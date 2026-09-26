import 'dart:async';

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
    required this.emoji,
    this.available = true,
  });

  final String id;
  final String title;
  final String description;
  final String priceLabel;
  final String emoji;
  final bool available;
}

/// In-app purchase abstraction (Google Play Billing / StoreKit adapter goes
/// here). Purchases are cosmetic or convenience only.
abstract class PurchaseService {
  List<StoreProduct> get products;

  /// Returns true when the purchase succeeded.
  Future<bool> purchase(String productId);
  Future<Set<String>> restore();
}

class ProductIds {
  static const removeAds = 'remove_ads';
  static const sparklePack = 'sparkle_pack';
  static const worldPack = 'world_pack_dino';
}

typedef PurchasePresenter = Future<bool> Function(StoreProduct product);

class MockPurchaseService implements PurchaseService {
  PurchasePresenter? presenter;
  final Set<String> _owned = {};

  @override
  List<StoreProduct> get products => const [
        StoreProduct(
          id: ProductIds.removeAds,
          title: 'Remove Ads',
          description: 'No more ads, ever.',
          priceLabel: '\$2.99',
          emoji: '🚫',
        ),
        StoreProduct(
          id: ProductIds.sparklePack,
          title: 'Sparkle Pack',
          description: '500 coins + a golden hat.',
          priceLabel: '\$1.99',
          emoji: '✨',
        ),
        StoreProduct(
          id: ProductIds.worldPack,
          title: 'Dino Land (soon)',
          description: 'A brand new world of 10 levels.',
          priceLabel: 'Coming soon',
          emoji: '🦖',
          available: false,
        ),
      ];

  @override
  Future<bool> purchase(String productId) async {
    final product = products.firstWhere((p) => p.id == productId);
    if (!product.available) return false;
    final ok = presenter == null ? true : await presenter!(product);
    if (ok) _owned.add(productId);
    return ok;
  }

  @override
  Future<Set<String>> restore() async => Set.of(_owned);
}
