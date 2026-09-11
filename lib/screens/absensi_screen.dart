import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';
import '../services/watermark_service.dart';
import '../theme/app_theme.dart';

class AbsensiScreen extends StatefulWidget {
  final AppUser user;

  const AbsensiScreen({
    super.key,
    required this.user,
  });

  @override
  State<AbsensiScreen> createState() => _AbsensiScreenState();
}

class _AbsensiScreenState extends State<AbsensiScreen> {
  CameraController? _cameraController;

  bool _cameraReady = false;
  bool _processing = false;
  bool _loadingStatus = true;

  AttendanceStatus? _attendanceStatus;
  String? _statusMessage;
  bool _statusIsError = false;

  late final FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableTracking: false,
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
      ),
    );

    _loadAttendanceStatus();
    _initializeCamera();
  }

  Future<void> _loadAttendanceStatus() async {
    try {
      final res = await ApiService.instance.get('/attendance/status');
      if (mounted) {
        setState(() {
          _loadingStatus = false;
          if (res['success'] == true && res['data'] != null) {
            _attendanceStatus = AttendanceStatus.fromJson(res);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingStatus = false);
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Kamera tidak tersedia pada perangkat ini.');
      }

      CameraDescription selectedCamera;
      try {
        selectedCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      } catch (_) {
        selectedCamera = cameras.first;
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
        _statusMessage = null;
        _statusIsError = false;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _statusIsError = true;
        _statusMessage = _cameraErrorMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _statusIsError = true;
        _statusMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _cameraErrorMessage(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Akses kamera ditolak. Silakan aktifkan izin kamera.';
      case 'cameraNotFound':
        return 'Kamera tidak ditemukan pada perangkat ini.';
      default:
        return 'Kamera tidak dapat digunakan. Pastikan izin kamera telah diberikan.';
    }
  }

  Future<bool> _validateFace(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        throw Exception(
          'Wajah tidak terdeteksi. Posisikan wajah di tengah kamera dan pastikan pencahayaan cukup.',
        );
      }

      if (faces.length > 1) {
        throw Exception(
          'Terdeteksi lebih dari satu wajah. Pastikan hanya wajah petugas yang terlihat.',
        );
      }

      return true;
    } on PlatformException catch (e) {
      debugPrint('ML Kit Face Detection PlatformException: $e');
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _submitAttendance(String type) async {
    if (_processing) return;

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _showError('Kamera belum siap. Silakan tunggu beberapa saat.');
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      // 1. Ambil Foto
      final picture = await controller.takePicture();
      if (!mounted) return;

      // 2. Validasi Wajah
      await _validateFace(picture.path);
      if (!mounted) return;

      // 3. Ambil Lokasi GPS
      final position = await LocationService.instance.getCurrentPosition();
      if (!mounted) return;

      // 4. Bubuhkan Watermark pada foto
      final rawPhotoFile = File(picture.path);
      final watermarkedFile = await WatermarkService.instance.applyWatermark(
        photo: rawPhotoFile,
        fullName: widget.user.fullName,
        position: position,
        checkpointName: type == 'CHECK_IN' ? 'Presensi Masuk Shift' : 'Presensi Pulang Shift',
      );

      final activeSiteId = await SessionService.instance.getActiveSiteId();

      // 5. Kirim Multipart Request ke Server
      Map<String, dynamic> response;
      if (type == 'CHECK_IN') {
        response = await ApiService.instance.multipartPost(
          '/attendance/check-in',
          fields: {
            'site_id': activeSiteId.toString(),
            'latitude': position.latitude.toString(),
            'longitude': position.longitude.toString(),
            'notes': 'Hadir tepat waktu siap tugas',
          },
          files: {
            'selfie_photo': watermarkedFile,
          },
        );
      } else {
        response = await ApiService.instance.multipartPost(
          '/attendance/check-out',
          fields: {
            'latitude': position.latitude.toString(),
            'longitude': position.longitude.toString(),
            'notes': 'Selesai shift tugas',
          },
          files: {
            'selfie_photo': watermarkedFile,
          },
        );
      }

      if (!mounted) return;

      final success = response['success'] == true;

      if (success) {
        setState(() {
          _processing = false;
          _statusIsError = false;
          _statusMessage = type == 'CHECK_IN'
              ? 'Presensi Masuk berhasil dicatat!'
              : 'Presensi Pulang berhasil dicatat!';
        });

        await Future.delayed(const Duration(milliseconds: 1400));
        if (!mounted) return;

        Navigator.pop(context, true);
      } else {
        setState(() {
          _processing = false;
          _statusIsError = true;
          _statusMessage = response['message']?.toString() ?? 'Presensi gagal disimpan ke server.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusIsError = true;
        _statusMessage = _cleanErrorMessage(e);
      });
    }
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Terjadi kesalahan saat memproses absensi.' : message;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.danger,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 21),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildCameraSection(),
            ),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            onPressed: _processing ? null : () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: _processing ? Colors.white24 : Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Presensi Shift Satpam',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'Selfie Watermark & GPS Geofencing',
                  style: TextStyle(color: Colors.white60, fontSize: 11.5),
                ),
              ],
            ),
          ),
          _buildCameraStatus(),
        ],
      ),
    );
  }

  Widget _buildCameraStatus() {
    final ready = _cameraReady;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: ready ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            ready ? 'Kamera siap' : 'Menyiapkan',
            style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_cameraReady && _cameraController != null)
            Positioned.fill(child: _buildCameraPreview())
          else
            _buildCameraLoading(),

          if (_cameraReady)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: Colors.black.withValues(alpha: 0.13)),
              ),
            ),

          if (_cameraReady)
            const IgnorePointer(
              child: _FaceScannerFrame(),
            ),

          if (_cameraReady)
            Positioned(
              top: 16,
              left: 18,
              right: 18,
              child: _buildInstruction(),
            ),

          if (_processing)
            Positioned.fill(
              child: _buildProcessingOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController!;
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  Widget _buildCameraLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
          SizedBox(height: 16),
          Text('Menyiapkan kamera...', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _buildInstruction() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: const Row(
        children: [
          Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Posisikan wajah Anda di dalam bingkai untuk validasi',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.70),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
            SizedBox(height: 18),
            Text(
              'Memproses Presensi...',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Membubuhkan watermark & verifikasi GPS',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    final bool isCheckedIn = _attendanceStatus?.isCheckedIn == true;
    final bool isCheckedOut = _attendanceStatus?.isCheckedOut == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUserInfo(),
          const SizedBox(height: 12),
          if (_statusMessage != null) ...[
            _buildStatusMessage(),
            const SizedBox(height: 10),
          ],
          _buildLocationInfo(),
          const SizedBox(height: 14),
          _buildActionButtons(isCheckedIn: isCheckedIn, isCheckedOut: isCheckedOut),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.user.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.user.badgeNumber} • ${widget.user.role.toUpperCase()}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        if (!_loadingStatus && _attendanceStatus != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (_attendanceStatus!.isCheckedIn && !_attendanceStatus!.isCheckedOut)
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _attendanceStatus!.isCheckedOut
                  ? 'Sudah Pulang'
                  : (_attendanceStatus!.isCheckedIn ? 'Hadir (Shift Aktif)' : 'Belum Masuk'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: (_attendanceStatus!.isCheckedIn && !_attendanceStatus!.isCheckedOut)
                    ? AppColors.success
                    : AppColors.warning,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Foto selfie akan dicap watermark nama, waktu & GPS.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
          Icon(Icons.verified_outlined, color: AppColors.success, size: 16),
        ],
      ),
    );
  }

  Widget _buildStatusMessage() {
    final isError = _statusIsError;
    final color = isError ? AppColors.danger : AppColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({required bool isCheckedIn, required bool isCheckedOut}) {
    return Row(
      children: [
        // Tombol Check-In Masuk
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_processing || (isCheckedIn && !isCheckedOut))
                  ? null
                  : () => _submitAttendance('CHECK_IN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Check-In Masuk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Tombol Check-Out Pulang
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_processing || !isCheckedIn || isCheckedOut)
                  ? null
                  : () => _submitAttendance('CHECK_OUT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Check-Out Pulang', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
          ),
        ),
      ],
    );
  }
}

class _FaceScannerFrame extends StatelessWidget {
  const _FaceScannerFrame();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = (constraints.maxWidth * 0.72).clamp(200.0, 290.0);
        return SizedBox(
          width: size,
          height: size * 1.25,
          child: CustomPaint(
            painter: _OvalScannerPainter(),
          ),
        );
      },
    );
  }
}

class _OvalScannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
