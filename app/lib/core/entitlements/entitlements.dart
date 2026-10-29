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

/// Whether the free-script limit is enforced. Off in normal builds until billing is connected (plan Phase 3): the Pro
/// screens work and free scripts are counted, but nothing is locked, because a locked free user with no way to buy
/// would be stuck. Build with `--dart-define=ENFORCE_FREE_LIMIT=true` to run the whole upgrade path: the locked Start,
/// the upgrade sheet, the reminder card and the sheet on app open.
const proEnforced = bool.fromEnvironment('ENFORCE_FREE_LIMIT');

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

  ProState copyWith({Set<String>? presented, ProPlan? plan}) =>
      ProState(presented: presented ?? this.presented, plan: plan ?? this.plan);
}
