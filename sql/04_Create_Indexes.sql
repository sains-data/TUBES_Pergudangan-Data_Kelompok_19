-- =====================================================
-- 04_Create_Indexes.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Performance Optimization Indexes
-- Engine  : Microsoft SQL Server 2019+
-- Dependencies: 03_Create_Facts.sql must be executed first
-- Author  : Zahra (Kelompok 19)
-- =====================================================

/*
    INDEXING STRATEGY (SQL SERVER):
    1. Clustered Indexes: Created automatically via PRIMARY KEY (IDENTITY) constraints.
    2. Non-Clustered Indexes: For foreign keys and lookups.
    3. Filtered Indexes: Using WHERE clause for specific patterns.
    
    NOTE: SQL Server uses BIT for booleans (1=True, 0=False).
*/

-- =====================================================
-- SECTION 1: CLUSTERED INDEX OPTIMIZATION
-- =====================================================
-- Automatically handled by Primary Keys in previous scripts.

-- =====================================================
-- SECTION 2: NON-CLUSTERED INDEXES FOR FK COLUMNS
-- =====================================================

-- ------------------------------------------------------
-- 2.1 INDEXES ON DIM TABLES (for JOIN optimization)
-- ------------------------------------------------------

-- Dim_Waktu
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_waktu_tanggal' AND object_id = OBJECT_ID('dim.dim_waktu'))
CREATE INDEX ix_dim_waktu_tanggal ON dim.dim_waktu(tanggal);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_waktu_tahun_bulan' AND object_id = OBJECT_ID('dim.dim_waktu'))
CREATE INDEX ix_dim_waktu_tahun_bulan ON dim.dim_waktu(tahun, bulan);

-- Dim_Unit_Kerja
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_unit_kerja_kode' AND object_id = OBJECT_ID('dim.dim_unit_kerja'))
CREATE INDEX ix_dim_unit_kerja_kode ON dim.dim_unit_kerja(kode_unit);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_unit_kerja_parent' AND object_id = OBJECT_ID('dim.dim_unit_kerja'))
CREATE INDEX ix_dim_unit_kerja_parent ON dim.dim_unit_kerja(parent_unit_key) WHERE parent_unit_key IS NOT NULL;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_unit_kerja_active' AND object_id = OBJECT_ID('dim.dim_unit_kerja'))
CREATE INDEX ix_dim_unit_kerja_active ON dim.dim_unit_kerja(is_active);

-- Dim_Pegawai
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_pegawai_unit' AND object_id = OBJECT_ID('dim.dim_pegawai'))
CREATE INDEX ix_dim_pegawai_unit ON dim.dim_pegawai(unit_key) WHERE is_current = 1;

-- Dim_Jenis_Surat
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_jenis_surat_kode' AND object_id = OBJECT_ID('dim.dim_jenis_surat'))
CREATE INDEX ix_dim_jenis_surat_kode ON dim.dim_jenis_surat(kode_jenis_surat);

-- Dim_Jenis_Layanan
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_jenis_layanan_kode' AND object_id = OBJECT_ID('dim.dim_jenis_layanan'))
CREATE INDEX ix_dim_jenis_layanan_kode ON dim.dim_jenis_layanan(kode_jenis_layanan);

-- Dim_Barang
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_barang_kode' AND object_id = OBJECT_ID('dim.dim_barang'))
CREATE INDEX ix_dim_barang_kode ON dim.dim_barang(kode_barang);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_barang_kategori' AND object_id = OBJECT_ID('dim.dim_barang'))
CREATE INDEX ix_dim_barang_kategori ON dim.dim_barang(kategori_barang);

-- Dim_Lokasi
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_lokasi_kode' AND object_id = OBJECT_ID('dim.dim_lokasi'))
CREATE INDEX ix_dim_lokasi_kode ON dim.dim_lokasi(kode_lokasi);

-- ------------------------------------------------------
-- 2.2 ADDITIONAL INDEXES ON FACT_SURAT
-- ------------------------------------------------------

-- FK Indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_unit_penerima' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_unit_penerima ON fact.fact_surat(unit_penerima_key) WHERE unit_penerima_key IS NOT NULL;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_pegawai' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_pegawai ON fact.fact_surat(pegawai_penerima_key) WHERE pegawai_penerima_key IS NOT NULL;

-- Composite
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_tgl_jenis' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_tgl_jenis ON fact.fact_surat(tanggal_key, jenis_surat_key);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_units' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_units ON fact.fact_surat(unit_pengirim_key, unit_penerima_key);

-- ------------------------------------------------------
-- 2.3 ADDITIONAL INDEXES ON FACT_LAYANAN
-- ------------------------------------------------------

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_tgl_selesai' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_tgl_selesai ON fact.fact_layanan(tanggal_selesai_key) WHERE tanggal_selesai_key IS NOT NULL;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_unit_pemohon' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_unit_pemohon ON fact.fact_layanan(unit_pemohon_key);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_unit_pelaksana' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_unit_pelaksana ON fact.fact_layanan(unit_pelaksana_key);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_pegawai_pemohon' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_pegawai_pemohon ON fact.fact_layanan(pegawai_pemohon_key) WHERE pegawai_pemohon_key IS NOT NULL;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_pegawai_pj' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_pegawai_pj ON fact.fact_layanan(pegawai_penanggung_jawab_key) WHERE pegawai_penanggung_jawab_key IS NOT NULL;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_tgl_jenis' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_tgl_jenis ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key);

-- ------------------------------------------------------
-- 2.4 ADDITIONAL INDEXES ON FACT_ASET
-- ------------------------------------------------------

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_aset_snapshot_barang' AND object_id = OBJECT_ID('fact.fact_aset'))
CREATE INDEX ix_fact_aset_snapshot_barang ON fact.fact_aset(tanggal_snapshot_key, barang_key);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_aset_lokasi_unit' AND object_id = OBJECT_ID('fact.fact_aset'))
CREATE INDEX ix_fact_aset_lokasi_unit ON fact.fact_aset(lokasi_key, unit_pemilik_key);

-- =====================================================
-- SECTION 3: FILTERED INDEXES FOR COMMON QUERIES
-- =====================================================

-- ------------------------------------------------------
-- 3.1 FILTERED INDEXES FOR FACT_SURAT
-- ------------------------------------------------------

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_over_sla' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_over_sla ON fact.fact_surat(tanggal_key, jenis_surat_key, durasi_proses_hari) WHERE melewati_sla_flag = 1;

-- [FIXED]: Mengganti NOT IN dengan operator <>
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_in_process' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_in_process ON fact.fact_surat(tanggal_key, status_akhir) 
WHERE status_akhir <> 'Selesai' AND status_akhir <> 'Arsip';

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_digital' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_digital ON fact.fact_surat(tanggal_key, channel) WHERE channel IN ('Email', 'Sistem');

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_surat_with_attachments' AND object_id = OBJECT_ID('fact.fact_surat'))
CREATE INDEX ix_fact_surat_with_attachments ON fact.fact_surat(tanggal_key, jumlah_lampiran) WHERE jumlah_lampiran > 0;

-- ------------------------------------------------------
-- 3.2 FILTERED INDEXES FOR FACT_LAYANAN
-- ------------------------------------------------------

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_over_sla' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_over_sla ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, waktu_selesai_jam) WHERE melewati_sla_flag = 1;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_pending' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_pending ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, status_akhir) WHERE status_akhir IN ('In Progress', 'Pending', 'Waiting');

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_low_rating' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_low_rating ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, rating_kepuasan) WHERE rating_kepuasan < 3.0 AND rating_kepuasan IS NOT NULL;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_with_cost' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_with_cost ON fact.fact_layanan(tanggal_request_key, biaya_layanan) WHERE biaya_layanan > 0;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_layanan_completed' AND object_id = OBJECT_ID('fact.fact_layanan'))
CREATE INDEX ix_fact_layanan_completed ON fact.fact_layanan(tanggal_selesai_key, waktu_selesai_jam, melewati_sla_flag) WHERE tanggal_selesai_key IS NOT NULL AND status_akhir = 'Selesai';

-- ------------------------------------------------------
-- 3.3 FILTERED INDEXES FOR FACT_ASET
-- ------------------------------------------------------

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_aset_active' AND object_id = OBJECT_ID('fact.fact_aset'))
CREATE INDEX ix_fact_aset_active ON fact.fact_aset(tanggal_snapshot_key, barang_key, unit_pemilik_key) WHERE status_pemanfaatan = 'Aktif';

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_aset_damaged' AND object_id = OBJECT_ID('fact.fact_aset'))
CREATE INDEX ix_fact_aset_damaged ON fact.fact_aset(tanggal_snapshot_key, barang_key, kondisi) WHERE kondisi IN ('Rusak Ringan', 'Rusak Berat');

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_aset_high_value' AND object_id = OBJECT_ID('fact.fact_aset'))
CREATE INDEX ix_fact_aset_high_value ON fact.fact_aset(tanggal_snapshot_key, nilai_buku, barang_key) WHERE nilai_buku > 10000000;

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_fact_aset_end_of_life' AND object_id = OBJECT_ID('fact.fact_aset'))
CREATE INDEX ix_fact_aset_end_of_life ON fact.fact_aset(tanggal_snapshot_key, barang_key, umur_tersisa_tahun) WHERE umur_tersisa_tahun <= 1.0;

-- =====================================================
-- SECTION 4: COMPOSITE INDEXES FOR COMPLEX QUERIES
-- =====================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_waktu_hierarchy' AND object_id = OBJECT_ID('dim.dim_waktu'))
CREATE INDEX ix_dim_waktu_hierarchy ON dim.dim_waktu(tahun DESC, bulan DESC, tanggal_key DESC);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_waktu_workdays' AND object_id = OBJECT_ID('dim.dim_waktu'))
CREATE INDEX ix_dim_waktu_workdays ON dim.dim_waktu(tahun, bulan, hari_kerja);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dim_pegawai_unit_current' AND object_id = OBJECT_ID('dim.dim_pegawai'))
CREATE INDEX ix_dim_pegawai_unit_current ON dim.dim_pegawai(unit_key, is_current, status_kepegawaian);

-- =====================================================
-- SECTION 5: PERFORMANCE MONITORING INDEXES
-- =====================================================

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_job_exec_status' AND object_id = OBJECT_ID('etl_log.job_execution'))
CREATE INDEX ix_job_exec_status ON etl_log.job_execution(status, start_time DESC);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_dq_result' AND object_id = OBJECT_ID('etl_log.data_quality_checks'))
CREATE INDEX ix_dq_result ON etl_log.data_quality_checks(check_result, table_name);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'ix_error_severity' AND object_id = OBJECT_ID('etl_log.error_details'))
CREATE INDEX ix_error_severity ON etl_log.error_details(severity, resolution_status, error_timestamp DESC);

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================
PRINT '======================================================';
PRINT '04_Create_Indexes.sql executed successfully';
PRINT '======================================================';
PRINT 'Summary:';
PRINT '- Indexes created for Dimensions, Facts, and ETL logs';
PRINT '- Fixed syntax error on Filtered Index (using <> instead of NOT IN)';
PRINT '';
PRINT 'Next steps:';
PRINT '1. Update Statistics: EXEC sp_updatestats;';
PRINT '2. Proceed to 06_Create_Staging.sql';
PRINT '======================================================';

-- ====================== END OF FILE ======================
