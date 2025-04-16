import 'dart:convert';

/// Model for storing authentication data
class AuthModel {
  final String? passwordHash; // Hashed password (null if not set)
  final String? salt; // Salt used for password hashing
  final bool useBiometrics; // Whether biometrics are enabled
  final int lastAuthTime; // Timestamp of last successful authentication
  final bool isManuallyLocked; // Whether the app was manually locked by the user

  const AuthModel({this.passwordHash, this.salt, this.useBiometrics = false, this.lastAuthTime = 0, this.isManuallyLocked = false});

  // Check if a password is set
  bool get hasPassword => passwordHash != null && passwordHash!.isNotEmpty;

  // Create a copy with some values replaced
  AuthModel copyWith({String? passwordHash, String? salt, bool? useBiometrics, int? lastAuthTime, bool? isManuallyLocked}) {
    return AuthModel(
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      lastAuthTime: lastAuthTime ?? this.lastAuthTime,
      isManuallyLocked: isManuallyLocked ?? this.isManuallyLocked,
    );
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {'passwordHash': passwordHash, 'salt': salt, 'useBiometrics': useBiometrics, 'lastAuthTime': lastAuthTime, 'isManuallyLocked': isManuallyLocked};
  }

  // Create from JSON
  factory AuthModel.fromJson(Map<String, dynamic> json) {
    return AuthModel(
      passwordHash: json['passwordHash'],
      salt: json['salt'],
      useBiometrics: json['useBiometrics'] ?? false,
      lastAuthTime: json['lastAuthTime'] ?? 0,
      isManuallyLocked: json['isManuallyLocked'] ?? false,
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
