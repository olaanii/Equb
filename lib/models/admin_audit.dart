import 'package:meta/meta.dart';

enum AdminAction {
  userRoleUpdate,
  userSuspension,
  userDeletion,
  groupDeletion,
  payoutOverride,
  documentApproval,
  documentRejection,
  bulkOperation,
  systemConfigUpdate,
  emergencyShutdown,
}

enum AuditSeverity {
  low,
  medium,
  high,
  critical,
}

extension AdminActionX on AdminAction {
  String get label {
    switch (this) {
      case AdminAction.userRoleUpdate:
        return 'User Role Update';
      case AdminAction.userSuspension:
        return 'User Suspension';
      case AdminAction.userDeletion:
        return 'User Deletion';
      case AdminAction.groupDeletion:
        return 'Group Deletion';
      case AdminAction.payoutOverride:
        return 'Payout Override';
      case AdminAction.documentApproval:
        return 'Document Approval';
      case AdminAction.documentRejection:
        return 'Document Rejection';
      case AdminAction.bulkOperation:
        return 'Bulk Operation';
      case AdminAction.systemConfigUpdate:
        return 'System Config Update';
      case AdminAction.emergencyShutdown:
        return 'Emergency Shutdown';
    }
  }

  String get description {
    switch (this) {
      case AdminAction.userRoleUpdate:
        return 'Changed user role/permissions';
      case AdminAction.userSuspension:
        return 'Suspended user account';
      case AdminAction.userDeletion:
        return 'Deleted user account';
      case AdminAction.groupDeletion:
        return 'Deleted savings group';
      case AdminAction.payoutOverride:
        return 'Manually overrode payout process';
      case AdminAction.documentApproval:
        return 'Approved user verification document';
      case AdminAction.documentRejection:
        return 'Rejected user verification document';
      case AdminAction.bulkOperation:
        return 'Performed bulk administrative action';
      case AdminAction.systemConfigUpdate:
        return 'Updated system configuration';
      case AdminAction.emergencyShutdown:
        return 'Initiated emergency system shutdown';
    }
  }
}

@immutable
class AdminAuditLog {
  const AdminAuditLog({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.action,
    required this.severity,
    required this.targetType,
    required this.targetId,
    this.targetName,
    required this.details,
    required this.timestamp,
    this.ipAddress,
    this.userAgent,
    this.metadata = const {},
  });

  final String id;
  final String adminId;
  final String adminName;
  final AdminAction action;
  final AuditSeverity severity;
  final String targetType; // 'user', 'group', 'system', etc.
  final String targetId;
  final String? targetName;
  final String details;
  final DateTime timestamp;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> metadata;

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] as String,
      adminId: json['adminId'] as String,
      adminName: json['adminName'] as String,
      action: AdminAction.values.firstWhere(
        (e) => e.toString().split('.').last == json['action'],
      ),
      severity: AuditSeverity.values.firstWhere(
        (e) => e.toString().split('.').last == json['severity'],
        orElse: () => AuditSeverity.medium,
      ),
      targetType: json['targetType'] as String,
      targetId: json['targetId'] as String,
      targetName: json['targetName'] as String?,
      details: json['details'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adminId': adminId,
      'adminName': adminName,
      'action': action.toString().split('.').last,
      'severity': severity.toString().split('.').last,
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'metadata': metadata,
    };
  }
}

@immutable
class BulkOperation {
  const BulkOperation({
    required this.id,
    required this.adminId,
    required this.operationType,
    required this.targetType,
    required this.filters,
    required this.actions,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.results,
    this.errorMessage,
  });

  final String id;
  final String adminId;
  final String operationType; // 'update_users', 'suspend_users', 'send_notifications', etc.
  final String targetType; // 'users', 'groups', 'transactions', etc.
  final Map<String, dynamic> filters; // Criteria for selecting targets
  final Map<String, dynamic> actions; // Actions to perform
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? results;
  final String? errorMessage;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isProcessing => status == 'processing';

  factory BulkOperation.fromJson(Map<String, dynamic> json) {
    return BulkOperation(
      id: json['id'] as String,
      adminId: json['adminId'] as String,
      operationType: json['operationType'] as String,
      targetType: json['targetType'] as String,
      filters: json['filters'] as Map<String, dynamic>,
      actions: json['actions'] as Map<String, dynamic>,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      results: json['results'] as Map<String, dynamic>?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adminId': adminId,
      'operationType': operationType,
      'targetType': targetType,
      'filters': filters,
      'actions': actions,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'results': results,
      'errorMessage': errorMessage,
    };
  }
}

@immutable
class ComplianceReport {
  const ComplianceReport({
    required this.id,
    required this.reportType,
    required this.period,
    required this.generatedAt,
    required this.adminId,
    required this.summary,
    required this.details,
    required this.recommendations,
    this.metadata = const {},
  });

  final String id;
  final String reportType; // 'kyc_compliance', 'transaction_monitoring', 'risk_assessment', etc.
  final DateTime period; // Report period end date
  final DateTime generatedAt;
  final String adminId;
  final Map<String, dynamic> summary;
  final Map<String, dynamic> details;
  final List<String> recommendations;
  final Map<String, dynamic> metadata;

  factory ComplianceReport.fromJson(Map<String, dynamic> json) {
    return ComplianceReport(
      id: json['id'] as String,
      reportType: json['reportType'] as String,
      period: DateTime.parse(json['period'] as String),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      adminId: json['adminId'] as String,
      summary: json['summary'] as Map<String, dynamic>,
      details: json['details'] as Map<String, dynamic>,
      recommendations: List<String>.from(json['recommendations'] as List),
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportType': reportType,
      'period': period.toIso8601String(),
      'generatedAt': generatedAt.toIso8601String(),
      'adminId': adminId,
      'summary': summary,
      'details': details,
      'recommendations': recommendations,
      'metadata': metadata,
    };
  }
}

@immutable
class AdminDashboardStats {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalGroups,
    required this.activeGroups,
    required this.totalTransactions,
    required this.pendingVerifications,
    required this.systemHealth,
    required this.recentAlerts,
    required this.generatedAt,
  });

  final int totalUsers;
  final int activeUsers;
  final int totalGroups;
  final int activeGroups;
  final int totalTransactions;
  final int pendingVerifications;
  final double systemHealth; // 0.0-1.0
  final List<String> recentAlerts;
  final DateTime generatedAt;

  double get userActivityRate => totalUsers > 0 ? activeUsers / totalUsers : 0.0;
  double get groupActivityRate => totalGroups > 0 ? activeGroups / totalGroups : 0.0;

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalUsers: json['totalUsers'] as int,
      activeUsers: json['activeUsers'] as int,
      totalGroups: json['totalGroups'] as int,
      activeGroups: json['activeGroups'] as int,
      totalTransactions: json['totalTransactions'] as int,
      pendingVerifications: json['pendingVerifications'] as int,
      systemHealth: (json['systemHealth'] as num).toDouble(),
      recentAlerts: List<String>.from(json['recentAlerts'] as List),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'totalGroups': totalGroups,
      'activeGroups': activeGroups,
      'totalTransactions': totalTransactions,
      'pendingVerifications': pendingVerifications,
      'systemHealth': systemHealth,
      'recentAlerts': recentAlerts,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

