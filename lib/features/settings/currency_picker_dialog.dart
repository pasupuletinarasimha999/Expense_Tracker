import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';

Future<void> showCurrencyPickerDialog(BuildContext context, WidgetRef ref) async {
  final currentCode = ref.read(currencyCodeProvider);

  final selected = await showDialog<CurrencyOption>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Select Currency'),
      children: [
        RadioGroup<String>(
          groupValue: currentCode,
          onChanged: (code) {
            final option = AppConstants.availableCurrencies.firstWhere((o) => o.code == code);
            Navigator.pop(context, option);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppConstants.availableCurrencies.map((option) {
              return RadioListTile<String>(title: Text(option.displayName), value: option.code);
            }).toList(),
          ),
        ),
      ],
    ),
  );

  if (selected == null) return;

  final preferences = ref.read(userPreferencesProvider);
  preferences.currencyCode = selected.code;
  preferences.currencySymbol = selected.symbol;
  ref.read(currencyCodeProvider.notifier).state = selected.code;
  ref.read(currencySymbolProvider.notifier).state = selected.symbol;

  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Currency updated to ${selected.displayName}')));
  }
}
