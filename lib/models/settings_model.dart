import 'package:flutter/material.dart';
import '../utils/page_transitions.dart';
import '../utils/color_utils.dart';

// Enum for home screen view type
enum HomeViewType { authyStyle, grid, list }

// Enum for theme style type
enum ThemeStyleType { defaultStyle, forest, sunset, violet, custom }

// Model for custom theme colors
class CustomThemeModel {
  // Basic colors
  final Color primaryColor;
  final Color scaffoldBackgroundColor;
  final Color surfaceColor;
  final Color errorColor;

  // App bar
  final Color appBarBackgroundColor;
  final Color appBarForegroundColor;
  final double appBarElevation;

  // FAB
  final Color fabBackgroundColor;
  final Color fabForegroundColor;

  // Text
  final Color textPrimaryColor;
  final Color textSecondaryColor;

  // Card
  final Color cardColor;
  final double cardElevation;

  // Dialog
  final Color dialogBackgroundColor;
  final Color dialogTitleColor;
  final Color dialogContentColor;

  // Bottom sheet
  final Color bottomSheetBackgroundColor;

  // Popup menu
  final Color popupMenuBackgroundColor;
  final Color popupMenuTextColor;

  // Divider
  final Color dividerColor;
  final double dividerThickness;

  // Input decoration
  final Color inputLabelColor;
  final Color inputHintColor;
  final Color inputBorderColor;
  final Color inputFocusedBorderColor;

  // Buttons
  final Color elevatedButtonBackgroundColor;
  final Color elevatedButtonForegroundColor;
  final Color textButtonColor;

  const CustomThemeModel({
    // Basic colors
    this.primaryColor = const Color(0xFF0066CC),
    this.scaffoldBackgroundColor = const Color(0xFFF9F9F9),
    this.surfaceColor = const Color(0xFFFFFFFF),
    this.errorColor = const Color(0xFFFF0000),

    // App bar
    this.appBarBackgroundColor = const Color(0xFF0066CC),
    this.appBarForegroundColor = const Color(0xFFFFFFFF),
    this.appBarElevation = 4.0,

    // FAB
    this.fabBackgroundColor = const Color(0xFF0066CC),
    this.fabForegroundColor = const Color(0xFFFFFFFF),

    // Text
    this.textPrimaryColor = const Color(0xFF000000),
    this.textSecondaryColor = const Color(0xFF4F4F4F),

    // Card
    this.cardColor = const Color(0xFFFFFFFF),
    this.cardElevation = 2.0,

    // Dialog
    this.dialogBackgroundColor = const Color(0xFFFFFFFF),
    this.dialogTitleColor = const Color(0xFF000000),
    this.dialogContentColor = const Color(0xFF4F4F4F),

    // Bottom sheet
    this.bottomSheetBackgroundColor = const Color(0xFFF9F9F9),

    // Popup menu
    this.popupMenuBackgroundColor = const Color(0xFFFFFFFF),
    this.popupMenuTextColor = const Color(0xFF000000),

    // Divider
    this.dividerColor = const Color(0x334F4F4F), // 20% opacity
    this.dividerThickness = 1.0,

    // Input decoration
    this.inputLabelColor = const Color(0xFF4F4F4F),
    this.inputHintColor = const Color(0x994F4F4F), // 60% opacity
    this.inputBorderColor = const Color(0xFF4F4F4F),
    this.inputFocusedBorderColor = const Color(0xFF0066CC),

    // Buttons
    this.elevatedButtonBackgroundColor = const Color(0xFF0066CC),
    this.elevatedButtonForegroundColor = const Color(0xFFFFFFFF),
    this.textButtonColor = const Color(0xFF0066CC),
  });

  // Light mode default values
  static const CustomThemeModel lightDefaults = CustomThemeModel();

  // Dark mode default values
  static const CustomThemeModel darkDefaults = CustomThemeModel(
    // Basic colors
    primaryColor: Color(0xFF0066CC),
    scaffoldBackgroundColor: Color(0xFF121212),
    surfaceColor: Color(0xFF1E1E1E),
    errorColor: Color(0xFFFF5252),

    // App bar
    appBarBackgroundColor: Color(0xFF0066CC),
    appBarForegroundColor: Color(0xFFFFFFFF),
    appBarElevation: 4.0,

    // FAB
    fabBackgroundColor: Color(0xFF00BCD4),
    fabForegroundColor: Color(0xFFFFFFFF),

    // Text
    textPrimaryColor: Color(0xFFFFFFFF),
    textSecondaryColor: Color(0xFFB0B0B0),

    // Card
    cardColor: Color(0xFF1E1E1E),
    cardElevation: 2.0,

    // Dialog
    dialogBackgroundColor: Color(0xFF1E1E1E),
    dialogTitleColor: Color(0xFFFFFFFF),
    dialogContentColor: Color(0xFFB0B0B0),

    // Bottom sheet
    bottomSheetBackgroundColor: Color(0xFF121212),

    // Popup menu
    popupMenuBackgroundColor: Color(0xFF1E1E1E),
    popupMenuTextColor: Color(0xFFFFFFFF),

    // Divider
    dividerColor: Color(0x33B0B0B0), // 20% opacity
    dividerThickness: 1.0,

    // Input decoration
    inputLabelColor: Color(0xFFB0B0B0),
    inputHintColor: Color(0x99B0B0B0), // 60% opacity
    inputBorderColor: Color(0xFFB0B0B0),
    inputFocusedBorderColor: Color(0xFF0066CC),

    // Buttons
    elevatedButtonBackgroundColor: Color(0xFF0066CC),
    elevatedButtonForegroundColor: Color(0xFFFFFFFF),
    textButtonColor: Color(0xFF0066CC),
  );

  // Create a copy with some values replaced
  CustomThemeModel copyWith({
    // Basic colors
    Color? primaryColor,
    Color? scaffoldBackgroundColor,
    Color? surfaceColor,
    Color? errorColor,

    // App bar
    Color? appBarBackgroundColor,
    Color? appBarForegroundColor,
    double? appBarElevation,

    // FAB
    Color? fabBackgroundColor,
    Color? fabForegroundColor,

    // Text
    Color? textPrimaryColor,
    Color? textSecondaryColor,

    // Card
    Color? cardColor,
    double? cardElevation,

    // Dialog
    Color? dialogBackgroundColor,
    Color? dialogTitleColor,
    Color? dialogContentColor,

    // Bottom sheet
    Color? bottomSheetBackgroundColor,

    // Popup menu
    Color? popupMenuBackgroundColor,
    Color? popupMenuTextColor,

    // Divider
    Color? dividerColor,
    double? dividerThickness,

    // Input decoration
    Color? inputLabelColor,
    Color? inputHintColor,
    Color? inputBorderColor,
    Color? inputFocusedBorderColor,

    // Buttons
    Color? elevatedButtonBackgroundColor,
    Color? elevatedButtonForegroundColor,
    Color? textButtonColor,
  }) {
    return CustomThemeModel(
      // Basic colors
      primaryColor: primaryColor ?? this.primaryColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      errorColor: errorColor ?? this.errorColor,

      // App bar
      appBarBackgroundColor: appBarBackgroundColor ?? this.appBarBackgroundColor,
      appBarForegroundColor: appBarForegroundColor ?? this.appBarForegroundColor,
      appBarElevation: appBarElevation ?? this.appBarElevation,

      // FAB
      fabBackgroundColor: fabBackgroundColor ?? this.fabBackgroundColor,
      fabForegroundColor: fabForegroundColor ?? this.fabForegroundColor,

      // Text
      textPrimaryColor: textPrimaryColor ?? this.textPrimaryColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,

      // Card
      cardColor: cardColor ?? this.cardColor,
      cardElevation: cardElevation ?? this.cardElevation,

      // Dialog
      dialogBackgroundColor: dialogBackgroundColor ?? this.dialogBackgroundColor,
      dialogTitleColor: dialogTitleColor ?? this.dialogTitleColor,
      dialogContentColor: dialogContentColor ?? this.dialogContentColor,

      // Bottom sheet
      bottomSheetBackgroundColor: bottomSheetBackgroundColor ?? this.bottomSheetBackgroundColor,

      // Popup menu
      popupMenuBackgroundColor: popupMenuBackgroundColor ?? this.popupMenuBackgroundColor,
      popupMenuTextColor: popupMenuTextColor ?? this.popupMenuTextColor,

      // Divider
      dividerColor: dividerColor ?? this.dividerColor,
      dividerThickness: dividerThickness ?? this.dividerThickness,

      // Input decoration
      inputLabelColor: inputLabelColor ?? this.inputLabelColor,
      inputHintColor: inputHintColor ?? this.inputHintColor,
      inputBorderColor: inputBorderColor ?? this.inputBorderColor,
      inputFocusedBorderColor: inputFocusedBorderColor ?? this.inputFocusedBorderColor,

      // Buttons
      elevatedButtonBackgroundColor: elevatedButtonBackgroundColor ?? this.elevatedButtonBackgroundColor,
      elevatedButtonForegroundColor: elevatedButtonForegroundColor ?? this.elevatedButtonForegroundColor,
      textButtonColor: textButtonColor ?? this.textButtonColor,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      // Basic colors
      'primaryColor': primaryColor.toString(),
      'scaffoldBackgroundColor': scaffoldBackgroundColor.toString(),
      'surfaceColor': surfaceColor.toString(),
      'errorColor': errorColor.toString(),

      // App bar
      'appBarBackgroundColor': appBarBackgroundColor.toString(),
      'appBarForegroundColor': appBarForegroundColor.toString(),
      'appBarElevation': appBarElevation,

      // FAB
      'fabBackgroundColor': fabBackgroundColor.toString(),
      'fabForegroundColor': fabForegroundColor.toString(),

      // Text
      'textPrimaryColor': textPrimaryColor.toString(),
      'textSecondaryColor': textSecondaryColor.toString(),

      // Card
      'cardColor': cardColor.toString(),
      'cardElevation': cardElevation,

      // Dialog
      'dialogBackgroundColor': dialogBackgroundColor.toString(),
      'dialogTitleColor': dialogTitleColor.toString(),
      'dialogContentColor': dialogContentColor.toString(),

      // Bottom sheet
      'bottomSheetBackgroundColor': bottomSheetBackgroundColor.toString(),

      // Popup menu
      'popupMenuBackgroundColor': popupMenuBackgroundColor.toString(),
      'popupMenuTextColor': popupMenuTextColor.toString(),

      // Divider
      'dividerColor': dividerColor.toString(),
      'dividerThickness': dividerThickness,

      // Input decoration
      'inputLabelColor': inputLabelColor.toString(),
      'inputHintColor': inputHintColor.toString(),
      'inputBorderColor': inputBorderColor.toString(),
      'inputFocusedBorderColor': inputFocusedBorderColor.toString(),

      // Buttons
      'elevatedButtonBackgroundColor': elevatedButtonBackgroundColor.toString(),
      'elevatedButtonForegroundColor': elevatedButtonForegroundColor.toString(),
      'textButtonColor': textButtonColor.toString(),
    };
  }

  // Create from JSON
  factory CustomThemeModel.fromJson(Map<String, dynamic> json) {
    return CustomThemeModel(
      // Basic colors
      primaryColor: _parseColorString(json['primaryColor'], const Color(0xFF0066CC)),
      scaffoldBackgroundColor: _parseColorString(json['scaffoldBackgroundColor'], const Color(0xFFF9F9F9)),
      surfaceColor: _parseColorString(json['surfaceColor'], const Color(0xFFFFFFFF)),
      errorColor: _parseColorString(json['errorColor'], const Color(0xFFFF0000)),

      // App bar
      appBarBackgroundColor: _parseColorString(json['appBarBackgroundColor'], const Color(0xFF0066CC)),
      appBarForegroundColor: _parseColorString(json['appBarForegroundColor'], const Color(0xFFFFFFFF)),
      appBarElevation: json['appBarElevation']?.toDouble() ?? 4.0,

      // FAB
      fabBackgroundColor: _parseColorString(json['fabBackgroundColor'], const Color(0xFF0066CC)),
      fabForegroundColor: _parseColorString(json['fabForegroundColor'], const Color(0xFFFFFFFF)),

      // Text
      textPrimaryColor: _parseColorString(json['textPrimaryColor'], const Color(0xFF000000)),
      textSecondaryColor: _parseColorString(json['textSecondaryColor'], const Color(0xFF4F4F4F)),

      // Card
      cardColor: _parseColorString(json['cardColor'], const Color(0xFFFFFFFF)),
      cardElevation: json['cardElevation']?.toDouble() ?? 2.0,

      // Dialog
      dialogBackgroundColor: _parseColorString(json['dialogBackgroundColor'], const Color(0xFFFFFFFF)),
      dialogTitleColor: _parseColorString(json['dialogTitleColor'], const Color(0xFF000000)),
      dialogContentColor: _parseColorString(json['dialogContentColor'], const Color(0xFF4F4F4F)),

      // Bottom sheet
      bottomSheetBackgroundColor: _parseColorString(json['bottomSheetBackgroundColor'], const Color(0xFFF9F9F9)),

      // Popup menu
      popupMenuBackgroundColor: _parseColorString(json['popupMenuBackgroundColor'], const Color(0xFFFFFFFF)),
      popupMenuTextColor: _parseColorString(json['popupMenuTextColor'], const Color(0xFF000000)),

      // Divider
      dividerColor: _parseColorString(json['dividerColor'], const Color(0x334F4F4F)),
      dividerThickness: json['dividerThickness']?.toDouble() ?? 1.0,

      // Input decoration
      inputLabelColor: _parseColorString(json['inputLabelColor'], const Color(0xFF4F4F4F)),
      inputHintColor: _parseColorString(json['inputHintColor'], const Color(0x994F4F4F)),
      inputBorderColor: _parseColorString(json['inputBorderColor'], const Color(0xFF4F4F4F)),
      inputFocusedBorderColor: _parseColorString(json['inputFocusedBorderColor'], const Color(0xFF0066CC)),

      // Buttons
      elevatedButtonBackgroundColor: _parseColorString(json['elevatedButtonBackgroundColor'], const Color(0xFF0066CC)),
      elevatedButtonForegroundColor: _parseColorString(json['elevatedButtonForegroundColor'], const Color(0xFFFFFFFF)),
      textButtonColor: _parseColorString(json['textButtonColor'], const Color(0xFF0066CC)),
    );
  }

  // Helper method to parse color from string representation
  static Color _parseColorString(String? colorString, Color defaultColor) {
    if (colorString == null) return defaultColor;

    try {
      // Check if it's a hex string (starts with #)
      if (colorString.startsWith('#')) {
        return ColorUtils.hexToColor(colorString, defaultColor: defaultColor);
      }

      // Color.toString() returns "Color(0xAARRGGBB)"
      // Extract the hex value from the string
      final valueString = colorString.split('(')[1].split(')')[0];
      return Color(int.parse(valueString));
    } catch (e) {
      return defaultColor;
    }
  }

  // Get a color as a hex string
  String getColorHex(Color color) {
    return ColorUtils.colorToHex(color);
  }
}

class SettingsModel {
  final ThemeMode themeMode;
  final bool useBiometrics;
  final int autoLockTimeout; // in minutes, 0 means never, -1 means always
  final PageTransitionType pageTransitionType; // Type of page transition animation
  final HomeViewType homeViewType; // Grid or list view for home screen
  final ThemeStyleType themeStyleType; // Theme style (Default, Forest, Sunset, Violet, Custom)
  final CustomThemeModel? lightCustomTheme; // Custom theme for light mode
  final CustomThemeModel? darkCustomTheme; // Custom theme for dark mode
  final bool simpleDeleteConfirmation; // Whether to use a simple checkbox for delete confirmation
  final String deviceName; // Device name for LAN sync
  final String? syncPin; // PIN for LAN sync authentication
  final int? serverPort; // Custom port for LAN sync server
  final int? clientPort; // Custom port for LAN sync client
  final bool usePasswordEncryption; // Whether to use password as a second layer of encryption

  const SettingsModel({
    this.themeMode = ThemeMode.system,
    this.useBiometrics = false,
    this.autoLockTimeout = 5,
    this.pageTransitionType = PageTransitionType.rightToLeft,
    this.homeViewType = HomeViewType.authyStyle, // Default to Authy style with selection at top
    this.themeStyleType = ThemeStyleType.defaultStyle, // Default theme style
    this.lightCustomTheme, // Custom light theme (null by default)
    this.darkCustomTheme, // Custom dark theme (null by default)
    this.simpleDeleteConfirmation = false, // Default to requiring typing the name
    this.deviceName = '', // Default empty device name
    this.syncPin, // Default null sync PIN
    this.serverPort, // Default null server port (will use default)
    this.clientPort, // Default null client port (will use default)
    this.usePasswordEncryption = false, // Default to not using password encryption
  });

  // Create a copy of this settings model with some values replaced
  SettingsModel copyWith({
    ThemeMode? themeMode,
    bool? useBiometrics,
    int? autoLockTimeout,
    PageTransitionType? pageTransitionType,
    HomeViewType? homeViewType,
    ThemeStyleType? themeStyleType,
    CustomThemeModel? lightCustomTheme,
    CustomThemeModel? darkCustomTheme,
    bool? simpleDeleteConfirmation,
    String? deviceName,
    String? syncPin,
    int? serverPort,
    int? clientPort,
    bool? usePasswordEncryption,
  }) {
    return SettingsModel(
      themeMode: themeMode ?? this.themeMode,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      autoLockTimeout: autoLockTimeout ?? this.autoLockTimeout,
      pageTransitionType: pageTransitionType ?? this.pageTransitionType,
      homeViewType: homeViewType ?? this.homeViewType,
      themeStyleType: themeStyleType ?? this.themeStyleType,
      lightCustomTheme: lightCustomTheme ?? this.lightCustomTheme,
      darkCustomTheme: darkCustomTheme ?? this.darkCustomTheme,
      simpleDeleteConfirmation: simpleDeleteConfirmation ?? this.simpleDeleteConfirmation,
      deviceName: deviceName ?? this.deviceName,
      syncPin: syncPin ?? this.syncPin,
      serverPort: serverPort ?? this.serverPort,
      clientPort: clientPort ?? this.clientPort,
      usePasswordEncryption: usePasswordEncryption ?? this.usePasswordEncryption,
    );
  }

  // Convert settings to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'useBiometrics': useBiometrics,
      'autoLockTimeout': autoLockTimeout,
      'pageTransitionType': pageTransitionType.index,
      'homeViewType': homeViewType.index,
      'themeStyleType': themeStyleType.index,
      'lightCustomTheme': lightCustomTheme?.toJson(),
      'darkCustomTheme': darkCustomTheme?.toJson(),
      'simpleDeleteConfirmation': simpleDeleteConfirmation,
      'deviceName': deviceName,
      'syncPin': syncPin,
      'serverPort': serverPort,
      'clientPort': clientPort,
      'usePasswordEncryption': usePasswordEncryption,
    };
  }

  // Create settings from JSON
  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    // Parse custom themes if they exist
    CustomThemeModel? lightCustomTheme;
    if (json['lightCustomTheme'] != null) {
      lightCustomTheme = CustomThemeModel.fromJson(json['lightCustomTheme']);
    }

    CustomThemeModel? darkCustomTheme;
    if (json['darkCustomTheme'] != null) {
      darkCustomTheme = CustomThemeModel.fromJson(json['darkCustomTheme']);
    }

    return SettingsModel(
      themeMode: ThemeMode.values[json['themeMode'] ?? 0],
      useBiometrics: json['useBiometrics'] ?? false,
      autoLockTimeout: json['autoLockTimeout'] ?? -1, // Always lock
      pageTransitionType: json['pageTransitionType'] != null ? PageTransitionType.values[json['pageTransitionType']] : PageTransitionType.rightToLeft,
      homeViewType: json['homeViewType'] != null ? HomeViewType.values[json['homeViewType']] : HomeViewType.grid,
      themeStyleType: json['themeStyleType'] != null ? ThemeStyleType.values[json['themeStyleType']] : ThemeStyleType.defaultStyle,
      lightCustomTheme: lightCustomTheme,
      darkCustomTheme: darkCustomTheme,
      simpleDeleteConfirmation: json['simpleDeleteConfirmation'] ?? false,
      deviceName: json['deviceName'] ?? '',
      syncPin: json['syncPin'],
      serverPort: json['serverPort'] != null ? int.tryParse(json['serverPort'].toString()) : null,
      clientPort: json['clientPort'] != null ? int.tryParse(json['clientPort'].toString()) : null,
      usePasswordEncryption: json['usePasswordEncryption'] ?? false,
    );
  }

  // Default settings
  static const SettingsModel defaults = SettingsModel();
}
