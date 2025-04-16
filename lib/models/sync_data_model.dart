import 'dart:convert';
import 'package:openotp/models/otp_entry.dart';
import 'package:openotp/models/settings_model.dart';

class SyncDataModel {
  final List<OtpEntry> otpEntries;
  final SettingsModel? settings;
  final DateTime timestamp;
  final String sourceDeviceId;
  final String sourceDeviceName;
  final SyncDirection direction;
  final bool includeSettings;

  SyncDataModel({
    required this.otpEntries,
    this.settings,
    required this.sourceDeviceId,
    required this.sourceDeviceName,
    SyncDirection? direction,
    DateTime? timestamp,
    this.includeSettings = true,
  }) : timestamp = timestamp ?? DateTime.now(),
       direction = direction ?? SyncDirection.bidirectional;

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'otpEntries': otpEntries.map((entry) => entry.toJson()).toList(),
      'settings': settings?.toJson(),
      'timestamp': timestamp.toIso8601String(),
      'sourceDeviceId': sourceDeviceId,
      'sourceDeviceName': sourceDeviceName,
      'direction': direction.index,
      'includeSettings': includeSettings,
    };
  }

  // Create from JSON
  factory SyncDataModel.fromJson(Map<String, dynamic> json) {
    final entriesJson = json['otpEntries'] as List;
    final entries = entriesJson.map((entryJson) => OtpEntry.fromJson(entryJson)).toList();

    SettingsModel? settings;
    if (json['settings'] != null) {
      settings = SettingsModel.fromJson(json['settings']);
    }

    return SyncDataModel(
      otpEntries: entries,
      settings: settings,
      timestamp: DateTime.parse(json['timestamp']),
      sourceDeviceId: json['sourceDeviceId'],
      sourceDeviceName: json['sourceDeviceName'],
      direction: SyncDirection.values[json['direction'] ?? 0],
      includeSettings: json['includeSettings'] ?? true,
    );
  }

  // Convert to string for network transmission
  String toTransmissionString() {
    return jsonEncode(toJson());
  }

  // Create from transmission string
  factory SyncDataModel.fromTransmissionString(String data) {
    return SyncDataModel.fromJson(jsonDecode(data));
  }
}

enum SyncDirection {
  bidirectional, // Sync both ways
  sendOnly, // Only send data to the other device
  receiveOnly, // Only receive data from the other device
}
