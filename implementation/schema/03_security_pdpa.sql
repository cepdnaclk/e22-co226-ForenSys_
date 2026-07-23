-- ============================================================================
-- 03_security_pdpa.sql
-- Security & Personal Data Protection Act No. 9 of 2022 (PDPA) compliance
-- ============================================================================
-- PDPA obligations addressed here:
--   * Lawful basis & consent (s.5-9)         -> patient.consent_given/consent_date,
--                                                 consent_log table below
--   * Data minimisation / purpose limitation  -> RBAC + RLS in 06_rbac_privileges.sql
--   * Security safeguards (s.24-25)           -> column encryption for identity
--                                                 numbers, hashed audit trail,
--                                                 TLS/pg_hba guidance (see README)
--   * Accountability & record-keeping (s.23)  -> audit_log table + triggers
--   * Data subject rights (s.14-19: access,    -> dsar_request table +
--     rectification, erasure, restriction)         sp_handle_erasure_request()
--   * Breach notification duty (s.29)          -> security_incident table
--   * Retention limitation (s.10)               -> data_retention_policy table
--                                                    + scheduled anonymisation job
-- ============================================================================

-- ---------------------------------------------------------------------------
-- A. Column-level encryption for high-sensitivity identifiers
-- ---------------------------------------------------------------------------
-- Rationale: NIC numbers, passport numbers and residential addresses are
-- direct identifiers of living or recently-deceased individuals and their
-- relatives (next of kin). They are encrypted at rest using pgcrypto
-- symmetric encryption. The encryption key is NEVER stored in the database;
-- it is supplied by the application at query time via the session GUC
-- `app.pii_key`, itself sourced from a secrets manager / HSM, not from a
-- config file checked into source control.
--
--   SET app.pii_key = '<key from secrets manager>';   -- once per connection
--   SELECT pii_encrypt('952345678V');                  -- write path
--   SELECT pii_decrypt(nic_number_enc) FROM identifier; -- read path (authorised roles only)
--
-- Existing plaintext columns (nic_number, nic_no, passport_no, last_address,
-- residing_address, delivered_by_nic) are retained for backward
-- compatibility with the DDL in 01_schema.sql but should be migrated to the
-- *_enc bytea columns added below and then dropped in a follow-up migration
-- once the application has been updated to call pii_encrypt/pii_decrypt.

CREATE OR REPLACE FUNCTION public.pii_encrypt(p_plaintext text)
RETURNS bytea
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_plaintext IS NULL THEN
        RETURN NULL;
    END IF;
    IF current_setting('app.pii_key', true) IS NULL OR current_setting('app.pii_key', true) = '' THEN
        RAISE EXCEPTION 'app.pii_key session variable is not set - refusing to encrypt PII';
    END IF;
    RETURN pgp_sym_encrypt(p_plaintext, current_setting('app.pii_key'));
END;
$$;

CREATE OR REPLACE FUNCTION public.pii_decrypt(p_ciphertext bytea)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF p_ciphertext IS NULL THEN
        RETURN NULL;
    END IF;
    IF current_setting('app.pii_key', true) IS NULL OR current_setting('app.pii_key', true) = '' THEN
        RAISE EXCEPTION 'app.pii_key session variable is not set - refusing to decrypt PII';
    END IF;
    RETURN pgp_sym_decrypt(p_ciphertext, current_setting('app.pii_key'));
END;
$$;

REVOKE ALL ON FUNCTION public.pii_encrypt(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pii_decrypt(bytea) FROM PUBLIC;

-- Encrypted columns alongside the plaintext ones for migration purposes.
ALTER TABLE public.identifier      ADD COLUMN nic_number_enc      bytea;
ALTER TABLE public.patient         ADD COLUMN nic_no_enc          bytea;
ALTER TABLE public.patient         ADD COLUMN passport_no_enc     bytea;
ALTER TABLE public.chain_of_custody ADD COLUMN delivered_by_nic_enc bytea;

-- One-way hash (not reversible) used for equality search / deduplication
-- without decrypting - avoids ever pulling plaintext NIC into a WHERE clause.
CREATE OR REPLACE FUNCTION public.pii_search_hash(p_plaintext text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT encode(digest(lower(trim(p_plaintext)), 'sha256'), 'hex');
$$;

ALTER TABLE public.identifier ADD COLUMN nic_number_hash text;
CREATE INDEX idx_identifier_nic_hash ON public.identifier (nic_number_hash);

-- ---------------------------------------------------------------------------
-- B. Session context helpers (read by Row-Level Security policies)
-- ---------------------------------------------------------------------------
-- The application, immediately after authenticating a user and resolving
-- their role from users/user_roles/role, must run:
--   SELECT set_config('app.current_user_id', '<user_id>', false);
--   SELECT set_config('app.current_role', '<ROLE_NAME>', false);
-- for the lifetime of that logical session (per-transaction in a pooled
-- connection via SET LOCAL, or per-session otherwise).

CREATE OR REPLACE FUNCTION public.app_current_user_id() RETURNS bigint
LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::bigint;
$$;

CREATE OR REPLACE FUNCTION public.app_current_role() RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('app.current_role', true), '');
$$;

-- ---------------------------------------------------------------------------
-- C. Audit trail (PDPA accountability, s.23) - append-only, tamper-evident
-- ---------------------------------------------------------------------------
CREATE TABLE public.audit_log (
    audit_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name    text NOT NULL,
    row_pk        text NOT NULL,
    operation     character varying(10) NOT NULL,
    changed_by_user_id bigint,
    changed_by_role    text,
    changed_at         timestamptz NOT NULL DEFAULT now(),
    old_data           jsonb,
    new_data           jsonb,
    client_addr        inet,
    row_hash            text,   -- sha256(prev_row_hash || new_data) - tamper-evidence chain
    CONSTRAINT audit_log_operation_ck CHECK (operation = ANY (ARRAY['INSERT','UPDATE','DELETE'])),
    CONSTRAINT audit_log_changed_by_fk FOREIGN KEY (changed_by_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_audit_log_table_row ON public.audit_log (table_name, row_pk);
CREATE INDEX idx_audit_log_changed_at ON public.audit_log (changed_at);
CREATE INDEX idx_audit_log_changed_by ON public.audit_log (changed_by_user_id);
COMMENT ON TABLE public.audit_log IS
    'Append-only audit trail. INSERT-only privileges are granted to application
     roles; UPDATE/DELETE are revoked from everyone (enforced in 06) so the log
     cannot be altered even by an attacker with an app_service credential.';

-- Every SELECT against a table containing personal data is also logged, for
-- PDPA accountability on the read side (who viewed whose forensic record).
CREATE TABLE public.data_access_log (
    access_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    accessed_table text NOT NULL,
    accessed_pk    text,
    accessed_by_user_id bigint,
    accessed_by_role    text,
    access_reason        text,     -- free-text justification captured by the app UI
    accessed_at            timestamptz NOT NULL DEFAULT now(),
    client_addr              inet,
    CONSTRAINT data_access_log_user_fk FOREIGN KEY (accessed_by_user_id) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);
CREATE INDEX idx_data_access_log_table ON public.data_access_log (accessed_table, accessed_at);

-- ---------------------------------------------------------------------------
-- D. Consent register (PDPA s.5-9)
-- ---------------------------------------------------------------------------
CREATE TABLE public.consent_log (
    consent_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id      bigint,
    deceased_id       bigint,   -- for next-of-kin consent regarding a deceased subject
    consent_type        character varying(50) NOT NULL,
    consent_given          boolean NOT NULL,
    consent_text_version      character varying(20),
    recorded_by                bigint,
    recorded_at                  timestamptz NOT NULL DEFAULT now(),
    withdrawn_at                  timestamptz,
    CONSTRAINT consent_log_subject_present_ck CHECK (patient_id IS NOT NULL OR deceased_id IS NOT NULL),
    CONSTRAINT consent_log_type_ck CHECK (consent_type = ANY (ARRAY['EXAMINATION','SAMPLE_RETENTION','DATA_SHARING_WITH_COURT','RESEARCH_USE','OTHER'])),
    CONSTRAINT consent_log_patient_fk FOREIGN KEY (patient_id) REFERENCES public.patient(patient_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT consent_log_deceased_fk FOREIGN KEY (deceased_id) REFERENCES public.deceased(deceased_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT consent_log_recorded_by_fk FOREIGN KEY (recorded_by) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- ---------------------------------------------------------------------------
-- E. Data Subject Access / Rectification / Erasure Requests (PDPA s.14-19)
-- ---------------------------------------------------------------------------
CREATE TABLE public.dsar_request (
    dsar_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_name      character varying(150) NOT NULL,
    requester_nic_hash    text,             -- hashed, never store the requester's plaintext NIC bare
    request_type            character varying(30) NOT NULL,
    subject_patient_id         bigint,
    subject_deceased_id           bigint,
    status                          character varying(20) NOT NULL DEFAULT 'RECEIVED',
    received_at                       timestamptz NOT NULL DEFAULT now(),
    due_at                              timestamptz NOT NULL DEFAULT (now() + INTERVAL '14 days'), -- statutory response window
    resolved_at                           timestamptz,
    resolution_notes                        text,
    handled_by                                bigint,
    CONSTRAINT dsar_request_type_ck CHECK (request_type = ANY (ARRAY['ACCESS','RECTIFICATION','ERASURE','RESTRICTION','OBJECTION','PORTABILITY'])),
    CONSTRAINT dsar_request_status_ck CHECK (status = ANY (ARRAY['RECEIVED','IN_PROGRESS','PARTIALLY_FULFILLED','REJECTED_STATUTORY_RETENTION','COMPLETED'])),
    CONSTRAINT dsar_request_subject_present_ck CHECK (subject_patient_id IS NOT NULL OR subject_deceased_id IS NOT NULL),
    CONSTRAINT dsar_request_patient_fk FOREIGN KEY (subject_patient_id) REFERENCES public.patient(patient_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT dsar_request_deceased_fk FOREIGN KEY (subject_deceased_id) REFERENCES public.deceased(deceased_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT dsar_request_handled_by_fk FOREIGN KEY (handled_by) REFERENCES public.users(user_id) ON DELETE SET NULL ON UPDATE CASCADE
);
COMMENT ON COLUMN public.dsar_request.status IS
    'REJECTED_STATUTORY_RETENTION is a legitimate outcome under PDPA s.10(2):
     forensic/medico-legal records tied to an open case, an inquest, or within
     the statutory retention period cannot be erased on request; they are
     anonymised instead once retention lapses (see sp_anonymize_deceased/
     sp_anonymize_patient in 04_functions_procedures.sql).';

-- ---------------------------------------------------------------------------
-- F. Retention policy register + security incident log (breach duty, s.29)
-- ---------------------------------------------------------------------------
CREATE TABLE public.data_retention_policy (
    policy_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name       text NOT NULL,
    retention_years    integer NOT NULL,
    legal_basis           text NOT NULL,
    CONSTRAINT data_retention_policy_table_uk UNIQUE (table_name),
    CONSTRAINT data_retention_policy_years_ck CHECK (retention_years > 0)
);
INSERT INTO public.data_retention_policy (table_name, retention_years, legal_basis) VALUES
    ('deceased',        10, 'Coroners/Judicature ordinance - medico-legal case files'),
    ('patient',          6, 'PDPA data-minimisation default for clinical-forensic records without ongoing litigation'),
    ('forensic_report', 10, 'Court-evidentiary document retention'),
    ('mlr_report',      10, 'Court-evidentiary document retention'),
    ('chain_of_custody',10, 'Evidentiary chain-of-custody integrity requirement');

CREATE TABLE public.security_incident (
    incident_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    detected_at        timestamptz NOT NULL DEFAULT now(),
    category              character varying(30) NOT NULL,
    description             text NOT NULL,
    affected_data_subjects_estimate integer,
    reported_to_dpo_at         timestamptz,   -- Data Protection Officer
    reported_to_authority_at     timestamptz, -- PDPA s.29 breach notification to the Data Protection Authority
    status                          character varying(20) NOT NULL DEFAULT 'OPEN',
    CONSTRAINT security_incident_category_ck CHECK (category = ANY (ARRAY['UNAUTHORIZED_ACCESS','DATA_LOSS','SYSTEM_COMPROMISE','MISDIRECTED_DISCLOSURE','OTHER'])),
    CONSTRAINT security_incident_status_ck CHECK (status = ANY (ARRAY['OPEN','CONTAINED','NOTIFIED','CLOSED']))
);
