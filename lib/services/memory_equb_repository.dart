import 'package:equb/models/equb_model.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/equb_rotation_engine.dart';
import 'package:flutter/material.dart';

class EqubStore {
  EqubStore({List<EqubGroup>? seed})
    : _groups = {for (final g in seed ?? const <EqubGroup>[]) g.id: g};

  final Map<String, EqubGroup> _groups;

  List<EqubGroup> list() => _groups.values.toList(growable: false);

  EqubGroup? getById(String id) => _groups[id];

  void upsert(EqubGroup group) {
    _groups[group.id] = group;
  }

  void deleteById(String id) {
    _groups.remove(id);
  }
}

class MemoryEqubRepository implements EqubRepository {
  MemoryEqubRepository({
    required EqubStore store,
    EqubRotationEngine? rotationEngine,
  }) : _store = store,
       _rotationEngine = rotationEngine ?? EqubRotationEngine();

  final EqubStore _store;
  final EqubRotationEngine _rotationEngine;

  @override
  Future<List<EqubGroup>> listGroups() async {
    final groups = _store.list();
    groups.sort((a, b) => a.name.compareTo(b.name));
    return groups;
  }

  @override
  Future<EqubGroup> createGroup(EqubGroup g, {String? actingUserId}) async {
    _store.upsert(g);
    return g;
  }

  @override
  Future<EqubGroup> updateGroup(EqubGroup g, {String? actingUserId}) async {
    _store.upsert(g);
    return g;
  }

  @override
  Future<void> deleteGroup(String groupId, {String? actingUserId}) async {
    _store.deleteById(groupId);
  }

  @override
  Future<EqubGroup?> findGroup(
    String groupId, {
    bool syncRotation = true,
  }) async {
    final group = _store.getById(groupId);
    if (group == null) return null;
    if (!syncRotation) return group;

    final synced = group.copyWith(
      rotationState: _rotationEngine.syncState(
        state: group.rotationState,
        config: group.scheduleConfig,
        members: group.members,
      ),
    );
    _store.upsert(synced);
    return synced;
  }

  @override
  Future<EqubGroupMetrics> fetchGroupMetrics(String groupId) async {
    final group = await findGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    final state = group.rotationState;
    final totalMembers = group.members.length;
    final required = group.contributionAmount;
    final pot = group.poolAmountPerCycle;
    final totalContributions = state.contributionProgress.values.fold<double>(
      0,
      (sum, amount) => sum + amount,
    );
    final fundedRatio =
        pot <= 0 ? 0.0 : (totalContributions / pot).clamp(0.0, 1.0);
    final outstanding = (pot - totalContributions).clamp(0.0, double.infinity);
    final memberProgress = <String, double>{
      for (final member in group.members)
        member:
            required <= 0
                ? 0.0
                : ((state.contributionProgress[member] ?? 0.0) / required)
                    .clamp(0.0, 1.0),
    };
    final nextRecipient =
        state.payoutQueue.isNotEmpty ? state.payoutQueue.first : null;
    final nextRound = state.currentRound + 1;

    return EqubGroupMetrics(
      groupId: group.id,
      totalMembers: totalMembers,
      currentRound: state.currentRound,
      completedRounds: state.history.length,
      contributionAmount: required,
      potSize: pot,
      fundedPercentage: fundedRatio,
      totalOutstanding: outstanding,
      cycle: group.scheduleConfig.cycle,
      cycleLengthDays: group.scheduleConfig.cycleLengthDays,
      nextPayoutDate: state.nextPayoutDate,
      memberProgress: memberProgress,
      nextRecipient: nextRecipient,
      nextRound: nextRecipient == null ? null : nextRound,
    );
  }

  @override
  Future<List<EqubRoundSummary>> fetchRoundSummaries(String groupId) async {
    final group = await findGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    final state = group.rotationState;
    final List<EqubRoundSummary> summaries = [
      for (final record in state.history)
        EqubRoundSummary(
          round: record.round,
          memberId: record.memberId,
          scheduledFor: record.scheduledFor,
          expectedAmount: record.amount,
          status: EqubRoundStatus.completed,
          autoAssigned: record.autoAssigned,
          actualPayout: record,
        ),
    ];

    final now = DateTime.now();
    final queue = state.payoutQueue;
    final required = group.contributionAmount;
    final pot = group.poolAmountPerCycle;

    var scheduledDate = state.nextPayoutDate;
    for (var i = 0; i < queue.length; i++) {
      final member = queue[i];
      final roundNumber = state.currentRound + i + 1;
      final contributed = state.contributionProgress[member] ?? 0.0;
      final funded = required <= 0 ? true : contributed + 1e-8 >= required;
      final overdue = scheduledDate.isBefore(now) && !funded;
      final status =
          overdue ? EqubRoundStatus.overdue : EqubRoundStatus.pending;
      summaries.add(
        EqubRoundSummary(
          round: roundNumber,
          memberId: member,
          scheduledFor: scheduledDate,
          expectedAmount: pot,
          status: status,
          autoAssigned: group.scheduleConfig.autoAssign,
          actualPayout: null,
        ),
      );
      scheduledDate = scheduledDate.add(
        Duration(days: group.scheduleConfig.cycleLengthDays),
      );
    }

    summaries.sort((a, b) => a.round.compareTo(b.round));
    return summaries;
  }

  @override
  Future<EqubPayoutRecord?> triggerNextPayout(
    String groupId, {
    String? overrideMemberId,
    double? overrideAmount,
    bool ignoreContributionThreshold = false,
  }) async {
    final group = await findGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    final outcome = _rotationEngine.forcePayout(
      group: group,
      overrideMemberId: overrideMemberId,
      overrideAmount: overrideAmount,
      ignoreContributionThreshold: ignoreContributionThreshold,
      now: DateTime.now(),
    );

    if (!outcome.payoutTriggered || outcome.payout == null) {
      final updated = group.copyWith(rotationState: outcome.state);
      _store.upsert(updated);
      return null;
    }

    final payout = outcome.payout!;
    final payoutTx = TransactionModel(
      id:
          'manual-$groupId-${payout.round}-${payout.processedAt.microsecondsSinceEpoch}',
      fromUserId: groupId,
      toUserId: payout.memberId,
      amount: payout.amount,
      timestamp: payout.processedAt,
      status: TransactionStatus.success,
      gateway: 'equb_payout',
    );
    final ledger = List<TransactionModel>.from(group.ledger)..add(payoutTx);
    final updated = group.copyWith(
      ledger: ledger,
      rotationState: outcome.state,
    );
    _store.upsert(updated);
    return payout;
  }

  @override
  Future<TransactionModel> contribute({
    required String groupId,
    required String userId,
    required BuildContext context,
    String? screenshotUrl,
  }) async {
    final group = await findGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    final tx = TransactionModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      fromUserId: userId,
      toUserId: groupId,
      amount: group.contributionAmount,
      timestamp: DateTime.now(),
      status: TransactionStatus.success,
      gateway: 'simulated',
    );

    final rotationOutcome = _rotationEngine.registerContribution(
      group: group,
      memberId: userId,
      amount: tx.amount,
      now: tx.timestamp,
    );

    var updatedGroup = group.copyWith(
      ledger: [...group.ledger, tx],
      rotationState: rotationOutcome.state,
    );

    if (rotationOutcome.payoutTriggered && rotationOutcome.payout != null) {
      final payout = rotationOutcome.payout!;
      final payoutTx = TransactionModel(
        id:
            'payout-$groupId-${payout.round}-${payout.processedAt.microsecondsSinceEpoch}',
        fromUserId: groupId,
        toUserId: payout.memberId,
        amount: payout.amount,
        timestamp: payout.processedAt,
        status: TransactionStatus.success,
        gateway: 'equb_payout',
      );
      updatedGroup = updatedGroup.copyWith(
        ledger: [...updatedGroup.ledger, payoutTx],
        rotationState: rotationOutcome.state,
      );
    }

    _store.upsert(updatedGroup);
    return tx;
  }
}
