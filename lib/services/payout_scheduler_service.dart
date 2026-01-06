import 'dart:async';
import 'dart:math';

import 'package:equb/models/equb_model.dart';
import 'package:equb/models/payout_schedule.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/services/wallet_repository.dart';

class PayoutSchedulerService {
  PayoutSchedulerService({
    required this.equbRepository,
    required this.walletRepository,
    required this.logService,
  });

  final EqubRepository equbRepository;
  final WalletRepository walletRepository;
  final SystemLogService logService;

  Timer? _schedulerTimer;
  bool _isSchedulerActive = false;

  /// Start the payout scheduler
  void startScheduler() {
    if (_isSchedulerActive) return;

    _isSchedulerActive = true;
    _schedulerTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _processScheduledPayouts();
    });

    logService.log(
      LogLevel.info,
      'payout_scheduler.startScheduler',
      'Payout scheduler started',
    );
  }

  /// Stop the payout scheduler
  void stopScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _isSchedulerActive = false;

    logService.log(
      LogLevel.info,
      'payout_scheduler.stopScheduler',
      'Payout scheduler stopped',
    );
  }

  /// Process scheduled payouts that are due
  Future<void> _processScheduledPayouts() async {
    try {
      final now = DateTime.now();

      // Get all groups that might have payouts due
      final groups = await equbRepository.listGroups();

      for (final group in groups) {
        try {
          await _processGroupPayouts(group, now);
        } catch (e) {
          logService.log(
            LogLevel.error,
            'payout_scheduler.processGroupPayouts',
            'Failed to process payouts for group',
            context: {'groupId': group.id, 'error': e.toString()},
          );
        }
      }
    } catch (e) {
      logService.log(
        LogLevel.error,
        'payout_scheduler.processScheduledPayouts',
        'Failed to process scheduled payouts',
        context: {'error': e.toString()},
      );
    }
  }

  /// Process payouts for a specific group
  Future<void> _processGroupPayouts(
    EqubGroup group,
    DateTime currentTime,
  ) async {
    // Check if it's time for a payout based on the group's schedule
    final nextPayoutDate = group.rotationState.nextPayoutDate;

    if (nextPayoutDate.isAfter(currentTime)) {
      return; // Not time yet
    }

    // Check if we have enough funds for payout
    final potSize = await _calculateGroupPotSize(group);
    final payoutAmount = group.contributionAmount * group.members.length;

    if (potSize < payoutAmount) {
      logService.log(
        LogLevel.warning,
        'payout_scheduler.checkPotSize',
        'Insufficient funds for payout',
        context: {
          'groupId': group.id,
          'potSize': potSize,
          'requiredAmount': payoutAmount,
        },
      );
      return;
    }

    // Select winner and schedule payout
    final winnerResult = await _selectWinner(group);

    if (winnerResult != null) {
      await _schedulePayout(group, winnerResult, payoutAmount, currentTime);
    }
  }

  /// Calculate the current pot size for a group
  Future<double> _calculateGroupPotSize(EqubGroup group) async {
    double totalPot = 0;

    // Sum up contributions from all members
    for (final memberId in group.members) {
      try {
        final summary = await walletRepository.getWalletSummary(memberId);
        // In a real implementation, we'd track group-specific contributions
        // For now, assume each member has contributed their share
        totalPot += group.contributionAmount;
      } catch (e) {
        logService.log(
          LogLevel.warning,
          'payout_scheduler.calculatePotSize',
          'Failed to get member balance',
          context: {
            'groupId': group.id,
            'memberId': memberId,
            'error': e.toString(),
          },
        );
      }
    }

    return totalPot;
  }

  /// Select a winner for the current round
  Future<WinnerSelectionResult?> _selectWinner(EqubGroup group) async {
    final currentRound = group.rotationState.currentRound + 1;
    final eligibleMembers =
        group.members.where((member) {
          // Check if member has completed their contributions
          final progress =
              group.rotationState.contributionProgress[member] ?? 0.0;
          return progress >= 1.0; // 100% contributed
        }).toList();

    if (eligibleMembers.isEmpty) {
      logService.log(
        LogLevel.warning,
        'payout_scheduler.selectWinner',
        'No eligible members for payout',
        context: {'groupId': group.id, 'round': currentRound},
      );
      return null;
    }

    String selectedRecipient;
    String strategy;
    double confidence = 1.0;

    switch (group.payoutStrategy) {
      case PayoutStrategy.random:
        selectedRecipient = _selectRandomWinner(eligibleMembers);
        strategy = 'random';
        break;

      case PayoutStrategy.fixedOrder:
        selectedRecipient = _selectFixedOrderWinner(
          group,
          eligibleMembers,
          currentRound,
        );
        strategy = 'fixed_order';
        break;

      case PayoutStrategy.adminAssigned:
        // Check for admin assignment
        final adminAssignment =
            group.scheduleConfig.adminAssignments[currentRound];
        if (adminAssignment != null &&
            eligibleMembers.contains(adminAssignment)) {
          selectedRecipient = adminAssignment;
          strategy = 'admin_assigned';
        } else {
          // Fallback to random
          selectedRecipient = _selectRandomWinner(eligibleMembers);
          strategy = 'random_fallback';
          confidence = 0.8;
        }
        break;
    }

    return WinnerSelectionResult(
      groupId: group.id,
      round: currentRound,
      selectedRecipient: selectedRecipient,
      strategy: strategy,
      eligibleMembers: eligibleMembers,
      selectionTimestamp: DateTime.now(),
      confidence: confidence,
    );
  }

  String _selectRandomWinner(List<String> eligibleMembers) {
    final random = Random();
    return eligibleMembers[random.nextInt(eligibleMembers.length)];
  }

  String _selectFixedOrderWinner(
    EqubGroup group,
    List<String> eligibleMembers,
    int round,
  ) {
    final preferredOrder = group.scheduleConfig.preferredOrder;
    if (preferredOrder.isNotEmpty) {
      final index = (round - 1) % preferredOrder.length;
      final candidate = preferredOrder[index];
      if (eligibleMembers.contains(candidate)) {
        return candidate;
      }
    }

    // Fallback to random if preferred order member is not eligible
    return _selectRandomWinner(eligibleMembers);
  }

  /// Schedule a payout for the selected winner
  Future<void> _schedulePayout(
    EqubGroup group,
    WinnerSelectionResult winnerResult,
    double amount,
    DateTime scheduleTime,
  ) async {
    try {
      // Create fund distribution plan
      final distributionPlan = FundDistributionPlan(
        groupId: group.id,
        round: winnerResult.round,
        totalPot: amount,
        recipientId: winnerResult.selectedRecipient,
        distributionAmount: amount,
        feeAmount: amount * 0.02, // 2% fee
        netAmount: amount * 0.98,
        distributionMethod: 'wallet', // Default to wallet transfer
        createdAt: DateTime.now(),
      );

      // Create payout schedule
      final payoutSchedule = PayoutSchedule(
        id:
            'payout_${group.id}_${winnerResult.round}_${DateTime.now().millisecondsSinceEpoch}',
        groupId: group.id,
        round: winnerResult.round,
        recipientId: winnerResult.selectedRecipient,
        amount: distributionPlan.netAmount,
        scheduledDate: scheduleTime,
        type: PayoutType.regular,
        status: PayoutStatus.scheduled,
        createdAt: DateTime.now(),
        metadata: {
          'winnerSelection': winnerResult.toJson(),
          'distributionPlan': distributionPlan.toJson(),
        },
      );

      // Process the payout immediately (or schedule for later)
      await _executePayout(payoutSchedule, distributionPlan);

      // Update group rotation state
      final updatedGroup = group.copyWith(
        rotationState: group.rotationState.copyWith(
          currentRound: winnerResult.round,
          nextPayoutDate: scheduleTime.add(group.scheduleConfig.cycle.interval),
          history: [
            ...group.rotationState.history,
            EqubPayoutRecord(
              round: winnerResult.round,
              memberId: winnerResult.selectedRecipient,
              amount: distributionPlan.netAmount,
              scheduledFor: scheduleTime,
              processedAt: DateTime.now(),
            ),
          ],
        ),
      );

      await equbRepository.updateGroup(updatedGroup);

      logService.log(
        LogLevel.info,
        'payout_scheduler.schedulePayout',
        'Payout scheduled and executed',
        context: {
          'groupId': group.id,
          'round': winnerResult.round,
          'recipientId': winnerResult.selectedRecipient,
          'amount': distributionPlan.netAmount,
        },
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'payout_scheduler.schedulePayout',
        'Failed to schedule payout',
        context: {
          'groupId': group.id,
          'round': winnerResult.round,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Execute a scheduled payout
  Future<PayoutProcessingResult> _executePayout(
    PayoutSchedule schedule,
    FundDistributionPlan plan,
  ) async {
    try {
      // Transfer funds to recipient's wallet
      final transaction = await walletRepository.deposit(
        schedule.recipientId,
        plan.netAmount,
        'internal_transfer', // Internal system transfer
      );

      // Update payout schedule status
      final completedSchedule = schedule.copyWith(
        status: PayoutStatus.completed,
        processedAt: DateTime.now(),
        transactionId: transaction.id,
      );

      logService.log(
        LogLevel.info,
        'payout_scheduler.executePayout',
        'Payout executed successfully',
        context: {
          'payoutId': schedule.id,
          'recipientId': schedule.recipientId,
          'amount': plan.netAmount,
          'transactionId': transaction.id,
        },
      );

      return PayoutProcessingResult(
        success: true,
        payoutSchedule: completedSchedule,
        transactionId: transaction.id,
      );
    } catch (e) {
      // Mark payout as failed
      final failedSchedule = schedule.copyWith(
        status: PayoutStatus.failed,
        processedAt: DateTime.now(),
        failureReason: e.toString(),
      );

      logService.log(
        LogLevel.error,
        'payout_scheduler.executePayout',
        'Payout execution failed',
        context: {
          'payoutId': schedule.id,
          'recipientId': schedule.recipientId,
          'error': e.toString(),
        },
      );

      return PayoutProcessingResult(
        success: false,
        payoutSchedule: failedSchedule,
        errorMessage: e.toString(),
      );
    }
  }

  /// Manually trigger payout for a group (admin function)
  Future<bool> triggerManualPayout(String groupId) async {
    try {
      final group = await equbRepository.findGroup(groupId);
      if (group == null) {
        throw Exception('Group not found');
      }

      await _processGroupPayouts(group, DateTime.now());
      return true;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'payout_scheduler.triggerManualPayout',
        'Manual payout trigger failed',
        context: {'groupId': groupId, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Get payout history for a group
  Future<List<PayoutSchedule>> getGroupPayoutHistory(
    String groupId, {
    int limit = 50,
  }) async {
    // In a real implementation, this would query a payout schedule repository
    // For now, we'll derive this from the group's rotation history
    try {
      final group = await equbRepository.findGroup(groupId);
      if (group == null) return [];

      final schedules = <PayoutSchedule>[];

      for (final record in group.rotationState.history) {
        schedules.add(
          PayoutSchedule(
            id: 'payout_${groupId}_${record.round}',
            groupId: groupId,
            round: record.round,
            recipientId: record.memberId,
            amount: record.amount,
            scheduledDate: record.scheduledFor,
            type: PayoutType.regular,
            status: PayoutStatus.completed,
            createdAt: record.processedAt ?? record.scheduledFor,
            processedAt: record.processedAt,
          ),
        );
      }

      schedules.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return schedules.take(limit).toList();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'payout_scheduler.getGroupPayoutHistory',
        'Failed to get payout history',
        context: {'groupId': groupId, 'error': e.toString()},
      );
      return [];
    }
  }

  /// Check if scheduler is active
  bool get isSchedulerActive => _isSchedulerActive;

  /// Force immediate execution check (admin only)
  Future<int> forceExecutionCheck() async {
    if (!_isSchedulerActive) {
      throw Exception('Scheduler is not active');
    }

    await _processScheduledPayouts();
    return 0; // Would return count of processed payouts
  }
}
