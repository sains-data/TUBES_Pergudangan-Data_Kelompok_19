-- =====================================================
-- 08_Data_Quality_Checks.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Automated DQ Checks
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- HELPER PROCEDURE: LOGGING
-- =====================================================

DROP PROCEDURE IF EXISTS etl.log_dq_result(INT, VARCHAR, VARCHAR, VARCHAR, INT, INT, VARCHAR) CASCADE;
CREATE OR REPLACE PROCEDURE etl.log_dq_result(
    p_execution_id INT,
    p_check_name VARCHAR,
    p_table_name VARCHAR,
    p_column_name VARCHAR,
    p_failed_count INT,
    p_threshold INT,
    p_notes VARCHAR
) AS $$
DECLARE
    v_result VARCHAR(20);
BEGIN
    IF p_failed_count > p_threshold THEN
        v_result := 'Fail';
    ELSIF p_failed_count > 0 THEN
        v_result := 'Warning';
    ELSE
        v_result := 'Pass';
    END IF;
    
    INSERT INTO etl_log.data_quality_checks (execution_id, check_name, table_name, column_name, check_result, actual_value, expected_value, notes)
    VALUES (p_execution_id, p_check_name, p_table_name, p_column_name, v_result, p_failed_count::VARCHAR, '0', p_notes);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- MAIN PROCEDURE: RUN ALL CHECKS
-- =====================================================

DROP PROCEDURE IF EXISTS etl.run_data_quality_checks(INT) CASCADE;
CREATE OR REPLACE PROCEDURE etl.run_data_quality_checks(p_execution_id INT DEFAULT NULL) AS $$
DECLARE
    v_exec_id INT;
    v_fail_count INT;
BEGIN
    -- Setup execution ID
    IF p_execution_id IS NULL THEN
        INSERT INTO etl_log.job_execution (job_name, status) VALUES ('Manual_DQ_Check', 'Running')
        RETURNING execution_id INTO v_exec_id;
    ELSE
        v_exec_id := p_execution_id;
    END IF;
    
    RAISE NOTICE 'Starting DQ Checks for Execution ID: %', v_exec_id;
    
    -- =====================================================
    -- DIMENSION CHECKS
    -- =====================================================
    
    -- 1.1 Dim Pegawai: Check if table exists before running checks
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'dim' AND table_name = 'dim_pegawai') THEN
        SELECT COUNT(*) INTO v_fail_count FROM dim.dim_pegawai WHERE created_date > CURRENT_DATE;
        CALL etl.log_dq_result(v_exec_id, 'Date Logic Check', 'dim_pegawai', 'created_date', v_fail_count, 0, 'Future dates detected');
    END IF;
    
    -- =====================================================
    -- FACT TABLE CHECKS
    -- =====================================================
    
    -- 2.1 Fact Surat: Check table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'fact' AND table_name = 'fact_surat') THEN
        SELECT COUNT(*) INTO v_fail_count FROM fact.fact_surat WHERE tanggal_key IS NULL;
        CALL etl.log_dq_result(v_exec_id, 'NOT NULL Check', 'fact_surat', 'tanggal_key', v_fail_count, 0, 'NULL tanggal_key found');
    END IF;
    
    -- 2.2 Fact Layanan: Check table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'fact' AND table_name = 'fact_layanan') THEN
        SELECT COUNT(*) INTO v_fail_count FROM fact.fact_layanan WHERE tanggal_request_key IS NULL;
        CALL etl.log_dq_result(v_exec_id, 'NOT NULL Check', 'fact_layanan', 'tanggal_request_key', v_fail_count, 0, 'NULL tanggal_request_key found');
    END IF;
    
    -- 2.3 Fact Aset: Check table exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'fact' AND table_name = 'fact_aset') THEN
        SELECT COUNT(*) INTO v_fail_count FROM fact.fact_aset WHERE nilai_perolehan < 0;
        CALL etl.log_dq_result(v_exec_id, 'Value Accuracy', 'fact_aset', 'nilai_perolehan', v_fail_count, 0, 'Negative nilai_perolehan found');
    END IF;
    
    RAISE NOTICE 'DQ Checks completed successfully.';
    
    -- Update job status if manual run
    IF p_execution_id IS NULL THEN
        UPDATE etl_log.job_execution SET status = 'Success', end_time = CURRENT_TIMESTAMP WHERE execution_id = v_exec_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VIEW: DQ DASHBOARD SUMMARY
-- =====================================================

DROP VIEW IF EXISTS reports.vw_dq_dashboard CASCADE;
CREATE VIEW reports.vw_dq_dashboard AS
SELECT 
    CAST(dq.check_timestamp AS DATE) as check_date,
    dq.table_name,
    dq.check_name,
    dq.check_result,
    dq.actual_value as failed_rows,
    dq.notes
FROM etl_log.data_quality_checks dq
WHERE dq.execution_id = (SELECT MAX(execution_id) FROM etl_log.job_execution WHERE job_name LIKE '%DQ%')
ORDER BY dq.check_timestamp DESC;

-- =====================================================================
-- SUCCESS MESSAGE
-- =====================================================================

SELECT '08_Data_Quality_Checks.sql executed successfully' as status;

-- ====================== END OF FILE ======================
