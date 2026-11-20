import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

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

  Timer? _liveTrackingTimer;
  StreamSubscription<Position>? _positionStreamSub;
  bool _isPinging = false;
  Position? _lastPosition;

  /// Status apakah Live Tracking sedang aktif
  bool get isTrackingLive => _liveTrackingTimer != null || _positionStreamSub != null;

  /// Posisi terakhir yang tercatat
  Position? get lastPosition => _lastPosition;

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

    _lastPosition = position;

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

  // =========================================================================
  // 📍 1.4 LIVE REAL-TIME GPS LOCATION TRACKING (PING LOKASI SATPAM)
  // =========================================================================

  /// 1.4.1 Kirim Koordinat GPS Live Satpam (POST /live/location)
  /// Mengirimkan posisi koordinat, arah (heading), kecepatan (speed), dan akurasi (accuracy)
  Future<Map<String, dynamic>> sendLiveLocationPing({
    double? latitude,
    double? longitude,
    double? heading,
    double? speed,
    double? accuracy,
    Position? position,
  }) async {
    if (!ApiService.instance.hasToken) {
      return {'success': false, 'message': 'Sesi login tidak aktif'};
    }

    try {
      Position? currentPos = position;
      if (currentPos == null && (latitude == null || longitude == null)) {
        currentPos = await getCurrentPosition(allowMocked: false);
      }

      final double lat = latitude ?? currentPos?.latitude ?? 0.0;
      final double lng = longitude ?? currentPos?.longitude ?? 0.0;
      final double? head = heading ?? (currentPos?.heading != null && currentPos!.heading >= 0 ? currentPos.heading : null);
      final double? spd = speed ?? (currentPos?.speed != null && currentPos!.speed >= 0 ? currentPos.speed : null);
      final double? acc = accuracy ?? currentPos?.accuracy;

      if (lat == 0.0 && lng == 0.0) {
        return {'success': false, 'message': 'Koordinat GPS tidak valid'};
      }

      final payload = <String, dynamic>{
        'latitude': lat,
        'longitude': lng,
        if (head != null) 'heading': head,
        if (spd != null) 'speed': spd,
        if (acc != null) 'accuracy': acc,
      };

      final response = await ApiService.instance.post('/live/location', payload);
      return response;
    } catch (e) {
      debugPrint('📍 [LocationService] Live location ping failed: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Mulai pelacakan lokasi berkala (Foreground / Background Ping)
  /// Secara otomatis mengirimkan koordinat ke backend setiap `interval` (default 10 detik)
  void startLiveTracking({Duration interval = const Duration(seconds: 10)}) {
    if (!ApiService.instance.hasToken) return;
    if (_liveTrackingTimer != null) return; // Sudah berjalan

    debugPrint('📍 [LocationService] Memulai Live GPS Tracking (Interval: ${interval.inSeconds}s)...');

    // Ping pertama segera
    _performPeriodicPing();

    // Timer berkala
    _liveTrackingTimer = Timer.periodic(interval, (_) {
      _performPeriodicPing();
    });
  }

  /// Eksekusi ping berkala dengan pencegahan reentrant call
  Future<void> _performPeriodicPing() async {
    if (_isPinging || !ApiService.instance.hasToken) return;
    _isPinging = true;

    try {
      final pos = await getCurrentPosition(allowMocked: false);
      await sendLiveLocationPing(position: pos);
    } catch (e) {
      debugPrint('📍 [LocationService] Ping berkala dilewati: $e');
    } finally {
      _isPinging = false;
    }
  }

  /// Hentikan pelacakan GPS live
  void stopLiveTracking() {
    debugPrint('📍 [LocationService] Menghentikan Live GPS Tracking.');
    _liveTrackingTimer?.cancel();
    _liveTrackingTimer = null;
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _isPinging = false;
  }

  /// 1.4.2 Ambil Data Seluruh Satpam Aktif di Peta Live (GET /live/guards)
  Future<Map<String, dynamic>> fetchLiveGuards() async {
    return await ApiService.instance.get('/live/guards');
  }
}

