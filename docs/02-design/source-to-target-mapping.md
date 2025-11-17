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
| -          | -    | Constant 1                    | is_active  | BIT/BOOLEAN | 1 = unit kerja aktif (default); bisa diubah jika nanti ada flag non-aktif di source | → 1 |


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
| kode_jenis | VARCHAR(10) | UPPER(TRIM()) | kode_jenis_surat | VARCHAR(10) | Business key | um → UM |
| nama_jenis | VARCHAR(100) | TRIM(), INITCAP() | nama_jenis_surat | VARCHAR(100) | - | surat undangan → Surat Undangan |
| kategori | VARCHAR(50) | TRIM() | kategori | VARCHAR(50) | Internal, Eksternal, Edaran | Internal → Internal |
| sla_hari | INT | Direct | sla_hari | INT | Target processing days | 3 → 3 |
| sifat     | VARCHAR(20) | TRIM()          | sifat     | VARCHAR(20) | Sifat surat (Biasa/Penting/Rahasia/Segera) | Penting → Penting |
| -         | -           | Constant 1      | is_active | BIT         | 1 = jenis surat aktif                      | → 1               |


**Data Quality Rules:**
- kategori must be in ('Internal', 'Eksternal', 'Edaran', 'Umum')
- sla_hari default = 5 if NULL

---

### 1.5 DIM_BARANG (Item / Asset Dimension)

**Source System:** INVENTARIS_DB  
**Source Table:** tbl_inventaris (distinct by kode_barang)  
**Load Frequency:** On change (full reload kecil saat ada barang baru)  
**SCD Type:** Type 1 (overwrite)  
**Grain:** 1 baris per jenis barang unik (per kode_barang)

| Source Column    | Source Type    | Transformation                        | Target Column        | Target Type   | Business Rule                                                                                  | Sample Input → Output                |
|------------------|----------------|---------------------------------------|----------------------|---------------|-----------------------------------------------------------------------------------------------|--------------------------------------|
| id_barang        | INT            | Direct                                | barang_key           | INTEGER       | Surrogate key dim_barang (bisa diganti sequence di implementasi fisik).                      | 1001 → 1001                          |
| kode_barang      | VARCHAR(30)    | UPPER(TRIM())                         | kode_barang          | VARCHAR(30)   | Kode barang dari sistem inventaris; distandarkan ke huruf besar tanpa spasi ekstra.          | " inv/comp/2024/001 " → "INV/COMP/2024/001" |
| nama_barang      | VARCHAR(200)   | TRIM(), INITCAP()                     | nama_barang          | VARCHAR(200)  | Nama barang; huruf awal tiap kata kapital, spasi dirapikan.                                  | "laptop dell latitude 5420" → "Laptop Dell Latitude 5420" |
| kategori         | VARCHAR(50)    | TRIM()                                | kategori_barang      | VARCHAR(50)   | Kategori umum barang (Elektronik, Furnitur, Kendaraan, dll.); mapping cleaning di rules ETL. | " komputer " → "komputer"           |
| kategori         | VARCHAR(50)    | Mapping kategori → subkategori (opsional, via lookup) | subkategori_barang   | VARCHAR(50)   | Subkategori barang (Laptop, Proyektor, Kursi, dll.); hasil standardisasi kategori rinci.     | "komputer" → "Laptop"               |
| NULL             | -              | Constant 'unit'                       | satuan               | VARCHAR(20)   | Satuan default "unit" untuk sebagian besar aset; bisa diganti jika nanti ada field satuan.   | NULL → "unit"                        |
| nama_barang      | VARCHAR(200)   | Ekstrak merk dari awal nama (opsional) | merk                 | VARCHAR(50)   | Merk barang; dapat diisi manual atau menggunakan rule sederhana (kata pertama dari nama).    | "Laptop Dell Latitude 5420" → "Dell" |
| nama_barang      | VARCHAR(200)   | TRIM()                                | spesifikasi          | VARCHAR(255)  | Ringkasan spesifikasi teknis; sementara isi dengan nama lengkap jika belum ada detail lain. | "Laptop Dell Latitude 5420" → "Laptop Dell Latitude 5420" |
| kategori         | VARCHAR(50)    | CASE WHEN kategori ILIKE '%Kursi%' OR kategori ILIKE '%Meja%' THEN 0 ELSE 1 END | is_bergerak          | BOOLEAN       | Flag TRUE jika aset bersifat bergerak (umumnya elektronik/peralatan kecil), FALSE untuk furnitur besar. | "Komputer" → 1; "Meja Kerja" → 0    |
| kategori         | VARCHAR(50)    | CASE WHEN kategori ILIKE '%Komputer%' OR kategori ILIKE '%Laptop%' OR kategori ILIKE '%Printer%' THEN 1 ELSE 0 END | is_tik               | BOOLEAN       | TRUE jika aset termasuk kategori TIK (komputer, laptop, printer, dll.).                     | "Komputer" → 1; "Lemari Arsip" → 0  |


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

### 1.6 DIM_LOKASI (Location Dimension)

**Source System:** INVENTARIS_DB  
**Source Table:** ref_lokasi (atau distinct dari tbl_inventaris.lokasi_id + master ruangan)  
**Load Frequency:** On change (ketika ada lokasi/ruangan baru)  
**SCD Type:** Type 1 (overwrite)  
**Grain:** 1 baris per lokasi/ruangan unik  

| Source Column | Source Type | Transformation                                        | Target Column | Target Type   | Business Rule                                                                 | Sample Input → Output          |
|---------------|------------|-------------------------------------------------------|--------------|---------------|-------------------------------------------------------------------------------|--------------------------------|
| id_lokasi     | INT        | Direct                                                | lokasi_key   | INTEGER       | Surrogate key dim_lokasi (bisa diganti sequence di implementasi fisik).     | 1 → 1                          |
| id_lokasi     | INT        | CONCAT(gedung, '-', ruangan) atau kode master lain   | kode_lokasi  | VARCHAR(30)   | Kode lokasi/ruangan; kombinasi gedung-ruangan jika tidak ada kode baku.     | (Gedung Rektorat, R.201) → "REKTORAT-R.201" |
| ruangan       | VARCHAR(50)| TRIM(), INITCAP()                                    | nama_lokasi  | VARCHAR(100)  | Nama ruangan/lokasi; gunakan nama ruangan + konteks gedung jika perlu.      | "r.201" → "R.201"              |
| ruangan       | VARCHAR(50)| CASE WHEN ruangan ILIKE '%Rapat%' THEN 'Ruang Rapat' WHEN ruangan ILIKE '%Aula%' THEN 'Aula' ELSE 'Ruang Kerja' END | jenis_lokasi | VARCHAR(50)   | Jenis lokasi (Ruang Rapat, Aula, Kantor, Gudang, dll.) berdasarkan pola nama.| "R.201" → "Ruang Kerja"       |
| gedung        | VARCHAR(50)| TRIM(), INITCAP()                                    | gedung       | VARCHAR(50)   | Nama gedung tempat ruangan berada.                                           | "gedung rektorat" → "Gedung Rektorat" |
| lantai        | INT        | CAST(lantai AS VARCHAR)                              | lantai       | VARCHAR(10)   | Lantai disimpan sebagai teks agar fleksibel (Lantai 1, Basement, dll.).     | 2 → "2"                        |
| kapasitas     | INT        | CAST(kapasitas AS VARCHAR)                           | keterangan   | VARCHAR(255)  | Keterangan tambahan; sementara isi kapasitas atau catatan ringkas.          | 20 → "Kapasitas 20 orang"      |


---

### 1.7 DIM_JENIS_LAYANAN (Service Type Dimension)

**Source System:** LAYANAN_DB  
**Source Table:** ref_jenis_layanan  
**Load Frequency:** On change (full reload kecil, jarang berubah)  
**SCD Type:** Type 1 (overwrite)  
**Grain:** 1 baris per jenis layanan unik  

| Source Column     | Source Type  | Transformation                       | Target Column         | Target Type   | Business Rule                                                                                   | Sample Input → Output     |
|-------------------|-------------|--------------------------------------|-----------------------|---------------|--------------------------------------------------------------------------------------------------|---------------------------|
| id_jenis_layanan  | INT         | Direct                               | jenis_layanan_key     | INTEGER       | Surrogate key dim_jenis_layanan (bisa diganti sequence saat implementasi fisik).                | 3 → 3                     |
| kode_layanan      | VARCHAR(10) | UPPER(TRIM())                        | kode_jenis_layanan    | VARCHAR(10)   | Kode jenis layanan; distandarkan ke huruf besar tanpa spasi ekstra.                            | "lyn-pr " → "LYN-PR"      |
| nama_layanan      | VARCHAR(100)| TRIM(), INITCAP()                    | nama_jenis_layanan    | VARCHAR(100)  | Nama jenis layanan; huruf awal kapital, spasi dirapikan.                                       | "peminjaman ruangan" → "Peminjaman Ruangan" |
|

---

## Fact Tables Mapping

### 2.1 FACT_SURAT (Letter Transactions)

**Source System:** SIMASTER_DB  
**Source Tables:** tbl_surat_masuk, tbl_disposisi, ref_jenis_surat  
**Load Frequency:** Daily (incremental)  
**Grain:** 1 baris per surat individual  
**Fact Type:** Transaction  

| Source Table      | Source Column        | Source Type | Transformation                                                                 | Target Column          | Target Type      | Measure Type | Business Rule                                                                                       |
|-------------------|----------------------|-------------|--------------------------------------------------------------------------------|------------------------|------------------|--------------|-----------------------------------------------------------------------------------------------------|
| -                 | -                    | -           | Generated                                                                      | surat_key              | BIGINT           | -            | Surrogate key (identity/sequence).                                                                  |
| tbl_surat_masuk   | tanggal_diterima     | DATE        | Lookup dim_waktu.tanggal_key                                                   | tanggal_key            | INTEGER          | -            | FK ke dim_waktu berdasarkan tanggal_diterima.                                                       |
| tbl_surat_masuk   | pengirim             | VARCHAR     | Lookup dim_unit_kerja berdasarkan nama unit; jika tidak cocok → key unit eksternal | unit_pengirim_key      | INTEGER          | -            | FK ke dim_unit_kerja (role: Pengirim).                                                              |
| tbl_surat_masuk   | disposisi_ke         | VARCHAR     | Lookup dim_unit_kerja berdasarkan nama unit tujuan disposisi                  | unit_penerima_key      | INTEGER          | -            | FK ke dim_unit_kerja (role: Penerima).                                                              |
| tbl_disposisi     | kepada_pegawai_id    | INT         | Lookup dim_pegawai (record current)                                            | pegawai_penerima_key   | INTEGER          | -            | FK ke dim_pegawai penerima/disposisi akhir.                                                         |
| tbl_surat_masuk   | jenis_surat_id       | INT         | Lookup dim_jenis_surat.jenis_surat_key                                         | jenis_surat_key        | INTEGER          | -            | FK ke dim_jenis_surat.                                                                              |
| tbl_surat_masuk   | nomor_surat          | VARCHAR(50) | Direct                                                                         | nomor_surat            | VARCHAR(50)      | -            | Degenerate dimension (nomor surat).                                                                 |
| tbl_surat_masuk   | file_path            | VARCHAR(255)| CASE WHEN file_path IS NOT NULL THEN 1 ELSE 0 END                              | jumlah_lampiran        | INTEGER          | Additive     | Asumsi 1 lampiran per file_path; 0 jika tidak ada file lampiran.                                   |
| tbl_surat_masuk   | tanggal_diterima     | DATE        | DATEDIFF(day, tanggal_diterima, d.tanggal_selesai) jika status selesai         | durasi_proses_hari     | INTEGER          | Additive     | Selisih hari dari tanggal_diterima sampai tanggal_selesai; NULL jika belum selesai.                |
| tbl_surat_masuk   | jenis_surat_id       | INT         | Join ke ref_jenis_surat.sla_hari, bandingkan dengan durasi_proses_hari        | melewati_sla_flag      | BIT/BOOLEAN      | Additive     | 1 jika durasi_proses_hari > sla_hari, else 0; NULL jika durasi_proses_hari NULL.                   |
| tbl_disposisi     | status               | VARCHAR(20) | COALESCE(d.status, s.status)                                                   | status_akhir           | VARCHAR(20)      | -            | Status akhir surat (Selesai/Pending/Dibatalkan/Arsip) mengambil prioritas dari disposisi jika ada. |
| tbl_surat_masuk   | status               | VARCHAR(20) | CASE WHEN status IN ('E-Office','Digital') OR file_path IS NOT NULL THEN 'Sistem' ELSE 'Fisik' END | channel                | VARCHAR(20)      | -            | Kanal surat: Sistem (digital) atau Fisik, berdasarkan kombinasi status/file_path.                  |
| -                 | -                    | -           | Constant 1                                                                     | jumlah_surat           | INTEGER          | Additive     | 1 per baris fact, untuk agregasi jumlah surat.                                                      |


**Complex Transformation Notes:**
```sql
-- Calculate durasi_proses_hari only for completed letters
durasi_proses_hari =
CASE
WHEN d.status_akhir = 'Selesai' AND d.tanggal_selesai IS NOT NULL
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
d.status_akhir
FROM tbl_surat_masuk s
LEFT JOIN tbl_disposisi d ON s.id_surat = d.id_surat
WHERE d.status_akhir = 'Selesai' OR d.id_disposisi IS NULL;
```
---

### 2.2 FACT_ASET (Asset Inventory Snapshots)

**Source System:** INVENTARIS_DB  
**Source Tables:** tbl_inventaris, ref_barang, ref_lokasi, ref_unit_kerja  
**Load Frequency:** Bulanan (snapshot di akhir bulan)  
**Grain:** 1 baris per aset (barang) per tanggal snapshot  
**Fact Type:** Periodic Snapshot  

| Source Table   | Source Column        | Source Type | Transformation                                                                                       | Target Column           | Target Type       | Measure Type | Business Rule                                                                                                     |
|----------------|----------------------|-------------|------------------------------------------------------------------------------------------------------|-------------------------|-------------------|--------------|-------------------------------------------------------------------------------------------------------------------|
| -              | -                    | -           | Generated                                                                                            | aset_snapshot_key       | BIGINT            | -            | Surrogate key fact_aset (identity/sequence).                                                                      |
| ETL_SNAPSHOT   | snapshot_date        | DATE        | Lookup dim_waktu.tanggal_key                                                                         | tanggal_snapshot_key    | INTEGER           | -            | FK ke dim_waktu berdasarkan tanggal snapshot (misal akhir bulan).                                                |
| tbl_inventaris | kode_barang          | VARCHAR(30) | Lookup dim_barang.barang_key                                                                         | barang_key              | INTEGER           | -            | FK ke dim_barang berdasarkan kode_barang.                                                                         |
| tbl_inventaris | lokasi_id            | INT         | Lookup dim_lokasi.lokasi_key                                                                         | lokasi_key              | INTEGER           | -            | FK ke dim_lokasi tempat aset berada saat snapshot.                                                                |
| tbl_inventaris | unit_kerja_id        | INT         | Lookup dim_unit_kerja.unit_key                                                                       | unit_pemilik_key        | INTEGER           | -            | FK ke dim_unit_kerja sebagai pemilik/pengguna aset.                                                               |
| tbl_inventaris | jumlah_unit          | INT         | COALESCE(jumlah_unit, 1)                                                                             | jumlah_unit             | INTEGER           | Additive     | Jumlah unit aset pada baris tersebut; default 1 jika NULL.                                                        |
| tbl_inventaris | nilai_perolehan      | NUMERIC     | CAST(nilai_perolehan AS NUMERIC(18,2))                                                               | nilai_perolehan         | NUMERIC(18,2)     | Additive     | Nilai perolehan total aset (per jumlah_unit).                                                                    |
| tbl_inventaris | nilai_perolehan      | NUMERIC     | Hitung nilai buku berdasarkan umur ekonomis dan umur pakai (misal metode garis lurus)                | nilai_buku              | NUMERIC(18,2)     | Additive     | Nilai buku pada tanggal snapshot; aturan depresiasi dirinci di dokumen ETL/finance (bisa diset = nilai_perolehan pada versi awal). |
| tbl_inventaris | umur_ekonomis_tahun  | DECIMAL     | CAST(umur_ekonomis_tahun AS DECIMAL(5,2))                                                            | umur_ekonomis_tahun     | DECIMAL(5,2)      | -            | Umur ekonomis aset dalam tahun (dari kebijakan akuntansi/inventaris).                                            |
| tbl_inventaris | tahun_perolehan      | INT         | (tahun_snapshot - tahun_perolehan) dibatasi minimal 0                                                | umur_tersisa_tahun      | DECIMAL(5,2)      | -            | Perkiraan umur ekonomis tersisa = umur_ekonomis_tahun - umur_pakai; 0 jika sudah melewati umur ekonomis.         |
| tbl_inventaris | kondisi              | VARCHAR(20) | Normalisasi ke nilai master (Baik/Rusak Ringan/Rusak Berat/Dihapus)                                  | kondisi                 | VARCHAR(20)       | -            | Kondisi aset pada saat snapshot.                                                                                  |
| tbl_inventaris | status_pemanfaatan   | VARCHAR(20) | Normalisasi ke nilai master (Aktif/Tidak Terpakai/Dipinjamkan/Dihapus)                              | status_pemanfaatan      | VARCHAR(20)       | -            | Status pemanfaatan aset pada saat snapshot.                                                                       |


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
-- Monthly snapshot on last day of month
DECLARE @SnapshotDate DATE = EOMONTH(GETDATE());

INSERT INTO fact_aset (
tanggal_snapshot_key,
barang_key,
lokasi_key,
unit_pemilik_key,
jumlah_unit,
nilai_perolehan,
nilai_buku,
umur_ekonomis_tahun,
umur_tersisa_tahun,
kondisi,
status_pemanfaatan
)
SELECT
dw.tanggal_key AS tanggal_snapshot_key,
b.barang_key AS barang_key,
l.lokasi_key AS lokasi_key,
u.unit_key AS unit_pemilik_key,
COALESCE(i.jumlah_unit, 1) AS jumlah_unit,
COALESCE(i.nilai_perolehan, 0) AS nilai_perolehan,
-- Versi awal: nilai_buku = nilai_perolehan (belum pakai depresiasi penuh)
COALESCE(i.nilai_perolehan, 0) AS nilai_buku,
i.umur_ekonomis_tahun AS umur_ekonomis_tahun,
-- Umur tersisa = umur ekonomis - umur pakai (dibatasi minimum 0)
CASE
WHEN i.umur_ekonomis_tahun IS NULL
OR i.tahun_perolehan IS NULL THEN NULL
ELSE
GREATEST(
i.umur_ekonomis_tahun
- DATEDIFF(year, DATEFROMPARTS(i.tahun_perolehan,1,1), @SnapshotDate),
0
)
END AS umur_tersisa_tahun,
i.kondisi AS kondisi,
i.status_pemanfaatan AS status_pemanfaatan
FROM tbl_inventaris i
INNER JOIN dim_barang b ON i.kode_barang = b.kode_barang
INNER JOIN dim_lokasi l ON i.lokasi_id = l.lokasi_key
INNER JOIN dim_unit_kerja u ON i.unit_kerja_id = u.unit_key
INNER JOIN dim_waktu dw ON dw.tanggal = @SnapshotDate
WHERE i.tanggal_snapshot = @SnapshotDate;
---

### 2.3 FACT_LAYANAN (Service Requests)

**Source System:** LAYANAN_DB  
**Source Tables:** tbl_permintaan_layanan, ref_jenis_layanan, ref_unit, ref_pegawai  
**Load Frequency:** Daily (incremental)  
**Grain:** 1 baris per permintaan layanan (ticket)  
**Fact Type:** Transaction  

| Source Table           | Source Column          | Source Type | Transformation                                                                                   | Target Column                | Target Type       | Measure Type | Business Rule                                                                                                      |
|------------------------|------------------------|-------------|--------------------------------------------------------------------------------------------------|------------------------------|-------------------|--------------|--------------------------------------------------------------------------------------------------------------------|
| -                      | -                      | -           | Generated                                                                                        | layanan_key                  | BIGINT            | -            | Surrogate key fact_layanan (identity/sequence).                                                                    |
| tbl_permintaan_layanan | timestamp_submit       | DATETIME    | Lookup dim_waktu.tanggal_key                                                                    | tanggal_request_key          | INTEGER           | -            | FK ke dim_waktu berdasarkan tanggal permintaan dibuat.                                                             |
| tbl_permintaan_layanan | tanggal_selesai        | DATETIME    | Lookup dim_waktu.tanggal_key (NULL jika belum selesai)                                         | tanggal_selesai_key          | INTEGER           | -            | FK ke dim_waktu berdasarkan tanggal permintaan selesai; NULL jika belum selesai.                                  |
| tbl_permintaan_layanan | unit_pemohon_id        | INT         | Lookup dim_unit_kerja.unit_key                                                                  | unit_pemohon_key             | INTEGER           | -            | FK ke dim_unit_kerja sebagai unit pemohon layanan.                                                                 |
| tbl_permintaan_layanan | unit_pelaksana_id      | INT         | Lookup dim_unit_kerja.unit_key                                                                  | unit_pelaksana_key           | INTEGER           | -            | FK ke dim_unit_kerja sebagai unit pelaksana layanan.                                                               |
| tbl_permintaan_layanan | pemohon_nip            | VARCHAR(20) | Lookup dim_pegawai.pegawai_key (record current)                                                 | pegawai_pemohon_key          | INTEGER           | -            | FK ke dim_pegawai sebagai pemohon/pengaju layanan.                                                                 |
| tbl_permintaan_layanan | penanggung_jawab_nip   | VARCHAR(20) | Lookup dim_pegawai.pegawai_key (record current)                                                 | pegawai_penanggung_jawab_key | INTEGER           | -            | FK ke dim_pegawai sebagai penanggung jawab pelaksanaan layanan.                                                    |
| tbl_permintaan_layanan | jenis_layanan_id       | INT         | Lookup dim_jenis_layanan.jenis_layanan_key                                                      | jenis_layanan_key            | INTEGER           | -            | FK ke dim_jenis_layanan.                                                                                           |
| tbl_permintaan_layanan | nomor_tiket            | VARCHAR(30) | UPPER(TRIM())                                                                                   | nomor_tiket                  | VARCHAR(30)       | -            | Nomor tiket unik permintaan layanan (degenerate dimension).                                                        |
| ref_jenis_layanan      | sla_hari               | INT         | sla_hari * 24                                                                                    | sla_target_jam               | INTEGER           | -            | SLA target penyelesaian dalam jam (konversi dari hari * 24).                                                       |
| tbl_permintaan_layanan | timestamp_submit       | DATETIME    | DATEDIFF(hour, timestamp_submit, first_response_time)                                           | waktu_respon_jam             | DECIMAL(10,2)     | Additive     | Waktu dari submit sampai respons pertama dicatat; NULL jika belum ada respons (opsional jika kolom tersedia).    |
| tbl_permintaan_layanan | timestamp_submit       | DATETIME    | DATEDIFF(hour, timestamp_submit, tanggal_selesai)                                               | waktu_selesai_jam            | DECIMAL(10,2)     | Additive     | Waktu dari submit sampai status selesai; NULL jika belum selesai.                                                 |
| -                      | -                      | -           | CASE WHEN waktu_selesai_jam IS NULL THEN NULL WHEN waktu_selesai_jam > sla_target_jam THEN 1 ELSE 0 END | melewati_sla_flag            | BIT/BOOLEAN       | Additive     | 1 jika `waktu_selesai_jam` > `sla_target_jam`; 0 jika ≤ SLA; NULL jika layanan belum selesai.                     |
| tbl_permintaan_layanan | rating_kepuasan        | DECIMAL(2,1)| CAST(rating_kepuasan AS DECIMAL(2,1))                                                           | rating_kepuasan              | DECIMAL(2,1)      | Semi-additive| Rating kepuasan pemohon (skala 1–5) dari sistem layanan.                                                           |
| tbl_permintaan_layanan | biaya_layanan          | MONEY/NUM   | CAST(biaya_layanan AS NUMERIC(18,2))                                                            | biaya_layanan                | NUMERIC(18,2)     | Additive     | Biaya aktual layanan (jika tersedia); 0 jika layanan tidak berbiaya.                                              |
| tbl_permintaan_layanan | status_penyelesaian    | VARCHAR(20) | Normalisasi ke nilai master (Selesai/Dibatalkan/Ditolak/In Progress)                            | status_akhir                 | VARCHAR(20)       | -            | Status akhir tiket layanan.                                                                                        |
| -                      | -                      | -           | Constant 1                                                                                       | jumlah_permintaan            | INTEGER           | Additive     | 1 per baris fact, digunakan untuk agregasi jumlah permintaan layanan.                                             |


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
melewati_sla_flag =
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
| fact_surat | dim_pegawai | pegawai_penerima_key | pegawai_key |
| fact_aset | dim_waktu | tanggal_snapshot_key | tanggal_key |
| fact_aset | dim_barang | barang_key | barang_key |
| fact_aset | dim_lokasi | lokasi_key | lokasi_key |
| fact_aset | dim_unit_kerja | unit_pemilik_key | unit_key |
| fact_layanan | dim_waktu | tanggal_request_key | tanggal_key |
| fact_layanan | dim_jenis_layanan | jenis_layanan_key | jenis_layanan_key |
| fact_layanan | dim_pegawai | pegawai_pemohon_key | pegawai_key |
| fact_layanan | dim_unit_kerja | unit_pelaksana_key | unit_key |

### A.2 Measure Types Summary

| Measure Type | Description | Example | Aggregation |
|--------------|-------------|---------|-------------|
| Additive | Can be summed across all dimensions | jumlah_surat, jumlah_permintaan | SUM, AVG, COUNT |
| Semi-additive | Can be summed across some dimensions (not time) | nilai_buku | AVG across time, SUM across others |
| Non-additive | Cannot be summed | rating_kepuasan, kondisi_score | AVG, MIN, MAX |

---

**Prepared by:** Kelompok 19 - Tugas Besar Pergudangan Data  
**Last Updated:** 12 November 2025, 00:54 WIB
