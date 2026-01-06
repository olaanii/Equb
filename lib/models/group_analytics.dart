import 'package:meta/meta.dart';

enum AnalyticsTimeframe {
  week,
  month,
  quarter,
  year,
  allTime,
}

extension AnalyticsTimeframeX on AnalyticsTimeframe {
  String get label {
    switch (this) {
      case AnalyticsTimeframe.week:
        return 'This Week';
      case AnalyticsTimeframe.month:
        return 'This Month';
      case AnalyticsTimeframe.quarter:
        return 'This Quarter';
      case AnalyticsTimeframe.year:
        return 'This Year';
      case AnalyticsTimeframe.allTime:
        return 'All Time';
    }
  }

  Duration get duration {
    switch (this) {
      case AnalyticsTimeframe.week:
        return const Duration(days: 7);
      case AnalyticsTimeframe.month:
        return const Duration(days: 30);
      case AnalyticsTimeframe.quarter:
        return const Duration(days: 90);
      case AnalyticsTimeframe.year:
        return const Duration(days: 365);
      case AnalyticsTimeframe.allTime:
        return const Duration(days: 365 * 10); // 10 years
    }
  }
}

@immutable
class GroupAnalytics {
  const GroupAnalytics({
    required this.groupId,
    required this.timeframe,
    required this.overview,
    required this.contributionMetrics,
    required this.payoutMetrics,
    required this.memberMetrics,
    required this.healthScore,
    required this.riskFactors,
    required this.trends,
    required this.generatedAt,
  });

  final String groupId;
  final AnalyticsTimeframe timeframe;
  final AnalyticsOverview overview;
  final ContributionMetrics contributionMetrics;
  final PayoutMetrics payoutMetrics;
  final MemberMetrics memberMetrics;
  final double healthScore; // 0.0-1.0
  final List<RiskFactor> riskFactors;
  final AnalyticsTrends trends;
  final DateTime generatedAt;

  factory GroupAnalytics.fromJson(Map<String, dynamic> json) {
    return GroupAnalytics(
      groupId: json['groupId'] as String,
      timeframe: AnalyticsTimeframe.values.firstWhere(
        (e) => e.toString().split('.').last == json['timeframe'],
        orElse: () => AnalyticsTimeframe.month,
      ),
      overview: AnalyticsOverview.fromJson(json['overview'] as Map<String, dynamic>),
      contributionMetrics: ContributionMetrics.fromJson(json['contributionMetrics'] as Map<String, dynamic>),
      payoutMetrics: PayoutMetrics.fromJson(json['payoutMetrics'] as Map<String, dynamic>),
      memberMetrics: MemberMetrics.fromJson(json['memberMetrics'] as Map<String, dynamic>),
      healthScore: (json['healthScore'] as num).toDouble(),
      riskFactors: (json['riskFactors'] as List<dynamic>?)
          ?.map((e) => RiskFactor.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
      trends: AnalyticsTrends.fromJson(json['trends'] as Map<String, dynamic>),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'timeframe': timeframe.toString().split('.').last,
      'overview': overview.toJson(),
      'contributionMetrics': contributionMetrics.toJson(),
      'payoutMetrics': payoutMetrics.toJson(),
      'memberMetrics': memberMetrics.toJson(),
      'healthScore': healthScore,
      'riskFactors': riskFactors.map((e) => e.toJson()).toList(),
      'trends': trends.toJson(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}

@immutable
class AnalyticsOverview {
  const AnalyticsOverview({
    required this.totalMembers,
    required this.activeMembers,
    required this.totalContributions,
    required this.totalPayouts,
    required this.currentPot,
    required this.averageContribution,
    required this.nextPayoutDate,
    required this.daysUntilNextPayout,
  });

  final int totalMembers;
  final int activeMembers;
  final double totalContributions;
  final double totalPayouts;
  final double currentPot;
  final double averageContribution;
  final DateTime? nextPayoutDate;
  final int daysUntilNextPayout;

  double get contributionRate => totalMembers > 0 ? activeMembers / totalMembers : 0.0;
  double get netPosition => totalContributions - totalPayouts;

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      totalMembers: json['totalMembers'] as int,
      activeMembers: json['activeMembers'] as int,
      totalContributions: (json['totalContributions'] as num).toDouble(),
      totalPayouts: (json['totalPayouts'] as num).toDouble(),
      currentPot: (json['currentPot'] as num).toDouble(),
      averageContribution: (json['averageContribution'] as num).toDouble(),
      nextPayoutDate: json['nextPayoutDate'] != null
          ? DateTime.parse(json['nextPayoutDate'] as String)
          : null,
      daysUntilNextPayout: json['daysUntilNextPayout'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalMembers': totalMembers,
      'activeMembers': activeMembers,
      'totalContributions': totalContributions,
      'totalPayouts': totalPayouts,
      'currentPot': currentPot,
      'averageContribution': averageContribution,
      'nextPayoutDate': nextPayoutDate?.toIso8601String(),
      'daysUntilNextPayout': daysUntilNextPayout,
    };
  }
}

@immutable
class ContributionMetrics {
  const ContributionMetrics({
    required this.totalContributions,
    required this.onTimeContributions,
    required this.lateContributions,
    required this.missedContributions,
    required this.averageContributionAmount,
    required this.contributionFrequency,
    required this.contributionTrend,
    required this.topContributors,
  });

  final int totalContributions;
  final int onTimeContributions;
  final int lateContributions;
  final int missedContributions;
  final double averageContributionAmount;
  final String contributionFrequency;
  final List<ContributionDataPoint> contributionTrend;
  final List<MemberContribution> topContributors;

  double get onTimeRate => totalContributions > 0 ? onTimeContributions / totalContributions : 0.0;
  double get lateRate => totalContributions > 0 ? lateContributions / totalContributions : 0.0;
  double get missedRate => totalContributions > 0 ? missedContributions / totalContributions : 0.0;

  factory ContributionMetrics.fromJson(Map<String, dynamic> json) {
    return ContributionMetrics(
      totalContributions: json['totalContributions'] as int,
      onTimeContributions: json['onTimeContributions'] as int,
      lateContributions: json['lateContributions'] as int,
      missedContributions: json['missedContributions'] as int,
      averageContributionAmount: (json['averageContributionAmount'] as num).toDouble(),
      contributionFrequency: json['contributionFrequency'] as String,
      contributionTrend: (json['contributionTrend'] as List<dynamic>)
          .map((e) => ContributionDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      topContributors: (json['topContributors'] as List<dynamic>)
          .map((e) => MemberContribution.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalContributions': totalContributions,
      'onTimeContributions': onTimeContributions,
      'lateContributions': lateContributions,
      'missedContributions': missedContributions,
      'averageContributionAmount': averageContributionAmount,
      'contributionFrequency': contributionFrequency,
      'contributionTrend': contributionTrend.map((e) => e.toJson()).toList(),
      'topContributors': topContributors.map((e) => e.toJson()).toList(),
    };
  }
}

@immutable
class PayoutMetrics {
  const PayoutMetrics({
    required this.totalPayouts,
    required this.completedPayouts,
    required this.pendingPayouts,
    required this.failedPayouts,
    required this.averagePayoutAmount,
    required this.payoutTrend,
    required this.mostFrequentWinners,
    required this.payoutDistribution,
  });

  final int totalPayouts;
  final int completedPayouts;
  final int pendingPayouts;
  final int failedPayouts;
  final double averagePayoutAmount;
  final List<PayoutDataPoint> payoutTrend;
  final List<MemberPayout> mostFrequentWinners;
  final Map<String, int> payoutDistribution; // memberId -> count

  double get completionRate => totalPayouts > 0 ? completedPayouts / totalPayouts : 0.0;

  factory PayoutMetrics.fromJson(Map<String, dynamic> json) {
    return PayoutMetrics(
      totalPayouts: json['totalPayouts'] as int,
      completedPayouts: json['completedPayouts'] as int,
      pendingPayouts: json['pendingPayouts'] as int,
      failedPayouts: json['failedPayouts'] as int,
      averagePayoutAmount: (json['averagePayoutAmount'] as num).toDouble(),
      payoutTrend: (json['payoutTrend'] as List<dynamic>)
          .map((e) => PayoutDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      mostFrequentWinners: (json['mostFrequentWinners'] as List<dynamic>)
          .map((e) => MemberPayout.fromJson(e as Map<String, dynamic>))
          .toList(),
      payoutDistribution: (json['payoutDistribution'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as int)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalPayouts': totalPayouts,
      'completedPayouts': completedPayouts,
      'pendingPayouts': pendingPayouts,
      'failedPayouts': failedPayouts,
      'averagePayoutAmount': averagePayoutAmount,
      'payoutTrend': payoutTrend.map((e) => e.toJson()).toList(),
      'mostFrequentWinners': mostFrequentWinners.map((e) => e.toJson()).toList(),
      'payoutDistribution': payoutDistribution,
    };
  }
}

@immutable
class MemberMetrics {
  const MemberMetrics({
    required this.memberStats,
    required this.activityLevels,
    required this.riskProfiles,
  });

  final List<MemberStats> memberStats;
  final Map<String, double> activityLevels; // memberId -> activity score
  final Map<String, RiskProfile> riskProfiles; // memberId -> risk profile

  factory MemberMetrics.fromJson(Map<String, dynamic> json) {
    return MemberMetrics(
      memberStats: (json['memberStats'] as List<dynamic>)
          .map((e) => MemberStats.fromJson(e as Map<String, dynamic>))
          .toList(),
      activityLevels: (json['activityLevels'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, (value as num).toDouble())),
      riskProfiles: (json['riskProfiles'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, RiskProfile.fromJson(value as Map<String, dynamic>))),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberStats': memberStats.map((e) => e.toJson()).toList(),
      'activityLevels': activityLevels,
      'riskProfiles': riskProfiles.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

@immutable
class MemberStats {
  const MemberStats({
    required this.memberId,
    required this.totalContributions,
    required this.totalPayouts,
    required this.contributionStreak,
    required this.lastActivityDate,
    required this.joinDate,
  });

  final String memberId;
  final double totalContributions;
  final double totalPayouts;
  final int contributionStreak;
  final DateTime lastActivityDate;
  final DateTime joinDate;

  int get daysSinceLastActivity => DateTime.now().difference(lastActivityDate).inDays;
  int get membershipDays => DateTime.now().difference(joinDate).inDays;

  factory MemberStats.fromJson(Map<String, dynamic> json) {
    return MemberStats(
      memberId: json['memberId'] as String,
      totalContributions: (json['totalContributions'] as num).toDouble(),
      totalPayouts: (json['totalPayouts'] as num).toDouble(),
      contributionStreak: json['contributionStreak'] as int,
      lastActivityDate: DateTime.parse(json['lastActivityDate'] as String),
      joinDate: DateTime.parse(json['joinDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'totalContributions': totalContributions,
      'totalPayouts': totalPayouts,
      'contributionStreak': contributionStreak,
      'lastActivityDate': lastActivityDate.toIso8601String(),
      'joinDate': joinDate.toIso8601String(),
    };
  }
}

@immutable
class MemberContribution {
  const MemberContribution({
    required this.memberId,
    required this.amount,
    required this.contributionCount,
    required this.onTimeRate,
  });

  final String memberId;
  final double amount;
  final int contributionCount;
  final double onTimeRate;

  factory MemberContribution.fromJson(Map<String, dynamic> json) {
    return MemberContribution(
      memberId: json['memberId'] as String,
      amount: (json['amount'] as num).toDouble(),
      contributionCount: json['contributionCount'] as int,
      onTimeRate: (json['onTimeRate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'amount': amount,
      'contributionCount': contributionCount,
      'onTimeRate': onTimeRate,
    };
  }
}

@immutable
class MemberPayout {
  const MemberPayout({
    required this.memberId,
    required this.payoutCount,
    required this.totalAmount,
    required this.lastPayoutDate,
  });

  final String memberId;
  final int payoutCount;
  final double totalAmount;
  final DateTime lastPayoutDate;

  factory MemberPayout.fromJson(Map<String, dynamic> json) {
    return MemberPayout(
      memberId: json['memberId'] as String,
      payoutCount: json['payoutCount'] as int,
      totalAmount: (json['totalAmount'] as num).toDouble(),
      lastPayoutDate: DateTime.parse(json['lastPayoutDate'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'payoutCount': payoutCount,
      'totalAmount': totalAmount,
      'lastPayoutDate': lastPayoutDate.toIso8601String(),
    };
  }
}

@immutable
class ContributionDataPoint {
  const ContributionDataPoint({
    required this.date,
    required this.amount,
    required this.expectedAmount,
    required this.onTime,
  });

  final DateTime date;
  final double amount;
  final double expectedAmount;
  final bool onTime;

  factory ContributionDataPoint.fromJson(Map<String, dynamic> json) {
    return ContributionDataPoint(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      expectedAmount: (json['expectedAmount'] as num).toDouble(),
      onTime: json['onTime'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'amount': amount,
      'expectedAmount': expectedAmount,
      'onTime': onTime,
    };
  }
}

@immutable
class PayoutDataPoint {
  const PayoutDataPoint({
    required this.date,
    required this.amount,
    required this.recipientId,
    required this.completed,
  });

  final DateTime date;
  final double amount;
  final String recipientId;
  final bool completed;

  factory PayoutDataPoint.fromJson(Map<String, dynamic> json) {
    return PayoutDataPoint(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      recipientId: json['recipientId'] as String,
      completed: json['completed'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'amount': amount,
      'recipientId': recipientId,
      'completed': completed,
    };
  }
}

@immutable
class RiskFactor {
  const RiskFactor({
    required this.type,
    required this.severity,
    required this.description,
    required this.impact,
    required this.recommendation,
  });

  final String type;
  final double severity; // 0.0-1.0
  final String description;
  final String impact;
  final String recommendation;

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      type: json['type'] as String,
      severity: (json['severity'] as num).toDouble(),
      description: json['description'] as String,
      impact: json['impact'] as String,
      recommendation: json['recommendation'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'severity': severity,
      'description': description,
      'impact': impact,
      'recommendation': recommendation,
    };
  }
}

@immutable
class RiskProfile {
  const RiskProfile({
    required this.overallRisk,
    required this.factors,
    required this.lastAssessment,
  });

  final double overallRisk; // 0.0-1.0
  final List<RiskFactor> factors;
  final DateTime lastAssessment;

  factory RiskProfile.fromJson(Map<String, dynamic> json) {
    return RiskProfile(
      overallRisk: (json['overallRisk'] as num).toDouble(),
      factors: (json['factors'] as List<dynamic>)
          .map((e) => RiskFactor.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastAssessment: DateTime.parse(json['lastAssessment'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overallRisk': overallRisk,
      'factors': factors.map((e) => e.toJson()).toList(),
      'lastAssessment': lastAssessment.toIso8601String(),
    };
  }
}

@immutable
class AnalyticsTrends {
  const AnalyticsTrends({
    required this.contributionGrowth,
    required this.payoutGrowth,
    required this.memberRetention,
    required this.predictedNextPayout,
    required this.riskTrend,
  });

  final double contributionGrowth; // percentage change
  final double payoutGrowth; // percentage change
  final double memberRetention; // percentage
  final DateTime? predictedNextPayout;
  final double riskTrend; // risk change over time

  factory AnalyticsTrends.fromJson(Map<String, dynamic> json) {
    return AnalyticsTrends(
      contributionGrowth: (json['contributionGrowth'] as num).toDouble(),
      payoutGrowth: (json['payoutGrowth'] as num).toDouble(),
      memberRetention: (json['memberRetention'] as num).toDouble(),
      predictedNextPayout: json['predictedNextPayout'] != null
          ? DateTime.parse(json['predictedNextPayout'] as String)
          : null,
      riskTrend: (json['riskTrend'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contributionGrowth': contributionGrowth,
      'payoutGrowth': payoutGrowth,
      'memberRetention': memberRetention,
      'predictedNextPayout': predictedNextPayout?.toIso8601String(),
      'riskTrend': riskTrend,
    };
  }
}

