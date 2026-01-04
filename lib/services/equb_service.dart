import 'package:equb/models/equb_model.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/equb_rotation_engine.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/services/analytics_service.dart';
import 'package:flutter/material.dart';

class EqubService {
  EqubService({
    required this.paymentService,
    required this.repository,
    EqubRotationEngine? rotationEngine,
    AnalyticsService? analyticsService,
  }) : _rotationEngine = rotationEngine ?? EqubRotationEngine(),
       _analyticsService = analyticsService;

  final PaymentService paymentService;
  final EqubRepository repository;
  final EqubRotationEngine _rotationEngine;
  final AnalyticsService? _analyticsService;

  Future<List<EqubGroup>> listGroups({bool syncRotation = true}) async {
    return repository.listGroups();
  }

  Future<EqubGroup?> getGroup(String id, {bool syncRotation = true}) {
    return repository.findGroup(id, syncRotation: syncRotation);
  }

  Future<EqubGroup> createGroup(
    EqubGroup template, {
    String? actingUserId,
  }) async {
    final members =
        template.members.isEmpty && actingUserId != null
            ? <String>[actingUserId]
            : template.members;
    final schedule = template.scheduleConfig.copyWith(
      preferredOrder: _mergePreferredOrder(
        template.scheduleConfig.preferredOrder,
        members,
      ),
    );
    final state = _rotationEngine.bootstrapState(
      config: schedule,
      members: members,
    );
    final group = template.copyWith(
      members: members,
      frequencyDays: schedule.cycleLengthDays,
      payoutStrategy: schedule.strategy,
      scheduleConfig: schedule,
      rotationState: state,
      ledger: template.ledger,
    );
    final created = await repository.createGroup(
      group,
      actingUserId: actingUserId,
    );
    await _track(
      'group_created',
      userId: actingUserId,
      properties: {
        'groupId': created.id,
        'memberCount': created.members.length,
        'contributionAmount': created.contributionAmount,
        'frequencyDays': created.frequencyDays,
        'strategy': created.payoutStrategy.name,
      },
    );
    return created;
  }

  Future<EqubGroup> updateGroup(
    EqubGroup updated, {
    String? actingUserId,
  }) async {
    final existing = await repository.findGroup(updated.id);
    if (existing == null) {
      throw Exception('Group not found');
    }
    final members =
        updated.members.isEmpty ? existing.members : updated.members;
    final schedule = updated.scheduleConfig.copyWith(
      preferredOrder: _mergePreferredOrder(
        updated.scheduleConfig.preferredOrder,
        members,
      ),
    );
    final syncedState = _rotationEngine.syncState(
      state: existing.rotationState,
      config: schedule,
      members: members,
    );
    final mergedLedger =
        updated.ledger.isEmpty ? existing.ledger : updated.ledger;
    final merged = existing.copyWith(
      name: updated.name,
      contributionAmount: updated.contributionAmount,
      frequencyDays: schedule.cycleLengthDays,
      payoutStrategy: schedule.strategy,
      members: members,
      ledger: mergedLedger,
      scheduleConfig: schedule,
      rotationState: syncedState,
    );
    final persisted = await repository.updateGroup(
      merged,
      actingUserId: actingUserId,
    );
    await _track(
      'group_updated',
      userId: actingUserId,
      properties: {
        'groupId': persisted.id,
        'memberCount': persisted.members.length,
        'frequencyDays': persisted.frequencyDays,
      },
    );
    return persisted;
  }

  Future<void> deleteGroup(String id) async {
    await repository.deleteGroup(id);
    await _track('group_deleted', properties: {'groupId': id});
  }

  Future<TransactionModel> contribute({
    required String groupId,
    required String userId,
    required BuildContext context,
  }) async {
    var group = await repository.findGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }

    if (!group.members.contains(userId)) {
      final extendedMembers = [...group.members, userId];
      final schedule = group.scheduleConfig.copyWith(
        preferredOrder: _mergePreferredOrder(
          group.scheduleConfig.preferredOrder,
          extendedMembers,
        ),
      );
      final syncedState = _rotationEngine.syncState(
        state: group.rotationState,
        config: schedule,
        members: extendedMembers,
      );
      group = group.copyWith(
        members: extendedMembers,
        scheduleConfig: schedule,
        rotationState: syncedState,
      );
    }

    if (!context.mounted) {
      throw Exception('Context is no longer valid');
    }

    final transaction = await paymentService.createPayment(
      fromUserId: userId,
      toUserId: groupId,
      amount: group.contributionAmount,
      gateway: 'simulated',
      context: context,
    );

    final ledger = List<TransactionModel>.from(group.ledger)..add(transaction);
    final rotationOutcome = _rotationEngine.registerContribution(
      group: group,
      memberId: userId,
      amount: transaction.amount,
      now: transaction.timestamp,
    );

    var updatedGroup = group.copyWith(
      ledger: ledger,
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
      final augmentedLedger = List<TransactionModel>.from(updatedGroup.ledger)
        ..add(payoutTx);
      updatedGroup = updatedGroup.copyWith(
        ledger: augmentedLedger,
        rotationState: rotationOutcome.state,
      );
    }

    await repository.updateGroup(updatedGroup);
    await _track(
      'group_contribution_recorded',
      userId: userId,
      properties: {'groupId': groupId, 'amount': transaction.amount},
    );
    return transaction;
  }

  Future<EqubGroup> configureSchedule(
    String groupId, {
    int? cycleLengthDays,
    DateTime? startDate,
    bool? autoAssign,
    PayoutStrategy? strategy,
    List<String>? preferredOrder,
    Map<int, String>? adminAssignments,
  }) async {
    final group = await repository.findGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }
    final mergedOrder = _mergePreferredOrder(
      preferredOrder ?? group.scheduleConfig.preferredOrder,
      group.members,
    );
    final schedule = group.scheduleConfig.copyWith(
      cycleLengthDays: cycleLengthDays,
      startDate: startDate,
      autoAssign: autoAssign,
      strategy: strategy,
      preferredOrder: mergedOrder,
      adminAssignments:
          adminAssignments != null
              ? {...group.scheduleConfig.adminAssignments, ...adminAssignments}
              : group.scheduleConfig.adminAssignments,
    );
    final rotationState = _rotationEngine.syncState(
      state: group.rotationState,
      config: schedule,
      members: group.members,
    );
    final updated = group.copyWith(
      frequencyDays: schedule.cycleLengthDays,
      payoutStrategy: schedule.strategy,
      scheduleConfig: schedule,
      rotationState: rotationState,
    );
    return repository.updateGroup(updated);
  }

  Future<EqubPayoutRecord?> triggerNextPayout(
    String groupId, {
    String? overrideMemberId,
    double? overrideAmount,
    bool ignoreContributionThreshold = false,
    String? note,
  }) async {
    final group = await repository.findGroup(groupId);
    if (group == null) {
      throw Exception('Group not found');
    }
    final outcome = _rotationEngine.forcePayout(
      group: group,
      overrideMemberId: overrideMemberId,
      overrideAmount: overrideAmount,
      ignoreContributionThreshold: ignoreContributionThreshold,
      now: DateTime.now(),
      note: note,
    );

    if (!outcome.payoutTriggered || outcome.payout == null) {
      await repository.updateGroup(
        group.copyWith(rotationState: outcome.state),
      );
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
    await repository.updateGroup(updated);
    await _track(
      'group_payout_triggered',
      userId: overrideMemberId,
      properties: {
        'groupId': groupId,
        'memberId': payout.memberId,
        'amount': payout.amount,
      },
    );
    return payout;
  }

  Future<EqubGroupMetrics> getGroupMetrics(String groupId) async {
    final group = await getGroup(groupId);
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

  Future<List<EqubRoundSummary>> getRoundSummaries(String groupId) async {
    final group = await getGroup(groupId);
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

  Future<void> _track(
    String event, {
    String? userId,
    Map<String, dynamic>? properties,
  }) async {
    if (_analyticsService == null) return;
    await _analyticsService.track(
      event,
      userId: userId,
      properties: properties,
    );
  }

  List<String> _mergePreferredOrder(
    List<String> preferredOrder,
    List<String> members,
  ) {
    final result = <String>[];
    final memberSet = members.toSet();
    for (final member in preferredOrder) {
      if (memberSet.contains(member) && !result.contains(member)) {
        result.add(member);
      }
    }
    for (final member in members) {
      if (!result.contains(member)) {
        result.add(member);
      }
    }
    return List<String>.unmodifiable(result);
  }

  // Legacy seeding code removed
}
