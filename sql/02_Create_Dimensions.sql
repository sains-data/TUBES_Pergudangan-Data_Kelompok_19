-- =====================================================
-- 02_Create_Dimensions.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Dimension Tables in 'dim' schema
-- Engine  : Microsoft SQL Server 2019+
-- Dependencies: 01_Create_Database.sql must be executed first
-- =====================================================

/*
    Changes from PostgreSQL:
    - SERIAL -> INT IDENTITY(1,1)
    - BOOLEAN -> BIT (0=False, 1=True)
    - TEXT -> VARCHAR(MAX)
    - IF NOT EXISTS -> IF OBJECT_ID check
*/

-- 1. DIM WAKTU (Date Dimension)
-- Grain: 1 row per day
IF OBJECT_ID('dim.dim_waktu', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_waktu (
        tanggal_key         INT PRIMARY KEY, -- Format YYYYMMDD (e.g., 20241015)
        tanggal             DATE NOT NULL,
        hari                VARCHAR(20),     -- Senin, Selasa...
        bulan               INT,             -- 1-12
        tahun               INT,             -- 2024
        quarter             INT,             -- 1-4
        minggu_tahun        INT,             -- 1-53
        hari_dalam_bulan    INT,             -- 1-31
        hari_kerja          BIT,             -- 1 if Mon-Fri & not holiday
        bulan_tahun         VARCHAR(20)      -- 'Oktober 2024'
    );
END
GO

-- 2. DIM UNIT KERJA (Organizational Hierarchy)
-- Grain: 1 row per unit kerja
IF OBJECT_ID('dim.dim_unit_kerja', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_unit_kerja (
        unit_key            INT IDENTITY(1,1) PRIMARY KEY,
        kode_unit           VARCHAR(20) NOT NULL,
        nama_unit           VARCHAR(100) NOT NULL,
        level               INT,             -- 1=Rektorat, 2=Biro, etc.
        parent_unit_key     INT,             -- Self-referencing FK
        kepala_unit_nip     VARCHAR(20),
        email_unit          VARCHAR(100),
        path_hierarchy      VARCHAR(MAX),    -- 'Rektorat > BAU'
        jumlah_sub_unit     INT DEFAULT 0,
        is_active           BIT DEFAULT 1
    );

    -- Self-Referencing FK for Hierarchy
    ALTER TABLE dim.dim_unit_kerja 
    ADD CONSTRAINT fk_dim_unit_parent 
    FOREIGN KEY (parent_unit_key) REFERENCES dim.dim_unit_kerja(unit_key);
END
GO

-- 3. DIM PEGAWAI (SCD Type 2)
-- Grain: 1 row per employee version
IF OBJECT_ID('dim.dim_pegawai', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_pegawai (
        pegawai_key         INT IDENTITY(1,1) PRIMARY KEY,
        nip                 VARCHAR(20) NOT NULL,
        nama                VARCHAR(100),
        jabatan             VARCHAR(100),
        unit_key            INT,             -- FK to Dim Unit Kerja
        status_kepegawaian  VARCHAR(50),     -- PNS, PPPK, Honorer
        tanggal_masuk       DATE,
        email               VARCHAR(100),
        no_hp               VARCHAR(20),
        -- SCD Type 2 Columns
        effective_date      DATE NOT NULL,
        end_date            DATE DEFAULT '9999-12-31' NOT NULL,
        is_current          BIT DEFAULT 1
    );

    CREATE INDEX ix_dim_pegawai_nip ON dim.dim_pegawai(nip);
    CREATE INDEX ix_dim_pegawai_current ON dim.dim_pegawai(is_current);
END
GO

-- 4. DIM JENIS SURAT
-- Grain: 1 row per letter type
IF OBJECT_ID('dim.dim_jenis_surat', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_jenis_surat (
        jenis_surat_key     INT IDENTITY(1,1) PRIMARY KEY,
        kode_jenis_surat    VARCHAR(20),
        nama_jenis_surat    VARCHAR(100),
        kategori            VARCHAR(50),     -- Internal, Eksternal
        sifat               VARCHAR(20),     -- Biasa, Penting, Rahasia
        is_active           BIT DEFAULT 1
    );
END
GO

-- 5. DIM JENIS LAYANAN
-- Grain: 1 row per service type
IF OBJECT_ID('dim.dim_jenis_layanan', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_jenis_layanan (
        jenis_layanan_key   INT IDENTITY(1,1) PRIMARY KEY,
        kode_jenis_layanan  VARCHAR(20),
        nama_jenis_layanan  VARCHAR(100),
        kategori_layanan    VARCHAR(50),     -- Sarpras, Akademik
        sla_target_jam      INT,             -- Target SLA in hours
        is_active           BIT DEFAULT 1
    );
END
GO

-- 6. DIM BARANG (Aset/Inventaris)
-- Grain: 1 row per item type/asset
IF OBJECT_ID('dim.dim_barang', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_barang (
        barang_key          INT IDENTITY(1,1) PRIMARY KEY,
        kode_barang         VARCHAR(30) NOT NULL,
        nama_barang         VARCHAR(200),
        kategori_barang     VARCHAR(50),     -- Elektronik, Furnitur
        subkategori_barang  VARCHAR(50),
        satuan              VARCHAR(20),
        merk                VARCHAR(50),
        spesifikasi         VARCHAR(MAX),
        is_bergerak         BIT,             -- 1=True, 0=False
        is_tik              BIT              -- 1 if IT asset
    );
END
GO

-- 7. DIM LOKASI
-- Grain: 1 row per physical location
IF OBJECT_ID('dim.dim_lokasi', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_lokasi (
        lokasi_key          INT IDENTITY(1,1) PRIMARY KEY,
        kode_lokasi         VARCHAR(30),
        nama_lokasi         VARCHAR(100),
        jenis_lokasi        VARCHAR(50),     -- Ruang Kerja, Gudang, Kelas
        gedung              VARCHAR(50),
        lantai              VARCHAR(10),
        keterangan          VARCHAR(MAX)
    );
END
GO

-- =====================================================
-- NOTICE
-- =====================================================
PRINT 'Dimension tables created successfully in schema "dim".';

-- ====================== END OF FILE ======================
