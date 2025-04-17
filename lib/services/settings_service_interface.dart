import 'package:openotp/utils/page_transitions.dart';
import '../models/settings_model.dart';
import 'package:flutter/material.dart';

/// Interface that both your real SettingsService and any fakes implement.
abstract class ISettingsService {
  Future<SettingsModel> loadSettings();
  Future<SettingsModel> updateThemeMode(ThemeMode mode);
  Future<SettingsModel> updateBiometrics(bool useBiometrics);
  Future<SettingsModel> updateAutoLockTimeout(int minutes);
  Future<SettingsModel> updatePageTransitionType(PageTransitionType type);
  Future<SettingsModel> updateHomeViewType(HomeViewType viewType);
  Future<SettingsModel> updateThemeStyleType(ThemeStyleType styleType);
  Future<SettingsModel> updateCustomLightTheme(CustomThemeModel theme);
  Future<SettingsModel> updateCustomDarkTheme(CustomThemeModel theme);
  Future<SettingsModel> updateSimpleDeleteConfirmation(bool useSimpleConfirmation);
  Future<SettingsModel> updateDeviceName(String deviceName);
  Future<SettingsModel> updateSyncPin(String? syncPin);
  Future<SettingsModel> updateServerPort(int? serverPort);
  Future<SettingsModel> updateClientPort(int? clientPort);
  Future<SettingsModel> updatePasswordEncryption(bool usePasswordEncryption);
}
