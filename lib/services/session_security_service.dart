import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/services/device_management_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionSecurityService {
  SessionSecurityService({
    required this.firestore,
    required this.deviceService,
    required this.logService,
  });

  final FirebaseFirestore firestore;
  final DeviceManagementService deviceService;
  final SystemLogService logService;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'user_sessions';
  static const Duration _sessionTimeout = Duration(hours: 24); // 24 hours
  static const int _maxConcurrentSessions = 5; // Maximum concurrent sessions per user

  Timer? _sessionTimer;
  DateTime? _lastActivity;

  /// Initialize session monitoring
  void initializeSessionMonitoring(String userId) {
    _lastActivity = DateTime.now();

    // Start session timeout timer
    _startSessionTimer(userId);

    // Monitor user activity (this would be called from UI interactions)
    // For now, we'll use a periodic check
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (_shouldCheckSessionTimeout(userId)) {
        _checkSessionTimeout(userId);
      }
    });

    logService.log(
      LogLevel.info,
      'session_monitoring_started',
      'Session monitoring initialized',
      context: {'userId': userId},
    );
  }

  /// Record user activity to extend session
  void recordUserActivity(String userId) {
    _lastActivity = DateTime.now();

    // Reset session timer
    _startSessionTimer(userId);
  }

  /// Create a new session record
  Future<SessionInfo> createSession(String userId, String deviceId) async {
    try {
      final sessionId = '${userId}_${deviceId}_${DateTime.now().millisecondsSinceEpoch}';

      final session = SessionInfo(
        id: sessionId,
        userId: userId,
        deviceId: deviceId,
        startedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        isActive: true,
        ipAddress: null, // Would get from request
        userAgent: null, // Would get from request
      );

      await firestore.collection(_collection).doc(sessionId).set({
        ...session.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check concurrent session limits
      await _enforceSessionLimits(userId);

      logService.log(
        LogLevel.info,
        'session_created',
        'New session created',
        context: {
          'userId': userId,
          'deviceId': deviceId,
          'sessionId': sessionId,
        },
      );

      return session;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'session_creation_failed',
        'Failed to create session',
        context: {'userId': userId, 'deviceId': deviceId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Update session activity
  Future<void> updateSessionActivity(String sessionId) async {
    try {
      await firestore.collection(_collection).doc(sessionId).update({
        'lastActivityAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logService.log(
        LogLevel.warning,
        'session_activity_update_failed',
        'Failed to update session activity',
        context: {'sessionId': sessionId, 'error': e.toString()},
      );
    }
  }

  /// End a session
  Future<void> endSession(String sessionId, String endedBy) async {
    try {
      await firestore.collection(_collection).doc(sessionId).update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'endedBy': endedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'session_ended',
        'Session ended',
        context: {'sessionId': sessionId, 'endedBy': endedBy},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'session_end_failed',
        'Failed to end session',
        context: {'sessionId': sessionId, 'error': e.toString()},
      );
    }
  }

  /// End all sessions for a user (force logout everywhere)
  Future<void> endAllUserSessions(String userId, String endedBy) async {
    try {
      final sessions = await getActiveUserSessions(userId);

      for (final session in sessions) {
        await endSession(session.id, endedBy);
      }

      logService.log(
        LogLevel.warning,
        'all_sessions_ended',
        'All user sessions ended (force logout)',
        context: {'userId': userId, 'endedBy': endedBy, 'sessionCount': sessions.length},
      );

      // Send security alert
      await deviceService.sendSecurityAlert(
        userId,
        SecurityAlertType.suspiciousActivity,
        {
          'action': 'force_logout_all_devices',
          'endedBy': endedBy,
          'sessionCount': sessions.length,
        },
      );

    } catch (e) {
      logService.log(
        LogLevel.error,
        'bulk_session_end_failed',
        'Failed to end all user sessions',
        context: {'userId': userId, 'error': e.toString()},
      );
    }
  }

  /// Get active sessions for a user
  Future<List<SessionInfo>> getActiveUserSessions(String userId) async {
    try {
      final snapshot = await firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => SessionInfo.fromJson(doc.data()))
          .toList();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'active_sessions_fetch_failed',
        'Failed to fetch active user sessions',
        context: {'userId': userId, 'error': e.toString()},
      );
      return [];
    }
  }

  /// Check if session has timed out
  Future<bool> hasSessionTimedOut(String sessionId) async {
    try {
      final doc = await firestore.collection(_collection).doc(sessionId).get();

      if (!doc.exists) return true;

      final session = SessionInfo.fromJson(doc.data()!);

      if (!session.isActive) return true;

      final timeSinceActivity = DateTime.now().difference(session.lastActivityAt);
      return timeSinceActivity > _sessionTimeout;
    } catch (e) {
      logService.log(
        LogLevel.warning,
        'session_timeout_check_failed',
        'Failed to check session timeout',
        context: {'sessionId': sessionId, 'error': e.toString()},
      );
      return true; // Assume timed out on error
    }
  }

  /// Perform secure logout with session cleanup
  Future<void> secureLogout(String userId, String sessionId) async {
    try {
      // End the current session
      await endSession(sessionId, 'user_logout');

      // Update device last activity
      final sessionDoc = await firestore.collection(_collection).doc(sessionId).get();
      if (sessionDoc.exists) {
        final session = SessionInfo.fromJson(sessionDoc.data()!);
        await deviceService.updateLastLogin(session.deviceId);
      }

      logService.log(
        LogLevel.info,
        'secure_logout',
        'User logged out securely',
        context: {'userId': userId, 'sessionId': sessionId},
      );

    } catch (e) {
      logService.log(
        LogLevel.error,
        'secure_logout_failed',
        'Secure logout failed',
        context: {'userId': userId, 'sessionId': sessionId, 'error': e.toString()},
      );
    }
  }

  /// Check for suspicious session activity
  Future<void> checkForSuspiciousActivity(String userId, String currentDeviceId, String ipAddress) async {
    try {
      final activeSessions = await getActiveUserSessions(userId);
      final currentDeviceSessions = activeSessions.where((s) => s.deviceId == currentDeviceId);

      // Check for unusual number of concurrent sessions
      if (activeSessions.length > _maxConcurrentSessions) {
        logService.log(
          LogLevel.warning,
          'suspicious_sessions',
          'Unusual number of concurrent sessions detected',
          context: {
            'userId': userId,
            'sessionCount': activeSessions.length,
            'maxAllowed': _maxConcurrentSessions,
          },
        );

        // Send security alert
        await deviceService.sendSecurityAlert(
          userId,
          SecurityAlertType.suspiciousActivity,
          {
            'type': 'concurrent_sessions',
            'sessionCount': activeSessions.length,
            'maxAllowed': _maxConcurrentSessions,
          },
        );
      }

      // Check for sessions from different locations (simplified check)
      final otherSessions = activeSessions.where((s) => s.deviceId != currentDeviceId);
      if (otherSessions.isNotEmpty && currentDeviceSessions.isEmpty) {
        // First login from this device while others are active
        logService.log(
          LogLevel.info,
          'new_device_login',
          'Login from new device while others are active',
          context: {
            'userId': userId,
            'currentDeviceId': currentDeviceId,
            'activeSessions': otherSessions.length,
          },
        );

        // Send security alert to all trusted devices
        await deviceService.sendSecurityAlert(
          userId,
          SecurityAlertType.newDeviceLogin,
          {
            'deviceId': currentDeviceId,
            'ipAddress': ipAddress,
            'activeSessions': otherSessions.length,
          },
        );
      }

    } catch (e) {
      logService.log(
        LogLevel.error,
        'suspicious_activity_check_failed',
        'Failed to check for suspicious activity',
        context: {'userId': userId, 'error': e.toString()},
      );
    }
  }

  /// Clean up expired sessions
  Future<void> cleanupExpiredSessions() async {
    try {
      final cutoffTime = DateTime.now().subtract(_sessionTimeout);

      final expiredSessions = await firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .where('lastActivityAt', isLessThan: cutoffTime)
          .get();

      for (final doc in expiredSessions.docs) {
        await doc.reference.update({
          'isActive': false,
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': 'session_timeout',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (expiredSessions.size > 0) {
        logService.log(
          LogLevel.info,
          'expired_sessions_cleaned',
          'Expired sessions cleaned up',
          context: {'count': expiredSessions.size},
        );
      }

    } catch (e) {
      logService.log(
        LogLevel.error,
        'session_cleanup_failed',
        'Failed to cleanup expired sessions',
        context: {'error': e.toString()},
      );
    }
  }

  void _startSessionTimer(String userId) {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_sessionTimeout, () {
      _checkSessionTimeout(userId);
    });
  }

  bool _shouldCheckSessionTimeout(String userId) {
    if (_lastActivity == null) return false;
    final timeSinceActivity = DateTime.now().difference(_lastActivity!);
    return timeSinceActivity > _sessionTimeout;
  }

  Future<void> _checkSessionTimeout(String userId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser?.uid != userId) return; // Session no longer active for this user

      logService.log(
        LogLevel.warning,
        'session_timeout',
        'Session timed out due to inactivity',
        context: {'userId': userId},
      );

      // Force logout
      await _auth.signOut();

      // This would trigger UI to show login screen
      // In a real app, you'd have a global state management solution

    } catch (e) {
      logService.log(
        LogLevel.error,
        'session_timeout_handling_failed',
        'Failed to handle session timeout',
        context: {'userId': userId, 'error': e.toString()},
      );
    }
  }

  Future<void> _enforceSessionLimits(String userId) async {
    try {
      final activeSessions = await getActiveUserSessions(userId);

      if (activeSessions.length > _maxConcurrentSessions) {
        // End oldest sessions to stay within limit
        final sessionsToEnd = activeSessions.length - _maxConcurrentSessions;
        final sortedSessions = activeSessions
            .where((s) => s.lastActivityAt != null)
            .toList()
          ..sort((a, b) => a.lastActivityAt.compareTo(b.lastActivityAt));

        for (var i = 0; i < sessionsToEnd && i < sortedSessions.length; i++) {
          await endSession(sortedSessions[i].id, 'session_limit_enforcement');
        }

        logService.log(
          LogLevel.warning,
          'session_limit_enforced',
          'Session limit enforced by ending old sessions',
          context: {
            'userId': userId,
            'activeSessions': activeSessions.length,
            'maxAllowed': _maxConcurrentSessions,
            'endedCount': sessionsToEnd,
          },
        );
      }
    } catch (e) {
      logService.log(
        LogLevel.error,
        'session_limit_enforcement_failed',
        'Failed to enforce session limits',
        context: {'userId': userId, 'error': e.toString()},
      );
    }
  }

  /// Dispose resources
  void dispose() {
    _sessionTimer?.cancel();
  }
}

class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.startedAt,
    required this.lastActivityAt,
    required this.isActive,
    this.ipAddress,
    this.userAgent,
    this.endedAt,
  });

  final String id;
  final String userId;
  final String deviceId;
  final DateTime startedAt;
  final DateTime lastActivityAt;
  final bool isActive;
  final String? ipAddress;
  final String? userAgent;
  final DateTime? endedAt;

  Duration get duration => endedAt != null
      ? endedAt!.difference(startedAt)
      : DateTime.now().difference(startedAt);

  bool get isExpired {
    if (!isActive) return true;
    final timeSinceActivity = DateTime.now().difference(lastActivityAt);
    return timeSinceActivity > const Duration(hours: 24);
  }

  SessionInfo copyWith({
    String? id,
    String? userId,
    String? deviceId,
    DateTime? startedAt,
    DateTime? lastActivityAt,
    bool? isActive,
    String? ipAddress,
    String? userAgent,
    DateTime? endedAt,
  }) {
    return SessionInfo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      startedAt: startedAt ?? this.startedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isActive: isActive ?? this.isActive,
      ipAddress: ipAddress ?? this.ipAddress,
      userAgent: userAgent ?? this.userAgent,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'deviceId': deviceId,
      'startedAt': startedAt.toIso8601String(),
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'isActive': isActive,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'endedAt': endedAt?.toIso8601String(),
    };
  }

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      id: json['id'] as String,
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      lastActivityAt: DateTime.parse(json['lastActivityAt'] as String),
      isActive: json['isActive'] as bool? ?? false,
      ipAddress: json['ipAddress'] as String?,
      userAgent: json['userAgent'] as String?,
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
    );
  }
}

