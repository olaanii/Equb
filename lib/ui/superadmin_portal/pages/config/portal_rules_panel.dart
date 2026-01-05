import 'dart:convert';

import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

class PortalRulesPanel extends StatefulWidget {
  const PortalRulesPanel({super.key});

  @override
  State<PortalRulesPanel> createState() => _PortalRulesPanelState();
}

class _PortalRulesPanelState extends State<PortalRulesPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = jsonEncode(jsonDecode(_controller.text));
      _controller.text = payload;
      messenger.showSnackBar(
        const SnackBar(content: Text('Rules validated (local only)')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Invalid JSON: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editorHeight = (MediaQuery.sizeOf(context).height * 0.45)
        .clamp(220.0, context.isDesktop ? 520.0 : 420.0);

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rules',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Platform rules editor. Backend wiring can persist these later.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform Rules (JSON)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: editorHeight,
                        child: TextField(
                          controller: _controller,
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          decoration: const InputDecoration(
                            hintText: '{"minContribution": 100}',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        children: [
                          FilledButton(
                            onPressed: _validate,
                            child: const Text('Validate'),
                          ),
                          OutlinedButton(
                            onPressed: _controller.clear,
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
