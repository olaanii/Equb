import 'package:equb/models/equb_model.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';

class GroupDialog extends StatefulWidget {
  final EqubGroup? group;

  const GroupDialog({super.key, this.group});

  @override
  State<GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<GroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late EqubCycle _selectedCycle;
  late DateTime _startDate;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameController = TextEditingController(text: g?.name ?? '');
    _amountController = TextEditingController(
      text: g?.contributionAmount.toString() ?? '100',
    );
    _selectedCycle = g?.scheduleConfig.cycle ?? EqubCycle.monthly;
    _startDate = g?.scheduleConfig.startDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.group != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Group' : 'Create Group'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Contribution Amount (ETB)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EqubCycle>(
                value: _selectedCycle,
                decoration: const InputDecoration(labelText: 'Cycle'),
                items:
                    EqubCycle.values.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c.label));
                    }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCycle = v);
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Start Date'),
                  child: Text(
                    '${_startDate.year}-${_startDate.month}-${_startDate.day}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(text: 'Save', onPressed: _save),
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text);

    final newGroup = EqubGroup(
      id: widget.group?.id ?? '', // Empty ID means new
      name: name,
      contributionAmount: amount,
      members: widget.group?.members ?? [], // Preserve members if editing
      scheduleConfig: EqubScheduleConfig(
        cycle: _selectedCycle,
        startDate: _startDate,
      ),
    );

    Navigator.of(context).pop(newGroup);
  }
}
