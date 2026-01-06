import 'package:equb/models/group_analytics.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class GroupAnalyticsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupAnalyticsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupAnalyticsScreen> createState() => _GroupAnalyticsScreenState();
}

class _GroupAnalyticsScreenState extends ConsumerState<GroupAnalyticsScreen> {
  AnalyticsTimeframe _selectedTimeframe = AnalyticsTimeframe.month;

  @override
  Widget build(BuildContext context) {
    final analyticsAsync = ref.watch(
      FutureProvider((ref) async {
        final service = ref.watch(groupAnalyticsServiceProvider);
        return service.generateAnalytics(widget.groupId, timeframe: _selectedTimeframe);
      }),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Analytics'),
        actions: [
          PopupMenuButton<AnalyticsTimeframe>(
            onSelected: (timeframe) {
              setState(() => _selectedTimeframe = timeframe);
            },
            itemBuilder: (context) => AnalyticsTimeframe.values.map((timeframe) {
              return PopupMenuItem(
                value: timeframe,
                child: Text(timeframe.label),
              );
            }).toList(),
          ),
        ],
      ),
      body: analyticsAsync.when(
        data: (analytics) => _buildAnalyticsView(analytics),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load analytics'),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidateSelf(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsView(GroupAnalytics analytics) {
    return ListView(
      padding: AppSpacing.pagePaddingMobile,
      children: [
        // Health Score Card
        _HealthScoreCard(analytics: analytics),

        const SizedBox(height: 16),

        // Overview Cards
        _OverviewCards(analytics: analytics.overview),

        const SizedBox(height: 16),

        // Contribution Analytics
        _ContributionAnalytics(analytics: analytics.contributionMetrics),

        const SizedBox(height: 16),

        // Payout Analytics
        _PayoutAnalytics(analytics: analytics.payoutMetrics),

        const SizedBox(height: 16),

        // Member Analytics
        _MemberAnalytics(analytics: analytics.memberMetrics),

        const SizedBox(height: 16),

        // Risk Factors
        if (analytics.riskFactors.isNotEmpty)
          _RiskFactorsCard(riskFactors: analytics.riskFactors),

        const SizedBox(height: 16),

        // Trends
        _TrendsCard(trends: analytics.trends),
      ],
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.analytics});

  final GroupAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final healthScore = (analytics.healthScore * 100).round();
    final healthColor = _getHealthColor(analytics.healthScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Group Health Score',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: analytics.healthScore,
                    strokeWidth: 12,
                    backgroundColor: scheme.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$healthScore%',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: healthColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getHealthLabel(analytics.healthScore),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: healthColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Based on contribution rates, payout completion, and member activity',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getHealthColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _getHealthLabel(double score) {
    if (score >= 0.8) return 'Excellent';
    if (score >= 0.6) return 'Good';
    if (score >= 0.4) return 'Fair';
    return 'Needs Attention';
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({required this.analytics});

  final AnalyticsOverview analytics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: context.isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _OverviewCard(
          title: 'Total Members',
          value: '${analytics.totalMembers}',
          subtitle: '${analytics.activeMembers} active',
          icon: Icons.group,
          color: Colors.blue,
        ),
        _OverviewCard(
          title: 'Current Pot',
          value: 'ETB ${analytics.currentPot.toStringAsFixed(0)}',
          subtitle: '${analytics.contributionRate.toStringAsFixed(1)}x funded',
          icon: Icons.account_balance_wallet,
          color: Colors.green,
        ),
        _OverviewCard(
          title: 'Total Contributions',
          value: 'ETB ${analytics.totalContributions.toStringAsFixed(0)}',
          subtitle: '${analytics.averageContribution.toStringAsFixed(0)} avg',
          icon: Icons.trending_up,
          color: Colors.purple,
        ),
        _OverviewCard(
          title: 'Next Payout',
          value: analytics.nextPayoutDate != null
              ? DateFormat('MMM d').format(analytics.nextPayoutDate!)
              : 'N/A',
          subtitle: '${analytics.daysUntilNextPayout} days',
          icon: Icons.calendar_today,
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributionAnalytics extends StatelessWidget {
  const _ContributionAnalytics({required this.analytics});

  final ContributionMetrics analytics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contribution Analytics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Contribution rates
            Row(
              children: [
                Expanded(
                  child: _MetricItem(
                    label: 'On Time',
                    value: '${(analytics.onTimeRate * 100).round()}%',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricItem(
                    label: 'Late',
                    value: '${(analytics.lateRate * 100).round()}%',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricItem(
                    label: 'Missed',
                    value: '${(analytics.missedRate * 100).round()}%',
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contribution trend chart
            SizedBox(
              height: 200,
              child: LineChart(
                _buildContributionChart(),
              ),
            ),

            const SizedBox(height: 16),

            // Top contributors
            Text(
              'Top Contributors',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...analytics.topContributors.take(3).map((contributor) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16),
                    const SizedBox(width: 8),
                    Text(contributor.memberId),
                    const Spacer(),
                    Text('ETB ${contributor.amount.toStringAsFixed(0)}'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  LineChartData _buildContributionChart() {
    final spots = analytics.contributionTrend.asMap().entries.map((entry) {
      final point = entry.value;
      return FlSpot(entry.key.toDouble(), point.amount);
    }).toList();

    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
      ],
    );
  }
}

class _PayoutAnalytics extends StatelessWidget {
  const _PayoutAnalytics({required this.analytics});

  final PayoutMetrics analytics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payout Analytics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Payout stats
            Row(
              children: [
                Expanded(
                  child: _MetricItem(
                    label: 'Completed',
                    value: '${analytics.completedPayouts}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricItem(
                    label: 'Pending',
                    value: '${analytics.pendingPayouts}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricItem(
                    label: 'Failed',
                    value: '${analytics.failedPayouts}',
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Average payout
            Center(
              child: Text(
                'Average Payout: ETB ${analytics.averagePayoutAmount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            const SizedBox(height: 16),

            // Most frequent winners
            Text(
              'Most Frequent Winners',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...analytics.mostFrequentWinners.take(3).map((winner) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(winner.memberId),
                    const Spacer(),
                    Text('${winner.payoutCount} payouts'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _MemberAnalytics extends StatelessWidget {
  const _MemberAnalytics({required this.analytics});

  final MemberMetrics analytics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member Analytics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Member stats
            ...analytics.memberStats.take(5).map((member) {
              final activityLevel = analytics.activityLevels[member.memberId] ?? 0.0;
              final riskProfile = analytics.riskProfiles[member.memberId];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.memberId,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Contributed: ETB ${member.totalContributions.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: activityLevel > 0.7 ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        activityLevel > 0.7 ? 'Active' : 'Inactive',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: activityLevel > 0.7 ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RiskFactorsCard extends StatelessWidget {
  const _RiskFactorsCard({required this.riskFactors});

  final List<RiskFactor> riskFactors;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Risk Factors',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...riskFactors.map((factor) {
              final severityColor = factor.severity > 0.7 ? Colors.red : factor.severity > 0.5 ? Colors.orange : Colors.yellow;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: severityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            factor.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Impact: ${factor.impact}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Recommendation: ${factor.recommendation}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TrendsCard extends StatelessWidget {
  const _TrendsCard({required this.trends});

  final AnalyticsTrends trends;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trends & Predictions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            _TrendItem(
              label: 'Contribution Growth',
              value: '${(trends.contributionGrowth * 100).toStringAsFixed(1)}%',
              isPositive: trends.contributionGrowth >= 0,
            ),
            const SizedBox(height: 8),
            _TrendItem(
              label: 'Payout Growth',
              value: '${(trends.payoutGrowth * 100).toStringAsFixed(1)}%',
              isPositive: trends.payoutGrowth >= 0,
            ),
            const SizedBox(height: 8),
            _TrendItem(
              label: 'Member Retention',
              value: '${(trends.memberRetention * 100).toStringAsFixed(1)}%',
              isPositive: trends.memberRetention >= 0.8,
            ),

            if (trends.predictedNextPayout != null) ...[
              const SizedBox(height: 16),
              Text(
                'Predicted Next Payout: ${DateFormat('MMM d, yyyy').format(trends.predictedNextPayout!)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendItem extends StatelessWidget {
  const _TrendItem({
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final String label;
  final String value;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Row(
          children: [
            Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: isPositive ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: isPositive ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

