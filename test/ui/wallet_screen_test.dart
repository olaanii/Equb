import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/gateway_providers.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/services/wallet_repository.dart';
import 'package:equb/ui/screens/wallet/wallet_screen.dart';
import 'package:equb/utils/money_mathematics.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equb/services/gateway_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FirestoreWalletRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = FirestoreWalletRepository(firestore: fakeFirestore);
  });

  const userId = 'user-123';
  final testUser = UserModel(
    id: userId,
    email: 'test@example.com',
    name: 'Test User',
    role: UserRole.user,
    walletBalance: 1500.0,
    createdAt: DateTime.now(),
  );

  Future<void> seedUserDocument({double balance = 1500.0}) async {
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

  List<TransactionModel> buildSampleTransactions() {
    return [
      TransactionModel(
        id: 'tx1',
        fromUserId: userId,
        toUserId: 'wallet',
        amount: 500.0,
        status: TransactionStatus.success,
        gateway: 'telebirr',
        timestamp: DateTime.now(),
      ),
      TransactionModel(
        id: 'tx2',
        fromUserId: 'wallet',
        toUserId: userId,
        amount: 200.0,
        status: TransactionStatus.pending,
        gateway: 'bank_transfer',
        timestamp: DateTime.now(),
      ),
    ];
  }

  List<PaymentGatewayConfig> buildGatewayConfigs() {
    return [
      PaymentGatewayConfig(
        id: 'telebirr',
        name: 'Telebirr',
        enabled: true,
        environment: 'sandbox',
      ),
      PaymentGatewayConfig(
        id: 'cbe_birr',
        name: 'CBE Birr',
        enabled: false,
        environment: 'mock',
      ),
    ];
  }

  testWidgets('WalletScreen displays balance and transactions', (tester) async {
    final sampleTransactions = buildSampleTransactions();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(repository),
          currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
          transactionHistoryProvider.overrideWithValue(
            AsyncValue.data(sampleTransactions),
          ),
          gatewayConfigsProvider.overrideWith(
            (ref) async => buildGatewayConfigs(),
          ),
        ],
        child: const MaterialApp(home: WalletScreen()),
      ),
    );

    // Allow streams to emit
    await tester.pump();
    await tester.pumpAndSettle();

    // Check Balance
    expect(find.text('ETB 1500.00'), findsOneWidget);

    // Check Transaction
    expect(find.textContaining('Telebirr \u2022 Sandbox'), findsOneWidget);
  });

  testWidgets('WalletScreen deposit flow works', (tester) async {
    await seedUserDocument();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletRepositoryProvider.overrideWithValue(repository),
          currentUserProvider.overrideWith((ref) => Stream.value(testUser)),
          transactionHistoryProvider.overrideWithValue(
            const AsyncValue.data(<TransactionModel>[]),
          ),
          gatewayConfigsProvider.overrideWith(
            (ref) async => buildGatewayConfigs(),
          ),
        ],
        child: const MaterialApp(home: WalletScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Deposit
    await tester.tap(find.text('Deposit funds'));
    await tester.pumpAndSettle();

    // Enter Amount
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.pump();

    // Confirm
    await tester.tap(find.text('Deposit now'));
    await tester.pumpAndSettle();

    // Verify Balance Updated in Firestore
    final userDoc = await fakeFirestore.collection('users').doc(userId).get();
    const depositAmount = 1000.0;
    final fee = MoneyMathematics.calculateFee(depositAmount);
    final expectedBalance = 1500.0 + (depositAmount - fee);
    expect(
      (userDoc.data()?['walletBalance'] as num?)?.toDouble(),
      closeTo(expectedBalance, 1e-9),
    );

    final txSnapshot = await fakeFirestore.collection('transactions').get();
    expect(txSnapshot.docs, hasLength(1));
    expect(txSnapshot.docs.first.data()['gateway'], 'telebirr');
  });
}
