import 'package:equb/services/bank_settlement_worker.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BankSettlementWorker', () {
    test('settles aged bank transfer payouts', () async {
      final firestore = FakeFirebaseFirestore();
      final logService = SystemLogService();
      final worker = BankSettlementWorker(
        firestore: firestore,
        logService: logService,
        settlementDelay: const Duration(hours: 1),
      );

      final staleTimestamp =
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String();
      final freshTimestamp = DateTime.now().toIso8601String();

      await firestore.collection('transactions').doc('stale').set({
        'id': 'stale',
        'fromUserId': 'wallet',
        'toUserId': 'user',
        'amount': 100,
        'status': 'pending',
        'gateway': 'bank_transfer',
        'timestamp': staleTimestamp,
      });

      await firestore.collection('transactions').doc('fresh').set({
        'id': 'fresh',
        'fromUserId': 'wallet',
        'toUserId': 'user',
        'amount': 50,
        'status': 'pending',
        'gateway': 'bank_transfer',
        'timestamp': freshTimestamp,
      });

      final settled = await worker.reconcilePendingSettlements();
      expect(settled, 1);

      final staleDoc =
          await firestore.collection('transactions').doc('stale').get();
      expect(staleDoc['status'], 'success');
      expect(staleDoc['settlementTimestamp'], isNotNull);

      final freshDoc =
          await firestore.collection('transactions').doc('fresh').get();
      expect(freshDoc['status'], 'pending');

      expect(logService.list(level: LogLevel.info), isNotEmpty);
    });
  });
}
