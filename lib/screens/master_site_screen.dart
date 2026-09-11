import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class MasterSiteScreen extends StatefulWidget {
  final AppUser user;

  const MasterSiteScreen({
    super.key,
    required this.user,
  });

  @override
  State<MasterSiteScreen> createState() => _MasterSiteScreenState();
}

class _MasterSiteScreenState extends State<MasterSiteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _errorMessage;

  List<SiteModel> _sites = [];
  SiteModel? _selectedSiteForCheckpoints;
  List<CheckpointModel> _currentCheckpoints = [];
  bool _loadingCheckpoints = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadSites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    if (mounted) setState(() => _loading = true);

    try {
      final res = await ApiService.instance.get('/sites');
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List)
            .map((e) => SiteModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (!mounted) return;
        setState(() {
          _sites = list;
          _loading = false;
          _errorMessage = null;
          if (_sites.isNotEmpty && _selectedSiteForCheckpoints == null) {
            _selectedSiteForCheckpoints = _sites.first;
            _loadCheckpointsForSite(_sites.first.id);
          } else if (_selectedSiteForCheckpoints != null) {
            final updated = _sites.firstWhere(
              (s) => s.id == _selectedSiteForCheckpoints!.id,
              orElse: () => _sites.first,
            );
            _selectedSiteForCheckpoints = updated;
            _loadCheckpointsForSite(updated.id);
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = res['message']?.toString() ?? 'Gagal memuat data site.';
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

  Future<void> _loadCheckpointsForSite(int siteId) async {
    setState(() => _loadingCheckpoints = true);
    try {
      final res = await ApiService.instance.get('/sites/$siteId/checkpoints');
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        List<CheckpointModel> cps = [];
        if (data is Map && data['checkpoints'] is List) {
          cps = (data['checkpoints'] as List)
              .map((e) =>
                  CheckpointModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } else if (data is List) {
          cps = data
              .map((e) =>
                  CheckpointModel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }

        if (!mounted) return;
        setState(() {
          _currentCheckpoints = cps;
          _loadingCheckpoints = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingCheckpoints = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCheckpoints = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : const Color(0xFF16A34A),
      ),
    );
  }

  // ============================================================
  // CRUD ACTIONS: SITES
  // ============================================================
  void _openSiteFormDialog([SiteModel? siteToEdit]) {
    final isEdit = siteToEdit != null;
    final nameCtrl = TextEditingController(text: siteToEdit?.name ?? '');
    final codeCtrl = TextEditingController(text: siteToEdit?.code ?? '');
    final addressCtrl = TextEditingController(text: siteToEdit?.address ?? '');
    final latCtrl = TextEditingController(
        text: siteToEdit != null ? siteToEdit.latitude.toString() : '-6.229746');
    final lngCtrl = TextEditingController(
        text: siteToEdit != null ? siteToEdit.longitude.toString() : '106.829518');
    final radiusCtrl = TextEditingController(
        text: siteToEdit != null
            ? siteToEdit.geofenceRadiusMeters.toInt().toString()
            : '50');

    bool isSubmitting = false;
    bool isFetchingGps = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Color(0xFF2563EB),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Edit Data Site / Gedung' : 'Tambah Site / Gedung Baru',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildTextField(
                    controller: nameCtrl,
                    label: 'Nama Site / Gedung *',
                    hint: 'Contoh: Site PT. Gajah Angkasa Perkasa',
                    icon: Icons.business_rounded,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: codeCtrl,
                          label: 'Kode Site *',
                          hint: 'Contoh: SITE-GAP-01',
                          icon: Icons.qr_code_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: radiusCtrl,
                          label: 'Geofence (Meter)',
                          hint: '50',
                          icon: Icons.radar_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: addressCtrl,
                    label: 'Alamat Lokasi',
                    hint: 'Jl. Jend. Sudirman Kav. 21, Jakarta Selatan',
                    icon: Icons.location_on_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // Header GPS dengan tombol Set Lokasi Terkini
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Titik Koordinat GPS Site *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      InkWell(
                        onTap: isFetchingGps
                            ? null
                            : () async {
                                setModalState(() => isFetchingGps = true);
                                try {
                                  final pos = await LocationService.instance.getCurrentPosition();
                                  latCtrl.text = pos.latitude.toStringAsFixed(6);
                                  lngCtrl.text = pos.longitude.toStringAsFixed(6);
                                  _showToast('GPS diperbarui: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}');
                                } catch (e) {
                                  _showToast('Gagal membaca GPS: $e', isError: true);
                                } finally {
                                  setModalState(() => isFetchingGps = false);
                                }
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFetchingGps) ...[
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2563EB)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                const Icon(Icons.my_location_rounded,
                                    size: 14, color: Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isFetchingGps
                                    ? 'Membaca GPS...'
                                    : '📍 Set Lokasi Terkini',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: latCtrl,
                          label: 'Latitude',
                          hint: '-6.229746',
                          icon: Icons.my_location_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: lngCtrl,
                          label: 'Longitude',
                          hint: '106.829518',
                          icon: Icons.pin_drop_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final code = codeCtrl.text.trim();
                              if (name.isEmpty || code.isEmpty) {
                                _showToast('Nama site dan kode site wajib diisi.', isError: true);
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              final body = {
                                'name': name,
                                'code': code,
                                'address': addressCtrl.text.trim(),
                                'latitude': double.tryParse(latCtrl.text) ?? 0.0,
                                'longitude': double.tryParse(lngCtrl.text) ?? 0.0,
                                'geofence_radius_meters':
                                    double.tryParse(radiusCtrl.text) ?? 50.0,
                              };

                              try {
                                final res = isEdit
                                    ? await ApiService.instance
                                        .post('/sites/${siteToEdit.id}', body)
                                    : await ApiService.instance.post('/sites', body);

                                if (!mounted) return;
                                Navigator.of(context).pop();

                                if (res['success'] == true) {
                                  _showToast(res['message']?.toString() ??
                                      (isEdit
                                          ? 'Site berhasil diperbarui'
                                          : 'Site berhasil ditambahkan'));
                                  _loadSites();
                                } else {
                                  _showToast(res['message']?.toString() ??
                                      'Gagal menyimpan data site', isError: true);
                                }
                              } catch (e) {
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                _showToast('Error: $e', isError: true);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan Site' : 'Tambah Site Baru',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteSite(SiteModel site) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 8),
            const Text('Hapus Site?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${site.name}" (${site.code})?\n\nSemua titik checkpoint pada site ini juga akan terhapus.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final res = await ApiService.instance.post('/sites/${site.id}', {
                  '_method': 'DELETE',
                });
                if (!mounted) return;
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Site berhasil dihapus'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                  _loadSites();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'Gagal menghapus site'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CRUD ACTIONS: CHECKPOINTS
  // ============================================================
  void _openCheckpointFormDialog([CheckpointModel? cpToEdit]) {
    final isEdit = cpToEdit != null;
    final siteId = _selectedSiteForCheckpoints?.id ?? (_sites.isNotEmpty ? _sites.first.id : 1);

    final nameCtrl = TextEditingController(text: cpToEdit?.name ?? '');
    final codeCtrl = TextEditingController(
        text: cpToEdit?.code ??
            'CP-${(_currentCheckpoints.length + 1).toString().padLeft(2, '0')}');
    final qrTokenCtrl = TextEditingController(
        text: cpToEdit?.qrToken ??
            'CP-GAP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final descCtrl =
        TextEditingController(text: cpToEdit?.locationDescription ?? '');
    final latCtrl = TextEditingController(
        text: cpToEdit != null
            ? cpToEdit.latitude.toString()
            : (_selectedSiteForCheckpoints?.latitude.toString() ?? '-6.229746'));
    final lngCtrl = TextEditingController(
        text: cpToEdit != null
            ? cpToEdit.longitude.toString()
            : (_selectedSiteForCheckpoints?.longitude.toString() ?? '106.829518'));
    final radiusCtrl = TextEditingController(
        text: cpToEdit != null
            ? cpToEdit.maxRadiusMeters.toInt().toString()
            : '10');
    final orderCtrl = TextEditingController(
        text: cpToEdit != null
            ? cpToEdit.orderIndex.toString()
            : (_currentCheckpoints.length + 1).toString());

    int targetSiteId = siteId;
    bool isSubmitting = false;
    bool isFetchingGps = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF059669),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEdit ? 'Edit Titik Checkpoint' : 'Tambah Checkpoint Baru',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Pilih Site Dropdown jika ada banyak site
                  if (_sites.length > 1) ...[
                    const Text(
                      'Pilih Site / Gedung *',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: targetSiteId,
                          isExpanded: true,
                          items: _sites.map((s) {
                            return DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(
                                '${s.name} (${s.code})',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() => targetSiteId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  _buildTextField(
                    controller: nameCtrl,
                    label: 'Nama Checkpoint / Pos Jaga *',
                    hint: 'Contoh: Pos Jaga Gerbang Utama / Pintu Darurat Lt 3',
                    icon: Icons.pin_drop_rounded,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: codeCtrl,
                          label: 'Kode Titik *',
                          hint: 'CP-01',
                          icon: Icons.tag_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: orderCtrl,
                          label: 'Urutan Rute',
                          hint: '1',
                          icon: Icons.format_list_numbered_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: qrTokenCtrl,
                    label: 'QR Code String / Token *',
                    hint: 'CP-GB-UTAMA-01',
                    icon: Icons.qr_code_2_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: descCtrl,
                    label: 'Petunjuk Lokasi / Deskripsi SOP',
                    hint: 'Contoh: Periksa gembok pagar & panel listrik',
                    icon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // Header GPS Checkpoint dengan tombol Set Lokasi Terkini
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Titik Koordinat GPS Checkpoint *',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      InkWell(
                        onTap: isFetchingGps
                            ? null
                            : () async {
                                setModalState(() => isFetchingGps = true);
                                try {
                                  final pos = await LocationService.instance.getCurrentPosition();
                                  latCtrl.text = pos.latitude.toStringAsFixed(6);
                                  lngCtrl.text = pos.longitude.toStringAsFixed(6);
                                  _showToast('GPS diperbarui: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}');
                                } catch (e) {
                                  _showToast('Gagal membaca GPS: $e', isError: true);
                                } finally {
                                  setModalState(() => isFetchingGps = false);
                                }
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFetchingGps) ...[
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF059669)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ] else ...[
                                const Icon(Icons.my_location_rounded,
                                    size: 14, color: Color(0xFF059669)),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                isFetchingGps
                                    ? 'Membaca GPS...'
                                    : '📍 Set Lokasi Terkini',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: latCtrl,
                          label: 'Latitude',
                          hint: '-6.229746',
                          icon: Icons.my_location_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: lngCtrl,
                          label: 'Longitude',
                          hint: '106.829518',
                          icon: Icons.pin_drop_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: radiusCtrl,
                    label: 'Toleransi Radius Geofence (Meter)',
                    hint: '10',
                    icon: Icons.radar_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              final code = codeCtrl.text.trim();
                              final qrToken = qrTokenCtrl.text.trim();

                              if (name.isEmpty || code.isEmpty || qrToken.isEmpty) {
                                _showToast('Nama, kode, dan QR token wajib diisi.', isError: true);
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              final body = {
                                'site_id': targetSiteId,
                                'name': name,
                                'code': code,
                                'qr_token': qrToken,
                                'location_description': descCtrl.text.trim(),
                                'latitude': double.tryParse(latCtrl.text) ?? 0.0,
                                'longitude': double.tryParse(lngCtrl.text) ?? 0.0,
                                'max_radius_meters':
                                    double.tryParse(radiusCtrl.text) ?? 10.0,
                                'order_index': int.tryParse(orderCtrl.text) ?? 1,
                              };

                              try {
                                final res = isEdit
                                    ? await ApiService.instance
                                        .post('/checkpoints/${cpToEdit.id}', body)
                                    : await ApiService.instance.post('/checkpoints', body);

                                if (!mounted) return;
                                Navigator.of(context).pop();

                                if (res['success'] == true) {
                                  _showToast(res['message']?.toString() ??
                                      (isEdit
                                          ? 'Checkpoint berhasil diperbarui'
                                          : 'Checkpoint berhasil ditambahkan'));
                                  _loadCheckpointsForSite(targetSiteId);
                                  _loadSites();
                                } else {
                                  _showToast(res['message']?.toString() ??
                                      'Gagal menyimpan data checkpoint', isError: true);
                                }
                              } catch (e) {
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                _showToast('Error: $e', isError: true);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan Checkpoint' : 'Tambah Checkpoint Baru',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteCheckpoint(CheckpointModel cp) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded,
                  color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 8),
            const Text('Hapus Checkpoint?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus titik "${cp.name}" (${cp.code})?\n\nKode QR: ${cp.qrToken}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final res = await ApiService.instance.post('/checkpoints/${cp.id}', {
                  '_method': 'DELETE',
                });
                if (!mounted) return;
                if (res['success'] == true) {
                  _showToast(res['message']?.toString() ?? 'Checkpoint berhasil dihapus');
                  if (_selectedSiteForCheckpoints != null) {
                    _loadCheckpointsForSite(_selectedSiteForCheckpoints!.id);
                  }
                  _loadSites();
                } else {
                  _showToast(res['message']?.toString() ?? 'Gagal menghapus checkpoint',
                      isError: true);
                }
              } catch (e) {
                if (!mounted) return;
                _showToast('Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  void _showQrPreviewDialog(CheckpointModel cp) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cp.code,
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 150,
                      color: Color(0xFF0F172A),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cp.qrToken,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                cp.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (cp.locationDescription != null &&
                  cp.locationDescription!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  cp.locationDescription!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: cp.qrToken));
                    Navigator.pop(dialogCtx);
                    _showToast('QR Token berhasil disalin ke clipboard!');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Salin QR Token Barcode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.normal,
            ),
            prefixIcon: Icon(icon, size: 19, color: const Color(0xFF2563EB)),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2.0),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Master Site & Checkpoint',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: _loadSites,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.apartment_rounded, size: 20),
              text: 'Daftar Site (${_sites.length})',
            ),
            const Tab(
              icon: Icon(Icons.qr_code_scanner_rounded, size: 20),
              text: 'Titik Checkpoint & QR',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF475569), fontSize: 14)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadSites,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSitesTab(),
                    _buildCheckpointsTab(),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _openSiteFormDialog();
          } else {
            _openCheckpointFormDialog();
          }
        },
        backgroundColor: _tabController.index == 0
            ? const Color(0xFF2563EB)
            : const Color(0xFF059669),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _tabController.index == 0 ? 'Tambah Site' : 'Tambah Checkpoint',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ),
    );
  }

  // ============================================================
  // TAB 1: SITES LIST
  // ============================================================
  Widget _buildSitesTab() {
    if (_sites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Belum ada data Site / Gedung',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tekan tombol Tambah Site untuk membuat lokasi baru.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: _sites.length,
      itemBuilder: (ctx, index) {
        final site = _sites[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header Card
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            site.code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: site.isActive
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        site.isActive ? 'AKTIF' : 'NONAKTIF',
                        style: TextStyle(
                          color: site.isActive
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB91C1C),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (site.address != null && site.address!.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              site.address!,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // GPS & Radius Geofence Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildInfoBadge(
                          icon: Icons.radar_rounded,
                          label: 'Radius: ${site.geofenceRadiusMeters.toInt()}m',
                          color: const Color(0xFF059669),
                          bgColor: const Color(0xFFECFDF5),
                        ),
                        _buildInfoBadge(
                          icon: Icons.qr_code_scanner_rounded,
                          label:
                              '${site.checkpointsCount} Titik Checkpoint',
                          color: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFFFAF5FF),
                        ),
                        _buildInfoBadge(
                          icon: Icons.my_location_rounded,
                          label:
                              '${site.latitude.toStringAsFixed(4)}, ${site.longitude.toStringAsFixed(4)}',
                          color: const Color(0xFF475569),
                          bgColor: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedSiteForCheckpoints = site;
                              _tabController.animateTo(1);
                              _loadCheckpointsForSite(site.id);
                            });
                          },
                          icon: const Icon(Icons.visibility_outlined,
                              size: 16, color: Color(0xFF2563EB)),
                          label: const Text(
                            'Lihat Titik QR',
                            style: TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFBFDBFE)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _openSiteFormDialog(site),
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: Color(0xFF475569)),
                          tooltip: 'Edit Site',
                        ),
                        IconButton(
                          onPressed: () => _confirmDeleteSite(site),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Color(0xFFDC2626)),
                          tooltip: 'Hapus Site',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // TAB 2: CHECKPOINTS LIST
  // ============================================================
  Widget _buildCheckpointsTab() {
    return Column(
      children: [
        // Site Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              const Icon(Icons.domain_rounded,
                  size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              const Text(
                'Pilih Site:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedSiteForCheckpoints?.id,
                      isExpanded: true,
                      hint: const Text('Pilih Site...'),
                      items: _sites.map((s) {
                        return DropdownMenuItem<int>(
                          value: s.id,
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newSiteId) {
                        if (newSiteId != null) {
                          final selected = _sites.firstWhere(
                            (s) => s.id == newSiteId,
                            orElse: () => _sites.first,
                          );
                          setState(() {
                            _selectedSiteForCheckpoints = selected;
                          });
                          _loadCheckpointsForSite(selected.id);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Checkpoints Content List
        Expanded(
          child: _loadingCheckpoints
              ? const Center(
                  child:
                      CircularProgressIndicator(color: Color(0xFF059669)),
                )
              : _currentCheckpoints.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_2_rounded,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum ada titik checkpoint di site ini',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tekan tombol Tambah Checkpoint di bawah untuk membuat titik QR.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                      itemCount: _currentCheckpoints.length,
                      itemBuilder: (ctx, index) {
                        final cp = _currentCheckpoints[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A)
                                    .withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // QR Code Button Preview
                              InkWell(
                                onTap: () => _showQrPreviewDialog(cp),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 36,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info Checkpoint
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669)
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '#${cp.orderIndex} • ${cp.code}',
                                            style: const TextStyle(
                                              color: Color(0xFF059669),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Radius: ${cp.maxRadiusMeters.toInt()}m',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      cp.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (cp.locationDescription != null &&
                                        cp.locationDescription!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        cp.locationDescription!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      'GPS: ${cp.latitude.toStringAsFixed(4)}, ${cp.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10.5,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quick Action Edit / Delete
                              Column(
                                children: [
                                  IconButton(
                                    onPressed: () =>
                                        _openCheckpointFormDialog(cp),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18, color: Color(0xFF64748B)),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Edit Titik',
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _confirmDeleteCheckpoint(cp),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFDC2626)),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Hapus Titik',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
