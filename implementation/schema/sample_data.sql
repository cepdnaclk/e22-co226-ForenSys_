-- ============================================================================
-- 02_data.sql
-- Sample Data Dump for Forensic Medical Department Database System
-- ============================================================================

BEGIN;

SET search_path = public;

-- ----------------------------------------------------------------------------
-- SECTION A - IDENTITY, ACCESS CONTROL, ORGANISATION
-- ----------------------------------------------------------------------------

-- public.users
INSERT INTO public.users (
    user_id, user_name, password, email, is_active, is_deleted, 
    failed_login_attempts, locked_until, last_login_at, password_changed_at, 
    mfa_enabled, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES 
(
    1, 'admin_sys', '$2a$12$e86821217e6e58b13d298u/aY0K8G1rLq5xJ/X58k8z.123456789012', 
    'admin@forensic.gov.lk', true, false, 0, NULL, '2025-02-10 08:30:00+00', 
    '2025-01-01 00:00:00+00', true, '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'
),
(
    2, 'dr_perera', '$2a$12$e86821217e6e58b13d298u/aY0K8G1rLq5xJ/X58k8z.123456789012', 
    'jmo.perera@forensic.gov.lk', true, false, 0, NULL, '2025-02-12 09:15:00+00', 
    '2025-01-01 00:00:00+00', true, '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'
),
(
    3, 'ip_fernando', '$2a$12$e86821217e6e58b13d298u/aY0K8G1rLq5xJ/X58k8z.123456789012', 
    'ip.fernando@police.gov.lk', true, false, 0, NULL, '2025-02-11 14:20:00+00', 
    '2025-01-01 00:00:00+00', false, '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'
),
(
    4, 'lab_tech_sami', '$2a$12$e86821217e6e58b13d298u/aY0K8G1rLq5xJ/X58k8z.123456789012', 
    'sami.lab@forensic.gov.lk', true, false, 0, NULL, '2025-02-12 11:00:00+00', 
    '2025-01-01 00:00:00+00', false, '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'
);

-- public.role
INSERT INTO public.role (role_id, role_name, description, created_at) 
OVERRIDING SYSTEM VALUE VALUES
(1, 'ADMIN', 'System Administrator', '2025-01-01 00:00:00+00'),
(2, 'MEDICAL_OFFICER', 'Judicial Medical Officer', '2025-01-01 00:00:00+00'),
(3, 'POLICE_OFFICER', 'Investigating Police Officer', '2025-01-01 00:00:00+00'),
(4, 'CLERICAL_OFFICER', 'Department Records Clerk', '2025-01-01 00:00:00+00'),
(5, 'LABORATORY_STAFF', 'Forensic Laboratory Technician', '2025-01-01 00:00:00+00');

-- public.permission
INSERT INTO public.permission (permission_id, action_description, created_at) 
OVERRIDING SYSTEM VALUE VALUES
(1, 'READ_AUTOPSY_REPORTS', '2025-01-01 00:00:00+00'),
(2, 'WRITE_AUTOPSY_REPORTS', '2025-01-01 00:00:00+00'),
(3, 'MANAGE_SYSTEM_USERS', '2025-01-01 00:00:00+00'),
(4, 'LOG_FORENSIC_SAMPLES', '2025-01-01 00:00:00+00');

-- public.role_permissions
INSERT INTO public.role_permissions (role_id, permission_id, granted_at) VALUES
(1, 3, '2025-01-01 00:00:00+00'),
(2, 1, '2025-01-01 00:00:00+00'),
(2, 2, '2025-01-01 00:00:00+00'),
(5, 4, '2025-01-01 00:00:00+00');

-- public.user_roles
INSERT INTO public.user_roles (user_id, role_id, granted_at, granted_by) VALUES
(1, 1, '2025-01-01 00:00:00+00', 1),
(2, 2, '2025-01-01 00:00:00+00', 1),
(3, 3, '2025-01-01 00:00:00+00', 1),
(4, 5, '2025-01-01 00:00:00+00', 1);

-- public.department
INSERT INTO public.department (dept_id, dept_name, created_at) 
OVERRIDING SYSTEM VALUE VALUES
(1, 'Department of Forensic Medicine, NHSL', '2025-01-01 00:00:00+00'),
(2, 'Toxicology & Histopathology Laboratory', '2025-01-01 00:00:00+00');

-- public.medical_officer
INSERT INTO public.medical_officer (
    officer_id, full_name, designation, qualifications, slmc_reg_no, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Dr. K. L. Perera', 'Senior Judicial Medical Officer', 
    'MBBS, MD (Forensic Medicine)', 'SLMC-12345', '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'
);

-- public.police_officer
INSERT INTO public.police_officer (
    officer_id, name, police_station, rank, reg_no, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Inspector A. B. Fernando', 'Colombo Central Police Station', 
    'Inspector of Police', 'IP-98765', '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'
);

-- public.staff
INSERT INTO public.staff (
    staff_id, specialization, dept_id, officer_id, user_id, is_active, is_deleted, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Forensic Pathology Specialist', 1, 1, 2, true, false, '2025-01-01 00:00:00+00', '2025-01-01 00:00:00+00'
);

-- public.staff_contacts
INSERT INTO public.staff_contacts (staff_id, contact_no) VALUES
(1, '+94771234567'),
(1, '0112691111');

-- ----------------------------------------------------------------------------
-- SECTION B - CASE INTAKE, SUBJECTS
-- ----------------------------------------------------------------------------

-- public.case_register
INSERT INTO public.case_register (
    register_id, autopsy_ref_no, date_of_autopsy, date_of_death, date_of_incident, 
    subject_type, is_deleted, created_at, updated_at, created_by, updated_by
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'PM-2025-001', '2025-01-15', '2025-01-14', '2025-01-14', 
    'DECEASED', false, '2025-01-14 20:00:00+00', '2025-01-15 10:00:00+00', 1, 1
),
(
    2, NULL, NULL, NULL, '2025-02-01', 
    'PATIENT', false, '2025-02-01 09:00:00+00', '2025-02-01 09:00:00+00', 1, 1
);

-- public.deceased
INSERT INTO public.deceased (
    deceased_id, age_when_died, bht_no, date_of_death, full_name, hospital_name, 
    last_address, place_of_death, sex, time_of_death, ward_no, is_deleted, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 42, 'BHT-88392', '2025-01-14', 'Saman Kumara', 'National Hospital Sri Lanka', 
    'No. 45, Main Street, Colombo 03', 'Ward 12, NHSL', 'MALE', '14:30:00', 'Ward 12', 
    false, '2025-01-14 16:00:00+00', '2025-01-14 16:00:00+00'
);

-- public.identifier
INSERT INTO public.identifier (
    identifier_id, full_name, nic_number, residing_address, deceased_id, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Nimali Kumara', '198354300123', 'No. 45, Main Street, Colombo 03', 1, '2025-01-14 17:00:00+00'
);

-- public.patient
INSERT INTO public.patient (
    patient_id, address, consent_given, consent_date, date_of_birth, full_name, 
    nic_no, passport_no, sex, is_deleted, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'No. 12, Galle Road, Colombo 04', true, '2025-02-01 09:30:00+00', '1992-05-15', 
    'Sunil Jayasinghe', '199213500987', NULL, 'MALE', false, '2025-02-01 09:30:00+00', '2025-02-01 09:30:00+00'
);

-- public.inquest_order
INSERT INTO public.inquest_order (
    inquest_number, case_no, court, date_of_inquest, inquirer_designation, 
    inquirer_full_name, inquirer_into_sudden_deaths, magistrate, police_officer_incharge, 
    police_station_area, deceased_id, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'INQ-2025-101', 'Magistrate Court 01 Colombo', '2025-01-14', 'Inquirer into Sudden Deaths', 
    'H. M. Bandara', true, 'Hon. Magistrate Silva', 'IP-98765', 'Colombo Central', 1, '2025-01-14 18:00:00+00'
);

-- ----------------------------------------------------------------------------
-- SECTION C - POST MORTEM / AUTOPSY
-- ----------------------------------------------------------------------------

-- public.post_mortem
INSERT INTO public.post_mortem (
    pm_serial_no, date_time_of_pm_exam, district, place_of_examination, 
    specimens_retained, under_investigation, deceased_id, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, '2025-01-15 09:30:00+00', 'Colombo', 'JMO Mortuary - NHSL', true, true, 1, '2025-01-15 08:00:00+00', '2025-01-15 12:00:00+00'
);

-- public.pm_medical_officer
INSERT INTO public.pm_medical_officer (pm_serial_no, officer_id, assigned_at) VALUES
(1, 1, '2025-01-15 08:30:00+00');

-- public.autopsy_exam
INSERT INTO public.autopsy_exam (
    autopsy_id, autopsy_report_pdf, health1135a_doc, maternal_death_category, 
    under_investigation, pm_serial_no, is_deleted, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, '/storage/reports/pm_2025_001.pdf', '/storage/docs/h1135a_001.pdf', NULL, true, 1, false, '2025-01-15 09:30:00+00', '2025-01-15 12:00:00+00'
);

-- public.autopsy_cause_of_death
INSERT INTO public.autopsy_cause_of_death (
    autopsy_id, aproxtfrom_onset_to_death, cause_description, severity, seq_no
) VALUES
(1, 'Minutes', 'Hemorrhagic shock due to sharp force injury to chest', 'IMMEDIATE', 1),
(1, 'Minutes', 'Penetrating stab wound to cardiac myocardium', 'ANTECEDENT', 2);

-- public.autopsy_comment
INSERT INTO public.autopsy_comment (autopsy_id, comment, commented_at) VALUES
(1, 'Rigor mortis present throughout the body. Livor mortis fixed dorsally.', '2025-01-15 10:00:00+00');

-- public.pre_autopsy_information
INSERT INTO public.pre_autopsy_information (
    record_id, information_category, record_details, pm_serial_no, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Police B-Report', 'Deceased was found unmoving following a street altercation.', 1, '2025-01-15 08:30:00+00'
);

-- ----------------------------------------------------------------------------
-- SECTION F - MEDICO-LEGAL EXAMINATION FORM (MLEF)
-- (Inserted before Section D/E to fulfill foreign key targets)
-- ----------------------------------------------------------------------------

-- public.mlef_record
INSERT INTO public.mlef_record (
    mlef_id, alcohol_influence, breathing_smell_intensity, date_admitted, date_discharged, 
    date_time_examined, drug_consumed, drug_influence, hospital_bht_no, hospital_name, 
    hospital_ward, injury_abrasion, injury_bite, injury_burns, injury_contusion, 
    injury_cut, injury_dislocation, injury_explosive, injury_firearm, injury_fracture, 
    injury_laceration, injury_none, injury_stab, internal_injuries, other_opinions_recommendations, 
    others_nature_of_harm, place_examined, police_date_of_issue, police_ref_no, reason_for_referral, 
    remarks, sexual_assault_brief_history, short_history_given_by_patient, signs_anal_penetration, 
    signs_inter_labial_penetration, signs_vaginal_hymen_penetration, time_admitted, medical_officer_id, 
    brought_by_officer_id, patient_id, is_deleted, created_at, updated_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'NEGATIVE', 'None', '2025-02-01', '2025-02-01', '2025-02-01 10:00:00+00', false, 
    'NEGATIVE', 'BHT-90123', 'National Hospital Sri Lanka', 'Ward 05', false, false, false, 
    true, true, false, false, false, false, false, false, false, false, 
    'Suggest follow up radiograph in 7 days.', NULL, 'JMO Office - NHSL', '2025-02-01', 
    'POL-2025-555', 'Alleged physical assault examination', 'Patient conscious and oriented.', 
    NULL, 'Attacked with a wooden club during an argument.', false, false, false, 
    '09:00:00', 1, 1, 1, false, '2025-02-01 10:00:00+00', '2025-02-01 10:30:00+00'
);

-- ----------------------------------------------------------------------------
-- SECTION D - INJURIES
-- ----------------------------------------------------------------------------

-- public.individual_injury
INSERT INTO public.individual_injury (
    injury_id, auto_seq_number, category_of_hurt, detailed_description, diagram_tag_label, 
    explanatory_remarks, injury_class, injury_to_course_of_death, nature_of_bodily_harm, 
    penal_code_section, remarks, specific_weapon_name, weapon_category, mlef_id, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'INJ-001', 'NON_GRIEVOUS', 'Ecchymosis measuring 5x3 cm on anterior right forearm.', 
    'TAG-A', 'Defense injury consistent with blunt trauma', 'Contusion', 
    'Did not contribute to fatality', 'CONTUSION', '314', 'Mild tenderness', 'Wooden bat', 
    'BLUNT', 1, '2025-02-01 10:15:00+00'
);

-- ----------------------------------------------------------------------------
-- SECTION E - CLINICAL INVESTIGATIONS
-- ----------------------------------------------------------------------------

-- public.investigation
INSERT INTO public.investigation (
    investigation_id, description, findings, investigation_date, result, 
    type, injury_id, pm_serial_no, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Post-Mortem Blood Screen', 'Negative for ethanol and major toxins', '2025-01-15', 
    'Clear', 'BLOOD', NULL, 1, '2025-01-15 11:00:00+00'
),
(
    2, 'Forearm Radiograph', 'No cortical disruption or fracture seen', '2025-02-01', 
    'Normal bone architecture', 'X_RAY', 1, NULL, '2025-02-01 11:00:00+00'
);

-- public.blood_investigation
INSERT INTO public.blood_investigation (investigation_id) VALUES (1);

-- public.x_ray
INSERT INTO public.x_ray (investigation_id) VALUES (2);

-- public.referral
INSERT INTO public.referral (
    ref_id, referral_reason, referred_to_consultant, report_received_back, specialty, mlef_id, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Rule out hairline crack on ulnar bone', 'Dr. S. Jayawardene (Radiologist)', 
    true, 'Radiology', 1, '2025-02-01 11:15:00+00'
);

-- ----------------------------------------------------------------------------
-- SECTION G - SAMPLES & CHAIN OF CUSTODY
-- ----------------------------------------------------------------------------

-- public.forensic_sample
INSERT INTO public.forensic_sample (
    sample_id, collected_by, collection_date, number_of_tissues, organ_source, 
    production_number, referred_institution, specimen_type, autopsy_id, mlef_id, is_deleted, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Dr. K. L. Perera', '2025-01-15', 1, 'Femoral Blood', 'PROD-2025-88A', 
    'Government Analyst Department', 'BLOOD', 1, NULL, false, '2025-01-15 11:30:00+00'
),
(
    2, 'Dr. K. L. Perera', '2025-02-01', 1, 'Urine Specimen', 'PROD-2025-99B', 
    'Genetech Sri Lanka', 'URINE', NULL, 1, false, '2025-02-01 11:30:00+00'
);

-- public.chain_of_custody
INSERT INTO public.chain_of_custody (
    custody_id, accepted_by_name, accepted_date, delivered_by_name, delivered_by_nic, 
    delivered_by_occupation, delivery_date, delivery_time, jmo_signature_status, sample_id, created_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Analyst M. Perera', '2025-01-16', 'PC Silva', '198812345678', 
    'Police Constable', '2025-01-15', '14:00:00', true, 1, '2025-01-15 14:00:00+00'
);

-- ----------------------------------------------------------------------------
-- SECTION H - LABORATORY REQUESTS
-- ----------------------------------------------------------------------------

-- public.laboratory_request
INSERT INTO public.laboratory_request (
    request_id, register_id, request_type, requested_at
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 1, 'HISTOPATHOLOGY', '2025-01-15 12:00:00+00'
),
(
    2, 1, 'TOXICOLOGY', '2025-01-15 12:10:00+00'
);

-- public.histopathology_request
INSERT INTO public.histopathology_request (
    diagnosis, macroscopic_appearances, microscopic_appearance, probable_cause_of_death, 
    request_type, special_procedure_request, request_id
) VALUES
(
    'Myocardial infarction rule out', 'Narrowed left anterior descending artery', 
    'Infiltrate of neutrophils confirmed', 'Cardiogenic Shock', 'ROUTINE', 'H&E Stain', 1
);

-- public.toxicology_request
INSERT INTO public.toxicology_request (
    analysis_required, medical_history, mode_of_poisoning, request_id
) VALUES
(
    'Full toxicology panel including pesticide screen', 'No known history of drug ingestion', 
    'HOMICIDE', 2
);

-- ----------------------------------------------------------------------------
-- SECTION I - MEDIA
-- ----------------------------------------------------------------------------

-- public.media_asset
INSERT INTO public.media_asset (
    media_id, file_name, file_path, type, checksum_sha256, mlef_id, pm_serial_no, created_at, created_by
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'pm_001_injury.jpg', '/storage/media/2025/pm_001_injury.jpg', 'PM_PHOTO', 
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', NULL, 1, '2025-01-15 10:15:00+00', 1
),
(
    2, 'mlef_001_chart.png', '/storage/media/2025/mlef_001_chart.png', 'BODY_DIAGRAM_CHART', 
    'a1b2c3d4e5f60123456789abcdef0123456789abcdef0123456789abcdef0123', 1, NULL, '2025-02-01 10:30:00+00', 1
);

-- public.photograph
INSERT INTO public.photograph (caption, capture_date, description, media_id) VALUES
('Chest wound entrance', '2025-01-15', 'Close-up of penetrating stab wound on left chest wall.', 1);

-- public.pm_photo
INSERT INTO public.pm_photo (media_id) VALUES (1);

-- public.body_diagram_chart
INSERT INTO public.body_diagram_chart (diagram_type, media_id) VALUES
('Full Body Front Anatomy Chart', 2);

-- ----------------------------------------------------------------------------
-- SECTION J - MEDICO-LEGAL REPORTS
-- ----------------------------------------------------------------------------

-- public.forensic_report
INSERT INTO public.forensic_report (
    id, amendment_reason, case_type, court_case_no, court_name, created_at, date_of_trial, 
    details_json, dispatched_date, doctor_designation, doctor_name, doctor_slmc_no, draft_date, 
    examination_date, finalized_date, opinion, parent_report_id, police_ref_no, police_station, 
    receipt_confirmed_date, report_type, serial_no, status, updated_at, version_number, 
    mlef_id, pm_serial_no, is_deleted
) OVERRIDING SYSTEM VALUE VALUES
(
    1, NULL, 'CRIMINAL', 'MC-101/2025', 'Magistrate Court Colombo 01', '2025-01-15 12:00:00+00', NULL, 
    '{"findings": "Death due to sharp force cardiac injury"}'::jsonb, '2025-01-17 10:00:00+00', 
    'Senior Judicial Medical Officer', 'Dr. K. L. Perera', 'SLMC-12345', '2025-01-15 14:00:00+00', 
    '2025-01-15 09:30:00+00', '2025-01-16 11:00:00+00', 'Death was caused by sharp force trauma.', 
    NULL, 'POL-2025-100', 'Colombo Central', '2025-01-18 09:00:00+00', 'PMR', 'PMR-2025-001', 
    'RECEIPT_CONFIRMED', '2025-01-18 09:00:00+00', 1, NULL, 1, false
);

-- public.mlr_report
INSERT INTO public.mlr_report (
    mlr_id, compatibility_verdict, consider_self_infliction, court_case_no, court_name, 
    date_of_issue, date_of_trial, date_report_dispatched, police_station, received_by_court_date, 
    serial_no, mlef_id
) OVERRIDING SYSTEM VALUE VALUES
(
    1, 'Injuries consistent with non-fatal blunt force impact', false, 'MC-202/2025', 
    'Magistrate Court Colombo 01', '2025-02-02', NULL, '2025-02-03', 'Colombo Central', 
    '2025-02-04', 'MLR-2025-045', 1
);

-- ----------------------------------------------------------------------------
-- SECTION K - COURT WORKFLOW
-- ----------------------------------------------------------------------------

-- public.court_request
INSERT INTO public.court_request (
    request_id, date_and_time, pm_serial_no
) OVERRIDING SYSTEM VALUE VALUES
(
    1, '2025-02-10 10:00:00+00', 1
);

-- public.court_summon
INSERT INTO public.court_summon (case_no, court, request_id) VALUES
('MC-101/2025', 'Magistrate Court Colombo 01', 1);

-- ----------------------------------------------------------------------------
-- SEQUENCE SYNCHRONIZATION
-- ----------------------------------------------------------------------------

SELECT setval(pg_get_serial_sequence('public.users', 'user_id'), COALESCE(MAX(user_id), 1)) FROM public.users;
SELECT setval(pg_get_serial_sequence('public.role', 'role_id'), COALESCE(MAX(role_id), 1)) FROM public.role;
SELECT setval(pg_get_serial_sequence('public.permission', 'permission_id'), COALESCE(MAX(permission_id), 1)) FROM public.permission;
SELECT setval(pg_get_serial_sequence('public.department', 'dept_id'), COALESCE(MAX(dept_id), 1)) FROM public.department;
SELECT setval(pg_get_serial_sequence('public.medical_officer', 'officer_id'), COALESCE(MAX(officer_id), 1)) FROM public.medical_officer;
SELECT setval(pg_get_serial_sequence('public.police_officer', 'officer_id'), COALESCE(MAX(officer_id), 1)) FROM public.police_officer;
SELECT setval(pg_get_serial_sequence('public.staff', 'staff_id'), COALESCE(MAX(staff_id), 1)) FROM public.staff;
SELECT setval(pg_get_serial_sequence('public.case_register', 'register_id'), COALESCE(MAX(register_id), 1)) FROM public.case_register;
SELECT setval(pg_get_serial_sequence('public.deceased', 'deceased_id'), COALESCE(MAX(deceased_id), 1)) FROM public.deceased;
SELECT setval(pg_get_serial_sequence('public.identifier', 'identifier_id'), COALESCE(MAX(identifier_id), 1)) FROM public.identifier;
SELECT setval(pg_get_serial_sequence('public.patient', 'patient_id'), COALESCE(MAX(patient_id), 1)) FROM public.patient;
SELECT setval(pg_get_serial_sequence('public.inquest_order', 'inquest_number'), COALESCE(MAX(inquest_number), 1)) FROM public.inquest_order;
SELECT setval(pg_get_serial_sequence('public.post_mortem', 'pm_serial_no'), COALESCE(MAX(pm_serial_no), 1)) FROM public.post_mortem;
SELECT setval(pg_get_serial_sequence('public.autopsy_exam', 'autopsy_id'), COALESCE(MAX(autopsy_id), 1)) FROM public.autopsy_exam;
SELECT setval(pg_get_serial_sequence('public.pre_autopsy_information', 'record_id'), COALESCE(MAX(record_id), 1)) FROM public.pre_autopsy_information;
SELECT setval(pg_get_serial_sequence('public.mlef_record', 'mlef_id'), COALESCE(MAX(mlef_id), 1)) FROM public.mlef_record;
SELECT setval(pg_get_serial_sequence('public.individual_injury', 'injury_id'), COALESCE(MAX(injury_id), 1)) FROM public.individual_injury;
SELECT setval(pg_get_serial_sequence('public.investigation', 'investigation_id'), COALESCE(MAX(investigation_id), 1)) FROM public.investigation;
SELECT setval(pg_get_serial_sequence('public.referral', 'ref_id'), COALESCE(MAX(ref_id), 1)) FROM public.referral;
SELECT setval(pg_get_serial_sequence('public.forensic_sample', 'sample_id'), COALESCE(MAX(sample_id), 1)) FROM public.forensic_sample;
SELECT setval(pg_get_serial_sequence('public.chain_of_custody', 'custody_id'), COALESCE(MAX(custody_id), 1)) FROM public.chain_of_custody;
SELECT setval(pg_get_serial_sequence('public.laboratory_request', 'request_id'), COALESCE(MAX(request_id), 1)) FROM public.laboratory_request;
SELECT setval(pg_get_serial_sequence('public.media_asset', 'media_id'), COALESCE(MAX(media_id), 1)) FROM public.media_asset;
SELECT setval(pg_get_serial_sequence('public.forensic_report', 'id'), COALESCE(MAX(id), 1)) FROM public.forensic_report;
SELECT setval(pg_get_serial_sequence('public.mlr_report', 'mlr_id'), COALESCE(MAX(mlr_id), 1)) FROM public.mlr_report;
SELECT setval(pg_get_serial_sequence('public.court_request', 'request_id'), COALESCE(MAX(request_id), 1)) FROM public.court_request;

COMMIT;