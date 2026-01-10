import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:equb/services/system_log_service.dart';

class DeviceManagementService {
  DeviceManagementService({required this.firestore, required this.logService});

  final FirebaseFirestore firestore;
  final SystemLogService logService;

  static const String _collection = 'user_devices';

  /// Register a new device for the user
  Future<DeviceInfo> registerDevice(String userId, String deviceName) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final deviceId = await _getDeviceId();

      final device = DeviceInfo(
        id: deviceId,
        userId: userId,
        name: deviceName,
        deviceModel: deviceInfo.model,
        platform: deviceInfo.platform,
        osVersion: deviceInfo.osVersion,
        appVersion: deviceInfo.appVersion,
        isTrusted: true, // New devices are trusted by default
        lastLoginAt: DateTime.now(),
        registeredAt: DateTime.now(),
        fcmToken: null, // Will be updated when FCM token is available
      );

      await firestore.collection(_collection).doc(deviceId).set({
        ...device.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'device_registered',
        'New device registered for user',
        context: {
          'userId': userId,
          'deviceId': deviceId,
          'deviceName': deviceName,
          'platform': deviceInfo.platform,
        },
      );

      return device;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'device_registration_failed',
        'Failed to register device',
        context: {'userId': userId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Get all devices for a user
  Future<List<DeviceInfo>> getUserDevices(String userId) async {
    try {
      final snapshot =
          await firestore
              .collection(_collection)
              .where('userId', isEqualTo: userId)
              .get();

      return snapshot.docs
          .map((doc) => DeviceInfo.fromJson(doc.data()))
          .toList();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'device_fetch_failed',
        'Failed to fetch user devices',
        context: {'userId': userId, 'error': e.toString()},
      );
      return [];
    }
  }

  /// Update device FCM token
  Future<void> updateDeviceFcmToken(String deviceId, String fcmToken) async {
    try {
      await firestore.collection(_collection).doc(deviceId).update({
        'fcmToken': fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.debug,
        'device_fcm_updated',
        'Device FCM token updated',
        context: {'deviceId': deviceId},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'device_fcm_update_failed',
        'Failed to update device FCM token',
        context: {'deviceId': deviceId, 'error': e.toString()},
      );
    }
  }

  /// Mark device as trusted
  Future<void> trustDevice(String deviceId, String trustedBy) async {
    try {
      await firestore.collection(_collection).doc(deviceId).update({
        'isTrusted': true,
        'trustedAt': FieldValue.serverTimestamp(),
        'trustedBy': trustedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'device_trusted',
        'Device marked as trusted',
        context: {'deviceId': deviceId, 'trustedBy': trustedBy},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'device_trust_failed',
        'Failed to trust device',
        context: {'deviceId': deviceId, 'error': e.toString()},
      );
    }
  }

  /// Revoke device trust
  Future<void> revokeDeviceTrust(String deviceId, String revokedBy) async {
    try {
      await firestore.collection(_collection).doc(deviceId).update({
        'isTrusted': false,
        'trustRevokedAt': FieldValue.serverTimestamp(),
        'trustRevokedBy': revokedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'device_trust_revoked',
        'Device trust revoked',
        context: {'deviceId': deviceId, 'revokedBy': revokedBy},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'device_trust_revoke_failed',
        'Failed to revoke device trust',
        context: {'deviceId': deviceId, 'error': e.toString()},
      );
    }
  }

  /// Remove a device
  Future<void> removeDevice(String deviceId, String removedBy) async {
    try {
      await firestore.collection(_collection).doc(deviceId).delete();

      logService.log(
        LogLevel.info,
        'device_removed',
        'Device removed',
        context: {'deviceId': deviceId, 'removedBy': removedBy},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'device_removal_failed',
        'Failed to remove device',
        context: {'deviceId': deviceId, 'error': e.toString()},
      );
    }
  }

  /// Update device last login time
  Future<void> updateLastLogin(String deviceId) async {
    try {
      await firestore.collection(_collection).doc(deviceId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail for login updates
      logService.log(
        LogLevel.warning,
        'device_login_update_failed',
        'Failed to update device last login',
        context: {'deviceId': deviceId, 'error': e.toString()},
      );
    }
  }

  /// Check if device is trusted
  Future<bool> isDeviceTrusted(String deviceId) async {
    try {
      final doc = await firestore.collection(_collection).doc(deviceId).get();

      if (!doc.exists) return false;

      final device = DeviceInfo.fromJson(doc.data()!);
      return device.isTrusted;
    } catch (e) {
      logService.log(
        LogLevel.warning,
        'device_trust_check_failed',
        'Failed to check device trust status',
        context: {'deviceId': deviceId, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Get device information for security alerts
  Future<DeviceInfo?> getDeviceInfo(String deviceId) async {
    try {
      final doc = await firestore.collection(_collection).doc(deviceId).get();

      if (!doc.exists) return null;

      return DeviceInfo.fromJson(doc.data()!);
    } catch (e) {
      logService.log(
        LogLevel.warning,
        'device_info_fetch_failed',
        'Failed to fetch device info',
        context: {'deviceId': deviceId, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Send security alert to all trusted devices
  Future<void> sendSecurityAlert(
    String userId,
    SecurityAlertType alertType,
    Map<String, dynamic> alertData,
  ) async {
    try {
      final devices = await getUserDevices(userId);
      final trustedDevices = devices.where(
        (device) => device.isTrusted && device.fcmToken != null,
      );

      if (trustedDevices.isEmpty) {
        logService.log(
          LogLevel.warning,
          'security_alert_no_devices',
          'No trusted devices with FCM tokens found for security alert',
          context: {'userId': userId, 'alertType': alertType.name},
        );
        return;
      }

      // This would integrate with push notification service
      // For now, just log the alert
      logService.log(
        LogLevel.info,
        'security_alert_sent',
        'Security alert sent to trusted devices',
        context: {
          'userId': userId,
          'alertType': alertType.name,
          'deviceCount': trustedDevices.length,
          'alertData': alertData,
        },
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'security_alert_failed',
        'Failed to send security alert',
        context: {
          'userId': userId,
          'alertType': alertType.name,
          'error': e.toString(),
        },
      );
    }
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios_device';
    } else {
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<DevicePlatformInfo> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return DevicePlatformInfo(
        platform: 'android',
        model: androidInfo.model,
        osVersion: 'Android ${androidInfo.version.release}',
        appVersion: '1.0.0', // Would get from package info
      );
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return DevicePlatformInfo(
        platform: 'ios',
        model: iosInfo.model,
        osVersion: 'iOS ${iosInfo.systemVersion}',
        appVersion: '1.0.0', // Would get from package info
      );
    } else {
      return DevicePlatformInfo(
        platform: 'unknown',
        model: 'Unknown Device',
        osVersion: 'Unknown OS',
        appVersion: '1.0.0',
      );
    }
  }
}

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.userId,
    required this.name,
    required this.deviceModel,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
    required this.isTrusted,
    required this.lastLoginAt,
    required this.registeredAt,
    this.fcmToken,
    this.trustedAt,
    this.trustRevokedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String deviceModel;
  final String platform;
  final String osVersion;
  final String appVersion;
  final bool isTrusted;
  final DateTime lastLoginAt;
  final DateTime registeredAt;
  final String? fcmToken;
  final DateTime? trustedAt;
  final DateTime? trustRevokedAt;

  bool get isCurrentSession =>
      DateTime.now().difference(lastLoginAt).inMinutes < 5;

  DeviceInfo copyWith({
    String? id,
    String? userId,
    String? name,
    String? deviceModel,
    String? platform,
    String? osVersion,
    String? appVersion,
    bool? isTrusted,
    DateTime? lastLoginAt,
    DateTime? registeredAt,
    String? fcmToken,
    DateTime? trustedAt,
    DateTime? trustRevokedAt,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      deviceModel: deviceModel ?? this.deviceModel,
      platform: platform ?? this.platform,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      isTrusted: isTrusted ?? this.isTrusted,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      registeredAt: registeredAt ?? this.registeredAt,
      fcmToken: fcmToken ?? this.fcmToken,
      trustedAt: trustedAt ?? this.trustedAt,
      trustRevokedAt: trustRevokedAt ?? this.trustRevokedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'deviceModel': deviceModel,
      'platform': platform,
      'osVersion': osVersion,
      'appVersion': appVersion,
      'isTrusted': isTrusted,
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'registeredAt': registeredAt.toIso8601String(),
      'fcmToken': fcmToken,
      'trustedAt': trustedAt?.toIso8601String(),
      'trustRevokedAt': trustRevokedAt?.toIso8601String(),
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      deviceModel: json['deviceModel'] as String,
      platform: json['platform'] as String,
      osVersion: json['osVersion'] as String,
      appVersion: json['appVersion'] as String,
      isTrusted: json['isTrusted'] as bool? ?? false,
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      fcmToken: json['fcmToken'] as String?,
      trustedAt:
          json['trustedAt'] != null
              ? DateTime.parse(json['trustedAt'] as String)
              : null,
      trustRevokedAt:
          json['trustRevokedAt'] != null
              ? DateTime.parse(json['trustRevokedAt'] as String)
              : null,
    );
  }
}

class DevicePlatformInfo {
  const DevicePlatformInfo({
    required this.platform,
    required this.model,
    required this.osVersion,
    required this.appVersion,
  });

  final String platform;
  final String model;
  final String osVersion;
  final String appVersion;
}

enum SecurityAlertType {
  newDeviceLogin,
  suspiciousActivity,
  passwordChanged,
  accountLocked,
  unusualLocation,
}
