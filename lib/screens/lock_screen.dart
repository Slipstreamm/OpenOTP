import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../services/theme_service.dart';

class LockScreen extends StatefulWidget {
  final Widget child;
  final bool canCancel;

  const LockScreen({super.key, required this.child, this.canCancel = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final AuthService _authService = AuthService();
  final LoggerService _logger = LoggerService();
  bool _isAuthenticating = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing LockScreen');
    _authenticate();
  }

  Future<void> _authenticate() async {
    _logger.d('Starting authentication process');
    final themeService = Provider.of<ThemeService>(context, listen: false);

    // Check if a password is set
    final hasPassword = await _authService.isPasswordSet();

    // Check if biometrics is available
    final biometricAvailable = await _authService.isBiometricAvailable();

    // Check if authentication is required based on settings and timeout
    final requiresAuth = await _authService.isAuthenticationRequired(themeService);

    // If no authentication methods are available, skip authentication
    if (!hasPassword && !biometricAvailable) {
      _logger.i('Authentication not required (no methods available)');
      setState(() {
        _isAuthenticating = false;
        _isAuthenticated = true;
      });
      return;
    }

    // Check if authentication is required based on timeout
    if (!requiresAuth) {
      _logger.i('Authentication not required (timeout not reached)');
      setState(() {
        _isAuthenticating = false;
        _isAuthenticated = true;
      });
      return;
    }

    // If we have a password or biometrics, and authentication is required, show the lock screen
    _logger.i('Authentication required, showing lock screen');

    // Check if the widget is still mounted before proceeding
    if (!mounted) return;

    // Use a completer to handle the result
    final completer = Completer<bool>();

    // Show the lock screen
    _authService.showLockScreen(context, canCancel: widget.canCancel).then((result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    });

    // Wait for the result
    final authenticated = await completer.future;

    // Check if the widget is still mounted before updating state
    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
      _isAuthenticated = authenticated;
    });

    _logger.i('Authentication ${authenticated ? 'successful' : 'failed'}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      // Show loading screen while checking authentication
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Checking security settings...', style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      );
    }

    if (_isAuthenticated) {
      // If authenticated, show the child widget
      return widget.child;
    } else {
      // If not authenticated and can't cancel, try again
      if (!widget.canCancel) {
        // Retry authentication after a short delay
        Future.delayed(const Duration(milliseconds: 500), _authenticate);
      }

      // Show a blank screen while waiting
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 48),
              const SizedBox(height: 16),
              Text('Authentication required', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (widget.canCancel)
                ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))
              else
                ElevatedButton(onPressed: _authenticate, child: const Text('Try Again')),
            ],
          ),
        ),
      );
    }
  }
}
