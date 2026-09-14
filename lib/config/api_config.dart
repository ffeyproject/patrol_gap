import 'package:shared_preferences/shared_preferences.dart';

/// Konfigurasi koneksi ke RESTful API Backend Laravel (Sanctum).
class ApiConfig {
  static const String _defaultProductionUrl =
      'https://patroli.portalgapsoft.xyz/api/v1';

  static const String _prefKeyBaseUrl = 'custom_api_base_url';

  static String _activeBaseUrl = _defaultProductionUrl;

  /// Mendapatkan Base URL saat ini
  static String get baseUrl => _activeBaseUrl;

  /// Default Base URL
  static String get defaultBaseUrl => _defaultProductionUrl;

  /// Normalisasi URL agar memiliki skema protokol dan path /api/v1 yang valid
  static String normalizeUrl(String input) {
    var cleaned = input.trim();
    if (cleaned.isEmpty) return defaultBaseUrl;

    // Tambahkan https:// jika belum memiliki protokol http:// atau https://
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'https://$cleaned';
    }

    // Hapus trailing slash
    cleaned = cleaned.replaceAll(RegExp(r'/+$'), '');

    // Pastikan memiliki path /api/v1 jika belum ada
    if (!cleaned.contains('/api')) {
      cleaned = '$cleaned/api/v1';
    }

    return cleaned;
  }

  /// Inisialisasi konfigurasi dari SharedPreferences
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString(_prefKeyBaseUrl);
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      _activeBaseUrl = normalizeUrl(customUrl);
    } else {
      _activeBaseUrl = defaultBaseUrl;
    }
  }

  /// Mengubah Base URL secara dinamis di runtime (misal jika pakai Physical Device IP)
  static Future<void> setBaseUrl(String newUrl) async {
    final normalized = normalizeUrl(newUrl);
    _activeBaseUrl = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, normalized);
  }

  /// Reset Base URL ke bawaan
  static Future<void> resetBaseUrl() async {
    _activeBaseUrl = defaultBaseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyBaseUrl);
  }

  /// Mengambil origin server tanpa path /api/v1 (misal: "http://192.168.1.10:8000" atau "https://apk.produksionline.xyz")
  static String get serverOrigin {
    try {
      final uri = Uri.parse(_activeBaseUrl);
      if (uri.hasScheme && uri.hasAuthority) {
        return '${uri.scheme}://${uri.authority}';
      }
    } catch (_) {}
    return _activeBaseUrl
        .replaceAll(RegExp(r'/api/v1/?$'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  /// Menormalisasi dan menyelesaikan URL foto / aset dari backend Laravel
  static String resolveImageUrl(String? rawUrl) {
    if (rawUrl == null) return '';
    final url = rawUrl.trim();
    if (url.isEmpty) return '';

    // Jika base64 data URI atau format byte inline
    if (url.startsWith('data:image') || url.startsWith('blob:')) {
      return url;
    }

    // Jika path lokal di device (file path internal)
    if (url.startsWith('/') &&
        (url.contains('/data/user/') ||
            url.contains('/storage/emulated/') ||
            url.contains('/app_flutter/') ||
            url.contains('/cache/'))) {
      return url;
    }

    // Jika sudah berupa URL absolut (http/https)
    if (url.startsWith('http://') || url.startsWith('https://')) {
      try {
        final parsed = Uri.parse(url);
        final host = parsed.host.toLowerCase();
        // Jika URL dari backend menggunakan localhost / 127.0.0.1 tetapi device menggunakan IP server berbeda
        if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
          final serverUri = Uri.parse(serverOrigin);
          final serverHost = serverUri.host.toLowerCase();
          if (serverHost.isNotEmpty && serverHost != host) {
            final replaced = parsed.replace(
              scheme: serverUri.scheme,
              host: serverUri.host,
              port: serverUri.hasPort ? serverUri.port : (serverUri.scheme == 'https' ? 443 : 80),
            );
            return replaced.toString();
          }
        }
      } catch (_) {}
      return url;
    }

    // Jika relative path dari backend Laravel (misal: "patrols/selfies/abc.jpg" atau "/storage/patrols/...")
    final origin = serverOrigin;
    String cleanPath = url.startsWith('/') ? url : '/$url';

    // Jika belum ada prefix /storage/ atau /uploads/
    if (!cleanPath.startsWith('/storage/') &&
        !cleanPath.startsWith('/uploads/') &&
        !cleanPath.startsWith('/assets/')) {
      cleanPath = '/storage$cleanPath';
    }

    return '$origin$cleanPath';
  }

  /// Mengembalikan daftar kemungkinan URL gambar untuk dicoba secara berurutan
  static List<String> getImageCandidates(String? rawUrl) {
    if (rawUrl == null) return [];
    final url = rawUrl.trim();
    if (url.isEmpty) return [];

    // Jika base64 atau path file lokal langsung
    if (url.startsWith('data:image') ||
        url.startsWith('blob:') ||
        (url.startsWith('/') &&
            (url.contains('/data/user/') ||
                url.contains('/storage/emulated/') ||
                url.contains('/app_flutter/') ||
                url.contains('/cache/')))) {
      return [url];
    }

    final List<String> candidates = [];
    final primary = resolveImageUrl(url);
    if (primary.isNotEmpty) candidates.add(primary);

    final origin = serverOrigin;
    String clean = url;

    // Jika URL absolut, ambil bagian path
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        final uri = Uri.parse(clean);
        clean = uri.path;
      } catch (_) {}
    }

    if (!clean.startsWith('/')) clean = '/$clean';

    // Kandidat alternatif 1: $origin/storage/...
    if (!clean.startsWith('/storage/')) {
      final withStorage = '$origin/storage$clean';
      if (!candidates.contains(withStorage)) candidates.add(withStorage);
    }

    // Kandidat alternatif 2: $origin/... (langsung tanpa prefix storage)
    if (clean.startsWith('/storage/')) {
      final withoutStorage = '$origin${clean.replaceFirst('/storage', '')}';
      if (!candidates.contains(withoutStorage)) candidates.add(withoutStorage);
    } else {
      final direct = '$origin$clean';
      if (!candidates.contains(direct)) candidates.add(direct);
    }

    // Kandidat alternatif 3: jika mengandung /public/
    if (clean.contains('/public/')) {
      final viaStorage = '$origin${clean.replaceFirst('/public', '/storage')}';
      if (!candidates.contains(viaStorage)) candidates.add(viaStorage);
    }

    return candidates;
  }

  // Radius default geofencing (meter) jika checkpoint tidak mendefinisikan
  static const double defaultGeofenceRadius = 10.0;
}
