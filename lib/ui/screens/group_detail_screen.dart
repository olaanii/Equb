import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/ui/screens/gateways_screen.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/group.dart';
import 'group_chat_screen.dart';
import 'groups/group_analytics_screen.dart';

class GroupDetailScreen extends ConsumerWidget {
  final Group group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildActionButtons(context, ref, user),
            const SizedBox(height: 24),
            Text("Members", style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildMemberList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Contribution Details",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BalanceDisplay(
                label: 'Amount',
                amount: 'ETB 100.00', // Placeholder
              ),
              BalanceDisplay(label: 'Frequency', amount: group.frequency),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
  ) {
    return Column(
      children: [
        // Payment and Analytics buttons
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: 'Pay with FenanPay',
                icon: Icons.payment,
                onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                final gatewayService = ref.read(gatewayServiceProvider);
                final paymentService = await gatewayService.getAdapter(
                  'fenanpay',
                );
                if (paymentService == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('FenanPay gateway is not configured.'),
                    ),
                  );
                  return;
                }

                if (!context.mounted) return;

                final tx = await paymentService.createPayment(
                  fromUserId: user?.id ?? 'demo_user',
                  toUserId: group.id,
                  amount: group.contribution.toDouble(),
                  gateway: 'fenanpay',
                  context: context,
                );

                if (!context.mounted) return;

                switch (tx.status) {
                  case TransactionStatus.success:
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Payment completed.'),
                      ),
                    );
                    break;
                  case TransactionStatus.failed:
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment failed. Please try again.',
                        ),
                      ),
                    );
                    break;
                  case TransactionStatus.pending:
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment started. Awaiting confirmation.',
                        ),
                      ),
                    );
                    break;
                }
              } on GatewayCredentialException catch (err) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'FenanPay credentials missing: ${err.message}',
                    ),
                    action: SnackBarAction(
                      label: 'View runbook',
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GatewaysScreen(),
                            ),
                          ),
                    ),
                  ),
                );
              } catch (err) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Payment error: $err')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Group Chat'),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupChatScreen(groupId: group.id),
                  ),
                ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface),
        icon: const Icon(Icons.analytics_outlined),
        label: const Text('View Analytics'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupAnalyticsScreen(groupId: group.id),
          ),
        ),
      ),
    ),
  ],
);
}

  Widget _buildMemberList(BuildContext context) {
    return InfoCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: group.members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = group.members[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withAlpha((0.1 * 255).round()),
              child: Text(
                member.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            title: Text(member),
          );
        },
      ),
    );
  }
}
