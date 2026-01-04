enum NotificationType { info, success, error, warning, transaction }

class UserNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = NotificationType.info,
    this.isRead = false,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.info,
      ),
      isRead: json['isRead'] as bool? ?? false,
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String)
              : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type.toString().split('.').last,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  UserNotification copyWith({bool? isRead}) {
    return UserNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      metadata: metadata,
    );
  }
}
