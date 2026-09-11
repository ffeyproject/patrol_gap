/**
 * KONFIGURASI SISTEM PATROLI SECURITY
 * ------------------------------------
 * Semua nama sheet & struktur kolom didefinisikan di sini supaya
 * mudah disesuaikan tanpa harus mengubah logic di Code.gs
 */

// Baris tempat header kolom berada (baris 1-3 dipakai untuk judul sheet)
const HEADER_ROW = 4;
const DATA_START_ROW = 5;

// Nama-nama sheet (harus sama persis dengan tab di spreadsheet)
const SHEETS = {
  USERS: 'Users',
  SITES: 'Sites',
  CHECKPOINTS: 'Checkpoints',
  PATROL_LOGS: 'Patrol_Logs',
  INCIDENTS: 'Incidents',
  GUESTS: 'Guests'
};

// ID folder Google Drive untuk menyimpan foto (kosongkan '' agar dibuat otomatis)
const PHOTO_FOLDER_ID_PROP = 'PHOTO_FOLDER_ID';
const PHOTO_FOLDER_NAME = 'Patroli_Security_Photos';

// Radius toleransi geofencing SAAT SCAN CHECKPOINT PATROLI (meter).
// GPS petugas harus benar-benar dekat dengan titik checkpoint saat scan QR.
const PATROL_GEOFENCE_RADIUS_M = 30;

// Role yang dikenali sistem
const ROLES = {
  ADMIN: 'Super Admin',
  DANRU: 'Danru',
  SUPERVISOR: 'Supervisor',
  SATPAM: 'Satpam'
};