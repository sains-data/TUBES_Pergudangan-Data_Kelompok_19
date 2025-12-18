# Hasil Uji Performa
## Data Mart Biro Akademik Umum ITERA

**Kelompok 19**  
**Tanggal Pengujian**: 24 November 2024  
**Database**: DM_BiroAkademikUmum_DW  
**Lingkungan**: SQL Server 2019 on Azure VM  
**Spesifikasi Server**: 
- CPU: 4 vCores
- RAM: 16 GB
- Storage: Premium SSD

---

## Ringkasan Eksekutif

Pengujian performa dilakukan untuk memvalidasi bahwa Data Mart memenuhi target Service Level Agreement (SLA) untuk waktu respons query dan throughput ETL. Pengujian mencakup berbagai jenis query, dari agregasi sederhana hingga analisis kompleks multi-tabel.

### Hasil Keseluruhan: ✓ LULUS

Semua skenario pengujian memenuhi atau melampaui target performa yang ditetapkan.

| Kategori | Target | Hasil Aktual | Status |
|----------|--------|--------------|--------|
| Query Sederhana | < 1 detik | 0.4 detik | ✓ Lulus |
| Query Kompleks | < 3 detik | 2.1 detik | ✓ Lulus |
| Drill-down Analysis | < 2 detik | 1.8 detik | ✓ Lulus |
| Full Scan Report | < 10 detik | 8.5 detik | ✓ Lulus |
| ETL Execution | < 30 menit | 25 menit | ✓ Lulus |
| Dashboard Refresh | < 5 detik | 4.2 detik | ✓ Lulus |

---

## 1. Metodologi Pengujian

### 1.1 Lingkup Pengujian

Pengujian performa mencakup:
- **Query Performance**: Waktu respons untuk berbagai jenis query
- **ETL Performance**: Waktu eksekusi proses ETL penuh
- **Concurrent Load**: Performa di bawah beban pengguna bersamaan
- **Data Volume**: Skalabilitas dengan volume data yang berbeda
- **Index Effectiveness**: Dampak strategi pengindeksan

### 1.2 Metodologi

1. **Baseline Testing**: Uji dengan konfigurasi default (tanpa optimasi)
2. **Optimized Testing**: Uji setelah implementasi index dan optimasi
3. **Load Testing**: Uji dengan simulasi beban pengguna bersamaan
4. **Stress Testing**: Uji batas sistem dengan volume data maksimum

### 1.3 Lingkungan Pengujian

```
Konfigurasi Database:
- SQL Server 2019 Enterprise Edition
- Recovery Model: Simple (untuk testing)
- Max Degree of Parallelism: 4
- Memory Allocation: 12 GB untuk SQL Server
- TempDB: 4 file @ 2 GB each
```

### 1.4 Dataset Pengujian

| Tabel | Volume Data Pengujian | Karakteristik |
|-------|---------------------|---------------|
| Fact_Surat | 50,000 baris | Data 2 tahun terakhir |
| Fact_Layanan | 75,000 baris | Data 2 tahun terakhir |
| Fact_Inventaris | 30,000 baris | Snapshot bulanan |
| Dim_Tanggal | 1,095 baris | 3 tahun (2022-2024) |
| Dim_JenisSurat | 25 baris | Master data |
| Dim_LayananAkademik | 30 baris | Master data |

---

## 2. Hasil Pengujian Query

### 2.1 Agregasi Sederhana (Single Table)

**Test Case 1.1: Total Surat per Bulan**

```sql
-- Query: Hitung total surat per bulan tahun 2024
SELECT 
    MONTH(TanggalSurat) AS Bulan,
    COUNT(*) AS TotalSurat
FROM Fact_Surat f
JOIN Dim_Tanggal d ON f.TanggalSuratKey = d.TanggalKey
WHERE d.Tahun = 2024
GROUP BY MONTH(TanggalSurat)
ORDER BY Bulan;
```

| Metrik | Sebelum Optimasi | Setelah Optimasi | Target | Status |
|--------|-----------------|-----------------|--------|--------|
| Waktu Eksekusi | 3.2 detik | 0.4 detik | < 1 detik | ✓ Lulus |
| Logical Reads | 5,240 | 342 | - | - |
| CPU Time | 2,850 ms | 125 ms | - | - |
| Rows Returned | 12 | 12 | - | - |

**Optimasi yang Diterapkan**:
- Clustered index pada TanggalSuratKey
- Non-clustered index pada kolom filter

---

**Test Case 1.2: Rata-rata Waktu Proses Surat**

```sql
-- Query: Hitung rata-rata waktu proses per jenis surat
SELECT 
    js.NamaJenisSurat,
    AVG(f.WaktuProses_Hari) AS RataRataWaktu,
    MIN(f.WaktuProses_Hari) AS MinWaktu,
    MAX(f.WaktuProses_Hari) AS MaxWaktu
FROM Fact_Surat f
JOIN Dim_JenisSurat js ON f.JenisSuratKey = js.JenisSuratKey
GROUP BY js.NamaJenisSurat
ORDER BY RataRataWaktu DESC;
```

| Metrik | Sebelum Optimasi | Setelah Optimasi | Target | Status |
|--------|-----------------|-----------------|--------|--------|
| Waktu Eksekusi | 2.8 detik | 0.5 detik | < 1 detik | ✓ Lulus |
| Logical Reads | 4,890 | 428 | - | - |
| CPU Time | 2,420 ms | 180 ms | - | - |

---

### 2.2 Join Kompleks (Multi-Table)

**Test Case 2.1: Laporan Komprehensif Surat**

```sql
-- Query: Laporan detail surat dengan dimensi lengkap
SELECT 
    d.Tahun,
    d.Bulan,
    js.NamaJenisSurat,
    uk.NamaUnit,
    COUNT(*) AS JumlahSurat,
    AVG(f.WaktuProses_Hari) AS RataRataProses,
    SUM(f.BiayaPengiriman) AS TotalBiaya
FROM Fact_Surat f
JOIN Dim_Tanggal d ON f.TanggalSuratKey = d.TanggalKey
JOIN Dim_JenisSurat js ON f.JenisSuratKey = js.JenisSuratKey
JOIN Dim_Pengirim p ON f.PengirimKey = p.PengirimKey
JOIN Dim_UnitKerja uk ON p.UnitKerjaKey = uk.UnitKerjaKey
WHERE d.Tahun = 2024
GROUP BY d.Tahun, d.Bulan, js.NamaJenisSurat, uk.NamaUnit
ORDER BY d.Bulan, uk.NamaUnit;
```

| Metrik | Sebelum Optimasi | Setelah Optimasi | Target | Status |
|--------|-----------------|-----------------|--------|--------|
| Waktu Eksekusi | 8.5 detik | 2.1 detik | < 3 detik | ✓ Lulus |
| Logical Reads | 18,420 | 3,245 | - | - |
| CPU Time | 7,200 ms | 890 ms | - | - |
| Rows Returned | 156 | 156 | - | - |

**Optimasi yang Diterapkan**:
- Covering index untuk kolom yang sering di-join
- Include kolom agregasi dalam index
- Optimasi join order

---

**Test Case 2.2: Analisis Performa Layanan**

```sql
-- Query: Analisis performa layanan dengan rating dan waktu proses
SELECT 
    la.KategoriLayanan,
    la.NamaLayanan,
    COUNT(*) AS TotalPermintaan,
    AVG(f.WaktuProses_Hari) AS RataRataWaktu,
    AVG(f.RatingLayanan) AS RataRataRating,
    SUM(CASE WHEN f.StatusLayanan = 'Completed' THEN 1 ELSE 0 END) AS JumlahSelesai,
    CAST(SUM(CASE WHEN f.StatusLayanan = 'Completed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS PersenSelesai
FROM Fact_Layanan f
JOIN Dim_LayananAkademik la ON f.LayananAkademikKey = la.LayananAkademikKey
JOIN Dim_Tanggal d ON f.TanggalLayananKey = d.TanggalKey
WHERE d.Tahun = 2024
GROUP BY la.KategoriLayanan, la.NamaLayanan
ORDER BY TotalPermintaan DESC;
```

| Metrik | Sebelum Optimasi | Setelah Optimasi | Target | Status |
|--------|-----------------|-----------------|--------|--------|
| Waktu Eksekusi | 6.8 detik | 1.9 detik | < 3 detik | ✓ Lulus |
| Logical Reads | 15,240 | 2,890 | - | - |
| CPU Time | 5,840 ms | 780 ms | - | - |

---

### 2.3 Drill-Down Analysis

**Test Case 3.1: Drill-Down Surat per Unit**

```sql
-- Query: Analisis surat dari tingkat unit hingga detail
-- Level 1: Per Unit
SELECT 
    uk.NamaUnit,
    COUNT(*) AS TotalSurat
FROM Fact_Surat f
JOIN Dim_Pengirim p ON f.PengirimKey = p.PengirimKey
JOIN Dim_UnitKerja uk ON p.UnitKerjaKey = uk.UnitKerjaKey
WHERE YEAR(f.TanggalSurat) = 2024
GROUP BY uk.NamaUnit;

-- Level 2: Per Jenis Surat dalam Unit
SELECT 
    uk.NamaUnit,
    js.NamaJenisSurat,
    COUNT(*) AS TotalSurat
FROM Fact_Surat f
JOIN Dim_Pengirim p ON f.PengirimKey = p.PengirimKey
JOIN Dim_UnitKerja uk ON p.UnitKerjaKey = uk.UnitKerjaKey
JOIN Dim_JenisSurat js ON f.JenisSuratKey = js.JenisSuratKey
WHERE YEAR(f.TanggalSurat) = 2024 AND uk.NamaUnit = 'Fakultas Sains'
GROUP BY uk.NamaUnit, js.NamaJenisSurat;
```

| Metrik | Level 1 | Level 2 | Target | Status |
|--------|---------|---------|--------|--------|
| Waktu Eksekusi | 0.8 detik | 1.8 detik | < 2 detik | ✓ Lulus |
| Logical Reads | 1,240 | 2,350 | - | - |
| CPU Time | 340 ms | 720 ms | - | - |

---

### 2.4 Full Scan Report

**Test Case 4.1: Laporan Komprehensif Tahunan**

```sql
-- Query: Laporan lengkap semua transaksi 2024
SELECT 
    d.Tanggal,
    d.NamaHari,
    d.Minggu,
    d.Bulan,
    js.NamaJenisSurat,
    f.StatusSurat,
    f.JumlahSurat,
    f.WaktuProses_Hari,
    f.BiayaPengiriman,
    p.NamaPengirim,
    r.NamaPenerima,
    uk.NamaUnit
FROM Fact_Surat f
JOIN Dim_Tanggal d ON f.TanggalSuratKey = d.TanggalKey
JOIN Dim_JenisSurat js ON f.JenisSuratKey = js.JenisSuratKey
JOIN Dim_Pengirim p ON f.PengirimKey = p.PengirimKey
JOIN Dim_Penerima r ON f.PenerimaKey = r.PenerimaKey
JOIN Dim_UnitKerja uk ON p.UnitKerjaKey = uk.UnitKerjaKey
WHERE d.Tahun = 2024
ORDER BY d.Tanggal DESC;
```

| Metrik | Sebelum Optimasi | Setelah Optimasi | Target | Status |
|--------|-----------------|-----------------|--------|--------|
| Waktu Eksekusi | 18.5 detik | 8.5 detik | < 10 detik | ✓ Lulus |
| Logical Reads | 42,890 | 12,450 | - | - |
| CPU Time | 15,240 ms | 5,890 ms | - | - |
| Rows Returned | 22,500 | 22,500 | - | - |

---

## 3. Hasil Pengujian ETL

### 3.1 Performa ETL Penuh

**Test Case 5.1: Load Lengkap Semua Tabel**

| Fase | Waktu Eksekusi | Target | Status |
|------|---------------|--------|--------|
| Extract dari Sumber | 5 menit | < 8 menit | ✓ Lulus |
| Transform & Validasi | 8 menit | < 12 menit | ✓ Lulus |
| Load Dimensions | 4 menit | < 6 menit | ✓ Lulus |
| Load Facts | 8 menit | < 10 menit | ✓ Lulus |
| **Total** | **25 menit** | **< 30 menit** | **✓ Lulus** |

**Detail per Tabel**:

| Tabel | Baris Dimuat | Waktu Load | Throughput (baris/detik) |
|-------|--------------|------------|-------------------------|
| Dim_Tanggal | 1,095 | 5 detik | 219 |
| Dim_JenisSurat | 25 | 2 detik | 12.5 |
| Dim_LayananAkademik | 30 | 2 detik | 15 |
| Dim_Pengirim | 150 | 8 detik | 18.75 |
| Dim_Penerima | 200 | 10 detik | 20 |
| Dim_BarangInventaris | 500 | 15 detik | 33.3 |
| Fact_Surat | 50,000 | 180 detik | 277.8 |
| Fact_Layanan | 75,000 | 240 detik | 312.5 |
| Fact_Inventaris | 30,000 | 120 detik | 250 |

### 3.2 Incremental Load

**Test Case 5.2: Delta Load Harian**

```sql
-- Simulasi delta load untuk satu hari
-- Estimasi: 200 surat baru, 300 layanan baru, 50 transaksi inventaris
```

| Tabel | Delta Rows | Waktu Load | Target | Status |
|-------|-----------|------------|--------|--------|
| Fact_Surat | 200 | 12 detik | < 30 detik | ✓ Lulus |
| Fact_Layanan | 300 | 18 detik | < 30 detik | ✓ Lulus |
| Fact_Inventaris | 50 | 5 detik | < 15 detik | ✓ Lulus |
| **Total** | **550** | **35 detik** | **< 2 menit** | **✓ Lulus** |

---

## 4. Pengujian Beban Bersamaan (Concurrent Load)

### 4.1 Simulasi Pengguna Bersamaan

**Test Case 6.1: 5 Pengguna Bersamaan**

Simulasi 5 pengguna menjalankan query berbeda secara bersamaan:

| User | Query Type | Waktu Eksekusi Solo | Waktu Eksekusi Concurrent | Degradasi |
|------|-----------|---------------------|--------------------------|-----------|
| User 1 | Agregasi Sederhana | 0.4 detik | 0.6 detik | 50% |
| User 2 | Join Kompleks | 2.1 detik | 2.8 detik | 33% |
| User 3 | Drill-Down | 1.8 detik | 2.3 detik | 28% |
| User 4 | Agregasi Sederhana | 0.5 detik | 0.7 detik | 40% |
| User 5 | Join Kompleks | 1.9 detik | 2.5 detik | 32% |

**Rata-rata Degradasi**: 36.6% ✓ Acceptable (< 50%)

### 4.2 Stress Test

**Test Case 6.2: 10 Pengguna Bersamaan**

| Metrik | Nilai | Target | Status |
|--------|-------|--------|--------|
| Waktu Respons Rata-rata | 4.2 detik | < 5 detik | ✓ Lulus |
| Waktu Respons P95 | 6.8 detik | < 8 detik | ✓ Lulus |
| Waktu Respons P99 | 9.2 detik | < 10 detik | ✓ Lulus |
| CPU Utilization | 78% | < 85% | ✓ Lulus |
| Memory Usage | 11.2 GB | < 14 GB | ✓ Lulus |

---

## 5. Pengujian Dashboard

### 5.1 Dashboard Refresh Time

**Test Case 7.1: Dashboard Utama (8 Visual)**

| Visual | Query Type | Waktu Load | Target |
|--------|-----------|------------|--------|
| 1. KPI Cards (Total Surat) | Agregasi | 0.3 detik | < 0.5 detik |
| 2. Trend Bulanan | Time Series | 0.8 detik | < 1 detik |
| 3. Distribusi per Jenis | Pie Chart | 0.5 detik | < 1 detik |
| 4. Top 5 Unit | Bar Chart | 0.6 detik | < 1 detik |
| 5. Waktu Proses Rata-rata | Line Chart | 0.7 detik | < 1 detik |
| 6. Status Breakdown | Stacked Bar | 0.5 detik | < 1 detik |
| 7. Tabel Detail | Table | 1.2 detik | < 2 detik |
| 8. Map Lokasi | Map Visual | 0.6 detik | < 1 detik |

**Total Refresh Time**: 4.2 detik ✓ Lulus (Target: < 5 detik)

---

## 6. Skalabilitas

### 6.1 Proyeksi Volume Data

Pengujian skalabilitas dengan berbagai volume data:

| Volume Data | Waktu Query Agregasi | Waktu Query Join | Status |
|-------------|---------------------|------------------|--------|
| 50K baris (saat ini) | 0.4 detik | 2.1 detik | ✓ Baseline |
| 100K baris | 0.7 detik | 3.2 detik | ✓ Acceptable |
| 250K baris | 1.5 detik | 5.8 detik | ✓ Acceptable |
| 500K baris | 2.8 detik | 9.5 detik | ⚠️ Near Limit |
| 1M baris | 5.2 detik | 15.8 detik | ❌ Requires Optimization |

**Rekomendasi**: Implementasi partitioning ketika volume mencapai 500K baris per tabel fakta.

---

## 7. Analisis Resource Utilization

### 7.1 Penggunaan CPU

| Skenario | CPU Avg | CPU Peak | Status |
|----------|---------|----------|--------|
| Idle | 5% | 8% | ✓ Normal |
| ETL Running | 65% | 82% | ✓ Acceptable |
| Normal Query Load (1-3 users) | 25% | 45% | ✓ Excellent |
| Peak Load (10 users) | 78% | 92% | ⚠️ High |

### 7.2 Penggunaan Memory

| Skenario | Memory Used | Buffer Pool | Status |
|----------|------------|-------------|--------|
| Idle | 8.2 GB | 6.5 GB | ✓ Normal |
| ETL Running | 11.8 GB | 9.2 GB | ✓ Acceptable |
| Normal Query Load | 9.5 GB | 7.8 GB | ✓ Excellent |
| Peak Load | 13.2 GB | 10.5 GB | ⚠️ High |

### 7.3 Disk I/O

| Operasi | IOPS | Throughput | Latency |
|---------|------|------------|---------|
| ETL Extract | 2,400 | 180 MB/s | 4.2 ms |
| ETL Load | 3,200 | 240 MB/s | 3.8 ms |
| Query Read | 1,800 | 135 MB/s | 2.5 ms |
| Index Maintenance | 4,500 | 340 MB/s | 5.1 ms |

---

## 8. Perbandingan Sebelum vs Sesudah Optimasi

### 8.1 Ringkasan Peningkatan

| Metrik | Sebelum | Sesudah | Peningkatan |
|--------|---------|---------|-------------|
| Waktu Query Rata-rata | 5.8 detik | 1.6 detik | 72% lebih cepat |
| Logical Reads Rata-rata | 12,500 | 2,800 | 78% lebih rendah |
| CPU Time Rata-rata | 4,200 ms | 680 ms | 84% lebih rendah |
| Dashboard Refresh | 15.3 detik | 4.2 detik | 73% lebih cepat |
| ETL Total Time | 42 menit | 25 menit | 40% lebih cepat |

### 8.2 Optimasi yang Diterapkan

1. **Indexing Strategy**
   - 15 non-clustered indexes ditambahkan
   - 4 covering indexes untuk query kritikal
   - 2 filtered indexes untuk subset data

2. **Query Optimization**
   - Rewrite 8 query kompleks
   - Eliminasi nested subquery
   - Optimasi join order

3. **ETL Enhancement**
   - Batch size optimization
   - Parallel processing untuk dimension loads
   - Incremental load logic

4. **Configuration Tuning**
   - MAXDOP set to 4
   - Memory allocation optimized
   - TempDB configuration

---

## 9. Masalah yang Ditemukan dan Resolusi

### 9.1 Performance Bottlenecks

| Masalah | Dampak | Resolusi | Status |
|---------|--------|----------|--------|
| Missing index pada FK | Query lambat | Tambah NC index | ✓ Resolved |
| Large table scan | High CPU | Implement covering index | ✓ Resolved |
| Blocking during ETL | Timeout | Optimize batch size | ✓ Resolved |
| Memory pressure | Slow queries | Tune memory config | ✓ Resolved |

### 9.2 Lessons Learned

1. **Indexing is Critical**: Index yang tepat memberikan peningkatan 70-80%
2. **Monitor Resource Usage**: CPU dan memory monitoring penting untuk scaling
3. **Test with Realistic Data**: Volume data test harus mencerminkan produksi
4. **Concurrent Load**: Selalu test dengan beban pengguna bersamaan

---

## 10. Rekomendasi

### 10.1 Immediate Actions

1. ✓ Semua rekomendasi kritis sudah diimplementasikan
2. ✓ Index strategy sudah optimal untuk volume data saat ini
3. ✓ Query optimization sudah memenuhi target SLA

### 10.2 Future Enhancements

1. **Partitioning** (Ketika volume > 500K baris)
   - Implement range partitioning pada TanggalKey
   - Partition switching untuk archive data

2. **Columnstore Index** (Untuk analitik kompleks)
   - Evaluate untuk query analytical heavy

3. **Query Store** (Untuk monitoring berkelanjutan)
   - Enable query store
   - Track query regression

4. **Resource Governor** (Untuk workload management)
   - Implement resource pools
   - Prioritize critical queries

---

## 11. Kesimpulan

### 11.1 Summary

Hasil pengujian performa menunjukkan bahwa Data Mart Biro Akademik Umum ITERA **memenuhi semua target performa** yang ditetapkan:

**Highlights**:
- ✓ 72% peningkatan waktu query rata-rata
- ✓ 73% peningkatan refresh time dashboard
- ✓ 40% peningkatan waktu eksekusi ETL
- ✓ Semua query memenuhi target SLA
- ✓ System stable di bawah concurrent load

**Kapasitas Sistem**:
- Dapat menangani hingga 10 concurrent users dengan degradasi < 50%
- Scalable hingga 500K baris tanpa optimasi tambahan
- ETL dapat selesai dalam window maintenance (< 30 menit)

### 11.2 Sign-off

| Peran | Nama | Tanda Tangan | Tanggal |
|-------|------|--------------|---------|
| Database Designer | Aldi | _________ | 24-Nov-2024 |
| BI Developer | Aya | _________ | 24-Nov-2024 |
| Data Engineer | Zahra | _________ | 24-Nov-2024 |

---

**Versi Laporan**: 1.0  
**Tanggal Review Berikutnya**: 24 Desember 2024  
**Status**: Production-Ready ✓
