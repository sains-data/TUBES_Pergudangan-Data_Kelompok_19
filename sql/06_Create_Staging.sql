-- =====================================================
-- 06_Create_Staging.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Staging Area Validation and Additional Setup
-- Engine  : PostgreSQL
-- =====================================================

/*
    STAGING AREA OVERVIEW:
    Schema 'stg' dan staging tables sudah dibuat di 01_Create_Database.sql
    
    Script ini menyediakan:
    1. Validation queries untuk memastikan staging tables sudah ada
    2. Additional indexes untuk staging tables (jika diperlukan)
    3. Helper views untuk monitoring staging data
    4. Sample validation queries untuk data quality
*/

-- =====================================================
-- SECTION 1: VALIDATION - STAGING SCHEMA & TABLES
-- =====================================================

DO $$
DECLARE
    schema_count INT;
    table_count INT;
BEGIN
    -- Check if 'stg' schema exists
    SELECT COUNT(*) INTO schema_count
    FROM information_schema.schemata
    WHERE schema_name = 'stg';
    
    IF schema_count = 0 THEN
        RAISE EXCEPTION 'Schema "stg" does not exist! Please run 01_Create_Database.sql first.';
    ELSE
        RAISE NOTICE 'Schema "stg" exists: OK';
    END IF;
    
    -- Check if staging tables exist
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'stg'
    AND table_type = 'BASE TABLE';
    
    IF table_count < 6 THEN
        RAISE WARNING 'Expected at least 6 staging tables, found: %', table_count;
    ELSE
        RAISE NOTICE 'Staging tables found: % tables - OK', table_count;
    END IF;
END $$;

-- =====================================================
-- SECTION 2: VERIFY STAGING TABLES STRUCTURE
-- =====================================================

-- List all staging tables with column counts
DO $$
DECLARE
    r RECORD;
BEGIN
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'STAGING TABLES STRUCTURE VERIFICATION';
    RAISE NOTICE '======================================================';
    
    FOR r IN 
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
        ORDER BY t.table_name
    LOOP
        RAISE NOTICE 'Table: stg.% - Columns: %', r.table_name, r.column_count;
    END LOOP;
    
    RAISE NOTICE '======================================================';
END $$;

-- =====================================================
-- SECTION 3: VERIFY STAGING INDEXES
-- =====================================================

-- Check if indexes on staging tables exist
DO $$
DECLARE
    index_count INT;
BEGIN
    SELECT COUNT(*) INTO index_count
    FROM pg_indexes
    WHERE schemaname = 'stg';
    
    IF index_count = 0 THEN
        RAISE WARNING 'No indexes found on staging tables';
    ELSE
        RAISE NOTICE 'Staging indexes found: % indexes - OK', index_count;
    END IF;
END $$;

-- List all indexes on staging tables
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'stg'
ORDER BY tablename, indexname;

-- =====================================================
-- SECTION 4: ADDITIONAL STAGING UTILITIES
-- =====================================================

-- Create view for monitoring staging table row counts
CREATE OR REPLACE VIEW analytics.vw_staging_row_counts AS
SELECT 
    'stg_simaster_surat' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE is_processed = TRUE) AS processed_rows,
    COUNT(*) FILTER (WHERE is_processed = FALSE) AS pending_rows,
    MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_simaster_surat

UNION ALL

SELECT 
    'stg_inventaris' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE is_processed = TRUE) AS processed_rows,
    COUNT(*) FILTER (WHERE is_processed = FALSE) AS pending_rows,
    MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_inventaris

UNION ALL

SELECT 
    'stg_simpeg' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE is_processed = TRUE) AS processed_rows,
    COUNT(*) FILTER (WHERE is_processed = FALSE) AS pending_rows,
    MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_simpeg

UNION ALL

SELECT 
    'stg_layanan' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE is_processed = TRUE) AS processed_rows,
    COUNT(*) FILTER (WHERE is_processed = FALSE) AS pending_rows,
    MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_layanan

UNION ALL

SELECT 
    'stg_monitoring' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE is_processed = TRUE) AS processed_rows,
    COUNT(*) FILTER (WHERE is_processed = FALSE) AS pending_rows,
    MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_monitoring

UNION ALL

SELECT 
    'stg_unit_kerja' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE is_processed = TRUE) AS processed_rows,
    COUNT(*) FILTER (WHERE is_processed = FALSE) AS pending_rows,
    MAX(extract_timestamp) AS last_extract_time
FROM stg.stg_unit_kerja;

-- =====================================================
-- SECTION 5: DATA QUALITY HELPER VIEWS
-- =====================================================

-- View untuk monitoring data quality di staging surat
CREATE OR REPLACE VIEW analytics.vw_staging_surat_quality AS
SELECT 
    'Missing nomor_surat' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simaster_surat
WHERE nomor_surat IS NULL OR TRIM(nomor_surat) = ''

UNION ALL

SELECT 
    'Missing tanggal_diterima' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simaster_surat
WHERE tanggal_diterima IS NULL

UNION ALL

SELECT 
    'Invalid jenis_surat_id' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simaster_surat
WHERE jenis_surat_id IS NULL OR jenis_surat_id < 1

UNION ALL

SELECT 
    'Future dates' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simaster_surat
WHERE tanggal_diterima > CURRENT_DATE;

-- View untuk monitoring data quality di staging inventaris
CREATE OR REPLACE VIEW analytics.vw_staging_inventaris_quality AS
SELECT 
    'Missing kode_barang' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_inventaris
WHERE kode_barang IS NULL OR TRIM(kode_barang) = ''

UNION ALL

SELECT 
    'Missing nama_barang' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_inventaris
WHERE nama_barang IS NULL OR TRIM(nama_barang) = ''

UNION ALL

SELECT 
    'Negative nilai_perolehan' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_inventaris
WHERE nilai_perolehan < 0

UNION ALL

SELECT 
    'Future tanggal_pengadaan' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_inventaris
WHERE tanggal_pengadaan > CURRENT_DATE;

-- View untuk monitoring data quality di staging pegawai
CREATE OR REPLACE VIEW analytics.vw_staging_pegawai_quality AS
SELECT 
    'Missing NIP' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simpeg
WHERE nip IS NULL OR TRIM(nip) = ''

UNION ALL

SELECT 
    'Missing nama' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simpeg
WHERE nama IS NULL OR TRIM(nama) = ''

UNION ALL

SELECT 
    'Invalid NIP format (not 18 chars)' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simpeg
WHERE LENGTH(TRIM(nip)) != 18

UNION ALL

SELECT 
    'Future tanggal_masuk' AS issue_type,
    COUNT(*) AS issue_count
FROM stg.stg_simpeg
WHERE tanggal_masuk > CURRENT_DATE;

-- =====================================================
-- SECTION 6: STAGING DATA CLEANUP PROCEDURES
-- =====================================================

-- Function to reset staging table processing flags
CREATE OR REPLACE FUNCTION stg.reset_staging_flags(p_table_name VARCHAR)
RETURNS INTEGER AS $$
DECLARE
    affected_rows INTEGER;
    sql_query TEXT;
BEGIN
    -- Validate table name to prevent SQL injection
    IF p_table_name NOT IN (
        'stg_simaster_surat', 'stg_inventaris', 'stg_simpeg',
        'stg_layanan', 'stg_monitoring', 'stg_unit_kerja'
    ) THEN
        RAISE EXCEPTION 'Invalid staging table name: %', p_table_name;
    END IF;
    
    -- Build and execute dynamic SQL
    sql_query := format('UPDATE stg.%I SET is_processed = FALSE WHERE is_processed = TRUE', p_table_name);
    EXECUTE sql_query;
    
    GET DIAGNOSTICS affected_rows = ROW_COUNT;
    
    RAISE NOTICE 'Reset % processed flags for table: stg.%', affected_rows, p_table_name;
    
    RETURN affected_rows;
END;
$$ LANGUAGE plpgsql;

-- Function to truncate staging table
CREATE OR REPLACE FUNCTION stg.truncate_staging_table(p_table_name VARCHAR)
RETURNS BOOLEAN AS $$
DECLARE
    sql_query TEXT;
BEGIN
    -- Validate table name
    IF p_table_name NOT IN (
        'stg_simaster_surat', 'stg_inventaris', 'stg_simpeg',
        'stg_layanan', 'stg_monitoring', 'stg_unit_kerja'
    ) THEN
        RAISE EXCEPTION 'Invalid staging table name: %', p_table_name;
    END IF;
    
    -- Truncate table
    sql_query := format('TRUNCATE TABLE stg.%I', p_table_name);
    EXECUTE sql_query;
    
    RAISE NOTICE 'Truncated staging table: stg.%', p_table_name;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SECTION 7: STAGING AREA SUMMARY VIEW
-- =====================================================

CREATE OR REPLACE VIEW analytics.vw_staging_summary AS
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
-- SECTION 8: USEFUL VALIDATION QUERIES
-- =====================================================

-- Query 1: Check staging tables structure
-- SELECT 
--     table_name,
--     column_name,
--     data_type,
--     is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'stg'
-- ORDER BY table_name, ordinal_position;

-- Query 2: Check row counts in all staging tables
-- SELECT * FROM analytics.vw_staging_row_counts;

-- Query 3: Check staging summary
-- SELECT * FROM analytics.vw_staging_summary;

-- Query 4: Check data quality issues in staging surat
-- SELECT * FROM analytics.vw_staging_surat_quality WHERE issue_count > 0;

-- Query 5: Check data quality issues in staging inventaris
-- SELECT * FROM analytics.vw_staging_inventaris_quality WHERE issue_count > 0;

-- Query 6: Check data quality issues in staging pegawai
-- SELECT * FROM analytics.vw_staging_pegawai_quality WHERE issue_count > 0;

-- Query 7: List all indexes on staging tables
-- SELECT 
--     schemaname,
--     tablename,
--     indexname,
--     indexdef
-- FROM pg_indexes
-- WHERE schemaname = 'stg'
-- ORDER BY tablename, indexname;

-- Query 8: Check extract timestamps (freshness check)
-- SELECT 
--     'stg_simaster_surat' AS table_name,
--     MIN(extract_timestamp) AS oldest_record,
--     MAX(extract_timestamp) AS newest_record,
--     EXTRACT(EPOCH FROM (MAX(extract_timestamp) - MIN(extract_timestamp)))/3600 AS time_range_hours
-- FROM stg.stg_simaster_surat
-- UNION ALL
-- SELECT 
--     'stg_inventaris',
--     MIN(extract_timestamp),
--     MAX(extract_timestamp),
--     EXTRACT(EPOCH FROM (MAX(extract_timestamp) - MIN(extract_timestamp)))/3600
-- FROM stg.stg_inventaris;

-- =====================================================
-- SECTION 9: SAMPLE ETL LOGGING
-- =====================================================

-- Log staging validation execution
INSERT INTO etl_log.job_execution (
    job_name,
    start_time,
    status,
    rows_extracted
) VALUES (
    '06_Create_Staging_Validation',
    CURRENT_TIMESTAMP,
    'Success',
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'stg')
);

-- =====================================================
-- SUCCESS NOTICE & SUMMARY
-- =====================================================
DO $$
DECLARE
    stg_table_count INT;
    stg_index_count INT;
    stg_view_count INT;
BEGIN
    -- Count staging tables
    SELECT COUNT(*) INTO stg_table_count
    FROM information_schema.tables
    WHERE table_schema = 'stg' AND table_type = 'BASE TABLE';
    
    -- Count staging indexes
    SELECT COUNT(*) INTO stg_index_count
    FROM pg_indexes
    WHERE schemaname = 'stg';
    
    -- Count analytics views
    SELECT COUNT(*) INTO stg_view_count
    FROM information_schema.views
    WHERE table_schema = 'analytics'
    AND table_name LIKE 'vw_staging%';
    
    RAISE NOTICE '======================================================';
    RAISE NOTICE '06_Create_Staging.sql executed successfully';
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'Staging Area Summary:';
    RAISE NOTICE '- Staging tables: % tables', stg_table_count;
    RAISE NOTICE '- Staging indexes: % indexes', stg_index_count;
    RAISE NOTICE '- Monitoring views: % views', stg_view_count;
    RAISE NOTICE '- Helper functions: 2 functions (reset_flags, truncate)';
    RAISE NOTICE '';
    RAISE NOTICE 'Available Views:';
    RAISE NOTICE '- analytics.vw_staging_row_counts (row count monitoring)';
    RAISE NOTICE '- analytics.vw_staging_summary (overall summary)';
    RAISE NOTICE '- analytics.vw_staging_surat_quality (DQ checks)';
    RAISE NOTICE '- analytics.vw_staging_inventaris_quality (DQ checks)';
    RAISE NOTICE '- analytics.vw_staging_pegawai_quality (DQ checks)';
    RAISE NOTICE '';
    RAISE NOTICE 'Available Functions:';
    RAISE NOTICE '- stg.reset_staging_flags(table_name) - Reset processing flags';
    RAISE NOTICE '- stg.truncate_staging_table(table_name) - Truncate staging table';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Test staging area with sample data';
    RAISE NOTICE '2. Verify views: SELECT * FROM analytics.vw_staging_summary;';
    RAISE NOTICE '3. Proceed with ETL development (data loading scripts)';
    RAISE NOTICE '======================================================';
END $$;

-- ====================== END OF FILE ======================

