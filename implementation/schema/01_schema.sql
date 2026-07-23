-- ============================================================================
-- 01_schema.sql
-- Forensic Medical Department Database System - Hardened Schema
-- ============================================================================
-- Conventions used throughout this file:
--   * Every root entity gets: PRIMARY KEY, created_at/updated_at/created_by/
--     updated_by audit columns, and (where it holds personal or forensic
--     data with legal retention duties) an is_deleted soft-delete flag - hard
--     DELETE is blocked by trigger (05_triggers.sql); PDPA erasure requests
--     are satisfied by anonymisation, not physical deletion, because forensic
--     records are subject to statutory retention (Judicature Act / Coroners
--     ordinance) that overrides an erasure request while a case is open or
--     within the retention window.
--   * FK actions:
--       - ON DELETE RESTRICT ON UPDATE CASCADE   -> default for references
--         between independent forensic entities (never silently cascade a
--         delete through a chain-of-custody).
--       - ON DELETE CASCADE  ON UPDATE CASCADE    -> for true 1:1 "subtype"
--         detail tables whose PK IS the parent's PK (Hibernate table-per-
--         subclass pattern already present in the source dump) and for
--         many-to-many junction tables. Deleting the parent legitimately
--         removes its own extension rows / associations.
--   * CHECK constraints add real business-rule validation (no future dates,
--     non-negative measures, enumerations, NIC/contact number formats,
--     status lifecycles).
-- ============================================================================

SET search_path = public;

-- ============================================================================
-- SECTION A - IDENTITY, ACCESS CONTROL, ORGANISATION
-- ============================================================================

CREATE TABLE public.users (
    user_id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_name       character varying(100)  NOT NULL,
    password        character varying(255)  NOT NULL, -- store a bcrypt/argon2 HASH only, never plaintext
    email           character varying(255),
    is_active       boolean NOT NULL DEFAULT true,
    is_deleted      boolean NOT NULL DEFAULT false,
    failed_login_attempts smallint NOT NULL DEFAULT 0,
    locked_until    timestamptz,
    last_login_at   timestamptz,
    password_changed_at timestamptz NOT NULL DEFAULT now(),
    mfa_enabled     boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT users_user_name_uk UNIQUE (user_name),
    CONSTRAINT users_email_uk UNIQUE (email),
    CONSTRAINT users_password_hash_len_ck CHECK (char_length(password) >= 59), -- bcrypt/argon2 hash length
    CONSTRAINT users_email_format_ck CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT users_failed_attempts_ck CHECK (failed_login_attempts >= 0)
);
COMMENT ON COLUMN public.users.password IS 'PDPA/security: bcrypt or argon2 hash ONLY. Application layer must never write plaintext here.';

CREATE TABLE public.role (
    role_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_name   character varying(50) NOT NULL,
    description character varying(255),
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT role_name_uk UNIQUE (role_name),
    CONSTRAINT role_name_allowed_ck CHECK (role_name = ANY (ARRAY[
        'ADMIN','MEDICAL_OFFICER','CLERICAL_OFFICER','POLICE_OFFICER','LABORATORY_STAFF'
    ]))
);

CREATE TABLE public.permission (
    permission_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action_description character varying(150) NOT NULL,
    created_at         timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT permission_action_uk UNIQUE (action_description)
);

CREATE TABLE public.role_permissions (
    role_id       bigint NOT NULL,
    permission_id bigint NOT NULL,
    granted_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT role_permissions_pkey PRIMARY KEY (role_id, permission_id),
    CONSTRAINT role_permissions_role_fk FOREIGN KEY (role_id) REFERENCES public.role(role_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT role_permissions_permission_fk FOREIGN KEY (permission_id) REFERENCES public.permission(permission_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE public.user_roles (
    user_id    bigint NOT NULL,
    role_id    bigint NOT NULL,
    granted_at timestamptz NOT NULL DEFAULT now(),
    granted_by bigint,
    CONSTRAINT user_roles_pkey PRIMARY KEY (user_id, role_id),
    CONSTRAINT user_roles_user_fk FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT user_roles_role_fk FOREIGN KEY (role_id) REFERENCES public.role(role_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT user_roles_granted_by_fk FOREIGN KEY (granted_by) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE public.department (
    dept_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name  character varying(150) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT department_name_uk UNIQUE (dept_name)
);

CREATE TABLE public.medical_officer (
    officer_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name      character varying(150) NOT NULL,
    designation    character varying(100),
    qualifications character varying(255),
    slmc_reg_no    character varying(20) NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT medical_officer_slmc_uk UNIQUE (slmc_reg_no)
);

CREATE TABLE public.police_officer (
    officer_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            character varying(150) NOT NULL,
    police_station  character varying(150),
    rank            character varying(80),
    reg_no          character varying(30) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT police_officer_reg_no_uk UNIQUE (reg_no)
);

CREATE TABLE public.staff (
    staff_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    specialization character varying(150),
    dept_id        bigint,
    officer_id     bigint,           -- link to medical_officer, when staff member is a JMO
    user_id        bigint,
    is_active      boolean NOT NULL DEFAULT true,
    is_deleted     boolean NOT NULL DEFAULT false,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT staff_user_id_uk UNIQUE (user_id),
    CONSTRAINT staff_officer_id_uk UNIQUE (officer_id),
    CONSTRAINT staff_dept_fk FOREIGN KEY (dept_id) REFERENCES public.department(dept_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT staff_officer_fk FOREIGN KEY (officer_id) REFERENCES public.medical_officer(officer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT staff_user_fk FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.staff_contacts (
    staff_id   bigint NOT NULL,
    contact_no character varying(20) NOT NULL,
    CONSTRAINT staff_contacts_pkey PRIMARY KEY (staff_id, contact_no),
    CONSTRAINT staff_contacts_staff_fk FOREIGN KEY (staff_id) REFERENCES public.staff(staff_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT staff_contacts_format_ck CHECK (contact_no ~ '^(\+94|0)[0-9]{9}$')
);

-- ============================================================================
-- SECTION B - CASE INTAKE, SUBJECTS
-- ============================================================================

CREATE TABLE public.case_register (
    register_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    autopsy_ref_no  character varying(50),
    date_of_autopsy date,
    date_of_death   date,
    date_of_incident date,
    subject_type    character varying(20) NOT NULL,
    is_deleted      boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    created_by      bigint,
    updated_by      bigint,
    CONSTRAINT case_register_subject_type_check CHECK (subject_type = ANY (ARRAY['DECEASED','PATIENT','PSYCHIATRIC','OTHER'])),
    CONSTRAINT case_register_dates_not_future_ck CHECK (
        (date_of_autopsy   IS NULL OR date_of_autopsy   <= CURRENT_DATE) AND
        (date_of_death     IS NULL OR date_of_death     <= CURRENT_DATE) AND
        (date_of_incident  IS NULL OR date_of_incident  <= CURRENT_DATE)
    ),
    CONSTRAINT case_register_date_order_ck CHECK (
        date_of_incident IS NULL OR date_of_death IS NULL OR date_of_incident <= date_of_death
    ),
    CONSTRAINT case_register_created_by_fk FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT case_register_updated_by_fk FOREIGN KEY (updated_by) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);
-- Partial unique index (not a plain UNIQUE) because the ref no is only
-- assigned once a case is formally registered - many rows legitimately have
-- NULL while pending.
CREATE UNIQUE INDEX case_register_autopsy_ref_no_uk ON public.case_register (autopsy_ref_no) WHERE autopsy_ref_no IS NOT NULL;

CREATE TABLE public.deceased (
    deceased_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    age_when_died  smallint,
    bht_no         character varying(50),
    date_of_death  date,
    full_name      character varying(150) NOT NULL,
    hospital_name  character varying(150),
    last_address   character varying(255),
    place_of_death character varying(150),
    sex            character varying(10) NOT NULL DEFAULT 'UNKNOWN',
    time_of_death  time(0) without time zone,
    ward_no        character varying(30),
    is_deleted     boolean NOT NULL DEFAULT false,     -- PDPA erasure -> anonymised, not physically removed
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT deceased_sex_check CHECK (sex = ANY (ARRAY['MALE','FEMALE','UNKNOWN'])),
    CONSTRAINT deceased_age_ck CHECK (age_when_died IS NULL OR age_when_died BETWEEN 0 AND 130),
    CONSTRAINT deceased_date_of_death_not_future_ck CHECK (date_of_death IS NULL OR date_of_death <= CURRENT_DATE)
);

CREATE TABLE public.identifier (
    identifier_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name         character varying(150),
    nic_number        character varying(20),
    residing_address  character varying(255),
    deceased_id       bigint NOT NULL,
    created_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT identifier_deceased_fk FOREIGN KEY (deceased_id) REFERENCES public.deceased(deceased_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT identifier_nic_format_ck CHECK (nic_number IS NULL OR nic_number ~* '^([0-9]{9}[VXvx]|[0-9]{12})$')
);

CREATE TABLE public.patient (
    patient_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    address        character varying(255),
    consent_given  boolean NOT NULL DEFAULT false,     -- PDPA Art. consent basis for processing special-category health data
    consent_date   timestamptz,
    date_of_birth  date,
    full_name      character varying(150) NOT NULL,
    nic_no         character varying(20),
    passport_no    character varying(20),
    sex            character varying(10) NOT NULL DEFAULT 'UNKNOWN',
    is_deleted     boolean NOT NULL DEFAULT false,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT patient_sex_check CHECK (sex = ANY (ARRAY['MALE','FEMALE','UNKNOWN'])),
    CONSTRAINT patient_dob_not_future_ck CHECK (date_of_birth IS NULL OR date_of_birth <= CURRENT_DATE),
    CONSTRAINT patient_nic_format_ck CHECK (nic_no IS NULL OR nic_no ~* '^([0-9]{9}[VXvx]|[0-9]{12})$'),
    CONSTRAINT patient_identity_present_ck CHECK (nic_no IS NOT NULL OR passport_no IS NOT NULL)
);

CREATE TABLE public.inquest_order (
    inquest_number             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    case_no                    character varying(50),
    court                      character varying(150),
    date_of_inquest            date,
    inquirer_designation       character varying(100),
    inquirer_full_name         character varying(150),
    inquirer_into_sudden_deaths boolean NOT NULL DEFAULT false,
    magistrate                 character varying(150),
    police_officer_incharge    character varying(150),
    police_station_area        character varying(150),
    deceased_id                bigint,
    created_at                 timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT inquest_order_deceased_uk UNIQUE (deceased_id),
    CONSTRAINT inquest_order_deceased_fk FOREIGN KEY (deceased_id) REFERENCES public.deceased(deceased_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT inquest_order_date_not_future_ck CHECK (date_of_inquest IS NULL OR date_of_inquest <= CURRENT_DATE)
);

-- ============================================================================
-- SECTION C - POST MORTEM / AUTOPSY
-- ============================================================================

CREATE TABLE public.post_mortem (
    pm_serial_no        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_time_of_pm_exam timestamptz,
    district             character varying(100),
    place_of_examination character varying(150),
    specimens_retained   boolean NOT NULL DEFAULT false,
    under_investigation  boolean NOT NULL DEFAULT true,
    deceased_id          bigint,
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT post_mortem_deceased_fk FOREIGN KEY (deceased_id) REFERENCES public.deceased(deceased_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT post_mortem_exam_not_future_ck CHECK (date_time_of_pm_exam IS NULL OR date_time_of_pm_exam <= now())
);

CREATE TABLE public.pm_medical_officer (
    pm_serial_no bigint NOT NULL,
    officer_id   bigint NOT NULL,
    assigned_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pm_medical_officer_pkey PRIMARY KEY (pm_serial_no, officer_id),
    CONSTRAINT pm_medical_officer_pm_fk FOREIGN KEY (pm_serial_no) REFERENCES public.post_mortem(pm_serial_no) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT pm_medical_officer_officer_fk FOREIGN KEY (officer_id) REFERENCES public.medical_officer(officer_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.autopsy_exam (
    autopsy_id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    autopsy_report_pdf      character varying(255),
    health1135a_doc         character varying(255),
    maternal_death_category character varying(100),
    under_investigation     boolean NOT NULL DEFAULT true,
    pm_serial_no            bigint NOT NULL,
    is_deleted              boolean NOT NULL DEFAULT false,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT autopsy_exam_pm_uk UNIQUE (pm_serial_no),
    CONSTRAINT autopsy_exam_pm_fk FOREIGN KEY (pm_serial_no) REFERENCES public.post_mortem(pm_serial_no) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.autopsy_cause_of_death (
    autopsy_id                     bigint NOT NULL,
    aproxtfrom_onset_to_death      character varying(100),
    cause_description              character varying(500) NOT NULL,
    severity                       character varying(30),
    seq_no                         smallint NOT NULL DEFAULT 1, -- allows ordered multi-cause chains (Ia/Ib/Ic/II)
    CONSTRAINT autopsy_cause_of_death_pkey PRIMARY KEY (autopsy_id, seq_no),
    CONSTRAINT autopsy_cause_of_death_autopsy_fk FOREIGN KEY (autopsy_id) REFERENCES public.autopsy_exam(autopsy_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT autopsy_cause_of_death_severity_ck CHECK (severity IS NULL OR severity = ANY (ARRAY['IMMEDIATE','ANTECEDENT','UNDERLYING','CONTRIBUTORY']))
);

CREATE TABLE public.autopsy_comment (
    autopsy_id bigint NOT NULL,
    comment    character varying(1000) NOT NULL,
    comment_seq smallint GENERATED ALWAYS AS IDENTITY,
    commented_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT autopsy_comment_pkey PRIMARY KEY (autopsy_id, comment_seq),
    CONSTRAINT autopsy_comment_autopsy_fk FOREIGN KEY (autopsy_id) REFERENCES public.autopsy_exam(autopsy_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE public.pre_autopsy_information (
    record_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    information_category character varying(100),
    record_details       character varying(1000),
    pm_serial_no          bigint NOT NULL,
    created_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pre_autopsy_information_pm_fk FOREIGN KEY (pm_serial_no) REFERENCES public.post_mortem(pm_serial_no) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ============================================================================
-- SECTION D - INJURIES
-- ============================================================================

CREATE TABLE public.individual_injury (
    injury_id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    auto_seq_number             character varying(20),
    category_of_hurt            character varying(20),
    detailed_description        character varying(1000),
    diagram_tag_label           character varying(50),
    explanatory_remarks         character varying(1000),
    injury_class                character varying(50),
    injury_to_course_of_death   character varying(255),
    nature_of_bodily_harm       character varying(30),
    penal_code_section          character varying(50),
    remarks                     character varying(500),
    specific_weapon_name        character varying(100),
    weapon_category              character varying(30),
    mlef_id                     bigint NOT NULL,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT individual_injury_category_of_hurt_check CHECK (category_of_hurt IS NULL OR category_of_hurt = ANY (ARRAY['NON_GRIEVOUS','GRIEVOUS'])),
    CONSTRAINT individual_injury_nature_of_bodily_harm_check CHECK (nature_of_bodily_harm IS NULL OR nature_of_bodily_harm = ANY (ARRAY[
        'ABRASION','CONTUSION','LACERATION','CUT','FRACTURE','STAB','BITE','DISLOCATION_SUBLUXATION',
        'FIREARM_INJURY','BURNS','EXPLOSIVE_INJURY','INTERNAL_INJURY','NONE','OTHER'])),
    CONSTRAINT individual_injury_weapon_category_check CHECK (weapon_category IS NULL OR weapon_category = ANY (ARRAY[
        'BLUNT','SHARP','FIREARM','EXPLOSIVE_DEVICE','OTHER']))
    -- mlef_id FK added later in Section F once mlef_record exists (forward reference)
);

-- ============================================================================
-- SECTION E - CLINICAL INVESTIGATIONS
-- ============================================================================

CREATE TABLE public.investigation (
    investigation_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    description        character varying(500),
    findings            character varying(1000),
    investigation_date  date,
    result               character varying(500),
    type                 character varying(30) NOT NULL,
    injury_id            bigint,
    pm_serial_no         bigint,
    created_at            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT investigation_type_ck CHECK (type = ANY (ARRAY['BLOOD','CT_SCAN','HISTOLOGY','X_RAY'])),
    CONSTRAINT investigation_date_not_future_ck CHECK (investigation_date IS NULL OR investigation_date <= CURRENT_DATE),
    CONSTRAINT investigation_injury_fk FOREIGN KEY (injury_id) REFERENCES public.individual_injury(injury_id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT investigation_pm_fk FOREIGN KEY (pm_serial_no) REFERENCES public.post_mortem(pm_serial_no) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.blood_investigation (
    investigation_id bigint PRIMARY KEY,
    CONSTRAINT blood_investigation_fk FOREIGN KEY (investigation_id) REFERENCES public.investigation(investigation_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE public.ct_scan (
    investigation_id bigint PRIMARY KEY,
    CONSTRAINT ct_scan_fk FOREIGN KEY (investigation_id) REFERENCES public.investigation(investigation_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE public.histology (
    investigation_id bigint PRIMARY KEY,
    CONSTRAINT histology_fk FOREIGN KEY (investigation_id) REFERENCES public.investigation(investigation_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE public.x_ray (
    investigation_id bigint PRIMARY KEY,
    CONSTRAINT x_ray_fk FOREIGN KEY (investigation_id) REFERENCES public.investigation(investigation_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================================
-- SECTION F - MEDICO-LEGAL EXAMINATION FORM (MLEF) / CLINICAL FORENSIC
-- ============================================================================

CREATE TABLE public.mlef_record (
    mlef_id                        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    alcohol_influence               character varying(30),
    breathing_smell_intensity       character varying(50),
    date_admitted                    date,
    date_discharged                  date,
    date_time_examined               timestamptz,
    drug_consumed                    boolean NOT NULL DEFAULT false,
    drug_influence                   character varying(30),
    hospital_bht_no                  character varying(50),
    hospital_name                    character varying(150),
    hospital_ward                    character varying(30),
    injury_abrasion       boolean NOT NULL DEFAULT false,
    injury_bite            boolean NOT NULL DEFAULT false,
    injury_burns           boolean NOT NULL DEFAULT false,
    injury_contusion       boolean NOT NULL DEFAULT false,
    injury_cut              boolean NOT NULL DEFAULT false,
    injury_dislocation      boolean NOT NULL DEFAULT false,
    injury_explosive        boolean NOT NULL DEFAULT false,
    injury_firearm           boolean NOT NULL DEFAULT false,
    injury_fracture          boolean NOT NULL DEFAULT false,
    injury_laceration        boolean NOT NULL DEFAULT false,
    injury_none               boolean NOT NULL DEFAULT false,
    injury_stab                boolean NOT NULL DEFAULT false,
    internal_injuries          boolean NOT NULL DEFAULT false,
    other_opinions_recommendations character varying(1000),
    others_nature_of_harm            character varying(255),
    place_examined                   character varying(150),
    police_date_of_issue             date,
    police_ref_no                    character varying(50),
    reason_for_referral               character varying(500),
    remarks                            character varying(1000),
    sexual_assault_brief_history      character varying(1000),
    short_history_given_by_patient    character varying(1000),
    signs_anal_penetration             boolean NOT NULL DEFAULT false,
    signs_inter_labial_penetration     boolean NOT NULL DEFAULT false,
    signs_vaginal_hymen_penetration    boolean NOT NULL DEFAULT false,
    time_admitted                       time(0) without time zone,
    medical_officer_id                  bigint,
    brought_by_officer_id               bigint,
    patient_id                          bigint,
    is_deleted                          boolean NOT NULL DEFAULT false,
    created_at                          timestamptz NOT NULL DEFAULT now(),
    updated_at                          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT mlef_record_alcohol_influence_check CHECK (alcohol_influence IS NULL OR alcohol_influence = ANY (ARRAY['CONSUMED_SMELLING','UNDER_INFLUENCE','NEGATIVE'])),
    CONSTRAINT mlef_record_drug_influence_check CHECK (drug_influence IS NULL OR drug_influence = ANY (ARRAY['CONSUMED_SMELLING','UNDER_INFLUENCE','NEGATIVE'])),
    CONSTRAINT mlef_record_dates_not_future_ck CHECK (
        (date_admitted IS NULL OR date_admitted <= CURRENT_DATE) AND
        (date_discharged IS NULL OR date_discharged <= CURRENT_DATE) AND
        (date_time_examined IS NULL OR date_time_examined <= now())
    ),
    CONSTRAINT mlef_record_discharge_after_admit_ck CHECK (date_discharged IS NULL OR date_admitted IS NULL OR date_discharged >= date_admitted),
    CONSTRAINT mlef_record_medical_officer_fk FOREIGN KEY (medical_officer_id) REFERENCES public.medical_officer(officer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT mlef_record_brought_by_officer_fk FOREIGN KEY (brought_by_officer_id) REFERENCES public.police_officer(officer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT mlef_record_patient_fk FOREIGN KEY (patient_id) REFERENCES public.patient(patient_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- forward-reference FK from Section D now that mlef_record exists
ALTER TABLE public.individual_injury
    ADD CONSTRAINT individual_injury_mlef_fk FOREIGN KEY (mlef_id) REFERENCES public.mlef_record(mlef_id) ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE public.referral (
    ref_id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    referral_reason            character varying(500),
    referred_to_consultant      character varying(150),
    report_received_back        boolean NOT NULL DEFAULT false,
    specialty                    character varying(100),
    mlef_id                      bigint NOT NULL,
    created_at                    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT referral_mlef_fk FOREIGN KEY (mlef_id) REFERENCES public.mlef_record(mlef_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- ============================================================================
-- SECTION G - SAMPLES & CHAIN OF CUSTODY
-- ============================================================================

CREATE TABLE public.forensic_sample (
    sample_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    collected_by          character varying(150),
    collection_date        date,
    number_of_tissues       integer,
    organ_source             character varying(150),
    production_number         character varying(50),
    referred_institution       character varying(150),
    specimen_type               character varying(30) NOT NULL,
    autopsy_id                   bigint,
    mlef_id                       bigint,
    is_deleted                    boolean NOT NULL DEFAULT false,
    created_at                     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT forensic_sample_specimen_type_check CHECK (specimen_type = ANY (ARRAY[
        'BLOOD','LIVER','URINE','BILE','KIDNEY','SUSPECTED_POISON','TABLETS_MEDICINES','LUNGS',
        'STOMACH_CONTENTS','VITREOUS_HUMOR','INTESTINAL_CONTENTS','BRAIN','OTHER'])),
    CONSTRAINT forensic_sample_tissue_count_ck CHECK (number_of_tissues IS NULL OR number_of_tissues >= 0),
    CONSTRAINT forensic_sample_collection_not_future_ck CHECK (collection_date IS NULL OR collection_date <= CURRENT_DATE),
    CONSTRAINT forensic_sample_source_present_ck CHECK (autopsy_id IS NOT NULL OR mlef_id IS NOT NULL),
    CONSTRAINT forensic_sample_autopsy_fk FOREIGN KEY (autopsy_id) REFERENCES public.autopsy_exam(autopsy_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT forensic_sample_mlef_fk FOREIGN KEY (mlef_id) REFERENCES public.mlef_record(mlef_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.chain_of_custody (
    custody_id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    accepted_by_name        character varying(150),
    accepted_date             date,
    delivered_by_name          character varying(150) NOT NULL,
    delivered_by_nic             character varying(20),
    delivered_by_occupation        character varying(100),
    delivery_date                    date NOT NULL,
    delivery_time                      time(0) without time zone,
    jmo_signature_status                boolean NOT NULL DEFAULT false,
    sample_id                            bigint NOT NULL,
    created_at                            timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chain_of_custody_sample_fk FOREIGN KEY (sample_id) REFERENCES public.forensic_sample(sample_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chain_of_custody_nic_format_ck CHECK (delivered_by_nic IS NULL OR delivered_by_nic ~* '^([0-9]{9}[VXvx]|[0-9]{12})$'),
    CONSTRAINT chain_of_custody_dates_ck CHECK (
        delivery_date <= CURRENT_DATE AND (accepted_date IS NULL OR accepted_date >= delivery_date)
    )
);

-- ============================================================================
-- SECTION H - LABORATORY REQUESTS
-- ============================================================================

CREATE TABLE public.laboratory_request (
    request_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    register_id  bigint,
    request_type  character varying(20) NOT NULL DEFAULT 'ROUTINE',
    requested_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT laboratory_request_type_ck CHECK (request_type = ANY (ARRAY['HISTOPATHOLOGY','TOXICOLOGY'])),
    CONSTRAINT laboratory_request_register_fk FOREIGN KEY (register_id) REFERENCES public.case_register(register_id) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.histopathology_request (
    diagnosis                    character varying(500),
    macroscopic_appearances       character varying(1000),
    microscopic_appearance         character varying(1000),
    probable_cause_of_death         character varying(500),
    request_type                     character varying(20),
    special_procedure_request          character varying(255),
    request_id                          bigint PRIMARY KEY,
    CONSTRAINT histopathology_request_request_type_check CHECK (request_type IS NULL OR request_type = ANY (ARRAY['URGENT','ROUTINE','STORAGE','JUDICIAL','ACADEMIC'])),
    CONSTRAINT histopathology_request_fk FOREIGN KEY (request_id) REFERENCES public.laboratory_request(request_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE public.toxicology_request (
    analysis_required   character varying(500),
    medical_history       character varying(1000),
    mode_of_poisoning       character varying(30),
    request_id                bigint PRIMARY KEY,
    CONSTRAINT toxicology_request_mode_of_poisoning_check CHECK (mode_of_poisoning IS NULL OR mode_of_poisoning = ANY (ARRAY['HOMICIDE','SUICIDE','FATAL_ACCIDENT','DUI','ACCIDENTAL','OTHER'])),
    CONSTRAINT toxicology_request_fk FOREIGN KEY (request_id) REFERENCES public.laboratory_request(request_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================================
-- SECTION I - MEDIA (photographs, diagrams, transcripts)
-- ============================================================================

CREATE TABLE public.media_asset (
    media_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    file_name     character varying(255) NOT NULL,
    file_path      character varying(500) NOT NULL,
    type            character varying(30) NOT NULL,
    checksum_sha256  character varying(64),          -- integrity/tamper-evidence for exhibits
    mlef_id           bigint,
    pm_serial_no       bigint,
    created_at           timestamptz NOT NULL DEFAULT now(),
    created_by            bigint,
    CONSTRAINT media_asset_type_ck CHECK (type = ANY (ARRAY[
        'CASE_PHOTOGRAPH','CRIME_PHOTO','PM_PHOTO','BODY_DIAGRAM_CHART','AUDIO_TRANSCRIPT'])),
    CONSTRAINT media_asset_link_present_ck CHECK (mlef_id IS NOT NULL OR pm_serial_no IS NOT NULL),
    CONSTRAINT media_asset_checksum_format_ck CHECK (checksum_sha256 IS NULL OR checksum_sha256 ~* '^[0-9a-f]{64}$'),
    CONSTRAINT media_asset_mlef_fk FOREIGN KEY (mlef_id) REFERENCES public.mlef_record(mlef_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT media_asset_pm_fk FOREIGN KEY (pm_serial_no) REFERENCES public.post_mortem(pm_serial_no) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT media_asset_created_by_fk FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE public.photograph (
    caption      character varying(255),
    capture_date  date,
    description    character varying(500),
    media_id        bigint PRIMARY KEY,
    CONSTRAINT photograph_media_fk FOREIGN KEY (media_id) REFERENCES public.media_asset(media_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT photograph_capture_not_future_ck CHECK (capture_date IS NULL OR capture_date <= CURRENT_DATE)
);

CREATE TABLE public.case_photograph (
    media_id bigint PRIMARY KEY,
    CONSTRAINT case_photograph_fk FOREIGN KEY (media_id) REFERENCES public.photograph(media_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE public.crime_photo (
    media_id bigint PRIMARY KEY,
    CONSTRAINT crime_photo_fk FOREIGN KEY (media_id) REFERENCES public.photograph(media_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE public.pm_photo (
    media_id bigint PRIMARY KEY,
    CONSTRAINT pm_photo_fk FOREIGN KEY (media_id) REFERENCES public.photograph(media_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE public.body_diagram_chart (
    diagram_type character varying(100),
    media_id      bigint PRIMARY KEY,
    CONSTRAINT body_diagram_chart_fk FOREIGN KEY (media_id) REFERENCES public.media_asset(media_id) ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE TABLE public.audio_transcript (
    transcript_text character varying(4000),
    media_id          bigint PRIMARY KEY,
    CONSTRAINT audio_transcript_fk FOREIGN KEY (media_id) REFERENCES public.media_asset(media_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- ============================================================================
-- SECTION J - MEDICO-LEGAL REPORTS
-- ============================================================================

CREATE TABLE public.forensic_report (
    id                        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    amendment_reason           text,
    case_type                   character varying(50),
    court_case_no                 character varying(50),
    court_name                     character varying(150),
    created_at                      timestamptz NOT NULL DEFAULT now(),
    date_of_trial                     date,
    details_json                       jsonb,
    dispatched_date                     timestamptz,
    doctor_designation                    character varying(100),
    doctor_name                             character varying(150),
    doctor_slmc_no                            character varying(20),
    draft_date                                  timestamptz,
    examination_date                              timestamptz,
    finalized_date                                  timestamptz,
    opinion                                           text,
    parent_report_id                                    bigint,      -- amendment/versioning chain
    police_ref_no                                        character varying(50),
    police_station                                        character varying(150),
    receipt_confirmed_date                                 timestamptz,
    report_type                                              character varying(30) NOT NULL,
    serial_no                                                 character varying(50),
    status                                                      character varying(20) NOT NULL DEFAULT 'DRAFT',
    updated_at                                                    timestamptz NOT NULL DEFAULT now(),
    version_number                                                  integer NOT NULL DEFAULT 1,
    mlef_id                                                           bigint,
    pm_serial_no                                                       bigint,
    is_deleted                                                          boolean NOT NULL DEFAULT false,
    CONSTRAINT forensic_report_report_type_check CHECK (report_type = ANY (ARRAY['MLR','MLEF','PMR','CERTIFICATE_OF_RECEIPT'])),
    CONSTRAINT forensic_report_status_check CHECK (status = ANY (ARRAY['DRAFT','FINALIZED','DISPATCHED','RECEIPT_CONFIRMED'])),
    CONSTRAINT forensic_report_version_ck CHECK (version_number >= 1),
    CONSTRAINT forensic_report_source_present_ck CHECK (mlef_id IS NOT NULL OR pm_serial_no IS NOT NULL),
    CONSTRAINT forensic_report_date_order_ck CHECK (
        (finalized_date IS NULL OR draft_date IS NULL OR finalized_date >= draft_date) AND
        (dispatched_date IS NULL OR finalized_date IS NULL OR dispatched_date >= finalized_date) AND
        (receipt_confirmed_date IS NULL OR dispatched_date IS NULL OR receipt_confirmed_date >= dispatched_date)
    ),
    CONSTRAINT forensic_report_parent_fk FOREIGN KEY (parent_report_id) REFERENCES public.forensic_report(id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT forensic_report_mlef_fk FOREIGN KEY (mlef_id) REFERENCES public.mlef_record(mlef_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT forensic_report_pm_fk FOREIGN KEY (pm_serial_no) REFERENCES public.post_mortem(pm_serial_no) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.mlr_report (
    mlr_id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    compatibility_verdict      character varying(255),
    consider_self_infliction     boolean NOT NULL DEFAULT false,
    court_case_no                  character varying(50),
    court_name                       character varying(150),
    date_of_issue                      date,
    date_of_trial                        date,
    date_report_dispatched                 date,
    police_station                           character varying(150),
    received_by_court_date                     date,
    serial_no                                    character varying(50),
    mlef_id                                        bigint,
    CONSTRAINT mlr_report_mlef_uk UNIQUE (mlef_id),
    CONSTRAINT mlr_report_mlef_fk FOREIGN KEY (mlef_id) REFERENCES public.mlef_record(mlef_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT mlr_report_date_order_ck CHECK (
        (date_report_dispatched IS NULL OR date_of_issue IS NULL OR date_report_dispatched >= date_of_issue) AND
        (received_by_court_date IS NULL OR date_report_dispatched IS NULL OR received_by_court_date >= date_report_dispatched)
    )
);

-- ============================================================================
-- SECTION K - COURT WORKFLOW
-- ============================================================================

CREATE TABLE public.court_request (
    request_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    date_and_time    timestamptz NOT NULL DEFAULT now(),
    pm_serial_no       bigint,
    CONSTRAINT court_request_pm_fk FOREIGN KEY (pm_serial_no) REFERENCES public.post_mortem(pm_serial_no) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE public.court_summon (
    case_no      character varying(50),
    court         character varying(150) NOT NULL,
    request_id     bigint PRIMARY KEY,
    CONSTRAINT court_summon_fk FOREIGN KEY (request_id) REFERENCES public.court_request(request_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE public.report_req (
    certificate_of_receipt character varying(50),
    report_sent_date         date,
    required_date              date,
    request_id                   bigint PRIMARY KEY,
    CONSTRAINT report_req_fk FOREIGN KEY (request_id) REFERENCES public.court_request(request_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT report_req_sent_not_future_ck CHECK (report_sent_date IS NULL OR report_sent_date <= CURRENT_DATE)
);
