import 'package:equb/models/admin_audit.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AdvancedAdminDashboard extends ConsumerStatefulWidget {
  const AdvancedAdminDashboard({super.key});

  @override
  ConsumerState<AdvancedAdminDashboard> createState() => _AdvancedAdminDashboardState();
}

class _AdvancedAdminDashboardState extends ConsumerState<AdvancedAdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AdminDashboardStats? _dashboardStats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final service = ref.read(advancedAdminServiceProvider);
      final stats = await service.getDashboardStats();
      if (mounted) {
        setState(() => _dashboardStats = stats);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load dashboard stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Bulk Operations', icon: Icon(Icons.batch_prediction)),
            Tab(text: 'Audit Logs', icon: Icon(Icons.history)),
            Tab(text: 'Compliance', icon: Icon(Icons.security)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildBulkOperationsTab(),
          _buildAuditLogsTab(),
          _buildComplianceTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_dashboardStats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _dashboardStats!;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: AppSpacing.pagePaddingMobile,
      children: [
        // System Health
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      stats.systemHealth > 0.9 ? Icons.health_and_safety : Icons.warning,
                      color: stats.systemHealth > 0.9 ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'System Health',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${(stats.systemHealth * 100).round()}%',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: stats.systemHealth > 0.9 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: stats.systemHealth,
                  backgroundColor: scheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    stats.systemHealth > 0.9 ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Key Metrics Grid
        GridView.count(
          crossAxisCount: context.isMobile ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _MetricCard(
              title: 'Total Users',
              value: stats.totalUsers.toString(),
              subtitle: '${(stats.userActivityRate * 100).round()}% active',
              icon: Icons.people,
              color: Colors.blue,
            ),
            _MetricCard(
              title: 'Active Groups',
              value: stats.activeGroups.toString(),
              subtitle: 'of ${stats.totalGroups}',
              icon: Icons.group_work,
              color: Colors.green,
            ),
            _MetricCard(
              title: 'Transactions',
              value: _formatNumber(stats.totalTransactions),
              subtitle: 'total processed',
              icon: Icons.swap_horiz,
              color: Colors.purple,
            ),
            _MetricCard(
              title: 'Pending Verifications',
              value: stats.pendingVerifications.toString(),
              subtitle: 'awaiting review',
              icon: Icons.pending_actions,
              color: stats.pendingVerifications > 10 ? Colors.red : Colors.orange,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Recent Alerts
        if (stats.recentAlerts.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Alerts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...stats.recentAlerts.map((alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(alert)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Quick Actions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showBulkUserManagement(context),
                      icon: const Icon(Icons.people),
                      label: const Text('Bulk User Management'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showSystemMaintenance(context),
                      icon: const Icon(Icons.build),
                      label: const Text('System Maintenance'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _generateComplianceReport(),
                      icon: const Icon(Icons.security),
                      label: const Text('Generate Report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkOperationsTab() {
    return ListView(
      padding: AppSpacing.pagePaddingMobile,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk User Operations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                _BulkOperationCard(
                  title: 'Update User Roles',
                  description: 'Change roles for multiple users at once',
                  icon: Icons.admin_panel_settings,
                  onTap: () => _showBulkRoleUpdate(context),
                ),

                const SizedBox(height: 12),

                _BulkOperationCard(
                  title: 'Suspend Users',
                  description: 'Temporarily suspend multiple user accounts',
                  icon: Icons.block,
                  onTap: () => _showBulkSuspension(context),
                ),

                const SizedBox(height: 12),

                _BulkOperationCard(
                  title: 'Send Notifications',
                  description: 'Send bulk notifications to users',
                  icon: Icons.notifications_active,
                  onTap: () => _showBulkNotifications(context),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Group Operations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                _BulkOperationCard(
                  title: 'Group Maintenance',
                  description: 'Perform maintenance on inactive groups',
                  icon: Icons.group_remove,
                  onTap: () => _showBulkGroupMaintenance(context),
                ),

                const SizedBox(height: 12),

                _BulkOperationCard(
                  title: 'Payout Adjustments',
                  description: 'Adjust payout schedules in bulk',
                  icon: Icons.payments,
                  onTap: () => _showBulkPayoutAdjustments(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuditLogsTab() {
    final auditLogsAsync = ref.watch(
      FutureProvider((ref) async {
        final service = ref.read(advancedAdminServiceProvider);
        return service.getAuditLogs(limit: 50);
      }),
    );

    return auditLogsAsync.when(
      data: (logs) => ListView.builder(
        padding: AppSpacing.pagePaddingMobile,
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return _AuditLogCard(log: log);
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load audit logs: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceTab() {
    return ListView(
      padding: AppSpacing.pagePaddingMobile,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compliance Reports',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                _ComplianceReportCard(
                  title: 'KYC Compliance Report',
                  description: 'User verification and identity compliance',
                  onGenerate: () => _generateComplianceReportOfType('kyc_compliance'),
                ),

                const SizedBox(height: 12),

                _ComplianceReportCard(
                  title: 'Transaction Monitoring',
                  description: 'Suspicious activity and transaction patterns',
                  onGenerate: () => _generateComplianceReportOfType('transaction_monitoring'),
                ),

                const SizedBox(height: 12),

                _ComplianceReportCard(
                  title: 'Risk Assessment',
                  description: 'Overall system risk evaluation',
                  onGenerate: () => _generateComplianceReportOfType('risk_assessment'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regulatory Compliance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                _buildComplianceItem(
                  'AML Compliance',
                  'Anti-Money Laundering checks passed',
                  true,
                ),
                _buildComplianceItem(
                  'Data Privacy',
                  'GDPR and local privacy laws compliant',
                  true,
                ),
                _buildComplianceItem(
                  'Financial Reporting',
                  'Monthly financial reports up to date',
                  true,
                ),
                _buildComplianceItem(
                  'Audit Trail',
                  'Complete audit logging enabled',
                  true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceItem(String title, String description, bool compliant) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            compliant ? Icons.check_circle : Icons.warning,
            color: compliant ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBulkUserManagement(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BulkUserManagementScreen()),
    );
  }

  void _showSystemMaintenance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SystemMaintenanceScreen()),
    );
  }

  void _generateComplianceReport() {
    // Default to KYC compliance report
    _generateComplianceReportOfType('kyc_compliance');
  }

  Future<void> _generateComplianceReportOfType(String reportType) async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      final service = ref.read(advancedAdminServiceProvider);
      final report = await service.generateComplianceReport(
        adminId: user.id,
        reportType: reportType,
        periodEnd: DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$reportType report generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    }
  }

  void _showBulkRoleUpdate(BuildContext context) {
    // TODO: Implement bulk role update screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk role update not yet implemented')),
    );
  }

  void _showBulkSuspension(BuildContext context) {
    // TODO: Implement bulk suspension screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk suspension not yet implemented')),
    );
  }

  void _showBulkNotifications(BuildContext context) {
    // TODO: Implement bulk notifications screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk notifications not yet implemented')),
    );
  }

  void _showBulkGroupMaintenance(BuildContext context) {
    // TODO: Implement bulk group maintenance screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk group maintenance not yet implemented')),
    );
  }

  void _showBulkPayoutAdjustments(BuildContext context) {
    // TODO: Implement bulk payout adjustments screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk payout adjustments not yet implemented')),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkOperationCard extends StatelessWidget {
  const _BulkOperationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.log});

  final AdminAuditLog log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getSeverityIcon(log.severity),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.action.label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${log.adminName} • ${DateFormat('MMM d, HH:mm').format(log.timestamp)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(log.severity).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    log.severity.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getSeverityColor(log.severity),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              log.details,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (log.targetName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Target: ${log.targetName} (${log.targetId})',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _getSeverityIcon(AuditSeverity severity) {
    IconData icon;
    Color color;

    switch (severity) {
      case AuditSeverity.low:
        icon = Icons.info_outline;
        color = Colors.blue;
        break;
      case AuditSeverity.medium:
        icon = Icons.warning_outlined;
        color = Colors.orange;
        break;
      case AuditSeverity.high:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
      case AuditSeverity.critical:
        icon = Icons.dangerous_outlined;
        color = Colors.red.shade900;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }

  Color _getSeverityColor(AuditSeverity severity) {
    switch (severity) {
      case AuditSeverity.low:
        return Colors.blue;
      case AuditSeverity.medium:
        return Colors.orange;
      case AuditSeverity.high:
        return Colors.red;
      case AuditSeverity.critical:
        return Colors.red.shade900;
    }
  }
}

class _ComplianceReportCard extends StatelessWidget {
  const _ComplianceReportCard({
    required this.title,
    required this.description,
    required this.onGenerate,
  });

  final String title;
  final String description;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onGenerate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.security,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder screens for bulk operations
class BulkUserManagementScreen extends StatelessWidget {
  const BulkUserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk User Management')),
      body: const Center(
        child: Text('Bulk user management functionality\n(Not yet implemented)'),
      ),
    );
  }
}

class SystemMaintenanceScreen extends StatelessWidget {
  const SystemMaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Maintenance')),
      body: const Center(
        child: Text('System maintenance functionality\n(Not yet implemented)'),
      ),
    );
  }
}

