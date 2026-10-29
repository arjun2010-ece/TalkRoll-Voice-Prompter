import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import 'paywall_dialog.dart';
import 'pro_state.dart';

/// Opens the upgrade sheet once when the app starts, for a free user who has used all the free scripts and has not
/// seen an upgrade sheet in the last day. The sheet has a Close button and the Studio stays fully usable behind it.
/// It never opens for Pro, before the limit is used, or while the limit is switched off.
class LaunchUpgradePrompt extends ConsumerStatefulWidget {
  const LaunchUpgradePrompt({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LaunchUpgradePrompt> createState() => _LaunchUpgradePromptState();
}

class _LaunchUpgradePromptState extends ConsumerState<LaunchUpgradePrompt> {
  @override
  void initState() {
    super.initState();
    _maybeShow();
  }

  Future<void> _maybeShow() async {
    // Let the Studio draw first, so the sheet lands on top of the home screen, not instead of it.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted || !ref.read(proProvider.notifier).launchPromptDue()) return;
    await showPaywall(context, source: 'launch', reason: 'You\'ve used your $freeScriptLimit free scripts.');
  }

  @override
  Widget build(BuildContext context) {
    // A new script was refused because the free scripts are used up: say why and offer Pro.
    ref.listen(saveBlockedProvider, (_, _) {
      showPaywall(context, source: 'save', reason: 'You\'ve used your $freeScriptLimit free scripts, so a new one can\'t be saved.');
    });
    return widget.child;
  }
}
