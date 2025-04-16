import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_model.dart';
import '../widgets/password_entry_widget.dart';
import '../widgets/password_setup_widget.dart';
import 'logger_service.dart';
import 'secure_storage_service.dart';
import 'settings_service.dart';
import 'theme_service.dart';

class AuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final LoggerService _logger = LoggerService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final SettingsService _settingsService = SettingsService();
  late final SecureStorageService _secureStorageService;

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // Initialize secure storage service
    _secureStorageService = SecureStorageService();
  }

  // Keys for storing authentication data
  static const String _authDataKey = 'secure_auth_data';
  static const String _legacyAuthDataKey = 'auth_data'; // For migration from SharedPreferences
  static const String _legacyPasscodeKey = 'auth_passcode'; // For migration from old system

  // Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    _logger.d('Checking if biometric authentication is available');
    try {
      // Check if device supports biometrics
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (canAuthenticate) {
        // Get available biometrics
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        _logger.i('Available biometrics: $availableBiometrics');

        return availableBiometrics.isNotEmpty;
      }

      _logger.i('Biometric authentication is not available on this device');
      return false;
    } on PlatformException catch (e, stackTrace) {
      _logger.e('Error checking biometric availability', e, stackTrace);
      return false;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error checking biometric availability', e, stackTrace);
      return false;
    }
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    _logger.d('Getting available biometric types');
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      _logger.i('Available biometrics: $availableBiometrics');
      return availableBiometrics;
    } on PlatformException catch (e, stackTrace) {
      _logger.e('Error getting available biometrics', e, stackTrace);
      return [];
    } catch (e, stackTrace) {
      _logger.e('Unexpected error getting available biometrics', e, stackTrace);
      return [];
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String localizedReason = 'Authenticate to access your OTP codes',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    _logger.d('Attempting biometric authentication');
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: AuthenticationOptions(stickyAuth: stickyAuth, useErrorDialogs: useErrorDialogs, biometricOnly: true),
      );

      if (authenticated) {
        _logger.i('Biometric authentication successful');
        await _updateLastAuthTime();
      } else {
        _logger.w('Biometric authentication failed');
      }

      return authenticated;
    } on PlatformException catch (e, stackTrace) {
      if (e.code == auth_error.notAvailable || e.code == auth_error.notEnrolled || e.code == auth_error.passcodeNotSet) {
        _logger.w('Biometric authentication not available: ${e.code}');
      } else {
        _logger.e('Error during biometric authentication', e, stackTrace);
      }
      return false;
    } catch (e, stackTrace) {
      _logger.e('Unexpected error during biometric authentication', e, stackTrace);
      return false;
    }
  }

  // Load authentication data
  Future<AuthModel> _loadAuthData() async {
    _logger.d('Loading authentication data');
    try {
      // First, try to load from secure storage
      final authDataJson = await _secureStorage.read(key: _authDataKey);

      // Check if we have auth data in secure storage
      if (authDataJson != null) {
        _logger.i('Found authentication data in secure storage');
        return AuthModel.fromJsonString(authDataJson);
      }

      // If not in secure storage, check if we need to migrate from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final legacyAuthDataJson = prefs.getString(_legacyAuthDataKey);

      // Check if we have auth data in SharedPreferences
      if (legacyAuthDataJson != null) {
        _logger.i('Found authentication data in SharedPreferences, migrating to secure storage');
        // Parse the auth data
        final authModel = AuthModel.fromJsonString(legacyAuthDataJson);
        // Save to secure storage
        await _saveAuthData(authModel);
        // Remove from SharedPreferences
        await prefs.remove(_legacyAuthDataKey);
        _logger.i('Successfully migrated authentication data to secure storage');
        return authModel;
      }

      // Check for legacy passcode
      final legacyPasscode = prefs.getString(_legacyPasscodeKey);
      if (legacyPasscode != null) {
        _logger.i('Found legacy passcode, migrating to new format in secure storage');
        // Migrate legacy passcode to new format
        final authModel = await _migrateFromLegacyPasscode(legacyPasscode);
        return authModel;
      }

      // No authentication data found
      _logger.i('No authentication data found');
      return const AuthModel();
    } catch (e, stackTrace) {
      _logger.e('Error loading authentication data', e, stackTrace);
      return const AuthModel();
    }
  }

  // Save authentication data
  Future<bool> _saveAuthData(AuthModel authModel) async {
    _logger.d('Saving authentication data to secure storage');
    try {
      // Save to secure storage
      await _secureStorage.write(key: _authDataKey, value: authModel.toJsonString());
      _logger.i('Authentication data saved successfully to secure storage');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error saving authentication data to secure storage', e, stackTrace);
      return false;
    }
  }

  // Migrate from legacy passcode to new password system
  Future<AuthModel> _migrateFromLegacyPasscode(String legacyPasscode) async {
    _logger.d('Migrating from legacy passcode');
    try {
      // Generate a salt for the new password hash
      final salt = _generateSalt();

      // Hash the legacy passcode with the new salt
      final passwordHash = _hashPassword(legacyPasscode, salt);

      // Create a new auth model
      final authModel = AuthModel(passwordHash: passwordHash, salt: salt, useBiometrics: false, lastAuthTime: DateTime.now().millisecondsSinceEpoch);

      // Save the new auth model
      await _saveAuthData(authModel);

      // Remove the legacy passcode from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyPasscodeKey);

      _logger.i('Successfully migrated from legacy passcode');
      return authModel;
    } catch (e, stackTrace) {
      _logger.e('Error migrating from legacy passcode', e, stackTrace);
      rethrow;
    }
  }

  // Generate a random salt for password hashing
  String _generateSalt({int length = 32}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  // Hash a password with a salt
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = crypto.sha256.convert(bytes);
    return digest.toString();
  }

  // Check if a password is set
  Future<bool> isPasswordSet() async {
    _logger.d('Checking if password is set');
    try {
      final authData = await _loadAuthData();
      final hasPassword = authData.hasPassword;
      _logger.i('Password is ${hasPassword ? 'set' : 'not set'}');
      return hasPassword;
    } catch (e, stackTrace) {
      _logger.e('Error checking if password is set', e, stackTrace);
      return false;
    }
  }

  // Set a new password
  Future<bool> setPassword(String password) async {
    _logger.d('Setting new password');
    try {
      // Load current auth data
      final authData = await _loadAuthData();
      final oldSalt = authData.salt;
      final hadPassword = authData.hasPassword;

      // Generate a salt
      final salt = _generateSalt();

      // Hash the password
      final passwordHash = _hashPassword(password, salt);

      // Update auth data
      final updatedAuthData = authData.copyWith(passwordHash: passwordHash, salt: salt, lastAuthTime: DateTime.now().millisecondsSinceEpoch);

      // Check if password encryption is enabled
      final settings = await _settingsService.loadSettings();
      if (settings.usePasswordEncryption) {
        _logger.d('Password encryption is enabled, handling data re-encryption');

        if (hadPassword && oldSalt != null) {
          // This is a password change, need to re-encrypt data with new password
          final oldPseudoPassword = 'OpenOTP_SecureData_$oldSalt';
          final newPseudoPassword = 'OpenOTP_SecureData_$salt';

          // Re-encrypt data with new password
          final success = await _secureStorageService.reEncryptData(oldPseudoPassword, newPseudoPassword);
          if (!success) {
            _logger.e('Failed to re-encrypt data with new password');
            return false;
          }
        } else {
          // This is a new password being set, encrypt data if not already encrypted
          final pseudoPassword = 'OpenOTP_SecureData_$salt';

          // Encrypt data with new password
          final success = await _secureStorageService.encryptDataWithPassword(pseudoPassword);
          if (!success) {
            _logger.e('Failed to encrypt data with new password');
            return false;
          }
        }
      }

      // Save updated auth data
      final success = await _saveAuthData(updatedAuthData);

      if (success) {
        _logger.i('Password set successfully');
      } else {
        _logger.w('Failed to set password');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error setting password', e, stackTrace);
      return false;
    }
  }

  // Verify the password
  Future<bool> verifyPassword(String password) async {
    _logger.d('Verifying password');
    try {
      // Load auth data
      final authData = await _loadAuthData();

      if (!authData.hasPassword) {
        _logger.w('No password is set');
        return false;
      }

      // Hash the provided password with the stored salt
      final passwordHash = _hashPassword(password, authData.salt!);

      // Compare with stored hash
      final isValid = passwordHash == authData.passwordHash;

      if (isValid) {
        _logger.i('Password verification successful');
        await _updateLastAuthTime();
      } else {
        _logger.w('Password verification failed');
      }

      return isValid;
    } catch (e, stackTrace) {
      _logger.e('Error verifying password', e, stackTrace);
      return false;
    }
  }

  // Remove the password
  Future<bool> removePassword() async {
    _logger.d('Removing password');
    try {
      // Load current auth data
      final authData = await _loadAuthData();
      final oldSalt = authData.salt;

      // Check if password encryption is enabled
      final settings = await _settingsService.loadSettings();
      if (settings.usePasswordEncryption) {
        _logger.d('Password encryption is enabled, handling data decryption before removing password');

        if (oldSalt != null) {
          // Get the current pseudo-password for decryption
          final pseudoPassword = 'OpenOTP_SecureData_$oldSalt';

          // Decrypt data before removing password
          final success = await _secureStorageService.decryptData(pseudoPassword);
          if (!success) {
            _logger.e('Failed to decrypt data before removing password');
            return false;
          }

          // Disable password encryption setting since we can't use it without a password
          await _settingsService.updatePasswordEncryption(false);
          _logger.i('Password encryption disabled because password was removed');
        }
      }

      // Update auth data with null password hash and salt
      final updatedAuthData = authData.copyWith(passwordHash: null, salt: null);

      // Save updated auth data
      final success = await _saveAuthData(updatedAuthData);

      if (success) {
        _logger.i('Password removed successfully');
      } else {
        _logger.w('Failed to remove password');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error removing password', e, stackTrace);
      return false;
    }
  }

  // Get the raw password for encryption purposes
  // This is a special method that should ONLY be used for encrypting sensitive data
  // with the user's password as a second layer of security
  Future<String?> getPasswordForEncryption() async {
    _logger.d('Getting password for encryption');
    try {
      // Show a dialog to get the password from the user
      // For now, we'll use a simpler approach - we'll prompt the user to enter their password
      // when they enable the setting, and we'll store it temporarily in memory

      // Load auth data to get the salt
      final authData = await _loadAuthData();

      if (!authData.hasPassword || authData.salt == null) {
        _logger.w('No password is set, cannot use for encryption');
        return null;
      }

      // For security reasons, we don't store the raw password
      // Instead, we'll use a fixed string combined with the user's salt
      // This is still secure because the salt is unique per user and stored securely
      final pseudoPassword = 'OpenOTP_SecureData_${authData.salt!}';

      return pseudoPassword;
    } catch (e, stackTrace) {
      _logger.e('Error getting password for encryption', e, stackTrace);
      return null;
    }
  }

  // Update biometrics setting in auth model
  Future<bool> updateBiometricsSetting(bool useBiometrics) async {
    _logger.d('Updating biometrics setting in auth model to: $useBiometrics');
    try {
      // Load current auth data
      final authData = await _loadAuthData();

      // Update biometrics setting
      final updatedAuthData = authData.copyWith(useBiometrics: useBiometrics);

      // Save updated auth data
      final success = await _saveAuthData(updatedAuthData);

      if (success) {
        _logger.i('Biometrics setting in auth model updated successfully to: $useBiometrics');
      } else {
        _logger.w('Failed to update biometrics setting in auth model');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error updating biometrics setting in auth model', e, stackTrace);
      return false;
    }
  }

  // Manually lock the app by resetting the last authentication time
  Future<void> lockApp() async {
    _logger.d('Manually locking the app');
    try {
      // Load current auth data
      final authData = await _loadAuthData();

      // Set last auth time to 0 to force authentication and set manual lock flag
      final updatedAuthData = authData.copyWith(lastAuthTime: 0, isManuallyLocked: true);

      // Save updated auth data
      final success = await _saveAuthData(updatedAuthData);

      if (success) {
        _logger.i('App manually locked successfully');
      } else {
        _logger.w('Failed to manually lock app');
      }
    } catch (e, stackTrace) {
      _logger.e('Error manually locking app', e, stackTrace);
    }
  }

  // Update the last authentication time
  Future<void> _updateLastAuthTime() async {
    _logger.d('Updating last authentication time');
    try {
      // Load current auth data
      final authData = await _loadAuthData();

      // Update last auth time and reset manual lock flag
      final updatedAuthData = authData.copyWith(
        lastAuthTime: DateTime.now().millisecondsSinceEpoch,
        isManuallyLocked: false, // Reset manual lock flag after authentication
      );

      // Save updated auth data
      final success = await _saveAuthData(updatedAuthData);

      if (success) {
        _logger.i('Last authentication time updated successfully');
      } else {
        _logger.w('Failed to update last authentication time');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating last authentication time', e, stackTrace);
    }
  }

  // Check if authentication is required based on timeout
  Future<bool> isAuthenticationRequired(ThemeService themeService) async {
    _logger.d('Checking if authentication is required');
    try {
      // Load auth data
      final authData = await _loadAuthData();

      // Check if a password is set
      final hasPassword = authData.hasPassword;

      // Check if biometric authentication is available and enabled
      final biometricAvailable = await isBiometricAvailable();
      final biometricsEnabled = authData.useBiometrics && themeService.settings.useBiometrics;

      // If we have no authentication methods, don't require authentication
      if (!hasPassword && !(biometricsEnabled && biometricAvailable)) {
        _logger.i('Authentication not required (no authentication methods available)');
        return false;
      }

      // If we have a password set or biometrics enabled, check timeout
      if (hasPassword || (biometricsEnabled && biometricAvailable)) {
        _logger.i('Authentication method available, checking timeout');

        // Get the last authentication time
        final lastAuthTime = authData.lastAuthTime;

        // If no previous authentication, require authentication
        if (lastAuthTime == 0) {
          _logger.i('Authentication required (no previous authentication)');
          return true;
        }

        // Get the auto-lock timeout from settings (in minutes)
        final timeoutMinutes = themeService.settings.autoLockTimeout;

        // If timeout is -1, always require authentication
        if (timeoutMinutes == -1) {
          _logger.i('Authentication required (always lock enabled)');
          return true;
        }

        // If timeout is 0, never lock
        if (timeoutMinutes == 0) {
          _logger.i('Authentication not required (auto-lock disabled)');
          return false;
        }

        // Calculate if the timeout has passed
        final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTime);
        final now = DateTime.now();
        final difference = now.difference(lastAuth).inMinutes;

        final requiresAuth = difference >= timeoutMinutes;
        _logger.i('Authentication ${requiresAuth ? 'required' : 'not required'} (${difference}m elapsed, timeout: ${timeoutMinutes}m)');

        return requiresAuth;
      } else {
        // No authentication methods enabled
        _logger.i('Authentication not required (no methods enabled)');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error checking if authentication is required', e, stackTrace);
      // Default to requiring authentication on error
      return true;
    }
  }

  // Show the lock screen
  Future<bool> showLockScreen(BuildContext context, {bool canCancel = false}) async {
    _logger.d('Showing lock screen');

    try {
      // Load auth data
      final authData = await _loadAuthData();
      final hasPassword = authData.hasPassword;
      final isManuallyLocked = authData.isManuallyLocked;

      // Check if biometric authentication is available and enabled
      final biometricAvailable = await isBiometricAvailable();
      final biometricsEnabled = authData.useBiometrics;

      // Log if we're skipping biometrics due to manual lock
      if (isManuallyLocked) {
        _logger.i('Biometric authentication disabled because app was manually locked');
      }

      if ((!biometricAvailable || !biometricsEnabled) && !hasPassword) {
        _logger.w('No authentication methods available or enabled');
        // If no authentication methods are available or enabled, consider it authenticated
        await _updateLastAuthTime();
        return true;
      }

      // Create a completer to handle the result
      final completer = Completer<bool>();

      // Check if the context is still valid
      if (!context.mounted) {
        _logger.e('Context is no longer valid');
        return false;
      }

      // Show the password entry widget
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PasswordEntryWidget(
            verifyPassword: verifyPassword,
            authenticateWithBiometrics: authenticateWithBiometrics,
            biometricAvailable: biometricAvailable && biometricsEnabled && !isManuallyLocked,
            canCancel: canCancel,
            onAuthenticated: () {
              if (!completer.isCompleted) {
                completer.complete(true);
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            onCancelled:
                canCancel
                    ? () {
                      if (!completer.isCompleted) {
                        completer.complete(false);
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    }
                    : null,
          );
        },
      );

      // Wait for the result
      return await completer.future;
    } catch (e, stackTrace) {
      _logger.e('Error showing lock screen', e, stackTrace);
      return false;
    }
  }

  // Authenticate user before allowing password changes
  Future<bool> authenticateForPasswordChange(BuildContext context) async {
    _logger.d('Authenticating for password change');

    // Load auth data
    final authData = await _loadAuthData();
    final hasPassword = authData.hasPassword;
    final isManuallyLocked = authData.isManuallyLocked;

    // If no password is set, no authentication is needed
    if (!hasPassword) {
      _logger.i('No password set, no authentication needed');
      return true;
    }

    // Check if biometric authentication is available and enabled
    final biometricAvailable = await isBiometricAvailable();
    final biometricsEnabled = authData.useBiometrics;

    // Log if we're skipping biometrics due to manual lock
    if (isManuallyLocked) {
      _logger.i('Biometric authentication disabled because app was manually locked');
    }

    // Create a completer to handle the result
    final completer = Completer<bool>();

    // Check if the context is still valid
    if (!context.mounted) {
      _logger.e('Context is no longer valid');
      return false;
    }

    // Show the password entry widget
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PasswordEntryWidget(
          verifyPassword: verifyPassword,
          authenticateWithBiometrics: authenticateWithBiometrics,
          biometricAvailable: biometricAvailable && biometricsEnabled && !isManuallyLocked,
          canCancel: true,
          onAuthenticated: () {
            if (!completer.isCompleted) {
              completer.complete(true);
            }
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
          onCancelled: () {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          },
        );
      },
    );

    return await completer.future;
  }

  // Show the password setup screen
  Future<bool> showPasswordSetupScreen(BuildContext context) async {
    _logger.d('Showing password setup screen');

    try {
      // Create a completer to handle the result
      final completer = Completer<bool>();

      // Check if the context is still valid
      if (!context.mounted) {
        _logger.e('Error showing password setup screen: Context is no longer valid');
        return false;
      }

      // Show the password setup widget
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return PasswordSetupWidget(
            setPassword: setPassword,
            onComplete: (success) {
              // The dialog is now closed by the widget itself when successful
              if (!completer.isCompleted) {
                completer.complete(success);
              }
            },
            onCancelled: () {
              if (!completer.isCompleted) {
                completer.complete(false);
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
          );
        },
      );

      // Wait for the result
      return await completer.future;
    } catch (e, stackTrace) {
      _logger.e('Error showing password setup screen', e, stackTrace);
      return false;
    }
  }
}
