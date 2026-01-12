import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/equb_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/admin_providers.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/admin_screen.dart';
import 'package:equb/ui/screens/gateways_screen.dart';
import 'package:equb/ui/screens/group_chat_screen.dart';
import 'package:equb/ui/screens/super_admin_screen.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/screens/wallet/deposit_screen.dart';
import 'package:equb/ui/utils/app_snackbar.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:equb/ui/widgets/group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/providers/wallet_providers.dart';
// import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isAdmin = ref.watch(isAdminProvider).asData?.value == true;
    final isSuperAdmin = ref.watch(isSuperAdminProvider).asData?.value == true;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isWide = context.isTablet || context.isDesktop;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: () => Navigator.of(context).pushNamed('/admin'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Admin Panel',
            ),
          if (isSuperAdmin)
            IconButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SuperAdminScreen()),
                  ),
              icon: const Icon(Icons.security_outlined),
              tooltip: 'Super Admin',
            ),
          if (isAdmin)
            IconButton(
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GatewaysScreen()),
                  ),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: context.pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, ${user?.name ?? 'Guest'}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _WalletSummaryCard(),
                  const SizedBox(height: AppSpacing.lg),
                  const RoundWinnersStrip(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildMainSections(context, theme, isWide),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton:
          user != null
              ? FloatingActionButton(
                heroTag: 'fab_dashboard_add',
                onPressed: () => _showGroupDialog(context, ref),
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  void _showGroupDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider).value;
    final actingUserId = user?.id;
    if (actingUserId == null) {
      AppSnackbar.showError('Please sign in to create a group.');
      return;
    }
    final created = await showDialog<EqubGroup?>(
      context: context,
      builder: (_) => const GroupDialog(),
    );
    if (created != null) {
      try {
        final equbRepo = ref.read(equbRepositoryProvider);
        // Ensure ID is generated if empty (though repo might handle it, safer here or in repo)
        // The repo.createGroup usually handles ID generation if we pass empty or null,
        // but let's check our repo implementation.
        // FirestoreEqubRepository uses doc().id if id is empty.
        await equbRepo.createGroup(created, actingUserId: actingUserId);
        ref.invalidate(equbGroupsProvider); // Refresh list
        AppSnackbar.showInfo('Group created successfully');
      } catch (e) {
        AppSnackbar.showError('Failed to create group: $e');
      }
    }
  }

  Widget _buildMainSections(
    BuildContext context,
    ThemeData theme,
    bool isWide,
  ) {
    final groupsSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Groups', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const GroupList(),
      ],
    );

    final activitySection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        const TransactionList(),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: groupsSection),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: activitySection),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        groupsSection,
        const SizedBox(height: AppSpacing.lg),
        activitySection,
      ],
    );
  }
}

class _WalletSummaryCard extends ConsumerStatefulWidget {
  const _WalletSummaryCard();

  @override
  ConsumerState<_WalletSummaryCard> createState() => _WalletSummaryCardState();
}

class _WalletSummaryCardState extends ConsumerState<_WalletSummaryCard> {
  bool _isHidden = false;
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(walletSummaryProvider);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: AppColors.textSecondary,
      fontSize: 11,
    );
    final amountStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    );
    final buttonTextStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    );
    final amountText =
        _isHidden
            ? 'ETB ****'
            : summaryAsync.maybeWhen(
              data: (summary) => 'ETB ${summary.available.toStringAsFixed(2)}',
              orElse: () => 'ETB —',
            );
    final toggleVisibilityTooltip =
        _isHidden ? 'Show savings balance' : 'Hide savings balance';
    final collapseTooltip =
        _isCollapsed ? 'Show savings dashboard' : 'Hide savings dashboard';

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My savings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: collapseTooltip,
                icon: Icon(
                  _isCollapsed
                      ? Icons.unfold_more_outlined
                      : Icons.unfold_less_outlined,
                ),
                onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
              ),
              IconButton(
                tooltip: toggleVisibilityTooltip,
                icon: Icon(
                  _isHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _isHidden = !_isHidden),
              ),
            ],
          ),
          if (!_isCollapsed) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total savings', style: labelStyle),
                      const SizedBox(height: 4),
                      Text(amountText, style: amountStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 32),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DepositScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: Text('Top up', style: buttonTextStyle),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class RoundWinnersStrip extends ConsumerWidget {
  const RoundWinnersStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const SizedBox.shrink();
    }
    final repo = ref.watch(equbRepositoryProvider);
    return FutureBuilder<List<_GroupHighlight>>(
      future: _loadHighlights(repo, user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final highlights = snapshot.data ?? const <_GroupHighlight>[];
        if (highlights.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Round Highlights', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: highlights.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final highlight = highlights[index];
                  return _WinnerCard(highlight: highlight);
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.highlight});

  final _GroupHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = highlight.group;
    final metrics = highlight.metrics;
    final summaries = highlight.summaries;
    final completed =
        summaries
            .where((summary) => summary.status == EqubRoundStatus.completed)
            .toList();
    final historyPreview = completed.reversed.take(4).toList(growable: false);
    final lastPayout =
        completed.isNotEmpty ? completed.last.actualPayout : null;
    final upcoming = summaries
        .where((summary) => summary.status != EqubRoundStatus.completed)
        .toList(growable: false);
    final nextSummary = upcoming.isNotEmpty ? upcoming.first : null;
    final nextCandidate = metrics.nextRecipient ?? nextSummary?.memberId;
    final queuePreview = upcoming.take(5).toList(growable: false);
    final fundingRatio = metrics.fundedPercentage.clamp(0.0, 1.0);

    return SizedBox(
      width: 280,
      height: 240,
      child: InfoCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${group.scheduleConfig.cycle.label} • ETB ${group.contributionAmount.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lastPayout != null
                        ? 'Round ${lastPayout.round} winner • ${_formatMember(lastPayout.memberId)}'
                        : 'No payouts recorded yet',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextCandidate != null && nextSummary != null
                        ? 'Next up • ${_formatMember(nextCandidate)} on ${_formatDate(nextSummary.scheduledFor)}'
                        : nextCandidate != null
                        ? 'Next up • ${_formatMember(nextCandidate)} on ${_formatDate(metrics.nextPayoutDate)}'
                        : 'Next round pending',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: fundingRatio,
              minHeight: 6,
              backgroundColor: AppColors.slightlyLighterSurface,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.secondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pool funded ${_formatPercent(fundingRatio)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (queuePreview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Queue', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in queuePreview)
                    _QueueChip(
                      label: _formatMember(entry.memberId),
                      isNext: entry.memberId == nextCandidate,
                      status: entry.status,
                    ),
                ],
              ),
            ],
            if (historyPreview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Recent winners', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final record in historyPreview)
                    Chip(
                      label: Text(
                        'R${record.round} • ${_formatMember(record.memberId)}',
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.surface,
                      labelStyle: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              text: 'Open chat',
              icon: Icons.chat_bubble_outline,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(groupId: group.id),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _formatMember(String memberId) {
    final cleaned = memberId.trim();
    if (cleaned.isEmpty) {
      return 'Unknown';
    }
    final parts = cleaned.split(RegExp(r'[-_]'));
    if (parts.length >= 2) {
      final prefix = parts.first;
      final suffix = parts.last;
      final readablePrefix =
          prefix.isEmpty
              ? ''
              : '${prefix[0].toUpperCase()}${prefix.substring(1)}';
      return '${readablePrefix.trim()} ${suffix.toUpperCase()}'.trim();
    }
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  static String _formatPercent(double ratio) {
    final value = (ratio * 100).clamp(0, 100).round();
    return '$value%';
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year';
  }
}

class _GroupHighlight {
  const _GroupHighlight({
    required this.group,
    required this.metrics,
    required this.summaries,
  });

  final EqubGroup group;
  final EqubGroupMetrics metrics;
  final List<EqubRoundSummary> summaries;
}

Future<List<_GroupHighlight>> _loadHighlights(
  EqubRepository repo,
  String userId,
) async {
  final groups = await repo.listGroups();
  final visible = groups.where((g) => g.members.contains(userId)).toList();
  if (visible.isEmpty) {
    return const <_GroupHighlight>[];
  }
  final futures = visible.map((group) async {
    final metrics = await repo.fetchGroupMetrics(group.id);
    final summaries = await repo.fetchRoundSummaries(group.id);
    return _GroupHighlight(
      group: group,
      metrics: metrics,
      summaries: summaries,
    );
  });
  return Future.wait(futures);
}

class _QueueChip extends StatelessWidget {
  const _QueueChip({
    required this.label,
    required this.isNext,
    required this.status,
  });

  final String label;
  final bool isNext;
  final EqubRoundStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = status == EqubRoundStatus.overdue;
    final Color color;
    final Color background;
    Widget? avatar;
    if (isOverdue) {
      color = theme.colorScheme.error;
      background = theme.colorScheme.error.withAlpha((0.12 * 255).round());
      avatar = Icon(Icons.error_outline, size: 16, color: color);
    } else if (isNext) {
      color = AppColors.secondary;
      background = AppColors.secondary.withAlpha((0.12 * 255).round());
      avatar = const Icon(
        Icons.play_arrow,
        size: 16,
        color: AppColors.secondary,
      );
    } else {
      color = AppColors.textSecondary;
      background = AppColors.surface;
    }
    return Chip(
      label: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
      avatar: avatar,
      backgroundColor: background,
      shape: StadiumBorder(
        side: BorderSide(
          color:
              isOverdue
                  ? theme.colorScheme.error.withAlpha((0.6 * 255).round())
                  : isNext
                  ? AppColors.secondary.withAlpha((0.6 * 255).round())
                  : theme.dividerColor.withAlpha((0.3 * 255).round()),
        ),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class GroupList extends ConsumerWidget {
  const GroupList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(equbGroupsProvider);
    final user = ref.watch(currentUserProvider).value;

    return groupsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (groups) {
        if (groups.isEmpty) {
          return const InfoCard(
            child: Center(child: Text('No groups yet. Create one!')),
          );
        }
        return SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final g = groups[idx];
              final isAdmin =
                  user != null &&
                  (user.role == UserRole.equbAdmin ||
                      user.role == UserRole.superAdmin);
              return SizedBox(
                width: 280,
                child: InfoCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ETB ${g.contributionAmount.toStringAsFixed(2)} / cycle',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${g.members.length} members',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (isAdmin)
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: () async {
                                    final updated = await showDialog<EqubGroup>(
                                      context: context,
                                      builder: (_) => GroupDialog(group: g),
                                    );
                                    if (updated != null) {
                                      final repo = ref.read(
                                        equbRepositoryProvider,
                                      );
                                      await repo.updateGroup(
                                        updated,
                                        actingUserId: user.id,
                                      );
                                      ref.invalidate(equbGroupsProvider);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (ctx) => AlertDialog(
                                            title: const Text('Delete Group?'),
                                            content: Text(
                                              'Are you sure you want to delete "${g.name}"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      false,
                                                    ),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      ctx,
                                                      true,
                                                    ),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (confirm == true) {
                                      final repo = ref.read(
                                        equbRepositoryProvider,
                                      );
                                      await repo.deleteGroup(
                                        g.id,
                                        actingUserId: user.id,
                                      );
                                      ref.invalidate(equbGroupsProvider);
                                    }
                                  },
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        text: 'Open chat',
                        icon: Icons.chat_bubble_outline,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GroupChatScreen(groupId: g.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class TransactionList extends ConsumerWidget {
  const TransactionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equbRepo = ref.watch(equbRepositoryProvider);
    return FutureBuilder<List<EqubGroup>>(
      future: equbRepo.listGroups(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = snapshot.data ?? [];
        final txs = groups.expand((g) => g.ledger).toList();
        txs.sort(
          (a, b) => b.timestamp.compareTo(a.timestamp),
        ); // Sort descending

        if (txs.isEmpty) {
          return const InfoCard(
            child: Center(child: Text('No transactions yet.')),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: txs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, idx) {
            final t = txs[idx];
            final isSuccess = t.status == TransactionStatus.success;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    isSuccess
                        ? AppColors.success.withAlpha((0.1 * 255).round())
                        : AppColors.warning.withAlpha((0.1 * 255).round()),
                child: Icon(
                  isSuccess
                      ? Icons.check_circle_outline
                      : Icons.hourglass_bottom,
                  color: isSuccess ? AppColors.success : AppColors.warning,
                ),
              ),
              title: Text('ETB ${t.amount.toStringAsFixed(2)}'),
              subtitle: Text('${t.gateway} • ${t.timestamp.toLocal()}'),
              trailing: Text(
                isSuccess ? 'Success' : 'Pending',
                style: TextStyle(
                  color: isSuccess ? AppColors.success : AppColors.warning,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
