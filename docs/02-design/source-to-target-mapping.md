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
`-- Generate date dimension 2019-2030
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
END;`
---


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

`-- When jabatan or unit_kerja_id changes:
-- Step 1: Update existing record
UPDATE dim_pegawai
SET end_date = GETDATE() - 1, is_current = 0
WHERE nip = @nip AND is_current = 1;

-- Step 2: Insert new record
INSERT INTO dim_pegawai (nip, nama, jabatan, unit_key, status_kepegawaian, tanggal_masuk, email, no_hp, effective_date, end_date, is_current)
VALUES (@nip, @nama, @jabatan_new, @unit_key_new, @status, @tanggal_masuk, @email, @no_hp, GETDATE(), '9999-12-31', 1);`
---


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
`Python transformation
kategori_mapping = {
'PC': 'Komputer',
'Laptop': 'Komputer',
'Notebook': 'Komputer',
'Printer': 'Peralatan Elektronik',
'AC': 'Peralatan Elektronik',
'Meja': 'Furniture',
'Kursi': 'Furniture',
'Lemari': 'Furniture'
}`

Apply mapping
`df['kategori'] = df['kategori'].map(kategori_mapping).fillna('Lainnya')`
---


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
`-- Calculate waktu_proses_hari only for completed letters
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
END;`

**Join Logic:**
`SELECT
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
WHERE d.status = 'Selesai' OR d.id_disposisi IS NULL;'

