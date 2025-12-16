# Data Dictionary – Data Mart BAU ITERA

Dokumen ini mendefinisikan struktur logis tabel dimensi dan fakta pada Data Mart Biro Akademik Umum ITERA.  
Tipe data di sini bersifat **logis**; implementasi fisik di PostgreSQL dapat menyesuaikan (misal `INTEGER` vs `BIGINT`, `VARCHAR(n)`).

## Konvensi Umum

- Semua tabel dimensi menggunakan **surrogate key** dengan sufiks `_key`.  
- Kolom business key dari sistem sumber tetap disimpan (misal `nip`, `kode_unit`, `kode_barang`).  
- Tabel fakta menyimpan hanya **foreign key ke dimensi** dan **measure numerik**.  
- Nilai tanggal di fakta direferensikan ke `Dim_Waktu` melalui `*_tanggal_key`.  

---

## 1. Dimension Tables

### 1.1 Dim_Waktu

| Kolom             | Tipe Data | PK/FK | Null? | Deskripsi                                                      | Contoh        |
|-------------------|----------|------|-------|----------------------------------------------------------------|--------------|
| tanggal_key       | INTEGER  | PK   | NO    | Surrogate key tanggal, format `YYYYMMDD`.                      | 20240115     |
| tanggal           | DATE     |      | NO    | Tanggal kalender penuh.                                        | 2024-01-15   |
| hari              | VARCHAR  |      | NO    | Nama hari dalam bahasa Indonesia.                              | Senin        |
| bulan             | INTEGER  |      | NO    | Nomor bulan (1–12).                                            | 1            |
| tahun             | INTEGER  |      | NO    | Tahun empat digit.                                             | 2024         |
| quarter           | INTEGER  |      | NO    | Kuartal dalam tahun (1–4).                                     | 1            |
| minggu_tahun      | INTEGER  |      | YES   | Nomor minggu dalam tahun (1–53, opsional).                     | 3            |
| hari_dalam_bulan  | INTEGER  |      | NO    | Hari ke-berapa di bulan (1–31).                               | 15           |
| hari_kerja        | BOOLEAN  |      | NO    | Flag hari kerja (TRUE jika Senin–Jumat dan bukan hari libur). | TRUE         |
| bulan_tahun       | VARCHAR  |      | NO    | Label tampilan `NamaBulan YYYY`.                              | Januari 2024 |

---

### 1.2 Dim_Unit_Kerja

| Kolom            | Tipe Data | PK/FK | Null? | Deskripsi                                                           | Contoh                          |
|------------------|----------|------|-------|---------------------------------------------------------------------|---------------------------------|
| unit_key         | INTEGER  | PK   | NO    | Surrogate key unit kerja.                                           | 10                              |
| kode_unit        | VARCHAR  |      | NO    | Kode unik unit kerja sesuai master organisasi.                      | BAU                             |
| nama_unit        | VARCHAR  |      | NO    | Nama lengkap unit kerja.                                            | Biro Akademik Umum              |
| level            | INTEGER  |      | NO    | Tingkatan dalam hierarki (1 = Institut, 2 = Fakultas, dst.).        | 2                               |
| parent_unit_key  | INTEGER  | FK   | YES   | Referensi ke `Dim_Unit_Kerja.unit_key` untuk atasan langsung.       | 3                               |
| kepala_unit_nip  | VARCHAR  |      | YES   | NIP kepala unit (business key ke Dim_Pegawai).                      | 198501012015011001              |
| email_unit       | VARCHAR  |      | YES   | Alamat email resmi unit.                                            | bau@itera.ac.id                 |
| path_hierarchy   | VARCHAR  |      | YES   | Jalur hierarki teks dari puncak ke unit ini.                        | Rektorat > BAU                  |
| jumlah_sub_unit  | INTEGER  |      | YES   | Jumlah unit turunan langsung.                                       | 3                               |
| is_active        | BOOLEAN  |      | NO    | Status keaktifan unit kerja.                                        | TRUE                            |

---

### 1.3 Dim_Pegawai

| Kolom              | Tipe Data | PK/FK | Null? | Deskripsi                                                            | Contoh                            |
|--------------------|----------|------|-------|----------------------------------------------------------------------|-----------------------------------|
| pegawai_key        | INTEGER  | PK   | NO    | Surrogate key pegawai (SCD Type 2).                                  | 101                               |
| nip                | VARCHAR  |      | NO    | NIP sebagai business key.                                            | 199001012020011001                |
| nama               | VARCHAR  |      | NO    | Nama lengkap pegawai (title-case).                                   | Dr. Ahmad Fauzi                   |
| jabatan            | VARCHAR  |      | YES   | Nama jabatan struktural/fungsional.                                  | Kepala Bagian Umum                |
| unit_key           | INTEGER  | FK   | YES   | Referensi ke `Dim_Unit_Kerja`.                                       | 10                                |
| status_kepegawaian | VARCHAR  |      | YES   | Jenis status (PNS, PPPK, Honorer, Kontrak, dll.).                    | PNS                               |
| tanggal_masuk      | DATE     |      | YES   | Tanggal mulai bekerja di ITERA.                                      | 2020-01-15                        |
| email              | VARCHAR  |      | YES   | Email dinas pegawai.                                                 | ahmad.fauzi@itera.ac.id           |
| no_hp              | VARCHAR  |      | YES   | Nomor ponsel pegawai.                                                | 081234567890                      |
| effective_date     | DATE     |      | NO    | Tanggal awal berlakunya record (SCD start date).                     | 2024-01-01                        |
| end_date           | DATE     |      | NO    | Tanggal akhir berlakunya record (9999-12-31 untuk record aktif).     | 9999-12-31                        |
| is_current         | BOOLEAN  |      | NO    | TRUE jika record ini adalah versi terkini untuk NIP tersebut.        | TRUE                              |

---

### 1.4 Dim_Jenis_Surat

| Kolom             | Tipe Data | PK/FK | Null? | Deskripsi                                        | Contoh                     |
|-------------------|----------|------|-------|--------------------------------------------------|----------------------------|
| jenis_surat_key   | INTEGER  | PK   | NO    | Surrogate key jenis surat.                       | 5                          |
| kode_jenis_surat  | VARCHAR  |      | NO    | Kode jenis surat dari referensi SIMASTER.        | SURT-MSK                   |
| nama_jenis_surat  | VARCHAR  |      | NO    | Nama jenis surat.                                | Surat Masuk                |
| kategori           | VARCHAR  |      | YES   | Kategori umum (Internal, Eksternal, Undangan).   | Eksternal                  |
| sifat              | VARCHAR  |      | YES   | Sifat surat (Biasa, Penting, Rahasia, Segera).   | Penting                    |
| is_active          | BOOLEAN  |      | NO    | Status aktif jenis surat di referensi master.    | TRUE                       |

---

### 1.5 Dim_Jenis_Layanan

| Kolom                | Tipe Data | PK/FK | Null? | Deskripsi                                           | Contoh                      |
|----------------------|----------|------|-------|-----------------------------------------------------|-----------------------------|
| jenis_layanan_key    | INTEGER  | PK   | NO    | Surrogate key jenis layanan.                        | 3                           |
| kode_jenis_layanan   | VARCHAR  |      | NO    | Kode layanan dari sistem ticketing.                 | LYN-PR                       |
| nama_jenis_layanan   | VARCHAR  |      | NO    | Nama jenis layanan.                                 | Peminjaman Ruangan          |
| kategori_layanan     | VARCHAR  |      | YES   | Kategori (Layanan Umum, Sarpras, Kepegawaian, dll). | Sarpras                     |
| sla_target_jam       | INTEGER  |      | YES   | Target SLA penyelesaian layanan dalam jam.          | 24                          |
| is_active            | BOOLEAN  |      | NO    | Status aktif jenis layanan.                         | TRUE                        |

---

### 1.6 Dim_Barang

| Kolom               | Tipe Data | PK/FK | Null? | Deskripsi                                                   | Contoh                        |
|---------------------|----------|------|-------|-------------------------------------------------------------|-------------------------------|
| barang_key          | INTEGER  | PK   | NO    | Surrogate key barang/aset.                                 | 2001                          |
| kode_barang         | VARCHAR  |      | NO    | Kode barang dari sistem inventaris.                        | BRG-IT-001                    |
| nama_barang         | VARCHAR  |      | NO    | Nama barang.                                               | Laptop Dosen                  |
| kategori_barang     | VARCHAR  |      | YES   | Kategori umum (Elektronik, Furnitur, Kendaraan, dll.).     | Elektronik                    |
| subkategori_barang  | VARCHAR  |      | YES   | Subkategori (Laptop, Proyektor, Kursi, dll.).              | Laptop                        |
| satuan              | VARCHAR  |      | YES   | Satuan pengukuran (unit, buah, set, dll.).                 | unit                          |
| merk                | VARCHAR  |      | YES   | Merek barang (jika relevan).                               | Lenovo                        |
| spesifikasi         | VARCHAR  |      | YES   | Ringkasan spesifikasi teknis.                              | i5/16GB/512GB SSD             |
| is_bergerak         | BOOLEAN  |      | YES   | TRUE jika aset bersifat bergerak (mudah dipindahkan).      | TRUE                          |
| is_tik              | BOOLEAN  |      | YES   | TRUE jika aset termasuk kategori TIK.                      | TRUE                          |

---

### 1.7 Dim_Lokasi

| Kolom        | Tipe Data | PK/FK | Null? | Deskripsi                                          | Contoh            |
|--------------|----------|------|-------|----------------------------------------------------|-------------------|
| lokasi_key   | INTEGER  | PK   | NO    | Surrogate key lokasi.                              | 501               |
| kode_lokasi  | VARCHAR  |      | NO    | Kode lokasi/ruangan dari sistem inventaris/ruang.  | GKU-A101          |
| nama_lokasi  | VARCHAR  |      | NO    | Nama ruangan/lokasi.                               | Aula Gedung Kuliah Umum |
| jenis_lokasi | VARCHAR  |      | YES   | Jenis lokasi (Ruang Rapat, Aula, Kantor, Gudang).  | Aula              |
| gedung       | VARCHAR  |      | YES   | Nama gedung.                                       | GKU               |
| lantai       | VARCHAR  |      | YES   | Lantai (bisa teks untuk fleksibilitas).            | Lantai 1          |
| keterangan   | VARCHAR  |      | YES   | Keterangan tambahan (kapasitas, fasilitas, dsb.).  | Kapasitas 200 orang |

---

## 2. Fact Tables

### 2.1 Fact_Surat

**Grain:** 1 baris per surat yang tercatat di sistem persuratan (opsional: dapat diperluas ke level disposisi jika diperlukan).  

| Kolom                    | Tipe Data | PK/FK | Null? | Deskripsi                                                          | Contoh                 |
|--------------------------|----------|------|-------|--------------------------------------------------------------------|------------------------|
| surat_key                | BIGINT   | PK   | NO    | Surrogate key fact_surat.                                          | 1000001                |
| tanggal_key              | INTEGER  | FK   | NO    | FK ke `Dim_Waktu` berdasarkan tanggal diterima/terbit surat.      | 20241015               |
| unit_pengirim_key        | INTEGER  | FK   | YES   | FK ke `Dim_Unit_Kerja` sebagai pengirim surat.                     | 10                     |
| unit_penerima_key        | INTEGER  | FK   | YES   | FK ke `Dim_Unit_Kerja` sebagai penerima surat (role-playing).      | 25                     |
| pegawai_penerima_key     | INTEGER  | FK   | YES   | FK ke `Dim_Pegawai` sebagai pegawai penerima/disposisi akhir.      | 101                    |
| jenis_surat_key          | INTEGER  | FK   | YES   | FK ke `Dim_Jenis_Surat`.                                           | 5                      |
| nomor_surat              | VARCHAR  |      | NO    | Nomor surat (degenerate dimension dari SIMASTER).                  | 001/BAU/ITERA/X/2024   |
| jumlah_lampiran          | INTEGER  |      | YES   | Jumlah lampiran fisik/elektronik.                                 | 2                      |
| durasi_proses_hari       | INTEGER  |      | YES   | Selisih hari dari tanggal terima sampai status selesai.            | 3                      |
| melewati_sla_flag        | BOOLEAN  |      | YES   | TRUE jika durasi_proses_hari > SLA yang ditentukan.                | FALSE                  |
| status_akhir             | VARCHAR  |      | YES   | Status akhir surat (Selesai, Arsip, Ditolak, dll.).                | Selesai                |
| channel                  | VARCHAR  |      | YES   | Kanal surat (Fisik, Email, Sistem, Kurir).                         | Sistem                 |

---

### 2.2 Fact_Layanan

**Grain:** 1 baris per permintaan layanan di sistem ticketing/layanan BAU.  

| Kolom                       | Tipe Data | PK/FK | Null? | Deskripsi                                                          | Contoh                 |
|-----------------------------|----------|------|-------|--------------------------------------------------------------------|------------------------|
| layanan_key                 | BIGINT   | PK   | NO    | Surrogate key fact_layanan.                                        | 2000001                |
| tanggal_request_key         | INTEGER  | FK   | NO    | FK ke `Dim_Waktu` untuk tanggal permintaan dibuat.                 | 20241015               |
| tanggal_selesai_key         | INTEGER  | FK   | YES   | FK ke `Dim_Waktu` untuk tanggal permintaan diselesaikan.           | 20241016               |
| unit_pemohon_key            | INTEGER  | FK   | YES   | FK ke `Dim_Unit_Kerja` sebagai unit pemohon layanan.               | 30                     |
| unit_pelaksana_key          | INTEGER  | FK   | YES   | FK ke `Dim_Unit_Kerja` sebagai unit pelaksana layanan.             | 10                     |
| pegawai_pemohon_key         | INTEGER  | FK   | YES   | FK ke `Dim_Pegawai` sebagai pemohon/pengaju layanan.               | 120                    |
| pegawai_penanggung_jawab_key| INTEGER  | FK   | YES   | FK ke `Dim_Pegawai` penanggung jawab pelaksanaan.                  | 101                    |
| jenis_layanan_key           | INTEGER  | FK   | YES   | FK ke `Dim_Jenis_Layanan`.                                         | 3                      |
| nomor_tiket                 | VARCHAR  |      | NO    | Nomor tiket/ID permintaan dari sistem layanan.                     | REQ-2024-10-001        |
| sla_target_jam              | INTEGER  |      | YES   | SLA target penyelesaian dalam jam, ditarik dari dim_jenis_layanan. | 24                     |
| waktu_respon_jam            | DECIMAL  |      | YES   | Waktu dari submit sampai pertama kali ditindaklanjuti (jam).       | 1.5                    |
| waktu_selesai_jam           | DECIMAL  |      | YES   | Waktu dari submit sampai status selesai (jam).                     | 20.0                   |
| melewati_sla_flag           | BOOLEAN  |      | YES   | TRUE jika `waktu_selesai_jam > sla_target_jam`.                    | FALSE                  |
| rating_kepuasan             | DECIMAL  |      | YES   | Rating kepuasan pemohon (skala 1–5).                               | 4.5                    |
| biaya_layanan               | DECIMAL  |      | YES   | Biaya aktual layanan (jika relevan).                               | 0.00                   |
| status_akhir                | VARCHAR  |      | YES   | Status tiket (Selesai, Dibatalkan, Ditolak, In Progress).          | Selesai                |

---

### 2.3 Fact_Aset

**Grain:** 1 baris per aset (barang) per periode snapshot (misalnya per akhir bulan).  

| Kolom                    | Tipe Data | PK/FK | Null? | Deskripsi                                                        | Contoh      |
|--------------------------|----------|------|-------|------------------------------------------------------------------|------------|
| aset_snapshot_key        | BIGINT   | PK   | NO    | Surrogate key fact_aset (snapshot).                              | 3000001    |
| tanggal_snapshot_key     | INTEGER  | FK   | NO    | FK ke `Dim_Waktu` untuk tanggal snapshot.                        | 20241231   |
| barang_key               | INTEGER  | FK   | NO    | FK ke `Dim_Barang` (jenis barang/aset).                          | 2001       |
| lokasi_key               | INTEGER  | FK   | YES   | FK ke `Dim_Lokasi` posisi aset saat snapshot.                    | 501        |
| unit_pemilik_key         | INTEGER  | FK   | YES   | FK ke `Dim_Unit_Kerja` pemilik/pengguna aset.                    | 10         |
| jumlah_unit              | INTEGER  |      | NO    | Jumlah unit aset pada snapshot tersebut.                         | 5          |
| nilai_perolehan          | DECIMAL  |      | YES   | Nilai perolehan total aset (akumulasi jika banyak unit).         | 75_000_000 |
| nilai_buku               | DECIMAL  |      | YES   | Nilai buku pada saat snapshot setelah depresiasi.                | 45_000_000 |
| umur_ekonomis_tahun      | DECIMAL  |      | YES   | Umur ekonomis aset (tahun).                                      | 5.0        |
| umur_tersisa_tahun       | DECIMAL  |      | YES   | Perkiraan umur ekonomis tersisa.                                 | 2.0        |
| kondisi                  | VARCHAR  |      | YES   | Kondisi aset (Baik, Rusak Ringan, Rusak Berat, Dihapus).         | Baik       |
| status_pemanfaatan       | VARCHAR  |      | YES   | Status pemanfaatan (Aktif, Tidak Terpakai, Dipinjamkan, dll.).   | Aktif      |

---

## 3. Catatan Pemetaan ke PostgreSQL

- `INTEGER` → `INTEGER` di PostgreSQL; gunakan `BIGINT` untuk key/measure yang berpotensi besar.  
- `DECIMAL` umumnya diimplementasikan sebagai `NUMERIC(p,s)` (misal `NUMERIC(18,2)` untuk nilai uang).  
- `VARCHAR` dapat diberi panjang konservatif (misal 50, 100, 255) sesuai kebutuhan aktual.  
- Boolean diimplementasikan sebagai `BOOLEAN` (`TRUE`/`FALSE`).  

Dokumen ini harus dijaga sinkron dengan:  
- ERD/Dimensional Model ([`dimensional-model.svg`](docs/02-design/dimensional-model.svg)).  
- Source-to-Target Mapping ([`source-to-target-mapping.md`](docs/02-design/source-to-target-mapping.md)).  
- Skrip fisik database (`02_Create_Dimensions.sql`, `03_Create_Facts.sql`) ketika sudah dibuat.
