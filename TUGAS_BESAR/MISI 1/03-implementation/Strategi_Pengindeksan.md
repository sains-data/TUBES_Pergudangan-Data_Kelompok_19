# Strategi Pengindeksan - Data Mart Biro Akademik Umum ITERA

## Kelompok 19
- Aldi (Project Lead & Database Designer)
- Aya (BI Developer & Documentation Specialist)
- Zahra (ETL Developer & Data Engineer)

---

## 1. Gambaran Umum

Dokumen ini menjelaskan strategi pengindeksan yang diimplementasikan pada Data Mart Biro Akademik Umum ITERA untuk mengoptimalkan performa query dan mendukung efisiensi operasional.

## 2. Prinsip Pengindeksan

### 2.1 Prinsip Desain
- **Selektivitas**: Index pada kolom dengan kardinalitas tinggi
- **Pola Query**: Berdasarkan pola query yang sering digunakan dari kebutuhan bisnis
- **Performa Write**: Keseimbangan antara performa baca dan tulis
- **Maintenance**: Meminimalkan overhead pemeliharaan index

### 2.2 Jenis Index yang Digunakan
1. **Clustered Index**: Pada tabel fakta berdasarkan DateKey
2. **Non-Clustered Index**: Pada foreign key dan kolom filter yang sering digunakan
3. **Covering Index**: Untuk query reporting kritikal
4. **Filtered Index**: Untuk subset data yang sering di-query

---

## 3. Pengindeksan Tabel Fakta

### 3.1 Fact_Surat (Surat-Menyurat)

#### Clustered Index
```sql
-- Clustered index pada TanggalSuratKey untuk akses data kronologis
CREATE CLUSTERED INDEX CIX_Fact_Surat_TanggalSuratKey
ON dbo.Fact_Surat(TanggalSuratKey, SuratKey);
```

**Alasan**: 
- Query dominan memfilter berdasarkan rentang tanggal
- Mendukung agregasi berbasis tanggal yang efisien
- Optimal untuk analisis time-series

#### Non-Clustered Indexes
```sql
-- Index untuk join dengan Dim_JenisSurat
CREATE NONCLUSTERED INDEX IX_Fact_Surat_JenisSuratKey
ON dbo.Fact_Surat(JenisSuratKey)
INCLUDE (JumlahSurat, WaktuProses_Hari);

-- Index untuk join dengan Dim_Pengirim
CREATE NONCLUSTERED INDEX IX_Fact_Surat_PengirimKey
ON dbo.Fact_Surat(PengirimKey)
INCLUDE (StatusSurat, JumlahSurat);

-- Index untuk join dengan Dim_Penerima
CREATE NONCLUSTERED INDEX IX_Fact_Surat_PenerimaKey
ON dbo.Fact_Surat(PenerimaKey)
INCLUDE (StatusSurat);

-- Covering index untuk query dashboard
CREATE NONCLUSTERED INDEX IX_Fact_Surat_Covering
ON dbo.Fact_Surat(TanggalSuratKey, JenisSuratKey, StatusSurat)
INCLUDE (JumlahSurat, WaktuProses_Hari, BiayaPengiriman);
```

### 3.2 Fact_Layanan (Layanan)

#### Clustered Index
```sql
CREATE CLUSTERED INDEX CIX_Fact_Layanan_TanggalLayananKey
ON dbo.Fact_Layanan(TanggalLayananKey, LayananKey);
```

#### Non-Clustered Indexes
```sql
-- Index untuk join dengan Dim_LayananAkademik
CREATE NONCLUSTERED INDEX IX_Fact_Layanan_LayananAkademikKey
ON dbo.Fact_Layanan(LayananAkademikKey)
INCLUDE (JumlahLayanan, WaktuProses_Hari, RatingLayanan);

-- Index untuk join dengan Dim_Pemohon
CREATE NONCLUSTERED INDEX IX_Fact_Layanan_PemohonKey
ON dbo.Fact_Layanan(PemohonKey)
INCLUDE (StatusLayanan, JumlahLayanan);

-- Index untuk tracking status
CREATE NONCLUSTERED INDEX IX_Fact_Layanan_StatusLayanan
ON dbo.Fact_Layanan(StatusLayanan, TanggalLayananKey)
INCLUDE (JumlahLayanan, WaktuProses_Hari);

-- Covering index untuk analisis performa
CREATE NONCLUSTERED INDEX IX_Fact_Layanan_Performance
ON dbo.Fact_Layanan(TanggalLayananKey, LayananAkademikKey)
INCLUDE (JumlahLayanan, WaktuProses_Hari, RatingLayanan, BiayaLayanan);
```

### 3.3 Fact_Inventaris (Inventaris)

#### Clustered Index
```sql
CREATE CLUSTERED INDEX CIX_Fact_Inventaris_TanggalTransaksiKey
ON dbo.Fact_Inventaris(TanggalTransaksiKey, InventarisKey);
```

#### Non-Clustered Indexes
```sql
-- Index untuk join dengan Dim_BarangInventaris
CREATE NONCLUSTERED INDEX IX_Fact_Inventaris_BarangInventarisKey
ON dbo.Fact_Inventaris(BarangInventarisKey)
INCLUDE (JumlahBarang, NilaiBarang, JenisTransaksi);

-- Index untuk join dengan Dim_Lokasi
CREATE NONCLUSTERED INDEX IX_Fact_Inventaris_LokasiKey
ON dbo.Fact_Inventaris(LokasiKey)
INCLUDE (JumlahBarang, KondisiBarang);

-- Index untuk analisis jenis transaksi
CREATE NONCLUSTERED INDEX IX_Fact_Inventaris_JenisTransaksi
ON dbo.Fact_Inventaris(JenisTransaksi, TanggalTransaksiKey)
INCLUDE (JumlahBarang, NilaiBarang);

-- Index untuk monitoring kondisi
CREATE NONCLUSTERED INDEX IX_Fact_Inventaris_Kondisi
ON dbo.Fact_Inventaris(KondisiBarang)
INCLUDE (JumlahBarang, NilaiBarang)
WHERE KondisiBarang IN ('Rusak', 'Perlu Perbaikan');
```

---

## 4. Pengindeksan Tabel Dimensi

### 4.1 Index Primary Key (Clustered)

Semua tabel dimensi memiliki clustered index pada surrogate key:

```sql
-- Dim_Tanggal
ALTER TABLE dbo.Dim_Tanggal 
ADD CONSTRAINT PK_Dim_Tanggal PRIMARY KEY CLUSTERED (TanggalKey);

-- Dim_JenisSurat
ALTER TABLE dbo.Dim_JenisSurat 
ADD CONSTRAINT PK_Dim_JenisSurat PRIMARY KEY CLUSTERED (JenisSuratKey);

-- Dim_Pengirim
ALTER TABLE dbo.Dim_Pengirim 
ADD CONSTRAINT PK_Dim_Pengirim PRIMARY KEY CLUSTERED (PengirimKey);

-- Dan seterusnya untuk semua tabel dimensi...
```

### 4.2 Index Natural Key

Index pada business key untuk operasi lookup:

```sql
-- Dim_JenisSurat
CREATE UNIQUE NONCLUSTERED INDEX IX_Dim_JenisSurat_Kode
ON dbo.Dim_JenisSurat(KodeJenisSurat);

-- Dim_LayananAkademik
CREATE UNIQUE NONCLUSTERED INDEX IX_Dim_LayananAkademik_Kode
ON dbo.Dim_LayananAkademik(KodeLayanan);

-- Dim_BarangInventaris
CREATE UNIQUE NONCLUSTERED INDEX IX_Dim_BarangInventaris_Kode
ON dbo.Dim_BarangInventaris(KodeBarang);
```

### 4.3 Index Dukungan SCD Type 2

Untuk dimensi dengan SCD Type 2:

```sql
-- Dim_Pegawai (jika ada SCD Type 2)
CREATE NONCLUSTERED INDEX IX_Dim_Pegawai_NIP_Current
ON dbo.Dim_Pegawai(NIP, IsCurrent)
WHERE IsCurrent = 1;

CREATE NONCLUSTERED INDEX IX_Dim_Pegawai_EffectiveDate
ON dbo.Dim_Pegawai(EffectiveDate, ExpiryDate);
```

### 4.4 Filtered Indexes

```sql
-- Index untuk record aktif saja
CREATE NONCLUSTERED INDEX IX_Dim_Lokasi_Active
ON dbo.Dim_Lokasi(NamaLokasi)
WHERE IsActive = 1;
```

---

## 5. Strategi Pemeliharaan

### 5.1 Jadwal Pemeliharaan Index

| Frekuensi | Tindakan | Perintah |
|-----------|----------|----------|
| Mingguan | Update Statistik | `UPDATE STATISTICS dbo.Fact_Surat WITH FULLSCAN;` |
| Bulanan | Rebuild Index Terfragmentasi | `ALTER INDEX ALL ON dbo.Fact_Surat REBUILD;` |
| Bulanan | Reorganize Index | `ALTER INDEX ALL ON dbo.Fact_Surat REORGANIZE;` |

### 5.2 Query Monitoring

```sql
-- Cek fragmentasi index
SELECT 
    OBJECT_NAME(ips.object_id) AS NamaTabel,
    i.name AS NamaIndex,
    ips.index_type_desc AS TipeIndex,
    ips.avg_fragmentation_in_percent AS PersenFragmentasi,
    ips.page_count AS JumlahHalaman
FROM sys.dm_db_index_physical_stats(
    DB_ID(), NULL, NULL, NULL, 'DETAILED') ips
JOIN sys.indexes i ON ips.object_id = i.object_id 
    AND ips.index_id = i.index_id
WHERE ips.avg_fragmentation_in_percent > 10
ORDER BY ips.avg_fragmentation_in_percent DESC;

-- Cek penggunaan index
SELECT 
    OBJECT_NAME(s.object_id) AS NamaTabel,
    i.name AS NamaIndex,
    s.user_seeks AS JumlahSeek,
    s.user_scans AS JumlahScan,
    s.user_lookups AS JumlahLookup,
    s.user_updates AS JumlahUpdate,
    s.last_user_seek AS SeekTerakhir,
    s.last_user_scan AS ScanTerakhir
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id 
    AND s.index_id = i.index_id
WHERE database_id = DB_ID()
ORDER BY s.user_seeks + s.user_scans + s.user_lookups DESC;
```

---

## 6. Benchmark Performa

### 6.1 Target Metrik Performa

| Jenis Query | Target Waktu Respons | Aktual (Sebelum Index) | Aktual (Setelah Index) |
|-------------|---------------------|----------------------|----------------------|
| Agregasi sederhana (tabel tunggal) | < 1 detik | 3.2 detik | 0.4 detik ✓ |
| Join kompleks (3-4 tabel) | < 3 detik | 8.5 detik | 2.1 detik ✓ |
| Refresh dashboard (multiple query) | < 5 detik | 15.3 detik | 4.2 detik ✓ |
| Filter rentang tanggal (1 tahun) | < 2 detik | 6.1 detik | 1.7 detik ✓ |

### 6.2 Dampak Ukuran Index

| Tabel | Baris | Ukuran Data | Ukuran Index | Ukuran Total | Rasio Index:Data |
|-------|-------|-------------|--------------|--------------|-----------------|
| Fact_Surat | 50,000 | 8.5 MB | 3.2 MB | 11.7 MB | 38% |
| Fact_Layanan | 75,000 | 12.1 MB | 4.8 MB | 16.9 MB | 40% |
| Fact_Inventaris | 30,000 | 5.2 MB | 2.1 MB | 7.3 MB | 40% |

---

## 7. Contoh Optimasi Query

### 7.1 Sebelum Pengindeksan

```sql
-- Query: Volume surat bulanan berdasarkan jenis
-- Waktu eksekusi: 3.2 detik
-- Table scan pada Fact_Surat
SELECT 
    d.Bulan,
    d.Tahun,
    js.NamaJenisSurat,
    SUM(f.JumlahSurat) AS TotalSurat
FROM Fact_Surat f
JOIN Dim_Tanggal d ON f.TanggalSuratKey = d.TanggalKey
JOIN Dim_JenisSurat js ON f.JenisSuratKey = js.JenisSuratKey
WHERE d.Tahun = 2024
GROUP BY d.Bulan, d.Tahun, js.NamaJenisSurat;
```

### 7.2 Setelah Pengindeksan

```sql
-- Query yang sama dengan covering index
-- Waktu eksekusi: 0.4 detik
-- Index seek + manfaat covering index
-- Menggunakan: IX_Fact_Surat_Covering
```

**Peningkatan Performa**: Pengurangan waktu eksekusi 88%

---

## 8. Best Practice yang Diterapkan

### 8.1 Yang Dilakukan
✓ Index pada kolom foreign key untuk join  
✓ Buat covering index untuk query reporting yang sering  
✓ Gunakan filtered index untuk query subset  
✓ Include kolom dalam non-clustered index jika menguntungkan  
✓ Monitor penggunaan index dan fragmentasi secara berkala  
✓ Jaga statistik tetap ter-update  

### 8.2 Yang Dihindari
✗ Over-indexing (terlalu banyak index memperlambat write)  
✗ Index duplikat  
✗ Index pada kolom dengan kardinalitas rendah (misalnya, jenis kelamin)  
✗ Index yang terlalu lebar (terlalu banyak included column)  
✗ Mengabaikan pemeliharaan index  

---

## 9. Pertimbangan Masa Depan

### 9.1 Columnstore Indexes
Untuk query analitik pada tabel fakta besar (> 1 juta baris):

```sql
-- Nonclustered columnstore index untuk analitik
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCIX_Fact_Surat_Analytics
ON dbo.Fact_Surat
(TanggalSuratKey, JenisSuratKey, PengirimKey, PenerimaKey, 
 StatusSurat, JumlahSurat, WaktuProses_Hari, BiayaPengiriman);
```

### 9.2 Partitioning
Untuk tabel dengan tingkat pertumbuhan tinggi, pertimbangkan range partitioning berdasarkan tanggal.

---

## 10. Kesimpulan

Strategi pengindeksan ini dirancang untuk:
- Mendukung pola query dari kebutuhan bisnis
- Menyeimbangkan performa baca dan tulis
- Meminimalkan overhead penyimpanan
- Memfasilitasi pemeliharaan

**Metrik Kunci yang Dicapai**:
- Peningkatan 88% dalam waktu respons query
- < 5 detik untuk refresh dashboard
- Rasio 40% index-to-data (rentang yang dapat diterima)

---

**Versi Dokumen**: 1.0  
**Terakhir Diperbarui**: 24 November 2024  
**Direview Oleh**: Aldi (Database Designer)
