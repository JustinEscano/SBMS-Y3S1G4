import 'package:flutter/material.dart';
import 'Screens/LoginScreen.dart';

void main() {
  runApp(const SmartBuildingApp());
}

class SmartBuildingApp extends StatelessWidget {
  const SmartBuildingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Building Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}