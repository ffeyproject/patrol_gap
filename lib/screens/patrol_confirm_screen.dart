import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/offline_service.dart';
import '../services/watermark_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class PatrolConfirmScreen extends StatefulWidget {
  final AppUser user;
  final String qrToken;
  final int? activeSessionId;
  final CheckpointModel? checkpoint;

  const PatrolConfirmScreen({
    super.key,
    required this.user,
    required this.qrToken,
    this.activeSessionId,
    this.checkpoint,
  });

  @override
  State<PatrolConfirmScreen> createState() => _PatrolConfirmScreenState();
}

class _PatrolConfirmScreenState extends State<PatrolConfirmScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notesCtrl = TextEditingController();

  File? _photo;
  String _conditionStatus = 'normal'; // 'normal', 'warning', 'danger'

  bool _submitting = false;
  bool _processingPhoto = false;
  String? _error;

  final Map<String, String> _conditionLabels = {
    'normal': 'Kondisi Aman / Normal',
    'warning': 'Perhatian / Kerusakan Ringan',
    'danger': 'Bahaya / Temuan Kritis',
  };

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? xfile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (xfile == null || !mounted) return;

      setState(() {
        _processingPhoto = true;
        _error = null;
      });

      // Ambil GPS dan terapkan watermark
      final pos = await LocationService.instance.getCurrentPosition();
      final displayName = widget.checkpoint?.name ?? 'Checkpoint ${widget.qrToken}';

      final watermarked = await WatermarkService.instance.applyWatermark(
        photo: File(xfile.path),
        fullName: widget.user.fullName,
        position: pos,
        checkpointName: displayName,
      );

      if (!mounted) return;

      setState(() {
        _photo = watermarked;
        _processingPhoto = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingPhoto = false;
        _error = 'Gagal mengambil foto/lokasi: ${_cleanError(e)}';
      });
    }
  }

  Future<void> _submitScan() async {
    if (_photo == null) {
      setState(() => _error = 'Foto selfie petugas di depan checkpoint wajib dilampirkan.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final pos = await LocationService.instance.getCurrentPosition();
      final sessionId = widget.activeSessionId ?? 1;

      final hasConnection = await OfflineService.instance.hasConnection();

      if (!hasConnection) {
        // Simpan ke offline queue jika tidak ada koneksi
        await OfflineService.instance.enqueue(
          'patrolScan',
          {
            'patrol_session_id': sessionId,
            'qr_token': widget.qrToken,
            'latitude': pos.latitude,
            'longitude': pos.longitude,
            'condition_status': _conditionStatus,
            'notes': _notesCtrl.text.trim(),
            'photo_path': _photo!.path,
          },
        );

        if (!mounted) return;

        _showResultDialog(
          title: 'Disimpan Offline',
          message: 'Tidak ada koneksi internet. Data patroli checkpoint disimpan di perangkat dan akan disinkronkan saat online.',
          isSuccess: true,
          offline: true,
        );
        return;
      }

      // Kirim Multipart POST ke /patrol/scan
      final res = await ApiService.instance.multipartPost(
        '/patrol/scan',
        fields: {
          'patrol_session_id': sessionId.toString(),
          'qr_token': widget.qrToken,
          'latitude': pos.latitude.toString(),
          'longitude': pos.longitude.toString(),
          'condition_status': _conditionStatus,
          'notes': _notesCtrl.text.trim(),
        },
        files: {
          'selfie_photo': _photo!,
        },
      );

      if (!mounted) return;

      if (res['success'] == true) {
        final data = res['data'];
        final cpName = data?['checkpoint_name'] ?? widget.qrToken;
        final dist = data?['distance_meters'] != null ? '${data!['distance_meters']} meter' : '';

        _showResultDialog(
          title: 'Scan Berhasil Terverifikasi',
          message: "Checkpoint '$cpName' berhasil diverifikasi! ${dist.isNotEmpty ? '\nJarak ke titik: $dist' : ''}",
          isSuccess: true,
        );
      } else {
        setState(() {
          _submitting = false;
          _error = res['message']?.toString() ?? 'Checkpoint ditolak oleh server.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _cleanError(e);
      });
    }
  }

  String _cleanError(dynamic e) {
    return e.toString().replaceFirst('Exception: ', '').trim();
  }

  void _showResultDialog({
    required String title,
    required String message,
    required bool isSuccess,
    bool offline = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: (isSuccess ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: isSuccess ? AppColors.success : AppColors.danger,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4), textAlign: TextAlign.center),
            if (offline) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 16),
                    SizedBox(width: 8),
                    Expanded(child: Text('Data menunggu sinkronisasi otomatis.', style: TextStyle(fontSize: 11, color: AppColors.warning))),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Selesai & Lanjutkan'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkpointTitle = widget.checkpoint?.name ?? 'Checkpoint ${widget.qrToken}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Verifikasi Patroli'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HASIL SCAN QR', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(checkpointTitle, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Token: ${widget.qrToken}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Section: Foto Selfie Watermark
          const Text('Foto Selfie Petugas (Wajib)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Foto akan dicap watermark nama, waktu dan koordinat GPS secara otomatis.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: (_submitting || _processingPhoto) ? null : _takePhoto,
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _photo != null ? AppColors.success : AppColors.border,
                  width: _photo != null ? 1.5 : 1,
                ),
              ),
              child: _processingPhoto
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Membubuhkan watermark foto...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : (_photo == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_front_rounded, size: 38, color: AppColors.primary),
                            SizedBox(height: 10),
                            Text('Ambil Foto Selfie', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            SizedBox(height: 4),
                            Text('Ketuk untuk membuka kamera depan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(_photo!, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text('Ambil Ulang', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )),
            ),
          ),
          const SizedBox(height: 20),
          // Section: Kondisi Fisik Checkpoint
          const Text('Kondisi Fisik Checkpoint', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _conditionLabels.entries.map((e) {
              final isSelected = _conditionStatus == e.key;
              Color chipColor = AppColors.primary;
              if (e.key == 'warning') chipColor = AppColors.warning;
              if (e.key == 'danger') chipColor = AppColors.danger;

              return ChoiceChip(
                label: Text(e.value),
                selected: isSelected,
                selectedColor: chipColor,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _conditionStatus = e.key),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          // Section: Catatan
          const Text('Catatan Temuan (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Misal: Area bersih, gembok terkunci aman...',
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: LoadingButton(
              loading: _submitting,
              label: 'Verifikasi & Simpan Checkpoint',
              onPressed: _submitScan,
            ),
          ),
        ],
      ),
    );
  }
}
