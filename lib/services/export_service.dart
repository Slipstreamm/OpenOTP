import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:openotp/services/crypto_service.dart';
import 'package:openotp/services/logger_service.dart';
import 'package:openotp/services/secure_storage_service.dart';
import 'package:openotp/services/settings_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for exporting OTP entries and settings to a file
class ExportService {
  final LoggerService _logger = LoggerService();
  final CryptoService _cryptoService = CryptoService();
  final SecureStorageService _storageService = SecureStorageService();
  final SettingsService _settingsService = SettingsService();

  // Singleton pattern
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Export data to a file
  /// [includeOtpEntries] - Whether to include OTP entries in the export
  /// [includeSettings] - Whether to include settings in the export
  /// [encrypt] - Whether to encrypt the export
  /// [password] - Password for encryption (required if encrypt is true)
  Future<bool> exportToFile({required bool includeOtpEntries, required bool includeSettings, required bool encrypt, String? password}) async {
    _logger.d('Exporting data to file');

    try {
      // Validate parameters
      if (encrypt && (password == null || password.isEmpty)) {
        _logger.w('Encryption requested but no password provided');
        return false;
      }

      if (!includeOtpEntries && !includeSettings) {
        _logger.w('Nothing to export');
        return false;
      }

      // Prepare export data
      final exportData = await _prepareExportData(includeOtpEntries: includeOtpEntries, includeSettings: includeSettings);

      // Convert to JSON string
      final jsonString = jsonEncode(exportData);

      // Encrypt if requested
      final fileContent = encrypt ? await _encryptExportData(jsonString, password!) : jsonString;

      // Save to file
      final success = await _saveToFile(fileContent, encrypt);

      if (success) {
        _logger.i('Data exported successfully');
      } else {
        _logger.w('Failed to export data');
      }

      return success;
    } catch (e, stackTrace) {
      _logger.e('Error exporting data', e, stackTrace);
      return false;
    }
  }

  /// Prepare the data to be exported
  Future<Map<String, dynamic>> _prepareExportData({required bool includeOtpEntries, required bool includeSettings}) async {
    _logger.d('Preparing export data');

    final Map<String, dynamic> exportData = {'exportVersion': '1.0', 'exportTimestamp': DateTime.now().toIso8601String()};

    // Add OTP entries if requested
    if (includeOtpEntries) {
      final otpEntries = await _storageService.getOtpEntries();
      exportData['otpEntries'] = otpEntries.map((entry) => entry.toJson()).toList();
      _logger.d('Added ${otpEntries.length} OTP entries to export');
    }

    // Add settings if requested
    if (includeSettings) {
      final settings = await _settingsService.loadSettings();
      exportData['settings'] = settings.toJson();
      _logger.d('Added settings to export');
    }

    return exportData;
  }

  /// Encrypt the export data
  Future<String> _encryptExportData(String data, String password) async {
    _logger.d('Encrypting export data');

    // The CryptoService now automatically handles salt generation and storage
    final encryptedData = await _cryptoService.encrypt(data, password);

    // Create a wrapper to indicate this is encrypted data
    final wrapper = {'encrypted': true, 'data': encryptedData};

    return jsonEncode(wrapper);
  }

  /// Save the export data to a file
  Future<bool> _saveToFile(String data, bool encrypted) async {
    _logger.d('Saving export data to file');

    try {
      final fileName = 'openotp_export_${DateTime.now().millisecondsSinceEpoch}${encrypted ? '_encrypted' : ''}.json';

      // Use platform-specific approach
      if (Platform.isAndroid || Platform.isIOS) {
        return await _saveToFileMobile(data, fileName);
      } else {
        return await _saveToFileDesktop(data, fileName);
      }
    } catch (e, stackTrace) {
      _logger.e('Error saving export to file', e, stackTrace);
      return false;
    }
  }

  /// Save the export data to a file on desktop platforms
  Future<bool> _saveToFileDesktop(String data, String fileName) async {
    _logger.d('Saving export data to file on desktop');

    try {
      // Get save location from user
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save OTP Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile == null) {
        _logger.d('User cancelled file save');
        return false;
      }

      // Ensure the file has .json extension
      if (!outputFile.toLowerCase().endsWith('.json')) {
        outputFile += '.json';
      }

      // Write to file
      final file = File(outputFile);
      await file.writeAsString(data);

      _logger.i('Export saved to: $outputFile');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error saving export to file on desktop', e, stackTrace);
      return false;
    }
  }

  /// Save the export data to a file on mobile platforms
  Future<bool> _saveToFileMobile(String data, String fileName) async {
    _logger.d('Saving export data to file on mobile');

    try {
      // Get the temporary directory path
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';

      // Write to temporary file
      final file = File(filePath);
      await file.writeAsString(data);

      _logger.i('Export saved to temporary file: $filePath');

      // Share the file
      final result = await Share.shareXFiles([XFile(filePath)], subject: 'OpenOTP Export', text: 'Your OpenOTP export file');

      _logger.i('Share result: ${result.status}');

      // Consider the export successful if the share dialog was shown
      return result.status == ShareResultStatus.success || result.status == ShareResultStatus.dismissed;
    } catch (e, stackTrace) {
      _logger.e('Error saving export to file on mobile', e, stackTrace);
      return false;
    }
  }

  /// Import data from a file
  /// [filePath] - Path to the file to import
  /// [password] - Password for decryption (if the file is encrypted)
  Future<Map<String, dynamic>?> importFromFile({required String filePath, String? password}) async {
    _logger.d('Importing data from file: $filePath');

    try {
      // Read file
      final file = File(filePath);
      final fileContent = await file.readAsString();

      // Process the content
      return await importFromString(content: fileContent, password: password);
    } catch (e, stackTrace) {
      _logger.e('Error importing data from file', e, stackTrace);
      return null;
    }
  }

  /// Import data from a string (pasted content)
  /// [content] - The string content to import
  /// [password] - Password for decryption (if the content is encrypted)
  Future<Map<String, dynamic>?> importFromString({required String content, String? password}) async {
    _logger.d('Importing data from string');

    try {
      // Parse JSON
      final jsonData = jsonDecode(content);

      // Check if the data is encrypted
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('encrypted') && jsonData['encrypted'] == true) {
        _logger.d('Data is encrypted, attempting to decrypt');

        if (password == null || password.isEmpty) {
          _logger.w('Encrypted data but no password provided');
          return null;
        }

        // Decrypt the data
        // The CryptoService now automatically handles salt extraction from the encrypted data
        // and supports both legacy (fixed salt) and new (dynamic salt) formats
        final encryptedData = jsonData['data'];
        final decryptedData = await _cryptoService.decrypt(encryptedData, password);

        // Parse the decrypted JSON
        return jsonDecode(decryptedData);
      } else {
        // Data is not encrypted
        _logger.d('Data is not encrypted');
        return jsonData;
      }
    } catch (e, stackTrace) {
      _logger.e('Error importing data from string', e, stackTrace);
      return null;
    }
  }
}
