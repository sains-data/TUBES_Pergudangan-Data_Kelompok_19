-- =====================================================
-- 03_Create_Facts.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Fact Tables in 'fact' schema
-- Engine  : PostgreSQL
-- Dependencies: 02_Create_Dimensions.sql must be executed first
-- =====================================================

-- 1. FACT SURAT (Transactional)
-- Grain: 1 baris per surat
CREATE TABLE IF NOT EXISTS fact.fact_surat (
    surat_key               BIGSERIAL PRIMARY KEY,
    tanggal_key             INT NOT NULL,          -- FK Dim Waktu
    unit_pengirim_key       INT,                   -- FK Dim Unit
    unit_penerima_key       INT,                   -- FK Dim Unit
    pegawai_penerima_key    INT,                   -- FK Dim Pegawai
    jenis_surat_key         INT,                   -- FK Dim Jenis Surat
    
    -- Degenerate Dimension
    nomor_surat             VARCHAR(100),
    
    -- Measures
    jumlah_lampiran         INT DEFAULT 0,
    durasi_proses_hari      INT,
    
    -- Status & Flags
    melewati_sla_flag       BOOLEAN,
    status_akhir            VARCHAR(50),
    channel                 VARCHAR(20),           -- Fisik/Digital
    
    -- Audit
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Foreign Keys Fact Surat
ALTER TABLE fact.fact_surat ADD CONSTRAINT fk_surat_waktu 
    FOREIGN KEY (tanggal_key) REFERENCES dim.dim_waktu(tanggal_key);
ALTER TABLE fact.fact_surat ADD CONSTRAINT fk_surat_jenis 
    FOREIGN KEY (jenis_surat_key) REFERENCES dim.dim_jenis_surat(jenis_surat_key);
ALTER TABLE fact.fact_surat ADD CONSTRAINT fk_surat_pengirim 
    FOREIGN KEY (unit_pengirim_key) REFERENCES dim.dim_unit_kerja(unit_key);
-- Catatan: unit_penerima & pegawai_penerima bisa NULL (misal surat keluar eksternal)
ALTER TABLE fact.fact_surat ADD CONSTRAINT fk_surat_penerima
    FOREIGN KEY (unit_penerima_key) REFERENCES dim.dim_unit_kerja(unit_key);
ALTER TABLE fact.fact_surat ADD CONSTRAINT fk_surat_pegawai
    FOREIGN KEY (pegawai_penerima_key) REFERENCES dim.dim_pegawai(pegawai_key);


-- 2. FACT LAYANAN (Transactional)
-- Grain: 1 baris per tiket permintaan layanan
CREATE TABLE IF NOT EXISTS fact.fact_layanan (
    layanan_key                 BIGSERIAL PRIMARY KEY,
    tanggal_request_key         INT NOT NULL,      -- FK Dim Waktu
    tanggal_selesai_key         INT,               -- FK Dim Waktu (nullable)
    unit_pemohon_key            INT,               -- FK Dim Unit
    unit_pelaksana_key          INT,               -- FK Dim Unit
    pegawai_pemohon_key         INT,               -- FK Dim Pegawai
    pegawai_penanggung_jawab_key INT,              -- FK Dim Pegawai
    jenis_layanan_key           INT,               -- FK Dim Jenis Layanan
    
    -- Degenerate Dimension
    nomor_tiket                 VARCHAR(50),
    
    -- Measures
    sla_target_jam              INT,
    waktu_respon_jam            DECIMAL(10,2),
    waktu_selesai_jam           DECIMAL(10,2),
    rating_kepuasan             DECIMAL(3,2),      -- Skala 1.00 - 5.00
    biaya_layanan               NUMERIC(18,2),
    
    -- Flags
    melewati_sla_flag           BOOLEAN,
    status_akhir                VARCHAR(50),
    
    -- Audit
    created_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Foreign Keys Fact Layanan
ALTER TABLE fact.fact_layanan ADD CONSTRAINT fk_layanan_waktu_req 
    FOREIGN KEY (tanggal_request_key) REFERENCES dim.dim_waktu(tanggal_key);
ALTER TABLE fact.fact_layanan ADD CONSTRAINT fk_layanan_jenis 
    FOREIGN KEY (jenis_layanan_key) REFERENCES dim.dim_jenis_layanan(jenis_layanan_key);
ALTER TABLE fact.fact_layanan ADD CONSTRAINT fk_layanan_unit_req
    FOREIGN KEY (unit_pemohon_key) REFERENCES dim.dim_unit_kerja(unit_key);


-- 3. FACT ASET (Periodic Snapshot)
-- Grain: 1 baris per aset per periode snapshot (misal: Akhir Bulan)
CREATE TABLE IF NOT EXISTS fact.fact_aset (
    aset_snapshot_key       BIGSERIAL PRIMARY KEY,
    tanggal_snapshot_key    INT NOT NULL,          -- FK Dim Waktu (End of Month)
    barang_key              INT NOT NULL,          -- FK Dim Barang
    lokasi_key              INT,                   -- FK Dim Lokasi
    unit_pemilik_key        INT,                   -- FK Dim Unit Kerja
    
    -- Measures
    jumlah_unit             INT DEFAULT 1,
    nilai_perolehan         NUMERIC(18,2),
    nilai_buku              NUMERIC(18,2),         -- Nilai setelah penyusutan
    umur_ekonomis_tahun     DECIMAL(5,2),
    umur_tersisa_tahun      DECIMAL(5,2),
    
    -- Status Snapshot
    kondisi                 VARCHAR(50),           -- Baik, Rusak Ringan, dll
    status_pemanfaatan      VARCHAR(50),           -- Aktif, Dipinjam, dll
    
    -- Audit
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Foreign Keys Fact Aset
ALTER TABLE fact.fact_aset ADD CONSTRAINT fk_aset_waktu 
    FOREIGN KEY (tanggal_snapshot_key) REFERENCES dim.dim_waktu(tanggal_key);
ALTER TABLE fact.fact_aset ADD CONSTRAINT fk_aset_barang 
    FOREIGN KEY (barang_key) REFERENCES dim.dim_barang(barang_key);
ALTER TABLE fact.fact_aset ADD CONSTRAINT fk_aset_lokasi 
    FOREIGN KEY (lokasi_key) REFERENCES dim.dim_lokasi(lokasi_key);
ALTER TABLE fact.fact_aset ADD CONSTRAINT fk_aset_unit 
    FOREIGN KEY (unit_pemilik_key) REFERENCES dim.dim_unit_kerja(unit_key);


-- =====================================================
-- INDEXING (Performance Optimization)
-- =====================================================
-- Fact Surat Indexes
CREATE INDEX ix_fact_surat_tgl ON fact.fact_surat(tanggal_key);
CREATE INDEX ix_fact_surat_jenis ON fact.fact_surat(jenis_surat_key);
CREATE INDEX ix_fact_surat_unit ON fact.fact_surat(unit_pengirim_key);

-- Fact Layanan Indexes
CREATE INDEX ix_fact_layanan_tgl ON fact.fact_layanan(tanggal_request_key);
CREATE INDEX ix_fact_layanan_jenis ON fact.fact_layanan(jenis_layanan_key);

-- Fact Aset Indexes
CREATE INDEX ix_fact_aset_tgl ON fact.fact_aset(tanggal_snapshot_key);
CREATE INDEX ix_fact_aset_barang ON fact.fact_aset(barang_key);
CREATE INDEX ix_fact_aset_unit ON fact.fact_aset(unit_pemilik_key);

-- =====================================================
-- NOTICE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE 'Fact tables and indexes created successfully in schema "fact".';
END $$;
