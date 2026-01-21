import 'dart:async';

import 'package:equb/models/chat_message.dart';
import 'package:equb/models/equb_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();
  final List<ChatMessage> _messages = [];
  StreamSubscription<ChatMessage>? _subscription;
  bool _isSending = false;
  bool _rotationSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatService = ref.read(chatServiceProvider);
      try {
        final history = await chatService.getChatHistory(widget.groupId);
        if (!context.mounted) return;
        setState(() {
          _messages
            ..clear()
            ..addAll(history)
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        _subscription = chatService.watchMessages(widget.groupId).listen((message) {
          if (!context.mounted) return;
          setState(() {
            _mergeIncoming(message);
          });
          _scrollToBottom();
        });
      } catch (e) {
        // Handle chat initialization error gracefully
        debugPrint('Failed to initialize chat: $e');
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupAsync = ref.watch(equbGroupProvider(widget.groupId));
    final groupName = groupAsync.maybeWhen(
      data:
          (group) =>
              group?.name.trim().isNotEmpty == true
                  ? group!.name
                  : 'Group chat',
      orElse: () => 'Group chat',
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _ChatHeaderTitle(
          title: groupName,
          onShowDetails: _showRotationDetailsSheet,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _RotationDetailsPrompt(
                            onOpen: _showRotationDetailsSheet,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _ThisRoundSummaryCard(groupId: widget.groupId),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: InfoCard(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Real-time chat',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Messages are synced in real-time with delivery confirmation and retry support.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chat_outlined,
                                  color: AppColors.secondary,
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final message = _messages[index];
                        final currentUserId = ref.watch(currentUserProvider).value?.id ?? '';
                        final isMine = message.senderId == currentUserId;
                        final isSystem = message.isSystem;
                        final bubbleColor =
                            isSystem
                                ? AppColors.surface
                                : isMine
                                ? AppColors.secondary
                                : AppColors.surface;
                        final textColor =
                            isSystem
                                ? AppColors.textSecondary
                                : isMine
                                ? AppColors.background
                                : AppColors.textPrimary;
                        final alignment =
                            isSystem
                                ? Alignment.center
                                : isMine
                                ? Alignment.centerRight
                                : Alignment.centerLeft;

                        Widget? statusBadge;
                        if (isMine && !isSystem) {
                          switch (message.deliveryStatus) {
                            case ChatDeliveryStatus.sending:
                              statusBadge = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        textColor.withAlpha(
                                          (0.8 * 255).round(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Sending',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: textColor.withAlpha(
                                        (0.75 * 255).round(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              break;
                            case ChatDeliveryStatus.delivered:
                              statusBadge = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: textColor.withAlpha(
                                      (0.85 * 255).round(),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Delivered',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: textColor.withAlpha(
                                        (0.75 * 255).round(),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                              break;
                            case ChatDeliveryStatus.failed:
                              statusBadge = Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.error_outline,
                                    size: 16,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Failed — tap to retry',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              );
                              break;
                          }
                        }

                        return Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                          child: Align(
                            alignment: alignment,
                            child: GestureDetector(
                              onTap:
                                  message.deliveryStatus ==
                                          ChatDeliveryStatus.failed
                                      ? () => _retryFailed(message)
                                      : null,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      isSystem
                                          ? Border.all(
                                            color: AppColors.textSecondary
                                                .withAlpha((0.9 * 255).round()),
                                            width: 1,
                                          )
                                          : null,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        message.senderName,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: textColor.withAlpha(
                                                (0.85 * 255).round(),
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message.content,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(color: textColor),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatTimestamp(message.timestamp),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: textColor.withAlpha(
                                                    (0.7 * 255).round(),
                                                  ),
                                                ),
                                          ),
                                          if (statusBadge != null) statusBadge,
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }, childCount: _messages.length),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
            _MessageComposer(
              controller: _composerController,
              onSend: _handleSend,
              isSending: _isSending,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) {
      return;
    }
    final currentUser = ref.read(currentUserProvider).value;
    final userId = currentUser?.id ?? 'unknown';
    final userName = currentUser?.name ?? 'You';
    
    final localMessage = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      groupId: widget.groupId,
      senderId: userId,
      senderName: userName,
      content: trimmed,
      timestamp: DateTime.now(),
      deliveryStatus: ChatDeliveryStatus.sending,
    );
    setState(() {
      _isSending = true;
      _messages.add(localMessage);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
    _composerController.clear();
    _scrollToBottom();

    final chatService = ref.read(chatServiceProvider);
    try {
      final delivered = await chatService.sendMessage(
        groupId: widget.groupId,
        senderId: userId,
        senderName: userName,
        content: trimmed,
      );
      if (!context.mounted) return;
      setState(() {
        _replacePending(localMessage.id, delivered);
        _isSending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _markFailed(localMessage.id);
        _isSending = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send. Check connection and retry.'),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showRotationDetailsSheet() async {
    if (_rotationSheetOpen || !mounted) {
      return;
    }
    setState(() {
      _rotationSheetOpen = true;
    });
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) {
          final theme = Theme.of(sheetContext);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.55,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Rotation details',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView(
                        controller: scrollController,
                        children: [
                          _GroupRotationBanner(groupId: widget.groupId),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _rotationSheetOpen = false;
        });
      } else {
        _rotationSheetOpen = false;
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final hours = timestamp.hour.toString().padLeft(2, '0');
    final minutes = timestamp.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  void _mergeIncoming(ChatMessage message) {
    final existingIndex = _messages.indexWhere((m) => m.id == message.id);
    if (existingIndex != -1) {
      _messages[existingIndex] = message;
    } else {
      final pendingIndex = _messages.indexWhere(
        (m) =>
            m.deliveryStatus == ChatDeliveryStatus.sending &&
            m.content == message.content &&
            m.senderId == message.senderId,
      );
      if (pendingIndex != -1) {
        _messages[pendingIndex] = message;
      } else {
        _messages.add(message);
      }
    }
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void _replacePending(String localId, ChatMessage delivered) {
    final index = _messages.indexWhere((m) => m.id == localId);
    if (index != -1) {
      _messages[index] = delivered;
    } else {
      _mergeIncoming(delivered);
    }
  }

  void _markFailed(String localId) {
    final index = _messages.indexWhere((m) => m.id == localId);
    if (index == -1) {
      return;
    }
    _messages[index] = _messages[index].copyWith(
      deliveryStatus: ChatDeliveryStatus.failed,
    );
  }

  void _retryFailed(ChatMessage failedMessage) {
    if (_isSending) {
      return;
    }
    setState(() {
      _messages.removeWhere((m) => m.id == failedMessage.id);
    });
    _handleSend(failedMessage.content);
  }
}

class _ChatHeaderTitle extends StatelessWidget {
  const _ChatHeaderTitle({required this.title, required this.onShowDetails});

  final String title;
  final VoidCallback onShowDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    final captionStyle = theme.textTheme.labelSmall?.copyWith(
      // ignore: deprecated_member_use
      color: foreground.withOpacity(0.72),
      fontSize: 12,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onShowDetails,
      onVerticalDragStart: (_) => onShowDetails(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('Tap or pull for draw controls', style: captionStyle),
              ],
            ),
          ),
          Icon(Icons.expand_more, color: foreground),
        ],
      ),
    );
  }
}

class _RotationDetailsPrompt extends StatelessWidget {
  const _RotationDetailsPrompt({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InfoCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.casino_outlined, color: AppColors.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap the header to review rotation overview, contribution progress, the season queue, and recent payouts.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(onPressed: onOpen, child: const Text('Open')),
        ],
      ),
    );
  }
}

class _ThisRoundSummaryCard extends ConsumerWidget {
  const _ThisRoundSummaryCard({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncGroup = ref.watch(equbGroupProvider(groupId));
    final metricsValue = ref.watch(equbGroupMetricsProvider(groupId));
    final user = ref.watch(currentUserProvider).value;

    return asyncGroup.when(
      data: (group) {
        final metrics = metricsValue.asData?.value;
        if (group == null || metrics == null) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final equb = group;
        final totalMembers = equb.members.length;
        final nextRecipient = metrics.nextRecipient;
        final nextRound = metrics.nextRound ?? (metrics.currentRound + 1);
        final roundInSeason = _GroupRotationBanner._roundWithinSeason(
          nextRound,
          totalMembers,
        );
        final roleLabel = _GroupRotationBanner._roleForRoundInSeason(
          roundInSeason,
          totalMembers,
        );

        final requiredAmount = equb.contributionAmount;
        final progress = equb.rotationState.contributionProgress;

        Future<void> handleContribute() async {
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sign in to contribute.')),
            );
            return;
          }

          final phone = (user.phone ?? '').trim();
          if (phone.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Add your phone number in Profile and try again.',
                ),
              ),
            );
            return;
          }

          try {
            final gatewayService = ref.read(gatewayServiceProvider);
            final paymentService = await gatewayService.getAdapter('chapa');
            if (paymentService == null) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chapa gateway is not configured.'),
                ),
              );
              return;
            }

            if (!context.mounted) return;

            await paymentService.createPayment(
              fromUserId: user.id,
              toUserId: equb.id,
              amount: requiredAmount,
              gateway: 'chapa',
              customerPhone: phone,
              context: context,
            );

            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Checkout opened. Awaiting confirmation.'),
              ),
            );
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to start payment: $e')),
            );
          }
        }

        return InfoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This round', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(
                      'ETB ${requiredAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.payments_outlined, size: 14),
                  ),
                  Chip(
                    label: Text(
                      'Every ${equb.scheduleConfig.cycleLengthDays} days',
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.calendar_month_outlined, size: 14),
                  ),
                  Chip(
                    label: Text(
                      'Next payout ${_GroupRotationBanner._formatDate(metrics.nextPayoutDate)}',
                      style: theme.textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.emoji_events_outlined, size: 14),
                  ),
                ],
              ),
              if (nextRecipient != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Next winner: ${_GroupRotationBanner._formatMember(nextRecipient)}${roleLabel.isEmpty ? '' : ' ($roleLabel)'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Contribution status',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: handleContribute,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Pay this cycle'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final member in equb.members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MemberPaidRow(
                    memberLabel: _GroupRotationBanner._formatMember(member),
                    contributed: progress[member] ?? 0.0,
                    requiredAmount: requiredAmount,
                    highlight: user != null && member == user.id,
                  ),
                ),
            ],
          ),
        );
      },
      loading:
          () => const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (err, _) => InfoCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Unable to load this round summary: $err',
              style: theme.textTheme.bodySmall,
            ),
          ),
    );
  }
}

class _MemberPaidRow extends StatelessWidget {
  const _MemberPaidRow({
    required this.memberLabel,
    required this.contributed,
    required this.requiredAmount,
    required this.highlight,
  });

  final String memberLabel;
  final double contributed;
  final double requiredAmount;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paid =
        requiredAmount <= 0 ? true : contributed + 1e-8 >= requiredAmount;
    final statusColor = paid ? AppColors.success : theme.colorScheme.error;

    return Row(
      children: [
        Expanded(
          child: Text(
            memberLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Chip(
          label: Text(
            paid ? 'Paid' : 'Not paid',
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: statusColor.withOpacity(0.10),
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: statusColor.withOpacity(0.35)),
          avatar: Icon(
            paid ? Icons.check_circle_outline : Icons.schedule,
            size: 16,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

class _RoundTimelineStrip extends StatelessWidget {
  const _RoundTimelineStrip({
    required this.summaries,
    required this.memberCount,
    required this.nextRecipient,
  });

  final List<EqubRoundSummary> summaries;
  final int memberCount;
  final String? nextRecipient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcoming = summaries
        .where((s) => s.status != EqubRoundStatus.completed)
        .take(10)
        .toList(growable: false);

    if (upcoming.isEmpty) {
      return Text(
        'No upcoming rounds available.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    Color statusColor(EqubRoundStatus status) {
      switch (status) {
        case EqubRoundStatus.completed:
          return AppColors.success;
        case EqubRoundStatus.pending:
          return theme.colorScheme.primary;
        case EqubRoundStatus.overdue:
          return theme.colorScheme.error;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < upcoming.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _RoundChip(
              round: upcoming[i].round,
              memberId: upcoming[i].memberId,
              status: upcoming[i].status,
              isNext:
                  nextRecipient != null &&
                  upcoming[i].memberId == nextRecipient,
              memberCount: memberCount,
              color: statusColor(upcoming[i].status),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({
    required this.round,
    required this.memberId,
    required this.status,
    required this.isNext,
    required this.memberCount,
    required this.color,
  });

  final int round;
  final String memberId;
  final EqubRoundStatus status;
  final bool isNext;
  final int memberCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roundInSeason = _GroupRotationBanner._roundWithinSeason(
      round,
      memberCount,
    );
    final role = _GroupRotationBanner._roleForRoundInSeason(
      roundInSeason,
      memberCount,
    );
    final label = 'R$roundInSeason';
    final subtitle = _GroupRotationBanner._formatMember(memberId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isNext ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(isNext ? 0.65 : 0.35),
          width: isNext ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (role.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  role,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (isNext) ...[
                const SizedBox(width: 6),
                Icon(Icons.star_rounded, size: 16, color: color),
              ],
            ],
          ),
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              subtitle,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupRotationBanner extends ConsumerWidget {
  const _GroupRotationBanner({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGroup = ref.watch(equbGroupProvider(groupId));
    final metricsValue = ref.watch(equbGroupMetricsProvider(groupId));
    final summariesValue = ref.watch(equbRoundSummariesProvider(groupId));
    final userNotifier = ref.watch(currentUserProvider);

    return asyncGroup.when(
      data: (group) {
        final metrics = metricsValue.asData?.value;
        final summaries = summariesValue.asData?.value;
        final user = userNotifier.value;
        if (group == null) {
          return InfoCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              'This equb is no longer available. Try refreshing the page.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        final EqubGroup equb = group;
        if (metrics == null || summaries == null) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final theme = Theme.of(context);
        final totalMembers = metrics.totalMembers;
        if (totalMembers <= 0) {
          return InfoCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Add members to start this equb season. Rotation draws begin once at least one member joins.',
              style: theme.textTheme.bodySmall,
            ),
          );
        }

        final state = equb.rotationState;
        final currentRound = metrics.currentRound;
        final nextGlobalRound = metrics.nextRound ?? (currentRound + 1);
        final nextSeason = _seasonForRound(nextGlobalRound, totalMembers);
        final nextRoundInSeason = _roundWithinSeason(
          nextGlobalRound,
          totalMembers,
        );
        final nextCandidate = metrics.nextRecipient;
        final queueEntries = summaries
            .where((summary) => summary.status != EqubRoundStatus.completed)
            .toList(growable: false);
        final queuePreview = queueEntries.take(6).toList(growable: false);
        final historyPreview = summaries
            .where((summary) => summary.status == EqubRoundStatus.completed)
            .toList(growable: false)
            .reversed
            .take(4)
            .toList(growable: false);
        final strategyLabel = _strategyLabel(equb.scheduleConfig.strategy);
        final cycleLabel = equb.scheduleConfig.cycle.label;
        final autoAssignLabel =
            equb.scheduleConfig.autoAssign
                ? 'Auto assignment'
                : 'Manual assignment';

        return InfoCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 480;
                  final headingStyle =
                      theme.textTheme.titleSmall?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ) ??
                      const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      );
                  final chipTextStyle =
                      theme.textTheme.labelSmall?.copyWith(fontSize: 11) ??
                      const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      );
                  final buttonTextStyle =
                      theme.textTheme.labelLarge?.copyWith(fontSize: 13) ??
                      const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      );
                  final chipWidgets = <Widget>[
                    Chip(
                      label: Text(cycleLabel, style: chipTextStyle),
                      avatar: const Icon(Icons.calendar_month, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(strategyLabel, style: chipTextStyle),
                      avatar: const Icon(Icons.shuffle, size: 14),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(autoAssignLabel, style: chipTextStyle),
                      avatar: Icon(
                        equb.scheduleConfig.autoAssign
                            ? Icons.bolt_outlined
                            : Icons.handshake_outlined,
                        size: 14,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ];

                  Future<void> handleDraw({required bool force}) async {
                    final confirmTitle =
                        force ? 'Force draw' : 'Draw next round';
                    final confirmAction = force ? 'Force draw' : 'Draw';
                    final confirmMessage =
                        force
                            ? 'Override contribution thresholds and draw Season $nextSeason round $nextRoundInSeason right now? The fairness queue still ensures every member is selected once per season.'
                            : 'Season $nextSeason was shuffled randomly. Drawing round $nextRoundInSeason keeps the guarantee that every member wins once before the season resets. Continue?';

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: Text(confirmTitle),
                            content: Text(confirmMessage),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(confirmAction),
                              ),
                            ],
                          ),
                    );

                    if (confirm != true || !context.mounted) {
                      return;
                    }

                    final repo = ref.read(equbRepositoryProvider);
                    try {
                      final payout = await repo.triggerNextPayout(
                        equb.id,
                        ignoreContributionThreshold: force,
                      );
                      if (!context.mounted) return;
                      if (payout == null) {
                        final skippedMessage =
                            force
                                ? 'Force draw failed – no winner resolved.'
                                : 'Draw skipped – contribution threshold not met yet.';
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(skippedMessage)));
                      } else {
                        final season = _seasonForRound(
                          payout.round,
                          totalMembers,
                        );
                        final roundInSeason = _roundWithinSeason(
                          payout.round,
                          totalMembers,
                        );
                        final roleLabel = _roleForRoundInSeason(
                          roundInSeason,
                          totalMembers,
                        );
                        final prefix = force ? 'Forced Season' : 'Season';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$prefix $season | Round $roundInSeason${roleLabel.isEmpty ? '' : ' ($roleLabel)'} winner: ${_formatMember(payout.memberId)} - ETB ${payout.amount.toStringAsFixed(0)}',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      final errorMessage =
                          force
                              ? 'Failed to force draw: $e'
                              : 'Failed to draw next winner: $e';
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(errorMessage)));
                    }

                    ref.invalidate(equbRepositoryProvider);
                    ref.invalidate(equbGroupProvider(equb.id));
                    ref.invalidate(equbGroupMetricsProvider(equb.id));
                    ref.invalidate(equbRoundSummariesProvider(equb.id));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Rotation overview', style: headingStyle),
                          Chip(
                            label: Text(
                              'Season $nextSeason • Round $nextRoundInSeason of $totalMembers',
                              style: chipTextStyle,
                            ),
                            backgroundColor: AppColors.surface,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (int i = 0; i < chipWidgets.length; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              chipWidgets[i],
                            ],
                          ],
                        ),
                      ),
                      if (user != null &&
                          (user.role == UserRole.equbAdmin ||
                              user.role == UserRole.superAdmin)) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment:
                              isCompact
                                  ? WrapAlignment.start
                                  : WrapAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.casino_outlined, size: 18),
                              label: const Text('Draw next winner'),
                              style: ElevatedButton.styleFrom(
                                textStyle: buttonTextStyle,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => handleDraw(force: false),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.flash_on_outlined,
                                size: 18,
                              ),
                              label: const Text('Force draw'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.surface,
                                foregroundColor: theme.colorScheme.onSurface,
                                textStyle: buttonTextStyle,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () => handleDraw(force: true),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Next payout on ${_formatDateTime(metrics.nextPayoutDate)}',
                style: theme.textTheme.bodySmall,
              ),
              if (nextCandidate != null) ...[
                const SizedBox(height: 4),
                Builder(
                  builder: (context) {
                    final roleLabel = _roleForRoundInSeason(
                      nextRoundInSeason,
                      totalMembers,
                    );
                    return Text(
                      'Queued next: Season $nextSeason Round $nextRoundInSeason${roleLabel.isEmpty ? '' : ' ($roleLabel)'} - ${_formatMember(nextCandidate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  'Season $nextSeason order was shuffled randomly. All $totalMembers members win exactly once before Season ${nextSeason + 1} reshuffles the queue again.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary.withAlpha(
                      (0.85 * 255).round(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text('Contribution progress', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              for (final member in equb.members)
                _MemberProgressRow(
                  memberLabel: _formatMember(member),
                  contributed: state.contributionProgress[member] ?? 0,
                  requiredAmount: equb.contributionAmount,
                  highlight: member == nextCandidate,
                ),
              if (queuePreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Round timeline', style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                _RoundTimelineStrip(
                  summaries: summaries,
                  memberCount: totalMembers,
                  nextRecipient: nextCandidate,
                ),
                const SizedBox(height: 16),
                Text(
                  'Season $nextSeason queue (random order)',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < queuePreview.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        _QueueBadge(
                          label: _formatMember(queuePreview[i].memberId),
                          isNext: queuePreview[i].memberId == nextCandidate,
                          status: queuePreview[i].status,
                          season: _seasonForRound(
                            queuePreview[i].round,
                            totalMembers,
                          ),
                          roundInSeason: _roundWithinSeason(
                            queuePreview[i].round,
                            totalMembers,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (historyPreview.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Recent payouts', style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                for (final record in historyPreview)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Season ${_seasonForRound(record.round, totalMembers)} | Round ${_roundWithinSeason(record.round, totalMembers)} - ${_formatMember(record.memberId)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          _formatDate(
                            record.actualPayout?.processedAt ??
                                record.scheduledFor,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
      loading:
          () => const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => InfoCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Unable to load rotation details right now. Please try again later.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
    );
  }

  static int _seasonForRound(int round, int memberCount) {
    if (memberCount <= 0) {
      return 1;
    }
    if (round <= 0) {
      return 1;
    }
    return ((round - 1) ~/ memberCount) + 1;
  }

  static int _roundWithinSeason(int round, int memberCount) {
    if (memberCount <= 0) {
      return round <= 0 ? 1 : round;
    }
    if (round <= 0) {
      return 1;
    }
    return ((round - 1) % memberCount) + 1;
  }

  static String _roleForRoundInSeason(int roundInSeason, int memberCount) {
    if (memberCount <= 0) return '';
    if (roundInSeason == 1) return 'Borrower';
    if (roundInSeason == memberCount) return 'Saver';
    return '';
  }

  static String _strategyLabel(PayoutStrategy strategy) {
    switch (strategy) {
      case PayoutStrategy.random:
        return 'Random order';
      case PayoutStrategy.fixedOrder:
        return 'Fixed order';
      case PayoutStrategy.adminAssigned:
        return 'Admin assigned';
    }
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

  static String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year at $hour:$minute';
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year';
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.onSend,
    required this.isSending,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool isSending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  if (!isSending) {
                    onSend(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: isSending ? null : () => onSend(controller.text),
              icon:
                  isSending
                      ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                      : const Icon(Icons.send),
              label: Text(isSending ? 'Sending…' : 'Send'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(88, 40)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberProgressRow extends StatelessWidget {
  const _MemberProgressRow({
    required this.memberLabel,
    required this.contributed,
    required this.requiredAmount,
    required this.highlight,
  });

  final String memberLabel;
  final double contributed;
  final double requiredAmount;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio =
        requiredAmount <= 0
            ? 0.0
            : (contributed / requiredAmount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  memberLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: highlight ? FontWeight.w600 : null,
                  ),
                ),
              ),
              Text(
                'ETB ${contributed.toStringAsFixed(0)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.slightlyLighterSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                highlight ? AppColors.secondary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueBadge extends StatelessWidget {
  const _QueueBadge({
    required this.label,
    required this.isNext,
    required this.status,
    required this.season,
    required this.roundInSeason,
  });

  final String label;
  final bool isNext;
  final EqubRoundStatus status;
  final int season;
  final int roundInSeason;

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
        'S$season R$roundInSeason - $label',
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
      backgroundColor: background,
      avatar: avatar,
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
