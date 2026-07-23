-- ============================================================================
-- 02_indexes.sql
-- Indexes: every FK column gets one (Postgres does NOT auto-index FKs, unlike
-- the PK side), plus targeted indexes for the lookups the department does
-- every day (by case ref, by date range, by status, by NIC hash).
-- ============================================================================

-- --- Identity / access -------------------------------------------------
CREATE INDEX idx_staff_dept_id            ON public.staff (dept_id);
CREATE INDEX idx_staff_officer_id         ON public.staff (officer_id);
CREATE INDEX idx_staff_user_id            ON public.staff (user_id);
CREATE INDEX idx_user_roles_role_id       ON public.user_roles (role_id);
CREATE INDEX idx_role_permissions_perm_id ON public.role_permissions (permission_id);
CREATE INDEX idx_users_active_not_deleted ON public.users (user_id) WHERE is_active AND NOT is_deleted;

-- --- Case intake ---------------------------------------------------------
CREATE INDEX idx_case_register_dates      ON public.case_register (date_of_incident, date_of_death, date_of_autopsy);
CREATE INDEX idx_case_register_not_deleted ON public.case_register (register_id) WHERE NOT is_deleted;
CREATE INDEX idx_deceased_full_name       ON public.deceased (full_name);
CREATE INDEX idx_deceased_date_of_death   ON public.deceased (date_of_death);
CREATE INDEX idx_identifier_deceased_id   ON public.identifier (deceased_id);
CREATE INDEX idx_identifier_nic           ON public.identifier (nic_number);
CREATE INDEX idx_patient_full_name        ON public.patient (full_name);
CREATE INDEX idx_patient_nic              ON public.patient (nic_no);
CREATE INDEX idx_inquest_order_deceased   ON public.inquest_order (deceased_id);

-- --- Post-mortem / autopsy ------------------------------------------------
CREATE INDEX idx_post_mortem_deceased_id  ON public.post_mortem (deceased_id);
CREATE INDEX idx_post_mortem_exam_date    ON public.post_mortem (date_time_of_pm_exam);
CREATE INDEX idx_pm_medical_officer_officer ON public.pm_medical_officer (officer_id);
CREATE INDEX idx_autopsy_exam_pm          ON public.autopsy_exam (pm_serial_no);
CREATE INDEX idx_pre_autopsy_info_pm      ON public.pre_autopsy_information (pm_serial_no);

-- --- Injuries / investigations ---------------------------------------------
CREATE INDEX idx_individual_injury_mlef   ON public.individual_injury (mlef_id);
CREATE INDEX idx_investigation_injury     ON public.investigation (injury_id);
CREATE INDEX idx_investigation_pm         ON public.investigation (pm_serial_no);
CREATE INDEX idx_investigation_type_date  ON public.investigation (type, investigation_date);

-- --- MLEF -------------------------------------------------------------------
CREATE INDEX idx_mlef_record_medical_officer ON public.mlef_record (medical_officer_id);
CREATE INDEX idx_mlef_record_brought_by      ON public.mlef_record (brought_by_officer_id);
CREATE INDEX idx_mlef_record_patient         ON public.mlef_record (patient_id);
CREATE INDEX idx_mlef_record_police_ref_no   ON public.mlef_record (police_ref_no);
CREATE INDEX idx_mlef_record_examined_date   ON public.mlef_record (date_time_examined);
CREATE INDEX idx_referral_mlef               ON public.referral (mlef_id);

-- --- Samples & custody --------------------------------------------------------
CREATE INDEX idx_forensic_sample_autopsy  ON public.forensic_sample (autopsy_id);
CREATE INDEX idx_forensic_sample_mlef     ON public.forensic_sample (mlef_id);
CREATE INDEX idx_forensic_sample_production_no ON public.forensic_sample (production_number);
CREATE INDEX idx_chain_of_custody_sample  ON public.chain_of_custody (sample_id);
CREATE INDEX idx_chain_of_custody_dates   ON public.chain_of_custody (delivery_date, accepted_date);

-- --- Lab requests -------------------------------------------------------------
CREATE INDEX idx_laboratory_request_register ON public.laboratory_request (register_id);

-- --- Media --------------------------------------------------------------------
CREATE INDEX idx_media_asset_mlef         ON public.media_asset (mlef_id);
CREATE INDEX idx_media_asset_pm           ON public.media_asset (pm_serial_no);
CREATE INDEX idx_media_asset_type         ON public.media_asset (type);

-- --- Reports --------------------------------------------------------------------
CREATE INDEX idx_forensic_report_mlef     ON public.forensic_report (mlef_id);
CREATE INDEX idx_forensic_report_pm       ON public.forensic_report (pm_serial_no);
CREATE INDEX idx_forensic_report_parent   ON public.forensic_report (parent_report_id);
CREATE INDEX idx_forensic_report_status   ON public.forensic_report (status) WHERE NOT is_deleted;
CREATE INDEX idx_forensic_report_serial_no ON public.forensic_report (serial_no);
CREATE INDEX idx_forensic_report_details_json_gin ON public.forensic_report USING gin (details_json);
CREATE INDEX idx_mlr_report_mlef          ON public.mlr_report (mlef_id);

-- --- Court ------------------------------------------------------------------------
CREATE INDEX idx_court_request_pm         ON public.court_request (pm_serial_no);
CREATE INDEX idx_court_request_date       ON public.court_request (date_and_time);
CREATE INDEX idx_report_req_required_date ON public.report_req (required_date);
