import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/local/database.dart';
import '../../data/repositories/transaction_repository.dart';
import 'add_category_dialog.dart';
import 'recurring_scope_dialog.dart';
import 'transactions_providers.dart';

/// Add/Edit Transaction bottom sheet. Ported 1:1 from `AddEditTransactionBottomSheet.kt`
/// (+ `TransactionsViewModel.saveTransaction`).
Future<void> showAddEditTransactionSheet(
  BuildContext context, {
  Transaction? editing,
  TransactionType initialType = TransactionType.expense,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AddEditTransactionSheet(editing: editing, initialType: initialType),
  );
}

class _AddEditTransactionSheet extends ConsumerStatefulWidget {
  final Transaction? editing;
  final TransactionType initialType;

  const _AddEditTransactionSheet({this.editing, required this.initialType});

  @override
  ConsumerState<_AddEditTransactionSheet> createState() => _AddEditTransactionSheetState();
}

class _AddEditTransactionSheetState extends ConsumerState<_AddEditTransactionSheet> {
  late TransactionType _type;
  late final TextEditingController _amountController;
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  String? _selectedCategoryName;
  String _selectedPaymentMethod = PaymentMethod.cash;
  int _selectedTripId = 0;
  late DateTime _selectedDate;
  bool _isRecurring = false;
  RecurringUpdateScope _updateScope = RecurringUpdateScope.thisAndFutureMonths;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _type = TransactionTypeX.fromStorage(editing.type);
      _amountController = TextEditingController(text: editing.amount.toStringAsFixed(2));
      _titleController = TextEditingController(text: editing.title);
      _notesController = TextEditingController(text: editing.notes);
      _selectedCategoryName = editing.category;
      _selectedPaymentMethod = editing.paymentMethod;
      _selectedTripId = editing.tripId;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(editing.timestamp);
      _isRecurring = editing.isRecurring;
    } else {
      _type = widget.initialType;
      _amountController = TextEditingController();
      _titleController = TextEditingController();
      _notesController = TextEditingController();
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<Category> _categoriesFor(TransactionType type) {
    final async = type == TransactionType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);
    return async.valueOrNull ?? const [];
  }

  String? _effectiveCategoryName(List<Category> categories) {
    if (categories.isEmpty) return null;
    if (_selectedCategoryName != null && categories.any((c) => c.name == _selectedCategoryName)) {
      return _selectedCategoryName;
    }
    return categories.first.name;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _addCategory() async {
    final created = await showAddCategoryDialog(context, ref, initialType: _type);
    if (created != null) setState(() => _selectedCategoryName = created.name);
  }

  Future<void> _editCategory(Category category) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Category'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Category'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;

    if (choice == 'edit') {
      final updated = await showAddCategoryDialog(context, ref, initialType: _type, editing: category);
      if (updated != null) setState(() => _selectedCategoryName = updated.name);
    } else if (choice == 'delete') {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            'Delete "${category.name}"? Existing transactions keep this category name, but you won\'t be able to pick it again.',
          ),
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
      if (confirmed == true) {
        await ref.read(categoryRepositoryProvider).deleteCategory(category);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category deleted')));
        }
      }
    }
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final scope = await showDeleteScopeDialog(context, isRecurring: editing.isRecurring);
    if (scope == null) return;
    await ref.read(transactionRepositoryProvider).deleteTransaction(editing, scope: scope);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();
    final notes = _notesController.text.trim();
    final category = _selectedCategoryName ?? '';

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(transactionRepositoryProvider);
    final timestamp = _selectedDate.millisecondsSinceEpoch;
    final editing = widget.editing;

    try {
      if (editing == null) {
        await repo.insertTransaction(TransactionsCompanion.insert(
          title: title,
          amount: amount,
          type: _type.storageName,
          category: category,
          timestamp: timestamp,
          notes: drift.Value(notes),
          isRecurring: drift.Value(_isRecurring),
          isRecurringActive: const drift.Value(true),
          lastProcessedDate: timestamp,
          effectiveFromTimestamp: timestamp,
          paymentMethod: drift.Value(_selectedPaymentMethod),
          tripId: drift.Value(_selectedTripId),
        ));
      } else {
        final companion = TransactionsCompanion(
          id: drift.Value(editing.id),
          title: drift.Value(title),
          amount: drift.Value(amount),
          type: drift.Value(_type.storageName),
          category: drift.Value(category),
          timestamp: drift.Value(timestamp),
          notes: drift.Value(notes),
          isRecurring: drift.Value(_isRecurring),
          recurringInterval: const drift.Value('MONTHLY'),
          isRecurringActive: const drift.Value(true),
          lastProcessedDate: drift.Value(timestamp),
          recurringSeriesId: drift.Value(editing.recurringSeriesId),
          effectiveFromTimestamp: drift.Value(timestamp),
          paymentMethod: drift.Value(_selectedPaymentMethod),
          tripId: drift.Value(_selectedTripId),
        );

        if (_isRecurring) {
          await repo.updateRecurringTransaction(companion, _updateScope);
        } else {
          await repo.updateTransaction(companion);
        }
      }

      if (!mounted) return;
      final message = _isEditing && _isRecurring
          ? (_updateScope == RecurringUpdateScope.thisMonthOnly
              ? 'Updated for this month only'
              : 'Updated this and all subsequent months')
          : (!_isEditing && _isRecurring)
              ? 'Recurring transaction saved (25 months created)'
              : 'Transaction saved';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final categories = _categoriesFor(_type);
    final effectiveCategoryName = _effectiveCategoryName(categories);
    Category? selectedCategory;
    for (final c in categories) {
      if (c.name == effectiveCategoryName) {
        selectedCategory = c;
        break;
      }
    }
    final isTripSavings = effectiveCategoryName == AppConstants.tripSavingsCategoryName;
    final trips = ref.watch(allTripsProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
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
                  _isEditing ? 'Edit Transaction' : 'Add Transaction',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                    ButtonSegment(value: TransactionType.income, label: Text('Income')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() {
                    _type = s.first;
                    _selectedCategoryName = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Amount', prefixText: '$currencySymbol '),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: effectiveCategoryName,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories
                            .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedCategoryName = value),
                      ),
                    ),
                    IconButton(onPressed: _addCategory, icon: const Icon(Icons.add_circle_outline)),
                    if (selectedCategory != null && selectedCategory.isCustom)
                      IconButton(
                        onPressed: () => _editCategory(selectedCategory!),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedPaymentMethod,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: PaymentMethod.all.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (value) => setState(() => _selectedPaymentMethod = value ?? PaymentMethod.cash),
                ),
                if (isTripSavings) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedTripId,
                    decoration: const InputDecoration(labelText: 'Tag to Trip'),
                    items: [
                      const DropdownMenuItem(value: 0, child: Text('None')),
                      ...trips.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                    ],
                    onChanged: (value) => setState(() => _selectedTripId = value ?? 0),
                  ),
                ],
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18),
                        const SizedBox(width: 8),
                        Text(DateTimeUtils.formatDate(_selectedDate.millisecondsSinceEpoch)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recurring Monthly'),
                  value: _isRecurring,
                  onChanged: (value) => setState(() => _isRecurring = value),
                ),
                if (_isEditing && _isRecurring) ...[
                  Text('Apply Change To', style: Theme.of(context).textTheme.labelLarge),
                  RadioGroup<RecurringUpdateScope>(
                    groupValue: _updateScope,
                    onChanged: (value) => setState(() => _updateScope = value!),
                    child: const Column(
                      children: [
                        RadioListTile<RecurringUpdateScope>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('This & All Future Months'),
                          value: RecurringUpdateScope.thisAndFutureMonths,
                        ),
                        RadioListTile<RecurringUpdateScope>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('This Month Only'),
                          value: RecurringUpdateScope.thisMonthOnly,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(_isEditing ? 'Update' : 'Save'),
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
