import 'package:equb/models/equb_model.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_notification.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/equb_rotation_engine.dart';
import 'package:equb/services/repository_exception.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/utils/money_mathematics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class RtdbEqubRepository implements EqubRepository {
  RtdbEqubRepository({FirebaseDatabase? database, SystemLogService? logService})
    : _db = database ?? FirebaseDatabase.instance,
      _logService = logService;

  final FirebaseDatabase _db;
  final SystemLogService? _logService;
  final EqubRotationEngine _rotationEngine = EqubRotationEngine();

  DatabaseReference get _groupsRef => _db.ref('groups');

  Map<String, dynamic> _toRtdbGroupPayload(EqubGroup group) {
    final payload = group.toJson();
    payload['members'] = <String, dynamic>{
      for (final uid in group.members) uid: true,
    };
    return payload;
  }

  DatabaseReference _userRef(String userId) => _db.ref('users/$userId');

  String _notificationType(NotificationType type) =>
      type.toString().split('.').last;

  Future<void> _pushNotification({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? metadata,
  }) async {
    final id = _userRef(userId).child('notifications').push().key;
    if (id == null || id.isEmpty) return;

    final nowMs = ServerValue.timestamp;
    final payload = <String, dynamic>{
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': _notificationType(type),
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
      'createdAtMs': nowMs,
      if (metadata != null) 'metadata': metadata,
    };

    await _userRef(userId).child('notifications/$id').set(payload);
  }

  Future<void> _awardPoints({
    required String userId,
    required int delta,
    required String action,
    String? relatedGroupId,
    String? relatedTransactionId,
    Map<String, dynamic>? metadata,
  }) async {
    if (delta == 0) return;

    final ledgerId = _userRef(userId).child('points_ledger').push().key;
    if (ledgerId == null || ledgerId.isEmpty) return;

    final nowMs = ServerValue.timestamp;

    await _userRef(userId).runTransaction((currentData) {
      if (currentData == null || currentData is! Map) {
        return Transaction.abort();
      }

      final data = Map<String, dynamic>.from(currentData);
      final currentPoints = (data['points'] is int) ? data['points'] as int : 0;
      data['points'] = currentPoints + delta;

      final ledger =
          (data['points_ledger'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      ledger[ledgerId] = <String, dynamic>{
        'delta': delta,
        'action': action,
        'createdAtMs': nowMs,
        if (relatedTransactionId != null)
          'relatedTransactionId': relatedTransactionId,
        if (relatedGroupId != null) 'relatedGroupId': relatedGroupId,
        if (metadata != null) 'metadata': metadata,
      };
      data['points_ledger'] = ledger;

      return Transaction.success(data);
    });
  }

  @override
  Future<List<EqubGroup>> listGroups() {
    return _guard('listGroups', () async {
      final snapshot = await _groupsRef.get();
      final raw = snapshot.value;
      if (raw == null) return <EqubGroup>[];

      if (raw is! Map) {
        throw RepositoryException(
          code: 'invalid-data',
          message: 'Expected groups to be a Map',
        );
      }

      final groups = <EqubGroup>[];
      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is! Map) continue;
        final data = Map<String, dynamic>.from(value);
        data['id'] = data['id'] ?? key;
        groups.add(EqubGroup.fromJson(data));
      }

      groups.sort((a, b) => a.name.compareTo(b.name));
      return groups;
    });
  }

  @override
  Future<EqubGroup> createGroup(EqubGroup g, {String? actingUserId}) {
    return _guard('createGroup', () async {
      final ref = g.id.isEmpty ? _groupsRef.push() : _groupsRef.child(g.id);
      final id = ref.key;
      if (id == null || id.isEmpty) {
        throw RepositoryException(
          code: 'id-generation-failed',
          message: 'Failed to generate group id',
        );
      }
      final creatorId = (actingUserId ?? '').trim();
      final members =
          g.members.isNotEmpty
              ? g.members
              : (creatorId.isNotEmpty ? <String>[creatorId] : const <String>[]);

      final schedule = g.scheduleConfig.copyWith(
        preferredOrder:
            g.scheduleConfig.preferredOrder.isNotEmpty
                ? g.scheduleConfig.preferredOrder
                : members,
      );

      final rotation = _rotationEngine.bootstrapState(
        config: schedule,
        members: members,
      );

      final group = g.copyWith(
        id: id,
        members: members,
        scheduleConfig: schedule,
        rotationState: rotation,
      );
      await ref.set(_toRtdbGroupPayload(group));
      return group;
    }, context: {'groupId': g.id, 'actingUserId': actingUserId});
  }

  @override
  Future<EqubGroup> updateGroup(EqubGroup g, {String? actingUserId}) {
    return _guard('updateGroup', () async {
      await _groupsRef.child(g.id).set(_toRtdbGroupPayload(g));
      return g;
    }, context: {'groupId': g.id, 'actingUserId': actingUserId});
  }

  @override
  Future<void> deleteGroup(String groupId, {String? actingUserId}) {
    return _guard('deleteGroup', () async {
      await _groupsRef.child(groupId).remove();
    }, context: {'groupId': groupId, 'actingUserId': actingUserId});
  }

  @override
  Future<EqubGroup?> findGroup(String groupId, {bool syncRotation = true}) {
    return _guard('findGroup', () async {
      final snapshot = await _groupsRef.child(groupId).get();
      final raw = snapshot.value;
      if (raw == null) return null;
      if (raw is! Map) {
        throw RepositoryException(
          code: 'invalid-data',
          message: 'Expected group to be a Map',
        );
      }
      final data = Map<String, dynamic>.from(raw);
      data['id'] = data['id'] ?? groupId;
      final group = EqubGroup.fromJson(data);

      if (!syncRotation) return group;

      final now = DateTime.now();
      final updatedState = _rotationEngine.syncState(
        state: group.rotationState,
        config: group.scheduleConfig,
        members: group.members,
        now: now,
      );

      // Avoid over-optimizing equality checks; just persist the synced state.
      if (updatedState.nextPayoutDate != group.rotationState.nextPayoutDate ||
          updatedState.currentRound != group.rotationState.currentRound ||
          updatedState.payoutQueue.length !=
              group.rotationState.payoutQueue.length ||
          updatedState.history.length != group.rotationState.history.length) {
        await _groupsRef
            .child(groupId)
            .child('rotationState')
            .set(updatedState.toJson());
        return group.copyWith(rotationState: updatedState);
      }

      return group;
    }, context: {'groupId': groupId, 'syncRotation': syncRotation});
  }

  @override
  Future<EqubGroupMetrics> fetchGroupMetrics(String groupId) {
    return _guard('fetchGroupMetrics', () async {
      final group = await findGroup(groupId);
      if (group == null) {
        throw RepositoryException(
          code: 'group-not-found',
          message: 'Group $groupId not found',
        );
      }

      final state = group.rotationState;
      final config = group.scheduleConfig;
      final totalMembers = group.members.length;
      final completed = state.history.length;
      final potSize = group.contributionAmount * totalMembers;

      double totalCollected = 0;
      for (final m in group.members) {
        totalCollected += state.contributionProgress[m] ?? 0;
      }

      final fundedPct = potSize > 0 ? totalCollected / potSize : 0.0;
      final outstanding = potSize - totalCollected;

      return EqubGroupMetrics(
        groupId: group.id,
        totalMembers: totalMembers,
        currentRound: state.currentRound,
        completedRounds: completed,
        contributionAmount: group.contributionAmount,
        potSize: potSize,
        fundedPercentage: fundedPct > 1 ? 1.0 : fundedPct,
        totalOutstanding: outstanding < 0 ? 0 : outstanding,
        cycle: config.cycle,
        cycleLengthDays: config.cycleLengthDays,
        nextPayoutDate: state.nextPayoutDate,
        memberProgress: state.contributionProgress,
        nextRecipient:
            state.payoutQueue.isNotEmpty ? state.payoutQueue.first : null,
        nextRound: state.currentRound + 1,
      );
    }, context: {'groupId': groupId});
  }

  @override
  Future<List<EqubRoundSummary>> fetchRoundSummaries(String groupId) {
    return _guard('fetchRoundSummaries', () async {
      final group = await findGroup(groupId);
      if (group == null) {
        throw RepositoryException(
          code: 'group-not-found',
          message: 'Group $groupId not found',
        );
      }

      final summaries = <EqubRoundSummary>[];
      final historyMap = {
        for (var h in group.rotationState.history) h.round: h,
      };

      for (var i = 1; i <= group.rotationState.currentRound; i++) {
        final record = historyMap[i];
        if (record != null) {
          summaries.add(
            EqubRoundSummary(
              round: i,
              memberId: record.memberId,
              scheduledFor: record.scheduledFor,
              expectedAmount: record.amount,
              status: EqubRoundStatus.completed,
              autoAssigned: record.autoAssigned,
              actualPayout: record,
            ),
          );
        }
      }

      if (group.rotationState.payoutQueue.isNotEmpty) {
        summaries.add(
          EqubRoundSummary(
            round: group.rotationState.currentRound + 1,
            memberId: group.rotationState.payoutQueue.first,
            scheduledFor: group.rotationState.nextPayoutDate,
            expectedAmount: group.poolAmountPerCycle,
            status: EqubRoundStatus.pending,
            autoAssigned: true,
          ),
        );
      }

      return summaries;
    }, context: {'groupId': groupId});
  }

  @override
  Future<EqubPayoutRecord?> triggerNextPayout(
    String groupId, {
    String? overrideMemberId,
    double? overrideAmount,
    bool ignoreContributionThreshold = false,
  }) {
    return _guard('triggerNextPayout', () async {
      final group = await findGroup(groupId);
      if (group == null) {
        throw RepositoryException(
          code: 'group-not-found',
          message: 'Group $groupId not found',
        );
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
        await updateGroup(updated);
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

      final updated = group.copyWith(
        ledger: [...group.ledger, payoutTx],
        rotationState: outcome.state,
      );
      await updateGroup(updated);
      return payout;
    }, context: {'groupId': groupId});
  }

  @override
  Future<TransactionModel> contribute({
    required String groupId,
    required String userId,
    required BuildContext context,
    String? screenshotUrl,
  }) {
    return _guard('contribute', () async {
      final group = await findGroup(groupId);
      if (group == null) {
        throw RepositoryException(
          code: 'group-not-found',
          message: 'Group $groupId not found',
        );
      }

      if (screenshotUrl == null) {
        throw RepositoryException(
          code: 'payment-required',
          message:
              'Automatic contributions are disabled. Please complete payment via Chapa checkout, or upload a screenshot for manual verification.',
        );
      }

      final tx = TransactionModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fromUserId: userId,
        toUserId: groupId,
        amount: group.contributionAmount,
        timestamp: DateTime.now(),
        status: TransactionStatus.success,
        gateway: 'manual-screenshot',
        screenshotUrl: screenshotUrl,
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

      await updateGroup(updatedGroup);

      // Points + notifications (best-effort; non-fatal).
      try {
        final earned = MoneyMathematics.calculatePoints(
          tx.amount,
          'contribute',
        );
        await _awardPoints(
          userId: userId,
          delta: earned,
          action: 'contribute',
          relatedGroupId: groupId,
          relatedTransactionId: tx.id,
          metadata: <String, dynamic>{
            'amount': tx.amount,
            'groupName': group.name,
          },
        );

        await _pushNotification(
          userId: userId,
          title: 'Contribution recorded',
          body: 'Your contribution to ${group.name} was recorded.',
          type: NotificationType.transaction,
          metadata: <String, dynamic>{
            'groupId': groupId,
            'groupName': group.name,
            'transactionId': tx.id,
            'amount': tx.amount,
          },
        );

        if (rotationOutcome.payoutTriggered && rotationOutcome.payout != null) {
          final payout = rotationOutcome.payout!;
          await _pushNotification(
            userId: payout.memberId,
            title: 'Equb payout',
            body: 'You are the payout recipient for ${group.name}.',
            type: NotificationType.success,
            metadata: <String, dynamic>{
              'groupId': groupId,
              'groupName': group.name,
              'round': payout.round,
              'amount': payout.amount,
            },
          );
        }
      } catch (_) {
        // Best-effort; do not block contribution success.
      }

      return tx;
    }, context: {'groupId': groupId, 'userId': userId});
  }

  Future<T> _guard<T>(
    String operation,
    Future<T> Function() action, {
    Map<String, Object?>? context,
  }) async {
    try {
      return await action();
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'RtdbEqubRepository.$operation',
        'Operation failed',
        context: {'error': e.toString(), ...?context},
      );
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        code: 'operation-failed',
        message: 'Failed to $operation',
        cause: e,
      );
    }
  }
}
