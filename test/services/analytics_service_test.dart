import 'package:equb/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsService', () {
    test('records events and exposes counts', () async {
      var tick = 0;
      final service = AnalyticsService(
        clock: () {
          tick++;
          return DateTime.utc(2025, 1, 1, 0, 0, tick);
        },
      );

      await service.track(
        'auth_sign_in',
        userId: 'user-1',
        properties: {'method': 'email'},
      );
      await service.track(
        'wallet_deposit_success',
        userId: 'user-1',
        properties: {'amount': 25},
      );

      final events = service.recentEvents;
      expect(events.length, 2);
      expect(events.first.name, 'auth_sign_in');
      expect(events.last.properties['amount'], 25);

      final counts = service.eventCounts();
      expect(counts['auth_sign_in'], 1);
      expect(counts['wallet_deposit_success'], 1);

      service.dispose();
    });

    test('trims buffer when exceeding maxEvents', () async {
      final service = AnalyticsService(
        maxEvents: 2,
        clock: () => DateTime.utc(2025),
      );

      await service.track('event_a');
      await service.track('event_b');
      await service.track('event_c');

      final events = service.recentEvents;
      expect(events.length, 2);
      expect(events.first.name, 'event_b');
      expect(events.last.name, 'event_c');

      service.dispose();
    });

    test('trackDeposit helper emits structured event', () async {
      final destination = _TestDestination();
      final service = AnalyticsService(
        clock: () => DateTime.utc(2025, 6, 1),
        destinations: [destination],
      );

      await service.trackDeposit(
        userId: 'user-42',
        amount: 750,
        gateway: 'cbe_birr',
        transactionId: 'tx-xyz',
      );

      final event = destination.events.single;
      expect(event.name, 'wallet_deposit_success');
      expect(event.userId, 'user-42');
      expect(event.properties['gateway'], 'cbe_birr');
      expect(event.properties['transactionId'], 'tx-xyz');

      service.dispose();
    });
  });
}

class _TestDestination implements AnalyticsDestination {
  final events = <AnalyticsEvent>[];

  @override
  Future<void> send(AnalyticsEvent event) async {
    events.add(event);
  }
}
