import 'package:flutter/material.dart';

import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class PayoutSchedulerScreen extends StatelessWidget {
  const PayoutSchedulerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = context.isTablet || context.isDesktop;
    final schedule = [
      _PayoutJob(label: 'Monday batch', time: '08:00 • 24 members'),
      _PayoutJob(label: 'Wednesday batch', time: '12:00 • 12 members'),
      _PayoutJob(label: 'Friday batch', time: '17:30 • 7 members'),
    ];

    return ProdScaffold(
      title: 'Payout Scheduler',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _SummaryStat(label: 'Active schedules', value: '3'),
              _SummaryStat(label: 'Next payout', value: 'Today • 17:30'),
              _SummaryStat(label: 'Total recipients', value: '43 members'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ScheduleList(schedule: schedule)),
                const SizedBox(width: AppSpacing.md),
                const Expanded(child: _CalendarPlaceholder()),
              ],
            )
          else ...[
            _ScheduleList(schedule: schedule),
            const SizedBox(height: AppSpacing.md),
            const _CalendarPlaceholder(),
          ],
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: ProdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  final List<_PayoutJob> schedule;

  const _ScheduleList({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return ProdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly cadence',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(
            schedule.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == schedule.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: _ScheduleTile(job: schedule[index]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 220,
              child: PrimaryButton(
                label: 'Add schedule',
                icon: Icons.add,
                onPressed: () {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final _PayoutJob job;

  const _ScheduleTile({required this.job});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadiuses.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  job.time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
        ],
      ),
    );
  }
}

class _CalendarPlaceholder extends StatelessWidget {
  const _CalendarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ProdCard(
      child: SizedBox(
        height: 320,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Calendar scheduler placeholder',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayoutJob {
  final String label;
  final String time;

  const _PayoutJob({required this.label, required this.time});
}
