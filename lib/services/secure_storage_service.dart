import 'dart:convert';
import 'dart:async' show Future;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/otp_entry.dart';
import '../utils/base32_utils.dart';
import 'auth_service.dart' deferred as auth;
import 'crypto_service.dart';
import 'logger_service.dart';
import 'settings_service.dart';

class SecureStorageService {
  static const String _otpEntriesKey = 'otp_entries';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LoggerService _logger = LoggerService();
  final CryptoService _cryptoService = CryptoService();
  final SettingsService _settingsService = SettingsService();

  // Save all OTP entries
  Future<void> saveOtpEntries(List<OtpEntry> entries) async {
    _logger.d('Saving ${entries.length} OTP entries');
    try {
      final entriesJson = entries.map((entry) => entry.toJson()).toList();
      final entriesString = jsonEncode(entriesJson);
      _logger.d('Converted OTP entries to JSON string');

      // Check if password encryption is enabled
      final settings = await _settingsService.loadSettings();

      // Load AuthService using deferred import to avoid circular dependency
      await auth.loadLibrary();
      final authService = auth.AuthService();
      final hasPassword = await authService.isPasswordSet();

      if (hasPassword) {
        _logger.i('Password is set');
      }

      if (settings.usePasswordEncryption && hasPassword) {
        _logger.d('Using password encryption for OTP entries');
        // Get the current password
        final password = await authService.getPasswordForEncryption();
        if (password != null) {
          try {
            // Encrypt the entries string with the password
            final encryptedData = await _cryptoService.encrypt(entriesString, password);
            _logger.d('Data encrypted successfully, saving to secure storage');
            await _secureStorage.write(key: _otpEntriesKey, value: encryptedData);
            _logger.i('Successfully saved ${entries.length} OTP entries with password encryption');
            return;
          } catch (encryptError, encryptStackTrace) {
            _logger.e('Error encrypting OTP entries', encryptError, encryptStackTrace);
            _logger.w('Falling back to standard storage due to encryption error');
          }
        } else {
          _logger.w('Failed to get password for encryption, falling back to standard storage');
        }
      }

      // Standard storage without password encryption
      await _secureStorage.write(key: _otpEntriesKey, value: entriesString);
      _logger.i('Successfully saved ${entries.length} OTP entries without encryption');
    } catch (e, stackTrace) {
      _logger.e('Error saving OTP entries', e, stackTrace);
      rethrow;
    }
  }

  // Get all OTP entries
  Future<List<OtpEntry>> getOtpEntries() async {
    _logger.d('Getting all OTP entries');
    try {
      final entriesString = await _secureStorage.read(key: _otpEntriesKey);
      if (entriesString == null || entriesString.isEmpty) {
        _logger.i('No OTP entries found in storage');
        return [];
      }

      // Check if the data is encrypted with password
      final settings = await _settingsService.loadSettings();

      // Load AuthService using deferred import to avoid circular dependency
      await auth.loadLibrary();
      final authService = auth.AuthService();
      final hasPassword = await authService.isPasswordSet();

      String decodedString = entriesString;

      // Check if the data is encrypted
      bool isEncrypted = false;
      try {
        // Try to parse the data as JSON
        final jsonData = jsonDecode(entriesString);

        // If it parses as a Map with encryption-related fields, it's likely encrypted
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('version') && jsonData.containsKey('iv') && jsonData.containsKey('data')) {
          _logger.d('Data appears to be encrypted (has encryption fields)');
          isEncrypted = true;
        }
      } catch (e) {
        // If parsing fails, it might be encrypted or corrupted
        _logger.d('Data is not valid JSON, might be encrypted or corrupted');
        isEncrypted = true;
      }

      // Handle encrypted data if needed
      if (isEncrypted && settings.usePasswordEncryption && hasPassword) {
        _logger.d('Attempting to decrypt OTP entries with password');
        try {
          // Get the current password
          final password = await authService.getPasswordForEncryption();
          if (password != null) {
            // Decrypt the entries string with the password
            decodedString = await _cryptoService.decrypt(entriesString, password);
            _logger.i('Successfully decrypted OTP entries with password');
          } else {
            _logger.w('Failed to get password for decryption');
            return [];
          }
        } catch (decryptError) {
          _logger.e('Error decrypting OTP entries', decryptError);
          return [];
        }
      } else if (isEncrypted) {
        // If it's encrypted but we can't decrypt it (no password or encryption disabled)
        _logger.e('Data appears to be encrypted but cannot be decrypted (password not set or encryption disabled)');
        return [];
      }

      // Parse the decoded string
      _logger.d('Parsing decoded OTP entries data');
      final decodedJson = jsonDecode(decodedString);

      // Check if the decoded JSON is a List or a Map
      if (decodedJson is List) {
        // It's already a list of entries
        final entries = decodedJson.map((entryJson) => OtpEntry.fromJson(entryJson)).toList();
        _logger.i('Retrieved ${entries.length} OTP entries');
        return entries;
      } else if (decodedJson is Map<String, dynamic>) {
        // It might be a wrapped object, check if it contains an 'otpEntries' field
        if (decodedJson.containsKey('otpEntries') && decodedJson['otpEntries'] is List) {
          final entriesJson = decodedJson['otpEntries'] as List;
          final entries = entriesJson.map((entryJson) => OtpEntry.fromJson(entryJson)).toList();
          _logger.i('Retrieved ${entries.length} OTP entries from wrapped object');
          return entries;
        } else {
          // Log the structure to help diagnose the issue
          _logger.w('Decoded JSON is a Map but does not contain expected structure: ${decodedJson.keys.join(', ')}');
          return [];
        }
      } else {
        _logger.e('Unexpected JSON structure: ${decodedJson.runtimeType}');
        return [];
      }
    } catch (e, stackTrace) {
      _logger.e('Error getting OTP entries', e, stackTrace);
      // Return empty list in case of error to prevent app crashes
      return [];
    }
  }

  // Add a new OTP entry
  Future<void> addOtpEntry(OtpEntry entry) async {
    _logger.d('Adding new OTP entry: ${entry.name}');
    try {
      final entries = await getOtpEntries();
      entries.add(entry);
      await saveOtpEntries(entries);
      _logger.i('Successfully added OTP entry: ${entry.name}');
    } catch (e, stackTrace) {
      _logger.e('Error adding OTP entry: ${entry.name}', e, stackTrace);
      rethrow;
    }
  }

  // Update an existing OTP entry
  Future<void> updateOtpEntry(OtpEntry updatedEntry) async {
    _logger.d('Updating OTP entry: ${updatedEntry.name} (ID: ${updatedEntry.id})');
    try {
      final entries = await getOtpEntries();
      final index = entries.indexWhere((entry) => entry.id == updatedEntry.id);
      if (index != -1) {
        _logger.d('Found OTP entry to update at index $index');
        entries[index] = updatedEntry;
        await saveOtpEntries(entries);
        _logger.i('Successfully updated OTP entry: ${updatedEntry.name}');
      } else {
        _logger.w('OTP entry not found for update: ${updatedEntry.id}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating OTP entry: ${updatedEntry.name}', e, stackTrace);
      rethrow;
    }
  }

  // Delete an OTP entry
  Future<void> deleteOtpEntry(String id) async {
    _logger.d('Deleting OTP entry with ID: $id');
    try {
      final entries = await getOtpEntries();
      final initialCount = entries.length;
      entries.removeWhere((entry) => entry.id == id);

      if (initialCount != entries.length) {
        await saveOtpEntries(entries);
        _logger.i('Successfully deleted OTP entry with ID: $id');
      } else {
        _logger.w('OTP entry not found for deletion: $id');
      }
    } catch (e, stackTrace) {
      _logger.e('Error deleting OTP entry with ID: $id', e, stackTrace);
      rethrow;
    }
  }

  // Re-encrypt data with a new password
  Future<bool> reEncryptData(String oldPassword, String newPassword) async {
    _logger.d('Re-encrypting data with new password');
    try {
      // First, get the current data using the old password
      final entries = await getOtpEntries();
      if (entries.isEmpty) {
        _logger.i('No data to re-encrypt');
        return true; // Nothing to do, consider it a success
      }

      // Convert entries to JSON string
      final entriesJson = entries.map((entry) => entry.toJson()).toList();
      final entriesString = jsonEncode(entriesJson);

      // Encrypt with the new password
      final encryptedData = await _cryptoService.encrypt(entriesString, newPassword);

      // Save the re-encrypted data
      await _secureStorage.write(key: _otpEntriesKey, value: encryptedData);
      _logger.i('Successfully re-encrypted data with new password');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error re-encrypting data', e, stackTrace);
      return false;
    }
  }

  // Encrypt data with password (when enabling password encryption)
  Future<bool> encryptDataWithPassword(String password) async {
    _logger.d('Encrypting data with password');
    try {
      // First, get the current data (unencrypted)
      final entriesString = await _secureStorage.read(key: _otpEntriesKey);
      if (entriesString == null || entriesString.isEmpty) {
        _logger.i('No data to encrypt');
        return true; // Nothing to do, consider it a success
      }

      // Try to parse as JSON to check if it's already encrypted
      try {
        jsonDecode(entriesString);
        // If we get here, it's valid JSON and not encrypted

        // Encrypt with the password
        final encryptedData = await _cryptoService.encrypt(entriesString, password);

        // Save the encrypted data
        await _secureStorage.write(key: _otpEntriesKey, value: encryptedData);
        _logger.i('Successfully encrypted data with password');
        return true;
      } catch (e) {
        // If parsing fails, it might already be encrypted
        _logger.w('Data might already be encrypted or is in an invalid format');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('Error encrypting data with password', e, stackTrace);
      return false;
    }
  }

  // Decrypt data (when disabling password encryption)
  Future<bool> decryptData(String password) async {
    _logger.d('Decrypting data (removing password encryption)');
    try {
      // Get the current entries (this will handle decryption if needed)
      final entries = await getOtpEntries();
      if (entries.isEmpty) {
        _logger.i('No data to decrypt');
        return true; // Nothing to do, consider it a success
      }

      // Convert entries to JSON string (unencrypted)
      final entriesJson = entries.map((entry) => entry.toJson()).toList();
      final entriesString = jsonEncode(entriesJson);

      // Save the unencrypted data
      await _secureStorage.write(key: _otpEntriesKey, value: entriesString);
      _logger.i('Successfully removed password encryption from data');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error decrypting data', e, stackTrace);
      return false;
    }
  }

  /// Checks for and removes any OTP entries with invalid secret keys
  /// Returns the number of entries that were removed
  Future<int> cleanupInvalidEntries() async {
    _logger.d('Checking for OTP entries with invalid secret keys');
    try {
      // Get all entries
      final entries = await getOtpEntries();
      if (entries.isEmpty) {
        _logger.i('No OTP entries to check');
        return 0;
      }

      final initialCount = entries.length;

      // Filter out entries with invalid secret keys
      entries.removeWhere((entry) {
        final isValid = Base32Utils.isValidBase32(entry.secret) && Base32Utils.canDecode(entry.secret);
        if (!isValid) {
          _logger.w('Removing invalid OTP entry: ${entry.name} (ID: ${entry.id})');
        }
        return !isValid;
      });

      // If any entries were removed, save the updated list
      final removedCount = initialCount - entries.length;
      if (removedCount > 0) {
        _logger.i('Removed $removedCount OTP entries with invalid secret keys');
        await saveOtpEntries(entries);
      } else {
        _logger.i('No invalid OTP entries found');
      }

      return removedCount;
    } catch (e, stackTrace) {
      _logger.e('Error cleaning up invalid OTP entries', e, stackTrace);
      return 0;
    }
  }

  /// Wipes all OTP entries from secure storage
  /// Returns true if successful, false otherwise
  Future<bool> wipeAllOtpEntries() async {
    _logger.d('Wiping all OTP entries from secure storage');
    try {
      // Delete the OTP entries key from secure storage
      await _secureStorage.delete(key: _otpEntriesKey);
      _logger.i('Successfully wiped all OTP entries from secure storage');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error wiping OTP entries from secure storage', e, stackTrace);
      return false;
    }
  }
}
