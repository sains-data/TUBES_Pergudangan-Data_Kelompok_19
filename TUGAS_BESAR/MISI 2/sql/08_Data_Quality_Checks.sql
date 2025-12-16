-- =====================================================
-- 08_Data_Quality_Checks.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Automated DQ Checks
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Creating Data Quality Check Procedures...';
GO

-- =====================================================
-- HELPER PROCEDURE: LOGGING
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_LogDQResult
    @p_execution_id INT,
    @p_check_name VARCHAR(100),
    @p_table_name VARCHAR(100),
    @p_column_name VARCHAR(100),
    @p_failed_count INT,
    @p_threshold INT,
    @p_notes VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_result VARCHAR(20);

    -- Determine Pass/Warning/Fail
    IF @p_failed_count > @p_threshold
        SET @v_result = 'Fail';
    ELSE IF @p_failed_count > 0
        SET @v_result = 'Warning';
    ELSE
        SET @v_result = 'Pass';

    -- Insert into Log Table
    INSERT INTO etl_log.data_quality_checks (
        execution_id, 
        check_name, 
        table_name, 
        column_name, 
        check_result, 
        actual_value, 
        expected_value, 
        notes,
        check_timestamp
    )
    VALUES (
        @p_execution_id, 
        @p_check_name, 
        @p_table_name, 
        @p_column_name, 
        @v_result, 
        CAST(@p_failed_count AS VARCHAR(100)), 
        '0', 
        @p_notes,
        GETDATE()
    );
END;
GO

-- =====================================================
-- MAIN PROCEDURE: RUN ALL CHECKS
-- =====================================================

CREATE OR ALTER PROCEDURE etl.usp_RunDataQualityChecks
    @p_execution_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_exec_id INT;
    DECLARE @v_fail_count INT;
    DECLARE @IsManualRun BIT = 0;

    -- Setup Execution ID
    IF @p_execution_id IS NULL
    BEGIN
        INSERT INTO etl_log.job_execution (job_name, status, start_time) 
        VALUES ('Manual_DQ_Check', 'Running', GETDATE());
        
        SET @v_exec_id = SCOPE_IDENTITY();
        SET @IsManualRun = 1;
    END
    ELSE
    BEGIN
        SET @v_exec_id = @p_execution_id;
    END

    PRINT '>> Starting DQ Checks for Execution ID: ' + CAST(@v_exec_id AS VARCHAR(20));

    BEGIN TRY
        -- =====================================================
        -- DIMENSION CHECKS
        -- =====================================================

        -- 1.1 Dim Pegawai: Check for future dates (if table exists)
        IF OBJECT_ID('dim.dim_pegawai', 'U') IS NOT NULL
        BEGIN
            -- Note: dim_pegawai in script 02 doesn't have created_date, checking effective_date instead
            SELECT @v_fail_count = COUNT(*) FROM dim.dim_pegawai WHERE effective_date > GETDATE();
            EXEC etl.usp_LogDQResult @v_exec_id, 'Date Logic Check', 'dim_pegawai', 'effective_date', @v_fail_count, 0, 'Future effective_date detected';
        END

        -- =====================================================
        -- FACT TABLE CHECKS
        -- =====================================================

        -- 2.1 Fact Surat: Check NOT NULL keys
        IF OBJECT_ID('fact.fact_surat', 'U') IS NOT NULL
        BEGIN
            SELECT @v_fail_count = COUNT(*) FROM fact.fact_surat WHERE tanggal_key IS NULL;
            EXEC etl.usp_LogDQResult @v_exec_id, 'NOT NULL Check', 'fact_surat', 'tanggal_key', @v_fail_count, 0, 'NULL tanggal_key found';
        END

        -- 2.2 Fact Layanan: Check NOT NULL keys
        IF OBJECT_ID('fact.fact_layanan', 'U') IS NOT NULL
        BEGIN
            SELECT @v_fail_count = COUNT(*) FROM fact.fact_layanan WHERE tanggal_request_key IS NULL;
            EXEC etl.usp_LogDQResult @v_exec_id, 'NOT NULL Check', 'fact_layanan', 'tanggal_request_key', @v_fail_count, 0, 'NULL tanggal_request_key found';
        END

        -- 2.3 Fact Aset: Check Negative Values
        IF OBJECT_ID('fact.fact_aset', 'U') IS NOT NULL
        BEGIN
            SELECT @v_fail_count = COUNT(*) FROM fact.fact_aset WHERE nilai_perolehan < 0;
            EXEC etl.usp_LogDQResult @v_exec_id, 'Value Accuracy', 'fact_aset', 'nilai_perolehan', @v_fail_count, 0, 'Negative nilai_perolehan found';
        END

        PRINT '>> DQ Checks completed successfully.';

        -- Update job status if manual run
        IF @IsManualRun = 1
        BEGIN
            UPDATE etl_log.job_execution 
            SET status = 'Success', end_time = GETDATE() 
            WHERE execution_id = @v_exec_id;
        END

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        PRINT 'Error in DQ Checks: ' + @ErrorMessage;
        
        IF @IsManualRun = 1
        BEGIN
            UPDATE etl_log.job_execution 
            SET status = 'Failed', end_time = GETDATE(), error_message = @ErrorMessage
            WHERE execution_id = @v_exec_id;
        END
    END CATCH
END;
GO

-- =====================================================
-- VIEW: DQ DASHBOARD SUMMARY
-- =====================================================

CREATE OR ALTER VIEW reports.vw_dq_dashboard AS
SELECT TOP 100 PERCENT
    CAST(dq.check_timestamp AS DATE) as check_date,
    dq.table_name,
    dq.check_name,
    dq.check_result,
    dq.actual_value as failed_rows,
    dq.notes
FROM etl_log.data_quality_checks dq
-- To prevent performance issues on large logs, usually filtered by latest execution or date range
-- For this view, we order by latest check
ORDER BY dq.check_timestamp DESC;
GO

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

PRINT '>> 08_Data_Quality_Checks.sql executed successfully.';
GO
