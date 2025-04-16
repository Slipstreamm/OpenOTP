class OtpEntry {
  final String id;
  final String name;
  final String secret;
  final String issuer;
  final int digits;
  final int period;
  final String algorithm;

  OtpEntry({
    required this.id,
    required this.name,
    required this.secret,
    this.issuer = '',
    this.digits = 6,
    this.period = 30,
    this.algorithm = 'SHA1',
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
    };
  }

  // Create OtpEntry from JSON
  factory OtpEntry.fromJson(Map<String, dynamic> json) {
    return OtpEntry(
      id: json['id'],
      name: json['name'],
      secret: json['secret'],
      issuer: json['issuer'] ?? '',
      digits: json['digits'] ?? 6,
      period: json['period'] ?? 30,
      algorithm: json['algorithm'] ?? 'SHA1',
    );
  }
}
