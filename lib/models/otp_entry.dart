// Enum for OTP type (TOTP or HOTP)
enum OtpType { totp, hotp }

class OtpEntry {
  final String id;
  final String name;
  final String secret;
  final String issuer;
  final int digits;
  final int period; // Only used for TOTP
  final String algorithm;
  final OtpType type; // Type of OTP (TOTP or HOTP)
  final int counter; // Counter for HOTP

  OtpEntry({
    required this.id,
    required this.name,
    required this.secret,
    this.issuer = '',
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
    this.type = OtpType.totp,
    this.counter = 0,
  });

  // Convert OtpEntry to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'secret': secret,
      'issuer': issuer,
      'digits': digits,
      'period': period,
      'algorithm': algorithm,
      'type': type.index,
      'counter': counter,
    };
  }

  // Create OtpEntry from JSON
  factory OtpEntry.fromJson(Map<String, dynamic> json) {
    // Handle type conversion from older versions that don't have the type field
    OtpType type = OtpType.totp;
    if (json['type'] != null) {
      type = OtpType.values[json['type']];
    }

    return OtpEntry(
      id: json['id'],
      name: json['name'],
      secret: json['secret'],
      issuer: json['issuer'] ?? '',
      digits: json['digits'] ?? 6,
      period: json['period'] ?? 30,
      algorithm: json['algorithm'] ?? 'SHA1',
      type: type,
      counter: json['counter'] ?? 0,
    );
  }

  // Create a copy with updated fields
  OtpEntry copyWith({String? id, String? name, String? secret, String? issuer, int? digits, int? period, String? algorithm, OtpType? type, int? counter}) {
    return OtpEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      secret: secret ?? this.secret,
      issuer: issuer ?? this.issuer,
      digits: digits ?? this.digits,
      period: period ?? this.period,
      algorithm: algorithm ?? this.algorithm,
      type: type ?? this.type,
      counter: counter ?? this.counter,
    );
  }
}
