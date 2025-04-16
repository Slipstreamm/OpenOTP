import 'dart:convert';

/// Model for storing authentication data
class AuthModel {
  final String? passwordHash; // Hashed password (null if not set)
  final String? salt; // Salt used for password hashing
  final bool useBiometrics; // Whether biometrics are enabled
  final int lastAuthTime; // Timestamp of last successful authentication

  const AuthModel({
    this.passwordHash,
    this.salt,
    this.useBiometrics = false,
    this.lastAuthTime = 0,
  });

  // Check if a password is set
  bool get hasPassword => passwordHash != null && passwordHash!.isNotEmpty;

  // Create a copy with some values replaced
  AuthModel copyWith({
    String? passwordHash,
    String? salt,
    bool? useBiometrics,
    int? lastAuthTime,
  }) {
    return AuthModel(
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      lastAuthTime: lastAuthTime ?? this.lastAuthTime,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'passwordHash': passwordHash,
      'salt': salt,
      'useBiometrics': useBiometrics,
      'lastAuthTime': lastAuthTime,
    };
  }

  // Create from JSON
  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      passwordHash: json['passwordHash'],
      salt: json['salt'],
      useBiometrics: json['useBiometrics'] ?? false,
      lastAuthTime: json['lastAuthTime'] ?? 0,
    );
  }

  // Create from JSON string
  factory AuthModel.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString);
    return AuthModel.fromJson(json);
  }

  // Convert to JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }
}
