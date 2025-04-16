import 'package:flutter/material.dart';
import 'package:openotp/widgets/custom_app_bar.dart';
import '../models/otp_entry.dart';
import '../services/secure_storage_service.dart';
import '../services/logger_service.dart';
import '../services/qr_scanner_service.dart';
import '../utils/base32_utils.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class AddOtpScreen extends StatefulWidget {
  final bool showQrOptions;
  final bool initiallyShowQrScanner;
  final String? initialQrCode;

  const AddOtpScreen({super.key, this.showQrOptions = true, this.initiallyShowQrScanner = false, this.initialQrCode});

  @override
  State<AddOtpScreen> createState() => _AddOtpScreenState();
}

class _AddOtpScreenState extends State<AddOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _secretController = TextEditingController();
  final _issuerController = TextEditingController();

  final SecureStorageService _storageService = SecureStorageService();
  final LoggerService _logger = LoggerService();
  final QrScannerService _qrScannerService = QrScannerService();

  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  bool _isScanning = false;

  int _digits = 6;
  int _period = 30;
  String _algorithm = 'SHA1';
  OtpType _otpType = OtpType.totp;
  int _counter = 0;

  final List<int> _digitOptions = [6, 8];
  final List<int> _periodOptions = [30, 60];
  final List<String> _algorithmOptions = ['SHA1', 'SHA256', 'SHA512'];

  bool _showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing AddOtpScreen');

    // Process initial QR code if provided
    if (widget.initialQrCode != null) {
      _logger.d('Processing initial QR code');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processScannedCode(widget.initialQrCode!);
      });
    }

    // Start QR scanner if requested
    if (widget.initiallyShowQrScanner && _qrScannerService.isCameraQrScanningSupported()) {
      _logger.d('Auto-starting QR scanner');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startQrScan();
      });
    }

    _logger.d('AddOtpScreen initialized');
  }

  @override
  void dispose() {
    _logger.i('Disposing AddOtpScreen');
    _nameController.dispose();
    _secretController.dispose();
    _issuerController.dispose();
    // QRViewController auto-disposes in qr_code_scanner_plus
    super.dispose();
  }

  Future<void> _saveOtpEntry() async {
    _logger.d('Attempting to save OTP entry');
    if (_formKey.currentState!.validate()) {
      _logger.d('Form validation successful');
      try {
        // Additional validation to ensure the secret can be decoded
        final secretKey = _secretController.text;
        if (!Base32Utils.canDecode(secretKey)) {
          _logger.w('Secret key cannot be decoded as base32');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid secret key format. Please check your input.')));
          return;
        }

        final newEntry = OtpEntry(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text,
          secret: secretKey,
          issuer: _issuerController.text,
          digits: _digits,
          period: _period,
          algorithm: _algorithm,
          type: _otpType,
          counter: _counter,
        );

        _logger.d(
          'Created OTP entry: ${newEntry.name}, Type: ${newEntry.type.name}, Algorithm: ${newEntry.algorithm}, Digits: ${newEntry.digits}, Period: ${newEntry.period}, Counter: ${newEntry.counter}',
        );
        await _storageService.addOtpEntry(newEntry);
        _logger.i('Successfully saved OTP entry: ${newEntry.name}');

        if (mounted) {
          _logger.d('Returning to home screen');
          Navigator.pop(context, true);
        }
      } catch (e, stackTrace) {
        _logger.e('Error saving OTP entry', e, stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving OTP entry: ${e.toString()}')));
        }
      }
    } else {
      _logger.w('Form validation failed');
    }
  }

  void _startQrScan() {
    _logger.i('Starting QR scan');
    setState(() {
      _isScanning = true;
    });
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (context) => Scaffold(
                  appBar: CustomAppBar(title: 'Scan QR Code'),
                  body: Stack(
                    children: [
                      QRView(
                        key: _qrKey,
                        onQRViewCreated: _onQRViewCreated,
                        overlay: QrScannerOverlayShape(
                          borderColor: Theme.of(context).colorScheme.primary,
                          borderRadius: 10,
                          borderLength: 30,
                          borderWidth: 10,
                          cutOutSize: MediaQuery.of(context).size.width * 0.8,
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'Align the QR code within the frame',
                            style: TextStyle(
                              color: const Color(0xFFFFFFFF), // Text Primary (white)
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.black54, // Keep semi-transparent background for readability
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        )
        .then((_) {
          setState(() {
            _isScanning = false;
          });
        });
  }

  void _onQRViewCreated(QRViewController controller) {
    _logger.d('QR view created');
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && !_isScanning) {
        return; // Prevent multiple scans
      }

      if (scanData.code != null) {
        _logger.i('QR code scanned: ${scanData.code}');
        setState(() {
          _isScanning = false;
        });
        // QRViewController auto-disposes in qr_code_scanner_plus
        _processScannedCode(scanData.code!);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _processScannedCode(String code) {
    _logger.d('Processing scanned code: $code');
    try {
      final parsedData = _qrScannerService.parseOtpAuthUri(code);
      setState(() {
        _nameController.text = parsedData['name'];
        _secretController.text = parsedData['secret'];
        _issuerController.text = parsedData['issuer'];
        _digits = parsedData['digits'];
        _period = parsedData['period'];
        _algorithm = parsedData['algorithm'];
        _otpType = OtpType.values[parsedData['type']];
        if (_otpType == OtpType.hotp && parsedData.containsKey('counter')) {
          _counter = parsedData['counter'];
        }
        _showAdvancedSettings = true; // Show advanced settings if non-default values were scanned
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code successfully scanned')));
    } catch (e) {
      _logger.e('Error processing QR code', e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid QR code format: ${e.toString()}')));
    }
  }

  void _showUnsupportedCameraMessage() {
    _logger.i('Showing unsupported camera message');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_qrScannerService.getUnsupportedCameraMessage())));
  }

  Future<void> _scanQrFromImage() async {
    _logger.i('Starting QR scan from image');
    try {
      final qrCode = await _qrScannerService.pickAndDecodeQrFromImage();
      if (qrCode != null) {
        _processScannedCode(qrCode);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No QR code found in the selected image')));
        }
      }
    } catch (e) {
      _logger.e('Error scanning QR from image', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning QR code: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Add OTP Entry'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Account Name', hintText: 'e.g., Email, GitHub', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an account name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _issuerController,
                decoration: const InputDecoration(labelText: 'Issuer (Optional)', hintText: 'e.g., Google, Microsoft', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _secretController,
                      decoration: InputDecoration(
                        labelText: 'Secret Key',
                        border: const OutlineInputBorder(),
                        suffixIcon:
                            widget.showQrOptions
                                ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.qr_code_scanner),
                                      tooltip: 'Scan QR code with camera',
                                      onPressed: _qrScannerService.isCameraQrScanningSupported() ? _startQrScan : _showUnsupportedCameraMessage,
                                    ),
                                    IconButton(icon: const Icon(Icons.image), tooltip: 'Scan QR code from image', onPressed: _scanQrFromImage),
                                  ],
                                )
                                : null,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a secret key';
                        }
                        // Validate base32 characters
                        if (!Base32Utils.isValidBase32(value)) {
                          return 'Invalid base32 characters. Use only A-Z and 2-7';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.surface,
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: const Text('Advanced Settings'),
                  initiallyExpanded: _showAdvancedSettings,
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _showAdvancedSettings = expanded;
                    });
                    _logger.d('Advanced settings expanded: $expanded');
                  },
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Text(
                        'The default settings are the most common. Only change these if you know what you\'re doing.',
                        style: TextStyle(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFFB0B0B0) // Dark mode Text Secondary
                                  : const Color(0xFF4F4F4F), // Light mode Text Secondary
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: DropdownButtonFormField<OtpType>(
                        decoration: const InputDecoration(labelText: 'OTP Type', border: OutlineInputBorder()),
                        value: _otpType,
                        items: [
                          DropdownMenuItem<OtpType>(value: OtpType.totp, child: Text('TOTP (Time-based)')),
                          DropdownMenuItem<OtpType>(value: OtpType.hotp, child: Text('HOTP (Counter-based)')),
                        ],
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _otpType = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              decoration: const InputDecoration(labelText: 'Digits', border: OutlineInputBorder()),
                              value: _digits,
                              items:
                                  _digitOptions.map((int value) {
                                    return DropdownMenuItem<int>(value: value, child: Text('$value digits'));
                                  }).toList(),
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _digits = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child:
                                _otpType == OtpType.totp
                                    ? DropdownButtonFormField<int>(
                                      decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()),
                                      value: _period,
                                      items:
                                          _periodOptions.map((int value) {
                                            return DropdownMenuItem<int>(value: value, child: Text('$value seconds'));
                                          }).toList(),
                                      onChanged: (newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _period = newValue;
                                          });
                                        }
                                      },
                                    )
                                    : TextFormField(
                                      decoration: const InputDecoration(labelText: 'Initial Counter', border: OutlineInputBorder()),
                                      initialValue: _counter.toString(),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final parsedValue = int.tryParse(value);
                                        if (parsedValue != null) {
                                          setState(() {
                                            _counter = parsedValue;
                                          });
                                        }
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Algorithm', border: OutlineInputBorder()),
                        value: _algorithm,
                        items:
                            _algorithmOptions.map((String value) {
                              return DropdownMenuItem<String>(value: value, child: Text(value));
                            }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _algorithm = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveOtpEntry,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Save OTP Entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
