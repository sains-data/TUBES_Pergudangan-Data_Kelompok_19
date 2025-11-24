-- =====================================================
-- 08_Data_Quality_Checks.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Automated DQ Checks (Post-Load Validation)
-- Engine  : PostgreSQL
-- Dependencies: 03_Create_Facts.sql must be executed first
-- Author  : Aldi (Project Lead)
-- =====================================================

/*
    DQ CHECK STRATEGY:
    1. Completeness : Cek NULL pada kolom kritis (PK/FK).
    2. Uniqueness   : Cek duplikasi pada Business Key (Active Records).
    3. Consistency  : Cek logika SCD Type 2 (Effective Date vs End Date).
    4. Accuracy     : Cek kewajaran nilai (Negative Values, Future Dates).
    
    Output: Hasil check disimpan di tabel etl_log.data_quality_checks
*/

-- =====================================================
-- HELPER FUNCTION: LOGGING
-- =====================================================
CREATE OR REPLACE FUNCTION etl.log_dq_result(
    p_execution_id INT,
    p_check_name VARCHAR,
    p_table_name VARCHAR,
    p_column_name VARCHAR,
    p_failed_count INT,
    p_threshold INT,
    p_notes TEXT
) RETURNS VOID AS $$
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
        p_execution_id,
        p_check_name,
        p_table_name,
        p_column_name,
        v_result,
        CAST(p_failed_count AS VARCHAR), -- Actual: Jumlah baris error
        '0',                             -- Expected: 0 error
        p_notes
    );
END;
$$ LANGUAGE plpgsql;


-- =====================================================
-- MAIN PROCEDURE: RUN ALL CHECKS
-- =====================================================
CREATE OR REPLACE PROCEDURE etl.run_data_quality_checks(p_execution_id INT DEFAULT NULL)
LANGUAGE plpgsql
AS $$
DECLARE
    v_exec_id INT;
    v_fail_count INT;
BEGIN
    -- 1. Setup Execution ID (jika null, buat dummy id untuk testing manual)
    IF p_execution_id IS NULL THEN
        INSERT INTO etl_log.job_execution (job_name, status) 
        VALUES ('Manual_DQ_Check', 'Running') RETURNING execution_id INTO v_exec_id;
    ELSE
        v_exec_id := p_execution_id;
    END IF;

    RAISE NOTICE 'Starting DQ Checks for Execution ID: %', v_exec_id;

    -- =================================================
    -- SECTION 1: DIMENSION CHECKS
    -- =================================================

    -- 1.1 Dim Pegawai: Cek Konsistensi SCD Type 2
    -- Rule: effective_date tidak boleh lebih besar dari end_date
    SELECT COUNT(*) INTO v_fail_count
    FROM dim.dim_pegawai
    WHERE effective_date > end_date;
    
    PERFORM etl.log_dq_result(v_exec_id, 'SCD Date Logic', 'dim_pegawai', 'effective_date', v_fail_count, 0, 'Effective date > End date');

    -- 1.2 Dim Pegawai: Cek Uniqueness (Hanya boleh ada 1 record aktif per NIP)
    SELECT COUNT(*) INTO v_fail_count
    FROM (
        SELECT nip, COUNT(*) 
        FROM dim.dim_pegawai 
        WHERE is_current = TRUE 
        GROUP BY nip 
        HAVING COUNT(*) > 1
    ) sub;

    PERFORM etl.log_dq_result(v_exec_id, 'Active Record Uniqueness', 'dim_pegawai', 'is_current', v_fail_count, 0, 'Multiple active records for single NIP');

    -- 1.3 Dim Barang: Completeness (Kode Barang tidak boleh NULL/Empty)
    SELECT COUNT(*) INTO v_fail_count
    FROM dim.dim_barang
    WHERE kode_barang IS NULL OR TRIM(kode_barang) = '';

    PERFORM etl.log_dq_result(v_exec_id, 'Mandatory Fields', 'dim_barang', 'kode_barang', v_fail_count, 0, 'Missing Code');

    -- =================================================
    -- SECTION 2: FACT TABLE CHECKS
    -- =================================================

    -- 2.1 Fact Surat: Referential Integrity (Orphaned Keys)
    -- Cek jika ada surat dengan unit_pengirim yang tidak ada di dim_unit
    SELECT COUNT(*) INTO v_fail_count
    FROM fact.fact_surat f
    LEFT JOIN dim.dim_unit_kerja d ON f.unit_pengirim_key = d.unit_key
    WHERE d.unit_key IS NULL;

    PERFORM etl.log_dq_result(v_exec_id, 'FK Integrity', 'fact_surat', 'unit_pengirim_key', v_fail_count, 0, 'Orphaned Unit Key');

    -- 2.2 Fact Surat: Accuracy (Durasi Proses Negatif)
    -- Rule: Tanggal selesai tidak boleh sebelum tanggal terima
    SELECT COUNT(*) INTO v_fail_count
    FROM fact.fact_surat
    WHERE durasi_proses_hari < 0;

    PERFORM etl.log_dq_result(v_exec_id, 'Value Accuracy', 'fact_surat', 'durasi_proses_hari', v_fail_count, 0, 'Negative duration found');

    -- 2.3 Fact Aset: Accuracy (Nilai Aset Negatif)
    SELECT COUNT(*) INTO v_fail_count
    FROM fact.fact_aset
    WHERE nilai_perolehan < 0 OR nilai_buku < 0;

    PERFORM etl.log_dq_result(v_exec_id, 'Financial Accuracy', 'fact_aset', 'nilai_perolehan', v_fail_count, 0, 'Negative asset value');

    -- 2.4 Fact Layanan: Consistency (SLA Flag Logic)
    -- Rule: Jika waktu_selesai > sla_target, maka flag harus TRUE. Cek jika tidak sinkron.
    SELECT COUNT(*) INTO v_fail_count
    FROM fact.fact_layanan
    WHERE status_akhir = 'Selesai'
    AND (
        (waktu_selesai_jam > sla_target_jam AND melewati_sla_flag = FALSE)
        OR
        (waktu_selesai_jam <= sla_target_jam AND melewati_sla_flag = TRUE)
    );

    PERFORM etl.log_dq_result(v_exec_id, 'Logic Consistency', 'fact_layanan', 'melewati_sla_flag', v_fail_count, 0, 'SLA Flag contradicts duration');

    -- 2.5 Fact Layanan: Validity (Rating Range)
    -- Rule: Rating harus antara 1.0 sampai 5.0 (jika tidak null)
    SELECT COUNT(*) INTO v_fail_count
    FROM fact.fact_layanan
    WHERE rating_kepuasan IS NOT NULL 
    AND (rating_kepuasan < 1.0 OR rating_kepuasan > 5.0);

    PERFORM etl.log_dq_result(v_exec_id, 'Range Validity', 'fact_layanan', 'rating_kepuasan', v_fail_count, 0, 'Rating out of range (1-5)');

    -- =================================================
    -- FINISH
    -- =================================================
    RAISE NOTICE 'DQ Checks completed successfully.';
    
    -- Update job status if manual run
    IF p_execution_id IS NULL THEN
        UPDATE etl_log.job_execution 
        SET status = 'Success', end_time = CURRENT_TIMESTAMP 
        WHERE execution_id = v_exec_id;
    END IF;
END;
$$;

-- =====================================================
-- VIEW: DQ DASHBOARD SUMMARY
-- =====================================================
CREATE OR REPLACE VIEW reports.vw_dq_dashboard AS
SELECT 
    dq.check_timestamp::DATE as check_date,
    dq.table_name,
    dq.check_name,
    dq.check_result,
    dq.actual_value as failed_rows,
    dq.notes
FROM etl_log.data_quality_checks dq
JOIN (
    SELECT MAX(execution_id) as max_id FROM etl_log.job_execution WHERE job_name LIKE '%DQ%'
) latest ON dq.execution_id = latest.max_id
ORDER BY dq.check_result DESC; -- Fail first

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '08_Data_Quality_Checks.sql executed successfully.';
    RAISE NOTICE 'Procedure etl.run_data_quality_checks() created.';
    RAISE NOTICE 'View reports.vw_dq_dashboard created.';
END $$;
