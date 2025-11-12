# Source-to-Target Mapping

**Document Version:** 1.0  
**Created:** 12 November 2025  
**Owner:** Kelompok 19 - Zahra (ETL Developer)  
**Purpose:** Complete field-level mapping dari OLTP sources ke Data Warehouse dimensional model

---

## Table of Contents

1. [Dimension Tables Mapping](#dimension-tables-mapping)
2. [Fact Tables Mapping](#fact-tables-mapping)
3. [Transformation Rules Library](#transformation-rules-library)
4. [Load Sequence & Dependencies](#load-sequence--dependencies)
5. [Data Volume Estimates](#data-volume-estimates)

---

## Dimension Tables Mapping

### 1.1 DIM_WAKTU (Date Dimension - Generated)

**Source Type:** Generated (Not from source system)  
**Load Frequency:** One-time (2019-2030 range)  
**SCD Type:** Type 0 (Never changes)  
**Grain:** Per hari (Daily)

| Target Column | Target Data Type | Generation Logic | Business Rule | Sample Output |
|---------------|------------------|------------------|---------------|---------------|
| tanggal_key | INT | FORMAT(date, 'yyyyMMdd') | PK, Format YYYYMMDD | 20240115 |
| tanggal | DATE | Generated date value | Full date | 2024-01-15 |
| hari | VARCHAR(10) | DATENAME(weekday, tanggal) | Senin-Minggu | Senin |
| bulan | INT | MONTH(tanggal) | 1-12 | 1 |
| tahun | INT | YEAR(tanggal) | YYYY | 2024 |
| quarter | INT | DATEPART(quarter, tanggal) | 1-4 | 1 |
| hari_kerja | BIT | IF weekday IN (Mon-Fri) AND NOT holiday THEN 1 ELSE 0 | Exclude weekends + ITERA holidays | 1 |
| bulan_tahun | VARCHAR(20) | CONCAT(month_name, ' ', year) | Display format | Januari 2024 |
| minggu_tahun | INT | DATEPART(week, tanggal) | Week number in year | 3 |
| hari_dalam_bulan | INT | DAY(tanggal) | Day of month | 15 |

**SQL Generation Script:**
```sql
-- Generate date dimension 2019-2030
DECLARE @StartDate DATE = '2019-01-01';
DECLARE @EndDate DATE = '2030-12-31';

WHILE @StartDate <= @EndDate
BEGIN
INSERT INTO dim_waktu (tanggal_key, tanggal, hari, bulan, tahun, quarter, hari_kerja, bulan_tahun, minggu_tahun, hari_dalam_bulan)
VALUES (
CAST(FORMAT(@StartDate, 'yyyyMMdd') AS INT),
@StartDate,
DATENAME(weekday, @StartDate),
MONTH(@StartDate),
YEAR(@StartDate),
DATEPART(quarter, @StartDate),
CASE WHEN DATEPART(weekday, @StartDate) BETWEEN 2 AND 6 THEN 1 ELSE 0 END,
CONCAT(DATENAME(month, @StartDate), ' ', YEAR(@StartDate)),
DATEPART(week, @StartDate),
DAY(@StartDate)
);
SET @StartDate = DATEADD(day, 1, @StartDate);
END;
```
---

### 1.2 DIM_UNIT_KERJA (Organizational Unit)

**Source System:** MASTER_DB  
**Source Table:** tbl_unit_kerja  
**Load Frequency:** Weekly (or on-change)  
**SCD Type:** Type 1 (Overwrite)  
**Grain:** Per unit organisasi

| Source Column | Source Type | Transformation | Target Column | Target Type | Business Rule | Sample Input → Output |
|---------------|-------------|----------------|---------------|-------------|---------------|----------------------|
| id_unit | INT | Direct | unit_key | INT | PK | 5 → 5 |
| kode_unit | VARCHAR(10) | UPPER(TRIM()) | kode_unit | VARCHAR(10) | Business key, uppercase | bau → BAU |
| nama_unit | VARCHAR(100) | TRIM() | nama_unit | VARCHAR(100) | Remove extra spaces | " Biro Akademik Umum " → Biro Akademik Umum |
| level | INT | Direct | level | INT | Hierarchy depth 1-5 | 2 → 2 |
| parent_unit_id | INT | Lookup dim_unit_kerja.unit_key | parent_unit_key | INT | Self-referencing FK, NULL for top | NULL → NULL |
| kepala_unit_nip | VARCHAR(20) | Direct | kepala_unit_nip | VARCHAR(20) | Reference to dim_pegawai | 198501012015011001 → 198501012015011001 |
| email_unit | VARCHAR(100) | LOWER(TRIM()) | email_unit | VARCHAR(100) | Lowercase for consistency | BAU@ITERA.AC.ID → bau@itera.ac.id |
| - | - | Calculated | path_hierarchy | VARCHAR(500) | Recursive CTE for full path | → Rektorat > Biro Akademik Umum |
| - | - | Calculated | jumlah_sub_unit | INT | COUNT of child units | → 3 |

**ETL Notes:**
- Load order: Top-down (Level 1 → 5) untuk maintain parent-child integrity
- Validate parent_unit_key exists sebelum insert
- Update path_hierarchy setelah all units loaded

---

### 1.3 DIM_PEGAWAI (Employee - SCD Type 2)

**Source System:** SIMPEG_DB  
**Source Table:** tbl_pegawai  
**Load Frequency:** Daily  
**SCD Type:** Type 2 (Track history untuk job changes)  
**Grain:** Per pegawai per periode efektif

| Source Column | Source Type | Transformation | Target Column | Target Type | Business Rule | Sample Input → Output |
|---------------|-------------|----------------|---------------|-------------|---------------|----------------------|
| - | - | Generated | pegawai_key | INT | PK, Surrogate key | → 1 (auto-increment) |
| nip | VARCHAR(20) | TRIM() | nip | VARCHAR(20) | Business key (natural key) | 199001012020011001 → 199001012020011001 |
| nama | VARCHAR(100) | TRIM(), INITCAP() | nama | VARCHAR(100) | Proper case | dr. ahmad fauzi → Dr. Ahmad Fauzi |
| jabatan | VARCHAR(100) | TRIM() | jabatan | VARCHAR(100) | - | Kepala Bagian Umum → Kepala Bagian Umum |
| unit_kerja_id | INT | Lookup dim_unit_kerja.unit_key | unit_key | INT | FK to dim_unit_kerja | 5 → 5 |
| status_kepegawaian | VARCHAR(30) | TRIM() | status_kepegawaian | VARCHAR(30) | PNS, PPPK, Honorer | PNS → PNS |
| tanggal_masuk | DATE | Direct | tanggal_masuk | DATE | - | 2020-01-15 → 2020-01-15 |
| email | VARCHAR(100) | LOWER(TRIM()) | email | VARCHAR(100) | - | AHMAD.FAUZI@itera.ac.id → ahmad.fauzi@itera.ac.id |
| no_hp | VARCHAR(15) | TRIM() | no_hp | VARCHAR(15) | Optional | 081234567890 → 081234567890 |
| - | - | System-generated | effective_date | DATE | SCD start date | → 2024-01-01 |
| - | - | System-generated | end_date | DATE | SCD end date, 9999-12-31 for current | → 9999-12-31 |
| - | - | System-generated | is_current | BIT | 1 for current record | → 1 |

**SCD Type 2 Logic:**
```sql
-- When jabatan or unit_kerja_id changes:
-- Step 1: Update existing record
UPDATE dim_pegawai
SET end_date = GETDATE() - 1, is_current = 0
WHERE nip = @nip AND is_current = 1;

-- Step 2: Insert new record
INSERT INTO dim_pegawai (nip, nama, jabatan, unit_key, status_kepegawaian, tanggal_masuk, email, no_hp, effective_date, end_date, is_current)
VALUES (@nip, @nama, @jabatan_new, @unit_key_new, @status, @tanggal_masuk, @email, @no_hp, GETDATE(), '9999-12-31', 1);
```

**ETL Notes:**
- Check for changes in: jabatan, unit_kerja_id, status_kepegawaian
- Keep nip, nama, email changes as Type 1 (overwrite all records)
- Generate new surrogate key for each version

---

### 1.4 DIM_JENIS_SURAT (Letter Type)

**Source System:** SIMASTER_DB  
**Source Table:** ref_jenis_surat  
**Load Frequency:** Weekly  
**SCD Type:** Type 1  
**Grain:** Per jenis surat

| Source Column | Source Type | Transformation | Target Column | Target Type | Business Rule | Sample Input → Output |
|---------------|-------------|----------------|---------------|-------------|---------------|----------------------|
| id | INT | Direct | jenis_surat_key | INT | PK | 1 → 1 |
| kode_jenis | VARCHAR(10) | UPPER(TRIM()) | kode_jenis | VARCHAR(10) | Business key | um → UM |
| nama_jenis | VARCHAR(100) | TRIM(), INITCAP() | nama_jenis | VARCHAR(100) | - | surat undangan → Surat Undangan |
| kategori | VARCHAR(50) | TRIM() | kategori | VARCHAR(50) | Internal, Eksternal, Edaran | Internal → Internal |
| sla_hari | INT | Direct | sla_hari | INT | Target processing days | 3 → 3 |

**Data Quality Rules:**
- kategori must be in ('Internal', 'Eksternal', 'Edaran', 'Umum')
- sla_hari default = 5 if NULL

---

### 1.5 DIM_BARANG (Asset/Inventory Item)

**Source System:** INVENTARIS_DB  
**Source Table:** tbl_inventaris (reference data extracted)  
**Load Frequency:** Weekly  
**SCD Type:** Type 1  
**Grain:** Per item barang unik

| Source Column | Source Type | Transformation | Target Column | Target Type | Business Rule | Sample Input → Output |
|---------------|-------------|----------------|---------------|-------------|---------------|----------------------|
| - | - | Generated from kode_barang | barang_key | INT | PK, Surrogate | → 1 (auto) |
| kode_barang | VARCHAR(30) | UPPER(TRIM()) | kode_barang | VARCHAR(30) | Business key | inv/comp/2024/001 → INV/COMP/2024/001 |
| nama_barang | VARCHAR(200) | TRIM(), INITCAP() | nama_barang | VARCHAR(200) | - | laptop dell latitude 5420 → Laptop Dell Latitude 5420 |
| kategori | VARCHAR(50) | Standardize via mapping | kategori | VARCHAR(50) | Map PC/Laptop → Komputer | PC → Komputer |
| - | - | Derived from kategori | subkategori | VARCHAR(50) | More specific | Komputer → Laptop |
| - | - | Extracted | satuan | VARCHAR(20) | Unit of measurement | → Unit |

**Kategori Standardization Mapping:**
**Python transformation**
```python
kategori_mapping = {
'PC': 'Komputer',
'Laptop': 'Komputer',
'Notebook': 'Komputer',
'Printer': 'Peralatan Elektronik',
'AC': 'Peralatan Elektronik',
'Meja': 'Furniture',
'Kursi': 'Furniture',
'Lemari': 'Furniture'
}
```
**Apply mapping**
```python
df['kategori'] = df['kategori'].map(kategori_mapping).fillna('Lainnya')
```
---

### 1.6 DIM_LOKASI (Location)

**Source System:** INVENTARIS_DB  
**Source Table:** ref_lokasi  
**Load Frequency:** Monthly  
**SCD Type:** Type 1  
**Grain:** Per lokasi fisik

| Source Column | Source Type | Transformation | Target Column | Target Type | Business Rule | Sample Input → Output |
|---------------|-------------|----------------|---------------|-------------|---------------|----------------------|
| id_lokasi | INT | Direct | lokasi_key | INT | PK | 15 → 15 |
| gedung | VARCHAR(50) | TRIM(), INITCAP() | gedung | VARCHAR(50) | - | gedung rektorat → Gedung Rektorat |
| lantai | INT | Direct | lantai | INT | - | 2 → 2 |
| ruangan | VARCHAR(50) | UPPER(TRIM()) | ruangan | VARCHAR(50) | Standardize format | r.201 → R.201 |
| kapasitas | INT | Direct | kapasitas | INT | Optional, for meeting rooms | 20 → 20 |
| pic_nama | VARCHAR(100) | TRIM(), INITCAP() | pic_nama | VARCHAR(100) | Person in charge | agus santoso → Agus Santoso |
| - | - | Concatenate | lokasi_lengkap | VARCHAR(200) | Full location string | → Gedung Rektorat, Lt. 2, R.201 |

---

### 1.7 DIM_JENIS_LAYANAN (Service Type)

**Source System:** LAYANAN_DB  
**Source Table:** ref_jenis_layanan  
**Load Frequency:** Weekly  
**SCD Type:** Type 1  
**Grain:** Per jenis layanan

| Source Column | Source Type | Transformation | Target Column | Target Type | Business Rule | Sample Input → Output |
|---------------|-------------|----------------|---------------|-------------|---------------|----------------------|
| id | INT | Direct | jenis_layanan_key | INT | PK | 1 → 1 |
| kode_layanan | VARCHAR(10) | UPPER(TRIM()) | kode_layanan | VARCHAR(10) | Business key | leg → LEG |
| nama_layanan | VARCHAR(100) | TRIM(), INITCAP() | nama_layanan | VARCHAR(100) | - | legalisir dokumen → Legalisir Dokumen |
| kategori | VARCHAR(50) | TRIM() | kategori | VARCHAR(50) | Administrasi Akademik, Teknis, dsb | Administrasi Akademik → Administrasi Akademik |
| is_komplain | BIT | Direct | is_komplain | BIT | 1 = complaint, 0 = regular request | 0 → 0 |
| sla_hari | INT | Direct | sla_hari | INT | Target completion days | 2 → 2 |

---

## Fact Tables Mapping

### 2.1 FACT_SURAT (Letter Transactions)

**Source System:** SIMASTER_DB  
**Source Tables:** tbl_surat_masuk, tbl_disposisi  
**Load Frequency:** Daily (incremental)  
**Grain:** Per surat individual  
**Fact Type:** Transaction

| Source Table | Source Column | Source Type | Transformation | Target Column | Target Type | Measure Type | Business Rule |
|--------------|---------------|-------------|----------------|---------------|-------------|--------------|---------------|
| - | - | - | Generated | surat_key | INT | - | PK, Surrogate |
| tbl_surat_masuk | tanggal_diterima | DATE | Convert to tanggal_key via dim_waktu lookup | tanggal_key | INT | - | FK to dim_waktu |
| tbl_surat_masuk | jenis_surat_id | INT | Lookup dim_jenis_surat.jenis_surat_key | jenis_surat_key | INT | - | FK to dim_jenis_surat |
| tbl_surat_masuk | - | - | Parse from pengirim or default to external unit | unit_pengirim_key | INT | - | FK to dim_unit_kerja |
| tbl_surat_masuk | disposisi_ke | VARCHAR | Lookup unit by name → dim_unit_kerja.unit_key | unit_penerima_key | INT | - | FK to dim_unit_kerja (role-playing) |
| tbl_disposisi | kepada_pegawai_id | INT | Lookup dim_pegawai (current record) | pegawai_disposisi_key | INT | - | FK to dim_pegawai |
| - | - | - | COUNT = 1 per row | jumlah_surat | INT | Additive | Always 1, for aggregation |
| tbl_disposisi | tanggal_selesai, tbl_surat_masuk.tanggal_diterima | DATE | DATEDIFF(day, tanggal_diterima, tanggal_selesai) | waktu_proses_hari | INT | Additive | Processing time in days, NULL if not completed |
| tbl_surat_masuk | nomor_surat | VARCHAR(50) | Direct | nomor_surat | VARCHAR(50) | - | Degenerate dimension |
| tbl_disposisi | status | VARCHAR | IF status='Selesai' THEN 1 ELSE 0 | is_selesai | BIT | Additive | Completion flag |

**Complex Transformation Notes:**
```sql
-- Calculate waktu_proses_hari only for completed letters
waktu_proses_hari =
CASE
WHEN d.status = 'Selesai' AND d.tanggal_selesai IS NOT NULL
THEN DATEDIFF(day, s.tanggal_diterima, d.tanggal_selesai)
ELSE NULL
END;

-- Handle unit_pengirim for external senders
unit_pengirim_key =
CASE
WHEN s.pengirim LIKE '%ITERA%' OR s.pengirim IN (SELECT nama_unit FROM dim_unit_kerja)
THEN (SELECT unit_key FROM dim_unit_kerja WHERE nama_unit = s.pengirim)
ELSE -1 -- Default external unit key
END;
```
***Join Logic**
```sql
SELECT
s.id_surat,
s.tanggal_diterima,
s.jenis_surat_id,
s.pengirim,
s.nomor_surat,
d.kepada_pegawai_id,
d.tanggal_selesai,
d.status
FROM tbl_surat_masuk s
LEFT JOIN tbl_disposisi d ON s.id_surat = d.id_surat
WHERE d.status = 'Selesai' OR d.id_disposisi IS NULL;
```
---

### 2.2 FACT_ASET (Asset Snapshot)

**Source System:** INVENTARIS_DB  
**Source Table:** tbl_inventaris  
**Load Frequency:** Monthly (snapshot on last day of month)  
**Grain:** Per aset per bulan (periodic snapshot)  
**Fact Type:** Periodic Snapshot

| Source Column | Source Type | Transformation | Target Column | Target Type | Measure Type | Business Rule |
|---------------|-------------|----------------|---------------|-------------|--------------|---------------|
| - | - | Generated | aset_snapshot_key | INT | - | PK, Surrogate |
| tanggal_snapshot | DATE | Convert to tanggal_key (last day of month) | tanggal_snapshot_key | INT | - | FK to dim_waktu |
| kode_barang | VARCHAR(30) | Lookup dim_barang.barang_key | barang_key | INT | - | FK to dim_barang |
| lokasi_id | INT | Lookup dim_lokasi.lokasi_key | lokasi_key | INT | - | FK to dim_lokasi |
| unit_kerja_id | INT | Lookup dim_unit_kerja.unit_key | unit_kerja_key | INT | - | FK to dim_unit_kerja |
| nilai_perolehan | DECIMAL(15,2) | Handle NULL via median imputation | nilai_buku | DECIMAL(15,2) | Semi-additive | Current book value |
| kondisi | VARCHAR(20) | Map to numeric score: Baik=5, Cukup=3, Rusak=1 | kondisi_score | INT | Non-additive | Asset condition rating |
| - | - | COUNT = 1 | jumlah_unit | INT | Additive | Always 1 per asset |
| kondisi | VARCHAR(20) | Direct | status | VARCHAR(20) | - | Aktif, Rusak, Hilang |

**NULL Handling for nilai_buku:**
**In ETL script**
```python
import pandas as pd

Median imputation per kategori
df['nilai_buku'] = df.groupby('kategori')['nilai_perolehan'].transform(
lambda x: x.fillna(x.median())
)

Flag estimated values
df['is_nilai_estimated'] = df['nilai_perolehan'].isnull().astype(int)
```
**Snapshot Logic**
```sql
-- Monthly snapshot on last day
INSERT INTO fact_aset (
tanggal_snapshot_key,
barang_key,
lokasi_key,
unit_kerja_key,
nilai_buku,
kondisi_score,
jumlah_unit,
status
)
SELECT
(SELECT tanggal_key FROM dim_waktu WHERE tanggal = EOMONTH(GETDATE())) AS tanggal_snapshot_key,
b.barang_key,
l.lokasi_key,
u.unit_key,
ISNULL(i.nilai_perolehan, 0) AS nilai_buku,
CASE i.kondisi
WHEN 'Baik' THEN 5
WHEN 'Cukup' THEN 3
WHEN 'Rusak' THEN 1
ELSE 0
END AS kondisi_score,
1 AS jumlah_unit,
i.kondisi AS status
FROM tbl_inventaris i
INNER JOIN dim_barang b ON i.kode_barang = b.kode_barang
INNER JOIN dim_lokasi l ON i.lokasi_id = l.lokasi_key
INNER JOIN dim_unit_kerja u ON i.unit_kerja_id = u.unit_key
WHERE i.tanggal_snapshot = EOMONTH(GETDATE());
```
---

### 2.3 FACT_LAYANAN (Service Requests)

**Source System:** LAYANAN_DB  
**Source Table:** tbl_permintaan_layanan  
**Load Frequency:** Daily (incremental)  
**Grain:** Per permintaan layanan  
**Fact Type:** Transaction

| Source Column | Source Type | Transformation | Target Column | Target Type | Measure Type | Business Rule |
|---------------|-------------|----------------|---------------|-------------|--------------|---------------|
| - | - | Generated | layanan_key | INT | - | PK, Surrogate |
| timestamp_submit | DATETIME | Convert date part to tanggal_key | waktu_key | INT | - | FK to dim_waktu |
| jenis_layanan_id | INT | Lookup dim_jenis_layanan.jenis_layanan_key | jenis_layanan_key | INT | - | FK to dim_jenis_layanan |
| pemohon_nip | VARCHAR(20) | Lookup dim_pegawai (current record) | pegawai_pemohon_key | INT | - | FK to dim_pegawai |
| unit_tujuan_id | INT | Lookup dim_unit_kerja.unit_key | unit_tujuan_key | INT | - | FK to dim_unit_kerja |
| timestamp_submit, tanggal_selesai | DATETIME | DATEDIFF(hour, timestamp_submit, tanggal_selesai) | waktu_respon_jam | INT | Additive | Response time in hours |
| waktu_respon_jam | INT | IF waktu_respon_jam <= (sla * 24) THEN 1 ELSE 0 | is_on_time | BIT | Additive | SLA compliance flag |
| - | - | COUNT = 1 | jumlah_permintaan | INT | Additive | Always 1 for aggregation |
| rating_kepuasan | DECIMAL(2,1) | Direct, NULL allowed | rating_kepuasan | DECIMAL(2,1) | Non-additive | Customer satisfaction 1.0-5.0 |
| nomor_tiket | VARCHAR(30) | Direct | nomor_tiket | VARCHAR(30) | - | Degenerate dimension |
| status_penyelesaian | VARCHAR(20) | Direct | status | VARCHAR(20) | - | Selesai, Pending, Dibatalkan |

**Business Rules:**
```sql
-- Only include completed requests for waktu_respon_jam calculation
waktu_respon_jam =
CASE
WHEN status_penyelesaian = 'Selesai' AND tanggal_selesai IS NOT NULL
THEN DATEDIFF(hour, timestamp_submit, tanggal_selesai)
ELSE NULL
END;

-- SLA check based on jenis_layanan.sla_hari
is_on_time =
CASE
WHEN waktu_respon_jam <= (jl.sla_hari * 24) THEN 1
ELSE 0
END;
```
---

## Transfor
mation Rules Library

### 3.1 Data Quality Transformations

**Rule 1: Deduplikasi Nomor Surat (1% duplicates)**
```sql
-- Keep earliest record in case of duplicate nomor_surat
WITH RankedSurat AS (
SELECT *,
ROW_NUMBER() OVER (PARTITION BY nomor_surat ORDER BY tanggal_diterima ASC) AS rn
FROM tbl_surat_masuk
)
SELECT *
FROM RankedSurat
WHERE rn = 1;
```
**Rule 2: Standardisasi Kategori (12% non-standard)**Python transformation in ETL
```python
import pandas as pd

kategori_mapping = {
'PC': 'Komputer',
'Laptop': 'Komputer',
'Notebook': 'Komputer',
'Printer': 'Peralatan Elektronik',
'AC': 'Peralatan Elektronik',
'Meja': 'Furniture',
'Kursi': 'Furniture',
'Lemari': 'Furniture'
}
```
**Apply mapping with default fallback**
```python
df['kategori_std'] = df['kategori'].map(kategori_mapping).fillna('Lainnya')
```
**Rule 3: Handle NULL nilai_perolehan (8% missing)**
**Median imputation per kategori**
```python
import pandas as pd

Group by kategori and fill missing with median
df['nilai_buku'] = df.groupby('kategori')['nilai_perolehan'].transform(
lambda x: x.fillna(x.median())
)

Create flag for estimated values
df['is_estimated'] = df['nilai_perolehan'].isnull().astype(int)
```
**Rule 4: Date Format Standardization**
```sql
-- Ensure all dates in ISO 8601 format (YYYY-MM-DD)
SELECT
CONVERT(DATE, tanggal_field, 23) AS tanggal_standardized
FROM source_table;
```
---

## Load Sequence & Dependencies

### 4.1 Load Order (Critical for Referential Integrity)

**Phase 1: Dimension Tables (No Dependencies)**

1. **dim_waktu** - Generated, no dependency
2. **dim_jenis_surat** - Independent
3. **dim_jenis_layanan** - Independent
4. **dim_lokasi** - Independent

**Phase 2: Dimension Tables (With Dependencies)**

5. **dim_unit_kerja** - Self-referencing, load top-down by level
6. **dim_pegawai** - Depends on dim_unit_kerja
7. **dim_barang** - Independent

**Phase 3: Fact Tables**

8. **fact_surat** - Depends on all dimensions loaded
9. **fact_aset** - Depends on dim_barang, dim_lokasi, dim_unit_kerja, dim_waktu
10. **fact_layanan** - Depends on dim_jenis_layanan, dim_pegawai, dim_unit_kerja, dim_waktu

### 4.2 Incremental Load Strategy

**Daily Incremental (Transactional Facts):**
```sql
-- fact_surat: Load surat with tanggal_diterima >= last_load_date
SELECT * FROM tbl_surat_masuk
WHERE tanggal_diterima >= @last_load_date;

-- fact_layanan: Load requests with timestamp_submit >= last_load_date
SELECT * FROM tbl_permintaan_layanan
WHERE timestamp_submit >= @last_load_date;
```
**Monthly Snapshot (Periodic Facts):**
```sql
-- fact_aset: Full snapshot on last day of month
SELECT * FROM tbl_inventaris
WHERE tanggal_snapshot = EOMONTH(GETDATE());
```
**Dimension Updates:**
- **SCD Type 1**: Overwrite changed records
- **SCD Type 2** (dim_pegawai): Insert new version, close old version

---

## Data Volume Estimates

| Table | Current Volume | 1 Year Projection | 3 Year Projection |
|-------|----------------|-------------------|-------------------|
| dim_waktu | 4,383 rows | N/A (static) | N/A |
| dim_unit_kerja | ~50 rows | ~55 rows | ~60 rows |
| dim_pegawai | ~700 rows (with history) | ~1,000 rows | ~1,500 rows |
| dim_jenis_surat | ~15 rows | ~20 rows | ~25 rows |
| dim_barang | ~2,500 rows | ~2,700 rows | ~3,000 rows |
| dim_lokasi | ~100 rows | ~120 rows | ~150 rows |
| dim_jenis_layanan | ~20 rows | ~25 rows | ~30 rows |
| **fact_surat** | **18,000 rows** | **22,800 rows** | **35,000 rows** |
| **fact_aset** | **30,000 rows** | **62,400 rows** | **97,200 rows** |
| **fact_layanan** | **5,400 rows** | **7,200 rows** | **12,000 rows** |

**Total Estimated Size:**
- **Year 0**: ~56K fact rows, ~3.4K dimension rows
- **Year 1**: ~93K fact rows, ~3.9K dimension rows
- **Year 3**: ~144K fact rows, ~4.6K dimension rows

---

## Appendix: Quick Reference

### A.1 Foreign Key Relationships

| Fact Table | Dimension | FK Column | PK Column |
|------------|-----------|-----------|-----------|
| fact_surat | dim_waktu | tanggal_key | tanggal_key |
| fact_surat | dim_jenis_surat | jenis_surat_key | jenis_surat_key |
| fact_surat | dim_unit_kerja | unit_pengirim_key | unit_key |
| fact_surat | dim_unit_kerja | unit_penerima_key | unit_key |
| fact_surat | dim_pegawai | pegawai_disposisi_key | pegawai_key |
| fact_aset | dim_waktu | tanggal_snapshot_key | tanggal_key |
| fact_aset | dim_barang | barang_key | barang_key |
| fact_aset | dim_lokasi | lokasi_key | lokasi_key |
| fact_aset | dim_unit_kerja | unit_kerja_key | unit_key |
| fact_layanan | dim_waktu | waktu_key | tanggal_key |
| fact_layanan | dim_jenis_layanan | jenis_layanan_key | jenis_layanan_key |
| fact_layanan | dim_pegawai | pegawai_pemohon_key | pegawai_key |
| fact_layanan | dim_unit_kerja | unit_tujuan_key | unit_key |

### A.2 Measure Types Summary

| Measure Type | Description | Example | Aggregation |
|--------------|-------------|---------|-------------|
| Additive | Can be summed across all dimensions | jumlah_surat, jumlah_permintaan | SUM, AVG, COUNT |
| Semi-additive | Can be summed across some dimensions (not time) | nilai_buku | AVG across time, SUM across others |
| Non-additive | Cannot be summed | rating_kepuasan, kondisi_score | AVG, MIN, MAX |

---

**Prepared by:** Kelompok 19 - Tugas Besar Pergudangan Data  
**Last Updated:** 12 November 2025, 00:54 WIB
