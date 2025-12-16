-- =====================================================
-- 12_Run_ETL_Pipeline.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Execute Master ETL Pipeline
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

/*
    INSTRUCTIONS:
    1. Ensure all staging tables are populated with source data.
    2. Run this script to execute the complete ETL pipeline.
    3. Monitor job_execution table for status.
    4. Check data_quality_checks table for validation results.
*/

USE datamart_bau_itera;
GO

PRINT '>>> STARTING ETL PIPELINE EXECUTION...';
GO

-- =====================================================
-- STEP 1: VERIFY STAGING DATA EXISTS
-- =====================================================

PRINT '--- STEP 1: Verifying Staging Data ---';

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
GO

-- =====================================================
-- STEP 2: EXECUTE MASTER ETL PROCEDURE
-- =====================================================

PRINT '--- STEP 2: Executing Master ETL (Loading Dims & Facts) ---';

-- Execute the orchestrator procedure created in Script 07
EXEC etl.usp_MasterETL;
GO

-- =====================================================
-- STEP 3: RUN DATA QUALITY CHECKS
-- =====================================================

PRINT '--- STEP 3: Running Automated Data Quality Checks ---';

-- Execute DQ procedure created in Script 08
EXEC etl.usp_RunDataQualityChecks;
GO

-- =====================================================
-- STEP 4: VERIFY LOADED DATA
-- =====================================================

PRINT '--- STEP 4: Verifying Loaded Data in Warehouse ---';

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
GO

-- =====================================================
-- STEP 5: EXECUTION SUMMARY
-- =====================================================

PRINT '--- STEP 5: Execution Summary & Logs ---';

SELECT TOP 5 -- LIMIT replaced with TOP
    job_name,
    start_time,
    end_time,
    status,
    rows_extracted,
    rows_transformed,
    rows_loaded,
    error_message
FROM etl_log.job_execution
ORDER BY execution_id DESC;
GO

PRINT '>>> ETL Pipeline execution completed.';
GO
