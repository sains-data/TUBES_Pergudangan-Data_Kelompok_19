-- =====================================================
-- 07_ETL_Procedures.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Stored Procedures for Loading Data (ETL)
-- Engine  : Microsoft SQL Server 2019+
-- =====================================================

/*
    ETL STRATEGY:
    1. Dimensions: Use MERGE for SCD Type 1 (Update/Insert).
    2. Facts: Use INSERT INTO ... SELECT with Lookups.
    3. Logging: Log execution to etl_log tables.
*/

-- =====================================================
-- 1. PROCEDURE: LOAD DIM WAKTU
-- =====================================================
IF OBJECT_ID('etl.usp_LoadDimWaktu', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadDimWaktu;
GO

CREATE PROCEDURE etl.usp_LoadDimWaktu
    @StartDate DATE = '2020-01-01',
    @EndDate DATE = '2026-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATE = @StartDate;

    -- Pastikan ada row default untuk error handling (19000101)
    IF NOT EXISTS (SELECT 1 FROM dim.dim_waktu WHERE tanggal_key = 19000101)
    BEGIN
        INSERT INTO dim.dim_waktu (
            tanggal_key, tanggal, hari, bulan, tahun, 
            quarter, minggu_tahun, hari_dalam_bulan, hari_kerja, bulan_tahun
        ) VALUES (
            19000101, '1900-01-01', 'Unknown', 1, 1900, 1, 1, 1, 0, 'Unknown'
        );
    END

    WHILE @CurrentDate <= @EndDate
    BEGIN
        DECLARE @DateKey INT = CAST(CONVERT(VARCHAR(8), @CurrentDate, 112) AS INT);
        IF NOT EXISTS (SELECT 1 FROM dim.dim_waktu WHERE tanggal_key = @DateKey)
        BEGIN
            INSERT INTO dim.dim_waktu (
                tanggal_key, tanggal, hari, bulan, tahun, 
                quarter, minggu_tahun, hari_dalam_bulan, hari_kerja, bulan_tahun
            )
            VALUES (
                @DateKey, @CurrentDate, DATENAME(WEEKDAY, @CurrentDate), MONTH(@CurrentDate),
                YEAR(@CurrentDate), DATEPART(QUARTER, @CurrentDate), DATEPART(WEEK, @CurrentDate),
                DAY(@CurrentDate),
                CASE WHEN DATENAME(WEEKDAY, @CurrentDate) IN ('Saturday', 'Sunday') THEN 0 ELSE 1 END,
                FORMAT(@CurrentDate, 'MMMM yyyy')
            );
        END
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

CREATE PROCEDURE etl.usp_LoadDimUnitKerja
AS
BEGIN
    SET NOCOUNT ON;
    MERGE dim.dim_unit_kerja AS Target
    USING stg.stg_unit_kerja AS Source
    ON (Target.kode_unit = Source.kode_unit)
    WHEN MATCHED THEN
        UPDATE SET Target.nama_unit = Source.nama_unit, Target.level = Source.level,
                   Target.kepala_unit_nip = Source.kepala_unit_nip, Target.email_unit = Source.email_unit
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (kode_unit, nama_unit, level, kepala_unit_nip, email_unit, is_active)
        VALUES (Source.kode_unit, Source.nama_unit, Source.level, Source.kepala_unit_nip, Source.email_unit, 1);
    PRINT 'Dim Unit Kerja loaded.';
END
GO

-- =====================================================
-- 3. PROCEDURE: LOAD FACT SURAT
-- =====================================================
IF OBJECT_ID('etl.usp_LoadFactSurat', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadFactSurat;
GO

CREATE PROCEDURE etl.usp_LoadFactSurat
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO fact.fact_surat (
        tanggal_key, unit_pengirim_key, unit_penerima_key, pegawai_penerima_key,
        jenis_surat_key, nomor_surat, status_akhir, created_at
    )
    SELECT 
        COALESCE(dw.tanggal_key, 19000101),
        COALESCE(du_sender.unit_key, -1),
        -1, -- Default receiver
        -1, -- Default pegawai
        COALESCE(djs.jenis_surat_key, -1),
        s.nomor_surat, s.status, GETDATE()
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

CREATE PROCEDURE etl.usp_LoadFactLayanan
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO fact.fact_layanan (
        tanggal_request_key, tanggal_selesai_key, unit_pemohon_key, unit_pelaksana_key,
        pegawai_pemohon_key, pegawai_penanggung_jawab_key, jenis_layanan_key,
        nomor_tiket, sla_target_jam, waktu_selesai_jam, rating_kepuasan, 
        melewati_sla_flag, status_akhir, created_at
    )
    SELECT 
        COALESCE(dw_req.tanggal_key, 19000101), -- Handle invalid date
        dw_end.tanggal_key, -- Bisa NULL
        -1, -- Unit Pemohon (Default Unknown)
        COALESCE((SELECT unit_key FROM dim.dim_unit_kerja WHERE kode_unit = 'BAU'), -1),  -- Unit Pelaksana (BAU)
        -1, -- Pegawai Pemohon
        -1, -- Pegawai PJ
        COALESCE(djs.jenis_layanan_key, -1),
        s.nomor_tiket,
        djs.sla_target_jam,
        DATEDIFF(HOUR, s.timestamp_submit, s.tanggal_selesai), -- Hitung durasi
        s.rating_kepuasan,
        CASE WHEN DATEDIFF(HOUR, s.timestamp_submit, s.tanggal_selesai) > djs.sla_target_jam THEN 1 ELSE 0 END,
        s.status_penyelesaian,
        GETDATE()
    FROM stg.stg_layanan s
    LEFT JOIN dim.dim_waktu dw_req ON CAST(s.timestamp_submit AS DATE) = dw_req.tanggal
    LEFT JOIN dim.dim_waktu dw_end ON CAST(s.tanggal_selesai AS DATE) = dw_end.tanggal
    LEFT JOIN dim.dim_jenis_layanan djs ON s.jenis_layanan_id = djs.jenis_layanan_key
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

CREATE PROCEDURE etl.usp_LoadFactAset
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Snapshot per hari ini
    DECLARE @SnapshotDateKey INT = CAST(CONVERT(VARCHAR(8), GETDATE(), 112) AS INT);

    INSERT INTO fact.fact_aset (
        tanggal_snapshot_key, barang_key, lokasi_key, unit_pemilik_key,
        jumlah_unit, nilai_perolehan, nilai_buku, kondisi, status_pemanfaatan, created_at
    )
    SELECT 
        @SnapshotDateKey,
        COALESCE(db.barang_key, -1),
        COALESCE(dl.lokasi_key, -1),
        COALESCE(du.unit_key, -1),
        1, -- Default jumlah 1 per baris
        s.nilai_perolehan,
        s.nilai_perolehan, -- Asumsi nilai buku = nilai perolehan dulu
        s.kondisi,
        'Aktif', -- Default status
        GETDATE()
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
-- 6. MASTER PROCEDURE (ORCHESTRATION)
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

        -- 1. Load Dimensions
        EXEC etl.usp_LoadDimWaktu;
        EXEC etl.usp_LoadDimUnitKerja;
        
        -- 2. Load Facts
        EXEC etl.usp_LoadFactSurat;
        EXEC etl.usp_LoadFactLayanan;
        EXEC etl.usp_LoadFactAset;

        -- 3. Log Success
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