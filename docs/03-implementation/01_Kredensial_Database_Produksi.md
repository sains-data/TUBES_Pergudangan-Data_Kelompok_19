# Kredensial Database Produksi - Mission 3

**Proyek:** Data Mart BAU ITERA  
**Tim:** Kelompok 19 (Aldi, Zahra, Feby)  
**Tanggal:** 1 Desember 2025  
**Status:** Deployment Produksi

---

## Informasi Server Database

| Properti | Nilai |
|----------|-------|
| **Host/Alamat IP** | 104.43.93.28 |
| **Port** | 5432 |
| **Engine Database** | PostgreSQL 14.19 |
| **Nama Database** | datamart_bau_itera |
| **Lingkungan** | Azure VM (vm-kelompok-19) |
| **Platform Deployment** | Docker (postgres:14) |

---

## Akun Pengguna & Kredensial

### 1. Pengguna Aplikasi (Operasi Data)
```
Username: datamart_user
Password: Kelompok19@2025!
Tujuan: Pengguna utama untuk operasi ETL dan akses aplikasi
Izin: Akses penuh ke schemas stg, dim, fact, etl, dw, analytics, reports
```

### 2. Pengguna Business Intelligence
```
Username: user_bi
Password: BiPassItera2025!
Tujuan: Akses read-only untuk query BI/Analytics
Role: role_analyst
Izin: SELECT pada schemas analytics, reports, dim, fact
```

### 3. Pengguna Administrator ETL
```
Username: user_etl
Password: EtlPassItera2025!
Tujuan: Eksekusi pipeline ETL dan pemeliharaan data
Role: role_etl_admin
Izin: Akses penuh ke semua schemas (stg, dim, fact, etl_log, dw, analytics)
```

### 4. Superuser PostgreSQL
```
Username: postgres
Password: Kelompok19@2025!
Tujuan: Administrasi database dan pemeliharaan
Izin: Privilege superuser
```

---

## Contoh Connection String

### Untuk Aplikasi ETL
```
postgresql://datamart_user:Kelompok19@2025!@104.43.93.28:5432/datamart_bau_itera
```

### Untuk Tools BI (Tableau/Power BI)
```
postgresql://user_bi:BiPassItera2025!@104.43.93.28:5432/datamart_bau_itera
```

### Untuk Tugas Administratif
```
postgresql://postgres:Kelompok19@2025!@104.43.93.28:5432/datamart_bau_itera
```

---

## Contoh Koneksi Command Line

### Koneksi sebagai Pengguna Operasi Data
```bash
psql -h 104.43.93.28 -U datamart_user -d datamart_bau_itera
```

### Koneksi sebagai Pengguna BI
```bash
psql -h 104.43.93.28 -U user_bi -d datamart_bau_itera
```

### Koneksi sebagai Administrator
```bash
psql -h 104.43.93.28 -U postgres -d datamart_bau_itera
```

---

## Gambaran Arsitektur Database

### Schemas yang Dibuat
- **stg** - Tabel staging untuk data mentah
- **dim** - Tabel dimensi untuk analytics
- **fact** - Tabel fakta untuk metrik
- **etl** - Prosedur dan fungsi ETL
- **etl_log** - Tabel logging dan audit
- **dw** - Metadata data warehouse
- **analytics** - Views analitik untuk reporting
- **reports** - Views spesifik laporan
- **public** - Schema sistem (default PostgreSQL)

### Tabel Utama
- **dim.dim_waktu** - Dimensi waktu (1 baris)
- **dim.dim_unit_kerja** - Unit organisasi (1 baris default)
- **dim.dim_pegawai** - Karyawan (1 baris default)
- **dim.dim_jenis_surat** - Jenis dokumen (6 baris referensi)
- **dim.dim_jenis_layanan** - Jenis layanan (6 baris referensi)
- **dim.dim_barang** - Aset/Barang (1 baris default)
- **dim.dim_lokasi** - Lokasi (1 baris default)
- **fact.fact_surat** - Transaksi dokumen (kosong)
- **fact.fact_layanan** - Transaksi layanan (kosong)
- **fact.fact_aset** - Transaksi aset (kosong)

---

## Views Analitik yang Tersedia

### Views Dashboard Eksekutif
- **analytics.vw_surat_summary** - Statistik ringkasan dokumen
- **analytics.vw_layanan_performance** - Metrik kinerja layanan
- **analytics.vw_aset_overview** - Gambaran umum inventori aset
- **reports.vw_executive_dashboard** - KPI tingkat eksekutif
- **reports.vw_operational_dashboard** - Metrik operasional

---

## Keamanan & Kontrol Akses

### Role-Based Access Control (RBAC)

#### role_analyst (Baca-Saja)
- SELECT pada schemas dim, fact, analytics, reports
- Tanpa izin write/delete
- Ditugaskan ke: user_bi

#### role_etl_admin (Penuh)
- Privilege penuh pada semua schemas
- Dapat mengeksekusi procedures dan functions
- Dapat mengelola tabel staging
- Ditugaskan ke: user_etl

### Enkripsi & Kepatuhan
- SSL/TLS diaktifkan untuk koneksi remote
- Password harus mengikuti standar enterprise
- Tidak ada kredensial hardcoded di code repository
- Audit logging diaktifkan pada semua transaksi

---

## Informasi Backup & Recovery

### Lokasi Backup
- Docker volume: postgres-datamart-data
- Backup manual direkomendasikan setiap hari

### Prosedur Recovery
1. Hentikan layanan PostgreSQL
2. Restore dari backup
3. Restart PostgreSQL
4. Verifikasi integritas data

### Perintah Backup
```bash
pg_dump -h 104.43.93.28 -U postgres -d datamart_bau_itera > backup_datamart_$(date +%Y%m%d).sql
```

### Perintah Restore
```bash
psql -h 104.43.93.28 -U postgres -d datamart_bau_itera < backup_datamart_YYYYMMDD.sql
```

---

## Pemeliharaan & Dukungan

### Administrasi Database
- **Kontak Admin:** Aldi (Project Lead)
- **Administrator ETL:** Zahra
- **Developer BI:** Feby

### Poin Monitoring
- Status connection pool
- Penggunaan disk space
- Kinerja query
- Kesehatan index
- Status backup

### Informasi Kontak Darurat
- Project Lead (Aldi): Desain database & arsitektur
- ETL Developer (Zahra): Masalah data pipeline
- BI Developer (Feby): Kinerja query & analytics

---

## Catatan Penting

⚠️ **Peringatan Keamanan:**
- Jangan pernah commit password ke version control
- Gunakan environment variables untuk production deployment
- Rotasi password setiap kuartal
- Batasi akses jaringan menggunakan firewall rules
- Aktifkan monitoring dan alerting

⚠️ **Rekomendasi Kinerja:**
- Buat indexes pada foreign keys
- Monitor slow query log
- Gunakan ANALYZE secara berkala untuk update statistik
- Pertimbangkan table partitioning untuk fact tables besar (masa depan)

⚠️ **Kepatuhan:**
- Semua akses tercatat di tables etl_log dan dw
- Audit trail diaktifkan via audit functions
- Data masking tersedia untuk field sensitif
- Retensi backup: minimum 30 hari

---

**Terakhir Diperbarui:** 1 Desember 2025  
**Versi:** 1.0  
**Status:** APPROVED FOR PRODUCTION
