# Bus Matrix – Data Mart BAU ITERA

Matriks ini memetakan proses bisnis utama (baris) terhadap dimensi terpusat (kolom). Tanda ✓ berarti fact/proses bisnis tersebut menggunakan dimensi terkait.

## Bus Matrix

| Proses Bisnis / Dimensi                | Dim_Waktu | Dim_Unit_Kerja | Dim_Pegawai | Dim_Jenis_Surat | Dim_Jenis_Layanan | Dim_Barang | Dim_Lokasi |
|----------------------------------------|-----------|----------------|-------------|------------------|-------------------|------------|-----------|
| Surat Menyurat (Fact_Surat)           | ✓         | ✓              | ✓           | ✓                |                   |            |           |
| Layanan Sekretariat (Fact_Layanan)    | ✓         | ✓              | ✓           |                  | ✓                 |            |           |
| Snapshot Aset (Fact_Aset)             | ✓         | ✓              |             |                  |                   | ✓          | ✓         |
| Monitoring & Evaluasi KPI (Calon Fact)| ✓         | ✓              |             | ✓                | ✓                 |            |           |

## Catatan Grain & Peran Dimensi

- **Surat Menyurat (Fact_Surat)**  
  Grain: 1 baris per surat (opsional per disposisi jika dipisah).  
  Dimensi:  
  - Dim_Waktu → tanggal_diterima / tanggal_selesai.  
  - Dim_Unit_Kerja → Pengirim dan Penerima (role-playing).  
  - Dim_Pegawai → Pegawai penerima disposisi.  
  - Dim_Jenis_Surat → Klasifikasi jenis surat.

- **Layanan Sekretariat (Fact_Layanan)**  
  Grain: 1 baris per permintaan layanan.  
  Dimensi:  
  - Dim_Waktu → timestamp_submit / tanggal_selesai.  
  - Dim_Unit_Kerja → Unit tujuan layanan.  
  - Dim_Pegawai → Pemohon layanan (pegawai).  
  - Dim_Jenis_Layanan → Kategori layanan dan SLA.

- **Snapshot Aset (Fact_Aset)**  
  Grain: 1 baris per aset per periode snapshot (misalnya akhir bulan).  
  Dimensi:  
  - Dim_Waktu → tanggal_snapshot.  
  - Dim_Unit_Kerja → Unit pemilik/pengguna aset.  
  - Dim_Barang → Kategori/nama aset.  
  - Dim_Lokasi → Lokasi fisik aset.

- **Monitoring & Evaluasi KPI (Calon Fact)**  
  Grain: 1 baris per unit kerja per periode pelaporan (misalnya bulanan).  
  Dimensi:  
  - Dim_Waktu → periode pelaporan.  
  - Dim_Unit_Kerja → unit yang dievaluasi.  
  - Dim_Jenis_Surat / Dim_Jenis_Layanan → jika KPI dibuat per kategori surat/layanan tertentu.

## Penggunaan

- Bus Matrix ini menjadi referensi utama saat menambah fact baru: fact baru harus memilih dari dimensi yang sudah ada agar tetap terintegrasi.  
- Dokumen ini juga menjadi jembatan antara business requirements (proses & KPI) dengan desain dimensional (ERD dan S2T mapping).
