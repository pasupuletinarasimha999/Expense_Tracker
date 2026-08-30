import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database.dart';

/// Add/Edit custom category dialog. Ported 1:1 from `AddCategoryDialog.kt`. Default
/// categories are never editable — only categories created here (`isCustom = true`).
/// Returns the created/updated [Category] on success, or `null` if cancelled.
Future<Category?> showAddCategoryDialog(
  BuildContext context,
  WidgetRef ref, {
  TransactionType initialType = TransactionType.expense,
  Category? editing,
}) {
  return showDialog<Category?>(
    context: context,
    builder: (context) => _AddCategoryDialog(initialType: initialType, editing: editing),
  );
}

class _AddCategoryDialog extends ConsumerStatefulWidget {
  final TransactionType initialType;
  final Category? editing;

  const _AddCategoryDialog({required this.initialType, this.editing});

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  late TransactionType _selectedType;
  late String _selectedIconName;
  late String _selectedColorHex;
  late final TextEditingController _nameController;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _selectedType = editing != null ? TransactionTypeX.fromStorage(editing.type) : widget.initialType;
    _selectedIconName = editing?.iconName ?? availableCategoryIcons.first;
    _selectedColorHex = editing?.colorHex ?? availableCategoryColors.first;
    _nameController = TextEditingController(text: editing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a category name')));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(categoryRepositoryProvider);
    final editing = widget.editing;
    try {
      if (editing != null) {
        await repo.updateCategory(
          categoryId: editing.id,
          name: name,
          iconName: _selectedIconName,
          colorHex: _selectedColorHex,
          type: _selectedType,
        );
        if (!mounted) return;
        Navigator.pop(
          context,
          Category(
            id: editing.id,
            name: name,
            iconName: _selectedIconName,
            colorHex: _selectedColorHex,
            type: _selectedType.storageName,
            isCustom: true,
          ),
        );
      } else {
        final id = await repo.addCategory(
          name: name,
          iconName: _selectedIconName,
          colorHex: _selectedColorHex,
          type: _selectedType,
        );
        if (!mounted) return;
        Navigator.pop(
          context,
          Category(
            id: id,
            name: name,
            iconName: _selectedIconName,
            colorHex: _selectedColorHex,
            type: _selectedType.storageName,
            isCustom: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit Category' : 'New Category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                _isEditing
                    ? "Update this category's name, icon, or color."
                    : 'Create a custom category for your transactions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              if (!_isEditing)
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                    ButtonSegment(value: TransactionType.income, label: Text('Income')),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (s) => setState(() => _selectedType = s.first),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Category name'),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: availableCategoryIcons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final iconName = availableCategoryIcons[index];
                    final isSelected = iconName == _selectedIconName;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIconName = iconName),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryLight
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                        ),
                        child: Icon(
                          iconForName(iconName),
                          color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: availableCategoryColors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final colorHex = availableCategoryColors[index];
                    final isSelected = colorHex.toLowerCase() == _selectedColorHex.toLowerCase();
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = colorHex),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: AppColors.fromHex(colorHex), shape: BoxShape.circle),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_isEditing ? 'Update Category' : 'Save Category'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
