import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:openotp/models/otp_entry.dart';
import 'package:openotp/models/settings_model.dart';
import 'package:openotp/services/export_service.dart';
import 'package:openotp/services/logger_service.dart';
import 'package:openotp/services/secure_storage_service.dart';
import 'package:openotp/services/settings_service.dart';
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

  // Tab controller
  late TabController _tabController;

  // File import variables
  String? _selectedFilePath;
  String? _fileName;
  bool _isEncrypted = false;
  bool _fileAnalyzed = false;

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
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _fileName = result.files.single.name;
          _fileAnalyzed = false;
          _importData = null;
          _errorMessage = null;
        });

        _analyzeFile();
      }
    } catch (e) {
      _logger.e('Error selecting file', e);
      setState(() {
        _errorMessage = 'Error selecting file: ${e.toString()}';
      });
    }
  }

  // Analyze the selected file
  Future<void> _analyzeFile() async {
    _logger.d('Analyzing selected file');

    if (_selectedFilePath == null) return;

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

    try {
      // Import OTP entries if selected and available
      if (_importOtpEntries && _importData!.containsKey('otpEntries')) {
        final entriesJson = _importData!['otpEntries'] as List;
        final entries = entriesJson.map((e) => OtpEntry.fromJson(e)).toList();

        await _storageService.saveOtpEntries(entries);
        _logger.i('Imported ${entries.length} OTP entries');
      }

      // Import settings if selected and available
      if (_importSettings && _importData!.containsKey('settings')) {
        final settingsJson = _importData!['settings'];
        final settings = SettingsModel.fromJson(settingsJson);

        await _settingsService.saveSettings(settings);
        _logger.i('Imported settings');
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
                                        'Importing OTP entries will replace all your current entries. '
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
                                        'Importing OTP entries will replace all your current entries. '
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
