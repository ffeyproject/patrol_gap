import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class CheckpointRecapScreen extends StatefulWidget {
  final AppUser user;

  const CheckpointRecapScreen({
    super.key,
    required this.user,
  });

  @override
  State<CheckpointRecapScreen> createState() => _CheckpointRecapScreenState();
}

class _CheckpointRecapScreenState extends State<CheckpointRecapScreen> {
  bool _loading = true;
  String? _errorMessage;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  int? _selectedSiteId;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'scanned', 'unscanned', 'incident'

  List<SiteModel> _sites = [];
  CheckpointRecapSummary? _summary;
  List<CheckpointRecapItem> _checkpoints = [];

  final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadSites();
    _loadRecapData();
  }

  Future<void> _loadSites() async {
    try {
      final res = await ApiService.instance.get('/sites');
      if (res['success'] == true && res['data'] is List) {
        if (!mounted) return;
        setState(() {
          _sites = (res['data'] as List)
              .map((e) => SiteModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRecapData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final queryParams = <String, String>{
        'start_date': _apiDateFormat.format(_startDate),
        'end_date': _apiDateFormat.format(_endDate),
      };

      if (_selectedSiteId != null && _selectedSiteId! > 0) {
        queryParams['site_id'] = _selectedSiteId.toString();
      }

      final queryString = Uri(queryParameters: queryParams).query;
      final res = await ApiService.instance.get('/patrol/recap/checkpoints?$queryString');

      if (res['success'] == true && res['data'] is Map) {
        final data = res['data'] as Map<String, dynamic>;

        // Parse Summary
        CheckpointRecapSummary? summary;
        if (data['summary'] is Map) {
          summary = CheckpointRecapSummary.fromJson(Map<String, dynamic>.from(data['summary'] as Map));
        }

        // Parse Checkpoints
        List<CheckpointRecapItem> items = [];
        final rawList = data['checkpoints'] ?? data['data'] ?? data['items'];
        if (rawList is List) {
          items = rawList
              .map((e) => CheckpointRecapItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }

        if (!mounted) return;
        setState(() {
          _summary = summary;
          _checkpoints = items;
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = res['message']?.toString() ?? 'Gagal memuat rekap patroli checkpoint.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Terjadi kesalahan koneksi: $e';
      });
    }
  }

  Future<void> _showDateFilterModal() async {
    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSingleDay = tempStart.year == tempEnd.year &&
                tempStart.month == tempEnd.month &&
                tempStart.day == tempEnd.day;

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final yesterday = today.subtract(const Duration(days: 1));
            final sevenDaysAgo = today.subtract(const Duration(days: 6));
            final firstDayOfMonth = DateTime(now.year, now.month, 1);

            bool isPresetToday = tempStart.year == today.year &&
                tempStart.month == today.month &&
                tempStart.day == today.day &&
                tempEnd.year == today.year &&
                tempEnd.month == today.month &&
                tempEnd.day == today.day;

            bool isPresetYesterday = tempStart.year == yesterday.year &&
                tempStart.month == yesterday.month &&
                tempStart.day == yesterday.day &&
                tempEnd.year == yesterday.year &&
                tempEnd.month == yesterday.month &&
                tempEnd.day == yesterday.day;

            bool isPreset7Days = tempStart.year == sevenDaysAgo.year &&
                tempStart.month == sevenDaysAgo.month &&
                tempStart.day == sevenDaysAgo.day &&
                tempEnd.year == today.year &&
                tempEnd.month == today.month &&
                tempEnd.day == today.day;

            bool isPresetThisMonth = tempStart.year == firstDayOfMonth.year &&
                tempStart.month == firstDayOfMonth.month &&
                tempStart.day == firstDayOfMonth.day &&
                tempEnd.year == today.year &&
                tempEnd.month == today.month &&
                tempEnd.day == today.day;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              color: Color(0xFF2563EB), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'Pilih Periode Tanggal',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick presets
                  const Text(
                    'Pilihan Cepat:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip(
                        label: 'Hari Ini',
                        isSelected: isPresetToday,
                        onTap: () {
                          setModalState(() {
                            tempStart = today;
                            tempEnd = today;
                          });
                        },
                      ),
                      _buildPresetChip(
                        label: 'Kemarin',
                        isSelected: isPresetYesterday,
                        onTap: () {
                          setModalState(() {
                            tempStart = yesterday;
                            tempEnd = yesterday;
                          });
                        },
                      ),
                      _buildPresetChip(
                        label: '7 Hari Terakhir',
                        isSelected: isPreset7Days,
                        onTap: () {
                          setModalState(() {
                            tempStart = sevenDaysAgo;
                            tempEnd = today;
                          });
                        },
                      ),
                      _buildPresetChip(
                        label: 'Bulan Ini',
                        isSelected: isPresetThisMonth,
                        onTap: () {
                          setModalState(() {
                            tempStart = firstDayOfMonth;
                            tempEnd = today;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Custom Start & End Date Pickers
                  const Text(
                    'Rentang Tanggal Kustom:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Dari Tanggal
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempStart,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 30)),
                              helpText: 'PILIH DARI TANGGAL',
                              confirmText: 'PILIH',
                              cancelText: 'BATAL',
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempStart = picked;
                                if (tempEnd.isBefore(tempStart)) {
                                  tempEnd = tempStart;
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dari Tanggal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.event,
                                        size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _displayDateFormat.format(tempStart),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 10),
                      // Sampai Tanggal
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempEnd.isBefore(tempStart)
                                  ? tempStart
                                  : tempEnd,
                              firstDate: tempStart,
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 30)),
                              helpText: 'PILIH SAMPAI TANGGAL',
                              confirmText: 'PILIH',
                              cancelText: 'BATAL',
                            );
                            if (picked != null) {
                              setModalState(() {
                                tempEnd = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sampai Tanggal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.event_available,
                                        size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _displayDateFormat.format(tempEnd),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // SUBMIT / TERAPKAN BUTTON
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _startDate = tempStart;
                        _endDate = tempEnd;
                      });
                      _loadRecapData();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isSingleDay
                              ? 'Terapkan Filter (${_displayDateFormat.format(tempStart)})'
                              : 'Terapkan Filter (${_displayDateFormat.format(tempStart)} - ${_displayDateFormat.format(tempEnd)})',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  List<CheckpointRecapItem> get _filteredCheckpoints {
    return _checkpoints.where((item) {
      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = item.name.toLowerCase().contains(q);
        final matchQr = item.qrCode.toLowerCase().contains(q);
        final matchSite = (item.siteName ?? '').toLowerCase().contains(q);
        final matchLoc = (item.floorOrLocation ?? '').toLowerCase().contains(q);
        final matchGuard = (item.lastScannedBy ?? '').toLowerCase().contains(q);
        if (!matchName && !matchQr && !matchSite && !matchLoc && !matchGuard) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter == 'scanned' && !item.isScanned) return false;
      if (_statusFilter == 'unscanned' && item.isScanned) return false;
      if (_statusFilter == 'incident') {
        final hasIncident = item.recentLogs.any((l) =>
            l.condition.toLowerCase().contains('rusak') ||
            l.condition.toLowerCase().contains('bahaya') ||
            l.condition.toLowerCase().contains('kendala') ||
            (l.notes != null && l.notes!.isNotEmpty));
        if (!hasIncident) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCheckpoints;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rekap Laporan Checkpoint',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              'Monitoring Kepatuhan Titik & Validasi Scan',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: _loadRecapData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecapData,
        color: const Color(0xFF2563EB),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. FILTER HEADER BAR
            SliverToBoxAdapter(
              child: _buildFilterSection(),
            ),

            // 2. SUMMARY METRICS CARDS
            if (_summary != null)
              SliverToBoxAdapter(
                child: _buildSummaryMetrics(_summary!),
              ),

            // 3. SEARCH & STATUS CHIPS
            SliverToBoxAdapter(
              child: _buildSearchAndStatusFilters(),
            ),

            // 4. CHECKPOINT ITEMS LIST
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF2563EB)),
                      SizedBox(height: 14),
                      Text(
                        'Memuat rekap laporan checkpoint...',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13.5, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadRecapData,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded,
                              size: 48, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Tidak Ada Data Rekap Checkpoint',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ditemukan checkpoint dengan kata kunci "$_searchQuery".'
                              : 'Tidak ada aktivitas scan checkpoint pada rentang tanggal terpilih.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filtered[index];
                      return _CheckpointRecapCard(
                        item: item,
                        onTap: () => _showDetailBottomSheet(item),
                      );
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTER SECTION (DATE RANGE + SITE PICKER)
  // ============================================================
  Widget _buildFilterSection() {
    final isSameDay = _startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day;

    final dateLabel = isSameDay
        ? _displayDateFormat.format(_startDate)
        : '${_displayDateFormat.format(_startDate)} - ${_displayDateFormat.format(_endDate)}';

    return Container(
      color: const Color(0xFF1E3A8A),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              // Date Range Button
              Expanded(
                flex: 6,
                child: GestureDetector(
                  onTap: _showDateFilterModal,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dateLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down_rounded,
                            color: Colors.white70),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Site Filter Dropdown
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _selectedSiteId,
                      dropdownColor: const Color(0xFF1E3A8A),
                      isExpanded: true,
                      icon: const Icon(Icons.domain_rounded,
                          size: 18, color: Colors.white),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'Semua Site',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        ..._sites.map((site) {
                          return DropdownMenuItem<int?>(
                            value: site.id,
                            child: Text(
                              site.name,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedSiteId = val);
                        _loadRecapData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY METRICS DASHBOARD
  // ============================================================
  Widget _buildSummaryMetrics(CheckpointRecapSummary summary) {
    final comp = summary.compliancePercentage;
    final compColor = comp >= 90
        ? const Color(0xFF059669)
        : (comp >= 60 ? const Color(0xFFD97706) : const Color(0xFFDC2626));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics_rounded,
                      size: 18, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Kepatuhan Rute Patroli',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: compColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: compColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${comp.toStringAsFixed(1)}% Kepatuhan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: compColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar kepatuhan
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (comp / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(compColor),
            ),
          ),
          const SizedBox(height: 16),
          // 4 Grid Stats
          Row(
            children: [
              _buildStatCard(
                title: 'Total Titik',
                value: summary.totalCheckpoints.toString(),
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'Tervalidasi',
                value: summary.totalScannedPoints.toString(),
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'Total Scan',
                value: summary.totalScans.toString(),
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF5F3FF),
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                title: 'Temuan',
                value: summary.totalIncidentsReported.toString(),
                icon: Icons.warning_amber_rounded,
                color: summary.totalIncidentsReported > 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B),
                bgColor: summary.totalIncidentsReported > 0
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF8FAFC),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH & STATUS CHIPS
  // ============================================================
  Widget _buildSearchAndStatusFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Cari nama checkpoint, QR code, atau petugas...',
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF64748B), size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF64748B)),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua Titik', 'all', Icons.list_alt_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Tervalidasi Scan', 'scanned',
                    Icons.check_circle_outline_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Belum Discan', 'unscanned',
                    Icons.radio_button_unchecked_rounded),
                const SizedBox(width: 8),
                _buildFilterChip('Ada Catatan / Kendala', 'incident',
                    Icons.report_problem_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _statusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL BOTTOM SHEET WITH LOGS & SELFIE WATERMARK PREVIEWS
  // ============================================================
  void _showDetailBottomSheet(CheckpointRecapItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Checkpoint Detail
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: item.isScanned
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isScanned
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFFECACA),
                            ),
                          ),
                          child: Icon(
                            item.isScanned
                                ? Icons.verified_rounded
                                : Icons.highlight_off_rounded,
                            color: item.isScanned
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'QR: ${item.qrCode}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  if (item.siteName != null) ...[
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '• ${item.siteName}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (item.floorOrLocation != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.place_rounded,
                                        size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item.floorOrLocation!,
                                        style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // Riwayat Log Scan Titik Ini
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Riwayat Pindaian (${item.recentLogs.length} Log)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Target: ${item.actualScans}/${item.targetScans}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: item.recentLogs.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_rounded,
                                      size: 40, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Belum Ada Riwayat Scan Pada Periode Ini',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF475569)),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Titik ini belum dipindai oleh satpam pada tanggal yang dipilih.',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF94A3B8)),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: item.recentLogs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final log = item.recentLogs[idx];
                              return _LogHistoryCard(
                                log: log,
                                onPreviewPhoto: (url) =>
                                    _showPhotoDialog(url, log),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPhotoDialog(String photoUrl, CheckpointRecapLogItem log) {
    showAppImagePreviewDialog(
      context,
      imageUrl: photoUrl,
      title: log.userName,
      subtitle: '${log.scannedAt} • Kondisi: ${log.condition}',
    );
  }
}

// ============================================================
// CHECKPOINT RECAP ITEM CARD
// ============================================================
class _CheckpointRecapCard extends StatelessWidget {
  final CheckpointRecapItem item;
  final VoidCallback onTap;

  const _CheckpointRecapCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isScanned = item.isScanned;
    final statusColor = isScanned
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isScanned
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFFECACA),
          width: isScanned ? 1 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Name & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isScanned
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isScanned
                            ? Icons.qr_code_scanner_rounded
                            : Icons.hourglass_empty_rounded,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'QR: ${item.qrCode} ${item.siteName != null ? '• ${item.siteName}' : ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        isScanned ? 'TERVALIDASI' : 'BELUM SCAN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Bottom Scan Details
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Terakhir Oleh:',
                            style: TextStyle(
                                fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.lastScannedBy ?? 'Belum ada pindaian',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item.lastScannedBy != null
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (item.lastScannedAt != null) ...[
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Waktu Scan:',
                            style: TextStyle(
                                fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.lastScannedAt!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: Color(0xFFCBD5E1)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOG HISTORY CARD IN BOTTOM SHEET
// ============================================================
class _LogHistoryCard extends StatelessWidget {
  final CheckpointRecapLogItem log;
  final Function(String url) onPreviewPhoto;

  const _LogHistoryCard({
    required this.log,
    required this.onPreviewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        log.selfiePhotoUrl != null && log.selfiePhotoUrl!.isNotEmpty;
    final isGood = log.condition.toLowerCase().contains('aman') ||
        log.condition.toLowerCase().contains('baik') ||
        log.condition.toLowerCase().contains('normal');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selfie Photo Thumbnail or Avatar
          if (hasPhoto)
            GestureDetector(
              onTap: () => onPreviewPhoto(log.selfiePhotoUrl!),
              child: Stack(
                children: [
                  SafeImageView(
                    imageUrl: log.selfiePhotoUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    borderRadius: 10,
                    fallbackIcon: Icons.image_not_supported_rounded,
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.zoom_in_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Color(0xFF2563EB), size: 22),
            ),

          const SizedBox(width: 12),

          // Log Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        log.userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isGood
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        log.condition,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isGood
                              ? const Color(0xFF059669)
                              : const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      log.scannedAt,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    if (log.distanceMeters != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• Radius: ${log.distanceMeters!.toStringAsFixed(1)}m',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ],
                ),
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Catatan: "${log.notes}"',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
