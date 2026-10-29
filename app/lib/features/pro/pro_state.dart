import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/entitlements/entitlements.dart';
import '../../services/providers.dart';
import '../../services/storage/reinstall_store.dart';

const _proKey = 'EchoPrompter.proState.v1';
const _promptKey = 'EchoPrompter.upgradePrompt.v1';

/// The upgrade sheet opens by itself on app start at most this often.
const upgradePromptGap = Duration(hours: 24);

/// Free-script counter and plan. Purchases aren't connected yet, so the plan stays Free outside debug
/// builds; the counter is kept now so the numbers are right when the limit is switched on.
class ProNotifier extends Notifier<ProState> {
  static const _store = ReinstallStore();

  @override
  ProState build() {
    // After a reinstall the preferences can be empty while the count survives elsewhere (see [ReinstallStore]);
    // the two are merged once the store answers, and a restore can only raise the count.
    Future.microtask(_restore);
    return ProState(presented: _decode(ref.read(prefsProvider).getString(_proKey)));
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

  /// Debug builds only: preview the Pro screens in each state. Never saved.
  void previewPlan(ProPlan plan) => state = state.copyWith(plan: plan);
}

final proProvider = NotifierProvider<ProNotifier, ProState>(ProNotifier.new);

/// The Studio's upgrade card was closed with its × this session. Not saved: the card is back on the next launch.
class UpgradeCardHidden extends Notifier<bool> {
  @override
  bool build() => false;
  void hide() => state = true;
}

final upgradeCardHiddenProvider = NotifierProvider<UpgradeCardHidden, bool>(UpgradeCardHidden.new);
