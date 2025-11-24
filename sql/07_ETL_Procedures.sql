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
-- PROCEDURE: LOAD DIM WAKTU (Generate Date Data)
-- =====================================================
IF OBJECT_ID('etl.usp_LoadDimWaktu', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadDimWaktu;
GO

CREATE PROCEDURE etl.usp_LoadDimWaktu
    @StartDate DATE = '2020-01-01',
    @EndDate DATE = '2025-12-31'
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Clear existing if needed (or keep for incremental)
    -- TRUNCATE TABLE dim.dim_waktu; 

    DECLARE @CurrentDate DATE = @StartDate;

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
                @DateKey,
                @CurrentDate,
                DATENAME(WEEKDAY, @CurrentDate),
                MONTH(@CurrentDate),
                YEAR(@CurrentDate),
                DATEPART(QUARTER, @CurrentDate),
                DATEPART(WEEK, @CurrentDate),
                DAY(@CurrentDate),
                CASE WHEN DATENAME(WEEKDAY, @CurrentDate) IN ('Saturday', 'Sunday') THEN 0 ELSE 1 END,
                FORMAT(@CurrentDate, 'MMMM yyyy')
            );
        END

        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END
    
    PRINT 'Dim Waktu loaded successfully.';
END
GO

-- =====================================================
-- PROCEDURE: LOAD DIM UNIT KERJA
-- =====================================================
IF OBJECT_ID('etl.usp_LoadDimUnitKerja', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadDimUnitKerja;
GO

CREATE PROCEDURE etl.usp_LoadDimUnitKerja
AS
BEGIN
    SET NOCOUNT ON;
    
    -- MERGE Statement for SCD Type 1 (Overwrite changes)
    MERGE dim.dim_unit_kerja AS Target
    USING stg.stg_unit_kerja AS Source
    ON (Target.kode_unit = Source.kode_unit)
    
    WHEN MATCHED THEN
        UPDATE SET 
            Target.nama_unit = Source.nama_unit,
            Target.level = Source.level,
            Target.kepala_unit_nip = Source.kepala_unit_nip,
            Target.email_unit = Source.email_unit
            
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (kode_unit, nama_unit, level, kepala_unit_nip, email_unit, is_active)
        VALUES (Source.kode_unit, Source.nama_unit, Source.level, Source.kepala_unit_nip, Source.email_unit, 1);

    PRINT 'Dim Unit Kerja loaded successfully.';
END
GO

-- =====================================================
-- PROCEDURE: LOAD FACT SURAT
-- =====================================================
IF OBJECT_ID('etl.usp_LoadFactSurat', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LoadFactSurat;
GO

CREATE PROCEDURE etl.usp_LoadFactSurat
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @RowsInserted INT;

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
        dw.tanggal_key,
        COALESCE(du_sender.unit_key, -1),   -- Handle unknown unit
        COALESCE(du_receiver.unit_key, -1), 
        -1, -- Placeholder for pegawai logic (requires complex mapping)
        COALESCE(djs.jenis_surat_key, -1),
        s.nomor_surat,
        s.status,
        GETDATE()
    FROM stg.stg_simaster_surat s
    LEFT JOIN dim.dim_waktu dw ON s.tanggal_diterima = dw.tanggal
    LEFT JOIN dim.dim_unit_kerja du_sender ON s.pengirim = du_sender.nama_unit -- Assuming mapping by name
    -- Note: Logic penerima/pegawai disederhanakan untuk Misi 2
    LEFT JOIN dim.dim_unit_kerja du_receiver ON du_receiver.kode_unit = 'BAU' -- Default BAU as receiver
    LEFT JOIN dim.dim_jenis_surat djs ON s.jenis_surat_id = djs.jenis_surat_key
    WHERE s.is_processed = 0;

    SET @RowsInserted = @@ROWCOUNT;
    
    -- Mark staging as processed
    UPDATE stg.stg_simaster_surat SET is_processed = 1 WHERE is_processed = 0;

    PRINT 'Fact Surat loaded: ' + CAST(@RowsInserted AS VARCHAR) + ' rows.';
END
GO

-- =====================================================
-- MASTER PROCEDURE (ORCHESTRATION)
-- =====================================================
IF OBJECT_ID('etl.usp_MasterETL', 'P') IS NOT NULL DROP PROCEDURE etl.usp_MasterETL;
GO

CREATE PROCEDURE etl.usp_MasterETL
AS
BEGIN
    BEGIN TRY
        DECLARE @StartTime DATETIME = GETDATE();
        
        -- 1. Log Start
        INSERT INTO etl_log.job_execution (job_name, status) VALUES ('Master_ETL', 'Running');
        DECLARE @ExecID INT = SCOPE_IDENTITY();

        -- 2. Load Dimensions
        EXEC etl.usp_LoadDimWaktu;
        EXEC etl.usp_LoadDimUnitKerja;
        -- Add other dimension procs here (Pegawai, Barang, etc.)

        -- 3. Load Facts
        EXEC etl.usp_LoadFactSurat;
        -- Add other fact procs here (Layanan, Aset)

        -- 4. Log Success
        UPDATE etl_log.job_execution 
        SET status = 'Success', end_time = GETDATE() 
        WHERE execution_id = @ExecID;
        
        PRINT 'Master ETL completed successfully.';
    END TRY
    BEGIN CATCH
        -- Log Error
        IF @ExecID IS NOT NULL
            UPDATE etl_log.job_execution 
            SET status = 'Failed', end_time = GETDATE(), error_message = ERROR_MESSAGE()
            WHERE execution_id = @ExecID;
            
        PRINT 'Error in Master ETL: ' + ERROR_MESSAGE();
    END CATCH
END
GO
