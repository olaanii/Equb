import 'package:equb/models/equb_model.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/equb_service.dart';
import 'package:flutter/material.dart';

abstract class EqubRepository {
  Future<List<EqubGroup>> listGroups();
  Future<EqubGroup> createGroup(EqubGroup g, {String? actingUserId});
  Future<EqubGroup> updateGroup(EqubGroup g, {String? actingUserId});
  Future<void> deleteGroup(String groupId, {String? actingUserId});
  Future<EqubGroup?> findGroup(String groupId, {bool syncRotation});
  Future<EqubGroupMetrics> fetchGroupMetrics(String groupId);
  Future<List<EqubRoundSummary>> fetchRoundSummaries(String groupId);
  Future<EqubPayoutRecord?> triggerNextPayout(
    String groupId, {
    String? overrideMemberId,
    double? overrideAmount,
    bool ignoreContributionThreshold = false,
  });
  Future<TransactionModel> contribute({
    required String groupId,
    required String userId,
    required BuildContext context,
    String? screenshotUrl,
  });
}

class LocalEqubRepository implements EqubRepository {
  final EqubService service;

  LocalEqubRepository(this.service);

  @override
  Future<List<EqubGroup>> listGroups() async => service.listGroups();

  @override
  Future<EqubGroup> createGroup(EqubGroup g, {String? actingUserId}) async =>
      service.createGroup(g, actingUserId: actingUserId);

  @override
  Future<EqubGroup> updateGroup(EqubGroup g, {String? actingUserId}) async =>
      service.updateGroup(g, actingUserId: actingUserId);

  @override
  Future<void> deleteGroup(String groupId, {String? actingUserId}) async {
    await service.deleteGroup(groupId);
  }

  @override
  Future<EqubGroup?> findGroup(
    String groupId, {
    bool syncRotation = true,
  }) async => service.getGroup(groupId, syncRotation: syncRotation);

  @override
  Future<EqubGroupMetrics> fetchGroupMetrics(String groupId) async =>
      service.getGroupMetrics(groupId);

  @override
  Future<List<EqubRoundSummary>> fetchRoundSummaries(String groupId) async =>
      service.getRoundSummaries(groupId);

  @override
  Future<TransactionModel> contribute({
    required String groupId,
    required String userId,
    required BuildContext context,
    String? screenshotUrl,
  }) => service.contribute(groupId: groupId, userId: userId, context: context);

  @override
  Future<EqubPayoutRecord?> triggerNextPayout(
    String groupId, {
    String? overrideMemberId,
    double? overrideAmount,
    bool ignoreContributionThreshold = false,
  }) async => service.triggerNextPayout(
    groupId,
    overrideMemberId: overrideMemberId,
    overrideAmount: overrideAmount,
    ignoreContributionThreshold: ignoreContributionThreshold,
  );
}

// Removed SupabaseEqubRepository for frontend-only mode.
