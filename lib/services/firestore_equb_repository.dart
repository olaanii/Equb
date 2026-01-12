import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/equb_model.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/equb_rotation_engine.dart';
import 'package:equb/services/repository_exception.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/utils/money_mathematics.dart';
import 'package:flutter/material.dart';

class FirestoreEqubRepository implements EqubRepository {
  final FirebaseFirestore _firestore;
  final EqubRotationEngine _rotationEngine = EqubRotationEngine();
  final SystemLogService? _logService;

  FirestoreEqubRepository({
    FirebaseFirestore? firestore,
    SystemLogService? logService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _logService = logService;

  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection('groups');

  @override
  Future<List<EqubGroup>> listGroups() {
    return _guard('listGroups', () async {
      final snapshot = await _groupsRef.get();
      return snapshot.docs
          .map((doc) => EqubGroup.fromJson(doc.data()))
          .toList();
    });
  }

  @override
  Future<EqubGroup> createGroup(EqubGroup g, {String? actingUserId}) {
    return _guard('createGroup', () async {
      final docRef = g.id.isEmpty ? _groupsRef.doc() : _groupsRef.doc(g.id);
      final groupWithId = g.copyWith(id: docRef.id);
      await docRef.set(groupWithId.toJson());
      return groupWithId;
    }, context: {'groupId': g.id, 'actingUserId': actingUserId});
  }

  @override
  Future<EqubGroup> updateGroup(EqubGroup g, {String? actingUserId}) {
    return _guard('updateGroup', () async {
      await _groupsRef.doc(g.id).update(g.toJson());
      return g;
    }, context: {'groupId': g.id, 'actingUserId': actingUserId});
  }

  @override
  Future<void> deleteGroup(String groupId, {String? actingUserId}) {
    return _guard('deleteGroup', () async {
      await _groupsRef.doc(groupId).delete();
    }, context: {'groupId': groupId, 'actingUserId': actingUserId});
  }

  @override
  Future<EqubGroup?> findGroup(String groupId, {bool syncRotation = true}) {
    return _guard('findGroup', () async {
      final doc = await _groupsRef.doc(groupId).get();
      if (!doc.exists) return null;

      final group = EqubGroup.fromJson(doc.data()!);

      if (!syncRotation) return group;

      final now = DateTime.now();
      final updatedState = _rotationEngine.syncState(
        state: group.rotationState,
        config: group.scheduleConfig,
        members: group.members,
        now: now,
      );

      if (identical(updatedState, group.rotationState)) {
        return group;
      }

      final refreshed = group.copyWith(rotationState: updatedState);
      await _groupsRef.doc(groupId).update({
        'rotationState': updatedState.toJson(),
      });

      return refreshed;
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
  Future<TransactionModel> contribute({
    required String groupId,
    required String userId,
    required BuildContext context,
    String? screenshotUrl,
  }) {
    return _guard(
      'contribute',
      () async {
        final isManual = screenshotUrl != null;

        if (!isManual) {
          throw RepositoryException(
            code: 'payment-required',
            message:
                'Automatic contributions are disabled. Please complete payment via Chapa checkout, or upload a screenshot for manual verification.',
          );
        }

        return _firestore.runTransaction((transaction) async {
          final docRef = _groupsRef.doc(groupId);
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) {
            throw RepositoryException(
              code: 'group-not-found',
              message: 'Group $groupId not found',
            );
          }

          final userRef = _firestore.collection('users').doc(userId);
          final userDoc = await transaction.get(userRef);
          if (!userDoc.exists) {
            throw RepositoryException(
              code: 'user-not-found',
              message: 'User $userId not found',
            );
          }

          final group = EqubGroup.fromJson(snapshot.data()!);
          final amount = group.contributionAmount;
          final fee = MoneyMathematics.calculateFee(amount);
          final net = amount - fee;
          final points = MoneyMathematics.calculatePoints(
            amount,
            'contribution',
          );

          final tx = TransactionModel(
            id: 'TX-${DateTime.now().millisecondsSinceEpoch}',
            fromUserId: userId,
            toUserId: 'pool-$groupId',
            amount: amount,
            status: TransactionStatus.pending,
            gateway: 'manual-screenshot',
            feeAmount: fee,
            netAmount: net,
            screenshotUrl: screenshotUrl,
          );

          // Manual contributions are pending until reviewed/verified.
          final updatedGroup = group.copyWith(
            ledger: [...group.ledger, tx],
              rotationState: newRotationState,
            );
            transaction.update(docRef, updatedGroup.toJson());
          } else {
            // Just add to ledger but status is pending
            final updatedGroup = group.copyWith(ledger: [...group.ledger, tx]);
            transaction.update(docRef, updatedGroup.toJson());
          }

          return tx;
        });
      },
      context: {'groupId': groupId, 'userId': userId},
      friendlyMessage: 'Unable to record contribution',
    );
  }

  @override
  Future<EqubPayoutRecord?> triggerNextPayout(
    String groupId, {
    String? overrideMemberId,
    double? overrideAmount,
    bool ignoreContributionThreshold = false,
  }) {
    return _guard(
      'triggerNextPayout',
      () async {
        return _firestore.runTransaction((transaction) async {
          final docRef = _groupsRef.doc(groupId);
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) {
            throw RepositoryException(
              code: 'group-not-found',
              message: 'Group $groupId not found',
            );
          }

          final group = EqubGroup.fromJson(snapshot.data()!);
          final state = group.rotationState;
          if (state.payoutQueue.isEmpty) return null;

          final recipientId = overrideMemberId ?? state.payoutQueue.first;
          final amount = overrideAmount ?? group.poolAmountPerCycle;

          if (!ignoreContributionThreshold) {
            double totalCollected = 0;
            for (final m in group.members) {
              totalCollected += state.contributionProgress[m] ?? 0;
            }
            if (totalCollected + 1e-9 < amount) {
              throw RepositoryException(
                code: 'insufficient-funds',
                message: 'Not enough funds to trigger payout',
              );
            }
          }

          final payout = EqubPayoutRecord(
            round: state.currentRound + 1,
            memberId: recipientId,
            amount: amount,
            scheduledFor: state.nextPayoutDate,
            processedAt: DateTime.now(),
            autoAssigned: overrideMemberId == null,
          );

          final newHistory = [...state.history, payout];
          final newQueue = List<String>.from(state.payoutQueue)
            ..remove(recipientId);
          final newContributionProgress = {
            for (final m in group.members) m: 0.0,
          };

          final newRotationState = state.copyWith(
            currentRound: state.currentRound + 1,
            history: newHistory,
            payoutQueue: newQueue,
            contributionProgress: newContributionProgress,
            nextPayoutDate: state.nextPayoutDate.add(
              Duration(days: group.frequencyDays),
            ),
          );

          final updatedGroup = group.copyWith(rotationState: newRotationState);

          transaction.update(docRef, updatedGroup.toJson());

          return payout;
        });
      },
      context: {
        'groupId': groupId,
        'overrideMemberId': overrideMemberId,
        'ignoreContributionThreshold': ignoreContributionThreshold,
      },
    );
  }

  Future<T> _guard<T>(
    String operation,
    Future<T> Function() action, {
    Map<String, dynamic>? context,
    String? friendlyMessage,
  }) async {
    try {
      return await action();
    } on RepositoryException catch (error) {
      _logService?.log(
        LogLevel.warning,
        'FirestoreEqubRepository.$operation',
        error.message,
        context: _buildContext(operation, context, {'code': error.code}),
      );
      rethrow;
    } on FirebaseException catch (error, stack) {
      final wrapped = RepositoryException(
        code: error.code,
        message: friendlyMessage ?? 'Unable to complete $operation',
        cause: error,
        stackTrace: stack,
      );
      _logService?.log(
        LogLevel.error,
        'FirestoreEqubRepository.$operation',
        error.message ?? error.code,
        context: _buildContext(operation, context, {
          'firebaseCode': error.code,
        }),
      );
      throw wrapped;
    } catch (error, stack) {
      final wrapped = RepositoryException(
        code: 'unexpected',
        message: friendlyMessage ?? 'Unexpected failure during $operation',
        cause: error,
        stackTrace: stack,
      );
      _logService?.log(
        LogLevel.error,
        'FirestoreEqubRepository.$operation',
        error.toString(),
        context: _buildContext(operation, context),
      );
      throw wrapped;
    }
  }

  Map<String, dynamic> _buildContext(
    String operation,
    Map<String, dynamic>? context, [
    Map<String, dynamic>? extra,
  ]) {
    return {
      'operation': operation,
      if (context != null) ...context,
      if (extra != null) ...extra,
    };
  }
}
