import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../services/api_service.dart';

class LiveRadarScreen extends StatefulWidget {
  final AppUser user;

  const LiveRadarScreen({
    super.key,
    required this.user,
  });

  @override
  State<LiveRadarScreen> createState() => _LiveRadarScreenState();
}

class _LiveRadarScreenState extends State<LiveRadarScreen> {
  final MapController _mapController = MapController();
  Timer? _pollingTimer;

  bool _loading = true;
  bool _autoSync = true;

  int _totalGuardsPresent = 0;
  int _totalInPatrol = 0;
  List<LiveGuardModel> _guards = [];
  LiveGuardModel? _selectedGuard;

  // Default Center (Jakarta / Site)
  LatLng _mapCenter = const LatLng(-6.229746, 106.829518);
  static const double _mapZoom = 15.5;

  @override
  void initState() {
    super.initState();
    _loadLiveGuards();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_autoSync && mounted) {
        _loadLiveGuards(isBackground: true);
      }
    });
  }

  Future<void> _loadLiveGuards({bool isBackground = false}) async {
    if (!isBackground && mounted) {
      setState(() => _loading = true);
    }

    try {
      final res = await ApiService.instance.get('/live/guards');
      if (res['success'] == true && res['data'] is Map) {
        final data = res['data'] as Map<String, dynamic>;
        final totalPresent = int.tryParse(data['total_guards_present']?.toString() ?? '0') ?? 0;
        final totalPatrol = int.tryParse(data['total_in_patrol']?.toString() ?? '0') ?? 0;

        List<LiveGuardModel> guardList = [];
        if (data['active_guards'] is List) {
          guardList = (data['active_guards'] as List)
              .map((e) => LiveGuardModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }

        if (!mounted) return;
        setState(() {
          _totalGuardsPresent = totalPresent;
          _totalInPatrol = totalPatrol;
          _guards = guardList;
          _loading = false;

          // Update map center jika ada petugas aktif
          if (_guards.isNotEmpty && _selectedGuard == null) {
            final firstValid = _guards.firstWhere(
              (g) => g.latitude != 0.0 && g.longitude != 0.0,
              orElse: () => _guards.first,
            );
            if (firstValid.latitude != 0.0 && firstValid.longitude != 0.0) {
              _mapCenter = LatLng(firstValid.latitude, firstValid.longitude);
            }
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _focusGuard(LiveGuardModel guard) {
    setState(() {
      _selectedGuard = guard;
    });

    if (guard.latitude != 0.0 && guard.longitude != 0.0) {
      final target = LatLng(guard.latitude, guard.longitude);
      _mapController.move(target, 17.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int standbyCount = (_totalGuardsPresent - _totalInPatrol).clamp(0, 999);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Radar Live Satpam',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            Text(
              'Pemantauan GPS & Posisi Petugas Real-Time',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => _loadLiveGuards(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Radar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. MAP VIEW
          _buildMapView(),

          // 2. TOP METRICS FLOATING BAR
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: _buildMetricsHeader(standbyCount),
          ),

          // 3. BOTTOM GUARD DRAWER / SHEET
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomGuardList(),
          ),

          // 4. LOADING SPINNER OVERLAY
          if (_loading)
            Positioned(
              top: 90,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Memperbarui Radar...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // MAP VIEW WITH LIVE MARKERS
  // ============================================================
  Widget _buildMapView() {
    final markers = <Marker>[];

    for (final guard in _guards) {
      if (guard.latitude == 0.0 && guard.longitude == 0.0) continue;

      final isSelected = _selectedGuard?.id == guard.id;
      final isPatrol = guard.isInPatrol;

      markers.add(
        Marker(
          point: LatLng(guard.latitude, guard.longitude),
          width: isSelected ? 80 : 64,
          height: isSelected ? 80 : 64,
          child: GestureDetector(
            onTap: () => _focusGuard(guard),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPatrol ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    guard.name.split(' ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow ring pulsing
                    Container(
                      width: isSelected ? 42 : 36,
                      height: isSelected ? 42 : 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isPatrol
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6))
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPatrol ? const Color(0xFF059669) : const Color(0xFF2563EB),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        isPatrol ? Icons.radar_rounded : Icons.shield_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: _mapZoom,
        minZoom: 4,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gap.patroli_security_app',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  // ============================================================
  // TOP FLOATING METRICS HEADER
  // ============================================================
  Widget _buildMetricsHeader(int standbyCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            label: 'Total Hadir',
            value: '$_totalGuardsPresent',
            color: const Color(0xFF0F172A),
            icon: Icons.people_alt_rounded,
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          _buildMetricItem(
            label: 'Patroli Aktif',
            value: '$_totalInPatrol',
            color: const Color(0xFF059669),
            icon: Icons.radar_rounded,
            isPulsing: _totalInPatrol > 0,
          ),
          Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
          _buildMetricItem(
            label: 'Standby Pos',
            value: '$standbyCount',
            color: const Color(0xFF2563EB),
            icon: Icons.shield_moon_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool isPulsing = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.1,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM LIST & GUARD CARDS
  // ============================================================
  Widget _buildBottomGuardList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle & live sync switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'DAFTAR SATPAM BERTUGAS',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    'Auto-Sync (10s)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: _autoSync,
                      activeTrackColor: const Color(0xFF2563EB),
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        setState(() => _autoSync = val);
                        if (val) _startPolling();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Guards Horizontal / Vertical List
          if (_guards.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada petugas yang check-in shift hari ini.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _guards.length,
                itemBuilder: (ctx, index) {
                  final guard = _guards[index];
                  final isSelected = _selectedGuard?.id == guard.id;
                  final isPatrol = guard.isInPatrol;

                  return GestureDetector(
                    onTap: () => _focusGuard(guard),
                    child: Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isPatrol
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF2563EB),
                                child: Text(
                                  guard.name.isNotEmpty
                                      ? guard.name.substring(0, 1).toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      guard.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '${guard.role} • ${guard.badgeNumber}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPatrol
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPatrol ? 'PATROLI' : 'STANDBY',
                                  style: TextStyle(
                                    color: isPatrol
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF1D4ED8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.qr_code_scanner_rounded,
                                  size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  guard.lastCheckpointName != null
                                      ? 'Titik: ${guard.lastCheckpointName}'
                                      : 'Status: ${guard.status}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (guard.lastScannedAt != null) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Scan: ${guard.lastScannedAt}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
