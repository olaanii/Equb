import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';

class IdScanScreen extends StatelessWidget {
  const IdScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan ID'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help',
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan your national ID', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Place your ID within the frame. Make sure it is well-lit and readable.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withOpacity(0.7),
                        ),
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: scheme.outline.withOpacity(0.35)),
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.badge_outlined,
                              size: 64,
                              color: scheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: scheme.primary.withOpacity(0.75),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Start scan'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.image_search_rounded),
                    label: const Text('Upload photo instead'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
