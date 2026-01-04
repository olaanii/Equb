import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/gateway_providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/ui/screens/transactions/tx_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const userId = 'user-123';

  List<TransactionModel> buildTransactions() {
    final now = DateTime.now();
    return [
      TransactionModel(
        id: 'tx1',
        fromUserId: userId,
        toUserId: 'wallet',
        amount: 500.0,
        status: TransactionStatus.success,
        gateway: 'telebirr',
        timestamp: now,
      ),
      TransactionModel(
        id: 'tx2',
        fromUserId: 'wallet',
        toUserId: userId,
        amount: 200.0,
        status: TransactionStatus.pending,
        gateway: 'bank_transfer',
        timestamp: now.subtract(const Duration(minutes: 5)),
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
        id: 'bank_transfer',
        name: 'Bank Transfer',
        enabled: true,
        environment: 'manual',
      ),
    ];
  }

  testWidgets('TxHistoryScreen displays transactions', (tester) async {
    final transactions = buildTransactions();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryProvider.overrideWithValue(
            AsyncValue.data(transactions),
          ),
          gatewayConfigsProvider.overrideWith(
            (ref) async => buildGatewayConfigs(),
          ),
        ],
        child: const MaterialApp(home: TxHistoryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Check Transactions listed
    expect(find.textContaining('Telebirr (Sandbox) •'), findsOneWidget);
    expect(find.textContaining('Bank Transfer (Manual) •'), findsOneWidget);

    // Check Summary Tiles
    expect(find.text('ETB 500.00'), findsOneWidget); // Successful total
    expect(find.text('ETB 200.00'), findsOneWidget); // Pending total
  });

  testWidgets('TxHistoryScreen filtering works', (tester) async {
    final transactions = buildTransactions();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionHistoryProvider.overrideWithValue(
            AsyncValue.data(transactions),
          ),
          gatewayConfigsProvider.overrideWith(
            (ref) async => buildGatewayConfigs(),
          ),
        ],
        child: const MaterialApp(home: TxHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Filter by 'Pending'
    await tester.tap(find.widgetWithText(FilterChip, 'Pending'));
    await tester.pumpAndSettle();

    // Should see Bank (Pending) but not Telebirr (Success)
    expect(find.textContaining('Bank Transfer (Manual) •'), findsOneWidget);
    expect(find.textContaining('Telebirr (Sandbox) •'), findsNothing);

    // Filter by Search
    await tester.tap(
      find.widgetWithText(FilterChip, 'Pending'),
    ); // Unselect Pending
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Telebirr');
    await tester.pumpAndSettle();

    expect(find.textContaining('Telebirr (Sandbox) •'), findsOneWidget);
    expect(find.textContaining('Bank Transfer (Manual) •'), findsNothing);
  });
}
