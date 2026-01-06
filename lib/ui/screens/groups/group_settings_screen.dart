import 'package:equb/models/group_member.dart';
import 'package:equb/models/group_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({
    super.key,
    required this.group,
  });

  final GroupModel group;

  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  GroupSettings _settings = const GroupSettings();
  List<GroupMember> _members = [];
  List<GroupInvitation> _pendingInvitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final groupManagementService = ref.read(groupManagementServiceProvider);

      final members = await groupManagementService.getGroupMembers(widget.group.id);
      final invitations = await groupManagementService.getPendingInvitations(widget.group.id);

      if (mounted) {
        setState(() {
          _members = members;
          _pendingInvitations = invitations;
          _settings = widget.group.settings ?? const GroupSettings();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group data: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'General', icon: Icon(Icons.settings)),
            Tab(text: 'Members', icon: Icon(Icons.people)),
            Tab(text: 'Invitations', icon: Icon(Icons.person_add)),
            Tab(text: 'Advanced', icon: Icon(Icons.admin_panel_settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralSettings(),
          _buildMembersManagement(),
          _buildInvitationsManagement(),
          _buildAdvancedSettings(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return ListView(
      padding: AppSpacing.pagePaddingMobile,
      children: [
        // Group Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Group Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: widget.group.name,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // TODO: Update group name
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: widget.group.description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    // TODO: Update group description
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Contribution Settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contribution Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: widget.group.contributionAmount?.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Contribution Amount (ETB)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    // TODO: Update contribution amount
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: widget.group.frequencyDays.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Contribution Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('Daily')),
                    DropdownMenuItem(value: '7', child: Text('Weekly')),
                    DropdownMenuItem(value: '14', child: Text('Bi-weekly')),
                    DropdownMenuItem(value: '30', child: Text('Monthly')),
                  ],
                  onChanged: (value) {
                    // TODO: Update frequency
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Privacy Settings
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy & Access',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Public Group'),
                  subtitle: const Text('Allow anyone to find and join this group'),
                  value: _settings.isPublic,
                  onChanged: (value) {
                    setState(() => _settings = _settings.copyWith(isPublic: value));
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text('Require Approval'),
                  subtitle: const Text('New members need admin approval to join'),
                  value: _settings.requiresApproval,
                  onChanged: (value) {
                    setState(() => _settings = _settings.copyWith(requiresApproval: value));
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersManagement() {
    return ListView.builder(
      padding: AppSpacing.pagePaddingMobile,
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(member.userId[0].toUpperCase()),
            ),
            title: Text('Member ${member.userId}'), // TODO: Get user name
            subtitle: Text(member.role.displayName),
            trailing: PopupMenuButton<String>(
              onSelected: (action) => _handleMemberAction(member, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'change_role',
                  child: Text('Change Role'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove from Group'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvitationsManagement() {
    return ListView(
      padding: AppSpacing.pagePaddingMobile,
      children: [
        // Invite new member button
        ElevatedButton.icon(
          onPressed: _showInviteDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('Invite New Member'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),

        const SizedBox(height: 16),

        // Pending invitations
        if (_pendingInvitations.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No pending invitations'),
            ),
          )
        else
          ..._pendingInvitations.map((invitation) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: Text('Invitation to ${invitation.invitedUserId}'),
              subtitle: Text('Sent ${invitation.createdAt.toString().split(' ')[0]}'),
              trailing: TextButton(
                onPressed: () => _cancelInvitation(invitation.id),
                child: const Text('Cancel'),
              ),
            ),
          )),
      ],
    );
  }

  Widget _buildAdvancedSettings() {
    return ListView(
      padding: AppSpacing.pagePaddingMobile,
      children: [
        // Member Limits
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member Limits',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _settings.maxMembers.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Maximum Members',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final maxMembers = int.tryParse(value) ?? 50;
                    setState(() => _settings = _settings.copyWith(maxMembers: maxMembers));
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Advanced Options
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advanced Options',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Auto-approve Invitations'),
                  subtitle: const Text('Automatically accept member requests'),
                  value: _settings.autoApproveInvitations,
                  onChanged: (value) {
                    setState(() => _settings = _settings.copyWith(autoApproveInvitations: value));
                    _saveSettings();
                  },
                ),
                SwitchListTile(
                  title: const Text('Allow Guest Contributions'),
                  subtitle: const Text('Let non-members contribute to payouts'),
                  value: _settings.allowGuestContributions,
                  onChanged: (value) {
                    setState(() => _settings = _settings.copyWith(allowGuestContributions: value));
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Danger Zone
        Card(
          color: Colors.red.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Danger Zone',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'These actions cannot be undone. Please be certain.',
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _showDeleteGroupDialog,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Delete Group'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    try {
      final groupManagementService = ref.read(groupManagementServiceProvider);
      final user = ref.read(currentUserProvider).value;

      if (user == null) return;

      await groupManagementService.updateGroupSettings(
        groupId: widget.group.id,
        settings: _settings,
        updatedBy: user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  void _handleMemberAction(GroupMember member, String action) {
    switch (action) {
      case 'change_role':
        _showChangeRoleDialog(member);
        break;
      case 'remove':
        _showRemoveMemberDialog(member);
        break;
    }
  }

  void _showChangeRoleDialog(GroupMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Member Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: GroupMemberRole.values.map((role) {
            return RadioListTile<GroupMemberRole>(
              title: Text(role.displayName),
              subtitle: Text(role.description),
              value: role,
              groupValue: member.role,
              onChanged: (value) async {
                if (value != null) {
                  await _changeMemberRole(member, value);
                  if (mounted) Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _changeMemberRole(GroupMember member, GroupMemberRole newRole) async {
    try {
      final groupManagementService = ref.read(groupManagementServiceProvider);
      final user = ref.read(currentUserProvider).value;

      if (user == null) return;

      await groupManagementService.changeMemberRole(
        groupId: widget.group.id,
        memberId: member.userId,
        newRole: newRole,
        changedBy: user.id,
      );

      // Refresh members list
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member role updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change role: $e')),
        );
      }
    }
  }

  void _showRemoveMemberDialog(GroupMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _removeMember(member);
              if (mounted) Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(GroupMember member) async {
    try {
      final groupManagementService = ref.read(groupManagementServiceProvider);
      final user = ref.read(currentUserProvider).value;

      if (user == null) return;

      await groupManagementService.removeMember(
        groupId: widget.group.id,
        memberId: member.userId,
        removedBy: user.id,
      );

      // Refresh members list
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed from group')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove member: $e')),
        );
      }
    }
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite New Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email or Phone',
                hintText: 'user@example.com or +251911234567',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Personal Message (Optional)',
                hintText: 'Join our savings group!',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _sendInvitation(emailController.text, messageController.text);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation(String contact, String message) async {
    try {
      final groupManagementService = ref.read(groupManagementServiceProvider);
      final user = ref.read(currentUserProvider).value;

      if (user == null) return;

      // For now, treat contact as user ID. In real implementation,
      // this would resolve email/phone to user ID
      final invitedUserId = contact; // TODO: Resolve contact to user ID

      await groupManagementService.inviteUserToGroup(
        groupId: widget.group.id,
        invitedUserId: invitedUserId,
        invitedBy: user.id,
        message: message.isNotEmpty ? message : null,
      );

      // Refresh invitations list
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invitation: $e')),
        );
      }
    }
  }

  Future<void> _cancelInvitation(String invitationId) async {
    // TODO: Implement cancel invitation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cancel invitation not yet implemented')),
    );
  }

  void _showDeleteGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'This action cannot be undone. All group data, including member information, '
          'contributions, and chat history will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement group deletion
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Group deletion not yet implemented')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Group'),
          ),
        ],
      ),
    );
  }
}

