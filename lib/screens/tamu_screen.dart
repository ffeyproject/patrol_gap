import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'guest_detail_screen.dart';

class TamuScreen extends StatefulWidget {
  final AppUser user;

  const TamuScreen({
    super.key,
    required this.user,
  });

  @override
  State<TamuScreen> createState() => _TamuScreenState();
}

class _TamuScreenState extends State<TamuScreen> {
  List<GuestModel> _guests = [];
  bool _loading = true;
  String _activeTab = 'active'; // 'active' atau 'history'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    try {
      final res = await ApiService.instance.get('/visitors');
      if (!mounted) return;

      List<GuestModel> guests = [];
      if (res['success'] == true && res['data'] is List) {
        guests = (res['data'] as List)
            .map((e) =>
                GuestModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }

      setState(() {
        _loading = false;
        _guests = guests;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _checkOutById(GuestModel guest) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFD97706), size: 24),
            SizedBox(width: 10),
            Text(
              'Konfirmasi Check-Out',
              style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Text(
          'Konfirmasi kepulangan untuk tamu "${guest.guestName}" dari lokasi?',
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Check-Out Tamu',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res =
          await ApiService.instance.post('/visitors/${guest.id}/checkout');

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF16A34A),
            content: Text('${guest.guestName} berhasil check-out.'),
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(res['message']?.toString() ?? 'Gagal check-out tamu.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Error: $e')),
      );
    }
  }

  void _openNewGuestModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewGuestModalSheet(onSuccess: _loadData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGuests =
        _guests.where((g) => g.checkOutAt == null || g.isActive).toList();
    final historyGuests =
        _guests.where((g) => g.checkOutAt != null && !g.isActive).toList();

    final displayList = _activeTab == 'active' ? activeGuests : historyGuests;

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
              'Buku Tamu Digital',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Registrasi & Pemantauan Pengunjung',
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNewGuestModal,
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'Registrasi Tamu',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.3),
              ),
            ),
      body: RefreshIndicator(
        color: const Color(0xFF7C3AED),
        onRefresh: _loadData,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  // 1. Header Overview Card
                  _buildHeaderOverview(
                    activeCount: activeGuests.length,
                    historyCount: historyGuests.length,
                  ),

                  const SizedBox(height: 16),

                  // 2. Segmented Tabs Filter
                  Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          title: 'Tamu di Area',
                          count: activeGuests.length,
                          isSelected: _activeTab == 'active',
                          selectedColor: const Color(0xFF7C3AED),
                          onTap: () => setState(() => _activeTab = 'active'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TabButton(
                          title: 'Riwayat Selesai',
                          count: historyGuests.length,
                          isSelected: _activeTab == 'history',
                          selectedColor: const Color(0xFF475569),
                          onTap: () => setState(() => _activeTab = 'history'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 3. Section Title
                  Text(
                    _activeTab == 'active'
                        ? 'Daftar Tamu Sedang di Lokasi (${activeGuests.length})'
                        : 'Riwayat Tamu yang Telah Check-Out (${historyGuests.length})',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 4. Guest List
                  if (displayList.isEmpty)
                    _buildEmptyState()
                  else
                    ...displayList.map(
                      (g) => _GuestCardItem(
                        guest: g,
                        active: _activeTab == 'active',
                        onCheckOut: _activeTab == 'active'
                            ? () => _checkOutById(g)
                            : null,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => GuestDetailScreen(guest: g)),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderOverview(
      {required int activeCount, required int historyCount}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
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
              Icons.groups_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.badge_outlined,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SISTEM BUKU TAMU DIGITAL',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Monitoring Akses Pengunjung',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$activeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Tamu Sedang di Area',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$historyCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Total Selesai Check-Out',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
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
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.person_search_rounded,
                color: Color(0xFF94A3B8), size: 52),
            const SizedBox(height: 14),
            Text(
              _activeTab == 'active'
                  ? 'Tidak Ada Tamu di Area'
                  : 'Belum Ada Riwayat Kunjungan',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _activeTab == 'active'
                  ? 'Seluruh tamu telah selesai atau belum ada pengunjung yang check-in.'
                  : 'Daftar tamu yang telah check-out akan tercatat di sini.',
              textAlign: TextAlign.center,
              style: const TextStyle(
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

class _TabButton extends StatelessWidget {
  final String title;
  final int count;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.count,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.25)
                  : const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCardItem extends StatefulWidget {
  final GuestModel guest;
  final bool active;
  final VoidCallback? onCheckOut;
  final VoidCallback onTap;

  const _GuestCardItem({
    required this.guest,
    required this.active,
    required this.onCheckOut,
    required this.onTap,
  });

  @override
  State<_GuestCardItem> createState() => _GuestCardItemState();
}

class _GuestCardItemState extends State<_GuestCardItem> {
  bool _pressed = false;

  String _getInitial(String name) {
    final v = name.trim();
    return v.isEmpty ? 'T' : v.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guest;

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: widget.active
                    ? const Color(0xFFEDE9FE)
                    : const Color(0xFFF1F5F9),
                child: Text(
                  _getInitial(guest.guestName),
                  style: TextStyle(
                    color: widget.active
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Detail Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guest.guestName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tujuan: ${guest.destination}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Keperluan: ${guest.purpose}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (guest.checkinTime.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Masuk: ${guest.checkinTime}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Check-out Action Button
              if (widget.onCheckOut != null)
                ElevatedButton(
                  onPressed: widget.onCheckOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Check-Out',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewGuestModalSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const _NewGuestModalSheet({required this.onSuccess});

  @override
  State<_NewGuestModalSheet> createState() => _NewGuestModalSheetState();
}

class _NewGuestModalSheetState extends State<_NewGuestModalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _idCardCtrl = TextEditingController();

  File? _photo;
  bool _submitting = false;
  String? _error;

  Future<void> _takePhoto() async {
    try {
      final xfile = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 70);
      if (xfile != null && mounted) {
        setState(() => _photo = File(xfile.path));
      }
    } catch (_) {}
  }

  Future<void> _submitGuest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final activeSiteId = await SessionService.instance.getActiveSiteId();

      final res = await ApiService.instance.multipartPost(
        '/visitors',
        fields: {
          'site_id': activeSiteId.toString(),
          'guest_name': _nameCtrl.text.trim(),
          'company': _companyCtrl.text.trim(),
          'destination': _destCtrl.text.trim(),
          'purpose': _purposeCtrl.text.trim(),
          'vehicle_number': _vehicleCtrl.text.trim(),
          'id_card_number': _idCardCtrl.text.trim(),
        },
        files: _photo != null ? {'photo': _photo!} : null,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('Tamu baru berhasil didaftarkan!'),
          ),
        );
      } else {
        setState(() {
          _submitting = false;
          _error = res['message']?.toString() ?? 'Gagal mendaftarkan tamu.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        22,
        22,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded,
                        color: Color(0xFF7C3AED), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Registrasi Tamu Baru',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap Tamu *',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama tamu wajib diisi'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _companyCtrl,
                decoration: InputDecoration(
                  labelText: 'Instansi / Perusahaan',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _destCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tujuan (Lantai/Ruang) *',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Tujuan wajib diisi'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _vehicleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Plat Kendaraan',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _idCardCtrl,
                decoration: InputDecoration(
                  labelText: 'No. KTP / SIM / ID Card',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _purposeCtrl,
                decoration: InputDecoration(
                  labelText: 'Keperluan / Keterangan *',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Keperluan wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              // Foto Tamu Button
              GestureDetector(
                onTap: _takePhoto,
                child: Container(
                  height: 75,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: _photo == null
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                color: Color(0xFF7C3AED)),
                            SizedBox(width: 8),
                            Text(
                              'Ambil Foto Tamu / KTP (Opsional)',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475569)),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            const Text(
                              'Foto Tamu Terlampir',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF16A34A)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _photo = null),
                            ),
                          ],
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        color: Color(0xFFDC2626), fontSize: 12)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submitGuest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Simpan & Terbitkan Akses Tamu',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
