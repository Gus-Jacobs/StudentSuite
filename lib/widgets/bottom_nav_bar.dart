import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.event_note), label: 'Planner'),
        BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Study'),
        BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Career'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
      ],
      type: BottomNavigationBarType.fixed,
    );
  }
}
