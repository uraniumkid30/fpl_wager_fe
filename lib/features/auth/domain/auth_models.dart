class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.status = 'active',
    this.role = 'user',
    this.emailVerified = false,
    this.fplEntryId,
  });

  factory UserProfile.fromJson(Map<String, Object?> json) => UserProfile(
        id: json['id']! as String,
        fullName: json['full_name']! as String,
        email: json['email']! as String,
        phone: json['phone'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        role: json['role'] as String? ?? 'user',
        emailVerified: json['email_verified'] as bool? ?? false,
        fplEntryId: (json['fpl_entry_id'] as num?)?.toInt(),
      );

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String status;
  final String role;

  /// True once the address has been confirmed with a code. Accounts created
  /// with "Sign in with FPL" start unverified.
  final bool emailVerified;

  /// The FPL entry this account proved it owns by signing in with FPL.
  final int? fplEntryId;

  /// An FPL account with no address on file yet is given a stand-in one by
  /// the server. It is not somewhere mail can be sent, so it is never shown.
  bool get hasPlaceholderEmail =>
      email.toLowerCase().endsWith('@fpl.fplwager.internal');

  /// The address to show the user: empty while it is still the stand-in.
  String get displayEmail => hasPlaceholderEmail ? '' : email;

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
