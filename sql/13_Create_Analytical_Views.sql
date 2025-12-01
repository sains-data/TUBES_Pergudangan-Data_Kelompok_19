-- =====================================================
-- 13_Create_Analytical_Views.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Views for Power BI / Tableau Reporting
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- 1. VIEW: Surat Summary
-- =====================================================

DROP VIEW IF EXISTS analytics.vw_surat_summary CASCADE;
CREATE VIEW analytics.vw_surat_summary AS
SELECT 
    dw.tahun,
    dw.bulan_tahun,
    dw.tanggal,
    du.nama_unit AS unit_pengirim,
    djs.nama_jenis_surat,
    fs.status_akhir,
    fs.channel,
    fs.melewati_sla_flag,
    fs.durasi_proses_hari,
    1 AS jumlah_surat
FROM fact.fact_surat fs
INNER JOIN dim.dim_waktu dw ON fs.tanggal_key = dw.tanggal_key
INNER JOIN dim.dim_unit_kerja du ON fs.unit_pengirim_key = du.unit_key
INNER JOIN dim.dim_jenis_surat djs ON fs.jenis_surat_key = djs.jenis_surat_key;

-- =====================================================
-- 2. VIEW: Layanan Performance
-- =====================================================

DROP VIEW IF EXISTS analytics.vw_layanan_performance CASCADE;
CREATE VIEW analytics.vw_layanan_performance AS
SELECT 
    dw.bulan_tahun,
    djl.nama_jenis_layanan,
    djl.kategori_layanan,
    fl.nomor_tiket,
    fl.rating_kepuasan,
    fl.waktu_selesai_jam,
    fl.sla_target_jam,
    fl.melewati_sla_flag,
    CASE WHEN fl.rating_kepuasan >= 4 THEN 'Puas' 
         WHEN fl.rating_kepuasan >= 3 THEN 'Cukup' 
         ELSE 'Kurang' END AS kategori_kepuasan
FROM fact.fact_layanan fl
INNER JOIN dim.dim_waktu dw ON fl.tanggal_request_key = dw.tanggal_key
INNER JOIN dim.dim_jenis_layanan djl ON fl.jenis_layanan_key = djl.jenis_layanan_key;

-- =====================================================
-- 3. VIEW: Aset Overview
-- =====================================================

DROP VIEW IF EXISTS analytics.vw_aset_overview CASCADE;
CREATE VIEW analytics.vw_aset_overview AS
SELECT 
    dw.bulan_tahun AS periode_snapshot,
    du.nama_unit AS unit_pemilik,
    db.nama_barang,
    db.kategori_barang,
    dl.nama_lokasi,
    fa.kondisi,
    fa.nilai_buku,
    fa.nilai_perolehan,
    fa.jumlah_unit
FROM fact.fact_aset fa
INNER JOIN dim.dim_waktu dw ON fa.tanggal_snapshot_key = dw.tanggal_key
INNER JOIN dim.dim_unit_kerja du ON fa.unit_pemilik_key = du.unit_key
INNER JOIN dim.dim_barang db ON fa.barang_key = db.barang_key
INNER JOIN dim.dim_lokasi dl ON fa.lokasi_key = dl.lokasi_key;

-- =====================================================
-- 4. VIEW: Executive Dashboard Summary
-- =====================================================

DROP VIEW IF EXISTS reports.vw_executive_dashboard CASCADE;
CREATE VIEW reports.vw_executive_dashboard AS
SELECT 
    CURRENT_DATE AS report_date,
    (SELECT COUNT(*) FROM fact.fact_surat) AS total_surat,
    (SELECT COUNT(DISTINCT unit_pengirim_key) FROM fact.fact_surat) AS unique_units,
    (SELECT AVG(durasi_proses_hari) FROM fact.fact_surat) AS avg_processing_days,
    (SELECT COUNT(*) FILTER (WHERE melewati_sla_flag = FALSE) FROM fact.fact_surat) AS on_time_count,
    (SELECT COUNT(*) FROM fact.fact_layanan) AS total_layanan,
    (SELECT AVG(rating_kepuasan) FROM fact.fact_layanan WHERE rating_kepuasan IS NOT NULL) AS avg_satisfaction;

-- =====================================================
-- 5. VIEW: Operational Dashboard
-- =====================================================

DROP VIEW IF EXISTS reports.vw_operational_dashboard CASCADE;
CREATE VIEW reports.vw_operational_dashboard AS
SELECT 
    CURRENT_DATE AS report_date,
    (SELECT COUNT(*) FROM fact.fact_surat WHERE DATE(created_at) = CURRENT_DATE) AS today_surat_received,
    (SELECT COUNT(*) FROM fact.fact_surat WHERE DATE(created_at) = CURRENT_DATE AND status_akhir = 'Selesai') AS today_surat_completed,
    (SELECT COUNT(*) FROM fact.fact_layanan WHERE DATE(created_at) = CURRENT_DATE AND status_akhir <> 'Selesai') AS today_pending_layanan,
    (SELECT COUNT(*) FROM fact.fact_layanan WHERE melewati_sla_flag = TRUE AND DATE(created_at) = CURRENT_DATE) AS today_sla_violations;

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

SELECT 'Analytical views created successfully.' as status;
SELECT 'Views available for Power BI / Tableau reporting.' as note;

-- ====================== END OF FILE ======================
