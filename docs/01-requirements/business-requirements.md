# Business Requirements Document
## Data Mart Biro Akademik Umum ITERA

**Version:** 1.0  
**Date:** [Selasa. 10 November 2025]  
**Prepared by:** Tim Kelompok [19]  
**Status:** Draft

---

## 1. Executive Summary

Dokumen ini menjabarkan kebutuhan bisnis untuk pembangunan Data Mart Biro Akademik Umum Institut Teknologi Sumatera (ITERA). Data Mart ini dirancang untuk mendukung pengambilan keputusan berbasis data dalam pengelolaan administrasi umum, surat-menyurat, inventaris aset, dan pelayanan kesekretariatan di lingkungan ITERA.

**Tujuan Utama:**
- Menyediakan single source of truth untuk data administrasi umum
- Meningkatkan efisiensi pencarian dan pelaporan data
- Mendukung monitoring KPI secara real-time
- Memfasilitasi analisis trend dan pattern dalam operasional administrasi

---

## 2. Business Context

### 2.1 Tentang Biro Akademik Umum ITERA

Biro Akademik Umum merupakan unit penunjang akademik yang bertanggung jawab atas berbagai fungsi administratif penting di ITERA, meliputi:

1. **Pengelolaan Surat Menyurat dan Kearsipan**
   - Pencatatan surat masuk dan keluar
   - Pengarsipan dokumen institusi
   - Distribusi surat internal
   - Manajemen disposisi

2. **Pengelolaan Inventaris dan Aset**
   - Pencatatan aset institusi
   - Labeling dan tagging aset
   - Monitoring kondisi aset
   - Jadwal maintenance
   - Tracking lokasi aset

3. **Administrasi Kepegawaian**
   - Pencatatan data pegawai
   - Pengelolaan cuti dan izin
   - Administrasi kontrak kerja
   - Update data kepegawaian

4. **Pelayanan Kesekretariatan**
   - Peminjaman ruangan
   - Pengadaan perlengkapan kerja
   - Layanan umum untuk civitas akademika
   - Penanganan komplain

5. **Monitoring dan Pelaporan**
   - Pelaporan bulanan/triwulan/tahunan
   - Evaluasi kinerja administrasi
   - Survey kepuasan layanan

### 2.2 Stakeholders

| Stakeholder | Role | Interest |
|-------------|------|----------|
| Kepala Biro Akademik Umum | Decision Maker | Strategic planning, KPI monitoring |
| Staff Administrasi | Operational User | Daily operations, data entry |
| Manajemen ITERA | Executive | Performance overview, compliance |
| Civitas Akademika | End User | Service quality, response time |

---

## 3. Business Processes

### 3.1 Proses Surat Menyurat

**Alur Proses:**
```
Surat Masuk → Pencatatan → Disposisi → Tindak Lanjut → Arsip
```

**Pain Points:**
- Kesulitan tracking status surat
- Waktu pencarian arsip yang lama
- Tidak ada dashboard untuk monitoring volume surat
- Kesalahan pencatatan manual

**Expected Improvement:**
- Dashboard real-time untuk status surat
- Pencarian arsip digital < 15 menit
- Akurasi pencatatan > 98%

### 3.2 Proses Pengelolaan Aset

**Alur Proses:**
```
Pengadaan → Pencatatan → Labeling → Distribusi → Monitoring → Maintenance
```

**Pain Points:**
- Aset hilang atau tidak terlacak
- Data aset tidak up-to-date
- Sulit monitoring utilisasi ruangan
- Jadwal maintenance tidak terjadwal

**Expected Improvement:**
- 100% aset terlabeli dan tercatat
- Real-time tracking lokasi aset
- Dashboard utilisasi ruangan
- Automated maintenance reminder

### 3.3 Proses Peminjaman Ruangan

**Alur Proses:**
```
Request → Approval → Booking → Penggunaan → Return → Evaluasi
```

**Pain Points:**
- Double booking
- Tidak ada data utilisasi ruangan
- Sulit cek ketersediaan ruangan
- Tidak ada sistem rating/feedback

**Expected Improvement:**
- Integrated booking system
- Real-time room availability
- Utilisasi tracking per ruangan
- Feedback collection

---

## 4. Key Performance Indicators (KPIs)

### 4.1 Efektivitas Layanan

| KPI | Definition | Target | Measurement Frequency |
|-----|------------|--------|----------------------|
| **Tingkat Akurasi Pencatatan Surat** | % surat yang dicatat tanpa error | >98% | Bulanan |
| **Waktu Pencarian Arsip** | Rata-rata waktu untuk menemukan dokumen arsip | <15 menit | Per kasus |
| **Waktu Respon Layanan** | Waktu dari request hingga response | <24 jam | Harian |
| **Tingkat Penyelesaian Komplain** | % komplain diselesaikan dalam 3 hari kerja | >90% | Bulanan |

### 4.2 Pengelolaan Aset & Data

| KPI | Definition | Target | Measurement Frequency |
|-----|------------|--------|----------------------|
| **Aset Terlabeli** | % aset yang memiliki label dan tercatat dalam sistem | 100% | Semester |
| **Akurasi Data Kepegawaian** | % data pegawai yang akurat dan up-to-date | 100% | Triwulan |
| **Tingkat Utilisasi Ruangan** | % waktu ruangan terpakai vs available | 60-80% | Bulanan |

### 4.3 Kinerja Strategis

| KPI | Definition | Target | Measurement Frequency |
|-----|------------|--------|----------------------|
| **Ketepatan Waktu Pelaporan** | % laporan diserahkan tepat waktu | 100% | Bulanan |
| **Tingkat Kepuasan Layanan** | Skor rata-rata kepuasan civitas akademika | >4.0/5.0 | Semester |
| **Efisiensi Anggaran** | Actual spending vs budgeted | <100% | Tahunan |

---

## 5. Analytical Requirements

### 5.1 Key Business Questions

Data Mart harus mampu menjawab pertanyaan-pertanyaan bisnis berikut:

#### Surat Menyurat & Kearsipan:
1. Bagaimana **trend volume surat** masuk/keluar dalam 6-12 bulan terakhir?
2. **Jenis surat** apa yang paling sering mengalami kesalahan pencatatan?
3. Berapa **waktu rata-rata** proses disposisi per kategori surat?
4. Unit mana yang paling sering **mengirim/menerima** surat?

#### Aset & Inventaris:
5. Berapa **persentase aset** yang belum terlabeli berdasarkan kategori?
6. Bagaimana **distribusi geografis** aset di seluruh kampus ITERA?
7. Berapa **tingkat utilisasi** setiap ruangan per minggu/bulan?
8. Kapan **jadwal maintenance** aset yang akan datang?

#### Peminjaman Ruangan:
9. Ruangan mana yang memiliki **tingkat peminjaman tertinggi**?
10. Berapa **waktu rata-rata** peminjaman per jenis keperluan?
11. Unit/organisasi mana yang paling sering **meminjam ruangan**?

#### Kepegawaian:
12. Berapa **waktu rata-rata** penyelesaian berbagai jenis dokumen kepegawaian?
13. Bagaimana **distribusi pegawai** berdasarkan unit dan jabatan?

#### Layanan:
14. Apa **jenis permintaan layanan** yang paling sering diajukan?
15. Berapa **waktu rata-rata respon** per kategori layanan?
16. Bagaimana **distribusi komplain** berdasarkan kategori dan unit?

#### Performa & Kepuasan:
17. Apa **faktor-faktor** yang mempengaruhi tingkat kepuasan civitas akademika?
18. Bagaimana **perbandingan kinerja KPI** antar periode (MoM, YoY)?
19. Unit mana yang memiliki **response time terbaik** untuk layanan?
20. Bagaimana **trend efisiensi operasional** dalam 1 tahun terakhir?

---

## 6. Data Source Identification

### 6.1 Existing Data Sources

| Data Source | Type | Description | Volume (Est.) | Update Frequency |
|-------------|------|-------------|---------------|------------------|
| **SIAKAD Database** | SQL Server | Academic administrative system | 50K+ records | Real-time |
| **Spreadsheet Surat** | Excel | Manual surat logging | 10K records/year | Daily |
| **Spreadsheet Aset** | Excel | Asset inventory | 5K assets | Monthly |
| **Booking System** | Web App DB | Room booking records | 2K bookings/semester | Real-time |
| **HR System** | Database | Employee data | 500+ employees | Weekly |
| **Survey Forms** | Google Forms | Satisfaction surveys | 200 responses/semester | Semester |

### 6.2 Data Gaps & Assumptions

**Data Gaps:**
- Tidak ada tracking real-time untuk status surat
- Data aset tidak terintegrasi dengan lokasi geografis
- History maintenance aset tidak tercatat sistematis
- Feedback peminjaman ruangan tidak terstruktur

**Assumptions:**
- Data historis 3 tahun terakhir akan dimigrasi
- Data sensitif (personal info) akan di-mask
- ETL akan berjalan daily pada pukul 02:00 WIB
- Data quality threshold: 95% completeness, 98% accuracy

---

## 7. Functional Requirements

### 7.1 Data Integration
- **FR-01:** Sistem harus dapat mengintegrasikan data dari minimal 3 sumber berbeda
- **FR-02:** ETL process harus berjalan otomatis setiap hari
- **FR-03:** Sistem harus support incremental load untuk efisiensi
- **FR-04:** Data historical minimal 2 tahun harus dimuat

### 7.2 Data Quality
- **FR-05:** Sistem harus melakukan data validation sebelum load
- **FR-06:** Duplicate records harus dideteksi dan di-handle
- **FR-07:** Missing values harus di-flag dan dilaporkan
- **FR-08:** Referential integrity harus dijaga

### 7.3 Reporting & Analytics
- **FR-09:** Dashboard harus dapat di-filter by date, unit, category
- **FR-10:** Sistem harus support drill-down dari summary ke detail
- **FR-11:** Export ke Excel/PDF harus tersedia
- **FR-12:** Dashboard harus load dalam < 5 detik

### 7.4 Security
- **FR-13:** Role-based access control harus diimplementasikan
- **FR-14:** Audit trail untuk semua data modification
- **FR-15:** Data masking untuk informasi sensitif
- **FR-16:** Backup otomatis harian

---

## 8. Non-Functional Requirements

### 8.1 Performance
- **NFR-01:** Query response time < 3 detik untuk simple queries
- **NFR-02:** Query response time < 10 detik untuk complex queries
- **NFR-03:** ETL completion time < 30 menit untuk daily load
- **NFR-04:** Sistem harus support 50 concurrent users

### 8.2 Scalability
- **NFR-05:** Database design harus scalable untuk 5 tahun ke depan
- **NFR-06:** Partitioning strategy untuk tables > 1 juta rows
- **NFR-07:** Indexing untuk optimize query performance

### 8.3 Availability
- **NFR-08:** System uptime 99% (excluding planned maintenance)
- **NFR-09:** Backup retention: 30 hari
- **NFR-10:** Recovery Time Objective (RTO): < 4 jam
- **NFR-11:** Recovery Point Objective (RPO): < 24 jam

### 8.4 Usability
- **NFR-12:** Dashboard harus user-friendly (no training needed)
- **NFR-13:** Documentation lengkap (technical + user manual)
- **NFR-14:** Error messages harus informatif

---

## 9. Success Criteria

Project dianggap sukses jika:

✅ **Technical Success:**
- Database deployed dan operational
- ETL berjalan sukses tanpa error
- All KPIs dapat di-calculate dan di-visualize
- Performance requirements terpenuhi

✅ **Business Success:**
- Stakeholders dapat mengakses dashboard
- Business questions dapat dijawab
- Response time untuk pencarian data improved
- User satisfaction > 4.0/5.0

✅ **Documentation Success:**
- Technical documentation lengkap
- User manual tersedia
- Operations manual tersedia
- GitHub repository well-organized

---

## 10. Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Data sources tidak lengkap | High | Medium | Use synthetic data for missing parts |
| Performance issues | Medium | Low | Implement indexing & partitioning |
| Data quality rendah | High | Medium | Implement validation & cleansing |
| Timeline terlalu ketat | Medium | High | Prioritize must-have features |

---

## 11. Project constraints

- **Time:** 7 hari working time
- **Team:** 3 orang
- **Budget:** Azure student subscription
- **Technology:** PostgreSQL, Python, Power BI
- **Data:** Limited to available sources

---

## 12. Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Team Lead | Aldi | | |
| ETL Developer | Zahra | | |
| BI Developer | Feby | | |
| Course Instructor | | | |

---

**Document Control:**
- Version 1.0 - Initial Draft
- Next Review: [Date Hari 2]
- Status: Draft - Pending Review
