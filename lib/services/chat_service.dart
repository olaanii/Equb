import 'dart:async';

import 'package:equb/models/chat_message.dart';
import 'package:equb/services/rtdb_chat_repository.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:firebase_database/firebase_database.dart';

/// High-level chat service that manages chat functionality
class ChatService {
  ChatService({
    required FirebaseDatabase database,
    required SystemLogService logService,
  })  : _repository = RtdbChatRepository(
          database: database,
          logService: logService,
        ),
        _logService = logService;

  final RtdbChatRepository _repository;
  final SystemLogService _logService;

  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, StreamController<ChatMessage>> _messageControllers = {};
  final Map<String, StreamController<Map<String, String>>> _typingControllers = {};

  /// Sends a message to a group
  Future<ChatMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    return _repository.sendMessage(
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
    );
  }

  /// Gets chat history for a group
  Future<List<ChatMessage>> getChatHistory(String groupId, {int limit = 50}) async {
    return _repository.getChatHistory(groupId, limit: limit);
  }

  /// Starts listening to real-time messages for a group
  Stream<ChatMessage> watchMessages(String groupId) {
    // Return existing controller if already listening
    if (_messageControllers.containsKey(groupId)) {
      return _messageControllers[groupId]!.stream;
    }

    final controller = StreamController<ChatMessage>.broadcast();
    _messageControllers[groupId] = controller;

    final subscription = _repository.watchChatMessages(groupId).listen(
      (message) {
        controller.add(message);
      },
      onError: (error) {
        _logService.log(
          LogLevel.error,
          'chat_service.watchMessages',
          'Error in message stream',
          context: {
            'groupId': groupId,
            'error': error.toString(),
          },
        );
        controller.addError(error);
      },
    );

    _activeSubscriptions['messages_$groupId'] = subscription;

    // Clean up when controller is done
    controller.onCancel = () {
      _cleanupGroupSubscriptions(groupId);
    };

    return controller.stream;
  }

  /// Updates typing status for a user
  Future<void> updateTypingStatus({
    required String groupId,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    await _repository.updateTypingStatus(
      groupId: groupId,
      userId: userId,
      userName: userName,
      isTyping: isTyping,
    );
  }

  /// Watches typing status for a group
  Stream<Map<String, String>> watchTypingStatus(String groupId) {
    // Return existing controller if already listening
    if (_typingControllers.containsKey(groupId)) {
      return _typingControllers[groupId]!.stream;
    }

    final controller = StreamController<Map<String, String>>.broadcast();
    _typingControllers[groupId] = controller;

    final subscription = _repository.watchTypingStatus(groupId).listen(
      (typingUsers) {
        controller.add(typingUsers);
      },
      onError: (error) {
        _logService.log(
          LogLevel.error,
          'chat_service.watchTypingStatus',
          'Error in typing stream',
          context: {
            'groupId': groupId,
            'error': error.toString(),
          },
        );
        controller.addError(error);
      },
    );

    _activeSubscriptions['typing_$groupId'] = subscription;

    // Clean up when controller is done
    controller.onCancel = () {
      _cleanupGroupSubscriptions(groupId);
    };

    return controller.stream;
  }

  /// Marks a message as read
  Future<void> markMessageAsRead({
    required String groupId,
    required String messageId,
    required String userId,
  }) async {
    await _repository.markMessageAsRead(
      groupId: groupId,
      messageId: messageId,
      userId: userId,
    );
  }

  /// Gets read receipts for a message
  Future<Map<String, DateTime>> getReadReceipts(String groupId, String messageId) async {
    return _repository.getReadReceipts(groupId, messageId);
  }

  /// Deletes a message (admin or sender only)
  Future<void> deleteMessage(String groupId, String messageId) async {
    await _repository.deleteMessage(groupId, messageId);
  }

  /// Cleans up subscriptions for a specific group
  void _cleanupGroupSubscriptions(String groupId) {
    final messageSubscription = _activeSubscriptions.remove('messages_$groupId');
    final typingSubscription = _activeSubscriptions.remove('typing_$groupId');

    messageSubscription?.cancel();
    typingSubscription?.cancel();

    _messageControllers.remove(groupId)?.close();
    _typingControllers.remove(groupId)?.close();
  }

  /// Disposes all active subscriptions
  void dispose() {
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();

    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();

    for (final controller in _typingControllers.values) {
      controller.close();
    }
    _typingControllers.clear();

    _logService.log(
      LogLevel.info,
      'chat_service.dispose',
      'Chat service disposed',
    );
  }
}

