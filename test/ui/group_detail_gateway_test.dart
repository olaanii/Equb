import 'package:equb/domain/feature_flags.dart';
import 'package:equb/models/group.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/ui/screens/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingGatewayService extends GatewayService {
  _ThrowingGatewayService() : super();

  @override
  Future<PaymentService?> getAdapter(
    String gatewayId, {
    FeatureFlags? flags,
  }) async {
    throw GatewayCredentialException(
      message: 'Missing apiKey',
      gatewayId: gatewayId,
      field: 'apiKey',
    );
  }
}

void main() {
  testWidgets('shows actionable snackbar when Telebirr credentials missing', (
    tester,
  ) async {
    final group = Group(
      id: 'g1',
      name: 'Test Equb',
      contribution: 100,
      frequency: 'Weekly',
      members: const ['u1', 'u2'],
      nextPayout: DateTime.now().add(const Duration(days: 7)),
    );
    final user = UserModel(id: 'u1', name: 'Tester');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(user)),
          gatewayServiceProvider.overrideWithValue(_ThrowingGatewayService()),
        ],
        child: MaterialApp(home: GroupDetailScreen(group: group)),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Pay with Telebirr'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Telebirr credentials missing'), findsOneWidget);
  });
}
