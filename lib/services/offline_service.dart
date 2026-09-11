import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api_service.dart';

/// Menyimpan hasil scan patroli secara lokal ketika area minim sinyal, lalu
/// otomatis mengunggahnya saat koneksi internet kembali ada.
class OfflineService {
  OfflineService._();
  static final OfflineService instance = OfflineService._();

  static const _webQueueKey = 'pending_scans_web_queue';

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'patroli_offline.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_scans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<bool> hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Simpan 1 aksi (mis. patrolScan) ke antrian lokal
  Future<void> enqueue(String action, Map<String, dynamic> payload) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_webQueueKey) ?? <String>[];
      queue.add(jsonEncode({
        'action': action,
        'payload': payload,
        'created_at': DateTime.now().toIso8601String(),
      }));
      await prefs.setStringList(_webQueueKey, queue);
      return;
    }

    final db = await _getDb();
    await db.insert('pending_scans', {
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> pendingCount() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_webQueueKey) ?? <String>[]).length;
    }

    final db = await _getDb();
    final rows = await db.query('pending_scans');
    return rows.length;
  }

  Future<bool> _sendItem(String action, Map<String, dynamic> payload) async {
    try {
      if (action == 'patrolScan' || action == '/patrol/scan') {
        final photoPath = payload['photo_path']?.toString();
        File? photoFile;
        if (photoPath != null && photoPath.isNotEmpty) {
          photoFile = File(photoPath);
        }

        final res = await ApiService.instance.multipartPost(
          '/patrol/scan',
          fields: {
            'patrol_session_id': payload['patrol_session_id']?.toString() ?? '1',
            'qr_token': payload['qr_token']?.toString() ?? '',
            'latitude': payload['latitude']?.toString() ?? payload['scan_lat']?.toString() ?? '0',
            'longitude': payload['longitude']?.toString() ?? payload['scan_long']?.toString() ?? '0',
            'condition_status': payload['condition_status']?.toString() ?? 'normal',
            'notes': payload['notes']?.toString() ?? '',
          },
          files: photoFile != null && await photoFile.exists() ? {'selfie_photo': photoFile} : null,
        );
        return res['success'] == true;
      } else {
        final endpoint = action.startsWith('/') ? action : '/$action';
        final res = await ApiService.instance.post(endpoint, payload);
        return res['success'] == true;
      }
    } catch (_) {
      return false;
    }
  }

  /// Coba kirim semua data yang tertunda ke server. Baris yang berhasil
  /// dikirim akan dihapus dari antrian lokal.
  Future<int> syncAll() async {
    if (!await hasConnection()) return 0;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_webQueueKey) ?? <String>[];
      if (queue.isEmpty) return 0;

      final remaining = <String>[];
      int success = 0;
      for (final raw in queue) {
        final row = jsonDecode(raw) as Map<String, dynamic>;
        final action = row['action'] as String;
        final payload = Map<String, dynamic>.from(row['payload'] as Map);
        final ok = await _sendItem(action, payload);
        if (ok) {
          success++;
        } else {
          remaining.add(raw);
        }
      }
      await prefs.setStringList(_webQueueKey, remaining);
      return success;
    }

    final db = await _getDb();
    final rows = await db.query('pending_scans', orderBy: 'id ASC');
    int success = 0;

    for (final row in rows) {
      final action = row['action'] as String;
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      final ok = await _sendItem(action, payload);
      if (ok) {
        await db.delete('pending_scans', where: 'id = ?', whereArgs: [row['id']]);
        success++;
      }
    }
    return success;
  }
}
