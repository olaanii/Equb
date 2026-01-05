class PointsEvent {
  PointsEvent({
    required this.id,
    required this.userId,
    required this.delta,
    required this.action,
    DateTime? createdAt,
    this.relatedTransactionId,
    this.relatedGroupId,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String userId;
  final int delta;
  final String action;
  final DateTime createdAt;
  final String? relatedTransactionId;
  final String? relatedGroupId;
  final Map<String, dynamic>? metadata;

  factory PointsEvent.fromJson(Map<String, dynamic> json) {
    return PointsEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      delta: json['delta'] as int,
      action: json['action'] as String,
      createdAt:
          json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String)
              : null,
      relatedTransactionId: json['relatedTransactionId'] as String?,
      relatedGroupId: json['relatedGroupId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'delta': delta,
      'action': action,
      'createdAt': createdAt.toIso8601String(),
      if (relatedTransactionId != null) 'relatedTransactionId': relatedTransactionId,
      if (relatedGroupId != null) 'relatedGroupId': relatedGroupId,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
