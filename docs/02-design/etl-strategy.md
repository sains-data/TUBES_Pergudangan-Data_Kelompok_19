# ETL Strategy Document
- **Document Version:** 1.0
- **Created:** 12 November 2025
- **Owner:** Kelompok 19 - Zahra (ETL Developer Lead)
- **Project:** Data Mart Biro Akademik Umum ITERA
- **Purpose:** Comprehensive ETL strategy untuk development, deployment, dan operational management
---
## Table of Contents
1. [Executive Summary](#executive-summary)
2. [ETL Architecture & Approach](#etl-architecture-approach)
3. [Data Quality Strategy](#data-quality-strategy)
4. [Performance Optimilization](#data-quality-strategy)
5. [Monitoring & Logging](#Monitoring-&-Logging)
6. [Error Handling & Recovery](#Error-Handling-&-Recovery)
7. [Testing Strategy](#Testing-Strategy)
8. [Operational Procedures](#Operational-Procedures)
9. [Risk Management](#Risk-Management)
10. [Success Metrics](#Success-Metrics)
---
## Executive Summary
### Project Overview
Data Mart Biro Akademik Umum ITERA dirancang untuk mengintegrasikan data dari 6 source systems (SIMASTER, Inventaris, SIMPEG, Layanan, Monitoring, Unit Organisasi) ke dalam dimensional model Star Schema dengan 7 dimension tables dan 3 fact tables.

### ETL Scope
- Data Volume: ~56K fact rows, ~3.4K dimension rows (initial load)
- Growth Rate: ~65% per year (estimated)
- Refresh Frequency: Daily incremental (fact_surat, fact_layanan), Monthly snapshot (fact_aset), Weekly (dimensions)
- Technology Stack: SQL Server 2019, T-SQL Stored Procedures, Python (for data generation & transformation)
- Target Environment: Azure VM (SQL Server on Windows Server 2019)

### Key Objectives
- Data Quality: Achieve >95% data accuracy and completeness
- Performance: Complete daily ETL within 30-minute window
- Reliability: 99% ETL success rate with automated recovery
- Scalability: Support 3x data volume growth without architecture change
- Maintainability: Modular design with comprehensive documentation

---

## ETL Architecture & Approach
### 1.1 ETL vs ELT Decision
**Chosen Approach: ETL (Extract-Transform-Load)**

**Rationale:**
- **Data Volume:** Moderate size (~100K rows total) favors transformation before load
- **Source Systems:** Multiple heterogeneous sources require standardization
- **Data Quality:** Complex transformations needed (deduplication, standardization, imputation)
- **Target Platform:** SQL Server optimized for pre-transformed data
- **Team Skillset:** Strong T-SQL and Python capabilities

**Key Benefits:*
- Reduced load on target database
- Better data quality control at transformation stage
- Simplified querying for end-users (data already clean)
- Lower storage requirements in data warehouse
---
### 1.2 Architecture Overview
┌─────────────────────────────────────────────────────────────────┐
│                        SOURCE SYSTEMS                            │
├───────────┬───────────┬──────────┬──────────┬──────────┬────────┤
│ SIMASTER  │Inventaris │  SIMPEG  │ Layanan  │Monitoring│ Unit   │
│    DB     │    DB     │    DB    │    DB    │    DB    │  Org   │
└─────┬─────┴─────┬─────┴────┬─────┴────┬─────┴────┬─────┴────┬───┘
      │           │          │          │          │          │
      └───────────┴──────────┴──────────┴──────────┴──────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │   EXTRACTION LAYER (E)        │
              │ - Python scripts              │
              │ - ODBC/JDBC connectors        │
              │ - Export to CSV/staging       │
              └───────────┬───────────────────┘
                          │
                          ▼
              ┌───────────────────────────────┐
              │   STAGING AREA                │
              │ - Raw data tables             │
              │ - No transformations          │
              │ - Temporary storage           │
              └───────────┬───────────────────┘
                          │
                          ▼
              ┌───────────────────────────────┐
              │   TRANSFORMATION LAYER (T)    │
              │ - Data cleansing              │
              │ - Standardization             │
              │ - Business rules              │
              │ - Aggregation                 │
              │ - SCD handling                │
              └───────────┬───────────────────┘
                          │
                          ▼
              ┌───────────────────────────────┐
              │   LOADING LAYER (L)           │
              │ - Dimension load (SCD)        │
              │ - Fact table load             │
              │ - Index rebuild               │
              │ - Statistics update           │
              └───────────┬───────────────────┘
                          │
                          ▼
              ┌───────────────────────────────┐
              │   DATA WAREHOUSE              │
              │ - Star Schema                 │
              │ - 7 Dimensions + 3 Facts      │
              │ - Ready for BI tools          │
              └───────────────────────────────┘
---
### 1.3 Technology Stack
| Layer | Technology | Purpose | Justification |
| - | - | - | - |
|**Extraction**|Python 3.10 + pandas|Data extraction & CSV generation|Flexibility, library support, synthetic data generation|
|**Staging**|SQL Server Tables (stg schema)|Temporary raw data storage|Native integration, transaction support|
|**Transformation**|T-SQL Stored Procedures|Business logic execution|Performance, maintainability, version control|
|**Loading**|T-SQL MERGE statements|SCD handling & incremental load|Native SCD support, atomic operations|
|**Orchestration**|SQL Server Agent Jobs|Job scheduling & dependency management|Built-in, no additional cost|
|**Monitoring**|SQL Server Extended Events + Custom Log Tables|Performance tracking & auditing|Native, low overhead, no extra tools|
|**Version Control**|GitHub|Code & documentation management|Collaboration, backup, versioning|
---
### 1.4 Environment Strategy
| Environment | Purpose | Refresh Frequency | Data Volume | Access |
| - | - | - | - | - |
|**Development**|Development & unit testing|On-demand|Sample data (10%)|Team only|
|**Testing**|Integration & UAT|Weekly|Full synthetic data|Team + stakeholders|
|**Production**|Live operational system|Daily/Monthly/Weekly|Real data|End-users + team|

**Deployment Flow:**
DEV → TEST → PROD

**Promotion Criteria:**
- All unit tests passed
- Code review approved
- Integration tests successful
- Stakeholder sign-off (for PROD)
---
## Data Quality Strategy
### 2.1 Data Quality Dimensions
|Dimension|Definition|Target|Measurement Method|
| - | - | - | - |
|Completeness|Percentage of non-NULL values in required fields|>98%|COUNT(NULL) / COUNT(*)|
|Accuracy|Data matches source of truth|>95%|Reconciliation with source systems|
|Consistency|Data follows standardized formats|>99%|Pattern matching (regex)|
|Uniqueness|No duplicate records|100%|DISTINCT vs COUNT check|
|Timeliness|Data freshness|Daily refresh complete by 6 AM|ETL job completion timestamp|
|Validity|Data within valid ranges/values|>99%|CHECK constraints + validation queries|
---
### 2.2 Data Profiling Approach
**Pre-ETL Profiling (One-time):**
```sql  
-- Profile source data
SELECT 
    COUNT(*) AS total_rows,
    COUNT(DISTINCT column_name) AS unique_values,
    COUNT(column_name) AS non_null_count,
    COUNT(*) - COUNT(column_name) AS null_count,
    CAST(COUNT(column_name) AS FLOAT) / COUNT(*) * 100 AS completeness_pct,
    MIN(column_name) AS min_value,
    MAX(column_name) AS max_value
FROM source_table
GROUP BY 'column_name';
Ongoing Monitoring (Post-ETL):
```
**Ongoing Monitoring (Post-ETL):**
```sql
-- Data quality dashboard query
SELECT 
    table_name,
    column_name,
    check_date,
    completeness_score,
    accuracy_score,
    consistency_score
FROM etl_log.data_quality_metrics
WHERE check_date >= DATEADD(day, -30, GETDATE())
ORDER BY check_date DESC;
```
---
### 2.3 Data Validation Rules
*Source Data Validation (Pre-Transformation):*

```sql
-- Check 1: No duplicate primary keys
IF EXISTS (
    SELECT nomor_surat, COUNT(*) 
    FROM stg.surat_masuk 
    GROUP BY nomor_surat 
    HAVING COUNT(*) > 1
)
BEGIN
    RAISERROR('Duplicate nomor_surat found in staging', 16, 1);
    RETURN;
END;

-- Check 2: Date range validity
IF EXISTS (
    SELECT * FROM stg.surat_masuk 
    WHERE tanggal_diterima > GETDATE() OR tanggal_diterima < '2019-01-01'
)
BEGIN
    RAISERROR('Invalid date range in tanggal_diterima', 16, 1);
    RETURN;
END;

-- Check 3: Referential integrity
IF EXISTS (
    SELECT * FROM stg.surat_masuk s
    WHERE NOT EXISTS (SELECT 1 FROM stg.unit_kerja u WHERE u.id_unit = s.disposisi_ke)
)
BEGIN
    RAISERROR('Orphaned foreign key in disposisi_ke', 16, 1);
    RETURN;
END;
Target Data Validation (Post-Load):
```

```sql
-- Reconciliation query
SELECT 
    'fact_surat' AS table_name,
    (SELECT COUNT(*) FROM fact_surat WHERE tanggal_key = @today) AS dw_count,
    (SELECT COUNT(*) FROM stg.surat_masuk WHERE tanggal_diterima = @today) AS source_count,
    ABS((SELECT COUNT(*) FROM fact_surat WHERE tanggal_key = @today) - 
        (SELECT COUNT(*) FROM stg.surat_masuk WHERE tanggal_diterima = @today)) AS variance;
```
---
### 2.4 Error Handling Tiers
**Tier 1: Critical Errors (Stop ETL)**
- Source database unavailable
- Staging table corruption
- Critical validation failure (>10% records rejected)
- **Action:** Abort ETL, send alert, rollback changes

**Tier 2: Warning Errors (Log & Continue)**
- Minor data quality issues (<5% records affected)
- Non-critical transformations fail
**Action:** Log to error table, continue ETL, send warning email

**Tier 3: Info Messages (Log Only)**
- Record-level transformations (NULL imputation)
- Expected duplicates removed
**Action:** Log to audit table
---
## Performance Optimization
### 3.1 Indexing Strategy
**Dimension Tables:**

```sql
-- Clustered index on surrogate key
CREATE CLUSTERED INDEX CIX_dim_waktu_tanggal_key 
ON dim_waktu (tanggal_key);

-- Non-clustered index on business key
CREATE NONCLUSTERED INDEX IX_dim_waktu_tanggal 
ON dim_waktu (tanggal);

-- Non-clustered index on frequently filtered columns
CREATE NONCLUSTERED INDEX IX_dim_waktu_tahun_bulan 
ON dim_waktu (tahun, bulan);
```
**Fact Tables:**

```sql
-- Clustered columnstore index for analytical workload
CREATE CLUSTERED COLUMNSTORE INDEX CCIX_fact_surat 
ON fact_surat;

-- Non-clustered indexes on foreign keys
CREATE NONCLUSTERED INDEX IX_fact_surat_tanggal_key 
ON fact_surat (tanggal_key);

CREATE NONCLUSTERED INDEX IX_fact_surat_jenis_surat_key 
ON fact_surat (jenis_surat_key);

CREATE NONCLUSTERED INDEX IX_fact_surat_unit_penerima_key 
ON fact_surat (unit_penerima_key);
```
---
### 3.2 Partitioning Strategy
**Fact Tables (Date-based Partitioning):**

```sql
-- Create partition function (monthly partitions)
CREATE PARTITION FUNCTION pf_monthly_date (INT)
AS RANGE RIGHT FOR VALUES (
    20240101, 20240201, 20240301, 20240401, 20240501, 20240601,
    20240701, 20240801, 20240901, 20241001, 20241101, 20241201,
    20250101  -- Add new partition quarterly
);

-- Create partition scheme
CREATE PARTITION SCHEME ps_monthly_date
AS PARTITION pf_monthly_date
ALL TO ([PRIMARY]);

-- Apply to fact table
CREATE TABLE fact_surat (
    surat_key INT IDENTITY(1,1),
    tanggal_key INT NOT NULL,
    -- other columns...
) ON ps_monthly_date (tanggal_key);
```
**Benefits:**
- Faster queries with partition elimination
- Easier data archival (drop old partitions)
- Parallel load/query processing
- Better index maintenance (rebuild per partition)

### 3.3 Parallel Processing
**Dimension Load (Sequential - Dependency Management):**

```sql
-- Load in order due to FK dependencies
EXEC etl.load_dim_waktu;         -- No dependencies
EXEC etl.load_dim_unit_kerja;    -- Self-referencing, needs special handling
EXEC etl.load_dim_pegawai;       -- Depends on dim_unit_kerja
-- ... other dimensions
```

**Fact Load (Parallel - Independent Tables):**
```sql
-- Can run in parallel (no dependencies between facts)
-- Job 1:
EXEC etl.load_fact_surat;

-- Job 2 (parallel):
EXEC etl.load_fact_aset;

-- Job 3 (parallel):
EXEC etl.load_fact_layanan;
```
---
### 3.4 Incremental Load Strategy
**Daily Incremental (Transactional Facts):**
```sql
-- Load only new/changed records
INSERT INTO fact_surat (tanggal_key, jenis_surat_key, ...)
SELECT 
    w.tanggal_key,
    js.jenis_surat_key,
    ...
FROM stg.surat_masuk s
LEFT JOIN fact_surat f ON s.id_surat = f.nomor_surat  -- Degenerate dimension
INNER JOIN dim_waktu w ON CAST(FORMAT(s.tanggal_diterima, 'yyyyMMdd') AS INT) = w.tanggal_key
INNER JOIN dim_jenis_surat js ON s.jenis_surat_id = js.jenis_surat_key
WHERE f.surat_key IS NULL  -- Only new records
  AND s.tanggal_diterima >= @last_load_date;
  ```

**Monthly Full Snapshot (Periodic Facts):**

```sql
-- Full snapshot on last day of month
INSERT INTO fact_aset (tanggal_snapshot_key, barang_key, ...)
SELECT 
    @snapshot_date_key,
    b.barang_key,
    ...
FROM tbl_inventaris i
INNER JOIN dim_barang b ON i.kode_barang = b.kode_barang
WHERE i.tanggal_snapshot = EOMONTH(GETDATE());
```
---
## Monitoring & Logging
### 4.1 ETL Log Tables
**Job Execution Log:**

``` sql
CREATE TABLE etl_log.job_execution (
    execution_id INT IDENTITY(1,1) PRIMARY KEY,
    job_name VARCHAR(100) NOT NULL,
    start_time DATETIME2 NOT NULL,
    end_time DATETIME2,
    status VARCHAR(20) NOT NULL,  -- 'Running', 'Success', 'Failed', 'Warning'
    rows_extracted INT,
    rows_transformed INT,
    rows_loaded INT,
    error_message VARCHAR(MAX),
    duration_seconds AS DATEDIFF(SECOND, start_time, end_time)
);
```

**Data Quality Log:**

```sql
CREATE TABLE etl_log.data_quality_checks (
    check_id INT IDENTITY(1,1) PRIMARY KEY,
    execution_id INT FOREIGN KEY REFERENCES etl_log.job_execution(execution_id),
    check_name VARCHAR(100) NOT NULL,
    check_timestamp DATETIME2 NOT NULL,
    table_name VARCHAR(100),
    column_name VARCHAR(100),
    check_result VARCHAR(20),  -- 'Pass', 'Fail', 'Warning'
    expected_value VARCHAR(100),
    actual_value VARCHAR(100),
    variance_pct DECIMAL(5,2)
);
```
**Error Detail Log:**

```sql
CREATE TABLE etl_log.error_details (
    error_id INT IDENTITY(1,1) PRIMARY KEY,
    execution_id INT FOREIGN KEY REFERENCES etl_log.job_execution(execution_id),
    error_timestamp DATETIME2 NOT NULL,
    error_type VARCHAR(50),  -- 'Validation', 'Transformation', 'Load', 'System'
    severity VARCHAR(20),     -- 'Critical', 'Warning', 'Info'
    source_table VARCHAR(100),
    error_message VARCHAR(MAX),
    affected_rows INT,
    resolution_status VARCHAR(20)  -- 'Open', 'Resolved', 'Ignored'
);
```
---
### 4.2 Monitoring Dashboards
**Real-time Monitoring Query:**

```sql
-- ETL Job Status Dashboard
SELECT 
    job_name,
    start_time,
    end_time,
    status,
    duration_seconds,
    rows_loaded,
    CASE 
        WHEN duration_seconds > 1800 THEN 'Performance Issue'
        WHEN status = 'Failed' THEN 'Critical'
        WHEN status = 'Warning' THEN 'Review Required'
        ELSE 'Normal'
    END AS health_status
FROM etl_log.job_execution
WHERE start_time >= DATEADD(day, -1, GETDATE())
ORDER BY start_time DESC;
```
*Trend Analysis Query:*

```sql
-- ETL Performance Trends (Last 30 days)
SELECT 
    CAST(start_time AS DATE) AS execution_date,
    job_name,
    AVG(duration_seconds) AS avg_duration,
    SUM(rows_loaded) AS total_rows_loaded,
    COUNT(CASE WHEN status = 'Failed' THEN 1 END) AS failed_count
FROM etl_log.job_execution
WHERE start_time >= DATEADD(day, -30, GETDATE())
GROUP BY CAST(start_time AS DATE), job_name
ORDER BY execution_date DESC, job_name;
```
---
### 4.3 Alerting Mechanism
**Email Alerts (via Database Mail):**

```sql
-- Configure alert for critical failure
CREATE PROCEDURE etl.send_failure_alert
    @job_name VARCHAR(100),
    @error_message VARCHAR(MAX)
AS
BEGIN
    DECLARE @subject VARCHAR(200) = 'ETL FAILURE: ' + @job_name;
    DECLARE @body VARCHAR(MAX) = 
        'ETL Job Failed: ' + @job_name + CHAR(13) + CHAR(10) +
        'Timestamp: ' + CAST(GETDATE() AS VARCHAR(50)) + CHAR(13) + CHAR(10) +
        'Error: ' + @error_message;
    
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'ETL_Alerts',
        @recipients = 'zahra.123450026@student.itera.ac.id; syahrialdi.123450093@student.itera.ac.id',
        @subject = @subject,
        @body = @body,
        @importance = 'High';
END;
```
## Error Handling & Recovery
### 5.1 Retry Logic
**Transient Error Handling:**

```sql
CREATE PROCEDURE etl.execute_with_retry
    @procedure_name VARCHAR(100),
    @max_retries INT = 3,
    @retry_delay_seconds INT = 60
AS
BEGIN
    DECLARE @attempt INT = 1;
    DECLARE @success BIT = 0;
    
    WHILE @attempt <= @max_retries AND @success = 0
    BEGIN
        BEGIN TRY
            -- Execute target procedure
            EXEC (@procedure_name);
            SET @success = 1;
            PRINT 'Procedure executed successfully on attempt ' + CAST(@attempt AS VARCHAR(10));
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER() IN (1205, 2627, 2601)  -- Deadlock, PK violation, Unique constraint
            BEGIN
                PRINT 'Transient error on attempt ' + CAST(@attempt AS VARCHAR(10)) + ': ' + ERROR_MESSAGE();
                WAITFOR DELAY @retry_delay_seconds;
                SET @attempt = @attempt + 1;
            END
            ELSE
            BEGIN
                -- Non-transient error, don't retry
                THROW;
            END
        END CATCH
    END
    
    IF @success = 0
    BEGIN
        RAISERROR('Procedure failed after %d attempts', 16, 1, @max_retries);
    END
END;
```

### 5.2 Rollback Procedures
**Transaction-based Rollback:**

```sql
CREATE PROCEDURE etl.load_fact_surat_with_rollback
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Step 1: Validate staging data
        EXEC etl.validate_staging_surat;
        
        -- Step 2: Load to fact table
        INSERT INTO fact_surat (...)
        SELECT ... FROM stg.surat_masuk;
        
        -- Step 3: Update metadata
        UPDATE etl_metadata.last_load_date 
        SET last_load = GETDATE() 
        WHERE table_name = 'fact_surat';
        
        -- Step 4: Log success
        INSERT INTO etl_log.job_execution (job_name, status, rows_loaded)
        VALUES ('load_fact_surat', 'Success', @@ROWCOUNT);
        
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        -- Log error
        INSERT INTO etl_log.job_execution (job_name, status, error_message)
        VALUES ('load_fact_surat', 'Failed', ERROR_MESSAGE());
        
        -- Send alert
        EXEC etl.send_failure_alert 'load_fact_surat', ERROR_MESSAGE();
        
        THROW;
    END CATCH
END;
```

### 5.3 Data Recovery Plan
**Scenario 1: Partial Load Failure**
- **Action:** Identify last successful batch, truncate partial data, re-run from last checkpoint
- **Recovery Time:** < 1 hour

**Scenario 2: Data Corruption**
- **Action:** Restore from last known good backup, replay transaction logs
- **Recovery Time:** < 4 hours

**Scenario 3: Full ETL Failure**
- **Action:** Restore entire database from nightly backup, manual data validation
- **Recovery Time:** < 8 hours

**Backup Strategy:**

- **Full backup:** Daily at 2 AM (retention: 30 days)
- **Differential backup:** Every 6 hours (retention: 7 days)
- **Transaction log backup:** Every 15 minutes (retention: 24 hours)
- **Differential backup:** Every 6 hours (retention: 7 days)
- **Transaction log backup:** Every 15 minutes (retention: 24 hours)

## Testing Strategy
### 6.1 Testing Pyramid

           ┌─────────────────┐
          /  End-to-End (5%) /
         /───────────────────/
        /  Integration (25%) /
       /────────────────────/
      /   Unit Tests (70%)  /
     /─────────────────────/

### 6.2 Unit Testing
**Test Transformation Logic:**

```sql  
-- Test: Deduplikasi nomor_surat
CREATE PROCEDURE test.test_deduplicate_surat
AS
BEGIN
    -- Arrange: Insert duplicate test data
    INSERT INTO stg.surat_masuk (nomor_surat, tanggal_diterima)
    VALUES 
        ('001/BAU/2024', '2024-01-01'),
        ('001/BAU/2024', '2024-01-02');  -- Duplicate
    
    -- Act: Run transformation
    EXEC etl.transform_surat;
    
    -- Assert: Check only earliest record remains
    IF (SELECT COUNT(*) FROM stg.surat_masuk WHERE nomor_surat = '001/BAU/2024') = 1
        AND (SELECT tanggal_diterima FROM stg.surat_masuk WHERE nomor_surat = '001/BAU/2024') = '2024-01-01'
    BEGIN
        PRINT 'Test PASSED: Deduplication works correctly';
    END
    ELSE
    BEGIN
        RAISERROR('Test FAILED: Deduplication logic incorrect', 16, 1);
    END
    
    -- Cleanup
    DELETE FROM stg.surat_masuk WHERE nomor_surat = '001/BAU/2024';
END;
```

### 6.3 Integration Testing
**Test End-to-End Data Flow:**

```sql
-- Test: Full ETL pipeline for fact_surat
CREATE PROCEDURE test.test_etl_fact_surat_integration
AS
BEGIN
    -- Arrange: Setup test data
    EXEC test.setup_test_data_surat;
    
    -- Act: Run full ETL
    EXEC etl.load_dim_waktu;
    EXEC etl.load_dim_jenis_surat;
    EXEC etl.load_dim_unit_kerja;
    EXEC etl.load_fact_surat;
    
    -- Assert: Validate results
    DECLARE @source_count INT = (SELECT COUNT(*) FROM stg.surat_masuk);
    DECLARE @target_count INT = (SELECT COUNT(*) FROM fact_surat WHERE tanggal_key = 20240101);
    
    IF @source_count = @target_count
    BEGIN
        PRINT 'Test PASSED: Record count matches';
    END
    ELSE
    BEGIN
        RAISERROR('Test FAILED: Record count mismatch. Source: %d, Target: %d', 16, 1, @source_count, @target_count);
    END
    
    -- Cleanup
    EXEC test.cleanup_test_data;
END;
```

### 6.4 UAT (User Acceptance Testing)
**Test Cases:**
1. **Data Accuracy Test**
- Compare dashboard metrics with source system reports
- Validate KPI calculations
- Acceptance Criteria: <1% variance

2. **Performance Test**
- Query response time for standard reports
- Acceptance Criteria: <5 seconds for all dashboard queries

3. **Data Freshness Test**
- Verify latest data availability after ETL run
- Acceptance Criteria: Data updated by 6 AM daily

4. **Historical Trending Test**
- Validate month-over-month and year-over-year calculations
- Acceptance Criteria: Matches manual calculation

## Operational Procedures
### 7.1 ETL Schedule
|Job Name|Frequency|Start Time|Duration (Est.)|Dependencies|
|-|-|-|-|-|
|extract_all_sources|Daily|1:00 AM|10 min|None|
|load_dim_waktu|Weekly|1:15 AM|2 min|extract_all_sources|
|load_dim_jenis_surat|Weekly|1:17 AM|1 min|extract_all_sources|
|load_dim_jenis_layanan|Weekly|1:18 AM|1 min|extract_all_sources|
|load_dim_lokasi|Monthly|1:19 AM|1 min|extract_all_sources|
|load_dim_unit_kerja|Weekly|1:20 AM|2 min|extract_all_sources|
|load_dim_pegawai|Daily|1:22 AM|3 min|load_dim_unit_kerja|
|load_dim_barang|Weekly|1:25 AM|2 min|extract_all_sources|
|load_fact_surat|Daily|1:30 AM|5 min|All dimensions loaded|
|load_fact_layanan|Daily|1:35 AM|3 min|All dimensions loaded|
|load_fact_aset|Monthly (last day)|1:40 AM|10 min|All dimensions loaded|
|rebuild_indexes|Daily|2:00 AM|15 min|All loads complete|
|update_statistics|Daily|2:15 AM|10 min|rebuild_indexes|
|backup_database|Daily|2:30 AM|20 min|update_statistics|
**Total ETL Window: 1:00 AM - 3:00 AM (2 hours)**

### 7.2 Change Management Process
**Code Changes:**
1. Developer creates feature branch from main
2. Develop and test locally in DEV environment
3. Create Pull Request (PR) on GitHub
4. Code review by team lead (Aldi)
5. Merge to main after approval
6. Deploy to TEST environment
7. Integration testing in TEST
8. Stakeholder UAT
9. Deploy to PROD (schedule on weekend/low-traffic period)

**Documentation Updates:**
1. Update relevant .md files in /docs
2. Update data dictionary if schema changes
3. Update operations manual for new procedures

### 7.3 Incident Response Workflow
**Severity Levels:**

|Level|Description|Response Time|Escalation|
|-|-|-|-|
|P1 - Critical|ETL completely failed, no data available|Immediate|Team lead + stakeholders|
|P2 - High|Partial failure, some data missing|Within 2 hours|Team lead|
|P3 - Medium|Data quality issues, warnings|Within 24 hours|ETL developer|
|P4 - Low|Minor issues, informational|Next business day|ETL developer|
**Response Steps:**
1. **Detect:** Automated alert or user report
2. **Assess:** Check logs, determine severity
3. **Contain:** Stop affected jobs, prevent cascade
4. **Investigate:** Root cause analysis
5. **Resolve:** Apply fix, test in DEV/TEST environment
6. **Deploy:** Push to PROD if validated
7. **Verify:** Confirm resolution
8. **Document:** Update incident log, post-mortem if P1/P2

## Risk Management
### 8.1 Risk Register
|Risk ID|Risk Description|Probability|Impact|Mitigation Strategy|Owner|
|-|-|-|-|-|-|
|R-01|Source system unavailable during ETL window|Medium|High|Implement retry logic, shift ETL window if needed|Zahra|
|R-02|Data volume exceeds capacity estimates|Low|High|Monitor growth, implement archival strategy|Aldi|
|R-03|ETL job timeout due to performance|Medium|Medium|Optimize queries, implement parallel processing|Zahra|
|R-04|Data quality degradation in source|Medium|High|Implement robust validation, alert on anomalies|Zahra|
|R-05|Team member unavailability|Low|Medium|Cross-training, comprehensive documentation|Aldi|
|R-06|Infrastructure failure (Azure VM)|Low|Critical|Automated backups, documented recovery procedures|Aldi|
|R-07|Schema changes in source systems|Medium|High|Version control, change notification process|Zahra|

### 8.2 Contingency Plans
**Plan A: Primary ETL Failure**
- **Trigger:** ETL job fails 3 consecutive times
- **Action:**
    1. Alert team lead immediately
    2. Switch to manual data extraction if critical
    3. Investigate root cause in parallel
    4. Deploy hotfix if identified
    5. Run catch-up load after resolution

**Plan B: Azure VM Unavailable**
- **Trigger:** Cannot connect to database for >15 minutes
- **Action:**
    1. Check Azure portal for outage/maintenance
    2. Contact Azure support if unplanned
    3. Communicate downtime to stakeholders
    4. Restore from backup to alternate VM if extended outage
    5. Update DNS/connection strings if needed

**Plan C: Data Corruption Detected**
- **Trigger:** Data quality checks fail beyond threshold
- **Action:**
    1. Immediately stop all ETL jobs
    2. Identify corruption scope (which tables/dates)
    3. Restore affected tables from last known good backup
    4. Validate restored data
    5. Re-run ETL for affected period
    6. Root cause analysis and preventive measures


## Success Metrics
### 9.1 KPIs for ETL Operations
|Metric|Target|Measurement Frequency|Current Status|
|-|-|-|-|
|ETL Success Rate|>99%|Daily|TBD|
|Data Quality Score|>95%|Daily|TBD|
|ETL Duration|<30 minutes|Daily|TBD|
|Query Response Time|<5 seconds|Weekly|TBD|
|Data Freshness|<6 hours|Daily|TBD|
|Incident Resolution Time|P1: <2 hours, P2: <24 hours|Per incident|TBD|
|Documentation Coverage|100%|Monthly|100%|
### 9.2 Reporting & Review Cadence
**Daily:**
- ETL job status review (automated dashboard)
- Data quality metrics check
- Error log review (if any failures)
**Weekly:**
- Performance trend analysis
- Capacity utilization review
- Outstanding issues triage
**Monthly:**
- Comprehensive ETL health report
- Stakeholder review meeting
- KPI dashboard presentation
- Documentation updates
**Quarterly:**
- Architecture review (scalability, optimization opportunities)
- Risk register update
- Team training & knowledge sharing
## Appendix
#### A.1 ETL Procedure Naming Convention
|Pattern|Example|Purpose|
|-|-|-|
|etl.extract_<source>|etl.extract_simaster|Data extraction|
|etl.load_dim_<dimension>|etl.load_dim_waktu|Dimension load|
|etl.load_fact_<fact>|etl.load_fact_surat|Fact load|
|etl.transform_<entity>|etl.transform_surat|Data transformation|
|etl.validate_<entity>|etl.validate_surat|Data validation|
|test.test_<procedure>|test.test_deduplicate_surat|Unit test|
### A.2 Related Documents
- Source-to-Target Mapping: source-to-target-mapping.md
- Data Sources: ../01-requirements/data-sources.md
- ERD: ERD.svg
- Data Dictionary: data-dictionary.xlsx
- Operations Manual: ../03-implementation/operations-manual.pdf

### A.3 Contact & Escalation
**ETL Development Team:**
- **Zahra Putri Salsabilla** - ETL Developer Lead
    - **Email:** zahra.123450026@student.itera.ac.id
    - **Role:** ETL development, troubleshooting, performance optimization
 
- **Syahrialdi Rachim Akbar** - Project Lead & Database Designer
    - **Email:** syahrialdi.123450093@student.itera.ac.id
    - **Role:** Architecture decisions, escalation point, stakeholder communication


Prepared by: Kelompok 19 - Tugas Besar Pergudangan Data
Last Updated: 17 November 2025, 16:04 WIB
Next Review: 19 November 2025
