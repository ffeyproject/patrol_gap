import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class IncidentDetailScreen extends StatelessWidget {
  final IncidentModel incident;
  final Color color;
  final String severity;

  const IncidentDetailScreen({
    super.key,
    required this.incident,
    required this.color,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final reporter = incident.reporterName ?? (incident.userId != null ? 'User #${incident.userId}' : '-');

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Detail Insiden'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildPhoto(),
          const SizedBox(height: 18),
          _buildHeader(),
          const SizedBox(height: 18),
          _buildInfoRow(
            icon: Icons.event_outlined,
            label: 'Waktu Kejadian',
            value: incident.createdAt != null && incident.createdAt!.isNotEmpty
                ? incident.createdAt!
                : '-',
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Dilaporkan Oleh',
            value: reporter,
          ),
          const SizedBox(height: 18),
          _buildDescription(),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    final photo = incident.photoUrl;
    if (photo == null || photo.trim().isEmpty) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary, size: 32),
            SizedBox(height: 8),
            Text('Tidak ada lampiran foto', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Image.network(
          photo,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: AppColors.surface,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: AppColors.surface,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 32),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            incident.title.isEmpty ? '(Tanpa judul)' : incident.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            severity,
            style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deskripsi Lengkap',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            incident.description.isEmpty ? 'Tidak ada deskripsi.' : incident.description,
            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
