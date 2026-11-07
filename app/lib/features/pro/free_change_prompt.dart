import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import 'pro_state.dart';

/// Asks before a new script uses one of the shared free changes (the free scripts are all counted, and a deleted script's
/// slot is being reused). True when nothing is spent, or the user agrees.
Future<bool> confirmFreeChange(BuildContext context, WidgetRef ref) async {
  final pro = ref.read(proProvider);
  if (!pro.createCostsChange) return true;
  final left = pro.changesLeft;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Use a free change?'),
      content: Text(
        'You have already used your $freeScriptLimit free scripts, so a new script takes one of your free changes. '
        'You have $left left, and ${left - 1} after this one.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
      ],
    ),
  );
  return ok ?? false;
}
