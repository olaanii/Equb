import 'package:equb/models/admin_audit.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/admin_providers.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BulkUserManagementScreen extends ConsumerStatefulWidget {
  const BulkUserManagementScreen({super.key});

  @override
  ConsumerState<BulkUserManagementScreen> createState() =>
      _BulkUserManagementScreenState();
}

class _BulkUserManagementScreenState
    extends ConsumerState<BulkUserManagementScreen> {
  final Set<String> _selectedUsers = {};
  BulkOperationType _operationType = BulkOperationType.roleUpdate;
  UserRole _selectedRole = UserRole.member;
  String _operationReason = '';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk User Management'),
        actions: [
          if (_selectedUsers.isNotEmpty)
            TextButton(
              onPressed: _isProcessing ? null : _performBulkOperation,
              child:
                  _isProcessing
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Execute'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Operation configuration
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bulk Operation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  // Operation type selector
                  DropdownButtonFormField<BulkOperationType>(
                    value: _operationType,
                    decoration: const InputDecoration(
                      labelText: 'Operation Type',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        BulkOperationType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _operationType = value);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Role selector (only for role updates)
                  if (_operationType == BulkOperationType.roleUpdate)
                    DropdownButtonFormField<UserRole>(
                      value: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'New Role',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          UserRole.values.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role.displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                    ),

                  // Reason input
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Reason for operation',
                      hintText: 'Enter reason for audit trail',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged:
                        (value) => setState(() => _operationReason = value),
                  ),

                  const SizedBox(height: 16),

                  // Selected users summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people, color: scheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedUsers.length} users selected',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _clearSelection,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User list
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    // Fetch real users from Firebase via allUsersProvider
    final usersAsync = ref.watch(allUsersProvider);

    return usersAsync.when(
      data:
          (users) => ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isSelected = _selectedUsers.contains(user.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedUsers.add(user.id);
                      } else {
                        _selectedUsers.remove(user.id);
                      }
                    });
                  },
                  title: Text(user.displayName),
                  subtitle: Text('${user.email} • ${user.role.displayName}'),
                  secondary: CircleAvatar(
                    child: Text(user.displayName[0].toUpperCase()),
                  ),
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text('Failed to load users: $error'),
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

  void _clearSelection() {
    setState(() => _selectedUsers.clear());
  }

  Future<void> _performBulkOperation() async {
    if (_selectedUsers.isEmpty) return;
    if (_operationReason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for this operation'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final adminService = ref.read(advancedAdminServiceProvider);
      final currentUser = ref.read(currentUserProvider).value;

      if (currentUser == null) {
        throw Exception('Admin user not found');
      }

      BulkOperationResult result;

      switch (_operationType) {
        case BulkOperationType.roleUpdate:
          result = await adminService.bulkUpdateUserRoles(
            adminId: currentUser.id,
            userIds: _selectedUsers.toList(),
            newRole: _selectedRole,
            reason: _operationReason,
          );
          break;

        case BulkOperationType.suspension:
          result = await adminService.bulkSuspendUsers(
            adminId: currentUser.id,
            userIds: _selectedUsers.toList(),
            reason: _operationReason,
            suspensionEnd: null, // Could add UI for this
          );
          break;
      }

      if (mounted) {
        setState(() => _selectedUsers.clear());

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Bulk Operation Completed'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total users processed: ${result.totalCount}'),
                    Text('Successful: ${result.successCount}'),
                    Text('Failed: ${result.failureCount}'),
                    if (result.hasErrors) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Errors:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView(
                          children:
                              result.errors
                                  .map(
                                    (error) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        '• $error',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bulk operation failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

enum BulkOperationType { roleUpdate, suspension }

extension BulkOperationTypeX on BulkOperationType {
  String get label {
    switch (this) {
      case BulkOperationType.roleUpdate:
        return 'Update User Roles';
      case BulkOperationType.suspension:
        return 'Suspend Users';
    }
  }
}
