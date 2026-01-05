import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

class PortalSupportInboxPanel extends StatefulWidget {
  const PortalSupportInboxPanel({super.key});

  @override
  State<PortalSupportInboxPanel> createState() => _PortalSupportInboxPanelState();
}

class _PortalSupportInboxPanelState extends State<PortalSupportInboxPanel> {
  late final List<_SupportTicket> _tickets = <_SupportTicket>[
    _SupportTicket(
      id: 'SUP-1024',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      status: _TicketStatus.open,
      priority: _TicketPriority.high,
      customerLabel: 'user_9281',
      subject: 'Deposit not reflected',
      summary: 'CBE Birr transaction succeeded but balance not updated.',
      messages: const [
        _TicketMessage(
          from: 'customer',
          body: 'My deposit shows success but wallet did not change.',
        ),
        _TicketMessage(
          from: 'support',
          body: 'Thanks. We are checking the payment webhook logs.',
        ),
      ],
    ),
    _SupportTicket(
      id: 'SUP-1021',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      status: _TicketStatus.pending,
      priority: _TicketPriority.normal,
      customerLabel: 'user_1142',
      subject: 'Unable to join group',
      summary: 'App says “Not eligible” even though invite was shared.',
      messages: const [
        _TicketMessage(
          from: 'customer',
          body: 'I can’t join the group. It keeps rejecting me.',
        ),
      ],
    ),
    _SupportTicket(
      id: 'SUP-1013',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      status: _TicketStatus.resolved,
      priority: _TicketPriority.low,
      customerLabel: 'user_5530',
      subject: 'Wrong phone number on profile',
      summary: 'Customer requests profile phone update.',
      messages: const [
        _TicketMessage(
          from: 'customer',
          body: 'My phone number is wrong; please update it.',
        ),
        _TicketMessage(
          from: 'support',
          body: 'Resolved after identity verification.',
        ),
      ],
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

    final maxPaneHeight =
        (context.screenSize.height * 0.58).clamp(260.0, 720.0);

    final selected = _tickets.isEmpty
        ? null
        : _tickets[_selectedIndex.clamp(0, _tickets.length - 1)];

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
                    'Support inbox',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.support_agent_outlined,
                    color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Triaging customer tickets (UI-first). Backend wiring can load/stream tickets later.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (_tickets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('No tickets.', style: theme.textTheme.bodySmall),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final useTwoPane =
                      context.isDesktop && constraints.maxWidth >= 980;

                  if (useTwoPane) {
                    return SizedBox(
                      height: maxPaneHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 420,
                            child: _TicketList(
                              tickets: _tickets,
                              selectedIndex: _selectedIndex,
                              onSelect: _select,
                              maxHeight: maxPaneHeight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TicketDetail(ticket: selected!),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      _TicketList(
                        tickets: _tickets,
                        selectedIndex: _selectedIndex,
                        onSelect: _select,
                        maxHeight: maxPaneHeight,
                      ),
                      const SizedBox(height: 12),
                      _TicketDetail(ticket: selected!),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.selectedIndex,
    required this.onSelect,
    this.maxHeight,
  });

  final List<_SupportTicket> tickets;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final resolvedMaxHeight =
        maxHeight ?? (context.screenSize.height * 0.58).clamp(260.0, 720.0);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: resolvedMaxHeight),
        child: ListView.separated(
          itemCount: tickets.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final t = tickets[index];
            final isSelected = index == selectedIndex;

            return ListTile(
              selected: isSelected,
              selectedTileColor:
                  Theme.of(context).colorScheme.surface.withOpacity(0.7),
              onTap: () => onSelect(index),
              leading: CircleAvatar(
                child: Text(t.customerLabel.isEmpty
                    ? '?'
                    : t.customerLabel.characters.first.toUpperCase()),
              ),
              title: Text(
                t.subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              subtitle: Text(
                t.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(status: t.status),
                  const SizedBox(height: 6),
                  _PriorityChip(priority: t.priority),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TicketDetail extends StatelessWidget {
  const _TicketDetail({required this.ticket});

  final _SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceVariant,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ticket.id} • ${ticket.customerLabel}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(status: ticket.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.subject,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(ticket.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PriorityChip(priority: ticket.priority),
                _MetaChip(
                  icon: Icons.schedule_outlined,
                  label: 'Updated ${_formatAge(ticket.updatedAt)} ago',
                ),
                _MetaChip(
                  icon: Icons.event_outlined,
                  label: 'Created ${_formatAge(ticket.createdAt)} ago',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Conversation',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final msg in ticket.messages) ...[
              _MessageBubble(message: msg),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isSupport = message.from == 'support';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSupport ? scheme.surface : scheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSupport ? 'Support' : 'Customer',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(message.body, style: theme.textTheme.bodyMedium),
        ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      _TicketStatus.open => 'Open',
      _TicketStatus.pending => 'Pending',
      _TicketStatus.resolved => 'Resolved',
    };

    final icon = switch (status) {
      _TicketStatus.open => Icons.mark_email_unread_outlined,
      _TicketStatus.pending => Icons.hourglass_bottom_outlined,
      _TicketStatus.resolved => Icons.task_alt_outlined,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final _TicketPriority priority;

  @override
  Widget build(BuildContext context) {
    final label = switch (priority) {
      _TicketPriority.low => 'Low',
      _TicketPriority.normal => 'Normal',
      _TicketPriority.high => 'High',
    };

    final icon = switch (priority) {
      _TicketPriority.low => Icons.arrow_downward_outlined,
      _TicketPriority.normal => Icons.drag_handle_outlined,
      _TicketPriority.high => Icons.arrow_upward_outlined,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

String _formatAge(DateTime at) {
  final delta = DateTime.now().difference(at);
  if (delta.inDays >= 1) return '${delta.inDays}d';
  if (delta.inHours >= 1) return '${delta.inHours}h';
  if (delta.inMinutes >= 1) return '${delta.inMinutes}m';
  return '${delta.inSeconds}s';
}

enum _TicketStatus { open, pending, resolved }

enum _TicketPriority { low, normal, high }

class _SupportTicket {
  _SupportTicket({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.priority,
    required this.customerLabel,
    required this.subject,
    required this.summary,
    required this.messages,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final _TicketStatus status;
  final _TicketPriority priority;
  final String customerLabel;
  final String subject;
  final String summary;
  final List<_TicketMessage> messages;
}

class _TicketMessage {
  const _TicketMessage({required this.from, required this.body});

  final String from;
  final String body;
}
