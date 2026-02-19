import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Floating pill-shaped glassmorphic navigation dock.
class FloatingDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int notificationBadge;

  const FloatingDock({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.notificationBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _DockItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Agents',
                  isActive: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                const SizedBox(width: 24),
                _DockItem(
                  icon: Icons.search,
                  label: 'Search',
                  isActive: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                const SizedBox(width: 24),
                _DockItem(
                  icon: Icons.notifications_outlined,
                  label: 'Alerts',
                  isActive: currentIndex == 2,
                  onTap: () => onTap(2),
                  badgeCount: notificationBadge,
                ),
                const SizedBox(width: 24),
                _DockItem(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  isActive: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  _DockItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required VoidCallback onTap,
    this.badgeCount = 0,
  }) : onTap = (() {
        HapticFeedback.lightImpact();
        onTap();
      });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive
                  ? AppColors.textPrimary
                  : const Color(0xFF52525B),
            ),
            // Notification badge
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.background,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      style: GoogleFonts.inter(
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
