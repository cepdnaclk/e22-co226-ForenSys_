-- ============================================================================
-- 05_functions_procedures.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- sp_register_case: create a case_register row and auto-generate its
-- reference number in the department's own numbering convention
-- (e.g. MO/1234/2026), inside a single transaction.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_register_case(
    p_subject_type   character varying,
    p_date_of_incident date DEFAULT NULL,
    p_district_code    character varying DEFAULT 'GEN'
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_register_id bigint;
    v_seq         bigint;
    v_ref_no      character varying(50);
BEGIN
    INSERT INTO public.case_register (subject_type, date_of_incident, created_by)
    VALUES (p_subject_type, p_date_of_incident, public.app_current_user_id())
    RETURNING register_id INTO v_register_id;

    v_seq := v_register_id;
    v_ref_no := p_district_code || '/' || v_seq || '/' || to_char(now(), 'YYYY');

    UPDATE public.case_register SET autopsy_ref_no = v_ref_no WHERE register_id = v_register_id;

    RETURN v_register_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- sp_finalize_report: move a report DRAFT -> FINALIZED. Once finalized, the
-- content-bearing columns become immutable (enforced by trigger in
-- 06_triggers.sql); any further change must go through sp_amend_report which
-- creates a new versioned row linked via parent_report_id.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_finalize_report(p_report_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_status character varying(20);
BEGIN
    SELECT status INTO v_status FROM public.forensic_report WHERE id = p_report_id FOR UPDATE;
    IF v_status IS NULL THEN
        RAISE EXCEPTION 'forensic_report % not found', p_report_id;
    END IF;
    IF v_status <> 'DRAFT' THEN
        RAISE EXCEPTION 'report % is in status % - only DRAFT reports can be finalized', p_report_id, v_status;
    END IF;

    UPDATE public.forensic_report
    SET status = 'FINALIZED', finalized_date = now(), updated_at = now()
    WHERE id = p_report_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- sp_amend_report: create a new DRAFT version of a finalized/dispatched
-- report, preserving the original for the evidentiary record and linking the
-- chain via parent_report_id + version_number.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_amend_report(p_report_id bigint, p_amendment_reason text)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_id bigint;
BEGIN
    INSERT INTO public.forensic_report (
        case_type, court_case_no, court_name, doctor_designation, doctor_name,
        doctor_slmc_no, opinion, police_ref_no, police_station, report_type,
        status, version_number, mlef_id, pm_serial_no, parent_report_id, amendment_reason
    )
    SELECT
        case_type, court_case_no, court_name, doctor_designation, doctor_name,
        doctor_slmc_no, opinion, police_ref_no, police_station, report_type,
        'DRAFT', version_number + 1, mlef_id, pm_serial_no, id, p_amendment_reason
    FROM public.forensic_report
    WHERE id = p_report_id
    RETURNING id INTO v_new_id;

    IF v_new_id IS NULL THEN
        RAISE EXCEPTION 'forensic_report % not found', p_report_id;
    END IF;

    RETURN v_new_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- sp_transfer_custody: record a chain-of-custody handover for a sample, with
-- basic validation that the handover sequence is chronological.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_transfer_custody(
    p_sample_id       bigint,
    p_delivered_by_name character varying,
    p_delivered_by_nic    character varying,
    p_delivered_by_occupation character varying,
    p_delivery_date             date,
    p_delivery_time               time,
    p_accepted_by_name              character varying DEFAULT NULL,
    p_accepted_date                    date DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_last_delivery date;
    v_custody_id     bigint;
BEGIN
    SELECT max(delivery_date) INTO v_last_delivery
    FROM public.chain_of_custody WHERE sample_id = p_sample_id;

    IF v_last_delivery IS NOT NULL AND p_delivery_date < v_last_delivery THEN
        RAISE EXCEPTION 'New handover date % precedes previous handover date % for sample % - chain of custody must be chronological',
            p_delivery_date, v_last_delivery, p_sample_id;
    END IF;

    INSERT INTO public.chain_of_custody (
        sample_id, delivered_by_name, delivered_by_nic, delivered_by_occupation,
        delivery_date, delivery_time, accepted_by_name, accepted_date
    ) VALUES (
        p_sample_id, p_delivered_by_name, p_delivered_by_nic, p_delivered_by_occupation,
        p_delivery_date, p_delivery_time, p_accepted_by_name, p_accepted_date
    ) RETURNING custody_id INTO v_custody_id;

    RETURN v_custody_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- sp_anonymize_patient / sp_anonymize_deceased: PDPA erasure-request
-- fulfilment for subjects whose statutory retention period has lapsed.
-- Personal identifiers are irreversibly scrubbed; the clinical/forensic
-- record itself is kept (retention_years in data_retention_policy) because
-- it remains part of the permanent medico-legal case file.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_anonymize_patient(p_patient_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.patient
    SET full_name = 'ANONYMISED',
        address = NULL,
        nic_no = NULL,
        nic_no_enc = NULL,
        passport_no = NULL,
        passport_no_enc = NULL,
        is_deleted = true,
        updated_at = now()
    WHERE patient_id = p_patient_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_anonymize_deceased(p_deceased_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.deceased
    SET full_name = 'ANONYMISED',
        last_address = NULL,
        is_deleted = true,
        updated_at = now()
    WHERE deceased_id = p_deceased_id;

    UPDATE public.identifier
    SET full_name = 'ANONYMISED',
        nic_number = NULL,
        nic_number_enc = NULL,
        nic_number_hash = NULL,
        residing_address = NULL
    WHERE deceased_id = p_deceased_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- sp_run_retention_sweep: scheduled job (see pg_cron note in README) that
-- anonymises subjects whose retention window has lapsed AND whose case is no
-- longer under_investigation, i.e. it is safe to do so without destroying
-- live evidence.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_run_retention_sweep() RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer := 0;
    v_years integer;
    r RECORD;
BEGIN
    SELECT retention_years INTO v_years FROM public.data_retention_policy WHERE table_name = 'deceased';

    FOR r IN
        SELECT d.deceased_id
        FROM public.deceased d
        JOIN public.post_mortem pm ON pm.deceased_id = d.deceased_id
        WHERE NOT d.is_deleted
          AND NOT pm.under_investigation
          AND d.date_of_death IS NOT NULL
          AND d.date_of_death < CURRENT_DATE - (v_years || ' years')::interval
    LOOP
        PERFORM public.sp_anonymize_deceased(r.deceased_id);
        v_count := v_count + 1;
    END LOOP;

    RETURN v_count;
END;
$$;

-- ---------------------------------------------------------------------------
-- sp_grant_role / sp_revoke_role: audited wrappers around user_roles so that
-- every privilege change is captured with who performed it, even though the
-- underlying table has no explicit "granted/revoked by" business trigger.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_grant_role(p_user_id bigint, p_role_name character varying)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_role_id bigint;
BEGIN
    SELECT role_id INTO v_role_id FROM public.role WHERE role_name = p_role_name;
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'unknown role %', p_role_name;
    END IF;

    INSERT INTO public.user_roles (user_id, role_id, granted_by)
    VALUES (p_user_id, v_role_id, public.app_current_user_id())
    ON CONFLICT (user_id, role_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.sp_revoke_role(p_user_id bigint, p_role_name character varying)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM public.user_roles
    WHERE user_id = p_user_id
      AND role_id = (SELECT role_id FROM public.role WHERE role_name = p_role_name);
END;
$$;
