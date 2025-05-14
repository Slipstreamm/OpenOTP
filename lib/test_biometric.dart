import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biometric Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BiometricTestScreen(),
    );
  }
}

class BiometricTestScreen extends StatefulWidget {
  const BiometricTestScreen({super.key});

  @override
  State<BiometricTestScreen> createState() => _BiometricTestScreenState();
}

class _BiometricTestScreenState extends State<BiometricTestScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  String _status = 'Not authenticated';
  bool _isEmulator = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
    _checkIfEmulator();
  }

  Future<void> _checkBiometrics() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      
      if (canAuthenticate) {
        final availableBiometrics = await _localAuth.getAvailableBiometrics();
        setState(() {
          _availableBiometrics = availableBiometrics;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error checking biometrics: $e';
      });
    }
  }

  Future<void> _checkIfEmulator() async {
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        setState(() {
          _isEmulator = !androidInfo.isPhysicalDevice;
        });
      } catch (e) {
        print('Error checking if device is emulator: $e');
      }
    }
  }

  Future<void> _authenticate() async {
    try {
      setState(() {
        _status = 'Authenticating...';
      });

      // Special handling for emulators
      if (_isEmulator && _availableBiometrics.isEmpty) {
        setState(() {
          _status = 'Emulator detected with no biometrics. Simulating success.';
        });
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to test biometrics',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
          biometricOnly: true,
        ),
      );

      setState(() {
        _status = authenticated ? 'Authentication successful' : 'Authentication failed';
      });
    } catch (e) {
      setState(() {
        _status = 'Error during authentication: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Is Emulator: $_isEmulator'),
            const SizedBox(height: 20),
            Text('Available Biometrics: ${_availableBiometrics.join(", ")}'),
            const SizedBox(height: 20),
            Text('Status: $_status'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('Authenticate with Biometrics'),
            ),
          ],
        ),
      ),
    );
  }
}
