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
    
    -- 1.1 Dim Pegawai: SCD Date Logic
    SELECT COUNT(*) INTO v_fail_count FROM dim.dim_pegawai WHERE effective_date > end_date;
    CALL etl.log_dq_result(v_exec_id, 'SCD Date Logic', 'dim_pegawai', 'effective_date', v_fail_count, 0, 'Effective date > End date');
    
    -- 1.2 Dim Pegawai: Active Record Uniqueness
    SELECT COUNT(*) INTO v_fail_count FROM (
        SELECT nip FROM dim.dim_pegawai WHERE is_current = TRUE GROUP BY nip HAVING COUNT(*) > 1
    ) sub;
    CALL etl.log_dq_result(v_exec_id, 'Active Record Uniqueness', 'dim_pegawai', 'is_current', v_fail_count, 0, 'Multiple active records for single NIP');
    
    -- =====================================================
    -- FACT TABLE CHECKS
    -- =====================================================
    
    -- 2.1 Fact Surat: Referential Integrity
    SELECT COUNT(*) INTO v_fail_count FROM fact.fact_surat f LEFT JOIN dim.dim_unit_kerja d ON f.unit_pengirim_key = d.unit_key WHERE d.unit_key IS NULL;
    CALL etl.log_dq_result(v_exec_id, 'FK Integrity', 'fact_surat', 'unit_pengirim_key', v_fail_count, 0, 'Orphaned Unit Key');
    
    -- 2.2 Fact Surat: Negative Duration
    SELECT COUNT(*) INTO v_fail_count FROM fact.fact_surat WHERE durasi_proses_hari < 0;
    CALL etl.log_dq_result(v_exec_id, 'Value Accuracy', 'fact_surat', 'durasi_proses_hari', v_fail_count, 0, 'Negative duration found');
    
    -- 2.3 Fact Layanan: SLA Flag Logic
    SELECT COUNT(*) INTO v_fail_count FROM fact.fact_layanan
    WHERE status_akhir = 'Selesai' AND (
        (waktu_selesai_jam > sla_target_jam AND melewati_sla_flag = FALSE) OR
        (waktu_selesai_jam <= sla_target_jam AND melewati_sla_flag = TRUE)
    );
    CALL etl.log_dq_result(v_exec_id, 'Logic Consistency', 'fact_layanan', 'melewati_sla_flag', v_fail_count, 0, 'SLA Flag contradicts duration');
    
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
WHERE dq.execution_id = (SELECT MAX(execution_id) FROM etl_log.job_execution WHERE job_name LIKE '%DQ%');

-- ====================== END OF FILE ======================
