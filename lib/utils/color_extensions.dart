import 'package:flutter/material.dart';

/// Extensions for the Color class
extension ColorExtensions on Color {
  /// Creates a copy of this color with the given values replaced.
  /// This is a more precise alternative to withOpacity() to avoid precision loss.
  Color withValues({int? red, int? green, int? blue, double? alpha}) {
    return Color.fromARGB(alpha != null ? (alpha * 255).round() : a.toInt(), red ?? r.toInt(), green ?? g.toInt(), blue ?? b.toInt());
  }
}
