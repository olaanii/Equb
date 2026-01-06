import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemMaintenanceScreen extends ConsumerStatefulWidget {
  const SystemMaintenanceScreen({super.key});

  @override
  ConsumerState<SystemMaintenanceScreen> createState() => _SystemMaintenanceScreenState();
}

class _SystemMaintenanceScreenState extends ConsumerState<SystemMaintenanceScreen> {
  bool _isProcessing = false;
  String _selectedMaintenanceType = 'database_cleanup';

  final Map<String, MaintenanceOption> _maintenanceOptions = {
    'database_cleanup': MaintenanceOption(
      title: 'Database Cleanup',
      description: 'Remove orphaned records and optimize database performance',
      icon: Icons.cleaning_services,
      estimatedDuration: '5-15 minutes',
      riskLevel: 'Low',
    ),
    'cache_invalidation': MaintenanceOption(
      title: 'Cache Invalidation',
      description: 'Clear application caches to refresh data',
      icon: Icons.cached,
      estimatedDuration: '1-3 minutes',
      riskLevel: 'Low',
    ),
    'backup_verification': MaintenanceOption(
      title: 'Backup Verification',
      description: 'Verify integrity of recent backups',
      icon: Icons.backup,
      estimatedDuration: '2-5 minutes',
      riskLevel: 'Low',
    ),
    'index_rebuild': MaintenanceOption(
      title: 'Index Rebuild',
      description: 'Rebuild database indexes for better performance',
      icon: Icons.table_chart,
      estimatedDuration: '10-30 minutes',
      riskLevel: 'Medium',
    ),
    'log_rotation': MaintenanceOption(
      title: 'Log Rotation',
      description: 'Archive old logs and clean up log storage',
      icon: Icons.rotate_right,
      estimatedDuration: '1-2 minutes',
      riskLevel: 'Low',
    ),
    'emergency_shutdown': MaintenanceOption(
      title: 'Emergency Shutdown',
      description: 'Initiate emergency system shutdown (use only in critical situations)',
      icon: Icons.emergency,
      estimatedDuration: 'Immediate',
      riskLevel: 'Critical',
      requiresConfirmation: true,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Maintenance'),
        backgroundColor: _getRiskColor(_maintenanceOptions[_selectedMaintenanceType]!.riskLevel),
      ),
      body: Column(
        children: [
          // Warning banner for high-risk operations
          if (_isHighRiskOperation()) _buildRiskWarning(),

          // Maintenance options
          Expanded(
            child: ListView(
              padding: AppSpacing.pagePaddingMobile,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Maintenance Tasks',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        ..._maintenanceOptions.entries.map((entry) {
                          final option = entry.value;
                          final isSelected = entry.key == _selectedMaintenanceType;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => setState(() => _selectedMaintenanceType = entry.key),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? scheme.primary : scheme.outline,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected ? scheme.primary.withOpacity(0.05) : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _getRiskColor(option.riskLevel).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        option.icon,
                                        color: _getRiskColor(option.riskLevel),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                option.title,
                                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getRiskColor(option.riskLevel).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  option.riskLevel,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getRiskColor(option.riskLevel),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            option.description,
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: scheme.onSurface.withOpacity(0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule,
                                                size: 14,
                                                color: scheme.onSurface.withOpacity(0.6),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Duration: ${option.estimatedDuration}',
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                  color: scheme.onSurface.withOpacity(0.6),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: scheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Maintenance status (if running)
                if (_isProcessing) _buildMaintenanceProgress(),

                // Action buttons
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_maintenanceOptions[_selectedMaintenanceType]!.requiresConfirmation)
                          ...[
                            const Text(
                              '⚠️ This operation requires special confirmation',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _performMaintenance,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(_maintenanceOptions[_selectedMaintenanceType]!.icon),
                          label: Text(
                            _isProcessing ? 'Running...' : 'Start Maintenance',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getRiskColor(_maintenanceOptions[_selectedMaintenanceType]!.riskLevel),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),

                        const SizedBox(height: 12),

                        OutlinedButton(
                          onPressed: _showMaintenanceHistory,
                          child: const Text('View Maintenance History'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.red.withOpacity(0.1),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'High-risk operation selected. Please ensure you understand the consequences before proceeding.',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceProgress() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance in Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Please wait while the system performs maintenance operations...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  bool _isHighRiskOperation() {
    final riskLevel = _maintenanceOptions[_selectedMaintenanceType]!.riskLevel;
    return riskLevel == 'High' || riskLevel == 'Critical';
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.red;
      case 'Critical':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }

  Future<void> _performMaintenance() async {
    final option = _maintenanceOptions[_selectedMaintenanceType]!;

    // Special confirmation for critical operations
    if (option.requiresConfirmation) {
      final confirmed = await _showConfirmationDialog(
        title: 'Confirm Critical Operation',
        content: 'Are you sure you want to perform "${option.title}"? This operation cannot be undone and may affect system availability.',
        confirmText: 'Yes, proceed with emergency shutdown',
      );

      if (!confirmed) return;
    }

    setState(() => _isProcessing = true);

    try {
      final adminService = ref.read(advancedAdminServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;

      if (currentUser == null) {
        throw Exception('Admin user not found');
      }

      final success = await adminService.performSystemMaintenance(
        adminId: currentUser.id,
        maintenanceType: _selectedMaintenanceType,
        parameters: {
          'initiatedBy': currentUser.displayName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Maintenance completed successfully'
                : 'Maintenance failed - check logs for details'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Maintenance failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showMaintenanceHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MaintenanceHistoryScreen()),
    );
  }
}

class MaintenanceOption {
  const MaintenanceOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.estimatedDuration,
    required this.riskLevel,
    this.requiresConfirmation = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final String estimatedDuration;
  final String riskLevel;
  final bool requiresConfirmation;
}

// Placeholder screen for maintenance history
class MaintenanceHistoryScreen extends StatelessWidget {
  const MaintenanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance History')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.build),
              title: Text('Maintenance Task ${index + 1}'),
              subtitle: Text('Completed on ${DateTime.now().subtract(Duration(days: index)).toString().split(' ')[0]}'),
              trailing: const Icon(Icons.check_circle, color: Colors.green),
            ),
          );
        },
      ),
    );
  }
}

