import 'package:flutter/material.dart';

import '../../../../models/group.dart';
import '../../../widgets/common.dart';

@immutable
class GroupComposerResult {
  const GroupComposerResult({
    required this.name,
    required this.contribution,
    required this.frequency,
    required this.nextPayout,
    required this.members,
  });

  final String name;
  final int contribution;
  final String frequency;
  final DateTime nextPayout;
  final List<String> members;
}

Future<GroupComposerResult?> showGroupComposerSheet(
  BuildContext context, {
  Group? initial,
}) {
  return showModalBottomSheet<GroupComposerResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final nameController = TextEditingController(text: initial?.name ?? '');
      final amountController = TextEditingController(
        text: initial != null ? initial.contribution.toString() : '500',
      );
      final membersController = TextEditingController(
        text: initial != null ? initial.members.join(', ') : '',
      );
      String cadence = initial?.frequency ?? 'Weekly';
      DateTime payoutDate =
          initial?.nextPayout ?? DateTime.now().add(const Duration(days: 7));

      return StatefulBuilder(
        builder: (context, setState) {
          final viewInsets = MediaQuery.of(context).viewInsets;
          final theme = Theme.of(context);
          final localizations = MaterialLocalizations.of(context);
          return Padding(
            padding: viewInsets + const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    initial == null ? 'Create group' : 'Edit group',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      hintText: 'e.g. Addis Friday Equb',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Contribution amount (ETB)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: cadence,
                    decoration: const InputDecoration(
                      labelText: 'Contribution frequency',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                        value: 'Bi-weekly',
                        child: Text('Bi-weekly'),
                      ),
                      DropdownMenuItem(
                        value: 'Monthly',
                        child: Text('Monthly'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => cadence = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Next payout date'),
                    subtitle: Text(localizations.formatCompactDate(payoutDate)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: payoutDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selected != null) {
                        setState(() => payoutDate = selected);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: membersController,
                    decoration: const InputDecoration(
                      labelText: 'Initial members (comma separated)',
                      helperText: 'Leave blank to invite members later',
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: initial == null ? 'Create group' : 'Save changes',
                    icon:
                        initial == null
                            ? Icons.check_circle_outline
                            : Icons.save_alt,
                    onPressed: () {
                      final name = nameController.text.trim();
                      final amount = int.tryParse(amountController.text.trim());
                      if (name.isEmpty || amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a valid name and amount.'),
                          ),
                        );
                        return;
                      }
                      final members =
                          membersController.text
                              .split(',')
                              .map((m) => m.trim())
                              .where((m) => m.isNotEmpty)
                              .toList();
                      Navigator.of(context).pop(
                        GroupComposerResult(
                          name: name,
                          contribution: amount,
                          frequency: cadence,
                          nextPayout: payoutDate,
                          members: members,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
