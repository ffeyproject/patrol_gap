import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReportIncidentScreen extends StatefulWidget {
  final AppUser user;

  const ReportIncidentScreen({
    super.key,
    required this.user,
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _severity = 'medium'; // 'low', 'medium', 'high'
  File? _photo;
  bool _submitting = false;
  String? _error;

  final List<Map<String, String>> _severities = [
    {'value': 'low', 'label': 'Rendah (Low)', 'desc': 'Temuan ringan tidak darurat'},
    {'value': 'medium', 'label': 'Sedang (Medium)', 'desc': 'Perlu penanganan berkala'},
    {'value': 'high', 'label': 'Tinggi / Darurat (High)', 'desc': 'Butuh penanganan segera'},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final XFile? xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (xfile == null || !mounted) return;

      setState(() {
        _photo = File(xfile.path);
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Tidak dapat mengakses kamera.');
    }
  }

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final activeSiteId = await SessionService.instance.getActiveSiteId();

      final res = await ApiService.instance.multipartPost(
        '/incidents',
        fields: {
          'site_id': activeSiteId.toString(),
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'severity': _severity,
        },
        files: _photo != null ? {'photo': _photo!} : null,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Laporan insiden berhasil dikirim ke server!'),
          ),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _submitting = false;
          _error = res['message']?.toString() ?? 'Gagal mengirim laporan insiden.';
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Buat Laporan Insiden'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.danger, Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.report_problem_rounded, color: Colors.white, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Formulir Insiden Lapangan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('Laporan akan langsung terkirim ke Danru & Posko Pusat.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Judul Insiden
            const Text('Judul / Jenis Temuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'Misal: Pintu Darurat Terganjal Kardus',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul insiden wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            // Tingkat Keparahan (Severity)
            const Text('Tingkat Urgensi (Severity)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Column(
              children: _severities.map((item) {
                final isSelected = _severity == item['value'];
                Color activeColor = AppColors.primary;
                if (item['value'] == 'medium') activeColor = Colors.orange;
                if (item['value'] == 'high') activeColor = AppColors.danger;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _severity = item['value']!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withValues(alpha: 0.10) : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? activeColor : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? activeColor : AppColors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['label']!,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: isSelected ? activeColor : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(item['desc']!, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Deskripsi Detail
            const Text('Rincian Deskripsi Kejadian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Jelaskan kronologi, lokasi spesifik, dan kondisi di tempat...',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Deskripsi temuan wajib diisi' : null,
            ),
            const SizedBox(height: 18),
            // Foto Bukti
            const Text('Foto Bukti Kejadian (Opsional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _takePhoto,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _photo != null ? AppColors.success : AppColors.border),
                ),
                child: _photo == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 32),
                          SizedBox(height: 8),
                          Text('Ambil Foto Bukti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 2),
                          Text('Ketuk untuk membuka kamera', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.file(_photo!, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              onPressed: () => setState(() => _photo = null),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: LoadingButton(
                loading: _submitting,
                label: 'Kirim Laporan Insiden',
                onPressed: _submitIncident,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
