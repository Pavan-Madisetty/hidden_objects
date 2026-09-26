import 'ads_service.dart';
import 'analytics_service.dart';
import 'audio_service.dart';
import 'iap_service.dart';
import 'leaderboard_service.dart';
import 'save_service.dart';

/// Dependency container. Swap any implementation (real ads, cloud saves,
/// Firebase analytics, a real leaderboard...) here without touching gameplay.
class Services {
  Services({
    required this.store,
    required this.save,
    required this.audio,
    required this.analytics,
    required this.ads,
    required this.iap,
    required this.leaderboard,
  });

  final SaveStore store;
  final SaveService save;
  final AudioService audio;
  final AnalyticsService analytics;
  final AdsService ads;
  final PurchaseService iap;
  final LeaderboardService leaderboard;

  factory Services.defaults() {
    final store = PrefsSaveStore();
    return Services(
      store: store,
      save: SaveService(store),
      audio: AudioService(),
      analytics: LocalAnalytics(store),
      ads: MockAdsService(),
      iap: MockPurchaseService(),
      leaderboard: LocalLeaderboardService(),
    );
  }
}
