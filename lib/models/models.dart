library models;

// Data Models terstandarisasi untuk Patroli Security Mobile App

class AppUser {
  final int id;
  final String name;
  final String username;
  final String email;
  final String badgeNumber;
  final String? phone;
  final String role;
  final String? avatarUrl;
  final bool isActive;
  final String? token;
  final int? assignedSiteId;

  AppUser({
    required this.id,
    required this.name,
    this.username = '',
    required this.email,
    required this.badgeNumber,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.isActive = true,
    this.token,
    this.assignedSiteId,
  });

  factory AppUser.fromJson(dynamic rawJson, [String? authToken]) {
    Map<dynamic, dynamic> json = {};
    if (rawJson is Map) {
      json = rawJson;
      // Handle nested response structures (e.g. { data: { user: {...}, token: ... } } or { user: {...} })
      if (json['user'] is Map) {
        json = json['user'] as Map;
      } else if (json['data'] is Map) {
        final dataMap = json['data'] as Map;
        if (dataMap['user'] is Map) {
          json = dataMap['user'] as Map;
        } else if (dataMap['id'] != null || dataMap['name'] != null || dataMap['role'] != null) {
          json = dataMap;
        }
      }
    }

    final rawId = json['id'] ?? json['user_id'] ?? 0;
    final int parsedId = int.tryParse(rawId.toString()) ?? 0;
    final parsedUsername = json['username']?.toString() ?? '';
    final parsedBadge = json['badge_number']?.toString() ??
        json['badge']?.toString() ??
        json['nip']?.toString();
    final parsedName = json['name']?.toString() ??
        json['full_name']?.toString() ??
        json['nama']?.toString() ??
        '';
    final parsedRole = (json['role']?.toString() ??
            json['role_name']?.toString() ??
            'satpam')
        .toLowerCase();
    final parsedEmail = json['email']?.toString() ?? '';
    final parsedPhone = json['phone']?.toString() ??
        json['no_hp']?.toString() ??
        json['telepon']?.toString();
    final parsedAvatar = json['avatar_url']?.toString() ??
        json['avatar']?.toString() ??
        json['foto']?.toString();
    final parsedToken = authToken ??
        json['token']?.toString() ??
        (rawJson is Map ? rawJson['token']?.toString() : null);

    return AppUser(
      id: parsedId,
      name: parsedName,
      username: parsedUsername,
      email: parsedEmail,
      badgeNumber: (parsedBadge != null && parsedBadge.isNotEmpty)
          ? parsedBadge
          : (parsedUsername.isNotEmpty
              ? parsedUsername
              : (parsedId > 0 ? 'SEC-${parsedId.toString().padLeft(3, '0')}' : 'SEC-001')),
      phone: parsedPhone,
      role: parsedRole,
      avatarUrl: parsedAvatar,
      isActive: json['is_active'] == true ||
          json['is_active'] == 1 ||
          json['status'] == 'active',
      token: parsedToken,
      assignedSiteId: int.tryParse(
          json['assigned_site_id']?.toString() ?? json['site_id']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'username': username,
        'email': email,
        'badge_number': badgeNumber,
        'phone': phone,
        'role': role,
        'avatar_url': avatarUrl,
        'is_active': isActive,
        'token': token,
        'assigned_site_id': assignedSiteId,
      };

  // Compatibility Helpers
  String get userId => id.toString();
  String get displayUsername =>
      username.isNotEmpty ? username : (badgeNumber.isNotEmpty ? badgeNumber : email);
  String get fullName => name.isNotEmpty ? name : (username.isNotEmpty ? username : 'Petugas');
  String get assignedSiteIdStr => assignedSiteId != null ? assignedSiteId.toString() : '1';

  bool get isSatpam =>
      role.toLowerCase() == 'satpam' ||
      role.toLowerCase() == 'guard' ||
      role.toLowerCase() == 'anggota';
  bool get isDanru =>
      role.toLowerCase() == 'danru' ||
      role.toLowerCase() == 'commander' ||
      role.toLowerCase() == 'leader';
  bool get isSupervisor => role.toLowerCase() == 'supervisor';
  bool get isAdmin =>
      role.toLowerCase() == 'admin' ||
      role.toLowerCase() == 'superadmin' ||
      role.toLowerCase() == 'super admin';
  bool get canSupervise => isDanru || isSupervisor || isAdmin;
}

class CheckpointModel {
  final int id;
  final int? siteId;
  final String name;
  final String code;
  final String qrToken;
  final String? qrImageUrl;
  final String? locationDescription;
  final double latitude;
  final double longitude;
  final double maxRadiusMeters;
  final int orderIndex;
  final bool isActive;

  // Sesi Aktif Metadata
  final bool isScanned;
  final String? scannedAt;
  final double? distanceMeters;
  final String conditionStatus;
  final String? selfieUrl;

  CheckpointModel({
    required this.id,
    this.siteId,
    required this.name,
    required this.code,
    required this.qrToken,
    this.qrImageUrl,
    this.locationDescription,
    required this.latitude,
    required this.longitude,
    this.maxRadiusMeters = 10.0,
    this.orderIndex = 1,
    this.isActive = true,
    this.isScanned = false,
    this.scannedAt,
    this.distanceMeters,
    this.conditionStatus = 'normal',
    this.selfieUrl,
  });

  factory CheckpointModel.fromJson(Map<String, dynamic> json) {
    return CheckpointModel(
      id: int.tryParse(json['id']?.toString() ?? json['checkpoint_id']?.toString() ?? '0') ?? 0,
      siteId: int.tryParse(json['site_id']?.toString() ?? ''),
      name: json['name']?.toString() ?? json['checkpoint_name']?.toString() ?? 'Checkpoint',
      code: json['code']?.toString() ?? '',
      qrToken: json['qr_token']?.toString() ?? json['qr_code_val']?.toString() ?? '',
      qrImageUrl: json['qr_image_url']?.toString(),
      locationDescription: json['location_description']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? json['target_lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? json['target_long']?.toString() ?? '0') ?? 0.0,
      maxRadiusMeters: double.tryParse(json['max_radius_meters']?.toString() ?? '10.0') ?? 10.0,
      orderIndex: int.tryParse(json['order_index']?.toString() ?? '1') ?? 1,
      isActive: json['is_active'] != false && json['is_active'] != 0,
      isScanned: json['is_scanned'] == true || json['is_scanned'] == 1,
      scannedAt: json['scanned_at']?.toString(),
      distanceMeters: double.tryParse(json['distance_meters']?.toString() ?? ''),
      conditionStatus: json['condition_status']?.toString() ?? 'normal',
      selfieUrl: json['selfie_url']?.toString() ?? json['selfie_photo_url']?.toString(),
    );
  }

  // Compatibility helpers
  String get checkpointId => id.toString();
  String get checkpointName => name;
  String get qrCodeVal => qrToken;
  double get targetLat => latitude;
  double get targetLong => longitude;
}

class SiteModel {
  final int id;
  final String name;
  final String code;
  final String? address;
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;
  final bool isActive;
  final int checkpointsCount;
  final List<CheckpointModel> checkpoints;

  SiteModel({
    required this.id,
    required this.name,
    required this.code,
    this.address,
    required this.latitude,
    required this.longitude,
    this.geofenceRadiusMeters = 50.0,
    this.isActive = true,
    this.checkpointsCount = 0,
    this.checkpoints = const [],
  });

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    List<CheckpointModel> cpList = [];
    if (json['checkpoints'] is List) {
      cpList = (json['checkpoints'] as List)
          .map((e) => CheckpointModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final parsedCount = int.tryParse(json['checkpoints_count']?.toString() ?? '') ?? cpList.length;

    return SiteModel(
      id: int.tryParse(json['id']?.toString() ?? json['site_id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? json['site_name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      address: json['address']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      geofenceRadiusMeters: double.tryParse(json['geofence_radius_meters']?.toString() ?? '50.0') ?? 50.0,
      isActive: json['is_active'] != false && json['is_active'] != 0,
      checkpointsCount: parsedCount,
      checkpoints: cpList,
    );
  }

  String get siteId => id.toString();
  String get siteName => name;
}

class PatrolSchedule {
  final int id;
  final int siteId;
  final String shiftName;
  final String startTime;
  final String endTime;
  final int minPatrolRounds;
  final SiteModel? site;

  PatrolSchedule({
    required this.id,
    required this.siteId,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.minPatrolRounds,
    this.site,
  });

  factory PatrolSchedule.fromJson(Map<String, dynamic> json) {
    return PatrolSchedule(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      siteId: int.tryParse(json['site_id']?.toString() ?? '0') ?? 0,
      shiftName: json['shift_name']?.toString() ?? 'Shift Rutin',
      startTime: json['start_time']?.toString() ?? '07:00:00',
      endTime: json['end_time']?.toString() ?? '15:00:00',
      minPatrolRounds: int.tryParse(json['min_patrol_rounds']?.toString() ?? '1') ?? 1,
      site: json['site'] != null ? SiteModel.fromJson(Map<String, dynamic>.from(json['site'] as Map)) : null,
    );
  }
}

class PatrolSession {
  final int sessionId;
  final int? scheduleId;
  final int roundNumber;
  final String status;
  final String? startedAt;
  final String? completedAt;
  final String? siteName;
  final int totalCheckpoints;
  final int scannedCount;
  final int remainingCount;
  final List<CheckpointModel> checkpoints;

  PatrolSession({
    required this.sessionId,
    this.scheduleId,
    required this.roundNumber,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.siteName,
    required this.totalCheckpoints,
    required this.scannedCount,
    required this.remainingCount,
    this.checkpoints = const [],
  });

  factory PatrolSession.fromJson(Map<String, dynamic> json) {
    List<CheckpointModel> cpList = [];
    if (json['checkpoints'] is List) {
      cpList = (json['checkpoints'] as List)
          .map((e) => CheckpointModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    final total = int.tryParse(json['total_checkpoints']?.toString() ?? '0') ?? cpList.length;
    final scanned = int.tryParse(json['scanned_count']?.toString() ?? '0') ??
        cpList.where((c) => c.isScanned).length;

    return PatrolSession(
      sessionId: int.tryParse(json['session_id']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      scheduleId: int.tryParse(json['patrol_schedule_id']?.toString() ?? ''),
      roundNumber: int.tryParse(json['round_number']?.toString() ?? '1') ?? 1,
      status: json['status']?.toString() ?? 'in_progress',
      startedAt: json['started_at']?.toString(),
      completedAt: json['completed_at']?.toString(),
      siteName: json['site_name']?.toString(),
      totalCheckpoints: total,
      scannedCount: scanned,
      remainingCount: total - scanned,
      checkpoints: cpList,
    );
  }

  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';
}

class AttendanceStatus {
  final bool isCheckedIn;
  final bool isCheckedOut;
  final int? id;
  final int? siteId;
  final String? siteName;
  final String? checkInAt;
  final String? checkOutAt;
  final double? checkInLat;
  final double? checkInLng;
  final String? status;

  AttendanceStatus({
    required this.isCheckedIn,
    required this.isCheckedOut,
    this.id,
    this.siteId,
    this.siteName,
    this.checkInAt,
    this.checkOutAt,
    this.checkInLat,
    this.checkInLng,
    this.status,
  });

  factory AttendanceStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map<String, dynamic> : json;
    final att = data['attendance'] is Map ? data['attendance'] as Map<String, dynamic> : null;

    return AttendanceStatus(
      isCheckedIn: data['is_checked_in'] == true || att != null,
      isCheckedOut: data['is_checked_out'] == true || (att != null && att['check_out_at'] != null),
      id: att != null ? int.tryParse(att['id']?.toString() ?? '') : null,
      siteId: att != null ? int.tryParse(att['site_id']?.toString() ?? '') : null,
      siteName: att?['site_name']?.toString(),
      checkInAt: att?['check_in_at']?.toString(),
      checkOutAt: att?['check_out_at']?.toString(),
      checkInLat: double.tryParse(att?['check_in_lat']?.toString() ?? ''),
      checkInLng: double.tryParse(att?['check_in_lng']?.toString() ?? ''),
      status: att?['status']?.toString() ?? 'present',
    );
  }
}

class IncidentModel {
  final int id;
  final int? siteId;
  final int? checkpointId;
  final String? checkpointName;
  final int? userId;
  final String? reporterName;
  final String title;
  final String description;
  final String severity; // 'low', 'medium', 'high'
  final String? photoUrl;
  final String status; // 'open', 'in_progress', 'resolved'
  final String? createdAt;

  IncidentModel({
    required this.id,
    this.siteId,
    this.checkpointId,
    this.checkpointName,
    this.userId,
    this.reporterName,
    required this.title,
    required this.description,
    this.severity = 'medium',
    this.photoUrl,
    this.status = 'open',
    this.createdAt,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: int.tryParse(json['id']?.toString() ?? json['incident_id']?.toString() ?? '0') ?? 0,
      siteId: int.tryParse(json['site_id']?.toString() ?? ''),
      checkpointId: int.tryParse(json['checkpoint_id']?.toString() ?? ''),
      checkpointName: json['checkpoint_name']?.toString(),
      userId: int.tryParse(json['user_id']?.toString() ?? ''),
      reporterName: json['reporter_name']?.toString() ?? json['user_name']?.toString(),
      title: json['title']?.toString() ?? 'Laporan Insiden',
      description: json['description']?.toString() ?? '',
      severity: (json['severity']?.toString() ?? 'medium').toLowerCase(),
      photoUrl: json['photo_url']?.toString() ?? json['photo']?.toString(),
      status: json['status']?.toString() ?? 'open',
      createdAt: json['created_at']?.toString() ?? json['timestamp']?.toString(),
    );
  }

  // Compatibility helpers
  String get incidentId => id.toString();
  String get timestamp => createdAt ?? '';
  bool get isResolved => status == 'resolved' || status == 'closed';
  String get locationDisplay =>
      checkpointName != null && checkpointName!.isNotEmpty
          ? checkpointName!
          : 'Site Lokasi Utama';
  String get timeDisplay => createdAt ?? '';
}

class GuestModel {
  final int id;
  final int? siteId;
  final String guestName;
  final String? company;
  final String destination;
  final String purpose;
  final String? vehicleNumber;
  final String? idCardNumber;
  final String? photoUrl;
  final String? qrGuestCode;
  final String? checkInAt;
  final String? checkOutAt;
  final String status;

  GuestModel({
    required this.id,
    this.siteId,
    required this.guestName,
    this.company,
    required this.destination,
    required this.purpose,
    this.vehicleNumber,
    this.idCardNumber,
    this.photoUrl,
    this.qrGuestCode,
    this.checkInAt,
    this.checkOutAt,
    this.status = 'active',
  });

  factory GuestModel.fromJson(Map<String, dynamic> json) {
    return GuestModel(
      id: int.tryParse(json['id']?.toString() ?? json['guest_id']?.toString() ?? '0') ?? 0,
      siteId: int.tryParse(json['site_id']?.toString() ?? ''),
      guestName: json['guest_name']?.toString() ?? json['name']?.toString() ?? 'Tamu',
      company: json['company']?.toString() ?? json['institution']?.toString(),
      destination: json['destination']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      vehicleNumber: json['vehicle_number']?.toString(),
      idCardNumber: json['id_card_number']?.toString() ?? json['identity_no']?.toString(),
      photoUrl: json['photo_url']?.toString() ?? json['photo']?.toString(),
      qrGuestCode: json['qr_guest_code']?.toString() ?? json['qr_token']?.toString(),
      checkInAt: json['check_in_at']?.toString() ?? json['checkin_time']?.toString(),
      checkOutAt: json['check_out_at']?.toString() ?? json['checkout_time']?.toString(),
      status: json['status']?.toString() ?? (json['check_out_at'] != null ? 'checked_out' : 'active'),
    );
  }

  // Compatibility helpers
  String get guestId => id.toString();
  String get checkinTime => checkInAt ?? '';
  String get checkoutTime => checkOutAt ?? '';
  String get identityNo => idCardNumber ?? '';
  bool get isCheckedOut => checkOutAt != null && checkOutAt!.isNotEmpty && checkOutAt != 'null';
  bool get isActive => !isCheckedOut && status != 'checked_out';
}

class LiveGuardModel {
  final int id;
  final String name;
  final String role;
  final String badgeNumber;
  final String? siteName;
  final String? checkInAt;
  final String status;
  final double latitude;
  final double longitude;
  final String? lastCheckpointName;
  final String? lastScannedAt;
  final double? lastDistanceMeters;
  final bool isInPatrol;

  LiveGuardModel({
    required this.id,
    required this.name,
    required this.role,
    required this.badgeNumber,
    this.siteName,
    this.checkInAt,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.lastCheckpointName,
    this.lastScannedAt,
    this.lastDistanceMeters,
    required this.isInPatrol,
  });

  factory LiveGuardModel.fromJson(Map<String, dynamic> json) {
    return LiveGuardModel(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Petugas',
      role: json['role']?.toString() ?? 'SATPAM',
      badgeNumber: json['badge_number']?.toString() ?? '',
      siteName: json['site_name']?.toString(),
      checkInAt: json['check_in_at']?.toString(),
      status: json['status']?.toString() ?? 'Bertugas',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      lastCheckpointName: json['last_checkpoint_name']?.toString(),
      lastScannedAt: json['last_scanned_at']?.toString(),
      lastDistanceMeters: double.tryParse(json['last_distance_meters']?.toString() ?? ''),
      isInPatrol: json['is_in_patrol'] == true || json['is_in_patrol'] == 1,
    );
  }
}

class CheckpointRecapSummary {
  final int totalCheckpoints;
  final int totalScans;
  final int totalScannedPoints;
  final int totalMissedPoints;
  final double compliancePercentage;
  final int totalIncidentsReported;

  CheckpointRecapSummary({
    required this.totalCheckpoints,
    required this.totalScans,
    required this.totalScannedPoints,
    required this.totalMissedPoints,
    required this.compliancePercentage,
    required this.totalIncidentsReported,
  });

  factory CheckpointRecapSummary.fromJson(Map<String, dynamic> json) {
    return CheckpointRecapSummary(
      totalCheckpoints: int.tryParse(json['total_checkpoints']?.toString() ?? '0') ?? 0,
      totalScans: int.tryParse(json['total_scans']?.toString() ?? '0') ?? 0,
      totalScannedPoints: int.tryParse(json['total_scanned_points']?.toString() ?? '0') ?? 0,
      totalMissedPoints: int.tryParse(json['total_missed_points']?.toString() ?? '0') ?? 0,
      compliancePercentage: double.tryParse(json['compliance_percentage']?.toString() ?? '0') ?? 0.0,
      totalIncidentsReported: int.tryParse(json['total_incidents_reported']?.toString() ?? '0') ?? 0,
    );
  }
}

class CheckpointRecapLogItem {
  final int id;
  final String userName;
  final String? userBadge;
  final String scannedAt;
  final String condition;
  final String? notes;
  final double? distanceMeters;
  final String? selfiePhotoUrl;
  final double? latitude;
  final double? longitude;

  CheckpointRecapLogItem({
    required this.id,
    required this.userName,
    this.userBadge,
    required this.scannedAt,
    required this.condition,
    this.notes,
    this.distanceMeters,
    this.selfiePhotoUrl,
    this.latitude,
    this.longitude,
  });

  factory CheckpointRecapLogItem.fromJson(Map<String, dynamic> json) {
    return CheckpointRecapLogItem(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userName: json['user_name']?.toString() ?? json['guard_name']?.toString() ?? 'Petugas',
      userBadge: json['user_badge']?.toString() ?? json['badge_number']?.toString(),
      scannedAt: json['scanned_at']?.toString() ?? json['created_at']?.toString() ?? '',
      condition: json['condition']?.toString() ?? json['status']?.toString() ?? 'Aman',
      notes: json['notes']?.toString() ?? json['catatan']?.toString(),
      distanceMeters: double.tryParse(json['distance_meters']?.toString() ?? json['distance']?.toString() ?? ''),
      selfiePhotoUrl: json['selfie_photo_url']?.toString() ?? json['photo_url']?.toString() ?? json['selfie_photo']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
    );
  }
}

class CheckpointRecapItem {
  final int checkpointId;
  final String name;
  final String qrCode;
  final String? siteName;
  final String? floorOrLocation;
  final int targetScans;
  final int actualScans;
  final String status;
  final String? lastScannedAt;
  final String? lastScannedBy;
  final String? lastCondition;
  final double? latitude;
  final double? longitude;
  final List<CheckpointRecapLogItem> recentLogs;

  CheckpointRecapItem({
    required this.checkpointId,
    required this.name,
    required this.qrCode,
    this.siteName,
    this.floorOrLocation,
    required this.targetScans,
    required this.actualScans,
    required this.status,
    this.lastScannedAt,
    this.lastScannedBy,
    this.lastCondition,
    this.latitude,
    this.longitude,
    required this.recentLogs,
  });

  factory CheckpointRecapItem.fromJson(Map<String, dynamic> json) {
    List<CheckpointRecapLogItem> logs = [];
    final rawLogs = json['recent_logs'] ?? json['logs'] ?? json['history'];
    if (rawLogs is List) {
      logs = rawLogs
          .map((e) => CheckpointRecapLogItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return CheckpointRecapItem(
      checkpointId: int.tryParse(json['checkpoint_id']?.toString() ?? json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? json['checkpoint_name']?.toString() ?? 'Checkpoint',
      qrCode: json['qr_code']?.toString() ?? json['qr_token']?.toString() ?? '',
      siteName: json['site_name']?.toString(),
      floorOrLocation: json['floor_or_location']?.toString() ?? json['location']?.toString(),
      targetScans: int.tryParse(json['target_scans']?.toString() ?? '1') ?? 1,
      actualScans: int.tryParse(json['actual_scans']?.toString() ?? json['scans_count']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? (logs.isNotEmpty ? 'scanned' : 'unscanned'),
      lastScannedAt: json['last_scanned_at']?.toString(),
      lastScannedBy: json['last_scanned_by']?.toString() ?? json['guard_name']?.toString(),
      lastCondition: json['last_condition']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      recentLogs: logs,
    );
  }

  bool get isScanned => actualScans > 0 || status == 'scanned' || status == 'completed';
}

