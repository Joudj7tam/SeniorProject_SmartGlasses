import 'package:flutter/material.dart';

class SmartBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTap;

  const SmartBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
  });

  Color _iconColor(BuildContext context, int index) {
    return selectedIndex == index
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
  }

  TextStyle _labelStyle(BuildContext context, int index) {
    final selected = selectedIndex == index;
    return TextStyle(
      fontSize: 12,
      height: 1,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
      color: _iconColor(context, index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
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
                    context: context,
                    index: 0,
                    icon: Icons.home_outlined,
                    label: 'Home',
                  ),
                  _navItem(
                    context: context,
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
                  style: _labelStyle(context, 2),
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
                    context: context,
                    index: 3,
                    icon: Icons.notifications_none_rounded,
                    label: 'Alerts',
                  ),
                  _navItem(
                    context: context,
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
    required BuildContext context,
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
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: _iconColor(context, index),
              size: selected ? 28 : 25,
            ),
            const SizedBox(height: 4),
            Text(label, style: _labelStyle(context, index)),
          ],
        ),
      ),
    );
  }
}
