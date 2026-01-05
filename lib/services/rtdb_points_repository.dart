import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../models/points_event.dart';
import 'points_repository.dart';

class RtdbPointsRepository implements PointsRepository {
  RtdbPointsRepository(this._db);

  final FirebaseDatabase _db;

  DatabaseReference _ledgerRef(String userId) =>
      _db.ref('users/$userId/points_ledger');

  DatabaseReference _userRef(String userId) => _db.ref('users/$userId');

  @override
  Stream<List<PointsEvent>> watchPointsLedger(String userId) {
    return _ledgerRef(userId)
        .orderByChild('createdAtMs')
        .limitToLast(200)
        .onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <PointsEvent>[];

      final items = <PointsEvent>[];
      for (final entry in value.entries) {
        final key = entry.key?.toString();
        final raw = entry.value;
        if (key == null || raw is! Map) continue;

        final map = raw.cast<String, dynamic>();
        final createdAtMs = map['createdAtMs'];
        final createdAt =
            createdAtMs is int
                ? DateTime.fromMillisecondsSinceEpoch(createdAtMs)
                : DateTime.tryParse(map['createdAt']?.toString() ?? '');

        final delta = map['delta'];
        if (delta is! int) continue;

        items.add(
          PointsEvent(
            id: key,
            userId: userId,
            delta: delta,
            action: map['action']?.toString() ?? 'unknown',
            createdAt: createdAt,
            relatedTransactionId: map['relatedTransactionId']?.toString(),
            relatedGroupId: map['relatedGroupId']?.toString(),
            metadata: map['metadata'] is Map
                ? (map['metadata'] as Map).cast<String, dynamic>()
                : null,
          ),
        );
      }

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Future<void> awardPoints({
    required String userId,
    required int delta,
    required String action,
    String? relatedTransactionId,
    String? relatedGroupId,
    Map<String, dynamic>? metadata,
  }) async {
    if (delta == 0) return;

    final nowMs = ServerValue.timestamp;
    final ledgerKey = _ledgerRef(userId).push().key;
    if (ledgerKey == null) {
      throw StateError('Failed to create points_ledger key');
    }

    await _userRef(userId).runTransaction((currentData) {
      final data = (currentData as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

      final currentPoints = (data['points'] is int) ? data['points'] as int : 0;
      data['points'] = currentPoints + delta;

      final ledger = (data['points_ledger'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      ledger[ledgerKey] = <String, dynamic>{
        'delta': delta,
        'action': action,
        'createdAtMs': nowMs,
        if (relatedTransactionId != null)
          'relatedTransactionId': relatedTransactionId,
        if (relatedGroupId != null) 'relatedGroupId': relatedGroupId,
        if (metadata != null) 'metadata': metadata,
      };
      data['points_ledger'] = ledger;

      return Transaction.success(data);
    });
  }
}
