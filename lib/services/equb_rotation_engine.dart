import 'dart:math' as math;

import 'package:equb/models/equb_model.dart';
import 'package:equb/services/payout_scheduler_service.dart';

class RotationUpdate {
  const RotationUpdate({
    required this.state,
    required this.payoutTriggered,
    required this.readyForManualAssignment,
    this.payout,
  });

  final EqubRotationState state;
  final bool payoutTriggered;
  final bool readyForManualAssignment;
  final EqubPayoutRecord? payout;
}

class _RecipientSelection {
  const _RecipientSelection(this.recipient, this.queue);

  final String recipient;
  final List<String> queue;
}

class EqubRotationEngine {
  PayoutSchedulerService? _payoutScheduler;

  void setPayoutScheduler(PayoutSchedulerService scheduler) {
    _payoutScheduler = scheduler;
  }

  EqubRotationState bootstrapState({
    required EqubScheduleConfig config,
    required List<String> members,
    DateTime? now,
  }) {
    final normalizedMembers = _normalizeMembers(members);
    final queue = _buildInitialQueue(normalizedMembers, config);
    final contributions = {for (final member in normalizedMembers) member: 0.0};
    final anchor = (now ?? DateTime.now()).toUtc();
    var nextPayout = config.startDate;
    while (!nextPayout.isAfter(anchor)) {
      nextPayout = nextPayout.add(Duration(days: config.cycleLengthDays));
    }
    return EqubRotationState(
      currentRound: 0,
      nextPayoutDate: nextPayout,
      payoutQueue: queue,
      contributionProgress: contributions,
      history: const [],
    );
  }

  EqubRotationState syncState({
    required EqubRotationState state,
    required EqubScheduleConfig config,
    required List<String> members,
    DateTime? now,
  }) {
    final normalizedMembers = _normalizeMembers(members);
    final queue = _ensureQueue(state.payoutQueue, normalizedMembers, config);
    final contributions = <String, double>{
      for (final member in normalizedMembers)
        member: state.contributionProgress[member] ?? 0.0,
    };
    final history = state.history
        .where((record) => normalizedMembers.contains(record.memberId))
        .toList(growable: false);
    var nextPayout =
        state.nextPayoutDate.isBefore(config.startDate)
            ? config.startDate
            : state.nextPayoutDate;
    final anchor = (now ?? DateTime.now()).toUtc();
    while (!nextPayout.isAfter(anchor)) {
      nextPayout = nextPayout.add(Duration(days: config.cycleLengthDays));
    }
    return state.copyWith(
      payoutQueue: queue,
      contributionProgress: contributions,
      history: history,
      nextPayoutDate: nextPayout,
    );
  }

  RotationUpdate registerContribution({
    required EqubGroup group,
    required String memberId,
    required double amount,
    DateTime? now,
  }) {
    final config = group.scheduleConfig;
    final members = _normalizeMembers(group.members);
    if (members.isEmpty) {
      return RotationUpdate(
        state: group.rotationState,
        payoutTriggered: false,
        readyForManualAssignment: false,
      );
    }
    final syncedState = syncState(
      state: group.rotationState,
      config: config,
      members: members,
      now: now,
    );
    final contributions = Map<String, double>.from(
      syncedState.contributionProgress,
    );
    contributions[memberId] = (contributions[memberId] ?? 0.0) + amount;
    final required = group.contributionAmount;
    final thresholdMet = members.every(
      (member) => (contributions[member] ?? 0.0) + 1e-8 >= required,
    );
    if (!thresholdMet || !config.autoAssign) {
      final updatedState = syncedState.copyWith(
        contributionProgress: contributions,
      );
      return RotationUpdate(
        state: updatedState,
        payoutTriggered: false,
        readyForManualAssignment: thresholdMet && !config.autoAssign,
      );
    }

    final ensuredQueue = _ensureQueue(syncedState.payoutQueue, members, config);
    final nextRound = syncedState.currentRound + 1;
    final selection = _selectRecipient(
      ensuredQueue,
      config,
      nextRound,
      members,
    );
    final recipient = selection.recipient;
    final payoutAmount = required * members.length;
    final timestamp = (now ?? DateTime.now()).toUtc();

    // Instead of creating the record directly, trigger the payout scheduler
    if (_payoutScheduler != null) {
      // Schedule the payout using the payout scheduler service
      // This will handle winner selection, fund distribution, and execution
      Future.microtask(() async {
        try {
          await _payoutScheduler!.triggerManualPayout(group.id);
        } catch (e) {
          // Log error but don't block the contribution registration
          print('Failed to trigger payout for group ${group.id}: $e');
        }
      });
    }

    // For now, create a placeholder record until the payout scheduler processes it
    final record = EqubPayoutRecord(
      round: nextRound,
      memberId: recipient,
      amount: payoutAmount,
      scheduledFor: syncedState.nextPayoutDate,
      processedAt: timestamp,
      autoAssigned: true,
      note: 'Payout scheduled via scheduler service',
    );

    final history = [...syncedState.history, record];
    final adjustedProgress = <String, double>{
      for (final member in members)
        member: math.max((contributions[member] ?? 0.0) - required, 0.0),
    };
    final nextQueue = _rotateQueue(
      selection.queue,
      recipient,
      members,
      config,
      history.length,
    );
    final nextPayoutDate = _computeNextPayoutDate(
      syncedState.nextPayoutDate,
      config,
      timestamp,
    );

    final updatedState = syncedState.copyWith(
      currentRound: nextRound,
      contributionProgress: adjustedProgress,
      history: history,
      payoutQueue: nextQueue,
      nextPayoutDate: nextPayoutDate,
    );

    return RotationUpdate(
      state: updatedState,
      payoutTriggered: true,
      readyForManualAssignment: false,
      payout: record,
    );
  }

  RotationUpdate forcePayout({
    required EqubGroup group,
    String? overrideMemberId,
    double? overrideAmount,
    bool ignoreContributionThreshold = false,
    DateTime? now,
    String? note,
  }) {
    final config = group.scheduleConfig;
    final members = _normalizeMembers(group.members);
    if (members.isEmpty) {
      return RotationUpdate(
        state: group.rotationState,
        payoutTriggered: false,
        readyForManualAssignment: false,
      );
    }
    final syncedState = syncState(
      state: group.rotationState,
      config: config,
      members: members,
      now: now,
    );
    final ensuredQueue = _ensureQueue(syncedState.payoutQueue, members, config);
    final nextRound = syncedState.currentRound + 1;
    var selection = _selectRecipient(ensuredQueue, config, nextRound, members);
    var recipient = selection.recipient;
    if (overrideMemberId != null && members.contains(overrideMemberId)) {
      recipient = overrideMemberId;
      final normalizedMembers = _normalizeMembers(members);
      final updatedQueue = selection.queue
          .where(normalizedMembers.contains)
          .toList(growable: true);
      if (updatedQueue.contains(recipient)) {
        updatedQueue
          ..remove(recipient)
          ..insert(0, recipient);
      } else {
        updatedQueue.insert(0, recipient);
      }
      for (final member in normalizedMembers) {
        if (!updatedQueue.contains(member)) {
          updatedQueue.add(member);
        }
      }
      selection = _RecipientSelection(recipient, updatedQueue);
    }
    final contributions = Map<String, double>.from(
      syncedState.contributionProgress,
    );
    final required = group.contributionAmount;
    final thresholdMet = members.every(
      (member) => (contributions[member] ?? 0.0) + 1e-8 >= required,
    );

    if (!thresholdMet && !ignoreContributionThreshold) {
      return RotationUpdate(
        state: syncedState,
        payoutTriggered: false,
        readyForManualAssignment: false,
      );
    }

    final payoutAmount = overrideAmount ?? required * members.length;
    final timestamp = (now ?? DateTime.now()).toUtc();
    final record = EqubPayoutRecord(
      round: syncedState.currentRound + 1,
      memberId: recipient,
      amount: payoutAmount,
      scheduledFor: syncedState.nextPayoutDate,
      processedAt: timestamp,
      autoAssigned: false,
      note: note,
    );
    final history = [...syncedState.history, record];
    final adjustedProgress = <String, double>{
      for (final member in members)
        member: math.max((contributions[member] ?? 0.0) - required, 0.0),
    };
    final nextQueue = _rotateQueue(
      selection.queue,
      recipient,
      members,
      config,
      history.length,
    );
    final nextPayoutDate = _computeNextPayoutDate(
      syncedState.nextPayoutDate,
      config,
      timestamp,
    );
    final updatedState = syncedState.copyWith(
      currentRound: record.round,
      contributionProgress: adjustedProgress,
      history: history,
      payoutQueue: nextQueue,
      nextPayoutDate: nextPayoutDate,
    );

    return RotationUpdate(
      state: updatedState,
      payoutTriggered: true,
      readyForManualAssignment: false,
      payout: record,
    );
  }

  List<String> _normalizeMembers(List<String> members) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final member in members) {
      final trimmed = member.trim();
      if (trimmed.isEmpty) continue;
      if (seen.add(trimmed)) {
        normalized.add(trimmed);
      }
    }
    return List<String>.unmodifiable(normalized);
  }

  List<String> _buildInitialQueue(
    List<String> members,
    EqubScheduleConfig config,
  ) {
    if (members.isEmpty) {
      return const [];
    }
    switch (config.strategy) {
      case PayoutStrategy.fixedOrder:
      case PayoutStrategy.adminAssigned:
        final preferred =
            config.preferredOrder.where(members.contains).toList();
        final remainder = members.where((m) => !preferred.contains(m)).toList();
        return [...preferred, ...remainder];
      case PayoutStrategy.random:
        final list = members.toList();
        final random = math.Random(config.startDate.millisecondsSinceEpoch);
        list.shuffle(random);
        return list;
    }
  }

  List<String> _ensureQueue(
    List<String> existing,
    List<String> members,
    EqubScheduleConfig config,
  ) {
    final queue = existing.where(members.contains).toList();
    for (final member in members) {
      if (!queue.contains(member)) {
        queue.add(member);
      }
    }
    if (queue.isEmpty) {
      return _buildInitialQueue(members, config);
    }
    return queue;
  }

  _RecipientSelection _selectRecipient(
    List<String> queue,
    EqubScheduleConfig config,
    int nextRound,
    List<String> members,
  ) {
    final normalizedMembers = _normalizeMembers(members);
    if (normalizedMembers.isEmpty) {
      return _RecipientSelection('', const <String>[]);
    }
    final assigned = config.adminAssignments[nextRound];
    final workingQueue = queue.where(normalizedMembers.contains).toList();
    if (assigned != null && normalizedMembers.contains(assigned)) {
      final queueWithAssignment = List<String>.from(workingQueue);
      if (queueWithAssignment.contains(assigned)) {
        queueWithAssignment
          ..remove(assigned)
          ..insert(0, assigned);
      } else {
        queueWithAssignment.insert(0, assigned);
      }
      return _RecipientSelection(assigned, queueWithAssignment);
    }

    if (workingQueue.isEmpty) {
      final fallbackQueue = List<String>.from(normalizedMembers);
      if (config.strategy == PayoutStrategy.random &&
          fallbackQueue.length > 1) {
        fallbackQueue.shuffle(math.Random());
      }
      return _RecipientSelection(fallbackQueue.first, fallbackQueue);
    }

    if (config.strategy == PayoutStrategy.random && workingQueue.length > 1) {
      final roundsServed = nextRound - 1;
      final memberCount = normalizedMembers.length;
      final servedThisSeason =
          memberCount == 0 ? 0 : roundsServed % memberCount;
      final remainingThisSeason =
          memberCount == 0
              ? workingQueue.length
              : (memberCount - servedThisSeason == 0
                  ? memberCount
                  : memberCount - servedThisSeason);
      final limit = math.min(remainingThisSeason, workingQueue.length);
      if (limit > 1) {
        final segment = workingQueue.sublist(0, limit).toList(growable: false);
        segment.shuffle(math.Random());
        for (var i = 0; i < limit; i++) {
          workingQueue[i] = segment[i];
        }
      }
    }

    return _RecipientSelection(workingQueue.first, workingQueue);
  }

  List<String> _rotateQueue(
    List<String> queue,
    String recipient,
    List<String> members,
    EqubScheduleConfig config,
    int roundsServed,
  ) {
    final normalizedMembers = _normalizeMembers(members);
    final rotated = queue.where(normalizedMembers.contains).toList();
    rotated.remove(recipient);
    rotated.add(recipient);
    for (final member in normalizedMembers) {
      if (!rotated.contains(member)) {
        rotated.add(member);
      }
    }
    if (config.strategy == PayoutStrategy.random &&
        normalizedMembers.isNotEmpty) {
      if (roundsServed % normalizedMembers.length == 0) {
        rotated.shuffle(math.Random());
      }
    }
    return rotated;
  }

  DateTime _computeNextPayoutDate(
    DateTime current,
    EqubScheduleConfig config,
    DateTime reference,
  ) {
    var next = current.add(Duration(days: config.cycleLengthDays));
    if (next.isBefore(config.startDate)) {
      next = config.startDate;
    }
    while (!next.isAfter(reference)) {
      next = next.add(Duration(days: config.cycleLengthDays));
    }
    return next;
  }
}
