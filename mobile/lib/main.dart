import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Screens/LoginScreen.dart';
import 'Providers/chat_provider.dart'; // Add this import

void main() {
  runApp(const SmartBuildingApp());
}

class SmartBuildingApp extends StatelessWidget {
  const SmartBuildingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        // Add other providers here as needed
      ],
      child: MaterialApp(
        title: 'Smart Building Management',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}