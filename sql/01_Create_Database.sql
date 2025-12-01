-- =====================================================
-- 01_Create_Database.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Data Mart Database Creation Script
-- Target: PostgreSQL 14+
-- =====================================================

/*
    Project : Data Mart Biro Akademik Umum ITERA
    Purpose : Create schemas, metadata, staging & logging tables, and indexes
    Engine  : PostgreSQL 14+
    Notes   : Uses PostgreSQL syntax
*/

-- =====================================================
-- SCHEMAS
-- =====================================================

CREATE SCHEMA IF NOT EXISTS stg;
CREATE SCHEMA IF NOT EXISTS dim;
CREATE SCHEMA IF NOT EXISTS fact;
CREATE SCHEMA IF NOT EXISTS etl_log;
CREATE SCHEMA IF NOT EXISTS dw;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS reports;
CREATE SCHEMA IF NOT EXISTS etl;

-- =====================================================
-- DW METADATA
-- =====================================================

CREATE TABLE IF NOT EXISTS dw.etl_metadata (
    metadata_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL UNIQUE,
    last_load_date TIMESTAMP,
    last_load_status VARCHAR(20),
    total_records BIGINT,
    load_duration_minutes NUMERIC(10,2),
    last_error VARCHAR(500),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed entries
INSERT INTO dw.etl_metadata (table_name, last_load_status) VALUES
('dim_waktu', 'Pending'),
('dim_unit_kerja', 'Pending'),
('dim_pegawai', 'Pending'),
('dim_jenis_surat', 'Pending'),
('dim_barang', 'Pending'),
('dim_lokasi', 'Pending'),
('dim_jenis_layanan', 'Pending'),
('fact_surat', 'Pending'),
('fact_aset', 'Pending'),
('fact_layanan', 'Pending')
ON CONFLICT (table_name) DO NOTHING;

-- Index
CREATE INDEX IF NOT EXISTS ix_etl_metadata_table_name ON dw.etl_metadata (table_name);

-- =====================================================
-- STAGING TABLES (SOURCE-SPECIFIC)
-- =====================================================

-- SIMASTER - Surat
CREATE TABLE IF NOT EXISTS stg.stg_simaster_surat (
    id_surat VARCHAR(50),
    source_system VARCHAR(20) DEFAULT 'SIMASTER',
    nomor_surat VARCHAR(50),
    tanggal_diterima DATE,
    pengirim VARCHAR(200),
    perihal TEXT,
    jenis_surat_id INT,
    status VARCHAR(20),
    extract_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_processed BOOLEAN DEFAULT FALSE,
    raw_data JSONB
);
CREATE INDEX IF NOT EXISTS ix_stg_surat_processed ON stg.stg_simaster_surat (is_processed, extract_timestamp);
CREATE INDEX IF NOT EXISTS ix_stg_surat_nomor ON stg.stg_simaster_surat (nomor_surat);

-- INVENTARIS - Aset
CREATE TABLE IF NOT EXISTS stg.stg_inventaris (
    id_barang VARCHAR(50),
    source_system VARCHAR(20) DEFAULT 'INVENTARIS',
    kode_barang VARCHAR(30),
    nama_barang VARCHAR(200),
    kategori VARCHAR(50),
    tanggal_pengadaan DATE,
    nilai_perolehan NUMERIC(15,2),
    kondisi VARCHAR(20),
    lokasi_id INT,
    unit_kerja_id INT,
    extract_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_processed BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS ix_stg_inventaris_processed ON stg.stg_inventaris (is_processed, extract_timestamp);
CREATE INDEX IF NOT EXISTS ix_stg_inventaris_kode ON stg.stg_inventaris (kode_barang);

-- SIMPEG - Kepegawaian
CREATE TABLE IF NOT EXISTS stg.stg_simpeg (
    nip VARCHAR(20),
    source_system VARCHAR(20) DEFAULT 'SIMPEG',
    nama VARCHAR(100),
    jabatan VARCHAR(100),
    unit_kerja_id INT,
    tanggal_masuk DATE,
    status_kepegawaian VARCHAR(30),
    email VARCHAR(100),
    no_hp VARCHAR(50),
    extract_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_processed BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS ix_stg_simpeg_processed ON stg.stg_simpeg (is_processed, extract_timestamp);
CREATE INDEX IF NOT EXISTS ix_stg_simpeg_nip ON stg.stg_simpeg (nip);

-- LAYANAN - Service Requests
CREATE TABLE IF NOT EXISTS stg.stg_layanan (
    id_permintaan VARCHAR(50),
    source_system VARCHAR(20) DEFAULT 'LAYANAN',
    nomor_tiket VARCHAR(30),
    pemohon_nama VARCHAR(100),
    jenis_layanan_id INT,
    timestamp_submit TIMESTAMP,
    tanggal_selesai TIMESTAMP,
    status_penyelesaian VARCHAR(20),
    rating_kepuasan NUMERIC(2,1),
    extract_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_processed BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS ix_stg_layanan_processed ON stg.stg_layanan (is_processed, extract_timestamp);

-- MONITORING - Kinerja
CREATE TABLE IF NOT EXISTS stg.stg_monitoring (
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
    extract_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_processed BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS ix_stg_monitoring_processed ON stg.stg_monitoring (is_processed, extract_timestamp);

-- MASTER - Unit Kerja
CREATE TABLE IF NOT EXISTS stg.stg_unit_kerja (
    id_unit VARCHAR(20),
    source_system VARCHAR(20) DEFAULT 'MASTER',
    kode_unit VARCHAR(10),
    nama_unit VARCHAR(100),
    level INT,
    parent_unit_id INT,
    kepala_unit_nip VARCHAR(20),
    email_unit VARCHAR(100),
    extract_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_processed BOOLEAN DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS ix_stg_unit_kerja_processed ON stg.stg_unit_kerja (is_processed, extract_timestamp);

-- =====================================================
-- ETL LOGGING TABLES
-- =====================================================

CREATE TABLE IF NOT EXISTS etl_log.job_execution (
    execution_id SERIAL PRIMARY KEY,
    job_name VARCHAR(100) NOT NULL,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'Running',
    rows_extracted INT DEFAULT 0,
    rows_transformed INT DEFAULT 0,
    rows_loaded INT DEFAULT 0,
    error_message TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS ix_job_exec_name ON etl_log.job_execution (job_name);
CREATE INDEX IF NOT EXISTS ix_job_exec_time ON etl_log.job_execution (start_time);

CREATE TABLE IF NOT EXISTS etl_log.data_quality_checks (
    check_id SERIAL PRIMARY KEY,
    execution_id INT REFERENCES etl_log.job_execution(execution_id),
    check_name VARCHAR(100) NOT NULL,
    check_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    table_name VARCHAR(100),
    column_name VARCHAR(100),
    check_result VARCHAR(20),
    expected_value VARCHAR(100),
    actual_value VARCHAR(100),
    variance_pct NUMERIC(5,2),
    notes TEXT
);
CREATE INDEX IF NOT EXISTS ix_dq_time ON etl_log.data_quality_checks (check_timestamp);

CREATE TABLE IF NOT EXISTS etl_log.error_details (
    error_id SERIAL PRIMARY KEY,
    execution_id INT REFERENCES etl_log.job_execution(execution_id),
    error_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    error_type VARCHAR(50),
    severity VARCHAR(20),
    source_table VARCHAR(100),
    error_message TEXT,
    affected_rows INT,
    resolution_status VARCHAR(20) DEFAULT 'Open',
    resolved_date TIMESTAMP
);

-- =====================================================
-- SUCCESS NOTICES
-- =====================================================

RAISE NOTICE 'Database setup completed successfully.';
RAISE NOTICE 'Schemas created: stg, dim, fact, etl_log, dw, analytics, reports.';
RAISE NOTICE 'Staging and logging tables created.';
RAISE NOTICE 'Next steps: run 02_Create_Dimensions.sql then 03_Create_Facts.sql.';

-- ====================== END OF FILE ======================
