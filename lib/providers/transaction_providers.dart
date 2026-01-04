import 'package:equb/providers/providers.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';

final transactionHistoryProvider = StreamProvider<List<TransactionModel>>((
  ref,
) async* {
  final user = ref.watch(currentUserProvider).value;
  final sessionCache = ref.read(sessionCacheServiceProvider);
  final logService = ref.read(systemLogServiceProvider);

  // 1. Immediate cache load
  try {
    final cached = await sessionCache.loadTransactions();
    if (cached.isNotEmpty) {
      yield cached;
    }
  } catch (e) {
    // Fail silently on cache, we will try network next
  }

  if (user == null) return;

  // 2. Realtime Stream
  try {
    final repo = ref.watch(walletRepositoryProvider);
    yield* repo.getTransactionStream(user.id).map((transactions) {
      // Update cache with fresh data
      sessionCache.cacheTransactions(transactions);
      return transactions;
    });
  } catch (err) {
    logService.log(
      LogLevel.error,
      'wallet.transactionHistoryProvider',
      'Stream initialization failed',
      context: {'error': '$err'},
    );
    throw Exception('Failed to connect to transaction stream');
  }
});
