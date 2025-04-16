import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/logger_service.dart';

class CryptoService {
  static const String _saltKey = 'crypto_salt_key';
  static const String _legacySalt = 'OpenOTPSyncSalt';

  final LoggerService _logger = LoggerService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Generate a secure random salt
  Future<Uint8List> _generateSalt({int length = 32}) async {
    _logger.d('Generating secure random salt');
    try {
      final random = Random.secure();
      final salt = Uint8List(length);
      for (var i = 0; i < length; i++) {
        salt[i] = random.nextInt(256);
      }
      _logger.i('Generated secure random salt');
      return salt;
    } catch (e, stackTrace) {
      _logger.e('Error generating salt', e, stackTrace);
      rethrow;
    }
  }

  // Store the salt in secure storage
  Future<void> _storeSalt(Uint8List salt) async {
    _logger.d('Storing salt in secure storage');
    try {
      final saltBase64 = base64.encode(salt);
      await _secureStorage.write(key: _saltKey, value: saltBase64);
      _logger.i('Salt stored successfully');
    } catch (e, stackTrace) {
      _logger.e('Error storing salt', e, stackTrace);
      rethrow;
    }
  }

  // Get the salt from secure storage or generate a new one if it doesn't exist
  Future<Uint8List> _getSalt() async {
    _logger.d('Getting salt from secure storage');
    try {
      final saltBase64 = await _secureStorage.read(key: _saltKey);
      if (saltBase64 == null || saltBase64.isEmpty) {
        _logger.i('No salt found in storage, generating a new one');
        final newSalt = await _generateSalt();
        await _storeSalt(newSalt);
        return newSalt;
      }
      _logger.i('Retrieved salt from storage');
      return Uint8List.fromList(base64.decode(saltBase64));
    } catch (e, stackTrace) {
      _logger.e('Error getting salt', e, stackTrace);
      rethrow;
    }
  }

  // Generate a key from a PIN using the stored salt
  Future<Key> _generateKeyFromPin(String pin, {Uint8List? providedSalt}) async {
    _logger.d('Generating key from PIN');

    // Use PBKDF2 to derive a key from the PIN
    // We use a unique salt stored in secure storage for better security
    final salt = providedSalt ?? await _getSalt();
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);

    // Generate a 32-byte (256-bit) key
    final secretKey = await pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    final keyBytes = await secretKey.extractBytes();
    return Key(Uint8List.fromList(keyBytes));
  }

  // Generate a key from a PIN using the legacy fixed salt (for backward compatibility)
  Future<Key> _generateKeyFromPinLegacy(String pin) async {
    _logger.d('Generating key from PIN using legacy salt');

    // Use PBKDF2 to derive a key from the PIN with the legacy fixed salt
    final salt = utf8.encode(_legacySalt);
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256);

    // Generate a 32-byte (256-bit) key
    final secretKey = await pbkdf2.deriveKey(secretKey: SecretKey(utf8.encode(pin)), nonce: salt);
    final keyBytes = await secretKey.extractBytes();
    return Key(Uint8List.fromList(keyBytes));
  }

  // Encrypt data using AES with a PIN
  Future<String> encrypt(String data, String pin) async {
    _logger.d('Encrypting data');
    try {
      // Get or generate a salt
      final salt = await _getSalt();

      // Generate a key using the salt
      final key = await _generateKeyFromPin(pin, providedSalt: salt);
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

      final encrypted = encrypter.encrypt(data, iv: iv);

      // Combine IV, salt, and encrypted data for transmission
      // Include version to support future format changes
      final result = {
        'version': 2, // Version 2 includes salt
        'iv': base64.encode(iv.bytes),
        'salt': base64.encode(salt),
        'data': encrypted.base64,
      };

      return jsonEncode(result);
    } catch (e, stackTrace) {
      _logger.e('Error encrypting data', e, stackTrace);
      rethrow;
    }
  }

  // Decrypt data using AES with a PIN
  Future<String> decrypt(String encryptedData, String pin) async {
    _logger.d('Decrypting data');
    try {
      // Parse the encrypted data JSON
      final encryptedJson = jsonDecode(encryptedData);

      // Validate required fields
      if (!encryptedJson.containsKey('iv') || !encryptedJson.containsKey('data')) {
        _logger.e('Invalid encrypted data format: missing required fields');
        throw FormatException('Invalid encrypted data format: missing required fields');
      }

      final iv = IV.fromBase64(encryptedJson['iv']);
      final encrypted = Encrypted.fromBase64(encryptedJson['data']);

      // Check if the data was encrypted with a version that includes salt
      final version = encryptedJson['version'] ?? 1;
      Key key;

      if (version >= 2 && encryptedJson.containsKey('salt')) {
        // Version 2+ format with included salt
        _logger.d('Decrypting with version 2+ format (includes salt)');
        final salt = Uint8List.fromList(base64.decode(encryptedJson['salt']));
        key = await _generateKeyFromPin(pin, providedSalt: salt);
      } else {
        // Legacy format (version 1) with fixed salt
        _logger.d('Decrypting with legacy format (fixed salt)');
        key = await _generateKeyFromPinLegacy(pin);
      }

      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final decryptedData = encrypter.decrypt(encrypted, iv: iv);

      // Log a sample of the decrypted data to help with debugging
      final previewLength = decryptedData.length > 50 ? 50 : decryptedData.length;
      _logger.d('Data decrypted successfully. Preview: ${decryptedData.substring(0, previewLength)}...');

      return decryptedData;
    } catch (e, stackTrace) {
      _logger.e('Error decrypting data: ${e.toString()}', e, stackTrace);
      rethrow;
    }
  }

  // Generate a hash of the PIN for verification
  String hashPin(String pin) {
    _logger.d('Hashing PIN');
    try {
      final bytes = utf8.encode(pin);
      final digest = crypto.sha256.convert(bytes);
      return digest.toString();
    } catch (e, stackTrace) {
      _logger.e('Error hashing PIN', e, stackTrace);
      rethrow;
    }
  }

  // Verify a PIN against a hash
  bool verifyPin(String pin, String hash) {
    _logger.d('Verifying PIN');
    try {
      final pinHash = hashPin(pin);
      return pinHash == hash;
    } catch (e, stackTrace) {
      _logger.e('Error verifying PIN', e, stackTrace);
      return false;
    }
  }
}
