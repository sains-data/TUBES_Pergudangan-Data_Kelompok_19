# Misi 1 – Summary & Deliverables

**Tim:** Kelompok 19 – Data Mart Biro Akademik Umum ITERA  
**Ruang Lingkup:** Data mart untuk mendukung pengelolaan surat, layanan sekretariat, dan inventaris aset pada Biro Akademik Umum ITERA.  

## 1. Tujuan Misi 1

Misi 1 berfokus pada tahap desain dan perencanaan data warehouse, tanpa implementasi ETL penuh atau pengisian data produksi.  
Target utama: mendefinisikan kebutuhan bisnis, memetakan sumber data, merancang model dimensional, dan menyiapkan desain ETL di level dokumentasi serta struktur database dasar.  

## 2. Ringkasan Proses Bisnis & KPI

Proses bisnis utama yang dicakup:  
- Pengelolaan surat masuk & keluar (persuratan / SIMASTER).  
- Pengelolaan permintaan layanan (ticketing layanan sekretariat).  
- Pengelolaan inventaris dan aset kantor.  
- Monitoring dan evaluasi kinerja administrasi melalui KPI yang terkait surat, layanan, dan aset.  

Contoh KPI yang didukung:  
- Waktu penyelesaian surat dan permintaan layanan.  
- Volume surat dan layanan per unit kerja dan per periode.  
- Kondisi dan nilai aset per unit dan per lokasi.  

## 3. Deliverables Misi 1

### 3.1 Requirements & Sumber Data

- **Business Requirements**  
  - File: [Business Requirements](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/docs/01-requirements/business-requirements.md)  
  - Berisi tujuan bisnis, ruang lingkup, stakeholder, proses bisnis, dan KPI utama yang akan dianalisis.  

- **Data Source Inventory**  
  - File: [Data Sources](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/docs/01-requirements/data-sources.md)  
  - Berisi daftar sistem sumber (SIMASTER, Inventaris Aset, SIMPEG, Log Layanan, Monitoring, Master Unit), struktur tabel penting, volume data, frekuensi update, serta isu kualitas data.  

### 3.2 Dimensional Design

- **ERD (Star Schema)**  
  - File: [Dimensional Model](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/docs/02-design/ERD.mmd)  
  - Menggambarkan tiga tabel fakta utama (Surat, Layanan, Aset) dan tabel dimensi terkait (Waktu, Unit Kerja, Pegawai, Jenis Surat, Jenis Layanan, Barang, Lokasi).  

- **Bus Matrix**  
  - File: [Bus Matrix](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/docs/02-design/bus-matrix.md)
  - Matriks proses bisnis × dimensi yang menunjukkan dimensi mana saja yang digunakan oleh setiap fact serta grain per proses bisnis.  

- **Data Dictionary**  
  - File: [Data Dictionary](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/docs/02-design/data-dictionary.md)  
  - Menjelaskan definisi kolom untuk setiap fact dan dimensi, termasuk tipe data logis, makna bisnis, contoh nilai, serta aturan validasi dasar.  

### 3.3 ETL Design

- **Source-to-Target Mapping (S2T)**  
  - File: [Source-to-Target Mapping](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/docs/02-design/source-to-target-mapping.md)  
  - Mendokumentasikan mapping field-level dari tabel sumber ke tabel dim/dimensi dan fact, termasuk: konversi tipe data, lookup keys, SCD policy, aturan pembersihan data, dan perhitungan measure.  

- **ETL Strategy**  
  - File: [ETL Strategy](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/docs/02-design/etl-strategy.md)  
  - Menjelaskan arsitektur ETL (staging → transform → DW), urutan load dimensi dan fakta, strategi incremental vs snapshot, mekanisme logging & error handling, serta rencana data quality checks.  

### 3.4 Database Bootstrap (PostgreSQL)

- **Create Database & Schemas Script**  
  - File: [Create Database PostgreSQL](https://github.com/FebyAngelina/TUBES_Pergudangan-Data_Kelompok-19/blob/main/sql/01_Create_Database.sql)  
  - Membuat schema utama (`stg`, `dim`, `fact`, `etl_log`, `dw`, `analytics`, `reports`), tabel metadata `dw.etl_metadata`, staging tables untuk setiap sumber data, tabel logging ETL (`etl_log.job_execution`, `etl_log.data_quality_checks`, `etl_log.error_details`), serta indeks dasar.  
  - Skrip bersifat idempotent dan telah diuji di PostgreSQL melalui pgAdmin4.  

## 4. Cara Menjalankan (Quick Start Misi 1)

1. **Siapkan database PostgreSQL**  
   - Buat database baru dengan nama `datamart_bau_itera` melalui pgAdmin4.  

2. **Jalankan skrip bootstrap**  
   - Buka Query Tool pada database `datamart_bau_itera`.  
   - Jalankan file `sql/01_Create_Database_PostgreSQL.sql`.  

3. **Verifikasi struktur**  
   - Pastikan schema `stg`, `dim`, `fact`, `etl_log`, `dw`, `analytics`, `reports` sudah terbentuk.  
   - Cek tabel metadata dan logging, misalnya `dw.etl_metadata` dan `etl_log.job_execution`.  

> Catatan: Pada Misi 1, belum ada kewajiban mengisi data nyata; data sintetis dan implementasi ETL detail akan dilanjutkan pada Misi 2.

## 5. Status & Next Steps

- **Status Misi 1:**  
  - Requirements, sumber data, desain dimensional, dan desain ETL sudah terdokumentasi.  
  - Struktur database dasar PostgreSQL sudah siap untuk uji coba ETL pada Misi 2.  

- **Rencana Misi 2 (high-level):**  
  - Menyusun skrip `02_Create_Dimensions.sql` dan `03_Create_Facts.sql`.  
  - Menyiapkan data sintetis sesuai struktur sumber.  
  - Mengimplementasikan prosedur ETL awal dan melakukan pengujian integrasi end-to-end.  
