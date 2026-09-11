import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'patrol_confirm_screen.dart';

class QrScanScreen extends StatefulWidget {
  final AppUser user;
  final int? activeSessionId;

  const QrScanScreen({
    super.key,
    required this.user,
    this.activeSessionId,
  });

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  late final MobileScannerController _controller;

  bool _handled = false;
  bool _checking = false;
  bool _torchEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 1000,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _checking) return;
    if (capture.barcodes.isEmpty) return;

    String? code;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim();
      if (rawValue != null && rawValue.isNotEmpty) {
        code = rawValue;
        break;
      }
    }

    if (code == null || code.isEmpty) return;

    await _processScannedQr(code);
  }

  Future<void> _processScannedQr(String code) async {
    if (_checking || _handled) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      try {
        await _controller.stop();
      } catch (_) {}

      _handled = true;
      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatrolConfirmScreen(
            user: widget.user,
            qrToken: code,
            activeSessionId: widget.activeSessionId,
          ),
        ),
      );

      if (!mounted) return;

      Navigator.pop(context, result == true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _handled = false;
        _error = 'Terjadi kesalahan pemrosesan QR.';
      });
      try {
        await _controller.start();
      } catch (_) {}
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (!mounted) return;
      setState(() => _torchEnabled = !_torchEnabled);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final double frameSize = (width * 0.72).clamp(200.0, 280.0);
          final double frameTop = (height - frameSize) / 2.3;
          final double frameLeft = (width - frameSize) / 2;

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _ScannerOverlayPainter(
                    frameTop: frameTop,
                    frameLeft: frameLeft,
                    frameSize: frameSize,
                  ),
                  size: Size(width, height),
                ),
              ),
              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _IconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Scan QR Checkpoint', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Arahkan kamera ke QR Code', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _IconButton(
                          icon: _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          active: _torchEnabled,
                          onTap: _toggleTorch,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Scanner Frame Corner Marks
              Positioned(
                top: frameTop,
                left: frameLeft,
                child: SizedBox(
                  width: frameSize,
                  height: frameSize,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      if (!_checking)
                        Positioned(
                          left: 20,
                          right: 20,
                          top: frameSize / 2,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Bottom Instructions
              Positioned(
                left: 20,
                right: 20,
                bottom: 30,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error ?? 'Pastikan QR Code Checkpoint berada di dalam area kotak.',
                            style: TextStyle(
                              color: _error != null ? AppColors.danger : Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accent : Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double frameTop;
  final double frameLeft;
  final double frameSize;

  _ScannerOverlayPainter({
    required this.frameTop,
    required this.frameLeft,
    required this.frameSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(frameLeft, frameTop, frameSize, frameSize),
      const Radius.circular(20),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()..addRRect(frameRect),
      ),
      bgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
