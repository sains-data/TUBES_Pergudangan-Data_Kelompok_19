-- =====================================================
-- 13_Create_Analytical_Views.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Views for Power BI / Tableau Reporting
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Creating Analytical Views...';
GO

-- =====================================================
-- 1. VIEW: Surat Summary
-- =====================================================

CREATE OR ALTER VIEW analytics.vw_Surat_Summary AS
SELECT 
    dw.tahun,
    dw.bulan_tahun,
    dw.tanggal,
    dw.tanggal_key,
    du.unit_key AS unit_pengirim_key,
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
GO

-- =====================================================
-- 2. VIEW: Layanan Performance
-- =====================================================

CREATE OR ALTER VIEW analytics.vw_Layanan_Performance AS
SELECT 
    dw.bulan_tahun,
    dw.tanggal_key AS tanggal_request_key,
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
GO

-- =====================================================
-- 3. VIEW: Aset Overview
-- =====================================================

CREATE OR ALTER VIEW analytics.vw_Aset_Overview AS
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
GO

-- =====================================================
-- 4. VIEW: Executive Dashboard Summary
-- =====================================================

CREATE OR ALTER VIEW reports.vw_Executive_Dashboard AS
SELECT 
    CAST(GETDATE() AS DATE) AS report_date,
    (SELECT COUNT(*) FROM fact.fact_surat) AS total_surat,
    (SELECT COUNT(DISTINCT unit_pengirim_key) FROM fact.fact_surat) AS unique_units,
    (SELECT AVG(durasi_proses_hari) FROM fact.fact_surat) AS avg_processing_days,
    (SELECT COUNT(*) FROM fact.fact_surat WHERE melewati_sla_flag = 0) AS on_time_count,
    (SELECT COUNT(*) FROM fact.fact_layanan) AS total_layanan,
    (SELECT AVG(rating_kepuasan) FROM fact.fact_layanan WHERE rating_kepuasan IS NOT NULL) AS avg_satisfaction;
GO

-- =====================================================
-- 5. VIEW: Operational Dashboard
-- =====================================================

CREATE OR ALTER VIEW reports.vw_Operational_Dashboard AS
SELECT 
    CAST(GETDATE() AS DATE) AS report_date,
    (SELECT COUNT(*) FROM fact.fact_surat WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE)) AS today_surat_received,
    (SELECT COUNT(*) FROM fact.fact_surat WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE) AND status_akhir = 'Selesai') AS today_surat_completed,
    (SELECT COUNT(*) FROM fact.fact_layanan WHERE CAST(created_at AS DATE) = CAST(GETDATE() AS DATE) AND status_akhir <> 'Selesai') AS today_pending_layanan,
    (SELECT COUNT(*) FROM fact.fact_layanan WHERE melewati_sla_flag = 1 AND CAST(created_at AS DATE) = CAST(GETDATE() AS DATE)) AS today_sla_violations;
GO

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

PRINT '>> 13_Create_Analytical_Views.sql executed successfully.';
PRINT '>> Views available for Power BI / Tableau reporting.';
GO
