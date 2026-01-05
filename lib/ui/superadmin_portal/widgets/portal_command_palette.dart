import 'package:flutter/material.dart';

class PortalCommand {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback run;

  const PortalCommand({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.run,
  });
}

Future<void> showPortalCommandPalette(
  BuildContext context, {
  required List<PortalCommand> commands,
}) async {
  await showDialog<void>(
    context: context,
    builder: (context) => _CommandPaletteDialog(commands: commands),
  );
}

class _CommandPaletteDialog extends StatefulWidget {
  const _CommandPaletteDialog({required this.commands});

  final List<PortalCommand> commands;

  @override
  State<_CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<_CommandPaletteDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final q = _controller.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.commands
        : widget.commands
            .where(
              (c) =>
                  c.title.toLowerCase().contains(q) ||
                  c.subtitle.toLowerCase().contains(q),
            )
            .toList(growable: false);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.search_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Type a command…',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cmd = filtered[index];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(cmd.icon),
                        title: Text(
                          cmd.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          cmd.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          cmd.run();
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tip: Ctrl+K / Cmd+K to open',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
