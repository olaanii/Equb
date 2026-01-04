import 'package:equb/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsPersistenceQueue', () {
    test('enforces max records and drains deterministically', () {
      var now = DateTime.utc(2025, 1, 1);
      var id = 0;
      final queue = AnalyticsPersistenceQueue(
        maxRecords: 2,
        clock: () => now,
        idGenerator: () => 'rec_${id++}',
      );

      queue.enqueue(
        AnalyticsEvent(name: 'event_a', timestamp: now, properties: const {}),
      );
      now = now.add(const Duration(minutes: 5));
      queue.enqueue(
        AnalyticsEvent(name: 'event_b', timestamp: now, properties: const {}),
      );
      now = now.add(const Duration(minutes: 5));
      queue.enqueue(
        AnalyticsEvent(name: 'event_c', timestamp: now, properties: const {}),
      );

      final snapshot = queue.snapshot();
      expect(snapshot.length, 2);
      expect(snapshot.first.event.name, 'event_b');
      expect(snapshot.last.event.name, 'event_c');

      final drained = queue.drain();
      expect(drained.length, 2);
      expect(queue.snapshot(), isEmpty);
    });

    test('drops records outside retention window', () {
      var now = DateTime.utc(2025, 2, 1);
      final queue = AnalyticsPersistenceQueue(
        retention: const Duration(days: 2),
        clock: () => now,
        idGenerator: () => 'rec_${now.millisecondsSinceEpoch}',
      );

      queue.enqueue(
        AnalyticsEvent(name: 'retained', timestamp: now, properties: const {}),
      );
      now = now.add(const Duration(days: 3));

      expect(queue.snapshot(), isEmpty);
    });
  });

  group('AnalyticsService Supabase exports', () {
    test('tracks exports independent of recentEvents buffer', () async {
      var now = DateTime.utc(2025, 3, 1);
      final queue = AnalyticsPersistenceQueue(
        clock: () => now,
        idGenerator: () => 'rec_${now.microsecondsSinceEpoch}',
      );
      final service = AnalyticsService(
        maxEvents: 2,
        clock: () => now,
        destinations: [SupabaseAnalyticsDestination(queue: queue)],
      );

      for (var i = 0; i < 5; i++) {
        await service.track('event_$i');
        now = now.add(const Duration(minutes: 1));
      }

      expect(service.recentEvents.length, 2);
      expect(service.pendingSupabaseExports.length, 5);

      final drained = service.drainSupabaseExports();
      expect(drained.length, 5);
      expect(service.pendingSupabaseExports, isEmpty);

      service.dispose();
    });
  });
}
