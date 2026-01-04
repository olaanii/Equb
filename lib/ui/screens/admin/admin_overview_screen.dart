import 'dart:math' as math;

import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminOverviewScreen extends StatelessWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _adminStats;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Overview')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                stats
                    .map(
                      (stat) =>
                          SizedBox(width: 240, child: _StatCard(stat: stat)),
                    )
                    .toList(),
          ),
          const SizedBox(height: 16),
          InfoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operational alerts', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                ..._alerts.map(
                  (alert) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(alert.icon, color: alert.color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                alert.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          alert.timeAgo,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equb performance snapshot',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _TrendChart(points: _weeklyContributionTrend),
                      ),
                      const SizedBox(height: 12),
                      _TrendLegend(points: _weeklyContributionTrend),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      _trendHighlights
                          .map(
                            (highlight) => _InsightPill(highlight: highlight),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openAnalyticsDetails(context),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open analytics dashboard'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // ignore: deprecated_member_use
          colors: [AppColors.surface, AppColors.surface.withOpacity(0.25)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: CustomPaint(
          painter: _TrendChartPainter(points: points, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.points});

  final List<_TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children:
          points
              .map(
                (point) => Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        point.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        point.prettyValue,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter({required this.points, required this.color});

  final List<_TrendPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final values = points.map((point) => point.value).toList();
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final range = math.max(maxValue - minValue, 1);

    final dx = size.width / (points.length - 1);
    const topPadding = 6.0;
    const bottomPadding = 6.0;

    final normalized = List<Offset>.generate(points.length, (index) {
      final value = points[index].value;
      final x = dx * index;
      final yFactor = (value - minValue) / range;
      final y =
          size.height -
          (yFactor * (size.height - topPadding - bottomPadding)) -
          bottomPadding;
      return Offset(x, y);
    });

    final fillPath = Path()..moveTo(0, size.height);
    for (final offset in normalized) {
      fillPath.lineTo(offset.dx, offset.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint =
        Paint()
          ..shader = LinearGradient(
            // ignore: deprecated_member_use
            colors: [color.withOpacity(0.18), color.withOpacity(0.02)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;

    final gridPaint =
        Paint()
          // ignore: deprecated_member_use
          ..color = AppColors.textSecondary.withOpacity(0.12)
          ..strokeWidth = 1;

    for (final ratio in [0.25, 0.5, 0.75]) {
      final y = size.height * ratio;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawPath(fillPath, fillPaint);

    final strokePath = Path()..moveTo(normalized.first.dx, normalized.first.dy);
    for (var i = 1; i < normalized.length; i++) {
      strokePath.lineTo(normalized[i].dx, normalized[i].dy);
    }
    canvas.drawPath(strokePath, strokePaint);

    final dotPaint =
        Paint()
          ..style = PaintingStyle.fill
          ..color = color;
    for (final point in normalized) {
      canvas.drawCircle(point, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({required this.highlight});

  final _TrendHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: highlight.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(32),
        // ignore: deprecated_member_use
        border: Border.all(color: highlight.color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(highlight.icon, size: 18, color: highlight.color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                highlight.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: highlight.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                highlight.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _openAnalyticsDetails(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final media = MediaQuery.of(sheetContext);
      return Padding(
        padding: media.viewInsets.add(
          EdgeInsets.symmetric(
            horizontal: media.size.width > 720 ? 32 : 24,
            vertical: 16,
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: media.size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 4,
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: AppColors.textSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Analytics drilldown', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Weekly contribution trend, cohort health, and gateway uptime all in one place. Export a CSV snapshot for finance or operations.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'Top cohorts by contribution',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._cohortBreakdown.map(
                        (cohort) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            // ignore: deprecated_member_use
                            backgroundColor: AppColors.primary.withOpacity(
                              0.12,
                            ),
                            child: Text(cohort.label[0]),
                          ),
                          title: Text(
                            cohort.label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${_formatCurrency(cohort.volume)} | ${cohort.members} members',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: Chip(
                            backgroundColor:
                                cohort.growth >= 0
                                    // ignore: deprecated_member_use
                                    ? AppColors.success.withOpacity(0.14)
                                    // ignore: deprecated_member_use
                                    : AppColors.error.withOpacity(0.14),
                            label: Text(
                              cohort.growth >= 0
                                  ? '+${(cohort.growth * 100).toStringAsFixed(1)}%'
                                  : '${(cohort.growth * 100).toStringAsFixed(1)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    cohort.growth >= 0
                                        ? AppColors.success
                                        : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Gateway performance (last 24h)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._gatewayPerformance.map(
                        (gateway) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            // ignore: deprecated_member_use
                            backgroundColor: AppColors.secondary.withOpacity(
                              0.12,
                            ),
                            child: Icon(Icons.hub, color: AppColors.secondary),
                          ),
                          title: Text(
                            gateway.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Success ${gateway.successRate.toStringAsFixed(1)}% | Avg latency ${gateway.avgLatencyMs} ms',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          trailing: Text(
                            '${gateway.transactions} tx',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Retention snapshots',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            _retentionMetrics
                                .map(
                                  (metric) => Container(
                                    width: 180,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      // ignore: deprecated_member_use
                                      color: AppColors.surface.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          metric.label,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          metric.value,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          metric.context,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: 'Export CSV snapshot',
                    icon: Icons.download_outlined,
                    onPressed: () => _exportAnalytics(sheetContext),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _exportAnalytics(BuildContext context) async {
  final buffer =
      StringBuffer()
        ..writeln('Cohort,Volume (ETB),Members,Growth')
        ..writeAll(
          _cohortBreakdown.map((cohort) {
            final growthPercent = (cohort.growth * 100).toStringAsFixed(1);
            return '${cohort.label},${cohort.volume.toStringAsFixed(2)},${cohort.members},$growthPercent%\n';
          }),
        )
        ..writeln()
        ..writeln('Gateway,Success Rate,Avg Latency (ms),Transactions')
        ..writeAll(
          _gatewayPerformance.map((gateway) {
            return '${gateway.name},${gateway.successRate.toStringAsFixed(1)}%,${gateway.avgLatencyMs},${gateway.transactions}\n';
          }),
        );

  await Clipboard.setData(ClipboardData(text: buffer.toString()));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Analytics snapshot copied to clipboard (CSV).'),
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _AdminStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: stat.color, size: 28),
          const SizedBox(height: 16),
          Text(
            stat.label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.trendLabel,
            style: theme.textTheme.labelSmall?.copyWith(color: stat.trendColor),
          ),
        ],
      ),
    );
  }
}

class _AdminStat {
  const _AdminStat({
    required this.label,
    required this.value,
    required this.trendLabel,
    required this.trendColor,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String trendLabel;
  final Color trendColor;
  final IconData icon;
  final Color color;
}

class _AdminAlert {
  const _AdminAlert({
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final String timeAgo;
  final IconData icon;
  final Color color;
}

class _TrendPoint {
  const _TrendPoint({required this.label, required this.value});

  final String label;
  final double value;

  String get prettyValue => _formatCurrency(value);
}

class _TrendHighlight {
  const _TrendHighlight({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _CohortBreakdown {
  const _CohortBreakdown({
    required this.label,
    required this.volume,
    required this.members,
    required this.growth,
  });

  final String label;
  final double volume;
  final int members;
  final double growth;
}

class _GatewayPerformance {
  const _GatewayPerformance({
    required this.name,
    required this.successRate,
    required this.avgLatencyMs,
    required this.transactions,
  });

  final String name;
  final double successRate;
  final int avgLatencyMs;
  final int transactions;
}

class _RetentionMetric {
  const _RetentionMetric({
    required this.label,
    required this.value,
    required this.context,
  });

  final String label;
  final String value;
  final String context;
}

const _adminStats = <_AdminStat>[
  _AdminStat(
    label: 'Total groups',
    value: '128',
    trendLabel: '+12% vs last month',
    trendColor: AppColors.success,
    icon: Icons.groups,
    color: AppColors.secondary,
  ),
  _AdminStat(
    label: 'Active members',
    value: '4,223',
    trendLabel: '+4.5% this week',
    trendColor: AppColors.success,
    icon: Icons.people_alt_outlined,
    color: AppColors.primary,
  ),
  _AdminStat(
    label: 'Monthly contributions',
    value: 'ETB 1.6M',
    trendLabel: '+9.3% vs last month',
    trendColor: AppColors.success,
    icon: Icons.account_balance_wallet_outlined,
    color: AppColors.success,
  ),
  _AdminStat(
    label: 'Open support tickets',
    value: '6',
    trendLabel: '2 resolved today',
    trendColor: AppColors.warning,
    icon: Icons.support_agent,
    color: AppColors.warning,
  ),
];

const _alerts = <_AdminAlert>[
  _AdminAlert(
    title: 'CBE Birr callbacks failing',
    message:
        'Received timeout on webhook endpoint. Check gateway configuration.',
    timeAgo: '5m ago',
    icon: Icons.warning_amber,
    color: AppColors.error,
  ),
  _AdminAlert(
    title: 'New admin invite pending',
    message: 'Wondimu Ayele has not accepted the invite sent yesterday.',
    timeAgo: '1h ago',
    icon: Icons.person_add_alt_1,
    color: AppColors.secondary,
  ),
  _AdminAlert(
    title: 'Large payout queued',
    message: 'ETB 45,000 payout waiting for approval in Group Sunrise.',
    timeAgo: '3h ago',
    icon: Icons.outbound,
    color: AppColors.primary,
  ),
];

const _weeklyContributionTrend = <_TrendPoint>[
  _TrendPoint(label: 'W1', value: 1120000),
  _TrendPoint(label: 'W2', value: 1245000),
  _TrendPoint(label: 'W3', value: 1390000),
  _TrendPoint(label: 'W4', value: 1615000),
];

const _trendHighlights = <_TrendHighlight>[
  _TrendHighlight(
    label: 'WoW growth',
    value: '+8.4%',
    icon: Icons.trending_up,
    color: AppColors.success,
  ),
  _TrendHighlight(
    label: 'Churned groups',
    value: '4 this month',
    icon: Icons.error_outline,
    color: AppColors.warning,
  ),
  _TrendHighlight(
    label: 'Avg. payout SLA',
    value: '3h 12m',
    icon: Icons.timer_outlined,
    color: AppColors.primary,
  ),
];

const _cohortBreakdown = <_CohortBreakdown>[
  _CohortBreakdown(
    label: 'Addis Ababa',
    volume: 640000,
    members: 870,
    growth: 0.12,
  ),
  _CohortBreakdown(label: 'Adama', volume: 215000, members: 310, growth: 0.08),
  _CohortBreakdown(
    label: 'Dire Dawa',
    volume: 186000,
    members: 255,
    growth: -0.03,
  ),
  _CohortBreakdown(
    label: 'Mekelle',
    volume: 154000,
    members: 188,
    growth: 0.05,
  ),
];

const _gatewayPerformance = <_GatewayPerformance>[
  _GatewayPerformance(
    name: 'Telebirr',
    successRate: 99.2,
    avgLatencyMs: 412,
    transactions: 1482,
  ),
  _GatewayPerformance(
    name: 'CBE Birr',
    successRate: 96.8,
    avgLatencyMs: 655,
    transactions: 732,
  ),
  _GatewayPerformance(
    name: 'Bank transfer',
    successRate: 92.4,
    avgLatencyMs: 1800,
    transactions: 214,
  ),
];

const _retentionMetrics = <_RetentionMetric>[
  _RetentionMetric(
    label: 'D30 retention',
    value: '84%',
    context: 'Up 3 pts vs last sprint',
  ),
  _RetentionMetric(
    label: 'Average auto top-up',
    value: 'ETB 540',
    context: 'Across 1.1k members',
  ),
  _RetentionMetric(
    label: 'Dormant groups',
    value: '9',
    context: 'Flagged for outreach',
  ),
];

String _formatCurrency(double amount) {
  if (amount >= 1000000) {
    final millions = amount / 1000000;
    return 'ETB ${millions.toStringAsFixed(2)}M';
  }
  if (amount >= 1000) {
    final thousands = amount / 1000;
    return 'ETB ${thousands.toStringAsFixed(1)}K';
  }
  return 'ETB ${amount.toStringAsFixed(0)}';
}
