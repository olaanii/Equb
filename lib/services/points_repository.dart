import '../models/points_event.dart';

abstract class PointsRepository {
  Stream<List<PointsEvent>> watchPointsLedger(String userId);

  Future<void> awardPoints({
    required String userId,
    required int delta,
    required String action,
    String? relatedTransactionId,
    String? relatedGroupId,
    Map<String, dynamic>? metadata,
  });
}
