-- =====================================================
-- 07_ETL_Procedures.sql
-- SQL SERVER VERSION (FIXED BATCH SEPARATORS)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : ETL Stored Procedures
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Creating ETL Procedures...';
GO  -- <== PENTING: GO harus ada di sini agar CREATE PROCEDURE menjadi awal batch berikutnya

-- =====================================================
-- 1. PROCEDURE: LOAD DIM WAKTU
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_LoadDimWaktu
    @p_start_date DATE = '2020-01-01',
    @p_end_date DATE = '2026-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentDate DATE = @p_start_date;
    DECLARE @DateKey INT;

    -- Insert default unknown date
    IF NOT EXISTS (SELECT 1 FROM dim.dim_waktu WHERE tanggal_key = 19000101)
    BEGIN
        INSERT INTO dim.dim_waktu (tanggal_key, tanggal, hari, bulan, tahun, quarter, minggu_tahun, hari_dalam_bulan, hari_kerja, bulan_tahun)
        VALUES (19000101, '1900-01-01', 'Unknown', 1, 1900, 1, 1, 1, 0, 'Unknown');
    END

    -- Loop through dates
    WHILE @CurrentDate <= @p_end_date
    BEGIN
        SET @DateKey = CAST(CONVERT(VARCHAR(8), @CurrentDate, 112) AS INT); -- Format YYYYMMDD

        -- Check if exists, if not insert
        IF NOT EXISTS (SELECT 1 FROM dim.dim_waktu WHERE tanggal_key = @DateKey)
        BEGIN
            INSERT INTO dim.dim_waktu (
                tanggal_key, 
                tanggal, 
                hari, 
                bulan, 
                tahun, 
                quarter, 
                minggu_tahun, 
                hari_dalam_bulan, 
                hari_kerja, 
                bulan_tahun
            )
            VALUES (
                @DateKey,
                @CurrentDate,
                DATENAME(WEEKDAY, @CurrentDate),
                DATEPART(MONTH, @CurrentDate),
                DATEPART(YEAR, @CurrentDate),
                DATEPART(QUARTER, @CurrentDate),
                DATEPART(WEEK, @CurrentDate),
                DATEPART(DAY, @CurrentDate),
                CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 0 ELSE 1 END,
                DATENAME(MONTH, @CurrentDate) + ' ' + CAST(DATEPART(YEAR, @CurrentDate) AS VARCHAR(4))
            );
        END

        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END

    PRINT '>> Dim Waktu loaded successfully.';
END;
GO

-- =====================================================
-- 2. PROCEDURE: LOAD DIM UNIT KERJA
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_LoadDimUnitKerja
AS
BEGIN
    SET NOCOUNT ON;

    -- MERGE Statement (Upsert: Insert if new, Update if exists)
    MERGE dim.dim_unit_kerja AS Target
    USING (SELECT * FROM stg.stg_unit_kerja WHERE is_processed = 0) AS Source
    ON (Target.kode_unit = Source.kode_unit)
    
    WHEN MATCHED THEN
        UPDATE SET 
            nama_unit = Source.nama_unit,
            level = Source.level,
            kepala_unit_nip = Source.kepala_unit_nip,
            email_unit = Source.email_unit
    
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (kode_unit, nama_unit, level, kepala_unit_nip, email_unit, is_active)
        VALUES (Source.kode_unit, Source.nama_unit, Source.level, Source.kepala_unit_nip, Source.email_unit, 1);

    PRINT '>> Dim Unit Kerja loaded successfully.';
END;
GO

-- =====================================================
-- 3. PROCEDURE: LOAD FACT SURAT
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_LoadFactSurat
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO fact.fact_surat (
        tanggal_key, 
        unit_pengirim_key, 
        unit_penerima_key, 
        pegawai_penerima_key, 
        jenis_surat_key, 
        nomor_surat, 
        status_akhir, 
        created_at
    )
    SELECT 
        ISNULL(dw.tanggal_key, 19000101),
        ISNULL(du.unit_key, -1),
        -1, -- Placeholder for recipient unit
        -1, -- Placeholder for recipient employee
        ISNULL(djs.jenis_surat_key, -1),
        s.nomor_surat,
        s.status,
        GETDATE()
    FROM stg.stg_simaster_surat s
    LEFT JOIN dim.dim_waktu dw ON s.tanggal_diterima = dw.tanggal
    LEFT JOIN dim.dim_unit_kerja du ON s.pengirim = du.nama_unit 
    LEFT JOIN dim.dim_jenis_surat djs ON s.jenis_surat_id = djs.jenis_surat_key 
    WHERE s.is_processed = 0;
    
    -- Mark as processed
    UPDATE stg.stg_simaster_surat SET is_processed = 1 WHERE is_processed = 0;
    
    PRINT '>> Fact Surat loaded successfully.';
END;
GO

-- =====================================================
-- 4. PROCEDURE: LOAD FACT LAYANAN
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_LoadFactLayanan
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO fact.fact_layanan (
        tanggal_request_key, 
        tanggal_selesai_key, 
        unit_pemohon_key, 
        unit_pelaksana_key, 
        pegawai_pemohon_key, 
        pegawai_penanggung_jawab_key, 
        jenis_layanan_key, 
        nomor_tiket, 
        sla_target_jam, 
        waktu_selesai_jam, 
        rating_kepuasan, 
        melewati_sla_flag, 
        status_akhir, 
        created_at
    )
    SELECT 
        ISNULL(dw_req.tanggal_key, 19000101),
        ISNULL(dw_end.tanggal_key, 19000101), -- Added ISNULL/COALESCE protection
        -1,
        -1,
        -1,
        -1,
        ISNULL(djl.jenis_layanan_key, -1),
        s.nomor_tiket,
        djl.sla_target_jam,
        -- Calculate Duration in Hours
        CAST(DATEDIFF(SECOND, s.timestamp_submit, s.tanggal_selesai) AS DECIMAL(10,2)) / 3600.0,
        s.rating_kepuasan,
        -- SLA Flag Logic
        CASE 
            WHEN (CAST(DATEDIFF(SECOND, s.timestamp_submit, s.tanggal_selesai) AS DECIMAL(10,2)) / 3600.0) > djl.sla_target_jam THEN 1 
            ELSE 0 
        END,
        s.status_penyelesaian,
        GETDATE()
    FROM stg.stg_layanan s
    LEFT JOIN dim.dim_waktu dw_req ON CAST(s.timestamp_submit AS DATE) = dw_req.tanggal
    LEFT JOIN dim.dim_waktu dw_end ON CAST(s.tanggal_selesai AS DATE) = dw_end.tanggal
    LEFT JOIN dim.dim_jenis_layanan djl ON s.jenis_layanan_id = djl.jenis_layanan_key
    WHERE s.is_processed = 0;
    
    -- Mark as processed
    UPDATE stg.stg_layanan SET is_processed = 1 WHERE is_processed = 0;
    
    PRINT '>> Fact Layanan loaded successfully.';
END;
GO

-- =====================================================
-- 5. PROCEDURE: LOAD FACT ASET
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_LoadFactAset
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SnapshotDateKey INT = CAST(CONVERT(VARCHAR(8), GETDATE(), 112) AS INT);

    INSERT INTO fact.fact_aset (
        tanggal_snapshot_key, 
        barang_key, 
        lokasi_key, 
        unit_pemilik_key, 
        jumlah_unit, 
        nilai_perolehan, 
        nilai_buku, 
        kondisi, 
        status_pemanfaatan, 
        created_at
    )
    SELECT 
        @SnapshotDateKey,
        ISNULL(db.barang_key, -1),
        ISNULL(dl.lokasi_key, -1),
        ISNULL(du.unit_key, -1),
        1, 
        s.nilai_perolehan,
        s.nilai_perolehan, 
        s.kondisi,
        'Aktif',
        GETDATE()
    FROM stg.stg_inventaris s
    LEFT JOIN dim.dim_barang db ON s.kode_barang = db.kode_barang
    LEFT JOIN dim.dim_lokasi dl ON s.lokasi_id = dl.lokasi_key 
    LEFT JOIN dim.dim_unit_kerja du ON s.unit_kerja_id = du.unit_key
    WHERE s.is_processed = 0;
    
    -- Mark as processed
    UPDATE stg.stg_inventaris SET is_processed = 1 WHERE is_processed = 0;
    
    PRINT '>> Fact Aset loaded successfully.';
END;
GO

-- =====================================================
-- 6. MASTER PROCEDURE (ORCHESTRATOR)
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_MasterETL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ExecID INT;

    BEGIN TRY
        -- Log execution start
        INSERT INTO etl_log.job_execution (job_name, status, start_time) 
        VALUES ('Master_ETL', 'Running', GETDATE());
        
        -- Get generated ID
        SET @ExecID = SCOPE_IDENTITY();
        
        -- Execute ETL procedures
        EXEC etl.usp_LoadDimWaktu;
        EXEC etl.usp_LoadDimUnitKerja;
        EXEC etl.usp_LoadFactSurat;
        EXEC etl.usp_LoadFactLayanan;
        EXEC etl.usp_LoadFactAset;
        
        -- Log success
        UPDATE etl_log.job_execution 
        SET status = 'Success', end_time = GETDATE()
        WHERE execution_id = @ExecID;
        
        PRINT '>> Master ETL completed successfully.';
    END TRY
    BEGIN CATCH
        -- Log failure
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        
        UPDATE etl_log.job_execution 
        SET status = 'Failed', end_time = GETDATE(), error_message = @ErrorMessage
        WHERE execution_id = @ExecID;
        
        -- Record detailed error
        INSERT INTO etl_log.error_details (execution_id, error_message, error_type, severity)
        VALUES (@ExecID, @ErrorMessage, 'ETL_FAILURE', 'High');
        
        PRINT '>> Error in Master ETL: ' + @ErrorMessage;
    END CATCH
END;
GO

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

PRINT '>> 07_ETL_Procedures.sql executed successfully.';
GO
