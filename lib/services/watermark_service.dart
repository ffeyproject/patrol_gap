import 'dart:io';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Menambahkan watermark permanen (tercetak di dalam pixel foto, bukan cuma
/// overlay UI) berisi nama petugas, hari & tanggal, nama lokasi (hasil
/// reverse-geocoding), dan titik koordinat GPS ke foto selfie patroli.
class WatermarkService {
  WatermarkService._();
  static final WatermarkService instance = WatermarkService._();

  /// [photo]     : file foto asli (hasil kamera)
  /// [fullName]  : nama petugas yang sedang login
  /// [position]  : posisi GPS saat foto diambil
  /// [checkpointName] : opsional, nama checkpoint untuk ditambahkan ke baris lokasi
  ///
  /// Mengembalikan [File] baru (foto sudah ada watermark-nya) yang siap
  /// dipakai untuk preview maupun dikirim ke server.
  Future<File> applyWatermark({
    required File photo,
    required String fullName,
    required Position position,
    String? checkpointName,
  }) async {
    final bytes = await photo.readAsBytes();

    final original = img.decodeImage(bytes);
    if (original == null) {
      throw Exception('Gagal membaca file foto untuk watermark.');
    }

    // ------------------------------------------------------------
    // Susun teks watermark
    // ------------------------------------------------------------

    final now = DateTime.now();

    final dateText = DateFormat("EEEE, dd MMMM yyyy - HH:mm", 'id_ID')
        .format(now);

    final coordText =
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

    String locationText = await _resolveAddress(position);
    if (checkpointName != null && checkpointName.trim().isNotEmpty) {
      locationText = '$checkpointName - $locationText';
    }

    final lines = <String>[
      fullName,
      dateText,
      locationText,
      'Koordinat: $coordText',
    ];

    // ------------------------------------------------------------
    // Gambar kotak semi-transparan + teks di bagian bawah foto
    // ------------------------------------------------------------

    final watermarked = _drawWatermark(original, lines);

    // ------------------------------------------------------------
    // Simpan sebagai file baru
    // ------------------------------------------------------------

    final dir = await getTemporaryDirectory();
    final outPath =
        '${dir.path}/patroli_wm_${now.millisecondsSinceEpoch}.jpg';

    final outFile = File(outPath);
    await outFile.writeAsBytes(
      img.encodeJpg(watermarked, quality: 85),
    );

    return outFile;
  }

  /// Reverse-geocoding koordinat -> nama lokasi yang bisa dibaca manusia.
  /// Jika gagal (tidak ada internet / provider error), tetap kembalikan
  /// string koordinat supaya watermark tidak gagal total.
  Future<String> _resolveAddress(Position position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        return 'Lokasi tidak diketahui';
      }

      final p = placemarks.first;

      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.subAdministrativeArea,
      ].where((e) => e != null && e.trim().isNotEmpty).toSet().toList();

      if (parts.isEmpty) {
        return p.administrativeArea ?? 'Lokasi tidak diketahui';
      }

      return parts.join(', ');
    } catch (_) {
      return 'Lokasi tidak diketahui';
    }
  }

  img.Image _drawWatermark(img.Image original, List<String> lines) {
    final font = img.arial24;
    const lineHeight = 30;
    const padding = 16;

    final boxHeight = padding * 2 + lines.length * lineHeight;
    final boxTop = original.height - boxHeight;

    // Kotak hitam semi-transparan sebagai latar teks agar tetap terbaca
    // di foto terang maupun gelap.
    img.fillRect(
      original,
      x1: 0,
      y1: boxTop < 0 ? 0 : boxTop,
      x2: original.width,
      y2: original.height,
      color: img.ColorRgba8(0, 0, 0, 130),
    );

    var y = (boxTop < 0 ? 0 : boxTop) + padding;

    for (final line in lines) {
      img.drawString(
        original,
        line,
        font: font,
        x: padding,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );
      y += lineHeight;
    }

    return original;
  }
}
