-- =====================================================
-- 07_ETL_Procedures.sql (SMART VERSION)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : ETL Procedures with Auto-Ingestion
-- Engine  : Microsoft SQL Server 2019+
-- =====================================================

/*
    SMART ETL STRATEGY:
    1. Ingestion: Check if 'upload_*' tables exist. If yes, move to 'stg_*' & drop upload tables.
    2. Dimensions: MERGE (SCD Type 1).
    3. Facts: INSERT INTO ... SELECT with Lookups.
*/

-- =====================================================
-- 0. PROCEDURE: INGEST UPLOAD TABLES (BARU!)
-- =====================================================
IF OBJECT_ID('etl.usp_IngestUploadTables', 'P') IS NOT NULL DROP PROCEDURE etl.usp_IngestUploadTables;
GO

CREATE PROCEDURE etl.usp_IngestUploadTables
AS
BEGIN
    SET NOCOUNT ON;
    PRINT '>> Auto-Detecting Import Tables (Zero-Config)...';

    -- 1. UNIT KERJA (Mendeteksi tabel dbo.stg_unit_kerja)
    IF OBJECT_ID('dbo.stg_unit_kerja', 'U') IS NOT NULL
    BEGIN
        PRINT '   Found dbo.stg_unit_kerja. Ingesting...';
        TRUNCATE TABLE stg.stg_unit_kerja;
        INSERT INTO stg.stg_unit_kerja (id_unit, kode_unit, nama_unit, level, parent_unit_id, kepala_unit_nip, email_unit)
        SELECT TRY_CAST(id_unit AS VARCHAR(50)), LEFT(kode_unit, 20), LEFT(nama_unit, 100), TRY_CAST(level AS INT), TRY_CAST(parent_unit_id AS INT), LEFT(kepala_unit_nip, 20), LEFT(email_unit, 100)
        FROM dbo.stg_unit_kerja;
        DROP TABLE dbo.stg_unit_kerja; -- Hapus setelah selesai
    END

    -- 2. PEGAWAI
    IF OBJECT_ID('dbo.stg_simpeg', 'U') IS NOT NULL
    BEGIN
        PRINT '   Found dbo.stg_simpeg. Ingesting...';
        TRUNCATE TABLE stg.stg_simpeg;
        INSERT INTO stg.stg_simpeg (nip, nama, jabatan, unit_kerja_id, tanggal_masuk, status_kepegawaian, email, no_hp)
        SELECT LEFT(nip, 20), LEFT(nama, 100), LEFT(jabatan, 100), TRY_CAST(unit_kerja_id AS INT), TRY_CAST(NULLIF(tanggal_masuk, '') AS DATE), LEFT(status_kepegawaian, 50), LEFT(email, 100), LEFT(no_hp, 20)
        FROM dbo.stg_simpeg;
        DROP TABLE dbo.stg_simpeg;
    END

    -- 3. SURAT
    IF OBJECT_ID('dbo.stg_simaster_surat', 'U') IS NOT NULL
    BEGIN
        PRINT '   Found dbo.stg_simaster_surat. Ingesting...';
        TRUNCATE TABLE stg.stg_simaster_surat;
        INSERT INTO stg.stg_simaster_surat (id_surat, nomor_surat, tanggal_diterima, pengirim, perihal, jenis_surat_id, status, raw_data)
        SELECT id_surat, nomor_surat, TRY_CAST(NULLIF(tanggal_diterima, '') AS DATE), pengirim, perihal, TRY_CAST(jenis_surat_id AS INT), status, raw_data
        FROM dbo.stg_simaster_surat;
        DROP TABLE dbo.stg_simaster_surat;
    END

    -- 4. LAYANAN
    IF OBJECT_ID('dbo.stg_layanan', 'U') IS NOT NULL
    BEGIN
        PRINT '   Found dbo.stg_layanan. Ingesting...';
        TRUNCATE TABLE stg.stg_layanan;
        INSERT INTO stg.stg_layanan (id_permintaan, nomor_tiket, pemohon_nama, jenis_layanan_id, timestamp_submit, tanggal_selesai, status_penyelesaian, rating_kepuasan)
        SELECT id_permintaan, nomor_tiket, pemohon_nama, TRY_CAST(jenis_layanan_id AS INT), TRY_CAST(NULLIF(timestamp_submit, '') AS DATETIME), TRY_CAST(NULLIF(tanggal_selesai, '') AS DATETIME), status_penyelesaian, TRY_CAST(NULLIF(rating_kepuasan, '') AS DECIMAL(3,2))
        FROM dbo.stg_layanan;
        DROP TABLE dbo.stg_layanan;
    END

    -- 5. INVENTARIS
    IF OBJECT_ID('dbo.stg_inventaris', 'U') IS NOT NULL
    BEGIN
        PRINT '   Found dbo.stg_inventaris. Ingesting...';
        TRUNCATE TABLE stg.stg_inventaris;
        INSERT INTO stg.stg_inventaris (id_barang, kode_barang, nama_barang, kategori, tanggal_pengadaan, nilai_perolehan, kondisi, lokasi_id, unit_kerja_id)
        SELECT id_barang, kode_barang, nama_barang, kategori, TRY_CAST(NULLIF(tanggal_pengadaan, '') AS DATE), TRY_CAST(NULLIF(nilai_perolehan, '') AS DECIMAL(15,2)), kondisi, TRY_CAST(lokasi_id AS INT), TRY_CAST(unit_kerja_id AS INT)
        FROM dbo.stg_inventaris;
        DROP TABLE dbo.stg_inventaris;
    END
END
GO

-- =====================================================
-- 1. PROCEDURE: LOAD DIM WAKTU
-- =====================================================
IF OBJECT_ID('etl.usp_LoadDimWaktu', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadDimWaktu;
GO
CREATE PROCEDURE etl.usp_LoadDimWaktu @StartDate DATE = '2020-01-01', @EndDate DATE = '2026-12-31' AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATE = @StartDate;
    IF NOT EXISTS (SELECT 1 FROM dim.dim_waktu WHERE tanggal_key = 19000101)
        INSERT INTO dim.dim_waktu VALUES (19000101, '1900-01-01', 'Unknown', 1, 1900, 1, 1, 1, 0, 'Unknown');

    WHILE @CurrentDate <= @EndDate
    BEGIN
        DECLARE @DateKey INT = CAST(CONVERT(VARCHAR(8), @CurrentDate, 112) AS INT);
        IF NOT EXISTS (SELECT 1 FROM dim.dim_waktu WHERE tanggal_key = @DateKey)
            INSERT INTO dim.dim_waktu VALUES (@DateKey, @CurrentDate, DATENAME(WEEKDAY, @CurrentDate), MONTH(@CurrentDate), YEAR(@CurrentDate), DATEPART(QUARTER, @CurrentDate), DATEPART(WEEK, @CurrentDate), DAY(@CurrentDate), CASE WHEN DATENAME(WEEKDAY, @CurrentDate) IN ('Saturday', 'Sunday') THEN 0 ELSE 1 END, FORMAT(@CurrentDate, 'MMMM yyyy'));
        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END
    PRINT 'Dim Waktu loaded.';
END
GO

-- =====================================================
-- 2. PROCEDURE: LOAD DIM UNIT KERJA
-- =====================================================
IF OBJECT_ID('etl.usp_LoadDimUnitKerja', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadDimUnitKerja;
GO
CREATE PROCEDURE etl.usp_LoadDimUnitKerja AS
BEGIN
    SET NOCOUNT ON;
    MERGE dim.dim_unit_kerja AS Target USING stg.stg_unit_kerja AS Source ON (Target.kode_unit = Source.kode_unit)
    WHEN MATCHED THEN UPDATE SET Target.nama_unit = Source.nama_unit, Target.level = Source.level, Target.kepala_unit_nip = Source.kepala_unit_nip, Target.email_unit = Source.email_unit
    WHEN NOT MATCHED BY TARGET THEN INSERT (kode_unit, nama_unit, level, kepala_unit_nip, email_unit, is_active) VALUES (Source.kode_unit, Source.nama_unit, Source.level, Source.kepala_unit_nip, Source.email_unit, 1);
    PRINT 'Dim Unit Kerja loaded.';
END
GO

-- =====================================================
-- 3. PROCEDURE: LOAD FACT SURAT
-- =====================================================
IF OBJECT_ID('etl.usp_LoadFactSurat', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadFactSurat;
GO
CREATE PROCEDURE etl.usp_LoadFactSurat AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO fact.fact_surat (tanggal_key, unit_pengirim_key, unit_penerima_key, pegawai_penerima_key, jenis_surat_key, nomor_surat, status_akhir, created_at)
    SELECT COALESCE(dw.tanggal_key, 19000101), COALESCE(du_sender.unit_key, -1), -1, -1, COALESCE(djs.jenis_surat_key, -1), s.nomor_surat, s.status, GETDATE()
    FROM stg.stg_simaster_surat s
    LEFT JOIN dim.dim_waktu dw ON s.tanggal_diterima = dw.tanggal
    LEFT JOIN dim.dim_unit_kerja du_sender ON s.pengirim = du_sender.nama_unit
    LEFT JOIN dim.dim_jenis_surat djs ON s.jenis_surat_id = djs.jenis_surat_key
    WHERE s.is_processed = 0;
    UPDATE stg.stg_simaster_surat SET is_processed = 1 WHERE is_processed = 0;
    PRINT 'Fact Surat loaded.';
END
GO

-- =====================================================
-- 4. PROCEDURE: LOAD FACT LAYANAN
-- =====================================================
IF OBJECT_ID('etl.usp_LoadFactLayanan', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadFactLayanan;
GO
CREATE PROCEDURE etl.usp_LoadFactLayanan AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO fact.fact_layanan (tanggal_request_key, tanggal_selesai_key, unit_pemohon_key, unit_pelaksana_key, pegawai_pemohon_key, pegawai_penanggung_jawab_key, jenis_layanan_key, nomor_tiket, sla_target_jam, waktu_selesai_jam, rating_kepuasan, melewati_sla_flag, status_akhir, created_at)
    SELECT COALESCE(dw_req.tanggal_key, 19000101), dw_end.tanggal_key, -1, 2, -1, -1, COALESCE(djl.jenis_layanan_key, -1), s.nomor_tiket, djl.sla_target_jam, DATEDIFF(HOUR, s.timestamp_submit, s.tanggal_selesai), s.rating_kepuasan, CASE WHEN DATEDIFF(HOUR, s.timestamp_submit, s.tanggal_selesai) > djl.sla_target_jam THEN 1 ELSE 0 END, s.status_penyelesaian, GETDATE()
    FROM stg.stg_layanan s
    LEFT JOIN dim.dim_waktu dw_req ON CAST(s.timestamp_submit AS DATE) = dw_req.tanggal
    LEFT JOIN dim.dim_waktu dw_end ON CAST(s.tanggal_selesai AS DATE) = dw_end.tanggal
    LEFT JOIN dim.dim_jenis_layanan djl ON s.jenis_layanan_id = djl.jenis_layanan_key
    WHERE s.is_processed = 0;
    UPDATE stg.stg_layanan SET is_processed = 1 WHERE is_processed = 0;
    PRINT 'Fact Layanan loaded.';
END
GO

-- =====================================================
-- 5. PROCEDURE: LOAD FACT ASET
-- =====================================================
IF OBJECT_ID('etl.usp_LoadFactAset', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadFactAset;
GO
CREATE PROCEDURE etl.usp_LoadFactAset AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SnapshotDateKey INT = CAST(CONVERT(VARCHAR(8), GETDATE(), 112) AS INT);
    INSERT INTO fact.fact_aset (tanggal_snapshot_key, barang_key, lokasi_key, unit_pemilik_key, jumlah_unit, nilai_perolehan, nilai_buku, kondisi, status_pemanfaatan, created_at)
    SELECT @SnapshotDateKey, COALESCE(db.barang_key, -1), COALESCE(dl.lokasi_key, -1), COALESCE(du.unit_key, -1), 1, s.nilai_perolehan, s.nilai_perolehan, s.kondisi, 'Aktif', GETDATE()
    FROM stg.stg_inventaris s
    LEFT JOIN dim.dim_barang db ON s.kode_barang = db.kode_barang
    LEFT JOIN dim.dim_lokasi dl ON s.lokasi_id = dl.lokasi_key
    LEFT JOIN dim.dim_unit_kerja du ON s.unit_kerja_id = du.unit_key
    WHERE s.is_processed = 0;
    UPDATE stg.stg_inventaris SET is_processed = 1 WHERE is_processed = 0;
    PRINT 'Fact Aset loaded.';
END
GO

-- =====================================================
-- 6. MASTER PROCEDURE (UPDATED FOR SMART INGESTION)
-- =====================================================
IF OBJECT_ID('etl.usp_MasterETL', 'P') IS NOT NULL DROP PROCEDURE etl.usp_MasterETL;
GO

CREATE PROCEDURE etl.usp_MasterETL
AS
BEGIN
    BEGIN TRY
        DECLARE @StartTime DATETIME = GETDATE();
        INSERT INTO etl_log.job_execution (job_name, status) VALUES ('Master_ETL', 'Running');
        DECLARE @ExecID INT = SCOPE_IDENTITY();

        -- [BARU] Step 0: Cek & Ingest Upload Tables (Otomatis!)
        EXEC etl.usp_IngestUploadTables;

        -- Step 1: Load Dimensions
        EXEC etl.usp_LoadDimWaktu;
        EXEC etl.usp_LoadDimUnitKerja;
        
        -- Step 2: Load Facts
        EXEC etl.usp_LoadFactSurat;
        EXEC etl.usp_LoadFactLayanan;
        EXEC etl.usp_LoadFactAset;

        -- Step 3: Log Success
        UPDATE etl_log.job_execution 
        SET status = 'Success', end_time = GETDATE() 
        WHERE execution_id = @ExecID;
        
        PRINT 'Master ETL completed successfully.';
    END TRY
    BEGIN CATCH
        IF @ExecID IS NOT NULL
            UPDATE etl_log.job_execution 
            SET status = 'Failed', end_time = GETDATE(), error_message = ERROR_MESSAGE()
            WHERE execution_id = @ExecID;
        PRINT 'Error in Master ETL: ' + ERROR_MESSAGE();
    END CATCH
END
GO