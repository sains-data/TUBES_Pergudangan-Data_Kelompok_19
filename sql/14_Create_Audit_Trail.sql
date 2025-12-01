-- =====================================================
-- 14_Create_Audit_Trail.sql
-- POSTGRESQL VERSION
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Audit Trail & Change Tracking
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- AUDIT TRAIL TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS dw.audit_trail (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
    record_key VARCHAR(255),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100) DEFAULT CURRENT_USER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    session_id VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS ix_audit_trail_table ON dw.audit_trail(table_name);
CREATE INDEX IF NOT EXISTS ix_audit_trail_timestamp ON dw.audit_trail(changed_at);
CREATE INDEX IF NOT EXISTS ix_audit_trail_operation ON dw.audit_trail(operation);

-- =====================================================
-- AUDIT TRIGGER FUNCTION
-- =====================================================

CREATE OR REPLACE FUNCTION dw.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO dw.audit_trail (table_name, operation, record_key, new_values, changed_by)
        VALUES (TG_TABLE_NAME, 'INSERT', NEW.*::TEXT, row_to_json(NEW), CURRENT_USER);
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO dw.audit_trail (table_name, operation, record_key, old_values, new_values, changed_by)
        VALUES (TG_TABLE_NAME, 'UPDATE', OLD.*::TEXT, row_to_json(OLD), row_to_json(NEW), CURRENT_USER);
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO dw.audit_trail (table_name, operation, record_key, old_values, changed_by)
        VALUES (TG_TABLE_NAME, 'DELETE', OLD.*::TEXT, row_to_json(OLD), CURRENT_USER);
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- AUDIT TRAIL VIEWS
-- =====================================================

DROP VIEW IF EXISTS dw.vw_audit_summary CASCADE;
CREATE VIEW dw.vw_audit_summary AS
SELECT 
    CAST(changed_at AS DATE) as audit_date,
    table_name,
    operation,
    COUNT(*) as change_count,
    COUNT(DISTINCT changed_by) as users_involved
FROM dw.audit_trail
GROUP BY CAST(changed_at AS DATE), table_name, operation
ORDER BY audit_date DESC, table_name;

DROP VIEW IF EXISTS dw.vw_audit_detail CASCADE;
CREATE VIEW dw.vw_audit_detail AS
SELECT 
    audit_id,
    table_name,
    operation,
    changed_at,
    changed_by,
    new_values
FROM dw.audit_trail
WHERE changed_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY changed_at DESC;

-- =====================================================
-- DATA MODIFICATION AUDIT (STORED PROCEDURES)
-- =====================================================

DROP FUNCTION IF EXISTS dw.log_data_modification(VARCHAR, VARCHAR, VARCHAR, JSONB, JSONB) CASCADE;
CREATE OR REPLACE FUNCTION dw.log_data_modification(
    p_table_name VARCHAR,
    p_operation VARCHAR,
    p_record_key VARCHAR,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_audit_id BIGINT;
BEGIN
    INSERT INTO dw.audit_trail (table_name, operation, record_key, old_values, new_values, changed_by)
    VALUES (p_table_name, p_operation, p_record_key, p_old_values, p_new_values, CURRENT_USER)
    RETURNING audit_id INTO v_audit_id;
    
    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- CLEANUP PROCEDURES
-- =====================================================

DROP FUNCTION IF EXISTS dw.cleanup_old_audit_records(INT) CASCADE;
CREATE OR REPLACE FUNCTION dw.cleanup_old_audit_records(p_days_retention INT DEFAULT 90)
RETURNS INT AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM dw.audit_trail
    WHERE changed_at < CURRENT_DATE - (p_days_retention::TEXT || ' days')::INTERVAL;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'Deleted % audit records older than % days', v_deleted_count, p_days_retention;
    
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- AUDIT CONFIGURATION TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS dw.audit_config (
    config_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL UNIQUE,
    audit_enabled BOOLEAN DEFAULT TRUE,
    audit_inserts BOOLEAN DEFAULT TRUE,
    audit_updates BOOLEAN DEFAULT TRUE,
    audit_deletes BOOLEAN DEFAULT TRUE,
    retention_days INT DEFAULT 90,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed audit configuration
INSERT INTO dw.audit_config (table_name, audit_enabled) VALUES
('dim_waktu', TRUE),
('dim_unit_kerja', TRUE),
('dim_pegawai', TRUE),
('dim_jenis_surat', TRUE),
('dim_jenis_layanan', TRUE),
('dim_barang', TRUE),
('dim_lokasi', TRUE),
('fact_surat', TRUE),
('fact_layanan', TRUE),
('fact_aset', TRUE)
ON CONFLICT (table_name) DO NOTHING;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

SELECT '14_Create_Audit_Trail.sql executed successfully' as status;

-- ====================== END OF FILE ======================
