-- =====================================================
-- 14_Create_Audit_Trail.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Audit Trail & Change Tracking
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Creating Audit Trail Infrastructure...';
GO

-- =====================================================
-- 1. AUDIT TRAIL TABLE
-- =====================================================

IF OBJECT_ID('dw.audit_trail', 'U') IS NULL
BEGIN
    CREATE TABLE dw.audit_trail (
        audit_id BIGINT IDENTITY(1,1) PRIMARY KEY,
        table_name VARCHAR(100) NOT NULL,
        operation VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
        record_key VARCHAR(255),
        old_values NVARCHAR(MAX), -- JSONB replaced with NVARCHAR(MAX)
        new_values NVARCHAR(MAX), -- JSONB replaced with NVARCHAR(MAX)
        changed_by VARCHAR(100) DEFAULT SUSER_SNAME(), -- CURRENT_USER -> SUSER_SNAME()
        changed_at DATETIME DEFAULT GETDATE(),
        ip_address VARCHAR(45), -- INET -> VARCHAR(45)
        session_id VARCHAR(255)
    );

    CREATE INDEX ix_audit_trail_table ON dw.audit_trail(table_name);
    CREATE INDEX ix_audit_trail_timestamp ON dw.audit_trail(changed_at);
    CREATE INDEX ix_audit_trail_operation ON dw.audit_trail(operation);
    
    PRINT '>> Table dw.audit_trail created.';
END
GO

-- =====================================================
-- 2. AUDIT TRAIL VIEWS
-- =====================================================

CREATE OR ALTER VIEW dw.vw_Audit_Summary AS
SELECT 
    CAST(changed_at AS DATE) as audit_date,
    table_name,
    operation,
    COUNT(*) as change_count,
    COUNT(DISTINCT changed_by) as users_involved
FROM dw.audit_trail
GROUP BY CAST(changed_at AS DATE), table_name, operation
-- ORDER BY not allowed in views without TOP
GO

CREATE OR ALTER VIEW dw.vw_Audit_Detail AS
SELECT 
    audit_id,
    table_name,
    operation,
    changed_at,
    changed_by,
    new_values
FROM dw.audit_trail
WHERE changed_at >= DATEADD(DAY, -30, GETDATE());
GO

-- =====================================================
-- 3. DATA MODIFICATION AUDIT (STORED PROCEDURE)
-- =====================================================

CREATE OR ALTER PROCEDURE dw.usp_LogDataModification
    @p_table_name VARCHAR(100),
    @p_operation VARCHAR(20),
    @p_record_key VARCHAR(255),
    @p_old_values NVARCHAR(MAX) = NULL,
    @p_new_values NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NewAuditId BIGINT;

    INSERT INTO dw.audit_trail (table_name, operation, record_key, old_values, new_values, changed_by)
    VALUES (@p_table_name, @p_operation, @p_record_key, @p_old_values, @p_new_values, SUSER_SNAME());
    
    SET @NewAuditId = SCOPE_IDENTITY();
    
    -- In procedures, we usually don't return scalar values like functions.
    -- We can use OUTPUT parameters if needed, but here we just insert.
END;
GO

-- =====================================================
-- 4. CLEANUP PROCEDURE
-- =====================================================

CREATE OR ALTER PROCEDURE dw.usp_CleanupOldAuditRecords
    @p_days_retention INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_deleted_count INT;

    DELETE FROM dw.audit_trail
    WHERE changed_at < DATEADD(DAY, -@p_days_retention, GETDATE());
    
    SET @v_deleted_count = @@ROWCOUNT;
    
    PRINT 'Deleted ' + CAST(@v_deleted_count AS VARCHAR(20)) + ' audit records older than ' + CAST(@p_days_retention AS VARCHAR(10)) + ' days.';
END;
GO

-- =====================================================
-- 5. AUDIT CONFIGURATION TABLE
-- =====================================================

IF OBJECT_ID('dw.audit_config', 'U') IS NULL
BEGIN
    CREATE TABLE dw.audit_config (
        config_id INT IDENTITY(1,1) PRIMARY KEY,
        table_name VARCHAR(100) NOT NULL UNIQUE,
        audit_enabled BIT DEFAULT 1,
        audit_inserts BIT DEFAULT 1,
        audit_updates BIT DEFAULT 1,
        audit_deletes BIT DEFAULT 1,
        retention_days INT DEFAULT 90,
        created_at DATETIME DEFAULT GETDATE(),
        updated_at DATETIME DEFAULT GETDATE()
    );

    -- Seed audit configuration (Upsert logic)
    -- SQL Server doesn't have ON CONFLICT, use IF NOT EXISTS logic
    
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'dim_waktu') INSERT INTO dw.audit_config (table_name) VALUES ('dim_waktu');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'dim_unit_kerja') INSERT INTO dw.audit_config (table_name) VALUES ('dim_unit_kerja');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'dim_pegawai') INSERT INTO dw.audit_config (table_name) VALUES ('dim_pegawai');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'dim_jenis_surat') INSERT INTO dw.audit_config (table_name) VALUES ('dim_jenis_surat');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'dim_jenis_layanan') INSERT INTO dw.audit_config (table_name) VALUES ('dim_jenis_layanan');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'dim_barang') INSERT INTO dw.audit_config (table_name) VALUES ('dim_barang');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'dim_lokasi') INSERT INTO dw.audit_config (table_name) VALUES ('dim_lokasi');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'fact_surat') INSERT INTO dw.audit_config (table_name) VALUES ('fact_surat');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'fact_layanan') INSERT INTO dw.audit_config (table_name) VALUES ('fact_layanan');
    IF NOT EXISTS (SELECT 1 FROM dw.audit_config WHERE table_name = 'fact_aset') INSERT INTO dw.audit_config (table_name) VALUES ('fact_aset');
    
    PRINT '>> Table dw.audit_config created and seeded.';
END
GO

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

PRINT '>> 14_Create_Audit_Trail.sql executed successfully.';
GO
