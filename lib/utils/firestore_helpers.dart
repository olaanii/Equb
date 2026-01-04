class FirestoreHelpers {
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    // Firestore Timestamp (when cloud_firestore is present) supports `toDate()`.
    // Avoid depending on the package by using duck-typing.
    try {
      final dynamic dyn = value;
      final DateTime? date = dyn.toDate?.call();
      if (date != null) return date;
    } catch (_) {}

    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    // Common serialized shapes
    if (value is Map) {
      final seconds = value['seconds'] ?? value['_seconds'];
      final nanos = value['nanoseconds'] ?? value['_nanoseconds'];
      if (seconds is int) {
        final ms = seconds * 1000 + ((nanos is int) ? (nanos ~/ 1000000) : 0);
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      final ms = value['millisecondsSinceEpoch'];
      if (ms is int) return DateTime.fromMillisecondsSinceEpoch(ms);
      final iso = value['iso'] ?? value['iso8601'] ?? value['date'];
      if (iso is String) return DateTime.tryParse(iso);
    }

    return null;
  }

  static DateTime parseDateTimeOrNow(dynamic value) {
    return parseDateTime(value) ?? DateTime.now();
  }
}
