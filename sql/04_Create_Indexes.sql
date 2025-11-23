
/*
    INDEXING STRATEGY:
    1. Clustered Indexes (via PRIMARY KEY) - sudah ada di fact tables
    2. Non-Clustered Indexes - untuk foreign keys dan common filters
    3. Filtered Indexes - untuk query patterns yang spesifik
    
    NOTE: PostgreSQL tidak memiliki konsep "clustered index" seperti SQL Server.
    PRIMARY KEY otomatis membuat UNIQUE INDEX. Kita gunakan CLUSTER command
    untuk physical ordering jika diperlukan.
*/

-- =====================================================
-- SECTION 1: CLUSTERED INDEX OPTIMIZATION
-- =====================================================
-- Di PostgreSQL, PRIMARY KEY otomatis membuat index.
-- Kita bisa melakukan CLUSTER untuk physical ordering berdasarkan index tertentu.
-- CLUSTER berguna untuk table yang sering di-query berdasarkan range tanggal.

-- Cluster Fact_Surat berdasarkan tanggal untuk time-series queries
-- CLUSTER fact.fact_surat USING fact_surat_pkey;
-- NOTE: CLUSTER adalah operasi one-time. Jalankan setelah bulk load.

-- Cluster Fact_Layanan berdasarkan tanggal request
-- CLUSTER fact.fact_layanan USING fact_layanan_pkey;

-- Cluster Fact_Aset berdasarkan tanggal snapshot
-- CLUSTER fact.fact_aset USING fact_aset_pkey;

-- =====================================================
-- SECTION 2: NON-CLUSTERED INDEXES FOR FK COLUMNS
-- =====================================================

-- ------------------------------------------------------
-- 2.1 INDEXES ON DIM TABLES (untuk JOIN optimization)
-- ------------------------------------------------------

-- Dim_Waktu - Natural Key Index
CREATE INDEX IF NOT EXISTS ix_dim_waktu_tanggal 
ON dim.dim_waktu(tanggal);

CREATE INDEX IF NOT EXISTS ix_dim_waktu_tahun_bulan 
ON dim.dim_waktu(tahun, bulan);

-- Dim_Unit_Kerja - Business Key & Hierarchy
CREATE INDEX IF NOT EXISTS ix_dim_unit_kerja_kode 
ON dim.dim_unit_kerja(kode_unit);

CREATE INDEX IF NOT EXISTS ix_dim_unit_kerja_parent 
ON dim.dim_unit_kerja(parent_unit_key) 
WHERE parent_unit_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_dim_unit_kerja_active 
ON dim.dim_unit_kerja(is_active);

-- Dim_Pegawai - Business Key & SCD
-- Index sudah ada di 02_Create_Dimensions.sql:
-- ix_dim_pegawai_nip, ix_dim_pegawai_current

CREATE INDEX IF NOT EXISTS ix_dim_pegawai_unit 
ON dim.dim_pegawai(unit_key) 
WHERE is_current = TRUE;

-- Dim_Jenis_Surat - Business Key
CREATE INDEX IF NOT EXISTS ix_dim_jenis_surat_kode 
ON dim.dim_jenis_surat(kode_jenis_surat);

-- Dim_Jenis_Layanan - Business Key
CREATE INDEX IF NOT EXISTS ix_dim_jenis_layanan_kode 
ON dim.dim_jenis_layanan(kode_jenis_layanan);

-- Dim_Barang - Business Key
CREATE INDEX IF NOT EXISTS ix_dim_barang_kode 
ON dim.dim_barang(kode_barang);

CREATE INDEX IF NOT EXISTS ix_dim_barang_kategori 
ON dim.dim_barang(kategori_barang);

-- Dim_Lokasi - Business Key
CREATE INDEX IF NOT EXISTS ix_dim_lokasi_kode 
ON dim.dim_lokasi(kode_lokasi);

-- ------------------------------------------------------
-- 2.2 ADDITIONAL INDEXES ON FACT_SURAT
-- ------------------------------------------------------

-- FK Indexes (basic) - sudah ada sebagian di 03_Create_Facts.sql
-- Tambahan untuk optimasi JOIN dengan multiple dimensions

CREATE INDEX IF NOT EXISTS ix_fact_surat_unit_penerima 
ON fact.fact_surat(unit_penerima_key) 
WHERE unit_penerima_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_fact_surat_pegawai 
ON fact.fact_surat(pegawai_penerima_key) 
WHERE pegawai_penerima_key IS NOT NULL;

-- Composite index untuk analisis berdasarkan periode & jenis
CREATE INDEX IF NOT EXISTS ix_fact_surat_tgl_jenis 
ON fact.fact_surat(tanggal_key, jenis_surat_key);

-- Index untuk analisis unit
CREATE INDEX IF NOT EXISTS ix_fact_surat_units 
ON fact.fact_surat(unit_pengirim_key, unit_penerima_key);

-- ------------------------------------------------------
-- 2.3 ADDITIONAL INDEXES ON FACT_LAYANAN
-- ------------------------------------------------------

-- FK Indexes untuk dimension lookups
CREATE INDEX IF NOT EXISTS ix_fact_layanan_tgl_selesai 
ON fact.fact_layanan(tanggal_selesai_key) 
WHERE tanggal_selesai_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_fact_layanan_unit_pemohon 
ON fact.fact_layanan(unit_pemohon_key);

CREATE INDEX IF NOT EXISTS ix_fact_layanan_unit_pelaksana 
ON fact.fact_layanan(unit_pelaksana_key);

CREATE INDEX IF NOT EXISTS ix_fact_layanan_pegawai_pemohon 
ON fact.fact_layanan(pegawai_pemohon_key) 
WHERE pegawai_pemohon_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_fact_layanan_pegawai_pj 
ON fact.fact_layanan(pegawai_penanggung_jawab_key) 
WHERE pegawai_penanggung_jawab_key IS NOT NULL;

-- Composite index untuk time-series analysis
CREATE INDEX IF NOT EXISTS ix_fact_layanan_tgl_jenis 
ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key);

-- ------------------------------------------------------
-- 2.4 ADDITIONAL INDEXES ON FACT_ASET
-- ------------------------------------------------------

-- FK Indexes (basic) - sudah ada di 03_Create_Facts.sql
-- Composite indexes untuk snapshot analysis

CREATE INDEX IF NOT EXISTS ix_fact_aset_snapshot_barang 
ON fact.fact_aset(tanggal_snapshot_key, barang_key);

CREATE INDEX IF NOT EXISTS ix_fact_aset_lokasi_unit 
ON fact.fact_aset(lokasi_key, unit_pemilik_key);

-- =====================================================
-- SECTION 3: FILTERED INDEXES FOR COMMON QUERIES
-- =====================================================

-- ------------------------------------------------------
-- 3.1 FILTERED INDEXES FOR FACT_SURAT
-- ------------------------------------------------------

-- Index untuk surat yang melewati SLA (untuk monitoring)
CREATE INDEX IF NOT EXISTS ix_fact_surat_over_sla 
ON fact.fact_surat(tanggal_key, jenis_surat_key, durasi_proses_hari) 
WHERE melewati_sla_flag = TRUE;

-- Index untuk surat yang sedang diproses (status bukan 'Selesai')
CREATE INDEX IF NOT EXISTS ix_fact_surat_in_process 
ON fact.fact_surat(tanggal_key, status_akhir) 
WHERE status_akhir NOT IN ('Selesai', 'Arsip');

-- Index untuk surat digital vs fisik
CREATE INDEX IF NOT EXISTS ix_fact_surat_digital 
ON fact.fact_surat(tanggal_key, channel) 
WHERE channel IN ('Email', 'Sistem');

-- Index untuk surat dengan lampiran
CREATE INDEX IF NOT EXISTS ix_fact_surat_with_attachments 
ON fact.fact_surat(tanggal_key, jumlah_lampiran) 
WHERE jumlah_lampiran > 0;

-- ------------------------------------------------------
-- 3.2 FILTERED INDEXES FOR FACT_LAYANAN
-- ------------------------------------------------------

-- Index untuk layanan yang melewati SLA
CREATE INDEX IF NOT EXISTS ix_fact_layanan_over_sla 
ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, waktu_selesai_jam) 
WHERE melewati_sla_flag = TRUE;

-- Index untuk layanan yang belum selesai
CREATE INDEX IF NOT EXISTS ix_fact_layanan_pending 
ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, status_akhir) 
WHERE status_akhir IN ('In Progress', 'Pending', 'Waiting');

-- Index untuk layanan dengan rating rendah (< 3.0)
CREATE INDEX IF NOT EXISTS ix_fact_layanan_low_rating 
ON fact.fact_layanan(tanggal_request_key, jenis_layanan_key, rating_kepuasan) 
WHERE rating_kepuasan < 3.0 AND rating_kepuasan IS NOT NULL;

-- Index untuk layanan dengan biaya
CREATE INDEX IF NOT EXISTS ix_fact_layanan_with_cost 
ON fact.fact_layanan(tanggal_request_key, biaya_layanan) 
WHERE biaya_layanan > 0;

-- Index untuk analisis SLA performance (completed only)
CREATE INDEX IF NOT EXISTS ix_fact_layanan_completed 
ON fact.fact_layanan(tanggal_selesai_key, waktu_selesai_jam, melewati_sla_flag) 
WHERE tanggal_selesai_key IS NOT NULL AND status_akhir = 'Selesai';

-- ------------------------------------------------------
-- 3.3 FILTERED INDEXES FOR FACT_ASET
-- ------------------------------------------------------

-- Index untuk aset aktif
CREATE INDEX IF NOT EXISTS ix_fact_aset_active 
ON fact.fact_aset(tanggal_snapshot_key, barang_key, unit_pemilik_key) 
WHERE status_pemanfaatan = 'Aktif';

-- Index untuk aset dengan kondisi rusak
CREATE INDEX IF NOT EXISTS ix_fact_aset_damaged 
ON fact.fact_aset(tanggal_snapshot_key, barang_key, kondisi) 
WHERE kondisi IN ('Rusak Ringan', 'Rusak Berat');

-- Index untuk aset dengan nilai tinggi (> 10 juta)
CREATE INDEX IF NOT EXISTS ix_fact_aset_high_value 
ON fact.fact_aset(tanggal_snapshot_key, nilai_buku, barang_key) 
WHERE nilai_buku > 10000000;

-- Index untuk aset yang mendekati akhir umur ekonomis
CREATE INDEX IF NOT EXISTS ix_fact_aset_end_of_life 
ON fact.fact_aset(tanggal_snapshot_key, barang_key, umur_tersisa_tahun) 
WHERE umur_tersisa_tahun <= 1.0;

-- =====================================================
-- SECTION 4: COMPOSITE INDEXES FOR COMPLEX QUERIES
-- =====================================================

-- Index untuk query berdasarkan hierarki waktu (tahun, bulan, tanggal)
CREATE INDEX IF NOT EXISTS ix_dim_waktu_hierarchy 
ON dim.dim_waktu(tahun DESC, bulan DESC, tanggal_key DESC);

-- Index untuk query periode dan hari kerja
CREATE INDEX IF NOT EXISTS ix_dim_waktu_workdays 
ON dim.dim_waktu(tahun, bulan, hari_kerja);

-- Composite untuk analisis unit & pegawai
CREATE INDEX IF NOT EXISTS ix_dim_pegawai_unit_current 
ON dim.dim_pegawai(unit_key, is_current, status_kepegawaian);

-- =====================================================
-- SECTION 5: PERFORMANCE MONITORING INDEXES
-- =====================================================

-- Index untuk ETL metadata lookup by table name
-- (sudah ada di 01_Create_Database.sql: ix_etl_metadata_table_name)

-- Index untuk job execution history
CREATE INDEX IF NOT EXISTS ix_job_exec_status 
ON etl_log.job_execution(status, start_time DESC);

-- Index untuk data quality checks
CREATE INDEX IF NOT EXISTS ix_dq_result 
ON etl_log.data_quality_checks(check_result, table_name);

-- Index untuk error tracking
CREATE INDEX IF NOT EXISTS ix_error_severity 
ON etl_log.error_details(severity, resolution_status, error_timestamp DESC);

-- =====================================================
-- VALIDATION QUERIES
-- =====================================================

-- Total indexes created
-- SELECT 
--     schemaname,
--     tablename,
--     COUNT(*) as index_count
-- FROM pg_indexes
-- WHERE schemaname IN ('dim', 'fact', 'etl_log')
-- GROUP BY schemaname, tablename
-- ORDER BY schemaname, tablename;

-- Index sizes
-- SELECT
--     schemaname || '.' || tablename AS table_name,
--     indexname,
--     pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
-- FROM pg_stat_user_indexes
-- WHERE schemaname IN ('dim', 'fact', 'etl_log')
-- ORDER BY pg_relation_size(indexrelid) DESC;

-- =====================================================
-- MAINTENANCE RECOMMENDATIONS
-- =====================================================

/*
REGULAR MAINTENANCE:

1. ANALYZE tables setelah bulk load:
   ANALYZE dim.dim_waktu;
   ANALYZE dim.dim_unit_kerja;
   ANALYZE dim.dim_pegawai;
   ANALYZE fact.fact_surat;
   ANALYZE fact.fact_layanan;
   ANALYZE fact.fact_aset;

2. VACUUM untuk reclaim space:
   VACUUM ANALYZE fact.fact_surat;
   VACUUM ANALYZE fact.fact_layanan;
   VACUUM ANALYZE fact.fact_aset;

3. REINDEX jika performa menurun:
   REINDEX TABLE fact.fact_surat;
   REINDEX TABLE fact.fact_layanan;
   REINDEX TABLE fact.fact_aset;

4. Monitor index usage:
   SELECT 
       schemaname || '.' || tablename AS table,
       indexname,
       idx_scan as index_scans,
       idx_tup_read as tuples_read,
       idx_tup_fetch as tuples_fetched
   FROM pg_stat_user_indexes
   WHERE schemaname IN ('dim', 'fact')
   ORDER BY idx_scan DESC;
*/

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '======================================================';
    RAISE NOTICE '04_Create_Indexes.sql executed successfully';
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'Summary:';
    RAISE NOTICE '- Dimension table indexes: Created for business keys and lookups';
    RAISE NOTICE '- Fact table FK indexes: 8+ additional indexes for JOINs';
    RAISE NOTICE '- Filtered indexes: 13+ indexes for common query patterns';
    RAISE NOTICE '- Composite indexes: Multi-column indexes for complex queries';
    RAISE NOTICE '- ETL/Logging indexes: Performance monitoring indexes';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Run ANALYZE on all tables after initial data load';
    RAISE NOTICE '2. Monitor index usage with pg_stat_user_indexes';
    RAISE NOTICE '3. Proceed to 06_Create_Staging.sql';
    RAISE NOTICE '======================================================';
END $$;

-- ====================== END OF FILE ======================

