import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Exception khusus jika terdeteksi manipulasi Fake / Mock GPS
class MockGpsException implements Exception {
  final String message;
  MockGpsException([this.message = '⚠️ Akses Ditolak: Terdeteksi penggunaan Fake / Mock GPS pada perangkat Anda. Harap matikan aplikasi pemalsu lokasi dan gunakan sensor GPS fisik asli.']);

  @override
  String toString() => message;
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Meminta izin & mengambil posisi GPS saat ini dengan akurasi tinggi serta
  /// memvalidasi keaslian sinyal GPS dari manipulasi Fake / Mock Location Provider.
  /// 
  /// [allowMocked] default `false` untuk memastikan integritas data lapangan.
  Future<Position> getCurrentPosition({bool allowMocked = false}) async {
    // 1. Cek Service GPS Aktif
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS tidak aktif. Silakan aktifkan layanan lokasi perangkat.');
    }

    // 2. Cek Izin Lokasi
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin akses lokasi GPS ditolak.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Izin lokasi ditolak secara permanen. Silakan aktifkan di Pengaturan Aplikasi.');
    }

    // 3. Ambil Posisi Hardware GPS
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );

    // 4. SECURITY AUDIT: Anti-Fake / Mock GPS Check
    if (!allowMocked && position.isMocked) {
      debugPrint('🚨 [SECURITY ALERT] Mock GPS Terdeteksi! Lat: ${position.latitude}, Long: ${position.longitude}');
      throw MockGpsException();
    }

    return position;
  }

  /// Cek apakah posisi yang diberikan merupakan hasil manipulasi Mock GPS
  bool isMockLocation(Position position) {
    return position.isMocked;
  }

  /// Hitung jarak antara dua koordinat (dalam meter)
  double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}
