import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';

class HeatmapScreen extends StatelessWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Engagement Heatmap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Engagement overview', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Visualize contribution activity across your Equb groups. Darker cells indicate higher participation for the given day.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: SizedBox(
              height: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly activity heatmap',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _HeatmapGrid(data: _heatmapData)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Insights', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                const _InsightRow(
                  icon: Icons.north_east,
                  title: 'Peak contributions on Wednesdays',
                  message:
                      'Most groups hit their highest engagement mid-week. Consider scheduling payouts the day after.',
                ),
                const Divider(height: 24),
                const _InsightRow(
                  icon: Icons.schedule,
                  title: 'Low uptake on Sundays',
                  message:
                      'Weekend participation dips by 22%. Automated reminders could help even out contributions.',
                ),
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        () => _showComingSoon(context, 'Download heatmap CSV'),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export data'),
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

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({required this.data});

  final List<List<int>> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue =
        data.expand((row) => row).reduce((a, b) => a > b ? a : b).toDouble();
    final days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children:
              days
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(d, style: theme.textTheme.labelSmall),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  data.length,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'W${index + 1}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children:
                      data
                          .map(
                            (row) => Expanded(
                              child: Row(
                                children:
                                    row
                                        .map(
                                          (value) => Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.all(
                                                3.0,
                                              ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: _colorFor(
                                                    value,
                                                    maxValue,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    value.toString(),
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: Colors.black87,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _colorFor(int value, double maxValue) {
    if (value == 0) {
      // ignore: deprecated_member_use
      return AppColors.surface.withOpacity(0.4);
    }
    final intensity = (value / maxValue).clamp(0.2, 1.0);
    return Color.lerp(
      // ignore: deprecated_member_use
      AppColors.secondary.withOpacity(0.3),
      AppColors.secondary,
      intensity,
    )!;
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _heatmapData = <List<int>>[
  [12, 18, 25, 32, 27, 9, 4],
  [8, 15, 34, 28, 22, 11, 6],
  [10, 20, 36, 30, 24, 8, 5],
  [7, 14, 29, 26, 21, 7, 3],
];

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
}
