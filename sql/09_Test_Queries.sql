-- =====================================================
-- 09_Test_Queries.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Performance Testing & Analytical Queries
-- Engine  : Microsoft SQL Server 2019+
-- =====================================================

/*
    INSTRUCTIONS FOR PERFORMANCE TESTING:
    1. Execute "SET STATISTICS TIME ON" to measure execution time.
    2. Run each query and record the "CPU time" and "Elapsed time".
    3. Capture the "Execution Plan" (Ctrl+M) to show index usage.
*/

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

-- =====================================================
-- SCENARIO 1: Simple Aggregation (Total Surat per Bulan)
-- =====================================================
PRINT '--- TEST 1: Monthly Trend Analysis ---';

SELECT 
    dw.tahun,
    dw.bulan_tahun,
    COUNT(fs.surat_key) AS total_surat,
    SUM(fs.jumlah_lampiran) AS total_lampiran
FROM fact.fact_surat fs
INNER JOIN dim.dim_waktu dw ON fs.tanggal_key = dw.tanggal_key
GROUP BY dw.tahun, dw.bulan, dw.bulan_tahun
ORDER BY dw.tahun, dw.bulan;
GO

-- =====================================================
-- SCENARIO 2: Complex Join (Analisis Surat per Unit Kerja)
-- =====================================================
PRINT '--- TEST 2: Unit Kerja Performance ---';

SELECT 
    du.nama_unit,
    COUNT(fs.surat_key) AS total_surat_dikirim,
    AVG(fs.durasi_proses_hari) AS rata_rata_durasi_hari,
    SUM(CASE WHEN fs.melewati_sla_flag = 1 THEN 1 ELSE 0 END) AS surat_telat
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

SELECT TOP 100
    dw.tanggal,
    djl.nama_jenis_layanan,
    du.nama_unit AS pemohon,
    fl.nomor_tiket,
    fl.rating_kepuasan
FROM fact.fact_layanan fl
INNER JOIN dim.dim_waktu dw ON fl.tanggal_request_key = dw.tanggal_key
INNER JOIN dim.dim_jenis_layanan djl ON fl.jenis_layanan_key = djl.jenis_layanan_key
INNER JOIN dim.dim_unit_kerja du ON fl.unit_pemohon_key = du.unit_key
WHERE fl.rating_kepuasan < 3.0 -- Mencari layanan dengan rating rendah
ORDER BY dw.tanggal DESC;
GO

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
