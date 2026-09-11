import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Response wrapper standar RESTful API Patroli
class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final int statusCode;
  final Map<String, dynamic> raw;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    required this.statusCode,
    required this.raw,
  });

  bool get isOk => success && statusCode >= 200 && statusCode < 300;
}

/// Service pusat untuk komunikasi RESTful API Backend Laravel (Sanctum)
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();
  String? _authToken;

  /// Set Sanctum Bearer token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Hapus token
  void clearAuthToken() {
    _authToken = null;
  }

  /// Cek apakah token tersedia
  bool get hasToken => _authToken != null && _authToken!.isNotEmpty;

  Map<String, String> _buildHeaders({bool isJson = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    String base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    String path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    String fullUrl = '$base$path';

    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      )..removeWhere((k, v) => v.isEmpty);

      return Uri.parse(fullUrl).replace(queryParameters: stringParams);
    }

    return Uri.parse(fullUrl);
  }

  /// GET Request
  Future<Map<String, dynamic>> get(
    String endpoint, [
    Map<String, dynamic>? queryParams,
  ]) async {
    final uri = _buildUri(endpoint, queryParams);
    try {
      final res = await _client.get(
        uri,
        headers: _buildHeaders(isJson: false),
      );
      return _parseResponse(res);
    } catch (e) {
      debugPrint('ApiService GET Error ($endpoint): $e');
      return {
        'success': false,
        'message': 'Gagal terhubung ke server: ${_cleanError(e)}',
        'status_code': 0,
      };
    }
  }

  /// POST Request (JSON)
  Future<Map<String, dynamic>> post(
    String endpoint, [
    dynamic body,
  ]) async {
    final uri = _buildUri(endpoint);
    try {
      final jsonBody = body != null ? jsonEncode(body) : null;
      final res = await _client.post(
        uri,
        headers: _buildHeaders(isJson: true),
        body: jsonBody,
      );
      return _parseResponse(res);
    } catch (e) {
      debugPrint('ApiService POST Error ($endpoint): $e');
      return {
        'success': false,
        'message': 'Gagal mengirim data ke server: ${_cleanError(e)}',
        'status_code': 0,
      };
    }
  }

  /// PUT Request (JSON)
  Future<Map<String, dynamic>> put(
    String endpoint, [
    dynamic body,
  ]) async {
    final uri = _buildUri(endpoint);
    try {
      final jsonBody = body != null ? jsonEncode(body) : null;
      final res = await _client.put(
        uri,
        headers: _buildHeaders(isJson: true),
        body: jsonBody,
      );
      return _parseResponse(res);
    } catch (e) {
      debugPrint('ApiService PUT Error ($endpoint): $e');
      return {
        'success': false,
        'message': 'Gagal memperbarui data: ${_cleanError(e)}',
        'status_code': 0,
      };
    }
  }

  /// DELETE Request
  Future<Map<String, dynamic>> delete(
    String endpoint, [
    dynamic body,
  ]) async {
    final uri = _buildUri(endpoint);
    try {
      final jsonBody = body != null ? jsonEncode(body) : null;
      final res = await _client.delete(
        uri,
        headers: _buildHeaders(isJson: true),
        body: jsonBody,
      );
      return _parseResponse(res);
    } catch (e) {
      debugPrint('ApiService DELETE Error ($endpoint): $e');
      return {
        'success': false,
        'message': 'Gagal menghapus data: ${_cleanError(e)}',
        'status_code': 0,
      };
    }
  }

  /// POST Multipart Request (Upload foto / form-data)
  Future<Map<String, dynamic>> multipartPost(
    String endpoint, {
    Map<String, String>? fields,
    Map<String, File>? files,
  }) async {
    final uri = _buildUri(endpoint);
    try {
      final request = http.MultipartRequest('POST', uri);

      // Headers
      final baseHeaders = _buildHeaders(isJson: false);
      request.headers.addAll(baseHeaders);

      // Fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Files
      if (files != null) {
        for (final entry in files.entries) {
          final file = entry.value;
          if (await file.exists()) {
            final multipartFile = await http.MultipartFile.fromPath(
              entry.key,
              file.path,
            );
            request.files.add(multipartFile);
          }
        }
      }

      final streamedResponse = await _client.send(request);
      final res = await http.Response.fromStream(streamedResponse);
      return _parseResponse(res);
    } catch (e) {
      debugPrint('ApiService Multipart Error ($endpoint): $e');
      return {
        'success': false,
        'message': 'Gagal mengunggah data/foto: ${_cleanError(e)}',
        'status_code': 0,
      };
    }
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        // Normalisasi properti success
        final bool isSuccess = decoded['success'] == true ||
            (statusCode >= 200 && statusCode < 300 && decoded['success'] != false);

        String message = decoded['message']?.toString() ??
            (isSuccess ? 'Operasi berhasil' : 'Terjadi kesalahan pada server');

        // Ekstraksi pesan validasi Laravel jika ada (errors: {field: [msg]})
        if (!isSuccess && decoded['errors'] is Map) {
          final errors = decoded['errors'] as Map;
          if (errors.isNotEmpty) {
            final firstVal = errors.values.first;
            if (firstVal is List && firstVal.isNotEmpty) {
              message = firstVal.first.toString();
            } else if (firstVal != null) {
              message = firstVal.toString();
            }
          }
        }

        return {
          ...decoded,
          'success': isSuccess,
          'status_code': statusCode,
          'message': message,
        };
      } else if (decoded is List) {
        return {
          'success': statusCode >= 200 && statusCode < 300,
          'status_code': statusCode,
          'data': decoded,
          'message': 'Data berhasil dimuat',
        };
      }
    } catch (_) {
      // Body bukan JSON valid (misal HTML error 500)
    }

    final bool isSuccess = statusCode >= 200 && statusCode < 300;
    return {
      'success': isSuccess,
      'status_code': statusCode,
      'message': isSuccess
          ? 'Operasi berhasil.'
          : (statusCode == 401
              ? 'Sesi login telah berakhir. Silakan login kembali.'
              : 'Server merespons status code $statusCode'),
    };
  }

  String _cleanError(dynamic e) {
    return e.toString().replaceFirst('Exception: ', '').trim();
  }
}
