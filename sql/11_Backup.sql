-- =====================================================
-- 11_Backup.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Backup & Recovery Strategy
-- Engine  : PostgreSQL 14+
-- =====================================================

/*
    NOTE: PostgreSQL backup is done via command-line tools (pg_dump, pg_basebackup).
    This script documents the backup strategy.
    
    BACKUP COMMANDS (run from shell):
    
    1. Full Backup:
    pg_dump -U datamart_user -d datamart_bau_itera -Fc -f backup_full_$(date +%Y%m%d).dump
    
    2. Restore Backup:
    pg_restore -U postgres -d datamart_bau_itera backup_full_20250101.dump
    
    3. Backup entire cluster:
    pg_dumpall -U postgres > backup_all_$(date +%Y%m%d).sql
*/

-- =====================================================
-- BACKUP PROCEDURE (Shell Commands Reference)
-- =====================================================

CREATE TABLE IF NOT EXISTS dw.backup_log (
    backup_id SERIAL PRIMARY KEY,
    backup_type VARCHAR(50),
    backup_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    backup_file VARCHAR(500),
    status VARCHAR(20),
    notes TEXT
);

-- =====================================================
-- FUNCTION: LOG BACKUP EXECUTION
-- =====================================================

DROP FUNCTION IF EXISTS dw.log_backup(VARCHAR, VARCHAR, VARCHAR, TEXT) CASCADE;
CREATE OR REPLACE FUNCTION dw.log_backup(
    p_backup_type VARCHAR,
    p_backup_file VARCHAR,
    p_status VARCHAR,
    p_notes TEXT DEFAULT NULL
) RETURNS INT AS $$
DECLARE
    v_backup_id INT;
BEGIN
    INSERT INTO dw.backup_log (backup_type, backup_file, status, notes)
    VALUES (p_backup_type, p_backup_file, p_status, p_notes)
    RETURNING backup_id INTO v_backup_id;
    
    RETURN v_backup_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- BACKUP VERIFICATION QUERIES
-- =====================================================

-- View backup history
CREATE OR REPLACE VIEW dw.vw_backup_history AS
SELECT 
    backup_id,
    backup_type,
    backup_timestamp,
    backup_file,
    status,
    notes
FROM dw.backup_log
ORDER BY backup_timestamp DESC;

-- =====================================================
-- BACKUP STRATEGY DOCUMENTATION
-- =====================================================

/*
    ===== RECOMMENDED BACKUP STRATEGY FOR POSTGRESQL =====
    
    1. FULL DATABASE BACKUP (Weekly - Sunday)
    -----------------------------------------------
    Command:
    pg_dump -U datamart_user -d datamart_bau_itera -Fc -f /backup/datamart_FULL_$(date +%Y%m%d).dump
    
    Schedule: Weekly (Sunday 02:00 UTC)
    Retention: 4 weeks
    Location: /backup/ directory
    
    2. CONTINUOUS ARCHIVING (Daily)
    -----------------------------------------------
    Configure in postgresql.conf:
    - wal_level = archive
    - archive_mode = on
    - archive_command = 'cp %p /backup/wal_archive/%f'
    
    This enables Point-in-Time Recovery (PITR)
    
    3. RESTORE PROCEDURE
    -----------------------------------------------
    Full Restore:
    pg_restore -U postgres -d datamart_bau_itera -Fc /backup/datamart_FULL_20250101.dump
    
    Point-in-Time Restore (PITR):
    Set recovery_target_timeline, recovery_target_time, etc. in recovery.conf
    
    4. BACKUP TESTING
    -----------------------------------------------
    Always test backups on a separate server:
    createdb test_datamart
    pg_restore -U postgres -d test_datamart -Fc /backup/datamart_FULL_20250101.dump
    SELECT COUNT(*) FROM fact.fact_surat;  -- Verify data
*/

-- =====================================================
-- SAMPLE: RECORD BACKUP COMPLETION
-- =====================================================

-- Example: After manual full backup
-- SELECT dw.log_backup('FULL', '/backup/datamart_FULL_20250128.dump', 'Success', 'Full database backup completed');

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

SELECT 'Backup logging infrastructure created.' as status;
SELECT 'Manual backup commands documented above.' as note1;
SELECT 'See comments for recommended backup strategy.' as note2;

-- ====================== END OF FILE ======================
