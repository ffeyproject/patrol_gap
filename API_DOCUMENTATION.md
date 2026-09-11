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
- **Deskripsi**: Mengambil daftar shift yang ditugaskan kepada satpam ini beserta daftar checkpoint site tersebut.
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
                            "max_radius_meters": 10
                        },
                        {
                            "id": 2,
                            "name": "Lobby Utama & Resepsionis",
                            "code": "CP-02",
                            "qr_token": "CP-LB-UTAMA-02",
                            "latitude": -6.2298,
                            "longitude": 106.8296,
                            "max_radius_meters": 10
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
- **Request Body (JSON)**:
    ```json
    {
        "patrol_schedule_id": 1,
        "round_number": 1,
        "notes": "Memulai patroli round 1 lantai basement & lobby"
    }
    ```
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Sesi Patroli Round 1 berhasil dimulai. Silakan scan titik lokasi.",
        "data": {
            "session_id": 2,
            "round_number": 1,
            "started_at": "07:15:00",
            "status": "in_progress",
            "total_checkpoints": 6,
            "scanned_count": 0,
            "remaining_count": 6
        }
    }
    ```

### 3.3 Ambil Sesi Patroli Aktif & Checklist Checkpoint

- **Endpoint**: `GET /patrol/session/active`
- **Auth**: Bearer Token
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "data": {
            "session_id": 2,
            "round_number": 1,
            "status": "in_progress",
            "started_at": "07:15:00",
            "site_name": "Site Gedung Menara Utama",
            "total_checkpoints": 6,
            "scanned_count": 1,
            "remaining_count": 5,
            "checkpoints": [
                {
                    "id": 1,
                    "name": "Pos Jaga Gerbang Utama",
                    "code": "CP-01",
                    "qr_token": "CP-GB-UTAMA-01",
                    "latitude": -6.2297465,
                    "longitude": 106.829518,
                    "is_scanned": true,
                    "scanned_at": "07:18:22 WIB",
                    "distance_meters": 1.4,
                    "condition_status": "normal",
                    "selfie_url": "http://10.0.2.2:8000/storage/patrol_selfies/watermarked_xxx.jpg"
                },
                {
                    "id": 2,
                    "name": "Lobby Utama & Resepsionis",
                    "code": "CP-02",
                    "qr_token": "CP-LB-UTAMA-02",
                    "latitude": -6.2298,
                    "longitude": 106.8296,
                    "is_scanned": false,
                    "scanned_at": null
                }
            ]
        }
    }
    ```

### 3.4 Scan QR Checkpoint (Core Engine: Geofencing & Watermark)

- **Endpoint**: `POST /patrol/scan`
- **Auth**: Bearer Token
- **Content-Type**: `multipart/form-data`
- **Form Fields**:
  | Field | Tipe | Deskripsi |
  | :--- | :--- | :--- |
  | `patrol_session_id` | `int` | ID sesi patroli yang sedang aktif |
  | `qr_token` | `string` | Hasil teks scan QR Code (misal: `"CP-GB-UTAMA-01"`) |
  | `latitude` | `double` | Latitude GPS satpam saat scan (misal: `-6.2297465`) |
  | `longitude` | `double` | Longitude GPS satpam saat scan (misal: `106.8295180`) |
  | `selfie_photo` | `File / Image` | Foto selfie satpam di depan titik checkpoint |
  | `condition_status` | `string` | Pilihan: `"normal"`, `"warning"`, atau `"danger"` |
  | `notes` | `string` | Catatan temuan kondisi fisik di titik checkpoint |

- **Response Success (`200 OK`)**:

    ```json
    {
        "success": true,
        "message": "Checkpoint 'Pos Jaga Gerbang Utama' berhasil discan dan diverifikasi.",
        "data": {
            "log_id": 14,
            "checkpoint_name": "Pos Jaga Gerbang Utama",
            "distance_meters": 1.8,
            "scanned_at": "07:18:22 WIB",
            "selfie_photo_url": "http://10.0.2.2:8000/storage/patrol_selfies/watermark_1725700000.jpg",
            "condition_status": "normal",
            "scanned_count": 1,
            "total_checkpoints": 6,
            "is_round_complete": false
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

### 3.5 Selesaikan Ronde Patroli

- **Endpoint**: `POST /patrol/session/finish`
- **Auth**: Bearer Token
- **Request Body (JSON)**:
    ```json
    {
        "patrol_session_id": 2,
        "notes": "Ronde 1 selesai, seluruh pintu darurat dan server terkunci rapat."
    }
    ```
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "message": "Sesi patroli round 1 telah berhasil diselesaikan.",
        "data": {
            "session_id": 2,
            "status": "completed",
            "completed_at": "07:45:00"
        }
    }
    ```

### 3.6 Rekap Laporan Patroli per Titik (Checkpoints)

- **Endpoint**: `GET /patrol/recap/checkpoints`
- **Auth**: Bearer Token
- **Query Params**:
  - `site_id` *(Opsional)*: Filter berdasarkan ID Site/Lokasi
  - `start_date` *(Opsional, format: `YYYY-MM-DD`)*: Tanggal awal filter (Default: hari ini)
  - `end_date` *(Opsional, format: `YYYY-MM-DD`)*: Tanggal akhir filter (Default: hari ini)
- **Response Success (`200 OK`)**:
    ```json
    {
        "success": true,
        "filters": {
            "site_id": 1,
            "start_date": "2026-09-09",
            "end_date": "2026-09-09"
        },
        "metrics": {
            "total_checkpoints": 8,
            "scanned_checkpoints_count": 6,
            "unscanned_checkpoints_count": 2,
            "total_scan_events": 24,
            "total_incident_reports": 1
        },
        "data": [
            {
                "id": 1,
                "site_id": 1,
                "site_name": "Site Gedung Menara Utama",
                "name": "Pos Jaga Gerbang Utama",
                "code": "CP-01",
                "qr_token": "CP-GB-UTAMA-01",
                "latitude": -6.2297465,
                "longitude": 106.829518,
                "max_radius_meters": 10,
                "total_scans": 4,
                "incident_scans": 0,
                "normal_scans": 4,
                "avg_distance": 2.1,
                "last_scanned_at": "09/09/2026 14:15 WIB",
                "recent_logs": [
                    {
                        "id": 42,
                        "patrol_session_id": 10,
                        "round_number": 2,
                        "guard_name": "Agus Pratama",
                        "guard_badge": "SEC-002",
                        "distance_meters": 1.8,
                        "condition_status": "normal",
                        "notes": "Aman terkendali",
                        "selfie_photo_url": "http://10.0.2.2:8000/storage/patrol_selfies/watermark_1725700000.jpg",
                        "scanned_at": "09/09/2026 14:15:20 WIB"
                    }
                ]
            }
        ]
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

  // 2. Scan QR Checkpoint
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

  // 3. Tambah Checkpoint Baru
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

  // 4. Update Checkpoint
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
