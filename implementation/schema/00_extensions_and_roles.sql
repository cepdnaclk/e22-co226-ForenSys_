-- ============================================================================
-- 00_extensions_and_roles.sql
-- Forensic Medical Department Database System
-- Extensions + PostgreSQL server-level roles (defence-in-depth layer)
-- ============================================================================
-- Design note on RBAC:
-- Two layers of access control are implemented:
--   1. APPLICATION-LEVEL RBAC (users/role/permission/role_permissions tables,
--      already present in the source schema) - the app authenticates a person,
--      resolves their role(s), and sets session variables that Row-Level
--      Security policies (07_security_pdpa.sql) read.
--   2. DATABASE-LEVEL RBAC (native PostgreSQL ROLEs created below) - used when
--      services/back-office tools connect directly to Postgres with distinct
--      credentials per function (e.g. a reporting service, a DBA, a nightly
--      batch job). GRANT/REVOKE statements in 06_rbac_privileges.sql attach
--      table-level privileges to these roles.
-- Both layers enforce the same five business roles requested:
--   ADMIN, MEDICAL_OFFICER (JMO), CLERICAL_OFFICER, POLICE_OFFICER, LABORATORY_STAFF
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;      -- column encryption, password hashing, gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pg_stat_statements; -- monitor slow/expensive queries
CREATE EXTENSION IF NOT EXISTS btree_gist;    -- supports exclusion constraints used later

-- ---------------------------------------------------------------------------
-- Database-level group roles (NOLOGIN - credentials are issued per-person via
-- individual LOGIN roles that are then GRANTed membership, e.g.:
--   CREATE ROLE jmo_perera LOGIN PASSWORD '...' IN ROLE role_medical_officer;
-- Never grant application privileges directly to a login role - always via
-- one of these five group roles so that a person's access changes the moment
-- their group membership changes (single point of revocation).
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_admin') THEN
    CREATE ROLE role_admin NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_medical_officer') THEN
    CREATE ROLE role_medical_officer NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_clerical_officer') THEN
    CREATE ROLE role_clerical_officer NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_police_officer') THEN
    CREATE ROLE role_police_officer NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_laboratory_staff') THEN
    CREATE ROLE role_laboratory_staff NOLOGIN;
  END IF;
  -- application service account: the pooled connection the web app itself
  -- uses. It gets minimal, mediated privileges; real authorization happens
  -- through app-level RBAC + RLS, not through this role's own grants.
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_service') THEN
    CREATE ROLE app_service LOGIN PASSWORD 'CHANGE_ME_ROTATE_REGULARLY';
  END IF;
  -- read-only auditor role for compliance/DPO review (PDPA accountability)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'role_auditor') THEN
    CREATE ROLE role_auditor NOLOGIN;
  END IF;
END $$;

-- Lock down the default PUBLIC role - nobody gets anything by default.
REVOKE ALL ON SCHEMA public FROM PUBLIC;
-- Also run, substituting your actual database name (cannot be parameterised
-- inside a plain SQL script): REVOKE ALL ON DATABASE forensic_db FROM PUBLIC;
