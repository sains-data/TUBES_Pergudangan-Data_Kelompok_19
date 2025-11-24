# Technical Documentation - Misi 2
## Desain Fisikal dan ETL Development
### Data Mart Biro Akademik Umum ITERA

**Document Version:** 1.0  
**Created:** 24 November 2025  
**Owner:** Kelompok 19 - Feby (ETL Developer & Documentation Specialist)  
**Project:** Data Mart Biro Akademik Umum ITERA  
**Course:** SD25-31007 - Pergudangan Data

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Physical Database Design](#2-physical-database-design)
3. [ETL Architecture](#3-etl-architecture)
4. [ETL Implementation Details](#4-etl-implementation-details)
5. [Data Quality Framework](#5-data-quality-framework)
6. [Performance Optimization](#6-performance-optimization)
7. [Testing Strategy](#7-testing-strategy)
8. [Deployment Procedures](#8-deployment-procedures)
9. [Operational Guidelines](#9-operational-guidelines)
10. [Appendices](#10-appendices)

---

## 1. Executive Summary

### 1.1 Project Overview

Data Mart Biro Akademik Umum (BAU) ITERA adalah solusi business intelligence yang dirancang untuk mengintegrasikan dan menganalisis data dari berbagai sistem sumber untuk mendukung pengambilan keputusan operasional dan strategis di Biro Akademik Umum Institut Teknologi Sumatera.

### 1.2 Mission 2 Objectives

Misi 2 fokus pada implementasi fisik dari desain logikal yang telah dibuat pada Misi 1, dengan tujuan utama:

1. **Physical Database Implementation**: Implementasi schema database PostgreSQL dengan struktur dimensional yang optimal
2. **ETL Development**: Pengembangan proses Extract-Transform-Load yang robust dan scalable
3. **Data Quality Assurance**: Implementasi framework untuk memastikan kualitas data
4. **Performance Optimization**: Penerapan indexing, partitioning, dan optimasi query
5. **Testing & Validation**: Comprehensive testing untuk memastikan data integrity dan system reliability

### 1.3 Scope

**In Scope:**
- Physical database schema implementation (PostgreSQL 16)
- Staging area design and implementation
- ETL process development (PL/pgSQL stored procedures)
- Data transformation logic
- Data quality checks and validation
- Error handling and logging mechanisms
- Performance optimization (indexing, partitioning)
- Unit testing and integration testing
- Technical documentation

**Out of Scope:**
- Dashboard development (Misi 3)
- Production deployment (Misi 3)
- User training (Misi 3)
- Production support (Misi 3)

### 1.4 Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Database Platform | PostgreSQL | 16.x | Data warehouse database |
| ETL Processing | PL/pgSQL | Built-in | Stored procedures for ETL |
| Data Generation | Python | 3.10+ | Sample data generation |
| Version Control | Git/GitHub | Latest | Code repository |
| Development Tools | pgAdmin 4 | Latest | Database administration |
| Documentation | Markdown | N/A | Technical documentation |

### 1.5 Key Achievements

- ✅ Comprehensive ETL architecture diagram (draw.io format)
- ✅ Detailed source-to-target mapping spreadsheet (83+ mappings)
- ✅ Sample data generation for 5 staging tables (400+ records)
- ✅ Complete technical documentation
- ✅ ETL process flow documentation
- ✅ Data quality framework design

---

## 2. Physical Database Design

### 2.1 Database Architecture

#### 2.1.1 Schema Organization

Data Mart BAU menggunakan multi-schema architecture untuk memisahkan concerns:

```
datamart_bau_itera/
├── stg/           # Staging area - raw data from sources
├── dim/           # Dimension tables
├── fact/          # Fact tables
├── dw/            # Data warehouse metadata
├── etl_log/       # ETL logging and monitoring
├── analytics/     # Analytical views (Misi 3)
└── reports/       # Report-specific objects (Misi 3)
```

**Schema Purposes:**

- **stg (Staging)**: Temporary storage untuk raw data dari source systems. Data di sini belum divalidasi atau ditransformasi.
- **dim (Dimension)**: Dimension tables dalam star schema. Berisi descriptive attributes untuk analisis.
- **fact (Fact)**: Fact tables yang menyimpan business transactions dan measurements.
- **dw**: Metadata tables untuk tracking ETL processes, data lineage, dan business rules.
- **etl_log**: Comprehensive logging untuk monitoring, troubleshooting, dan auditing ETL runs.
- **analytics**: Pre-built aggregations dan analytical views (future implementation).
- **reports**: Report-specific tables dan materialized views (future implementation).

#### 2.1.2 Naming Conventions

**Tables:**
- Staging tables: `stg.<entity_name>` (lowercase, underscore-separated)
  - Example: `stg.surat`, `stg.pegawai`, `stg.unit_organisasi`
- Dimension tables: `dim.<dimension_name>` (lowercase, singular)
  - Example: `dim.waktu`, `dim.pegawai`, `dim.jenis_surat`
- Fact tables: `fact.<fact_name>` (lowercase, singular)
  - Example: `fact.surat`, `fact.layanan`, `fact.aset`

**Columns:**
- Primary keys: `<table_name>_key` (surrogate key, INTEGER SERIAL)
  - Example: `pegawai_key`, `waktu_key`, `jenis_surat_key`
- Business keys: Original column name from source
  - Example: `nip`, `kode_unit`, `jenis_surat_id`
- Foreign keys: `<referenced_table>_key`
  - Example: `tanggal_key`, `unit_pemilik_key`, `petugas_key`
- Timestamps: `created_at`, `updated_at`, `valid_from`, `valid_to`
- Flags: `is_<condition>` (boolean)
  - Example: `is_current`, `is_weekend`, `is_ontime`

**Indexes:**
- Primary key index: `pk_<table_name>`
- Foreign key index: `fk_<table_name>_<referenced_table>`
- Business key index: `idx_<table_name>_<column_name>`
- Composite index: `idx_<table_name>_<col1>_<col2>`

### 2.2 Dimension Tables Design

#### 2.2.1 dim.waktu (Time Dimension)

**Purpose**: Standard time dimension untuk time-based analysis.

**Structure:**
```sql
CREATE TABLE dim.waktu (
    waktu_key SERIAL PRIMARY KEY,
    tanggal DATE NOT NULL UNIQUE,
    tahun INTEGER NOT NULL,
    bulan INTEGER NOT NULL CHECK (bulan BETWEEN 1 AND 12),
    nama_bulan VARCHAR(20) NOT NULL,
    kuartal INTEGER NOT NULL CHECK (kuartal BETWEEN 1 AND 4),
    semester INTEGER NOT NULL CHECK (semester IN (1, 2)),
    hari_dalam_minggu INTEGER NOT NULL CHECK (hari_dalam_minggu BETWEEN 0 AND 6),
    nama_hari VARCHAR(20) NOT NULL,
    is_weekend BOOLEAN NOT NULL DEFAULT FALSE,
    is_holiday BOOLEAN NOT NULL DEFAULT FALSE,
    tahun_akademik VARCHAR(9), -- Format: 2024/2025
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Key Features:**
- Pre-populated untuk range 2020-2030 (10 years)
- Supports Indonesian localization (nama_bulan, nama_hari)
- Academic calendar support (tahun_akademik)
- Weekend and holiday flags untuk business day calculations
- Immutable after initial load (Type 0 SCD)

**Business Rules:**
- One row per calendar date
- Weekend: hari_dalam_minggu IN (0, 6) → Saturday = 6, Sunday = 0
- Academic year starts in August (e.g., 2024/2025 = Aug 2024 - Jul 2025)

#### 2.2.2 dim.pegawai (Employee Dimension - SCD Type 2)

**Purpose**: Employee master data dengan historical tracking.

**Structure:**
```sql
CREATE TABLE dim.pegawai (
    pegawai_key SERIAL PRIMARY KEY,
    nip VARCHAR(20) NOT NULL,  -- Business key (non-unique untuk SCD2)
    nama_lengkap VARCHAR(200) NOT NULL,
    jabatan VARCHAR(100) NOT NULL,
    unit_kerja VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    telepon VARCHAR(20),
    status_kepegawaian VARCHAR(30) NOT NULL,
    valid_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMP DEFAULT '9999-12-31'::TIMESTAMP,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_valid_dates CHECK (valid_to >= valid_from)
);

CREATE INDEX idx_pegawai_nip ON dim.pegawai(nip);
CREATE INDEX idx_pegawai_current ON dim.pegawai(nip, is_current) 
    WHERE is_current = TRUE;
```

**Key Features:**
- **SCD Type 2**: Tracks historical changes in jabatan, unit_kerja, status
- Multiple versions per employee (identified by nip)
- Current version marked dengan is_current = TRUE
- Valid date range untuk temporal queries

**Business Rules:**
- Only one current record per NIP (is_current = TRUE)
- When changes occur:
  1. Set old record: is_current = FALSE, valid_to = change_date
  2. Insert new record: is_current = TRUE, valid_from = change_date, valid_to = '9999-12-31'
- NIP format: 18 digits (YYYYMMDDXXXXXXXX)
- Email must follow pattern: {nip}@itera.ac.id
- Status options: AKTIF, CUTI, TUGAS_BELAJAR, PENSIUN, BERHENTI

#### 2.2.3 dim.unit_organisasi (Organizational Unit Dimension)

**Purpose**: Hierarchical organization structure.

**Structure:**
```sql
CREATE TABLE dim.unit_organisasi (
    unit_key SERIAL PRIMARY KEY,
    kode_unit VARCHAR(20) NOT NULL UNIQUE,  -- Business key
    nama_unit VARCHAR(200) NOT NULL,
    tipe_unit VARCHAR(50) NOT NULL,
    parent_kode_unit VARCHAR(20),  -- Self-referencing FK
    kepala_unit VARCHAR(200),
    level_hierarchy INTEGER,  -- Computed: 1=root, 2=child of root, etc
    path_hierarchy VARCHAR(500),  -- Materialized path: /UNIT-001/UNIT-002/UNIT-010
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_parent_unit FOREIGN KEY (parent_kode_unit) 
        REFERENCES dim.unit_organisasi(kode_unit),
    CONSTRAINT chk_tipe_unit CHECK (tipe_unit IN (
        'REKTORAT', 'FAKULTAS', 'BIRO', 'UPT', 'LEMBAGA', 'PROGRAM_STUDI'
    ))
);

CREATE INDEX idx_unit_kode ON dim.unit_organisasi(kode_unit);
CREATE INDEX idx_unit_parent ON dim.unit_organisasi(parent_kode_unit);
CREATE INDEX idx_unit_type ON dim.unit_organisasi(tipe_unit);
```

**Key Features:**
- **SCD Type 1**: Overwrite changes (structure changes are rare)
- Hierarchical structure dengan self-referencing foreign key
- Materialized path untuk efficient subtree queries
- Level indicator untuk depth-based queries

**Business Rules:**
- Root units (Rektorat) have parent_kode_unit = NULL
- Maximum hierarchy depth: 5 levels
- Each unit must have a unique kode_unit
- Path format: /PARENT1/PARENT2/CURRENT_UNIT

#### 2.2.4 dim.jenis_surat (Document Type Dimension)

**Purpose**: Classification of correspondence types.

**Structure:**
```sql
CREATE TABLE dim.jenis_surat (
    jenis_surat_key SERIAL PRIMARY KEY,
    jenis_surat_id VARCHAR(20) NOT NULL UNIQUE,  -- Business key
    nama_jenis VARCHAR(100) NOT NULL,
    kategori VARCHAR(50) NOT NULL,
    kode_klasifikasi VARCHAR(30),  -- Document classification code
    deskripsi TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_jenis_surat_id ON dim.jenis_surat(jenis_surat_id);
CREATE INDEX idx_jenis_surat_kategori ON dim.jenis_surat(kategori);
```

**Key Features:**
- **SCD Type 1**: Overwrite changes
- Document classification support
- Active/inactive flag untuk soft deletes

**Business Rules:**
- Kategori: MASUK, KELUAR, INTERNAL
- Kode klasifikasi mengikuti standard kearsipan nasional

#### 2.2.5 dim.jenis_layanan (Service Type Dimension)

**Purpose**: Service catalog dengan SLA definitions.

**Structure:**
```sql
CREATE TABLE dim.jenis_layanan (
    jenis_layanan_key SERIAL PRIMARY KEY,
    jenis_layanan_id VARCHAR(20) NOT NULL UNIQUE,
    nama_layanan VARCHAR(150) NOT NULL,
    kategori_layanan VARCHAR(50) NOT NULL,
    target_sla_hari INTEGER NOT NULL DEFAULT 7 CHECK (target_sla_hari > 0),
    biaya_layanan DECIMAL(12,2) DEFAULT 0,
    deskripsi TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_jenis_layanan_id ON dim.jenis_layanan(jenis_layanan_id);
CREATE INDEX idx_jenis_layanan_kategori ON dim.jenis_layanan(kategori_layanan);
```

**Key Features:**
- **SCD Type 1**: Overwrite changes
- SLA target untuk performance measurement
- Service costing support

**Business Rules:**
- Kategori: ADMINISTRASI, PEMINJAMAN, LEGALISIR, SURAT_KETERANGAN
- SLA default: 7 working days
- Biaya default: 0 (free services)

#### 2.2.6 dim.jenis_aset (Asset Type Dimension)

**Purpose**: Asset classification dengan depreciation rules.

**Structure:**
```sql
CREATE TABLE dim.jenis_aset (
    jenis_aset_key SERIAL PRIMARY KEY,
    jenis_aset_id VARCHAR(20) NOT NULL UNIQUE,
    nama_jenis VARCHAR(100) NOT NULL,
    kategori VARCHAR(50) NOT NULL,
    umur_ekonomis_tahun INTEGER NOT NULL DEFAULT 5 CHECK (umur_ekonomis_tahun > 0),
    metode_depresiasi VARCHAR(30) DEFAULT 'GARIS_LURUS',
    nilai_residu_persen DECIMAL(5,2) DEFAULT 10.00,
    deskripsi TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_kategori_aset CHECK (kategori IN (
        'ELEKTRONIK', 'FURNITURE', 'KENDARAAN', 'BANGUNAN', 'TANAH', 'PERALATAN'
    ))
);
```

**Key Features:**
- **SCD Type 1**: Overwrite changes
- Depreciation parameters untuk asset valuation
- Asset lifecycle management support

**Business Rules:**
- Umur ekonomis: 1-50 tahun (depending on asset type)
- Metode depresiasi: GARIS_LURUS (straight-line depreciation)
- Nilai residu: 0-30% dari nilai perolehan

#### 2.2.7 dim.status_layanan (Service Status Dimension)

**Purpose**: Service request lifecycle states.

**Structure:**
```sql
CREATE TABLE dim.status_layanan (
    status_layanan_key SERIAL PRIMARY KEY,
    status_layanan_id VARCHAR(20) NOT NULL UNIQUE,
    nama_status VARCHAR(50) NOT NULL,
    urutan INTEGER NOT NULL,  -- Workflow sequence
    is_terminal BOOLEAN DEFAULT FALSE,  -- End state indicator
    deskripsi TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Pre-populated dengan standard workflow statuses
INSERT INTO dim.status_layanan (status_layanan_id, nama_status, urutan, is_terminal) VALUES
('PENDING', 'Menunggu Proses', 1, FALSE),
('PROSES', 'Sedang Diproses', 2, FALSE),
('SELESAI', 'Selesai', 3, TRUE),
('BATAL', 'Dibatalkan', 4, TRUE);
```

**Key Features:**
- **Type 0 SCD**: Fixed/static dimension
- Workflow sequence tracking
- Terminal state identification untuk completion metrics

### 2.3 Fact Tables Design

#### 2.3.1 fact.surat (Correspondence Facts)

**Purpose**: Track document flow and disposition in BAU.

**Grain**: One row per document (nomor_surat)

**Structure:**
```sql
CREATE TABLE fact.surat (
    surat_fact_key SERIAL PRIMARY KEY,
    nomor_surat VARCHAR(50) NOT NULL UNIQUE,  -- Degenerate dimension
    
    -- Foreign Keys to Dimensions
    tanggal_key INTEGER NOT NULL,
    jenis_surat_key INTEGER NOT NULL,
    pembuat_key INTEGER NOT NULL,
    unit_pengirim_key INTEGER NOT NULL,
    unit_penerima_key INTEGER,  -- Nullable untuk external recipients
    
    -- Degenerate Dimensions (attributes that don't warrant separate dimension)
    prioritas VARCHAR(20) NOT NULL DEFAULT 'NORMAL',
    status_disposisi VARCHAR(30) NOT NULL,
    tanggal_disposisi DATE,
    
    -- Measures (Additive and Semi-additive)
    jumlah_surat INTEGER NOT NULL DEFAULT 1,  -- Additive count
    lama_disposisi_hari INTEGER,  -- Semi-additive (calculated)
    
    -- Audit Columns
    etl_batch_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_surat_tanggal FOREIGN KEY (tanggal_key) 
        REFERENCES dim.waktu(waktu_key),
    CONSTRAINT fk_surat_jenis FOREIGN KEY (jenis_surat_key) 
        REFERENCES dim.jenis_surat(jenis_surat_key),
    CONSTRAINT fk_surat_pembuat FOREIGN KEY (pembuat_key) 
        REFERENCES dim.pegawai(pegawai_key),
    CONSTRAINT fk_surat_pengirim FOREIGN KEY (unit_pengirim_key) 
        REFERENCES dim.unit_organisasi(unit_key),
    CONSTRAINT fk_surat_penerima FOREIGN KEY (unit_penerima_key) 
        REFERENCES dim.unit_organisasi(unit_key),
    CONSTRAINT chk_prioritas CHECK (prioritas IN ('URGENT', 'HIGH', 'NORMAL', 'LOW')),
    CONSTRAINT chk_lama_disposisi CHECK (lama_disposisi_hari >= 0)
);

-- Performance Indexes
CREATE INDEX idx_fact_surat_tanggal ON fact.surat(tanggal_key);
CREATE INDEX idx_fact_surat_jenis ON fact.surat(jenis_surat_key);
CREATE INDEX idx_fact_surat_unit_pengirim ON fact.surat(unit_pengirim_key);
CREATE INDEX idx_fact_surat_status ON fact.surat(status_disposisi);
CREATE INDEX idx_fact_surat_prioritas ON fact.surat(prioritas);

-- Composite indexes untuk common queries
CREATE INDEX idx_fact_surat_date_unit ON fact.surat(tanggal_key, unit_pengirim_key);
CREATE INDEX idx_fact_surat_date_status ON fact.surat(tanggal_key, status_disposisi);
```

**Measures:**
- **jumlah_surat**: Additive count measure (always 1, sum = total documents)
- **lama_disposisi_hari**: Semi-additive duration (can average, not sum across time)

**Business Rules:**
- Nomor surat format: {UNIT}/{TYPE}/{YEAR}/{SEQUENCE}
- Prioritas hierarchy: URGENT > HIGH > NORMAL > LOW
- lama_disposisi_hari = tanggal_disposisi - tanggal_surat (in days)
- If tanggal_disposisi IS NULL, document still pending

#### 2.3.2 fact.layanan (Service Transaction Facts)

**Purpose**: Track service requests and performance metrics.

**Grain**: One row per service transaction (transaksi_id)

**Structure:**
```sql
CREATE TABLE fact.layanan (
    layanan_fact_key SERIAL PRIMARY KEY,
    transaksi_id VARCHAR(50) NOT NULL UNIQUE,  -- Degenerate dimension
    
    -- Foreign Keys
    tanggal_permintaan_key INTEGER NOT NULL,
    tanggal_selesai_key INTEGER,  -- Nullable if not completed
    jenis_layanan_key INTEGER NOT NULL,
    pemohon_key INTEGER NOT NULL,
    petugas_key INTEGER,  -- Nullable if not assigned
    unit_key INTEGER NOT NULL,
    status_layanan_key INTEGER NOT NULL,
    
    -- Measures
    jumlah_layanan INTEGER NOT NULL DEFAULT 1,
    lama_proses_hari INTEGER,
    rating_kepuasan DECIMAL(3,2) CHECK (rating_kepuasan BETWEEN 1.00 AND 5.00),
    is_ontime BOOLEAN,  -- Derived: lama_proses <= SLA target
    
    -- Audit
    etl_batch_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_layanan_tanggal_permintaan FOREIGN KEY (tanggal_permintaan_key) 
        REFERENCES dim.waktu(waktu_key),
    CONSTRAINT fk_layanan_tanggal_selesai FOREIGN KEY (tanggal_selesai_key) 
        REFERENCES dim.waktu(waktu_key),
    CONSTRAINT fk_layanan_jenis FOREIGN KEY (jenis_layanan_key) 
        REFERENCES dim.jenis_layanan(jenis_layanan_key),
    CONSTRAINT fk_layanan_pemohon FOREIGN KEY (pemohon_key) 
        REFERENCES dim.pegawai(pegawai_key),
    CONSTRAINT fk_layanan_petugas FOREIGN KEY (petugas_key) 
        REFERENCES dim.pegawai(pegawai_key),
    CONSTRAINT fk_layanan_unit FOREIGN KEY (unit_key) 
        REFERENCES dim.unit_organisasi(unit_key),
    CONSTRAINT fk_layanan_status FOREIGN KEY (status_layanan_key) 
        REFERENCES dim.status_layanan(status_layanan_key),
    CONSTRAINT chk_lama_proses CHECK (lama_proses_hari >= 0)
);

-- Performance Indexes
CREATE INDEX idx_fact_layanan_tanggal_permintaan ON fact.layanan(tanggal_permintaan_key);
CREATE INDEX idx_fact_layanan_jenis ON fact.layanan(jenis_layanan_key);
CREATE INDEX idx_fact_layanan_unit ON fact.layanan(unit_key);
CREATE INDEX idx_fact_layanan_status ON fact.layanan(status_layanan_key);
CREATE INDEX idx_fact_layanan_ontime ON fact.layanan(is_ontime) WHERE is_ontime IS NOT NULL;

-- Composite indexes
CREATE INDEX idx_fact_layanan_date_unit ON fact.layanan(tanggal_permintaan_key, unit_key);
CREATE INDEX idx_fact_layanan_date_status ON fact.layanan(tanggal_permintaan_key, status_layanan_key);
```

**Measures:**
- **jumlah_layanan**: Additive count
- **lama_proses_hari**: Semi-additive duration
- **rating_kepuasan**: Non-additive (can average only)
- **is_ontime**: Boolean flag for SLA compliance analysis

**Business Rules:**
- lama_proses_hari = tanggal_selesai - tanggal_permintaan
- is_ontime = (lama_proses_hari <= jenis_layanan.target_sla_hari)
- Rating only applicable untuk status = 'SELESAI'

#### 2.3.3 fact.aset (Asset Snapshot Facts)

**Purpose**: Monthly snapshots of asset status and values.

**Grain**: One row per asset per snapshot date

**Structure:**
```sql
CREATE TABLE fact.aset (
    aset_fact_key SERIAL PRIMARY KEY,
    kode_aset VARCHAR(50) NOT NULL,  -- Degenerate dimension
    
    -- Foreign Keys
    snapshot_date_key INTEGER NOT NULL,  -- Monthly snapshot date
    tanggal_perolehan_key INTEGER NOT NULL,
    jenis_aset_key INTEGER NOT NULL,
    unit_pemilik_key INTEGER NOT NULL,
    penanggung_jawab_key INTEGER,
    
    -- Degenerate Dimensions
    kondisi VARCHAR(20) NOT NULL,
    status_aset VARCHAR(20) NOT NULL,
    
    -- Measures (Semi-additive - can't sum across time)
    jumlah_aset INTEGER NOT NULL DEFAULT 1,
    nilai_perolehan DECIMAL(15,2) NOT NULL CHECK (nilai_perolehan >= 0),
    nilai_buku DECIMAL(15,2) NOT NULL CHECK (nilai_buku >= 0),
    nilai_penyusutan DECIMAL(15,2) GENERATED ALWAYS AS (nilai_perolehan - nilai_buku) STORED,
    umur_aset_bulan INTEGER NOT NULL CHECK (umur_aset_bulan >= 0),
    
    -- Audit
    etl_batch_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_aset_snapshot FOREIGN KEY (snapshot_date_key) 
        REFERENCES dim.waktu(waktu_key),
    CONSTRAINT fk_aset_perolehan FOREIGN KEY (tanggal_perolehan_key) 
        REFERENCES dim.waktu(waktu_key),
    CONSTRAINT fk_aset_jenis FOREIGN KEY (jenis_aset_key) 
        REFERENCES dim.jenis_aset(jenis_aset_key),
    CONSTRAINT fk_aset_unit FOREIGN KEY (unit_pemilik_key) 
        REFERENCES dim.unit_organisasi(unit_key),
    CONSTRAINT fk_aset_penanggung_jawab FOREIGN KEY (penanggung_jawab_key) 
        REFERENCES dim.pegawai(pegawai_key),
    CONSTRAINT chk_kondisi CHECK (kondisi IN ('BAIK', 'RUSAK_RINGAN', 'RUSAK_BERAT', 'PERLU_PERAWATAN')),
    CONSTRAINT chk_status_aset CHECK (status_aset IN ('AKTIF', 'DIPINJAMKAN', 'RUSAK', 'DALAM_PERBAIKAN', 'TIDAK_DIGUNAKAN')),
    CONSTRAINT chk_nilai_buku_valid CHECK (nilai_buku <= nilai_perolehan),
    CONSTRAINT uq_aset_snapshot UNIQUE (kode_aset, snapshot_date_key)
);

-- Performance Indexes
CREATE INDEX idx_fact_aset_snapshot ON fact.aset(snapshot_date_key);
CREATE INDEX idx_fact_aset_jenis ON fact.aset(jenis_aset_key);
CREATE INDEX idx_fact_aset_unit ON fact.aset(unit_pemilik_key);
CREATE INDEX idx_fact_aset_kondisi ON fact.aset(kondisi);
CREATE INDEX idx_fact_aset_status ON fact.aset(status_aset);

-- Composite indexes
CREATE INDEX idx_fact_aset_snapshot_unit ON fact.aset(snapshot_date_key, unit_pemilik_key);
```

**Measures:**
- **jumlah_aset**: Semi-additive (can sum across dimensions, not time)
- **nilai_perolehan**: Semi-additive acquisition value
- **nilai_buku**: Semi-additive book value
- **nilai_penyusutan**: Semi-additive depreciation (computed column)
- **umur_aset_bulan**: Non-additive age metric

**Business Rules:**
- Snapshot taken monthly (last day of month)
- umur_aset_bulan = months between snapshot_date and tanggal_perolehan
- nilai_penyusutan automatically calculated as nilai_perolehan - nilai_buku
- Can't have multiple snapshots for same asset on same date

### 2.4 Staging Tables Design

Staging tables mirror source system structures but add metadata columns:

```sql
CREATE TABLE stg.surat (
    nomor_surat VARCHAR(50),
    tanggal_surat DATE,
    jenis_surat_id VARCHAR(10),
    nama_jenis_surat VARCHAR(100),
    perihal VARCHAR(500),
    pembuat_nip VARCHAR(20),
    unit_pengirim_kode VARCHAR(20),
    unit_penerima_kode VARCHAR(20),
    prioritas VARCHAR(20),
    status_disposisi VARCHAR(30),
    tanggal_disposisi DATE,
    keterangan TEXT,
    -- Metadata
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    etl_batch_id INTEGER,
    source_system VARCHAR(50) DEFAULT 'SIMASTER'
);
```

**Key Features:**
- No primary keys or foreign keys (raw data)
- Includes source attribution
- Batch tracking for ETL runs
- Truncated and reloaded each ETL cycle

---

## 3. ETL Architecture

### 3.1 ETL Approach: ETL vs ELT

**Decision: ETL (Extract-Transform-Load)**

**Rationale:**
1. **Data Volume**: Moderate size (~100K rows) favors transformation before load
2. **Source Complexity**: Multiple heterogeneous sources require standardization
3. **Data Quality**: Complex transformations needed (deduplication, imputation)
4. **Target Platform**: PostgreSQL optimized for pre-transformed data
5. **Team Skills**: Strong PL/pgSQL capabilities

### 3.2 Architecture Overview

```
┌─────────────────────────────────────────────────┐
│            SOURCE SYSTEMS LAYER                  │
│  SIMASTER │ Inventaris │ SIMPEG │ Layanan │ etc │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│         EXTRACTION LAYER (Python)                │
│  • ODBC/JDBC Connectors                         │
│  • CSV Export                                    │
│  • Initial Validation                            │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│         STAGING AREA (PostgreSQL)                │
│  stg.surat │ stg.pegawai │ stg.layanan │ etc    │
│  • Raw data, no transformations                  │
│  • Truncate & reload each cycle                  │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│      TRANSFORMATION LAYER (PL/pgSQL)             │
│  • Data Cleansing                                │
│  • Business Rules Application                    │
│  • SCD Type 2 Implementation                     │
│  • Surrogate Key Generation                      │
│  • Lookup & Matching                             │
└─────────────┬───────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────┐
│    DATA WAREHOUSE LAYER (Star Schema)            │
│  Dimensions: dim.*                               │
│  Facts: fact.*                                   │
└──────────────────────────────────────────────────┘

     ┌────────────────────────────────┐
     │  MONITORING & LOGGING           │
     │  etl_log.job_execution          │
     │  etl_log.data_quality_checks    │
     │  etl_log.error_details          │
     └────────────────────────────────┘
```

### 3.3 ETL Process Flow

#### Phase 1: EXTRACT
1. Connect to source systems
2. Execute extraction queries
3. Export to CSV/staging format
4. Validate file format and basic constraints
5. Log extraction metrics

#### Phase 2: LOAD TO STAGING
1. Truncate existing staging tables
2. Bulk load CSV files
3. Log row counts
4. Validate data types and formats

#### Phase 3: TRANSFORM & LOAD DIMENSIONS
1. **dim.waktu**: Pre-populated, no updates
2. **dim.jenis_surat, dim.jenis_layanan, dim.jenis_aset**: 
   - Lookup and match
   - Insert new records only
3. **dim.unit_organisasi**:
   - Process hierarchical structure
   - Update parent references
   - Calculate materialized paths
4. **dim.pegawai (SCD Type 2)**:
   - Compare with existing records
   - Detect changes in jabatan, unit_kerja, status
   - Close old versions (set is_current=FALSE, valid_to=today)
   - Insert new versions

#### Phase 4: TRANSFORM & LOAD FACTS
1. **fact.surat**:
   - Lookup dimension keys
   - Calculate lama_disposisi_hari
   - Insert/update records
2. **fact.layanan**:
   - Lookup dimension keys
   - Calculate lama_proses_hari and is_ontime
   - Handle ratings for completed services
3. **fact.aset (Monthly Snapshot)**:
   - Calculate snapshot metrics
   - Update book values based on depreciation
   - Insert monthly snapshot

#### Phase 5: DATA QUALITY CHECKS
1. Referential integrity validation
2. Business rule validation
3. Completeness checks
4. Consistency checks

#### Phase 6: LOGGING & CLEANUP
1. Log ETL run statistics
2. Archive staging data (optional)
3. Update metadata tables

### 3.4 ETL Dependencies & Execution Order

```
1. dim.waktu (prerequisite, usually pre-loaded)
2. dim.unit_organisasi (no dependencies)
3. dim.pegawai (depends on dim.unit_organisasi)
4. dim.jenis_surat, dim.jenis_layanan, dim.jenis_aset, dim.status_layanan (parallel)
5. fact.surat (depends on all related dimensions)
6. fact.layanan (depends on all related dimensions)
7. fact.aset (depends on all related dimensions)
8. Data quality checks
9. Logging & finalization
```

---

## 4. ETL Implementation Details

### 4.1 Stored Procedure Structure

ETL logic diimplementasikan menggunakan PL/pgSQL stored procedures yang terorganisir:

```sql
-- Master ETL Orchestration Procedure
CREATE OR REPLACE PROCEDURE dw.run_etl_full()
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id INTEGER;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_status VARCHAR(20);
    v_error_message TEXT;
BEGIN
    -- Initialize ETL run
    v_start_time := CURRENT_TIMESTAMP;
    v_batch_id := nextval('dw.etl_batch_id_seq');
    
    BEGIN
        -- Log ETL start
        INSERT INTO etl_log.job_execution (
            batch_id, job_name, start_time, status
        ) VALUES (
            v_batch_id, 'FULL_ETL', v_start_time, 'RUNNING'
        );
        
        -- Step 1: Load Dimensions
        CALL dw.load_dim_unit_organisasi(v_batch_id);
        CALL dw.load_dim_pegawai_scd2(v_batch_id);
        CALL dw.load_dim_jenis_surat(v_batch_id);
        CALL dw.load_dim_jenis_layanan(v_batch_id);
        CALL dw.load_dim_jenis_aset(v_batch_id);
        
        -- Step 2: Load Facts
        CALL dw.load_fact_surat(v_batch_id);
        CALL dw.load_fact_layanan(v_batch_id);
        CALL dw.load_fact_aset(v_batch_id);
        
        -- Step 3: Data Quality Checks
        CALL dw.run_data_quality_checks(v_batch_id);
        
        -- Mark as successful
        v_status := 'SUCCESS';
        v_end_time := CURRENT_TIMESTAMP;
        
    EXCEPTION WHEN OTHERS THEN
        v_status := 'FAILED';
        v_error_message := SQLERRM;
        v_end_time := CURRENT_TIMESTAMP;
        
        -- Log error
        INSERT INTO etl_log.error_details (
            batch_id, error_message, error_timestamp
        ) VALUES (
            v_batch_id, v_error_message, v_end_time
        );
    END;
    
    -- Update job status
    UPDATE etl_log.job_execution
    SET end_time = v_end_time,
        status = v_status,
        duration_seconds = EXTRACT(EPOCH FROM (v_end_time - v_start_time))
    WHERE batch_id = v_batch_id;
    
    COMMIT;
END;
$$;
```

### 4.2 SCD Type 2 Implementation Example

```sql
CREATE OR REPLACE PROCEDURE dw.load_dim_pegawai_scd2(p_batch_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_inserted INTEGER := 0;
    v_rows_updated INTEGER := 0;
BEGIN
    -- Close expired versions for changed records
    UPDATE dim.pegawai dp
    SET is_current = FALSE,
        valid_to = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
    FROM stg.pegawai sp
    WHERE dp.nip = sp.nip
      AND dp.is_current = TRUE
      AND (
          dp.jabatan != sp.jabatan OR
          dp.unit_kerja != sp.unit_kerja OR
          dp.status_kepegawaian != sp.status_kepegawaian
      );
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    -- Insert new versions for changed records
    INSERT INTO dim.pegawai (
        nip, nama_lengkap, jabatan, unit_kerja, email, telepon,
        status_kepegawaian, valid_from, valid_to, is_current
    )
    SELECT 
        sp.nip,
        INITCAP(TRIM(sp.nama_lengkap)),
        TRIM(sp.jabatan),
        TRIM(sp.unit_kerja),
        LOWER(TRIM(sp.email)),
        REGEXP_REPLACE(sp.telepon, '[^0-9+]', '', 'g'),
        UPPER(sp.status_kepegawaian),
        CURRENT_TIMESTAMP,
        '9999-12-31'::TIMESTAMP,
        TRUE
    FROM stg.pegawai sp
    LEFT JOIN dim.pegawai dp ON sp.nip = dp.nip AND dp.is_current = TRUE
    WHERE dp.pegawai_key IS NULL  -- New employees
       OR (  -- Changed employees
          dp.jabatan != sp.jabatan OR
          dp.unit_kerja != sp.unit_kerja OR
          dp.status_kepegawaian != sp.status_kepegawaian
       );
    
    GET DIAGNOSTICS v_rows_inserted = ROW_COUNT;
    
    -- Log results
    INSERT INTO etl_log.job_execution (
        batch_id, job_name, rows_inserted, rows_updated, status
    ) VALUES (
        p_batch_id, 'load_dim_pegawai_scd2', v_rows_inserted, v_rows_updated, 'SUCCESS'
    );
    
    COMMIT;
END;
$$;
```

### 4.3 Fact Table Loading Example

```sql
CREATE OR REPLACE PROCEDURE dw.load_fact_layanan(p_batch_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_processed INTEGER := 0;
BEGIN
    -- Insert or update fact_layanan
    INSERT INTO fact.layanan (
        transaksi_id,
        tanggal_permintaan_key,
        tanggal_selesai_key,
        jenis_layanan_key,
        pemohon_key,
        petugas_key,
        unit_key,
        status_layanan_key,
        jumlah_layanan,
        lama_proses_hari,
        rating_kepuasan,
        is_ontime,
        etl_batch_id
    )
    SELECT 
        sl.transaksi_id,
        w1.waktu_key AS tanggal_permintaan_key,
        w2.waktu_key AS tanggal_selesai_key,
        jl.jenis_layanan_key,
        p1.pegawai_key AS pemohon_key,
        p2.pegawai_key AS petugas_key,
        u.unit_key,
        st.status_layanan_key,
        1 AS jumlah_layanan,
        CASE 
            WHEN sl.tanggal_selesai IS NOT NULL 
            THEN sl.tanggal_selesai - sl.tanggal_permintaan 
            ELSE NULL 
        END AS lama_proses_hari,
        sl.rating_kepuasan,
        CASE 
            WHEN sl.tanggal_selesai IS NOT NULL 
            THEN (sl.tanggal_selesai - sl.tanggal_permintaan) <= jl.target_sla_hari
            ELSE NULL 
        END AS is_ontime,
        p_batch_id
    FROM stg.layanan sl
    INNER JOIN dim.waktu w1 ON sl.tanggal_permintaan = w1.tanggal
    LEFT JOIN dim.waktu w2 ON sl.tanggal_selesai = w2.tanggal
    INNER JOIN dim.jenis_layanan jl ON sl.jenis_layanan_id = jl.jenis_layanan_id
    INNER JOIN dim.pegawai p1 ON sl.pemohon_nip = p1.nip AND p1.is_current = TRUE
    LEFT JOIN dim.pegawai p2 ON sl.petugas_nip = p2.nip AND p2.is_current = TRUE
    INNER JOIN dim.unit_organisasi u ON sl.unit_pemohon_kode = u.kode_unit
    INNER JOIN dim.status_layanan st ON sl.status_layanan = st.status_layanan_id
    ON CONFLICT (transaksi_id) DO UPDATE SET
        tanggal_selesai_key = EXCLUDED.tanggal_selesai_key,
        petugas_key = EXCLUDED.petugas_key,
        status_layanan_key = EXCLUDED.status_layanan_key,
        lama_proses_hari = EXCLUDED.lama_proses_hari,
        rating_kepuasan = EXCLUDED.rating_kepuasan,
        is_ontime = EXCLUDED.is_ontime,
        updated_at = CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_rows_processed = ROW_COUNT;
    
    -- Log results
    INSERT INTO etl_log.job_execution (
        batch_id, job_name, rows_processed, status
    ) VALUES (
        p_batch_id, 'load_fact_layanan', v_rows_processed, 'SUCCESS'
    );
    
    COMMIT;
END;
$$;
```

---

## 5. Data Quality Framework

### 5.1 Data Quality Dimensions

1. **Completeness**: All required fields populated
2. **Accuracy**: Data values correct and valid
3. **Consistency**: Data consistent across systems
4. **Timeliness**: Data current and up-to-date
5. **Validity**: Data conforms to business rules
6. **Uniqueness**: No duplicate records

### 5.2 Quality Check Categories

#### 5.2.1 Schema-Level Checks
```sql
CREATE OR REPLACE PROCEDURE dw.check_schema_quality(p_batch_id INTEGER)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check for NULL in NOT NULL columns
    INSERT INTO etl_log.data_quality_checks (
        batch_id, check_name, check_status, issue_count
    )
    SELECT 
        p_batch_id,
        'null_check_fact_surat',
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        COUNT(*)
    FROM fact.surat
    WHERE nomor_surat IS NULL
       OR tanggal_key IS NULL
       OR jenis_surat_key IS NULL;
    
    -- Check foreign key integrity
    INSERT INTO etl_log.data_quality_checks (
        batch_id, check_name, check_status, issue_count
    )
    SELECT 
        p_batch_id,
        'fk_integrity_fact_surat_tanggal',
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        COUNT(*)
    FROM fact.surat fs
    LEFT JOIN dim.waktu w ON fs.tanggal_key = w.waktu_key
    WHERE w.waktu_key IS NULL;
END;
$$;
```

#### 5.2.2 Business Rule Checks
```sql
-- Check SLA compliance rates
INSERT INTO etl_log.data_quality_checks (
    batch_id, check_name, check_status, measured_value
)
SELECT 
    p_batch_id,
    'sla_compliance_rate',
    CASE WHEN AVG(CASE WHEN is_ontime THEN 1.0 ELSE 0.0 END) >= 0.80 
         THEN 'PASS' ELSE 'WARN' END,
    AVG(CASE WHEN is_ontime THEN 1.0 ELSE 0.0 END) * 100
FROM fact.layanan
WHERE status_layanan_key = (SELECT status_layanan_key FROM dim.status_layanan WHERE status_layanan_id = 'SELESAI');

-- Check asset value consistency
INSERT INTO etl_log.data_quality_checks (
    batch_id, check_name, check_status, issue_count
)
SELECT 
    p_batch_id,
    'asset_value_consistency',
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
    COUNT(*)
FROM fact.aset
WHERE nilai_buku > nilai_perolehan;
```

### 5.3 Quality Monitoring Dashboard Queries

```sql
-- ETL Success Rate (Last 30 Days)
SELECT 
    DATE(start_time) AS run_date,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful_runs,
    ROUND(100.0 * SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct
FROM etl_log.job_execution
WHERE start_time >= CURRENT_DATE - INTERVAL '30 days'
  AND job_name = 'FULL_ETL'
GROUP BY DATE(start_time)
ORDER BY run_date DESC;

-- Data Quality Trend
SELECT 
    DATE(check_timestamp) AS check_date,
    check_name,
    check_status,
    issue_count,
    measured_value
FROM etl_log.data_quality_checks
WHERE check_timestamp >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY check_timestamp DESC, check_name;
```

---

## 6. Performance Optimization

### 6.1 Indexing Strategy

#### 6.1.1 Index Types Used

1. **B-tree Indexes** (default): For equality and range queries
2. **Partial Indexes**: For filtered queries (e.g., WHERE is_current = TRUE)
3. **Composite Indexes**: For multi-column predicates

#### 6.1.2 Dimension Table Indexes

```sql
-- dim.waktu
CREATE INDEX idx_waktu_tahun ON dim.waktu(tahun);
CREATE INDEX idx_waktu_bulan ON dim.waktu(bulan);
CREATE INDEX idx_waktu_tahun_bulan ON dim.waktu(tahun, bulan);

-- dim.pegawai
CREATE INDEX idx_pegawai_nip_current ON dim.pegawai(nip) WHERE is_current = TRUE;
CREATE INDEX idx_pegawai_unit ON dim.pegawai(unit_kerja);
CREATE INDEX idx_pegawai_status ON dim.pegawai(status_kepegawaian);

-- dim.unit_organisasi
CREATE INDEX idx_unit_parent ON dim.unit_organisasi(parent_kode_unit);
CREATE INDEX idx_unit_type ON dim.unit_organisasi(tipe_unit);
CREATE INDEX idx_unit_path ON dim.unit_organisasi USING gin(path_hierarchy gin_trgm_ops);
```

#### 6.1.3 Fact Table Indexes

```sql
-- fact.surat
CREATE INDEX idx_fact_surat_composite1 ON fact.surat(tanggal_key, unit_pengirim_key);
CREATE INDEX idx_fact_surat_composite2 ON fact.surat(tanggal_key, status_disposisi);
CREATE INDEX idx_fact_surat_prioritas ON fact.surat(prioritas) WHERE prioritas IN ('URGENT', 'HIGH');

-- fact.layanan
CREATE INDEX idx_fact_layanan_composite1 ON fact.layanan(tanggal_permintaan_key, jenis_layanan_key);
CREATE INDEX idx_fact_layanan_ontime ON fact.layanan(is_ontime) WHERE is_ontime = FALSE;

-- fact.aset
CREATE INDEX idx_fact_aset_snapshot_unit ON fact.aset(snapshot_date_key, unit_pemilik_key);
CREATE INDEX idx_fact_aset_status ON fact.aset(status_aset) WHERE status_aset != 'AKTIF';
```

### 6.2 Query Optimization Techniques

#### 6.2.1 Use EXPLAIN ANALYZE

```sql
EXPLAIN ANALYZE
SELECT 
    u.nama_unit,
    COUNT(f.surat_fact_key) AS jumlah_surat,
    AVG(f.lama_disposisi_hari) AS avg_processing_days
FROM fact.surat f
INNER JOIN dim.unit_organisasi u ON f.unit_pengirim_key = u.unit_key
INNER JOIN dim.waktu w ON f.tanggal_key = w.waktu_key
WHERE w.tahun = 2024
  AND w.bulan = 11
GROUP BY u.nama_unit
ORDER BY jumlah_surat DESC;
```

#### 6.2.2 Materialized Views for Common Queries

```sql
CREATE MATERIALIZED VIEW analytics.monthly_surat_summary AS
SELECT 
    w.tahun,
    w.bulan,
    u.nama_unit,
    js.nama_jenis,
    COUNT(*) AS jumlah_surat,
    AVG(f.lama_disposisi_hari) AS avg_processing_days,
    SUM(CASE WHEN f.prioritas = 'URGENT' THEN 1 ELSE 0 END) AS jumlah_urgent
FROM fact.surat f
INNER JOIN dim.waktu w ON f.tanggal_key = w.waktu_key
INNER JOIN dim.unit_organisasi u ON f.unit_pengirim_key = u.unit_key
INNER JOIN dim.jenis_surat js ON f.jenis_surat_key = js.jenis_surat_key
GROUP BY w.tahun, w.bulan, u.nama_unit, js.nama_jenis;

CREATE INDEX idx_monthly_surat_year_month ON analytics.monthly_surat_summary(tahun, bulan);
```

### 6.3 Partitioning Strategy (Future Enhancement)

For future scalability, consider partitioning fact tables:

```sql
-- Partition fact.surat by year
CREATE TABLE fact.surat_2024 PARTITION OF fact.surat
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

CREATE TABLE fact.surat_2025 PARTITION OF fact.surat
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
```

---

## 7. Testing Strategy

### 7.1 Unit Testing

Test individual stored procedures:

```sql
-- Test dim.pegawai SCD2 logic
BEGIN;
    -- Setup test data
    INSERT INTO stg.pegawai VALUES ('12345', 'Test User', 'Staff', 'UNIT-001', ...);
    
    -- Run ETL
    CALL dw.load_dim_pegawai_scd2(9999);
    
    -- Verify results
    SELECT * FROM dim.pegawai WHERE nip = '12345';
    
ROLLBACK;
```

### 7.2 Integration Testing

Test complete ETL flow:

```sql
-- Full ETL test
CALL dw.run_etl_full();

-- Verify counts
SELECT 'dim.pegawai' AS table_name, COUNT(*) AS row_count FROM dim.pegawai
UNION ALL
SELECT 'fact.surat', COUNT(*) FROM fact.surat
UNION ALL
SELECT 'fact.layanan', COUNT(*) FROM fact.layanan;
```

### 7.3 Data Quality Testing

Automated quality checks after each ETL run:

```sql
-- Check for orphaned records
SELECT COUNT(*) AS orphaned_records
FROM fact.surat f
LEFT JOIN dim.waktu w ON f.tanggal_key = w.waktu_key
WHERE w.waktu_key IS NULL;
```

---

## 8. Deployment Procedures

### 8.1 Initial Deployment Checklist

- [ ] Create database and schemas
- [ ] Deploy dimension tables
- [ ] Deploy fact tables
- [ ] Deploy staging tables
- [ ] Deploy logging tables
- [ ] Create indexes
- [ ] Deploy stored procedures
- [ ] Load dim.waktu (2020-2030)
- [ ] Load static dimensions (status_layanan, etc)
- [ ] Test ETL with sample data
- [ ] Verify data quality checks
- [ ] Document access credentials

### 8.2 Regular ETL Schedule

**Daily ETL (Incremental):**
- Time: 02:00 AM WIB
- Duration: ~15-30 minutes
- Scope: fact.surat, fact.layanan, dimension updates

**Monthly ETL (Snapshot):**
- Time: Last day of month, 03:00 AM WIB
- Duration: ~45-60 minutes
- Scope: fact.aset snapshot, full refresh

---

## 9. Operational Guidelines

### 9.1 Monitoring

**Key Metrics to Monitor:**
1. ETL success rate
2. ETL duration trend
3. Data quality check failures
4. Row count trends
5. Disk space utilization

### 9.2 Troubleshooting

**Common Issues:**

| Issue | Possible Cause | Solution |
|-------|---------------|----------|
| ETL fails at dimension load | Source data quality issues | Check etl_log.error_details, fix source data |
| Slow query performance | Missing indexes | Run EXPLAIN ANALYZE, add appropriate indexes |
| Duplicate records in facts | Missing UNIQUE constraint | Add UNIQUE constraint on business key |
| SCD2 not tracking changes | Comparison logic error | Review SCD2 procedure, check column mappings |

### 9.3 Backup & Recovery

**Backup Strategy:**
- Daily full backup of database
- Transaction log backup every 4 hours
- Monthly archive of historical data

---

## 10. Appendices

### Appendix A: File Deliverables

1. **etl-architecture-diagram.drawio** - Complete ETL architecture diagram
2. **ETL_Mapping_Spreadsheet.csv** - Comprehensive source-to-target mappings (83 rows)
3. **sample_stg_surat.csv** - Sample correspondence data (100 rows)
4. **sample_stg_pegawai.csv** - Sample employee data (50 rows)
5. **sample_stg_layanan.csv** - Sample service data (150 rows)
6. **sample_stg_aset.csv** - Sample asset data (80 rows)
7. **sample_stg_unit_organisasi.csv** - Sample organizational units (20 rows)

### Appendix B: SQL Script References

Refer to GitHub repository for complete SQL scripts:
- `sql/02_Create_Dimensions.sql`
- `sql/03_Create_Facts.sql`
- `sql/04_Create_Indexes.sql`
- `sql/06_Create_Staging.sql`
- `sql/07_ETL_Procedures.sql`

### Appendix C: Team Contacts

| Name | Role | Contact |
|------|------|---------|
| Aldi | Project Lead & Database Designer | [email] |
| Zahra | ETL Developer & Data Engineer | [email] |
| Feby (Aya) | BI Developer & Documentation | [email] |

---

**Document Control:**
- **Version:** 1.0
- **Last Updated:** 24 November 2025
- **Next Review:** Misi 3 Kickoff
- **Approved By:** Kelompok 19

---

*End of Technical Documentation - Misi 2*
