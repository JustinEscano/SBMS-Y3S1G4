import 'package:flutter/material.dart';

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
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _navItems = [
    {
      'value': 'dashboard',
      'label': 'Dashboard',
      'icon': Icons.dashboard,
    },
    {
      'value': 'analytics',
      'label': 'Analytics',
      'icon': Icons.analytics,
    },
    {
      'value': 'maintenance_requests',
      'label': 'Maintenance Requests',
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
    _selectedIndex = _navItems.indexWhere((item) => item['value'] == widget.currentScreen);
    if (_selectedIndex == -1) _selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
        widget.onMenuSelection(_navItems[index]['value']);
      },
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      items: _navItems.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon']),
          label: item['label'],
        );
      }).toList(),
    );
  }
}