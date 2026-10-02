class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, Object?> json) => AppNotification(
        id: json['id']! as String,
        kind: json['kind']! as String,
        title: json['title']! as String,
        body: json['body']! as String,
        data: Map<String, Object?>.from(json['data'] as Map<Object?, Object?>? ?? const {}),
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at']! as String),
        createdAt: DateTime.parse(json['created_at']! as String),
      );

  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, Object?> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
  String? get route => data['route'] as String?;
}
