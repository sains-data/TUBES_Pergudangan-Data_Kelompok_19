-- =====================================================
-- 06_Create_Staging.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Staging Area Validation & Utility Procedures
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Creating Staging Helper Objects...';

-- =====================================================
-- SECTION 1: VERIFY STAGING TABLES
-- =====================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'stg' AND table_type = 'BASE TABLE'
ORDER BY table_name;
GO

-- =====================================================
-- SECTION 2: HELPER VIEWS
-- =====================================================

CREATE OR ALTER VIEW analytics.vw_staging_row_counts AS
SELECT 'stg_simaster_surat' AS table_name,
       COUNT(*) AS total_rows,
       SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END) AS processed_rows,
       SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END) AS pending_rows,
       MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_simaster_surat

UNION ALL

SELECT 'stg_inventaris',
       COUNT(*),
       SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
       MAX(extract_timestamp)
FROM stg.stg_inventaris

UNION ALL

SELECT 'stg_simpeg',
       COUNT(*),
       SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
       MAX(extract_timestamp)
FROM stg.stg_simpeg

UNION ALL

SELECT 'stg_layanan',
       COUNT(*),
       SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
       MAX(extract_timestamp)
FROM stg.stg_layanan

UNION ALL

SELECT 'stg_monitoring',
       COUNT(*),
       SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
       MAX(extract_timestamp)
FROM stg.stg_monitoring

UNION ALL

SELECT 'stg_unit_kerja',
       COUNT(*),
       SUM(CASE WHEN is_processed = 1 THEN 1 ELSE 0 END),
       SUM(CASE WHEN is_processed = 0 THEN 1 ELSE 0 END),
       MAX(extract_timestamp)
FROM stg.stg_unit_kerja;
GO

-- =====================================================
-- SECTION 3: DATA QUALITY VIEWS
-- =====================================================

CREATE OR ALTER VIEW analytics.vw_staging_surat_quality AS
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
FROM stg.stg_simaster_surat WHERE tanggal_diterima > CAST(GETDATE() AS DATE);
GO

CREATE OR ALTER VIEW analytics.vw_staging_inventaris_quality AS
SELECT 'Missing kode_barang' AS issue_type, COUNT(*) AS issue_count
FROM stg.stg_inventaris WHERE kode_barang IS NULL OR TRIM(kode_barang) = ''
UNION ALL
SELECT 'Missing nama_barang', COUNT(*)
FROM stg.stg_inventaris WHERE nama_barang IS NULL OR TRIM(nama_barang) = ''
UNION ALL
SELECT 'Negative nilai_perolehan', COUNT(*)
FROM stg.stg_inventaris WHERE nilai_perolehan < 0
UNION ALL
SELECT 'Future tanggal_pengadaan', COUNT(*)
FROM stg.stg_inventaris WHERE tanggal_pengadaan > CAST(GETDATE() AS DATE);
GO

CREATE OR ALTER VIEW analytics.vw_staging_pegawai_quality AS
SELECT 'Missing NIP' AS issue_type, COUNT(*) AS issue_count
FROM stg.stg_simpeg WHERE nip IS NULL OR TRIM(nip) = ''
UNION ALL
SELECT 'Missing nama', COUNT(*)
FROM stg.stg_simpeg WHERE nama IS NULL OR TRIM(nama) = ''
UNION ALL
SELECT 'Invalid NIP format (not 18 chars)', COUNT(*)
FROM stg.stg_simpeg WHERE LEN(TRIM(nip)) != 18
UNION ALL
SELECT 'Future tanggal_masuk', COUNT(*)
FROM stg.stg_simpeg WHERE tanggal_masuk > CAST(GETDATE() AS DATE);
GO

-- =====================================================
-- SECTION 4: STAGING UTILITY PROCEDURES (Replaces Functions)
-- =====================================================
-- Note: In SQL Server, functions cannot modify data (UPDATE/TRUNCATE).
-- We must use STORED PROCEDURES instead.

CREATE OR ALTER PROCEDURE stg.usp_ResetStagingFlags
    @table_name VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Input Validation
    IF @table_name NOT IN ('stg_simaster_surat', 'stg_inventaris', 'stg_simpeg', 'stg_layanan', 'stg_monitoring', 'stg_unit_kerja')
    BEGIN
        RAISEERROR('Invalid staging table name: %s', 16, 1, @table_name);
        RETURN;
    END

    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'UPDATE stg.' + QUOTENAME(@table_name) + ' SET is_processed = 0 WHERE is_processed = 1';
    
    EXEC sp_executesql @sql;
    PRINT 'Reset processed flags for table: stg.' + @table_name;
END;
GO

CREATE OR ALTER PROCEDURE stg.usp_TruncateStagingTable
    @table_name VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    -- Input Validation
    IF @table_name NOT IN ('stg_simaster_surat', 'stg_inventaris', 'stg_simpeg', 'stg_layanan', 'stg_monitoring', 'stg_unit_kerja')
    BEGIN
        RAISEERROR('Invalid staging table name: %s', 16, 1, @table_name);
        RETURN;
    END
    
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'TRUNCATE TABLE stg.' + QUOTENAME(@table_name);
    
    EXEC sp_executesql @sql;
    PRINT 'Truncated staging table: stg.' + @table_name;
END;
GO

-- =====================================================
-- SECTION 5: STAGING SUMMARY VIEW
-- =====================================================

CREATE OR ALTER VIEW analytics.vw_staging_summary AS
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
-- SUCCESS NOTICE
-- =====================================================

PRINT '>> 06_Create_Staging.sql executed successfully.';
GO
