import 'dart:convert';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/services/system_log_service.dart';

class SessionCacheService {
  SessionCacheService({
    required SecureStorageService secureStorage,
    required SystemLogService logService,
  }) : _secureStorage = secureStorage,
       _logService = logService;

  static const _userCacheKey = 'cached_user_profile';
  static const _txCacheKey = 'cached_wallet_transactions';

  final SecureStorageService _secureStorage;
  final SystemLogService _logService;

  Future<void> cacheUser(UserModel user) async {
    try {
      await _secureStorage.write(_userCacheKey, jsonEncode(user.toJson()));
    } catch (err) {
      _logService.log(
        LogLevel.warning,
        'SessionCacheService',
        'Failed to cache user',
        context: {'error': '$err'},
      );
    }
  }

  Future<UserModel?> loadUser() async {
    try {
      final raw = await _secureStorage.read(_userCacheKey);
      if (raw == null) {
        return null;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(decoded);
    } catch (err) {
      _logService.log(
        LogLevel.warning,
        'SessionCacheService',
        'Failed to hydrate cached user, clearing corrupted entry',
        context: {'error': '$err'},
      );
      await _secureStorage.delete(_userCacheKey);
      return null;
    }
  }

  Future<void> cacheTransactions(List<TransactionModel> txs) async {
    try {
      final data = txs.map((e) => e.toJson()).toList();
      await _secureStorage.write(_txCacheKey, jsonEncode(data));
    } catch (err) {
      _logService.log(
        LogLevel.warning,
        'SessionCacheService',
        'Failed to cache transactions',
        context: {'error': '$err'},
      );
    }
  }

  Future<List<TransactionModel>> loadTransactions() async {
    try {
      final raw = await _secureStorage.read(_txCacheKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (err) {
      _logService.log(
        LogLevel.warning,
        'SessionCacheService',
        'Failed to hydrate cached transactions',
        context: {'error': '$err'},
      );
      return [];
    }
  }

  Future<void> clear() async {
    await _secureStorage.delete(_userCacheKey);
    await _secureStorage.delete(_txCacheKey);
  }
}
