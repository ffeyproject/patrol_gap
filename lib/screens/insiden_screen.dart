import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'incident_detail_screen.dart';
import 'report_incident_screen.dart';

class InsidenScreen extends StatefulWidget {
  final AppUser user;

  const InsidenScreen({
    super.key,
    required this.user,
  });

  @override
  State<InsidenScreen> createState() => _InsidenScreenState();
}

class _InsidenScreenState extends State<InsidenScreen> {
  List<IncidentModel> _incidents = [];
  bool _loading = true;
  String _selectedFilter = 'all'; // 'all', 'high', 'medium', 'low'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    try {
      final res = await ApiService.instance.get('/incidents');
      if (!mounted) return;

      List<IncidentModel> incidents = [];
      if (res['success'] == true && res['data'] is List) {
        incidents = (res['data'] as List)
            .map((e) =>
                IncidentModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      setState(() {
        _loading = false;
        _incidents = incidents;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _reportIncident() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ReportIncidentScreen(user: widget.user)),
    );

    if (result == true && mounted) {
      _loadData();
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'danger':
      case 'critical':
        return const Color(0xFFEF4444);
      case 'medium':
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'low':
      default:
        return const Color(0xFF2563EB);
    }
  }

  String _severityLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'danger':
      case 'critical':
        return 'BAHAYA TINGGI';
      case 'medium':
      case 'warning':
        return 'SEDANG';
      case 'low':
      default:
        return 'RINGAN';
    }
  }

  List<IncidentModel> get _filteredIncidents {
    if (_selectedFilter == 'all') return _incidents;
    return _incidents.where((i) {
      final sev = i.severity.toLowerCase();
      if (_selectedFilter == 'high') {
        return sev == 'high' || sev == 'danger' || sev == 'critical';
      }
      if (_selectedFilter == 'medium') {
        return sev == 'medium' || sev == 'warning';
      }
      if (_selectedFilter == 'low') {
        return sev == 'low';
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final int countHigh = _incidents.where((i) {
      final s = i.severity.toLowerCase();
      return s == 'high' || s == 'danger' || s == 'critical';
    }).length;
    final int countMedium = _incidents.where((i) {
      final s = i.severity.toLowerCase();
      return s == 'medium' || s == 'warning';
    }).length;
    final int countLow =
        _incidents.where((i) => i.severity.toLowerCase() == 'low').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Laporan Insiden',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Monitoring Kejadian & Temuan Lapangan',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _reportIncident,
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text(
                'Lapor Insiden Baru',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
              ),
            ),
      body: RefreshIndicator(
        color: const Color(0xFFDC2626),
        onRefresh: _loadData,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFDC2626)))
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  // 1. Header Banner Megah
                  _buildHeaderBanner(),

                  const SizedBox(height: 16),

                  // 2. Metrics Counter Pills
                  Row(
                    children: [
                      Expanded(
                        child: _MetricBadge(
                          label: 'Bahaya Tinggi',
                          count: countHigh,
                          color: const Color(0xFFEF4444),
                          bgColor: const Color(0xFFFEF2F2),
                          isSelected: _selectedFilter == 'high',
                          onTap: () => setState(() => _selectedFilter =
                              _selectedFilter == 'high' ? 'all' : 'high'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricBadge(
                          label: 'Sedang',
                          count: countMedium,
                          color: const Color(0xFFF59E0B),
                          bgColor: const Color(0xFFFFFBEB),
                          isSelected: _selectedFilter == 'medium',
                          onTap: () => setState(() => _selectedFilter =
                              _selectedFilter == 'medium' ? 'all' : 'medium'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricBadge(
                          label: 'Ringan',
                          count: countLow,
                          color: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          isSelected: _selectedFilter == 'low',
                          onTap: () => setState(() => _selectedFilter =
                              _selectedFilter == 'low' ? 'all' : 'low'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Section Title with Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Daftar Laporan Temuan (${_filteredIncidents.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (_selectedFilter != 'all')
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedFilter = 'all'),
                          child: const Text('Reset Filter',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 4. List Cards
                  if (_filteredIncidents.isEmpty)
                    _buildEmptyState()
                  else
                    ..._filteredIncidents.map(
                      (inc) => _IncidentCard(
                        incident: inc,
                        color: _severityColor(inc.severity),
                        severityLabel: _severityLabel(inc.severity),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IncidentDetailScreen(
                                incident: inc,
                                color: _severityColor(inc.severity),
                                severity: _severityLabel(inc.severity),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF991B1B), Color(0xFFDC2626), Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            top: -15,
            child: Icon(
              Icons.shield_outlined,
              size: 110,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'RESPONSE & LOGGING DARURAT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_incidents.length} Laporan Tercatat',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Laporkan segera temuan kerusakan atau potensi ancaman keamanan.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.verified_user_rounded,
                color: Color(0xFF22C55E), size: 52),
            SizedBox(height: 14),
            Text(
              'Semua Area Terpantau Aman',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Tidak ada laporan insiden darurat yang terdaftar pada kategori ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _MetricBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? color.withValues(alpha: 0.25)
                  : const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentCard extends StatefulWidget {
  final IncidentModel incident;
  final Color color;
  final String severityLabel;
  final VoidCallback onTap;

  const _IncidentCard({
    required this.incident,
    required this.color,
    required this.severityLabel,
    required this.onTap,
  });

  @override
  State<_IncidentCard> createState() => _IncidentCardState();
}

class _IncidentCardState extends State<_IncidentCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final inc = widget.incident;
    final isResolved = inc.isResolved;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Severity Badge & Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.severityLabel,
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isResolved ? 'TERTANGANI' : 'MENUNGGU TINDAKAN',
                      style: TextStyle(
                        color: isResolved
                            ? const Color(0xFF15803D)
                            : const Color(0xFFB45309),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Title
              Text(
                inc.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 6),

              // Description
              Text(
                inc.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 12),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              const SizedBox(height: 10),

              // Footer: Location & Time
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      inc.locationDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    inc.timeDisplay,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
