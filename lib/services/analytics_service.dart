import 'dart:async';

class AnalyticsEvent {
  AnalyticsEvent({
    required this.name,
    required this.timestamp,
    this.userId,
    Map<String, dynamic>? properties,
  }) : properties = Map.unmodifiable(properties ?? const {});

  final String name;
  final DateTime timestamp;
  final String? userId;
  final Map<String, dynamic> properties;
}

class AnalyticsExportRecord {
  const AnalyticsExportRecord({
    required this.id,
    required this.event,
    required this.enqueuedAt,
  });

  final String id;
  final AnalyticsEvent event;
  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': event.name,
      'timestamp': event.timestamp.toIso8601String(),
      'userId': event.userId,
      'properties': event.properties,
      'enqueuedAt': enqueuedAt.toIso8601String(),
    };
  }
}

class AnalyticsPersistenceQueue {
  AnalyticsPersistenceQueue({
    int maxRecords = 500,
    Duration? retention,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _retention = retention ?? const Duration(days: 30),
       _clock = clock ?? DateTime.now,
       _idGenerator = idGenerator ?? _defaultId,
       _maxRecords = maxRecords;

  final int _maxRecords;
  final Duration _retention;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final _records = <AnalyticsExportRecord>[];

  void enqueue(AnalyticsEvent event) {
    final record = AnalyticsExportRecord(
      id: _idGenerator(),
      event: event,
      enqueuedAt: _clock(),
    );
    _records.add(record);
    _trim();
  }

  List<AnalyticsExportRecord> snapshot() {
    _trim();
    return List.unmodifiable(_records);
  }

  List<AnalyticsExportRecord> drain() {
    _trim();
    final drained = List<AnalyticsExportRecord>.unmodifiable(_records);
    _records.clear();
    return drained;
  }

  void _trim() {
    final now = _clock();
    _records.removeWhere(
      (record) => now.difference(record.enqueuedAt) > _retention,
    );
    final overflow = _records.length - _maxRecords;
    if (overflow > 0) {
      _records.removeRange(0, overflow);
    }
  }

  static String _defaultId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}

abstract class AnalyticsDestination {
  Future<void> send(AnalyticsEvent event);
}

class SegmentAnalyticsDestination implements AnalyticsDestination {
  final List<AnalyticsEvent> _buffer = [];

  @override
  Future<void> send(AnalyticsEvent event) async {
    _buffer.add(event);
    if (_buffer.length > 100) {
      _buffer.removeAt(0);
    }
  }

  List<AnalyticsEvent> get buffer => List.unmodifiable(_buffer);
}

class SupabaseAnalyticsDestination implements AnalyticsDestination {
  final List<AnalyticsEvent> _buffer = [];
  final AnalyticsPersistenceQueue _queue;

  SupabaseAnalyticsDestination({AnalyticsPersistenceQueue? queue})
    : _queue = queue ?? AnalyticsPersistenceQueue();

  @override
  Future<void> send(AnalyticsEvent event) async {
    _buffer.add(event);
    if (_buffer.length > 100) {
      _buffer.removeAt(0);
    }
    _queue.enqueue(event);
  }

  List<AnalyticsEvent> get buffer => List.unmodifiable(_buffer);
  AnalyticsPersistenceQueue get queue => _queue;
}

class AnalyticsService {
  AnalyticsService({
    int maxEvents = 250,
    DateTime Function()? clock,
    List<AnalyticsDestination>? destinations,
  }) : _maxEvents = maxEvents,
       _clock = clock ?? DateTime.now,
       _destinations =
           destinations ??
           [SegmentAnalyticsDestination(), SupabaseAnalyticsDestination()];

  final int _maxEvents;
  final DateTime Function() _clock;
  final List<AnalyticsDestination> _destinations;
  final _events = <AnalyticsEvent>[];
  final _controller = StreamController<AnalyticsEvent>.broadcast();

  List<AnalyticsEvent> get recentEvents => List.unmodifiable(_events);
  Stream<AnalyticsEvent> get stream => _controller.stream;
  List<AnalyticsExportRecord> get pendingSupabaseExports {
    final destination = _findSupabaseDestination();
    if (destination == null) {
      return const <AnalyticsExportRecord>[];
    }
    return destination.queue.snapshot();
  }

  List<AnalyticsExportRecord> drainSupabaseExports() {
    final destination = _findSupabaseDestination();
    if (destination == null) {
      return const <AnalyticsExportRecord>[];
    }
    return destination.queue.drain();
  }

  SupabaseAnalyticsDestination? _findSupabaseDestination() {
    for (final destination in _destinations) {
      if (destination is SupabaseAnalyticsDestination) {
        return destination;
      }
    }
    return null;
  }

  Future<void> identify(String userId, {Map<String, dynamic>? traits}) async {
    await track('identify', userId: userId, properties: traits ?? const {});
  }

  Future<void> track(
    String name, {
    String? userId,
    Map<String, dynamic>? properties,
  }) async {
    final event = AnalyticsEvent(
      name: name,
      timestamp: _clock(),
      userId: userId,
      properties: properties,
    );
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
    _controller.add(event);
    await Future.wait(
      _destinations.map((destination) => destination.send(event)),
    );
  }

  Future<void> trackDeposit({
    required String userId,
    required double amount,
    required String gateway,
    String? transactionId,
  }) {
    return track(
      'wallet_deposit_success',
      userId: userId,
      properties: {
        'amount': amount,
        'gateway': gateway,
        if (transactionId != null) 'transactionId': transactionId,
      },
    );
  }

  Future<void> trackWithdrawal({
    required String userId,
    required double amount,
    required String destination,
    String? transactionId,
  }) {
    return track(
      'wallet_withdraw_success',
      userId: userId,
      properties: {
        'amount': amount,
        'destination': destination,
        if (transactionId != null) 'transactionId': transactionId,
      },
    );
  }

  Map<String, int> eventCounts() {
    final counts = <String, int>{};
    for (final event in _events) {
      counts[event.name] = (counts[event.name] ?? 0) + 1;
    }
    return counts;
  }

  void dispose() {
    _controller.close();
  }
}
