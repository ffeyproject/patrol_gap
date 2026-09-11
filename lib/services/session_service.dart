import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_service.dart';

/// Service manajemen sesi pengguna dengan penyimpanan token terenkripsi
/// pada level hardware (Android Keystore & iOS Keychain)
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  static const _keyUser = 'logged_in_user';
  static const _keyToken = 'sanctum_auth_token';
  static const _keyActiveSite = 'active_site_id';

  // Konfigurasi enkripsi Hardware Keystore & Keychain
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  AppUser? _currentUser;
  String? _token;

  AppUser? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn =>
      _currentUser != null && _token != null && _token!.isNotEmpty;

  /// Inisialisasi sesi saat aplikasi start
  /// Mendukung Auto-Migration otomatis dari SharedPreferences ke Keystore
  Future<AppUser?> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Coba baca Token dari Secure Storage (Keystore / Keychain)
    try {
      _token = await _secureStorage.read(key: _keyToken);
    } catch (e) {
      debugPrint('🚨 [SECURITY WARNING] Secure Storage read error: $e');
      _token = null;
    }

    // 2. AUTO-MIGRATION: Jika token di Secure Storage belum ada, cek SharedPreferences lama
    if (_token == null || _token!.isEmpty) {
      final legacyToken = prefs.getString(_keyToken);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        debugPrint(
            '🔒 [SECURITY MIGRATION] Memindahkan token plain-text ke Android Keystore / iOS Keychain...');
        _token = legacyToken;
        try {
          await _secureStorage.write(key: _keyToken, value: legacyToken);
          // Hapus token plaintext lama setelah berhasil diamankan
          await prefs.remove(_keyToken);
          debugPrint(
              '✅ [SECURITY MIGRATION] Token berhasil diamankan di Keystore & dihapus dari SharedPreferences.');
        } catch (e) {
          debugPrint('🚨 [SECURITY MIGRATION] Gagal menulis ke Keystore: $e');
        }
      }
    }

    // 3. Set Bearer Token ke ApiService jika tersedia
    if (_token != null && _token!.isNotEmpty) {
      ApiService.instance.setAuthToken(_token);
    }

    // 4. Baca data user profile dari SharedPreferences cache
    final rawUser = prefs.getString(_keyUser);
    if (rawUser != null) {
      try {
        _currentUser = AppUser.fromJson(jsonDecode(rawUser), _token);
        return _currentUser;
      } catch (_) {
        _currentUser = null;
      }
    }

    return null;
  }

  /// Simpan user & token setelah login
  Future<void> saveUser(AppUser user, [String? token]) async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = user;

    final tokenToSave = token ?? user.token;
    if (tokenToSave != null && tokenToSave.isNotEmpty) {
      _token = tokenToSave;
      try {
        // Simpan token ke Hardware Keystore
        await _secureStorage.write(key: _keyToken, value: tokenToSave);
      } catch (e) {
        debugPrint(
            '🚨 [SECURITY WARNING] Gagal menyimpan token ke Keystore: $e');
      }
      ApiService.instance.setAuthToken(tokenToSave);
      // Pastikan token TIDAK tersimpan di plaintext SharedPreferences
      await prefs.remove(_keyToken);
    }

    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
  }

  /// Ambil user yang tersimpan
  Future<AppUser?> getUser() async {
    if (_currentUser != null) return _currentUser;
    return await initialize();
  }

  /// Ambil Token aktif dari Keystore
  Future<String?> getToken() async {
    if (_token != null && _token!.isNotEmpty) return _token;
    try {
      _token = await _secureStorage.read(key: _keyToken);
    } catch (_) {}
    return _token;
  }

  /// Simpan Site ID aktif
  Future<void> setActiveSiteId(int siteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyActiveSite, siteId);
  }

  /// Ambil Site ID aktif (default 1 jika belum ada)
  Future<int> getActiveSiteId() async {
    if (_currentUser?.assignedSiteId != null &&
        _currentUser!.assignedSiteId! > 0) {
      return _currentUser!.assignedSiteId!;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyActiveSite) ?? 1;
  }

  /// Logout: hapus token dari Keystore/Keychain dan bersihkan cache user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.delete(key: _keyToken);
    } catch (e) {
      debugPrint(
          '🚨 [SECURITY WARNING] Gagal menghapus token dari Keystore: $e');
    }
    await prefs.remove(_keyUser);
    await prefs.remove(_keyToken);
    _currentUser = null;
    _token = null;
    ApiService.instance.clearAuthToken();
  }
}
