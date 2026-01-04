import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Firestore-dependent tests disabled (auth-only mode)', () {
    // Intentionally empty.
  });
}
  Future<TransactionModel> verifyPayment(String transactionId) async {
    return TransactionModel(
      id: transactionId,
      fromUserId: 'mock_user',
      toUserId: 'mock_target',
      amount: 100,
      status: TransactionStatus.success,
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  group('EqubService Integration Tests', () {
    late FakeFirebaseFirestore firestore;
    late FirestoreEqubRepository repository;
    late EqubService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = FirestoreEqubRepository(firestore: firestore);
      service = EqubService(
        repository: repository,
        paymentService: MockPaymentService(),
      );
    });

    test('createGroup creates a group and persists it', () async {
      final group = EqubGroup(
        id: 'g1',
        name: 'Test Group',
        contributionAmount: 500,
        members: ['u1'],
        scheduleConfig: EqubScheduleConfig(cycle: EqubCycle.monthly),
      );

      final created = await service.createGroup(group, actingUserId: 'u1');

      expect(created.id, 'g1');
      final stored = await repository.findGroup('g1');
      expect(stored, isNotNull);
      expect(stored!.name, 'Test Group');
      expect(stored.members, contains('u1'));
    });

    test('updateGroup updates existing group', () async {
      // Setup
      final group = EqubGroup(
        id: 'g1',
        name: 'Original Name',
        contributionAmount: 100,
        members: ['u1'],
      );
      await repository.createGroup(group);

      // Act
      final updated = group.copyWith(
        name: 'Updated Name',
        contributionAmount: 200,
      );
      await service.updateGroup(updated, actingUserId: 'u1');

      // Assert
      final stored = await repository.findGroup('g1');
      expect(stored!.name, 'Updated Name');
      expect(stored.contributionAmount, 200);
    });

    test('deleteGroup removes group', () async {
      // Setup
      final group = EqubGroup(
        id: 'g1',
        name: 'To Delete',
        contributionAmount: 100,
      );
      await repository.createGroup(group);

      // Act
      await service.deleteGroup('g1');

      // Assert
      final stored = await repository.findGroup('g1');
      expect(stored, isNull);
    });

    test('getGroup syncs rotation state (basic check)', () async {
      // Setup
      final group = EqubGroup(
        id: 'g1',
        name: 'Sync Test',
        contributionAmount: 100,
        members: ['u1', 'u2'],
        scheduleConfig: EqubScheduleConfig(
          cycle: EqubCycle.daily,
          startDate: DateTime.now().subtract(const Duration(days: 2)),
        ),
      );
      await repository.createGroup(group);

      // Act
      // getGroup calls repository.findGroup which calls rotationEngine.syncState
      final retrieved = await service.getGroup('g1');

      // Assert
      expect(retrieved, isNotNull);
      // syncState updates nextPayoutDate to be in the future
      expect(
        retrieved!.rotationState.nextPayoutDate.isAfter(DateTime.now()),
        isTrue,
      );
      // currentRound should not advance just by time passing if no payouts occurred
      expect(retrieved.rotationState.currentRound, 0);
    });
  });
}
