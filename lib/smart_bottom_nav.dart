import 'package:flutter/material.dart';
import 'app_theme.dart';

class SmartBottomNav extends StatelessWidget {
  final int selectedIndex;

  final VoidCallback onHomeTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onProgressTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onTipsTap;

  const SmartBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onHomeTap,
    required this.onSettingsTap,
    required this.onProgressTap,
    required this.onAlertsTap,
    required this.onTipsTap,
  });

  Color _iconColor(int index, bool isDark) {
    return selectedIndex == index
        ? const Color(0xFF2EC4B6)
        : (isDark ? kDarkMuted : const Color(0xFF8A8580));
  }

  TextStyle _labelStyle(int index, bool isDark) {
    final selected = selectedIndex == index;
    return TextStyle(
      fontSize: 12,
      height: 1,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      color: _iconColor(index, isDark),
    );
  }

  void _handleTap(int index) {
    switch (index) {
      case 0:
        onHomeTap();
        break;
      case 1:
        onSettingsTap();
        break;
      case 2:
        onProgressTap();
        break;
      case 3:
        onAlertsTap();
        break;
      case 4:
        onTipsTap();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? const Color(0xFF0F2035) : Colors.white.withOpacity(0.96);

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 7,
      elevation: 0,
      color: navBg,
      child: SizedBox(
        height: 78,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(index: 0, icon: Icons.home_outlined, label: 'Home', isDark: isDark),
                  _navItem(index: 1, icon: Icons.settings_outlined, label: 'Settings', isDark: isDark),
                ],
              ),
            ),

            Expanded(
              flex: 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _handleTap(2),
                child: Padding(
                  padding: const EdgeInsets.only(top: 45),
                  child: Text(
                    'Progress',
                    style: _labelStyle(2, isDark),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(index: 3, icon: Icons.notifications_none_rounded, label: 'Alerts', isDark: isDark),
                  _navItem(index: 4, icon: Icons.lightbulb_outline_rounded, label: 'Tips', isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final selected = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _handleTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isDark
                  ? kDarkAccentSoft
                  : const Color(0xFFCBF3F0).withOpacity(0.45))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _iconColor(index, isDark), size: selected ? 28 : 25),
            const SizedBox(height: 4),
            Text(label, style: _labelStyle(index, isDark)),
          ],
        ),
      ),
    );
  }
}

class SmartProgressFab extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onTap;

  const SmartProgressFab({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Transform.translate(
      offset: const Offset(0, 12),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0D2A38), Color(0xFF1A3D50)]
                : const [Color(0xFFE9FFFC), Color(0xFFBFF3EE)],
          ),
          border: Border.all(
            color: isDark ? kDarkBorder : Colors.white,
            width: 6,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2EC4B6).withOpacity(isDark ? 0.18 : 0.28),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Icon(
                Icons.trending_up_rounded,
                color: selectedIndex == 2
                    ? const Color(0xFF2EC4B6)
                    : (isDark ? kDarkMuted : const Color(0xFF7C746E)),
                size: 34,
              ),
            ),
          ),
        ),
      ),
    );
  }
}