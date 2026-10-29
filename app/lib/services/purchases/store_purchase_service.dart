import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/entitlements/entitlements.dart';
import 'purchase_service.dart';

/// The real store: StoreKit on iPhone, iPad and Mac, Google Play Billing on Android, both through Flutter's
/// `in_app_purchase`. Used only when the switch for the platform is on (`PAYMENTS_APPLE`, `PAYMENTS_ANDROID`).
///
/// Not yet exercised against a real store: it needs an Apple Developer or Google Play Console account to create the
/// products. See `docs/payments-plan.md` for what to check first.
class StorePurchaseService implements PurchaseService {
  StorePurchaseService({InAppPurchase? store}) : _store = store ?? InAppPurchase.instance {
    _updates = _store.purchaseStream.listen(_onPurchases, onError: (Object _) {});
    // Android reports what the account owns when asked, silently. Apple delivers renewals and unfinished purchases on
    // the stream, and asks for the Apple ID only when the user presses Restore, so it is not asked at launch.
    if (Platform.isAndroid) unawaited(_store.restorePurchases().catchError((Object _) {}));
  }

  final InAppPurchase _store;
  late final StreamSubscription<List<PurchaseDetails>> _updates;
  final _changes = StreamController<ProPlan>.broadcast();
  Completer<PurchaseResult>? _buying;
  ProPlan _owned = ProPlan.free;
  Map<ProPlan, ProductDetails> _products = const {};

  @override
  Stream<ProPlan> get entitlement => _changes.stream;

  @override
  Future<List<ProOffer>> offers() async {
    try {
      if (!await _store.isAvailable()) return const [];
      final response = await _store.queryProductDetails(ProProductIds.all);
      final found = <ProPlan, ProductDetails>{
        for (final d in response.productDetails) ?ProProductIds.planOf(d.id): d,
      };
      _products = found;
      return [
        for (final plan in const [ProPlan.monthly, ProPlan.yearly, ProPlan.lifetime])
          if (found[plan] case final d?) ProOffer(plan: plan, price: d.price, amount: d.rawPrice),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<PurchaseResult> buy(ProPlan plan) async {
    if (_buying != null) return const PurchaseResult(PurchaseOutcome.pending, 'A purchase is already in progress.');
    var details = _products[plan];
    if (details == null) {
      await offers();
      details = _products[plan];
    }
    if (details == null) return const PurchaseResult(PurchaseOutcome.unavailable, 'This plan is not available from the store right now.');
    final done = _buying = Completer<PurchaseResult>();
    try {
      final started = await _store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
      if (!started && !done.isCompleted) done.complete(const PurchaseResult(PurchaseOutcome.failed, 'The purchase could not be started.'));
    } catch (e) {
      if (!done.isCompleted) done.complete(PurchaseResult(PurchaseOutcome.failed, '$e'));
    }
    final result = await done.future;
    _buying = null;
    return result;
  }

  @override
  Future<PurchaseResult> restore() async {
    try {
      await _store.restorePurchases();
    } catch (e) {
      return PurchaseResult(PurchaseOutcome.failed, '$e');
    }
    // Restored purchases arrive on the stream; give them a moment, then report what the account owns.
    await Future<void>.delayed(const Duration(seconds: 2));
    return _owned == ProPlan.free
        ? const PurchaseResult(PurchaseOutcome.failed, 'No earlier purchase was found for this account.')
        : const PurchaseResult(PurchaseOutcome.purchased);
  }

  @override
  Future<bool> manage() {
    final url = Platform.isAndroid ? 'https://play.google.com/store/account/subscriptions' : 'https://apps.apple.com/account/subscriptions';
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((Object _) => false);
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final plan = ProProductIds.planOf(p.productID);
          if (plan != null) _grant(plan);
          if (p.pendingCompletePurchase) unawaited(_store.completePurchase(p));
          _finish(const PurchaseResult(PurchaseOutcome.purchased));
        case PurchaseStatus.pending:
          _finish(const PurchaseResult(PurchaseOutcome.pending, 'Waiting for approval. Pro turns on when it is approved.'));
        case PurchaseStatus.canceled:
          _finish(const PurchaseResult(PurchaseOutcome.cancelled));
        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) unawaited(_store.completePurchase(p));
          _finish(PurchaseResult(PurchaseOutcome.failed, p.error?.message ?? 'The purchase failed.'));
      }
    }
  }

  void _finish(PurchaseResult result) {
    final waiting = _buying;
    if (waiting != null && !waiting.isCompleted) waiting.complete(result);
  }

  /// Keeps the best plan the account owns: lifetime over yearly over monthly.
  void _grant(ProPlan plan) {
    if (plan.index <= _owned.index && _owned != ProPlan.free) {
      // Same or lower than what is already owned; still report it so the app is sure.
      _changes.add(_owned);
      return;
    }
    _owned = plan;
    _changes.add(plan);
  }

  @override
  void dispose() {
    _updates.cancel();
    _changes.close();
  }
}
