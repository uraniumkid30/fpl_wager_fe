class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.status = 'active',
    this.role = 'user',
  });

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
        id: json['id']! as String,
        fullName: json['full_name']! as String,
        email: json['email']! as String,
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        role: json['role'] as String? ?? 'user',
      );

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String status;
  final String role;

  String get firstName {
    final value = fullName.trim();
    return value.isEmpty ? 'Manager' : value.split(RegExp(r'\s+')).first;
  }

  bool get isAdmin => role == 'admin' || role == 'superadmin';
}

class VerificationChallenge {
  const VerificationChallenge({
    required this.message,
    required this.verificationPath,
    required this.expiresInSeconds,
  });

  factory VerificationChallenge.fromJson(Map<String, Object?> json) =>
      VerificationChallenge(
        message: json['message'] as String? ?? 'Enter the code sent to you.',
        verificationPath: json['verification_path']! as String,
        expiresInSeconds: (json['expires_in_seconds']! as num).toInt(),
      );

  final String message;
  final String verificationPath;
  final int expiresInSeconds;
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final UserProfile user;
  final String accessToken;
  final String refreshToken;
}
