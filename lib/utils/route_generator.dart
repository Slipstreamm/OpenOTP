import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/add_otp_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/lan_sync_screen.dart';
import '../screens/custom_theme_screen.dart';
import '../screens/export_screen.dart';
import '../screens/import_screen.dart';
import '../services/logger_service.dart';
import 'page_transitions.dart';

/// Class to handle all app routes and transitions
class RouteGenerator {
  static const String home = '/';
  static const String addOtp = '/add-otp';
  static const String settings = '/settings';
  static const String qrScanner = '/qr-scanner';
  static const String lanSync = '/lan_sync';
  static const String customTheme = '/custom-theme';
  static const String export = '/export';
  static const String import = '/import';

  static final LoggerService _logger = LoggerService();

  /// The current transition type to use for all routes
  static PageTransitionType _transitionType = PageTransitionType.rightToLeft;

  /// Set the transition type to be used for all routes
  static void setTransitionType(PageTransitionType type) {
    _logger.i('Setting app-wide transition type to: $type');
    _transitionType = type;
  }

  /// Get the current transition type
  static PageTransitionType get transitionType => _transitionType;

  /// Generate routes with the appropriate transitions
  static Route<dynamic> generateRoute(RouteSettings settings) {
    _logger.d('Generating route for: ${settings.name}');

    // Get arguments passed to the route
    final args = settings.arguments;

    switch (settings.name) {
      case home:
        return PageTransition<dynamic>(child: const HomeScreen(), type: _transitionType, settings: settings, routeName: home);

      case addOtp:
        // Handle different constructor parameters for AddOtpScreen
        if (args is Map<String, dynamic>) {
          return PageTransition<bool?>(
            child: AddOtpScreen(
              showQrOptions: args['showQrOptions'] ?? true,
              initiallyShowQrScanner: args['initiallyShowQrScanner'] ?? false,
              initialQrCode: args['initialQrCode'],
            ),
            type: _transitionType,
            settings: settings,
            routeName: addOtp,
          );
        }
        // Default parameters
        return PageTransition<bool?>(child: const AddOtpScreen(), type: _transitionType, settings: settings, routeName: addOtp);

      case RouteGenerator.settings:
        return PageTransition<dynamic>(child: const SettingsScreen(), type: _transitionType, settings: settings, routeName: settings.name);

      case RouteGenerator.lanSync:
        return PageTransition<dynamic>(child: const LanSyncScreen(), type: _transitionType, settings: settings, routeName: lanSync);

      case RouteGenerator.customTheme:
        return PageTransition<dynamic>(child: const CustomThemeScreen(), type: _transitionType, settings: settings, routeName: customTheme);

      case RouteGenerator.export:
        return PageTransition<dynamic>(child: const ExportScreen(), type: _transitionType, settings: settings, routeName: export);

      case RouteGenerator.import:
        return PageTransition<bool?>(child: const ImportScreen(), type: _transitionType, settings: settings, routeName: import);

      default:
        // If the route is not found, show an error page
        _logger.e('Route not found: ${settings.name}');
        return PageTransition<dynamic>(
          child: Scaffold(appBar: AppBar(title: const Text('Error')), body: const Center(child: Text('Page not found'))),
          type: PageTransitionType.fade,
          settings: settings,
        );
    }
  }
}
