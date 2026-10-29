import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/purchases/fake_purchase_service.dart';
import '../../services/purchases/purchase_service.dart';

/// Restore Purchases from Settings: asks the store and says what it found.
Future<void> restorePurchases(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(purchaseServiceProvider).restore();
  messenger.showSnackBar(SnackBar(
    content: Text(result.purchased ? 'Pro is back on this device.' : (result.message ?? 'Nothing to restore.')),
  ));
}

/// Manage subscription from Settings: opens the store's subscriptions page.
Future<void> manageSubscription(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final opened = await ref.read(purchaseServiceProvider).manage();
  if (!opened) {
    messenger.showSnackBar(const SnackBar(content: Text("Open your store's subscriptions page to manage or cancel it.")));
  }
}

/// Debug builds with the fake store only: chooses what the next test purchase does.
class FakeOutcomeControls extends ConsumerWidget {
  const FakeOutcomeControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.read(purchaseServiceProvider) is! FakePurchaseService) return const SizedBox.shrink();
    final outcome = ref.watch(fakeOutcomeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Next test purchase', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        SegmentedButton<PurchaseOutcome>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: PurchaseOutcome.purchased, label: Text('buys')),
            ButtonSegment(value: PurchaseOutcome.cancelled, label: Text('cancel')),
            ButtonSegment(value: PurchaseOutcome.pending, label: Text('pending')),
            ButtonSegment(value: PurchaseOutcome.failed, label: Text('fails')),
          ],
          selected: {outcome},
          onSelectionChanged: (v) => ref.read(fakeOutcomeProvider.notifier).set(v.first),
        ),
      ]),
    );
  }
}
