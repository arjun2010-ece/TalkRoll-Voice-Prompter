import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../core/script/saved_script.dart';
import '../../services/providers.dart';
import '../../services/purchases/fake_purchase_service.dart';
import '../../services/purchases/purchase_service.dart';
import '../../services/storage/reinstall_store.dart';

const _proKey = 'TalkRoll.proState.v1';
const _promptKey = 'TalkRoll.upgradePrompt.v1';
// The real store and the debug fake keep their last answer apart, so trying one never leaks Pro into the other.
String get _planKey => storePaymentsLive ? 'TalkRoll.proPlan.store.v1' : 'TalkRoll.proPlan.debug.v1';

/// The upgrade sheet opens by itself on app start at most this often.
const upgradePromptGap = Duration(hours: 24);

/// Free-script counter and plan. The plan comes from the purchase service: the real store when its payments switch is on,
/// the debug fake in debug builds, and Free otherwise. The counter is kept even while the limit is off, so the numbers
/// are right when it is switched on.
class ProNotifier extends Notifier<ProState> {
  static const _store = ReinstallStore();

  @override
  ProState build() {
    // After a reinstall the preferences can be empty while the count survives elsewhere (see [ReinstallStore]);
    // the two are merged once the store answers, and a restore can only raise the count.
    Future.microtask(_restore);
    // The store tells us what the account owns; the last answer is kept so a paying user stays Pro offline.
    final service = ref.read(purchaseServiceProvider);
    final updates = service.entitlement.listen(setPlan);
    ref.onDispose(updates.cancel);
    return ProState(
      presented: _decode(ref.read(prefsProvider).getString(_proKey)),
      plan: _cachedPlan(),
      live: {for (final s in ref.read(libraryProvider).load()) s.id},
    );
  }

  /// The plan last confirmed by the store. Only trusted where a store (real or the debug fake) can confirm it, so a
  /// release build with payments off is always Free.
  ProPlan _cachedPlan() {
    if (!storePaymentsLive && !kDebugMode) return ProPlan.free;
    final name = ref.read(prefsProvider).getString(_planKey);
    return ProPlan.values.where((p) => p.name == name).firstOrNull ?? ProPlan.free;
  }

  /// Sets the plan the store reported and remembers it.
  void setPlan(ProPlan plan) {
    if (plan == state.plan) return;
    state = state.copyWith(plan: plan);
    ref.read(prefsProvider).setString(_planKey, plan.name);
  }

  static Set<String> _decode(String? raw) {
    if (raw == null) return const {};
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return {...(j['presented'] as List? ?? const []).cast<String>()};
    } catch (_) {
      return const {};
    }
  }

  String get _encoded => jsonEncode({'presented': state.presented.toList()});

  Future<void> _restore() async {
    final kept = _decode(await _store.read());
    if (kept.difference(state.presented).isNotEmpty) {
      state = state.copyWith(presented: {...state.presented, ...kept});
      ref.read(prefsProvider).setString(_proKey, _encoded);
    }
    if (state.presented.isNotEmpty) await _store.write(_encoded);
  }

  void _save() {
    ref.read(prefsProvider).setString(_proKey, _encoded);
    _store.write(_encoded);
  }

  /// Tells the free changes which scripts exist now. Called whenever the library changes.
  void refreshLive(Iterable<SavedScript> scripts) => state = state.copyWith(live: {for (final s in scripts) s.id});

  /// Counts the script with [id] as used, once. Called when a script is first saved and when it is presented, so a
  /// script that is written but never played still takes its slot.
  void recordStart(String id) {
    if (state.presented.contains(id)) return;
    state = state.copyWith(presented: {...state.presented, id});
    _save();
  }

  /// Whether the upgrade sheet should open on its own now: the limit is on and used up, and no upgrade sheet was shown
  /// in the last [upgradePromptGap]. Never true for Pro.
  bool launchPromptDue([DateTime? now]) {
    if (!proEnforced || !state.limitReached) return false;
    final last = ref.read(prefsProvider).getInt(_promptKey) ?? 0;
    return (now ?? DateTime.now()).millisecondsSinceEpoch - last >= upgradePromptGap.inMilliseconds;
  }

  /// Remembers that an upgrade sheet was shown, from any surface, so the next automatic one waits.
  void notePromptShown([DateTime? now]) =>
      ref.read(prefsProvider).setInt(_promptKey, (now ?? DateTime.now()).millisecondsSinceEpoch);

  /// Debug builds only: set the plan from Settings → Preview. With the debug fake store this changes what the "store"
  /// owns (so Restore and a restart agree); otherwise it only changes what the screens show.
  void previewPlan(ProPlan plan) {
    final service = ref.read(purchaseServiceProvider);
    if (service is FakePurchaseService) {
      service.setPlan(plan);
    } else {
      state = state.copyWith(plan: plan);
    }
  }
}

final proProvider = NotifierProvider<ProNotifier, ProState>(ProNotifier.new);

/// The Studio's upgrade card was closed with its × this session. Not saved: the card is back on the next launch.
class UpgradeCardHidden extends Notifier<bool> {
  @override
  bool build() => false;
  void hide() => state = true;
}

final upgradeCardHiddenProvider = NotifierProvider<UpgradeCardHidden, bool>(UpgradeCardHidden.new);

/// Counts the times a new script was refused because the free scripts are used up. The Studio's app-wide wrapper
/// listens and opens the upgrade sheet, so every way of creating a script (New, Import, Duplicate, typing over the
/// demo) gets the same answer.
class SaveBlocked extends Notifier<int> {
  @override
  int build() => 0;
  void blocked() => state = state + 1;
}

final saveBlockedProvider = NotifierProvider<SaveBlocked, int>(SaveBlocked.new);
