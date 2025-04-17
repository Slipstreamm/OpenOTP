// test/goldens/ipad_screenshot_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openotp/utils/page_transitions.dart';
import 'package:provider/provider.dart';

import 'package:openotp/screens/home_screen.dart';
import 'package:openotp/services/theme_service.dart';
import 'package:openotp/services/icon_service.dart';
import 'package:openotp/services/settings_service_interface.dart';
import 'package:openotp/models/settings_model.dart';

/// A fake that implements the interface instead of extending a factory class.
class FakeSettingsService implements ISettingsService {
  @override
  Future<SettingsModel> loadSettings() async {
    // immediately return defaults so initialize() won't hang
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateThemeMode(ThemeMode mode) async {
    return SettingsModel.defaults.copyWith(themeMode: mode);
  }

  @override
  Future<SettingsModel> updateBiometrics(bool useBiometrics) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateAutoLockTimeout(int minutes) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updatePageTransitionType(PageTransitionType type) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateHomeViewType(HomeViewType viewType) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateThemeStyleType(ThemeStyleType styleType) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateCustomLightTheme(CustomThemeModel theme) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateCustomDarkTheme(CustomThemeModel theme) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateSimpleDeleteConfirmation(bool useSimpleConfirmation) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateDeviceName(String deviceName) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateSyncPin(String? syncPin) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateServerPort(int? serverPort) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updateClientPort(int? clientPort) async {
    return SettingsModel.defaults;
  }

  @override
  Future<SettingsModel> updatePasswordEncryption(bool usePasswordEncryption) async {
    return SettingsModel.defaults;
  }
}

void main() {
  // Load your real fonts so text shows up properly
  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('OTP Home Screen Golden @ iPad Pro 12.9 (2048×2732 px)', (WidgetTester tester) async {
    // 1) Build a DeviceBuilder for a 12.9" iPad Pro:
    final builder =
        DeviceBuilder()
          ..overrideDevicesForAllScenarios(
            devices: [
              Device(
                name: 'iPad Pro 12.9',
                // **logical** size in dp:
                size: const Size(1024, 1366),
                devicePixelRatio: 2.0,
              ),
            ],
          )
          ..addScenario(
            name: 'OTP Home',
            widget: MultiProvider(
              providers: [
                ChangeNotifierProvider<ThemeService>.value(
                  value: ThemeService(settingsService: FakeSettingsService())..initialize(), // fire-and-forget is OK here
                ),
                Provider<IconService>.value(value: IconService()),
              ],
              child: const MaterialApp(home: HomeScreen()),
            ),
          );

    // 2) Pump the builder — this uses 1024×1366 dp @ 2.0 DPR → 2048×2732 px
    await tester.pumpDeviceBuilder(builder);
    await tester.pumpAndSettle();

    // 3) Compare against your golden file
    await screenMatchesGolden(tester, 'otp_home_ipad_pro_12_9');
  });
}
