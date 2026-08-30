import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/local/database.dart';

/// Add/Edit Trip dialog. Ported 1:1 from the trip dialog in `TripsFragment.kt`.
Future<void> showAddEditTripDialog(BuildContext context, WidgetRef ref, {Trip? editing}) {
  return showDialog(
    context: context,
    builder: (context) => _AddEditTripDialog(editing: editing),
  );
}

class _AddEditTripDialog extends ConsumerStatefulWidget {
  final Trip? editing;

  const _AddEditTripDialog({this.editing});

  @override
  ConsumerState<_AddEditTripDialog> createState() => _AddEditTripDialogState();
}

class _AddEditTripDialogState extends ConsumerState<_AddEditTripDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;
  late final TextEditingController _budgetController;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _startDate = DateTime.fromMillisecondsSinceEpoch(editing.startDate);
      _endDate = DateTime.fromMillisecondsSinceEpoch(editing.endDate);
      _nameController = TextEditingController(text: editing.name);
      _destinationController = TextEditingController(text: editing.destination);
      _budgetController = TextEditingController(text: editing.budget > 0 ? editing.budget.toStringAsFixed(2) : '');
    } else {
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 6));
      _nameController = TextEditingController();
      _destinationController = TextEditingController();
      _budgetController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate.isBefore(_startDate)) _endDate = _startDate;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: _startDate, lastDate: DateTime(2100));
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a trip name')));
      return;
    }
    final destination = _destinationController.text.trim();
    final budget = double.tryParse(_budgetController.text.trim()) ?? 0.0;

    setState(() => _saving = true);
    final repo = ref.read(tripRepositoryProvider);
    final editing = widget.editing;

    final companion = editing != null
        ? TripsCompanion(
            id: drift.Value(editing.id),
            name: drift.Value(name),
            destination: drift.Value(destination),
            startDate: drift.Value(_startDate.millisecondsSinceEpoch),
            endDate: drift.Value(_endDate.millisecondsSinceEpoch),
            budget: drift.Value(budget),
          )
        : TripsCompanion.insert(
            name: name,
            destination: drift.Value(destination),
            startDate: _startDate.millisecondsSinceEpoch,
            endDate: _endDate.millisecondsSinceEpoch,
            budget: drift.Value(budget),
          );

    await repo.saveTrip(companion);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEditing ? 'Trip updated' : 'Trip created')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Trip' : 'New Trip'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Trip name')),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: 'Destination (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Start Date'),
                      child: Text(DateTimeUtils.formatDate(_startDate.millisecondsSinceEpoch)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickEndDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'End Date'),
                      child: Text(DateTimeUtils.formatDate(_endDate.millisecondsSinceEpoch)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Budget (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_isEditing ? 'Update Trip' : 'Save Trip')),
      ],
    );
  }
}
