import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:openotp/services/crypto_service.dart';
import 'package:openotp/services/logger_service.dart';
import 'package:openotp/services/secure_storage_service.dart';
import 'package:openotp/services/settings_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mime/mime.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for exporting OTP entries and settings to a file
class ExportService {
  final LoggerService _logger = LoggerService();
  final CryptoService _cryptoService = CryptoService();
  final SecureStorageService _storageService = SecureStorageService();
  final SettingsService _settingsService = SettingsService();

  // Track the last export file path
  String? _lastExportFilePath;

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

  /// Open a file with the system's default app
  Future<bool> openFile(String filePath) async {
    _logger.d('Attempting to open file: $filePath');

    try {
      // First, ensure the file has the correct MIME type
      await _ensureFileIsOpenable(filePath);

      // Try to open with url_launcher first
      try {
        final uri = Uri.file(filePath);
        final canOpen = await canLaunchUrl(uri);

        if (canOpen) {
          final launched = await launchUrl(uri);
          if (launched) {
            _logger.i('File opened successfully with url_launcher');
            return true;
          }
        }
      } catch (e) {
        _logger.w('Could not open file with url_launcher: $e');
      }

      // On Android, we now save directly to the filesystem, so we don't need to share
      // But as a fallback, we'll still use Share.shareXFiles if url_launcher fails
      // This allows the user to open the file with a compatible app or save it to a different location
      final file = XFile(filePath, mimeType: 'application/json');
      final result = await Share.shareXFiles(
        [file],
        subject: 'OpenOTP Export',
        text: 'Your OpenOTP export file',
        sharePositionOrigin: Rect.fromLTWH(0, 0, 10, 10), // This is required but not used on mobile
      );

      _logger.i('Open file result: ${result.status}');
      return result.status == ShareResultStatus.success;
    } catch (e, stackTrace) {
      _logger.e('Error opening file', e, stackTrace);
      return false;
    }
  }

  /// Open the directory containing the file
  Future<bool> openFileDirectory(String filePath) async {
    _logger.d('Attempting to open directory containing file: $filePath');

    try {
      final file = File(filePath);
      final directory = file.parent.path;

      // Try to open the directory with url_launcher
      final uri = Uri.directory(directory);
      final canOpen = await canLaunchUrl(uri);

      if (canOpen) {
        final launched = await launchUrl(uri);
        if (launched) {
          _logger.i('Directory opened successfully');
          return true;
        }
      }

      _logger.w('Could not open directory with url_launcher');
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error opening directory', e, stackTrace);
      return false;
    }
  }

  /// Ensure the file can be opened by a text editor or JSON viewer
  Future<void> _ensureFileIsOpenable(String filePath) async {
    _logger.d('Ensuring file is openable: $filePath');

    try {
      final file = File(filePath);

      // Check if the file exists
      if (!await file.exists()) {
        _logger.w('File does not exist: $filePath');
        return;
      }

      // Create a .nomedia file in the same directory to prevent media scanning
      try {
        final directory = file.parent;
        final nomediaFile = File('${directory.path}/.nomedia');
        if (!await nomediaFile.exists()) {
          await nomediaFile.create();
        }
      } catch (e) {
        // Ignore errors with .nomedia file
        _logger.w('Could not create .nomedia file: $e');
      }

      // On Android, try to set file permissions to be readable
      if (Platform.isAndroid) {
        try {
          await Process.run('chmod', ['644', filePath]);
        } catch (e) {
          _logger.w('Could not set file permissions: $e');
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error ensuring file is openable', e, stackTrace);
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

      // Ensure the file has .json extension
      if (outputFile != null && !outputFile.toLowerCase().endsWith('.json')) {
        outputFile += '.json';
      }

      // Write to file
      if (outputFile == null) {
        _logger.w('No file selected for saving export');
        return false;
      }

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
      // Save to Downloads directory or app-specific directory for permanent storage
      final bool savedToStorage = await _saveToDownloadsDirectory(data, fileName);

      if (!savedToStorage) {
        _logger.w('Failed to save export file to storage');
        return false;
      }

      _logger.i('Export saved successfully to: $_lastExportFilePath');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error saving export to file on mobile', e, stackTrace);
      return false;
    }
  }

  /// Save the export data to the Downloads directory on Android
  Future<bool> _saveToDownloadsDirectory(String data, String fileName) async {
    _logger.d('Attempting to save export data to Downloads directory');

    try {
      if (Platform.isAndroid) {
        // Check Android version and request appropriate permissions
        Directory? downloadsDir;
        bool permissionGranted = false;

        // Get Android SDK version
        if (Platform.isAndroid) {
          try {
            // For Android 13+ (API 33+)
            if (await Permission.photos.status.isGranted && await Permission.videos.status.isGranted && await Permission.audio.status.isGranted) {
              permissionGranted = true;
            } else {
              // Request media permissions for Android 13+
              var mediaStatus = await [Permission.photos, Permission.videos, Permission.audio].request();

              permissionGranted = mediaStatus.values.every((status) => status.isGranted);
            }
          } catch (e) {
            _logger.e('Error checking media permissions', e);

            // Fall back to storage permission for older Android versions
            try {
              var storageStatus = await Permission.storage.request();
              permissionGranted = storageStatus.isGranted;
            } catch (e) {
              _logger.e('Error requesting storage permission', e);
            }
          }
        }

        if (!permissionGranted) {
          _logger.w('Storage permissions denied');

          // Try to save to app-specific directory as fallback
          final appDir = await getApplicationDocumentsDirectory();
          final filePath = '${appDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsString(data);
          _logger.i('Export saved to app directory as fallback: $filePath');
          _lastExportFilePath = filePath;
          return true;
        }

        // Try to get the Downloads directory
        try {
          // First try the standard Downloads directory
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            // Try alternative paths
            final directories = await getExternalStorageDirectories();
            if (directories != null && directories.isNotEmpty) {
              String path = directories[0].path;
              // Navigate to the root of external storage
              final parts = path.split('/');
              final rootIndex = parts.indexOf('Android');
              if (rootIndex > 0) {
                path = parts.sublist(0, rootIndex).join('/');
                downloadsDir = Directory('$path/Download');
              }
            }
          }

          // If we still can't find the Downloads directory, try to get the external storage directory
          if (!await downloadsDir.exists()) {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              downloadsDir = externalDir;
              _logger.i('Using external storage directory: ${externalDir.path}');
            }
          }
        } catch (e) {
          _logger.e('Error finding Downloads directory', e);
        }

        if (downloadsDir != null && await downloadsDir.exists()) {
          try {
            final filePath = '${downloadsDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsString(data);

            // Create a .nomedia file to prevent media scanning (optional)
            try {
              final nomediaFile = File('${downloadsDir.path}/.nomedia');
              if (!await nomediaFile.exists()) {
                await nomediaFile.create();
              }
            } catch (e) {
              // Ignore errors with .nomedia file
              _logger.w('Could not create .nomedia file: $e');
            }

            _logger.i('Export saved to Downloads directory: $filePath');
            _lastExportFilePath = filePath;

            // Set file permissions to be readable
            try {
              await Process.run('chmod', ['644', filePath]);
            } catch (e) {
              _logger.w('Could not set file permissions: $e');
            }

            return true;
          } catch (e) {
            _logger.e('Error writing to Downloads directory', e);
            // Fall back to app directory
          }
        } else {
          _logger.w('Downloads directory not found');
        }

        // Fallback to app-specific directory if Downloads directory is not accessible
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final filePath = '${appDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsString(data);
          _logger.i('Export saved to app directory as fallback: $filePath');
          _lastExportFilePath = filePath;
          return true;
        } catch (e) {
          _logger.e('Error saving to app directory', e);
          return false;
        }
      } else if (Platform.isIOS) {
        // On iOS, we can use the Documents directory which is accessible via Files app
        final documentsDir = await getApplicationDocumentsDirectory();
        final filePath = '${documentsDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(data);
        _logger.i('Export saved to Documents directory: $filePath');
        _lastExportFilePath = filePath;
        return true;
      }

      return false;
    } catch (e, stackTrace) {
      _logger.e('Error saving to Downloads directory', e, stackTrace);
      return false;
    }
  }

  /// Import data from a file
  /// [filePath] - Path to the file to import
  /// [password] - Password for decryption (if the file is encrypted)
  Future<Map<String, dynamic>?> importFromFile({required String filePath, String? password}) async {
    _logger.d('Importing data from file: $filePath');

    try {
      // Check if file exists and is readable
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.e('File does not exist: $filePath');
        return null;
      }

      // Log file details for debugging
      try {
        final fileSize = await file.length();
        _logger.d('File size: $fileSize bytes');

        // Check if file is readable
        final fileStats = await file.stat();
        _logger.d('File stats: ${fileStats.toString()}');
      } catch (e) {
        _logger.w('Error getting file details: $e');
      }

      // Read file
      String fileContent;
      try {
        fileContent = await file.readAsString();
        _logger.d('Successfully read file content (length: ${fileContent.length})');
      } catch (e) {
        _logger.e('Error reading file content: $e');
        return null;
      }

      // Process the content
      return await importFromString(content: fileContent, password: password);
    } catch (e, stackTrace) {
      _logger.e('Error importing data from file', e, stackTrace);
      return null;
    }
  }

  /// Get the path of the last exported file
  String? getLastExportFilePath() {
    return _lastExportFilePath;
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
