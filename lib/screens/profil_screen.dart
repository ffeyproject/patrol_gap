import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';
import '../services/session_service.dart';
import '../services/update_service.dart';
import '../widgets/common_widgets.dart';
import 'login_screen.dart';
import 'master_site_screen.dart';
import 'live_radar_screen.dart';
import 'checkpoint_recap_screen.dart';

class ProfilScreen extends StatefulWidget {
  final AppUser user;

  const ProfilScreen({
    super.key,
    required this.user,
  });

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  AppUser? _user;
  int _pending = 0;
  bool _syncing = false;
  String _appVersion = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadProfileData();
    _loadPending();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await UpdateService.instance.getLocalPackageInfo();
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}+${info.buildNumber}';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProfileData() async {
    try {
      final res = await ApiService.instance.get('/auth/profile');
      if (res['success'] == true &&
          (res['data'] != null || res['user'] != null) &&
          mounted) {
        final updated = AppUser.fromJson(res, widget.user.token);
        if (updated.id > 0 || updated.name.isNotEmpty || updated.username.isNotEmpty) {
          await SessionService.instance.saveUser(updated);
          setState(() {
            _user = updated;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPending() async {
    try {
      final count = await OfflineService.instance.pendingCount();
      if (!mounted) return;
      setState(() => _pending = count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pending = 0);
    }
  }

  Future<void> _syncOfflineData() async {
    if (_syncing) return;
    if (_pending <= 0) {
      _showMessage('Tidak ada data offline yang menunggu sinkronisasi.');
      return;
    }

    setState(() => _syncing = true);

    try {
      final synced = await OfflineService.instance.syncAll();
      if (!mounted) return;
      await _loadPending();
      _showMessage(
        synced > 0
            ? '$synced data patroli berhasil disinkronkan ke server.'
            : 'Seluruh data offline telah terkirim.',
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage('Sinkronisasi gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor:
              isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _showServerConfigModal() {
    final serverCtrl = TextEditingController(text: ApiConfig.baseUrl);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.dns_rounded, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 10),
            Text(
              'Pengaturan Server API',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alamat URL Backend REST API Laravel:',
              style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: serverCtrl,
              decoration: InputDecoration(
                hintText: 'https://patroli.portalgapsoft.xyz/api/v1',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            const Text(
              '• Default Production: https://patroli.portalgapsoft.xyz/api/v1\n• Localhost / IP Komputer: http://192.168.1.X:8000/api/v1',
              style: TextStyle(
                  fontSize: 11, color: Color(0xFF64748B), height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(dialogCtx);
              await ApiConfig.resetBaseUrl();
              if (mounted) {
                nav.pop();
                setState(() {});
                _showMessage('Base URL direset ke default.');
              }
            },
            child: const Text('Reset Default',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUrl = serverCtrl.text.trim();
              if (newUrl.isNotEmpty) {
                final nav = Navigator.of(dialogCtx);
                await ApiConfig.setBaseUrl(newUrl);
                if (mounted) {
                  nav.pop();
                  setState(() {});
                  _showMessage('Server API disimpan: ${ApiConfig.baseUrl}');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Simpan',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
              SizedBox(width: 10),
              Text(
                'Keluar Akun Petugas',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun aplikasi patroli ini?',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Keluar Akun',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ApiService.instance.post('/auth/logout');
    } catch (_) {}

    await SessionService.instance.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _getInitial(String name) {
    final value = name.trim();
    return value.isEmpty ? 'P' : value.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? widget.user;
    final fullName = user.fullName;
    final role = user.role.toUpperCase();
    final badgeNumber = user.badgeNumber;
    final username = user.username;
    final email = user.email;
    final phone = user.phone;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profil Petugas',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Identitas & Konfigurasi Sistem',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan Profil',
            onPressed: () {
              _loadProfileData();
              _loadPending();
            },
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () async {
          await _loadProfileData();
          await _loadPending();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
          children: [
            // 1. Hero Identity Profile Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF2563EB),
                    Color(0xFF3B82F6)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.shield_rounded,
                      size: 110,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.35),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.white,
                              child: Text(
                                _getInitial(fullName),
                                style: const TextStyle(
                                  color: Color(0xFF1E3A8A),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        role,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E)
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified_rounded,
                                              size: 11,
                                              color: Color(0xFF4ADE80)),
                                          SizedBox(width: 3),
                                          Text(
                                            'AKTIF',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  username.isNotEmpty
                                      ? '@$username • $badgeNumber'
                                      : badgeNumber,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),

                      // Contact info row
                      Row(
                        children: [
                          if (email.isNotEmpty) ...[
                            const Icon(Icons.email_outlined,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11.5),
                              ),
                            ),
                          ],
                          if (phone != null && phone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.phone_outlined,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (user.canSupervise) ...[
              _buildSectionHeader('MASTER DATA & SUPERVISI POSKO'),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.radar_rounded,
                title: 'Peta Live Radar Satpam',
                subtitle: 'Monitoring Posisi GPS Real-time & Status Regu Patroli',
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFDBEAFE),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            LiveRadarScreen(user: _user ?? widget.user)),
                  );
                },
              ),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.assignment_turned_in_rounded,
                title: 'Rekap Laporan Checkpoint',
                subtitle: 'Monitoring Kepatuhan Rute & Validasi Scan Titik',
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFEDE9FE),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            CheckpointRecapScreen(user: _user ?? widget.user)),
                  );
                },
              ),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.domain_add_rounded,
                title: 'Master Site & Checkpoint',
                subtitle: 'Kelola Lokasi Site, Titik QR Barcode & Geofencing',
                iconColor: const Color(0xFF0D9488),
                iconBg: const Color(0xFFCCFBF1),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            MasterSiteScreen(user: _user ?? widget.user)),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // 2. Section: Pengaturan Server & Sinkronisasi
            _buildSectionHeader('PENGATURAN & SINKRONISASI'),

            const SizedBox(height: 10),

            _MenuTile(
              icon: Icons.dns_rounded,
              title: 'Konfigurasi Server API',
              subtitle: ApiConfig.baseUrl,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFDBEAFE),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8)),
              onTap: _showServerConfigModal,
            ),

            const SizedBox(height: 10),

            _MenuTile(
              icon: Icons.cloud_upload_outlined,
              title: 'Data Offline Menunggu Sinkronisasi',
              subtitle: _pending > 0
                  ? '$_pending data patroli/foto tersimpan lokal'
                  : 'Seluruh data telah tersinkronkan ke server',
              iconColor: _pending > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF059669),
              iconBg: _pending > 0
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFD1FAE5),
              trailing: _pending > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFCD34D)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_syncing) ...[
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _syncing ? 'Syncing...' : 'Sync Now ($_pending)',
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 22),
              onTap: _pending > 0 ? _syncOfflineData : null,
            ),

            const SizedBox(height: 20),

            // 3. Section: Informasi Aplikasi
            _buildSectionHeader('INFORMASI APLIKASI'),

            const SizedBox(height: 10),

            _MenuTile(
              icon: Icons.system_update_rounded,
              title: 'Cek Pembaruan Versi Aplikasi',
              subtitle: 'Versi aktif: $_appVersion (Server: apk.produksionline.xyz)',
              iconColor: const Color(0xFF0284C7),
              iconBg: const Color(0xFFE0F2FE),
              trailing: const Icon(Icons.cloud_sync_rounded,
                  color: Color(0xFF0284C7)),
              onTap: () {
                UpdateService.instance.checkForUpdate(context, silent: false);
              },
            ),

            const SizedBox(height: 10),

            _MenuTile(
              icon: Icons.info_outline_rounded,
              title: 'Tentang Aplikasi Patroli GAP',
              subtitle: 'Patroli Security Mobile $_appVersion (Sanctum REST API)',
              iconColor: const Color(0xFF7C3AED),
              iconBg: const Color(0xFFEDE9FE),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8)),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Patroli Security GAP',
                  applicationVersion: '$_appVersion (Sanctum REST API)',
                  applicationIcon: const AppLogo(size: 48, borderRadius: 12),
                  children: const [
                    SizedBox(height: 10),
                    Text(
                      'Sistem Manajemen Patroli & Pengamanan Modern berbasis Real-Time Mobile dengan validasi Geofencing GPS, Deteksi Wajah Selfie Watermark, Pindai Barcode Checkpoint, Monitoring Insiden & Buku Tamu Digital.',
                      style: TextStyle(fontSize: 12.5, height: 1.45),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // 4. Logout Button
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded,
                        color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Keluar dari Akun (Logout)',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                'Terhubung ke: ${ApiConfig.baseUrl}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MenuTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    this.trailing,
    this.onTap,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
