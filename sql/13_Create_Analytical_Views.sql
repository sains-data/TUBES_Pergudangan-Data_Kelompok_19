-- =====================================================
-- 13_Create_Analytical_Views.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Views for Power BI Reporting
-- Engine  : Microsoft SQL Server 2019+
-- =====================================================

USE datamart_bau_itera;
GO

-- 1. View: Surat Summary (Ringkasan Persuratan)
IF OBJECT_ID('analytics.vw_Surat_Summary', 'V') IS NOT NULL DROP VIEW analytics.vw_Surat_Summary;
GO

CREATE VIEW analytics.vw_Surat_Summary AS
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
GO

-- 2. View: Layanan Performance (Kinerja Layanan)
IF OBJECT_ID('analytics.vw_Layanan_Performance', 'V') IS NOT NULL DROP VIEW analytics.vw_Layanan_Performance;
GO

CREATE VIEW analytics.vw_Layanan_Performance AS
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
GO

-- 3. View: Aset Overview (Inventaris)
IF OBJECT_ID('analytics.vw_Aset_Overview', 'V') IS NOT NULL DROP VIEW analytics.vw_Aset_Overview;
GO

CREATE VIEW analytics.vw_Aset_Overview AS
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

PRINT 'Analytical Views created successfully.';