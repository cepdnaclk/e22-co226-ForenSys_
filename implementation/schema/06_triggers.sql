-- ============================================================================
-- 06_triggers.sql
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Generic updated_at maintenance
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'users','staff','case_register','deceased','patient','post_mortem',
        'autopsy_exam','mlef_record','forensic_report','medical_officer','police_officer'
    ] LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%1$s_set_updated_at BEFORE UPDATE ON public.%1$s
             FOR EACH ROW EXECUTE FUNCTION public.trg_set_updated_at();', t);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Generic audit-log trigger (append-only INSERT/UPDATE/DELETE capture)
-- Applied to tables carrying personal data or evidentiary significance.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_audit_row() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pk text;
    v_old jsonb;
    v_new jsonb;
    v_prev_hash text;
    v_row_hash text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_old := to_jsonb(OLD);
        v_pk  := v_old->>TG_ARGV[0];
    ELSE
        v_new := to_jsonb(NEW);
        v_pk  := v_new->>TG_ARGV[0];
        IF TG_OP = 'UPDATE' THEN
            v_old := to_jsonb(OLD);
        END IF;
    END IF;

    SELECT row_hash INTO v_prev_hash
    FROM public.audit_log
    WHERE table_name = TG_TABLE_NAME AND row_pk = v_pk
    ORDER BY audit_id DESC LIMIT 1;

    v_row_hash := encode(digest(coalesce(v_prev_hash, '') || coalesce(v_new::text, v_old::text), 'sha256'), 'hex');

    INSERT INTO public.audit_log (
        table_name, row_pk, operation, changed_by_user_id, changed_by_role,
        old_data, new_data, client_addr, row_hash
    ) VALUES (
        TG_TABLE_NAME, v_pk, TG_OP,
        public.app_current_user_id(), public.app_current_role(),
        v_old, v_new, inet_client_addr(), v_row_hash
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

DO $$
DECLARE
    tbl_pk text[][] := ARRAY[
        ARRAY['deceased','deceased_id'], ARRAY['patient','patient_id'],
        ARRAY['identifier','identifier_id'], ARRAY['mlef_record','mlef_id'],
        ARRAY['forensic_report','id'], ARRAY['mlr_report','mlr_id'],
        ARRAY['chain_of_custody','custody_id'], ARRAY['forensic_sample','sample_id'],
        ARRAY['case_register','register_id'], ARRAY['users','user_id'],
        ARRAY['user_roles', NULL], ARRAY['role_permissions', NULL]
    ];
    pair text[];
BEGIN
    FOREACH pair SLICE 1 IN ARRAY tbl_pk LOOP
        CONTINUE WHEN pair[2] IS NULL; -- composite-PK tables handled separately if needed
        EXECUTE format(
            'CREATE TRIGGER trg_%1$s_audit AFTER INSERT OR UPDATE OR DELETE ON public.%1$s
             FOR EACH ROW EXECUTE FUNCTION public.trg_audit_row(%2$L);',
            pair[1], pair[2]);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Immutability of finalized/dispatched forensic reports. Corrections must go
-- through sp_amend_report() (creates a new linked DRAFT version) rather than
-- editing evidentiary text after the fact.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_forensic_report_immutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status IN ('FINALIZED','DISPATCHED','RECEIPT_CONFIRMED') THEN
        IF NEW.status = OLD.status
           AND (NEW.opinion IS DISTINCT FROM OLD.opinion
                OR NEW.details_json IS DISTINCT FROM OLD.details_json
                OR NEW.doctor_name IS DISTINCT FROM OLD.doctor_name
                OR NEW.doctor_slmc_no IS DISTINCT FROM OLD.doctor_slmc_no) THEN
            RAISE EXCEPTION 'forensic_report % is % and its content is immutable - use sp_amend_report() to create a new version',
                OLD.id, OLD.status;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_forensic_report_immutable
BEFORE UPDATE ON public.forensic_report
FOR EACH ROW EXECUTE FUNCTION public.trg_forensic_report_immutable();

-- ---------------------------------------------------------------------------
-- Prevent hard DELETE on PII-bearing / evidentiary tables. PDPA erasure is
-- satisfied by sp_anonymize_* instead (see 05_functions_procedures.sql).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_block_hard_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Hard DELETE is not permitted on %.% - use the soft-delete/anonymisation procedures instead',
        TG_TABLE_SCHEMA, TG_TABLE_NAME;
END;
$$;

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'deceased','patient','mlef_record','forensic_report','mlr_report',
        'chain_of_custody','forensic_sample','case_register'
    ] LOOP
        EXECUTE format(
            'CREATE TRIGGER trg_%1$s_block_delete BEFORE DELETE ON public.%1$s
             FOR EACH ROW EXECUTE FUNCTION public.trg_block_hard_delete();', t);
    END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Keep the NIC search-hash column in sync automatically whenever the
-- plaintext nic_number is written (application may still be mid-migration
-- to the encrypted column).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_identifier_sync_nic_hash() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.nic_number IS DISTINCT FROM OLD.nic_number OR TG_OP = 'INSERT' THEN
        NEW.nic_number_hash := public.pii_search_hash(NEW.nic_number);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_identifier_sync_nic_hash
BEFORE INSERT OR UPDATE ON public.identifier
FOR EACH ROW EXECUTE FUNCTION public.trg_identifier_sync_nic_hash();

