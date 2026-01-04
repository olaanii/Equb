import 'package:meta/meta.dart';

enum ChatDeliveryStatus { sending, delivered, failed }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.isSystem = false,
    this.deliveryStatus = ChatDeliveryStatus.delivered,
  });

  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isSystem;
  final ChatDeliveryStatus deliveryStatus;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSystem: json['isSystem'] as bool? ?? false,
      deliveryStatus: ChatDeliveryStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['deliveryStatus'],
        orElse: () => ChatDeliveryStatus.delivered,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isSystem': isSystem,
      'deliveryStatus': deliveryStatus.toString().split('.').last,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    bool? isSystem,
    ChatDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSystem: isSystem ?? this.isSystem,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
