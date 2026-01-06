import 'package:equb/models/equb_model.dart';
import 'package:equb/models/group_analytics.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/system_log_service.dart';

class GroupAnalyticsService {
  GroupAnalyticsService({
    required this.equbRepository,
    required this.logService,
  });

  final EqubRepository equbRepository;
  final SystemLogService logService;

  /// Generate comprehensive analytics for a group
  Future<GroupAnalytics> generateAnalytics(
    String groupId, {
    AnalyticsTimeframe timeframe = AnalyticsTimeframe.month,
  }) async {
    try {
      final group = await equbRepository.findGroup(groupId);
      if (group == null) {
        throw Exception('Group not found');
      }

      final cutoffDate = DateTime.now().subtract(timeframe.duration);

      // Generate all analytics components
      final overview = await _calculateOverview(group, cutoffDate);
      final contributionMetrics = await _calculateContributionMetrics(group, cutoffDate);
      final payoutMetrics = await _calculatePayoutMetrics(group, cutoffDate);
      final memberMetrics = await _calculateMemberMetrics(group, cutoffDate);
      final healthScore = _calculateHealthScore(
        contributionMetrics,
        payoutMetrics,
        memberMetrics,
      );
      final riskFactors = _assessRiskFactors(group, overview, contributionMetrics, memberMetrics);
      final trends = await _calculateTrends(group, timeframe);

      return GroupAnalytics(
        groupId: groupId,
        timeframe: timeframe,
        overview: overview,
        contributionMetrics: contributionMetrics,
        payoutMetrics: payoutMetrics,
        memberMetrics: memberMetrics,
        healthScore: healthScore,
        riskFactors: riskFactors,
        trends: trends,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'group_analytics.generateAnalytics',
        'Failed to generate analytics',
        context: {
          'groupId': groupId,
          'timeframe': timeframe.toString(),
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  Future<AnalyticsOverview> _calculateOverview(EqubGroup group, DateTime cutoffDate) async {
    final members = group.members;
    final history = group.rotationState.history
        .where((record) => record.processedAt != null && record.processedAt!.isAfter(cutoffDate))
        .toList();

    // Calculate active members (those who have contributed recently)
    final activeMembers = members.where((memberId) {
      final memberContributions = group.rotationState.contributionProgress[memberId] ?? 0.0;
      return memberContributions >= group.contributionAmount * 0.5; // At least half of required amount
    }).length;

    final totalContributions = history.length * group.contributionAmount;
    final totalPayouts = history.fold<double>(0, (sum, record) => sum + record.amount);
    final currentPot = (group.rotationState.contributionProgress.values
        .fold<double>(0, (sum, progress) => sum + progress));

    final averageContribution = members.isNotEmpty
        ? totalContributions / members.length
        : 0.0;

    final nextPayoutDate = group.rotationState.nextPayoutDate;
    final daysUntilNextPayout = nextPayoutDate != null
        ? nextPayoutDate.difference(DateTime.now()).inDays
        : 0;

    return AnalyticsOverview(
      totalMembers: members.length,
      activeMembers: activeMembers,
      totalContributions: totalContributions,
      totalPayouts: totalPayouts,
      currentPot: currentPot,
      averageContribution: averageContribution,
      nextPayoutDate: nextPayoutDate,
      daysUntilNextPayout: daysUntilNextPayout,
    );
  }

  Future<ContributionMetrics> _calculateContributionMetrics(
    EqubGroup group,
    DateTime cutoffDate,
  ) async {
    final history = group.rotationState.history
        .where((record) => record.processedAt != null && record.processedAt!.isAfter(cutoffDate))
        .toList();

    final totalContributions = history.length;
    final onTimeContributions = history
        .where((record) => record.scheduledFor.isAfter(record.processedAt!))
        .length;
    final lateContributions = totalContributions - onTimeContributions;
    final missedContributions = _calculateMissedContributions(group, cutoffDate);

    final averageContributionAmount = group.contributionAmount;

    // Calculate contribution trend (simplified - would need transaction history)
    final contributionTrend = _generateContributionTrend(group, cutoffDate);

    // Calculate top contributors
    final memberContributions = <String, double>{};
    for (final memberId in group.members) {
      memberContributions[memberId] = group.rotationState.contributionProgress[memberId] ?? 0.0;
    }

    final topContributors = memberContributions.entries
        .map((entry) => MemberContribution(
          memberId: entry.key,
          amount: entry.value,
          contributionCount: 1, // Simplified
          onTimeRate: 1.0, // Simplified
        ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount))
      ..take(5);

    return ContributionMetrics(
      totalContributions: totalContributions,
      onTimeContributions: onTimeContributions,
      lateContributions: lateContributions,
      missedContributions: missedContributions,
      averageContributionAmount: averageContributionAmount,
      contributionFrequency: group.scheduleConfig.cycle.label,
      contributionTrend: contributionTrend,
      topContributors: topContributors.toList(),
    );
  }

  Future<PayoutMetrics> _calculatePayoutMetrics(
    EqubGroup group,
    DateTime cutoffDate,
  ) async {
    final history = group.rotationState.history
        .where((record) => record.processedAt != null && record.processedAt!.isAfter(cutoffDate))
        .toList();

    final totalPayouts = history.length;
    final completedPayouts = history.length; // All records are processed
    final pendingPayouts = 0; // Simplified
    final failedPayouts = 0; // Simplified

    final averagePayoutAmount = history.isNotEmpty
        ? history.fold<double>(0, (sum, record) => sum + record.amount) / history.length
        : 0.0;

    // Calculate payout trend
    final payoutTrend = history.map((record) => PayoutDataPoint(
      date: record.processedAt!,
      amount: record.amount,
      recipientId: record.memberId,
      completed: true,
    )).toList();

    // Calculate most frequent winners
    final winnerCounts = <String, int>{};
    for (final record in history) {
      winnerCounts[record.memberId] = (winnerCounts[record.memberId] ?? 0) + 1;
    }

    final mostFrequentWinners = winnerCounts.entries
        .map((entry) => MemberPayout(
          memberId: entry.key,
          payoutCount: entry.value,
          totalAmount: entry.value * group.contributionAmount * group.members.length,
          lastPayoutDate: history
              .where((record) => record.memberId == entry.key)
              .map((record) => record.processedAt!)
              .reduce((a, b) => a.isAfter(b) ? a : b),
        ))
        .toList()
      ..sort((a, b) => b.payoutCount.compareTo(a.payoutCount));

    return PayoutMetrics(
      totalPayouts: totalPayouts,
      completedPayouts: completedPayouts,
      pendingPayouts: pendingPayouts,
      failedPayouts: failedPayouts,
      averagePayoutAmount: averagePayoutAmount,
      payoutTrend: payoutTrend,
      mostFrequentWinners: mostFrequentWinners.take(5).toList(),
      payoutDistribution: winnerCounts,
    );
  }

  Future<MemberMetrics> _calculateMemberMetrics(
    EqubGroup group,
    DateTime cutoffDate,
  ) async {
    final memberStats = <MemberStats>[];
    final activityLevels = <String, double>{};
    final riskProfiles = <String, RiskProfile>{};

    for (final memberId in group.members) {
      final contributions = group.rotationState.contributionProgress[memberId] ?? 0.0;
      final payouts = group.rotationState.history
          .where((record) => record.memberId == memberId)
          .fold<double>(0, (sum, record) => sum + record.amount);

      final stats = MemberStats(
        memberId: memberId,
        totalContributions: contributions,
        totalPayouts: payouts,
        contributionStreak: 1, // Simplified
        lastActivityDate: DateTime.now().subtract(const Duration(days: 1)), // Simplified
        joinDate: DateTime.now().subtract(const Duration(days: 30)), // Simplified
      );

      memberStats.add(stats);

      // Calculate activity level (0.0-1.0)
      final activityLevel = contributions > 0 ? 1.0 : 0.0;
      activityLevels[memberId] = activityLevel;

      // Assess risk profile
      final riskProfile = _assessMemberRisk(memberId, group, stats);
      riskProfiles[memberId] = riskProfile;
    }

    return MemberMetrics(
      memberStats: memberStats,
      activityLevels: activityLevels,
      riskProfiles: riskProfiles,
    );
  }

  RiskProfile _assessMemberRisk(String memberId, EqubGroup group, MemberStats stats) {
    final factors = <RiskFactor>[];
    double riskScore = 0.0;

    // Check contribution consistency
    final expectedContributions = group.contributionAmount;
    final actualContributions = stats.totalContributions;
    if (actualContributions < expectedContributions * 0.8) {
      factors.add(const RiskFactor(
        type: 'low_contribution',
        severity: 0.7,
        description: 'Member has contributed less than 80% of expected amount',
        impact: 'May delay group payouts',
        recommendation: 'Contact member to encourage contributions',
      ));
      riskScore += 0.7;
    }

    // Check inactivity
    if (stats.daysSinceLastActivity > 7) {
      factors.add(RiskFactor(
        type: 'inactivity',
        severity: 0.5,
        description: 'Member has been inactive for ${stats.daysSinceLastActivity} days',
        impact: 'May affect group participation',
        recommendation: 'Send reminder notification',
      ));
      riskScore += 0.5;
    }

    // Normalize risk score
    riskScore = riskScore.clamp(0.0, 1.0);

    return RiskProfile(
      overallRisk: riskScore,
      factors: factors,
      lastAssessment: DateTime.now(),
    );
  }

  double _calculateHealthScore(
    ContributionMetrics contributions,
    PayoutMetrics payouts,
    MemberMetrics members,
  ) {
    double score = 1.0;

    // Contribution health (40% weight)
    final contributionHealth = contributions.onTimeRate;
    score -= (1.0 - contributionHealth) * 0.4;

    // Payout health (30% weight)
    final payoutHealth = payouts.completionRate;
    score -= (1.0 - payoutHealth) * 0.3;

    // Member activity health (30% weight)
    final averageActivity = members.activityLevels.values.isNotEmpty
        ? members.activityLevels.values.reduce((a, b) => a + b) / members.activityLevels.length
        : 0.0;
    score -= (1.0 - averageActivity) * 0.3;

    return score.clamp(0.0, 1.0);
  }

  List<RiskFactor> _assessRiskFactors(
    EqubGroup group,
    AnalyticsOverview overview,
    ContributionMetrics contributions,
    MemberMetrics members,
  ) {
    final factors = <RiskFactor>[];

    // Group size risk
    if (overview.totalMembers < 3) {
      factors.add(const RiskFactor(
        type: 'small_group',
        severity: 0.8,
        description: 'Group has fewer than 3 members',
        impact: 'Higher risk of insufficient funds',
        recommendation: 'Recruit more members before starting contributions',
      ));
    }

    // Contribution rate risk
    if (contributions.onTimeRate < 0.7) {
      factors.add(RiskFactor(
        type: 'low_contribution_rate',
        severity: 0.6,
        description: 'Only ${(contributions.onTimeRate * 100).round()}% of contributions are on time',
        impact: 'May cause delays in payouts',
        recommendation: 'Implement stricter contribution deadlines',
      ));
    }

    // Inactive members risk
    final inactiveCount = members.activityLevels.values.where((level) => level < 0.5).length;
    if (inactiveCount > overview.totalMembers * 0.3) {
      factors.add(RiskFactor(
        type: 'inactive_members',
        severity: 0.5,
        description: '$inactiveCount members are inactive',
        impact: 'May affect group stability',
        recommendation: 'Contact inactive members and consider replacement',
      ));
    }

    return factors;
  }

  Future<AnalyticsTrends> _calculateTrends(
    EqubGroup group,
    AnalyticsTimeframe timeframe,
  ) async {
    // Simplified trend calculation - would need historical data
    final contributionGrowth = 0.05; // 5% growth (simplified)
    final payoutGrowth = 0.03; // 3% growth (simplified)
    final memberRetention = 0.95; // 95% retention (simplified)
    final predictedNextPayout = group.rotationState.nextPayoutDate;
    final riskTrend = -0.02; // Risk decreasing (simplified)

    return AnalyticsTrends(
      contributionGrowth: contributionGrowth,
      payoutGrowth: payoutGrowth,
      memberRetention: memberRetention,
      predictedNextPayout: predictedNextPayout,
      riskTrend: riskTrend,
    );
  }

  int _calculateMissedContributions(EqubGroup group, DateTime cutoffDate) {
    // Simplified calculation - would need transaction history
    return 0;
  }

  List<ContributionDataPoint> _generateContributionTrend(
    EqubGroup group,
    DateTime cutoffDate,
  ) {
    // Generate simplified trend data
    final trend = <ContributionDataPoint>[];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      trend.add(ContributionDataPoint(
        date: date,
        amount: group.contributionAmount * group.members.length * 0.8, // 80% collection rate
        expectedAmount: group.contributionAmount * group.members.length,
        onTime: true,
      ));
    }

    return trend;
  }
}

