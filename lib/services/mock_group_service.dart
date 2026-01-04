import 'dart:async';

import '../models/chat_message.dart';
import '../models/group.dart';

class MockGroupService {
  final List<Group> _groups = List.generate(
    6,
    (i) => Group(
      id: 'g${i + 1}',
      name: 'Equb Group ${i + 1}',
      contribution: 100 + i * 50,
      frequency: i % 2 == 0 ? 'Weekly' : 'Monthly',
      members: List.generate(5 + i, (m) => 'Member ${m + 1}'),
      nextPayout: DateTime.now().add(Duration(days: 7 - i)),
    ),
  );

  final Map<String, List<ChatMessage>> _chatHistory = {};
  final Map<String, StreamController<ChatMessage>> _chatControllers = {};
  final Set<String> _scheduledAnnouncements = <String>{};

  List<Group> fetchGroups() => _groups;

  Group createGroup({
    required String name,
    required int contribution,
    required String frequency,
    required List<String> members,
    DateTime? nextPayout,
  }) {
    final group = Group(
      id: 'g${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      contribution: contribution,
      frequency: frequency,
      members: members,
      nextPayout: nextPayout ?? DateTime.now().add(const Duration(days: 7)),
    );
    _groups.add(group);
    return group;
  }

  void addMember(String groupId, String memberName) {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index == -1) return;
    final group = _groups[index];
    final updatedMembers = [...group.members, memberName];
    _groups[index] = Group(
      id: group.id,
      name: group.name,
      contribution: group.contribution,
      frequency: group.frequency,
      members: updatedMembers,
      nextPayout: group.nextPayout,
    );
  }

  Group? updateGroup({
    required String groupId,
    String? name,
    int? contribution,
    String? frequency,
    DateTime? nextPayout,
  }) {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index == -1) {
      return null;
    }
    final group = _groups[index];
    final updated = Group(
      id: group.id,
      name: name ?? group.name,
      contribution: contribution ?? group.contribution,
      frequency: frequency ?? group.frequency,
      members: group.members,
      nextPayout: nextPayout ?? group.nextPayout,
    );
    _groups[index] = updated;
    return updated;
  }

  bool deleteGroup(String groupId) {
    final before = _groups.length;
    _groups.removeWhere((g) => g.id == groupId);
    return _groups.length < before;
  }

  List<ChatMessage> fetchChatHistory(String groupId) {
    final history = _chatHistory.putIfAbsent(
      groupId,
      () => _seedChatHistory(groupId),
    );
    return List.unmodifiable(history);
  }

  Stream<ChatMessage> chatStream(String groupId) {
    final controller = _chatControllers.putIfAbsent(
      groupId,
      () => StreamController<ChatMessage>.broadcast(),
    );
    if (_scheduledAnnouncements.add(groupId)) {
      _scheduleSystemAnnouncements(groupId);
    }
    return controller.stream;
  }

  Future<ChatMessage> sendChatMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String content,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final message = ChatMessage(
      id: 'msg-${DateTime.now().microsecondsSinceEpoch}',
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: DateTime.now(),
      deliveryStatus: ChatDeliveryStatus.delivered,
    );
    final history = _chatHistory.putIfAbsent(
      groupId,
      () => _seedChatHistory(groupId),
    );
    history.add(message);
    _chatControllers[groupId]?.add(message);
    return message;
  }

  List<ChatMessage> _seedChatHistory(String groupId) {
    final now = DateTime.now();
    return [
      ChatMessage(
        id: 'seed-$groupId-1',
        groupId: groupId,
        senderId: 'admin',
        senderName: 'Coordinator',
        content: 'Welcome to the group! Contributions open every Friday.',
        timestamp: now.subtract(const Duration(minutes: 30)),
        isSystem: true,
      ),
      ChatMessage(
        id: 'seed-$groupId-2',
        groupId: groupId,
        senderId: 'user-456',
        senderName: 'Sara',
        content: 'Thanks for the reminder, just sent mine.',
        timestamp: now.subtract(const Duration(minutes: 12)),
      ),
    ];
  }

  void _scheduleSystemAnnouncements(String groupId) {
    final controller = _chatControllers[groupId];
    if (controller == null) {
      return;
    }
    final announcements = <String>[
      'Reminder: contribute your weekly amount before 6 PM.',
      'Coordinator scheduled a check-in meeting for Saturday.',
      'Payout rotation updated. Review in the group details.',
    ];
    var delayMs = 1200;
    for (final text in announcements) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        final message = ChatMessage(
          id: 'auto-${DateTime.now().microsecondsSinceEpoch}',
          groupId: groupId,
          senderId: 'system',
          senderName: 'System',
          content: text,
          timestamp: DateTime.now(),
          isSystem: true,
        );
        final history = _chatHistory.putIfAbsent(
          groupId,
          () => _seedChatHistory(groupId),
        );
        history.add(message);
        controller.add(message);
      });
      delayMs += 1800;
    }
  }
}
