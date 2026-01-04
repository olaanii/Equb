import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/group.dart';
import '../../../../providers/group_providers.dart';
import 'group_composer_sheet.dart';

Future<void> startCreateGroupFlow(BuildContext context, WidgetRef ref) async {
  final result = await showGroupComposerSheet(context);
  if (result == null) {
    return;
  }
  final members = result.members.isEmpty ? <String>['You'] : result.members;
  ref
      .read(groupsProvider.notifier)
      .createGroup(
        name: result.name,
        contribution: result.contribution,
        frequency: result.frequency,
        members: members,
        nextPayout: result.nextPayout,
      );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Created ${result.name} with ${members.length} member(s).'),
    ),
  );
}

Future<void> startEditGroupFlow(
  BuildContext context,
  WidgetRef ref,
  Group group,
) async {
  final result = await showGroupComposerSheet(context, initial: group);
  if (result == null) {
    return;
  }
  ref
      .read(groupsProvider.notifier)
      .updateGroup(
        groupId: group.id,
        name: result.name,
        contribution: result.contribution,
        frequency: result.frequency,
        nextPayout: result.nextPayout,
      );
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Updated ${result.name}.')));
}

Future<void> startDeleteGroupFlow(
  BuildContext context,
  WidgetRef ref,
  Group group,
) async {
  final confirmed =
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove group'),
              content: Text('Delete ${group.name}? This cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
      ) ??
      false;
  if (!confirmed) {
    return;
  }
  ref.read(groupsProvider.notifier).deleteGroup(group.id);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Removed ${group.name}.')));
}

Future<void> promptAddMember(
  BuildContext context,
  WidgetRef ref,
  Group group,
) async {
  final controller = TextEditingController();
  final added = await showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text('Add member to ${group.name}'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Member name',
              hintText: 'e.g. Hana Getachew',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(name);
              },
              child: const Text('Add'),
            ),
          ],
        ),
  );
  if (added == null || added.isEmpty) {
    return;
  }
  ref.read(groupsProvider.notifier).addMember(group.id, added);
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Added $added to ${group.name}.')));
}
