import 'package:equb/models/equb_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:equb/ui/widgets/group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'group_chat_screen.dart';

class GroupsListScreen extends ConsumerWidget {
  const GroupsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(equbGroupsProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Groups')),
      body: Padding(
        padding: context.pagePadding,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return Center(
                    child: InfoCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No groups yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Create or join a group to start saving together.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _EqubGroupCard(group: group);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: InfoCard(
                  child: Text(
                    'Failed to load groups: $err',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_groups_create',
        onPressed: () => _handleCreateGroup(context, ref),
        icon: const Icon(Icons.group_add),
        label: const Text('Create Group'),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _handleCreateGroup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = ref.watch(firebaseAuthUserProvider).asData?.value?.uid;

    if (uid == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in required.')),
      );
      return;
    }

    final created = await showDialog<EqubGroup?>(
      context: context,
      builder: (_) => const GroupDialog(),
    );

    if (created == null) return;

    try {
      final equbRepo = ref.read(equbRepositoryProvider);
      await equbRepo.createGroup(created, actingUserId: uid);
      ref.invalidate(equbGroupsProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Group created successfully')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to create group: $e')),
      );
    }
  }
}

class _EqubGroupCard extends StatelessWidget {
  const _EqubGroupCard({required this.group});

  final EqubGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'ETB ${group.contributionAmount.toStringAsFixed(0)} • every ${group.scheduleConfig.cycleLengthDays} days',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${group.members.length} members',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Next payout ${GroupsListScreen._formatDate(group.rotationState.nextPayoutDate.toLocal())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open group chat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.textSecondary),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GroupChatScreen(groupId: group.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
