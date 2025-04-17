// test/goldens/ipad_screenshot_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openotp/screens/settings_screen.dart';
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
  setUpAll(() async {
    await loadAppFonts();
  });

  testWidgets('OTP Home Screen Golden (iPad Pro 12.9) — dark mode', (WidgetTester tester) async {
    // 1) Initialize binding and override window + platform settings
    final binding = TestWidgetsFlutterBinding.ensureInitialized() as TestWidgetsFlutterBinding;

    // physical size & DPR → logical 1024×1366
    binding.window.physicalSizeTestValue = const Size(2048, 2732);
    binding.window.devicePixelRatioTestValue = 2.0;

    // platform brightness override lives on platformDispatcher now:
    binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;

    // 2) Prep your services
    final themeService = ThemeService(settingsService: FakeSettingsService());
    await themeService.initialize();
    final iconService = IconService();

    // 3) Pump app with ThemeMode.system so it respects our faked brightness
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: themeService), Provider.value(value: iconService)],
        child: MaterialApp(
          theme: themeService.getLightTheme(),
          darkTheme: themeService.getDarkTheme(),
          themeMode: ThemeMode.system,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 4) Capture golden at full 2048×2732px
    await expectLater(find.byType(SettingsScreen), matchesGoldenFile('goldens/otp_settings_ipad_dark.png'));

    // 5) Clear so other tests aren’t affected
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });
}
