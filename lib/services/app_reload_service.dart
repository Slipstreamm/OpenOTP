import 'dart:async';
import 'package:openotp/services/logger_service.dart';

/// Service to manage app-wide reload events
class AppReloadService {
  final LoggerService _logger = LoggerService();

  // Singleton pattern
  static final AppReloadService _instance = AppReloadService._internal();
  factory AppReloadService() => _instance;
  AppReloadService._internal();

  // Stream controllers for different types of reload events
  final _settingsReloadController = StreamController<void>.broadcast();
  final _otpEntriesReloadController = StreamController<void>.broadcast();
  final _fullAppReloadController = StreamController<void>.broadcast();

  // Stream getters
  Stream<void> get onSettingsReload => _settingsReloadController.stream;
  Stream<void> get onOtpEntriesReload => _otpEntriesReloadController.stream;
  Stream<void> get onFullAppReload => _fullAppReloadController.stream;

  // Trigger a settings reload
  void triggerSettingsReload() {
    _logger.i('Triggering settings reload');
    _settingsReloadController.add(null);
  }

  // Trigger an OTP entries reload
  void triggerOtpEntriesReload() {
    _logger.i('Triggering OTP entries reload');
    _otpEntriesReloadController.add(null);
  }

  // Trigger a full app reload (both settings and OTP entries)
  void triggerFullAppReload() {
    _logger.i('Triggering full app reload');
    _settingsReloadController.add(null);
    _otpEntriesReloadController.add(null);
    _fullAppReloadController.add(null);
  }

  // Dispose of stream controllers
  void dispose() {
    _logger.d('Disposing AppReloadService');
    _settingsReloadController.close();
    _otpEntriesReloadController.close();
    _fullAppReloadController.close();
  }
}
