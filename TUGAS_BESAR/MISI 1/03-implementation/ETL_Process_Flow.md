# ETL Process Flow Documentation
## Data Mart Biro Akademik Umum ITERA

**Document Version:** 1.0  
**Created:** 24 November 2025  
**Owner:** Kelompok 19 - Feby Angelina  
**Purpose:** Detailed ETL process flow dan execution procedures

---

## Table of Contents

1. [ETL Process Overview](#1-etl-process-overview)
2. [Detailed Process Flows](#2-detailed-process-flows)
3. [ETL Execution Commands](#3-etl-execution-commands)
4. [Monitoring & Logging](#4-monitoring-logging)
5. [Error Handling Procedures](#5-error-handling-procedures)
6. [Performance Metrics](#6-performance-metrics)

---

## 1. ETL Process Overview

### 1.1 ETL Pipeline Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ETL MASTER PROCESS                    │
│                 (dw.run_etl_full)                        │
└────────────┬────────────────────────────────────────────┘
             │
             ├──► PHASE 1: EXTRACTION
             │    • Connect to source systems
             │    • Export data to CSV
             │    • Validate file formats
             │    Duration: ~5-10 minutes
             │
             ├──► PHASE 2: STAGING LOAD
             │    • Truncate staging tables
             │    • Bulk load CSV files
             │    • Log row counts
             │    Duration: ~2-3 minutes
             │
             ├──► PHASE 3: DIMENSION LOAD
             │    ├─► dim.unit_organisasi (Type 1)
             │    ├─► dim.pegawai (Type 2 SCD)
             │    ├─► dim.jenis_surat (Type 1)
             │    ├─► dim.jenis_layanan (Type 1)
             │    └─► dim.jenis_aset (Type 1)
             │    Duration: ~5-8 minutes
             │
             ├──► PHASE 4: FACT LOAD
             │    ├─► fact.surat
             │    ├─► fact.layanan
             │    └─► fact.aset (monthly snapshot)
             │    Duration: ~8-12 minutes
             │
             ├──► PHASE 5: DATA QUALITY CHECKS
             │    • Schema validation
             │    • Business rule checks
             │    • Referential integrity
             │    Duration: ~2-3 minutes
             │
             └──► PHASE 6: FINALIZATION
                  • Update metadata
                  • Log statistics
                  • Send notifications
                  Duration: ~1 minute
                  
Total Duration: ~25-40 minutes
```

### 1.2 Execution Frequency

| ETL Type | Frequency | Start Time | Target Duration | Scope |
|----------|-----------|------------|-----------------|-------|
| **Daily Incremental** | Every day | 02:00 AM | 15-30 min | Transactional facts, dimension updates |
| **Monthly Snapshot** | Last day of month | 03:00 AM | 45-60 min | Asset snapshots, full refresh |
| **On-Demand** | As needed | Manual | 25-40 min | Ad-hoc loads, testing |

---

## 2. Detailed Process Flows

### 2.1 PHASE 1: Data Extraction

#### 2.1.1 Source System Connections

```python
# Python extraction script example
import psycopg2
import csv
from datetime import datetime

def extract_surat_data(source_conn, output_file):
    """Extract correspondence data from SIMASTER"""
    
    query = """
        SELECT 
            nomor_surat,
            tanggal_surat,
            jenis_surat_id,
            perihal,
            pembuat_nip,
            unit_pengirim_kode,
            unit_penerima_kode,
            prioritas,
            status_disposisi,
            tanggal_disposisi,
            keterangan
        FROM simaster.dbo.surat
        WHERE tanggal_surat >= CURRENT_DATE - INTERVAL '7 days'  -- Incremental
    """
    
    try:
        cursor = source_conn.cursor()
        cursor.execute(query)
        
        with open(output_file, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.writer(f)
            # Write header
            writer.writerow([desc[0] for desc in cursor.description])
            # Write data
            writer.writerows(cursor.fetchall())
        
        row_count = cursor.rowcount
        print(f"✓ Extracted {row_count} rows to {output_file}")
        
        return row_count
        
    except Exception as e:
        print(f"✗ Extraction failed: {str(e)}")
        raise
```

#### 2.1.2 Extraction Validation Rules

**Pre-extraction Checks:**
- [ ] Source database connectivity
- [ ] Sufficient disk space for export files
- [ ] No active locks on source tables
- [ ] Previous ETL completed successfully

**Post-extraction Validation:**
- [ ] File size > 0 bytes
- [ ] Row count matches query result
- [ ] No NULL values in key columns
- [ ] File encoding is UTF-8

### 2.2 PHASE 2: Staging Load

#### 2.2.1 Staging Table Refresh Strategy

```sql
-- Truncate and load staging tables
CREATE OR REPLACE PROCEDURE dw.load_staging_from_csv()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_loaded INTEGER;
BEGIN
    -- Truncate existing data
    TRUNCATE TABLE stg.surat CASCADE;
    TRUNCATE TABLE stg.pegawai CASCADE;
    TRUNCATE TABLE stg.layanan CASCADE;
    TRUNCATE TABLE stg.aset CASCADE;
    TRUNCATE TABLE stg.unit_organisasi CASCADE;
    
    -- Load stg.surat
    COPY stg.surat (
        nomor_surat, tanggal_surat, jenis_surat_id, nama_jenis_surat,
        perihal, pembuat_nip, unit_pengirim_kode, unit_penerima_kode,
        prioritas, status_disposisi, tanggal_disposisi, keterangan
    )
    FROM '/data/etl/sample_stg_surat.csv'
    WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');
    
    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;
    RAISE NOTICE 'Loaded % rows into stg.surat', v_rows_loaded;
    
    -- Load stg.pegawai
    COPY stg.pegawai (
        nip, nama_lengkap, jabatan, unit_kerja, email, 
        telepon, status_kepegawaian, tanggal_mulai_kerja
    )
    FROM '/data/etl/sample_stg_pegawai.csv'
    WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');
    
    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;
    RAISE NOTICE 'Loaded % rows into stg.pegawai', v_rows_loaded;
    
    -- Load other staging tables similarly...
    
    COMMIT;
END;
$$;
```

#### 2.2.2 Staging Data Validation

```sql
-- Check for basic data quality issues in staging
CREATE OR REPLACE FUNCTION dw.validate_staging_data() 
RETURNS TABLE (
    table_name VARCHAR(50),
    check_name VARCHAR(100),
    issue_count INTEGER,
    sample_records TEXT
) AS $$
BEGIN
    -- Check for NULL nomor_surat
    RETURN QUERY
    SELECT 
        'stg.surat'::VARCHAR(50),
        'null_nomor_surat'::VARCHAR(100),
        COUNT(*)::INTEGER,
        STRING_AGG(DISTINCT tanggal_surat::TEXT, ', ')
    FROM stg.surat
    WHERE nomor_surat IS NULL;
    
    -- Check for invalid NIP format
    RETURN QUERY
    SELECT 
        'stg.pegawai'::VARCHAR(50),
        'invalid_nip_format'::VARCHAR(100),
        COUNT(*)::INTEGER,
        STRING_AGG(DISTINCT nip, ', ')
    FROM stg.pegawai
    WHERE LENGTH(nip) != 18 OR nip !~ '^[0-9]+$';
    
    -- Check for future dates
    RETURN QUERY
    SELECT 
        'stg.layanan'::VARCHAR(50),
        'future_date'::VARCHAR(100),
        COUNT(*)::INTEGER,
        STRING_AGG(DISTINCT transaksi_id, ', ')
    FROM stg.layanan
    WHERE tanggal_permintaan > CURRENT_DATE;
    
    -- Add more validation checks...
END;
$$ LANGUAGE plpgsql;
```

### 2.3 PHASE 3: Dimension Load

#### 2.3.1 Load Sequence (Ordered by Dependencies)

```
1. dim.unit_organisasi
   └─► No dependencies
   └─► Process hierarchical structure
   
2. dim.pegawai (SCD Type 2)
   └─► Depends on: dim.unit_organisasi
   └─► Track historical changes
   
3. dim.jenis_surat, dim.jenis_layanan, dim.jenis_aset
   └─► No dependencies
   └─► Can be loaded in parallel
   
4. dim.status_layanan
   └─► Static dimension (pre-populated)
```

#### 2.3.2 Example: Load dim.unit_organisasi

```sql
CREATE OR REPLACE PROCEDURE dw.load_dim_unit_organisasi(p_batch_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_inserted INTEGER := 0;
    v_rows_updated INTEGER := 0;
BEGIN
    -- Insert new units or update existing
    INSERT INTO dim.unit_organisasi (
        kode_unit, nama_unit, tipe_unit, parent_kode_unit, 
        kepala_unit, created_at, updated_at
    )
    SELECT 
        UPPER(TRIM(kode_unit)),
        TRIM(nama_unit),
        UPPER(TRIM(tipe_unit)),
        CASE 
            WHEN TRIM(parent_kode_unit) = '' THEN NULL 
            ELSE UPPER(TRIM(parent_kode_unit)) 
        END,
        TRIM(kepala_unit),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    FROM stg.unit_organisasi
    ON CONFLICT (kode_unit) DO UPDATE SET
        nama_unit = EXCLUDED.nama_unit,
        tipe_unit = EXCLUDED.tipe_unit,
        parent_kode_unit = EXCLUDED.parent_kode_unit,
        kepala_unit = EXCLUDED.kepala_unit,
        updated_at = CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_rows_inserted = ROW_COUNT;
    
    -- Update hierarchical path and level
    WITH RECURSIVE unit_hierarchy AS (
        -- Root units (no parent)
        SELECT 
            unit_key,
            kode_unit,
            parent_kode_unit,
            1 AS level_hierarchy,
            '/' || kode_unit AS path_hierarchy
        FROM dim.unit_organisasi
        WHERE parent_kode_unit IS NULL
        
        UNION ALL
        
        -- Child units
        SELECT 
            u.unit_key,
            u.kode_unit,
            u.parent_kode_unit,
            uh.level_hierarchy + 1,
            uh.path_hierarchy || '/' || u.kode_unit
        FROM dim.unit_organisasi u
        INNER JOIN unit_hierarchy uh ON u.parent_kode_unit = uh.kode_unit
    )
    UPDATE dim.unit_organisasi u
    SET 
        level_hierarchy = uh.level_hierarchy,
        path_hierarchy = uh.path_hierarchy,
        updated_at = CURRENT_TIMESTAMP
    FROM unit_hierarchy uh
    WHERE u.unit_key = uh.unit_key;
    
    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    
    -- Log execution
    INSERT INTO etl_log.job_execution (
        batch_id, job_name, rows_inserted, rows_updated, status
    ) VALUES (
        p_batch_id, 'load_dim_unit_organisasi', v_rows_inserted, v_rows_updated, 'SUCCESS'
    );
    
    RAISE NOTICE 'dim.unit_organisasi: inserted=%, updated=%', v_rows_inserted, v_rows_updated;
    COMMIT;
END;
$$;
```

#### 2.3.3 SCD Type 2 Implementation Details

**Key Concepts:**
- **Business Key**: nip (employee ID)
- **Surrogate Key**: pegawai_key (auto-increment)
- **Tracking Attributes**: jabatan, unit_kerja, status_kepegawaian
- **Validity Period**: valid_from, valid_to
- **Current Flag**: is_current

**Change Detection Logic:**

```sql
-- Step 1: Identify changed records
CREATE TEMP TABLE changed_pegawai AS
SELECT 
    sp.nip,
    dp.pegawai_key AS old_key
FROM stg.pegawai sp
INNER JOIN dim.pegawai dp ON sp.nip = dp.nip AND dp.is_current = TRUE
WHERE 
    dp.jabatan != sp.jabatan OR
    dp.unit_kerja != sp.unit_kerja OR
    dp.status_kepegawaian != sp.status_kepegawaian;

-- Step 2: Close old versions
UPDATE dim.pegawai dp
SET 
    is_current = FALSE,
    valid_to = CURRENT_TIMESTAMP,
    updated_at = CURRENT_TIMESTAMP
FROM changed_pegawai cp
WHERE dp.pegawai_key = cp.old_key;

-- Step 3: Insert new versions
INSERT INTO dim.pegawai (
    nip, nama_lengkap, jabatan, unit_kerja, email, telepon,
    status_kepegawaian, valid_from, valid_to, is_current
)
SELECT 
    sp.nip,
    INITCAP(TRIM(sp.nama_lengkap)),
    TRIM(sp.jabatan),
    TRIM(sp.unit_kerja),
    LOWER(TRIM(sp.email)),
    sp.telepon,
    UPPER(sp.status_kepegawaian),
    CURRENT_TIMESTAMP,
    '9999-12-31'::TIMESTAMP,
    TRUE
FROM stg.pegawai sp
INNER JOIN changed_pegawai cp ON sp.nip = cp.nip;

-- Step 4: Insert new employees (not in dimension yet)
INSERT INTO dim.pegawai (...)
SELECT ...
FROM stg.pegawai sp
LEFT JOIN dim.pegawai dp ON sp.nip = dp.nip AND dp.is_current = TRUE
WHERE dp.pegawai_key IS NULL;
```

### 2.4 PHASE 4: Fact Load

#### 2.4.1 Fact Load Principles

1. **Grain Enforcement**: Ensure each fact record represents the correct grain
2. **Dimension Key Lookup**: Resolve all foreign keys before insert
3. **Measure Calculation**: Compute derived measures consistently
4. **Idempotency**: Support re-running without duplicates (UPSERT pattern)

#### 2.4.2 Example: Load fact.surat

```sql
CREATE OR REPLACE PROCEDURE dw.load_fact_surat(p_batch_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_inserted INTEGER := 0;
    v_rows_updated INTEGER := 0;
    v_orphaned_records INTEGER := 0;
BEGIN
    -- Check for orphaned staging records (missing dimension keys)
    SELECT COUNT(*) INTO v_orphaned_records
    FROM stg.surat ss
    LEFT JOIN dim.waktu w ON ss.tanggal_surat = w.tanggal
    LEFT JOIN dim.jenis_surat js ON ss.jenis_surat_id = js.jenis_surat_id
    LEFT JOIN dim.pegawai p ON ss.pembuat_nip = p.nip AND p.is_current = TRUE
    LEFT JOIN dim.unit_organisasi u1 ON ss.unit_pengirim_kode = u1.kode_unit
    WHERE w.waktu_key IS NULL 
       OR js.jenis_surat_key IS NULL
       OR p.pegawai_key IS NULL
       OR u1.unit_key IS NULL;
    
    IF v_orphaned_records > 0 THEN
        RAISE WARNING 'Found % orphaned records in stg.surat', v_orphaned_records;
        
        -- Log orphaned records
        INSERT INTO etl_log.error_details (
            batch_id, error_type, error_message, affected_records
        )
        SELECT 
            p_batch_id,
            'ORPHANED_RECORD',
            'Missing dimension keys for fact.surat',
            COUNT(*)
        FROM stg.surat ss
        LEFT JOIN dim.waktu w ON ss.tanggal_surat = w.tanggal
        WHERE w.waktu_key IS NULL;
    END IF;
    
    -- Insert/Update fact records
    INSERT INTO fact.surat (
        nomor_surat,
        tanggal_key,
        jenis_surat_key,
        pembuat_key,
        unit_pengirim_key,
        unit_penerima_key,
        prioritas,
        status_disposisi,
        tanggal_disposisi,
        jumlah_surat,
        lama_disposisi_hari,
        etl_batch_id
    )
    SELECT 
        ss.nomor_surat,
        w.waktu_key,
        js.jenis_surat_key,
        p.pegawai_key,
        u1.unit_key,
        u2.unit_key,
        COALESCE(UPPER(TRIM(ss.prioritas)), 'NORMAL'),
        UPPER(TRIM(ss.status_disposisi)),
        ss.tanggal_disposisi,
        1,
        CASE 
            WHEN ss.tanggal_disposisi IS NOT NULL 
            THEN ss.tanggal_disposisi - ss.tanggal_surat
            ELSE NULL 
        END,
        p_batch_id
    FROM stg.surat ss
    INNER JOIN dim.waktu w ON ss.tanggal_surat = w.tanggal
    INNER JOIN dim.jenis_surat js ON ss.jenis_surat_id = js.jenis_surat_id
    INNER JOIN dim.pegawai p ON ss.pembuat_nip = p.nip AND p.is_current = TRUE
    INNER JOIN dim.unit_organisasi u1 ON ss.unit_pengirim_kode = u1.kode_unit
    LEFT JOIN dim.unit_organisasi u2 ON ss.unit_penerima_kode = u2.kode_unit
    ON CONFLICT (nomor_surat) DO UPDATE SET
        status_disposisi = EXCLUDED.status_disposisi,
        tanggal_disposisi = EXCLUDED.tanggal_disposisi,
        lama_disposisi_hari = EXCLUDED.lama_disposisi_hari,
        updated_at = CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_rows_inserted = ROW_COUNT;
    
    -- Log execution
    INSERT INTO etl_log.job_execution (
        batch_id, job_name, rows_inserted, rows_updated, status
    ) VALUES (
        p_batch_id, 'load_fact_surat', v_rows_inserted, v_rows_updated, 'SUCCESS'
    );
    
    RAISE NOTICE 'fact.surat: inserted/updated=%, orphaned=%', v_rows_inserted, v_orphaned_records;
    COMMIT;
END;
$$;
```

### 2.5 PHASE 5: Data Quality Checks

```sql
CREATE OR REPLACE PROCEDURE dw.run_data_quality_checks(p_batch_id INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE
    v_check_count INTEGER := 0;
    v_failed_checks INTEGER := 0;
BEGIN
    -- Check 1: Referential Integrity - fact.surat
    INSERT INTO etl_log.data_quality_checks (
        batch_id, check_name, check_status, issue_count, check_timestamp
    )
    SELECT 
        p_batch_id,
        'ref_integrity_fact_surat',
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
        COUNT(*),
        CURRENT_TIMESTAMP
    FROM fact.surat fs
    LEFT JOIN dim.waktu w ON fs.tanggal_key = w.waktu_key
    WHERE w.waktu_key IS NULL;
    
    -- Check 2: Business Rule - disposition time
    INSERT INTO etl_log.data_quality_checks (
        batch_id, check_name, check_status, issue_count, check_timestamp
    )
    SELECT 
        p_batch_id,
        'business_rule_disposition_time',
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
        COUNT(*),
        CURRENT_TIMESTAMP
    FROM fact.surat
    WHERE lama_disposisi_hari < 0;
    
    -- Check 3: Completeness - fact.layanan ratings
    INSERT INTO etl_log.data_quality_checks (
        batch_id, check_name, check_status, measured_value, check_timestamp
    )
    SELECT 
        p_batch_id,
        'completeness_layanan_rating',
        CASE WHEN AVG(CASE WHEN rating_kepuasan IS NOT NULL THEN 1.0 ELSE 0.0 END) >= 0.80 
             THEN 'PASS' ELSE 'WARN' END,
        AVG(CASE WHEN rating_kepuasan IS NOT NULL THEN 1.0 ELSE 0.0 END) * 100,
        CURRENT_TIMESTAMP
    FROM fact.layanan
    WHERE status_layanan_key = (
        SELECT status_layanan_key FROM dim.status_layanan WHERE status_layanan_id = 'SELESAI'
    );
    
    -- Check 4: Uniqueness - no duplicate fact records
    INSERT INTO etl_log.data_quality_checks (
        batch_id, check_name, check_status, issue_count, check_timestamp
    )
    SELECT 
        p_batch_id,
        'uniqueness_fact_layanan',
        CASE WHEN COUNT(*) = COUNT(DISTINCT transaksi_id) THEN 'PASS' ELSE 'FAIL' END,
        COUNT(*) - COUNT(DISTINCT transaksi_id),
        CURRENT_TIMESTAMP
    FROM fact.layanan;
    
    -- Count total and failed checks
    SELECT 
        COUNT(*),
        SUM(CASE WHEN check_status = 'FAIL' THEN 1 ELSE 0 END)
    INTO v_check_count, v_failed_checks
    FROM etl_log.data_quality_checks
    WHERE batch_id = p_batch_id;
    
    RAISE NOTICE 'Data Quality: % checks run, % failed', v_check_count, v_failed_checks;
    
    IF v_failed_checks > 0 THEN
        RAISE WARNING 'Data quality check(s) failed. Review etl_log.data_quality_checks';
    END IF;
    
    COMMIT;
END;
$$;
```

---

## 3. ETL Execution Commands

### 3.1 Manual Execution

```sql
-- Full ETL (All phases)
CALL dw.run_etl_full();

-- Individual dimension loads
CALL dw.load_dim_unit_organisasi(9999);
CALL dw.load_dim_pegawai_scd2(9999);
CALL dw.load_dim_jenis_surat(9999);

-- Individual fact loads
CALL dw.load_fact_surat(9999);
CALL dw.load_fact_layanan(9999);

-- Data quality only
CALL dw.run_data_quality_checks(9999);
```

### 3.2 Scheduled Execution (Cron)

```bash
# Daily ETL at 2 AM
0 2 * * * /usr/bin/psql -U datamart_user -d datamart_bau_itera -c "CALL dw.run_etl_full();" >> /var/log/etl/daily_etl.log 2>&1

# Monthly snapshot on last day of month at 3 AM
0 3 L * * /usr/bin/psql -U datamart_user -d datamart_bau_itera -c "CALL dw.run_monthly_snapshot();" >> /var/log/etl/monthly_etl.log 2>&1
```

### 3.3 Pre-execution Checklist

```sql
-- Check system readiness
SELECT 
    'Source DB Connection' AS check_type,
    CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'FAIL' END AS status
FROM pg_stat_activity
WHERE datname = 'source_db'
UNION ALL
SELECT 
    'Disk Space',
    CASE WHEN pg_database_size('datamart_bau_itera') < pg_tablespace_size('pg_default') * 0.8 
         THEN 'OK' ELSE 'WARN' END
UNION ALL
SELECT 
    'Last ETL Status',
    COALESCE(
        (SELECT status FROM etl_log.job_execution 
         WHERE job_name = 'FULL_ETL' 
         ORDER BY start_time DESC LIMIT 1),
        'NEVER_RUN'
    );
```

---

## 4. Monitoring & Logging

### 4.1 Real-time Monitoring Queries

```sql
-- Current ETL status
SELECT 
    batch_id,
    job_name,
    status,
    start_time,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - start_time)) AS running_seconds,
    rows_processed
FROM etl_log.job_execution
WHERE status = 'RUNNING'
ORDER BY start_time DESC;

-- Recent ETL history (last 7 days)
SELECT 
    DATE(start_time) AS run_date,
    job_name,
    status,
    duration_seconds,
    rows_inserted + rows_updated AS total_rows,
    CASE 
        WHEN status = 'SUCCESS' THEN '✓'
        WHEN status = 'FAILED' THEN '✗'
        ELSE '⚠'
    END AS indicator
FROM etl_log.job_execution
WHERE start_time >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY start_time DESC;
```

### 4.2 Performance Metrics

```sql
-- ETL duration trend
SELECT 
    DATE_TRUNC('day', start_time) AS run_date,
    AVG(duration_seconds) AS avg_duration_sec,
    MIN(duration_seconds) AS min_duration_sec,
    MAX(duration_seconds) AS max_duration_sec
FROM etl_log.job_execution
WHERE job_name = 'FULL_ETL'
  AND status = 'SUCCESS'
  AND start_time >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', start_time)
ORDER BY run_date DESC;
```

---

## 5. Error Handling Procedures

### 5.1 Common Error Scenarios

| Error Type | Symptom | Resolution |
|------------|---------|------------|
| **Source Connection Failure** | "could not connect to source database" | Check network, verify credentials, restart source DB |
| **Orphaned Records** | "missing dimension keys" | Load missing dimension data first, then retry |
| **Duplicate Key Violation** | "duplicate key value violates unique constraint" | Check UPSERT logic, verify business key uniqueness |
| **Out of Memory** | "out of memory" | Reduce batch size, increase work_mem setting |
| **Constraint Violation** | "violates check constraint" | Review business rules, fix source data |

### 5.2 Recovery Procedures

```sql
-- Rollback failed ETL
BEGIN;
    -- Identify failed batch
    SELECT batch_id, start_time, error_message
    FROM etl_log.job_execution
    WHERE status = 'FAILED'
    ORDER BY start_time DESC
    LIMIT 1;
    
    -- Delete partial data for failed batch
    DELETE FROM fact.surat WHERE etl_batch_id = <failed_batch_id>;
    DELETE FROM fact.layanan WHERE etl_batch_id = <failed_batch_id>;
    
    -- Revert dimension changes if needed (SCD2)
    -- Note: This is complex and may require manual intervention
    
COMMIT;

-- Retry ETL
CALL dw.run_etl_full();
```

---

## 6. Performance Metrics

### 6.1 Target KPIs

| Metric | Target | Critical Threshold |
|--------|--------|-------------------|
| ETL Success Rate | > 95% | < 85% |
| ETL Duration | < 30 minutes | > 60 minutes |
| Data Quality Pass Rate | > 98% | < 90% |
| Fact Table Load Rate | > 1000 rows/sec | < 500 rows/sec |
| Error Rate | < 0.1% | > 1% |

### 6.2 Monitoring Dashboard Queries

```sql
-- ETL Health Dashboard
WITH recent_runs AS (
    SELECT *
    FROM etl_log.job_execution
    WHERE start_time >= CURRENT_DATE - INTERVAL '30 days'
      AND job_name = 'FULL_ETL'
)
SELECT 
    'Total Runs' AS metric,
    COUNT(*)::TEXT AS value
FROM recent_runs
UNION ALL
SELECT 
    'Success Rate %',
    ROUND(100.0 * SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2)::TEXT
FROM recent_runs
UNION ALL
SELECT 
    'Avg Duration (min)',
    ROUND(AVG(duration_seconds) / 60.0, 2)::TEXT
FROM recent_runs
WHERE status = 'SUCCESS'
UNION ALL
SELECT 
    'Last Run Status',
    status
FROM recent_runs
ORDER BY start_time DESC
LIMIT 1;
```

---

## Appendix: Quick Reference Commands

```sql
-- Start ETL
CALL dw.run_etl_full();

-- Check ETL status
SELECT * FROM etl_log.job_execution ORDER BY start_time DESC LIMIT 5;

-- View data quality results
SELECT * FROM etl_log.data_quality_checks 
WHERE check_timestamp >= CURRENT_DATE 
ORDER BY check_timestamp DESC;

-- Check staging data
SELECT 'stg.surat' AS table_name, COUNT(*) FROM stg.surat
UNION ALL SELECT 'stg.pegawai', COUNT(*) FROM stg.pegawai
UNION ALL SELECT 'stg.layanan', COUNT(*) FROM stg.layanan;

-- Verify fact counts
SELECT 'fact.surat' AS table_name, COUNT(*) FROM fact.surat
UNION ALL SELECT 'fact.layanan', COUNT(*) FROM fact.layanan
UNION ALL SELECT 'fact.aset', COUNT(*) FROM fact.aset;
```

---

**Document Control:**
- **Version:** 1.0
- **Last Updated:** 24 November 2025
- **Owner:** Feby Angelina (Kelompok 19)

---

*End of ETL Process Flow Documentation*
