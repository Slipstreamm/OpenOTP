import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:openotp/services/settings_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings_model.dart';
import '../utils/page_transitions.dart';
import 'logger_service.dart';
import 'app_reload_service.dart';

class SettingsService implements ISettingsService {
  static const String _settingsKey = 'app_settings';
  final LoggerService _logger = LoggerService();
  final AppReloadService _reloadService = AppReloadService();

  // Singleton pattern
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Save settings to shared preferences
  Future<void> saveSettings(SettingsModel settings) async {
    _logger.d('Saving app settings');
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      _logger.i('Successfully saved app settings');

      // Trigger settings reload event
      _reloadService.triggerSettingsReload();
    } catch (e, stackTrace) {
      _logger.e('Error saving app settings', e, stackTrace);
      rethrow;
    }
  }

  // Load settings from shared preferences
  @override
  Future<SettingsModel> loadSettings() async {
    _logger.d('Loading app settings');
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson == null) {
        _logger.i('No saved settings found, using defaults');
        return SettingsModel.defaults;
      }

      final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
      final settings = SettingsModel.fromJson(settingsMap);
      _logger.i('Successfully loaded app settings');
      return settings;
    } catch (e, stackTrace) {
      _logger.e('Error loading app settings', e, stackTrace);
      // Return default settings in case of error
      return SettingsModel.defaults;
    }
  }

  // Update theme mode
  @override
  Future<SettingsModel> updateThemeMode(ThemeMode themeMode) async {
    _logger.d('Updating theme mode to: $themeMode');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(themeMode: themeMode);
      await saveSettings(newSettings);
      _logger.i('Successfully updated theme mode to: $themeMode');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating theme mode', e, stackTrace);
      rethrow;
    }
  }

  // Update biometrics setting
  @override
  Future<SettingsModel> updateBiometrics(bool useBiometrics) async {
    _logger.d('Updating biometrics setting to: $useBiometrics');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(useBiometrics: useBiometrics);
      await saveSettings(newSettings);
      _logger.i('Successfully updated biometrics setting to: $useBiometrics');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating biometrics setting', e, stackTrace);
      rethrow;
    }
  }

  // Update auto-lock timeout
  @override
  Future<SettingsModel> updateAutoLockTimeout(int minutes) async {
    _logger.d('Updating auto-lock timeout to: $minutes minutes');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(autoLockTimeout: minutes);
      await saveSettings(newSettings);
      _logger.i('Successfully updated auto-lock timeout to: $minutes minutes');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating auto-lock timeout', e, stackTrace);
      rethrow;
    }
  }

  // Update page transition type
  @override
  Future<SettingsModel> updatePageTransitionType(PageTransitionType type) async {
    _logger.d('Updating page transition type to: $type');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(pageTransitionType: type);
      await saveSettings(newSettings);
      _logger.i('Successfully updated page transition type to: $type');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating page transition type', e, stackTrace);
      rethrow;
    }
  }

  // Update home view type (grid or list)
  @override
  Future<SettingsModel> updateHomeViewType(HomeViewType viewType) async {
    _logger.d('Updating home view type to: $viewType');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(homeViewType: viewType);
      await saveSettings(newSettings);
      _logger.i('Successfully updated home view type to: $viewType');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating home view type', e, stackTrace);
      rethrow;
    }
  }

  // Update theme style type
  @override
  Future<SettingsModel> updateThemeStyleType(ThemeStyleType styleType) async {
    _logger.d('Updating theme style type to: $styleType');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(themeStyleType: styleType);
      await saveSettings(newSettings);
      _logger.i('Successfully updated theme style type to: $styleType');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating theme style type', e, stackTrace);
      rethrow;
    }
  }

  // Update custom light theme
  @override
  Future<SettingsModel> updateCustomLightTheme(CustomThemeModel theme) async {
    _logger.d('Updating custom light theme');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(
        lightCustomTheme: theme,
        themeStyleType: ThemeStyleType.custom, // Automatically switch to custom theme
      );
      await saveSettings(newSettings);
      _logger.i('Successfully updated custom light theme');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating custom light theme', e, stackTrace);
      rethrow;
    }
  }

  // Update custom dark theme
  @override
  Future<SettingsModel> updateCustomDarkTheme(CustomThemeModel theme) async {
    _logger.d('Updating custom dark theme');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(
        darkCustomTheme: theme,
        themeStyleType: ThemeStyleType.custom, // Automatically switch to custom theme
      );
      await saveSettings(newSettings);
      _logger.i('Successfully updated custom dark theme');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating custom dark theme', e, stackTrace);
      rethrow;
    }
  }

  // Update simple delete confirmation setting
  @override
  Future<SettingsModel> updateSimpleDeleteConfirmation(bool useSimpleConfirmation) async {
    _logger.d('Updating simple delete confirmation setting to: $useSimpleConfirmation');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(simpleDeleteConfirmation: useSimpleConfirmation);
      await saveSettings(newSettings);
      _logger.i('Successfully updated simple delete confirmation setting to: $useSimpleConfirmation');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating simple delete confirmation setting', e, stackTrace);
      rethrow;
    }
  }

  // Update device name for LAN sync
  @override
  Future<SettingsModel> updateDeviceName(String deviceName) async {
    _logger.d('Updating device name to: $deviceName');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(deviceName: deviceName);
      await saveSettings(newSettings);
      _logger.i('Successfully updated device name to: $deviceName');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating device name', e, stackTrace);
      rethrow;
    }
  }

  // Update sync PIN for LAN sync
  @override
  Future<SettingsModel> updateSyncPin(String? syncPin) async {
    _logger.d('Updating sync PIN');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(syncPin: syncPin);
      await saveSettings(newSettings);
      _logger.i('Successfully updated sync PIN');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating sync PIN', e, stackTrace);
      rethrow;
    }
  }

  // Update server port for LAN sync
  @override
  Future<SettingsModel> updateServerPort(int? serverPort) async {
    _logger.d('Updating server port to: $serverPort');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(serverPort: serverPort);
      await saveSettings(newSettings);
      _logger.i('Successfully updated server port to: $serverPort');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating server port', e, stackTrace);
      rethrow;
    }
  }

  // Update client port for LAN sync
  @override
  Future<SettingsModel> updateClientPort(int? clientPort) async {
    _logger.d('Updating client port to: $clientPort');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(clientPort: clientPort);
      await saveSettings(newSettings);
      _logger.i('Successfully updated client port to: $clientPort');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating client port', e, stackTrace);
      rethrow;
    }
  }

  // Update password encryption setting
  @override
  Future<SettingsModel> updatePasswordEncryption(bool usePasswordEncryption) async {
    _logger.d('Updating password encryption setting to: $usePasswordEncryption');
    try {
      final currentSettings = await loadSettings();
      final newSettings = currentSettings.copyWith(usePasswordEncryption: usePasswordEncryption);
      await saveSettings(newSettings);
      _logger.i('Successfully updated password encryption setting to: $usePasswordEncryption');
      return newSettings;
    } catch (e, stackTrace) {
      _logger.e('Error updating password encryption setting', e, stackTrace);
      rethrow;
    }
  }

  /// Clears all settings from shared preferences
  /// Returns true if successful, false otherwise
  Future<bool> clearAllSettings() async {
    _logger.d('Clearing all settings from shared preferences');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_settingsKey);
      _logger.i('Successfully cleared all settings from shared preferences');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error clearing settings from shared preferences', e, stackTrace);
      return false;
    }
  }

  /// Clears all shared preferences data (not just settings)
  /// Returns true if successful, false otherwise
  Future<bool> clearAllSharedPreferences() async {
    _logger.d('Clearing all shared preferences data');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _logger.i('Successfully cleared all shared preferences data');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error clearing all shared preferences data', e, stackTrace);
      return false;
    }
  }
}
