import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Konfigurasi koneksi ke RESTful API Backend Laravel (Sanctum).
class ApiConfig {
  static const String _defaultAndroidEmulatorUrl =
      'http://10.0.2.2:8000/api/v1';
  static const String _defaultLocalhostUrl = 'http://127.0.0.1:8000/api/v1';

  static const String _prefKeyBaseUrl = 'custom_api_base_url';

  static String _activeBaseUrl =
      kIsWeb ? _defaultLocalhostUrl : _defaultAndroidEmulatorUrl;

  /// Mendapatkan Base URL saat ini
  static String get baseUrl => _activeBaseUrl;

  /// Default Base URL
  static String get defaultBaseUrl =>
      kIsWeb ? _defaultLocalhostUrl : _defaultAndroidEmulatorUrl;

  /// Inisialisasi konfigurasi dari SharedPreferences
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(_prefKeyBaseUrl);
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      _activeBaseUrl = customUrl.trim();
    }
  }

  /// Mengubah Base URL secara dinamis di runtime (misal jika pakai Physical Device IP)
  static Future<void> setBaseUrl(String newUrl) async {
    final cleaned = newUrl.trim();
    if (cleaned.isEmpty) return;
    _activeBaseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, cleaned);
  }

  /// Reset Base URL ke bawaan
  static Future<void> resetBaseUrl() async {
    _activeBaseUrl = defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyBaseUrl);
  }

  // Radius default geofencing (meter) jika checkpoint tidak mendefinisikan
  static const double defaultGeofenceRadius = 10.0;
}
