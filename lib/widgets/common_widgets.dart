import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// ===============================================================
/// APP LOGO
/// ===============================================================
/// Logo resmi aplikasi (assets/images/logo.png), dipakai konsisten di
/// splash screen, halaman login, dan profil supaya tidak ada lagi ikon
/// generik (Icons.shield_*) yang berbeda-beda di tiap layar.
/// Kalau aset gagal dimuat, tetap tampil fallback ikon perisai supaya
/// UI tidak pernah pecah.
class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color iconFallbackColor;

  const AppLogo({
    super.key,
    this.size = 64,
    this.borderRadius = 18,
    this.backgroundColor,
    this.iconFallbackColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.15),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.shield_rounded,
              color: iconFallbackColor,
              size: size * 0.55,
            );
          },
        ),
      ),
    );
  }
}

/// ===============================================================
/// STAT CARD
/// ===============================================================
/// Kartu statistik ringkas untuk dashboard.
/// Contoh:
/// - 8/10 Checkpoint
/// - 12 Insiden
/// - 5 Tamu
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================================
/// STATUS PILL
/// ===============================================================
/// Label kecil berwarna untuk status.
///
/// Contoh:
/// StatusPill(
///   text: 'Aman',
///   color: AppColors.success,
/// )
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const StatusPill({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// ===============================================================
/// ACTION TILE
/// ===============================================================
/// Tombol aksi berbentuk kartu.
/// Digunakan untuk menu utama/dashboard.
class ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// LOADING BUTTON
/// ===============================================================
/// Tombol dengan indikator loading.
///
/// Saat loading == true:
/// - tombol dinonaktifkan
/// - menampilkan CircularProgressIndicator
class LoadingButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  const LoadingButton({
    super.key,
    required this.loading,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: color != null
            ? ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color!.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.white70,
              )
            : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: loading
              ? const SizedBox(
                  key: ValueKey<String>('loading'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  key: const ValueKey<String>('label'),
                ),
        ),
      ),
    );
  }
}

/// ===============================================================
/// SAFE IMAGE VIEW
/// ===============================================================
/// Widget cerdas & tangguh untuk memuat gambar dari berbagai sumber:
/// 1. Otomatis mencoba berbagai kombinasi URL path dari backend Laravel
/// 2. Otomatis mencoba tanpa header auth & dengan Bearer token
/// 3. Data Base64 (data:image/... atau raw base64)
/// 4. File path lokal di storage HP
/// 5. Fallback placeholder elegan jika gagal dimuat + tombol salin link
class SafeImageView extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;
  final IconData fallbackIcon;
  final String? fallbackText;
  final Map<String, String>? headers;
  final bool showActionButtons;

  const SafeImageView({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.fallbackIcon = Icons.broken_image_rounded,
    this.fallbackText,
    this.headers,
    this.showActionButtons = false,
  });

  @override
  State<SafeImageView> createState() => _SafeImageViewState();
}

class _SafeImageViewState extends State<SafeImageView> {
  List<String> _candidates = [];
  int _candidateIndex = 0;
  bool _useAuthHeader = false;
  bool _allFailed = false;

  @override
  void initState() {
    super.initState();
    _initCandidates();
  }

  @override
  void didUpdateWidget(SafeImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initCandidates();
    }
  }

  void _initCandidates() {
    _candidates = ApiConfig.getImageCandidates(widget.imageUrl);
    _candidateIndex = 0;
    _useAuthHeader = false;
    _allFailed = _candidates.isEmpty;
  }

  void _handleError() {
    if (!mounted) return;

    // Jika belum coba dengan header autentikasi pada candidate saat ini
    if (!_useAuthHeader && ApiService.instance.hasToken) {
      setState(() {
        _useAuthHeader = true;
      });
      return;
    }

    // Coba kandidat URL berikutnya jika masih ada
    if (_candidateIndex < _candidates.length - 1) {
      setState(() {
        _candidateIndex++;
        _useAuthHeader = false;
      });
    } else {
      setState(() {
        _allFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.imageUrl?.trim() ?? '';
    if (raw.isEmpty || _allFailed || _candidates.isEmpty) {
      return _buildFallback();
    }

    final currentTarget = _candidates[_candidateIndex];

    Widget content;

    if (currentTarget.startsWith('data:image') || _isLikelyBase64(currentTarget)) {
      content = _buildBase64Image(currentTarget);
    } else if (currentTarget.startsWith('/') && File(currentTarget).existsSync()) {
      content = Image.file(
        File(currentTarget),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else if (currentTarget.startsWith('http://') || currentTarget.startsWith('https://')) {
      final imgHeaders = widget.headers ??
          (_useAuthHeader ? ApiService.instance.imageHeaders : {'Accept': 'image/*, */*'});

      content = Image.network(
        currentTarget,
        key: ValueKey('img_${currentTarget}_$_useAuthHeader'),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        headers: imgHeaders,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          final total = progress.expectedTotalBytes;
          final loaded = progress.cumulativeBytesLoaded;
          final percent = total != null && total > 0 ? (loaded / total) : null;

          return Container(
            width: widget.width,
            height: widget.height,
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 2.2,
                color: const Color(0xFF2563EB),
              ),
            ),
          );
        },
        errorBuilder: (ctx, err, stack) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleError();
          });
          return Container(
            width: widget.width,
            height: widget.height,
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          );
        },
      );
    } else {
      content = _buildFallback();
    }

    if (widget.borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: content,
      );
    }

    return content;
  }

  bool _isLikelyBase64(String str) {
    if (str.length < 100) return false;
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(str.replaceAll('\n', '').replaceAll('\r', ''));
  }

  Widget _buildBase64Image(String raw) {
    try {
      String clean = raw;
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      clean = clean.replaceAll('\n', '').replaceAll('\r', '').trim();
      final bytes = base64Decode(clean);
      return Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } catch (_) {
      return _buildFallback();
    }
  }

  Widget _buildFallback() {
    final rawUrl = widget.imageUrl?.trim() ?? '';
    final resolvedUrl = ApiConfig.resolveImageUrl(rawUrl);

    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.fallbackIcon,
                size: (widget.width != null && widget.width! < 60) ? 20 : 38,
                color: const Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            Text(
              widget.fallbackText ?? 'Foto selfie watermark belum tersedia / tidak ditemukan di server.',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.showActionButtons && resolvedUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: resolvedUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Link foto disalin: $resolvedUrl'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 13),
                    label: const Text('Salin Link', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _initCandidates();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 13),
                    label: const Text('Coba Lagi', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal Dialog interaktif untuk preview foto selfie watermark / bukti dengan fitur zoom & pan
void showAppImagePreviewDialog(
  BuildContext context, {
  required String? imageUrl,
  required String title,
  String? subtitle,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) {
      final screenHeight = MediaQuery.of(dialogCtx).size.height;
      final screenWidth = MediaQuery.of(dialogCtx).size.width;
      final isLandscape = screenWidth > screenHeight;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 32 : 16,
          vertical: isLandscape ? 12 : 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: screenHeight * (isLandscape ? 0.94 : 0.85),
            maxWidth: 640,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Header Dialog
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null && subtitle.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                subtitle,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                ),

                // 2. Interactive Zoomable Image Area (Flexible agar responsif di layar landscape & tidak overflow)
                Flexible(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xFF0F172A),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Center(
                        child: SafeImageView(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          fallbackText: 'Foto selfie watermark belum tersedia atau gagal dimuat dari server.',
                          fallbackIcon: Icons.broken_image_rounded,
                          showActionButtons: true,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. Bottom Bar info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: const Color(0xFFF8FAFC),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.pinch_rounded, size: 13, color: Color(0xFF64748B)),
                          SizedBox(width: 5),
                          Text(
                            'Cubit / geser untuk zoom foto',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
