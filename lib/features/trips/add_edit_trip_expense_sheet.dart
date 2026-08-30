import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/local/database.dart';
import '../../services/notifications/notification_service.dart';

/// Add/Edit Trip Expense bottom sheet. Ported 1:1 from `AddEditTripExpenseBottomSheet.kt`.
Future<void> showAddEditTripExpenseSheet(
  BuildContext context,
  WidgetRef ref, {
  required int tripId,
  required String tripName,
  TripExpense? editing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddEditTripExpenseSheet(tripId: tripId, tripName: tripName, editing: editing),
  );
}

class _AddEditTripExpenseSheet extends ConsumerStatefulWidget {
  final int tripId;
  final String tripName;
  final TripExpense? editing;

  const _AddEditTripExpenseSheet({required this.tripId, required this.tripName, this.editing});

  @override
  ConsumerState<_AddEditTripExpenseSheet> createState() => _AddEditTripExpenseSheetState();
}

class _AddEditTripExpenseSheetState extends ConsumerState<_AddEditTripExpenseSheet> {
  late String _selectedCategory;
  late String _selectedPaymentMethod;
  late DateTime _selectedDate;
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  bool _isPaid = false;
  bool _reminderEnabled = false;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _selectedCategory = editing.category;
      _selectedPaymentMethod = editing.paymentMethod;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(editing.date);
      _amountController = TextEditingController(text: editing.amount.toStringAsFixed(2));
      _titleController = TextEditingController(text: editing.title);
      _isPaid = editing.isPaid;
      _reminderEnabled = editing.reminderEnabled;
    } else {
      _selectedCategory = TripCategories.all.first.name;
      _selectedPaymentMethod = PaymentMethod.cash;
      _selectedDate = DateTime.now();
      _amountController = TextEditingController();
      _titleController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _onReminderToggled(bool value) async {
    if (value) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (!result.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text("Reminders won't show without notification permission")));
          }
        }
      }
    }
    setState(() => _reminderEnabled = value);
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Remove "${editing.title}" from this trip?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await NotificationService.instance.cancelReminder(editing.id);
    await ref.read(tripRepositoryProvider).deleteExpense(editing.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(tripRepositoryProvider);
    final editing = widget.editing;
    final dateMillis = _selectedDate.millisecondsSinceEpoch;

    try {
      final companion = editing != null
          ? TripExpensesCompanion(
              id: drift.Value(editing.id),
              tripId: drift.Value(widget.tripId),
              category: drift.Value(_selectedCategory),
              title: drift.Value(title),
              amount: drift.Value(amount),
              date: drift.Value(dateMillis),
              isPaid: drift.Value(_isPaid),
              reminderEnabled: drift.Value(_reminderEnabled),
              paymentMethod: drift.Value(_selectedPaymentMethod),
            )
          : TripExpensesCompanion.insert(
              tripId: widget.tripId,
              category: _selectedCategory,
              title: title,
              amount: amount,
              date: dateMillis,
              isPaid: drift.Value(_isPaid),
              reminderEnabled: drift.Value(_reminderEnabled),
              paymentMethod: drift.Value(_selectedPaymentMethod),
            );

      final savedId = await repo.saveExpense(companion);

      await NotificationService.instance.scheduleTripReminder(
        expenseId: savedId,
        title: title,
        tripName: widget.tripName,
        targetDateMillis: dateMillis,
        reminderEnabled: _reminderEnabled,
        isPaid: _isPaid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Budget item saved')));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = ref.watch(currencySymbolProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  _isEditing ? 'Edit Budget Item' : 'Add Budget Item',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Amount', prefixText: '$currencySymbol '),
                ),
                const SizedBox(height: 12),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: TripCategories.all.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value ?? _selectedCategory),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: PaymentMethod.all.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (value) => setState(() => _selectedPaymentMethod = value ?? PaymentMethod.cash),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: _isPaid ? 'Date Paid' : 'Target Date'),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                        Text(DateTimeUtils.formatDate(_selectedDate.millisecondsSinceEpoch)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Already Paid'),
                  value: _isPaid,
                  onChanged: (value) => setState(() {
                    _isPaid = value;
                    if (value) _reminderEnabled = false;
                  }),
                ),
                Opacity(
                  opacity: _isPaid ? 0.5 : 1,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Remind Me'),
                    value: _reminderEnabled,
                    onChanged: _isPaid ? null : _onReminderToggled,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(_isEditing ? 'Update Item' : 'Save Item'),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _saving ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
