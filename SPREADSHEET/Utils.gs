/**
 * UTILITAS UMUM
 * -------------
 */

function ss_() {
  return SpreadsheetApp.getActiveSpreadsheet();
}

function sheet_(name) {
  const sh = ss_().getSheetByName(name);
  if (!sh) throw new Error('Sheet tidak ditemukan: ' + name);
  return sh;
}

/**
 * Field yang berisi jam/tanggal (timestamp, checkin_time, checkout_time, dst).
 * Dipakai supaya kolom ini selalu dipaksa jadi TEKS, bukan tipe Date -
 * lihat penjelasan panjang di appendObject_() di bawah.
 */
function isTimeLikeField_(header) {
  if (!header) return false;
  const h = String(header).toLowerCase();
  return h === 'timestamp' || h.indexOf('_time') !== -1 || h.indexOf('_at') !== -1;
}

/**
 * Field koordinat GPS (lat/long). HARUS selalu ditulis sebagai Number murni,
 * bukan string - lihat penjelasan panjang di normalizeFieldValue_() di bawah.
 * Ini akar masalah "titik GPS tidak konsisten": kalau nilai dikirim sebagai
 * string (mis. dari form Dashboard), appendRow()/setValue() menyerahkan
 * proses "menerka" jenis datanya ke Google Sheets, dan Sheets membaca ulang
 * string itu memakai locale FILE spreadsheet. Pada locale Indonesia (id_ID),
 * tanda titik dibaca sebagai pemisah ribuan (bukan koma desimal), sehingga
 * "-6.915079" yang harusnya minus enam koma sekian, malah dibaca sebagai
 * minus enam juta sembilan ratus lima belas ribu tujuh puluh sembilan
 * (-6915079) - persis pola kerusakan yang terjadi di data Sites.
 */
function isCoordField_(header) {
  if (!header) return false;
  const h = String(header).toLowerCase();
  return h === 'latitude' || h === 'longitude' || h === 'lat' || h === 'long' ||
    h === 'target_lat' || h === 'target_long' || h === 'scan_lat' || h === 'scan_long';
}

/**
 * Field ID / kode / PIN. HARUS selalu dikunci sebagai format TEKS ('@'),
 * dengan alasan yang sama seperti isCoordField_ di atas: supaya Sheets tidak
 * pernah mencoba mengonversinya jadi tipe Number sendiri (yang bisa
 * menghilangkan angka nol di depan PIN, mis. "0823" -> 823, atau salah baca
 * ID numerik sebagai notasi ilmiah).
 */
function isTextLockField_(header) {
  if (!header) return false;
  const h = String(header).toLowerCase();
  if (h === 'pin_pass' || h === 'identity_no' || h === 'qr_code_val' || h === 'qr_guest_code' || h === 'username') return true;
  return h.indexOf('_id') !== -1; // site_id, checkpoint_id, user_id, log_id, incident_id, guest_id, assigned_site_id
}

/** Normalisasi 1 nilai field sebelum ditulis ke sheet, sesuai jenis field-nya. */
function normalizeFieldValue_(header, value) {
  if (isCoordField_(header)) {
    if (value === '' || value === null || value === undefined) return value;
    const n = parseFloat(value);
    return isNaN(n) ? value : n;
  }
  return value;
}

/** Mengubah 1 sheet menjadi array of object berdasarkan HEADER_ROW */
function sheetToObjects_(sheetName) {
  const sh = sheet_(sheetName);
  const lastRow = sh.getLastRow();
  const lastCol = sh.getLastColumn();
  if (lastRow < DATA_START_ROW) return [];

  const headers = sh.getRange(HEADER_ROW, 1, 1, lastCol).getValues()[0];
  const values = sh.getRange(DATA_START_ROW, 1, lastRow - DATA_START_ROW + 1, lastCol).getValues();

  const result = [];
  for (let i = 0; i < values.length; i++) {
    const row = values[i];
    // lewati baris yang benar-benar kosong (kolom pertama kosong)
    if (row[0] === '' || row[0] === null) continue;
    const obj = {};
    for (let c = 0; c < headers.length; c++) {
      const key = headers[c];
      if (!key) continue;
      let val = row[c];
      // CATATAN PENTING soal jam/tanggal:
      // Kolom jam SEHARUSNYA selalu teks polos (lihat appendObject_), tapi
      // baris LAMA yang sempat kebaca sebagai tipe Date oleh Google Sheets
      // (sebelum kolom dikunci jadi format Teks) tetap kita format di sini
      // sebagai fallback, supaya tidak tampil sebagai angka serial mentah.
      // Baris baru tidak akan lewat jalur ini lagi karena sudah dipaksa teks.
      if (val instanceof Date) {
        val = Utilities.formatDate(val, Session.getScriptTimeZone() || 'GMT+7', 'yyyy-MM-dd HH:mm:ss');
      }
      obj[key] = val;
    }
    obj.__row = DATA_START_ROW + i; // baris fisik di spreadsheet (untuk update)
    result.push(obj);
  }
  return result;
}

/** Menambahkan 1 baris baru ke sheet sesuai urutan header */
function appendObject_(sheetName, obj) {
  const sh = sheet_(sheetName);
  const lastCol = sh.getLastColumn();
  const headers = sh.getRange(HEADER_ROW, 1, 1, lastCol).getValues()[0];
  const row = headers.map(function (h) {
    if (!h || !obj.hasOwnProperty(h)) return '';
    // Koordinat GPS dipaksa jadi Number murni DI SINI, sebelum appendRow() -
    // lihat catatan lengkap di isCoordField_(). Kalau sudah berupa Number asli
    // (bukan string), Sheets tidak akan pernah menerka-nerka formatnya lagi
    // memakai locale file, jadi nilainya pasti sama persis dgn yang dikirim
    // Flutter/Dashboard, apa pun setelan locale spreadsheet-nya.
    return normalizeFieldValue_(h, obj[h]);
  });
  sh.appendRow(row);

  // PENTING - akar masalah jam yang meleset beberapa jam di app/dashboard:
  // nowStr_() menulis jam sebagai teks yang SUDAH benar (timezone project
  // script). Tapi begitu teks itu masuk ke appendRow(), Google Sheets
  // otomatis mendeteksinya sebagai tanggal/jam dan mengonversinya jadi tipe
  // Date - memakai timezone FILE SPREADSHEET (Setelan File > Zona waktu),
  // yang merupakan setting TERPISAH dari timezone project Apps Script. Kalau
  // dua setting itu beda, nanti saat dibaca ulang & diformat pakai timezone
  // project (di sheetToObjects_), jamnya jadi tergeser (di kasus kita: WIB,
  // 7 jam). Solusinya: kunci kolom jam sebagai format Teks SEBELUM menulis,
  // supaya Sheets tidak pernah mengonversinya jadi Date sama sekali - jam
  // yang tersimpan & yang dibaca ulang selalu sama persis, apa pun setting
  // zona waktu file spreadsheet atau project script-nya.
  const newRow = sh.getLastRow();
  headers.forEach(function (h, idx) {
    if (isTimeLikeField_(h) || isTextLockField_(h)) {
      // Sama seperti field jam: kunci ID/kode/PIN sebagai format Teks supaya
      // Sheets tidak pernah mengonversinya jadi Number (hilang nol di depan,
      // atau salah baca sbg notasi ilmiah).
      const cell = sh.getRange(newRow, idx + 1);
      cell.setNumberFormat('@');
      cell.setValue(obj.hasOwnProperty(h) ? String(obj[h]) : '');
    } else if (isCoordField_(h) && obj.hasOwnProperty(h)) {
      // Kunci format tampilan angka desimal supaya konsisten di spreadsheet
      // (mis. selalu "-6.915079"), terlepas dari locale file.
      const cell = sh.getRange(newRow, idx + 1);
      cell.setNumberFormat('0.000000;-0.000000');
    }
  });

  return obj;
}

/** Update baris tertentu (berdasarkan nomor baris fisik) dengan field-field baru */
function updateRowByIndex_(sheetName, rowIndex, updates) {
  const sh = sheet_(sheetName);
  const lastCol = sh.getLastColumn();
  const headers = sh.getRange(HEADER_ROW, 1, 1, lastCol).getValues()[0];
  headers.forEach(function (h, idx) {
    if (h && updates.hasOwnProperty(h)) {
      const cell = sh.getRange(rowIndex, idx + 1);
      if (isTimeLikeField_(h) || isTextLockField_(h)) {
        // Sama seperti di appendObject_ - kunci kolom jam/ID/kode/PIN sebagai
        // teks supaya tidak dikonversi Sheets jadi Date/Number sendiri.
        cell.setNumberFormat('@');
        cell.setValue(String(updates[h]));
      } else if (isCoordField_(h)) {
        // Paksa jadi Number murni sebelum ditulis - akar perbaikan bug GPS,
        // dipakai saat Edit Site / Edit Checkpoint dari Dashboard.
        cell.setNumberFormat('0.000000;-0.000000');
        cell.setValue(normalizeFieldValue_(h, updates[h]));
      } else {
        cell.setValue(updates[h]);
      }
    }
  });
}

/** Hapus 1 baris fisik dari sheet (dipakai untuk fitur Hapus di dashboard CRUD) */
function deleteRowByIndex_(sheetName, rowIndex) {
  const sh = sheet_(sheetName);
  sh.deleteRow(rowIndex);
}

/** Cari 1 baris berdasarkan kolom id, kembalikan object + nomor baris fisik */
function findByField_(sheetName, field, value) {
  const rows = sheetToObjects_(sheetName);
  for (let i = 0; i < rows.length; i++) {
    if (String(rows[i][field]) === String(value)) return rows[i];
  }
  return null;
}

/** Generate ID unik dengan prefix, contoh: genId_('LOG') -> LOG-1723000000000 */
function genId_(prefix) {
  return prefix + '-' + new Date().getTime();
}

/** Timestamp string konsisten dengan format di data mockup */
function nowStr_() {
  return Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'GMT+7', 'yyyy-MM-dd HH:mm:ss');
}

/** Hitung jarak antar 2 koordinat (meter) - formula Haversine */
function distanceMeters_(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = function (v) { return (v * Math.PI) / 180; };
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/** Simpan foto base64 ke Google Drive, kembalikan URL yang bisa diakses */
function savePhotoBase64_(base64Data, fileNamePrefix) {
  if (!base64Data) return '';
  try {
    const props = PropertiesService.getScriptProperties();
    let folderId = props.getProperty(PHOTO_FOLDER_ID_PROP);
    let folder;
    if (folderId) {
      try {
        folder = DriveApp.getFolderById(folderId);
      } catch (e) {
        folder = null;
      }
    }
    if (!folder) {
      const it = DriveApp.getFoldersByName(PHOTO_FOLDER_NAME);
      folder = it.hasNext() ? it.next() : DriveApp.createFolder(PHOTO_FOLDER_NAME);
      props.setProperty(PHOTO_FOLDER_ID_PROP, folder.getId());
    }

    // Terima format "data:image/jpeg;base64,...." maupun base64 murni
    let contentType = 'image/jpeg';
    let pureBase64 = base64Data;
    const match = base64Data.match(/^data:(image\/[a-zA-Z]+);base64,(.*)$/);
    if (match) {
      contentType = match[1];
      pureBase64 = match[2];
    }
    const bytes = Utilities.base64Decode(pureBase64);
    const blob = Utilities.newBlob(bytes, contentType, fileNamePrefix + '_' + new Date().getTime() + '.jpg');
    const file = folder.createFile(blob);
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    return 'https://drive.google.com/uc?id=' + file.getId();
  } catch (err) {
    return '';
  }
}

/** Bungkus response sukses */
function ok_(data) {
  return jsonOut_({ success: true, data: data });
}

/** Bungkus response error */
function err_(message) {
  return jsonOut_({ success: false, message: String(message) });
}

function jsonOut_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}