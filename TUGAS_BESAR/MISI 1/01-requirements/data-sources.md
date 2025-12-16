# Data Source Inventory - Biro Akademik Umum ITERA

**Dokumen Version:** 2.0  
**Last Updated:** 11 November 2025  
**Updated by:** Kelompok 19 - Aldi, Zahra, Feby

---

## 1. Sistem Persuratan (SIMASTER/E-Office)

**Deskripsi:** Aplikasi web untuk mengelola surat masuk dan keluar institusi

**Detail Teknis:**
- Platform: Diasumsikan berbasis web dengan database SQL Server
- Database: SIMASTER_DB
- Tabel utama: 
  - tbl_surat_masuk
  - tbl_surat_keluar
  - tbl_disposisi
  - tbl_tracking_surat

**Data Available:**
- Periode: Januari 2021 - Present (4 tahun data)
- Volume estimasi: ~18,000 surat (rata-rata 400 surat/bulan)
- Update frequency: Real-time (setiap ada surat baru)
- Growth rate: 400-450 surat/bulan

### 1.1 Struktur Data (tbl_surat_masuk)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_surat              | VARCHAR(30)  | SRT/IN/2024/001           |
| nomor_surat           | VARCHAR(50)  | 123/UN31/AK/2024          |
| tanggal_surat         | DATE         | 2024-10-15                |
| tanggal_diterima      | DATE         | 2024-10-16                |
| pengirim              | VARCHAR(200) | Direktorat Akademik       |
| perihal               | TEXT         | Undangan Rapat Koordinasi |
| jenis_surat_id        | INT          | 3                         |
| status                | VARCHAR(20)  | Selesai                   |
| disposisi_ke          | VARCHAR(100) | Kabag Umum                |
| file_path             | VARCHAR(255) | /uploads/2024/10/srt001.pdf |

### 1.2 Struktur Data (tbl_surat_keluar)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_surat              | VARCHAR(30)  | SRT/OUT/2024/001          |
| nomor_surat           | VARCHAR(50)  | 456/UN31/AK/2024          |
| tanggal_surat         | DATE         | 2024-10-20                |
| tujuan                | VARCHAR(200) | Kementerian Pendidikan    |
| perihal               | TEXT         | Laporan Kegiatan          |
| jenis_surat_id        | INT          | 5                         |
| status                | VARCHAR(20)  | Terkirim                  |
| penandatangan         | VARCHAR(100) | Rektor                    |
| file_path             | VARCHAR(255) | /uploads/2024/10/srt002.pdf |

### 1.3 Struktur Data (tbl_disposisi)

**[TAMBAHAN BARU - Critical untuk KPI Waktu Proses]**

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_disposisi          | VARCHAR(30)  | DISP/2024/00123           |
| id_surat              | VARCHAR(30)  | SRT/IN/2024/001           |
| tanggal_disposisi     | DATETIME     | 2024-10-16 09:30:00       |
| dari_pegawai_id       | INT          | 101                       |
| kepada_pegawai_id     | INT          | 205                       |
| instruksi             | TEXT         | Tindak lanjuti segera     |
| status                | VARCHAR(20)  | Selesai                   |
| tanggal_selesai       | DATETIME     | 2024-10-18 15:00:00       |
| catatan               | TEXT         | Sudah diproses            |

**Data Available:**
- Periode: Januari 2021 - Present
- Volume estimasi: ~25,000 disposisi (rata-rata 1.4 disposisi per surat)
- Update frequency: Real-time

**Data Quality:**
- Completeness: 95% (5% tanggal_selesai NULL untuk status "Pending")
- Known issues: None significant

### 1.4 Reference Table: Jenis Surat

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id                    | INT          | 1                         |
| kode_jenis            | VARCHAR(10)  | UM                        |
| nama_jenis            | VARCHAR(100) | Surat Undangan            |
| kategori              | VARCHAR(50)  | Internal                  |
| sla_hari              | INT          | 3                         |

**Data Quality:**
- Completeness: 100%
- Known issues: 
  - Duplikasi nomor surat: ~1% (estimasi 180 kasus)
  - Kategori tidak standar: ~12% (perlu mapping)

---

## 2. Sistem Inventaris & Aset (SIMAK/SIPANDU)

**Deskripsi:** Database untuk mengelola inventaris barang dan aset institusi

**Detail Teknis:**
- Platform: Diasumsikan aplikasi desktop/web dengan database SQL Server
- Database: INVENTARIS_DB
- Tabel utama:
  - tbl_inventaris
  - tbl_pemeliharaan
  - tbl_pengadaan

**Data Available:**
- Periode: Januari 2020 - Present (5 tahun data)
- Volume estimasi: ~2,500 item barang
- Update frequency: Monthly (untuk inventaris), Event-based (untuk pemeliharaan)
- Growth rate: 40-50 item baru/tahun

### 2.1 Struktur Data (tbl_inventaris)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_barang             | INT          | 1001                      |
| kode_barang           | VARCHAR(30)  | INV/COMP/2024/001         |
| nama_barang           | VARCHAR(200) | Laptop Dell Latitude 5420 |
| kategori              | VARCHAR(50)  | Komputer                  |
| tanggal_pengadaan     | DATE         | 2024-03-15                |
| nilai_perolehan       | DECIMAL(15,2)| 12500000.00               |
| kondisi               | VARCHAR(20)  | Baik                      |
| lokasi_id             | INT          | 15                        |
| unit_kerja_id         | INT          | 5                         |
| status_label          | VARCHAR(20)  | Terlabeli                 |
| tanggal_snapshot      | DATE         | 2024-10-31                |

### 2.2 Struktur Data (tbl_pemeliharaan)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_pemeliharaan       | INT          | 5001                      |
| kode_barang           | VARCHAR(30)  | INV/COMP/2024/001         |
| tanggal_pemeliharaan  | DATE         | 2024-09-10                |
| jenis_pemeliharaan    | VARCHAR(50)  | Service Rutin             |
| biaya                 | DECIMAL(15,2)| 500000.00                 |
| vendor                | VARCHAR(200) | PT Teknologi Prima        |
| status                | VARCHAR(20)  | Selesai                   |

### 2.3 Struktur Data (tbl_pengadaan)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_pengadaan          | INT          | 3001                      |
| nomor_pengadaan       | VARCHAR(30)  | PGD/2024/001              |
| tanggal_pengadaan     | DATE         | 2024-05-20                |
| vendor                | VARCHAR(200) | PT Sukses Jaya            |
| total_item            | INT          | 15                        |
| total_nilai           | DECIMAL(15,2)| 50000000.00               |
| unit_kerja_id         | INT          | 5                         |
| status                | VARCHAR(20)  | Selesai                   |

### 2.4 Reference Table: Lokasi

**[TAMBAHAN BARU - untuk tracking aset per gedung/ruangan]**

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_lokasi             | INT          | 1                         |
| gedung                | VARCHAR(50)  | Gedung Rektorat           |
| lantai                | INT          | 2                         |
| ruangan               | VARCHAR(50)  | R.201                     |
| kapasitas             | INT          | 20                        |
| pic_nama              | VARCHAR(100) | Agus Santoso              |

**Data Quality:**
- Completeness: 92% (8% nilai_perolehan NULL)
- Known issues:
  - Kategori tidak standar: ~12% (PC, Laptop, Komputer → perlu standardisasi)
  - Duplikasi kode barang: <1%

---

## 3. Sistem Kepegawaian (SIMPEG)

**Deskripsi:** Database pegawai dan absensi

**Detail Teknis:**
- Platform: Diasumsikan aplikasi web dengan database SQL Server
- Database: SIMPEG_DB
- Tabel utama:
  - tbl_pegawai
  - tbl_absensi
  - tbl_pelatihan

**Data Available:**
- Periode: Januari 2019 - Present (6 tahun data)
- Volume estimasi: ~350 pegawai, ~90,000 records absensi
- Update frequency: Daily (absensi), Monthly (data pegawai)

### 3.1 Struktur Data (tbl_pegawai)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_pegawai            | INT          | 1                         |
| nip                   | VARCHAR(20)  | 199001012020011001        |
| nama                  | VARCHAR(100) | Dr. Ahmad Fauzi           |
| jabatan               | VARCHAR(100) | Kepala Bagian Umum        |
| unit_kerja_id         | INT          | 5                         |
| status_kepegawaian    | VARCHAR(30)  | PNS                       |
| tanggal_masuk         | DATE         | 2020-01-15                |
| email                 | VARCHAR(100) | ahmad.fauzi@itera.ac.id   |
| no_hp                 | VARCHAR(15)  | 081234567890              |

### 3.2 Struktur Data (tbl_absensi)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_absensi            | INT          | 100001                    |
| nip                   | VARCHAR(20)  | 199001012020011001        |
| tanggal               | DATE         | 2024-10-15                |
| waktu_masuk           | TIME         | 07:45:00                  |
| waktu_keluar          | TIME         | 16:30:00                  |
| status_kehadiran      | VARCHAR(20)  | Hadir                     |
| jam_kerja             | DECIMAL(4,2) | 8.75                      |

### 3.3 Struktur Data (tbl_pelatihan)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_pelatihan          | INT          | 2001                      |
| nip                   | VARCHAR(20)  | 199001012020011001        |
| nama_pelatihan        | VARCHAR(200) | Manajemen Arsip Digital   |
| tanggal_pelatihan     | DATE         | 2024-08-20                |
| durasi_jam            | INT          | 16                        |
| penyelenggara         | VARCHAR(200) | ITERA - PSDM              |
| status                | VARCHAR(20)  | Selesai                   |

**Data Quality:**
- Completeness: 100%
- Known issues: None significant

---

## 4. Sistem Permintaan Layanan (Service Desk/Manual)

**Deskripsi:** Tracking permintaan layanan administrasi dari civitas akademika

**Detail Teknis:**
- Platform: Diasumsikan Google Form/Excel → to be digitized
- Database: LAYANAN_DB
- Tabel utama:
  - tbl_permintaan_layanan
  - ref_jenis_layanan

**Data Available:**
- Periode: Januari 2022 - Present (3 tahun data)
- Volume estimasi: ~5,400 permintaan (rata-rata 150/bulan)
- Update frequency: Real-time
- Growth rate: 150-180 permintaan/bulan

### 4.1 Struktur Data (tbl_permintaan_layanan)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_permintaan         | INT          | 10001                     |
| nomor_tiket           | VARCHAR(30)  | TKT/2024/00123            |
| timestamp_submit      | DATETIME     | 2024-10-15 09:00:00       |
| pemohon_nama          | VARCHAR(100) | Budi Santoso              |
| pemohon_nip           | VARCHAR(20)  | 199501012021011001        |
| jenis_layanan_id      | INT          | 5                         |
| deskripsi             | TEXT         | Permohonan legalisir      |
| unit_tujuan_id        | INT          | 5                         |
| status_penyelesaian   | VARCHAR(20)  | Selesai                   |
| tanggal_selesai       | DATETIME     | 2024-10-16 14:30:00       |
| rating_kepuasan       | DECIMAL(2,1) | 4.5                       |
| feedback              | TEXT         | Pelayanan cepat           |

**[FIELD BARU]:**
- `rating_kepuasan`: Rating 1.0-5.0 untuk tracking kepuasan layanan
- `feedback`: Optional feedback dari pemohon

### 4.2 Reference Table: Jenis Layanan

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id                    | INT          | 1                         |
| kode_layanan          | VARCHAR(10)  | LEG                       |
| nama_layanan          | VARCHAR(100) | Legalisir Dokumen         |
| kategori              | VARCHAR(50)  | Administrasi Akademik     |
| is_komplain           | BIT          | 0                         |
| sla_hari              | INT          | 2                         |

**[FIELD BARU]:**
- `is_komplain`: Boolean flag (1 = Komplain, 0 = Request biasa)
- `sla_hari`: Target penyelesaian dalam hari kerja

**Data Quality:**
- Completeness: 88% (12% rating_kepuasan NULL)
- Known issues: 
  - Kategori layanan tidak standar: ~10%
  - Timestamp submit vs selesai inconsistent: ~5%

---

## 5. Sistem Monitoring Kinerja

**[DATA SOURCE BARU - Critical untuk KPI Monitoring & Evaluasi]**

**Deskripsi:** Database untuk monitoring dan pelaporan kinerja bulanan per unit kerja

**Detail Teknis:**
- Platform: Excel/Manual reporting → to be digitized to database
- Database: MONITORING_DB
- Tabel utama:
  - tbl_laporan_kinerja

**Data Available:**
- Periode: Januari 2023 - Present (2 tahun data)
- Volume estimasi: ~480 laporan (20 unit × 24 bulan)
- Update frequency: Monthly (due by 5th of next month)
- Growth rate: 20 laporan/bulan (1 per unit)

### 5.1 Struktur Data (tbl_laporan_kinerja)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_laporan            | INT          | 1                         |
| periode               | DATE         | 2024-10-01                |
| unit_kerja_id         | INT          | 5                         |
| target_layanan        | INT          | 100                       |
| realisasi_layanan     | INT          | 95                        |
| target_surat          | INT          | 50                        |
| realisasi_surat       | INT          | 52                        |
| waktu_proses_rata2    | DECIMAL(5,2) | 2.5                       |
| tingkat_kepuasan      | DECIMAL(3,2) | 4.35                      |
| budget_allocated      | DECIMAL(15,2)| 50000000.00               |
| actual_spending       | DECIMAL(15,2)| 48500000.00               |
| efisiensi_persen      | DECIMAL(5,2) | 97.00                     |
| tanggal_submit        | DATE         | 2024-11-03                |
| status_approval       | VARCHAR(20)  | Approved                  |
| catatan               | TEXT         | Sesuai target             |

**Data Quality:**
- Completeness: 85% (15% budget fields NULL untuk unit tanpa budget allocation)
- Known issues:
  - Inconsistent submission dates: ~20% terlambat dari deadline
  - Manual entry errors: ~5%

---

## 6. Unit Organisasi & Hierarki ITERA

**Deskripsi:** Master data struktur organisasi Institut Teknologi Sumatera

**Detail Teknis:**
- Platform: Master data dalam database MASTER_DB
- Tabel: tbl_unit_kerja

**Data Available:**
- Periode: Static (updated annually)
- Volume: ~50 unit kerja (all levels)

### 6.1 Struktur Data (tbl_unit_kerja)

| Kolom                 | Tipe Data    | Contoh                    |
|-----------------------|--------------|---------------------------|
| id_unit               | INT          | 1                         |
| kode_unit             | VARCHAR(10)  | BAU                       |
| nama_unit             | VARCHAR(100) | Biro Akademik Umum        |
| level                 | INT          | 2                         |
| parent_unit_id        | INT          | NULL                      |
| kepala_unit_nip       | VARCHAR(20)  | 198501012015011001        |
| email_unit            | VARCHAR(100) | bau@itera.ac.id           |

**Hierarki ITERA:**
- Level 1: Rektorat
- Level 2: Biro/Direktorat (termasuk Biro Akademik Umum)
- Level 3: Bagian
- Level 4: Sub Bagian
- Level 5: Unit Teknis

**Data Quality:**
- Completeness: 100%
- Known issues: None

---

## 7. Summary Table - Data Sources Overview

| No | Data Source | Platform | Tables | Volume | Update Freq | Relevance | Priority |
|----|-------------|----------|--------|--------|-------------|-----------|----------|
| 1  | Sistem Persuratan | SIMASTER_DB | 4 tables | 18K surat, 25K disposisi | Real-time | ⭐⭐⭐⭐⭐ | HIGH |
| 2  | Inventaris & Aset | INVENTARIS_DB | 3 tables | 2.5K items | Monthly/Event | ⭐⭐⭐⭐ | HIGH |
| 3  | Kepegawaian | SIMPEG_DB | 3 tables | 350 pegawai, 90K absensi | Daily | ⭐⭐⭐⭐ | MEDIUM |
| 4  | Permintaan Layanan | LAYANAN_DB | 2 tables | 5.4K requests | Real-time | ⭐⭐⭐⭐⭐ | HIGH |
| 5  | Monitoring Kinerja | MONITORING_DB | 1 table | 480 laporan | Monthly | ⭐⭐⭐⭐⭐ | HIGH |
| 6  | Unit Organisasi | MASTER_DB | 1 table | 50 units | Yearly | ⭐⭐⭐⭐⭐ | HIGH |

**Total Tables:** 14 operational tables + 3 reference tables = **17 tables**

---

## 8. Data Integration Notes

### 8.1 Common Keys (For Integration)

- **unit_kerja_id**: Foreign key across all systems
- **nip**: Employee identifier (SIMPEG → all systems)
- **tanggal**: Date field for time-based analysis

### 8.2 Data Quality Summary

| Quality Dimension | Overall Score | Notes |
|-------------------|---------------|-------|
| Completeness | 92% | Good, minor gaps in optional fields |
| Consistency | 85% | Kategori fields need standardization |
| Accuracy | 95% | Minimal errors, mostly validated |
| Timeliness | 90% | Real-time for transactional data |
| Uniqueness | 99% | <1% duplicates, manageable |

### 8.3 ETL Considerations

**Critical Transformations Needed:**
1. **Standardisasi Kategori:** Map non-standard categories (PC → Komputer, etc.)
2. **Deduplication:** Handle duplicate nomor_surat (1%)
3. **NULL Handling:** Median/average imputation for missing nilai_perolehan
4. **Date Formatting:** Standardize to ISO 8601 format
5. **SCD Type 2:** For dim_pegawai and dim_unit_kerja (track historical changes)

**Data Volume Projections (3 years):**
- Surat: 18K → 35K (growth rate 400/month)
- Inventaris: 2.5K → 2.7K (growth rate 40-50/year)
- Layanan: 5.4K → 12K (growth rate 150/month)
- Absensi: 90K → 180K (daily accumulation)

---

## 9. Alignment dengan KPI

| KPI | Data Sources Required | Status |
|-----|----------------------|--------|
| Tingkat Akurasi Pencatatan Surat | tbl_surat_masuk | ✅ Available |
| Waktu Respon Permintaan Layanan | tbl_permintaan_layanan | ✅ Available |
| Komplain Terselesaikan <3 Hari | tbl_permintaan_layanan + ref_jenis_layanan | ✅ Available |
| Aset Terlabeli | tbl_inventaris | ✅ Available |
| Akurasi Data Kepegawaian | tbl_pegawai | ✅ Available |
| Ketepatan Waktu Pelaporan | tbl_laporan_kinerja | ✅ Available |
| Tingkat Kepuasan Civitas | tbl_permintaan_layanan (rating_kepuasan) | ✅ Available |
| Efisiensi Anggaran | tbl_laporan_kinerja | ✅ Available |
| Waktu Proses Surat | tbl_surat_masuk + tbl_disposisi | ✅ Available |

**Coverage:** 9/9 KPI = **100% data coverage** ✅

---

## 10. Change Log

**Version 2.0 (11 Nov 2025):**
- Added: tbl_disposisi (Section 1.3) - Critical untuk KPI waktu proses
- Added: Data Source #5 (Sistem Monitoring Kinerja) - Untuk KPI monitoring & evaluasi
- Added: ref_lokasi (Section 2.4) - Untuk tracking aset per lokasi
- Added: Field `rating_kepuasan` dan `feedback` di tbl_permintaan_layanan
- Added: Field `is_komplain` dan `sla_hari` di ref_jenis_layanan
- Updated: Summary table dengan 6 data sources (dari 4)
- Updated: KPI alignment table - 100% coverage achieved
- Updated: ETL considerations dengan SCD Type 2 strategy
- Updated: Data volume projections untuk 3 tahun

**Version 1.0 (10 Nov 2025):**
- Initial documentation dengan 4 data sources
- Basic structure untuk Surat, Inventaris, Kepegawaian, Layanan

---

**Prepared by:** Kelompok 19 - Tugas Besar Pergudangan Data    
**Last Review:** 11 November 2025, 23:54 WIB
