-- =====================================================
-- 02_Create_Dimensions.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create AND Seed Dimension Tables in 'dim' schema
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- 1. DIM WAKTU (Date Dimension)
-- =====================================================

CREATE TABLE IF NOT EXISTS dim.dim_waktu (
    tanggal_key INT PRIMARY KEY,
    tanggal DATE NOT NULL,
    hari VARCHAR(20),
    bulan INT,
    tahun INT,
    quarter INT,
    minggu_tahun INT,
    hari_dalam_bulan INT,
    hari_kerja BOOLEAN,
    bulan_tahun VARCHAR(20)
);

-- SEEDING DEFAULT DATE
INSERT INTO dim.dim_waktu (tanggal_key, tanggal, hari, bulan, tahun, quarter, minggu_tahun, hari_dalam_bulan, hari_kerja, bulan_tahun)
VALUES (19000101, '1900-01-01', 'Unknown', 1, 1900, 1, 1, 1, FALSE, 'Unknown')
ON CONFLICT (tanggal_key) DO NOTHING;

-- =====================================================
-- 2. DIM UNIT KERJA
-- =====================================================

CREATE TABLE IF NOT EXISTS dim.dim_unit_kerja (
    unit_key SERIAL PRIMARY KEY,
    kode_unit VARCHAR(20) NOT NULL,
    nama_unit VARCHAR(100) NOT NULL,
    level INT,
    parent_unit_key INT REFERENCES dim.dim_unit_kerja(unit_key),
    kepala_unit_nip VARCHAR(20),
    email_unit VARCHAR(100),
    path_hierarchy TEXT,
    jumlah_sub_unit INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE
);

-- SEEDING DEFAULT ROW (-1)
INSERT INTO dim.dim_unit_kerja (unit_key, kode_unit, nama_unit, level, is_active)
VALUES (-1, 'UNK', 'Unknown Unit', 0, TRUE)
ON CONFLICT (unit_key) DO NOTHING;

-- =====================================================
-- 3. DIM PEGAWAI
-- =====================================================

CREATE TABLE IF NOT EXISTS dim.dim_pegawai (
    pegawai_key SERIAL PRIMARY KEY,
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
    is_current BOOLEAN DEFAULT TRUE
);
CREATE INDEX IF NOT EXISTS ix_dim_pegawai_nip ON dim.dim_pegawai(nip);

-- SEEDING DEFAULT ROW (-1)
INSERT INTO dim.dim_pegawai (pegawai_key, nip, nama, effective_date, is_current)
VALUES (-1, 'UNK', 'Unknown Employee', '1900-01-01', TRUE)
ON CONFLICT (pegawai_key) DO NOTHING;

-- =====================================================
-- 4. DIM JENIS SURAT
-- =====================================================

CREATE TABLE IF NOT EXISTS dim.dim_jenis_surat (
    jenis_surat_key SERIAL PRIMARY KEY,
    kode_jenis_surat VARCHAR(20),
    nama_jenis_surat VARCHAR(100),
    kategori VARCHAR(50),
    sifat VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE
);

-- SEEDING REFERENCE DATA
INSERT INTO dim.dim_jenis_surat (jenis_surat_key, kode_jenis_surat, nama_jenis_surat, kategori, sifat, is_active) VALUES
(-1, 'UNK', 'Unknown', 'Unknown', 'Biasa', TRUE),
(1, 'SRT-UM', 'Surat Undangan', 'Eksternal', 'Biasa', TRUE),
(2, 'SRT-ED', 'Surat Edaran', 'Internal', 'Penting', TRUE),
(3, 'SRT-TG', 'Surat Tugas', 'Internal', 'Biasa', TRUE),
(4, 'SRT-SK', 'Surat Keputusan', 'Internal', 'Rahasia', TRUE),
(5, 'SRT-PM', 'Surat Permohonan', 'Eksternal', 'Segera', TRUE)
ON CONFLICT (jenis_surat_key) DO NOTHING;

-- =====================================================
-- 5. DIM JENIS LAYANAN
-- =====================================================

CREATE TABLE IF NOT EXISTS dim.dim_jenis_layanan (
    jenis_layanan_key SERIAL PRIMARY KEY,
    kode_jenis_layanan VARCHAR(20),
    nama_jenis_layanan VARCHAR(100),
    kategori_layanan VARCHAR(50),
    sla_target_jam INT,
    is_active BOOLEAN DEFAULT TRUE
);

-- SEEDING REFERENCE DATA
INSERT INTO dim.dim_jenis_layanan (jenis_layanan_key, kode_jenis_layanan, nama_jenis_layanan, sla_target_jam, is_active) VALUES
(-1, 'UNK', 'Unknown', 0, TRUE),
(1, 'LYN-PR', 'Peminjaman Ruangan', 24, TRUE),
(2, 'LYN-LG', 'Legalisir Dokumen', 48, TRUE),
(3, 'LYN-SR', 'Permintaan Surat', 72, TRUE),
(4, 'LYN-ATK', 'Permintaan ATK', 24, TRUE),
(5, 'LYN-CMP', 'Pengaduan Fasilitas', 24, TRUE)
ON CONFLICT (jenis_layanan_key) DO NOTHING;

-- =====================================================
-- 6. DIM BARANG
-- =====================================================

CREATE TABLE IF NOT EXISTS dim.dim_barang (
    barang_key SERIAL PRIMARY KEY,
    kode_barang VARCHAR(30) NOT NULL,
    nama_barang VARCHAR(200),
    kategori_barang VARCHAR(50),
    subkategori_barang VARCHAR(50),
    satuan VARCHAR(20),
    merk VARCHAR(50),
    spesifikasi TEXT,
    is_bergerak BOOLEAN,
    is_tik BOOLEAN
);

-- SEEDING DEFAULT ROW (-1)
INSERT INTO dim.dim_barang (barang_key, kode_barang, nama_barang) VALUES
(-1, 'UNK', 'Unknown Item')
ON CONFLICT (barang_key) DO NOTHING;

-- =====================================================
-- 7. DIM LOKASI
-- =====================================================

CREATE TABLE IF NOT EXISTS dim.dim_lokasi (
    lokasi_key SERIAL PRIMARY KEY,
    kode_lokasi VARCHAR(30),
    nama_lokasi VARCHAR(100),
    jenis_lokasi VARCHAR(50),
    gedung VARCHAR(50),
    lantai VARCHAR(10),
    keterangan TEXT
);

-- SEEDING DEFAULT ROW (-1)
INSERT INTO dim.dim_lokasi (lokasi_key, kode_lokasi, nama_lokasi) VALUES
(-1, 'UNK', 'Unknown Location')
ON CONFLICT (lokasi_key) DO NOTHING;

-- =====================================================
-- SUCCESS NOTICES
-- =====================================================

SELECT 'All Dimensions Created & Seeded.' as status;

-- ====================== END OF FILE ======================
