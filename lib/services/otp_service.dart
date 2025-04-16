import 'dart:math';
import 'package:otp/otp.dart';
import '../models/otp_entry.dart';
import '../utils/base32_utils.dart';
import 'logger_service.dart';
import 'secure_storage_service.dart';

class OtpService {
  final LoggerService _logger = LoggerService();
  final SecureStorageService _storageService = SecureStorageService();

  // Generate an OTP code for a given entry (either TOTP or HOTP)
  Future<String> generateOtp(OtpEntry entry) async {
    if (entry.type == OtpType.totp) {
      return generateTotp(entry);
    } else {
      return await generateHotp(entry);
    }
  }

  // Generate a TOTP code for a given OTP entry
  String generateTotp(OtpEntry entry) {
    _logger.d('Generating TOTP code for ${entry.name}');
    try {
      // Validate the secret key before attempting to generate a code
      if (!Base32Utils.isValidBase32(entry.secret)) {
        _logger.e('Invalid base32 characters in secret for ${entry.name}');
        return 'ERROR';
      }

      // Try to generate the code
      try {
        final code = OTP.generateTOTPCodeString(
          entry.secret,
          DateTime.now().millisecondsSinceEpoch,
          length: entry.digits,
          interval: entry.period,
          algorithm: _getAlgorithm(entry.algorithm),
          isGoogle: true,
        );
        _logger.i('Generated TOTP code for ${entry.name}');
        return code;
      } catch (e, stackTrace) {
        _logger.e('Error generating TOTP code for ${entry.name}', e, stackTrace);
        return 'ERROR';
      }
    } catch (e, stackTrace) {
      _logger.e('Error in generateTotp for ${entry.name}', e, stackTrace);
      return 'ERROR';
    }
  }

  // Generate an HOTP code for a given OTP entry
  Future<String> generateHotp(OtpEntry entry) async {
    _logger.d('Generating HOTP code for ${entry.name} with counter ${entry.counter}');
    try {
      // Validate the secret key before attempting to generate a code
      if (!Base32Utils.isValidBase32(entry.secret)) {
        _logger.e('Invalid base32 characters in secret for ${entry.name}');
        return 'ERROR';
      }

      // Try to generate the code
      try {
        final code = OTP.generateHOTPCodeString(entry.secret, entry.counter, length: entry.digits, algorithm: _getAlgorithm(entry.algorithm));
        _logger.i('Generated HOTP code for ${entry.name}');
        return code;
      } catch (e, stackTrace) {
        _logger.e('Error generating HOTP code for ${entry.name}', e, stackTrace);
        return 'ERROR';
      }
    } catch (e, stackTrace) {
      _logger.e('Error in generateTotp for ${entry.name}', e, stackTrace);
      return 'ERROR';
    }
  }

  // Get the remaining seconds until the next TOTP code
  // Uses the package's built-in method
  // For HOTP, always returns the period (since there's no time component)
  int getRemainingSeconds(OtpEntry entry) {
    // For HOTP, there's no time component, so just return the period
    if (entry.type == OtpType.hotp) {
      return entry.period;
    }

    _logger.d('Getting remaining seconds for ${entry.name}');
    try {
      // Validate the secret key before attempting to get remaining seconds
      if (!Base32Utils.isValidBase32(entry.secret)) {
        _logger.e('Invalid base32 characters in secret for ${entry.name}');
        return entry.period; // Return default period
      }

      // Generate a code first to set the lastUsedTime in the OTP package
      final code = generateTotp(entry);
      if (code == 'ERROR') {
        _logger.w('Could not generate code for ${entry.name}, returning default period');
        return entry.period;
      }

      // Then use the package's method to get remaining seconds
      final seconds = OTP.remainingSeconds(interval: entry.period);
      _logger.d('Remaining seconds for ${entry.name}: $seconds');
      return seconds;
    } catch (e, stackTrace) {
      _logger.e('Error getting remaining seconds for ${entry.name}', e, stackTrace);
      // Default to entry.period in case of error
      return entry.period;
    }
  }

  // Verify an OTP code using constant time comparison to prevent timing attacks
  Future<bool> verifyOtp(String userCode, OtpEntry entry) async {
    _logger.d('Verifying OTP code for ${entry.name}');
    try {
      // Validate the secret key before attempting to verify
      if (!Base32Utils.isValidBase32(entry.secret)) {
        _logger.e('Invalid base32 characters in secret for ${entry.name}');
        return false;
      }

      String generatedCode;
      if (entry.type == OtpType.totp) {
        generatedCode = generateTotp(entry);
      } else {
        generatedCode = await generateHotp(entry);
      }

      if (generatedCode == 'ERROR') {
        _logger.w('Could not generate code for ${entry.name}, verification failed');
        return false;
      }

      final isValid = OTP.constantTimeVerification(userCode, generatedCode);
      _logger.i('OTP code verification for ${entry.name}: ${isValid ? 'valid' : 'invalid'}');
      return isValid;
    } catch (e, stackTrace) {
      _logger.e('Error verifying OTP code for ${entry.name}', e, stackTrace);
      return false;
    }
  }

  // Generate a random secret key for new OTP entries
  String generateSecret({int length = 32}) {
    _logger.d('Generating random secret key with length $length');
    try {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'; // Base32 characters
      final random = Random.secure();
      final secret = List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
      _logger.i('Generated random secret key');
      return secret;
    } catch (e, stackTrace) {
      _logger.e('Error generating random secret key', e, stackTrace);
      rethrow;
    }
  }

  // Increment the counter for an HOTP entry and save it
  Future<OtpEntry> incrementHotpCounter(OtpEntry entry) async {
    _logger.d('Incrementing HOTP counter for ${entry.name} from ${entry.counter} to ${entry.counter + 1}');
    try {
      // Create a new entry with incremented counter
      final updatedEntry = entry.copyWith(counter: entry.counter + 1);

      // Save the updated entry
      await _storageService.updateOtpEntry(updatedEntry);
      _logger.i('Successfully incremented HOTP counter for ${entry.name}');

      return updatedEntry;
    } catch (e, stackTrace) {
      _logger.e('Error incrementing HOTP counter for ${entry.name}', e, stackTrace);
      rethrow;
    }
  }

  // Convert string algorithm to Algorithm enum
  Algorithm _getAlgorithm(String algorithm) {
    _logger.d('Converting algorithm string to enum: $algorithm');
    Algorithm result;
    switch (algorithm.toUpperCase()) {
      case 'SHA256':
        result = Algorithm.SHA256;
        break;
      case 'SHA512':
        result = Algorithm.SHA512;
        break;
      case 'SHA1':
        result = Algorithm.SHA1;
        break;
      default:
        _logger.w('Unknown algorithm: $algorithm, defaulting to SHA1');
        result = Algorithm.SHA1;
        break;
    }
    _logger.d('Algorithm converted: $result');
    return result;
  }
}
