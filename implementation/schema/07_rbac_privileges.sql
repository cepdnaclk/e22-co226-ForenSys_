-- ============================================================================
-- 07_rbac_privileges.sql
-- Privilege grants for the five system roles + Row-Level Security.
-- ============================================================================
-- Role summary (principle of least privilege):
--   ADMIN               - full administrative access, including user/role
--                          management and audit review. Does NOT get a
--                          blanket bypass of RLS; even admins go through the
--                          same policies (BYPASSRLS is deliberately withheld).
--   MEDICAL_OFFICER      - full clinical/forensic authoring rights: autopsy,
--                          MLEF, injuries, samples, investigations, reports
--                          (draft/finalize). No user-management access.
--   CLERICAL_OFFICER     - case registration, court workflow, report
--                          dispatch tracking, media/document handling.
--                          Read-only on clinical opinion content; cannot
--                          create or edit medical findings.
--   POLICE_OFFICER       - can lodge/track requests that originate a case
--                          (inquest orders, court requests) and view case
--                          status, but cannot see clinical findings or PII
--                          beyond what is needed to identify the case.
--   LABORATORY_STAFF     - full CRUD on laboratory/histopathology/toxicology
--                          workflow and forensic_sample/chain_of_custody, but
--                          no access to identity tables (deceased, patient,
--                          identifier) - lab work is de-identified by sample
--                          number wherever the process allows it.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Seed the application-level role/permission tables to match the five roles.
-- ---------------------------------------------------------------------------
INSERT INTO public.role (role_name, description) VALUES
    ('ADMIN', 'System administrator - user/role management, full oversight'),
    ('MEDICAL_OFFICER', 'Judicial Medical Officer - clinical & forensic authoring'),
    ('CLERICAL_OFFICER', 'Registry/clerical staff - case intake, court & report logistics'),
    ('POLICE_OFFICER', 'Police officer - case referral, inquest & court liaison'),
    ('LABORATORY_STAFF', 'Laboratory staff - sample analysis workflow')
ON CONFLICT (role_name) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Table grants per PostgreSQL group role (used when a service/tool connects
-- with its own DB login rather than going through the app_service pool).
-- ---------------------------------------------------------------------------

-- ============ ADMIN ============
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO role_admin;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO role_admin;
REVOKE UPDATE, DELETE ON public.audit_log FROM role_admin; -- append-only, even for admins

-- ============ MEDICAL_OFFICER (JMO) ============
GRANT SELECT, INSERT, UPDATE ON
    public.post_mortem, public.pm_medical_officer, public.autopsy_exam,
    public.autopsy_cause_of_death, public.autopsy_comment, public.pre_autopsy_information,
    public.individual_injury, public.investigation, public.blood_investigation,
    public.ct_scan, public.histology, public.x_ray, public.mlef_record, public.referral,
    public.forensic_sample, public.chain_of_custody, public.media_asset, public.photograph,
    public.case_photograph, public.crime_photo, public.pm_photo, public.body_diagram_chart,
    public.audio_transcript, public.forensic_report, public.mlr_report
    TO role_medical_officer;
GRANT SELECT ON
    public.deceased, public.identifier, public.patient, public.case_register,
    public.inquest_order, public.laboratory_request, public.histopathology_request,
    public.toxicology_request, public.medical_officer, public.police_officer,
    public.v_case_overview, public.v_chain_of_custody_trail, public.v_pending_reports,
    public.v_lab_request_queue, public.v_court_deadlines
    TO role_medical_officer;
GRANT UPDATE (age_when_died, bht_no, date_of_death, hospital_name, place_of_death, sex,
              time_of_death, ward_no) ON public.deceased TO role_medical_officer;
GRANT EXECUTE ON FUNCTION
    public.sp_finalize_report(bigint), public.sp_amend_report(bigint, text),
    public.sp_transfer_custody(bigint, character varying, character varying, character varying, date, time, character varying, date)
    TO role_medical_officer;

-- ============ CLERICAL_OFFICER ============
GRANT SELECT, INSERT, UPDATE ON
    public.case_register, public.deceased, public.identifier, public.patient,
    public.court_request, public.court_summon, public.report_req, public.laboratory_request,
    public.consent_log, public.dsar_request
    TO role_clerical_officer;
GRANT SELECT ON
    public.post_mortem, public.autopsy_exam, public.mlef_record, public.forensic_report,
    public.mlr_report, public.medical_officer, public.police_officer, public.department,
    public.v_case_overview, public.v_pending_reports, public.v_court_deadlines,
    public.v_dsar_due_soon, public.v_staff_directory
    TO role_clerical_officer;
-- explicitly no INSERT/UPDATE on clinical opinion tables
REVOKE INSERT, UPDATE, DELETE ON
    public.autopsy_cause_of_death, public.autopsy_comment, public.individual_injury,
    public.forensic_report, public.mlr_report
    FROM role_clerical_officer;
GRANT EXECUTE ON FUNCTION public.sp_register_case(character varying, date, character varying) TO role_clerical_officer;

-- ============ POLICE_OFFICER ============
GRANT SELECT, INSERT ON
    public.inquest_order, public.court_request, public.court_summon
    TO role_police_officer;
GRANT SELECT ON
    public.v_case_overview, public.v_court_deadlines, public.case_register
    TO role_police_officer;
GRANT UPDATE (case_no, court, date_of_inquest, magistrate, police_officer_incharge, police_station_area)
    ON public.inquest_order TO role_police_officer;
-- police officers never get direct SELECT on clinical/identity detail tables
REVOKE ALL ON
    public.deceased, public.patient, public.identifier, public.mlef_record,
    public.autopsy_exam, public.forensic_report, public.mlr_report
    FROM role_police_officer;

-- ============ LABORATORY_STAFF ============
GRANT SELECT, INSERT, UPDATE ON
    public.forensic_sample, public.chain_of_custody, public.laboratory_request,
    public.histopathology_request, public.toxicology_request, public.investigation,
    public.blood_investigation, public.ct_scan, public.histology, public.x_ray
    TO role_laboratory_staff;
GRANT SELECT ON public.v_lab_request_queue, public.v_chain_of_custody_trail TO role_laboratory_staff;
GRANT EXECUTE ON FUNCTION
    public.sp_transfer_custody(bigint, character varying, character varying, character varying, date, time, character varying, date)
    TO role_laboratory_staff;
-- lab staff have no access at all to identity-bearing tables
REVOKE ALL ON public.deceased, public.patient, public.identifier FROM role_laboratory_staff;

-- ---------------------------------------------------------------------------
-- Audit log: append-only for everyone; nobody may UPDATE/DELETE it, not even
-- role_admin (revoked above). Only role_auditor may read it in full.
-- ---------------------------------------------------------------------------
GRANT INSERT ON public.audit_log, public.data_access_log TO
    role_admin, role_medical_officer, role_clerical_officer, role_police_officer, role_laboratory_staff;
GRANT SELECT ON public.audit_log, public.data_access_log, public.security_incident TO role_auditor;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO
    role_admin, role_medical_officer, role_clerical_officer, role_police_officer, role_laboratory_staff;

-- app_service (the pooled connection the web/API tier itself uses) needs
-- broad DML because real authorization happens at the RLS/app-RBAC layer,
-- not at the Postgres-login level, for this connection.
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_service;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_service;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_service;
REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM app_service; -- deletes only via SECURITY DEFINER sp_* functions
REVOKE UPDATE, DELETE ON public.audit_log FROM app_service;

-- ---------------------------------------------------------------------------
-- Row-Level Security: restrict which ROWS a session may see/touch based on
-- the app-level role recorded in app.current_role (set by the application
-- after authentication - see 03_security_pdpa.sql section B).
-- ---------------------------------------------------------------------------
ALTER TABLE public.deceased        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.identifier      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mlef_record     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forensic_report ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mlr_report      ENABLE ROW LEVEL SECURITY;

-- Police officers must never read these tables at all, even through
-- app_service - RLS blocks it independent of column/table grants.
CREATE POLICY rls_deceased_no_police ON public.deceased
    FOR ALL
    USING (public.app_current_role() IS DISTINCT FROM 'POLICE_OFFICER');

CREATE POLICY rls_patient_no_police ON public.patient
    FOR ALL
    USING (public.app_current_role() IS DISTINCT FROM 'POLICE_OFFICER');

CREATE POLICY rls_identifier_no_police ON public.identifier
    FOR ALL
    USING (public.app_current_role() IS DISTINCT FROM 'POLICE_OFFICER');

CREATE POLICY rls_mlef_no_police_no_lab ON public.mlef_record
    FOR ALL
    USING (public.app_current_role() NOT IN ('POLICE_OFFICER','LABORATORY_STAFF'));

-- Only medical officers may see an unfinalized (DRAFT) report's clinical
-- opinion; other roles only ever see reports once FINALIZED or later.
CREATE POLICY rls_forensic_report_draft_visibility ON public.forensic_report
    FOR SELECT
    USING (
        status <> 'DRAFT'
        OR public.app_current_role() IN ('ADMIN','MEDICAL_OFFICER')
    );
CREATE POLICY rls_forensic_report_write ON public.forensic_report
    FOR INSERT WITH CHECK (public.app_current_role() IN ('ADMIN','MEDICAL_OFFICER'));
CREATE POLICY rls_forensic_report_update ON public.forensic_report
    FOR UPDATE USING (public.app_current_role() IN ('ADMIN','MEDICAL_OFFICER'));

CREATE POLICY rls_mlr_report_draft_visibility ON public.mlr_report
    FOR ALL
    USING (public.app_current_role() IS DISTINCT FROM 'POLICE_OFFICER');

-- Note: ADMIN already passes every policy above (none of them exclude
-- ADMIN specifically). role_auditor connects for read-only compliance review
-- through audit_log/data_access_log/security_incident only (granted above)
-- and is intentionally NOT given row access to the PII tables themselves -
-- an auditor reviews who accessed what, not the clinical content itself.
