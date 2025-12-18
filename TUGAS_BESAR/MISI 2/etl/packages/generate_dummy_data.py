import pandas as pd
import random
from faker import Faker
from datetime import datetime, timedelta

# Setup
fake = Faker('id_ID')
Faker.seed(19)
random.seed(19)

# Jumlah Data yang diinginkan
NUM_UNIT = 15
NUM_PEGAWAI = 50
NUM_SURAT = 2000
NUM_LAYANAN = 1000
NUM_INVENTARIS = 500

print("Sedang men-generate data dummy...")

# ==========================================
# 1. GENERATE UNIT KERJA (MASTER)
# ==========================================
units = [
    {'id_unit': 1, 'kode_unit': 'REK', 'nama_unit': 'Rektorat', 'level': 1},
    {'id_unit': 2, 'kode_unit': 'BAU', 'nama_unit': 'Biro Akademik Umum', 'level': 2},
    {'id_unit': 3, 'kode_unit': 'BUPK', 'nama_unit': 'Biro Umum dan Keuangan', 'level': 2},
    {'id_unit': 4, 'kode_unit': 'FSAINS', 'nama_unit': 'Fakultas Sains', 'level': 2},
    {'id_unit': 5, 'kode_unit': 'FTI', 'nama_unit': 'Fakultas Teknologi Industri', 'level': 2},
    {'id_unit': 6, 'kode_unit': 'JTIK', 'nama_unit': 'Jurusan Teknologi Produksi dan Industri', 'level': 3},
    {'id_unit': 7, 'kode_unit': 'JSTP', 'nama_unit': 'Jurusan Sains', 'level': 3},
    {'id_unit': 8, 'kode_unit': 'PRODI-SD', 'nama_unit': 'Prodi Sains Data', 'level': 4},
    {'id_unit': 9, 'kode_unit': 'PRODI-IF', 'nama_unit': 'Prodi Informatika', 'level': 4},
    {'id_unit': 10, 'kode_unit': 'UPT-TIK', 'nama_unit': 'UPT TIK', 'level': 3},
]
# Tambah random unit sisa
for i in range(11, NUM_UNIT + 1):
    units.append({
        'id_unit': i,
        'kode_unit': f'UNIT{i}',
        'nama_unit': f'Unit Kerja {i}',
        'level': 4
    })

df_unit = pd.DataFrame(units)
df_unit['parent_unit_id'] = 1 # Simplifikasi: semua lapor ke Rektorat
df_unit['kepala_unit_nip'] = None
df_unit['email_unit'] = df_unit['kode_unit'].apply(lambda x: f"{x.lower()}@itera.ac.id")

# ==========================================
# 2. GENERATE PEGAWAI (SIMPEG)
# ==========================================
pegawai_list = []
for i in range(NUM_PEGAWAI):
    nip = fake.numerify(text='19##########%')
    unit = random.choice(units)
    
    pegawai_list.append({
        'nip': nip,
        'nama': fake.name(),
        'jabatan': random.choice(['Staf', 'Kepala Seksi', 'Kepala Bagian', 'Dosen']),
        'unit_kerja_id': unit['id_unit'],
        'tanggal_masuk': fake.date_between(start_date='-10y', end_date='-1y'),
        'status_kepegawaian': random.choice(['PNS', 'PPPK', 'Honorer']),
        'email': fake.email(),
        'no_hp': fake.phone_number()
    })

df_pegawai = pd.DataFrame(pegawai_list)

# ==========================================
# 3. GENERATE SURAT (SIMASTER)
# ==========================================
surat_list = []
for i in range(NUM_SURAT):
    tgl_terima = fake.date_between(start_date='-2y', end_date='today')
    sender_unit = random.choice(units)['nama_unit']
    
    surat_list.append({
        'id_surat': f"SRT-{2023+i}",
        'nomor_surat': f"{i+1}/ITERA/BAU/{tgl_terima.year}",
        'tanggal_diterima': tgl_terima,
        'pengirim': sender_unit,
        'perihal': fake.sentence(nb_words=6),
        'jenis_surat_id': random.randint(1, 5), # Asumsi ada 5 jenis surat
        'status': random.choice(['Selesai', 'Proses', 'Disposisi']),
        'raw_data': "{}"
    })

df_surat = pd.DataFrame(surat_list)

# ==========================================
# 4. GENERATE LAYANAN
# ==========================================
layanan_list = []
for i in range(NUM_LAYANAN):
    tgl_submit = fake.date_time_between(start_date='-1y', end_date='now')
    # Tanggal selesai 1-3 hari setelah submit
    tgl_selesai = tgl_submit + timedelta(hours=random.randint(2, 72))
    
    layanan_list.append({
        'id_permintaan': f"REQ-{i}",
        'nomor_tiket': f"TKT-{tgl_submit.strftime('%Y%m')}-{i:04d}",
        'pemohon_nama': random.choice(pegawai_list)['nama'],
        'jenis_layanan_id': random.randint(1, 5),
        'timestamp_submit': tgl_submit,
        'tanggal_selesai': tgl_selesai,
        'status_penyelesaian': 'Selesai',
        'rating_kepuasan': round(random.uniform(3.0, 5.0), 2)
    })

df_layanan = pd.DataFrame(layanan_list)

# ==========================================
# 5. GENERATE INVENTARIS
# ==========================================
inventaris_list = []
kategori_aset = ['Elektronik', 'Furniture', 'Kendaraan', 'Alat Tulis']
kondisi_aset = ['Baik', 'Rusak Ringan', 'Rusak Berat']

for i in range(NUM_INVENTARIS):
    kategori = random.choice(kategori_aset)
    tgl_ada = fake.date_between(start_date='-5y', end_date='-1m')
    
    inventaris_list.append({
        'id_barang': f"INV-{i}",
        'kode_barang': f"BRG-{kategori[:3].upper()}-{i:03d}",
        'nama_barang': f"{kategori} - {fake.word()}",
        'kategori': kategori,
        'tanggal_pengadaan': tgl_ada,
        'nilai_perolehan': random.randint(100000, 15000000),
        'kondisi': random.choice(kondisi_aset),
        'lokasi_id': random.randint(1, 10),
        'unit_kerja_id': random.choice(units)['id_unit']
    })

df_inventaris = pd.DataFrame(inventaris_list)

# ==========================================
# EXPORT TO CSV
# ==========================================
df_unit.to_csv('stg_unit_kerja.csv', index=False)
df_pegawai.to_csv('stg_simpeg.csv', index=False)
df_surat.to_csv('stg_simaster_surat.csv', index=False)
df_layanan.to_csv('stg_layanan.csv', index=False)
df_inventaris.to_csv('stg_inventaris.csv', index=False)
