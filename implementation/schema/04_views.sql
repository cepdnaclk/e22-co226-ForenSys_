-- ============================================================================
-- 04_views.sql
-- ============================================================================

-- Case dashboard: one row per registered case with key milestone dates.
-- Note: case_register does not carry a direct FK to deceased/post_mortem in
-- the source data model (the link is implied downstream via workflow), so
-- this view surfaces the case register alongside the post-mortem examined on
-- the same date as contextual information only. Once the application adds a
-- proper case_register -> post_mortem FK, replace the LATERAL match below
-- with a direct join for a guaranteed 1:1 result.
CREATE OR REPLACE VIEW public.v_case_overview AS
SELECT
    cr.register_id,
    cr.autopsy_ref_no,
    cr.subject_type,
    cr.date_of_incident,
    cr.date_of_death,
    cr.date_of_autopsy,
    pm.pm_serial_no,
    pm.under_investigation,
    d.full_name AS deceased_name,
    d.sex,
    d.age_when_died,
    cr.created_at,
    cr.updated_at
FROM public.case_register cr
LEFT JOIN LATERAL (
    SELECT p.pm_serial_no, p.under_investigation, p.deceased_id
    FROM public.post_mortem p
    WHERE cr.date_of_autopsy IS NOT NULL
      AND p.date_time_of_pm_exam::date = cr.date_of_autopsy
    ORDER BY p.pm_serial_no DESC
    LIMIT 1
) pm ON true
LEFT JOIN public.deceased d ON d.deceased_id = pm.deceased_id AND NOT d.is_deleted
WHERE NOT cr.is_deleted;

-- Chain-of-custody audit trail per sample - who handled an exhibit and when.
CREATE OR REPLACE VIEW public.v_chain_of_custody_trail AS
SELECT
    fs.sample_id,
    fs.specimen_type,
    fs.production_number,
    fs.autopsy_id,
    fs.mlef_id,
    coc.custody_id,
    coc.delivered_by_name,
    coc.delivered_by_occupation,
    coc.delivery_date,
    coc.delivery_time,
    coc.accepted_by_name,
    coc.accepted_date,
    coc.jmo_signature_status
FROM public.forensic_sample fs
JOIN public.chain_of_custody coc ON coc.sample_id = fs.sample_id
WHERE NOT fs.is_deleted
ORDER BY fs.sample_id, coc.delivery_date;

-- Reports awaiting dispatch or court receipt confirmation.
CREATE OR REPLACE VIEW public.v_pending_reports AS
SELECT
    fr.id,
    fr.report_type,
    fr.status,
    fr.serial_no,
    fr.court_name,
    fr.police_station,
    fr.draft_date,
    fr.finalized_date,
    fr.dispatched_date,
    fr.mlef_id,
    fr.pm_serial_no,
    now() - COALESCE(fr.finalized_date, fr.created_at) AS age_since_finalized
FROM public.forensic_report fr
WHERE NOT fr.is_deleted
  AND fr.status IN ('DRAFT','FINALIZED','DISPATCHED');

-- Upcoming/overdue court obligations.
CREATE OR REPLACE VIEW public.v_court_deadlines AS
SELECT
    rr.request_id,
    cs.case_no,
    cs.court,
    cq.date_and_time AS request_date,
    rr.required_date,
    rr.report_sent_date,
    (rr.report_sent_date IS NULL AND rr.required_date < CURRENT_DATE) AS is_overdue
FROM public.report_req rr
JOIN public.court_request cq ON cq.request_id = rr.request_id
LEFT JOIN public.court_summon cs ON cs.request_id = rr.request_id;

-- Laboratory workload queue (histopathology + toxicology in one place).
CREATE OR REPLACE VIEW public.v_lab_request_queue AS
SELECT
    lr.request_id,
    lr.request_type,
    lr.register_id,
    lr.requested_at,
    hr.diagnosis,
    hr.request_type AS histopathology_priority,
    tr.mode_of_poisoning,
    tr.analysis_required
FROM public.laboratory_request lr
LEFT JOIN public.histopathology_request hr ON hr.request_id = lr.request_id
LEFT JOIN public.toxicology_request tr ON tr.request_id = lr.request_id;

-- PII-masked staff directory - safe to expose to any authenticated role.
CREATE OR REPLACE VIEW public.v_staff_directory AS
SELECT
    s.staff_id,
    s.specialization,
    dp.dept_name,
    mo.designation,
    left(mo.full_name, 1) || repeat('*', greatest(char_length(mo.full_name) - 1, 0)) AS officer_name_masked,
    s.is_active
FROM public.staff s
LEFT JOIN public.department dp ON dp.dept_id = s.dept_id
LEFT JOIN public.medical_officer mo ON mo.officer_id = s.officer_id
WHERE NOT s.is_deleted;

-- Compliance dashboard: DSAR requests approaching their statutory deadline.
CREATE OR REPLACE VIEW public.v_dsar_due_soon AS
SELECT dsar_id, requester_name, request_type, status, received_at, due_at,
       (due_at - now()) AS time_remaining
FROM public.dsar_request
WHERE status NOT IN ('COMPLETED','REJECTED_STATUTORY_RETENTION')
ORDER BY due_at;
