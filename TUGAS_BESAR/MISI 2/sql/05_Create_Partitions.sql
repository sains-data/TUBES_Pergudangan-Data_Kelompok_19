-- =====================================================
-- 05_Create_Partitions.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Implement Table Partitioning Strategy
-- Engine  : Microsoft SQL Server 2019+
-- Dependencies: 03_Create_Facts.sql must be executed first
-- =====================================================

/*
    PARTITIONING STRATEGY:
    - Column: tanggal_key (INT format YYYYMMDD)
    - Type: Range Right (Yearly Partitions)
    - Range: 2020 - 2026
    - Target: Fact_Surat, Fact_Layanan (Large transactional tables)
    
    Benefits:
    - Improved query performance for time-series analysis
    - Easier data management (sliding window scenarios)
*/

USE [datamart_bau_itera]; -- Sesuaikan nama DB jika berbeda
GO

-- =====================================================
-- 1. CREATE PARTITION FUNCTION
-- =====================================================
-- Define boundaries for yearly partitions
IF NOT EXISTS (SELECT * FROM sys.partition_functions WHERE name = 'pf_YearlyRange')
BEGIN
    CREATE PARTITION FUNCTION pf_YearlyRange (INT)
    AS RANGE RIGHT FOR VALUES 
    (
        20210101, -- Data < 2021
        20220101, -- 2021 data
        20230101, -- 2022 data
        20240101, -- 2023 data
        20250101, -- 2024 data
        20260101  -- 2025 data
    );
    PRINT 'Partition Function pf_YearlyRange created.';
END
GO

-- =====================================================
-- 2. CREATE PARTITION SCHEME
-- =====================================================
-- Map all partitions to PRIMARY filegroup for simplicity
-- (In production, you might map to different filegroups for I/O isolation)
IF NOT EXISTS (SELECT * FROM sys.partition_schemes WHERE name = 'ps_YearlyRange')
BEGIN
    CREATE PARTITION SCHEME ps_YearlyRange
    AS PARTITION pf_YearlyRange
    ALL TO ([PRIMARY]);
    PRINT 'Partition Scheme ps_YearlyRange created.';
END
GO

-- =====================================================
-- 3. APPLY PARTITIONING TO FACT_SURAT
-- =====================================================
-- Note: To partition an existing table, we must drop the clustered index (PK)
-- and recreate it on the partition scheme. The partition key MUST be part of the PK.

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'PK__fact_sur' AND object_id = OBJECT_ID('fact.fact_surat'))
   OR EXISTS (SELECT * FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('fact.fact_surat'))
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Get current PK Name (Dynamic because System Named)
        DECLARE @pk_name_surat NVARCHAR(128);
        SELECT TOP 1 @pk_name_surat = name 
        FROM sys.key_constraints 
        WHERE parent_object_id = OBJECT_ID('fact.fact_surat') AND type = 'PK';

        -- 2. Drop FKs referencing this PK (None in Star Schema usually, but good practice)
        -- (Skipping FK drop as Facts are usually child tables, not parents)

        -- 3. Drop current PK
        DECLARE @sql_surat NVARCHAR(MAX);
        SET @sql_surat = 'ALTER TABLE fact.fact_surat DROP CONSTRAINT ' + @pk_name_surat;
        EXEC sp_executesql @sql_surat;

        -- 4. Re-create PK as Clustered on Partition Scheme
        -- We MUST include tanggal_key in the PK to align the partition
        ALTER TABLE fact.fact_surat
        ADD CONSTRAINT PK_Fact_Surat_Partitioned 
        PRIMARY KEY CLUSTERED (surat_key, tanggal_key)
        ON ps_YearlyRange(tanggal_key);

        COMMIT TRANSACTION;
        PRINT 'Fact_Surat successfully partitioned on tanggal_key.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error partitioning Fact_Surat: ' + ERROR_MESSAGE();
    END CATCH
END
GO

-- =====================================================
-- 4. APPLY PARTITIONING TO FACT_LAYANAN
-- =====================================================

IF EXISTS (SELECT * FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('fact.fact_layanan') AND type = 'PK')
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Get PK Name
        DECLARE @pk_name_layanan NVARCHAR(128);
        SELECT TOP 1 @pk_name_layanan = name 
        FROM sys.key_constraints 
        WHERE parent_object_id = OBJECT_ID('fact.fact_layanan') AND type = 'PK';

        -- 2. Drop current PK
        DECLARE @sql_layanan NVARCHAR(MAX);
        SET @sql_layanan = 'ALTER TABLE fact.fact_layanan DROP CONSTRAINT ' + @pk_name_layanan;
        EXEC sp_executesql @sql_layanan;

        -- 3. Re-create PK as Clustered on Partition Scheme
        -- Use tanggal_request_key as partition column
        ALTER TABLE fact.fact_layanan
        ADD CONSTRAINT PK_Fact_Layanan_Partitioned 
        PRIMARY KEY CLUSTERED (layanan_key, tanggal_request_key)
        ON ps_YearlyRange(tanggal_request_key);

        COMMIT TRANSACTION;
        PRINT 'Fact_Layanan successfully partitioned on tanggal_request_key.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'Error partitioning Fact_Layanan: ' + ERROR_MESSAGE();
    END CATCH
END
GO

-- =====================================================
-- VALIDATION QUERY
-- =====================================================
/*
SELECT 
    t.name AS TableName,
    i.name AS IndexName,
    p.partition_number,
    p.rows,
    f.name AS FunctionName,
    r.value AS BoundaryValue
FROM sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.partition_schemes s ON i.data_space_id = s.data_space_id
JOIN sys.partition_functions f ON s.function_id = f.function_id
LEFT JOIN sys.partition_range_values r ON f.function_id = r.function_id AND r.boundary_id = p.partition_number
WHERE t.name IN ('fact_surat', 'fact_layanan') AND i.type <= 1
ORDER BY t.name, p.partition_number;
*/

-- ====================== END OF FILE ======================
