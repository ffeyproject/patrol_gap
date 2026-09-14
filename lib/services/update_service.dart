import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

/// Model metadata informasi rilis APK dari server
class AppUpdateInfo {
  final String version;
  final int versionCode;
  final String apkUrl;
  final String changelog;
  final bool forceUpdate;
  final String? fileSize;

  AppUpdateInfo({
    required this.version,
    required this.versionCode,
    required this.apkUrl,
    required this.changelog,
    this.forceUpdate = false,
    this.fileSize,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: (json['version'] ?? json['version_name'] ?? '1.0.0').toString(),
      versionCode: int.tryParse(
            (json['version_code'] ?? json['versionCode'] ?? json['build_number'] ?? '1').toString(),
          ) ??
          1,
      apkUrl: (json['apk_url'] ?? json['download_url'] ?? json['url'] ?? '').toString(),
      changelog: (json['changelog'] ?? json['release_notes'] ?? json['notes'] ?? 'Pembaruan sistem dan peningkatan stabilitas.').toString(),
      forceUpdate: json['force_update'] == true || json['forceUpdate'] == true,
      fileSize: json['file_size']?.toString() ?? json['fileSize']?.toString(),
    );
  }
}

/// Service untuk menangani pengecekan dan auto-update APK dari server apk.produksionline.xyz
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// URL default untuk manifest version.json di server apk.produksionline.xyz
  static const String defaultUpdateUrl = 'https://apk.produksionline.xyz/files/version.json';

  bool _isChecking = false;

  /// Membaca info versi aplikasi lokal yang sedang aktif saat ini
  Future<PackageInfo> getLocalPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  /// Mengecek apakah ada versi baru di server
  Future<AppUpdateInfo?> checkUpdate() async {
    if (_isChecking) return null;
    _isChecking = true;

    try {
      final localInfo = await getLocalPackageInfo();
      final localVersionCode = int.tryParse(localInfo.buildNumber) ?? 1;
      final localVersionName = localInfo.version;

      AppUpdateInfo? remoteUpdate;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final headers = {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };

      // 1. Coba ambil dari manifest update version.json di /files/ atau root
      final manifestUrls = [
        'https://apk.produksionline.xyz/files/version.json?t=$timestamp',
        'https://apk.produksionline.xyz/version.json?t=$timestamp',
      ];

      for (final url in manifestUrls) {
        try {
          final res = await http.get(
            Uri.parse(url),
            headers: headers,
          ).timeout(const Duration(seconds: 6));

          if (res.statusCode == 200 && res.body.trim().startsWith('{')) {
            final data = jsonDecode(res.body);
            if (data is Map<String, dynamic> && data['version'] != null) {
              remoteUpdate = AppUpdateInfo.fromJson(data);
              break;
            }
          }
        } catch (_) {}
      }

      // 2. Fallback cerdas: Auto-deteksi file APK terbaru dari listing /files/ jika version.json belum di-upload
      if (remoteUpdate == null) {
        try {
          final filesRes = await http.get(
            Uri.parse('https://apk.produksionline.xyz/files/?t=$timestamp'),
            headers: headers,
          ).timeout(const Duration(seconds: 6));

          if (filesRes.statusCode == 200 && filesRes.body.trim().startsWith('[')) {
            final decoded = jsonDecode(filesRes.body);
            if (decoded is List) {
              String? highestVer;
              String? highestApkName;
              int highestSize = 0;

              final regex = RegExp(
                r'patroli[_\-\s]*gap[_\-\s]*v?([0-9]+(?:\.[0-9]+)*)\.apk',
                caseSensitive: false,
              );

              for (final item in decoded) {
                if (item is Map && item['name'] != null && item['type'] == 'file') {
                  final name = item['name'].toString();
                  final match = regex.firstMatch(name);
                  if (match != null) {
                    final verStr = match.group(1) ?? '';
                    if (verStr.isNotEmpty) {
                      if (highestVer == null || _compareVersions(verStr, highestVer) > 0) {
                        highestVer = verStr;
                        highestApkName = name;
                        highestSize = int.tryParse(item['size']?.toString() ?? '') ?? 0;
                      }
                    }
                  }
                }
              }

              if (highestVer != null && highestApkName != null) {
                final sizeMb = highestSize > 0
                    ? '${(highestSize / (1024 * 1024)).toStringAsFixed(1)} MB'
                    : '101.9 MB';

                remoteUpdate = AppUpdateInfo(
                  version: highestVer,
                  versionCode: 0,
                  apkUrl: 'https://apk.produksionline.xyz/files/$highestApkName',
                  changelog: '• Pembaruan sistem & fitur patroli terbaru versi $highestVer\n• Peningkatan kestabilan performa aplikasi',
                  forceUpdate: false,
                  fileSize: sizeMb,
                );
              }
            }
          }
        } catch (_) {}
      }

      // 3. Fallback: jika direct static gagal, coba query API Backend
      if (remoteUpdate == null) {
        try {
          final fallbackUri = Uri.parse('${ApiConfig.baseUrl}/app-version?t=$timestamp');
          final res = await http.get(
            fallbackUri,
            headers: headers,
          ).timeout(const Duration(seconds: 5));

          if (res.statusCode == 200 && res.body.trim().startsWith('{')) {
            final data = jsonDecode(res.body);
            if (data is Map<String, dynamic>) {
              final payload = data['data'] ?? data;
              if (payload is Map<String, dynamic>) {
                remoteUpdate = AppUpdateInfo.fromJson(payload);
              }
            }
          }
        } catch (_) {}
      }

      if (remoteUpdate == null || remoteUpdate.apkUrl.isEmpty) {
        return null;
      }

      // 4. Bandingkan versi server dengan versi aplikasi lokal
      final cmp = _compareVersions(remoteUpdate.version, localVersionName);

      if (cmp > 0) {
        // Versi server lebih tinggi (misal server 1.0.3 > lokal 1.0.2)
        return remoteUpdate;
      } else if (cmp == 0) {
        // Versi semantik sama persis (misal sama-sama 1.0.2)
        // Hanya picu update jika remote versionCode valid, bukan 0, dan lebih besar dari local versionCode
        if (remoteUpdate.versionCode > 0 &&
            localVersionCode > 0 &&
            remoteUpdate.versionCode > localVersionCode &&
            remoteUpdate.versionCode < 1000) {
          return remoteUpdate;
        }
      }

      // Jika versi server sama atau lebih rendah, aplikasi sudah yang terbaru
      return null;
    } catch (_) {
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// Membandingkan dua versi semantik (mengembalikan 1 jika v1 > v2, -1 jika v1 < v2, 0 jika sama)
  int _compareVersions(String v1, String v2) {
    try {
      final p1 = v1
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final p2 = v2
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final len = p1.length > p2.length ? p1.length : p2.length;
      for (var i = 0; i < len; i++) {
        final a = i < p1.length ? p1[i] : 0;
        final b = i < p2.length ? p2[i] : 0;
        if (a > b) return 1;
        if (a < b) return -1;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Pengecekan otomatis & menampilkan modal dialog pembaruan jika tersedia
  Future<void> checkForUpdate(BuildContext context, {bool silent = true}) async {
    final update = await checkUpdate();
    if (!context.mounted) return;

    if (update != null) {
      showUpdateDialog(context, update);
    } else if (!silent) {
      final info = await getLocalPackageInfo();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aplikasi sudah menggunakan versi terbaru (v${info.version}+${info.buildNumber}).',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  /// Menampilkan dialog pembaruan interaktif
  void showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (dialogCtx) => _UpdateDialog(updateInfo: updateInfo),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const _UpdateDialog({required this.updateInfo});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  int _progress = 0;
  String _statusText = '';
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  void _startUpdate() {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _errorMessage = null;
      _statusText = 'Menghubungkan ke server...';
    });

    try {
      final cleanUrl = widget.updateInfo.apkUrl.trim();
      final destinationName = 'Patroli_GAP_v${widget.updateInfo.version}.apk';

      _otaSubscription = OtaUpdate()
          .execute(
        cleanUrl,
        destinationFilename: destinationName,
      )
          .listen(
        (OtaEvent event) {
          if (!mounted) return;

          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final val = int.tryParse(event.value ?? '0') ?? 0;
              setState(() {
                _progress = val;
                _statusText = 'Mengunduh file APK ($val%)...';
              });
              break;
            case OtaStatus.INSTALLING:
              setState(() {
                _progress = 100;
                _statusText = 'Membuka instalasi APK...';
              });
              break;
            case OtaStatus.ALREADY_RUNNING_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Proses unduhan sedang berjalan di latar belakang.';
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Izin instalasi dari sumber tidak dikenal belum diaktifkan. Silakan aktifkan di Pengaturan Android.';
              });
              break;
            case OtaStatus.INTERNAL_ERROR:
            default:
              setState(() {
                _isDownloading = false;
                _errorMessage = 'Gagal mengunduh: ${event.value ?? 'Terjadi kesalahan internal'}';
              });
              break;
          }
        },
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _isDownloading = false;
            _errorMessage = 'Gagal mengunduh APK: $err';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Gagal memulai update: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return PopScope(
      canPop: !info.forceUpdate && !_isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon & Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF2563EB),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Tersedia',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Versi baru: v${info.version} (Build ${info.versionCode})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Server host badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_done_rounded, size: 14, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sumber Server: apk.produksionline.xyz',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Changelog Box
              const Text(
                'Catatan Rilis / Pembaruan:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.changelog,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),

              // Error notification if any
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Progress Section
              if (_isDownloading) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress / 100.0 : null,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _statusText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '$_progress%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              if (!_isDownloading) ...[
                Row(
                  children: [
                    if (!info.forceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Nanti Saja',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: info.forceUpdate ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _startUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Update Sekarang',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
