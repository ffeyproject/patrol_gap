import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import 'beranda_screen.dart';
import 'patroli_screen.dart';
import 'insiden_screen.dart';
import 'tamu_screen.dart';
import 'profil_screen.dart';

class HomeShell extends StatefulWidget {
  final AppUser user;

  const HomeShell({
    super.key,
    required this.user,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      BerandaScreen(user: widget.user),
      PatroliScreen(user: widget.user),
      InsidenScreen(user: widget.user),
      TamuScreen(user: widget.user),
      ProfilScreen(user: widget.user),
    ];
  }

  void _onTabSelected(int index) {
    if (_index == index) return;
    HapticFeedback.lightImpact();
    setState(() {
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: _ModernCustomBottomNav(
        currentIndex: _index,
        onTap: _onTabSelected,
      ),
    );
  }
}

/// Custom Bottom Navigation Bar yang Megah, Modern, Interaktif, dan Cerah
class _ModernCustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ModernCustomBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0),
            width: 1.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding > 0 ? bottomPadding + 2 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            index: 0,
            currentIndex: currentIndex,
            label: 'Beranda',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            activeColor: const Color(0xFF2563EB),
            onTap: () => onTap(0),
          ),
          _NavItem(
            index: 1,
            currentIndex: currentIndex,
            label: 'Patroli',
            icon: Icons.qr_code_scanner_outlined,
            activeIcon: Icons.qr_code_scanner_rounded,
            activeColor: const Color(0xFF059669),
            onTap: () => onTap(1),
          ),
          _NavItem(
            index: 2,
            currentIndex: currentIndex,
            label: 'Insiden',
            icon: Icons.warning_amber_outlined,
            activeIcon: Icons.warning_amber_rounded,
            activeColor: const Color(0xFFDC2626),
            onTap: () => onTap(2),
          ),
          _NavItem(
            index: 3,
            currentIndex: currentIndex,
            label: 'Tamu',
            icon: Icons.badge_outlined,
            activeIcon: Icons.badge_rounded,
            activeColor: const Color(0xFF7C3AED),
            onTap: () => onTap(3),
          ),
          _NavItem(
            index: 4,
            currentIndex: currentIndex,
            label: 'Profil',
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            activeColor: const Color(0xFF2563EB),
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = index == currentIndex;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active Pill Icon Container with Animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 16 : 8,
                vertical: isSelected ? 5 : 4,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.25)
                      : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? activeColor : const Color(0xFF64748B),
                size: isSelected ? 22 : 21,
              ),
            ),
            const SizedBox(height: 3),

            // Label Text
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : const Color(0xFF64748B),
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: isSelected ? 0.2 : 0.0,
              ),
            ),

            // Active Dot Indicator
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
