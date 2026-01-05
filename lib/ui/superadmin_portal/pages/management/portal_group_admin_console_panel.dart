import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

class PortalGroupAdminConsolePanel extends StatefulWidget {
  const PortalGroupAdminConsolePanel({super.key});

  @override
  State<PortalGroupAdminConsolePanel> createState() =>
      _PortalGroupAdminConsolePanelState();
}

class _PortalGroupAdminConsolePanelState
    extends State<PortalGroupAdminConsolePanel> {
  late final List<_PortalGroup> _groups = <_PortalGroup>[
    _PortalGroup(
      id: 'grp_001',
      name: 'Addis Savings 12',
      status: _GroupStatus.active,
      members: const [
        _GroupMember(uid: 'user_9281', role: _MemberRole.member),
        _GroupMember(uid: 'user_1142', role: _MemberRole.member),
        _GroupMember(uid: 'user_5530', role: _MemberRole.moderator),
      ],
      flags: <String, bool>{
        'allowDeposits': true,
        'allowWithdrawals': true,
        'allowInvites': true,
      },
    ),
    _PortalGroup(
      id: 'grp_014',
      name: 'Dire Dawa Equb',
      status: _GroupStatus.paused,
      members: const [
        _GroupMember(uid: 'user_7788', role: _MemberRole.owner),
        _GroupMember(uid: 'user_2299', role: _MemberRole.member),
      ],
      flags: <String, bool>{
        'allowDeposits': false,
        'allowWithdrawals': false,
        'allowInvites': false,
      },
    ),
    _PortalGroup(
      id: 'grp_031',
      name: 'Hawassa Friends',
      status: _GroupStatus.active,
      members: const [
        _GroupMember(uid: 'user_3001', role: _MemberRole.owner),
        _GroupMember(uid: 'user_3002', role: _MemberRole.member),
        _GroupMember(uid: 'user_3003', role: _MemberRole.member),
        _GroupMember(uid: 'user_3004', role: _MemberRole.member),
      ],
      flags: <String, bool>{
        'allowDeposits': true,
        'allowWithdrawals': true,
        'allowInvites': true,
      },
    ),
  ];

  int _selectedIndex = 0;

  void _select(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final selected = _groups.isEmpty
        ? null
        : _groups[_selectedIndex.clamp(0, _groups.length - 1)];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Group admin console',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.groups_2_outlined, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Inspect groups, membership, and safety flags (UI-first).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_groups.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('No groups.', style: theme.textTheme.bodySmall),
              )
            else
              context.isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 420,
                          child: _GroupList(
                            groups: _groups,
                            selectedIndex: _selectedIndex,
                            onSelect: _select,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _GroupDetail(
                            group: selected!,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _GroupList(
                          groups: _groups,
                          selectedIndex: _selectedIndex,
                          onSelect: _select,
                        ),
                        const SizedBox(height: 12),
                        _GroupDetail(
                          group: selected!,
                          onChanged: () => setState(() {}),
                        ),
                      ],
                    ),
          ],
        ),
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_PortalGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxHeight = (context.screenSize.height * 0.58).clamp(260.0, 720.0);

    return Card(
      elevation: 0,
      color: scheme.surfaceVariant,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final g = groups[index];
            final isSelected = index == selectedIndex;

            return ListTile(
              selected: isSelected,
              selectedTileColor: scheme.surface.withOpacity(0.7),
              onTap: () => onSelect(index),
              leading: CircleAvatar(
                child: Text(g.name.isEmpty ? '?' : g.name.characters.first),
              ),
              title: Text(
                g.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              subtitle: Text('${g.id} • ${g.members.length} members'),
              trailing: _GroupStatusChip(status: g.status),
            );
          },
        ),
      ),
    );
  }
}

class _GroupDetail extends StatelessWidget {
  const _GroupDetail({required this.group, required this.onChanged});

  final _PortalGroup group;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final membersMaxHeight = (context.screenSize.height * 0.34)
        .clamp(180.0, context.isDesktop ? 420.0 : 320.0);

    final membersByRole = <_MemberRole, int>{
      for (final role in _MemberRole.values) role: 0,
    };
    for (final m in group.members) {
      membersByRole[m.role] = (membersByRole[m.role] ?? 0) + 1;
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${group.name} • ${group.id}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _GroupStatusChip(status: group.status),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.people_outline,
                  label: '${group.members.length} members',
                ),
                _MetaChip(
                  icon: Icons.verified_user_outlined,
                  label: '${membersByRole[_MemberRole.owner]} owner',
                ),
                _MetaChip(
                  icon: Icons.security_outlined,
                  label: '${membersByRole[_MemberRole.moderator]} moderators',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Safety flags',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final entry in group.flags.entries)
                  FilterChip(
                    label: Text(entry.key),
                    selected: entry.value,
                    onSelected: (v) {
                      group.flags[entry.key] = v;
                      onChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Members',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.7)),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: membersMaxHeight),
                child: ListView.builder(
                  itemCount: group.members.length,
                  itemBuilder: (context, index) {
                    final m = group.members[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline),
                      title: Text(m.uid),
                      trailing: _RoleChip(role: m.role),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('UI-only: backend action not wired'),
                    ),
                  );
                },
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Take action'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _GroupStatusChip extends StatelessWidget {
  const _GroupStatusChip({required this.status});

  final _GroupStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      _GroupStatus.active => 'Active',
      _GroupStatus.paused => 'Paused',
      _GroupStatus.archived => 'Archived',
    };

    final icon = switch (status) {
      _GroupStatus.active => Icons.check_circle_outline,
      _GroupStatus.paused => Icons.pause_circle_outline,
      _GroupStatus.archived => Icons.archive_outlined,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final _MemberRole role;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      _MemberRole.owner => 'Owner',
      _MemberRole.moderator => 'Mod',
      _MemberRole.member => 'Member',
    };

    final icon = switch (role) {
      _MemberRole.owner => Icons.stars_outlined,
      _MemberRole.moderator => Icons.shield_outlined,
      _MemberRole.member => Icons.person_outline,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

enum _GroupStatus { active, paused, archived }

enum _MemberRole { owner, moderator, member }

class _PortalGroup {
  _PortalGroup({
    required this.id,
    required this.name,
    required this.status,
    required this.members,
    required this.flags,
  });

  final String id;
  final String name;
  _GroupStatus status;
  final List<_GroupMember> members;
  final Map<String, bool> flags;
}

class _GroupMember {
  const _GroupMember({required this.uid, required this.role});

  final String uid;
  final _MemberRole role;
}
