import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings_model.dart';
import '../utils/page_transitions.dart';
import '../utils/route_generator.dart';
import 'auth_service.dart';
import 'logger_service.dart';
import 'settings_service.dart';
import 'secure_storage_service.dart';
import 'settings_service_interface.dart';

class ThemeService with ChangeNotifier {
  // Allow injecting a fake in tests:
  final ISettingsService _settingsService;
  final LoggerService _logger;
  final AuthService _authService;

  ThemeService({ISettingsService? settingsService, LoggerService? logger, AuthService? authService})
    : _settingsService = settingsService ?? SettingsService(),
      _logger = logger ?? LoggerService(),
      _authService = authService ?? AuthService();

  // Theme definitions as static final fields
  final ThemeData darkTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // Background
    cardColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF0066CC), // Primary
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0066CC), // Primary
      foregroundColor: Color(0xFFFFFFFF), // Text Primary
      elevation: 4.0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: Color(0xFF0066CC), foregroundColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFFFFFFF)), // Text Primary
      bodyMedium: TextStyle(color: Color(0xFFFFFFFF)), // Text Primary
      bodySmall: TextStyle(color: Color(0xFFB0B0B0)), // Text Secondary
      titleLarge: TextStyle(color: Color(0xFFFFFFFF)), // Text Primary
      titleMedium: TextStyle(color: Color(0xFFFFFFFF)), // Text Primary
      titleSmall: TextStyle(color: Color(0xFFB0B0B0)), // Text Secondary
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF0066CC), // Primary
      secondary: Color(0xFF0066CC), // FAB
      surface: Color(0xFF1E1E1E),
      surfaceTint: Color(0xFF121212), // Background
      onPrimary: Color(0xFFFFFFFF), // Text Primary
      onSecondary: Color(0xFFFFFFFF), // Text Primary
      onSurface: Color(0xFFFFFFFF), // Text Primary
      onError: Color(0xFFFFFFFF),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      titleTextStyle: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFF121212)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFF1E1E1E), textStyle: const TextStyle(color: Color(0xFFFFFFFF))),
  );

  final ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF9F9F9), // Background
    cardColor: const Color(0xFFFFFFFF),
    primaryColor: const Color(0xFF0066CC), // Primary
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0066CC), // Primary
      foregroundColor: Color(0xFFFFFFFF), // FAB Icon (white for contrast)
      elevation: 4.0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF0066CC), // FAB (same as primary)
      foregroundColor: Color(0xFFFFFFFF), // FAB Icon
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF000000)), // Text Primary
      bodyMedium: TextStyle(color: Color(0xFF000000)), // Text Primary
      bodySmall: TextStyle(color: Color(0xFF4F4F4F)), // Text Secondary
      titleLarge: TextStyle(color: Color(0xFF000000)), // Text Primary
      titleMedium: TextStyle(color: Color(0xFF000000)), // Text Primary
      titleSmall: TextStyle(color: Color(0xFF4F4F4F)), // Text Secondary
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0066CC), // Primary
      secondary: Color(0xFF0066CC), // FAB (same as primary)
      surface: Color(0xFFFFFFFF),
      surfaceTint: Color(0xFFF9F9F9), // Background
      onPrimary: Color(0xFFFFFFFF), // FAB Icon (white for contrast)
      onSecondary: Color(0xFFFFFFFF), // FAB Icon (white for contrast)
      onSurface: Color(0xFF000000), // Text Primary
      onError: Color(0xFFFFFFFF),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFFFFFFFF),
      titleTextStyle: const TextStyle(color: Color(0xFF000000), fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFF4F4F4F), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFFF9F9F9)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFFFFFFFF), textStyle: const TextStyle(color: Color(0xFF000000))),
  );

  // Light Forest Theme
  final ThemeData lightForestTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFE8F5E9), // Light green background
    cardColor: const Color(0xFFFFFFFF),
    primaryColor: const Color(0xFF388E3C), // Green primary
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF388E3C), foregroundColor: Colors.white, elevation: 4.0),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFF388E3C), foregroundColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF1B5E20)),
      bodyMedium: TextStyle(color: Color(0xFF1B5E20)),
      bodySmall: TextStyle(color: Color(0xFF2E7D32)),
      titleLarge: TextStyle(color: Color(0xFF1B5E20)),
      titleMedium: TextStyle(color: Color(0xFF1B5E20)),
      titleSmall: TextStyle(color: Color(0xFF2E7D32)),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF388E3C),
      secondary: Color(0xFF66BB6A),
      surface: Color(0xFFFFFFFF),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF1B5E20),
      error: Colors.red,
      onError: Colors.white,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFFFFFFFF),
      titleTextStyle: const TextStyle(color: Color(0xFF1B5E20), fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFF2E7D32), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFFE8F5E9)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFFFFFFFF), textStyle: const TextStyle(color: Color(0xFF1B5E20))),
  );

  // Dark Forest Theme
  final ThemeData darkForestTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // Standard dark background
    cardColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF2E7D32), // Forest green
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF2E7D32), foregroundColor: Colors.white, elevation: 4.0),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFF2E7D32), foregroundColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Color(0xFFA5D6A7)), // Muted green
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Color(0xFFA5D6A7)),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF2E7D32),
      secondary: Color(0xFF66BB6A),
      surface: Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFFA5D6A7), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFF121212)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFF1E1E1E), textStyle: const TextStyle(color: Colors.white)),
  );

  // Light Sunset Theme
  final ThemeData lightSunsetTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFFFF3E0), // Soft warm background
    cardColor: const Color(0xFFFFFFFF),
    primaryColor: const Color(0xFFF57C00), // Warm orange
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF57C00), foregroundColor: Colors.white, elevation: 4.0),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFFF57C00), foregroundColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFFBF360C)),
      bodyMedium: TextStyle(color: Color(0xFFBF360C)),
      bodySmall: TextStyle(color: Color(0xFFD84315)),
      titleLarge: TextStyle(color: Color(0xFFBF360C)),
      titleMedium: TextStyle(color: Color(0xFFBF360C)),
      titleSmall: TextStyle(color: Color(0xFFD84315)),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFFF57C00),
      secondary: Color(0xFFFF8A65),
      surface: Color(0xFFFFFFFF),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFFBF360C),
      error: Colors.red,
      onError: Colors.white,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFFFFFFFF),
      titleTextStyle: const TextStyle(color: Color(0xFFBF360C), fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFFD84315), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFFFFF3E0)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFFFFFFFF), textStyle: const TextStyle(color: Color(0xFFBF360C))),
  );

  // Dark Sunset Theme
  final ThemeData darkSunsetTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // Standard dark background
    cardColor: const Color(0xFF121212),
    primaryColor: const Color(0xFFD84315), // Rich orange
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFD84315), foregroundColor: Colors.white, elevation: 4.0),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFFD84315), foregroundColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Color(0xFFFFAB91)), // Warm tone for secondary text
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Color(0xFFFFAB91)),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFD84315),
      secondary: Color(0xFFFF8A65),
      surface: Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFFFFAB91), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFF121212)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFF1E1E1E), textStyle: const TextStyle(color: Colors.white)),
  );

  // Light Violet Theme
  final ThemeData lightVioletTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFEDE7F6), // Light lavender background
    cardColor: const Color(0xFFFFFFFF),
    primaryColor: const Color(0xFF7E57C2), // Violet primary
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF7E57C2), foregroundColor: Colors.white, elevation: 4.0),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFF7E57C2), foregroundColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF4A148C)),
      bodyMedium: TextStyle(color: Color(0xFF4A148C)),
      bodySmall: TextStyle(color: Color(0xFF6A1B9A)),
      titleLarge: TextStyle(color: Color(0xFF4A148C)),
      titleMedium: TextStyle(color: Color(0xFF4A148C)),
      titleSmall: TextStyle(color: Color(0xFF6A1B9A)),
    ),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF7E57C2),
      secondary: Color(0xFFBA68C8),
      surface: Color(0xFFFFFFFF),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF4A148C),
      error: Colors.red,
      onError: Colors.white,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFFFFFFFF),
      titleTextStyle: const TextStyle(color: Color(0xFF4A148C), fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFF6A1B9A), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFFEDE7F6)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFFFFFFFF), textStyle: const TextStyle(color: Color(0xFF4A148C))),
  );

  // Dark Violet Theme
  final ThemeData darkVioletTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212), // Standard dark background
    cardColor: const Color(0xFF121212),
    primaryColor: const Color(0xFF6A1B9A), // Deep violet
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF6A1B9A), foregroundColor: Colors.white, elevation: 4.0),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xFF6A1B9A), foregroundColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: Color(0xFFCE93D8)), // Light purple
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Color(0xFFCE93D8)),
    ),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF6A1B9A),
      secondary: Color(0xFFBA68C8),
      surface: Color(0xFF1E1E1E),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      contentTextStyle: const TextStyle(color: Color(0xFFCE93D8), fontSize: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: const Color(0xFF121212)),
    popupMenuTheme: PopupMenuThemeData(color: const Color(0xFF1E1E1E), textStyle: const TextStyle(color: Colors.white)),
  );

  late SettingsModel _settings;
  bool _isInitialized = false;

  ThemeMode get themeMode => _settings.themeMode;
  SettingsModel get settings => _settings;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _logger.d('Initializing theme service');
    try {
      _settings = await _settingsService.loadSettings();
      _isInitialized = true;
      _logger.i('Theme service initialized with mode: ${_settings.themeMode}');
      notifyListeners();
    } catch (e, stack) {
      _logger.e('Error initializing theme service', e, stack);
      _settings = SettingsModel.defaults;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Update theme mode
  Future<void> updateThemeMode(ThemeMode mode) async {
    _logger.d('Updating theme mode to: $mode');
    try {
      _settings = await _settingsService.updateThemeMode(mode);
      _logger.i('Theme mode updated to: $mode');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating theme mode', e, stackTrace);
    }
  }

  // Update biometrics setting
  Future<void> updateBiometrics(bool useBiometrics) async {
    _logger.d('Updating biometrics setting to: $useBiometrics');
    try {
      // Update the setting in SettingsModel
      _settings = await _settingsService.updateBiometrics(useBiometrics);

      // Also update the setting in AuthModel
      final success = await _authService.updateBiometricsSetting(useBiometrics);
      if (!success) {
        _logger.w('Failed to update biometrics setting in auth model');
      }

      _logger.i('Biometrics setting updated to: $useBiometrics');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating biometrics setting', e, stackTrace);
    }
  }

  // Update auto-lock timeout
  Future<void> updateAutoLockTimeout(int minutes) async {
    _logger.d('Updating auto-lock timeout to: $minutes minutes');
    try {
      _settings = await _settingsService.updateAutoLockTimeout(minutes);
      _logger.i('Auto-lock timeout updated to: $minutes minutes');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating auto-lock timeout', e, stackTrace);
    }
  }

  // Update page transition type
  Future<void> updatePageTransitionType(PageTransitionType type) async {
    _logger.d('Updating page transition type to: $type');
    try {
      _settings = await _settingsService.updatePageTransitionType(type);
      // Update the global transition type in RouteGenerator
      RouteGenerator.setTransitionType(type);
      _logger.i('Page transition type updated to: $type');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating page transition type', e, stackTrace);
    }
  }

  // Update home view type (grid or list)
  Future<void> updateHomeViewType(HomeViewType viewType) async {
    _logger.d('Updating home view type to: $viewType');
    try {
      _settings = await _settingsService.updateHomeViewType(viewType);
      _logger.i('Home view type updated to: $viewType');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating home view type', e, stackTrace);
    }
  }

  // Update theme style type
  Future<void> updateThemeStyleType(ThemeStyleType styleType) async {
    _logger.d('Updating theme style type to: $styleType');
    try {
      _settings = await _settingsService.updateThemeStyleType(styleType);
      _logger.i('Theme style type updated to: $styleType');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating theme style type', e, stackTrace);
    }
  }

  // Update custom light theme
  Future<void> updateCustomLightTheme(CustomThemeModel theme) async {
    _logger.d('Updating custom light theme');
    try {
      _settings = await _settingsService.updateCustomLightTheme(theme);
      _logger.i('Custom light theme updated');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating custom light theme', e, stackTrace);
    }
  }

  // Update custom dark theme
  Future<void> updateCustomDarkTheme(CustomThemeModel theme) async {
    _logger.d('Updating custom dark theme');
    try {
      _settings = await _settingsService.updateCustomDarkTheme(theme);
      _logger.i('Custom dark theme updated');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating custom dark theme', e, stackTrace);
    }
  }

  // Update simple delete confirmation setting
  Future<void> updateSimpleDeleteConfirmation(bool useSimpleConfirmation) async {
    _logger.d('Updating simple delete confirmation setting to: $useSimpleConfirmation');
    try {
      _settings = await _settingsService.updateSimpleDeleteConfirmation(useSimpleConfirmation);
      _logger.i('Simple delete confirmation setting updated to: $useSimpleConfirmation');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating simple delete confirmation setting', e, stackTrace);
    }
  }

  // Update device name for LAN sync
  Future<void> updateDeviceName(String deviceName) async {
    _logger.d('Updating device name to: $deviceName');
    try {
      _settings = await _settingsService.updateDeviceName(deviceName);
      _logger.i('Device name updated to: $deviceName');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating device name', e, stackTrace);
    }
  }

  // Update sync PIN for LAN sync
  Future<void> updateSyncPin(String? syncPin) async {
    _logger.d('Updating sync PIN');
    try {
      _settings = await _settingsService.updateSyncPin(syncPin);
      _logger.i('Sync PIN updated');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating sync PIN', e, stackTrace);
    }
  }

  // Update server port for LAN sync
  Future<void> updateServerPort(int? serverPort) async {
    _logger.d('Updating server port to: $serverPort');
    try {
      _settings = await _settingsService.updateServerPort(serverPort);
      _logger.i('Server port updated to: $serverPort');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating server port', e, stackTrace);
    }
  }

  // Update client port for LAN sync
  Future<void> updateClientPort(int? clientPort) async {
    _logger.d('Updating client port to: $clientPort');
    try {
      _settings = await _settingsService.updateClientPort(clientPort);
      _logger.i('Client port updated to: $clientPort');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating client port', e, stackTrace);
    }
  }

  // Update password encryption setting
  Future<void> updatePasswordEncryption(bool usePasswordEncryption) async {
    _logger.d('Updating password encryption setting to: $usePasswordEncryption');
    try {
      // Check if we're disabling encryption
      if (!usePasswordEncryption) {
        _logger.d('Disabling password encryption, need to decrypt data first');

        // Get the current password for decryption
        final password = await _authService.getPasswordForEncryption();

        if (password != null) {
          // Create an instance of SecureStorageService
          final secureStorageService = SecureStorageService();

          // Decrypt the data before updating the setting
          final success = await secureStorageService.decryptData(password);

          if (!success) {
            _logger.e('Failed to decrypt data when disabling password encryption');
            // Throw an exception to be caught by the caller
            throw Exception('Failed to decrypt data when disabling password encryption');
          }

          _logger.i('Successfully decrypted data when disabling password encryption');
        } else {
          _logger.w('Could not get password for decryption when disabling encryption');
          throw Exception('Could not get password for decryption');
        }
      }

      // Update the setting
      _settings = await _settingsService.updatePasswordEncryption(usePasswordEncryption);
      _logger.i('Password encryption setting updated to: $usePasswordEncryption');
      notifyListeners();
    } catch (e, stackTrace) {
      _logger.e('Error updating password encryption setting', e, stackTrace);
      // Re-throw the exception to be handled by the caller
      rethrow;
    }
  }

  // Get light theme data based on theme style
  ThemeData getLightTheme() {
    switch (_settings.themeStyleType) {
      case ThemeStyleType.forest:
        return lightForestTheme;
      case ThemeStyleType.sunset:
        return lightSunsetTheme;
      case ThemeStyleType.violet:
        return lightVioletTheme;
      case ThemeStyleType.custom:
        if (_settings.lightCustomTheme != null) {
          return _createThemeFromCustom(_settings.lightCustomTheme!, Brightness.light);
        }
        return lightTheme; // Fallback to default if custom theme is null
      case ThemeStyleType.defaultStyle:
        return lightTheme;
    }
  }

  // Get dark theme data based on theme style
  ThemeData getDarkTheme() {
    switch (_settings.themeStyleType) {
      case ThemeStyleType.forest:
        return darkForestTheme;
      case ThemeStyleType.sunset:
        return darkSunsetTheme;
      case ThemeStyleType.violet:
        return darkVioletTheme;
      case ThemeStyleType.custom:
        if (_settings.darkCustomTheme != null) {
          return _createThemeFromCustom(_settings.darkCustomTheme!, Brightness.dark);
        }
        return darkTheme; // Fallback to default if custom theme is null
      case ThemeStyleType.defaultStyle:
        return darkTheme;
    }
  }

  // Create a ThemeData object from a CustomThemeModel
  ThemeData _createThemeFromCustom(CustomThemeModel customTheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      scaffoldBackgroundColor: customTheme.scaffoldBackgroundColor,
      cardColor: customTheme.cardColor,
      primaryColor: customTheme.primaryColor,

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: customTheme.appBarBackgroundColor,
        foregroundColor: customTheme.appBarForegroundColor,
        elevation: customTheme.appBarElevation,
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: customTheme.fabBackgroundColor,
        foregroundColor: customTheme.fabForegroundColor,
      ),

      // Text theme
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: customTheme.textPrimaryColor),
        bodyMedium: TextStyle(color: customTheme.textPrimaryColor),
        bodySmall: TextStyle(color: customTheme.textSecondaryColor),
        titleLarge: TextStyle(color: customTheme.textPrimaryColor),
        titleMedium: TextStyle(color: customTheme.textPrimaryColor),
        titleSmall: TextStyle(color: customTheme.textSecondaryColor),
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: customTheme.dialogBackgroundColor,
        titleTextStyle: TextStyle(color: customTheme.dialogTitleColor, fontSize: 20),
        contentTextStyle: TextStyle(color: customTheme.dialogContentColor, fontSize: 16),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: customTheme.bottomSheetBackgroundColor),

      // Popup menu theme
      popupMenuTheme: PopupMenuThemeData(color: customTheme.popupMenuBackgroundColor, textStyle: TextStyle(color: customTheme.popupMenuTextColor)),

      // Card theme
      cardTheme: CardTheme(color: customTheme.cardColor, elevation: customTheme.cardElevation),

      // Divider theme
      dividerTheme: DividerThemeData(color: customTheme.dividerColor, thickness: customTheme.dividerThickness),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: customTheme.inputLabelColor),
        hintStyle: TextStyle(color: customTheme.inputHintColor),
        border: OutlineInputBorder(borderSide: BorderSide(color: customTheme.inputBorderColor)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: customTheme.inputFocusedBorderColor, width: 2.0)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: customTheme.inputBorderColor)),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(backgroundColor: customTheme.elevatedButtonBackgroundColor, foregroundColor: customTheme.elevatedButtonForegroundColor),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: customTheme.textButtonColor)),

      // Color scheme
      colorScheme:
          brightness == Brightness.light
              ? ColorScheme.light(
                primary: customTheme.primaryColor,
                secondary: customTheme.fabBackgroundColor,
                surface: customTheme.surfaceColor,
                surfaceTint: customTheme.scaffoldBackgroundColor,
                onPrimary: customTheme.appBarForegroundColor,
                onSecondary: customTheme.fabForegroundColor,
                onSurface: customTheme.textPrimaryColor,
                onError: Colors.white,
                error: customTheme.errorColor,
              )
              : ColorScheme.dark(
                primary: customTheme.primaryColor,
                secondary: customTheme.fabBackgroundColor,
                surface: customTheme.surfaceColor,
                surfaceTint: customTheme.scaffoldBackgroundColor,
                onPrimary: customTheme.appBarForegroundColor,
                onSecondary: customTheme.fabForegroundColor,
                onSurface: customTheme.textPrimaryColor,
                onError: Colors.white,
                error: customTheme.errorColor,
              ),
    );
  }

  // Static method to get ThemeService from context
  static ThemeService of(BuildContext context) {
    return Provider.of<ThemeService>(context, listen: false);
  }
}
