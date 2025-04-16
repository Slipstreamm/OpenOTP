import 'dart:math';
import 'package:otp/otp.dart';
import '../models/otp_entry.dart';
import 'logger_service.dart';

class OtpService {
  final LoggerService _logger = LoggerService();

  // Generate a TOTP code for a given OTP entry
  String generateTotp(OtpEntry entry) {
    _logger.d('Generating TOTP code for ${entry.name}');
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
      rethrow;
    }
  }

  // Get the remaining seconds until the next TOTP code
  // Uses the package's built-in method
  int getRemainingSeconds(OtpEntry entry) {
    _logger.d('Getting remaining seconds for ${entry.name}');
    try {
      // Generate a code first to set the lastUsedTime in the OTP package
      generateTotp(entry);
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
  bool verifyOtp(String userCode, OtpEntry entry) {
    _logger.d('Verifying OTP code for ${entry.name}');
    try {
      final generatedCode = generateTotp(entry);
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
