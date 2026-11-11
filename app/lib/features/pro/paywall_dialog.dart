import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../services/platform.dart';
import '../../services/external_links.dart';
import '../../services/providers.dart' show analyticsProvider;
import '../../services/purchases/purchase_service.dart';
import '../onboarding/onboarding_widgets.dart' show onboardingHero, onboardingTheme;
import 'pro_state.dart';

/// Opens the plans. [reason] sits under the title when the paywall came from a locked Start. [title] replaces the
/// usual heading (the welcome tour restates the reader's goal). [source] says which surface opened it (`start`, `card`,
/// `settings`, `launch`, `onboarding`), for the event log only.
Future<void> showPaywall(BuildContext context, {String? reason, String? title, String source = 'start'}) async {
  final container = ProviderScope.containerOf(context);
  container.read(proProvider.notifier).notePromptShown();
  container.read(analyticsProvider).log('upgrade_prompt_shown', {'source': source});
  if (isMobile || isMacOS) {
    // Phones, tablets and the Mac get a full screen of plans; Windows keeps the sheet.
    await Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => PaywallScreen(reason: reason)));
  } else {
    await showDialog<void>(context: context, builder: (_) => PaywallDialog(reason: reason, title: title));
  }
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

/// The auto-renewal and billing disclosure the stores expect next to a purchase button. [price] is the store's own
/// text for [plan]. Apple's wording on Apple platforms, Google Play's on Android.
String subscriptionDisclosure(ProPlan plan, String price) {
  final play = isAndroid;
  final account = play ? 'Google Play account' : 'Apple ID account';
  final period = plan == ProPlan.monthly ? 'month' : 'year';
  return switch (plan) {
    ProPlan.lifetime =>
      'One-time purchase of $price, charged to your $account at confirmation. It does not renew. '
          'Restore Purchases brings it back on your other devices signed in to the same account.',
    ProPlan.free => '',
    _ when play =>
      'Payment is charged to your $account at confirmation of purchase. The subscription renews automatically at '
          '$price/$period unless you cancel it before the end of the current period. You can manage or cancel it at any '
          'time in Google Play under Payments & subscriptions.',
    _ =>
      'Payment will be charged to your $account at confirmation of purchase. The subscription renews automatically at '
          '$price/$period unless canceled at least 24 hours before the end of the current period. Your account will be '
          'charged for renewal within 24 hours before the end of the current period. You can manage or cancel your '
          'subscription in your Account Settings on the App Store after purchase.',
  };
}

/// Percent saved by the yearly plan against twelve monthly payments, from the store's own amounts; null under 5%.
int? _yearlySaving(List<ProOffer> offers) {
  final m = offers.where((o) => o.plan == ProPlan.monthly).firstOrNull?.amount;
  final y = offers.where((o) => o.plan == ProPlan.yearly).firstOrNull?.amount;
  if (m == null || y == null || m <= 0) return null;
  final pct = ((1 - y / (m * 12)) * 100).round();
  return pct >= 5 ? pct : null;
}

class PaywallDialog extends ConsumerStatefulWidget {
  const PaywallDialog({super.key, this.reason, this.title});
  final String? reason;
  final String? title;

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
    final pct = _yearlySaving(offers);
    return pct == null ? null : 'SAVE $pct%';
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
            Text(widget.title ?? 'Upgrade to TalkRoll Pro', textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
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
              isMacOS && _offer(offers, _plan) != null
                  ? '${subscriptionDisclosure(_plan, _offer(offers, _plan)!.price)} Questions? $supportEmail'
                  : 'Prices are shown in your store\'s currency. Monthly and Yearly renew until you cancel them in your store settings. '
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
      'TalkRoll checks your Pro subscription at least every 30 days. Connect to the internet to keep presenting. '
      'It checks again on its own as soon as you\'re online.',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Not Now')),
      FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Try Again')),
    ],
  ),
);

/// The plans on phones and tablets: a full screen with the plan rows, one buy button and the store links below.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.reason});
  final String? reason;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  ProPlan _plan = ProPlan.yearly;
  String? _notice;
  bool _busy = false;

  ProOffer? _offer(List<ProOffer> offers, ProPlan plan) => offers.where((o) => o.plan == plan).firstOrNull;

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

  String _buyLabel(List<ProOffer> offers) {
    final price = _offer(offers, _plan)?.price;
    if (price == null) return 'Not available right now';
    return switch (_plan) {
      ProPlan.monthly => 'Subscribe for $price/month',
      ProPlan.yearly => 'Subscribe for $price/year',
      ProPlan.lifetime => 'Buy Lifetime for $price',
      ProPlan.free => '',
    };
  }

  String get _terms => switch (_plan) {
    ProPlan.monthly => 'Renews monthly until canceled in store settings.',
    ProPlan.yearly => 'Renews yearly until canceled in store settings.',
    ProPlan.lifetime => 'One payment. No renewal.',
    ProPlan.free => '',
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: onboardingTheme(Theme.of(context)),
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final muted = theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant);
        final loaded = ref.watch(proOffersProvider);
        final offers = loaded.value ?? const <ProOffer>[];
        final saving = _yearlySaving(offers);
        final rows = [
          (ProPlan.monthly, 'Monthly', null as String?, ' / month'),
          (ProPlan.yearly, 'Yearly', saving == null ? null : 'Save $saving% vs monthly', ' / year'),
          (ProPlan.lifetime, 'Lifetime', 'Pro forever', ' once'),
        ];
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 14, 8),
                      child: Row(
                        children: [
                          Expanded(child: Text('TalkRoll Pro', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500))),
                          TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Not now')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Unlimited scripts', style: onboardingHero(context)?.copyWith(fontSize: 30)),
                                      const SizedBox(height: 16),
                                      Text(
                                        widget.reason == null ? 'Save and present as many scripts as you need.' : '${widget.reason} Pro lets you save and present as many as you need.',
                                        style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.3),
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Editing and exporting stay free.', style: muted),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Padding(padding: EdgeInsets.only(top: 4), child: _ScriptsIcon()),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Divider(height: 1, color: scheme.outlineVariant),
                            const SizedBox(height: 28),
                            Text('Choose a plan', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 20),
                            if (offers.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Column(children: [
                                  if (loaded.isLoading)
                                    const CircularProgressIndicator()
                                  else ...[
                                    Text('The store did not answer, so prices are not available right now.', textAlign: TextAlign.center, style: muted),
                                    const SizedBox(height: 8),
                                    TextButton(onPressed: () => ref.invalidate(proOffersProvider), child: const Text('Try again')),
                                  ],
                                ]),
                              )
                            else
                              for (final (plan, name, sub, unit) in rows)
                                if (_offer(offers, plan) case final offer?)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _PlanRow(
                                      name: name,
                                      subtitle: sub,
                                      price: '${offer.price}$unit',
                                      selected: _plan == plan,
                                      onTap: () => setState(() {
                                        _plan = plan;
                                        _notice = null;
                                      }),
                                    ),
                                  ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: _busy || _offer(offers, _plan) == null
                                  ? null
                                  : () => _run(() {
                                      ref.read(analyticsProvider).log('purchase_started', {'plan': _plan.name});
                                      return ref.read(purchaseServiceProvider).buy(_plan);
                                    }, success: 'Pro is on. Thank you!'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                              child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text(_buyLabel(offers)),
                            ),
                            if (_notice != null) ...[
                              const SizedBox(height: 16),
                              Text(_notice!, textAlign: TextAlign.center, style: muted?.copyWith(color: scheme.error)),
                            ],
                            const SizedBox(height: 18),
                            Text(_terms, textAlign: TextAlign.center, style: muted?.copyWith(color: scheme.onSurface)),
                            if (_offer(offers, _plan) case final chosen?) ...[
                              const SizedBox(height: 12),
                              Text(
                                subscriptionDisclosure(_plan, chosen.price),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: _busy ? null : () => _run(() => ref.read(purchaseServiceProvider).restore(), success: 'Pro is back on this device.'),
                            child: const Text('Restore purchases'),
                          ),
                          TextButton(onPressed: () => openExternal(Uri.parse(termsUrl)), child: const Text('Terms of use')),
                          TextButton(onPressed: () => openExternal(Uri.parse(privacyUrl)), child: const Text('Privacy policy')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// One plan: a radio, its name (and a line under it) and its price; blue-bordered when chosen.
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.name, required this.price, required this.selected, required this.onTap, this.subtitle});
  final String name;
  final String? subtitle;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $price',
      excludeSemantics: true,
      child: Material(
        color: selected ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.12), scheme.surfaceContainerHigh) : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
              children: [
                _Radio(selected: selected),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 21, fontWeight: FontWeight.w600)),
                      if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(price, style: theme.textTheme.titleMedium?.copyWith(fontSize: 19, fontWeight: FontWeight.w600)),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? const Color(0xFF1E7BF0) : Colors.transparent,
        border: Border.all(color: selected ? scheme.primary : scheme.outline, width: 2),
      ),
      child: selected ? Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)) : null,
    );
  }
}

/// Two stacked script pages, the front one with a lit line: the "unlimited scripts" graphic.
class _ScriptsIcon extends StatelessWidget {
  const _ScriptsIcon();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(76, 90), painter: _ScriptsPainter(Theme.of(context).colorScheme, Theme.of(context).brightness == Brightness.dark));
}

class _ScriptsPainter extends CustomPainter {
  _ScriptsPainter(this.scheme, this.dark);
  final ColorScheme scheme;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = dark ? const Color(0xFF6784B3) : scheme.outline;
    final line = dark ? const Color(0xFF667894) : scheme.outlineVariant;
    Paint stroke(Color c, double w) => Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round;
    // The page behind, tilted a little to the right.
    canvas.save();
    canvas.translate(size.width * 0.62, size.height * 0.1);
    canvas.rotate(0.1);
    final back = RRect.fromRectAndRadius(Rect.fromLTWH(-22, 0, 44, 62), const Radius.circular(8));
    canvas.drawRRect(back, Paint()..color = scheme.surface);
    canvas.drawRRect(back, stroke(edge.withValues(alpha: 0.7), 2));
    canvas.restore();
    // The page in front.
    final front = RRect.fromRectAndRadius(const Rect.fromLTWH(6, 24, 46, 62), const Radius.circular(9));
    canvas.drawRRect(front, Paint()..color = dark ? const Color(0xFF10192D) : scheme.surfaceContainerHigh);
    canvas.drawRRect(front, stroke(edge, 2.5));
    for (final (y, x1, c) in [(36.0, 44.0, line), (45.0, 40.0, line), (54.0, 44.0, scheme.primary), (63.0, 40.0, line), (72.0, 34.0, line)]) {
      canvas.drawLine(Offset(14, y), Offset(x1, y), stroke(c, 3));
    }
  }

  @override
  bool shouldRepaint(_ScriptsPainter old) => old.scheme != scheme || old.dark != dark;
}
