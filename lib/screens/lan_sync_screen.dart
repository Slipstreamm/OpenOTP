import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import '../models/device_info_model.dart';
import '../models/otp_entry.dart';
import '../models/sync_data_model.dart';
import '../services/lan_sync_service.dart' as lan_sync;
import '../services/logger_service.dart';
import '../services/qr_scanner_service.dart';
import '../services/secure_storage_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../services/app_reload_service.dart';
import '../widgets/custom_app_bar.dart';

// A dedicated QR scanner screen to handle QR code scanning safely
class _QrScannerScreen extends StatefulWidget {
  final Function(String) onCodeScanned;
  final String title;
  final String instructionText;

  const _QrScannerScreen({required this.onCodeScanned, required this.title, required this.instructionText});

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  final LoggerService _logger = LoggerService();
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QRView');
  QRViewController? _controller;
  bool _hasScanned = false;

  @override
  void dispose() {
    // QRViewController auto-disposes in qr_code_scanner_plus
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_controller != null) {
      // On hot reload, pause camera on Android, resume on iOS
      if (Platform.isAndroid) {
        _controller!.pauseCamera();
      } else if (Platform.isIOS) {
        _controller!.resumeCamera();
      }
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && !_hasScanned) {
        // Store the code before setting state
        final code = scanData.code!;

        setState(() {
          _hasScanned = true;
        });
        _logger.i('QR code scanned: $code');

        // Use a microtask to avoid BuildContext across async gaps
        Future.microtask(() {
          if (mounted) {
            // Process the scanned code
            widget.onCodeScanned(code);

            // Close the scanner screen
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: widget.title),
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
                widget.instructionText,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, backgroundColor: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LanSyncScreen extends StatefulWidget {
  const LanSyncScreen({super.key});

  @override
  State<LanSyncScreen> createState() => _LanSyncScreenState();
}

class _LanSyncScreenState extends State<LanSyncScreen> {
  final LoggerService _logger = LoggerService();
  final lan_sync.LanSyncService _lanSyncService = lan_sync.LanSyncService();
  final SecureStorageService _storageService = SecureStorageService();
  final SettingsService _settingsService = SettingsService();
  final QrScannerService _qrScannerService = QrScannerService();
  final AppReloadService _reloadService = AppReloadService();

  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _syncPinController = TextEditingController();
  final TextEditingController _ipAddressController = TextEditingController();
  final TextEditingController _serverPortController = TextEditingController();
  final TextEditingController _clientPortController = TextEditingController();

  bool _isServerRunning = false;
  bool _isConnectedToServer = false;
  bool _isLoading = false;
  bool _syncSettings = true;
  String? _errorMessage;

  // ignore: prefer_final_fields
  List<DeviceInfoModel> _discoveredDevices = [];

  StreamSubscription? _deviceDiscoveredSubscription;
  StreamSubscription? _dataReceivedSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _connectionStateSubscription;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing LanSyncScreen');
    _initializeLanSync();
  }

  @override
  void dispose() {
    _logger.i('Disposing LanSyncScreen');
    _deviceNameController.dispose();
    _syncPinController.dispose();
    _ipAddressController.dispose();
    _serverPortController.dispose();
    _clientPortController.dispose();

    _deviceDiscoveredSubscription?.cancel();
    _dataReceivedSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionStateSubscription?.cancel();

    super.dispose();
  }

  // Initialize LAN sync
  Future<void> _initializeLanSync() async {
    _logger.d('Initializing LAN sync');
    setState(() {
      _isLoading = true;
    });

    try {
      // Initialize LAN sync service
      await _lanSyncService.initialize();

      // Load settings
      final settings = await _settingsService.loadSettings();

      // Set device name from settings or get from LAN sync service if empty
      if (settings.deviceName.isEmpty) {
        final deviceInfo = _lanSyncService.getCurrentDeviceInfo();
        if (deviceInfo != null) {
          _deviceNameController.text = deviceInfo.name;
        } else {
          _deviceNameController.text = 'OpenOTP Sync Device';
        }
      } else {
        _deviceNameController.text = settings.deviceName;
      }

      if (settings.syncPin != null) {
        _syncPinController.text = settings.syncPin!;
      }

      // Set port controllers
      _serverPortController.text = settings.serverPort?.toString() ?? lan_sync.LanSyncService.defaultPort.toString();
      _clientPortController.text = settings.clientPort?.toString() ?? lan_sync.LanSyncService.defaultPort.toString();

      // Set up listeners
      _setupListeners();

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      _logger.e('Error initializing LAN sync', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize LAN sync: ${e.toString()}';
      });
    }
  }

  // Set up listeners for LAN sync events
  void _setupListeners() {
    _logger.d('Setting up LAN sync listeners');

    // Listen for discovered devices
    _deviceDiscoveredSubscription = _lanSyncService.onDeviceDiscovered.listen((device) {
      _logger.i('Device discovered: ${device.name} (${device.ipAddress})');
      setState(() {
        if (!_discoveredDevices.contains(device)) {
          _discoveredDevices.add(device);
        }
      });
    });

    // Listen for received data
    _dataReceivedSubscription = _lanSyncService.onDataReceived.listen((data) {
      _logger.i('Data received from ${data.sourceDeviceName}');
      _handleReceivedData(data);
    });

    // Listen for errors
    _errorSubscription = _lanSyncService.onError.listen((error) {
      _logger.e('LAN sync error: $error');
      setState(() {
        _errorMessage = error;
      });
    });

    // Listen for connection state changes
    _connectionStateSubscription = _lanSyncService.onConnectionStateChanged.listen((state) {
      _logger.i('Connection state changed: $state');
      setState(() {
        _isServerRunning = state == lan_sync.ConnectionState.listening;
        _isConnectedToServer = state == lan_sync.ConnectionState.connected;
      });
    });
  }

  // Handle received sync data
  Future<void> _handleReceivedData(SyncDataModel data) async {
    _logger.d('Handling received data from ${data.sourceDeviceName}');

    try {
      // Show confirmation dialog
      final confirmed = await _showSyncConfirmationDialog(data);

      if (confirmed) {
        // Apply the received data
        await _applyReceivedData(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully synced with ${data.sourceDeviceName}')));
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error handling received data', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error syncing: ${e.toString()}')));
      }
    }
  }

  // Apply received sync data
  Future<void> _applyReceivedData(SyncDataModel data) async {
    _logger.d('Applying received data');

    bool otpEntriesUpdated = false;
    bool settingsUpdated = false;

    // Apply OTP entries
    if (data.otpEntries.isNotEmpty) {
      // Get existing entries
      final existingEntries = await _storageService.getOtpEntries();

      // Identify new entries to add
      final newEntries = _identifyNewEntries(existingEntries, data.otpEntries);

      // Add new entries to existing ones
      if (newEntries.isNotEmpty) {
        final mergedEntries = [...existingEntries, ...newEntries];
        await _storageService.saveOtpEntries(mergedEntries);
        _logger.i('Added ${newEntries.length} new OTP entries');
        otpEntriesUpdated = true;
      } else {
        _logger.i('No new OTP entries to add');
      }
    }

    // Apply settings if included and allowed
    if (data.settings != null && data.includeSettings && data.direction != SyncDirection.sendOnly) {
      // Preserve device name and sync PIN
      final currentSettings = await _settingsService.loadSettings();
      final newSettings = data.settings!.copyWith(deviceName: currentSettings.deviceName, syncPin: currentSettings.syncPin);

      await _settingsService.saveSettings(newSettings);
      _logger.i('Applied settings');
      settingsUpdated = true;

      // Notify theme service of changes
      if (mounted) {
        final themeService = Provider.of<ThemeService>(context, listen: false);
        await themeService.initialize();
      }
    }

    // Trigger appropriate reload events
    if (otpEntriesUpdated && settingsUpdated) {
      _reloadService.triggerFullAppReload();
      _logger.i('Triggered full app reload after sync');
    } else if (otpEntriesUpdated) {
      _reloadService.triggerOtpEntriesReload();
      _logger.i('Triggered OTP entries reload after sync');
    } else if (settingsUpdated) {
      _reloadService.triggerSettingsReload();
      _logger.i('Triggered settings reload after sync');
    }
  }

  // Show confirmation dialog for received sync data
  Future<bool> _showSyncConfirmationDialog(SyncDataModel data) async {
    _logger.d('Showing sync confirmation dialog');

    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Sync Confirmation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.arrow_downward, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              const TextSpan(text: 'Receiving data '),
                              TextSpan(text: 'FROM ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              TextSpan(text: data.sourceDeviceName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: ' TO ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              TextSpan(text: _deviceNameController.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vpn_key, size: 16),
                            const SizedBox(width: 8),
                            Text('OTP Entries: ${data.otpEntries.length}', style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                        if (data.settings != null && data.includeSettings)
                          Row(
                            children: [
                              const Icon(Icons.settings, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text('Settings included', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
                            ],
                          ),
                        if (data.settings != null && !data.includeSettings)
                          Row(
                            children: [
                              const Icon(Icons.settings, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              const Text('Settings NOT included (OTP data only)', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Do you want to apply these changes?', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('CANCEL')),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('APPLY')),
              ],
            );
          },
        ) ??
        false;
  }

  // Start the server
  Future<void> _startServer() async {
    _logger.d('Starting server');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save device name if changed
      final themeService = Provider.of<ThemeService>(context, listen: false);
      if (_deviceNameController.text != themeService.settings.deviceName) {
        await themeService.updateDeviceName(_deviceNameController.text);
      }

      // Save sync PIN if changed
      final currentPin = themeService.settings.syncPin;
      if (_syncPinController.text != currentPin) {
        await themeService.updateSyncPin(_syncPinController.text.isNotEmpty ? _syncPinController.text : null);
      }

      // Get server port
      int serverPort = lan_sync.LanSyncService.defaultPort;
      try {
        final portText = _serverPortController.text.trim();
        if (portText.isNotEmpty) {
          final parsedPort = int.tryParse(portText);
          if (parsedPort != null && parsedPort > 0 && parsedPort < 65536) {
            serverPort = parsedPort;
            // Save server port if changed
            if (serverPort != themeService.settings.serverPort) {
              await themeService.updateServerPort(serverPort);
            }
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Invalid server port. Using default port.';
            });
          }
        }
      } catch (e) {
        _logger.w('Error parsing server port: $e. Using default port.');
      }

      // Start the server
      final success = await _lanSyncService.startServer(port: serverPort);

      // Get updated device info after server starts
      final deviceInfo = _lanSyncService.getCurrentDeviceInfo();

      setState(() {
        _isLoading = false;
        _isServerRunning = success;
        if (!success) {
          _errorMessage = 'Failed to start server';
        }
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server started on ${deviceInfo?.ipAddress}:${deviceInfo?.port}')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error starting server', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error starting server: ${e.toString()}';
      });
    }
  }

  // Stop the server
  Future<void> _stopServer() async {
    _logger.d('Stopping server');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _lanSyncService.stopServer();

      setState(() {
        _isLoading = false;
        _isServerRunning = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server stopped')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error stopping server', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error stopping server: ${e.toString()}';
      });
    }
  }

  // Connect to a server
  Future<void> _connectToServer() async {
    _logger.d('Connecting to server');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate inputs
      final ipAddress = _ipAddressController.text.trim();
      if (ipAddress.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter an IP address';
        });
        return;
      }

      final pin = _syncPinController.text.trim();
      if (pin.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please enter a sync PIN';
        });
        return;
      }

      // Save device name if changed
      final themeService = Provider.of<ThemeService>(context, listen: false);
      if (_deviceNameController.text != themeService.settings.deviceName) {
        await themeService.updateDeviceName(_deviceNameController.text);
      }

      // Save sync PIN if changed
      final currentPin = themeService.settings.syncPin;
      if (pin != currentPin) {
        await themeService.updateSyncPin(pin);
      }

      // Get client port
      int clientPort = lan_sync.LanSyncService.defaultPort;
      try {
        final portText = _clientPortController.text.trim();
        if (portText.isNotEmpty) {
          final parsedPort = int.tryParse(portText);
          if (parsedPort != null && parsedPort > 0 && parsedPort < 65536) {
            clientPort = parsedPort;
            // Save client port if changed
            if (clientPort != themeService.settings.clientPort) {
              await themeService.updateClientPort(clientPort);
            }
          } else {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Invalid client port. Using default port.';
            });
          }
        }
      } catch (e) {
        _logger.w('Error parsing client port: $e. Using default port.');
      }

      // Connect to the server
      final success = await _lanSyncService.connectToServer(ipAddress, clientPort, pin);

      setState(() {
        _isLoading = false;
        _isConnectedToServer = success;
        if (!success) {
          _errorMessage = 'Failed to connect to server';
        }
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connected to server at $ipAddress:$clientPort')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error connecting to server', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error connecting to server: ${e.toString()}';
      });
    }
  }

  // Disconnect from the server
  Future<void> _disconnectFromServer() async {
    _logger.d('Disconnecting from server');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _lanSyncService.disconnectFromServer();

      setState(() {
        _isLoading = false;
        _isConnectedToServer = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnected from server')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error disconnecting from server', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error disconnecting from server: ${e.toString()}';
      });
    }
  }

  // Send sync data
  Future<void> _sendSyncData() async {
    _logger.d('Sending sync data');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get OTP entries
      final otpEntries = await _storageService.getOtpEntries();

      // Get settings
      final settings = await _settingsService.loadSettings();

      // Get device info
      final deviceInfo = _lanSyncService.getCurrentDeviceInfo();
      if (deviceInfo == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Device info not available';
        });
        return;
      }

      // Create sync data
      final syncData = SyncDataModel(
        otpEntries: otpEntries,
        settings: _syncSettings ? settings : null,
        sourceDeviceId: deviceInfo.id,
        sourceDeviceName: deviceInfo.name,
        direction: SyncDirection.bidirectional,
        includeSettings: _syncSettings,
      );

      // Send the data
      final pin = _syncPinController.text.trim();
      final success = await _lanSyncService.sendSyncData(syncData, pin);

      setState(() {
        _isLoading = false;
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync data sent successfully')));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send sync data')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending sync data', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error sending sync data: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'LAN Sync'),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceInfoSection(),
                    const Divider(height: 32),
                    _buildServerSection(),
                    const Divider(height: 32),
                    _buildClientSection(),
                    if (_errorMessage != null) ...[const SizedBox(height: 16), _buildErrorSection()],
                  ],
                ),
              ),
    );
  }

  // Build device info section
  Widget _buildDeviceInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Device Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _deviceNameController,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
            helperText: 'Name that will be shown to other devices. Defaults to your device hostname or "OpenOTP Sync Device" if hostname cannot be retrieved.',
            helperMaxLines: 3,
            helperStyle: TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _syncPinController,
          decoration: const InputDecoration(
            labelText: 'Sync Passphrase',
            border: OutlineInputBorder(),
            helperText: 'Passphrase used for authentication and encryption. Use something secure if you are on a public network. Default: 123456',
            helperMaxLines: 3,
            helperStyle: TextStyle(fontSize: 12),
          ),
          obscureText: true,
        ),
      ],
    );
  }

  // Show QR code dialog for server connection
  void _showServerQrCode() {
    _logger.d('Showing server QR code dialog');
    final qrData = _lanSyncService.generateServerQrData();
    if (qrData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot generate QR code: server information not available')));
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Scan to Connect'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scan this QR code from another device to connect to this server'),
                const SizedBox(height: 16),
                SizedBox(width: 200, height: 200, child: QrImageView(data: qrData, version: QrVersions.auto, backgroundColor: Colors.white)),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CLOSE'))],
          ),
    );
  }

  // Scan QR code for server connection
  Future<void> _scanServerQrCode() async {
    _logger.d('Starting QR code scanning for server connection');
    try {
      if (!mounted) return;

      if (_qrScannerService.isCameraQrScanningSupported()) {
        // Use a safer approach by creating a dedicated QR scanner screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => _QrScannerScreen(
                  onCodeScanned: (code) {
                    if (mounted) {
                      _processScannedServerQrCode(code);
                    }
                  },
                  title: 'Scan Server QR Code',
                  instructionText: 'Scan the server QR code',
                ),
          ),
        );
      } else {
        // Show message for unsupported platforms
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_qrScannerService.getUnsupportedCameraMessage())));
          // Offer to scan from image instead
          _scanServerQrFromImage();
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error scanning QR code', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning QR code: ${e.toString()}')));
      }
    }
  }

  // Scan QR code from image for server connection
  Future<void> _scanServerQrFromImage() async {
    _logger.d('Starting QR scan from image for server connection');
    try {
      if (!mounted) return;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecting image...'), duration: Duration(seconds: 1)));

      final qrCode = await _qrScannerService.pickAndDecodeQrFromImage();

      // Check mounted again after async operation
      if (!mounted) return;

      if (qrCode != null) {
        _processScannedServerQrCode(qrCode);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No QR code found in the selected image')));
      }
    } catch (e, stackTrace) {
      _logger.e('Error scanning QR from image', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning QR code: ${e.toString()}')));
      }
    }
  }

  // Process scanned server QR code
  void _processScannedServerQrCode(String qrCode) {
    _logger.d('Processing scanned server QR code: $qrCode');
    try {
      if (!mounted) return;

      final connectionData = _lanSyncService.parseConnectionQrData(qrCode);
      if (connectionData == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid QR code format')));
        return;
      }

      // Update the UI with the scanned data
      setState(() {
        _ipAddressController.text = connectionData['ip']!;
        _clientPortController.text = connectionData['port']!;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully scanned server: ${connectionData["name"]}')));
    } catch (e, stackTrace) {
      _logger.e('Error processing scanned QR code', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error processing QR code: ${e.toString()}')));
      }
    }
  }

  // Build server section
  Widget _buildServerSection() {
    // Get the current device info
    final deviceInfo = _lanSyncService.getCurrentDeviceInfo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Server Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Start a server to allow other devices to connect and send data to this device.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _serverPortController,
                decoration: const InputDecoration(
                  labelText: 'Server Port',
                  border: OutlineInputBorder(),
                  helperText: 'Custom port (default: ${lan_sync.LanSyncService.defaultPort})',
                  helperMaxLines: 2,
                  helperStyle: TextStyle(fontSize: 12),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isServerRunning,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: ElevatedButton(onPressed: _isServerRunning ? _stopServer : _startServer, child: Text(_isServerRunning ? 'Stop Server' : 'Start Server')),
            ),
          ],
        ),
        if (_isServerRunning) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Server is running - other devices can connect to you', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
              IconButton(icon: const Icon(Icons.qr_code, color: Colors.blue), tooltip: 'Show QR Code', onPressed: _showServerQrCode),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tell other devices to connect to:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.computer, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Device: ${_deviceNameController.text}', style: const TextStyle(fontWeight: FontWeight.w500))),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(179), // 0.7 opacity
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(128)), // 0.5 opacity
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Connection Information:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.wifi, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('IP Address: ${deviceInfo?.ipAddress ?? "Retrieving..."}', style: const TextStyle(fontWeight: FontWeight.w500))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.numbers, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Port: ${_serverPortController.text}', style: const TextStyle(fontWeight: FontWeight.w500))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('Other devices should use these values to connect', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Build client section
  Widget _buildClientSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Client Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Connect to another device to send OTP entries and settings to that device.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ipAddressController,
                decoration: const InputDecoration(
                  labelText: 'Server IP Address',
                  border: OutlineInputBorder(),
                  helperText: 'IP address of the device running the server',
                  helperMaxLines: 2,
                  helperStyle: TextStyle(fontSize: 12),
                ),
                enabled: !_isConnectedToServer,
              ),
            ),
            if (!_isConnectedToServer) ...[
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.qr_code_scanner), tooltip: 'Scan Server QR Code', onPressed: _scanServerQrCode),
              IconButton(icon: const Icon(Icons.image), tooltip: 'Scan QR from Image', onPressed: _scanServerQrFromImage),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _clientPortController,
                decoration: const InputDecoration(
                  labelText: 'Server Port',
                  border: OutlineInputBorder(),
                  helperText: 'Port of the remote server',
                  helperMaxLines: 2,
                  helperStyle: TextStyle(fontSize: 12),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isConnectedToServer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: ElevatedButton(
                onPressed: _isConnectedToServer ? _disconnectFromServer : _connectToServer,
                child: Text(_isConnectedToServer ? 'Disconnect' : 'Connect'),
              ),
            ),
          ],
        ),
        if (_isConnectedToServer) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Connected to server at ${_ipAddressController.text}:${_clientPortController.text}', style: const TextStyle(color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Include Settings'),
                  subtitle: const Text('Uncheck to sync only OTP data'),
                  value: _syncSettings,
                  onChanged: (value) {
                    setState(() {
                      _syncSettings = value ?? true;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sendSyncData,
                  icon: const Icon(Icons.upload),
                  label: Text('Send Data FROM ${_deviceNameController.text} TO server at ${_ipAddressController.text}:${_clientPortController.text}'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
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

  // Build error section
  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.red.withAlpha(26), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
