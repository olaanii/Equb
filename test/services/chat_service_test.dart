import 'dart:async';

import 'package:equb/models/chat_message.dart';
import 'package:equb/services/chat_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';

// Mock Firebase Database for testing
class MockFirebaseDatabase {
  final Map<String, dynamic> _data = {};
  final Map<String, StreamController<DatabaseEvent>> _controllers = {};

  DatabaseReference ref([String? path]) {
    return MockDatabaseReference(this, path ?? '');
  }

  dynamic getData(String path) {
    return _data[path];
  }

  void setData(String path, dynamic value) {
    _data[path] = value;
    _notifyListeners(path);
  }

  void _notifyListeners(String path) {
    for (final entry in _controllers.entries) {
      if (path.startsWith(entry.key) || entry.key.startsWith(path)) {
        final event = DatabaseEvent(
          snapshot: MockDataSnapshot(path, _data[path]),
          type: DatabaseEventType.value,
        );
        entry.value.add(event);
      }
    }
  }

  StreamController<DatabaseEvent> getController(String path) {
    return _controllers.putIfAbsent(path, () => StreamController<DatabaseEvent>.broadcast());
  }
}

class MockDatabaseReference {
  final MockFirebaseDatabase _db;
  final String _path;

  MockDatabaseReference(this._db, this._path);

  DatabaseReference child(String path) {
    return MockDatabaseReference(_db, _path.isEmpty ? path : '$_path/$path');
  }

  Future<DatabaseEvent> get() async {
    return DatabaseEvent(
      snapshot: MockDataSnapshot(_path, _db.getData(_path)),
      type: DatabaseEventType.value,
    );
  }

  Future<DatabaseReference> set(dynamic value) async {
    _db.setData(_path, value);
    return this;
  }

  Future<DatabaseReference> update(Map<String, dynamic> value) async {
    final current = _db.getData(_path) ?? {};
    if (current is Map) {
      current.addAll(value);
      _db.setData(_path, current);
    }
    return this;
  }

  Stream<DatabaseEvent> onValue() {
    return _db.getController(_path).stream;
  }

  Future<void> remove() async {
    _db.setData(_path, null);
  }

  String get key => _path.split('/').last;
}

class MockDataSnapshot implements DataSnapshot {
  final String _path;
  final dynamic _value;

  MockDataSnapshot(this._path, this._value);

  @override
  dynamic get value => _value;

  @override
  String? get key => _path.split('/').last;

  @override
  DataSnapshot? get child => throw UnimplementedError();

  @override
  Iterable<DataSnapshot> get children => throw UnimplementedError();

  @override
  bool get exists => _value != null;

  @override
  int? get priority => throw UnimplementedError();

  @override
  DataSnapshot childSnapshot(String path) => throw UnimplementedError();

  @override
  bool hasChild(String path) => throw UnimplementedError();
}

void main() {
  late MockFirebaseDatabase mockDatabase;
  late SystemLogService logService;
  late ChatService chatService;

  setUp(() {
    mockDatabase = MockFirebaseDatabase();
    logService = SystemLogService();
    chatService = ChatService(
      database: mockDatabase as FirebaseDatabase,
      logService: logService,
    );
  });

  tearDown(() {
    chatService.dispose();
  });

  group('ChatService', () {
    const testGroupId = 'test-group-123';
    const testSenderId = 'user-456';
    const testSenderName = 'Test User';

    test('should send message successfully', () async {
      final message = await chatService.sendMessage(
        groupId: testGroupId,
        senderId: testSenderId,
        senderName: testSenderName,
        content: 'Hello, world!',
      );

      expect(message.groupId, equals(testGroupId));
      expect(message.senderId, equals(testSenderId));
      expect(message.senderName, equals(testSenderName));
      expect(message.content, equals('Hello, world!'));
      expect(message.deliveryStatus, equals(ChatDeliveryStatus.delivered));
      expect(message.timestamp, isNotNull);
    });

    test('should get chat history', () async {
      // First send some messages
      await chatService.sendMessage(
        groupId: testGroupId,
        senderId: testSenderId,
        senderName: testSenderName,
        content: 'Message 1',
      );

      await chatService.sendMessage(
        groupId: testGroupId,
        senderId: 'user-789',
        senderName: 'Other User',
        content: 'Message 2',
      );

      final history = await chatService.getChatHistory(testGroupId);

      expect(history.length, equals(2));
      expect(history[0].content, equals('Message 1'));
      expect(history[1].content, equals('Message 2'));
      expect(history[0].timestamp.isBefore(history[1].timestamp), isTrue);
    });

    test('should update typing status', () async {
      await chatService.updateTypingStatus(
        groupId: testGroupId,
        userId: testSenderId,
        userName: testSenderName,
        isTyping: true,
      );

      final typingStatus = await chatService.watchTypingStatus(testGroupId).first;

      expect(typingStatus.containsKey(testSenderId), isTrue);
      expect(typingStatus[testSenderId], equals(testSenderName));
    });

    test('should mark message as read', () async {
      final message = await chatService.sendMessage(
        groupId: testGroupId,
        senderId: testSenderId,
        senderName: testSenderName,
        content: 'Test message',
      );

      await chatService.markMessageAsRead(
        groupId: testGroupId,
        messageId: message.id,
        userId: 'reader-user',
      );

      final receipts = await chatService.getReadReceipts(testGroupId, message.id);

      expect(receipts.containsKey('reader-user'), isTrue);
      expect(receipts['reader-user'], isA<DateTime>());
    });

    test('should delete message', () async {
      final message = await chatService.sendMessage(
        groupId: testGroupId,
        senderId: testSenderId,
        senderName: testSenderName,
        content: 'Message to delete',
      );

      var history = await chatService.getChatHistory(testGroupId);
      expect(history.length, equals(1));

      await chatService.deleteMessage(testGroupId, message.id);

      history = await chatService.getChatHistory(testGroupId);
      expect(history.length, equals(0));
    });
  });
}

