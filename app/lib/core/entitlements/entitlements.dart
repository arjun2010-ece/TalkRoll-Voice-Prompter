import 'dart:io' show Platform;

import '../script/saved_script.dart';

/// Paywall seam. Phase 3 replaces [UnlockedEntitlements] with the real state
/// machine; call sites already go through this interface.
abstract class Entitlements {
  bool get isPro;
  bool canStartPrompter(SavedScript script);
}

class UnlockedEntitlements implements Entitlements {
  const UnlockedEntitlements();
  @override
  bool get isPro => true;
  @override
  bool canStartPrompter(SavedScript script) => true;
}

/// Real store payments, one switch per store, so Apple can go live first and Android later. Off by default: a release
/// built without the switch for its platform keeps every script free and shows no limit (nobody is locked out when no
/// store can sell them Pro).
///
/// - `--dart-define=PAYMENTS_APPLE=true`: iPhone, iPad and Mac use the App Store (StoreKit).
/// - `--dart-define=PAYMENTS_ANDROID=true`: Android uses Google Play Billing.
///
/// Windows has no store integration yet, so it never turns payments on.
const paymentsApple = bool.fromEnvironment('PAYMENTS_APPLE');
const paymentsAndroid = bool.fromEnvironment('PAYMENTS_ANDROID');

/// Whether this build, on this platform, sells Pro through its store.
final bool storePaymentsLive = (Platform.isIOS || Platform.isMacOS)
    ? paymentsApple
    : Platform.isAndroid
    ? paymentsAndroid
    : false;

/// Whether the free-script limit is enforced: when the store payments for this platform are live, or when a developer
/// build asks for it with `--dart-define=ENFORCE_FREE_LIMIT=true` (the debug fake store then sells Pro, so the whole
/// upgrade path can be run without any store account).
final bool proEnforced = storePaymentsLive || const bool.fromEnvironment('ENFORCE_FREE_LIMIT');

/// Scripts a free user may present.
const freeScriptLimit = 5;

enum ProPlan { free, monthly, yearly, lifetime }

/// Prices shown on the paywall; the stores will supply them in the user's currency once purchases are connected.
class ProPrices {
  const ProPrices._();
  static const monthly = '€6.99';
  static const yearly = '€55';
  static const yearlyPerMonth = '€4.58';
  static const lifetime = '€109.99';
}

class ProState {
  const ProState({this.presented = const {}, this.plan = ProPlan.free});

  /// Ids of the scripts that use up a free slot, in the order they were counted: a script counts the first time it is
  /// saved or presented. Only the first [freeScriptLimit] are free to present.
  final Set<String> presented;
  final ProPlan plan;

  bool get isPro => plan != ProPlan.free;
  int get used => presented.length;

  /// A free user has used all [freeScriptLimit] scripts and is no longer allowed a new one.
  bool get limitReached => !isPro && used >= freeScriptLimit;

  /// Whether the script with [id] (null: a script not saved before) may be presented. A counted script is free if it is
  /// among the first [freeScriptLimit]; one not counted yet is free while a slot is left.
  bool canPresent(String? id) {
    if (!proEnforced || isPro) return true;
    final at = id == null ? -1 : presented.toList().indexOf(id);
    return at >= 0 ? at < freeScriptLimit : used < freeScriptLimit;
  }

  /// Whether a new script may be saved: the limit is off, the user is Pro, or a free slot is left. Once the free
  /// scripts are used a new script is not created at all; the upgrade sheet opens instead.
  bool get canCreate => !proEnforced || isPro || used < freeScriptLimit;

  ProState copyWith({Set<String>? presented, ProPlan? plan}) =>
      ProState(presented: presented ?? this.presented, plan: plan ?? this.plan);
}
