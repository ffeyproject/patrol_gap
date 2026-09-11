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
  static const String defaultUpdateUrl = 'https://apk.produksionline.xyz/version.json';

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

      // 1. Coba ambil dari manifest update server apk.produksionline.xyz
      AppUpdateInfo? remoteUpdate;
      try {
        final res = await http.get(
          Uri.parse(defaultUpdateUrl),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map<String, dynamic>) {
            remoteUpdate = AppUpdateInfo.fromJson(data);
          }
        }
      } catch (_) {
        // Fallback: jika direct static JSON gagal, coba query API Backend jika endpoint tersedia
        try {
          final fallbackUri = Uri.parse('${ApiConfig.baseUrl}/app-version');
          final res = await http.get(
            fallbackUri,
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 5));

          if (res.statusCode == 200) {
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

      // 2. Bandingkan versi server dengan versi aplikasi lokal
      final isNewerCode = remoteUpdate.versionCode > localVersionCode;
      final isNewerSemantic = _isVersionGreaterThan(remoteUpdate.version, localVersionName);

      if (isNewerCode || isNewerSemantic) {
        return remoteUpdate;
      }

      return null;
    } catch (_) {
      return null;
    } finally {
      _isChecking = false;
    }
  }

  /// Membandingkan semantic version (misal: "1.0.1" > "1.0.0")
  bool _isVersionGreaterThan(String remote, String local) {
    try {
      final rParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final lParts = local.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (var i = 0; i < 3; i++) {
        final r = i < rParts.length ? rParts[i] : 0;
        final l = i < lParts.length ? lParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (_) {
      return false;
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
