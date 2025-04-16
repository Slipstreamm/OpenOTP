import 'package:base32/base32.dart';

/// Utility class for base32 operations
class Base32Utils {
  /// Checks if a string contains only valid base32 characters
  /// 
  /// Base32 characters are: A-Z and 2-7
  /// Optionally allows padding character '='
  static bool isValidBase32(String input, {bool allowPadding = true}) {
    if (input.isEmpty) {
      return false;
    }

    // Remove padding if allowed
    String cleanInput = input;
    if (allowPadding) {
      cleanInput = input.replaceAll('=', '');
    } else if (input.contains('=')) {
      return false;
    }

    // Check if the string contains only valid base32 characters (A-Z, 2-7)
    final regex = RegExp(r'^[A-Z2-7]+$');
    return regex.hasMatch(cleanInput);
  }

  /// Attempts to decode a base32 string to verify it's valid
  /// 
  /// Returns true if the string can be decoded without errors
  static bool canDecode(String input) {
    if (!isValidBase32(input)) {
      return false;
    }

    try {
      base32.decode(input);
      return true;
    } catch (e) {
      return false;
    }
  }
}
