-- =====================================================
-- 01_CREATE_DATABASE.SQL
-- Data Mart Database Creation Script
-- =====================================================

/*
    TUBES Pergudangan Data - Kelompok 19
    Project: Data Mart Biro Akademik Umum ITERA
    Script: Database dan Schema Creation
    Author: Syahrialdi Rachim Akbar
    Created: 12 November 2025
    Purpose: Create database structure, schemas, dan user accounts
*/

-- =====================================================
-- DATABASE CREATION
-- =====================================================

-- Step 1: Create database
CREATE DATABASE DataMart_BAU_ITERA;
GO

-- Set compatibility level
ALTER DATABASE DataMart_BAU_ITERA
SET COMPATIBILITY_LEVEL = 150;  -- SQL Server 2019

-- Enable services
ALTER DATABASE DataMart_BAU_ITERA
SET RECOVERY FULL, 
    PAGE_VERIFY CHECKSUM,
    READ_COMMITTED_SNAPSHOT ON;

PRINT '✅ Database DataMart_BAU_ITERA created successfully';

-- =====================================================
-- SCHEMA CREATION
-- =====================================================

USE DataMart_BAU_ITERA;
GO

-- Create schemas for organized data management
CREATE SCHEMA stg;      -- Staging area untuk raw data
GO
CREATE SCHEMA dim;      -- Dimension tables
GO
CREATE SCHEMA fact;     -- Fact tables
GO
CREATE SCHEMA etl_log;  -- ETL logging tables
GO
CREATE SCHEMA dw;       -- Main data warehouse schema
GO
CREATE SCHEMA analytics; -- View dan stored procedures untuk BI
GO
CREATE SCHEMA reports;  -- Report-specific procedures
GO

-- =====================================================
-- DATABASE SETTINGS
-- =====================================================

-- Configure database options untuk optimal performance
ALTER DATABASE DataMart_BAU_ITERA
SET AUTO_CLOSE OFF,
    AUTO_SHRINK OFF,
    AUTO_UPDATE_STATISTICS ON,
    AUTO_CREATE_STATISTICS ON;

PRINT '✅ Database schemas created successfully';

-- =====================================================
-- USERS & SECURITY
-- =====================================================

-- Database owner (untuk maintenance)
CREATE USER bau_dw_owner WITHOUT LOGIN;
ALTER ROLE db_owner ADD MEMBER bau_dw_owner;

-- ETL Developer role (Zahra)
CREATE USER bau_etl_dev WITHOUT LOGIN;
ALTER USER bau_etl_dev
FOR LOGIN [domain\bau_etl_dev] 
WITH DEFAULT_SCHEMA = etl_log;
ALTER ROLE db_datareader ADD MEMBER bau_etl_dev;
ALTER ROLE db_datawriter ADD MEMBER bau_etl_dev;
PRINT '✅ ETL Developer user created';

-- BI Developer role (Feby)
CREATE USER bau_bi_dev WITHOUT LOGIN;
ALTER USER bau_bi_dev
FOR LOGIN [domain\bau_bi_dev] 
WITH DEFAULT_SCHEMA = analytics;
ALTER ROLE db_datareader ADD MEMBER bau_bi_dev;
PRINT '✅ BI Developer user created';

-- End users role (read-only access)
CREATE USER bau_readonly WITHOUT LOGIN;
ALTER USER bau_readonly
FOR LOGIN [domain\bau_readonly] 
WITH DEFAULT_SCHEMA = reports;
ALTER ROLE db_datareader ADD MEMBER bau_readonly;
PRINT '✅ End user role created';

-- =====================================================
-- DATABASE FILES & FILEGROUPS (OPTIONAL)
-- =====================================================

-- Create filegroups untuk partitioning (recommended untuk performance)
ALTER DATABASE DataMart_BAU_ITERA
ADD FILEGROUP FG_DIMENSIONS;  -- Dimension tables
GO

ALTER DATABASE DataMart_BAU_ITERA
ADD FILEGROUP FG_FACTS;       -- Fact tables
GO

ALTER DATABASE DataMart_BAU_ITERA
ADD FILEGROUP FG_LOGS;        -- Logging tables
GO

-- =====================================================
-- MAIN DATABASE METADATA TABLE
-- =====================================================

-- ETL metadata untuk tracking load status
CREATE TABLE dw.etl_metadata (
    metadata_id INT IDENTITY(1,1) PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    last_load_date DATETIME2,
    last_load_status VARCHAR(20),
    total_records BIGINT,
    load_duration_minutes DECIMAL(10,2),
    last_error VARCHAR(500),
    created_date DATETIME2 DEFAULT GETDATE(),
    updated_date DATETIME2 DEFAULT GETDATE()
);

-- Populate initial metadata
INSERT INTO dw.etl_metadata (table_name, last_load_date, last_load_status)
VALUES 
    ('dim_waktu', NULL, 'Pending'),
    ('dim_unit_kerja', NULL, 'Pending'),
    ('dim_pegawai', NULL, 'Pending'),
    ('dim_jenis_surat', NULL, 'Pending'),
    ('dim_barang', NULL, 'Pending'),
    ('dim_lokasi', NULL, 'Pending'),
    ('dim_jenis_layanan', NULL, 'Pending'),
    ('fact_surat', NULL, 'Pending'),
    ('fact_aset', NULL, 'Pending'),
    ('fact_layanan', NULL, 'Pending');

PRINT '✅ ETL metadata table created successfully';

-- =====================================================
-- STAGING SCHEMA TABLES
-- =====================================================

-- Generic staging table template (untuk flexibility)
CREATE TABLE stg.staging_template (
    source_system VARCHAR(50),
    source_table VARCHAR(100),
    record_key VARCHAR(50),
    extract_timestamp DATETIME2 DEFAULT GETDATE(),
    raw_data JSON,  -- Flexible structure untuk raw data
    is_processed BIT DEFAULT 0,
    processing_error VARCHAR(500),
    hash_key VARCHAR(32)  -- MD5 hash untuk detect changes
);

PRINT '✅ Staging schema template created';

-- =====================================================
-- LOGGING TABLES (SCHEMA: etl_log)
-- =====================================================

-- Job execution log untuk monitoring
CREATE TABLE etl_log.job_execution (
    execution_id INT IDENTITY(1,1) PRIMARY KEY,
    job_name VARCHAR(100) NOT NULL,
    start_time DATETIME2 NOT NULL,
    end_time DATETIME2,
    status VARCHAR(20) NOT NULL DEFAULT 'Running',  -- Running, Success, Failed, Warning
    rows_extracted INT DEFAULT 0,
    rows_transformed INT DEFAULT 0,
    rows_loaded INT DEFAULT 0,
    error_message VARCHAR(1000),
    duration_seconds AS (
        CASE 
            WHEN end_time IS NULL THEN NULL
            ELSE DATEDIFF(SECOND, start_time, end_time)
        END
    ),
    created_date DATETIME2 DEFAULT GETDATE()
);

-- Data quality monitoring log
CREATE TABLE etl_log.data_quality_checks (
    check_id INT IDENTITY(1,1) PRIMARY KEY,
    execution_id INT NULL,
    check_name VARCHAR(100) NOT NULL,
    check_timestamp DATETIME2 NOT NULL DEFAULT GETDATE(),
    table_name VARCHAR(100),
    column_name VARCHAR(100),
    check_result VARCHAR(20),  -- Pass, Fail, Warning
    expected_value VARCHAR(100),
    actual_value VARCHAR(100),
    variance_pct DECIMAL(5,2),
    notes VARCHAR(500)
);

-- Detailed error log
CREATE TABLE etl_log.error_details (
    error_id INT IDENTITY(1,1) PRIMARY KEY,
    execution_id INT NULL,
    error_timestamp DATETIME2 NOT NULL DEFAULT GETDATE(),
    error_type VARCHAR(50),  -- Validation, Transformation, Load, System
    severity VARCHAR(20),     -- Critical, High, Medium, Low
    source_table VARCHAR(100),
    error_message VARCHAR(1000),
    affected_rows INT,
    resolution_status VARCHAR(20) DEFAULT 'Open',  -- Open, Resolved, Ignored
    resolved_date DATETIME2
);

-- Indexes untuk logging tables
CREATE INDEX IX_job_execution_job_name 
ON etl_log.job_execution (job_name);

CREATE INDEX IX_job_execution_date 
ON etl_log.job_execution (start_time);

CREATE INDEX IX_data_quality_date 
ON etl_log.data_quality_checks (check_timestamp);

CREATE INDEX IX_error_details_date 
ON etl_log.error_details (error_timestamp);

PRINT '✅ Logging tables created successfully';

-- =====================================================
-- ANALYTICS SCHEMA (EMPTY FOR NOW)
-- =====================================================

-- Placeholder untuk views dan analytics procedures
-- Views akan dibuat di script terpisah untuk simplicity

PRINT '✅ Analytics schema prepared';

-- =====================================================
-- REPORTS SCHEMA (EMPTY FOR NOW)
-- =====================================================

-- Placeholder untuk reporting procedures
-- Reporting procedures akan dibuat di tahap kemudian

PRINT '✅ Reports schema prepared';

-- =====================================================
-- DATABASE INTEGRITY CHECKS
-- =====================================================

-- Create indexes on metadata tables untuk fast lookup
CREATE INDEX IX_etl_metadata_table_name 
ON dw.etl_metadata (table_name);

PRINT '✅ Database integrity indexes created';

-- =====================================================
-- INITIAL HEALTH CHECK & VALIDATION
-- =====================================================

PRINT '';
PRINT '================================================';
PRINT 'DATABASE VALIDATION';
PRINT '================================================';

-- Check database creation
SELECT 
    @@SERVERNAME AS server_name,
    DB_NAME() AS database_name,
    GETDATE() AS created_date,
    CASE 
        WHEN @@SERVICENAME = 'MSSQLSERVER' THEN '✅ SQL Server Ready'
        WHEN @@SERVICENAME LIKE '%SQL%' THEN '⚠️ Non-standard service name'
        ELSE '❌ Service name verification failed'
    END AS sql_server_status;

-- Check schema creation
SELECT 
    'Schemas Created' AS check_name,
    COUNT(*) AS count,
    STRING_AGG(name, ', ') AS schema_list
FROM sys.schemas
WHERE name IN ('stg', 'dim', 'fact', 'etl_log', 'dw', 'analytics', 'reports');

-- Check table creation in etl_log schema
SELECT 
    'Tables Created' AS check_name,
    COUNT(*) AS count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'etl_log'
  AND TABLE_NAME IN ('job_execution', 'data_quality_checks', 'error_details');

-- Check metadata table population
SELECT 
    'Metadata Records' AS check_name,
    COUNT(*) AS count
FROM dw.etl_metadata;

PRINT '';
PRINT '================================================';
PRINT '✅ DATABASE CREATION SUCCESSFUL';
PRINT '================================================';
PRINT '';

-- =====================================================
-- SETUP DATABASE MAIL FOR ALERTS (OPTIONAL)
-- =====================================================

PRINT '';
PRINT '================================================';
PRINT 'DATABASE MAIL SETUP (OPTIONAL)';
PRINT '================================================';

-- Note: Database Mail harus di-configure oleh DBA
-- Script ini hanya menunjukkan struktur, konfigurasi tetap manual
PRINT '-- Manual setup required via SSMS:';
PRINT '-- 1. Enable Database Mail in SQL Server Configuration';
PRINT '-- 2. Create mail profile';
PRINT '-- 3. Configure mail accounts';
PRINT '-- 4. Test connectivity';
PRINT '';
PRINT '-- Sample procedure structure:';
PRINT '';

PRINT 'CREATE PROCEDURE etl.send_failure_alert';
PRINT '( @job_name VARCHAR(100), @error_message VARCHAR(MAX) )';
PRINT 'AS';
PRINT 'BEGIN';
PRINT '    EXEC msdb.dbo.sp_send_dbmail';
PRINT '        @profile_name = ''ETL_Alerts'',';
PRINT '        @recipients = ''team@itera.ac.id'',';
PRINT '        @subject = ''ETL FAILURE: '' + @job_name,';
PRINT '        @body = @error_message,';
PRINT '        @importance = ''High'';';
PRINT 'END;';

PRINT '';
PRINT '================================================';
PRINT 'DATABASE SETUP COMPLETE';
PRINT '================================================';
PRINT '';
PRINT '📋 Next Steps:';
PRINT '1. Execute 02_Create_Dimensions.sql';
PRINT '2. Execute 03_Create_Facts.sql';
PRINT '3. Load sample data for testing';
PRINT '4. Configure SQL Server Agent jobs';
PRINT '5. Test ETL procedures';
PRINT '';
PRINT '🔗 Related Documents:';
PRINT '- 02_Create_Dimensions.sql (dimension table structures)';
PRINT '- 03_Create_Facts.sql (fact table structures)';
PRINT '- etl-strategy.md (ETL approach and procedures)';
PRINT '- source-to-target-mapping.md (field-level transformations)';
PRINT '';
PRINT '⚠️  Manual Steps Required:';
PRINT '- Configure Database Mail for alerts';
PRINT '- Setup backup schedule';
PRINT '- Create SQL Server Agent jobs for scheduling';
PRINT '- Configure user permissions';
PRINT '';
PRINT '🎉 Database ready for ETL development!';
PRINT '';

-- =====================================================
-- END OF SCRIPT
-- =====================================================

-- Script execution summary
PRINT 'Execution Summary:';
PRINT '- Database: DataMart_BAU_ITERA (Created)';
PRINT '- Schemas: stg, dim, fact, etl_log, dw, analytics, reports (Created)';
PRINT '- Tables: 4 logging tables, 1 metadata table (Created)';
PRINT '- Users: 4 roles (Created)';
PRINT '- Indexes: Database integrity indexes (Created)';
PRINT '';
PRINT 'Total execution time: ' + CAST(DATEDIFF(SECOND, @@PROCID, GETDATE()) AS VARCHAR(10)) + ' seconds';
PRINT '';
PRINT '✅ All database creation tasks completed successfully!';
PRINT 'Next step: Execute 02_Create_Dimensions.sql';
