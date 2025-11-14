# 📊 Data Mart Biro Akademik Umum - Institut Teknologi Sumatera

![Logo Tugas Besar Data Warehouse Gasal 2025](https://github.com/sains-data/Data-Warehouse-2025-Gasal/blob/main/Logo-DW-Gasal-2025.gif)

**Tugas Besar Pergudangan Data (SD25-31007)**  
**Program Studi Sains Data - Fakultas Sains**  
**Tahun Ajaran 2025**

---

## 👥 Tim Pengembang - Kelompok [19]

| NIM | Nama | Role | Email |
|-----|------|------|-------|
| 123450093 | Syahrialdi Rachim Akbar | Project Lead & Database Designer | Syahrialdi.123450093@student.itera.ac.id |
| 123450026 | ZAHRA PUTRI SALSABILLA | ETL Developer & Data Engineer | Zahra.123450093@student.itera.ac.id  |
| 123450039| FEBY ANGELINA| BI Developer & Documentation | Feby.123450093@student.itera.ac.id  |

---

## 📋 Project Overview

Data Mart ini dirancang untuk mendukung pengambilan keputusan berbasis data di **Biro Akademik Umum ITERA**, yang bertanggung jawab atas:
- Pengelolaan surat-menyurat dan kearsipan
- Manajemen inventaris dan aset institusi
- Administrasi kepegawaian
- Pelayanan kesekretariatan
- Monitoring dan evaluasi kinerja administrasi

---
## Misi 1 - Deliverables

Paket artefak desain dan perencanaan data mart yang dikumpulkan untuk Misi 1.

- Business Requirements
    - [Business Requirements](docs/01-requirements/business-requirements.md)
    - Ringkasan tujuan, ruang lingkup, proses bisnis, KPI, dan use cases.

- Data Sources Inventory
    - [Data Sources Inventory](docs/01-requirements/data-sources.md)
    - Daftar sistem sumber, tabel kunci, volume/refresh rate, risiko kualitas data, dan akses.

- Dimensional Design
    - ERD (Star Schema): [Dimensional Model](docs/02-design/dimensional-model.svg)
    - [Bus Matrix](docs/02-design/bus-matrix.md)
    - [Data Dictionary](docs/02-design/data-dictionary.md)
    - Catatan: tiap fact memiliki grain eksplisit, setiap dimensi memiliki kunci, tipe data, dan definisi kolom.

- ETL Design
  - [Source-to-Target Mapping](docs/02-design/source-to-target-mapping.md)
  - [ETL Strategy](docs/02-design/etl-strategy.md)
  - Memuat: urutan load, incremental vs snapshot, SCD policy, data quality checks, logging & alerting.

- Database Bootstrap (PostgreSQL)
  - [Create Database PostgreSQL](sql/01_Create_Database_PostgreSQL.sql)
  - Membuat schemas (stg, dim, fact, etl_log, dw, analytics, reports), tabel metadata/logging, staging tables, serta indeks dasar; idempotent dan siap dieksekusi di pgAdmin4.

- Cara Menjalankan (Quick Start – Misi 1)
  1. Buat database PostgreSQL: datamart_bau_itera (via pgAdmin4).
  2. Buka Query Tool pada DB tersebut, jalankan: [Create Database PostgreSQL](sql/01_Create_Database_PostgreSQL.sql)
  3. Verifikasi schemas dan tabel: lihat catatan “VALIDATION QUERIES” di akhir skrip.
 
- Status & Versi
  - Status: Final untuk Misi 1
  - Versi Dokumen: v2.0

  ---

## 🎯 Business Domain: Biro Akademik Umum ITERA

### Proses Bisnis Utama:
1. Mengelola surat-menyurat dan kearsipan dokumen institusi
2. Mengelola inventaris, aset, dan pengadaan perlengkapan kerja
3. Melaksanakan administrasi dan pengembangan kepegawaian
4. Memberikan pelayanan kesekretariatan dan operasional harian
5. Melaksanakan monitoring, evaluasi, dan pelaporan kinerja administrasi

### Key Performance Indicators (KPIs):

**1. Efektivitas Layanan:**
- Tingkat akurasi pencatatan surat (target: >98%, diukur bulanan)
- Waktu pencarian arsip (target: <15 menit, diukur per kasus)
- Waktu respon terhadap permintaan layanan (target: <24 jam, diukur harian)

**2. Pengelolaan Aset & Data:**
- Persentase aset terlabeli dan tercatat (target: 100%, diukur semester)
- Akurasi data kepegawaian (target: 100%, diukur triwulan)

**3. Kinerja Strategis:**
- Ketepatan waktu pelaporan rutin (target: 100%, diukur bulanan)
- Tingkat kepuasan civitas akademika (target: >4.0/5.0, diukur semester)

---

## 🏗️ Arsitektur Data Warehouse

- **Approach:** Kimball Dimensional Modeling (Star Schema)
- **Database:** SQL Server 2019 on Azure VM
- **ETL:** SQL Server Integration Services (SSIS) / T-SQL Stored Procedures
- **Visualization:** Power BI Desktop
- **Version Control:** GitHub

### Data Model (Coming Soon)
![Dimensional Model](docs/02-design/dimensional-model.png)

**Fact Tables:**
- Fact_Surat_Menyurat
- Fact_Peminjaman_Ruangan
- Fact_Pengadaan (optional)

**Dimension Tables:**
- Dim_Date (Time dimension)
- Dim_Unit (Fakultas, Jurusan, Biro)
- Dim_Ruangan (Ruangan & Fasilitas)
- Dim_Jenis_Surat
- Dim_Status
- Dim_Peminjam

---

## 📁 Repository Structure
```
├── README.md
├── .gitignore
├── docs/
│   ├── 01-requirements/
│   │   ├── business-requirements.md
│   │   └── data-sources.md
│   ├── 02-design/
│   │   ├── ERD.png
│   │   ├── dimensional-model.png
│   │   └── data-dictionary.xlsx
│   ├── 03-implementation/
│   │   ├── etl-documentation.md
│   │   ├── user-manual.pdf
│   │   └── operations-manual.pdf
│   └── presentations/
├── sql/
│   ├── 01_Create_Database.sql
│   ├── 02_Create_Dimensions.sql
│   ├── 03_Create_Facts.sql
│   ├── 04_Create_Indexes.sql
│   ├── 05_Create_Partitions.sql
│   ├── 06_Create_Staging.sql
│   ├── 07_ETL_Procedures.sql
│   ├── 08_Data_Quality_Checks.sql
│   ├── 09_Test_Queries.sql
│   ├── 10_Security.sql
│   └── 11_Backup.sql
├── etl/
│   ├── packages/
│   └── scripts/
├── dashboards/
└── tests/
```

---

## 📅 Project Timeline

| Misi | Kegiatan Utama | Target Selesai |
|------|----------------|----------------|
| **Misi 1** | Desain Konseptual & Logikal | Minggu 1 |
| **Misi 2** | Desain Fisikal & Development | Minggu 2 |
| **Misi 3** | Implementasi Produksi & Dashboard | Minggu 3 |

---

## 📊 Dashboards (Coming Soon)

1. **Executive Dashboard** - High-level KPIs dan trend analysis
2. **Operational Dashboard** - Detail monitoring operasional harian
3. **Custom Reports** - Ad-hoc analysis dan deep-dive

---

## 📚 Documentation

- [Business Requirements](docs/01-requirements/business-requirements.md)
- [Data Sources](docs/01-requirements/data-sources.md)
- [ERD & Dimensional Model](docs/02-design/)
- [Data Dictionary](docs/02-design/data-dictionary.xlsx)
- [ETL Documentation](docs/03-implementation/etl-documentation.md)
- [User Manual](docs/03-implementation/user-manual.pdf)
- [Operations Manual](docs/03-implementation/operations-manual.pdf)

---

## 🔒 Security

- Role-based access control (RBAC)
- Data masking untuk informasi sensitif
- Audit trail untuk semua modifikasi data
- Backup otomatis harian

---

## 📞 Contact

Untuk pertanyaan atau issue, silakan hubungi team lead atau buat issue di repository ini.

---

## 📜 License

Project ini dikembangkan untuk keperluan akademik mata kuliah **Pergudangan Data (SD25-31007)** - Program Studi Sains Data, Fakultas Sains, Institut Teknologi Sumatera.

---

> *"Turning raw data into actionable insight - through collaboration, modeling, and analytics."*  
> **Tim Pergudangan Data 2025**
