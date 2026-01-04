import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/system_log_service.dart';

class BankSettlementWorker {
  BankSettlementWorker({
    FirebaseFirestore? firestore,
    SystemLogService? logService,
    Duration? settlementDelay,
    int batchSize = 25,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _logService = logService,
       _settlementDelay = settlementDelay ?? const Duration(hours: 2),
       _batchSize = batchSize;

  final FirebaseFirestore _firestore;
  final SystemLogService? _logService;
  final Duration _settlementDelay;
  final int _batchSize;

  /// Reconciles pending bank-transfer payouts that are older than the
  /// configured settlement delay. Returns the number of transactions updated.
  Future<int> reconcilePendingSettlements() async {
    final snapshot =
        await _firestore
            .collection('transactions')
            .where('gateway', isEqualTo: 'bank_transfer')
            .where('status', isEqualTo: TransactionStatus.pending.name)
            .limit(_batchSize)
            .get();

    if (snapshot.docs.isEmpty) {
      return 0;
    }

    final cutoff = DateTime.now().subtract(_settlementDelay);
    var updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final createdAtString = data['timestamp'] as String?;
      final createdAt =
          createdAtString == null
              ? DateTime.fromMillisecondsSinceEpoch(0)
              : DateTime.tryParse(createdAtString) ??
                  DateTime.fromMillisecondsSinceEpoch(0);

      if (createdAt.isAfter(cutoff)) {
        continue;
      }

      updated++;
      await doc.reference.update({
        'status': TransactionStatus.success.name,
        'settlementTimestamp': DateTime.now().toIso8601String(),
      });

      _logService?.log(
        LogLevel.info,
        'BankSettlementWorker',
        'Settled bank transfer ${doc.id}',
        context: {
          'transactionId': doc.id,
          'createdAt': createdAt.toIso8601String(),
        },
      );
    }

    return updated;
  }
}
