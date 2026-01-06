import 'dart:convert';

import 'package:equb/services/system_log_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService({required this.logService});

  final SystemLogService logService;
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on this device
  Future<bool> isBiometricAvailable() async {
    try {
      if (kIsWeb) {
        return false;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      final isAvailable =
          (canCheckBiometrics || isDeviceSupported) &&
          availableBiometrics.isNotEmpty;

      logService.log(
        LogLevel.info,
        'biometric_check',
        'Biometric availability checked',
        context: {
          'available': isAvailable,
          'biometricTypes': availableBiometrics.map((e) => e.name).toList(),
        },
      );

      return isAvailable;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'biometric_check_failed',
        'Failed to check biometric availability',
        context: {'error': e.toString()},
      );
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      logService.log(
        LogLevel.error,
        'biometric_types_failed',
        'Failed to get available biometric types',
        context: {'error': e.toString()},
      );
      return [];
    }
  }

  /// Authenticate using biometrics
  Future<BiometricAuthResult> authenticate({
    String? reason,
    bool biometricOnly = false,
  }) async {
    try {
      if (kIsWeb) {
        return const BiometricAuthResult(
          success: false,
          error: 'Biometric authentication is not supported on web.',
        );
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason ?? 'Please authenticate to access your account',
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      final result = BiometricAuthResult(
        success: authenticated,
        error: authenticated ? null : 'Authentication failed or was cancelled',
      );

      logService.log(
        LogLevel.info,
        'biometric_auth_attempt',
        'Biometric authentication ${authenticated ? 'successful' : 'failed'}',
        context: {
          'success': authenticated,
          'biometricOnly': biometricOnly,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      );

      return result;
    } on PlatformException catch (e) {
      final errorMessage = _getErrorMessage(e.code);

      logService.log(
        LogLevel.warning,
        'biometric_auth_error',
        'Biometric authentication error',
        context: {
          'errorCode': e.code,
          'errorMessage': e.message,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        },
      );

      return BiometricAuthResult(
        success: false,
        error: errorMessage,
        platformError: e.code,
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'biometric_auth_unexpected_error',
        'Unexpected biometric authentication error',
        context: {'error': e.toString()},
      );

      return BiometricAuthResult(
        success: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  /// Check if biometric authentication is enabled for the current user
  Future<bool> isBiometricEnabled(String userId) async {
    // This would check user preferences stored securely
    // For now, return false as placeholder
    return false;
  }

  /// Enable biometric authentication for the current user
  Future<bool> enableBiometricAuth(String userId) async {
    try {
      // First verify the user can authenticate
      final authResult = await authenticate(
        reason: 'Enable biometric authentication for your account',
      );

      if (!authResult.success) {
        return false;
      }

      // Store biometric preference securely
      // This would update user preferences in database
      logService.log(
        LogLevel.info,
        'biometric_enabled',
        'Biometric authentication enabled for user',
        context: {'userId': userId},
      );

      return true;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'biometric_enable_failed',
        'Failed to enable biometric authentication',
        context: {'userId': userId, 'error': e.toString()},
      );
      return false;
    }
  }

  /// Disable biometric authentication for the current user
  Future<void> disableBiometricAuth(String userId) async {
    try {
      // Remove biometric preference
      logService.log(
        LogLevel.info,
        'biometric_disabled',
        'Biometric authentication disabled for user',
        context: {'userId': userId},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'biometric_disable_failed',
        'Failed to disable biometric authentication',
        context: {'userId': userId, 'error': e.toString()},
      );
    }
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device';
      case 'NotEnrolled':
        return 'No biometrics enrolled on this device. Please set up biometrics in your device settings';
      case 'LockedOut':
        return 'Biometric authentication is temporarily locked. Please try again later';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is permanently locked. Please use your device passcode';
      case 'OtherOperatingSystem':
        return 'Biometric authentication failed due to operating system error';
      case 'Cancelled':
        return 'Authentication was cancelled';
      default:
        return 'Biometric authentication failed. Please try again';
    }
  }
}

class BiometricAuthResult {
  const BiometricAuthResult({
    required this.success,
    this.error,
    this.platformError,
  });

  final bool success;
  final String? error;
  final String? platformError;

  bool get hasError => error != null;
}
