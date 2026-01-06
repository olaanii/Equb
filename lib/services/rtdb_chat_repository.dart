import 'dart:async';

import 'package:equb/models/chat_message.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:equb/services/system_log_service.dart';

/// Firebase Realtime Database implementation for chat functionality
class RtdbChatRepository {
  RtdbChatRepository({
    required FirebaseDatabase database,
    required SystemLogService logService,
  })  : _database = database,
        _logService = logService;

  final FirebaseDatabase _database;
  final SystemLogService _logService;

  /// Sends a chat message to a group
  Future<ChatMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    try {
      final messagesRef = _database.ref('groups/$groupId/messages');
      final messageId = messagesRef.push().key;

      if (messageId == null) {
        throw Exception('Failed to generate message ID');
      }

      final message = ChatMessage(
        id: messageId,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        timestamp: DateTime.now(),
        deliveryStatus: ChatDeliveryStatus.delivered,
      );

      await messagesRef.child(messageId).set(message.toJson());

      _logService.log(
        LogLevel.info,
        'rtdb_chat.sendMessage',
        'Message sent successfully',
        context: {
          'groupId': groupId,
          'messageId': messageId,
          'senderId': senderId,
        },
      );

      return message;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'rtdb_chat.sendMessage',
        'Failed to send message',
        context: {
          'groupId': groupId,
          'senderId': senderId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Gets the chat history for a group
  Future<List<ChatMessage>> getChatHistory(String groupId, {int limit = 50}) async {
    try {
      final messagesRef = _database.ref('groups/$groupId/messages');
      final snapshot = await messagesRef
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final messages = <ChatMessage>[];
      final rawData = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in rawData.entries) {
        try {
          final messageData = Map<String, dynamic>.from(entry.value);
          messageData['id'] = entry.key;
          messageData['groupId'] = groupId;

          final message = ChatMessage.fromJson(messageData);
          messages.add(message);
        } catch (e) {
          _logService.log(
            LogLevel.warning,
            'rtdb_chat.getChatHistory',
            'Failed to parse message',
            context: {
              'groupId': groupId,
              'messageId': entry.key,
              'error': e.toString(),
            },
          );
        }
      }

      // Sort messages by timestamp (oldest first)
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      _logService.log(
        LogLevel.info,
        'rtdb_chat.getChatHistory',
        'Retrieved chat history',
        context: {
          'groupId': groupId,
          'messageCount': messages.length,
        },
      );

      return messages;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'rtdb_chat.getChatHistory',
        'Failed to get chat history',
        context: {
          'groupId': groupId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Streams real-time chat messages for a group
  Stream<ChatMessage> watchChatMessages(String groupId) {
    final messagesRef = _database.ref('groups/$groupId/messages');

    return messagesRef.onChildAdded.map((event) {
      try {
        if (event.snapshot.value == null) return null;

        final messageData = Map<String, dynamic>.from(event.snapshot.value as Map);
        messageData['id'] = event.snapshot.key;
        messageData['groupId'] = groupId;

        final message = ChatMessage.fromJson(messageData);

        _logService.log(
          LogLevel.debug,
          'rtdb_chat.watchChatMessages',
          'Received real-time message',
          context: {
            'groupId': groupId,
            'messageId': message.id,
            'senderId': message.senderId,
          },
        );

        return message;
      } catch (e) {
        _logService.log(
          LogLevel.warning,
          'rtdb_chat.watchChatMessages',
          'Failed to parse real-time message',
          context: {
            'groupId': groupId,
            'messageId': event.snapshot.key,
            'error': e.toString(),
          },
        );
        return null;
      }
    }).where((message) => message != null).cast<ChatMessage>();
  }

  /// Marks a message as read for a specific user
  Future<void> markMessageAsRead({
    required String groupId,
    required String messageId,
    required String userId,
  }) async {
    try {
      final readReceiptsRef = _database.ref('groups/$groupId/messages/$messageId/readReceipts/$userId');
      await readReceiptsRef.set({
        'userId': userId,
        'readAt': ServerValue.timestamp,
      });

      _logService.log(
        LogLevel.debug,
        'rtdb_chat.markMessageAsRead',
        'Message marked as read',
        context: {
          'groupId': groupId,
          'messageId': messageId,
          'userId': userId,
        },
      );
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'rtdb_chat.markMessageAsRead',
        'Failed to mark message as read',
        context: {
          'groupId': groupId,
          'messageId': messageId,
          'userId': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Gets read receipts for a message
  Future<Map<String, DateTime>> getReadReceipts(String groupId, String messageId) async {
    try {
      final readReceiptsRef = _database.ref('groups/$groupId/messages/$messageId/readReceipts');
      final snapshot = await readReceiptsRef.get();

      if (!snapshot.exists || snapshot.value == null) {
        return {};
      }

      final receipts = <String, DateTime>{};
      final rawData = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in rawData.entries) {
        final userId = entry.key.toString();
        final receiptData = Map<String, dynamic>.from(entry.value);
        final readAt = receiptData['readAt'];

        if (readAt is int) {
          receipts[userId] = DateTime.fromMillisecondsSinceEpoch(readAt);
        }
      }

      return receipts;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'rtdb_chat.getReadReceipts',
        'Failed to get read receipts',
        context: {
          'groupId': groupId,
          'messageId': messageId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Deletes a message (admin only or sender only)
  Future<void> deleteMessage(String groupId, String messageId) async {
    try {
      final messageRef = _database.ref('groups/$groupId/messages/$messageId');
      await messageRef.remove();

      _logService.log(
        LogLevel.info,
        'rtdb_chat.deleteMessage',
        'Message deleted',
        context: {
          'groupId': groupId,
          'messageId': messageId,
        },
      );
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'rtdb_chat.deleteMessage',
        'Failed to delete message',
        context: {
          'groupId': groupId,
          'messageId': messageId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Updates typing status for a user in a group
  Future<void> updateTypingStatus({
    required String groupId,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    try {
      final typingRef = _database.ref('groups/$groupId/typing/$userId');

      if (isTyping) {
        await typingRef.set({
          'userId': userId,
          'userName': userName,
          'timestamp': ServerValue.timestamp,
        });

        // Auto-clear typing status after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          typingRef.remove().catchError((_) {});
        });
      } else {
        await typingRef.remove();
      }
    } catch (e) {
      _logService.log(
        LogLevel.warning,
        'rtdb_chat.updateTypingStatus',
        'Failed to update typing status',
        context: {
          'groupId': groupId,
          'userId': userId,
          'isTyping': isTyping,
          'error': e.toString(),
        },
      );
    }
  }

  /// Watches typing status for a group
  Stream<Map<String, String>> watchTypingStatus(String groupId) {
    final typingRef = _database.ref('groups/$groupId/typing');

    return typingRef.onValue.map((event) {
      try {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <String, String>{};
        }

        final typingUsers = <String, String>{};
        final rawData = event.snapshot.value as Map<dynamic, dynamic>;

        for (final entry in rawData.entries) {
          final userId = entry.key.toString();
          final typingData = Map<String, dynamic>.from(entry.value);
          final userName = typingData['userName'] as String? ?? 'Unknown';

          typingUsers[userId] = userName;
        }

        return typingUsers;
      } catch (e) {
        _logService.log(
          LogLevel.warning,
          'rtdb_chat.watchTypingStatus',
          'Failed to parse typing status',
          context: {
            'groupId': groupId,
            'error': e.toString(),
          },
        );
        return <String, String>{};
      }
    });
  }
}

