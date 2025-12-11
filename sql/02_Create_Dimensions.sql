-- =====================================================
-- 02_Create_Dimensions.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create AND Seed Dimension Tables in 'dim' schema
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Creating Dimensions...';

-- =====================================================
-- 1. DIM WAKTU (Date Dimension)
-- =====================================================

IF OBJECT_ID('dim.dim_waktu', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_waktu (
        tanggal_key INT PRIMARY KEY, -- YYYYMMDD format
        tanggal DATE NOT NULL,
        hari VARCHAR(20),
        bulan INT,
        tahun INT,
        quarter INT,
        minggu_tahun INT,
        hari_dalam_bulan INT,
        hari_kerja BIT, -- BIT replaces BOOLEAN
        bulan_tahun VARCHAR(20)
    );
END
GO

-- SEEDING DEFAULT DATE
IF NOT EXISTS (SELECT 1 FROM dim.dim_waktu WHERE tanggal_key = 19000101)
BEGIN
    INSERT INTO dim.dim_waktu (tanggal_key, tanggal, hari, bulan, tahun, quarter, minggu_tahun, hari_dalam_bulan, hari_kerja, bulan_tahun)
    VALUES (19000101, '1900-01-01', 'Unknown', 1, 1900, 1, 1, 1, 0, 'Unknown');
END
GO

-- =====================================================
-- 2. DIM UNIT KERJA
-- =====================================================

IF OBJECT_ID('dim.dim_unit_kerja', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_unit_kerja (
        unit_key INT IDENTITY(1,1) PRIMARY KEY, -- SERIAL replaces IDENTITY
        kode_unit VARCHAR(20) NOT NULL,
        nama_unit VARCHAR(100) NOT NULL,
        level INT,
        parent_unit_key INT REFERENCES dim.dim_unit_kerja(unit_key),
        kepala_unit_nip VARCHAR(20),
        email_unit VARCHAR(100),
        path_hierarchy VARCHAR(MAX), -- TEXT replaces VARCHAR(MAX)
        jumlah_sub_unit INT DEFAULT 0,
        is_active BIT DEFAULT 1 -- BIT replaces BOOLEAN (1=True)
    );
END
GO

-- SEEDING DEFAULT ROW (-1)
-- Note: Must enable IDENTITY_INSERT to manually set ID -1
SET IDENTITY_INSERT dim.dim_unit_kerja ON;
IF NOT EXISTS (SELECT 1 FROM dim.dim_unit_kerja WHERE unit_key = -1)
BEGIN
    INSERT INTO dim.dim_unit_kerja (unit_key, kode_unit, nama_unit, level, is_active)
    VALUES (-1, 'UNK', 'Unknown Unit', 0, 1);
END
SET IDENTITY_INSERT dim.dim_unit_kerja OFF;
GO

-- =====================================================
-- 3. DIM PEGAWAI
-- =====================================================

IF OBJECT_ID('dim.dim_pegawai', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_pegawai (
        pegawai_key INT IDENTITY(1,1) PRIMARY KEY,
        nip VARCHAR(20) NOT NULL,
        nama VARCHAR(100),
        jabatan VARCHAR(100),
        unit_key INT REFERENCES dim.dim_unit_kerja(unit_key),
        status_kepegawaian VARCHAR(50),
        tanggal_masuk DATE,
        email VARCHAR(100),
        no_hp VARCHAR(20),
        effective_date DATE NOT NULL,
        end_date DATE DEFAULT '9999-12-31',
        is_current BIT DEFAULT 1
    );
    CREATE INDEX ix_dim_pegawai_nip ON dim.dim_pegawai(nip);
END
GO

-- SEEDING DEFAULT ROW (-1)
SET IDENTITY_INSERT dim.dim_pegawai ON;
IF NOT EXISTS (SELECT 1 FROM dim.dim_pegawai WHERE pegawai_key = -1)
BEGIN
    INSERT INTO dim.dim_pegawai (pegawai_key, nip, nama, effective_date, is_current)
    VALUES (-1, 'UNK', 'Unknown Employee', '1900-01-01', 1);
END
SET IDENTITY_INSERT dim.dim_pegawai OFF;
GO

-- =====================================================
-- 4. DIM JENIS SURAT
-- =====================================================

IF OBJECT_ID('dim.dim_jenis_surat', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_jenis_surat (
        jenis_surat_key INT IDENTITY(1,1) PRIMARY KEY,
        kode_jenis_surat VARCHAR(20),
        nama_jenis_surat VARCHAR(100),
        kategori VARCHAR(50),
        sifat VARCHAR(20),
        is_active BIT DEFAULT 1
    );
END
GO

-- SEEDING REFERENCE DATA
SET IDENTITY_INSERT dim.dim_jenis_surat ON;

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_surat WHERE jenis_surat_key = -1)
    INSERT INTO dim.dim_jenis_surat (jenis_surat_key, kode_jenis_surat, nama_jenis_surat, kategori, sifat, is_active) 
    VALUES (-1, 'UNK', 'Unknown', 'Unknown', 'Biasa', 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_surat WHERE jenis_surat_key = 1)
    INSERT INTO dim.dim_jenis_surat (jenis_surat_key, kode_jenis_surat, nama_jenis_surat, kategori, sifat, is_active) 
    VALUES (1, 'SRT-UM', 'Surat Undangan', 'Eksternal', 'Biasa', 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_surat WHERE jenis_surat_key = 2)
    INSERT INTO dim.dim_jenis_surat (jenis_surat_key, kode_jenis_surat, nama_jenis_surat, kategori, sifat, is_active) 
    VALUES (2, 'SRT-ED', 'Surat Edaran', 'Internal', 'Penting', 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_surat WHERE jenis_surat_key = 3)
    INSERT INTO dim.dim_jenis_surat (jenis_surat_key, kode_jenis_surat, nama_jenis_surat, kategori, sifat, is_active) 
    VALUES (3, 'SRT-TG', 'Surat Tugas', 'Internal', 'Biasa', 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_surat WHERE jenis_surat_key = 4)
    INSERT INTO dim.dim_jenis_surat (jenis_surat_key, kode_jenis_surat, nama_jenis_surat, kategori, sifat, is_active) 
    VALUES (4, 'SRT-SK', 'Surat Keputusan', 'Internal', 'Rahasia', 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_surat WHERE jenis_surat_key = 5)
    INSERT INTO dim.dim_jenis_surat (jenis_surat_key, kode_jenis_surat, nama_jenis_surat, kategori, sifat, is_active) 
    VALUES (5, 'SRT-PM', 'Surat Permohonan', 'Eksternal', 'Segera', 1);

SET IDENTITY_INSERT dim.dim_jenis_surat OFF;
GO

-- =====================================================
-- 5. DIM JENIS LAYANAN
-- =====================================================

IF OBJECT_ID('dim.dim_jenis_layanan', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_jenis_layanan (
        jenis_layanan_key INT IDENTITY(1,1) PRIMARY KEY,
        kode_jenis_layanan VARCHAR(20),
        nama_jenis_layanan VARCHAR(100),
        kategori_layanan VARCHAR(50),
        sla_target_jam INT,
        is_active BIT DEFAULT 1
    );
END
GO

-- SEEDING REFERENCE DATA
SET IDENTITY_INSERT dim.dim_jenis_layanan ON;

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_layanan WHERE jenis_layanan_key = -1)
    INSERT INTO dim.dim_jenis_layanan (jenis_layanan_key, kode_jenis_layanan, nama_jenis_layanan, sla_target_jam, is_active) 
    VALUES (-1, 'UNK', 'Unknown', 0, 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_layanan WHERE jenis_layanan_key = 1)
    INSERT INTO dim.dim_jenis_layanan (jenis_layanan_key, kode_jenis_layanan, nama_jenis_layanan, sla_target_jam, is_active) 
    VALUES (1, 'LYN-PR', 'Peminjaman Ruangan', 24, 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_layanan WHERE jenis_layanan_key = 2)
    INSERT INTO dim.dim_jenis_layanan (jenis_layanan_key, kode_jenis_layanan, nama_jenis_layanan, sla_target_jam, is_active) 
    VALUES (2, 'LYN-LG', 'Legalisir Dokumen', 48, 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_layanan WHERE jenis_layanan_key = 3)
    INSERT INTO dim.dim_jenis_layanan (jenis_layanan_key, kode_jenis_layanan, nama_jenis_layanan, sla_target_jam, is_active) 
    VALUES (3, 'LYN-SR', 'Permintaan Surat', 72, 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_layanan WHERE jenis_layanan_key = 4)
    INSERT INTO dim.dim_jenis_layanan (jenis_layanan_key, kode_jenis_layanan, nama_jenis_layanan, sla_target_jam, is_active) 
    VALUES (4, 'LYN-ATK', 'Permintaan ATK', 24, 1);

IF NOT EXISTS (SELECT 1 FROM dim.dim_jenis_layanan WHERE jenis_layanan_key = 5)
    INSERT INTO dim.dim_jenis_layanan (jenis_layanan_key, kode_jenis_layanan, nama_jenis_layanan, sla_target_jam, is_active) 
    VALUES (5, 'LYN-CMP', 'Pengaduan Fasilitas', 24, 1);

SET IDENTITY_INSERT dim.dim_jenis_layanan OFF;
GO

-- =====================================================
-- 6. DIM BARANG
-- =====================================================

IF OBJECT_ID('dim.dim_barang', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_barang (
        barang_key INT IDENTITY(1,1) PRIMARY KEY,
        kode_barang VARCHAR(30) NOT NULL,
        nama_barang VARCHAR(200),
        kategori_barang VARCHAR(50),
        subkategori_barang VARCHAR(50),
        satuan VARCHAR(20),
        merk VARCHAR(50),
        spesifikasi VARCHAR(MAX),
        is_bergerak BIT,
        is_tik BIT
    );
END
GO

-- SEEDING DEFAULT ROW (-1)
SET IDENTITY_INSERT dim.dim_barang ON;
IF NOT EXISTS (SELECT 1 FROM dim.dim_barang WHERE barang_key = -1)
BEGIN
    INSERT INTO dim.dim_barang (barang_key, kode_barang, nama_barang) 
    VALUES (-1, 'UNK', 'Unknown Item');
END
SET IDENTITY_INSERT dim.dim_barang OFF;
GO

-- =====================================================
-- 7. DIM LOKASI
-- =====================================================

IF OBJECT_ID('dim.dim_lokasi', 'U') IS NULL
BEGIN
    CREATE TABLE dim.dim_lokasi (
        lokasi_key INT IDENTITY(1,1) PRIMARY KEY,
        kode_lokasi VARCHAR(30),
        nama_lokasi VARCHAR(100),
        jenis_lokasi VARCHAR(50),
        gedung VARCHAR(50),
        lantai VARCHAR(10),
        keterangan VARCHAR(MAX)
    );
END
GO

-- SEEDING DEFAULT ROW (-1)
SET IDENTITY_INSERT dim.dim_lokasi ON;
IF NOT EXISTS (SELECT 1 FROM dim.dim_lokasi WHERE lokasi_key = -1)
BEGIN
    INSERT INTO dim.dim_lokasi (lokasi_key, kode_lokasi, nama_lokasi) 
    VALUES (-1, 'UNK', 'Unknown Location');
END
SET IDENTITY_INSERT dim.dim_lokasi OFF;
GO

-- =====================================================
-- SUCCESS NOTICES
-- =====================================================

PRINT '>> All Dimensions Created & Seeded.';
GO
