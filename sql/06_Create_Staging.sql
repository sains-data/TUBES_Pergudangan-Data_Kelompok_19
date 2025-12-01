-- =====================================================
-- 06_Create_Staging.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Staging Area Validation
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- SECTION 1: VERIFY STAGING TABLES
-- =====================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'stg' AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- =====================================================
-- SECTION 2: HELPER VIEWS
-- =====================================================

DROP VIEW IF EXISTS analytics.vw_staging_row_counts CASCADE;
CREATE VIEW analytics.vw_staging_row_counts AS
SELECT 'stg_simaster_surat' AS table_name,
       COUNT(*) AS total_rows,
       COUNT(*) FILTER (WHERE is_processed = TRUE) AS processed_rows,
       COUNT(*) FILTER (WHERE is_processed = FALSE) AS pending_rows,
       MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_simaster_surat

UNION ALL

SELECT 'stg_inventaris',
       COUNT(*),
       COUNT(*) FILTER (WHERE is_processed = TRUE),
       COUNT(*) FILTER (WHERE is_processed = FALSE),
       MAX(extract_timestamp)
FROM stg.stg_inventaris

UNION ALL

SELECT 'stg_simpeg',
       COUNT(*),
       COUNT(*) FILTER (WHERE is_processed = TRUE),
       COUNT(*) FILTER (WHERE is_processed = FALSE),
       MAX(extract_timestamp)
FROM stg.stg_simpeg

UNION ALL

SELECT 'stg_layanan',
       COUNT(*),
       COUNT(*) FILTER (WHERE is_processed = TRUE),
       COUNT(*) FILTER (WHERE is_processed = FALSE),
       MAX(extract_timestamp)
FROM stg.stg_layanan

UNION ALL

SELECT 'stg_monitoring',
       COUNT(*),
       COUNT(*) FILTER (WHERE is_processed = TRUE),
       COUNT(*) FILTER (WHERE is_processed = FALSE),
       MAX(extract_timestamp)
FROM stg.stg_monitoring

UNION ALL

SELECT 'stg_unit_kerja',
       COUNT(*),
       COUNT(*) FILTER (WHERE is_processed = TRUE),
       COUNT(*) FILTER (WHERE is_processed = FALSE),
       MAX(extract_timestamp)
FROM stg.stg_unit_kerja;

-- =====================================================
-- SECTION 3: DATA QUALITY VIEWS
-- =====================================================

DROP VIEW IF EXISTS analytics.vw_staging_surat_quality CASCADE;
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
FROM stg.stg_simaster_surat WHERE tanggal_diterima > CURRENT_DATE;

DROP VIEW IF EXISTS analytics.vw_staging_inventaris_quality CASCADE;
CREATE VIEW analytics.vw_staging_inventaris_quality AS
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
FROM stg.stg_inventaris WHERE tanggal_pengadaan > CURRENT_DATE;

DROP VIEW IF EXISTS analytics.vw_staging_pegawai_quality CASCADE;
CREATE VIEW analytics.vw_staging_pegawai_quality AS
SELECT 'Missing NIP' AS issue_type, COUNT(*) AS issue_count
FROM stg.stg_simpeg WHERE nip IS NULL OR TRIM(nip) = ''
UNION ALL
SELECT 'Missing nama', COUNT(*)
FROM stg.stg_simpeg WHERE nama IS NULL OR TRIM(nama) = ''
UNION ALL
SELECT 'Invalid NIP format (not 18 chars)', COUNT(*)
FROM stg.stg_simpeg WHERE LENGTH(TRIM(nip)) != 18
UNION ALL
SELECT 'Future tanggal_masuk', COUNT(*)
FROM stg.stg_simpeg WHERE tanggal_masuk > CURRENT_DATE;

-- =====================================================
-- SECTION 4: STAGING UTILITY FUNCTIONS
-- =====================================================

DROP FUNCTION IF EXISTS stg.reset_staging_flags(VARCHAR) CASCADE;
CREATE OR REPLACE FUNCTION stg.reset_staging_flags(table_name VARCHAR)
RETURNS void AS $$
BEGIN
    IF table_name NOT IN ('stg_simaster_surat', 'stg_inventaris', 'stg_simpeg', 'stg_layanan', 'stg_monitoring', 'stg_unit_kerja') THEN
        RAISE EXCEPTION 'Invalid staging table name: %', table_name;
    END IF;
    
    EXECUTE FORMAT('UPDATE stg.%I SET is_processed = FALSE WHERE is_processed = TRUE', table_name);
    RAISE NOTICE 'Reset processed flags for table: stg.%', table_name;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS stg.truncate_staging_table(VARCHAR) CASCADE;
CREATE OR REPLACE FUNCTION stg.truncate_staging_table(table_name VARCHAR)
RETURNS void AS $$
BEGIN
    IF table_name NOT IN ('stg_simaster_surat', 'stg_inventaris', 'stg_simpeg', 'stg_layanan', 'stg_monitoring', 'stg_unit_kerja') THEN
        RAISE EXCEPTION 'Invalid staging table name: %', table_name;
    END IF;
    
    EXECUTE FORMAT('TRUNCATE TABLE stg.%I', table_name);
    RAISE NOTICE 'Truncated staging table: stg.%', table_name;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SECTION 5: STAGING SUMMARY VIEW
-- =====================================================

DROP VIEW IF EXISTS analytics.vw_staging_summary CASCADE;
CREATE VIEW analytics.vw_staging_summary AS
SELECT 
    CURRENT_TIMESTAMP AS report_time,
    (SELECT COUNT(*) FROM stg.stg_simaster_surat WHERE is_processed = FALSE) AS pending_surat,
    (SELECT COUNT(*) FROM stg.stg_inventaris WHERE is_processed = FALSE) AS pending_inventaris,
    (SELECT COUNT(*) FROM stg.stg_simpeg WHERE is_processed = FALSE) AS pending_pegawai,
    (SELECT COUNT(*) FROM stg.stg_layanan WHERE is_processed = FALSE) AS pending_layanan,
    (SELECT COUNT(*) FROM stg.stg_monitoring WHERE is_processed = FALSE) AS pending_monitoring,
    (SELECT COUNT(*) FROM stg.stg_unit_kerja WHERE is_processed = FALSE) AS pending_unit_kerja,
    (SELECT COUNT(*) FROM stg.stg_simaster_surat) AS total_surat,
    (SELECT COUNT(*) FROM stg.stg_inventaris) AS total_inventaris,
    (SELECT COUNT(*) FROM stg.stg_simpeg) AS total_pegawai,
    (SELECT COUNT(*) FROM stg.stg_layanan) AS total_layanan,
    (SELECT COUNT(*) FROM stg.stg_monitoring) AS total_monitoring,
    (SELECT COUNT(*) FROM stg.stg_unit_kerja) AS total_unit_kerja;

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

SELECT '06_Create_Staging.sql executed successfully' as status;

-- ====================== END OF FILE ======================
