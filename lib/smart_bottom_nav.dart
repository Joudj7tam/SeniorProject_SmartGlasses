import 'package:flutter/material.dart';

class SmartBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  const SmartBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
  });

  Color _iconColor(int index) {
    return selectedIndex == index
        ? const Color(0xFF2EC4B6)
        : const Color(0xFF8A8580);
  }

  TextStyle _labelStyle(int index) {
    final selected = selectedIndex == index;
    return TextStyle(
      fontSize: 12,
      height: 1,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      color: _iconColor(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 0,
      color: Colors.white.withOpacity(0.96),
      child: SizedBox(
        height: 78,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    label: 'Home',
                  ),
                  _navItem(
                    index: 1,
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                  ),
                ],
              ),
            ),

            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 45),
                child: Text(
                  'Progress',
                  style: _labelStyle(2),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _navItem(
                    index: 3,
                    icon: Icons.notifications_none_rounded,
                    label: 'Alerts',
                  ),
                  _navItem(
                    index: 4,
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Tips',
                  ),
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
  }) {
    final selected = selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onItemTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFCBF3F0).withOpacity(0.45)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: _iconColor(index),
              size: selected ? 28 : 25,
            ),
            const SizedBox(height: 4),
            Text(label, style: _labelStyle(index)),
          ],
        ),
      ),
    );
  }
}