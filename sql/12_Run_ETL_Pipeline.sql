-- =====================================================
-- 12_Run_ETL_Pipeline.sql
-- POSTGRESQL VERSION
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Execute Master ETL Pipeline
-- Engine  : PostgreSQL 14+
-- =====================================================

/*
    INSTRUCTIONS:
    1. Ensure all staging tables are populated with source data
    2. Run this script to execute the complete ETL pipeline
    3. Monitor job_execution table for status
    4. Check data_quality_checks table for validation results
*/

-- =====================================================
-- STEP 1: VERIFY STAGING DATA EXISTS
-- =====================================================

SELECT 'ETL Pipeline Execution Started' as step;

SELECT 
    'stg_simaster_surat' as table_name,
    COUNT(*) as row_count
FROM stg.stg_simaster_surat
UNION ALL
SELECT 'stg_inventaris', COUNT(*) FROM stg.stg_inventaris
UNION ALL
SELECT 'stg_simpeg', COUNT(*) FROM stg.stg_simpeg
UNION ALL
SELECT 'stg_layanan', COUNT(*) FROM stg.stg_layanan
UNION ALL
SELECT 'stg_monitoring', COUNT(*) FROM stg.stg_monitoring
UNION ALL
SELECT 'stg_unit_kerja', COUNT(*) FROM stg.stg_unit_kerja;

-- =====================================================
-- STEP 2: EXECUTE MASTER ETL PROCEDURE
-- =====================================================

SELECT 'Executing Master ETL...' as status;

CALL etl.master_etl();

-- =====================================================
-- STEP 3: RUN DATA QUALITY CHECKS
-- =====================================================

SELECT 'Running Data Quality Checks...' as status;

CALL etl.run_data_quality_checks();

-- =====================================================
-- STEP 4: VERIFY LOADED DATA
-- =====================================================

SELECT 'Verifying loaded data...' as status;

SELECT 
    'dim_waktu' as table_name,
    COUNT(*) as row_count
FROM dim.dim_waktu
UNION ALL
SELECT 'dim_unit_kerja', COUNT(*) FROM dim.dim_unit_kerja
UNION ALL
SELECT 'dim_pegawai', COUNT(*) FROM dim.dim_pegawai
UNION ALL
SELECT 'dim_jenis_surat', COUNT(*) FROM dim.dim_jenis_surat
UNION ALL
SELECT 'dim_jenis_layanan', COUNT(*) FROM dim.dim_jenis_layanan
UNION ALL
SELECT 'dim_barang', COUNT(*) FROM dim.dim_barang
UNION ALL
SELECT 'dim_lokasi', COUNT(*) FROM dim.dim_lokasi
UNION ALL
SELECT 'fact_surat', COUNT(*) FROM fact.fact_surat
UNION ALL
SELECT 'fact_layanan', COUNT(*) FROM fact.fact_layanan
UNION ALL
SELECT 'fact_aset', COUNT(*) FROM fact.fact_aset;

-- =====================================================
-- STEP 5: EXECUTION SUMMARY
-- =====================================================

SELECT 'ETL Pipeline execution completed.' as final_status;

SELECT 
    job_name,
    start_time,
    end_time,
    status,
    rows_extracted,
    rows_transformed,
    rows_loaded,
    error_message
FROM etl_log.job_execution
ORDER BY execution_id DESC
LIMIT 5;

-- ====================== END OF FILE ======================
