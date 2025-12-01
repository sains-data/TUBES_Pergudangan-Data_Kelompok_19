-- =====================================================
-- 04_Create_Indexes.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Performance Optimization Indexes
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- SECTION 1: INDEXES ON DIM TABLES
-- =====================================================

-- Dim_Waktu
CREATE INDEX IF NOT EXISTS ix_dim_waktu_tanggal ON dim.dim_waktu(tanggal);
CREATE INDEX IF NOT EXISTS ix_dim_waktu_tahun_bulan ON dim.dim_waktu(tahun, bulan);

-- Dim_Unit_Kerja
CREATE INDEX IF NOT EXISTS ix_dim_unit_kerja_kode ON dim.dim_unit_kerja(kode_unit);
CREATE INDEX IF NOT EXISTS ix_dim_unit_kerja_parent ON dim.dim_unit_kerja(parent_unit_key) WHERE parent_unit_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_dim_unit_kerja_active ON dim.dim_unit_kerja(is_active);

-- Dim_Pegawai
CREATE INDEX IF NOT EXISTS ix_dim_pegawai_unit ON dim.dim_pegawai(unit_key) WHERE is_current = TRUE;

-- Dim_Jenis_Surat
CREATE INDEX IF NOT EXISTS ix_dim_jenis_surat_kode ON dim.dim_jenis_surat(kode_jenis_surat);

-- Dim_Jenis_Layanan
CREATE INDEX IF NOT EXISTS ix_dim_jenis_layanan_kode ON dim.dim_jenis_layanan(kode_jenis_layanan);

-- Dim_Barang
CREATE INDEX IF NOT EXISTS ix_dim_barang_kode ON dim.dim_barang(kode_barang);
CREATE INDEX IF NOT EXISTS ix_dim_barang_kategori ON dim.dim_barang(kategori_barang);

-- Dim_Lokasi
CREATE INDEX IF NOT EXISTS ix_dim_lokasi_kode ON dim.dim_lokasi(kode_lokasi);

-- =====================================================
-- SECTION 2: ADDITIONAL INDEXES ON FACT_SURAT
-- =====================================================

CREATE INDEX IF NOT EXISTS ix_fact_surat_unit_penerima ON fact.fact_surat(unit_penerima_key) WHERE unit_penerima_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_fact_surat_pegawai ON fact.fact_surat(pegawai_penerima_key) WHERE pegawai_penerima_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_fact_surat_tgl_jenis ON fact.fact_surat(tanggal_key, jenis_surat_key);
CREATE INDEX IF NOT EXISTS ix_fact_surat_units ON fact.fact_surat(unit_pengirim_key, unit_penerima_key);

-- =====================================================
-- SECTION 3: ADDITIONAL INDEXES ON FACT_LAYANAN
-- =====================================================

CREATE INDEX IF NOT EXISTS ix_fact_layanan_tgl_selesai ON fact.fact_layanan(tanggal_selesai_key) WHERE tanggal_selesai_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_fact_layanan_unit_pemohon ON fact.fact_layanan(unit_pemohon_key);
CREATE INDEX IF NOT EXISTS ix_fact_layanan_unit_pelaksana ON fact.fact_layanan(unit_pelaksana_key);
CREATE INDEX IF NOT EXISTS ix_fact_layanan_pegawai_pemohon ON fact.fact_layanan(pegawai_pemohon_key) WHERE pegawai_pemohon_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_fact_layanan_pegawai_pj ON fact.fact_layanan(pegawai_penanggung_jawab_key) WHERE pegawai_penanggung_jawab_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_fact_layanan_tgl_jenis ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key);

-- =====================================================
-- SECTION 4: ADDITIONAL INDEXES ON FACT_ASET
-- =====================================================

CREATE INDEX IF NOT EXISTS ix_fact_aset_snapshot_barang ON fact.fact_aset(tanggal_snapshot_key, barang_key);
CREATE INDEX IF NOT EXISTS ix_fact_aset_lokasi_unit ON fact.fact_aset(lokasi_key, unit_pemilik_key);

-- =====================================================
-- SECTION 5: FILTERED INDEXES FOR COMMON QUERIES
-- =====================================================

-- Fact_Surat
CREATE INDEX IF NOT EXISTS ix_fact_surat_over_sla ON fact.fact_surat(tanggal_key, jenis_surat_key, durasi_proses_hari) WHERE melewati_sla_flag = TRUE;
CREATE INDEX IF NOT EXISTS ix_fact_surat_in_process ON fact.fact_surat(tanggal_key, status_akhir) WHERE status_akhir <> 'Selesai' AND status_akhir <> 'Arsip';
CREATE INDEX IF NOT EXISTS ix_fact_surat_digital ON fact.fact_surat(tanggal_key, channel) WHERE channel IN ('Email', 'Sistem');
CREATE INDEX IF NOT EXISTS ix_fact_surat_with_attachments ON fact.fact_surat(tanggal_key, jumlah_lampiran) WHERE jumlah_lampiran > 0;

-- Fact_Layanan
CREATE INDEX IF NOT EXISTS ix_fact_layanan_over_sla ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, waktu_selesai_jam) WHERE melewati_sla_flag = TRUE;
CREATE INDEX IF NOT EXISTS ix_fact_layanan_pending ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, status_akhir) WHERE status_akhir IN ('In Progress', 'Pending', 'Waiting');
CREATE INDEX IF NOT EXISTS ix_fact_layanan_low_rating ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, rating_kepuasan) WHERE rating_kepuasan < 3.0 AND rating_kepuasan IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_fact_layanan_with_cost ON fact.fact_layanan(tanggal_request_key, biaya_layanan) WHERE biaya_layanan > 0;
CREATE INDEX IF NOT EXISTS ix_fact_layanan_completed ON fact.fact_layanan(tanggal_selesai_key, waktu_selesai_jam, melewati_sla_flag) WHERE tanggal_selesai_key IS NOT NULL AND status_akhir = 'Selesai';

-- Fact_Aset
CREATE INDEX IF NOT EXISTS ix_fact_aset_active ON fact.fact_aset(tanggal_snapshot_key, barang_key, unit_pemilik_key) WHERE status_pemanfaatan = 'Aktif';
CREATE INDEX IF NOT EXISTS ix_fact_aset_damaged ON fact.fact_aset(tanggal_snapshot_key, barang_key, kondisi) WHERE kondisi IN ('Rusak Ringan', 'Rusak Berat');
CREATE INDEX IF NOT EXISTS ix_fact_aset_high_value ON fact.fact_aset(tanggal_snapshot_key, nilai_buku, barang_key) WHERE nilai_buku > 10000000;
CREATE INDEX IF NOT EXISTS ix_fact_aset_end_of_life ON fact.fact_aset(tanggal_snapshot_key, barang_key, umur_tersisa_tahun) WHERE umur_tersisa_tahun <= 1.0;

-- =====================================================
-- SECTION 6: COMPOSITE INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS ix_dim_waktu_hierarchy ON dim.dim_waktu(tahun DESC, bulan DESC, tanggal_key DESC);
CREATE INDEX IF NOT EXISTS ix_dim_waktu_workdays ON dim.dim_waktu(tahun, bulan, hari_kerja);
CREATE INDEX IF NOT EXISTS ix_dim_pegawai_unit_current ON dim.dim_pegawai(unit_key, is_current, status_kepegawaian);

-- =====================================================
-- SECTION 7: PERFORMANCE MONITORING INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS ix_job_exec_status ON etl_log.job_execution(status, start_time DESC);
CREATE INDEX IF NOT EXISTS ix_dq_result ON etl_log.data_quality_checks(check_result, table_name);
CREATE INDEX IF NOT EXISTS ix_error_severity ON etl_log.error_details(severity, resolution_status, error_timestamp DESC);

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

SELECT '04_Create_Indexes.sql executed successfully' as status;
SELECT 'All indexes created for Dimensions, Facts, and ETL logs' as summary;

-- ====================== END OF FILE ======================
