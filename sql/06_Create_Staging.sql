-- =====================================================
-- 06_Create_Staging.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Staging Area Validation and Additional Setup
-- Engine  : Microsoft SQL Server 2019+
-- =====================================================

/*
    STAGING AREA OVERVIEW:
    Schema 'stg' and staging tables created in 01_Create_Database.sql
    
    This script provides:
    1. Validation queries
    2. Helper views for monitoring
    3. Sample validation queries for DQ
*/

-- =====================================================
-- SECTION 1: VALIDATION - STAGING SCHEMA & TABLES
-- =====================================================

BEGIN
    DECLARE @table_count INT;
    
    -- Check schema (Schema existence is implicit in SQL Server if tables exist)
    IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
    BEGIN
        PRINT 'WARNING: Schema "stg" does not exist! Please run 01_Create_Database.sql first.';
    END
    ELSE
    BEGIN
        PRINT 'Schema "stg" exists: OK';
    END

    -- Check staging tables
    SELECT @table_count = COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'stg' AND table_type = 'BASE TABLE';

    IF @table_count < 6
    BEGIN
        PRINT 'WARNING: Expected at least 6 staging tables, found: ' + CAST(@table_count AS VARCHAR);
    END
    ELSE
    BEGIN
        PRINT 'Staging tables found: ' + CAST(@table_count AS VARCHAR) + ' tables - OK';
    END
END
GO

-- =====================================================
-- SECTION 2: VERIFY STAGING TABLES STRUCTURE
-- =====================================================

PRINT '======================================================';
PRINT 'STAGING TABLES STRUCTURE VERIFICATION';
PRINT '======================================================';

SELECT 
    t.table_name,
    COUNT(c.column_name) as column_count
FROM information_schema.tables t
LEFT JOIN information_schema.columns c 
    ON t.table_schema = c.table_schema 
    AND t.table_name = c.table_name
WHERE t.table_schema = 'stg'
AND t.table_type = 'BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;
GO

-- =====================================================
-- SECTION 3: VERIFY STAGING INDEXES
-- =====================================================

DECLARE @index_count INT;
SELECT @index_count = COUNT(*)
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'stg';

IF @index_count = 0
    PRINT 'WARNING: No indexes found on staging tables';
ELSE
    PRINT 'Staging indexes found: ' + CAST(@index_count AS VARCHAR) + ' indexes - OK';
GO

-- List indexes
SELECT 
    t.name AS table_name,
    i.name AS index_name
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'stg'
ORDER BY t.name, i.name;
GO

-- =====================================================
-- SECTION 4: ADDITIONAL STAGING UTILITIES
-- =====================================================

-- View for monitoring staging table row counts
IF OBJECT_ID('analytics.vw_staging_row_counts', 'V') IS NOT NULL DROP VIEW analytics.vw_staging_row_counts;
GO

CREATE VIEW analytics.vw_staging_row_counts AS
SELECT 
    'stg_simaster_surat' AS table_name,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END) AS processed_rows,
    SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END) AS pending_rows,
    MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_simaster_surat

UNION ALL

SELECT 
    'stg_inventaris',
    COUNT(*),
    SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
    MAX(extract_timestamp)
FROM stg.stg_inventaris

UNION ALL

SELECT 
    'stg_simpeg',
    COUNT(*),
    SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
    MAX(extract_timestamp)
FROM stg.stg_simpeg

UNION ALL

SELECT 
    'stg_layanan',
    COUNT(*),
    SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
    MAX(extract_timestamp)
FROM stg.stg_layanan

UNION ALL

SELECT 
    'stg_monitoring',
    COUNT(*),
    SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
    MAX(extract_timestamp)
FROM stg.stg_monitoring

UNION ALL

SELECT 
    'stg_unit_kerja',
    COUNT(*),
    SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
    MAX(extract_timestamp)
FROM stg.stg_unit_kerja;
GO

-- =====================================================
-- SECTION 5: DATA QUALITY HELPER VIEWS
-- =====================================================

-- View for staging surat quality
IF OBJECT_ID('analytics.vw_staging_surat_quality', 'V') IS NOT NULL DROP VIEW analytics.vw_staging_surat_quality;
GO

CREATE VIEW analytics.vw_staging_surat_quality AS
SELECT 'Missing nomor_surat' AS issue_type, COUNT(*) AS issue_count
FROM stg.stg_simaster_surat WHERE nomor_surat IS NULL OR TRIM(nomor_surat) = ''
UNION ALL
SELECT 'Missing tanggal_diterima', COUNT(*)
FROM stg.stg_simaster_surat WHERE tanggal_diterima IS NULL
UNION ALL
SELECT 'Invalid jenis_surat_id', COUNT(*)
FROM stg.stg_simaster_surat WHERE jenis_surat_id IS NULL OR jenis_surat_id < 1
UNION ALL
SELECT 'Future dates', COUNT(*)
FROM stg.stg_simaster_surat WHERE tanggal_diterima > GETDATE();
GO

-- View for staging inventaris quality
IF OBJECT_ID('analytics.vw_staging_inventaris_quality', 'V') IS NOT NULL DROP VIEW analytics.vw_staging_inventaris_quality;
GO

CREATE VIEW analytics.vw_staging_inventaris_quality AS
SELECT 'Missing kode_barang', COUNT(*)
FROM stg.stg_inventaris WHERE kode_barang IS NULL OR TRIM(kode_barang) = ''
UNION ALL
SELECT 'Missing nama_barang', COUNT(*)
FROM stg.stg_inventaris WHERE nama_barang IS NULL OR TRIM(nama_barang) = ''
UNION ALL
SELECT 'Negative nilai_perolehan', COUNT(*)
FROM stg.stg_inventaris WHERE nilai_perolehan < 0
UNION ALL
SELECT 'Future tanggal_pengadaan', COUNT(*)
FROM stg.stg_inventaris WHERE tanggal_pengadaan > GETDATE();
GO

-- View for staging pegawai quality
IF OBJECT_ID('analytics.vw_staging_pegawai_quality', 'V') IS NOT NULL DROP VIEW analytics.vw_staging_pegawai_quality;
GO

CREATE VIEW analytics.vw_staging_pegawai_quality AS
SELECT 'Missing NIP', COUNT(*)
FROM stg.stg_simpeg WHERE nip IS NULL OR TRIM(nip) = ''
UNION ALL
SELECT 'Missing nama', COUNT(*)
FROM stg.stg_simpeg WHERE nama IS NULL OR TRIM(nama) = ''
UNION ALL
SELECT 'Invalid NIP format (not 18 chars)', COUNT(*)
FROM stg.stg_simpeg WHERE LEN(TRIM(nip)) != 18
UNION ALL
SELECT 'Future tanggal_masuk', COUNT(*)
FROM stg.stg_simpeg WHERE tanggal_masuk > GETDATE();
GO

-- =====================================================
-- SECTION 6: STAGING DATA CLEANUP PROCEDURES
-- =====================================================

-- Procedure to reset staging table processing flags
IF OBJECT_ID('stg.usp_ResetStagingFlags', 'P') IS NOT NULL DROP PROCEDURE stg.usp_ResetStagingFlags;
GO

CREATE PROCEDURE stg.usp_ResetStagingFlags
    @TableName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    
    -- Validate table name (Basic whitelist check)
    IF @TableName NOT IN ('stg_simaster_surat', 'stg_inventaris', 'stg_simpeg', 'stg_layanan', 'stg_monitoring', 'stg_unit_kerja')
    BEGIN
        RAISERROR('Invalid staging table name', 16, 1);
        RETURN;
    END

    SET @Sql = 'UPDATE stg.' + QUOTENAME(@TableName) + ' SET is_processed = 0 WHERE is_processed = 1';
    EXEC sp_executesql @Sql;
    
    PRINT 'Reset processed flags for table: stg.' + @TableName;
END
GO

-- Procedure to truncate staging table
IF OBJECT_ID('stg.usp_TruncateStagingTable', 'P') IS NOT NULL DROP PROCEDURE stg.usp_TruncateStagingTable;
GO

CREATE PROCEDURE stg.usp_TruncateStagingTable
    @TableName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sql NVARCHAR(MAX);
    
    IF @TableName NOT IN ('stg_simaster_surat', 'stg_inventaris', 'stg_simpeg', 'stg_layanan', 'stg_monitoring', 'stg_unit_kerja')
    BEGIN
        RAISERROR('Invalid staging table name', 16, 1);
        RETURN;
    END

    SET @Sql = 'TRUNCATE TABLE stg.' + QUOTENAME(@TableName);
    EXEC sp_executesql @Sql;
    
    PRINT 'Truncated staging table: stg.' + @TableName;
END
GO

-- =====================================================
-- SECTION 7: STAGING AREA SUMMARY VIEW
-- =====================================================

IF OBJECT_ID('analytics.vw_staging_summary', 'V') IS NOT NULL DROP VIEW analytics.vw_staging_summary;
GO

CREATE VIEW analytics.vw_staging_summary AS
SELECT 
    GETDATE() AS report_time,
    (SELECT COUNT(*) FROM stg.stg_simaster_surat WHERE is_processed = 0) AS pending_surat,
    (SELECT COUNT(*) FROM stg.stg_inventaris WHERE is_processed = 0) AS pending_inventaris,
    (SELECT COUNT(*) FROM stg.stg_simpeg WHERE is_processed = 0) AS pending_pegawai,
    (SELECT COUNT(*) FROM stg.stg_layanan WHERE is_processed = 0) AS pending_layanan,
    (SELECT COUNT(*) FROM stg.stg_monitoring WHERE is_processed = 0) AS pending_monitoring,
    (SELECT COUNT(*) FROM stg.stg_unit_kerja WHERE is_processed = 0) AS pending_unit_kerja,
    (SELECT COUNT(*) FROM stg.stg_simaster_surat) AS total_surat,
    (SELECT COUNT(*) FROM stg.stg_inventaris) AS total_inventaris,
    (SELECT COUNT(*) FROM stg.stg_simpeg) AS total_pegawai,
    (SELECT COUNT(*) FROM stg.stg_layanan) AS total_layanan,
    (SELECT COUNT(*) FROM stg.stg_monitoring) AS total_monitoring,
    (SELECT COUNT(*) FROM stg.stg_unit_kerja) AS total_unit_kerja;
GO

-- =====================================================
-- SECTION 9: SAMPLE ETL LOGGING
-- =====================================================

INSERT INTO etl_log.job_execution (
    job_name,
    start_time,
    status,
    rows_extracted
) VALUES (
    '06_Create_Staging_Validation',
    GETDATE(),
    'Success',
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'stg')
);
GO

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================
PRINT '======================================================';
PRINT '06_Create_Staging.sql executed successfully';
PRINT '======================================================';
PRINT 'Next steps:';
PRINT '1. Verify views: SELECT * FROM analytics.vw_staging_summary;';
PRINT '======================================================';

-- ====================== END OF FILE ======================
