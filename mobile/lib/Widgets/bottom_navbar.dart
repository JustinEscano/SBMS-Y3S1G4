import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      'defaultIcon': 'assets/icons/Home Default.png',
      'hoveredIcon': 'assets/icons/Home Hovered.png',
    },
    {
      'value': 'analytics',
      'label': 'Usage',
      'defaultIcon': 'assets/icons/Usage Default.png',
      'hoveredIcon': 'assets/icons/Usage Hovered.png',
    },
    {
      'value': 'maintenance_requests',
      'label': 'Requests',
      'defaultIcon': 'assets/icons/Report Default.png',
      'hoveredIcon': 'assets/icons/Report Hovered.png',
    },
    {
      'value': 'orb_chat',
      'label': 'ORB Chat',
      'defaultIcon': 'assets/icons/Orb Default.png',
      'hoveredIcon': 'assets/icons/Orb Hovered.png',
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
      selectedItemColor: const Color(0xFF184BFB), // Vibrant blue for selected label
      unselectedItemColor: Colors.white70, // White70 for unselected label
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
      items: _navItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isSelected = _selectedIndex == index;
        return BottomNavigationBarItem(
          icon: IconTheme(
            data: const IconThemeData(color: null), // Prevent color overlay
            child: Icon(
              size: 24, // Adjust icon size
              Icons.image, // Placeholder icon, actual image provided by Image.asset
              color: Colors.transparent, // Ensure no tint
            ),
          ).animate(
            key: ValueKey('${item['value']}_$isSelected'),
            onPlay: (controller) => controller.forward(),
          ).scale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            begin: isSelected ? const Offset(1.0, 1.0) : const Offset(0.8, 0.8),
            end: isSelected ? const Offset(1.2, 1.2) : const Offset(1.0, 1.0),
          ).fade(
            duration: const Duration(milliseconds: 200),
            begin: isSelected ? 0.8 : 1.0,
            end: isSelected ? 1.0 : 0.8,
          ).custom(
            builder: (context, child, animation) {
              return Image.asset(
                isSelected ? item['hoveredIcon'] : item['defaultIcon'],
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              );
            },
          ),
          label: item['label'],
        );
      }).toList(),
    );
  }
}