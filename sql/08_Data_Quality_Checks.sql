-- =====================================================
-- 08_Data_Quality_Checks.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Automated DQ Checks (Post-Load Validation)
-- Engine  : Microsoft SQL Server 2019+
-- Dependencies: 03_Create_Facts.sql must be executed first
-- Author  : Aldi (Project Lead)
-- =====================================================

/*
    DQ CHECK STRATEGY:
    1. Completeness : Check NULL on critical columns (PK/FK).
    2. Uniqueness   : Check duplication on Business Keys.
    3. Consistency  : Check SCD logic and cross-column logic.
    4. Accuracy     : Check value ranges (Negative Values, Future Dates).
    
    Output: Results stored in etl_log.data_quality_checks
*/

-- =====================================================
-- HELPER PROCEDURE: LOGGING
-- =====================================================
IF OBJECT_ID('etl.usp_LogDQResult', 'P') IS NOT NULL DROP PROCEDURE etl.usp_LogDQResult;
GO

CREATE PROCEDURE etl.usp_LogDQResult
    @ExecutionId INT,
    @CheckName VARCHAR(100),
    @TableName VARCHAR(100),
    @ColumnName VARCHAR(100),
    @FailedCount INT,
    @Threshold INT,
    @Notes VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Result VARCHAR(20);

    IF @FailedCount > @Threshold
        SET @Result = 'Fail';
    ELSE IF @FailedCount > 0
        SET @Result = 'Warning';
    ELSE
        SET @Result = 'Pass';

    INSERT INTO etl_log.data_quality_checks (
        execution_id,
        check_name,
        table_name,
        column_name,
        check_result,
        actual_value,
        expected_value,
        notes
    ) VALUES (
        @ExecutionId,
        @CheckName,
        @TableName,
        @ColumnName,
        @Result,
        CAST(@FailedCount AS VARCHAR(100)), -- Actual: Failed rows count
        '0',                                -- Expected: 0 errors
        @Notes
    );
END
GO

-- =====================================================
-- MAIN PROCEDURE: RUN ALL CHECKS
-- =====================================================
IF OBJECT_ID('etl.usp_RunDataQualityChecks', 'P') IS NOT NULL DROP PROCEDURE etl.usp_RunDataQualityChecks;
GO

CREATE PROCEDURE etl.usp_RunDataQualityChecks
    @ExecutionId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ExecID INT;
    DECLARE @FailCount INT;

    -- 1. Setup Execution ID (if null, create dummy for manual testing)
    IF @ExecutionId IS NULL
    BEGIN
        INSERT INTO etl_log.job_execution (job_name, status) 
        VALUES ('Manual_DQ_Check', 'Running');
        SET @ExecID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        SET @ExecID = @ExecutionId;
    END

    PRINT 'Starting DQ Checks for Execution ID: ' + CAST(@ExecID AS VARCHAR);

    -- =================================================
    -- SECTION 1: DIMENSION CHECKS
    -- =================================================

    -- 1.1 Dim Pegawai: Check SCD Consistency
    -- Rule: effective_date should not be greater than end_date
    SELECT @FailCount = COUNT(*)
    FROM dim.dim_pegawai
    WHERE effective_date > end_date;
    
    EXEC etl.usp_LogDQResult @ExecID, 'SCD Date Logic', 'dim_pegawai', 'effective_date', @FailCount, 0, 'Effective date > End date';

    -- 1.2 Dim Pegawai: Check Uniqueness (Only 1 active record per NIP)
    SELECT @FailCount = COUNT(*)
    FROM (
        SELECT nip
        FROM dim.dim_pegawai 
        WHERE is_current = 1 
        GROUP BY nip 
        HAVING COUNT(*) > 1
    ) sub;

    EXEC etl.usp_LogDQResult @ExecID, 'Active Record Uniqueness', 'dim_pegawai', 'is_current', @FailCount, 0, 'Multiple active records for single NIP';

    -- 1.3 Dim Barang: Completeness (Kode Barang cannot be NULL/Empty)
    SELECT @FailCount = COUNT(*)
    FROM dim.dim_barang
    WHERE kode_barang IS NULL OR TRIM(kode_barang) = '';

    EXEC etl.usp_LogDQResult @ExecID, 'Mandatory Fields', 'dim_barang', 'kode_barang', @FailCount, 0, 'Missing Code';

    -- =================================================
    -- SECTION 2: FACT TABLE CHECKS
    -- =================================================

    -- 2.1 Fact Surat: Referential Integrity (Orphaned Keys)
    -- Check for unit_pengirim_key not existing in dim_unit_kerja
    SELECT @FailCount = COUNT(*)
    FROM fact.fact_surat f
    LEFT JOIN dim.dim_unit_kerja d ON f.unit_pengirim_key = d.unit_key
    WHERE d.unit_key IS NULL;

    EXEC etl.usp_LogDQResult @ExecID, 'FK Integrity', 'fact_surat', 'unit_pengirim_key', @FailCount, 0, 'Orphaned Unit Key';

    -- 2.2 Fact Surat: Accuracy (Negative Duration)
    -- Rule: Process duration cannot be negative
    SELECT @FailCount = COUNT(*)
    FROM fact.fact_surat
    WHERE durasi_proses_hari < 0;

    EXEC etl.usp_LogDQResult @ExecID, 'Value Accuracy', 'fact_surat', 'durasi_proses_hari', @FailCount, 0, 'Negative duration found';

    -- 2.3 Fact Aset: Accuracy (Negative Asset Value)
    SELECT @FailCount = COUNT(*)
    FROM fact.fact_aset
    WHERE nilai_perolehan < 0 OR nilai_buku < 0;

    EXEC etl.usp_LogDQResult @ExecID, 'Financial Accuracy', 'fact_aset', 'nilai_perolehan', @FailCount, 0, 'Negative asset value';

    -- 2.4 Fact Layanan: Consistency (SLA Flag Logic)
    -- Rule: If duration > target, flag must be 1.
    SELECT @FailCount = COUNT(*)
    FROM fact.fact_layanan
    WHERE status_akhir = 'Selesai'
    AND (
        (waktu_selesai_jam > sla_target_jam AND melewati_sla_flag = 0)
        OR
        (waktu_selesai_jam <= sla_target_jam AND melewati_sla_flag = 1)
    );

    EXEC etl.usp_LogDQResult @ExecID, 'Logic Consistency', 'fact_layanan', 'melewati_sla_flag', @FailCount, 0, 'SLA Flag contradicts duration';

    -- 2.5 Fact Layanan: Validity (Rating Range)
    -- Rule: Rating must be between 1.0 and 5.0 (if not null)
    SELECT @FailCount = COUNT(*)
    FROM fact.fact_layanan
    WHERE rating_kepuasan IS NOT NULL 
    AND (rating_kepuasan < 1.0 OR rating_kepuasan > 5.0);

    EXEC etl.usp_LogDQResult @ExecID, 'Range Validity', 'fact_layanan', 'rating_kepuasan', @FailCount, 0, 'Rating out of range (1-5)';

    -- =================================================
    -- FINISH
    -- =================================================
    PRINT 'DQ Checks completed successfully.';
    
    -- Update job status if manual run
    IF @ExecutionId IS NULL
    BEGIN
        UPDATE etl_log.job_execution 
        SET status = 'Success', end_time = GETDATE() 
        WHERE execution_id = @ExecID;
    END
END
GO

-- =====================================================
-- VIEW: DQ DASHBOARD SUMMARY
-- =====================================================
IF OBJECT_ID('reports.vw_dq_dashboard', 'V') IS NOT NULL DROP VIEW reports.vw_dq_dashboard;
GO

CREATE VIEW reports.vw_dq_dashboard AS
SELECT 
    CAST(dq.check_timestamp AS DATE) as check_date,
    dq.table_name,
    dq.check_name,
    dq.check_result,
    dq.actual_value as failed_rows,
    dq.notes
FROM etl_log.data_quality_checks dq
INNER JOIN (
    SELECT MAX(execution_id) as max_id 
    FROM etl_log.job_execution 
    WHERE job_name LIKE '%DQ%'
) latest ON dq.execution_id = latest.max_id
-- ORDER BY not allowed in VIEW without TOP
GO

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================
PRINT '08_Data_Quality_Checks.sql executed successfully.';
PRINT 'Procedure etl.usp_RunDataQualityChecks created.';
PRINT 'View reports.vw_dq_dashboard created.';

-- ====================== END OF FILE ======================
