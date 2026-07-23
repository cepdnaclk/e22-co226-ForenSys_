-- ============================================================================
-- 08_backup_recovery.sql
-- Backup / disaster-recovery configuration + helper objects.
-- The actual backup jobs run OUTSIDE the database (cron / systemd timer /
-- your orchestrator), but the pieces below make the department's recovery
-- posture auditable from inside the database itself.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- A. Point-in-time recovery (PITR) prerequisites
-- ---------------------------------------------------------------------------
-- Run these as postgresql.conf settings (require a server restart), not as
-- SQL - included here as the authoritative reference for what "done" means:
--
--   wal_level = replica
--   archive_mode = on
--   archive_command = 'test ! -f /secure/wal_archive/%f && cp %p /secure/wal_archive/%f'
--   archive_timeout = 300                 -- force a WAL switch at least every 5 min
--   max_wal_senders = 3                   -- headroom for a streaming standby
--
-- Nightly full backup + continuous WAL archiving gives PITR to within
-- seconds of any point, which matters here because a chain-of-custody or
-- autopsy record's edit history must be recoverable to the exact moment
-- before an erroneous change, not just to last night's snapshot.
--
--   pg_basebackup -D /secure/base_backup/$(date +%F) -Fp -Xs -P \
--       -h localhost -U replication_user
--
-- Restore drill (run this against a scratch instance at least quarterly and
-- log the result in security_incident/runbook - an untested backup is not a
-- backup):
--   1. restore base backup
--   2. create recovery.signal + restore_command in postgresql.conf
--   3. recovery_target_time = '<the moment just before the incident>'
--   4. start server, confirm data matches expectations, promote

-- ---------------------------------------------------------------------------
-- B. Logical backup helper - one-command consistent dump definition
-- ---------------------------------------------------------------------------
-- Physical (pg_basebackup/WAL) backups protect the whole cluster; logical
-- dumps are kept in parallel for portability, selective table restore, and
-- because pg_dump output can itself be encrypted at rest independent of the
-- database's own disk encryption.
--
--   pg_dump -Fc -h localhost -U role_admin_login forensic_db \
--       | gpg --encrypt --recipient dba-backup-key \
--       > /secure/logical_backups/forensic_db_$(date +%FT%H%M%S).dump.gpg
--
-- Retention: 35 daily, 12 monthly, 7 yearly, mirroring data_retention_policy
-- rather than a single fixed window, since some tables are kept far longer
-- than others.

-- ---------------------------------------------------------------------------
-- C. Encryption at rest (disk-level, complements the pgcrypto column
-- encryption already applied to identity fields in 03_security_pdpa.sql)
-- ---------------------------------------------------------------------------
-- Deploy PostgreSQL's data directory on a LUKS-encrypted (Linux) or
-- equivalent cloud-provider-managed encrypted volume (e.g. AWS EBS/RDS
-- encryption, Azure Disk Encryption). Enforce TLS in transit via
-- postgresql.conf `ssl = on` and require it per-role in pg_hba.conf, e.g.:
--
--   hostssl  forensic_db  +role_medical_officer  10.0.0.0/8  scram-sha-256
--   hostssl  forensic_db  +role_police_officer    10.0.0.0/8  scram-sha-256
--   host     all          all                     0.0.0.0/0   reject
--
-- and set password_encryption = 'scram-sha-256' (never md5) in
-- postgresql.conf.

-- ---------------------------------------------------------------------------
-- D. Backup-completion log - lets the audit_log/security_incident review
-- process confirm backups actually ran, from inside the database.
-- ---------------------------------------------------------------------------
CREATE TABLE public.backup_run_log (
    backup_id     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    backup_type    character varying(20) NOT NULL,
    started_at       timestamptz NOT NULL,
    completed_at       timestamptz,
    status                character varying(20) NOT NULL DEFAULT 'RUNNING',
    destination             text,
    size_bytes                bigint,
    verified_restorable         boolean NOT NULL DEFAULT false,
    verified_at                   timestamptz,
    CONSTRAINT backup_run_log_type_ck CHECK (backup_type = ANY (ARRAY['FULL_PHYSICAL','WAL_ARCHIVE','LOGICAL_DUMP'])),
    CONSTRAINT backup_run_log_status_ck CHECK (status = ANY (ARRAY['RUNNING','SUCCESS','FAILED']))
);
GRANT SELECT ON public.backup_run_log TO role_admin, role_auditor;
GRANT INSERT, UPDATE ON public.backup_run_log TO role_admin;

-- Alert view: has a full physical backup run in the last 25 hours?
CREATE OR REPLACE VIEW public.v_backup_health AS
SELECT
    backup_type,
    max(completed_at) FILTER (WHERE status = 'SUCCESS') AS last_success,
    (max(completed_at) FILTER (WHERE status = 'SUCCESS') < now() - INTERVAL '25 hours') AS is_overdue
FROM public.backup_run_log
GROUP BY backup_type;
GRANT SELECT ON public.v_backup_health TO role_admin, role_auditor;
