import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../services/platform.dart';
import '../../services/external_links.dart';
import '../../services/providers.dart' show analyticsProvider;
import '../../services/purchases/purchase_service.dart';
import 'pro_state.dart';

/// Opens the plans. [reason] sits under the title when the paywall came from a locked Start. [source] says which
/// surface opened it (`start`, `card`, `settings`, `launch`), for the event log only.
Future<void> showPaywall(BuildContext context, {String? reason, String source = 'start'}) async {
  final container = ProviderScope.containerOf(context);
  container.read(proProvider.notifier).notePromptShown();
  container.read(analyticsProvider).log('upgrade_prompt_shown', {'source': source});
  await showDialog<void>(context: context, builder: (_) => PaywallDialog(reason: reason));
  container.read(analyticsProvider).log('upgrade_prompt_closed', {'source': source});
}

/// Pro accent: amber, so the buy path stands apart from the blue Start button.
const proAccent = Color(0xFFFFB340);

/// Amber text and icons need a deeper shade on light surfaces.
Color proText(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? proAccent : const Color(0xFFB26A00);

bool _dark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

String _planName(ProPlan p) => switch (p) {
  ProPlan.monthly => 'Monthly',
  ProPlan.yearly => 'Yearly',
  ProPlan.lifetime => 'Lifetime',
  ProPlan.free => 'Free',
};

class PaywallDialog extends ConsumerStatefulWidget {
  const PaywallDialog({super.key, this.reason});
  final String? reason;

  @override
  ConsumerState<PaywallDialog> createState() => _PaywallDialogState();
}

class _PaywallDialogState extends ConsumerState<PaywallDialog> {
  // Yearly is the default: best value, and a year of revenue up front.
  ProPlan _plan = ProPlan.yearly;
  String? _notice;
  bool _busy = false;

  ProOffer? _offer(List<ProOffer> offers, ProPlan plan) => offers.where((o) => o.plan == plan).firstOrNull;

  String _buyLabel(List<ProOffer> offers) {
    final price = _offer(offers, _plan)?.price;
    if (price == null) return 'Not available right now';
    return switch (_plan) {
      ProPlan.monthly => 'Subscribe for $price a month',
      ProPlan.yearly => 'Subscribe for $price a year',
      ProPlan.lifetime => 'Buy Lifetime for $price',
      ProPlan.free => '',
    };
  }

  /// Percent saved by the yearly plan against twelve monthly payments, from the store's own amounts.
  String? _yearlyBadge(List<ProOffer> offers) {
    final m = _offer(offers, ProPlan.monthly)?.amount;
    final y = _offer(offers, ProPlan.yearly)?.amount;
    if (m == null || y == null || m <= 0) return null;
    final pct = ((1 - y / (m * 12)) * 100).round();
    return pct >= 5 ? 'SAVE $pct%' : null;
  }

  /// Runs a store call, shows what happened, and closes the sheet with a thank-you when Pro is on.
  Future<void> _run(Future<PurchaseResult> Function() action, {required String success}) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _notice = null;
    });
    final result = await action();
    if (!mounted) return;
    if (result.purchased) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(success)));
      return;
    }
    setState(() {
      _busy = false;
      // A cancelled purchase is the user's own choice: nothing to explain.
      _notice = result.outcome == PurchaseOutcome.cancelled ? null : (result.message ?? 'Something went wrong. Please try again.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = isMobile && MediaQuery.sizeOf(context).shortestSide < 600;
    final loaded = ref.watch(proOffersProvider);
    final offers = loaded.value ?? const <ProOffer>[];
    final monthly = _offer(offers, ProPlan.monthly);
    final yearly = _offer(offers, ProPlan.yearly);
    final lifetime = _offer(offers, ProPlan.lifetime);
    final plans = [
      if (monthly != null) _PlanCard(plan: ProPlan.monthly, price: monthly.price, line1: 'per month', line2: 'cancel anytime', selected: _plan, onSelect: _select),
      if (yearly != null)
        _PlanCard(
          plan: ProPlan.yearly,
          price: yearly.price,
          line1: 'per year',
          line2: yearly.perMonth != null ? 'about ${yearly.perMonth} a month' : 'billed every year',
          badge: _yearlyBadge(offers),
          selected: _plan,
          onSelect: _select,
        ),
      if (lifetime != null) _PlanCard(plan: ProPlan.lifetime, price: lifetime.price, line1: 'one payment', line2: 'Pro forever', selected: _plan, onSelect: _select),
    ];
    return Dialog(
      insetPadding: phone ? const EdgeInsets.all(12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Stack(children: [
        // The plans scroll on a small screen; the buy button, Restore and the terms stay in view below them.
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Flexible(
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: proAccent.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.star_rounded, size: 32, color: proAccent),
              ),
            ),
            const SizedBox(height: 14),
            Text('Upgrade to EchoPrompter Pro', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              widget.reason == null
                  ? 'Save and present as many scripts as you like.'
                  : '${widget.reason} Pro lets you save and present as many as you like.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final line in const [
              'Save and present unlimited scripts',
              'Get it back on a new phone or computer with Restore Purchases',
              'Editing and exporting your scripts stay free',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(Icons.check_rounded, size: 18, color: _dark(context) ? const Color(0xFF30D158) : const Color(0xFF1F9D43)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line)),
                ]),
              ),
            const SizedBox(height: 16),
            if (plans.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(children: [
                  if (loaded.isLoading) const CircularProgressIndicator() else ...[
                    Text('The store did not answer, so prices are not available right now.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => ref.invalidate(proOffersProvider), child: const Text('Try again')),
                  ],
                ]),
              )
            else if (phone)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final c in plans) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
              ])
            else
              Row(children: [
                for (var i = 0; i < plans.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: plans[i]),
                ],
              ]),
            if (_notice != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(8), border: Border.all(color: scheme.outlineVariant)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_notice!, style: theme.textTheme.bodySmall)),
                ]),
              ),
            ],
          ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FilledButton(
              onPressed: _busy || _offer(offers, _plan) == null
                  ? null
                  : () => _run(
                      () {
                        ref.read(analyticsProvider).log('purchase_started', {'plan': _plan.name});
                        return ref.read(purchaseServiceProvider).buy(_plan);
                      },
                      success: 'Pro is on. Thank you!',
                    ),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_buyLabel(offers)),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: _busy ? null : () => _run(() => ref.read(purchaseServiceProvider).restore(), success: 'Pro is back on this device.'),
                child: const Text('Restore Purchases'),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Not Now')),
            ]),
            Text(
              'Prices are shown in your store\'s currency. Monthly and Yearly renew until you cancel them in your store settings. '
              'Questions? $supportEmail',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            // The store requires links to the terms and the privacy policy next to the purchase.
            if (isAndroid || isMacOS || isMobile)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(onPressed: () => openExternal(Uri.parse(termsUrl)), child: const Text('Terms of Use')),
                const SizedBox(width: 12),
                TextButton(onPressed: () => openExternal(Uri.parse(privacyUrl)), child: const Text('Privacy Policy')),
              ]),
          ]),
        ),
        ]),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        ]),
      ),
    );
  }

  void _select(ProPlan p) => setState(() {
    _plan = p;
    _notice = null;
  });
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.price, required this.line1, required this.line2, required this.selected, required this.onSelect, this.badge});
  final ProPlan plan;
  final String price;
  final String line1;
  final String line2;
  final String? badge;
  final ProPlan selected;
  final void Function(ProPlan) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = plan == selected;
    return Semantics(
      button: true,
      selected: on,
      label: '${_planName(plan)}, $price, $line1',
      child: InkWell(
        onTap: () => onSelect(plan),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: on ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerHigh,
            border: Border.all(color: on ? scheme.primary : scheme.outlineVariant, width: on ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_planName(plan), style: theme.textTheme.labelLarge),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: _dark(context) ? const Color(0xFF1E3A26) : const Color(0xFFDDF5E4), borderRadius: BorderRadius.circular(5)),
                  child: Text(badge!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _dark(context) ? const Color(0xFF30D158) : const Color(0xFF1F9D43))),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(price, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('$line1\n$line2', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// Shown when a subscription hasn't been checked for 30 days (plan §10.4). Wired in with billing (Phase 3).
Future<void> showSubscriptionCheckAlert(BuildContext context) => showDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    icon: Icon(Icons.warning_amber_rounded, size: 32, color: proText(ctx)),
    title: const Text('Connect to check your subscription'),
    content: const Text(
      'EchoPrompter checks your Pro subscription at least every 30 days. Connect to the internet to keep presenting. '
      'It checks again on its own as soon as you\'re online.',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Not Now')),
      FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Try Again')),
    ],
  ),
);
