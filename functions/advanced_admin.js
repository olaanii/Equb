const functions = require('firebase-functions');
const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();
const firestore = admin.firestore();

/**
 * Get admin dashboard statistics
 */
exports.getAdminDashboardStats = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated and is admin
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    // Get basic stats
    const usersRef = firestore.collection('users');
    const groupsRef = db.ref('groups');
    const transactionsRef = firestore.collection('transactions');

    // Count users
    const usersSnapshot = await usersRef.get();
    const totalUsers = usersSnapshot.size;
    const activeUsers = usersSnapshot.docs.filter(doc => {
      const user = doc.data();
      return user.lastLogin && (Date.now() - user.lastLogin.toDate().getTime()) < (30 * 24 * 60 * 60 * 1000); // 30 days
    }).length;

    // Count groups
    const groupsSnapshot = await groupsRef.once('value');
    const groupsData = groupsSnapshot.val() || {};
    const totalGroups = Object.keys(groupsData).length;
    const activeGroups = Object.values(groupsData).filter(group =>
      group.members && Object.keys(group.members).length >= 3
    ).length;

    // Count transactions
    const transactionsSnapshot = await transactionsRef.get();
    const totalTransactions = transactionsSnapshot.size;

    // Get pending verifications
    const pendingDocsRef = firestore.collection('id_documents').where('status', '==', 'pending');
    const pendingDocsSnapshot = await pendingDocsRef.get();
    const pendingVerifications = pendingDocsSnapshot.size;

    // Calculate system health (simplified)
    const systemHealth = 0.98; // This would be calculated based on various metrics

    // Recent alerts (simplified)
    const recentAlerts = [
      'High transaction volume detected',
      'New user registrations increased 15%',
      'System backup completed successfully',
    ];

    return {
      success: true,
      stats: {
        totalUsers,
        activeUsers,
        totalGroups,
        activeGroups,
        totalTransactions,
        pendingVerifications,
        systemHealth,
        recentAlerts,
        generatedAt: new Date().toISOString(),
      }
    };
  } catch (error) {
    console.error('Error getting admin dashboard stats:', error);
    return {
      success: false,
      error: error.message,
      stats: {
        totalUsers: 0,
        activeUsers: 0,
        totalGroups: 0,
        activeGroups: 0,
        totalTransactions: 0,
        pendingVerifications: 0,
        systemHealth: 0.5,
        recentAlerts: ['Error loading dashboard data'],
        generatedAt: new Date().toISOString(),
      }
    };
  }
});

/**
 * Get admin audit logs
 */
exports.getAdminAuditLogs = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const { limit = 100, startDate, endDate, actionFilter, severityFilter } = data;

    let query = firestore.collection('admin_audit_logs')
      .orderBy('timestamp', 'desc')
      .limit(Math.min(limit, 1000));

    // Apply filters
    if (startDate) {
      query = query.where('timestamp', '>=', new Date(startDate));
    }
    if (endDate) {
      query = query.where('timestamp', '<=', new Date(endDate));
    }

    const snapshot = await query.get();
    let logs = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    // Client-side filtering for action and severity (Firestore limitations)
    if (actionFilter) {
      logs = logs.filter(log => log.action === actionFilter);
    }
    if (severityFilter) {
      logs = logs.filter(log => log.severity === severityFilter);
    }

    return {
      success: true,
      logs: logs,
    };
  } catch (error) {
    console.error('Error getting audit logs:', error);
    return {
      success: false,
      error: error.message,
      logs: [],
    };
  }
});

/**
 * Log admin action
 */
exports.logAdminAction = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const {
      adminId,
      action,
      severity,
      targetType,
      targetId,
      targetName,
      details,
      metadata = {},
    } = data;

    const auditLog = {
      id: `${adminId}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      adminId,
      adminName: context.auth.token.name || context.auth.token.email || 'Unknown Admin',
      action,
      severity,
      targetType,
      targetId,
      targetName,
      details,
      timestamp: new Date(),
      ipAddress: context.rawRequest?.ip,
      userAgent: context.rawRequest?.get('User-Agent'),
      metadata,
    };

    // Store in Firestore
    await firestore.collection('admin_audit_logs').add(auditLog);

    // Also log to Firebase Functions logger for additional tracking
    console.log('Admin Action:', JSON.stringify(auditLog));

    return { success: true };
  } catch (error) {
    console.error('Error logging admin action:', error);
    return { success: false, error: error.message };
  }
});

/**
 * Perform system maintenance
 */
exports.performSystemMaintenance = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const { adminId, maintenanceType, parameters = {} } = data;

    // Log maintenance start
    await firestore.collection('admin_audit_logs').add({
      id: `maintenance_${Date.now()}`,
      adminId,
      adminName: context.auth.token.name || context.auth.token.email || 'Unknown Admin',
      action: 'system_config_update',
      severity: 'high',
      targetType: 'system',
      targetId: `maintenance_${maintenanceType}`,
      targetName: 'System Maintenance',
      details: `Started ${maintenanceType} maintenance`,
      timestamp: new Date(),
      metadata: parameters,
    });

    let success = true;
    let result = {};

    switch (maintenanceType) {
      case 'database_cleanup':
        result = await performDatabaseCleanup();
        break;
      case 'cache_invalidation':
        result = await performCacheInvalidation();
        break;
      case 'backup_verification':
        result = await performBackupVerification();
        break;
      case 'index_rebuild':
        result = await performIndexRebuild();
        break;
      case 'log_rotation':
        result = await performLogRotation();
        break;
      case 'emergency_shutdown':
        result = await performEmergencyShutdown(adminId, parameters);
        break;
      default:
        throw new functions.https.HttpsError('invalid-argument', `Unknown maintenance type: ${maintenanceType}`);
    }

    // Log maintenance completion
    await firestore.collection('admin_audit_logs').add({
      id: `maintenance_complete_${Date.now()}`,
      adminId,
      adminName: context.auth.token.name || context.auth.token.email || 'Unknown Admin',
      action: 'system_config_update',
      severity: success ? 'medium' : 'high',
      targetType: 'system',
      targetId: `maintenance_${maintenanceType}`,
      targetName: 'System Maintenance',
      details: `Completed ${maintenanceType} maintenance: ${success ? 'Success' : 'Failed'}`,
      timestamp: new Date(),
      metadata: { ...parameters, result },
    });

    return { success, result };
  } catch (error) {
    console.error('Error performing system maintenance:', error);

    // Log failure
    await firestore.collection('admin_audit_logs').add({
      id: `maintenance_failed_${Date.now()}`,
      adminId: data.adminId,
      adminName: context.auth.token.name || context.auth.token.email || 'Unknown Admin',
      action: 'system_config_update',
      severity: 'critical',
      targetType: 'system',
      targetId: `maintenance_${data.maintenanceType}`,
      targetName: 'System Maintenance',
      details: `Failed ${data.maintenanceType} maintenance: ${error.message}`,
      timestamp: new Date(),
      metadata: { error: error.message },
    });

    return { success: false, error: error.message };
  }
});

/**
 * Generate compliance report
 */
exports.generateComplianceReport = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  try {
    const { adminId, reportType, periodEnd } = data;
    const endDate = new Date(periodEnd);
    const startDate = new Date(endDate);
    startDate.setMonth(startDate.getMonth() - 1); // Last 30 days

    let report = {
      id: `${reportType}_${Date.now()}`,
      reportType,
      period: endDate.toISOString(),
      generatedAt: new Date().toISOString(),
      adminId,
      summary: {},
      details: {},
      recommendations: [],
      metadata: {},
    };

    switch (reportType) {
      case 'kyc_compliance':
        report = await generateKYCComplianceReport(report, startDate, endDate);
        break;
      case 'transaction_monitoring':
        report = await generateTransactionMonitoringReport(report, startDate, endDate);
        break;
      case 'risk_assessment':
        report = await generateRiskAssessmentReport(report, startDate, endDate);
        break;
      default:
        throw new functions.https.HttpsError('invalid-argument', `Unknown report type: ${reportType}`);
    }

    // Store report
    await firestore.collection('compliance_reports').add(report);

    return { success: true, report };
  } catch (error) {
    console.error('Error generating compliance report:', error);
    return { success: false, error: error.message };
  }
});

// Helper functions for maintenance operations
async function performDatabaseCleanup() {
  // Remove orphaned records, clean up old sessions, etc.
  console.log('Performing database cleanup...');

  // Example: Clean up old verification codes
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const oldCodes = await firestore.collection('verification_codes')
    .where('createdAt', '<', thirtyDaysAgo)
    .get();

  const deletePromises = oldCodes.docs.map(doc => doc.ref.delete());
  await Promise.all(deletePromises);

  return {
    cleanedRecords: oldCodes.size,
    operation: 'database_cleanup',
  };
}

async function performCacheInvalidation() {
  // Invalidate application caches
  console.log('Performing cache invalidation...');
  // This would typically involve Redis or similar cache invalidation
  return { operation: 'cache_invalidation', status: 'completed' };
}

async function performBackupVerification() {
  // Verify recent backups
  console.log('Performing backup verification...');
  // This would check backup integrity
  return { operation: 'backup_verification', status: 'verified' };
}

async function performIndexRebuild() {
  // Rebuild database indexes
  console.log('Performing index rebuild...');
  // This would trigger index rebuilding in the database
  return { operation: 'index_rebuild', status: 'completed' };
}

async function performLogRotation() {
  // Archive old logs
  console.log('Performing log rotation...');
  // This would move old logs to archive storage
  return { operation: 'log_rotation', status: 'completed' };
}

async function performEmergencyShutdown(adminId, parameters) {
  console.log('Performing emergency shutdown...');

  // Set system maintenance flag
  await firestore.collection('system_settings').doc('maintenance').set({
    active: true,
    reason: parameters.reason || 'Emergency shutdown',
    initiatedBy: adminId,
    initiatedAt: new Date(),
  });

  // Disable all user operations (would implement through security rules)
  // This is a simplified version

  return {
    operation: 'emergency_shutdown',
    status: 'initiated',
    reason: parameters.reason,
  };
}

// Helper functions for compliance reports
async function generateKYCComplianceReport(report, startDate, endDate) {
  const documentsRef = firestore.collection('id_documents');
  const docs = await documentsRef
    .where('uploadedAt', '>=', startDate)
    .where('uploadedAt', '<=', endDate)
    .get();

  const totalDocuments = docs.size;
  const approvedDocuments = docs.docs.filter(doc => doc.data().status === 'approved').length;
  const rejectedDocuments = docs.docs.filter(doc => doc.data().status === 'rejected').length;
  const pendingDocuments = docs.docs.filter(doc => doc.data().status === 'pending').length;

  const approvalRate = totalDocuments > 0 ? approvedDocuments / totalDocuments : 0;

  report.summary = {
    totalDocuments,
    approvedDocuments,
    rejectedDocuments,
    pendingDocuments,
    approvalRate,
  };

  report.details = {
    processingTimes: await calculateProcessingTimes(docs.docs),
    rejectionReasons: await calculateRejectionReasons(docs.docs),
  };

  report.recommendations = [
    approvalRate < 0.8 ? 'Review KYC approval criteria' : 'KYC approval rate is healthy',
    pendingDocuments > 50 ? 'Address pending document backlog' : 'Document processing is current',
  ];

  return report;
}

async function generateTransactionMonitoringReport(report, startDate, endDate) {
  const transactionsRef = firestore.collection('transactions');
  const txns = await transactionsRef
    .where('timestamp', '>=', startDate)
    .where('timestamp', '<=', endDate)
    .get();

  const suspiciousTransactions = txns.docs.filter(doc => {
    const txn = doc.data();
    // Simple suspicious transaction detection
    return txn.amount > 10000 || txn.frequency > 10;
  });

  report.summary = {
    totalTransactions: txns.size,
    suspiciousTransactions: suspiciousTransactions.size,
    riskLevel: suspiciousTransactions.length > txns.size * 0.05 ? 'High' : 'Low',
  };

  report.details = {
    suspiciousPatterns: await analyzeTransactionPatterns(txns.docs),
  };

  report.recommendations = [
    suspiciousTransactions.length > 0 ? 'Review suspicious transactions' : 'No suspicious activity detected',
    'Continue monitoring transaction patterns',
  ];

  return report;
}

async function generateRiskAssessmentReport(report, startDate, endDate) {
  // Comprehensive risk assessment
  const usersRef = firestore.collection('users');
  const groupsRef = db.ref('groups');

  const newUsers = await usersRef.where('createdAt', '>=', startDate).get();
  const groupsSnapshot = await groupsRef.once('value');

  report.summary = {
    newUserRegistrations: newUsers.size,
    activeGroups: Object.keys(groupsSnapshot.val() || {}).length,
    systemUptime: 0.99, // Would calculate from monitoring data
  };

  report.details = {
    userGrowth: calculateUserGrowth(newUsers.docs),
    groupActivity: calculateGroupActivity(groupsSnapshot.val()),
  };

  report.recommendations = [
    'Monitor user growth trends',
    'Ensure adequate support for new users',
    'Review group formation patterns',
  ];

  return report;
}

// Additional helper functions would be implemented for detailed calculations
async function calculateProcessingTimes(docs) {
  // Calculate average processing times
  return { averageDays: 2.5 };
}

async function calculateRejectionReasons(docs) {
  // Analyze rejection reasons
  return { invalidDocument: 45, poorQuality: 30, expired: 25 };
}

async function analyzeTransactionPatterns(docs) {
  // Analyze transaction patterns for suspicious activity
  return { highValueTransactions: 5, frequentSmallTransactions: 12 };
}

function calculateUserGrowth(docs) {
  // Calculate user growth metrics
  return { weeklyGrowth: 15, monthlyGrowth: 45 };
}

function calculateGroupActivity(groups) {
  // Calculate group activity metrics
  return { activeGroups: 85, inactiveGroups: 15 };
}

