# 📱 RESTful API Documentation - Patroli Security GAP (Mobile Flutter)

Dokumentasi lengkap REST API untuk integrasi aplikasi mobile Satpam & Danru berbasis Flutter.

---

## 🌐 Informasi Dasar (Base Configuration)

- **Base URL**: `http://<SERVER_IP>:8000/api/v1` (contoh lokal: `http://10.0.2.2:8000/api/v1` untuk Android Emulator atau `http://192.168.1.X:8000/api/v1` untuk Physical Device).
- **Format Data**: JSON (`application/json`) dan Multipart Form Data (`multipart/form-data`) untuk upload foto selfie/laporan.
- **Header Standar**:
    ```http
    Accept: application/json
    Authorization: Bearer {YOUR_SANCTUM_TOKEN}
    ```

---

## 🔐 1. Authentication (Autentikasi)

### 1.1 Login Petugas / Admin

- **Endpoint**: `POST /auth/login`
- **Auth**: Public (Tidak butuh token)
- **Request Body (JSON)**:
    ```json
    {
        "login": "agus", // bisa berupa username, email, atau badge_number
        "password": "password",
        "device_name": "Flutter Android SM-A52"
    }
    ```
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Login berhasil.",
        "token": "1|n5f2Pxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        "user": {
            "id": 3,
            "name": "Agus Pratama",
            "username": "agus",
            "email": "agus@patroli.id",
            "badge_number": "SEC-002",
            "phone": "081234567892",
            "role": "satpam",
            "avatar": null,
            "is_active": true
        }
    }
    ```
- **Response Error Password Salah (`401 Unauthorized`)**:
    ```json
    {
        "success": false,
        "message": "Kredensial login tidak valid. Sisa percobaan: 3 kali sebelum terkunci sementara.",
        "remaining_attempts": 3
    }
    ```
- **Response Rate Limiting > 5 Percobaan Gagal (`429 Too Many Requests`)**:
    ```json
    {
        "success": false,
        "message": "Terlalu banyak percobaan login gagal. Akun/IP dibatasi sementara, silakan coba lagi dalam 54 detik.",
        "retry_after_seconds": 54
    }
    ```

### 1.2 Get User Profile

- **Endpoint**: `GET /auth/profile`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": {
            "id": 3,
            "name": "Agus Pratama",
            "email": "agus@patroli.id",
            "badge_number": "SEC-002",
            "role": "satpam"
        }
    }
    ```

### 1.3 Logout

- **Endpoint**: `POST /auth/logout`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Berhasil logout."
    }
    ```

---

## 🕒 2. Attendance (Presensi Masuk & Keluar Shift)

### 2.1 Cek Status Presensi Hari Ini

- **Endpoint**: `GET /attendance/status`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": {
            "is_checked_in": true,
            "is_checked_out": false,
            "attendance": {
                "id": 1,
                "site_id": 1,
                "site_name": "Site Gedung Menara Utama",
                "check_in_at": "06:48:00",
                "check_out_at": null,
                "check_in_lat": -6.229746,
                "check_in_lng": 106.8295175,
                "status": "present"
            }
        }
    }
    ```

### 2.2 Check-In Shift Masuk (Selfie + GPS)

- **Endpoint**: `POST /attendance/check-in`
- **Auth**: Bearer Token
- **Content-Type**: `multipart/form-data`
- **Form Fields**:
  | Field | Tipe | Keterangan |
  | :--- | :--- | :--- |
  | `site_id` | `int` | ID Site lokasi kerja |
  | `latitude` | `double` | Koordinat latitude satpam (misal: `-6.2297460`) |
  | `longitude` | `double` | Koordinat longitude satpam (misal: `106.8295175`) |
  | `selfie_photo` | `File / Image` | Foto selfie kehadiran (otomatis dicap watermark) |
  | `notes` | `string` _(Opsional)_ | Catatan (misal: `"Hadir tepat waktu siap tugas"`) |

- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Presensi masuk berhasil dicatat.",
        "data": {
            "id": 5,
            "user_id": 3,
            "site_id": 1,
            "check_in_at": "06:55:00",
            "status": "present"
        }
    }
    ```

### 2.3 Check-Out Shift Pulang

- **Endpoint**: `POST /attendance/check-out`
- **Auth**: Bearer Token
- **Content-Type**: `multipart/form-data`
- **Form Fields**: `latitude`, `longitude`, `notes` (opsional).
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Presensi keluar berhasil dicatat."
    }
    ```

---

## 🛡️ 3. Patroli Keamanan (Schedules, Sesi, Scan QR & Geofencing)

### 3.1 Ambil Jadwal Shift Saya

- **Endpoint**: `GET /patrol/my-schedules`
- **Auth**: Bearer Token
- **Deskripsi**: Mengambil daftar shift yang ditugaskan kepada satpam yang sedang login (atau seluruh jadwal aktif jika role `danru` / `admin` / `superadmin`). Otomatis dilengkapi deteksi shift aktif (`is_current_shift`), status sesi ronde berjalan (`has_active_session`), jumlah ronde yang selesai hari ini (`completed_rounds_count`), dan diurutkan dengan shift yang sedang aktif di urutan pertama.
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": [
            {
                "id": 1,
                "site_id": 1,
                "shift_name": "Shift Pagi (07:00 - 15:00)",
                "start_time": "07:00:00",
                "end_time": "15:00:00",
                "min_patrol_rounds": 3,
                "is_active": true,
                "is_current_shift": true,
                "has_active_session": true,
                "active_session_id": 12,
                "active_round_number": 1,
                "completed_rounds_count": 0,
                "total_checkpoints": 6,
                "site": {
                    "id": 1,
                    "name": "Site Gedung Menara Utama",
                    "code": "SITE-MK",
                    "latitude": -6.2297465,
                    "longitude": 106.829518,
                    "checkpoints": [
                        {
                            "id": 1,
                            "name": "Pos Jaga Gerbang Utama",
                            "code": "CP-01",
                            "qr_token": "CP-GB-UTAMA-01",
                            "latitude": -6.2297465,
                            "longitude": 106.829518,
                            "max_radius_meters": 10,
                            "order_index": 1,
                            "is_active": true
                        },
                        {
                            "id": 2,
                            "name": "Lobby Utama & Resepsionis",
                            "code": "CP-02",
                            "qr_token": "CP-LB-UTAMA-02",
                            "latitude": -6.2298,
                            "longitude": 106.8296,
                            "max_radius_meters": 10,
                            "order_index": 2,
                            "is_active": true
                        }
                    ]
                }
            }
        ]
    }
    ```

### 3.2 Mulai Sesi Ronde Patroli

- **Endpoint**: `POST /patrol/session/start`
- **Auth**: Bearer Token
- **Deskripsi**: Memulai sesi ronde patroli baru untuk jadwal shift yang dipilih.
  - **Otomatisasi Ronde Berurutan**: Nomor ronde (`round_number`) dihitung otomatis secara berurutan per jadwal shift hari ini (Round 1, Round 2, Round 3, dst.).
  - **Izin Shift Petugas**: Hanya satpam yang ditugaskan pada jadwal shift tersebut (atau `danru` / `admin`) yang dapat memulai sesi.
  - **Proteksi Sesi Aktif**: Jika sudah ada sesi aktif untuk shift ini (misal dimulai rekan satu shift), sistem mengembalikan data sesi aktif tersebut agar dapat langsung dilanjutkan tanpa membuat duplikasi ronde.
- **Request Body (JSON)**:
    ```json
    {
        "patrol_schedule_id": 1,
        "notes": "Memulai patroli round 1 lantai basement & lobby"
    }
    ```
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Sesi Patroli Round 1 (Shift Pagi (07:00 - 15:00)) berhasil dimulai. Silakan scan titik lokasi.",
        "data": {
            "session_id": 12,
            "round_number": 1,
            "status": "in_progress",
            "started_at": "2026-09-19 07:15:00",
            "completed_at": null,
            "schedule": {
                "id": 1,
                "shift_name": "Shift Pagi (07:00 - 15:00)",
                "start_time": "07:00:00",
                "end_time": "15:00:00",
                "min_patrol_rounds": 3
            },
            "site": {
                "id": 1,
                "name": "Site Gedung Menara Utama",
                "code": "SITE-MK"
            },
            "user": {
                "id": 3,
                "name": "Agus Pratama",
                "badge_number": "SEC-002"
            },
            "progress": {
                "total_checkpoints": 6,
                "scanned_count": 0,
                "percentage": 0,
                "is_all_scanned": false
            },
            "checkpoints": [
                {
                    "id": 1,
                    "name": "Pos Jaga Gerbang Utama",
                    "code": "CP-01",
                    "qr_token": "CP-GB-UTAMA-01",
                    "latitude": -6.2297465,
                    "longitude": 106.829518,
                    "max_radius_meters": 10,
                    "order_index": 1,
                    "is_scanned": false,
                    "scanned_at": null,
                    "selfie_photo": null,
                    "distance_meters": null
                }
            ]
        }
    }
    ```
- **Response Error Tidak Terdaftar di Shift (`403 Forbidden`)**:
    ```json
    {
        "success": false,
        "message": "Akses ditolak! Anda tidak memiliki jadwal penugasan patroli pada shift ini."
    }
    ```

### 3.3 Ambil Sesi Patroli Aktif & Checklist Checkpoint

- **Endpoint**: `GET /patrol/session/active`
- **Auth**: Bearer Token
- **Deskripsi**: Mengambil sesi patroli yang sedang berjalan (`status: "in_progress"`) milik satpam yang login atau sesi pada shift yang ditugaskan kepadanya (multi-guard shift sharing).
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": {
            "session_id": 12,
            "round_number": 1,
            "status": "in_progress",
            "started_at": "2026-09-19 07:15:00",
            "completed_at": null,
            "schedule": {
                "id": 1,
                "shift_name": "Shift Pagi (07:00 - 15:00)",
                "start_time": "07:00:00",
                "end_time": "15:00:00",
                "min_patrol_rounds": 3
            },
            "site": {
                "id": 1,
                "name": "Site Gedung Menara Utama",
                "code": "SITE-MK"
            },
            "user": {
                "id": 3,
                "name": "Agus Pratama",
                "badge_number": "SEC-002"
            },
            "progress": {
                "total_checkpoints": 6,
                "scanned_count": 1,
                "percentage": 17,
                "is_all_scanned": false
            },
            "checkpoints": [
                {
                    "id": 1,
                    "name": "Pos Jaga Gerbang Utama",
                    "code": "CP-01",
                    "qr_token": "CP-GB-UTAMA-01",
                    "latitude": -6.2297465,
                    "longitude": 106.829518,
                    "max_radius_meters": 10,
                    "order_index": 1,
                    "is_scanned": true,
                    "scanned_at": "07:18:22",
                    "selfie_photo": "http://10.0.2.2:8000/storage/patrol_selfies/watermarked_xxx.jpg",
                    "distance_meters": 1.4
                },
                {
                    "id": 2,
                    "name": "Lobby Utama & Resepsionis",
                    "code": "CP-02",
                    "qr_token": "CP-LB-UTAMA-02",
                    "latitude": -6.2298,
                    "longitude": 106.8296,
                    "max_radius_meters": 10,
                    "order_index": 2,
                    "is_scanned": false,
                    "scanned_at": null,
                    "selfie_photo": null,
                    "distance_meters": null
                }
            ]
        }
    }
    ```
- **Response Jika Tidak Ada Sesi Aktif (`200 OK`)**:
    ```json
    {
        "success": false,
        "message": "Tidak ada sesi patroli aktif saat ini.",
        "data": null
    }
    ```

### 3.4 Scan QR Checkpoint (Geofencing & Watermark)

- **Endpoint**: `POST /patrol/scan`
- **Auth**: Bearer Token
- **Content-Type**: `multipart/form-data`
- **Hak Akses**: Satpam pembuat sesi, atau seluruh satpam yang ditugaskan pada shift yang sama, atau role `danru` / `admin`.
- **Aturan Urutan Scan (Sequential Scan)**: Titik checkpoint **wajib discan sesuai urutan** (`order_index` 1, 2, 3, dst.). Satpam tidak dapat melompati atau mengacak titik checkpoint.
- **Form Fields**:
  | Field | Tipe | Deskripsi |
  | :--- | :--- | :--- |
  | `patrol_session_id` | `int` | ID sesi patroli yang sedang aktif |
  | `qr_token` | `string` | Hasil teks scan QR Code (misal: `"CP-GB-UTAMA-01"`) |
  | `latitude` | `double` | Latitude GPS satpam saat scan (misal: `-6.2297465`) |
  | `longitude` | `double` | Longitude GPS satpam saat scan (misal: `106.8295180`) |
  | `selfie_photo` | `File / Image` | Foto selfie satpam di depan titik checkpoint |
  | `condition_status` | `string` *(Opsional)* | Pilihan: `"normal"` (default), `"warning"`, atau `"danger"` |
  | `notes` | `string` *(Opsional)* | Catatan kondisi fisik di titik checkpoint |

- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Titik [Pos Jaga Gerbang Utama] berhasil discan! Jarak: 1.8m.",
        "data": {
            "log": {
                "id": 14,
                "patrol_session_id": 12,
                "checkpoint_id": 1,
                "user_id": 3,
                "scanned_at": "2026-09-19T07:18:22.000000Z",
                "selfie_photo_path": "storage/patrol_selfies/watermark_1725700000.jpg",
                "latitude": -6.2297465,
                "longitude": 106.829518,
                "distance_meters": 1.8,
                "is_valid_location": true,
                "condition_status": "normal",
                "notes": null,
                "checkpoint": {
                    "id": 1,
                    "name": "Pos Jaga Gerbang Utama",
                    "code": "CP-01"
                }
            },
            "distance_meters": 1.8,
            "scanned_checkpoints": 1,
            "total_checkpoints": 6,
            "is_all_scanned": false,
            "next_checkpoint": {
                "id": 2,
                "name": "Lobby Utama & Resepsionis",
                "code": "CP-02",
                "order_index": 2
            }
        }
    }
    ```

- **Response Error Urutan Scan Salah (`422 Unprocessable Content`)**:
    ```json
    {
        "success": false,
        "message": "Urutan scan tidak sesuai! Anda harus scan titik ke-1 [Pos Jaga Gerbang Utama] terlebih dahulu sebelum titik ke-2 [Lobby Utama & Resepsionis].",
        "expected_checkpoint": {
            "id": 1,
            "name": "Pos Jaga Gerbang Utama",
            "code": "CP-01",
            "order_index": 1
        }
    }
    ```

- **Response Error Radius > 10 Meter (`422 Unprocessable Content`)**:
    ```json
    {
        "success": false,
        "message": "Posisi Anda terlalu jauh dari titik (28.4 meter). Maksimal radius yang diizinkan adalah 10 meter!",
        "distance_meters": 28.4,
        "max_radius_meters": 10,
        "checkpoint_name": "Pos Jaga Gerbang Utama"
    }
    ```

- **Response Error Bukan Pemilik/Bukan Shift Anda (`403 Forbidden`)**:
    ```json
    {
        "success": false,
        "message": "Sesi patroli ini bukan milik akun Anda dan Anda tidak ditugaskan pada jadwal shift ini."
    }
    ```

### 3.5 Selesaikan Ronde Patroli

- **Endpoint**: `POST /patrol/session/finish`
- **Auth**: Bearer Token
- **Deskripsi**: Menyelesaikan sesi ronde patroli yang sedang berjalan.
  - **Validasi Kelengkapan Titik**: Secara default seluruh titik checkpoint aktif pada site tersebut wajib discan (`scanned_checkpoints == total_checkpoints`) sebelum ronde dapat diselesaikan.
  - **Parameter Force**: Parameter `force: true` dapat digunakan (khusus kondisi darurat atau role Danru/Admin) untuk memaksa penyelesaian ronde meski belum semua titik discan.
- **Request Body (JSON)**:
    ```json
    {
        "patrol_session_id": 12,
        "notes": "Ronde 1 selesai, seluruh pintu darurat dan server terkunci rapat.",
        "force": false
    }
    ```
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Sesi Patroli Round 1 selesai (6/6 titik). Terima kasih!",
        "data": {
            "session_id": 12,
            "round_number": 1,
            "status": "completed",
            "started_at": "2026-09-19 07:15:00",
            "completed_at": "2026-09-19 07:45:00",
            "schedule": {
                "id": 1,
                "shift_name": "Shift Pagi (07:00 - 15:00)",
                "start_time": "07:00:00",
                "end_time": "15:00:00",
                "min_patrol_rounds": 3
            },
            "site": {
                "id": 1,
                "name": "Site Gedung Menara Utama",
                "code": "SITE-MK"
            },
            "user": {
                "id": 3,
                "name": "Agus Pratama",
                "badge_number": "SEC-002"
            },
            "progress": {
                "total_checkpoints": 6,
                "scanned_count": 6,
                "percentage": 100,
                "is_all_scanned": true
            },
            "checkpoints": [ ... ]
        }
    }
    ```
- **Response Error Titik Belum Lengkap Discan (`422 Unprocessable Content`)**:
    ```json
    {
        "success": false,
        "message": "Ronde 1 belum selesai! Baru 4 dari 6 titik checkpoint yang discan. Silakan scan semua titik sebelum mengakhiri ronde.",
        "data": {
            "scanned_count": 4,
            "total_checkpoints": 6,
            "missing_count": 2
        }
    }
    ```
- **Response Error Bukan Pemilik/Bukan Shift Anda (`403 Forbidden`)**:
    ```json
    {
        "success": false,
        "message": "Unauthorized. Sesi patroli bukan milik akun Anda dan Anda tidak terdaftar pada jadwal shift ini."
    }
    ```

### 3.6 Rekap Laporan Patroli per Titik (Checkpoints)

- **Endpoint**: `GET /patrol/recap/checkpoints`
- **Auth**: Bearer Token
- **Query Params**:
  - `site_id` *(Opsional)*: Filter berdasarkan ID Site/Lokasi
  - `start_date` *(Opsional, format: `YYYY-MM-DD`)*: Tanggal awal filter
  - `end_date` *(Opsional, format: `YYYY-MM-DD`)*: Tanggal akhir filter
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": {
            "summary": {
                "total_checkpoints": 8,
                "total_scans": 24
            },
            "checkpoints": [
                {
                    "id": 1,
                    "name": "Pos Jaga Gerbang Utama",
                    "code": "CP-01",
                    "site_id": 1,
                    "site_name": "Site Gedung Menara Utama",
                    "max_radius_meters": 10,
                    "order_index": 1,
                    "is_active": true,
                    "total_scans": 4,
                    "avg_distance_meters": 2.1,
                    "last_scanned_at": "19 Sep 2026, 14:15",
                    "last_guard_name": "Agus Pratama",
                    "last_condition_status": "normal",
                    "recent_logs": [
                        {
                            "id": 42,
                            "scanned_at": "19 Sep 2026, 14:15:20",
                            "guard_name": "Agus Pratama",
                            "guard_badge": "SEC-002",
                            "distance_meters": 1.8,
                            "condition_status": "normal",
                            "selfie_photo_url": "http://10.0.2.2:8000/storage/patrol_selfies/watermark_1725700000.jpg",
                            "notes": "Aman terkendali"
                        }
                    ]
                }
            ]
        }
    }
    ```

---

## 📡 4. Peta Live Satpam (Live Radar Tracking)

### 4.1 Ambil Posisi GPS Seluruh Satpam yang Hadir

- **Endpoint**: `GET /live/guards`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": {
            "total_guards_present": 3,
            "total_in_patrol": 1,
            "active_guards": [
                {
                    "id": 3,
                    "name": "Agus Pratama",
                    "role": "SATPAM",
                    "badge_number": "SEC-002",
                    "site_name": "Site Gedung Menara Utama",
                    "check_in_at": "06:48:00",
                    "status": "Patroli Aktif (Round 1)",
                    "latitude": -6.2298,
                    "longitude": 106.8296,
                    "last_checkpoint_name": "Lobby Utama",
                    "last_scanned_at": "07:22:10 WIB",
                    "last_distance_meters": 1.2,
                    "is_in_patrol": true
                }
            ]
        }
    }
    ```

---

## ⚠️ 5. Laporan Insiden Keamanan

### 5.1 Ambil Daftar Insiden

- **Endpoint**: `GET /incidents`
- **Auth**: Bearer Token
- **Query Params**: `site_id` _(Opsional)_, `status` (`open` / `resolved`)

### 5.2 Buat Laporan Insiden Temuan

- **Endpoint**: `POST /incidents`
- **Auth**: Bearer Token
- **Content-Type**: `multipart/form-data`
- **Form Fields**:
  | Field | Tipe | Keterangan |
  | :--- | :--- | :--- |
  | `site_id` | `int` | ID Site kejadian |
  | `checkpoint_id` | `int` _(Opsional)_ | ID Checkpoint lokasi temuan |
  | `title` | `string` | Judul temuan (misal: `"Pintu Darurat Terganjal Kardus"`) |
  | `description` | `string` | Rincian temuan insiden |
  | `severity` | `string` | `"low"`, `"medium"`, atau `"high"` |
  | `photo` | `File / Image` _(Opsional)_ | Foto bukti kejadian di lapangan |

---

## 📄 6. Buku Tamu Digital (Visitors)

### 6.1 Daftar Buku Tamu

- **Endpoint**: `GET /visitors`
- **Auth**: Bearer Token

### 6.2 Check-In Tamu Baru

- **Endpoint**: `POST /visitors`
- **Auth**: Bearer Token
- **Content-Type**: `multipart/form-data` / `application/json`
- **Fields**: `site_id`, `guest_name`, `company`, `destination`, `purpose`, `vehicle_number`, `id_card_number`, `photo`.

### 6.3 Check-Out Tamu

- **Endpoint**: `POST /visitors/{id}/checkout`
- **Auth**: Bearer Token

---

## 📍 7. Master Site & Checkpoint (CRUD & Geofencing)

### 7.1 Ambil Semua Site & Titik Checkpoint
- **Endpoint**: `GET /sites`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": [
            {
                "id": 1,
                "name": "Site Gedung Menara Utama",
                "code": "SITE-MK",
                "address": "Jl. Jend. Sudirman Kav. 21, Jakarta Selatan",
                "latitude": -6.2297465,
                "longitude": 106.829518,
                "geofence_radius_meters": 50,
                "is_active": true,
                "checkpoints_count": 2,
                "checkpoints": [
                    {
                        "id": 1,
                        "site_id": 1,
                        "name": "Pos Jaga Gerbang Utama",
                        "code": "CP-01",
                        "qr_token": "CP-GB-UTAMA-01",
                        "qr_image_url": "http://10.0.2.2:8000/api/qr/CP-GB-UTAMA-01.png",
                        "location_description": "Periksa buku tamu & palang gerbang",
                        "latitude": -6.2297465,
                        "longitude": 106.829518,
                        "max_radius_meters": 10,
                        "order_index": 1,
                        "is_active": true
                    }
                ]
            }
        ]
    }
    ```

### 7.2 Tambah Site / Gedung Baru
- **Endpoint**: `POST /sites`
- **Auth**: Bearer Token
- **Request Body (JSON)**:
    ```json
    {
        "name": "Site PT. Gajah Angkasa Perkasa",
        "code": "SITE-GAP-01",
        "address": "Jl. Jend. Sudirman Kav. 21, Jakarta Selatan",
        "latitude": -6.2297465,
        "longitude": 106.829518,
        "geofence_radius_meters": 50
    }
    ```
- **Response Success (`201 Created`)**:
    ```json
    {
        "success": true,
        "message": "Site / Lokasi baru berhasil ditambahkan.",
        "data": {
            "id": 2,
            "name": "Site PT. Gajah Angkasa Perkasa",
            "code": "SITE-GAP-01",
            "address": "Jl. Jend. Sudirman Kav. 21, Jakarta Selatan",
            "latitude": -6.2297465,
            "longitude": 106.829518,
            "geofence_radius_meters": 50,
            "is_active": true
        }
    }
    ```

### 7.3 Update / Edit Site
- **Endpoint**: `PUT /sites/{id}` atau `POST /sites/{id}`
- **Auth**: Bearer Token
- **Request Body (JSON)**:
    ```json
    {
        "name": "Site PT. Gajah Angkasa Perkasa (Pusat)",
        "code": "SITE-GAP-01",
        "address": "Jl. Jend. Sudirman Kav. 21, Jakarta Selatan",
        "latitude": -6.2297465,
        "longitude": 106.829518,
        "geofence_radius_meters": 75,
        "is_active": true
    }
    ```
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Data Site / Lokasi berhasil diperbarui.",
        "data": {
            "id": 2,
            "name": "Site PT. Gajah Angkasa Perkasa (Pusat)",
            "code": "SITE-GAP-01",
            "address": "Jl. Jend. Sudirman Kav. 21, Jakarta Selatan",
            "latitude": -6.2297465,
            "longitude": 106.829518,
            "geofence_radius_meters": 75,
            "is_active": true
        }
    }
    ```

### 7.4 Hapus Site
- **Endpoint**: `DELETE /sites/{id}`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Site / Lokasi berhasil dihapus."
    }
    ```

### 7.5 Ambil Titik Checkpoint Berdasarkan Site
- **Endpoint**: `GET /sites/{site_id}/checkpoints`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": {
            "site": {
                "id": 1,
                "name": "Site Gedung Menara Utama",
                "code": "SITE-MK"
            },
            "checkpoints": [
                {
                    "id": 1,
                    "site_id": 1,
                    "name": "Pos Jaga Gerbang Utama",
                    "code": "CP-01",
                    "qr_token": "CP-GB-UTAMA-01",
                    "qr_image_url": "http://10.0.2.2:8000/api/qr/CP-GB-UTAMA-01.png",
                    "location_description": "Periksa buku tamu & palang gerbang",
                    "latitude": -6.2297465,
                    "longitude": 106.829518,
                    "max_radius_meters": 10,
                    "order_index": 1,
                    "is_active": true
                }
            ]
        }
    }
    ```

### 7.6 Tambah Titik Checkpoint Patroli Baru
- **Endpoint**: `POST /checkpoints`
- **Auth**: Bearer Token
- **Request Body (JSON)**:
    ```json
    {
        "site_id": 1,
        "name": "Pintu Darurat Lantai 3 Sayap Barat",
        "code": "CP-08",
        "latitude": -6.22985,
        "longitude": 106.82965,
        "max_radius_meters": 10,
        "order_index": 8,
        "location_description": "Pastikan gembok tidak terkunci dari dalam dan bebas halangan."
    }
    ```
- **Response Success (`201 Created`)**:
    ```json
    {
        "success": true,
        "message": "Titik lokasi patroli baru berhasil ditambahkan.",
        "data": {
            "checkpoint": {
                "id": 8,
                "site_id": 1,
                "name": "Pintu Darurat Lantai 3 Sayap Barat",
                "code": "CP-08",
                "qr_token": "CP-X9K2LA7P1M0Q",
                "latitude": -6.22985,
                "longitude": 106.82965,
                "max_radius_meters": 10,
                "order_index": 8,
                "is_active": true
            },
            "qr_image_url": "http://10.0.2.2:8000/api/qr/CP-X9K2LA7P1M0Q.png"
        }
    }
    ```

### 7.7 Update / Edit Titik Checkpoint Patroli
- **Endpoint**: `PUT /checkpoints/{id}` atau `POST /checkpoints/{id}`
- **Auth**: Bearer Token
- **Request Body (JSON)**:
    ```json
    {
        "name": "Pintu Darurat Lantai 3 Sayap Barat (Revisi)",
        "code": "CP-08",
        "latitude": -6.22985,
        "longitude": 106.82965,
        "max_radius_meters": 10,
        "order_index": 8,
        "location_description": "Instruksi diperbarui: Periksa segel pintu & tabung APAR.",
        "is_active": true
    }
    ```
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Titik lokasi patroli berhasil diperbarui.",
        "data": {
            "checkpoint": {
                "id": 8,
                "name": "Pintu Darurat Lantai 3 Sayap Barat (Revisi)",
                "code": "CP-08",
                "qr_token": "CP-X9K2LA7P1M0Q",
                "latitude": -6.22985,
                "longitude": 106.82965,
                "max_radius_meters": 10,
                "order_index": 8,
                "is_active": true
            },
            "qr_image_url": "http://10.0.2.2:8000/api/qr/CP-X9K2LA7P1M0Q.png"
        }
    }
    ```

### 7.8 Hapus Titik Checkpoint Patroli
- **Endpoint**: `DELETE /checkpoints/{id}`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Titik lokasi patroli berhasil dihapus."
    }
    ```

---

## 💻 8. Contoh Integrasi Flutter (Dio Service)

```dart
import 'package:dio/dio.dart';

class PatroliApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://10.0.2.2:8000/api/v1',
    headers: {
      'Accept': 'application/json',
    },
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // 1. Login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'login': email,
      'password': password,
      'device_name': 'Flutter Mobile App',
    });
    return response.data;
  }

  // 2. Ambil Jadwal Shift Satpam
  Future<Map<String, dynamic>> getMySchedules() async {
    final response = await _dio.get('/patrol/my-schedules');
    return response.data;
  }

  // 3. Mulai Sesi Ronde Patroli
  Future<Map<String, dynamic>> startPatrolSession({
    required int scheduleId,
    String? notes,
  }) async {
    final response = await _dio.post('/patrol/session/start', data: {
      'patrol_schedule_id': scheduleId,
      'notes': notes,
    });
    return response.data;
  }

  // 4. Ambil Sesi Patroli Aktif
  Future<Map<String, dynamic>> getActivePatrolSession() async {
    final response = await _dio.get('/patrol/session/active');
    return response.data;
  }

  // 5. Scan QR Checkpoint (Watermark + Geofencing <=10m)
  Future<Map<String, dynamic>> scanCheckpoint({
    required int patrolSessionId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required String selfieFilePath,
    String conditionStatus = 'normal',
    String? notes,
  }) async {
    final formData = FormData.fromMap({
      'patrol_session_id': patrolSessionId,
      'qr_token': qrToken,
      'latitude': latitude,
      'longitude': longitude,
      'condition_status': conditionStatus,
      'notes': notes ?? '',
      'selfie_photo': await MultipartFile.fromFile(
        selfieFilePath,
        filename: 'selfie_scan.jpg',
      ),
    });

    final response = await _dio.post('/patrol/scan', data: formData);
    return response.data;
  }

  // 6. Selesaikan Sesi Ronde Patroli
  Future<Map<String, dynamic>> finishPatrolSession({
    required int patrolSessionId,
    String? notes,
    bool force = false,
  }) async {
    final response = await _dio.post('/patrol/session/finish', data: {
      'patrol_session_id': patrolSessionId,
      'notes': notes,
      'force': force,
    });
    return response.data;
  }

  // 7. Tambah Checkpoint Baru
  Future<Map<String, dynamic>> addCheckpoint({
    required int siteId,
    required String name,
    required String code,
    required double latitude,
    required double longitude,
    int maxRadiusMeters = 10,
    String? locationDescription,
  }) async {
    final response = await _dio.post('/checkpoints', data: {
      'site_id': siteId,
      'name': name,
      'code': code,
      'latitude': latitude,
      'longitude': longitude,
      'max_radius_meters': maxRadiusMeters,
      'location_description': locationDescription ?? '',
    });
    return response.data;
  }

  // 8. Update Checkpoint
  Future<Map<String, dynamic>> updateCheckpoint({
    required int checkpointId,
    required String name,
    required String code,
    required double latitude,
    required double longitude,
    int maxRadiusMeters = 10,
    String? locationDescription,
  }) async {
    final response = await _dio.post('/checkpoints/$checkpointId', data: {
      'name': name,
      'code': code,
      'latitude': latitude,
      'longitude': longitude,
      'max_radius_meters': maxRadiusMeters,
      'location_description': locationDescription ?? '',
    });
    return response.data;
  }
}
```
