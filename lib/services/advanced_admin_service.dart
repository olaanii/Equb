import 'package:cloud_functions/cloud_functions.dart';
import 'package:equb/models/admin_audit.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/id_document_repository.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/services/user_repository.dart';
import 'package:firebase_database/firebase_database.dart';

class AdvancedAdminService {
  AdvancedAdminService({
    required this.functions,
    required this.equbRepository,
    required this.userRepository,
    required this.idDocumentRepository,
    required this.logService,
  });

  final FirebaseFunctions functions;
  final EqubRepository equbRepository;
  final UserRepository userRepository;
  final IdDocumentRepository idDocumentRepository;
  final SystemLogService logService;

  /// Bulk user operations
  Future<BulkOperationResult> bulkUpdateUserRoles({
    required String adminId,
    required List<String> userIds,
    required UserRole newRole,
    required String reason,
  }) async {
    try {
      final operation = BulkOperation(
        id: 'bulk_role_update_${DateTime.now().millisecondsSinceEpoch}',
        adminId: adminId,
        operationType: 'update_user_roles',
        targetType: 'users',
        filters: {'userIds': userIds},
        actions: {
          'newRole': newRole.toString().split('.').last,
          'reason': reason,
        },
        status: 'pending',
        createdAt: DateTime.now(),
      );

      // Log the bulk operation start
      await _logAdminAction(
        adminId: adminId,
        action: AdminAction.bulkOperation,
        severity: AuditSeverity.medium,
        targetType: 'users',
        targetId: operation.id,
        targetName: 'Bulk Role Update',
        details: 'Updating roles for ${userIds.length} users to $newRole',
        metadata: {'operation': operation.toJson()},
      );

      // Process each user
      int successCount = 0;
      int failureCount = 0;
      final errors = <String>[];

      for (final userId in userIds) {
        try {
          await _updateUserRole(userId, newRole, adminId, reason);
          successCount++;

          await _logAdminAction(
            adminId: adminId,
            action: AdminAction.userRoleUpdate,
            severity: AuditSeverity.low,
            targetType: 'user',
            targetId: userId,
            details: 'Role updated to $newRole: $reason',
            metadata: {'newRole': newRole.toString(), 'reason': reason},
          );
        } catch (e) {
          failureCount++;
          errors.add('User $userId: $e');
          logService.log(
            LogLevel.error,
            'bulk_role_update',
            'Failed to update role for user $userId',
            context: {'error': e.toString()},
          );
        }
      }

      return BulkOperationResult(
        operationId: operation.id,
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'bulk_update_user_roles',
        'Bulk role update failed',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  Future<BulkOperationResult> bulkSuspendUsers({
    required String adminId,
    required List<String> userIds,
    required String reason,
    required DateTime? suspensionEnd,
  }) async {
    try {
      // Log bulk operation
      await _logAdminAction(
        adminId: adminId,
        action: AdminAction.bulkOperation,
        severity: AuditSeverity.high,
        targetType: 'users',
        targetId: 'bulk_suspend_${DateTime.now().millisecondsSinceEpoch}',
        targetName: 'Bulk User Suspension',
        details: 'Suspending ${userIds.length} users',
        metadata: {
          'reason': reason,
          'suspensionEnd': suspensionEnd?.toIso8601String(),
        },
      );

      int successCount = 0;
      int failureCount = 0;
      final errors = <String>[];

      for (final userId in userIds) {
        try {
          await _suspendUser(userId, reason, suspensionEnd, adminId);
          successCount++;

          await _logAdminAction(
            adminId: adminId,
            action: AdminAction.userSuspension,
            severity: AuditSeverity.medium,
            targetType: 'user',
            targetId: userId,
            details: 'User suspended: $reason',
            metadata: {
              'reason': reason,
              'suspensionEnd': suspensionEnd?.toIso8601String(),
            },
          );
        } catch (e) {
          failureCount++;
          errors.add('User $userId: $e');
        }
      }

      return BulkOperationResult(
        operationId: 'bulk_suspend_${DateTime.now().millisecondsSinceEpoch}',
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'bulk_suspend_users',
        'Bulk user suspension failed',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Advanced reporting
  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      // Get basic stats from Firebase Functions
      final callable = functions.httpsCallable('getAdminDashboardStats');
      final result = await callable.call();

      if (result.data['success'] == true) {
        return AdminDashboardStats.fromJson(result.data['stats']);
      }

      // Fallback: calculate basic stats locally
      return await _calculateBasicStats();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'get_dashboard_stats',
        'Failed to get dashboard stats',
        context: {'error': e.toString()},
      );
      return await _calculateBasicStats();
    }
  }

  Future<AdminDashboardStats> _calculateBasicStats() async {
    // Minimal, DB-derived fallback stats (no mock/demo numbers).
    final groups = await equbRepository.listGroups();
    final pendingDocs = await idDocumentRepository.getPendingDocuments();

    final memberIds = <String>{
      for (final g in groups) ...g.members,
    };

    var totalUsers = 0;
    var activeUsers = 0;
    var successfulTransactions = 0;

    try {
      final usersSnap = await FirebaseDatabase.instance.ref('users').get();
      final usersRaw = usersSnap.value;
      if (usersRaw is Map) {
        for (final entry in usersRaw.entries) {
          final userId = entry.key.toString();
          final value = entry.value;
          if (value is! Map) continue;

          totalUsers++;
          var isActive = memberIds.contains(userId);

          final data = Map<String, dynamic>.from(value);
          final walletBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0;
          final points = (data['points'] as int?) ?? 0;
          if (walletBalance > 0 || points > 0) {
            isActive = true;
          }

          final txRaw = data['transactions'];
          if (txRaw is Map && txRaw.isNotEmpty) {
            isActive = true;
            for (final txEntry in txRaw.entries) {
              final txValue = txEntry.value;
              if (txValue is! Map) continue;
              final tx = Map<String, dynamic>.from(txValue);

              final status = (tx['status']?.toString() ?? '').toLowerCase();
              final verificationStatus =
                  (tx['verificationStatus']?.toString() ?? '').toLowerCase();
              final isSuccess =
                  status == 'success' || verificationStatus == 'success';
              if (isSuccess) {
                successfulTransactions++;
              }
            }
          }

          if (isActive) {
            activeUsers++;
          }
        }
      }
    } catch (e) {
      // Keep fallback usable even if admin doesn't have permission to read
      // the full users tree; report via logs and return partial stats.
      logService.log(
        LogLevel.warning,
        'admin.basic_stats',
        'Failed to read users tree for dashboard fallback stats',
        context: {'error': e.toString()},
      );
    }

    final recentAlerts = <String>[];
    if (pendingDocs.isNotEmpty) {
      recentAlerts.add('${pendingDocs.length} pending verifications');
    }
    if (groups.isEmpty) {
      recentAlerts.add('No groups created yet');
    }
    if (successfulTransactions == 0) {
      recentAlerts.add('No successful transactions recorded yet');
    }

    // A simple availability signal (not a fabricated KPI): higher when there
    // are fewer pending items relative to user count.
    final denom = (totalUsers + pendingDocs.length).clamp(1, 1 << 30);
    final systemHealth =
        (1.0 - (pendingDocs.length / denom)).clamp(0.0, 1.0);

    return AdminDashboardStats(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      totalGroups: groups.length,
      activeGroups: groups.where((g) => g.members.length >= 3).length,
      totalTransactions: successfulTransactions,
      pendingVerifications: pendingDocs.length,
      systemHealth: systemHealth,
      recentAlerts: recentAlerts,
      generatedAt: DateTime.now(),
    );
  }

  Future<List<AdminAuditLog>> getAuditLogs({
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
    AdminAction? actionFilter,
    AuditSeverity? severityFilter,
  }) async {
    try {
      final callable = functions.httpsCallable('getAdminAuditLogs');
      final result = await callable.call({
        'limit': limit,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'actionFilter': actionFilter?.toString().split('.').last,
        'severityFilter': severityFilter?.toString().split('.').last,
      });

      if (result.data['success'] == true) {
        final logs = result.data['logs'] as List<dynamic>;
        return logs
            .map((log) => AdminAuditLog.fromJson(log as Map<String, dynamic>))
            .toList();
      }

      return [];
    } catch (e) {
      logService.log(
        LogLevel.error,
        'get_audit_logs',
        'Failed to get audit logs',
        context: {'error': e.toString()},
      );
      return [];
    }
  }

  Future<ComplianceReport> generateComplianceReport({
    required String adminId,
    required String reportType,
    required DateTime periodEnd,
  }) async {
    try {
      final callable = functions.httpsCallable('generateComplianceReport');
      final result = await callable.call({
        'adminId': adminId,
        'reportType': reportType,
        'periodEnd': periodEnd.toIso8601String(),
      });

      if (result.data['success'] == true) {
        return ComplianceReport.fromJson(result.data['report']);
      }

      throw Exception('Failed to generate compliance report');
    } catch (e) {
      logService.log(
        LogLevel.error,
        'generate_compliance_report',
        'Failed to generate compliance report',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// System maintenance
  Future<bool> performSystemMaintenance({
    required String adminId,
    required String maintenanceType,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _logAdminAction(
        adminId: adminId,
        action: AdminAction.systemConfigUpdate,
        severity: AuditSeverity.high,
        targetType: 'system',
        targetId: 'maintenance_$maintenanceType',
        targetName: 'System Maintenance',
        details: 'Performed $maintenanceType maintenance',
        metadata: parameters ?? const {},
      );

      // Call Firebase Function for maintenance
      final callable = functions.httpsCallable('performSystemMaintenance');
      final result = await callable.call({
        'adminId': adminId,
        'maintenanceType': maintenanceType,
        'parameters': parameters ?? {},
      });

      return result.data['success'] == true;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'system_maintenance',
        'System maintenance failed',
        context: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Emergency controls
  Future<bool> initiateEmergencyShutdown({
    required String adminId,
    required String reason,
  }) async {
    try {
      await _logAdminAction(
        adminId: adminId,
        action: AdminAction.emergencyShutdown,
        severity: AuditSeverity.critical,
        targetType: 'system',
        targetId: 'emergency_shutdown',
        targetName: 'Emergency Shutdown',
        details: 'Emergency system shutdown initiated: $reason',
        metadata: {
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final callable = functions.httpsCallable('emergencyShutdown');
      final result = await callable.call({
        'adminId': adminId,
        'reason': reason,
      });

      return result.data['success'] == true;
    } catch (e) {
      logService.log(
        LogLevel.critical,
        'emergency_shutdown',
        'Emergency shutdown failed',
        context: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Helper methods
  Future<void> _updateUserRole(
    String userId,
    UserRole newRole,
    String adminId,
    String reason,
  ) async {
    // This would call the existing admin function
    final callable = functions.httpsCallable('adminSetUserRole');
    await callable.call({
      'targetUserId': userId,
      'role': newRole.toString().split('.').last,
    });
  }

  Future<void> _suspendUser(
    String userId,
    String reason,
    DateTime? suspensionEnd,
    String adminId,
  ) async {
    // Mark user as suspended in database
    // This would require additional database schema
    logService.log(
      LogLevel.info,
      'suspend_user',
      'User suspension logic would be implemented here',
      context: {'userId': userId, 'reason': reason},
    );
  }

  Future<void> _logAdminAction({
    required String adminId,
    required AdminAction action,
    required AuditSeverity severity,
    required String targetType,
    required String targetId,
    String? targetName,
    required String details,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final callable = functions.httpsCallable('logAdminAction');
      await callable.call({
        'adminId': adminId,
        'action': action.toString().split('.').last,
        'severity': severity.toString().split('.').last,
        'targetType': targetType,
        'targetId': targetId,
        'targetName': targetName,
        'details': details,
        'metadata': metadata ?? {},
      });
    } catch (e) {
      // Log locally if Firebase function fails
      logService.log(
        LogLevel.warning,
        'admin_audit_log',
        'Failed to log admin action to Firebase',
        context: {
          'action': action.toString(),
          'adminId': adminId,
          'error': e.toString(),
        },
      );
    }
  }
}

class BulkOperationResult {
  const BulkOperationResult({
    required this.operationId,
    required this.successCount,
    required this.failureCount,
    required this.errors,
  });

  final String operationId;
  final int successCount;
  final int failureCount;
  final List<String> errors;

  int get totalCount => successCount + failureCount;
  double get successRate => totalCount > 0 ? successCount / totalCount : 0.0;

  bool get hasErrors => errors.isNotEmpty;
}
