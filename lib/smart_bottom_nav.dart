// smart_bottom_nav.dart
import 'package:flutter/material.dart';

/// Shared bottom navigation bar used across screens.
///
/// Maintainability note:
/// - Keep UI-only.
/// - Navigation decisions should remain in the parent widget via onItemTap.
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
        : Colors.black45;
  }

  TextStyle _labelStyle(int index) {
    return TextStyle(
      fontSize: 11,
      fontWeight: selectedIndex == index ? FontWeight.w600 : FontWeight.w400,
      color: _iconColor(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      child: SizedBox(
        height: 68,
        child: Row(
          children: [
            // Home + Settings
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () => onItemTap(0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_outlined, color: _iconColor(0)),
                        const SizedBox(height: 2),
                        Text('Home', style: _labelStyle(0)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => onItemTap(1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings_outlined, color: _iconColor(1)),
                        const SizedBox(height: 2),
                        Text('Settings', style: _labelStyle(1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            //progress
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Progress',
                    style: _labelStyle(2),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Alerts + Tips
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InkWell(
                    onTap: () => onItemTap(3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            color: _iconColor(3)),
                        const SizedBox(height: 2),
                        Text('Alerts', style: _labelStyle(3)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => onItemTap(4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lightbulb_outline, color: _iconColor(4)),
                        const SizedBox(height: 2),
                        Text('Tips', style: _labelStyle(4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
