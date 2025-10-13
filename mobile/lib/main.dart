import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Screens/LoginScreen.dart';
import 'Providers/chat_provider.dart';
import 'providers/dashboard_provider.dart';
import 'Services/auth_service.dart';
import 'Services/api_service.dart';
import 'repositories/dashboard_repository.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ApiService>(
          create: (context) => ApiService(Provider.of<AuthService>(context, listen: false)),
        ),
        Provider<DashboardRepository>(
          create: (context) => DashboardRepository(
            Provider.of<ApiService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            Provider.of<AuthService>(context, listen: false),
            Provider.of<ApiService>(context, listen: false),
            Provider.of<DashboardRepository>(context, listen: false),
          ),
        ),
      ],
      child: const SmartBuildingApp(),
    ),
  );
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
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        // '/dashboard' route removed; handled via MaterialPageRoute in LoginScreen
      },
    );
  }
}