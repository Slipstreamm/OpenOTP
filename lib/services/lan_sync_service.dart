import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/device_info_model.dart';
import '../models/sync_data_model.dart';
import '../models/sync_protocol_message.dart';
import '../services/crypto_service.dart';
import '../services/logger_service.dart';
import '../services/settings_service.dart';

/// Service for LAN synchronization using TCP sockets
class LanSyncService {
  // Constants
  static const int defaultPort = 57579;
  static const String protocolVersion = '1.0';
  static const int connectionTimeout = 30; // seconds

  // Services
  final LoggerService _logger = LoggerService();
  final CryptoService _cryptoService = CryptoService();
  final SettingsService _settingsService = SettingsService();

  // Device information
  String? _deviceId;
  String? _deviceName;
  String? _ipAddress;

  // Server
  ServerSocket? _server;
  final Map<String, Socket> _connectedClients = {};

  // Client
  Socket? _clientSocket;

  // Streams
  final StreamController<DeviceInfoModel> _deviceDiscoveredController = StreamController<DeviceInfoModel>.broadcast();
  final StreamController<SyncDataModel> _dataReceivedController = StreamController<SyncDataModel>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  final StreamController<ConnectionState> _connectionStateController = StreamController<ConnectionState>.broadcast();

  // Getters for streams
  Stream<DeviceInfoModel> get onDeviceDiscovered => _deviceDiscoveredController.stream;
  Stream<SyncDataModel> get onDataReceived => _dataReceivedController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<ConnectionState> get onConnectionStateChanged => _connectionStateController.stream;

  // Singleton pattern
  static final LanSyncService _instance = LanSyncService._internal();
  factory LanSyncService() => _instance;
  LanSyncService._internal();

  // Initialize the service
  Future<void> initialize() async {
    _logger.d('Initializing LAN sync service');
    try {
      await _initializeDeviceInfo();
      _logger.i('LAN sync service initialized');
    } catch (e, stackTrace) {
      _logger.e('Error initializing LAN sync service', e, stackTrace);
      _errorController.add('Failed to initialize LAN sync service: ${e.toString()}');
    }
  }

  // Initialize device information
  Future<void> _initializeDeviceInfo() async {
    _logger.d('Initializing device information');

    // Generate a unique device ID if not already set
    _deviceId ??= const Uuid().v4();

    // Get device name
    String defaultDeviceName = 'OpenOTP Sync Device';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.name;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceName = windowsInfo.computerName;
        defaultDeviceName = _deviceName ?? defaultDeviceName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _deviceName = linuxInfo.prettyName;
        defaultDeviceName = _deviceName ?? defaultDeviceName;
      } else if (Platform.isMacOS) {
        final macOsInfo = await deviceInfo.macOsInfo;
        _deviceName = macOsInfo.computerName;
        defaultDeviceName = _deviceName ?? defaultDeviceName;
      } else {
        _deviceName = defaultDeviceName;
      }
    } catch (e, stackTrace) {
      _logger.e('Error getting device name', e, stackTrace);
      _deviceName = defaultDeviceName;
    }

    // Get IP address
    final networkInfo = NetworkInfo();
    _ipAddress = await networkInfo.getWifiIP();

    // Update settings with default device name if empty
    try {
      final settingsService = SettingsService();
      final settings = await settingsService.loadSettings();
      if (settings.deviceName.isEmpty) {
        await settingsService.updateDeviceName(_deviceName!);
        _logger.i('Updated settings with default device name: $_deviceName');
      }
    } catch (e, stackTrace) {
      _logger.e('Error updating settings with default device name', e, stackTrace);
    }

    _logger.i('Device info initialized: ID=$_deviceId, Name=$_deviceName, IP=$_ipAddress');
  }

  // Start the server
  Future<bool> startServer({int port = defaultPort}) async {
    _logger.d('Starting LAN sync server on port $port');

    if (_server != null) {
      _logger.w('Server is already running');
      return true;
    }

    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _logger.i('Server started on ${_server!.address.address}:${_server!.port}');

      // Update IP address if it's null or if we're using a loopback address
      if (_ipAddress == null || _ipAddress == '127.0.0.1' || _ipAddress!.isEmpty) {
        // Try to get the IP address again
        final networkInfo = NetworkInfo();
        _ipAddress = await networkInfo.getWifiIP();

        // If still null, use the server's address (though it might be 0.0.0.0)
        if (_ipAddress == null || _ipAddress!.isEmpty) {
          // Get a more specific IP address
          _ipAddress = await _getLocalIpAddress();
          if (_ipAddress == null || _ipAddress!.isEmpty) {
            // Fallback to the server's address
            _ipAddress = _server!.address.address;
          }
        }

        _logger.i('Updated IP address to: $_ipAddress');
      }

      _server!.listen(
        _handleClientConnection,
        onError: (error) {
          _logger.e('Server error', error);
          _errorController.add('Server error: ${error.toString()}');
        },
        onDone: () {
          _logger.i('Server closed');
          _connectionStateController.add(ConnectionState.disconnected);
        },
      );

      _connectionStateController.add(ConnectionState.listening);
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error starting server', e, stackTrace);
      _errorController.add('Failed to start server: ${e.toString()}');
      return false;
    }
  }

  // Stop the server
  Future<void> stopServer() async {
    _logger.d('Stopping LAN sync server');

    // Close all client connections
    for (final socket in _connectedClients.values) {
      try {
        socket.destroy();
      } catch (e) {
        _logger.w('Error closing client socket: $e');
      }
    }
    _connectedClients.clear();

    // Close the server
    if (_server != null) {
      await _server!.close();
      _server = null;
      _logger.i('Server stopped');
      _connectionStateController.add(ConnectionState.disconnected);
    }
  }

  // Handle a new client connection
  void _handleClientConnection(Socket client) {
    _logger.d('New client connected: ${client.remoteAddress.address}:${client.remotePort}');

    // Buffer for incoming data
    List<int> dataBuffer = [];
    int? expectedLength;

    client.listen(
      (data) {
        // Add data to buffer
        dataBuffer.addAll(data);

        // Process complete messages
        while (dataBuffer.isNotEmpty) {
          // If we don't know the message length yet, try to read it
          if (expectedLength == null) {
            if (dataBuffer.length >= 4) {
              // Read the message length from the first 4 bytes
              final headerBytes = Uint8List.fromList(dataBuffer.sublist(0, 4));
              expectedLength = ByteData.view(headerBytes.buffer).getUint32(0, Endian.big);

              // Remove the header from the buffer
              dataBuffer = dataBuffer.sublist(4);
            } else {
              // Not enough data to read the header
              break;
            }
          }

          // If we have a complete message, process it
          if (dataBuffer.length >= expectedLength!) {
            final messageBytes = dataBuffer.sublist(0, expectedLength!);
            final messageString = utf8.decode(messageBytes);

            // Process the message
            _processClientMessage(client, messageString);

            // Remove the processed message from the buffer
            dataBuffer = dataBuffer.sublist(expectedLength!);
            expectedLength = null;
          } else {
            // Not enough data for a complete message
            break;
          }
        }
      },
      onError: (error) {
        _logger.e('Error from client ${client.remoteAddress.address}', error);
        _errorController.add('Client error: ${error.toString()}');
        client.destroy();
        _removeClient(client);
      },
      onDone: () {
        _logger.i('Client disconnected: ${client.remoteAddress.address}');
        _removeClient(client);
      },
    );
  }

  // Process a message from a client
  void _processClientMessage(Socket client, String messageString) async {
    _logger.d('Processing message from client ${client.remoteAddress.address}');

    try {
      final messageJson = jsonDecode(messageString);
      final message = SyncProtocolMessage.fromJson(messageJson);

      switch (message.type) {
        case MessageType.handshake:
          await _handleHandshake(client, message);
          break;
        case MessageType.authenticate:
          await _handleAuthentication(client, message);
          break;
        case MessageType.data:
          await _handleDataMessage(client, message);
          break;
        case MessageType.ack:
          _handleAcknowledgment(message);
          break;
        case MessageType.disconnect:
          _handleDisconnect(client, message);
          break;
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing client message', e, stackTrace);
      _sendErrorToClient(client, 'Failed to process message: ${e.toString()}');
    }
  }

  // Handle a handshake message
  Future<void> _handleHandshake(Socket client, SyncProtocolMessage message) async {
    _logger.d('Handling handshake from client');

    final deviceId = message.payload['deviceId'];
    final deviceName = message.payload['deviceName'];
    final version = message.payload['version'];

    // Check protocol version compatibility
    if (version != protocolVersion) {
      _logger.w('Protocol version mismatch: $version vs $protocolVersion');
      _sendErrorToClient(client, 'Protocol version mismatch');
      return;
    }

    // Store client information
    _connectedClients[deviceId] = client;

    // Create device info model
    final deviceInfo = DeviceInfoModel(id: deviceId, name: deviceName, ipAddress: client.remoteAddress.address, port: client.remotePort);

    // Notify listeners
    _deviceDiscoveredController.add(deviceInfo);

    // Send acknowledgment
    final ackMessage = SyncProtocolMessage.ack(message.messageId, true, null);

    _sendMessageToClient(client, ackMessage);

    _logger.i('Handshake completed with device: $deviceName ($deviceId)');
  }

  // Handle an authentication message
  Future<void> _handleAuthentication(Socket client, SyncProtocolMessage message) async {
    _logger.d('Handling authentication from client');

    final pin = message.payload['pin'];

    // Get the stored PIN from settings
    final settings = await _settingsService.loadSettings();
    final storedPin = settings.syncPin ?? '123456'; // Use default if not set

    // Verify the PIN using the crypto service
    bool success = _cryptoService.verifyPin(pin, _cryptoService.hashPin(storedPin));
    String? errorMessage;

    if (!success) {
      errorMessage = 'Invalid PIN';
      _logger.w('Authentication failed: Invalid PIN');
    } else {
      _logger.i('PIN verification successful');
    }

    // Send acknowledgment
    final ackMessage = SyncProtocolMessage.ack(message.messageId, success, errorMessage);

    _sendMessageToClient(client, ackMessage);

    _logger.i('Authentication successful');
  }

  // Handle a data message
  Future<void> _handleDataMessage(Socket client, SyncProtocolMessage message) async {
    _logger.d('Handling data message from client');

    final encryptedData = message.payload['data'];

    try {
      // Get PIN from settings
      final settings = await _settingsService.loadSettings();
      final pin = settings.syncPin ?? '123456'; // Use default if not set

      // Decrypt the data
      // The CryptoService now automatically handles the salt extraction from the encrypted data
      final decryptedData = await _cryptoService.decrypt(encryptedData, pin);

      // Parse the sync data
      final syncData = SyncDataModel.fromTransmissionString(decryptedData);

      // Notify listeners
      _dataReceivedController.add(syncData);

      // Send acknowledgment
      final ackMessage = SyncProtocolMessage.ack(message.messageId, true, null);

      _sendMessageToClient(client, ackMessage);

      _logger.i('Data message processed successfully');
    } catch (e, stackTrace) {
      _logger.e('Error processing data message', e, stackTrace);

      // Send error acknowledgment
      final ackMessage = SyncProtocolMessage.ack(message.messageId, false, 'Failed to process data: ${e.toString()}');

      _sendMessageToClient(client, ackMessage);
    }
  }

  // Handle an acknowledgment message
  void _handleAcknowledgment(SyncProtocolMessage message) {
    _logger.d('Handling acknowledgment message');

    final originalMessageId = message.payload['originalMessageId'];
    final success = message.payload['success'];
    final errorMessage = message.payload['errorMessage'];

    if (success) {
      _logger.i('Message $originalMessageId acknowledged successfully');
    } else {
      _logger.w('Message $originalMessageId failed: $errorMessage');
      _errorController.add('Sync error: $errorMessage');
    }
  }

  // Handle a disconnect message
  void _handleDisconnect(Socket client, SyncProtocolMessage message) {
    _logger.d('Handling disconnect message');

    final reason = message.payload['reason'];
    _logger.i('Client disconnecting: $reason');

    // Close the connection
    client.destroy();
    _removeClient(client);
  }

  // Remove a client from the connected clients list
  void _removeClient(Socket client) {
    String? deviceIdToRemove;

    for (final entry in _connectedClients.entries) {
      if (entry.value == client) {
        deviceIdToRemove = entry.key;
        break;
      }
    }

    if (deviceIdToRemove != null) {
      _connectedClients.remove(deviceIdToRemove);
      _logger.i('Removed client: $deviceIdToRemove');
    }
  }

  // Send a message to a client
  void _sendMessageToClient(Socket client, SyncProtocolMessage message) {
    _logger.d('Sending message to client: ${message.type}');

    try {
      final bytes = message.toBytes();
      client.add(bytes);
    } catch (e, stackTrace) {
      _logger.e('Error sending message to client', e, stackTrace);
    }
  }

  // Send an error message to a client
  void _sendErrorToClient(Socket client, String errorMessage) {
    _logger.d('Sending error to client: $errorMessage');

    final message = SyncProtocolMessage.ack(DateTime.now().millisecondsSinceEpoch.toString(), false, errorMessage);

    _sendMessageToClient(client, message);
  }

  // Connect to a server
  Future<bool> connectToServer(String ipAddress, int port, String pin) async {
    _logger.d('Connecting to server at $ipAddress:$port');

    if (_clientSocket != null) {
      _logger.w('Already connected to a server');
      return false;
    }

    try {
      // Connect to the server
      _clientSocket = await Socket.connect(ipAddress, port).timeout(const Duration(seconds: connectionTimeout));

      _logger.i('Connected to server at $ipAddress:$port');
      _connectionStateController.add(ConnectionState.connected);

      // Send handshake
      final handshakeMessage = SyncProtocolMessage.handshake(_deviceId!, _deviceName!, protocolVersion);

      _sendMessageToServer(handshakeMessage);

      // Set up listener for server responses
      _setupServerListener();

      // Send authentication
      final authMessage = SyncProtocolMessage.authenticate(pin);
      _sendMessageToServer(authMessage);

      return true;
    } catch (e, stackTrace) {
      _logger.e('Error connecting to server', e, stackTrace);
      _errorController.add('Failed to connect to server: ${e.toString()}');

      // Clean up if connection failed
      if (_clientSocket != null) {
        _clientSocket!.destroy();
        _clientSocket = null;
      }

      _connectionStateController.add(ConnectionState.disconnected);
      return false;
    }
  }

  // Set up listener for server responses
  void _setupServerListener() {
    _logger.d('Setting up server listener');

    if (_clientSocket == null) {
      _logger.w('Cannot set up server listener: not connected');
      return;
    }

    // Buffer for incoming data
    List<int> dataBuffer = [];
    int? expectedLength;

    _clientSocket!.listen(
      (data) {
        // Add data to buffer
        dataBuffer.addAll(data);

        // Process complete messages
        while (dataBuffer.isNotEmpty) {
          // If we don't know the message length yet, try to read it
          if (expectedLength == null) {
            if (dataBuffer.length >= 4) {
              // Read the message length from the first 4 bytes
              final headerBytes = Uint8List.fromList(dataBuffer.sublist(0, 4));
              expectedLength = ByteData.view(headerBytes.buffer).getUint32(0, Endian.big);

              // Remove the header from the buffer
              dataBuffer = dataBuffer.sublist(4);
            } else {
              // Not enough data to read the header
              break;
            }
          }

          // If we have a complete message, process it
          if (dataBuffer.length >= expectedLength!) {
            final messageBytes = dataBuffer.sublist(0, expectedLength!);
            final messageString = utf8.decode(messageBytes);

            // Process the message
            _processServerMessage(messageString);

            // Remove the processed message from the buffer
            dataBuffer = dataBuffer.sublist(expectedLength!);
            expectedLength = null;
          } else {
            // Not enough data for a complete message
            break;
          }
        }
      },
      onError: (error) {
        _logger.e('Error from server', error);
        _errorController.add('Server error: ${error.toString()}');
        disconnectFromServer();
      },
      onDone: () {
        _logger.i('Disconnected from server');
        _clientSocket = null;
        _connectionStateController.add(ConnectionState.disconnected);
      },
    );
  }

  // Process a message from the server
  void _processServerMessage(String messageString) {
    _logger.d('Processing message from server');

    try {
      final messageJson = jsonDecode(messageString);
      final message = SyncProtocolMessage.fromJson(messageJson);

      switch (message.type) {
        case MessageType.handshake:
          _logger.w('Unexpected handshake message from server');
          break;
        case MessageType.authenticate:
          _logger.w('Unexpected authentication message from server');
          break;
        case MessageType.data:
          _handleServerDataMessage(message);
          break;
        case MessageType.ack:
          _handleAcknowledgment(message);
          break;
        case MessageType.disconnect:
          _handleServerDisconnect(message);
          break;
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing server message', e, stackTrace);
    }
  }

  // Handle a data message from the server
  Future<void> _handleServerDataMessage(SyncProtocolMessage message) async {
    _logger.d('Handling data message from server');

    final encryptedData = message.payload['data'];

    try {
      // Get PIN from settings
      final settings = await _settingsService.loadSettings();
      final pin = settings.syncPin ?? '123456'; // Use default if not set

      // Decrypt the data
      // The CryptoService now automatically handles the salt extraction from the encrypted data
      final decryptedData = await _cryptoService.decrypt(encryptedData, pin);

      // Parse the sync data
      final syncData = SyncDataModel.fromTransmissionString(decryptedData);

      // Notify listeners
      _dataReceivedController.add(syncData);

      // Send acknowledgment
      final ackMessage = SyncProtocolMessage.ack(message.messageId, true, null);

      _sendMessageToServer(ackMessage);

      _logger.i('Server data message processed successfully');
    } catch (e, stackTrace) {
      _logger.e('Error processing server data message', e, stackTrace);

      // Send error acknowledgment
      final ackMessage = SyncProtocolMessage.ack(message.messageId, false, 'Failed to process data: ${e.toString()}');

      _sendMessageToServer(ackMessage);
    }
  }

  // Handle a disconnect message from the server
  void _handleServerDisconnect(SyncProtocolMessage message) {
    _logger.d('Handling disconnect message from server');

    final reason = message.payload['reason'];
    _logger.i('Server disconnecting: $reason');

    // Close the connection
    disconnectFromServer();
  }

  // Send a message to the server
  void _sendMessageToServer(SyncProtocolMessage message) {
    _logger.d('Sending message to server: ${message.type}');

    if (_clientSocket == null) {
      _logger.w('Cannot send message: not connected to server');
      return;
    }

    try {
      final bytes = message.toBytes();
      _clientSocket!.add(bytes);
    } catch (e, stackTrace) {
      _logger.e('Error sending message to server', e, stackTrace);
    }
  }

  // Disconnect from the server
  Future<void> disconnectFromServer() async {
    _logger.d('Disconnecting from server');

    if (_clientSocket != null) {
      try {
        // Send disconnect message
        final disconnectMessage = SyncProtocolMessage.disconnect('Client initiated disconnect');
        _sendMessageToServer(disconnectMessage);

        // Close the socket
        await _clientSocket!.close();
      } catch (e) {
        _logger.w('Error during disconnect: $e');
      } finally {
        _clientSocket = null;
        _connectionStateController.add(ConnectionState.disconnected);
      }
    }
  }

  // Send sync data to a connected device
  Future<bool> sendSyncData(SyncDataModel syncData, String pin) async {
    _logger.d('Sending sync data');

    if (_clientSocket == null) {
      _logger.w('Cannot send sync data: not connected to a server');
      return false;
    }

    try {
      // Convert sync data to string
      final dataString = syncData.toTransmissionString();

      // Encrypt the data using the improved CryptoService
      // The salt is now automatically handled by the CryptoService
      final encryptedData = await _cryptoService.encrypt(dataString, pin);

      // Create data message
      final dataMessage = SyncProtocolMessage.data(encryptedData);

      // Send the message
      _sendMessageToServer(dataMessage);

      _logger.i('Sync data sent successfully');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error sending sync data', e, stackTrace);
      _errorController.add('Failed to send sync data: ${e.toString()}');
      return false;
    }
  }

  // Get current device information
  DeviceInfoModel? getCurrentDeviceInfo() {
    if (_deviceId == null || _deviceName == null || _ipAddress == null) {
      return null;
    }

    return DeviceInfoModel(id: _deviceId!, name: _deviceName!, ipAddress: _ipAddress!, port: _server?.port ?? defaultPort);
  }

  // Get the local IP address using network interfaces
  Future<String?> _getLocalIpAddress() async {
    _logger.d('Getting local IP address');
    try {
      final interfaces = await NetworkInterface.list(includeLinkLocal: false, type: InternetAddressType.IPv4);

      // Find the first non-loopback IPv4 address
      for (var interface in interfaces) {
        _logger.d('Checking interface: ${interface.name}');
        for (var addr in interface.addresses) {
          final ip = addr.address;
          _logger.d('Found address: $ip');
          if (!ip.startsWith('127.') && !ip.startsWith('0.') && ip != '::1') {
            _logger.i('Selected IP address: $ip');
            return ip;
          }
        }
      }

      _logger.w('No suitable IP address found');
      return null;
    } catch (e, stackTrace) {
      _logger.e('Error getting local IP address', e, stackTrace);
      return null;
    }
  }

  // Generate a QR code data string for server connection
  String generateServerQrData() {
    _logger.d('Generating server QR data');
    final deviceInfo = getCurrentDeviceInfo();
    if (deviceInfo == null) {
      _logger.w('Cannot generate QR data: device info not available');
      return '';
    }

    // Format: otpsync://connect?ip=IP&port=PORT&name=NAME
    final uri = Uri(
      scheme: 'otpsync',
      host: 'connect',
      queryParameters: {'ip': deviceInfo.ipAddress, 'port': deviceInfo.port.toString(), 'name': deviceInfo.name},
    );

    _logger.i('Generated server QR data: ${uri.toString()}');
    return uri.toString();
  }

  // Parse QR code data for client connection
  Map<String, String>? parseConnectionQrData(String qrData) {
    _logger.d('Parsing connection QR data: $qrData');
    try {
      final uri = Uri.parse(qrData);

      // Validate the URI format
      if (uri.scheme != 'otpsync' || uri.host != 'connect') {
        _logger.w('Invalid QR data format: $qrData');
        return null;
      }

      // Extract the connection parameters
      final ip = uri.queryParameters['ip'];
      final portStr = uri.queryParameters['port'];
      final name = uri.queryParameters['name'];

      if (ip == null || portStr == null) {
        _logger.w('Missing required parameters in QR data');
        return null;
      }

      // Validate port
      final port = int.tryParse(portStr);
      if (port == null || port <= 0 || port > 65535) {
        _logger.w('Invalid port in QR data: $portStr');
        return null;
      }

      _logger.i('Successfully parsed connection QR data');
      return {'ip': ip, 'port': portStr, 'name': name ?? 'Unknown Device'};
    } catch (e, stackTrace) {
      _logger.e('Error parsing connection QR data', e, stackTrace);
      return null;
    }
  }

  // Dispose the service
  void dispose() {
    _logger.d('Disposing LAN sync service');

    stopServer();
    disconnectFromServer();

    _deviceDiscoveredController.close();
    _dataReceivedController.close();
    _errorController.close();
    _connectionStateController.close();
  }
}

/// Connection states for the LAN sync service
enum ConnectionState { disconnected, connecting, connected, listening }
