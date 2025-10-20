import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Navigation state manager to prevent black screens and manage navigation properly
class NavigationStateManager {
  static final NavigationStateManager _instance = NavigationStateManager._internal();
  factory NavigationStateManager() => _instance;
  NavigationStateManager._internal();

  final List<String> _navigationStack = [];
  bool _isNavigating = false;

  /// Add route to navigation stack
  void addRoute(String routeName) {
    if (!_navigationStack.contains(routeName)) {
      _navigationStack.add(routeName);
    }
  }

  /// Remove route from navigation stack
  void removeRoute(String routeName) {
    _navigationStack.remove(routeName);
  }

  /// Clear navigation stack
  void clearStack() {
    _navigationStack.clear();
  }

  /// Get current route
  String? get currentRoute => _navigationStack.isNotEmpty ? _navigationStack.last : null;

  /// Check if navigating
  bool get isNavigating => _isNavigating;

  /// Set navigating state
  void setNavigating(bool navigating) {
    _isNavigating = navigating;
  }

  /// Get navigation stack
  List<String> get navigationStack => List.unmodifiable(_navigationStack);

  /// Check if we can navigate back
  bool canNavigateBack() {
    return _navigationStack.length > 1;
  }

  /// Get previous route
  String? get previousRoute {
    if (_navigationStack.length > 1) {
      return _navigationStack[_navigationStack.length - 2];
    }
    return null;
  }
}

/// Enhanced PopScope widget with better back button handling
class SafePopScope extends StatelessWidget {
  final Widget child;
  final bool canPop;
  final VoidCallback? onPopInvoked;
  final bool showExitConfirmation;
  final String? routeName;

  const SafePopScope({
    super.key,
    required this.child,
    this.canPop = true,
    this.onPopInvoked,
    this.showExitConfirmation = false,
    this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    // Add route to navigation stack
    if (routeName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NavigationStateManager().addRoute(routeName!);
      });
    }

    return PopScope(
      canPop: canPop,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (onPopInvoked != null) {
            onPopInvoked!();
          } else if (showExitConfirmation) {
            _showExitConfirmation(context);
          } else {
            // Default behavior - try to pop
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              _showExitConfirmation(context);
            }
          }
        }
      },
      child: child,
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1E23),
          title: Text(
            'Exit App',
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to exit the app?',
            style: GoogleFonts.urbanist(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.urbanist(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: Text(
                'Exit',
                style: GoogleFonts.urbanist(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Safe navigation methods
class SafeNavigation {
  /// Safe push with error handling
  static Future<T?> push<T extends Object?>(
      BuildContext context,
      Widget screen, {
        String? routeName,
        bool maintainState = true,
        bool fullscreenDialog = false,
      }) async {
    try {
      NavigationStateManager().setNavigating(true);

      final result = await Navigator.push<T>(
        context,
        MaterialPageRoute<T>(
          builder: (context) => screen,
          maintainState: maintainState,
          fullscreenDialog: fullscreenDialog,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
      );

      return result;
    } catch (e) {
      debugPrint('Navigation error: $e');
      return null;
    } finally {
      NavigationStateManager().setNavigating(false);
    }
  }

  /// Safe push replacement
  static Future<T?> pushReplacement<T extends Object?, TO extends Object?>(
      BuildContext context,
      Widget screen, {
        TO? result,
        String? routeName,
      }) async {
    try {
      NavigationStateManager().setNavigating(true);

      final navigationResult = await Navigator.pushReplacement<T, TO>(
        context,
        MaterialPageRoute<T>(
          builder: (context) => screen,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
        result: result,
      );

      return navigationResult;
    } catch (e) {
      debugPrint('Navigation replacement error: $e');
      return null;
    } finally {
      NavigationStateManager().setNavigating(false);
    }
  }

  /// Safe pop with error handling
  static void pop(BuildContext context, [dynamic result]) {
    try {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, result);
      } else {
        // Show exit confirmation if we can't pop
        _showExitConfirmation(context);
      }
    } catch (e) {
      debugPrint('Pop error: $e');
    }
  }

  /// Push and clear stack
  static Future<T?> pushAndClearStack<T extends Object?>(
      BuildContext context,
      Widget screen, {
        String? routeName,
      }) async {
    try {
      NavigationStateManager().setNavigating(true);
      NavigationStateManager().clearStack();

      final result = await Navigator.pushAndRemoveUntil<T>(
        context,
        MaterialPageRoute<T>(
          builder: (context) => screen,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
            (route) => false,
      );

      return result;
    } catch (e) {
      debugPrint('Push and clear stack error: $e');
      return null;
    } finally {
      NavigationStateManager().setNavigating(false);
    }
  }

  /// Push and clear to first route
  static Future<T?> pushAndClearToFirst<T extends Object?>(
      BuildContext context,
      Widget screen, {
        String? routeName,
      }) async {
    try {
      NavigationStateManager().setNavigating(true);

      final result = await Navigator.pushAndRemoveUntil<T>(
        context,
        MaterialPageRoute<T>(
          builder: (context) => screen,
          settings: routeName != null ? RouteSettings(name: routeName) : null,
        ),
            (route) => route.isFirst,
      );

      return result;
    } catch (e) {
      debugPrint('Push and clear to first error: $e');
      return null;
    } finally {
      NavigationStateManager().setNavigating(false);
    }
  }

  /// Check if we can pop
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  /// Get current route name
  static String? getCurrentRouteName(BuildContext context) {
    return ModalRoute.of(context)?.settings.name;
  }

  /// Show exit confirmation dialog
  static void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1E23),
          title: Text(
            'Exit App',
            style: GoogleFonts.urbanist(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to exit the app?',
            style: GoogleFonts.urbanist(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.urbanist(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop();
              },
              child: Text(
                'Exit',
                style: GoogleFonts.urbanist(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
