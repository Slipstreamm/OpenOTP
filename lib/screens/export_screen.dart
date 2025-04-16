import 'package:flutter/material.dart';
import 'package:openotp/services/export_service.dart';
import 'package:openotp/services/logger_service.dart';
import 'package:openotp/widgets/custom_app_bar.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final LoggerService _logger = LoggerService();
  final ExportService _exportService = ExportService();
  
  bool _includeOtpEntries = true;
  bool _includeSettings = false;
  bool _encrypt = false;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isExporting = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _logger.i('Initializing ExportScreen');
  }
  
  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  Future<void> _exportData() async {
    _logger.d('Starting export process');
    
    // Validate input
    if (_encrypt) {
      if (_passwordController.text.isEmpty) {
        setState(() {
          _errorMessage = 'Password is required for encryption';
        });
        return;
      }
      
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = 'Passwords do not match';
        });
        return;
      }
    }
    
    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });
    
    try {
      final success = await _exportService.exportToFile(
        includeOtpEntries: _includeOtpEntries,
        includeSettings: _includeSettings,
        encrypt: _encrypt,
        password: _encrypt ? _passwordController.text : null,
      );
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Export completed successfully')),
          );
          Navigator.pop(context);
        } else {
          setState(() {
            _errorMessage = 'Export failed';
            _isExporting = false;
          });
        }
      }
    } catch (e) {
      _logger.e('Error during export', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Export error: ${e.toString()}';
          _isExporting = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Export Data'),
      body: _isExporting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Exporting data...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Export Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // What to export
                  const Text(
                    'What to export:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  CheckboxListTile(
                    title: const Text('OTP Entries'),
                    subtitle: const Text('Export all your saved OTP codes'),
                    value: _includeOtpEntries,
                    onChanged: (value) {
                      setState(() {
                        _includeOtpEntries = value ?? true;
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Settings'),
                    subtitle: const Text('Export app settings and preferences'),
                    value: _includeSettings,
                    onChanged: (value) {
                      setState(() {
                        _includeSettings = value ?? false;
                      });
                    },
                  ),
                  const Divider(),
                  
                  // Encryption options
                  const Text(
                    'Security:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SwitchListTile(
                    title: const Text('Encrypt Export'),
                    subtitle: const Text('Protect your data with a password'),
                    value: _encrypt,
                    onChanged: (value) {
                      setState(() {
                        _encrypt = value;
                      });
                    },
                  ),
                  
                  // Password fields (only shown if encryption is enabled)
                  if (_encrypt) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                  ],
                  
                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  
                  // Export button
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _includeOtpEntries || _includeSettings
                          ? _exportData
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Export',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  
                  // Note about security
                  const SizedBox(height: 24),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Note:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Exported OTP secrets can be used to generate your authentication codes. '
                            'If you choose to encrypt your export, make sure to use a strong password '
                            'and keep it safe. Anyone with access to your export file and password '
                            'will be able to generate your OTP codes.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
