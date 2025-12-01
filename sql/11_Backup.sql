-- =====================================================
-- 11_Backup.sql
-- POSTGRESQL VERSION
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Backup & Recovery Strategy
-- Engine  : PostgreSQL 14+
-- =====================================================

/*
    NOTE: PostgreSQL backup is done via command-line tools (pg_dump, pg_basebackup).
    This script documents the backup strategy and creates logging infrastructure.
    
    BACKUP COMMANDS (run from shell):
    
    1. Full Backup:
    pg_dump -U datamart_user -d datamart_bau_itera -Fc -f backup_full_$(date +%Y%m%d).dump
    
    2. Restore Backup:
    pg_restore -U postgres -d datamart_bau_itera backup_full_20250101.dump
    
    3. Backup entire cluster:
    pg_dumpall -U postgres > backup_all_$(date +%Y%m%d).sql
*/

-- =====================================================
-- BACKUP LOGGING TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS dw.backup_log (
    backup_id SERIAL PRIMARY KEY,
    backup_type VARCHAR(50),
    backup_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    backup_file VARCHAR(500),
    status VARCHAR(20),
    notes TEXT
);

CREATE INDEX IF NOT EXISTS ix_backup_log_timestamp ON dw.backup_log(backup_timestamp);

-- =====================================================
-- FUNCTION: LOG BACKUP EXECUTION
-- =====================================================

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
-- BACKUP HISTORY VIEW
-- =====================================================

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
-- SUCCESS MESSAGES
-- =====================================================

SELECT 'Backup logging infrastructure created.' as status;
SELECT 'Manual backup commands documented in comments above.' as note1;
SELECT 'Use: SELECT dw.log_backup(...) to record backup completion.' as note2;

-- ====================== END OF FILE ======================
