import 'package:equb/models/equb_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';

/// Legacy provider maintained for backward compatibility.
/// New code should use [equbGroupsProvider] and [equbRepositoryProvider] from providers.dart.
@Deprecated('Use equbGroupsProvider from providers.dart instead')
class GroupListNotifier extends Notifier<List<Group>> {
  @override
  List<Group> build() {
    // Convert EqubGroups to legacy Group model for backward compatibility
    final equbGroupsAsync = ref.watch(equbGroupsProvider);
    return equbGroupsAsync.when(
      data: (groups) => groups.map((g) => Group(
        id: g.id,
        name: g.name,
        contribution: g.contributionAmount.toInt(),
        frequency: g.scheduleConfig.cycle.label,
        members: g.members,
        nextPayout: g.rotationState.nextPayoutDate,
      )).toList(),
      loading: () => <Group>[],
      error: (_, __) => <Group>[],
    );
  }

  void createGroup({
    required String name,
    required int contribution,
    required String frequency,
    required List<String> members,
    DateTime? nextPayout,
  }) async {
    final repo = ref.read(equbRepositoryProvider);
    final cycle = EqubCycle.values.firstWhere(
      (c) => c.label.toLowerCase() == frequency.toLowerCase(),
      orElse: () => EqubCycle.weekly,
    );
    final newGroup = EqubGroup(
      id: '',
      name: name,
      contributionAmount: contribution.toDouble(),
      members: members,
      frequencyDays: cycle.defaultDays ?? 30,
      payoutStrategy: PayoutStrategy.fixedOrder,
      scheduleConfig: EqubScheduleConfig(
        cycle: cycle,
      ),
      rotationState: EqubRotationState(
        nextPayoutDate: nextPayout ?? DateTime.now().add(const Duration(days: 7)),
        payoutQueue: members,
        contributionProgress: {
          for (final member in members) member: 0.0,
        },
      ),
    );
    await repo.createGroup(newGroup);
    ref.invalidate(equbGroupsProvider);
  }

  void addMember(String groupId, String member) async {
    final repo = ref.read(equbRepositoryProvider);
    final existing = await repo.findGroup(groupId);
    if (existing == null) return;
    
    final updatedMembers = [...existing.members, member];
    final updated = existing.copyWith(members: updatedMembers);
    await repo.updateGroup(updated);
    ref.invalidate(equbGroupsProvider);
  }

  void updateGroup({
    required String groupId,
    String? name,
    int? contribution,
    String? frequency,
    DateTime? nextPayout,
  }) async {
    final repo = ref.read(equbRepositoryProvider);
    final existing = await repo.findGroup(groupId);
    if (existing == null) return;
    
    final updated = existing.copyWith(
      name: name ?? existing.name,
      contributionAmount: contribution?.toDouble() ?? existing.contributionAmount,
      scheduleConfig: frequency != null 
        ? existing.scheduleConfig.copyWith(
            cycle: EqubCycle.values.firstWhere(
              (c) => c.label.toLowerCase() == frequency.toLowerCase(),
              orElse: () => existing.scheduleConfig.cycle,
            ),
          )
        : existing.scheduleConfig,
      rotationState: nextPayout != null
        ? existing.rotationState.copyWith(nextPayoutDate: nextPayout)
        : existing.rotationState,
    );
    await repo.updateGroup(updated);
    ref.invalidate(equbGroupsProvider);
  }

  void deleteGroup(String groupId) async {
    final repo = ref.read(equbRepositoryProvider);
    await repo.deleteGroup(groupId);
    ref.invalidate(equbGroupsProvider);
  }
}

@Deprecated('Use equbGroupsProvider from providers.dart instead')
final groupsProvider = NotifierProvider<GroupListNotifier, List<Group>>(
  GroupListNotifier.new,
);
