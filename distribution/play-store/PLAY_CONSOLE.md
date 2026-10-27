# Isian Google Play Console — RME Bayan

Jawaban untuk setiap form Play Console, disusun dari apa yang benar-benar
dilakukan app (lihat `pubspec.yaml`, `AndroidManifest.xml`, dan fitur per role).
Ganti setiap `[...]` sebelum disalin.

- `support@rmebayanpeduli.com` — email yang tampil di Play Store dan menerima permintaan data

Penerbit: perorangan (nama developer di akun Play Console). Kebijakan privasi
disajikan backend di **https://api.rmebayanpeduli.com/privacy** (sumber:
`app/handler/privacy/privacy-policy.html` di repo backend).

---

## 1. Store listing

**Menu:** Grow users → Store presence → Main store listing

| Kolom | Batas | Isi |
|---|---|---|
| App name | 30 | `RME Bayan` |
| Short description (id) | 80 | `Rekam medis elektronik untuk staf RS Kapal Bayan Peduli, bisa dipakai offline` |
| Short description (en) | 80 | `Electronic medical records for Bayan Peduli hospital ship staff, works offline` |

### Full description (Indonesia)

```
RME Bayan adalah aplikasi rekam medis elektronik untuk staf Rumah Sakit Kapal Bayan Peduli. Aplikasi ini hanya untuk staf: akun dibuat dan diberikan oleh pengelola rumah sakit kapal, tidak ada pendaftaran akun dari aplikasi.

Setiap petugas melihat fitur sesuai perannya:

• Perawat — mendaftarkan pasien, mencatat keluhan dan tanda vital, lalu mengarahkan pasien ke poli dan dokter.
• Dokter — memeriksa pasien, mengisi diagnosis ICD-10 dan tindakan ICD-9-CM, menulis resep, meminta pemeriksaan lab, dan merujuk pasien.
• Farmasi — menyerahkan obat sesuai resep dan memantau stok obat di kapal.
• Laboratorium — mengisi dan mengirim hasil pemeriksaan lab kepada dokter.
• Koordinator — mengatur jadwal poli perjalanan dan menyesuaikan stok obat dengan hitungan fisik.
• Admin kapal — mencatat bahan bakar, air bersih, dan kendala selama perjalanan.

Dirancang untuk pelayanan di laut:
• Tetap bisa dipakai tanpa sinyal. Data disimpan terenkripsi di perangkat dan dikirim otomatis saat koneksi kembali.
• Notifikasi saat ada pasien baru, resep, atau hasil lab.
• Tampilan menyesuaikan ponsel dan tablet.

Data pasien hanya dapat diakses oleh staf yang berwenang dan dikirim melalui koneksi terenkripsi.
```

### Full description (English)

```
RME Bayan is the electronic medical record app for the staff of the Bayan Peduli hospital ship. It is for staff only: accounts are created and issued by the hospital ship's administration; there is no sign-up in the app.

Each staff member sees the features of their role:

• Nurses — register patients, record complaints and vital signs, and send patients to a clinic and doctor.
• Doctors — examine patients, add ICD-10 diagnoses and ICD-9-CM procedures, write prescriptions, order lab tests and refer patients.
• Pharmacy — dispense prescriptions and keep track of the ship's medicine stock.
• Laboratory — enter and send lab results to the doctor.
• Coordinators — set the trip's clinic schedule and adjust medicine stock to the physical count.
• Ship admins — log fuel, fresh water and issues during the trip.

Built for care at sea:
• Keeps working without signal. Data is stored encrypted on the device and sent automatically when the connection is back.
• Notifications for new patients, prescriptions and lab results.
• Layouts for phones and tablets.

Patient data is only available to authorised staff and is sent over an encrypted connection.
```

### Lainnya di halaman yang sama

| Kolom | Isi |
|---|---|
| App category | Application → **Medical** |
| Tags | Medical records, Healthcare (pilih yang tersedia) |
| Contact email | `support@rmebayanpeduli.com` |
| Website | kosongkan |
| Privacy policy | `https://api.rmebayanpeduli.com/privacy` |

**Grafik yang wajib diunggah:**
- App icon 512 × 512 PNG (32-bit, maks 1 MB)
- Feature graphic 1024 × 500 PNG/JPG
- Minimal 2 screenshot ponsel (sisi pendek ≥ 320 px, rasio maks 2:1). Ambil dari akun demo dengan **data pasien contoh**, jangan data asli.
- Screenshot tablet 7" dan 10" disarankan (app punya tampilan tablet).

---

## 2. Kebijakan privasi

URL: **https://api.rmebayanpeduli.com/privacy** — halaman publik dari backend,
bisa dibuka tanpa login. Isi URL yang sama di Store listing dan di
**Policy and programs → App content → Privacy policy**.

Sumber teksnya `app/handler/privacy/privacy-policy.html` di repo backend; ubah
di sana lalu deploy backend. Sebaiknya dibaca pengelola RS Kapal Bayan Peduli
(dan penasihat hukum bila ada) sebelum diajukan.

---

## 3. Data safety

**Menu:** Policy and programs → App content → Data safety

### Data collection and security

| Pertanyaan | Jawaban |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS) |
| Which of the following methods of account creation does your app support? | **My app does not allow users to create an account** → pilih opsi bahwa akun dibuat oleh organisasi (staf menerima akun dari pengelola rumah sakit kapal) |
| Do you provide a way for users to request that their data is deleted? | **Yes** — lewat `support@rmebayanpeduli.com` |

### Data types

Centang 10 tipe ini, biarkan yang lain kosong:

| Kategori | Tipe yang dicentang | Data di app |
|---|---|---|
| Personal info | **Name** | nama staf dan pasien |
| Personal info | **Email address** | email akun staf |
| Personal info | **User IDs** | ID akun staf (pencatat dan pengubah data) |
| Personal info | **Address** | alamat pasien |
| Personal info | **Phone number** | nomor telepon pasien |
| Personal info | **Other info** | NIK, tanggal lahir, jenis kelamin, golongan darah, data wali |
| Health and fitness | **Health info** | keluhan, tanda vital, alergi, diagnosis, resep, hasil lab |
| Photos and videos | **Photos** | foto identitas pasien tanpa NIK |
| Files and docs | **Files and docs** | dokumen hasil lab |
| Device or other IDs | **Device or other IDs** | token notifikasi (Firebase Cloud Messaging) |

**Tidak dicentang:** Location, Financial info, Messages, Contacts, Calendar,
Audio, Web browsing, App activity, App info and performance (tidak ada crash log
atau diagnostik).

### Data usage and handling

Setelah tipe dicentang, setiap tipe muncul di daftar dengan tombol panah/**Start**.
Buka satu per satu dan jawab 4 pertanyaan berikut.

**Jawaban yang sama untuk semua tipe:**

| Pertanyaan di Console | Jawaban |
|---|---|
| Is this data collected, shared, or both? | ☑ **Collected** saja (☐ Shared) |
| Is this data processed ephemerally? | **No, this collected data is not processed ephemerally** (data disimpan di server dan di perangkat untuk offline) |

"Shared" tidak dicentang karena data tidak diberikan ke pihak ketiga. Firebase
Cloud Messaging dan penyedia server memproses data atas nama penerbit, dan menurut
aturan Play itu tidak dihitung sebagai "sharing".

**Jawaban yang berbeda per tipe** — pertanyaan *"Is this data required for your app,
or can users choose whether it's collected?"* dan *"Why is this user data collected?"*:

| Tipe | Required / Optional | Why is this user data collected? (centang) |
|---|---|---|
| Name | **Data collection is required** | App functionality · Account management |
| Email address | **Data collection is required** | App functionality · Account management |
| User IDs | **Data collection is required** | App functionality · Account management · Fraud prevention, security, and compliance |
| Address | **Users can choose whether this data is collected** | App functionality |
| Phone number | **Users can choose whether this data is collected** | App functionality |
| Other info | **Data collection is required** | App functionality |
| Health info | **Data collection is required** | App functionality |
| Photos | **Users can choose whether this data is collected** | App functionality |
| Files and docs | **Users can choose whether this data is collected** | App functionality |
| Device or other IDs | **Data collection is required** | App functionality |

Alasan pilihannya:
- **Optional** untuk alamat, telepon, foto, dan dokumen: kolomnya tidak wajib di
  form; foto hanya dipakai bila pasien tidak punya NIK, dokumen lab hanya bila
  petugas lab mengunggahnya.
- **Account management** untuk nama, email, dan ID: dipakai untuk login dan
  mengelola akun staf.
- **Fraud prevention, security, and compliance** untuk User IDs: audit log mencatat
  siapa yang membuat, mengubah, dan menghapus data rekam medis.
- Jangan centang **Analytics**, **Developer communications**, **Advertising or
  marketing**, atau **Personalization**: app tidak melakukan itu.

Setelah 10 tipe selesai, klik **Next** untuk melihat pratinjau label Data safety,
lalu **Save**.

---

## 4. App content lainnya

**Menu:** Policy and programs → App content

| Form | Jawaban |
|---|---|
| **Ads** | No, my app does not contain ads |
| **Target audience and content** | Usia **18 and over** saja. Tidak menarik bagi anak-anak. |
| **News apps** | No |
| **COVID-19 contact tracing and status apps** | My app is not a publicly available COVID-19 contact tracing or status app |
| **Government apps** | No (penerbit perorangan, bukan instansi pemerintah) |
| **Financial features** | My app doesn't provide any financial features |
| **Health apps** | Lihat di bawah |
| **Content rating** | Lihat di bawah |
| **App access** | Lihat bagian 5 |

### Health apps declaration

- Pilih kategori yang paling sesuai dengan app rekam medis klinis, misalnya
  **Electronic health records** dan **Healthcare services and management**.
  Nama opsi di Console bisa sedikit berbeda; pilih yang paling mendekati.
- Jangan pilih kategori *medical device* atau *clinical decision support*: app
  mencatat dan mengirim data, tidak mendiagnosis atau mengendalikan alat medis.
- Bila diminta penjelasan: *"Aplikasi internal rekam medis elektronik untuk staf
  Rumah Sakit Kapal Bayan Peduli. Staf mencatat pendaftaran, pemeriksaan, resep,
  dan hasil lab pasien yang dilayani di kapal. Tidak tersedia untuk publik; akun
  diberikan oleh pengelola rumah sakit kapal."*

### Content rating (kuesioner IARC)

| Pertanyaan | Jawaban |
|---|---|
| Email | `support@rmebayanpeduli.com` |
| Category | **All Other App Types** |
| Violence, sexuality, language, controlled substances, gambling | **No** semua |
| Does the app allow users to interact or exchange content with other users? | **No** (tidak ada chat atau konten publik antar pengguna) |
| Does the app share the user's current physical location? | **No** |
| Does the app allow users to purchase digital goods? | **No** |
| Is the app a web browser or search engine? | **No** |

Hasil yang diharapkan: rating semua umur / 3+. Target audience tetap 18+.

---

## 5. App access (akses untuk reviewer)

**Menu:** Policy and programs → App content → App access → **All or some
functionality in my app is restricted**

Siapkan dulu di backend production:
1. Akun demo, mis. `reviewer.play@[domain]`, role **Perawat**, yang ditugaskan ke
   kapal dan jadwal Ongoing berisi **data contoh** (bukan pasien asli).
2. Bila ingin reviewer melihat fitur dokter juga, buat akun kedua dengan role
   **Dokter** di kapal yang sama.

Isi form:

| Kolom | Isi |
|---|---|
| Name | `Akun demo reviewer (Perawat)` |
| Username / email | `[EMAIL AKUN DEMO]` |
| Password | `[PASSWORD AKUN DEMO]` |
| Any other information | lihat teks di bawah |

```
This app is for the staff of the Bayan Peduli hospital ship only; accounts are issued by the hospital ship's administration, there is no sign-up.

1. Open the app and sign in with the account above. No other steps (no OTP or 2FA).
2. The demo account is a nurse on a demo ship with sample data, so no real patient data is shown.
3. Main features: register a patient (Daftar Pasien), record complaints and vital signs, and view patient visits. The app also works offline and sends saved data when the connection is back.
```

Jangan pakai akun staf asli. Nonaktifkan atau ganti password akun demo bila
sudah tidak dipakai reviewer.
