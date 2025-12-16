-- =====================================================
-- 01_Create_Database.sql
-- SQL SERVER VERSION (CORRECTED)
-- Data Mart Database Creation Script
-- Target: SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera; -- Pastikan database ini sudah dibuat sebelumnya
GO

PRINT '>> Starting Database Setup...';

-- =====================================================
-- 1. SCHEMAS
-- =====================================================
-- SQL Server requirement: Check existence before creating schema
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA [stg]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dim') EXEC('CREATE SCHEMA [dim]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fact') EXEC('CREATE SCHEMA [fact]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'etl_log') EXEC('CREATE SCHEMA [etl_log]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw') EXEC('CREATE SCHEMA [dw]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'analytics') EXEC('CREATE SCHEMA [analytics]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'reports') EXEC('CREATE SCHEMA [reports]');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'etl') EXEC('CREATE SCHEMA [etl]');
GO

-- =====================================================
-- 2. DW METADATA
-- =====================================================

IF OBJECT_ID('dw.etl_metadata', 'U') IS NULL
BEGIN
    CREATE TABLE dw.etl_metadata (
        metadata_id INT IDENTITY(1,1) PRIMARY KEY, -- SERIAL diganti IDENTITY
        table_name VARCHAR(50) NOT NULL UNIQUE,
        last_load_date DATETIME, -- TIMESTAMP diganti DATETIME
        last_load_status VARCHAR(20),
        total_records BIGINT,
        load_duration_minutes DECIMAL(10,2), -- NUMERIC diganti DECIMAL
        last_error VARCHAR(500),
        created_date DATETIME DEFAULT GETDATE(), -- CURRENT_TIMESTAMP diganti GETDATE()
        updated_date DATETIME DEFAULT GETDATE()
    );
END
GO

-- Seed entries (Menggunakan IF NOT EXISTS pengganti ON CONFLICT)
IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'dim_waktu')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('dim_waktu', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'dim_unit_kerja')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('dim_unit_kerja', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'dim_pegawai')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('dim_pegawai', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'dim_jenis_surat')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('dim_jenis_surat', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'dim_barang')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('dim_barang', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'dim_lokasi')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('dim_lokasi', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'dim_jenis_layanan')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('dim_jenis_layanan', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'fact_surat')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('fact_surat', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'fact_aset')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('fact_aset', 'Pending');

IF NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = 'fact_layanan')
    INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES ('fact_layanan', 'Pending');
GO

-- Index
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_etl_metadata_table_name')
    CREATE INDEX ix_etl_metadata_table_name ON dw.etl_metadata (table_name);
GO

-- =====================================================
-- 3. STAGING TABLES (SOURCE-SPECIFIC)
-- =====================================================

-- SIMASTER - Surat
IF OBJECT_ID('stg.stg_simaster_surat', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_simaster_surat (
        id_surat VARCHAR(50),
        source_system VARCHAR(20) DEFAULT 'SIMASTER',
        nomor_surat VARCHAR(50),
        tanggal_diterima DATE,
        pengirim VARCHAR(200),
        perihal VARCHAR(MAX), -- TEXT diganti VARCHAR(MAX)
        jenis_surat_id INT,
        status VARCHAR(20),
        extract_timestamp DATETIME DEFAULT GETDATE(),
        is_processed BIT DEFAULT 0, -- BOOLEAN diganti BIT
        raw_data NVARCHAR(MAX) -- JSONB diganti NVARCHAR(MAX)
    );
    CREATE INDEX ix_stg_surat_processed ON stg.stg_simaster_surat (is_processed, extract_timestamp);
    CREATE INDEX ix_stg_surat_nomor ON stg.stg_simaster_surat (nomor_surat);
END
GO

-- INVENTARIS - Aset
IF OBJECT_ID('stg.stg_inventaris', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_inventaris (
        id_barang VARCHAR(50),
        source_system VARCHAR(20) DEFAULT 'INVENTARIS',
        kode_barang VARCHAR(30),
        nama_barang VARCHAR(200),
        kategori VARCHAR(50),
        tanggal_pengadaan DATE,
        nilai_perolehan DECIMAL(15,2),
        kondisi VARCHAR(20),
        lokasi_id INT,
        unit_kerja_id INT,
        extract_timestamp DATETIME DEFAULT GETDATE(),
        is_processed BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_inventaris_processed ON stg.stg_inventaris (is_processed, extract_timestamp);
    CREATE INDEX ix_stg_inventaris_kode ON stg.stg_inventaris (kode_barang);
END
GO

-- SIMPEG - Kepegawaian
IF OBJECT_ID('stg.stg_simpeg', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_simpeg (
        nip VARCHAR(20),
        source_system VARCHAR(20) DEFAULT 'SIMPEG',
        nama VARCHAR(100),
        jabatan VARCHAR(100),
        unit_kerja_id INT,
        tanggal_masuk DATE,
        status_kepegawaian VARCHAR(30),
        email VARCHAR(100),
        no_hp VARCHAR(50),
        extract_timestamp DATETIME DEFAULT GETDATE(),
        is_processed BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_simpeg_processed ON stg.stg_simpeg (is_processed, extract_timestamp);
    CREATE INDEX ix_stg_simpeg_nip ON stg.stg_simpeg (nip);
END
GO

-- LAYANAN - Service Requests
IF OBJECT_ID('stg.stg_layanan', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_layanan (
        id_permintaan VARCHAR(50),
        source_system VARCHAR(20) DEFAULT 'LAYANAN',
        nomor_tiket VARCHAR(30),
        pemohon_nama VARCHAR(100),
        jenis_layanan_id INT,
        timestamp_submit DATETIME,
        tanggal_selesai DATETIME,
        status_penyelesaian VARCHAR(20),
        rating_kepuasan DECIMAL(2,1),
        extract_timestamp DATETIME DEFAULT GETDATE(),
        is_processed BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_layanan_processed ON stg.stg_layanan (is_processed, extract_timestamp);
END
GO

-- MONITORING - Kinerja
IF OBJECT_ID('stg.stg_monitoring', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_monitoring (
        id_laporan VARCHAR(50),
        source_system VARCHAR(20) DEFAULT 'MONITORING',
        periode DATE,
        unit_kerja_id INT,
        target_layanan INT,
        realisasi_layanan INT,
        target_surat INT,
        realisasi_surat INT,
        tanggal_submit DATE,
        status_approval VARCHAR(20),
        extract_timestamp DATETIME DEFAULT GETDATE(),
        is_processed BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_monitoring_processed ON stg.stg_monitoring (is_processed, extract_timestamp);
END
GO

-- MASTER - Unit Kerja
IF OBJECT_ID('stg.stg_unit_kerja', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_unit_kerja (
        id_unit VARCHAR(20),
        source_system VARCHAR(20) DEFAULT 'MASTER',
        kode_unit VARCHAR(10),
        nama_unit VARCHAR(100),
        level INT,
        parent_unit_id INT,
        kepala_unit_nip VARCHAR(20),
        email_unit VARCHAR(100),
        extract_timestamp DATETIME DEFAULT GETDATE(),
        is_processed BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_unit_kerja_processed ON stg.stg_unit_kerja (is_processed, extract_timestamp);
END
GO

-- =====================================================
-- 4. ETL LOGGING TABLES
-- =====================================================

IF OBJECT_ID('etl_log.job_execution', 'U') IS NULL
BEGIN
    CREATE TABLE etl_log.job_execution (
        execution_id INT IDENTITY(1,1) PRIMARY KEY,
        job_name VARCHAR(100) NOT NULL,
        start_time DATETIME DEFAULT GETDATE(),
        end_time DATETIME,
        status VARCHAR(20) DEFAULT 'Running',
        rows_extracted INT DEFAULT 0,
        rows_transformed INT DEFAULT 0,
        rows_loaded INT DEFAULT 0,
        error_message VARCHAR(MAX),
        created_date DATETIME DEFAULT GETDATE()
    );
    CREATE INDEX ix_job_exec_name ON etl_log.job_execution (job_name);
    CREATE INDEX ix_job_exec_time ON etl_log.job_execution (start_time);
END
GO

IF OBJECT_ID('etl_log.data_quality_checks', 'U') IS NULL
BEGIN
    CREATE TABLE etl_log.data_quality_checks (
        check_id INT IDENTITY(1,1) PRIMARY KEY,
        execution_id INT REFERENCES etl_log.job_execution(execution_id),
        check_name VARCHAR(100) NOT NULL,
        check_timestamp DATETIME DEFAULT GETDATE(),
        table_name VARCHAR(100),
        column_name VARCHAR(100),
        check_result VARCHAR(20),
        expected_value VARCHAR(100),
        actual_value VARCHAR(100),
        variance_pct DECIMAL(5,2),
        notes VARCHAR(MAX)
    );
    CREATE INDEX ix_dq_time ON etl_log.data_quality_checks (check_timestamp);
END
GO

IF OBJECT_ID('etl_log.error_details', 'U') IS NULL
BEGIN
    CREATE TABLE etl_log.error_details (
        error_id INT IDENTITY(1,1) PRIMARY KEY,
        execution_id INT REFERENCES etl_log.job_execution(execution_id),
        error_timestamp DATETIME DEFAULT GETDATE(),
        error_type VARCHAR(50),
        severity VARCHAR(20),
        source_table VARCHAR(100),
        error_message VARCHAR(MAX),
        affected_rows INT,
        resolution_status VARCHAR(20) DEFAULT 'Open',
        resolved_date DATETIME
    );
END
GO

PRINT '>> Database setup completed successfully.';
PRINT '>> Schemas created: stg, dim, fact, etl_log, dw, analytics, reports.';
PRINT '>> Staging and logging tables created.';
GO
