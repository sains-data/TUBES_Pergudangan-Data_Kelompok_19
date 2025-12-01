-- =====================================================
-- 09_Test_Queries.sql
-- POSTGRESQL VERSION (Converted from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Performance Testing & Analytical Queries
-- Engine  : PostgreSQL 14+
-- =====================================================

/*
    INSTRUCTIONS FOR PERFORMANCE TESTING:
    1. Run each query and note the execution time (shown at bottom)
    2. Use EXPLAIN ANALYZE to see the execution plan
    3. Check index usage and query performance
*/

-- =====================================================
-- SCENARIO 1: Simple Aggregation (Total Surat per Bulan)
-- =====================================================

RAISE NOTICE '--- TEST 1: Monthly Trend Analysis ---';

EXPLAIN ANALYZE
SELECT 
    dw.tahun,
    dw.bulan_tahun,
    COUNT(fs.surat_key) AS total_surat
FROM fact.fact_surat fs
INNER JOIN dim.dim_waktu dw ON fs.tanggal_key = dw.tanggal_key
GROUP BY dw.tahun, dw.bulan_tahun
ORDER BY dw.tahun, dw.bulan_tahun;

-- =====================================================
-- SCENARIO 2: Complex Join (Analisis Surat per Unit Kerja)
-- =====================================================

RAISE NOTICE '--- TEST 2: Unit Kerja Performance ---';

EXPLAIN ANALYZE
SELECT 
    du.nama_unit,
    COUNT(fs.surat_key) AS total_surat_dikirim,
    AVG(CAST(EXTRACT(EPOCH FROM (fs.updated_timestamp - fs.created_at)) / 86400 AS NUMERIC(10,2))) AS rata_rata_durasi_hari
FROM fact.fact_surat fs
INNER JOIN dim.dim_unit_kerja du ON fs.unit_pengirim_key = du.unit_key
WHERE fs.status_akhir = 'Selesai'
GROUP BY du.nama_unit
ORDER BY total_surat_dikirim DESC;

-- =====================================================
-- SCENARIO 3: Drill-Down (Detail Layanan)
-- =====================================================

RAISE NOTICE '--- TEST 3: Layanan Detail Drill-Down ---';

EXPLAIN ANALYZE
SELECT 
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
ORDER BY dw.tanggal DESC
LIMIT 100;

-- =====================================================
-- SCENARIO 4: Aggregation with Filter
-- =====================================================

RAISE NOTICE '--- TEST 4: Asset Overview ---';

EXPLAIN ANALYZE
SELECT 
    dl.nama_lokasi,
    COUNT(fa.aset_key) AS total_aset,
    CAST(SUM(fa.nilai_buku) AS NUMERIC(15,2)) AS total_nilai_buku
FROM fact.fact_aset fa
INNER JOIN dim.dim_lokasi dl ON fa.lokasi_key = dl.lokasi_key
WHERE fa.status_pemanfaatan = 'Aktif'
GROUP BY dl.nama_lokasi
ORDER BY total_nilai_buku DESC;

-- =====================================================
-- SCENARIO 5: Time Series Analysis
-- =====================================================

RAISE NOTICE '--- TEST 5: Time Series Performance ---';

EXPLAIN ANALYZE
SELECT 
    dw.tahun,
    dw.bulan_tahun,
    COUNT(fl.layanan_key) AS total_layanan,
    ROUND(AVG(fl.rating_kepuasan)::NUMERIC, 2) AS avg_rating,
    SUM(CASE WHEN fl.melewati_sla_flag = TRUE THEN 1 ELSE 0 END) AS count_sla_violation
FROM fact.fact_layanan fl
INNER JOIN dim.dim_waktu dw ON fl.tanggal_request_key = dw.tanggal_key
GROUP BY dw.tahun, dw.bulan, dw.bulan_tahun
ORDER BY dw.tahun DESC, dw.bulan DESC;

-- =====================================================
-- SCENARIO 6: Cross-Domain Join (Surat & Layanan)
-- =====================================================

RAISE NOTICE '--- TEST 6: Cross-Domain Analysis ---';

EXPLAIN ANALYZE
SELECT 
    du.nama_unit,
    COUNT(DISTINCT fs.surat_key) AS total_surat,
    COUNT(DISTINCT fl.layanan_key) AS total_layanan,
    ROUND(AVG(fl.rating_kepuasan)::NUMERIC, 2) AS avg_layanan_rating
FROM dim.dim_unit_kerja du
LEFT JOIN fact.fact_surat fs ON du.unit_key = fs.unit_pengirim_key
LEFT JOIN fact.fact_layanan fl ON du.unit_key = fl.unit_pemohon_key
GROUP BY du.nama_unit
ORDER BY total_surat DESC
LIMIT 50;

-- =====================================================
-- PERFORMANCE SUMMARY
-- =====================================================

SELECT 'All test queries executed successfully' as test_summary;

-- ====================== END OF FILE ======================
