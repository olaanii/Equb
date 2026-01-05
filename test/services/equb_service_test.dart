import 'package:equb/models/equb_model.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/equb_service.dart';
import 'package:equb/services/firestore_equb_repository.dart';
import 'package:equb/services/payment_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopPaymentService implements PaymentService {
  @override
  Future<TransactionModel> createPayment({
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String gateway,
    required BuildContext context,
  }) {
    throw UnimplementedError('Not needed for these tests');
  }

  @override
  Future<TransactionModel> verifyPayment(String transactionId) {
    throw UnimplementedError('Not needed for these tests');
  }
}

void main() {
  group('EqubService (Firestore)', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreEqubRepository repository;
    late EqubService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirestoreEqubRepository(firestore: firestore);
      service = EqubService(repository: repository, paymentService: _NoopPaymentService());
    });

    test('createGroup persists group', () async {
      final group = EqubGroup(
        id: 'g1',
        name: 'Test Group',
        contributionAmount: 500,
        members: const ['u1'],
      );

      final created = await service.createGroup(group, actingUserId: 'u1');

      expect(created.id, 'g1');
      final stored = await repository.findGroup('g1', syncRotation: false);
      expect(stored, isNotNull);
      expect(stored!.name, 'Test Group');
      expect(stored.members, contains('u1'));
    });

    test('updateGroup updates existing group', () async {
      final group = EqubGroup(
        id: 'g1',
        name: 'Original Name',
        contributionAmount: 100,
        members: const ['u1'],
      );
      await service.createGroup(group, actingUserId: 'u1');

      final updated = group.copyWith(name: 'Updated Name', contributionAmount: 200);
      await service.updateGroup(updated, actingUserId: 'u1');

      final stored = await repository.findGroup('g1', syncRotation: false);
      expect(stored, isNotNull);
      expect(stored!.name, 'Updated Name');
      expect(stored.contributionAmount, 200);
    });

    test('deleteGroup removes group', () async {
      final group = EqubGroup(
        id: 'g1',
        name: 'To Delete',
        contributionAmount: 100,
        members: const ['u1'],
      );
      await service.createGroup(group, actingUserId: 'u1');

      await service.deleteGroup('g1');

      final stored = await repository.findGroup('g1', syncRotation: false);
      expect(stored, isNull);
    });
  });
}
