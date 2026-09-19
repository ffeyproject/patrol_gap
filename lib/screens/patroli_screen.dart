import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/offline_service.dart';
import '../services/session_service.dart';
import 'absensi_screen.dart';
import 'qr_scan_screen.dart';

class PatroliScreen extends StatefulWidget {
  final AppUser user;

  const PatroliScreen({
    super.key,
    required this.user,
  });

  @override
  State<PatroliScreen> createState() => _PatroliScreenState();
}

class _PatroliScreenState extends State<PatroliScreen> {
  PatrolSchedule? _schedule;
  PatrolSession? _activeSession;
  AttendanceStatus? _attendance;
  List<CheckpointModel> _checkpoints = [];

  bool _loading = true;
  bool _syncing = false;
  int _pendingSync = 0;
  String? _errorMessage;

  bool get _isCheckedIn =>
      _attendance?.isCheckedIn == true && _attendance?.isCheckedOut != true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    try {
      // 0. Ambil Status Presensi (Wajib Check-In)
      AttendanceStatus? attendance;
      try {
        final attRes = await ApiService.instance.get('/attendance/status');
        if (attRes['success'] == true && attRes['data'] != null) {
          attendance = AttendanceStatus.fromJson(attRes);
        }
      } catch (_) {}

      // 1. Ambil Sesi Aktif
      final activeRes = await ApiService.instance.get('/patrol/session/active');

      PatrolSession? activeSession;
      List<CheckpointModel> checkpoints = [];

      if (activeRes['success'] == true &&
          activeRes['data'] != null &&
          activeRes['data'] is Map) {
        activeSession =
            PatrolSession.fromJson(activeRes['data'] as Map<String, dynamic>);
        checkpoints = activeSession.checkpoints;
      }

      // 2. Ambil Jadwal Shift Saya
      final scheduleRes = await ApiService.instance.get('/patrol/my-schedules');
      PatrolSchedule? schedule;

      if (scheduleRes['success'] == true &&
          scheduleRes['data'] is List &&
          (scheduleRes['data'] as List).isNotEmpty) {
        final list = scheduleRes['data'] as List;
        schedule =
            PatrolSchedule.fromJson(Map<String, dynamic>.from(list.first as Map));

        // Jika checkpoints belum ada atau sesi aktif tidak menyertakan checkpoint, gunakan dari jadwal site
        if (checkpoints.isEmpty && schedule.site != null) {
          checkpoints = schedule.site!.checkpoints;
          await SessionService.instance.setActiveSiteId(schedule.siteId);
        }

        if (activeSession != null &&
            activeSession.totalCheckpoints == 0 &&
            checkpoints.isNotEmpty) {
          final totalCp = schedule.site?.checkpointsCount ?? checkpoints.length;
          final scannedCp = checkpoints.where((c) => c.isScanned).length;
          activeSession = PatrolSession(
            sessionId: activeSession.sessionId,
            scheduleId: activeSession.scheduleId ?? schedule.id,
            roundNumber: activeSession.roundNumber,
            status: activeSession.status,
            startedAt: activeSession.startedAt,
            completedAt: activeSession.completedAt,
            siteName: activeSession.siteName ?? schedule.site?.name,
            totalCheckpoints: totalCp,
            scannedCount: scannedCp,
            remainingCount: (totalCp - scannedCp) < 0 ? 0 : (totalCp - scannedCp),
            progressPercentage: activeSession.progressPercentage,
            isAllScanned: activeSession.isAllScanned,
            nextCheckpoint: activeSession.nextCheckpoint,
            checkpoints: checkpoints,
          );
        }
      }

      final pending = await OfflineService.instance.pendingCount();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _attendance = attendance;
        _activeSession = activeSession;
        _schedule = schedule;
        _checkpoints = checkpoints;
        _pendingSync = pending;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat data patroli: $e';
      });
    }
  }

  Future<void> _showCheckInRequiredDialog() async {
    final bool isCheckedOut = _attendance?.isCheckedOut == true;
    final title = isCheckedOut
        ? 'Shift Sudah Selesai (Check-Out)'
        : 'Presensi Shift Diperlukan';
    final desc = isCheckedOut
        ? 'Anda telah melakukan Check-Out presensi shift hari ini. Anda tidak dapat melakukan scan patroli di luar jam shift aktif.'
        : 'Anda belum melakukan Check-In shift kerja. Silakan lakukan Presensi Masuk (Check-In) terlebih dahulu untuk mulai memindai checkpoint patroli.';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
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
          desc,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Tutup',
              style: TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.bold),
            ),
          ),
          if (!isCheckedOut)
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AbsensiScreen(user: widget.user),
                  ),
                );
                if (mounted) _loadData();
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
                'Check-In Sekarang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startRoundDialog() async {
    if (!_isCheckedIn) {
      await _showCheckInRequiredDialog();
      return;
    }

    int nextRound = (_schedule?.completedRoundsCount ?? 0) + 1;
    int selectedRound = nextRound > 5 ? 1 : nextRound;
    final notesCtrl =
        TextEditingController(text: 'Memulai patroli round $selectedRound area site');

    final bool? startConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(Icons.play_circle_fill_rounded,
                  color: Color(0xFF2563EB), size: 26),
              SizedBox(width: 10),
              Text(
                'Mulai Ronde Patroli',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Nomor Ronde Patroli:',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: List.generate(5, (index) {
                  final round = index + 1;
                  final isSelected = selectedRound == round;
                  return ChoiceChip(
                    label: Text('Round $round'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) =>
                        setDialogState(() => selectedRound = round),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text(
                'Catatan Tugas (Opsional):',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Misal: Patroli round area basement & lobby',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Mulai Patroli',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (startConfirmed != true) return;

    setState(() => _loading = true);

    try {
      final Map<String, dynamic> body = {
        'round_number': selectedRound,
        'notes': notesCtrl.text.trim(),
      };
      if (_schedule?.id != null && _schedule!.id > 0) {
        body['patrol_schedule_id'] = _schedule!.id;
      }

      final res = await ApiService.instance.post(
        '/patrol/session/start',
        body,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(res['message']?.toString() ??
                'Sesi patroli berhasil dimulai! Silakan scan titik checkpoint.'),
          ),
        );
        await _loadData();
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(
                res['message']?.toString() ?? 'Gagal memulai sesi patroli.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error: $e')),
      );
    }
  }

  Future<void> _finishRoundDialog() async {
    if (_activeSession == null) return;

    final notesCtrl = TextEditingController(
        text: 'Ronde patroli selesai, seluruh area terpantau aman.');

    final bool? finishConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF16A34A), size: 26),
            SizedBox(width: 10),
            Text(
              'Selesaikan Ronde Patroli',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda telah memindai ${_activeSession!.scannedCount} dari ${_activeSession!.totalCheckpoints} checkpoint.',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            const Text('Catatan Penyelesaian Ronde:',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Misal: Ronde selesai, seluruh pintu darurat terkunci aman.',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              ),
              style: const TextStyle(fontSize: 12.5),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Batal',
                  style: TextStyle(
                      color: Color(0xFF64748B), fontWeight: FontWeight.bold))),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Selesaikan Ronde',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (finishConfirmed != true) return;

    setState(() => _loading = true);

    try {
      final res = await ApiService.instance.post(
        '/patrol/session/finish',
        {
          'patrol_session_id': _activeSession!.sessionId,
          'notes': notesCtrl.text.trim(),
        },
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text(
                res['message']?.toString() ?? 'Ronde patroli berhasil diselesaikan!'),
          ),
        );
        await _loadData();
      } else {
        setState(() => _loading = false);
        final msg = res['message']?.toString() ?? 'Gagal menyelesaikan patroli.';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 24),
                SizedBox(width: 8),
                Text('Ronde Belum Lengkap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(msg, style: const TextStyle(fontSize: 13, height: 1.4)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error: $e')),
      );
    }
  }

  Future<void> _syncOffline() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final count = await OfflineService.instance.syncAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count > 0
              ? '$count data patroli berhasil disinkronkan'
              : 'Belum ada data antrean'),
        ),
      );
      await _loadData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi offline gagal')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _scanQr([CheckpointModel? targetCheckpoint]) async {
    if (!_isCheckedIn) {
      await _showCheckInRequiredDialog();
      return;
    }

    if (_activeSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD97706),
          content: Text('Silakan tekan tombol "Mulai Ronde" terlebih dahulu sebelum scan QR.'),
        ),
      );
      await _startRoundDialog();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrScanScreen(
          user: widget.user,
          activeSessionId: _activeSession!.sessionId,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final int done = _activeSession != null
        ? _activeSession!.scannedCount
        : _checkpoints.where((c) => c.isScanned).length;
    final int total = _activeSession != null
        ? _activeSession!.totalCheckpoints
        : _checkpoints.length;
    final double progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

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
              'Patroli Keamanan',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Geofencing QR Checkpoint & Watermark',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_pendingSync > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.cloud_upload_outlined,
                    color: Color(0xFFD97706)),
                onPressed: _syncOffline,
                tooltip: 'Sync data offline ($_pendingSync)',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            onPressed: _loadData,
            tooltip: 'Segarkan',
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _scanQr(),
              backgroundColor: _isCheckedIn
                  ? const Color(0xFF059669)
                  : const Color(0xFF64748B),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: Icon(
                _isCheckedIn
                    ? Icons.qr_code_scanner_rounded
                    : Icons.lock_clock_rounded,
              ),
              label: Text(
                _isCheckedIn
                    ? (_activeSession?.nextCheckpoint != null
                        ? 'Scan Titik #${_activeSession!.nextCheckpoint!.orderIndex}'
                        : 'Pindai QR Checkpoint')
                    : 'Wajib Check-In Shift',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 0.3),
              ),
            ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: _loadData,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Peringatan Check-In jika belum presensi
                  if (!_isCheckedIn) _buildCheckInWarningCard(),

                  // 1. Shift Schedule Card
                  _buildShiftScheduleCard(),

                  const SizedBox(height: 14),

                  // 2. Active Session Card
                  _buildActiveSessionCard(
                      done: done, total: total, progress: progress),

                  // 2.1 Next Checkpoint Guidance Banner (Sekuensial)
                  if (_activeSession != null && _activeSession!.nextCheckpoint != null) ...[
                    const SizedBox(height: 14),
                    _buildNextCheckpointGuideCard(_activeSession!.nextCheckpoint!),
                  ],

                  const SizedBox(height: 22),

                  // 3. Section Title with Start / Finish Round Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Titik Checkpoint Rute',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            _activeSession != null
                                ? 'Ronde ${_activeSession!.roundNumber}: $done dari $total telah diverifikasi'
                                : '$total titik checkpoint dalam rute shift ini',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (_activeSession == null)
                        ElevatedButton.icon(
                          onPressed: _startRoundDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text(
                            'Mulai Ronde',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                        )
                      else if (_activeSession!.isAllScanned)
                        ElevatedButton.icon(
                          onPressed: _finishRoundDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text(
                            'Selesai Ronde',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 4. Checkpoints List
                  if (_checkpoints.isEmpty)
                    _buildEmptyCheckpoints()
                  else
                    ..._checkpoints.asMap().entries.map((entry) {
                      final index = entry.key;
                      final cp = entry.value;
                      final bool isNextTarget = _activeSession?.nextCheckpoint != null &&
                          (cp.id == _activeSession!.nextCheckpoint!.id ||
                              cp.orderIndex == _activeSession!.nextCheckpoint!.orderIndex ||
                              (index + 1) == _activeSession!.nextCheckpoint!.orderIndex);

                      return _CheckpointTile(
                        number: index + 1,
                        checkpoint: cp,
                        hasActiveSession: _activeSession != null,
                        isNextTarget: isNextTarget,
                        onScanTap: () => _scanQr(cp),
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _buildNextCheckpointGuideCard(NextCheckpointInfo nextCp) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(Icons.near_me_rounded, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'TITIK #${nextCp.orderIndex}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Wajib Discan Berikutnya',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  nextCp.name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _scanQr(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInWarningCard() {
    final bool isCheckedOut = _attendance?.isCheckedOut == true;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_clock_rounded,
              color: Color(0xFFD97706),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckedOut
                      ? 'Shift Selesai (Sudah Check-Out)'
                      : 'Wajib Presensi Check-In',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isCheckedOut
                      ? 'Anda telah checkout shift. Scan patroli dinonaktifkan di luar jam kerja aktif.'
                      : 'Lakukan Check-In kehadiran shift sebelum memulai sesi atau scan barcode checkpoint.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFB45309),
                    height: 1.3,
                  ),
                ),
                if (!isCheckedOut) ...[
                  const SizedBox(height: 9),
                  InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AbsensiScreen(user: widget.user),
                        ),
                      );
                      if (mounted) _loadData();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fingerprint_rounded,
                              size: 15, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Check-In Presensi Sekarang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftScheduleCard() {
    final schedule = _schedule;
    final siteName = schedule?.site?.name ?? 'Site PT. Gajah Angkasa Perkasa';
    final shiftName = schedule?.shiftName ?? 'Shift Rutin Patroli';
    final isCurrent = schedule?.isCurrentShift == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isCurrent ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.domain_rounded,
                color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF64748B), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  siteName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shiftName,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrent ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isCurrent ? 'SHIFT AKTIF' : 'TERJADWAL',
              style: TextStyle(
                color: isCurrent ? const Color(0xFF15803D) : const Color(0xFF64748B),
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard({
    required int done,
    required int total,
    required double progress,
  }) {
    final bool hasActiveSession = _activeSession != null;
    final int percentage = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasActiveSession
              ? const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)]
              : const [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (hasActiveSession
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF2563EB))
                .withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.radar_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: hasActiveSession
                          ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: hasActiveSession
                            ? const Color(0xFF4ADE80)
                            : Colors.white.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasActiveSession
                              ? Icons.radar_rounded
                              : Icons.pending_actions_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasActiveSession
                              ? 'RONDE ${_activeSession!.roundNumber} AKTIF'
                              : 'SIAP MULAI RONDE',
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
                  const Spacer(),
                  if (hasActiveSession)
                    InkWell(
                      onTap: _finishRoundDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Selesai Ronde',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$done / $total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasActiveSession
                              ? 'Checkpoint tervalidasi pada ronde ${_activeSession!.roundNumber}'
                              : 'Klik tombol "Mulai Ronde" di bawah untuk mengaktifkan',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCheckpoints() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFF94A3B8), size: 48),
            SizedBox(height: 12),
            Text(
              'Tidak Ada Titik Checkpoint',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFF0F172A)),
            ),
            SizedBox(height: 4),
            Text(
              'Belum ada titik checkpoint yang terdaftar untuk jadwal site ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckpointTile extends StatefulWidget {
  final int number;
  final CheckpointModel checkpoint;
  final bool hasActiveSession;
  final bool isNextTarget;
  final VoidCallback onScanTap;

  const _CheckpointTile({
    required this.number,
    required this.checkpoint,
    this.hasActiveSession = false,
    this.isNextTarget = false,
    required this.onScanTap,
  });

  @override
  State<_CheckpointTile> createState() => _CheckpointTileState();
}

class _CheckpointTileState extends State<_CheckpointTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cp = widget.checkpoint;
    final isScanned = cp.isScanned;
    final isNext = widget.isNextTarget;

    Color borderColor = const Color(0xFFE2E8F0);
    double borderWidth = 1.0;
    if (isScanned) {
      borderColor = const Color(0xFF86EFAC);
      borderWidth = 1.4;
    } else if (isNext) {
      borderColor = const Color(0xFF3B82F6);
      borderWidth = 1.8;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onScanTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isNext ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: isNext
                    ? const Color(0xFF2563EB).withValues(alpha: 0.08)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Checkpoint Number Pill
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isScanned
                      ? const Color(0xFFDCFCE7)
                      : (isNext ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isScanned
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF16A34A), size: 20)
                      : (isNext
                          ? const Icon(Icons.near_me_rounded,
                              color: Color(0xFF2563EB), size: 20)
                          : Text(
                              '${widget.number}',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            )),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Geofence Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cp.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isNext ? const Color(0xFF1E40AF) : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.qr_code_rounded,
                            size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          cp.code,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Radius max 10m',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Status Tag
              if (isScanned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TERVERIFIKASI',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                )
              else if (isNext)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'TARGET BERIKUTNYA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                )
              else if (widget.hasActiveSession)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'MENUNGGU GILIRAN',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PINDAI SEKARANG',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
