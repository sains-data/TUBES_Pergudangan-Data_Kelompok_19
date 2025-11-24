# 📊 Data Mart Biro Akademik Umum - Institut Teknologi Sumatera

![Logo Tugas Besar Data Warehouse Gasal 2025](https://github.com/sains-data/Data-Warehouse-2025-Gasal/blob/main/Logo-DW-Gasal-2025.gif)

**Tugas Besar Pergudangan Data (SD25-31007)**  
**Program Studi Sains Data - Fakultas Sains**  
**Institut Teknologi Sumatera**  
**Tahun Ajaran 2024/2025**

![Status](https://img.shields.io/badge/Status-Active-brightgreen)
![Misi 1](https://img.shields.io/badge/Misi%201-Complete-success)
![Misi 2](https://img.shields.io/badge/Misi%202-Complete-success)
![Misi 3](https://img.shields.io/badge/Misi%203-In%20Progress-yellow)
![Documentation](https://img.shields.io/badge/Documentation-Excellent-blue)

---

## 👥 Tim Pengembang - Kelompok 19

| NIM | Nama | Role | Kontribusi | Email |
|-----|------|------|------------|-------|
| 123450093 | **Syahrialdi Rachim Akbar** | Project Lead & Database Designer | ERD, Schema Design, DDL Scripts | Syahrialdi.123450093@student.itera.ac.id |
| 123450026 | **Zahra Putri Salsabilla** | ETL Developer & Data Engineer | ETL Procedures, Data Quality | Zahra.123450026@student.itera.ac.id |
| 123450039 | **Feby Angelina** | BI Developer & Documentation | Documentation, Mapping, Sample Data | Feby.123450039@student.itera.ac.id |

---

## 📖 Tentang Project

Data Mart Biro Akademik Umum (BAU) ITERA adalah solusi Business Intelligence yang dirancang untuk mendukung pengambilan keputusan berbasis data di **Biro Akademik Umum ITERA**. Project ini mengintegrasikan dan menganalisis data dari berbagai sistem sumber guna mendukung pengambilan keputusan operasional dan strategis.

### 🎯 Tujuan

- Mengintegrasikan data dari 6 sistem sumber (SIMASTER, Inventaris, SIMPEG, Layanan, Monitoring, Unit Organisasi)
- Menyediakan dimensional model (Star Schema) untuk analisis data yang efisien
- Membangun dashboard interaktif untuk monitoring KPI
- Implementasi ETL process yang robust dan scalable
- Mendukung proses bisnis utama BAU ITERA

### 📊 Ruang Lingkup

**Area Tanggung Jawab BAU:**
- Pengelolaan surat-menyurat dan kearsipan dokumen institusi
- Manajemen inventaris, aset, dan pengadaan perlengkapan kerja
- Administrasi dan pengembangan kepegawaian
- Pelayanan kesekretariatan dan operasional harian
- Monitoring, evaluasi, dan pelaporan kinerja administrasi

**Dimensi (7 tables):**
- `dim.waktu` - Time dimension (2020-2030)
- `dim.pegawai` - Employee dimension (SCD Type 2)
- `dim.unit_organisasi` - Organizational hierarchy
- `dim.jenis_surat` - Document types & SLA
- `dim.jenis_layanan` - Service types & SLA
- `dim.jenis_aset` - Asset types & specifications
- `dim.status_layanan` - Service status definitions

**Fakta (3 tables):**
- `fact.surat` - Correspondence transactions (Grain: per surat)
- `fact.layanan` - Service requests & performance (Grain: per tiket)
- `fact.aset` - Asset inventory snapshots (Grain: per aset per bulan)

---

## 🏗️ Arsitektur Data Warehouse

### Technology Stack

| Komponen | Teknologi |
|----------|-----------|
| **Database** | PostgreSQL 16 / Microsoft SQL Server 2019 / Azure SQL Database |
| **ETL** | Python (Pandas) + PL/pgSQL / T-SQL Stored Procedures |
| **Management Tools** | pgAdmin4 / SSMS & Azure Data Studio |
| **BI Tools** | Power BI Desktop |
| **Cloud** | Azure VM (Ubuntu) |
| **Version Control** | Git & GitHub |
| **Modeling Approach** | Kimball Dimensional Modeling (Star Schema) |

### ETL Architecture

```
┌─────────────────────────────────────────────────────────┐
│               SOURCE SYSTEMS (6)                        │
│  SIMASTER | Inventaris | SIMPEG | Layanan |            │
│           Monitoring | Unit Organisasi                  │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              EXTRACTION LAYER                           │
│      Python + ODBC → CSV Export / Direct Load          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│             STAGING AREA (stg.*)                        │
│  Temporary storage for raw data validation             │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│          TRANSFORMATION LAYER                           │
│   PL/pgSQL / T-SQL Stored Procedures                   │
│   - Data Cleansing & Validation                        │
│   - Business Rules Application                         │
│   - SCD Type 2 for dim.pegawai                         │
│   - Surrogate Key Generation                           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│          DATA WAREHOUSE (Star Schema)                   │
│           dim.* (7 dimensions)                         │
│           fact.* (3 fact tables)                       │
└─────────────────────────────────────────────────────────┘
```

Diagram lengkap: [ETL Architecture](docs/03-implementation/ETL_Architecture_BAU_ITERA.png)

---

## 🎯 Key Performance Indicators (KPIs)

### 1. Efektivitas Layanan
- **Tingkat akurasi pencatatan surat** (target: >98%, diukur bulanan)
- **Waktu pencarian arsip** (target: <15 menit, diukur per kasus)
- **Waktu respon permintaan layanan** (target: <24 jam, diukur harian)
- **SLA compliance rate** (% on-time)
- **Average satisfaction rating** (target: >4.0/5.0)

### 2. Pengelolaan Aset & Data
- **Persentase aset terlabeli dan tercatat** (target: 100%, diukur semester)
- **Akurasi data kepegawaian** (target: 100%, diukur triwulan)
- **Total asset value & depreciation trends**
- **Asset condition distribution**

### 3. Kinerja Strategis
- **Ketepatan waktu pelaporan rutin** (target: 100%, diukur bulanan)
- **Tingkat kepuasan civitas akademika** (target: >4.0/5.0, diukur semester)
- **Document processing time trends**
- **Service type distribution analysis**

---

## 📁 Struktur Repository

```
TUBES_Pergudangan-Data_Kelompok-19/
├── README.md                          # ⭐ File ini
├── .gitignore
│
├── Data/                              # 📊 Data Files
│   └── sample/                        # Sample data (400+ rows) ⭐
│       ├── sample_stg_aset.csv
│       ├── sample_stg_layanan.csv
│       ├── sample_stg_pegawai.csv
│       ├── sample_stg_surat (1).csv
│       ├── sample_stg_unit_organisasi.csv
│       └── tempat.csv
│
├── dashboards/                        # 📈 Power BI Dashboards
│   └── PowerBI files/                 # .pbix files
│       └── .gitkeep
│
├── docs/                              # 📚 Dokumentasi lengkap
│   ├── 01-requirements/               # Misi 1: Requirements & Analysis
│   │   ├── business-requirements.md
│   │   ├── data-sources.md
│   │   └── kpi-definitions.md
│   ├── 02-design/                     # Misi 1 & 2: Design Documents
│   │   ├── ERD.png
│   │   ├── dimensional-model.svg
│   │   ├── dimensional-model.md
│   │   ├── data-dictionary.md
│   │   ├── bus-matrix.md
│   │   ├── source-to-target-mapping.md
│   │   ├── etl-strategy.md
│   │   └── ETL_Mapping_Spreadsheet.csv ⭐
│   ├── 03-implementation/             # Misi 2: Technical Documentation
│   │   ├── Technical_Documentation_Misi_2.md ⭐
│   │   ├── ETL_Process_Flow.md ⭐
│   │   ├── ETL_Architecture_BAU_ITERA.png ⭐
│   │   ├── etl-documentation.md
│   │   ├── user-manual.pdf
│   │   └── operations-manual.pdf
│   └── presentations/                 # Slide presentasi
│
├── etl/                               # 🔄 ETL Scripts (Python)
│   ├── packages/                      # ETL packages/modules
│   ├── scripts/                       # ETL execution scripts
│   └── ETL architecture diagram.png   # ⭐ Architecture visualization
│
├── sql/                               # 💾 SQL Scripts
│   ├── 01_Create_Database.sql         # ⭐ Database initialization
│   ├── 02_Create_Dimensions.sql       # Dimension tables DDL
│   ├── 03_Create_Facts.sql            # Fact tables DDL
│   ├── 04_Create_Indexes.sql          # Indexes & constraints
│   ├── 05_Create_Partitions.sql       # Table partitioning
│   ├── 06_Create_Staging.sql          # Staging tables DDL
│   ├── 07_ETL_Procedures.sql          # ETL stored procedures
│   ├── 08_Data_Quality_Checks.sql     # Data quality validation
│   ├── 09_Test_Queries.sql            # Testing & verification
│   ├── 10_Security.sql                # Security & access control
│   └── 11_Backup                      # Backup procedures
│
└── tests/                             # 🧪 Testing Scripts
    ├── unit_tests/
    ├── integration_tests/
    ├── data_quality_tests/
    └── test_results/
```

---

## 🚀 Quick Start

### Prerequisites

- **PostgreSQL 16+** atau **Microsoft SQL Server 2019+**
- **Python 3.10+** (untuk ETL scripts)
- **Power BI Desktop** (untuk dashboard)
- **Git** (untuk version control)
- **pgAdmin4** atau **SSMS** (untuk database management)

### Setup Database (PostgreSQL)

```bash
# 1. Clone repository
git clone https://github.com/username/TUBES_Pergudangan-Data_Kelompok-19.git
cd TUBES_Pergudangan-Data_Kelompok-19

# 2. Create database
psql -U postgres -c "CREATE DATABASE datamart_bau_itera;"

# 3. Run DDL scripts (in order)
psql -U postgres -d datamart_bau_itera -f sql/01_Create_Database.sql
psql -U postgres -d datamart_bau_itera -f sql/02_Create_Dimensions.sql
psql -U postgres -d datamart_bau_itera -f sql/03_Create_Facts.sql
psql -U postgres -d datamart_bau_itera -f sql/04_Create_Indexes.sql
psql -U postgres -d datamart_bau_itera -f sql/05_Create_Partitions.sql
psql -U postgres -d datamart_bau_itera -f sql/06_Create_Staging.sql

# 4. Load sample data
psql -U postgres -d datamart_bau_itera -c "\COPY stg.surat FROM 'Data/sample/sample_stg_surat (1).csv' CSV HEADER;"
psql -U postgres -d datamart_bau_itera -c "\COPY stg.layanan FROM 'Data/sample/sample_stg_layanan.csv' CSV HEADER;"
psql -U postgres -d datamart_bau_itera -c "\COPY stg.aset FROM 'Data/sample/sample_stg_aset.csv' CSV HEADER;"
psql -U postgres -d datamart_bau_itera -c "\COPY stg.pegawai FROM 'Data/sample/sample_stg_pegawai.csv' CSV HEADER;"
psql -U postgres -d datamart_bau_itera -c "\COPY stg.unit_organisasi FROM 'Data/sample/sample_stg_unit_organisasi.csv' CSV HEADER;"

# 5. Verify installation
psql -U postgres -d datamart_bau_itera -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('stg', 'dim', 'fact', 'etl_log', 'dw');"
```

### Setup via pgAdmin4 (Alternative)

1. Buka **pgAdmin4**
2. Create new database: `datamart_bau_itera`
3. Open Query Tool pada database tersebut
4. Execute script: `sql/01_ddl/01_Create_Database_PostgreSQL.sql`
5. Verifikasi dengan menjalankan validation queries di akhir script

### Run ETL

```bash
# Option 1: Run full ETL via SQL
psql -U postgres -d datamart_bau_itera -c "CALL dw.run_etl_full();"

# Option 2: Run individual ETL procedures
psql -U postgres -d datamart_bau_itera -f sql/07_ETL_Procedures.sql

# Option 3: Run Python extraction script (if available)
cd etl/scripts
python extract_all.py
```

### Open Dashboard

```bash
# Open Power BI file
open dashboards/PowerBI\ files/DataMart_BAU_ITERA.pbix
```

---

## 📚 Dokumentasi Lengkap

### 📘 Misi 1: Requirements & Design
- [Business Requirements](docs/01-requirements/business-requirements.md) - Tujuan, scope, proses bisnis
- [Data Sources](docs/01-requirements/data-sources.md) - Inventory sistem sumber, volume, refresh rate
- [KPI Definitions](docs/01-requirements/kpi-definitions.md) - Definisi KPI dan target
- [ERD Diagram](docs/02-design/ERD.png) - Entity Relationship Diagram
- [Dimensional Model](docs/02-design/dimensional-model.svg) - Star Schema visualization
- [Data Dictionary](docs/02-design/data-dictionary.md) - Definisi kolom, tipe data, constraints
- [Bus Matrix](docs/02-design/bus-matrix.md) - Dimensi vs Fact mapping
- [Source-to-Target Mapping](docs/02-design/source-to-target-mapping.md) - Field-level mapping
- [ETL Strategy](docs/02-design/etl-strategy.md) - Load strategy, SCD policy, logging

### 📗 Misi 2: Implementation & Testing
- [📘 Technical Documentation Misi 2](docs/03-implementation/Technical_Documentation_Misi_2.md) ⭐ **NEW**
- [📗 ETL Process Flow](docs/03-implementation/ETL_Process_Flow.md) ⭐ **NEW**
- [🎨 ETL Architecture Diagram](etl/ETL%20architecture%20diagram.png) ⭐ **NEW**
- [📊 ETL Mapping Spreadsheet](docs/02-design/ETL_Mapping_Spreadsheet.csv) ⭐ **NEW**
- [ETL Documentation](docs/03-implementation/etl-documentation.md) - Detailed ETL procedures
- [Sample Data (400+ rows)](Data/sample/) ⭐ **NEW**
- [Test Results](tests/test_results/test_results_misi2.md)

### 📙 Misi 3: Deployment & Dashboard (Coming Soon)
- [Deployment Guide](docs/04-deployment/deployment-guide.md)
- [Operations Manual](docs/04-deployment/operations-manual.md)
- [User Manual](docs/04-deployment/user-manual.md)
- [Dashboard Screenshots](dashboards/screenshots/)

---

## 📊 Key Features

### Data Quality ✅
- Automated data validation
- Referential integrity checks
- Business rule validation
- Completeness & consistency checks
- Comprehensive error logging via `etl_log` schema
- Data quality metrics tracking

### Performance ⚡
- Optimized indexing strategy (B-tree, composite indexes)
- Partitioning for large tables
- Materialized views for reporting
- Query optimization
- Incremental ETL loads
- SCD Type 2 for slowly changing dimensions

### Monitoring 📊
- ETL execution logging (`etl_log.job_execution`)
- Data quality metrics (`etl_log.data_quality_log`)
- Performance dashboards
- Error tracking & alerting
- Audit trails (`etl_log.audit_log`)
- Row count validation

### Security 🔒
- Role-Based Access Control (RBAC)
- Row-Level Security (RLS)
- Data masking for sensitive fields (PII)
- Encrypted connections (SSL/TLS)
- Audit logging for all modifications
- Backup automation

---

## 📈 Project Statistics

| Metric | Value |
|--------|-------|
| **Source Systems** | 6 databases (SIMASTER, Inventaris, SIMPEG, Layanan, Monitoring, Unit Org) |
| **Schemas** | 5 (stg, dim, fact, etl_log, dw) |
| **Dimension Tables** | 7 tables |
| **Fact Tables** | 3 tables |
| **Sample Data Records** | 400+ rows |
| **ETL Mappings** | 83+ field-level mappings |
| **SQL Scripts** | 20+ files |
| **Documentation** | 70+ KB markdown |
| **Test Coverage** | Unit + Integration + Data Quality tests |
| **Time Dimension Range** | 2020-2030 (10 years) |

---

## 🧪 Testing & Validation

### Run Tests

```bash
# Data Quality Tests
psql -U postgres -d datamart_bau_itera -f tests/data_quality_tests/test_data_quality.sql

# Unit Tests (Dimensions)
psql -U postgres -d datamart_bau_itera -f tests/unit_tests/test_etl_dimensions.sql

# Integration Tests (Full ETL)
psql -U postgres -d datamart_bau_itera -f tests/integration_tests/test_full_etl.sql

# Validation Queries
psql -U postgres -d datamart_bau_itera -f sql/05_queries/09_Test_Queries.sql
```

### Test Coverage
- ✅ Dimension loading (dim.waktu, dim.pegawai, dim.unit_organisasi, etc.)
- ✅ Fact table population (fact.surat, fact.layanan, fact.aset)
- ✅ SCD Type 2 implementation (dim.pegawai)
- ✅ Referential integrity
- ✅ Business rule validation
- ✅ Data completeness checks
- ✅ Row count validation

### Test Results
- [Test Results Misi 2](tests/test_results/test_results_misi2.md)

---

## 🤝 Contributing

### Workflow
1. Create feature branch: `git checkout -b feature/nama-fitur`
2. Commit changes: `git commit -m "Add: deskripsi fitur"`
3. Push to branch: `git push origin feature/nama-fitur`
4. Create Pull Request
5. Code review & merge

### Commit Message Convention
```
Add: Menambahkan fitur baru
Fix: Memperbaiki bug
Update: Memperbarui fitur existing
Docs: Memperbarui dokumentasi
Test: Menambahkan atau memperbaiki test
Refactor: Refactoring code tanpa mengubah fungsionalitas
Style: Perubahan formatting (whitespace, indentation)
```

---

## 📅 Project Timeline

| Misi | Periode | Status | Deliverables |
|------|---------|--------|--------------|
| **Misi 1** | Week 1-4 | ✅ **Complete** | Business Requirements, Data Sources, ERD, Dimensional Model, Data Dictionary, Bus Matrix, ETL Strategy, Database Bootstrap |
| **Misi 2** | Week 5-8 | ✅ **Complete** | DDL Scripts, ETL Procedures, Indexes, Sample Data (400 rows), Technical Documentation, ETL Mapping, Testing |
| **Misi 3** | Week 9-12 | 🔄 **In Progress** | Dashboard Power BI, Deployment, User Manual, Operations Manual, Final Presentation |

### Misi 1 Deliverables ✅
- ✅ Business Requirements Document
- ✅ Data Sources Inventory
- ✅ ERD (Star Schema)
- ✅ Dimensional Model
- ✅ Bus Matrix
- ✅ Data Dictionary
- ✅ Source-to-Target Mapping
- ✅ ETL Strategy
- ✅ Database Bootstrap (PostgreSQL)

### Misi 2 Deliverables ✅
- ✅ Create Database Script (idempotent)
- ✅ Create Dimensions Tables
- ✅ Create Facts Tables
- ✅ Create Staging Tables
- ✅ Create Indexes & Constraints
- ✅ ETL Stored Procedures
- ✅ Sample Data (400+ rows)
- ✅ Technical Documentation
- ✅ ETL Mapping Spreadsheet
- ✅ Unit & Integration Tests

### Misi 3 Deliverables 🔄
- 🔄 Power BI Dashboard (Executive, Operational, Custom Reports)
- 🔄 Deployment to Production
- 🔄 User Manual
- 🔄 Operations Manual
- 🔄 Final Presentation

---

## 📞 Contact Information

### Dosen Pengampu
**[Nama Dosen]**  
Email: [email@itera.ac.id]

### Tim Kelompok 19

**Syahrialdi Rachim Akbar (Aldi)** - Project Lead & Database Designer  
📧 Syahrialdi.123450093@student.itera.ac.id

**Zahra Putri Salsabilla** - ETL Developer & Data Engineer  
📧 Zahra.123450026@student.itera.ac.id

**Feby Angelina (Aya)** - BI Developer & Documentation  
📧 Feby.123450039@student.itera.ac.id

---

## 🙏 Acknowledgments

- **Dosen Pengampu:** [Nama Dosen] - Mata Kuliah Pergudangan Data (SD25-31007)
- **Asisten Praktikum:** [Nama Asisten]
- **Institut Teknologi Sumatera** - Program Studi Sains Data
- **Biro Akademik Umum ITERA** - Domain knowledge & business requirements
- **Kimball Group** - Dimensional modeling methodology

---

## 📄 License

Project ini dikembangkan untuk keperluan akademik mata kuliah **Pergudangan Data (SD25-31007)** - Program Studi Sains Data, Fakultas Sains, Institut Teknologi Sumatera.

© 2025 Tim Kelompok 19 - Data Mart BAU ITERA. All rights reserved.

---

## 📊 Project Status Dashboard

![Status](https://img.shields.io/badge/Status-Active-brightgreen)
![Misi 1](https://img.shields.io/badge/Misi%201-Complete-success)
![Misi 2](https://img.shields.io/badge/Misi%202-Complete-success)
![Misi 3](https://img.shields.io/badge/Misi%203-In%20Progress-yellow)
![Documentation](https://img.shields.io/badge/Documentation-Excellent-blue)
![Test Coverage](https://img.shields.io/badge/Tests-Passing-success)
![Code Quality](https://img.shields.io/badge/Code%20Quality-A-brightgreen)

---

**Last Updated:** 24 November 2025  
**Version:** 2.0 (Misi 2 Complete - Ready for Misi 3)  
**Next Milestone:** Power BI Dashboard & Deployment

---

> *"Turning raw data into actionable insights through collaboration, modeling, and analytics."*  
> **— Tim Kelompok 19, Data Mart BAU ITERA**

---

## 🔗 Quick Links

- 📚 [Full Documentation](docs/)
- 🎨 [ETL Architecture Diagram](etl/ETL%20architecture%20diagram.png)
- 📊 [Sample Data](Data/sample/)
- 🧪 [Test Results](tests/test_results/)
- 🐛 [Report Issues](https://github.com/username/TUBES_Pergudangan-Data_Kelompok-19/issues)

---

**🌟 Star this repo if you find it useful!**
