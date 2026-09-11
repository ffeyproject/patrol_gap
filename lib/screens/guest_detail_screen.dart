import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class GuestDetailScreen extends StatelessWidget {
  final GuestModel guest;

  const GuestDetailScreen({
    super.key,
    required this.guest,
  });

  @override
  Widget build(BuildContext context) {
    final active = !guest.isCheckedOut;
    final qrCode = guest.qrGuestCode;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Detail Tamu'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildHeader(active),
          const SizedBox(height: 20),
          _buildInfoCard(active),
          const SizedBox(height: 20),
          if (qrCode != null && qrCode.trim().isNotEmpty) _buildQrCard(qrCode),
        ],
      ),
    );
  }

  Widget _buildHeader(bool active) {
    return Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent.withValues(alpha: 0.10)
                : AppColors.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            active ? Icons.person_pin_rounded : Icons.person_outline_rounded,
            color: active ? AppColors.accent : AppColors.success,
            size: 28,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guest.guestName.isEmpty ? '(Tanpa nama)' : guest.guestName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              StatusPillDetail(active: active),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(bool active) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row(Icons.badge_outlined, 'No. Identitas', guest.identityNo),
          if (guest.company != null && guest.company!.isNotEmpty) ...[
            const Divider(height: 20),
            _row(Icons.corporate_fare_rounded, 'Instansi / Perusahaan', guest.company!),
          ],
          if (guest.vehicleNumber != null && guest.vehicleNumber!.isNotEmpty) ...[
            const Divider(height: 20),
            _row(Icons.directions_car_rounded, 'Plat Nomor Kendaraan', guest.vehicleNumber!),
          ],
          const Divider(height: 20),
          _row(Icons.business_outlined, 'Tujuan', guest.destination),
          const Divider(height: 20),
          _row(Icons.assignment_outlined, 'Keperluan', guest.purpose),
          const Divider(height: 20),
          _row(
            Icons.login_rounded,
            'Check-In',
            guest.checkinTime.isEmpty ? '-' : guest.checkinTime,
            valueColor: AppColors.success,
          ),
          const Divider(height: 20),
          _row(
            Icons.logout_rounded,
            'Check-Out',
            guest.checkoutTime.isEmpty ? 'Belum check-out' : guest.checkoutTime,
            valueColor: guest.checkoutTime.isEmpty ? AppColors.textSecondary : AppColors.danger,
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCard(String qrCode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'QR BADGE TAMU',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          QrImageView(
            data: qrCode,
            version: QrVersions.auto,
            size: 190,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            qrCode,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPillDetail extends StatelessWidget {
  final bool active;

  const StatusPillDetail({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Di Dalam Area' : 'Sudah Check-Out',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
