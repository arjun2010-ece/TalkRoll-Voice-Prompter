import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/entitlements/entitlements.dart';
import 'purchase_service.dart';

const _fakePlanKey = 'EchoPrompter.debugFakePlan.v1';

/// What the next fake purchase does, set from Settings → Preview (debug builds only), so cancel, pending and failure
/// can be tried without a store.
class FakeOutcome extends Notifier<PurchaseOutcome> {
  @override
  PurchaseOutcome build() => PurchaseOutcome.purchased;
  void set(PurchaseOutcome o) => state = o;
}

final fakeOutcomeProvider = NotifierProvider<FakeOutcome, PurchaseOutcome>(FakeOutcome.new);

/// A stand-in for the stores in **debug builds only** (see [purchaseServiceProvider]): buying grants the plan after a
/// short pause, Restore finds it again, and the plan survives a restart. It does not exist in release builds, so it is
/// not a way to get Pro for free.
class FakePurchaseService implements PurchaseService {
  FakePurchaseService(this._prefs, this._outcome) {
    final saved = _prefs.getString(_fakePlanKey);
    _owned = ProPlan.values.where((p) => p.name == saved).firstOrNull ?? ProPlan.free;
    // The ownership known at start, like a store's first answer.
    Future.microtask(() {
      if (!_changes.isClosed && _owned != ProPlan.free) _changes.add(_owned);
    });
  }

  final SharedPreferences _prefs;

  /// What the next [buy] does, read when the purchase is made so the debug controls can change it.
  final PurchaseOutcome Function() _outcome;

  final _changes = StreamController<ProPlan>.broadcast();
  ProPlan _owned = ProPlan.free;

  @override
  Stream<ProPlan> get entitlement => _changes.stream;

  @override
  Future<List<ProOffer>> offers() async => placeholderOffers();

  @override
  Future<PurchaseResult> buy(ProPlan plan) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    switch (_outcome()) {
      case PurchaseOutcome.purchased:
        setPlan(plan);
        return const PurchaseResult(PurchaseOutcome.purchased);
      case PurchaseOutcome.cancelled:
        return const PurchaseResult(PurchaseOutcome.cancelled);
      case PurchaseOutcome.pending:
        return const PurchaseResult(PurchaseOutcome.pending, 'Waiting for approval. Pro turns on when it is approved.');
      case PurchaseOutcome.failed:
        return const PurchaseResult(PurchaseOutcome.failed, 'The test purchase failed.');
      case PurchaseOutcome.unavailable:
        return const PurchaseResult(PurchaseOutcome.unavailable, 'The store is not available.');
    }
  }

  @override
  Future<PurchaseResult> restore() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_owned == ProPlan.free) return const PurchaseResult(PurchaseOutcome.failed, 'No earlier purchase was found for this account.');
    _changes.add(_owned);
    return const PurchaseResult(PurchaseOutcome.purchased);
  }

  @override
  Future<bool> manage() async => false;

  /// Debug controls: set the plan directly (Free removes Pro).
  void setPlan(ProPlan plan) {
    _owned = plan;
    _prefs.setString(_fakePlanKey, plan.name);
    _changes.add(plan);
  }

  @override
  void dispose() => _changes.close();
}
