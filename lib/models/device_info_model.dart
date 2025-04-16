import 'dart:convert';

class DeviceInfoModel {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DateTime lastSeen;

  DeviceInfoModel({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  // Create from JSON
  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    return DeviceInfoModel(
      id: json['id'],
      name: json['name'],
      ipAddress: json['ipAddress'],
      port: json['port'],
      lastSeen: DateTime.parse(json['lastSeen']),
    );
  }

  // Convert to string for network transmission
  String toTransmissionString() {
    return jsonEncode(toJson());
  }

  // Create from transmission string
  factory DeviceInfoModel.fromTransmissionString(String data) {
    return DeviceInfoModel.fromJson(jsonDecode(data));
  }

  // Create a copy with updated fields
  DeviceInfoModel copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    DateTime? lastSeen,
  }) {
    return DeviceInfoModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  // Update the lastSeen timestamp
  DeviceInfoModel withUpdatedTimestamp() {
    return copyWith(lastSeen: DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
