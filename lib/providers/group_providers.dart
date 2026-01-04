import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../services/mock_group_service.dart';

final mockGroupServiceProvider = Provider<MockGroupService>(
  (ref) => MockGroupService(),
);

class GroupListNotifier extends Notifier<List<Group>> {
  @override
  List<Group> build() {
    final svc = ref.watch(mockGroupServiceProvider);
    return List<Group>.from(svc.fetchGroups());
  }

  void createGroup({
    required String name,
    required int contribution,
    required String frequency,
    required List<String> members,
    DateTime? nextPayout,
  }) {
    final svc = ref.read(mockGroupServiceProvider);
    final group = svc.createGroup(
      name: name,
      contribution: contribution,
      frequency: frequency,
      members: members,
      nextPayout: nextPayout,
    );
    state = [...state, group];
  }

  void addMember(String groupId, String member) {
    final svc = ref.read(mockGroupServiceProvider);
    svc.addMember(groupId, member);
    state = [
      for (final group in state)
        if (group.id == groupId)
          Group(
            id: group.id,
            name: group.name,
            contribution: group.contribution,
            frequency: group.frequency,
            members: [...group.members, member],
            nextPayout: group.nextPayout,
          )
        else
          group,
    ];
  }

  void updateGroup({
    required String groupId,
    String? name,
    int? contribution,
    String? frequency,
    DateTime? nextPayout,
  }) {
    final svc = ref.read(mockGroupServiceProvider);
    final updated = svc.updateGroup(
      groupId: groupId,
      name: name,
      contribution: contribution,
      frequency: frequency,
      nextPayout: nextPayout,
    );
    if (updated == null) {
      return;
    }
    state = [for (final group in state) group.id == groupId ? updated : group];
  }

  void deleteGroup(String groupId) {
    final svc = ref.read(mockGroupServiceProvider);
    final removed = svc.deleteGroup(groupId);
    if (!removed) {
      return;
    }
    state = [
      for (final group in state)
        if (group.id != groupId) group,
    ];
  }
}

final groupsProvider = NotifierProvider<GroupListNotifier, List<Group>>(
  GroupListNotifier.new,
);
