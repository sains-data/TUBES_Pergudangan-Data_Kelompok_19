-- =====================================================
-- 01_Create_Database.sql
-- Data Mart Database Creation Script (SQL Server / T-SQL)
-- Target: Execute inside existing DB (e.g., datamart_bau_itera)
-- =====================================================

/*
    Project : Data Mart Biro Akademik Umum ITERA
    Purpose : Create schemas, metadata, staging & logging tables, and indexes
    Engine  : Microsoft SQL Server 2019+
    Notes   : Uses T-SQL syntax (IDENTITY, DATETIME, BIT, etc.)
*/

-- =====================================================
-- SCHEMAS
-- =====================================================
-- SQL Server does not support "CREATE SCHEMA IF NOT EXISTS" in one line.
-- We must check sys.schemas first.

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg') EXEC('CREATE SCHEMA [stg]');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dim') EXEC('CREATE SCHEMA [dim]');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'fact') EXEC('CREATE SCHEMA [fact]');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'etl_log') EXEC('CREATE SCHEMA [etl_log]');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'dw') EXEC('CREATE SCHEMA [dw]');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'analytics') EXEC('CREATE SCHEMA [analytics]');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'reports') EXEC('CREATE SCHEMA [reports]');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'etl') EXEC('CREATE SCHEMA [etl]');

-- =====================================================
-- DW METADATA
-- =====================================================
IF OBJECT_ID('dw.etl_metadata', 'U') IS NULL
BEGIN
    CREATE TABLE dw.etl_metadata (
        metadata_id              INT IDENTITY(1,1) PRIMARY KEY,
        table_name               VARCHAR(50) NOT NULL UNIQUE,
        last_load_date           DATETIME,
        last_load_status         VARCHAR(20),
        total_records            BIGINT,
        load_duration_minutes    DECIMAL(10,2),
        last_error               VARCHAR(500),
        created_date             DATETIME DEFAULT GETDATE(),
        updated_date             DATETIME DEFAULT GETDATE()
    );

    -- Seed entries (Idempotent using NOT EXISTS check)
    INSERT INTO dw.etl_metadata (table_name, last_load_status)
    SELECT table_name, 'Pending'
    FROM (VALUES
      ('dim_waktu'),
      ('dim_unit_kerja'),
      ('dim_pegawai'),
      ('dim_jenis_surat'),
      ('dim_barang'),
      ('dim_lokasi'),
      ('dim_jenis_layanan'),
      ('fact_surat'),
      ('fact_aset'),
      ('fact_layanan')
    ) AS v(table_name)
    WHERE NOT EXISTS (SELECT 1 FROM dw.etl_metadata WHERE table_name = v.table_name);

    -- Index
    CREATE INDEX ix_etl_metadata_table_name ON dw.etl_metadata (table_name);
END
GO

-- =====================================================
-- STAGING TABLES (SOURCE-SPECIFIC)
-- =====================================================

-- SIMASTER - Surat
IF OBJECT_ID('stg.stg_simaster_surat', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_simaster_surat (
        id_surat            VARCHAR(50),
        source_system       VARCHAR(20) DEFAULT 'SIMASTER',
        nomor_surat         VARCHAR(50),
        tanggal_diterima    DATE,
        pengirim            VARCHAR(200),
        perihal             VARCHAR(MAX), -- TEXT -> VARCHAR(MAX)
        jenis_surat_id      INT,
        status              VARCHAR(20),
        extract_timestamp   DATETIME DEFAULT GETDATE(),
        is_processed        BIT DEFAULT 0, -- BOOLEAN -> BIT
        raw_data            NVARCHAR(MAX)  -- JSON -> NVARCHAR(MAX)
    );
    CREATE INDEX ix_stg_surat_processed ON stg.stg_simaster_surat (is_processed, extract_timestamp);
    CREATE INDEX ix_stg_surat_nomor ON stg.stg_simaster_surat (nomor_surat);
END
GO

-- INVENTARIS - Aset
IF OBJECT_ID('stg.stg_inventaris', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_inventaris (
        id_barang           VARCHAR(50),
        source_system       VARCHAR(20) DEFAULT 'INVENTARIS',
        kode_barang         VARCHAR(30),
        nama_barang         VARCHAR(200),
        kategori            VARCHAR(50),
        tanggal_pengadaan   DATE,
        nilai_perolehan     DECIMAL(15,2),
        kondisi             VARCHAR(20),
        lokasi_id           INT,
        unit_kerja_id       INT,
        extract_timestamp   DATETIME DEFAULT GETDATE(),
        is_processed        BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_inventaris_processed ON stg.stg_inventaris (is_processed, extract_timestamp);
    CREATE INDEX ix_stg_inventaris_kode ON stg.stg_inventaris (kode_barang);
END
GO

-- SIMPEG - Kepegawaian
IF OBJECT_ID('stg.stg_simpeg', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_simpeg (
        nip                 VARCHAR(20),
        source_system       VARCHAR(20) DEFAULT 'SIMPEG',
        nama                VARCHAR(100),
        jabatan             VARCHAR(100),
        unit_kerja_id       INT,
        tanggal_masuk       DATE,
        status_kepegawaian  VARCHAR(30),
        email               VARCHAR(100),
        no_hp               VARCHAR(15),
        extract_timestamp   DATETIME DEFAULT GETDATE(),
        is_processed        BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_simpeg_processed ON stg.stg_simpeg (is_processed, extract_timestamp);
    CREATE INDEX ix_stg_simpeg_nip ON stg.stg_simpeg (nip);
END
GO

-- LAYANAN - Service Requests
IF OBJECT_ID('stg.stg_layanan', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_layanan (
        id_permintaan       VARCHAR(50),
        source_system       VARCHAR(20) DEFAULT 'LAYANAN',
        nomor_tiket         VARCHAR(30),
        pemohon_nama        VARCHAR(100),
        jenis_layanan_id    INT,
        timestamp_submit    DATETIME,
        tanggal_selesai     DATETIME,
        status_penyelesaian VARCHAR(20),
        rating_kepuasan     DECIMAL(2,1),
        extract_timestamp   DATETIME DEFAULT GETDATE(),
        is_processed        BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_layanan_processed ON stg.stg_layanan (is_processed, extract_timestamp);
END
GO

-- MONITORING - Kinerja
IF OBJECT_ID('stg.stg_monitoring', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_monitoring (
        id_laporan          VARCHAR(50),
        source_system       VARCHAR(20) DEFAULT 'MONITORING',
        periode             DATE,
        unit_kerja_id       INT,
        target_layanan      INT,
        realisasi_layanan   INT,
        target_surat        INT,
        realisasi_surat     INT,
        tanggal_submit      DATE,
        status_approval     VARCHAR(20),
        extract_timestamp   DATETIME DEFAULT GETDATE(),
        is_processed        BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_monitoring_processed ON stg.stg_monitoring (is_processed, extract_timestamp);
END
GO

-- MASTER - Unit Kerja
IF OBJECT_ID('stg.stg_unit_kerja', 'U') IS NULL
BEGIN
    CREATE TABLE stg.stg_unit_kerja (
        id_unit             VARCHAR(20),
        source_system       VARCHAR(20) DEFAULT 'MASTER',
        kode_unit           VARCHAR(10),
        nama_unit           VARCHAR(100),
        level               INT,
        parent_unit_id      INT,
        kepala_unit_nip     VARCHAR(20),
        email_unit          VARCHAR(100),
        extract_timestamp   DATETIME DEFAULT GETDATE(),
        is_processed        BIT DEFAULT 0
    );
    CREATE INDEX ix_stg_unit_kerja_processed ON stg.stg_unit_kerja (is_processed, extract_timestamp);
END
GO

-- =====================================================
-- ETL LOGGING TABLES
-- =====================================================

IF OBJECT_ID('etl_log.job_execution', 'U') IS NULL
BEGIN
    CREATE TABLE etl_log.job_execution (
        execution_id        INT IDENTITY(1,1) PRIMARY KEY,
        job_name            VARCHAR(100) NOT NULL,
        start_time          DATETIME DEFAULT GETDATE(),
        end_time            DATETIME,
        status              VARCHAR(20) DEFAULT 'Running',  -- Running, Success, Failed, Warning
        rows_extracted      INT DEFAULT 0,
        rows_transformed    INT DEFAULT 0,
        rows_loaded         INT DEFAULT 0,
        error_message       VARCHAR(MAX),
        created_date        DATETIME DEFAULT GETDATE()
    );
    CREATE INDEX ix_job_exec_name ON etl_log.job_execution (job_name);
    CREATE INDEX ix_job_exec_time ON etl_log.job_execution (start_time);
END
GO

IF OBJECT_ID('etl_log.data_quality_checks', 'U') IS NULL
BEGIN
    CREATE TABLE etl_log.data_quality_checks (
        check_id            INT IDENTITY(1,1) PRIMARY KEY,
        execution_id        INT FOREIGN KEY REFERENCES etl_log.job_execution(execution_id),
        check_name          VARCHAR(100) NOT NULL,
        check_timestamp     DATETIME DEFAULT GETDATE(),
        table_name          VARCHAR(100),
        column_name         VARCHAR(100),
        check_result        VARCHAR(20), -- Pass, Fail, Warning
        expected_value      VARCHAR(100),
        actual_value        VARCHAR(100),
        variance_pct        DECIMAL(5,2),
        notes               VARCHAR(MAX)
    );
    CREATE INDEX ix_dq_time ON etl_log.data_quality_checks (check_timestamp);
END
GO

IF OBJECT_ID('etl_log.error_details', 'U') IS NULL
BEGIN
    CREATE TABLE etl_log.error_details (
        error_id            INT IDENTITY(1,1) PRIMARY KEY,
        execution_id        INT FOREIGN KEY REFERENCES etl_log.job_execution(execution_id),
        error_timestamp     DATETIME DEFAULT GETDATE(),
        error_type          VARCHAR(50),  -- Validation, Transformation, Load, System
        severity            VARCHAR(20),  -- Critical, High, Medium, Low
        source_table        VARCHAR(100),
        error_message       VARCHAR(MAX),
        affected_rows       INT,
        resolution_status   VARCHAR(20) DEFAULT 'Open',
        resolved_date       DATETIME
    );
END
GO

-- =====================================================
-- SUCCESS NOTICES
-- =====================================================
PRINT 'Database setup completed successfully.';
PRINT 'Schemas created: stg, dim, fact, etl_log, dw, analytics, reports.';
PRINT 'Staging and logging tables created.';
PRINT 'Next steps: run 02_Create_Dimensions.sql then 03_Create_Facts.sql.';

-- ====================== END OF FILE ======================
