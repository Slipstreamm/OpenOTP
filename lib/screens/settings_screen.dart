import 'dart:async';
import 'package:flutter/material.dart';
import 'package:openotp/widgets/custom_app_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/settings_model.dart';
import '../services/logger_service.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/secure_storage_service.dart';
import '../services/settings_service.dart';
import '../services/app_reload_service.dart';
import '../utils/page_transitions.dart';
import '../utils/route_generator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LoggerService _logger = LoggerService();
  final SecureStorageService _storageService = SecureStorageService();
  final SettingsService _settingsService = SettingsService();
  final AppReloadService _reloadService = AppReloadService();

  // Subscriptions for reload events
  StreamSubscription? _settingsReloadSubscription;
  StreamSubscription? _fullAppReloadSubscription;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing SettingsScreen');

    // Set up listeners for reload events
    _setupReloadListeners();
  }

  // Set up listeners for reload events
  void _setupReloadListeners() {
    _logger.d('Setting up reload listeners for SettingsScreen');

    // Listen for settings reload events
    _settingsReloadSubscription = _reloadService.onSettingsReload.listen((_) {
      _logger.i('Settings reload event received');
      // Refresh the ThemeService to reload settings
      if (mounted) {
        final themeService = Provider.of<ThemeService>(context, listen: false);
        themeService.initialize();
      }
    });

    // Listen for full app reload events
    _fullAppReloadSubscription = _reloadService.onFullAppReload.listen((_) {
      _logger.i('Full app reload event received');
      // Refresh the ThemeService to reload settings
      if (mounted) {
        final themeService = Provider.of<ThemeService>(context, listen: false);
        themeService.initialize();
      }
    });
  }

  @override
  void dispose() {
    _logger.i('Disposing SettingsScreen');
    _settingsReloadSubscription?.cancel();
    _fullAppReloadSubscription?.cancel();
    super.dispose();
  }

  void _showPageTransitionDialog(BuildContext context, ThemeService themeService) {
    _logger.d('Showing page transition selection dialog');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Page Transition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<PageTransitionType>(
                  title: const Text('Fade'),
                  value: PageTransitionType.fade,
                  groupValue: themeService.settings.pageTransitionType,
                  onChanged: (PageTransitionType? value) {
                    if (value != null) {
                      _logger.d('Page transition selected: $value');
                      themeService.updatePageTransitionType(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<PageTransitionType>(
                  title: const Text('Slide Right to Left'),
                  value: PageTransitionType.rightToLeft,
                  groupValue: themeService.settings.pageTransitionType,
                  onChanged: (PageTransitionType? value) {
                    if (value != null) {
                      _logger.d('Page transition selected: $value');
                      themeService.updatePageTransitionType(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<PageTransitionType>(
                  title: const Text('Slide Left to Right'),
                  value: PageTransitionType.leftToRight,
                  groupValue: themeService.settings.pageTransitionType,
                  onChanged: (PageTransitionType? value) {
                    if (value != null) {
                      _logger.d('Page transition selected: $value');
                      themeService.updatePageTransitionType(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<PageTransitionType>(
                  title: const Text('Slide Down to Up'),
                  value: PageTransitionType.downToUp,
                  groupValue: themeService.settings.pageTransitionType,
                  onChanged: (PageTransitionType? value) {
                    if (value != null) {
                      _logger.d('Page transition selected: $value');
                      themeService.updatePageTransitionType(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<PageTransitionType>(
                  title: const Text('Scale'),
                  value: PageTransitionType.scale,
                  groupValue: themeService.settings.pageTransitionType,
                  onChanged: (PageTransitionType? value) {
                    if (value != null) {
                      _logger.d('Page transition selected: $value');
                      themeService.updatePageTransitionType(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<PageTransitionType>(
                  title: const Text('Right to Left with Fade'),
                  value: PageTransitionType.rightToLeftWithFade,
                  groupValue: themeService.settings.pageTransitionType,
                  onChanged: (PageTransitionType? value) {
                    if (value != null) {
                      _logger.d('Page transition selected: $value');
                      themeService.updatePageTransitionType(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Page transition selection dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Reusable Settings Card Widget
  Widget _buildSettingsCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building SettingsScreen widget');
    return Scaffold(
      appBar: CustomAppBar(title: 'Settings'),
      body: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            children: [
              // Appearance section with the new card widget
              _buildSettingsCard(
                context: context,
                title: 'Appearance',
                icon: Icons.palette,
                initiallyExpanded: true,
                children: [
                  ListTile(
                    title: const Text('Light/Dark Mode'),
                    subtitle: Text(_getThemeModeText(themeService.themeMode)),
                    leading: const Icon(Icons.brightness_6),
                    onTap: () => _showThemeDialog(context, themeService),
                  ),
                  ListTile(
                    title: const Text('Theme Style'),
                    subtitle: Text(_getThemeStyleText(themeService.settings.themeStyleType)),
                    leading: const Icon(Icons.color_lens),
                    onTap: () => _showThemeStyleDialog(context, themeService),
                  ),
                  ListTile(
                    title: const Text('Create Custom Theme'),
                    subtitle: const Text('Design your own theme colors'),
                    leading: const Icon(Icons.palette),
                    onTap: () => Navigator.pushNamed(context, RouteGenerator.customTheme),
                  ),
                  ListTile(
                    title: const Text('Home Screen View'),
                    subtitle: Text(_getHomeViewTypeText(themeService.settings.homeViewType)),
                    leading: const Icon(Icons.grid_view),
                    onTap: () => _showHomeViewTypeDialog(context, themeService),
                  ),
                ],
              ),

              // Animations section
              _buildSettingsCard(
                context: context,
                title: 'Animations',
                icon: Icons.animation,
                children: [
                  ListTile(
                    title: const Text('Page Transitions'),
                    subtitle: Text(_getPageTransitionText(themeService.settings.pageTransitionType)),
                    leading: const Icon(Icons.animation),
                    onTap: () => _showPageTransitionDialog(context, themeService),
                  ),
                ],
              ),

              // Security section
              _buildSettingsCard(
                context: context,
                title: 'Security',
                icon: Icons.security,
                children: [
                  SwitchListTile(
                    title: const Text('Simple Delete Confirmation'),
                    subtitle: const Text('Use a checkbox instead of typing the entry name to confirm deletion'),
                    value: themeService.settings.simpleDeleteConfirmation,
                    onChanged: (value) {
                      _logger.d('Simple delete confirmation toggled to: $value');
                      themeService.updateSimpleDeleteConfirmation(value);
                    },
                  ),
                  FutureBuilder<bool>(
                    future: _authService.isBiometricAvailable(),
                    builder: (context, snapshot) {
                      final biometricsAvailable = snapshot.data ?? false;

                      return SwitchListTile(
                        title: const Text('Use Biometric Authentication'),
                        subtitle: Text(
                          biometricsAvailable ? 'Require biometric authentication to open the app' : 'Biometric authentication is not available on this device',
                        ),
                        value: themeService.settings.useBiometrics && biometricsAvailable,
                        onChanged:
                            biometricsAvailable
                                ? (value) {
                                  _logger.d('Biometric authentication toggled to: $value');
                                  if (value) {
                                    // If enabling biometrics, check if a passcode is set as fallback
                                    _authService.isPasswordSet().then((hasPasscode) {
                                      if (!hasPasscode && mounted) {
                                        // If no passcode is set, show passcode setup screen
                                        // Use a post-frame callback to ensure the context is valid
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) {
                                            _showPasswordSetupDialog(context);
                                          }
                                        });
                                      }
                                    });
                                  }
                                  themeService.updateBiometrics(value);
                                }
                                : null,
                      );
                    },
                  ),
                  FutureBuilder<bool>(
                    future: _authService.isPasswordSet(),
                    builder: (context, snapshot) {
                      final hasPasscode = snapshot.data ?? false;

                      return ListTile(
                        title: const Text('App Password'),
                        subtitle: Text(hasPasscode ? 'Change or remove password' : 'Set up a password for app security'),
                        leading: const Icon(Icons.password),
                        onTap: () => _showPasswordOptionsDialog(context),
                      );
                    },
                  ),
                  FutureBuilder<bool>(
                    future: _authService.isPasswordSet(),
                    builder: (context, snapshot) {
                      final hasPassword = snapshot.data ?? false;

                      return SwitchListTile(
                        title: const Text('Encrypt OTP Keys'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Encrypt your OTP keys with your password'),
                            Text('Malware can easily decrypt your keys if this is off', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        value: themeService.settings.usePasswordEncryption && hasPassword,
                        onChanged:
                            hasPassword
                                ? (value) {
                                  _logger.d('Password encryption toggled to: $value');
                                  if (value) {
                                    _showPasswordEncryptionInfoDialog(context, themeService);
                                  } else {
                                    // Store a reference to the scaffold messenger before the async gap
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                                    // Show a loading indicator
                                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Decrypting OTP keys...')));

                                    // Disable encryption and decrypt data
                                    themeService
                                        .updatePasswordEncryption(false)
                                        .then((_) {
                                          if (mounted) {
                                            scaffoldMessenger.showSnackBar(
                                              const SnackBar(content: Text('Password encryption disabled and OTP keys decrypted')),
                                            );
                                          }
                                        })
                                        .catchError((error) {
                                          _logger.e('Error disabling password encryption', error);
                                          if (mounted) {
                                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Error disabling password encryption')));
                                          }
                                        });
                                  }
                                }
                                : null,
                        secondary: const Icon(Icons.enhanced_encryption),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Auto-Lock Timeout'),
                    subtitle: Text(_getAutoLockText(themeService.settings.autoLockTimeout)),
                    leading: const Icon(Icons.timer),
                    onTap: () => _showAutoLockDialog(context, themeService),
                  ),
                ],
              ),

              // Synchronization section
              _buildSettingsCard(
                context: context,
                title: 'Synchronization',
                icon: Icons.sync,
                children: [
                  ListTile(
                    title: const Text('LAN Device Sync'),
                    subtitle: const Text('Sync OTP entries and settings with other devices on your network'),
                    leading: const Icon(Icons.sync),
                    onTap: () => _navigateToLanSyncScreen(context),
                  ),
                ],
              ),

              // Data Management section
              _buildSettingsCard(
                context: context,
                title: 'Data Management',
                icon: Icons.storage,
                children: [
                  ListTile(
                    title: const Text('Export Data'),
                    subtitle: const Text('Export your OTP entries and settings to a file'),
                    leading: const Icon(Icons.upload_file),
                    onTap: () => _navigateToExportScreen(context),
                  ),
                  ListTile(
                    title: const Text('Import Data'),
                    subtitle: const Text('Import OTP entries and settings from a file'),
                    leading: const Icon(Icons.download_rounded),
                    onTap: () => _navigateToImportScreen(context),
                  ),
                  ListTile(
                    title: const Text('Clean Up Invalid Entries'),
                    subtitle: const Text('Remove any OTP entries with invalid secret keys'),
                    leading: const Icon(Icons.cleaning_services),
                    onTap: () => _cleanupInvalidEntries(context),
                  ),
                  ListTile(
                    title: const Text('Wipe All Data'),
                    subtitle: const Text('Permanently delete all saved data including OTP entries and settings'),
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    onTap: () => _showWipeDataDialog(context),
                  ),
                ],
              ),

              // About section
              _buildSettingsCard(
                context: context,
                title: 'About',
                icon: Icons.info_outline,
                children: [
                  const ListTile(title: Text('OpenOTP'), subtitle: Text('A secure, open-source OTP authenticator app'), leading: Icon(Icons.app_shortcut)),
                  FutureBuilder<String>(
                    future: _getAppVersion(),
                    builder: (context, snapshot) {
                      return ListTile(
                        title: const Text('Version'),
                        subtitle: Text(
                          snapshot.connectionState == ConnectionState.waiting
                              ? 'Loading...'
                              : snapshot.hasError
                              ? 'Error loading version'
                              : snapshot.data ?? 'Unknown',
                        ),
                        leading: const Icon(Icons.info_outline),
                      );
                    },
                  ),
                  ListTile(
                    title: const Text('Developer'),
                    subtitle: const Text('Hunter Lee / Slipstreamm'),
                    leading: const Icon(Icons.person),
                    onTap: () => _launchUrl('https://github.com/Slipstreamm'),
                  ),
                  ListTile(
                    title: const Text('GitHub Repository'),
                    subtitle: const Text('View source code on GitHub'),
                    leading: const Icon(Icons.code),
                    onTap: () => _launchUrl('https://github.com/Slipstreamm/OpenOTP'),
                  ),
                  ListTile(
                    title: const Text('Website'),
                    subtitle: const Text('Visit our website'),
                    leading: const Icon(Icons.language),
                    onTap: () => _launchUrl('https://openotp.lol'),
                  ),
                  ListTile(
                    title: const Text('Privacy Policy'),
                    subtitle: const Text('View our privacy policy'),
                    leading: const Icon(Icons.privacy_tip),
                    onTap: () => _launchUrl('https://openotp.lol/privacy'),
                  ),
                  ListTile(
                    title: const Text('Help & Support'),
                    subtitle: const Text('Get help with using the app'),
                    leading: const Icon(Icons.help),
                    onTap: () => _launchUrl('https://openotp.lol/support'),
                  ),
                  ListTile(
                    title: const Text('Open Source Licenses'),
                    subtitle: const Text('View licenses for third-party libraries'),
                    leading: const Icon(Icons.source),
                    onTap: () => _showLicensesPage(context),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  final AuthService _authService = AuthService();

  // Show remove password confirmation dialog
  void _showRemovePasswordConfirmDialog(BuildContext context) async {
    _logger.d('Showing remove password confirmation dialog');

    // Check if password encryption is enabled
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final usePasswordEncryption = themeService.settings.usePasswordEncryption;

    if (usePasswordEncryption) {
      // Show warning about password encryption first
      final shouldProceed = await _showPasswordEncryptionWarningDialog(context);
      if (!shouldProceed) {
        _logger.d('Password removal cancelled due to encryption warning');
        return;
      }
    }

    // Check if widget is still mounted after the async operation
    if (!mounted) return;

    // Use a post-frame callback to ensure the context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Remove Password'),
              content: const Text('Are you sure you want to remove your password? This will reduce the security of your app.'),
              actions: [
                TextButton(
                  onPressed: () {
                    _logger.d('Remove password cancelled');
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.red),
                  onPressed: () async {
                    _logger.d('Removing password confirmed');
                    // Store context before async gap
                    final scaffoldMessenger = ScaffoldMessenger.of(dialogContext);
                    Navigator.pop(dialogContext); // Close dialog first

                    // Then remove password - use await to handle any potential errors
                    try {
                      final success = await _authService.removePassword();
                      if (success && mounted) {
                        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Password removed successfully')));

                        // If we had password encryption enabled, show a message that it's been disabled
                        if (usePasswordEncryption && mounted) {
                          // Add a slight delay to avoid overlapping snackbars
                          await Future.delayed(const Duration(seconds: 1));
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Password encryption has been disabled')));
                          }
                        }
                      }
                    } catch (e) {
                      _logger.e('Error removing password', e);
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Error removing password')));
                      }
                    }
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  // Show warning dialog for password encryption when removing password
  Future<bool> _showPasswordEncryptionWarningDialog(BuildContext context) async {
    _logger.d('Showing password encryption warning dialog');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Warning: Password Encryption Enabled'),
          content: const Text(
            'You currently have password encryption enabled for your OTP data. '
            'Removing your password will also disable password encryption and decrypt your data.\n\n'
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Password encryption warning acknowledged, cancelling password removal');
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.red),
              onPressed: () {
                _logger.d('Password encryption warning acknowledged, proceeding with password removal');
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // Navigate to LAN sync screen
  void _navigateToLanSyncScreen(BuildContext context) async {
    _logger.d('Navigating to LAN sync screen');
    try {
      await Navigator.pushNamed(context, RouteGenerator.lanSync);
      _logger.i('Returned from LAN sync screen');
    } catch (e, stackTrace) {
      _logger.e('Error navigating to LAN sync screen', e, stackTrace);
    }
  }

  // Navigate to export screen
  void _navigateToExportScreen(BuildContext context) async {
    _logger.d('Navigating to export screen');
    try {
      await Navigator.pushNamed(context, RouteGenerator.export);
      _logger.i('Returned from export screen');
    } catch (e, stackTrace) {
      _logger.e('Error navigating to export screen', e, stackTrace);
    }
  }

  // Navigate to import screen
  void _navigateToImportScreen(BuildContext context) async {
    _logger.d('Navigating to import screen');
    try {
      // Store a reference to the scaffold messenger before the async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      final result = await Navigator.pushNamed<bool>(context, RouteGenerator.import);
      _logger.i('Returned from import screen with result: $result');

      // If data was imported, show a message
      if (result == true && mounted) {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Import completed successfully')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error navigating to import screen', e, stackTrace);
    }
  }

  // Clean up invalid OTP entries
  Future<void> _cleanupInvalidEntries(BuildContext originalContext) async {
    _logger.d('Starting cleanup of invalid OTP entries');
    try {
      // Show a confirmation dialog first
      final shouldProceed = await showDialog<bool>(
        context: originalContext,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Clean Up Invalid Entries'),
            content: const Text(
              'This will scan your OTP entries and remove any with invalid secret keys. '
              'This action cannot be undone.\n\n'
              'Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );

      if (shouldProceed != true) {
        _logger.d('Cleanup cancelled by user');
        return;
      }

      // Store a reference to the scaffold messenger before the async gap
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(originalContext);

      // Show a loading indicator
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Cleaning up invalid entries...')));

      // Run the cleanup
      final removedCount = await _storageService.cleanupInvalidEntries();

      // Show the result
      if (!mounted) return;
      if (removedCount > 0) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Removed $removedCount invalid OTP ${removedCount == 1 ? 'entry' : 'entries'}')));
      } else {
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('No invalid entries found')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error cleaning up invalid OTP entries', e, stackTrace);

      // Show error message if still mounted
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(originalContext);
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error cleaning up entries: ${e.toString()}')));
      }
    }
  }

  void _showThemeDialog(BuildContext context, ThemeService themeService) {
    _logger.d('Showing theme selection dialog');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Light/Dark Mode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('System'),
                value: ThemeMode.system,
                groupValue: themeService.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    _logger.d('Theme mode selected: $value');
                    themeService.updateThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: themeService.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    _logger.d('Theme mode selected: $value');
                    themeService.updateThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: themeService.themeMode,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    _logger.d('Theme mode selected: $value');
                    themeService.updateThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Theme selection dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showThemeStyleDialog(BuildContext context, ThemeService themeService) {
    _logger.d('Showing theme style selection dialog');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Theme Style'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeStyleType>(
                title: const Text('Default'),
                subtitle: const Text('Blue theme'),
                value: ThemeStyleType.defaultStyle,
                groupValue: themeService.settings.themeStyleType,
                onChanged: (ThemeStyleType? value) {
                  if (value != null) {
                    _logger.d('Theme style selected: $value');
                    themeService.updateThemeStyleType(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeStyleType>(
                title: const Text('Forest'),
                subtitle: const Text('Green theme'),
                value: ThemeStyleType.forest,
                groupValue: themeService.settings.themeStyleType,
                onChanged: (ThemeStyleType? value) {
                  if (value != null) {
                    _logger.d('Theme style selected: $value');
                    themeService.updateThemeStyleType(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeStyleType>(
                title: const Text('Sunset'),
                subtitle: const Text('Orange theme'),
                value: ThemeStyleType.sunset,
                groupValue: themeService.settings.themeStyleType,
                onChanged: (ThemeStyleType? value) {
                  if (value != null) {
                    _logger.d('Theme style selected: $value');
                    themeService.updateThemeStyleType(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeStyleType>(
                title: const Text('Violet'),
                subtitle: const Text('Purple theme'),
                value: ThemeStyleType.violet,
                groupValue: themeService.settings.themeStyleType,
                onChanged: (ThemeStyleType? value) {
                  if (value != null) {
                    _logger.d('Theme style selected: $value');
                    themeService.updateThemeStyleType(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<ThemeStyleType>(
                title: const Text('Custom'),
                subtitle: const Text('Your custom theme'),
                value: ThemeStyleType.custom,
                groupValue: themeService.settings.themeStyleType,
                onChanged: (ThemeStyleType? value) {
                  if (value != null) {
                    _logger.d('Theme style selected: $value');
                    themeService.updateThemeStyleType(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Theme style selection dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showAutoLockDialog(BuildContext context, ThemeService themeService) {
    _logger.d('Showing auto-lock timeout selection dialog');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Auto-Lock Timeout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('Always'),
                subtitle: const Text('Require authentication every time'),
                value: -1,
                groupValue: themeService.settings.autoLockTimeout,
                onChanged: (int? value) {
                  if (value != null) {
                    _logger.d('Auto-lock timeout selected: Always');
                    themeService.updateAutoLockTimeout(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<int>(
                title: const Text('Never'),
                subtitle: const Text('Only authenticate once'),
                value: 0,
                groupValue: themeService.settings.autoLockTimeout,
                onChanged: (int? value) {
                  if (value != null) {
                    _logger.d('Auto-lock timeout selected: Never');
                    themeService.updateAutoLockTimeout(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<int>(
                title: const Text('1 minute'),
                value: 1,
                groupValue: themeService.settings.autoLockTimeout,
                onChanged: (int? value) {
                  if (value != null) {
                    _logger.d('Auto-lock timeout selected: $value minutes');
                    themeService.updateAutoLockTimeout(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<int>(
                title: const Text('5 minutes'),
                value: 5,
                groupValue: themeService.settings.autoLockTimeout,
                onChanged: (int? value) {
                  if (value != null) {
                    _logger.d('Auto-lock timeout selected: $value minutes');
                    themeService.updateAutoLockTimeout(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<int>(
                title: const Text('15 minutes'),
                value: 15,
                groupValue: themeService.settings.autoLockTimeout,
                onChanged: (int? value) {
                  if (value != null) {
                    _logger.d('Auto-lock timeout selected: $value minutes');
                    themeService.updateAutoLockTimeout(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<int>(
                title: const Text('30 minutes'),
                value: 30,
                groupValue: themeService.settings.autoLockTimeout,
                onChanged: (int? value) {
                  if (value != null) {
                    _logger.d('Auto-lock timeout selected: $value minutes');
                    themeService.updateAutoLockTimeout(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Auto-lock timeout selection dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _getThemeStyleText(ThemeStyleType style) {
    switch (style) {
      case ThemeStyleType.defaultStyle:
        return 'Default';
      case ThemeStyleType.forest:
        return 'Forest';
      case ThemeStyleType.sunset:
        return 'Sunset';
      case ThemeStyleType.violet:
        return 'Violet';
      case ThemeStyleType.custom:
        return 'Custom';
    }
  }

  String _getAutoLockText(int minutes) {
    if (minutes == -1) {
      return 'Always';
    } else if (minutes == 0) {
      return 'Never';
    } else if (minutes == 1) {
      return '1 minute';
    } else {
      return '$minutes minutes';
    }
  }

  // Get app version dynamically using PackageInfo
  Future<String> _getAppVersion() async {
    _logger.d('Getting app version');
    try {
      final info = await PackageInfo.fromPlatform();
      final version = '${info.version}+${info.buildNumber}';
      _logger.d('App version: $version');
      return version;
    } catch (e) {
      _logger.e('Error getting app version', e);
      return 'Error';
    }
  }

  // Launch URL in browser
  Future<void> _launchUrl(String urlString) async {
    _logger.d('Launching URL: $urlString');
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        _logger.i('Successfully launched URL: $urlString');
      } else {
        _logger.w('Could not launch URL: $urlString');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $urlString')));
        }
      }
    } catch (e) {
      _logger.e('Error launching URL: $urlString', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening link: ${e.toString()}')));
      }
    }
  }

  // Show licenses page
  void _showLicensesPage(BuildContext context) {
    _logger.d('Showing licenses page');
    showLicensePage(
      context: context,
      applicationName: 'OpenOTP',
      applicationVersion: 'v1.1.1+1', // Hard-coded version for now
      applicationIcon: const Icon(Icons.app_shortcut, size: 48),
      applicationLegalese: '© ${DateTime.now().year} Hunter Lee',
    );
  }

  String _getPageTransitionText(PageTransitionType type) {
    switch (type) {
      case PageTransitionType.fade:
        return 'Fade';
      case PageTransitionType.rightToLeft:
        return 'Slide Right to Left';
      case PageTransitionType.leftToRight:
        return 'Slide Left to Right';
      case PageTransitionType.upToDown:
        return 'Slide Up to Down';
      case PageTransitionType.downToUp:
        return 'Slide Down to Up';
      case PageTransitionType.scale:
        return 'Scale';
      case PageTransitionType.rotate:
        return 'Rotate';
      case PageTransitionType.size:
        return 'Size';
      case PageTransitionType.rightToLeftWithFade:
        return 'Slide Right to Left with Fade';
      case PageTransitionType.leftToRightWithFade:
        return 'Slide Left to Right with Fade';
    }
  }

  String _getHomeViewTypeText(HomeViewType viewType) {
    switch (viewType) {
      case HomeViewType.authyStyle:
        return 'Authy Style (Selection at top)';
      case HomeViewType.grid:
        return 'Grid View';
      case HomeViewType.list:
        return 'List View';
    }
  }

  // Show home view type selection dialog
  void _showHomeViewTypeDialog(BuildContext context, ThemeService themeService) {
    _logger.d('Showing home view type selection dialog');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose Home Screen View'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<HomeViewType>(
                title: const Text('Authy Style'),
                subtitle: const Text('Selected TOTP at top with grid below'),
                value: HomeViewType.authyStyle,
                groupValue: themeService.settings.homeViewType,
                onChanged: (HomeViewType? value) {
                  if (value != null) {
                    _logger.d('Home view type selected: $value');
                    themeService.updateHomeViewType(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<HomeViewType>(
                title: const Text('Grid View'),
                subtitle: const Text('All TOTPs displayed in a grid'),
                value: HomeViewType.grid,
                groupValue: themeService.settings.homeViewType,
                onChanged: (HomeViewType? value) {
                  if (value != null) {
                    _logger.d('Home view type selected: $value');
                    themeService.updateHomeViewType(value);
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<HomeViewType>(
                title: const Text('List View'),
                subtitle: const Text('Detailed list with more information'),
                value: HomeViewType.list,
                groupValue: themeService.settings.homeViewType,
                onChanged: (HomeViewType? value) {
                  if (value != null) {
                    _logger.d('Home view type selected: $value');
                    themeService.updateHomeViewType(value);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Home view type selection dialog cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Show password setup dialog
  void _showPasswordSetupDialog(BuildContext context) {
    _logger.d('Showing password setup dialog');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Up Password'),
          content: const Text(
            'A password is required as a fallback when biometric authentication fails or is unavailable. Would you like to set up a password now?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Password setup cancelled');
                Navigator.pop(dialogContext);
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                _logger.d('Setting up password');
                Navigator.pop(dialogContext);

                // Store context references before async gap
                final scaffoldMessengerState = ScaffoldMessenger.of(context);

                // Use a post-frame callback to ensure the context is valid
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _authService
                        .showPasswordSetupScreen(context)
                        .then((success) {
                          if (success && mounted) {
                            scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Password set successfully')));
                          }
                        })
                        .catchError((error) {
                          _logger.e('Error setting up password', error);
                          if (mounted) {
                            scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Error setting password')));
                          }
                        });
                  }
                });
              },
              child: const Text('Set Up Now'),
            ),
          ],
        );
      },
    );
  }

  // Show password encryption info dialog
  void _showPasswordEncryptionInfoDialog(BuildContext context, ThemeService themeService) {
    _logger.d('Showing password encryption info dialog');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Password Encryption'),
          content: const Text(
            'This feature adds a second layer of encryption to your OTP data using your password. '
            'This provides additional security but requires your password to be set.\n\n'
            'Note: Enabling this feature will re-encrypt all your OTP data. If you forget your password, '
            'you will lose access to your OTP codes.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.d('Password encryption cancelled');
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _logger.d('Password encryption enabled');
                Navigator.pop(dialogContext);

                // Store a reference to the scaffold messenger before the async gap
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Show a loading indicator
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Encrypting OTP keys...')));

                // Enable encryption
                themeService
                    .updatePasswordEncryption(true)
                    .then((_) {
                      if (mounted) {
                        // Show a success message
                        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Password encryption enabled and OTP keys encrypted')));
                      }
                    })
                    .catchError((error) {
                      _logger.e('Error enabling password encryption', error);
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Error enabling password encryption')));
                      }
                    });
              },
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
  }

  // Show password options dialog
  Future<void> _showPasswordOptionsDialog(BuildContext context) async {
    _logger.d('Showing password options dialog');

    // Get password status first
    final hasPassword = await _authService.isPasswordSet();
    if (!mounted) return;

    // Use a post-frame callback to ensure the context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Then show dialog
        showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(hasPassword ? 'Password Options' : 'Set Up Password'),
              content:
                  hasPassword
                      ? const Text('What would you like to do with your password?')
                      : const Text('Setting up a password adds an extra layer of security to your app.'),
              actions: [
                if (hasPassword) ...[
                  TextButton(
                    onPressed: () async {
                      _logger.d('Attempting to remove password');
                      Navigator.pop(dialogContext);

                      // Store context references before async gap
                      final scaffoldMessengerState = ScaffoldMessenger.of(context);

                      // Authenticate before allowing password removal
                      final authenticated = await _authService.authenticateForPasswordChange(context);

                      // Check if widget is still mounted
                      if (!mounted) return;

                      if (authenticated) {
                        _logger.d('Authentication successful, showing remove password dialog');
                        // Use a post-frame callback to ensure the context is valid
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _showRemovePasswordConfirmDialog(context);
                          }
                        });
                      } else {
                        _logger.w('Authentication failed, password removal cancelled');
                        scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Authentication failed. Password removal cancelled.')));
                      }
                    },
                    child: const Text('Remove Password'),
                  ),
                  TextButton(
                    onPressed: () async {
                      _logger.d('Attempting to change password');
                      Navigator.pop(dialogContext);

                      // Store context references before async gap
                      final scaffoldMessengerState = ScaffoldMessenger.of(context);

                      // Authenticate before allowing password change
                      final authenticated = await _authService.authenticateForPasswordChange(context);

                      // Check if widget is still mounted
                      if (!mounted) return;

                      if (authenticated) {
                        _logger.d('Authentication successful, showing password setup screen');

                        // Use a post-frame callback to ensure the context is valid
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            // Get password encryption status inside the post-frame callback
                            final themeService = Provider.of<ThemeService>(context, listen: false);
                            final usePasswordEncryption = themeService.settings.usePasswordEncryption;

                            _authService
                                .showPasswordSetupScreen(context)
                                .then((success) async {
                                  if (success && mounted) {
                                    // Show password changed success message
                                    scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Password changed successfully')));

                                    // If password encryption is enabled, show a message that data has been re-encrypted
                                    if (usePasswordEncryption) {
                                      // Add a slight delay to avoid overlapping snackbars
                                      await Future.delayed(const Duration(seconds: 1));
                                      if (mounted) {
                                        scaffoldMessengerState.showSnackBar(
                                          const SnackBar(content: Text('Your data has been re-encrypted with the new password')),
                                        );
                                      }
                                    }
                                  }
                                })
                                .catchError((error) {
                                  _logger.e('Error setting up password', error);
                                  if (mounted) {
                                    scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Error changing password')));
                                  }
                                });
                          }
                        });
                      } else {
                        _logger.w('Authentication failed, password change cancelled');
                        scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Authentication failed. Password change cancelled.')));
                      }
                    },
                    child: const Text('Change Password'),
                  ),
                ] else ...[
                  TextButton(
                    onPressed: () {
                      _logger.d('Setting up password');
                      Navigator.pop(context);

                      // Store context references before async gap
                      final scaffoldMessengerState = ScaffoldMessenger.of(context);

                      // Use a post-frame callback to ensure the context is valid
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _authService
                              .showPasswordSetupScreen(context)
                              .then((success) {
                                if (success && mounted) {
                                  scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Password set successfully')));
                                }
                              })
                              .catchError((error) {
                                _logger.e('Error setting up password', error);
                                if (mounted) {
                                  scaffoldMessengerState.showSnackBar(const SnackBar(content: Text('Error setting password')));
                                }
                              });
                        }
                      });
                    },
                    child: const Text('Set Up Password'),
                  ),
                ],
                TextButton(
                  onPressed: () {
                    _logger.d('Password options dialog cancelled');
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      }
    });
  }

  // Show dialog to wipe all data
  void _showWipeDataDialog(BuildContext context) async {
    _logger.d('Showing wipe all data dialog');

    // Check if password is set
    final hasPassword = await _authService.isPasswordSet();
    if (!mounted) return;

    // Use a post-frame callback to ensure the context is valid
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) {
            // Text controller for confirmation text
            final confirmTextController = TextEditingController();
            // Password controller if password is set
            final passwordController = TextEditingController();
            // Checkbox state
            bool isConfirmed = false;

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text('Wipe All Data'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WARNING: This will permanently delete all your OTP entries, settings, and authentication data. '
                          'This action cannot be undone.',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (hasPassword) ...[
                          const Text('Enter your password to confirm:'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: passwordController,
                            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Password'),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text('Type "WIPE ALL DATA" to confirm:'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: confirmTextController,
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Confirmation text'),
                          onChanged: (value) {
                            setState(() {
                              isConfirmed = value == 'WIPE ALL DATA';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        CheckboxListTile(
                          title: const Text('I understand this action cannot be undone'),
                          value: isConfirmed,
                          onChanged: (value) {
                            setState(() {
                              isConfirmed = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        _logger.d('Wipe data cancelled');
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed:
                          isConfirmed && confirmTextController.text == 'WIPE ALL DATA'
                              ? () {
                                _logger.d('Attempting to wipe all data');

                                // Store context and messenger before any async operations
                                final contextToUse = context;
                                final messenger = ScaffoldMessenger.of(dialogContext);

                                // Create a function to handle verification and wiping
                                Future<void> verifyAndWipe() async {
                                  // Verify password if set
                                  if (hasPassword) {
                                    final passwordValid = await _authService.verifyPassword(passwordController.text);
                                    if (!passwordValid) {
                                      messenger.showSnackBar(const SnackBar(content: Text('Incorrect password')));
                                      return;
                                    }
                                  }

                                  // Perform the data wipe
                                  _wipeAllData(contextToUse);
                                }

                                // Close dialog first
                                Navigator.pop(dialogContext);

                                // Then start the verification and wipe process
                                verifyAndWipe();
                              }
                              : null,
                      child: const Text('Wipe All Data'),
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    });
  }

  // Perform the actual data wipe
  void _wipeAllData(BuildContext originalContext) {
    _logger.d('Wiping all data');

    // Store a reference to the scaffold messenger before any async operations
    final scaffoldMessenger = ScaffoldMessenger.of(originalContext);
    final navigator = Navigator.of(originalContext);

    // Create an async function to handle the actual wiping
    Future<void> performWipe() async {
      try {
        // Show a loading indicator
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Wiping all data...')));

        // Wipe OTP entries from secure storage
        final otpWipeSuccess = await _storageService.wipeAllOtpEntries();
        if (!otpWipeSuccess) {
          _logger.e('Failed to wipe OTP entries');
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Error wiping OTP entries')));
          return;
        }

        // Clear authentication data
        final authClearSuccess = await _authService.clearAuthData();
        if (!authClearSuccess) {
          _logger.e('Failed to clear authentication data');
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Error clearing authentication data')));
          return;
        }

        // Clear all shared preferences
        final prefsClearSuccess = await _settingsService.clearAllSharedPreferences();
        if (!prefsClearSuccess) {
          _logger.e('Failed to clear shared preferences');
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Error clearing settings')));
          return;
        }

        // Show success message
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('All data has been wiped. The app will now restart.'), duration: Duration(seconds: 5)));

        // Give the user a moment to see the message before restarting
        await Future.delayed(const Duration(seconds: 2));

        // Restart the app by returning to the home screen
        navigator.pushNamedAndRemoveUntil(RouteGenerator.home, (route) => false);
      } catch (e, stackTrace) {
        _logger.e('Error wiping all data', e, stackTrace);
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error wiping data: ${e.toString()}')));
      }
    }

    // Start the wiping process
    performWipe();
  }
}
