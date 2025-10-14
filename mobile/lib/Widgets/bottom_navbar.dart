import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BottomNavBar extends StatefulWidget {
  final Function(String) onMenuSelection;
  final String currentScreen;

  const BottomNavBar({
    super.key,
    required this.onMenuSelection,
    this.currentScreen = 'dashboard',
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  late int _selectedIndex;

  final List<Map<String, dynamic>> _navItems = [
    {
      'value': 'dashboard',
      'label': 'Home',
      'icon': Icons.dashboard,
    },
    {
      'value': 'analytics',
      'label': 'Usage',
      'icon': Icons.analytics,
    },
    {
      'value': 'maintenance_requests',
      'label': 'Requests',
      'icon': Icons.build,
    },
    {
      'value': 'orb_chat',
      'label': 'ORB Chat',
      'icon': Icons.chat,
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateSelectedIndex();
  }

  @override
  void didUpdateWidget(BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentScreen != widget.currentScreen) {
      _updateSelectedIndex();
    }
  }

  void _updateSelectedIndex() {
    _selectedIndex = _navItems.indexWhere((item) => item['value'] == widget.currentScreen);
    if (_selectedIndex == -1) _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF1F1E23), // Dark gray background
      currentIndex: _selectedIndex,
      onTap: (index) {
        if (_selectedIndex != index) {
          setState(() {
            _selectedIndex = index;
          });
          widget.onMenuSelection(_navItems[index]['value']);
        }
      },
      selectedItemColor: const Color(0xFF184BFB), // Vibrant blue for selected icon and label
      unselectedItemColor: Colors.white70, // White70 for unselected icon and label
      selectedFontSize: 12,
      unselectedFontSize: 12,
      selectedLabelStyle: GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w600, // Slightly bolder for selected
      ),
      unselectedLabelStyle: GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      items: _navItems.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon']),
          label: item['label'],
        );
      }).toList(),
    );
  }
}