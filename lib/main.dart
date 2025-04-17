import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'services/logger_service.dart';
import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'services/icon_service.dart';
import 'utils/route_generator.dart';
import 'screens/lock_screen.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger
  final logger = LoggerService();
  logger.i('Starting OpenOTP application');

  // Set up error handling for Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.e('Flutter error: ${details.exception}', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  // Set up global error handler for uncaught async errors
  // This will catch errors that happen in asynchronous code
  // including asset loading errors
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Uncaught platform error', error, stack);
    // Return true to indicate the error has been handled
    return true;
  };

  // Initialize theme service
  final themeService = ThemeService();
  await themeService.initialize();

  // Initialize auth service (just to ensure it's created)
  // ignore: unused_local_variable
  final authService = AuthService();
  logger.i('Auth service initialized');

  // Initialize icon service and preload common icons
  final iconService = IconService();
  // Preload common icons in the background
  iconService
      .preloadCommonIcons()
      .then((_) {
        logger.i('Common icons preloaded');
      })
      .catchError((error, stackTrace) {
        logger.e('Error preloading common icons', error, stackTrace);
      });

  // Provide both theme service and icon service to the widget tree
  runApp(
    MultiProvider(providers: [ChangeNotifierProvider(create: (_) => themeService), Provider<IconService>(create: (_) => iconService)], child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = LoggerService();
    logger.d('Building MyApp widget');

    // Get theme service from provider
    final themeService = Provider.of<ThemeService>(context);

    // Set initial transition type from settings
    RouteGenerator.setTransitionType(themeService.settings.pageTransitionType);

    return MaterialApp(
      title: 'OpenOTP',
      theme: themeService.getLightTheme(),
      darkTheme: themeService.getDarkTheme(),
      themeMode: themeService.themeMode,
      initialRoute: RouteGenerator.home,
      onGenerateRoute: (settings) {
        // Generate the route
        final route = RouteGenerator.generateRoute(settings);

        // If this is the home route and we need to show the lock screen
        if (settings.name == RouteGenerator.home) {
          logger.d('Wrapping home route with LockScreen');
          return PageRouteBuilder(
            settings: route.settings,
            transitionDuration: const Duration(milliseconds: 0),
            pageBuilder: (context, animation, secondaryAnimation) {
              // Extract the child widget from the original route
              final Widget child = (route as PageRouteBuilder).pageBuilder(context, animation, secondaryAnimation);
              return LockScreen(child: child);
            },
          );
        }

        return route;
      },
      navigatorObservers: [
        // Log route changes
        _LoggingNavigatorObserver(),
      ],
    );
  }
}

// Custom navigator observer for logging route changes
class _LoggingNavigatorObserver extends NavigatorObserver {
  final LoggerService _logger = LoggerService();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.i('Navigation: Pushed ${route.settings.name ?? route.toString()}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.i('Navigation: Popped ${route.settings.name ?? route.toString()}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.i('Navigation: Removed ${route.settings.name ?? route.toString()}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logger.i('Navigation: Replaced ${oldRoute?.settings.name ?? oldRoute.toString()} with ${newRoute?.settings.name ?? newRoute.toString()}');
  }
}
