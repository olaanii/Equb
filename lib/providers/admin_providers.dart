import 'package:cloud_functions/cloud_functions.dart';
import 'package:equb/models/transaction_model.dart';import 'package:equb/models/user_model.dart';import 'package:equb/providers/providers.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingDepositItem {
  final String id;
  final String userId;
  final String txId;
  final double amount;
  final double feeAmount;
  final double netAmount;
  final String gateway;
  final String? screenshotUrl;
  final int createdAtMs;
  final String status;

  const PendingDepositItem({
    required this.id,
    required this.userId,
    required this.txId,
    required this.amount,
    required this.feeAmount,
    required this.netAmount,
    required this.gateway,
    required this.screenshotUrl,
    required this.createdAtMs,
    required this.status,
  });

  factory PendingDepositItem.fromMap(Map<String, dynamic> map) {
    return PendingDepositItem(
      id: (map['id'] as String?)?.trim() ?? '',
      userId: (map['userId'] as String?)?.trim() ?? '',
      txId: (map['txId'] as String?)?.trim() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      feeAmount: (map['feeAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount: (map['netAmount'] as num?)?.toDouble() ?? 0.0,
      gateway: (map['gateway'] as String?)?.trim() ?? '',
      screenshotUrl: map['screenshotUrl'] as String?,
      createdAtMs: (map['createdAtMs'] as num?)?.toInt() ?? 0,
      status: (map['status'] as String?)?.trim() ?? 'pending',
    );
  }

  bool get isValid => userId.isNotEmpty && txId.isNotEmpty;
}

typedef PendingDepositKey = ({String userId, String txId});

final pendingDepositsProvider = FutureProvider<List<PendingDepositItem>>((ref) async {
  final callable = FirebaseFunctions.instance.httpsCallable('adminListPendingDeposits');
  final result = await callable.call(<String, dynamic>{'limit': 80});

  final data = result.data;
  if (data is! Map) return const <PendingDepositItem>[];
  final items = data['items'];
  if (items is! List) return const <PendingDepositItem>[];

  final out = <PendingDepositItem>[];
  for (final item in items) {
    if (item is! Map) continue;
    final mapped = PendingDepositItem.fromMap(Map<String, dynamic>.from(item));
    if (mapped.isValid) out.add(mapped);
  }

  out.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
  return out;
});

final adminDepositTransactionProvider = FutureProvider.family<TransactionModel?, PendingDepositKey>((ref, key) async {
  final snap = await FirebaseDatabase.instance
      .ref('users/${key.userId}/transactions/${key.txId}')
      .get();
  final raw = snap.value;
  if (raw == null || raw is! Map) return null;

  final map = Map<String, dynamic>.from(raw);
  map['id'] = map['id'] ?? key.txId;
  return TransactionModel.fromJson(map);
});

final isAdminProvider = StreamProvider<bool>((ref) {
  final auth = ref.watch(firebaseAuthUserProvider).asData?.value;
  final uid = auth?.uid;
  if (uid == null) {
    return Stream<bool>.value(false);
  }

  return FirebaseDatabase.instance
      .ref('admins/$uid')
      .onValue
      .map((event) => event.snapshot.value == true);
});

final isSuperAdminProvider = StreamProvider<bool>((ref) {
  final auth = ref.watch(firebaseAuthUserProvider).asData?.value;
  final uid = auth?.uid;
  if (uid == null) {
    return Stream<bool>.value(false);
  }

  return FirebaseDatabase.instance
      .ref('superadmins/$uid')
      .onValue
      .map((event) => event.snapshot.value == true);
});

/// Provider for all users (admin use only)
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.watchAllUsers();
});

/// Provider for paginated user fetching
final paginatedUsersProvider = FutureProvider.family<List<UserModel>, int?>((ref, limit) async {
  final userRepo = ref.watch(userRepositoryProvider);
  return userRepo.getAllUsers(limit: limit);
});
