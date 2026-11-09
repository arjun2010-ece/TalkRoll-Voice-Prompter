import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../providers.dart' show prefsProvider;
import 'fake_purchase_service.dart';
import 'store_purchase_service.dart';

/// Product ids, the same in App Store Connect and Play Console. Monthly and yearly are auto-renewing subscriptions,
/// lifetime is a non-consumable.
class ProProductIds {
  const ProProductIds._();
  static const monthly = 'talkroll.pro.monthly';
  static const yearly = 'talkroll.pro.yearly';
  static const lifetime = 'talkroll.pro.lifetime';
  static const all = {monthly, yearly, lifetime};

  static String of(ProPlan plan) => switch (plan) {
    ProPlan.monthly => monthly,
    ProPlan.yearly => yearly,
    ProPlan.lifetime => lifetime,
    ProPlan.free => '',
  };

  static ProPlan? planOf(String id) => switch (id) {
    monthly => ProPlan.monthly,
    yearly => ProPlan.yearly,
    lifetime => ProPlan.lifetime,
    _ => null,
  };
}

/// What the paywall shows for one plan. [price] is the store's own text (in the user's currency); [amount] is the number
/// behind it, for the "save n%" badge; [perMonth] is only set where it can be written correctly.
class ProOffer {
  const ProOffer({required this.plan, required this.price, this.amount, this.perMonth});
  final ProPlan plan;
  final String price;
  final double? amount;
  final String? perMonth;
}

enum PurchaseOutcome { purchased, cancelled, pending, unavailable, failed }

class PurchaseResult {
  const PurchaseResult(this.outcome, [this.message]);
  final PurchaseOutcome outcome;
  final String? message;
  bool get purchased => outcome == PurchaseOutcome.purchased;
}

/// The one door to a store. The paywall, the Settings screens and `ProNotifier` use only this, so Apple, Google, the
/// debug fake and "no store" are interchangeable.
abstract class PurchaseService {
  /// The plan the store says the user owns, every time it changes: after a purchase, a restore, a renewal on launch.
  Stream<ProPlan> get entitlement;

  /// Plans with the store's prices. Empty when the store cannot be reached.
  Future<List<ProOffer>> offers();

  Future<PurchaseResult> buy(ProPlan plan);

  /// Asks the store for what this account already owns.
  Future<PurchaseResult> restore();

  /// Opens the store's page for managing or cancelling a subscription. False if it could not be opened.
  Future<bool> manage();

  void dispose();
}

/// The placeholder prices used when no store is connected (the debug fake and builds with payments off).
List<ProOffer> placeholderOffers() => const [
  ProOffer(plan: ProPlan.monthly, price: ProPrices.monthly, amount: 6.99),
  ProOffer(plan: ProPlan.yearly, price: ProPrices.yearly, amount: 55, perMonth: ProPrices.yearlyPerMonth),
  ProOffer(plan: ProPlan.lifetime, price: ProPrices.lifetime, amount: 109.99),
];

/// Used by release builds whose store payments are off: buying says it is not available, as before.
class UnavailablePurchaseService implements PurchaseService {
  const UnavailablePurchaseService();

  @override
  Stream<ProPlan> get entitlement => const Stream.empty();
  @override
  Future<List<ProOffer>> offers() async => placeholderOffers();
  @override
  Future<PurchaseResult> buy(ProPlan plan) async => const PurchaseResult(PurchaseOutcome.unavailable, "Buying Pro isn't available in this build yet.");
  @override
  Future<PurchaseResult> restore() async => const PurchaseResult(PurchaseOutcome.unavailable, "Restoring purchases isn't available in this build yet.");
  @override
  Future<bool> manage() async => false;
  @override
  void dispose() {}
}

/// Which store a build talks to:
/// - the real store, when the switch for this platform is on (`PAYMENTS_APPLE`, `PAYMENTS_ANDROID`);
/// - the debug fake, in debug builds with the switch off, so buying can be tested without any account;
/// - nothing, in release builds with the switch off.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final PurchaseService service = storePaymentsLive
      ? StorePurchaseService()
      : kDebugMode
      ? FakePurchaseService(ref.read(prefsProvider), () => ref.read(fakeOutcomeProvider))
      : const UnavailablePurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

/// The offers the paywall and the upgrade card show; loaded once, then reused.
final proOffersProvider = FutureProvider<List<ProOffer>>((ref) => ref.read(purchaseServiceProvider).offers());
