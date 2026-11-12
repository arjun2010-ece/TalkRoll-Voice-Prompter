import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../services/providers.dart';
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

/// Asks before a save that rewrites most of a script (more than 60% of its words) takes one of the shared free changes.
/// Only called when [ProState.rewriteCostsChange] says it will. True when the reader agrees.
Future<bool> confirmBigRewrite(BuildContext context, WidgetRef ref) async {
  final left = ref.read(proProvider).changesLeft;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Use a free change?'),
      content: Text(
        'This edit changes more than 60% of the words in this script, so saving it takes one of your free changes. '
        'You have $left left, and ${left - 1} after this one. Smaller edits are always free.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep editing')),
        TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save and use a change')),
      ],
    ),
  );
  return ok ?? false;
}

/// What a screen does with a save that [checkSaveLimits] looked at.
typedef SaveGate = ({bool proceed, bool rewriteConfirmed});

/// Runs the free limits (word limit, big rewrite) before a screen saves [cleaned] over the open script. A refused save
/// (too long, or a rewrite with no free change left) opens the upgrade sheet and does not proceed; a rewrite that takes a
/// free change asks first. Where the limits are off this always proceeds, so a screen can call it unconditionally.
Future<SaveGate> checkSaveLimits(BuildContext context, WidgetRef ref, String cleaned) async {
  final studio = ref.read(studioProvider.notifier);
  final verdict = studio.checkSave(cleaned);
  if (verdict == SaveVerdict.tooLong || verdict == SaveVerdict.noChangesLeft) {
    studio.signalBlocked(verdict, cleaned);
    return (proceed: false, rewriteConfirmed: false);
  }
  if (verdict == SaveVerdict.rewriteCostsChange) {
    if (!await confirmBigRewrite(context, ref) || !context.mounted) return (proceed: false, rewriteConfirmed: false);
    return (proceed: true, rewriteConfirmed: true);
  }
  return (proceed: true, rewriteConfirmed: false);
}
