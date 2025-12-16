# ERD Documentation - Biro Akademik Umum ITERA

## Overview
ERD ini merepresentasikan struktur database operasional (OLTP) untuk mendukung
proses bisnis Biro Akademik Umum ITERA.

## Entity Categories

### 1. Core Transaction Entities
- **SURAT_MASUK**: Surat yang diterima institusi
- **SURAT_KELUAR**: Surat yang dikeluarkan institusi
- **PERMINTAAN_LAYANAN**: Log permintaan layanan dari civitas akademika
- **ASET**: Master data aset/inventaris
- **MAINTENANCE_ASET**: Riwayat maintenance aset

### 2. Master Data Entities
- **UNIT_ORGANISASI**: Struktur organisasi ITERA (fakultas, jurusan, biro)
- **PEGAWAI**: Data pegawai (dosen, tendik, staff)

### 3. Lookup/Reference Entities
- **JENIS_SURAT**: Kategori jenis surat
- **STATUS**: Status proses (surat, layanan, aset)
- **KATEGORI_ASET**: Kategori aset
- **KONDISI**: Kondisi aset
- **JENIS_LAYANAN**: Jenis layanan yang tersedia
- **LOKASI**: Lokasi gedung/ruangan
- **JABATAN**: Jabatan pegawai

## Key Relationships

### UNIT_ORGANISASI
- Self-referencing (parent-child untuk hierarki organisasi)
- Parent of PEGAWAI (1:N)
- Referenced by SURAT_MASUK (unit tujuan)
- Referenced by SURAT_KELUAR (unit pengirim)
- Referenced by PERMINTAAN_LAYANAN (unit pemohon)

### PEGAWAI
- Belongs to UNIT_ORGANISASI (N:1)
- Has JABATAN (N:1)
- Handles SURAT_MASUK as PIC (1:N)
- Creates SURAT_KELUAR as PIC (1:N)
- Manages ASET as PIC (1:N)
- Handles PERMINTAAN_LAYANAN (1:N)
- Requests MAINTENANCE_ASET (1:N)

### ASET
- Belongs to KATEGORI_ASET (N:1)
- Has KONDISI current (N:1)
- Located at LOKASI (N:1)
- Managed by PEGAWAI (N:1)
- Has MAINTENANCE_ASET history (1:N)

## Business Rules

1. **Surat Masuk/Keluar**
   - Setiap surat harus memiliki nomor unik
   - Setiap surat harus memiliki PIC (Pegawai)
   - Status surat mengikuti alur: Draf → Dalam Proses → Selesai

2. **Aset**
   - Setiap aset harus memiliki kode unik
   - Aset harus memiliki PIC pengelola (Pegawai)
   - Status aset mengikuti alur: Draf → Dalam Proses → Selesai
