import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'absensi_screen.dart';
import 'patroli_screen.dart';
import 'insiden_screen.dart';
import 'tamu_screen.dart';
import 'master_site_screen.dart';
import 'live_radar_screen.dart';
import 'checkpoint_recap_screen.dart';

class BerandaScreen extends StatefulWidget {
  final AppUser user;

  const BerandaScreen({
    super.key,
    required this.user,
  });

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen>
    with SingleTickerProviderStateMixin {
  AppUser? _liveUser;
  AttendanceStatus? _attendance;
  PatrolSession? _activePatrol;
  int _incidentCount = 0;
  int _guestCount = 0;
  int _totalGuardsPresent = 0;
  bool _loading = true;

  // Real-time Clock
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  // Animations
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _liveUser = widget.user;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Detik jam real-time
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    _loadDashboardData();
  }

  @override
  void dispose() {
    _timer.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    if (mounted) setState(() => _loading = true);

    try {
      // 0. Ambil Profile User Terbaru
      try {
        final profileRes = await ApiService.instance.get('/auth/profile');
        if (profileRes['success'] == true &&
            (profileRes['data'] != null || profileRes['user'] != null)) {
          final updatedUser = AppUser.fromJson(
            profileRes,
            widget.user.token,
          );
          if (updatedUser.id > 0 ||
              updatedUser.name.isNotEmpty ||
              updatedUser.username.isNotEmpty) {
            await SessionService.instance.saveUser(updatedUser);
            if (mounted) {
              setState(() {
                _liveUser = updatedUser;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Profile sync error: $e');
      }

      // 1. Status Presensi
      final attRes = await ApiService.instance.get('/attendance/status');
      AttendanceStatus? attendance;
      if (attRes['success'] == true && attRes['data'] != null) {
        attendance = AttendanceStatus.fromJson(attRes);
      }

      // 2. Sesi Patroli Aktif
      final patrolRes = await ApiService.instance.get('/patrol/session/active');
      PatrolSession? activePatrol;
      if (patrolRes['success'] == true &&
          patrolRes['data'] != null &&
          patrolRes['data'] is Map) {
        activePatrol =
            PatrolSession.fromJson(patrolRes['data'] as Map<String, dynamic>);
      }

      // Fallback jika ada sesi aktif tetapi total checkpoints 0, ambil data site dari jadwal
      if (activePatrol != null && activePatrol.totalCheckpoints == 0) {
        try {
          final schedRes = await ApiService.instance.get('/patrol/my-schedules');
          if (schedRes['success'] == true &&
              schedRes['data'] is List &&
              (schedRes['data'] as List).isNotEmpty) {
            final list = schedRes['data'] as List;
            final sched = PatrolSchedule.fromJson(
                Map<String, dynamic>.from(list.first as Map));
            final totalCp = sched.site?.checkpointsCount ??
                sched.site?.checkpoints.length ??
                0;
            if (totalCp > 0) {
              final scannedCp = activePatrol.scannedCount > 0
                  ? activePatrol.scannedCount
                  : (sched.site?.checkpoints.where((c) => c.isScanned).length ?? 0);
              activePatrol = PatrolSession(
                sessionId: activePatrol.sessionId,
                scheduleId: activePatrol.scheduleId ?? sched.id,
                roundNumber: activePatrol.roundNumber,
                status: activePatrol.status,
                startedAt: activePatrol.startedAt,
                completedAt: activePatrol.completedAt,
                siteName: activePatrol.siteName ?? sched.site?.name,
                totalCheckpoints: totalCp,
                scannedCount: scannedCp,
                remainingCount:
                    (totalCp - scannedCp) < 0 ? 0 : (totalCp - scannedCp),
                checkpoints: activePatrol.checkpoints.isNotEmpty
                    ? activePatrol.checkpoints
                    : (sched.site?.checkpoints ?? []),
              );
            }
          }
        } catch (_) {}
      }

      // 3. Insiden
      final incRes = await ApiService.instance.get('/incidents');
      int incidentCount = 0;
      if (incRes['success'] == true && incRes['data'] is List) {
        incidentCount = (incRes['data'] as List).length;
      }

      // 4. Buku Tamu Aktif
      final guestRes = await ApiService.instance.get('/visitors');
      int guestCount = 0;
      if (guestRes['success'] == true && guestRes['data'] is List) {
        guestCount = (guestRes['data'] as List)
            .where((g) => g['check_out_at'] == null || g['status'] == 'active')
            .length;
      }

      // 5. Live Guards (jika danru/admin)
      int totalGuards = 0;
      final currentUser = _liveUser ?? widget.user;
      if (currentUser.canSupervise) {
        final guardRes = await ApiService.instance.get('/live/guards');
        if (guardRes['success'] == true && guardRes['data'] is Map) {
          totalGuards = int.tryParse(
                  guardRes['data']['total_guards_present']?.toString() ??
                      '0') ??
              0;
        }
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
        _attendance = attendance;
        _activePatrol = activePatrol;
        _incidentCount = incidentCount;
        _guestCount = guestCount;
        _totalGuardsPresent = totalGuards;
      });

      _animController.forward(from: 0.0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _animController.forward(from: 0.0);
    }
  }

  String _greeting() {
    final hour = _currentTime.hour;
    if (hour < 11) return 'Selamat Pagi ☀️';
    if (hour < 15) return 'Selamat Siang 🌤️';
    if (hour < 18) return 'Selamat Sore 🌇';
    return 'Selamat Malam 🌙';
  }

  String _firstName() {
    final currentUser = _liveUser ?? widget.user;
    final name = currentUser.name.trim();
    if (name.isEmpty) return 'Petugas';
    return name.split(' ').first;
  }

  Future<void> _openAbsensi() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AbsensiScreen(user: widget.user)),
    );
    if (mounted) _loadDashboardData();
  }

  Future<void> _openPatroli() async {
    final bool isCheckedIn =
        _attendance?.isCheckedIn == true && _attendance?.isCheckedOut != true;

    if (!isCheckedIn) {
      final bool isCheckedOut = _attendance?.isCheckedOut == true;
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_clock_rounded,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isCheckedOut
                      ? 'Shift Telah Selesai'
                      : 'Presensi Shift Diperlukan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            isCheckedOut
                ? 'Anda telah melakukan Check-Out presensi shift hari ini. Scan barcode checkpoint dinonaktifkan di luar jam kerja aktif.'
                : 'Anda belum melakukan Check-In kehadiran shift kerja. Petugas wajib Check-In terlebih dahulu untuk dapat memulai sesi patroli atau memindai barcode checkpoint.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Lihat Rute Patroli',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.bold),
              ),
            ),
            if (!isCheckedOut)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx, false);
                  _openAbsensi();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.fingerprint_rounded, size: 18),
                label: const Text(
                  'Presensi Masuk',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PatroliScreen(user: widget.user)),
    );
    if (mounted) _loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_currentTime);
    final String formattedTime = DateFormat('HH:mm:ss').format(_currentTime);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
        onRefresh: _loadDashboardData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Top Modern Header Bar
            _buildSliverHeader(formattedDate, formattedTime),

            // Main Dashboard Body with Fade-Slide Animation
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Status Kehadiran Shift Card
                        _buildAttendanceCard(),

                        const SizedBox(height: 16),

                        // 2. Hero Interactive Patrol Card
                        _buildHeroPatrolCard(),

                        const SizedBox(height: 24),

                        // 3. Quick Action Operations (Disesuaikan Hak Akses Role)
                        _buildSectionTitle(
                          title: 'Menu Operasional',
                          subtitle: (_liveUser ?? widget.user).isAdmin
                              ? 'Akses Administrator • Kendali Modul Lapangan'
                              : ((_liveUser ?? widget.user).isDanru
                                  ? 'Akses Komandan Regu • Supervisi & Patroli'
                                  : 'Pintas modul tugas pengamanan harian'),
                          icon: Icons.grid_view_rounded,
                          accentColor: (_liveUser ?? widget.user).isAdmin
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF2563EB),
                        ),

                        const SizedBox(height: 12),

                        _buildQuickActionGrid(),

                        const SizedBox(height: 24),

                        // 4. Posko & Lapangan Summary Metrics
                        _buildSectionTitle(
                          title: 'Ringkasan Posko Real-Time',
                          subtitle: 'Data terintegrasi pos penjagaan hari ini',
                          icon: Icons.analytics_rounded,
                          accentColor: const Color(0xFF0D9488),
                        ),

                        const SizedBox(height: 12),

                        _buildSummaryMetrics(),

                        const SizedBox(height: 20),

                        // 5. SOP & Security Tip Banner
                        _buildSecurityTipsCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER SLIVER APP BAR (SESUAI USER YANG LOGIN)
  // ============================================================
  Widget _buildSliverHeader(String formattedDate, String formattedTime) {
    final user = _liveUser ?? widget.user;
    final String displayName =
        user.fullName.isNotEmpty ? user.fullName : user.name;
    final String initial = displayName.trim().isNotEmpty
        ? displayName.trim().substring(0, 1).toUpperCase()
        : 'P';
    final String roleTag = user.role.toUpperCase();

    // Role Accent Color
    Color roleBadgeBg;
    Color roleBadgeBorder;
    Color roleTextColor;
    IconData roleIcon;

    if (user.role.toLowerCase().contains('admin')) {
      roleBadgeBg = const Color(0xFF7C3AED).withValues(alpha: 0.35);
      roleBadgeBorder = const Color(0xFFA78BFA);
      roleTextColor = const Color(0xFFF5F3FF);
      roleIcon = Icons.admin_panel_settings_rounded;
    } else if (user.role.toLowerCase().contains('danru') ||
        user.role.toLowerCase().contains('leader') ||
        user.role.toLowerCase().contains('supervisor')) {
      roleBadgeBg = const Color(0xFFD97706).withValues(alpha: 0.35);
      roleBadgeBorder = const Color(0xFFFBBF24);
      roleTextColor = const Color(0xFFFFFBEB);
      roleIcon = Icons.military_tech_rounded;
    } else {
      roleBadgeBg = Colors.white.withValues(alpha: 0.20);
      roleBadgeBorder = Colors.white.withValues(alpha: 0.40);
      roleTextColor = Colors.white;
      roleIcon = Icons.shield_rounded;
    }

    return SliverAppBar(
      expandedHeight: 135.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1E3A8A),
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Subtle Glow Circles
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: 60,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  ),
                ),
              ),

              // Content Inside Expanded Header
              SafeArea(
                bottom: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with glow ring and initial
                      GestureDetector(
                        onTap: () => _showUserProfileBottomSheet(user),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.35),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.white,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Color(0xFF1E3A8A),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // User Info & Greeting
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_greeting()}, ${_firstName()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.90),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: roleBadgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: roleBadgeBorder,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        roleIcon,
                                        size: 10,
                                        color: roleTextColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        roleTag,
                                        style: TextStyle(
                                          color: roleTextColor,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.username.isNotEmpty
                                  ? '@${user.username} • ${user.badgeNumber.isNotEmpty ? user.badgeNumber : user.email}'
                                  : (user.badgeNumber.isNotEmpty
                                      ? user.badgeNumber
                                      : user.email),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Refresh & Live Clock Action
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.30),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _PulsingLiveDot(color: Color(0xFF4ADE80)),
                                const SizedBox(width: 5),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: _loadDashboardData,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserProfileBottomSheet(AppUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF1E3A8A),
              child: Text(
                user.fullName.isNotEmpty
                    ? user.fullName.substring(0, 1).toUpperCase()
                    : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.username.isNotEmpty ? '@${user.username}' : user.email,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _profileInfoChip(
                      'Role', user.role.toUpperCase(), Icons.security_rounded),
                  _profileInfoChip(
                      'Badge',
                      user.badgeNumber.isNotEmpty ? user.badgeNumber : '-',
                      Icons.badge_rounded),
                  _profileInfoChip(
                      'Status', 'Aktif', Icons.check_circle_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _profileInfoChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF2563EB)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // 1. ATTENDANCE STATUS CARD
  // ============================================================
  Widget _buildAttendanceCard() {
    final bool isCheckedIn = _attendance?.isCheckedIn == true;
    final bool isCheckedOut = _attendance?.isCheckedOut == true;

    Color badgeBg;
    Color badgeTextColor;
    String statusTitle;
    String statusDesc;
    IconData statusIcon;

    if (isCheckedOut) {
      badgeBg = const Color(0xFFE2E8F0);
      badgeTextColor = const Color(0xFF475569);
      statusTitle = 'Shift Selesai (Check-Out)';
      statusDesc = 'Tugas hari ini telah diselesaikan dengan baik.';
      statusIcon = Icons.task_alt_rounded;
    } else if (isCheckedIn) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeTextColor = const Color(0xFF15803D);
      statusTitle = 'Sedang Bertugas (Hadir)';
      statusDesc = _attendance?.checkInAt != null
          ? 'Check-In pukul ${_attendance!.checkInAt} • GPS Terverifikasi'
          : 'Presensi masuk aktif dan tervalidasi.';
      statusIcon = Icons.verified_user_rounded;
    } else {
      badgeBg = const Color(0xFFFEF3C7);
      badgeTextColor = const Color(0xFFB45309);
      statusTitle = 'Belum Check-In Shift';
      statusDesc = 'Ambil foto selfie & verifikasi lokasi GPS Anda.';
      statusIcon = Icons.access_time_filled_rounded;
    }

    return _InteractiveCard(
      onTap: _openAbsensi,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCheckedIn && !isCheckedOut
                  ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                  : (isCheckedOut
                      ? const Color(0xFF64748B).withValues(alpha: 0.12)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              statusIcon,
              color: isCheckedIn && !isCheckedOut
                  ? const Color(0xFF16A34A)
                  : (isCheckedOut
                      ? const Color(0xFF475569)
                      : const Color(0xFFD97706)),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusTitle,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  statusDesc,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Action CTA Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: isCheckedIn && !isCheckedOut
                  ? const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                  : const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: (isCheckedIn && !isCheckedOut
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF2563EB))
                      .withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              isCheckedOut
                  ? 'Detail'
                  : (isCheckedIn ? 'Check-Out' : 'Check-In'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 2. HERO INTERACTIVE PATROL CARD
  // ============================================================
  Widget _buildHeroPatrolCard() {
    final hasActive = _activePatrol != null;
    final int roundNum = _activePatrol?.roundNumber ?? 1;
    final int scanned = _activePatrol?.scannedCount ?? 0;
    final int total = _activePatrol?.totalCheckpoints ?? 0;
    final double progress = total > 0 ? (scanned / total).clamp(0.0, 1.0) : 0.0;
    final int percentage = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasActive
              ? const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)]
              : const [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                (hasActive ? const Color(0xFF0F172A) : const Color(0xFF2563EB))
                    .withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Realistic 3D Command Center Background Image with Opacity & Gradient Filter
            Positioned.fill(
              child: Opacity(
                opacity: 0.22,
                child: Image.asset(
                  'assets/images/patrol_banner.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),

            // Background Decorative Geometric Accents
            Positioned(
              right: -25,
              top: -25,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -35,
              right: 40,
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 130,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Badge Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          hasActive
                              ? Icons.radar_rounded
                              : Icons.shield_moon_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasActive
                                ? 'RONDE $roundNum SEDANG BERJALAN'
                                : 'RONDE PATROLI KELILING',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            hasActive
                                ? 'Site: ${_activePatrol?.siteName ?? "Gedung Utama"}'
                                : 'Validasi Geofencing & QR Code',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: hasActive
                              ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: hasActive
                                ? const Color(0xFF4ADE80)
                                : Colors.white.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasActive) ...[
                              const _PulsingLiveDot(color: Color(0xFF4ADE80)),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              hasActive ? 'LIVE AKTIF' : 'SIAP',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Main Stats Content
                  if (hasActive) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$scanned',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          ' / $total Titik',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            color: Color(0xFF67E8F9),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Animated Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: progress),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF38BDF8)),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Siap Menjalankan Sesi Patroli GAP?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pindai barcode titik pos secara berurutan sesuai rute site yang telah dijadwalkan.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openPatroli,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1E3A8A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            hasActive
                                ? Icons.qr_code_scanner_rounded
                                : Icons.play_arrow_rounded,
                            size: 20,
                            color: const Color(0xFF1E3A8A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasActive
                                ? 'Lanjutkan Scan Checkpoint Ronde $roundNum'
                                : 'Buka Jadwal & Mulai Patroli',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 3. QUICK ACTION GRID (MENYESUAIKAN HAK AKSES ROLE)
  // ============================================================
  Widget _buildQuickActionGrid() {
    final user = _liveUser ?? widget.user;
    final bool canSupervise = user.canSupervise;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.18,
      children: [
        _QuickActionTile(
          title: 'Presensi Shift',
          subtitle: 'Foto Selfie & GPS Validasi',
          tag: 'SELFIE GPS',
          icon: Icons.camera_front_rounded,
          gradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          accentColor: const Color(0xFF2563EB),
          iconBg: const Color(0xFF2563EB),
          onTap: _openAbsensi,
        ),
        _QuickActionTile(
          title: 'Scan Patroli',
          subtitle: 'QR Barcode & Geofencing',
          tag: 'QR PATROL',
          icon: Icons.qr_code_scanner_rounded,
          gradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          accentColor: const Color(0xFF059669),
          iconBg: const Color(0xFF059669),
          onTap: _openPatroli,
        ),
        _QuickActionTile(
          title: 'Lapor Insiden',
          subtitle: 'Temuan Lapangan Darurat',
          tag: 'EMERGENCY',
          icon: Icons.warning_amber_rounded,
          gradient: const [Color(0xFFFFF1F2), Color(0xFFFEE2E2)],
          accentColor: const Color(0xFFDC2626),
          iconBg: const Color(0xFFDC2626),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => InsidenScreen(user: widget.user)),
          ).then((_) => _loadDashboardData()),
        ),
        _QuickActionTile(
          title: 'Buku Tamu',
          subtitle: 'Registrasi & Cek Visitor',
          tag: 'VISITOR',
          icon: Icons.badge_outlined,
          gradient: const [Color(0xFFFAF5FF), Color(0xFFEDE9FE)],
          accentColor: const Color(0xFF7C3AED),
          iconBg: const Color(0xFF7C3AED),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TamuScreen(user: widget.user)),
          ).then((_) => _loadDashboardData()),
        ),
        if (canSupervise) ...[
          _QuickActionTile(
            title: 'Master Site & QR',
            subtitle: 'CRUD Site & Geofencing',
            tag: user.isAdmin ? 'ADMIN' : 'DANRU',
            icon: Icons.domain_add_rounded,
            gradient: const [Color(0xFFF0FDFA), Color(0xFFCCFBF1)],
            accentColor: const Color(0xFF0D9488),
            iconBg: const Color(0xFF0D9488),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => MasterSiteScreen(user: widget.user)),
            ).then((_) => _loadDashboardData()),
          ),
          _QuickActionTile(
            title: user.isAdmin ? 'Radar Posko' : 'Supervisi Regu',
            subtitle: 'Monitoring Petugas Aktif',
            tag: 'LIVE RADAR',
            icon: Icons.radar_rounded,
            gradient: const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
            accentColor: const Color(0xFF16A34A),
            iconBg: const Color(0xFF16A34A),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LiveRadarScreen(user: widget.user)),
            ).then((_) => _loadDashboardData()),
          ),
          _QuickActionTile(
            title: 'Rekap Checkpoint',
            subtitle: 'Kepatuhan & Validasi Titik',
            tag: 'REKAP 3.6',
            icon: Icons.assignment_turned_in_rounded,
            gradient: const [Color(0xFFFAF5FF), Color(0xFFEDE9FE)],
            accentColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFF7C3AED),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CheckpointRecapScreen(user: widget.user)),
            ).then((_) => _loadDashboardData()),
          ),
          _QuickActionTile(
            title: 'Rekap Laporan',
            subtitle: 'Insiden & Aktivitas Shift',
            tag: 'LOG REPORT',
            icon: Icons.assignment_rounded,
            gradient: const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
            accentColor: const Color(0xFF475569),
            iconBg: const Color(0xFF475569),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InsidenScreen(user: widget.user)),
            ).then((_) => _loadDashboardData()),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // 4. SUMMARY METRICS (MEGAH & INFORMATIF)
  // ============================================================
  Widget _buildSummaryMetrics() {
    final user = _liveUser ?? widget.user;
    final bool canSupervise = user.canSupervise;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Laporan Insiden',
            value: '$_incidentCount',
            subtitle:
                _incidentCount == 0 ? 'Kondisi Terkendali' : 'Perlu Perhatian',
            badgeText: _incidentCount == 0 ? 'AMAN' : 'PERHATIAN',
            icon: Icons.report_problem_rounded,
            color: _incidentCount == 0
                ? const Color(0xFF16A34A)
                : const Color(0xFFEF4444),
            bgColor: _incidentCount == 0
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFEF2F2),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => InsidenScreen(user: widget.user)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            title: 'Tamu di Lokasi',
            value: '$_guestCount',
            subtitle: _guestCount == 0 ? 'Belum Ada Tamu' : 'Aktif Berkunjung',
            badgeText: 'VISITOR',
            icon: Icons.groups_2_rounded,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TamuScreen(user: widget.user)),
            ),
          ),
        ),
        if (canSupervise) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              title: 'Petugas Hadir',
              value: '$_totalGuardsPresent',
              subtitle: 'Radar Satpam Aktif',
              badgeText: 'ON DUTY',
              icon: Icons.shield_rounded,
              color: const Color(0xFF059669),
              bgColor: const Color(0xFFECFDF5),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => LiveRadarScreen(user: widget.user)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // 5. SECURITY TIPS / SOP INFO CARD
  // ============================================================
  Widget _buildSecurityTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Standar Prosedur Patroli (SOP)',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Pastikan GPS HP aktif & berada dalam radius maksimal 10 meter dari titik barcode saat scan untuk mencegah penolakan sistem.',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE COMPONENT
  // ============================================================
  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// HELPER COMPONENTS & WIDGETS
// ============================================================

/// Card dengan feedback interaktif (scale down saat ditekan)
class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const _InteractiveCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard> {
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
          padding: widget.padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Quick Action Tile (Megah, Padat, & Interaktif)
class _QuickActionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final List<Color> gradient;
  final Color accentColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.gradient,
    required this.accentColor,
    required this.iconBg,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Top subtle gradient bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  child: Container(
                    color: widget.accentColor,
                  ),
                ),

                // Ambient Watermark Icon at bottom-right
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    widget.icon,
                    size: 76,
                    color: widget.accentColor.withValues(alpha: 0.05),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header Row: Icon Container + Tag Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  widget.iconBg,
                                  widget.iconBg.withValues(alpha: 0.82),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.iconBg.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.tag,
                              style: TextStyle(
                                color: widget.accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Content: Title & Subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: widget.accentColor
                                      .withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: widget.accentColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Metric Card (Megah, Padat, & Mewah)
class _MetricCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  State<_MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<_MetricCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.bgColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 20,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.badgeText,
                      style: TextStyle(
                        color: widget.color,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Counter Number
              Text(
                widget.value,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 5),

              // Title
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 1),

              // Subtitle
              Text(
                widget.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing Live Dot Animation
class _PulsingLiveDot extends StatefulWidget {
  final Color color;

  const _PulsingLiveDot({required this.color});

  @override
  State<_PulsingLiveDot> createState() => _PulsingLiveDotState();
}

class _PulsingLiveDotState extends State<_PulsingLiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.75, end: 1.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
