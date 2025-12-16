# Manual Operasional - Mission 3

**Proyek:** Data Mart BAU ITERA  
**Tim:** Kelompok 19 (Aldi, Zahra, Feby)  
**Tanggal:** 1 Desember 2025  
**Status:** Operational

---

## 📋 Panduan Cepat

### Koneksi Database
```bash
# Pengguna Operasi
psql -h 104.43.93.28 -U datamart_user -d datamart_bau_itera

# Pengguna BI
psql -h 104.43.93.28 -U user_bi -d datamart_bau_itera

# Admin
psql -h 104.43.93.28 -U postgres -d datamart_bau_itera
```

### Informasi Server
- **Host:** 104.43.93.28
- **Port:** 5432
- **Database:** datamart_bau_itera
- **Engine:** PostgreSQL 14.19

---

## 🚀 Startup Checklist

Lakukan setiap pagi sebelum operasional:

- [ ] Verifikasi Docker container running
  ```bash
  docker ps | grep postgres
  ```

- [ ] Test database connectivity
  ```bash
  psql -h 104.43.93.28 -U datamart_user -d datamart_bau_itera -c "SELECT 1;"
  ```

- [ ] Check disk space
  ```bash
  df -h
  # Pastikan > 20% free space
  ```

- [ ] Review error log
  ```bash
  # Check etl_log.error_logs table
  SELECT * FROM etl_log.error_logs ORDER BY created_at DESC LIMIT 10;
  ```

- [ ] Verify backup status
  ```bash
  # Check backup_log table
  SELECT * FROM dw.backup_log ORDER BY backup_time DESC LIMIT 1;
  ```

**Estimasi Waktu:** 15-20 menit

---

## 🔄 ETL Pipeline Execution

### Manual ETL Execution

**Jalankan Master ETL:**
```sql
CALL etl.master_etl();
```

**Monitor ETL Execution:**
```sql
SELECT * FROM etl_log.execution_history 
ORDER BY execution_time DESC LIMIT 5;
```

**Check ETL Errors:**
```sql
SELECT * FROM etl_log.error_logs 
WHERE error_date = CURRENT_DATE
ORDER BY error_time DESC;
```

### ETL Procedure Execution Order
1. load_dim_waktu() - Time dimension
2. load_dim_unit_kerja() - Organizational units
3. load_dim_pegawai() - Employees
4. load_dim_jenis_surat() - Document types
5. load_dim_layanan() - Service types
6. Fact tables (from staging)

---

## 📊 Daily Operations

### Pagi (08:00-09:00)
- Start system & run startup checklist
- Execute ETL pipeline
- Verify all loads completed successfully
- Check error logs

### Siang (12:00-13:00)
- Monitor query performance
- Check connection pool status
- Review any operational issues
- Prepare reports if needed

### Sore (16:00-17:00)
- Final data validation
- Verify backup execution
- Document any issues encountered
- Close daily operations

---

## 🔍 Monitoring & Health Checks

### Connection Pool Status
```sql
SELECT datname, count(*) as connections
FROM pg_stat_activity
GROUP BY datname;

-- Expected: < 10 connections
```

### Disk Space Monitoring
```bash
df -h
# Alert if < 20% free space
```

### Query Performance
```sql
-- Find slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC;
```

### Index Health
```sql
-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0;
-- WARNING: Unused indexes should be reviewed
```

### Table Statistics
```sql
-- Analyze table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 🚨 Alert Thresholds

| Metrik | Threshold | Aksi |
|--------|-----------|------|
| Disk Usage | > 70% | Perhatian diperlukan |
| Disk Usage | > 90% | Alert kritis |
| Connections | > 80% max | Review aktif |
| Query Time | > 30 seconds | Investigate & optimize |
| CPU Usage | > 80% | Monitor ketat |
| Error Rate | > 5% | Urgent review |

---

## 💾 Backup & Recovery

### Manual Backup
```bash
# Full database backup
pg_dump -h 104.43.93.28 -U postgres datamart_bau_itera > backup_$(date +%Y%m%d_%H%M%S).sql

# Compressed backup
pg_dump -h 104.43.93.28 -U postgres datamart_bau_itera | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Automated Backup (Cron Job)
```bash
# Add to crontab (run daily at 2 AM)
0 2 * * * /home/azureuser19/backup_datamart.sh
```

### Backup Verification
```bash
# Check last backup
ls -lh backup_*.sql | tail -1

# Verify backup integrity
pg_restore -l backup_YYYYMMDD.sql | head -20
```

### Restore from Backup

**Partial Restore (Single Table):**
```bash
pg_restore -d datamart_bau_itera -t table_name backup_YYYYMMDD.sql
```

**Full Database Restore:**
```bash
# Option 1: Using psql
psql -U postgres -d datamart_bau_itera < backup_YYYYMMDD.sql

# Option 2: Using pg_restore
pg_restore -d datamart_bau_itera backup_YYYYMMDD.dump
```

---

## 🔐 User Management

### Create New User
```sql
CREATE USER new_user WITH PASSWORD 'secure_password';
GRANT role_analyst TO new_user;
```

### Grant Permissions
```sql
-- Grant SELECT on schema
GRANT USAGE ON SCHEMA analytics TO new_user;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO new_user;

-- Grant EXECUTE on procedures
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA etl TO new_user;
```

### Revoke Permissions
```sql
REVOKE SELECT ON ALL TABLES IN SCHEMA analytics FROM old_user;
```

### Change User Password
```sql
ALTER USER user_name WITH PASSWORD 'new_password';
```

### List All Users
```sql
SELECT usename FROM pg_user;
```

---

## 🔧 Common Troubleshooting

### Issue 1: Cannot Connect to Database

**Symptoms:** Connection refused error

**Solution:**
```bash
# Check if Docker container is running
docker ps | grep postgres

# Start container if stopped
docker start postgres-datamart

# Verify port is listening
netstat -tlnp | grep 5432

# Test connection
psql -h 104.43.93.28 -U datamart_user -d datamart_bau_itera
```

### Issue 2: Slow Query Performance

**Symptoms:** Queries taking > 30 seconds

**Solution:**
```sql
-- Analyze query plan
EXPLAIN ANALYZE SELECT ...;

-- Update table statistics
ANALYZE table_name;

-- Check missing indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0;

-- Create indexes if needed
CREATE INDEX idx_name ON table_name(column_name);
```

### Issue 3: Disk Space Full

**Symptoms:** Cannot insert data error

**Solution:**
```bash
# Check disk usage
df -h

# Find large files
find / -type f -size +1G 2>/dev/null

# Clean old backups
rm backup_*.sql  # Keep only recent ones

# Check Docker volume usage
docker volume ls
```

### Issue 4: ETL Pipeline Failed

**Symptoms:** ETL procedures return errors

**Solution:**
```sql
-- Check error logs
SELECT * FROM etl_log.error_logs 
WHERE error_date = CURRENT_DATE
ORDER BY error_time DESC LIMIT 5;

-- Check job logs
SELECT * FROM etl_log.job_logs 
WHERE job_date = CURRENT_DATE
ORDER BY job_time DESC;

-- Re-run specific procedure
CALL etl.load_dim_waktu();
```

### Issue 5: Authentication Failed

**Symptoms:** Password denied error

**Solution:**
```sql
-- Reset user password (as admin)
ALTER USER user_name WITH PASSWORD 'new_password';

-- Verify user exists
SELECT usename FROM pg_user WHERE usename = 'user_name';

-- Check user roles
SELECT * FROM pg_user_functions WHERE usename = 'user_name';
```

---

## 📈 Performance Optimization

### Index Analysis
```sql
-- Find unused indexes
SELECT schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND indexname NOT LIKE 'pg_toast%';
```

### Query Optimization
```sql
-- Find slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
WHERE mean_exec_time > 100
ORDER BY mean_exec_time DESC LIMIT 10;

-- Get query execution plan
EXPLAIN ANALYZE SELECT ...;
```

### Table Maintenance
```sql
-- Vacuum analysis
VACUUM ANALYZE table_name;

-- Reindex table
REINDEX TABLE table_name;
```

---

## 📊 Data Quality Checks

### Data Validation Queries

**Check Null Values:**
```sql
SELECT COUNT(*) FROM dim.dim_pegawai WHERE id IS NULL;
-- Expected: 0
```

**Check Duplicates:**
```sql
SELECT id, COUNT(*) FROM dim.dim_surat 
GROUP BY id HAVING COUNT(*) > 1;
-- Expected: 0
```

**Check Referential Integrity:**
```sql
SELECT f.surat_id FROM fact.fact_surat f
LEFT JOIN dim.dim_surat d ON f.surat_id = d.id
WHERE d.id IS NULL;
-- Expected: 0
```

**Overall Data Quality Score:**
```sql
SELECT 
  ROUND(100 * (1 - (errors / NULLIF(total_records, 0))), 1) as quality_score
FROM (
  SELECT COUNT(*) as total_records, 
         (SELECT COUNT(*) FROM etl_log.error_logs) as errors
  FROM fact.fact_surat
) sq;
-- Target: > 94%
```

---

## 📞 Support Contacts

### Tim Kelompok 19
- **Aldi** - Database Lead & Infrastructure
- **Zahra** - ETL Development & Troubleshooting
- **Feby** - BI & Analytics Support

### Support Hours
- Monday-Friday: 09:00-17:00 WIB
- Response Time: < 24 hours
- Emergency: Contact Project Lead

---

## 📝 Operational Log Template

### Daily Operations Log
```
Date: ________
Shift: Morning / Afternoon / Evening

✓ Startup Checklist Completed:
  - Database connectivity: YES / NO
  - Disk space available: ___%
  - Error log review: No issues / Issues found
  
✓ ETL Pipeline Execution:
  - Status: Success / Failed
  - Records loaded: ______
  - Errors encountered: ______

✓ System Status:
  - Connections active: ______
  - Query performance: Normal / Slow
  - Backups: OK / Failed

✓ Notes:
  _________________________________
  _________________________________

Operator: _____________ Time: ______
```

---

## ✅ Monthly Maintenance Checklist

- [ ] Full database backup verification
- [ ] Security audit (user accounts review)
- [ ] Performance tuning analysis
- [ ] Index efficiency review
- [ ] Storage capacity planning
- [ ] Disaster recovery test
- [ ] Documentation updates
- [ ] Team meeting & knowledge sharing

---

## 🎓 Training & Knowledge

### Quick Start for New Users
1. Read this manual (sections 1-3)
2. Review database credentials
3. Try example queries
4. Execute sample ETL procedure
5. Monitor execution results

### Advanced Topics
1. Query optimization techniques
2. Index design best practices
3. Backup & recovery procedures
4. Security configuration
5. Performance monitoring

---

**Status:** ✅ OPERATIONAL & READY  
**Last Updated:** 1 Desember 2025  
**Version:** 1.0 - Production Manual
