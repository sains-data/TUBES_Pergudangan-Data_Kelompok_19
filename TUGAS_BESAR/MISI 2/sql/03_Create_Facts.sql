-- =====================================================
-- 03_Create_Facts.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Fact Tables in 'fact' schema
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Creating Fact Tables...';

-- =====================================================
-- 1. FACT SURAT (Transactional)
-- =====================================================

IF OBJECT_ID('fact.fact_surat', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_surat (
        surat_key BIGINT IDENTITY(1,1) PRIMARY KEY, -- BIGSERIAL -> BIGINT IDENTITY
        tanggal_key INT NOT NULL REFERENCES dim.dim_waktu(tanggal_key),
        unit_pengirim_key INT REFERENCES dim.dim_unit_kerja(unit_key),
        unit_penerima_key INT REFERENCES dim.dim_unit_kerja(unit_key),
        pegawai_penerima_key INT REFERENCES dim.dim_pegawai(pegawai_key),
        jenis_surat_key INT REFERENCES dim.dim_jenis_surat(jenis_surat_key),
        
        -- Degenerate Dimension
        nomor_surat VARCHAR(100),
        
        -- Measures
        jumlah_lampiran INT DEFAULT 0,
        durasi_proses_hari INT,
        
        -- Status & Flags
        melewati_sla_flag BIT, -- BOOLEAN -> BIT
        status_akhir VARCHAR(50),
        channel VARCHAR(20),
        
        -- Audit
        created_at DATETIME DEFAULT GETDATE() -- TIMESTAMP -> DATETIME
    );

    -- Create Indexes
    CREATE INDEX ix_fact_surat_tgl ON fact.fact_surat(tanggal_key);
    CREATE INDEX ix_fact_surat_jenis ON fact.fact_surat(jenis_surat_key);
    CREATE INDEX ix_fact_surat_unit ON fact.fact_surat(unit_pengirim_key);
END
GO

-- =====================================================
-- 2. FACT LAYANAN (Transactional)
-- =====================================================

IF OBJECT_ID('fact.fact_layanan', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_layanan (
        layanan_key BIGINT IDENTITY(1,1) PRIMARY KEY,
        tanggal_request_key INT NOT NULL REFERENCES dim.dim_waktu(tanggal_key),
        tanggal_selesai_key INT REFERENCES dim.dim_waktu(tanggal_key),
        unit_pemohon_key INT REFERENCES dim.dim_unit_kerja(unit_key),
        unit_pelaksana_key INT REFERENCES dim.dim_unit_kerja(unit_key),
        pegawai_pemohon_key INT REFERENCES dim.dim_pegawai(pegawai_key),
        pegawai_penanggung_jawab_key INT REFERENCES dim.dim_pegawai(pegawai_key),
        jenis_layanan_key INT REFERENCES dim.dim_jenis_layanan(jenis_layanan_key),
        
        -- Degenerate Dimension
        nomor_tiket VARCHAR(50),
        
        -- Measures
        sla_target_jam INT,
        waktu_respon_jam DECIMAL(10,2), -- NUMERIC -> DECIMAL
        waktu_selesai_jam DECIMAL(10,2),
        rating_kepuasan DECIMAL(3,2),
        biaya_layanan DECIMAL(18,2),
        
        -- Flags
        melewati_sla_flag BIT,
        status_akhir VARCHAR(50),
        
        -- Audit
        created_at DATETIME DEFAULT GETDATE()
    );

    -- Create Indexes
    CREATE INDEX ix_fact_layanan_tgl ON fact.fact_layanan(tanggal_request_key);
    CREATE INDEX ix_fact_layanan_jenis ON fact.fact_layanan(jenis_layanan_key);
END
GO

-- =====================================================
-- 3. FACT ASET (Periodic Snapshot)
-- =====================================================

IF OBJECT_ID('fact.fact_aset', 'U') IS NULL
BEGIN
    CREATE TABLE fact.fact_aset (
        aset_snapshot_key BIGINT IDENTITY(1,1) PRIMARY KEY,
        tanggal_snapshot_key INT NOT NULL REFERENCES dim.dim_waktu(tanggal_key),
        barang_key INT NOT NULL REFERENCES dim.dim_barang(barang_key),
        lokasi_key INT REFERENCES dim.dim_lokasi(lokasi_key),
        unit_pemilik_key INT REFERENCES dim.dim_unit_kerja(unit_key),
        
        -- Measures
        jumlah_unit INT DEFAULT 1,
        nilai_perolehan DECIMAL(18,2),
        nilai_buku DECIMAL(18,2),
        umur_ekonomis_tahun DECIMAL(5,2),
        umur_tersisa_tahun DECIMAL(5,2),
        
        -- Status Snapshot
        kondisi VARCHAR(50),
        status_pemanfaatan VARCHAR(50),
        
        -- Audit
        created_at DATETIME DEFAULT GETDATE()
    );

    -- Create Indexes
    CREATE INDEX ix_fact_aset_tgl ON fact.fact_aset(tanggal_snapshot_key);
    CREATE INDEX ix_fact_aset_barang ON fact.fact_aset(barang_key);
    CREATE INDEX ix_fact_aset_unit ON fact.fact_aset(unit_pemilik_key);
END
GO

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

PRINT '>> Fact tables and indexes created successfully in schema "fact".';
GO
