import 'package:fplboardman/features/auth/domain/auth_models.dart';

/// A QR code the website shows so the phone app can sign it in.
class QrLogin {
  const QrLogin({
    required this.id,
    required this.code,
    required this.pollToken,
    required this.expiresAt,
    this.linkDays = 90,
  });

  factory QrLogin.fromJson(Map<String, Object?> json) => QrLogin(
        id: json['id']! as String,
        code: json['code']! as String,
        pollToken: json['poll_token']! as String,
        expiresAt: DateTime.tryParse('${json['expires_at']}')?.toLocal() ??
            DateTime.now().add(const Duration(minutes: 2)),
        linkDays: (json['link_days'] as num? ?? 90).toInt(),
      );

  final String id;

  /// What goes in the QR code (inside [link]).
  final String code;

  /// Known only to this browser; it is what collects the session.
  final String pollToken;
  final DateTime expiresAt;

  /// How long the browser stays signed in once approved.
  final int linkDays;
}

/// Where a QR code stands, as the website sees it.
enum QrStatus {
  pending,
  scanned,
  approved,
  consumed,
  declined,
  expired;

  static QrStatus parse(String value) => QrStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => QrStatus.expired,
      );
}

/// The answer to the website's "has it been approved?". [session] is set
/// once, when the phone has approved.
class QrPoll {
  const QrPoll({required this.status, this.session});

  final QrStatus status;
  final AuthSession? session;
}

/// What the phone shows before approving: which browser is asking.
class QrRequest {
  const QrRequest({required this.label, this.linkDays = 90});

  factory QrRequest.fromJson(Map<String, Object?> json) => QrRequest(
        label: json['label'] as String? ?? 'Web browser',
        linkDays: (json['link_days'] as num? ?? 90).toInt(),
      );

  /// "Chrome on macOS".
  final String label;
  final int linkDays;
}

/// A browser signed in to the account through a QR code.
class WebLink {
  const WebLink({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUsedAt,
  });

  factory WebLink.fromJson(Map<String, Object?> json) => WebLink(
        id: json['id']! as String,
        label: json['label'] as String? ?? 'Web browser',
        createdAt: DateTime.parse(json['created_at']! as String).toLocal(),
        expiresAt: DateTime.parse(json['expires_at']! as String).toLocal(),
        lastUsedAt: DateTime.tryParse('${json['last_used_at']}')?.toLocal() ??
            DateTime.parse(json['created_at']! as String).toLocal(),
      );

  final String id;
  final String label;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime lastUsedAt;
}

/// Pulls the sign-in code out of what the camera read: the website's link
/// (".../v1/link/CODE") or the code on its own. Null when it is neither.
String? webLinkCodeFrom(String? scanned) {
  var text = (scanned ?? '').trim();
  if (text.isEmpty) return null;
  final index = text.lastIndexOf('/link/');
  if (index >= 0) text = text.substring(index + '/link/'.length);
  text = text.split(RegExp(r'[?#]')).first;
  return RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(text) ? text : null;
}
