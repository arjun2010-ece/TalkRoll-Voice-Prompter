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

/// Once the free scripts are all used, replacing one (delete it, then create a new one) takes one of these free changes,
/// shared by every script. When they are gone a new script needs Pro.
const freeChangeLimit = 15;

/// Whether the free changes are on for this platform. Switched on one platform at a time as each is tested; where it is
/// off, a deleted script keeps its free slot as before.
bool get freeChangesActive => Platform.isAndroid || Platform.isMacOS;

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
  const ProState({this.presented = const {}, this.plan = ProPlan.free, this.live = const {}});

  /// Ids of the scripts that use up a free slot, in the order they were counted: a script counts the first time it is
  /// saved or presented. A deleted script stays in the list, so deleting never hands its slot back for nothing.
  final Set<String> presented;
  final ProPlan plan;

  /// Ids of the scripts that exist now (the library). Used by the free changes to tell a deleted script from a kept one.
  final Set<String> live;

  bool get isPro => plan != ProPlan.free;

  /// Free slots in use: the counted scripts that still exist (with the free changes on), or every counted script.
  int get used => freeChangesActive ? presented.where(live.contains).length : presented.length;

  /// Free changes spent: every script counted after the first [freeScriptLimit] replaced one.
  int get changesUsed => freeChangesActive ? (presented.length - freeScriptLimit).clamp(0, freeChangeLimit) : 0;
  int get changesLeft => freeChangeLimit - changesUsed;

  /// The free changes matter now: all the free scripts have been counted at least once.
  bool get changesStarted => proEnforced && !isPro && freeChangesActive && presented.length >= freeScriptLimit;

  /// A new script would take a free change (a slot is free, but only because another script was deleted).
  bool get createCostsChange => changesStarted && used < freeScriptLimit && changesLeft > 0;

  /// A slot is free, but every free change is spent.
  bool get changesExhausted => changesStarted && used < freeScriptLimit && changesLeft <= 0;

  /// A free user may not create another script: no free slot, or no free change left to use one.
  bool get limitReached => !isPro && !_hasRoom;

  bool get _hasRoom => used < freeScriptLimit && !(freeChangesActive && presented.length >= freeScriptLimit && changesLeft <= 0);

  /// Whether the script with [id] (null: a script not saved before) may be presented. A counted script is free if it is
  /// among the first [freeScriptLimit]; one not counted yet is free while a slot is left.
  bool canPresent(String? id) {
    if (!proEnforced || isPro) return true;
    final counted = freeChangesActive ? presented.where(live.contains).toList() : presented.toList();
    final at = id == null ? -1 : counted.indexOf(id);
    return at >= 0 ? at < freeScriptLimit : _hasRoom;
  }

  /// Whether a new script may be saved: the limit is off, the user is Pro, or a free slot is left. Once the free scripts are used a new script is not created at all; the upgrade sheet opens instead.
  bool get canCreate => !proEnforced || isPro || _hasRoom;

  ProState copyWith({Set<String>? presented, ProPlan? plan, Set<String>? live}) =>
      ProState(presented: presented ?? this.presented, plan: plan ?? this.plan, live: live ?? this.live);
}

/// Why the upgrade sheet opens: the free scripts or the free changes ran out.
String proLimitReason(ProState pro) =>
    pro.changesExhausted ? "You've used your $freeChangeLimit free changes." : "You've used your $freeScriptLimit free scripts.";
