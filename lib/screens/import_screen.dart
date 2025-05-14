import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:openotp/models/otp_entry.dart';
import 'package:openotp/models/settings_model.dart';
import 'package:openotp/services/export_service.dart';
import 'package:openotp/services/logger_service.dart';
import 'package:openotp/services/secure_storage_service.dart';
import 'package:openotp/services/settings_service.dart';
import 'package:openotp/services/app_reload_service.dart';
import 'package:openotp/widgets/custom_app_bar.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> with SingleTickerProviderStateMixin {
  final LoggerService _logger = LoggerService();
  final ExportService _exportService = ExportService();
  final SecureStorageService _storageService = SecureStorageService();
  final SettingsService _settingsService = SettingsService();
  final AppReloadService _reloadService = AppReloadService();

  // Tab controller
  late TabController _tabController;

  // File import variables
  String? _selectedFilePath;
  String? _fileName;
  bool _isEncrypted = false;
  bool _fileAnalyzed = false;
  List<String> _foundJsonFiles = [];

  // Paste import variables
  final TextEditingController _pasteController = TextEditingController();
  bool _isPastedDataEncrypted = false;
  bool _pastedDataAnalyzed = false;

  // Common variables
  final TextEditingController _passwordController = TextEditingController();
  bool _importOtpEntries = true;
  bool _importSettings = true;
  bool _isImporting = false;
  String? _errorMessage;
  Map<String, dynamic>? _importData;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing ImportScreen');

    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // On Android, check for common JSON file locations
    if (Platform.isAndroid) {
      _checkCommonJsonLocations();
    }
  }

  // Check common locations for JSON files on Android
  Future<void> _checkCommonJsonLocations() async {
    _logger.d('Checking common JSON file locations on Android');

    List<String> commonPaths = ['/storage/emulated/0/Download', '/storage/emulated/0/Documents', '/storage/emulated/0'];

    List<String> tempFoundFiles = [];

    for (String path in commonPaths) {
      try {
        final dir = Directory(path);
        if (await dir.exists()) {
          _logger.d('Checking directory: $path');

          final files = dir.listSync(recursive: false);
          for (var file in files) {
            if (file is File && file.path.toLowerCase().endsWith('.json')) {
              _logger.i('Found potential JSON file: ${file.path}');
              // We'll add it to the list and validate it later
              tempFoundFiles.add(file.path);
            }
          }
        }
      } catch (e) {
        _logger.w('Error checking directory $path: $e');
      }
    }

    if (tempFoundFiles.isNotEmpty) {
      _logger.i('Found ${tempFoundFiles.length} potential JSON files in common locations');

      // Filter to only include valid JSON files
      List<String> validJsonFiles = [];
      for (String filePath in tempFoundFiles) {
        try {
          if (await _isValidJsonFile(filePath)) {
            validJsonFiles.add(filePath);
          }
        } catch (e) {
          _logger.w('Error validating JSON file: $e');
        }
      }

      _logger.i('Found ${validJsonFiles.length} valid JSON files out of ${tempFoundFiles.length} potential files');
      setState(() {
        _foundJsonFiles = validJsonFiles;
      });
    }
  }

  // Select a found JSON file
  Future<void> _selectFoundJsonFile(String filePath) async {
    _logger.d('Selected found JSON file: $filePath');

    // First validate that it's a valid JSON file
    final isValid = await _isValidJsonFile(filePath);
    if (!isValid) {
      setState(() {
        _errorMessage = 'The selected file is not a valid JSON file.';
      });
      return;
    }

    setState(() {
      _selectedFilePath = filePath;
      _fileName = filePath.split('/').last;
      _fileAnalyzed = false;
      _importData = null;
      _errorMessage = null;
    });

    _analyzeFile();
  }

  // Check if a file is a valid JSON file
  Future<bool> _isValidJsonFile(String filePath) async {
    _logger.d('Checking if file is a valid JSON file: $filePath');

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.w('File does not exist: $filePath');
        return false;
      }

      if (!filePath.toLowerCase().endsWith('.json')) {
        _logger.w('File does not have .json extension: $filePath');
        return false;
      }

      // Try to read and parse the file
      final content = await file.readAsString();
      if (content.isEmpty) {
        _logger.w('File is empty: $filePath');
        return false;
      }

      // Try to parse as JSON
      try {
        jsonDecode(content);
        _logger.i('File is a valid JSON file: $filePath');
        return true;
      } catch (e) {
        _logger.w('File is not valid JSON: $filePath - $e');
        return false;
      }
    } catch (e) {
      _logger.w('Error checking if file is valid JSON: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _passwordController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  // Handle tab change
  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        // Reset error message when switching tabs
        _errorMessage = null;
      });
    }
  }

  // Select a file for import
  Future<void> _selectFile() async {
    _logger.d('Selecting file for import');

    try {
      FilePickerResult? result;

      // Use platform-specific approach for better file system access
      if (Platform.isAndroid) {
        // On Android, we need to use a more direct approach to access all files
        // First, try with FileType.any to show all files
        result = await FilePicker.platform.pickFiles(
          type: FileType.any, // Show all files instead of just JSON
          withData: true, // Ensure we can read the file content
          lockParentWindow: true, // Improves UX on some platforms
          dialogTitle: 'Select JSON File', // More descriptive dialog title
        );

        // If a file was selected, verify it's a JSON file
        if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
          final path = result.files.single.path!;
          if (!path.toLowerCase().endsWith('.json')) {
            setState(() {
              _errorMessage = 'Please select a JSON file (with .json extension)';
            });
            return;
          }

          // Validate that it's a valid JSON file
          final isValid = await _isValidJsonFile(path);
          if (!isValid) {
            setState(() {
              _errorMessage = 'The selected file is not a valid JSON file.';
            });
            return;
          }
        }
      } else {
        // For other platforms, use the standard approach
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: true, // Ensure we can read the file content
          lockParentWindow: true, // Improves UX on some platforms
          dialogTitle: 'Select JSON File', // More descriptive dialog title
        );
      }

      _logger.d('File picker result: ${result != null ? result.files.length : 0} files selected');

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final path = result.files.single.path;
        final name = result.files.single.name;

        _logger.i('Selected file path: $path');
        _logger.i('Selected file name: $name');

        setState(() {
          _selectedFilePath = path;
          _fileName = name;
          _fileAnalyzed = false;
          _importData = null;
          _errorMessage = null;
        });

        _analyzeFile();
      } else {
        _logger.d('No file selected or file path is null');

        // On Android, if the file picker didn't return a valid result,
        // it might be due to permission issues or limitations in the file picker.
        if (Platform.isAndroid) {
          setState(() {
            _errorMessage = 'No file selected. Try using a file manager app to locate your JSON file first.';
          });
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error selecting file', e, stackTrace);
      setState(() {
        _errorMessage = 'Error selecting file: ${e.toString()}';
      });
    }
  }

  // Analyze the selected file
  Future<void> _analyzeFile() async {
    _logger.d('Analyzing selected file');

    if (_selectedFilePath == null) return;

    // Log more details about the file path to help with debugging
    _logger.d('File path details:');
    _logger.d('- Full path: $_selectedFilePath');

    try {
      final file = File(_selectedFilePath!);
      final exists = await file.exists();
      _logger.d('- File exists: $exists');

      if (!exists) {
        setState(() {
          _errorMessage = 'File not found: $_selectedFilePath';
        });
        return;
      }

      if (!_selectedFilePath!.toLowerCase().endsWith('.json')) {
        setState(() {
          _errorMessage = 'Selected file is not a JSON file. Please select a file with .json extension.';
        });
        return;
      }

      final size = await file.length();
      _logger.d('- File size: $size bytes');

      if (size == 0) {
        setState(() {
          _errorMessage = 'Selected file is empty.';
        });
        return;
      }
    } catch (e) {
      _logger.w('Error checking file details: $e');
      setState(() {
        _errorMessage = 'Error accessing file: ${e.toString()}';
      });
      return;
    }

    try {
      // Try to read the file without decryption first to determine if it's encrypted
      final fileContents = await _exportService.importFromFile(
        filePath: _selectedFilePath!,
        password: '', // Empty password will fail if the file is encrypted
      );

      if (fileContents == null) {
        // File might be encrypted
        setState(() {
          _isEncrypted = true;
          _fileAnalyzed = true;
        });
      } else {
        // File is not encrypted
        setState(() {
          _isEncrypted = false;
          _importData = fileContents;
          _fileAnalyzed = true;

          // Check what's available in the file
          _importOtpEntries = fileContents.containsKey('otpEntries');
          _importSettings = fileContents.containsKey('settings');
        });
      }
    } catch (e) {
      _logger.e('Error analyzing file', e);
      setState(() {
        _errorMessage = 'Error analyzing file: ${e.toString()}';
      });
    }
  }

  // Analyze pasted data
  Future<void> _analyzePastedData() async {
    _logger.d('Analyzing pasted data');

    final pastedText = _pasteController.text.trim();
    if (pastedText.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste some data first';
      });
      return;
    }

    try {
      // Try to parse the pasted data without decryption first
      final data = await _exportService.importFromString(
        content: pastedText,
        password: '', // Empty password will fail if the data is encrypted
      );

      if (data == null) {
        // Data might be encrypted
        setState(() {
          _isPastedDataEncrypted = true;
          _pastedDataAnalyzed = true;
        });
      } else {
        // Data is not encrypted
        setState(() {
          _isPastedDataEncrypted = false;
          _importData = data;
          _pastedDataAnalyzed = true;

          // Check what's available in the data
          _importOtpEntries = data.containsKey('otpEntries');
          _importSettings = data.containsKey('settings');
        });
      }
    } catch (e) {
      _logger.e('Error analyzing pasted data', e);
      setState(() {
        _errorMessage = 'Error analyzing pasted data: ${e.toString()}';
      });
    }
  }

  // Decrypt file data
  Future<void> _decryptFile() async {
    _logger.d('Decrypting file data');

    if (_selectedFilePath == null) return;

    // Validate password
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Password is required for encrypted files';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      // Try to decrypt the file
      final decryptedData = await _exportService.importFromFile(filePath: _selectedFilePath!, password: _passwordController.text);

      if (decryptedData == null) {
        setState(() {
          _errorMessage = 'Failed to decrypt file. Check your password.';
        });
        return;
      }

      // Update state with decrypted data
      setState(() {
        _importData = decryptedData;
        _importOtpEntries = decryptedData.containsKey('otpEntries');
        _importSettings = decryptedData.containsKey('settings');
      });

      _logger.i('File decrypted successfully');
    } catch (e) {
      _logger.e('Error decrypting file', e);
      setState(() {
        _errorMessage = 'Error decrypting file: ${e.toString()}';
      });
    }
  }

  // Import data from file
  Future<void> _importFromFile() async {
    _logger.d('Starting import from file');

    if (_selectedFilePath == null) return;

    // If the file is encrypted and we don't have data yet, we need to decrypt first
    if (_isEncrypted && _importData == null) {
      setState(() {
        _errorMessage = 'Please decrypt the file first';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      await _performImport();
    } catch (e) {
      _logger.e('Error during file import', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Import error: ${e.toString()}';
          _isImporting = false;
        });
      }
    }
  }

  // Decrypt pasted data
  Future<void> _decryptPastedData() async {
    _logger.d('Decrypting pasted data');

    final pastedText = _pasteController.text.trim();
    if (pastedText.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste some data first';
      });
      return;
    }

    // Validate password
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Password is required for encrypted data';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    try {
      // Try to decrypt the data
      final decryptedData = await _exportService.importFromString(content: pastedText, password: _passwordController.text);

      if (decryptedData == null) {
        setState(() {
          _errorMessage = 'Failed to decrypt data. Check your password.';
        });
        return;
      }

      // Update state with decrypted data
      setState(() {
        _importData = decryptedData;
        _importOtpEntries = decryptedData.containsKey('otpEntries');
        _importSettings = decryptedData.containsKey('settings');
      });

      _logger.i('Data decrypted successfully');
    } catch (e) {
      _logger.e('Error decrypting pasted data', e);
      setState(() {
        _errorMessage = 'Error decrypting data: ${e.toString()}';
      });
    }
  }

  // Import data from pasted text
  Future<void> _importFromPastedData() async {
    _logger.d('Starting import from pasted data');

    final pastedText = _pasteController.text.trim();
    if (pastedText.isEmpty) {
      setState(() {
        _errorMessage = 'Please paste some data first';
      });
      return;
    }

    // If the data is encrypted and we don't have data yet, we need to decrypt first
    if (_isPastedDataEncrypted && _importData == null) {
      setState(() {
        _errorMessage = 'Please decrypt the data first';
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      await _performImport();
    } catch (e) {
      _logger.e('Error during paste import', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Import error: ${e.toString()}';
          _isImporting = false;
        });
      }
    }
  }

  // Common import logic for both file and pasted data
  Future<void> _performImport() async {
    _logger.d('Performing import');

    bool otpEntriesUpdated = false;
    bool settingsUpdated = false;

    try {
      // Import OTP entries if selected and available
      if (_importOtpEntries && _importData!.containsKey('otpEntries')) {
        final entriesJson = _importData!['otpEntries'] as List;
        final newEntries = entriesJson.map((e) => OtpEntry.fromJson(e)).toList();

        // Get existing entries
        final existingEntries = await _storageService.getOtpEntries();

        // Identify new entries to add
        final uniqueNewEntries = _identifyNewEntries(existingEntries, newEntries);

        // Add new entries to existing ones
        if (uniqueNewEntries.isNotEmpty) {
          final mergedEntries = [...existingEntries, ...uniqueNewEntries];
          await _storageService.saveOtpEntries(mergedEntries);
          _logger.i('Added ${uniqueNewEntries.length} new OTP entries');
          otpEntriesUpdated = true;
        } else {
          _logger.i('No new OTP entries to add');
        }
      }

      // Import settings if selected and available
      if (_importSettings && _importData!.containsKey('settings')) {
        final settingsJson = _importData!['settings'];
        final settings = SettingsModel.fromJson(settingsJson);

        await _settingsService.saveSettings(settings);
        _logger.i('Imported settings');
        settingsUpdated = true;
      }

      // Trigger appropriate reload events
      if (otpEntriesUpdated && settingsUpdated) {
        _reloadService.triggerFullAppReload();
        _logger.i('Triggered full app reload after import');
      } else if (otpEntriesUpdated) {
        _reloadService.triggerOtpEntriesReload();
        _logger.i('Triggered OTP entries reload after import');
      } else if (settingsUpdated) {
        _reloadService.triggerSettingsReload();
        _logger.i('Triggered settings reload after import');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import completed successfully')));
        Navigator.pop(context, true); // Return true to indicate successful import
      }
    } catch (e) {
      _logger.e('Error during import', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Import error: ${e.toString()}';
          _isImporting = false;
        });
      }
    }
  }

  // Identify new entries that don't exist in the current list
  List<OtpEntry> _identifyNewEntries(List<OtpEntry> existingEntries, List<OtpEntry> newEntries) {
    _logger.d('Identifying new entries');

    // Create a set of existing entry secrets for faster lookup
    final existingSecrets = existingEntries.map((e) => '${e.issuer}:${e.name}:${e.secret}').toSet();

    // Filter out entries that already exist
    final uniqueNewEntries =
        newEntries.where((entry) {
          final entryKey = '${entry.issuer}:${entry.name}:${entry.secret}';
          return !existingSecrets.contains(entryKey);
        }).toList();

    _logger.d('Found ${uniqueNewEntries.length} new entries out of ${newEntries.length} total');
    return uniqueNewEntries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Import Data'),
      body:
          _isImporting
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Importing data...')],
                ),
              )
              : Column(
                children: [
                  // Tab bar
                  TabBar(controller: _tabController, tabs: const [Tab(text: 'From File'), Tab(text: 'Paste Data')], labelColor: Theme.of(context).primaryColor),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // File import tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // File selection
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Select File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _fileName ?? 'No file selected',
                                              style: TextStyle(color: _fileName == null ? Theme.of(context).disabledColor : null),
                                            ),
                                          ),
                                          ElevatedButton(onPressed: _selectFile, child: const Text('Browse')),
                                        ],
                                      ),
                                      if (Platform.isAndroid) ...[
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Tip: If you can\'t find your JSON file, try using a file manager app to locate it first, '
                                          'or move it to a common location like Downloads.',
                                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(_foundJsonFiles.isNotEmpty ? 'Found JSON files on your device:' : 'No JSON files found in common locations'),
                                            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Scan for JSON files', onPressed: _checkCommonJsonLocations),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        if (_foundJsonFiles.isNotEmpty) ...[
                                          Container(
                                            height: 150,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Theme.of(context).dividerColor),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: ListView.builder(
                                              itemCount: _foundJsonFiles.length,
                                              itemBuilder: (context, index) {
                                                final filePath = _foundJsonFiles[index];
                                                final fileName = filePath.split('/').last;
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(fileName),
                                                  subtitle: Text(filePath, style: const TextStyle(fontSize: 12)),
                                                  onTap: () => _selectFoundJsonFile(filePath),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        const Text('Or enter the file path directly:'),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                decoration: const InputDecoration(
                                                  hintText: '/storage/emulated/0/Download/example.json',
                                                  border: OutlineInputBorder(),
                                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  isDense: true,
                                                ),
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedFilePath = value.trim().isNotEmpty ? value.trim() : null;
                                                    _fileName = _selectedFilePath?.split('/').last;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(onPressed: _selectedFilePath != null ? _analyzeFile : null, child: const Text('Load')),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // If file is selected and analyzed
                              if (_selectedFilePath != null && _fileAnalyzed) ...[
                                // Password field for encrypted files
                                if (_isEncrypted) ...[
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Encrypted File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 16),
                                          const Text('This file is encrypted. Please enter the password:'),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _passwordController,
                                            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                                            obscureText: true,
                                            onChanged: (value) {
                                              // Force UI update when password changes
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Decrypt button for encrypted files
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _passwordController.text.isNotEmpty ? _decryptFile : null,
                                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                      child: const Text('Decrypt File', style: TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Import options
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Import Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 16),

                                        if (_importData != null && _importData!.containsKey('otpEntries'))
                                          CheckboxListTile(
                                            title: const Text('OTP Entries'),
                                            subtitle: Text('Import ${(_importData!['otpEntries'] as List).length} OTP entries'),
                                            value: _importOtpEntries,
                                            onChanged: (value) {
                                              setState(() {
                                                _importOtpEntries = value ?? true;
                                              });
                                            },
                                          ),

                                        if (_importData != null && _importData!.containsKey('settings'))
                                          CheckboxListTile(
                                            title: const Text('Settings'),
                                            subtitle: const Text('Import app settings and preferences'),
                                            value: _importSettings,
                                            onChanged: (value) {
                                              setState(() {
                                                _importSettings = value ?? true;
                                              });
                                            },
                                          ),

                                        if (_importData == null || (!_importData!.containsKey('otpEntries') && !_importData!.containsKey('settings')))
                                          const Text('File content will be analyzed after decryption', style: TextStyle(fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              // Error message
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                              ],

                              // Import button
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _selectedFilePath != null ? _importFromFile : null,
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                  child: const Text('Import', style: TextStyle(fontSize: 16)),
                                ),
                              ),

                              // Warning about import
                              const SizedBox(height: 24),
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Warning:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      SizedBox(height: 8),
                                      Text(
                                        'Importing settings will overwrite your current settings. '
                                        'Importing OTP entries will add new entries to your existing ones. '
                                        'Make sure to export your current data first if you want to keep it.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Paste data tab
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Paste area
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Paste Export Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 16),
                                      const Text('Paste the exported JSON data below:'),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _pasteController,
                                        decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste JSON data here...'),
                                        maxLines: 10,
                                        onChanged: (value) {
                                          // Reset analysis when text changes
                                          setState(() {
                                            _pastedDataAnalyzed = false;
                                            _importData = null;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _pasteController.text.isNotEmpty ? _analyzePastedData : null,
                                          child: const Text('Analyze Data'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // If data is pasted and analyzed
                              if (_pastedDataAnalyzed) ...[
                                // Password field for encrypted data
                                if (_isPastedDataEncrypted) ...[
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Encrypted Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 16),
                                          const Text('This data is encrypted. Please enter the password:'),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: _passwordController,
                                            decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                                            obscureText: true,
                                            onChanged: (value) {
                                              // Force UI update when password changes
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Decrypt button for encrypted data
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _passwordController.text.isNotEmpty ? _decryptPastedData : null,
                                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                      child: const Text('Decrypt Data', style: TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Import options
                                if (_importData != null) ...[
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Import Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 16),

                                          if (_importData!.containsKey('otpEntries'))
                                            CheckboxListTile(
                                              title: const Text('OTP Entries'),
                                              subtitle: Text('Import ${(_importData!['otpEntries'] as List).length} OTP entries'),
                                              value: _importOtpEntries,
                                              onChanged: (value) {
                                                setState(() {
                                                  _importOtpEntries = value ?? true;
                                                });
                                              },
                                            ),

                                          if (_importData!.containsKey('settings'))
                                            CheckboxListTile(
                                              title: const Text('Settings'),
                                              subtitle: const Text('Import app settings and preferences'),
                                              value: _importSettings,
                                              onChanged: (value) {
                                                setState(() {
                                                  _importSettings = value ?? true;
                                                });
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],

                              // Error message
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                              ],

                              // Import button
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _pastedDataAnalyzed ? _importFromPastedData : null,
                                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                                  child: const Text('Import', style: TextStyle(fontSize: 16)),
                                ),
                              ),

                              // Warning about import
                              const SizedBox(height: 24),
                              const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Warning:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      SizedBox(height: 8),
                                      Text(
                                        'Importing settings will overwrite your current settings. '
                                        'Importing OTP entries will add new entries to your existing ones. '
                                        'Make sure to export your current data first if you want to keep it.',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
