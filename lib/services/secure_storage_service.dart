import 'dart:convert';
import 'dart:async' show Future;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/otp_entry.dart';
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

      // Check if password encryption is enabled
      final settings = await _settingsService.loadSettings();

      // Load AuthService using deferred import to avoid circular dependency
      await auth.loadLibrary();
      final authService = auth.AuthService();
      final hasPassword = await authService.isPasswordSet();

      if (settings.usePasswordEncryption && hasPassword) {
        _logger.d('Using password encryption for OTP entries');
        // Get the current password
        final password = await authService.getPasswordForEncryption();
        if (password != null) {
          // Encrypt the entries string with the password
          final encryptedData = await _cryptoService.encrypt(entriesString, password);
          await _secureStorage.write(key: _otpEntriesKey, value: encryptedData);
          _logger.i('Successfully saved ${entries.length} OTP entries with password encryption');
          return;
        } else {
          _logger.w('Failed to get password for encryption, falling back to standard storage');
        }
      }

      // Standard storage without password encryption
      await _secureStorage.write(key: _otpEntriesKey, value: entriesString);
      _logger.i('Successfully saved ${entries.length} OTP entries');
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

      // Try to parse as JSON to check if it's encrypted
      try {
        // If this succeeds without error, it's likely not encrypted with password
        jsonDecode(entriesString);
      } catch (e) {
        // If parsing fails, it might be encrypted with password
        if (settings.usePasswordEncryption && hasPassword) {
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
        } else {
          // If not using password encryption but data is not valid JSON, something is wrong
          _logger.e('OTP entries data is corrupted or in unknown format');
          return [];
        }
      }

      final entriesJson = jsonDecode(decodedString) as List;
      final entries = entriesJson.map((entryJson) => OtpEntry.fromJson(entryJson)).toList();
      _logger.i('Retrieved ${entries.length} OTP entries');
      return entries;
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
}
