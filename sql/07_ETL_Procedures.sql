-- =====================================================
-- 07_ETL_Procedures.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : ETL Procedures
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- 1. PROCEDURE: LOAD DIM WAKTU
-- =====================================================

DROP PROCEDURE IF EXISTS etl.load_dim_waktu(DATE, DATE) CASCADE;
CREATE OR REPLACE PROCEDURE etl.load_dim_waktu(
    p_start_date DATE DEFAULT '2020-01-01',
    p_end_date DATE DEFAULT '2026-12-31'
) AS $$
DECLARE
    v_current_date DATE := p_start_date;
    v_date_key INT;
BEGIN
    -- Insert default unknown date
    INSERT INTO dim.dim_waktu VALUES (19000101, '1900-01-01', 'Unknown', 1, 1900, 1, 1, 1, FALSE, 'Unknown')
    ON CONFLICT (tanggal_key) DO NOTHING;
    
    -- Loop through dates and insert
    WHILE v_current_date <= p_end_date LOOP
        v_date_key := CAST(TO_CHAR(v_current_date, 'YYYYMMDD') AS INT);
        
        INSERT INTO dim.dim_waktu (tanggal_key, tanggal, hari, bulan, tahun, quarter, minggu_tahun, hari_dalam_bulan, hari_kerja, bulan_tahun)
        VALUES (
            v_date_key,
            v_current_date,
            TO_CHAR(v_current_date, 'Day'),
            EXTRACT(MONTH FROM v_current_date)::INT,
            EXTRACT(YEAR FROM v_current_date)::INT,
            EXTRACT(QUARTER FROM v_current_date)::INT,
            EXTRACT(WEEK FROM v_current_date)::INT,
            EXTRACT(DAY FROM v_current_date)::INT,
            EXTRACT(DOW FROM v_current_date) NOT IN (0, 6),
            TO_CHAR(v_current_date, 'Month YYYY')
        )
        ON CONFLICT (tanggal_key) DO NOTHING;
        
        v_current_date := v_current_date + INTERVAL '1 day';
    END LOOP;
    
    RAISE NOTICE 'Dim Waktu loaded successfully.';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. PROCEDURE: LOAD DIM UNIT KERJA
-- =====================================================

DROP PROCEDURE IF EXISTS etl.load_dim_unit_kerja() CASCADE;
CREATE OR REPLACE PROCEDURE etl.load_dim_unit_kerja() AS $$
BEGIN
    INSERT INTO dim.dim_unit_kerja (kode_unit, nama_unit, level, kepala_unit_nip, email_unit, is_active)
    SELECT 
        kode_unit, 
        nama_unit, 
        level, 
        kepala_unit_nip, 
        email_unit, 
        TRUE
    FROM stg.stg_unit_kerja
    WHERE is_processed = FALSE
    ON CONFLICT (kode_unit) DO UPDATE SET
        nama_unit = EXCLUDED.nama_unit,
        level = EXCLUDED.level,
        kepala_unit_nip = EXCLUDED.kepala_unit_nip,
        email_unit = EXCLUDED.email_unit;
    
    RAISE NOTICE 'Dim Unit Kerja loaded successfully.';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. PROCEDURE: LOAD FACT SURAT
-- =====================================================

DROP PROCEDURE IF EXISTS etl.load_fact_surat() CASCADE;
CREATE OR REPLACE PROCEDURE etl.load_fact_surat() AS $$
BEGIN
    INSERT INTO fact.fact_surat (tanggal_key, unit_pengirim_key, unit_penerima_key, pegawai_penerima_key, jenis_surat_key, nomor_surat, status_akhir, created_at)
    SELECT 
        COALESCE(dw.tanggal_key, 19000101),
        COALESCE(du.unit_key, -1),
        -1,
        -1,
        COALESCE(djs.jenis_surat_key, -1),
        s.nomor_surat,
        s.status,
        CURRENT_TIMESTAMP
    FROM stg.stg_simaster_surat s
    LEFT JOIN dim.dim_waktu dw ON s.tanggal_diterima = dw.tanggal
    LEFT JOIN dim.dim_unit_kerja du ON s.pengirim = du.nama_unit
    LEFT JOIN dim.dim_jenis_surat djs ON s.jenis_surat_id = djs.jenis_surat_key
    WHERE s.is_processed = FALSE;
    
    UPDATE stg.stg_simaster_surat SET is_processed = TRUE WHERE is_processed = FALSE;
    
    RAISE NOTICE 'Fact Surat loaded successfully.';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. PROCEDURE: LOAD FACT LAYANAN
-- =====================================================

DROP PROCEDURE IF EXISTS etl.load_fact_layanan() CASCADE;
CREATE OR REPLACE PROCEDURE etl.load_fact_layanan() AS $$
BEGIN
    INSERT INTO fact.fact_layanan (tanggal_request_key, tanggal_selesai_key, unit_pemohon_key, unit_pelaksana_key, pegawai_pemohon_key, pegawai_penanggung_jawab_key, jenis_layanan_key, nomor_tiket, sla_target_jam, waktu_selesai_jam, rating_kepuasan, melewati_sla_flag, status_akhir, created_at)
    SELECT 
        COALESCE(dw_req.tanggal_key, 19000101),
        dw_end.tanggal_key,
        -1,
        -1,
        -1,
        -1,
        COALESCE(djl.jenis_layanan_key, -1),
        s.nomor_tiket,
        djl.sla_target_jam,
        EXTRACT(EPOCH FROM (s.tanggal_selesai - s.timestamp_submit)) / 3600,
        s.rating_kepuasan,
        CASE WHEN EXTRACT(EPOCH FROM (s.tanggal_selesai - s.timestamp_submit)) / 3600 > djl.sla_target_jam THEN TRUE ELSE FALSE END,
        s.status_penyelesaian,
        CURRENT_TIMESTAMP
    FROM stg.stg_layanan s
    LEFT JOIN dim.dim_waktu dw_req ON CAST(s.timestamp_submit AS DATE) = dw_req.tanggal
    LEFT JOIN dim.dim_waktu dw_end ON CAST(s.tanggal_selesai AS DATE) = dw_end.tanggal
    LEFT JOIN dim.dim_jenis_layanan djl ON s.jenis_layanan_id = djl.jenis_layanan_key
    WHERE s.is_processed = FALSE;
    
    UPDATE stg.stg_layanan SET is_processed = TRUE WHERE is_processed = FALSE;
    
    RAISE NOTICE 'Fact Layanan loaded successfully.';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. PROCEDURE: LOAD FACT ASET
-- =====================================================

DROP PROCEDURE IF EXISTS etl.load_fact_aset() CASCADE;
CREATE OR REPLACE PROCEDURE etl.load_fact_aset() AS $$
DECLARE
    v_snapshot_date_key INT;
BEGIN
    v_snapshot_date_key := CAST(TO_CHAR(CURRENT_DATE, 'YYYYMMDD') AS INT);
    
    INSERT INTO fact.fact_aset (tanggal_snapshot_key, barang_key, lokasi_key, unit_pemilik_key, jumlah_unit, nilai_perolehan, nilai_buku, kondisi, status_pemanfaatan, created_at)
    SELECT 
        v_snapshot_date_key,
        COALESCE(db.barang_key, -1),
        COALESCE(dl.lokasi_key, -1),
        COALESCE(du.unit_key, -1),
        1,
        s.nilai_perolehan,
        s.nilai_perolehan,
        s.kondisi,
        'Aktif',
        CURRENT_TIMESTAMP
    FROM stg.stg_inventaris s
    LEFT JOIN dim.dim_barang db ON s.kode_barang = db.kode_barang
    LEFT JOIN dim.dim_lokasi dl ON s.lokasi_id = dl.lokasi_key
    LEFT JOIN dim.dim_unit_kerja du ON s.unit_kerja_id = du.unit_key
    WHERE s.is_processed = FALSE;
    
    UPDATE stg.stg_inventaris SET is_processed = TRUE WHERE is_processed = FALSE;
    
    RAISE NOTICE 'Fact Aset loaded successfully.';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. MASTER PROCEDURE
-- =====================================================

DROP PROCEDURE IF EXISTS etl.master_etl() CASCADE;
CREATE OR REPLACE PROCEDURE etl.master_etl() AS $$
DECLARE
    v_exec_id INT;
BEGIN
    BEGIN
        -- Log execution start
        INSERT INTO etl_log.job_execution (job_name, status) VALUES ('Master_ETL', 'Running')
        RETURNING execution_id INTO v_exec_id;
        
        -- Execute ETL procedures
        CALL etl.load_dim_waktu();
        CALL etl.load_dim_unit_kerja();
        CALL etl.load_fact_surat();
        CALL etl.load_fact_layanan();
        CALL etl.load_fact_aset();
        
        -- Log success
        UPDATE etl_log.job_execution 
        SET status = 'Success', end_time = CURRENT_TIMESTAMP 
        WHERE execution_id = v_exec_id;
        
        RAISE NOTICE 'Master ETL completed successfully.';
    EXCEPTION WHEN OTHERS THEN
        UPDATE etl_log.job_execution 
        SET status = 'Failed', end_time = CURRENT_TIMESTAMP, error_message = SQLERRM
        WHERE execution_id = v_exec_id;
        RAISE NOTICE 'Error in Master ETL: %', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- ====================== END OF FILE ======================
