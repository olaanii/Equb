import 'dart:async';

import 'package:equb/models/auto_topup.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:equb/services/system_log_service.dart';

class AutoTopupRepository {
  AutoTopupRepository({
    required FirebaseDatabase database,
    required SystemLogService logService,
  })  : _database = database,
        _logService = logService;

  final FirebaseDatabase _database;
  final SystemLogService _logService;

  /// Create a new auto top-up rule
  Future<AutoTopupRule> createRule({
    required String userId,
    required double thresholdAmount,
    required double topupAmount,
    required AutoTopupFrequency frequency,
    required String paymentMethod,
    required DateTime nextScheduledAt,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final rulesRef = _database.ref('auto_topup_rules');
      final ruleId = rulesRef.push().key;

      if (ruleId == null) {
        throw Exception('Failed to generate rule ID');
      }

      final rule = AutoTopupRule(
        id: ruleId,
        userId: userId,
        enabled: true,
        thresholdAmount: thresholdAmount,
        topupAmount: topupAmount,
        frequency: frequency,
        nextScheduledAt: nextScheduledAt,
        paymentMethod: paymentMethod,
        createdAt: DateTime.now(),
        metadata: metadata ?? const {},
      );

      await rulesRef.child(ruleId).set(rule.toJson());

      _logService.log(
        LogLevel.info,
        'auto_topup.createRule',
        'Auto top-up rule created successfully',
        context: {
          'ruleId': ruleId,
          'userId': userId,
          'thresholdAmount': thresholdAmount,
          'topupAmount': topupAmount,
        },
      );

      return rule;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.createRule',
        'Failed to create auto top-up rule',
        context: {
          'userId': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get all auto top-up rules for a user
  Future<List<AutoTopupRule>> getUserRules(String userId) async {
    try {
      final snapshot = await _database
          .ref('auto_topup_rules')
          .orderByChild('userId')
          .equalTo(userId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final rules = <AutoTopupRule>[];
      final rawData = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in rawData.entries) {
        try {
          final ruleData = Map<String, dynamic>.from(entry.value);
          ruleData['id'] = entry.key;
          rules.add(AutoTopupRule.fromJson(ruleData));
        } catch (e) {
          _logService.log(
            LogLevel.warning,
            'auto_topup.getUserRules',
            'Failed to parse rule',
            context: {
              'ruleId': entry.key,
              'error': e.toString(),
            },
          );
        }
      }

      rules.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return rules;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.getUserRules',
        'Failed to get user rules',
        context: {
          'userId': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get a specific auto top-up rule
  Future<AutoTopupRule?> getRule(String ruleId) async {
    try {
      final snapshot = await _database.ref('auto_topup_rules/$ruleId').get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final ruleData = Map<String, dynamic>.from(snapshot.value as Map);
      ruleData['id'] = ruleId;

      return AutoTopupRule.fromJson(ruleData);
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.getRule',
        'Failed to get rule',
        context: {
          'ruleId': ruleId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Update an auto top-up rule
  Future<void> updateRule(String ruleId, AutoTopupRule updatedRule) async {
    try {
      await _database.ref('auto_topup_rules/$ruleId').update(updatedRule.toJson());

      _logService.log(
        LogLevel.info,
        'auto_topup.updateRule',
        'Auto top-up rule updated',
        context: {
          'ruleId': ruleId,
          'enabled': updatedRule.enabled,
          'thresholdAmount': updatedRule.thresholdAmount,
        },
      );
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.updateRule',
        'Failed to update rule',
        context: {
          'ruleId': ruleId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Enable/disable an auto top-up rule
  Future<void> setRuleEnabled(String ruleId, bool enabled) async {
    try {
      await _database.ref('auto_topup_rules/$ruleId/enabled').set(enabled);

      _logService.log(
        LogLevel.info,
        'auto_topup.setRuleEnabled',
        'Rule ${enabled ? 'enabled' : 'disabled'}',
        context: {'ruleId': ruleId, 'enabled': enabled},
      );
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.setRuleEnabled',
        'Failed to update rule status',
        context: {
          'ruleId': ruleId,
          'enabled': enabled,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Delete an auto top-up rule
  Future<void> deleteRule(String ruleId) async {
    try {
      await _database.ref('auto_topup_rules/$ruleId').remove();

      _logService.log(
        LogLevel.info,
        'auto_topup.deleteRule',
        'Auto top-up rule deleted',
        context: {'ruleId': ruleId},
      );
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.deleteRule',
        'Failed to delete rule',
        context: {
          'ruleId': ruleId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get rules that need execution (admin/scheduler only)
  Future<List<AutoTopupRule>> getRulesDueForExecution() async {
    try {
      final now = DateTime.now();
      final snapshot = await _database
          .ref('auto_topup_rules')
          .orderByChild('nextScheduledAt')
          .endAt(now.toIso8601String())
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final rules = <AutoTopupRule>[];
      final rawData = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in rawData.entries) {
        try {
          final ruleData = Map<String, dynamic>.from(entry.value);
          ruleData['id'] = entry.key;
          final rule = AutoTopupRule.fromJson(ruleData);

          // Additional filters
          if (rule.shouldExecute && rule.nextScheduledAt.isBefore(now)) {
            rules.add(rule);
          }
        } catch (e) {
          _logService.log(
            LogLevel.warning,
            'auto_topup.getRulesDueForExecution',
            'Failed to parse rule',
            context: {
              'ruleId': entry.key,
              'error': e.toString(),
            },
          );
        }
      }

      return rules;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.getRulesDueForExecution',
        'Failed to get rules due for execution',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Record an execution attempt
  Future<AutoTopupExecution> recordExecution({
    required String ruleId,
    required String userId,
    required double amount,
    required String paymentMethod,
    required String status,
    String? transactionId,
    String? errorMessage,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final executionsRef = _database.ref('auto_topup_executions');
      final executionId = executionsRef.push().key;

      if (executionId == null) {
        throw Exception('Failed to generate execution ID');
      }

      final execution = AutoTopupExecution(
        id: executionId,
        ruleId: ruleId,
        userId: userId,
        executedAt: DateTime.now(),
        amount: amount,
        paymentMethod: paymentMethod,
        status: status,
        transactionId: transactionId,
        errorMessage: errorMessage,
        metadata: metadata ?? const {},
      );

      await executionsRef.child(executionId).set(execution.toJson());

      // Update the rule with execution results
      final updates = <String, dynamic>{
        'lastExecutedAt': execution.executedAt.toIso8601String(),
        'lastExecutionResult': status,
      };

      if (status == 'failed') {
        // Increment failure count and potentially suspend
        final rule = await getRule(ruleId);
        if (rule != null) {
          final newFailureCount = rule.failureCount + 1;
          updates['failureCount'] = newFailureCount;

          if (newFailureCount >= rule.maxFailures) {
            updates['status'] = AutoTopupStatus.suspended.toString().split('.').last;
          }
        }
      } else if (status == 'success') {
        // Reset failure count and schedule next execution
        updates['failureCount'] = 0;
        final rule = await getRule(ruleId);
        if (rule != null) {
          updates['nextScheduledAt'] = rule.getNextExecutionTime().toIso8601String();
        }
      }

      await _database.ref('auto_topup_rules/$ruleId').update(updates);

      _logService.log(
        LogLevel.info,
        'auto_topup.recordExecution',
        'Execution recorded',
        context: {
          'executionId': executionId,
          'ruleId': ruleId,
          'status': status,
        },
      );

      return execution;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.recordExecution',
        'Failed to record execution',
        context: {
          'ruleId': ruleId,
          'status': status,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get execution history for a user
  Future<List<AutoTopupExecution>> getExecutionHistory(
    String userId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _database
          .ref('auto_topup_executions')
          .orderByChild('userId')
          .equalTo(userId)
          .limitToLast(limit)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final executions = <AutoTopupExecution>[];
      final rawData = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in rawData.entries) {
        try {
          final executionData = Map<String, dynamic>.from(entry.value);
          executionData['id'] = entry.key;
          executions.add(AutoTopupExecution.fromJson(executionData));
        } catch (e) {
          _logService.log(
            LogLevel.warning,
            'auto_topup.getExecutionHistory',
            'Failed to parse execution',
            context: {
              'executionId': entry.key,
              'error': e.toString(),
            },
          );
        }
      }

      executions.sort((a, b) => b.executedAt.compareTo(a.executedAt));

      return executions;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'auto_topup.getExecutionHistory',
        'Failed to get execution history',
        context: {
          'userId': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Stream user's auto top-up rules
  Stream<List<AutoTopupRule>> watchUserRules(String userId) {
    final query = _database
        .ref('auto_topup_rules')
        .orderByChild('userId')
        .equalTo(userId);

    return query.onValue.map((event) {
      try {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <AutoTopupRule>[];
        }

        final rules = <AutoTopupRule>[];
        final rawData = event.snapshot.value as Map<dynamic, dynamic>;

        for (final entry in rawData.entries) {
          try {
            final ruleData = Map<String, dynamic>.from(entry.value);
            ruleData['id'] = entry.key;
            rules.add(AutoTopupRule.fromJson(ruleData));
          } catch (e) {
            _logService.log(
              LogLevel.warning,
              'auto_topup.watchUserRules',
              'Failed to parse rule in stream',
              context: {
                'ruleId': entry.key,
                'error': e.toString(),
              },
            );
          }
        }

        rules.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return rules;
      } catch (e) {
        _logService.log(
          LogLevel.error,
          'auto_topup.watchUserRules',
          'Failed to process rules stream',
          context: {
            'userId': userId,
            'error': e.toString(),
          },
        );
        return <AutoTopupRule>[];
      }
    });
  }

  /// Stream execution history for a user
  Stream<List<AutoTopupExecution>> watchExecutionHistory(String userId) {
    final query = _database
        .ref('auto_topup_executions')
        .orderByChild('userId')
        .equalTo(userId);

    return query.onValue.map((event) {
      try {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <AutoTopupExecution>[];
        }

        final executions = <AutoTopupExecution>[];
        final rawData = event.snapshot.value as Map<dynamic, dynamic>;

        for (final entry in rawData.entries) {
          try {
            final executionData = Map<String, dynamic>.from(entry.value);
            executionData['id'] = entry.key;
            executions.add(AutoTopupExecution.fromJson(executionData));
          } catch (e) {
            _logService.log(
              LogLevel.warning,
              'auto_topup.watchExecutionHistory',
              'Failed to parse execution in stream',
              context: {
                'executionId': entry.key,
                'error': e.toString(),
              },
            );
          }
        }

        executions.sort((a, b) => b.executedAt.compareTo(a.executedAt));
        return executions;
      } catch (e) {
        _logService.log(
          LogLevel.error,
          'auto_topup.watchExecutionHistory',
          'Failed to process executions stream',
          context: {
            'userId': userId,
            'error': e.toString(),
          },
        );
        return <AutoTopupExecution>[];
      }
    });
  }
}

