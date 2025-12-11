-- =====================================================
-- 09_Test_Queries.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Performance Testing & Analytical Queries
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

/*
    INSTRUCTIONS FOR PERFORMANCE TESTING:
    1. Run the script.
    2. Check the 'Messages' tab in SSMS for "CPU time" and "Elapsed time".
    3. Click 'Include Actual Execution Plan' (Ctrl+M) before running to see index usage.
*/

USE datamart_bau_itera;
GO

-- Enable Performance Statistics
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

PRINT '>>> STARTING PERFORMANCE TEST SCENARIOS...';
GO

-- =====================================================
-- SCENARIO 1: Simple Aggregation (Total Surat per Bulan)
-- =====================================================

PRINT '--- TEST 1: Monthly Trend Analysis ---';

SELECT 
    dw.tahun,
    dw.bulan_tahun,
    COUNT(fs.surat_key) AS total_surat
FROM fact.fact_surat fs
INNER JOIN dim.dim_waktu dw ON fs.tanggal_key = dw.tanggal_key
GROUP BY dw.tahun, dw.bulan_tahun
ORDER BY dw.tahun, dw.bulan_tahun;
GO

-- =====================================================
-- SCENARIO 2: Complex Join (Analisis Surat per Unit Kerja)
-- =====================================================

PRINT '--- TEST 2: Unit Kerja Performance ---';

SELECT 
    du.nama_unit,
    COUNT(fs.surat_key) AS total_surat_dikirim,
    -- Menggunakan kolom durasi_proses_hari yang sudah ada di Fact Table
    AVG(CAST(fs.durasi_proses_hari AS DECIMAL(10,2))) AS rata_rata_durasi_hari
FROM fact.fact_surat fs
INNER JOIN dim.dim_unit_kerja du ON fs.unit_pengirim_key = du.unit_key
WHERE fs.status_akhir = 'Selesai'
GROUP BY du.nama_unit
ORDER BY total_surat_dikirim DESC;
GO

-- =====================================================
-- SCENARIO 3: Drill-Down (Detail Layanan)
-- =====================================================

PRINT '--- TEST 3: Layanan Detail Drill-Down ---';

SELECT TOP 100 -- LIMIT diganti TOP
    dw.tanggal,
    djl.nama_jenis_layanan,
    du.nama_unit AS pemohon,
    fl.nomor_tiket,
    fl.rating_kepuasan
FROM fact.fact_layanan fl
INNER JOIN dim.dim_waktu dw ON fl.tanggal_request_key = dw.tanggal_key
INNER JOIN dim.dim_jenis_layanan djl ON fl.jenis_layanan_key = djl.jenis_layanan_key
INNER JOIN dim.dim_unit_kerja du ON fl.unit_pemohon_key = du.unit_key
WHERE fl.rating_kepuasan < 3.0
ORDER BY dw.tanggal DESC;
GO

-- =====================================================
-- SCENARIO 4: Aggregation with Filter
-- =====================================================

PRINT '--- TEST 4: Asset Overview ---';

SELECT 
    dl.nama_lokasi,
    COUNT(fa.aset_snapshot_key) AS total_aset, -- aset_key diganti aset_snapshot_key (sesuai script 03)
    CAST(SUM(fa.nilai_buku) AS DECIMAL(15,2)) AS total_nilai_buku
FROM fact.fact_aset fa
INNER JOIN dim.dim_lokasi dl ON fa.lokasi_key = dl.lokasi_key
WHERE fa.status_pemanfaatan = 'Aktif'
GROUP BY dl.nama_lokasi
ORDER BY total_nilai_buku DESC;
GO

-- =====================================================
-- SCENARIO 5: Time Series Analysis
-- =====================================================

PRINT '--- TEST 5: Time Series Performance ---';

SELECT 
    dw.tahun,
    dw.bulan_tahun,
    COUNT(fl.layanan_key) AS total_layanan,
    ROUND(AVG(CAST(fl.rating_kepuasan AS DECIMAL(10,2))), 2) AS avg_rating,
    SUM(CASE WHEN fl.melewati_sla_flag = 1 THEN 1 ELSE 0 END) AS count_sla_violation -- TRUE diganti 1
FROM fact.fact_layanan fl
INNER JOIN dim.dim_waktu dw ON fl.tanggal_request_key = dw.tanggal_key
GROUP BY dw.tahun, dw.bulan, dw.bulan_tahun
ORDER BY dw.tahun DESC, dw.bulan DESC;
GO

-- =====================================================
-- SCENARIO 6: Cross-Domain Join (Surat & Layanan)
-- =====================================================

PRINT '--- TEST 6: Cross-Domain Analysis ---';

SELECT TOP 50
    du.nama_unit,
    COUNT(DISTINCT fs.surat_key) AS total_surat,
    COUNT(DISTINCT fl.layanan_key) AS total_layanan,
    ROUND(AVG(CAST(fl.rating_kepuasan AS DECIMAL(10,2))), 2) AS avg_layanan_rating
FROM dim.dim_unit_kerja du
LEFT JOIN fact.fact_surat fs ON du.unit_key = fs.unit_pengirim_key
LEFT JOIN fact.fact_layanan fl ON du.unit_key = fl.unit_pemohon_key
GROUP BY du.nama_unit
ORDER BY total_surat DESC;
GO

-- =====================================================
-- PERFORMANCE SUMMARY
-- =====================================================

-- Disable statistics to clean up output
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

PRINT '>> All test queries executed successfully.';
GO
