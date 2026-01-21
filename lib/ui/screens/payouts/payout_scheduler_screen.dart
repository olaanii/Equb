import 'package:equb/models/equb_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class PayoutSchedulerScreen extends ConsumerStatefulWidget {
  const PayoutSchedulerScreen({super.key});

  @override
  ConsumerState<PayoutSchedulerScreen> createState() => _PayoutSchedulerScreenState();
}

class _PayoutSchedulerScreenState extends ConsumerState<PayoutSchedulerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  @override
  Widget build(BuildContext context) {
    final isWide = context.isTablet || context.isDesktop;
    final groupsAsync = ref.watch(equbGroupsProvider);

    return groupsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error loading schedules: $error')),
      ),
      data: (groups) {
        final schedules = _buildSchedulesFromGroups(groups);
        final payoutDates = _extractPayoutDates(groups);
        final stats = _calculateStats(groups);

        return ProdScaffold(
          title: 'Payout Scheduler',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _SummaryStat(label: 'Active schedules', value: stats.activeCount.toString()),
                  _SummaryStat(label: 'Next payout', value: stats.nextPayoutLabel),
                  _SummaryStat(label: 'Total recipients', value: '${stats.totalRecipients} members'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _ScheduleList(schedule: schedules)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _PayoutCalendar(
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        payoutDates: payoutDates,
                        onDaySelected: (selected, focused) {
                          setState(() {
                            _selectedDay = selected;
                            _focusedDay = focused;
                          });
                        },
                        onPageChanged: (focused) {
                          setState(() {
                            _focusedDay = focused;
                          });
                        },
                      ),
                    ),
                  ],
                )
              else ...[
                _ScheduleList(schedule: schedules),
                const SizedBox(height: AppSpacing.md),
                _PayoutCalendar(
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  payoutDates: payoutDates,
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) {
                    setState(() {
                      _focusedDay = focused;
                    });
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<_PayoutJob> _buildSchedulesFromGroups(List<EqubGroup> groups) {
    final schedules = <_PayoutJob>[];
    final dateFormat = DateFormat('EEEE');
    final timeFormat = DateFormat('HH:mm');

    for (final group in groups) {
      final nextPayout = group.rotationState.nextPayoutDate;
      final dayLabel = dateFormat.format(nextPayout);
      final timeLabel = timeFormat.format(nextPayout);
      
      schedules.add(_PayoutJob(
        label: '${group.name} - $dayLabel',
        time: '$timeLabel • ${group.members.length} members',
        groupId: group.id,
      ));
    }

    // Sort by next payout date
    schedules.sort((a, b) => a.label.compareTo(b.label));
    return schedules;
  }

  Map<DateTime, List<EqubGroup>> _extractPayoutDates(List<EqubGroup> groups) {
    final payoutDates = <DateTime, List<EqubGroup>>{};
    
    for (final group in groups) {
      final payoutDate = DateTime(
        group.rotationState.nextPayoutDate.year,
        group.rotationState.nextPayoutDate.month,
        group.rotationState.nextPayoutDate.day,
      );
      
      payoutDates.putIfAbsent(payoutDate, () => []);
      payoutDates[payoutDate]!.add(group);
    }
    
    return payoutDates;
  }

  _PayoutStats _calculateStats(List<EqubGroup> groups) {
    final activeCount = groups.length;
    final totalRecipients = groups.fold<int>(0, (sum, g) => sum + g.members.length);
    
    String nextPayoutLabel = 'No scheduled payouts';
    if (groups.isNotEmpty) {
      final sortedGroups = groups.toList()
        ..sort((a, b) => a.rotationState.nextPayoutDate.compareTo(b.rotationState.nextPayoutDate));
      
      final nextPayout = sortedGroups.first.rotationState.nextPayoutDate;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final payoutDay = DateTime(nextPayout.year, nextPayout.month, nextPayout.day);
      
      if (payoutDay == today) {
        nextPayoutLabel = 'Today • ${DateFormat('HH:mm').format(nextPayout)}';
      } else if (payoutDay == today.add(const Duration(days: 1))) {
        nextPayoutLabel = 'Tomorrow • ${DateFormat('HH:mm').format(nextPayout)}';
      } else {
        nextPayoutLabel = DateFormat('MMM d • HH:mm').format(nextPayout);
      }
    }
    
    return _PayoutStats(
      activeCount: activeCount,
      totalRecipients: totalRecipients,
      nextPayoutLabel: nextPayoutLabel,
    );
  }
}

class _PayoutStats {
  final int activeCount;
  final int totalRecipients;
  final String nextPayoutLabel;

  const _PayoutStats({
    required this.activeCount,
    required this.totalRecipients,
    required this.nextPayoutLabel,
  });
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
            'Scheduled Payouts',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          if (schedule.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  'No active payout schedules',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...List.generate(
              schedule.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == schedule.length - 1 ? 0 : AppSpacing.sm,
                ),
                child: _ScheduleTile(job: schedule[index]),
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
          IconButton(
            onPressed: () {
              // View group details
            },
            icon: const Icon(Icons.visibility_outlined),
          ),
        ],
      ),
    );
  }
}

class _PayoutCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<DateTime, List<EqubGroup>> payoutDates;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  const _PayoutCalendar({
    required this.focusedDay,
    required this.selectedDay,
    required this.payoutDates,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ProdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payout Calendar',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          TableCalendar<EqubGroup>(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            eventLoader: (day) {
              final normalizedDay = DateTime(day.year, day.month, day.day);
              return payoutDates[normalizedDay] ?? [];
            },
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: AppColors.secondary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: theme.textTheme.titleSmall ?? const TextStyle(),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      events.length > 3 ? 3 : events.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (selectedDay != null) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            _SelectedDayPayouts(
              date: selectedDay!,
              groups: payoutDates[DateTime(selectedDay!.year, selectedDay!.month, selectedDay!.day)] ?? [],
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectedDayPayouts extends StatelessWidget {
  final DateTime date;
  final List<EqubGroup> groups;

  const _SelectedDayPayouts({required this.date, required this.groups});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat('EEEE, MMMM d').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (groups.isEmpty)
          Text(
            'No payouts scheduled',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          )
        else
          ...groups.map((group) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, size: 16, color: AppColors.secondary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  group.name,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '• ${group.members.length} members',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          )),
      ],
    );
  }
}

class _PayoutJob {
  final String label;
  final String time;
  final String groupId;

  const _PayoutJob({required this.label, required this.time, required this.groupId});
}
