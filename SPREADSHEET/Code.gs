/**
 * API ENDPOINT - APLIKASI MOBILE SECURITY & PATROLI REAL-TIME
 * =============================================================
 * Cara deploy:
 * 1. Buka spreadsheet "Database_Patroli_Security_Mockup"
 * 2. Extensions > Apps Script, lalu tempel semua file .gs ini
 * 3. Deploy > New deployment > Web app
 *      - Execute as: Me
 *      - Who has access: Anyone
 * 4. Salin Web App URL ke:
 *      - flutter_app/lib/config/api_config.dart  (BASE_URL)
 *      - web_dashboard/js/app.js                 (API_URL)
 *
 * Semua request GET & POST memakai parameter `action` untuk menentukan
 * operasi apa yang dijalankan. Body POST berupa JSON.
 */

function doGet(e) {
  try {
    const action = (e.parameter && e.parameter.action) || '';

    // Tidak ada parameter action -> tampilkan Dashboard Admin (Dashboard.html)
    // File Dashboard.html HARUS ditambahkan sebagai file HTML terpisah di
    // project Apps Script yang sama (Apps Script otomatis membuang ekstensi
    // .html dari nama file di editor, cukup beri nama "Dashboard").
    if (!action) {
      return HtmlService.createHtmlOutputFromFile('Dashboard')
        .setTitle('Dashboard Patroli Security')
        .addMetaTag('viewport', 'width=device-width, initial-scale=1')
        .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
    }

    switch (action) {
      case 'ping':
        return ok_({ message: 'API aktif', time: nowStr_() });

      case 'getUsers':
        return ok_(sheetToObjects_(SHEETS.USERS));

      case 'getSites':
        return ok_(sheetToObjects_(SHEETS.SITES));

      case 'getCheckpoints':
        return ok_(filterByParam_(sheetToObjects_(SHEETS.CHECKPOINTS), 'site_id', e.parameter.site_id));

      case 'getPatrolLogs':
        return ok_(filterLogsToday_(sheetToObjects_(SHEETS.PATROL_LOGS), e.parameter));

      case 'getIncidents':
        return ok_(sortDesc_(sheetToObjects_(SHEETS.INCIDENTS), 'timestamp'));

      case 'getGuests':
        return ok_(sortDesc_(sheetToObjects_(SHEETS.GUESTS), 'checkin_time'));

      case 'getDashboardSummary':
        return ok_(getDashboardSummary_());

      case 'getPatrolStatus':
        return ok_(getPatrolStatusPerSite_());

      case 'getPatrolStatusPerUser':
        return ok_(getPatrolStatusPerUser_());

      default:
        return err_('Action tidak dikenali: ' + action);
    }
  } catch (error) {
    return err_(error.message);
  }
}

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents || '{}');
    const action = body.action || (e.parameter && e.parameter.action) || '';

    switch (action) {
      case 'login':
        return login_(body);

      case 'patrolScan':
        return recordPatrolScan_(body);

      case 'reportIncident':
        return reportIncident_(body);

      case 'guestCheckIn':
        return guestCheckIn_(body);

      case 'guestCheckOut':
        return guestCheckOut_(body);

      case 'addSite':
        return addSite_(body);

      case 'addCheckpoint':
        return addCheckpoint_(body);

      case 'addUser':
        return addUser_(body);

      default:
        return err_('Action tidak dikenali: ' + action);
    }
  } catch (error) {
    return err_(error.message);
  }
}

/* =========================================================
 *  AUTH
 * ========================================================= */
function login_(body) {
  const username = body.username;
  const pin = body.pin_pass;
  if (!username || !pin) return err_('username dan pin_pass wajib diisi');

  const user = findByField_(SHEETS.USERS, 'username', username);
  if (!user) return err_('Username tidak ditemukan');
  if (String(user.pin_pass) !== String(pin)) return err_('PIN salah');
  if (user.status !== 'Active') return err_('Akun tidak aktif, hubungi admin');

  delete user.pin_pass;
  delete user.__row;
  return ok_(user);
}

/* =========================================================
 *  PATROLI (QR + GPS)
 * ========================================================= */
function recordPatrolScan_(body) {
  const required = ['user_id', 'checkpoint_id', 'scan_lat', 'scan_long'];
  for (const f of required) if (body[f] === undefined) return err_('Field wajib: ' + f);

  const checkpoint = findByField_(SHEETS.CHECKPOINTS, 'checkpoint_id', body.checkpoint_id);
  if (!checkpoint) return err_('Checkpoint / QR Code tidak valid');

  // VALIDASI GPS: pastikan petugas benar-benar berada dekat titik checkpoint
  // saat scan, bukan cuma memindai gambar QR dari jarak jauh / hasil kirim
  // ulang foto QR. Tanpa ini, siapa saja yang punya salinan kode QR bisa
  // "checkpoint palsu" dari mana saja.
  const cpLat = parseFloat(checkpoint.target_lat);
  const cpLong = parseFloat(checkpoint.target_long);
  const scanLat = parseFloat(body.scan_lat);
  const scanLong = parseFloat(body.scan_long);

  if (isNaN(cpLat) || isNaN(cpLong)) {
    return err_('Koordinat checkpoint ini belum diatur dengan benar. Hubungi Admin.');
  }
  if (isNaN(scanLat) || isNaN(scanLong)) {
    return err_('Lokasi GPS petugas tidak valid, coba ulangi dengan GPS aktif.');
  }

  const distance = distanceMeters_(scanLat, scanLong, cpLat, cpLong);
  const radius = body.radius ? parseFloat(body.radius) : PATROL_GEOFENCE_RADIUS_M;

  if (distance > radius) {
    return err_(
      'Anda berada ' + Math.round(distance) + 'm dari checkpoint "' + checkpoint.checkpoint_name +
      '" (maksimal ' + radius + 'm). Dekati lokasi checkpoint sebelum scan.'
    );
  }

  const photoUrl = savePhotoBase64_(body.photo_base64, 'patrol_' + body.checkpoint_id);

  const record = {
    log_id: genId_('LOG'),
    timestamp: nowStr_(),
    user_id: body.user_id,
    checkpoint_id: body.checkpoint_id,
    scan_lat: body.scan_lat,
    scan_long: body.scan_long,
    photo_url: photoUrl,
    notes: body.notes || ''
  };
  appendObject_(SHEETS.PATROL_LOGS, record);
  return ok_(record);
}

/* =========================================================
 *  INSIDEN / DARURAT
 * ========================================================= */
function reportIncident_(body) {
  const required = ['user_id', 'title', 'description', 'lat', 'long'];
  for (const f of required) if (body[f] === undefined) return err_('Field wajib: ' + f);

  const photoUrl = savePhotoBase64_(body.photo_base64, 'incident_' + body.user_id);

  const record = {
    incident_id: genId_('INC'),
    timestamp: nowStr_(),
    user_id: body.user_id,
    title: body.title,
    description: body.description,
    lat: body.lat,
    long: body.long,
    photo_url: photoUrl
  };
  appendObject_(SHEETS.INCIDENTS, record);

  // Notifikasi darurat untuk kategori kritikal (opsional: bisa dihubungkan ke
  // layanan push notification eksternal / FCM lewat UrlFetchApp)
  const criticalTypes = ['Kebakaran', 'Pencurian'];
  if (criticalTypes.indexOf(body.title) !== -1) {
    // TODO: panggil FCM / integrasi notifikasi Danru-Supervisor di sini
  }

  return ok_(record);
}

/* =========================================================
 *  BUKU TAMU DIGITAL
 * ========================================================= */
function guestCheckIn_(body) {
  const required = ['guest_name', 'identity_no', 'destination', 'purpose'];
  for (const f of required) if (!body[f]) return err_('Field wajib: ' + f);

  const guestId = genId_('GST');
  const record = {
    guest_id: guestId,
    checkin_time: nowStr_(),
    checkout_time: '',
    guest_name: body.guest_name,
    identity_no: body.identity_no,
    destination: body.destination,
    purpose: body.purpose,
    qr_guest_code: 'GUEST-QR-' + guestId
  };
  appendObject_(SHEETS.GUESTS, record);
  return ok_(record);
}

function guestCheckOut_(body) {
  if (!body.guest_id && !body.qr_guest_code) return err_('guest_id atau qr_guest_code wajib diisi');

  const field = body.guest_id ? 'guest_id' : 'qr_guest_code';
  const value = body.guest_id || body.qr_guest_code;
  const guest = findByField_(SHEETS.GUESTS, field, value);
  if (!guest) return err_('Data tamu tidak ditemukan');
  if (guest.checkout_time) return err_('Tamu ini sudah check-out sebelumnya');

  updateRowByIndex_(SHEETS.GUESTS, guest.__row, { checkout_time: nowStr_() });
  guest.checkout_time = nowStr_();
  delete guest.__row;
  return ok_(guest);
}

/* =========================================================
 *  ADMIN - MASTER DATA
 * ========================================================= */
function addSite_(body) {
  const required = ['site_name', 'address', 'latitude', 'longitude'];
  for (const f of required) if (body[f] === undefined) return err_('Field wajib: ' + f);
  const record = {
    site_id: body.site_id || genId_('SITE'),
    site_name: body.site_name,
    address: body.address,
    latitude: body.latitude,
    longitude: body.longitude
  };
  appendObject_(SHEETS.SITES, record);
  return ok_(record);
}

function addCheckpoint_(body) {
  const required = ['site_id', 'checkpoint_name', 'target_lat', 'target_long'];
  for (const f of required) if (body[f] === undefined) return err_('Field wajib: ' + f);
  const id = body.checkpoint_id || genId_('CP');
  const record = {
    checkpoint_id: id,
    site_id: body.site_id,
    checkpoint_name: body.checkpoint_name,
    qr_code_val: body.qr_code_val || ('QR-' + id),
    target_lat: body.target_lat,
    target_long: body.target_long
  };
  appendObject_(SHEETS.CHECKPOINTS, record);
  return ok_(record);
}

function addUser_(body) {
  const required = ['username', 'full_name', 'role', 'pin_pass', 'assigned_site_id'];
  for (const f of required) if (body[f] === undefined) return err_('Field wajib: ' + f);
  if (findByField_(SHEETS.USERS, 'username', body.username)) {
    return err_('Username sudah digunakan, pilih username lain');
  }
  const record = {
    user_id: body.user_id || genId_('USR'),
    username: body.username,
    full_name: body.full_name,
    role: body.role,
    pin_pass: body.pin_pass,
    assigned_site_id: body.assigned_site_id,
    status: body.status || 'Active'
  };
  appendObject_(SHEETS.USERS, record);
  return ok_(record);
}

/* =========================================================
 *  HELPER KHUSUS QUERY / DASHBOARD
 * ========================================================= */
function filterByParam_(list, field, value) {
  if (!value) return list;
  return list.filter(function (item) { return String(item[field]) === String(value); });
}

function filterLogsToday_(list, params) {
  let result = list;
  if (params && params.user_id) {
    result = result.filter(function (item) { return String(item.user_id) === String(params.user_id); });
  }
  if (params && params.date) {
    result = result.filter(function (item) {
      return String(item.timestamp).indexOf(params.date) === 0;
    });
  }
  return sortDesc_(result, 'timestamp');
}

function sortDesc_(list, field) {
  return list.slice().sort(function (a, b) {
    return String(b[field]).localeCompare(String(a[field]));
  });
}

function getDashboardSummary_() {
  const users = sheetToObjects_(SHEETS.USERS);
  const sites = sheetToObjects_(SHEETS.SITES);
  const patrolLogs = sheetToObjects_(SHEETS.PATROL_LOGS);
  const incidents = sheetToObjects_(SHEETS.INCIDENTS);
  const guests = sheetToObjects_(SHEETS.GUESTS);
  const today = Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'GMT+7', 'yyyy-MM-dd');

  const patrolToday = patrolLogs.filter(function (l) { return String(l.timestamp).indexOf(today) === 0; });
  const incidentsToday = incidents.filter(function (l) { return String(l.timestamp).indexOf(today) === 0; });
  const guestsActive = guests.filter(function (g) { return !g.checkout_time; });

  return {
    total_users: users.filter(function (u) { return u.status === 'Active'; }).length,
    total_sites: sites.length,
    patrol_scans_today: patrolToday.length,
    incidents_today: incidentsToday.length,
    guests_active: guestsActive.length,
    latest_patrol: sortDesc_(patrolLogs, 'timestamp').slice(0, 10),
    latest_incidents: sortDesc_(incidents, 'timestamp').slice(0, 5)
  };
}

/* =========================================================
 *  WRAPPER UNTUK DASHBOARD.HTML (dipanggil via google.script.run)
 *  ---------------------------------------------------------
 *  Beda dengan doGet/doPost (untuk aplikasi Flutter yang perlu
 *  balikan JSON via ContentService), fungsi di bawah ini balikan-
 *  nya harus berupa object/array JS biasa - itu sebabnya tidak
 *  memakai ok_()/err_(). Properti __row dihapus supaya bersih
 *  saat di-serialize ke client.
 * ========================================================= */
function stripRow_(list) {
  return list.map(function (item) {
    const copy = Object.assign({}, item);
    delete copy.__row;
    return copy;
  });
}

function dash_getSummary() {
  return getDashboardSummary_();
}

function dash_getPatrolStatus() {
  return getPatrolStatusPerSite_();
}

function dash_getPatrolStatusPerUser() {
  return getPatrolStatusPerUser_();
}

function dash_getSites() {
  return stripRow_(sheetToObjects_(SHEETS.SITES));
}

function dash_getCheckpoints() {
  return stripRow_(sheetToObjects_(SHEETS.CHECKPOINTS));
}

function dash_getPatrolLogs() {
  return stripRow_(sortDesc_(sheetToObjects_(SHEETS.PATROL_LOGS), 'timestamp'));
}

function dash_getIncidents() {
  return stripRow_(sortDesc_(sheetToObjects_(SHEETS.INCIDENTS), 'timestamp'));
}

function dash_getGuests() {
  return stripRow_(sortDesc_(sheetToObjects_(SHEETS.GUESTS), 'checkin_time'));
}

/**
 * Login khusus dashboard admin. Hanya role Super Admin, Danru, dan Supervisor
 * yang boleh masuk ke dashboard (Satpam ditolak - mereka pakai aplikasi mobile).
 * Melempar Error (bukan return {success:false,...}) karena ini dipanggil lewat
 * google.script.run - error yang di-throw otomatis masuk ke withFailureHandler
 * di sisi client.
 */
function dash_login(username, pin) {
  const user = findByField_(SHEETS.USERS, 'username', username);
  if (!user) throw new Error('Username tidak ditemukan');
  if (String(user.pin_pass) !== String(pin)) throw new Error('PIN salah');
  if (user.status !== 'Active') throw new Error('Akun tidak aktif, hubungi Super Admin');

  const allowedRoles = [ROLES.ADMIN, ROLES.DANRU, ROLES.SUPERVISOR];
  if (allowedRoles.indexOf(user.role) === -1) {
    throw new Error('Akun dengan role Satpam tidak memiliki akses ke dashboard ini');
  }

  delete user.pin_pass;
  delete user.__row;
  return user;
}

function dash_getUsers() {
  return stripRow_(sheetToObjects_(SHEETS.USERS)).map(function (u) {
    delete u.pin_pass; // jangan kirim PIN ke browser
    return u;
  });
}

function dash_addUser(payload) {
  const required = ['username', 'full_name', 'role', 'pin_pass', 'assigned_site_id'];
  required.forEach(function (f) {
    if (!payload[f]) throw new Error('Field wajib: ' + f);
  });
  if (findByField_(SHEETS.USERS, 'username', payload.username)) {
    throw new Error('Username sudah digunakan, pilih username lain');
  }
  const record = {
    user_id: genId_('USR'),
    username: payload.username,
    full_name: payload.full_name,
    role: payload.role,
    pin_pass: payload.pin_pass,
    assigned_site_id: payload.assigned_site_id,
    status: payload.status || 'Active'
  };
  appendObject_(SHEETS.USERS, record);
  delete record.pin_pass;
  return record;
}

function dash_addSite(payload) {
  const required = ['site_name', 'address', 'latitude', 'longitude'];
  required.forEach(function (f) {
    if (!payload[f]) throw new Error('Field wajib: ' + f);
  });
  const record = {
    site_id: genId_('SITE'),
    site_name: payload.site_name,
    address: payload.address,
    latitude: payload.latitude,
    longitude: payload.longitude
  };
  appendObject_(SHEETS.SITES, record);
  return record;
}

function dash_addCheckpoint(payload) {
  const required = ['site_id', 'checkpoint_name', 'target_lat', 'target_long'];
  required.forEach(function (f) {
    if (!payload[f]) throw new Error('Field wajib: ' + f);
  });
  const id = genId_('CP');
  const record = {
    checkpoint_id: id,
    site_id: payload.site_id,
    checkpoint_name: payload.checkpoint_name,
    qr_code_val: 'QR-' + id,
    target_lat: payload.target_lat,
    target_long: payload.target_long
  };
  appendObject_(SHEETS.CHECKPOINTS, record);
  return record;
}

/* =========================================================
 *  ADMIN - MASTER DATA (UPDATE & DELETE, dipanggil dari Dashboard)
 * ========================================================= */
function dash_updateSite(payload) {
  if (!payload || !payload.site_id) throw new Error('site_id wajib diisi');
  const site = findByField_(SHEETS.SITES, 'site_id', payload.site_id);
  if (!site) throw new Error('Site tidak ditemukan');
  const updates = {};
  ['site_name', 'address', 'latitude', 'longitude'].forEach(function (f) {
    if (payload[f] !== undefined) updates[f] = payload[f];
  });
  updateRowByIndex_(SHEETS.SITES, site.__row, updates);
  return Object.assign({}, site, updates, { __row: undefined });
}

function dash_deleteSite(siteId) {
  const site = findByField_(SHEETS.SITES, 'site_id', siteId);
  if (!site) throw new Error('Site tidak ditemukan');
  const usedByCheckpoint = findByField_(SHEETS.CHECKPOINTS, 'site_id', siteId);
  if (usedByCheckpoint) throw new Error('Site masih memiliki checkpoint terdaftar, hapus checkpoint-nya terlebih dahulu');
  const usedByUser = findByField_(SHEETS.USERS, 'assigned_site_id', siteId);
  if (usedByUser) throw new Error('Site masih memiliki petugas terdaftar, pindahkan petugas terlebih dahulu');
  deleteRowByIndex_(SHEETS.SITES, site.__row);
  return { site_id: siteId };
}

function dash_updateCheckpoint(payload) {
  if (!payload || !payload.checkpoint_id) throw new Error('checkpoint_id wajib diisi');
  const cp = findByField_(SHEETS.CHECKPOINTS, 'checkpoint_id', payload.checkpoint_id);
  if (!cp) throw new Error('Checkpoint tidak ditemukan');
  const updates = {};
  ['site_id', 'checkpoint_name', 'target_lat', 'target_long'].forEach(function (f) {
    if (payload[f] !== undefined) updates[f] = payload[f];
  });
  updateRowByIndex_(SHEETS.CHECKPOINTS, cp.__row, updates);
  return Object.assign({}, cp, updates, { __row: undefined });
}

function dash_deleteCheckpoint(checkpointId) {
  const cp = findByField_(SHEETS.CHECKPOINTS, 'checkpoint_id', checkpointId);
  if (!cp) throw new Error('Checkpoint tidak ditemukan');
  deleteRowByIndex_(SHEETS.CHECKPOINTS, cp.__row);
  return { checkpoint_id: checkpointId };
}

function dash_updateUser(payload) {
  if (!payload || !payload.user_id) throw new Error('user_id wajib diisi');
  const user = findByField_(SHEETS.USERS, 'user_id', payload.user_id);
  if (!user) throw new Error('User tidak ditemukan');
  if (payload.username && payload.username !== user.username) {
    const existing = findByField_(SHEETS.USERS, 'username', payload.username);
    if (existing && existing.user_id !== user.user_id) {
      throw new Error('Username sudah digunakan, pilih username lain');
    }
  }
  const updates = {};
  ['username', 'full_name', 'role', 'assigned_site_id', 'status'].forEach(function (f) {
    if (payload[f] !== undefined) updates[f] = payload[f];
  });
  // PIN hanya diupdate kalau memang diisi ulang (kosongkan field di form = tidak diganti)
  if (payload.pin_pass) updates.pin_pass = payload.pin_pass;
  updateRowByIndex_(SHEETS.USERS, user.__row, updates);
  const result = Object.assign({}, user, updates);
  delete result.__row;
  delete result.pin_pass;
  return result;
}

function dash_deleteUser(userId) {
  const user = findByField_(SHEETS.USERS, 'user_id', userId);
  if (!user) throw new Error('User tidak ditemukan');
  deleteRowByIndex_(SHEETS.USERS, user.__row);
  return { user_id: userId };
}

function getPatrolStatusPerSite_() {
  const sites = sheetToObjects_(SHEETS.SITES);
  const checkpoints = sheetToObjects_(SHEETS.CHECKPOINTS);
  const patrolLogs = sheetToObjects_(SHEETS.PATROL_LOGS);
  const today = Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'GMT+7', 'yyyy-MM-dd');
  const scannedTodayIds = patrolLogs
    .filter(function (l) { return String(l.timestamp).indexOf(today) === 0; })
    .map(function (l) { return l.checkpoint_id; });

  return sites.map(function (site) {
    const cps = checkpoints.filter(function (c) { return c.site_id === site.site_id; });
    const done = cps.filter(function (c) { return scannedTodayIds.indexOf(c.checkpoint_id) !== -1; }).length;
    return {
      site_id: site.site_id,
      site_name: site.site_name,
      total_checkpoints: cps.length,
      completed: done,
      missed: cps.length - done
    };
  });
}

/**
 * Status patroli per petugas (Satpam) hari ini: dari total checkpoint di
 * site tempat dia bertugas, berapa yang sudah di-scan hari ini, dan jam
 * scan terakhirnya. Dipakai oleh panel "Status Patroli per Petugas" di
 * Dashboard admin.
 */
function getPatrolStatusPerUser_() {
  const users = sheetToObjects_(SHEETS.USERS);
  const sites = sheetToObjects_(SHEETS.SITES);
  const checkpoints = sheetToObjects_(SHEETS.CHECKPOINTS);
  const patrolLogs = sheetToObjects_(SHEETS.PATROL_LOGS);
  const today = Utilities.formatDate(new Date(), Session.getScriptTimeZone() || 'GMT+7', 'yyyy-MM-dd');

  const logsToday = patrolLogs.filter(function (l) {
    return String(l.timestamp).indexOf(today) === 0;
  });

  const siteNameById = {};
  sites.forEach(function (s) { siteNameById[s.site_id] = s.site_name; });

  const allowedRoles = [ROLES.SATPAM, ROLES.DANRU]; // <-- atur di sini

  return users
    .filter(function (u) { return allowedRoles.indexOf(u.role) !== -1 && u.status === 'Active'; })
    .map(function (u) {
      const cps = checkpoints.filter(function (c) { return c.site_id === u.assigned_site_id; });
      const myLogsToday = logsToday.filter(function (l) { return l.user_id === u.user_id; });

      const scannedIds = [];
      myLogsToday.forEach(function (l) {
        if (scannedIds.indexOf(l.checkpoint_id) === -1) scannedIds.push(l.checkpoint_id);
      });

      const completed = cps.filter(function (c) {
        return scannedIds.indexOf(c.checkpoint_id) !== -1;
      }).length;

      let lastPatrolTime = '';
      myLogsToday.forEach(function (l) {
        if (String(l.timestamp) > lastPatrolTime) lastPatrolTime = String(l.timestamp);
      });

      let status;
      if (cps.length === 0) {
        status = 'Tanpa Checkpoint';
      } else if (completed === 0) {
        status = 'Belum Mulai';
      } else if (completed < cps.length) {
        status = 'Berjalan';
      } else {
        status = 'Selesai';
      }

      return {
        user_id: u.user_id,
        full_name: u.full_name,
        role: u.role,
        site_id: u.assigned_site_id,
        site_name: siteNameById[u.assigned_site_id] || '-',
        total_checkpoints: cps.length,
        completed: completed,
        missed: cps.length - completed,
        last_patrol_time: lastPatrolTime,
        status: status
      };
    });
}