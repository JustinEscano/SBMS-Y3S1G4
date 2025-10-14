import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Screens/LoginScreen.dart';
import 'Screens/DashboardScreen.dart';
import 'Providers/chat_provider.dart';
import 'providers/dashboard_provider.dart';
import 'Services/auth_service.dart';
import 'Services/api_service.dart';
import 'repositories/dashboard_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure async operations work
  final authService = AuthService();
  final apiService = ApiService(authService);
  bool isAuthenticated = await authService.loadStoredTokens() && await authService.verifyToken();
  if (!isAuthenticated) {
    isAuthenticated = await authService.refresh();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<ApiService>.value(value: apiService),
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
      child: SmartBuildingApp(isAuthenticated: isAuthenticated),
    ),
  );
}

class SmartBuildingApp extends StatelessWidget {
  final bool isAuthenticated;

  const SmartBuildingApp({super.key, required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Building Management',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: isAuthenticated ? '/dashboard' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => DashboardScreen(
          accessToken: Provider.of<AuthService>(context, listen: false).accessToken!,
        ),
      },
    );
  }
}