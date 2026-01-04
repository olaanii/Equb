import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportComplianceScreen extends ConsumerWidget {
  const SupportComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Support & Compliance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(theme, 'Help Center'),
          InfoCard(
            child: Column(
              children: [
                _buildActionTile(
                  theme,
                  icon: Icons.chat_bubble_outline,
                  title: 'Chat with Support',
                  subtitle: 'Real-time help from our agents',
                  onTap: () {},
                ),
                const Divider(),
                _buildActionTile(
                  theme,
                  icon: Icons.help_outline,
                  title: 'FAQs & Articles',
                  subtitle: 'Detailed guides on using Equb',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'Verification & Docs'),
          InfoCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.success,
                  ),
                  title: const Text('KYC Status'),
                  subtitle: const Text('Fully Verified • Renewed Aug 2024'),
                  onTap: () {},
                ),
                const Divider(),
                _buildActionTile(
                  theme,
                  icon: Icons.article_outlined,
                  title: 'Account Statements',
                  subtitle: 'Download monthly PDF exports',
                  onTap: () {},
                ),
                const Divider(),
                _buildActionTile(
                  theme,
                  icon: Icons.gavel_outlined,
                  title: 'Privacy & Terms',
                  subtitle: 'Review legal agreements',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
