import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class NavigationHelper {
  /// Safe navigation method that prevents black screens
  static Future<T?> pushScreen<T extends Object?>(
      BuildContext context,
      Widget screen, {
        bool maintainState = true,
        bool fullscreenDialog = false,
      }) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute<T>(
        builder: (context) => screen,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Safe replacement navigation method
  static Future<T?> pushReplacementScreen<T extends Object?, TO extends Object?>(
      BuildContext context,
      Widget screen, {
        TO? result,
      }) {
    return Navigator.pushReplacement<T, TO>(
      context,
      MaterialPageRoute<T>(
        builder: (context) => screen,
      ),
      result: result,
    );
  }

  /// Safe pop method with error handling
  static void popScreen(BuildContext context, [dynamic result]) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, result);
    } else {
      // If we can't pop, show exit confirmation
      _showExitConfirmation(context);
    }
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
                // Exit the app
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

  /// Create a PopScope wrapper for screens that need back button handling
  static Widget wrapWithPopScope({
    required Widget child,
    bool canPop = true,
    VoidCallback? onPopInvoked,
    bool showExitConfirmation = false,
  }) {
    return PopScope(
      canPop: canPop,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (onPopInvoked != null) {
            onPopInvoked();
          } else if (showExitConfirmation) {
            // This would need context, so it's better to handle in the screen itself
          }
        }
      },
      child: child,
    );
  }

  /// Clear navigation stack and go to a specific screen
  static Future<T?> pushAndClearStack<T extends Object?>(
      BuildContext context,
      Widget screen,
      ) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute<T>(
        builder: (context) => screen,
      ),
          (route) => false,
    );
  }

  /// Navigate to a screen and clear all previous routes except the first one
  static Future<T?> pushAndClearToFirst<T extends Object?>(
      BuildContext context,
      Widget screen,
      ) {
    return Navigator.pushAndRemoveUntil<T>(
      context,
      MaterialPageRoute<T>(
        builder: (context) => screen,
      ),
          (route) => route.isFirst,
    );
  }

  /// Check if navigation stack is empty
  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  /// Get current route name
  static String? getCurrentRouteName(BuildContext context) {
    return ModalRoute.of(context)?.settings.name;
  }

  /// Safe navigation with loading state
  static Future<T?> pushScreenWithLoading<T extends Object?>(
      BuildContext context,
      Widget screen, {
        String? loadingMessage,
      }) {
    // Show loading indicator
    if (loadingMessage != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1F1E23),
          content: Row(
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4D6BFE)),
              ),
              const SizedBox(width: 16),
              Text(
                loadingMessage,
                style: GoogleFonts.urbanist(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return pushScreen<T>(context, screen).then((result) {
      // Hide loading indicator
      if (loadingMessage != null && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return result;
    });
  }
}