import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/services/wallet_repository.dart';
import 'package:equb/utils/money_mathematics.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreWalletRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = FirestoreWalletRepository(firestore: fakeFirestore);
  });

  const userId = 'user-123';
  const initialBalance = 1000.0;

  Future<void> setupUser({double balance = 0.0}) async {
    await fakeFirestore.collection('users').doc(userId).set({
      'id': userId,
      'email': 'test@example.com',
      'name': 'Test User',
      'role': 'user',
      'walletBalance': balance,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  group('FirestoreWalletRepository', () {
    test('deposit increases balance and creates transaction', () async {
      await setupUser(balance: initialBalance);
      const depositAmount = 500.0;

      final expectedFee = MoneyMathematics.calculateFee(depositAmount);
      final expectedNet = depositAmount - expectedFee;

      await repository.deposit(userId, depositAmount, 'Telebirr');

      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(
        (userDoc.data()?['walletBalance'] as num?)?.toDouble(),
        closeTo(initialBalance + expectedNet, 1e-9),
      );

      final transactions = await fakeFirestore.collection('transactions').get();
      expect(transactions.docs.length, 1);
      final tx = transactions.docs.first.data();
      expect(tx['amount'], depositAmount);
      expect(tx['fromUserId'], userId);
      expect(tx['toUserId'], 'wallet');
      expect(tx['gateway'], 'Telebirr');
      expect(tx['status'], 'success');
    });

    test('withdraw decreases balance and creates transaction', () async {
      await setupUser(balance: initialBalance);
      const withdrawAmount = 200.0;

      final expectedFee = MoneyMathematics.calculateFee(withdrawAmount);

      await repository.withdraw(userId, withdrawAmount, 'Bank');

      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(
        (userDoc.data()?['walletBalance'] as num?)?.toDouble(),
        closeTo(initialBalance - withdrawAmount - expectedFee, 1e-9),
      );

      final transactions = await fakeFirestore.collection('transactions').get();
      expect(transactions.docs.length, 1);
      final tx = transactions.docs.first.data();
      expect(tx['amount'], withdrawAmount);
      expect(tx['fromUserId'], 'wallet');
      expect(tx['toUserId'], userId);
      expect(tx['gateway'], 'Bank');
      expect(tx['status'], 'success');
    });

    test('withdraw throws exception if insufficient funds', () async {
      await setupUser(balance: 100.0);
      const withdrawAmount = 200.0;

      expect(
        () => repository.withdraw(userId, withdrawAmount, 'Bank'),
        throwsException,
      );

      final userDoc = await fakeFirestore.collection('users').doc(userId).get();
      expect(userDoc.data()?['walletBalance'], 100.0); // Balance unchanged
    });

    test('getTransactions returns filtered list', () async {
      await setupUser();

      // Create some transactions
      // 1. User deposit (relevant)
      await fakeFirestore.collection('transactions').add({
        'id': 'tx1',
        'fromUserId': userId,
        'toUserId': 'wallet',
        'amount': 100.0,
        'status': 'success',
        'gateway': 'Telebirr',
        'timestamp': Timestamp.now(),
      });

      // 2. User withdrawal (relevant)
      await fakeFirestore.collection('transactions').add({
        'id': 'tx2',
        'fromUserId': 'wallet',
        'toUserId': userId,
        'amount': 50.0,
        'status': 'success',
        'gateway': 'Bank',
        'timestamp': Timestamp.now(),
      });

      // 3. Other user transaction (irrelevant)
      await fakeFirestore.collection('transactions').add({
        'id': 'tx3',
        'fromUserId': 'other-user',
        'toUserId': 'wallet',
        'amount': 300.0,
        'status': 'success',
        'gateway': 'Telebirr',
        'timestamp': Timestamp.now(),
      });

      final transactions = await repository.getTransactions(userId);

      expect(transactions.length, 2);
      expect(
        transactions.any((tx) => tx.id == 'tx1'),
        isTrue,
      ); // Note: ID might be auto-generated in real impl, but here we check count
      // Actually, in my impl I use doc ID as ID. But here I added manually.
      // The repository maps doc data to model.
      // Let's check amounts to be sure.
      expect(transactions.any((tx) => tx.amount == 100.0), isTrue);
      expect(transactions.any((tx) => tx.amount == 50.0), isTrue);
      expect(transactions.any((tx) => tx.amount == 300.0), isFalse);
    });
  });
}
