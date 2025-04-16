import 'package:flutter/material.dart';

class ColorUtils {
  /// Convert a Color to a hex string
  /// Returns a string in the format #RRGGBB or #AARRGGBB if includeAlpha is true
  static String colorToHex(Color color, {bool includeAlpha = false, bool includeHash = true}) {
    String hex = '';
    if (includeHash) hex += '#';

    if (includeAlpha) {
      hex += color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
    } else {
      // Skip the alpha channel (first 2 digits)
      hex += color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    }

    return hex;
  }

  /// Convert a hex string to a Color
  /// Accepts formats: #RRGGBB, RRGGBB, #AARRGGBB, AARRGGBB
  static Color hexToColor(String hexString, {Color defaultColor = Colors.black}) {
    try {
      String hex = hexString.replaceAll('#', '');

      if (hex.length == 6) {
        // Add alpha channel if not present
        hex = 'FF$hex';
      } else if (hex.length != 8) {
        return defaultColor;
      }

      return Color(int.parse('0x$hex'));
    } catch (e) {
      return defaultColor;
    }
  }

  /// Validate if a string is a valid hex color
  static bool isValidHex(String hexString) {
    // Remove # if present
    final hex = hexString.replaceAll('#', '');

    // Check if it's a valid hex length (6 for RGB or 8 for ARGB)
    if (hex.length != 6 && hex.length != 8) {
      return false;
    }

    // Check if it contains only valid hex characters
    return RegExp(r'^[0-9A-Fa-f]+$').hasMatch(hex);
  }
}
