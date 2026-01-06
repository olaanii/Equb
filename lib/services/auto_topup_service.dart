import 'dart:async';

import 'package:equb/models/auto_topup.dart';
import 'package:equb/services/auto_topup_repository.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/services/wallet_repository.dart';

class AutoTopupService {
  AutoTopupService({
    required this.repository,
    required this.walletRepository,
    required this.gatewayService,
    required this.logService,
  });

  final AutoTopupRepository repository;
  final WalletRepository walletRepository;
  final GatewayService gatewayService;
  final SystemLogService logService;

  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  /// Start monitoring user balances for auto top-up triggers
  void startBalanceMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkAndExecuteTopups();
    });

    logService.log(
      LogLevel.info,
      'auto_topup.startMonitoring',
      'Balance monitoring started',
    );
  }

  /// Stop balance monitoring
  void stopBalanceMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;

    logService.log(
      LogLevel.info,
      'auto_topup.stopMonitoring',
      'Balance monitoring stopped',
    );
  }

  /// Check balances and execute top-ups for users who need them
  Future<void> _checkAndExecuteTopups() async {
    try {
      // Get all active rules that are due for execution
      final dueRules = await repository.getRulesDueForExecution();

      logService.log(
        LogLevel.debug,
        'auto_topup.checkBalances',
        'Found rules due for execution',
        context: {'count': dueRules.length},
      );

      for (final rule in dueRules) {
        try {
          await _executeTopupForRule(rule);
        } catch (e) {
          logService.log(
            LogLevel.error,
            'auto_topup.executeTopup',
            'Failed to execute top-up for rule',
            context: {
              'ruleId': rule.id,
              'userId': rule.userId,
              'error': e.toString(),
            },
          );
        }
      }
    } catch (e) {
      logService.log(
        LogLevel.error,
        'auto_topup.checkBalances',
        'Failed to check balances for auto top-up',
        context: {'error': e.toString()},
      );
    }
  }

  /// Execute a top-up for a specific rule
  Future<void> _executeTopupForRule(AutoTopupRule rule) async {
    try {
      // Check current balance
      final summary = await walletRepository.getWalletSummary(rule.userId);
      final needsTopup = summary.available < rule.thresholdAmount;

      if (!needsTopup) {
        logService.log(
          LogLevel.debug,
          'auto_topup.executeTopup',
          'Top-up not needed, balance above threshold',
          context: {
            'ruleId': rule.id,
            'userId': rule.userId,
            'currentBalance': summary.available,
            'threshold': rule.thresholdAmount,
          },
        );
        return;
      }

      // Execute the top-up
      final transaction = await walletRepository.deposit(
        rule.userId,
        rule.topupAmount,
        rule.paymentMethod,
      );

      // Record the execution
      await repository.recordExecution(
        ruleId: rule.id,
        userId: rule.userId,
        amount: rule.topupAmount,
        paymentMethod: rule.paymentMethod,
        status: 'success',
        transactionId: transaction.id,
        metadata: {
          'balanceBefore': summary.available,
          'balanceAfter': summary.available + rule.topupAmount,
          'threshold': rule.thresholdAmount,
        },
      );

      logService.log(
        LogLevel.info,
        'auto_topup.executeTopup',
        'Auto top-up executed successfully',
        context: {
          'ruleId': rule.id,
          'userId': rule.userId,
          'amount': rule.topupAmount,
          'transactionId': transaction.id,
        },
      );
    } catch (e) {
      // Record the failure
      await repository.recordExecution(
        ruleId: rule.id,
        userId: rule.userId,
        amount: rule.topupAmount,
        paymentMethod: rule.paymentMethod,
        status: 'failed',
        errorMessage: e.toString(),
      );

      logService.log(
        LogLevel.warning,
        'auto_topup.executeTopup',
        'Auto top-up execution failed',
        context: {
          'ruleId': rule.id,
          'userId': rule.userId,
          'error': e.toString(),
        },
      );

      rethrow;
    }
  }

  /// Manually trigger a top-up check for a specific user
  Future<List<BalanceThresholdCheck>> checkUserBalances(String userId) async {
    try {
      final rules = await repository.getUserRules(userId);
      final summary = await walletRepository.getWalletSummary(userId);

      final checks = <BalanceThresholdCheck>[];

      for (final rule in rules.where((r) => r.isActive)) {
        final needsTopup = summary.available < rule.thresholdAmount;
        checks.add(BalanceThresholdCheck(
          userId: userId,
          currentBalance: summary.available,
          thresholdAmount: rule.thresholdAmount,
          needsTopup: needsTopup,
          recommendedAmount: needsTopup ? rule.topupAmount : 0,
        ));
      }

      return checks;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'auto_topup.checkUserBalances',
        'Failed to check user balances',
        context: {
          'userId': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Create a new auto top-up rule
  Future<AutoTopupRule> createRule({
    required String userId,
    required double thresholdAmount,
    required double topupAmount,
    required AutoTopupFrequency frequency,
    required String paymentMethod,
    DateTime? startDate,
  }) async {
    // Validate the payment method exists
    final gateways = await gatewayService.getEnabledGateways();
    final gatewayExists = gateways.any((g) => g.id == paymentMethod);

    if (!gatewayExists) {
      throw Exception('Payment method not available: $paymentMethod');
    }

    final nextScheduledAt = startDate ?? DateTime.now().add(frequency.interval);

    return repository.createRule(
      userId: userId,
      thresholdAmount: thresholdAmount,
      topupAmount: topupAmount,
      frequency: frequency,
      paymentMethod: paymentMethod,
      nextScheduledAt: nextScheduledAt,
    );
  }

  /// Update an existing rule
  Future<void> updateRule(String ruleId, AutoTopupRule updatedRule) async {
    await repository.updateRule(ruleId, updatedRule);
  }

  /// Enable/disable a rule
  Future<void> setRuleEnabled(String ruleId, bool enabled) async {
    await repository.setRuleEnabled(ruleId, enabled);
  }

  /// Delete a rule
  Future<void> deleteRule(String ruleId) async {
    await repository.deleteRule(ruleId);
  }

  /// Get user's rules
  Future<List<AutoTopupRule>> getUserRules(String userId) async {
    return repository.getUserRules(userId);
  }

  /// Get execution history
  Future<List<AutoTopupExecution>> getExecutionHistory(String userId) async {
    return repository.getExecutionHistory(userId);
  }

  /// Test a rule execution (for validation)
  Future<bool> testRuleExecution(AutoTopupRule rule) async {
    try {
      // Check if payment method is available
      final gateways = await gatewayService.getEnabledGateways();
      final gateway = gateways.where((g) => g.id == rule.paymentMethod).firstOrNull;

      if (gateway == null) {
        logService.log(
          LogLevel.warning,
          'auto_topup.testRule',
          'Payment method not available',
          context: {
            'ruleId': rule.id,
            'paymentMethod': rule.paymentMethod,
          },
        );
        return false;
      }

      // Check if user has sufficient balance (this would be checked during actual execution)
      // For testing, we just validate the rule configuration

      logService.log(
        LogLevel.info,
        'auto_topup.testRule',
        'Rule configuration validated successfully',
        context: {'ruleId': rule.id},
      );

      return true;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'auto_topup.testRule',
        'Rule validation failed',
        context: {
          'ruleId': rule.id,
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  /// Get monitoring status
  bool get isMonitoring => _isMonitoring;

  /// Force immediate execution check (admin only)
  Future<int> forceExecutionCheck() async {
    if (!_isMonitoring) {
      throw Exception('Monitoring is not active');
    }

    await _checkAndExecuteTopups();
    return 0; // Return count of processed rules (would need to track this)
  }
}

