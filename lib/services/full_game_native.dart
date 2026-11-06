// Buying the full game on Google Play: one non-consumable product, [fullGameProduct]. A reinstall
// or a new phone on the same Google account finds the purchase again (restorePurchases).
import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';

import 'full_game.dart';

bool get supported => Platform.isAndroid;

ProductDetails? _product;
StreamSubscription<List<PurchaseDetails>>? _sub;

Future<void> init(FullGame g) async {
  if (!supported) return;
  final iap = InAppPurchase.instance;
  if (!await iap.isAvailable()) return;
  _sub ??= iap.purchaseStream.listen((list) => _onPurchases(g, list), onError: (Object _) {
    g.busy = false;
    g.problem = 'The purchase didn\'t go through';
    g.changed();
  });
  final found = await iap.queryProductDetails({fullGameProduct});
  _product = found.productDetails.where((p) => p.id == fullGameProduct).firstOrNull;
  g.price = _product?.price;
  g.changed();
  // Quietly look for an earlier purchase (a reinstall, a new phone).
  if (!g.owned) await iap.restorePurchases();
}

Future<void> _onPurchases(FullGame g, List<PurchaseDetails> list) async {
  for (final p in list) {
    if (p.productID != fullGameProduct) continue;
    switch (p.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await g.grant();
      case PurchaseStatus.pending:
        g.busy = true;
        g.problem = 'Waiting for Google Play to confirm the payment…';
        g.changed();
      case PurchaseStatus.error:
        g.busy = false;
        g.problem = 'The purchase didn\'t go through${p.error?.message == null ? '' : ' (${p.error!.message})'}';
        g.changed();
      case PurchaseStatus.canceled:
        g.busy = false;
        g.changed();
    }
    if (p.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(p);
  }
}

Future<void> buy(FullGame g) async {
  final p = _product;
  if (p == null) {
    g.problem = 'Couldn\'t reach Google Play just now. Try again in a moment.';
    g.changed();
    // (Ask again: a slow start may have missed it.)
    try {
      final found = await InAppPurchase.instance.queryProductDetails({fullGameProduct});
      _product = found.productDetails.where((x) => x.id == fullGameProduct).firstOrNull;
      g.price = _product?.price;
      g.changed();
    } catch (_) {}
    return;
  }
  g.busy = true;
  g.changed();
  try {
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  } catch (_) {
    g.busy = false;
    g.problem = 'The purchase didn\'t go through';
    g.changed();
  }
}

Future<void> restore(FullGame g) async {
  if (!supported) return;
  await InAppPurchase.instance.restorePurchases();
}
