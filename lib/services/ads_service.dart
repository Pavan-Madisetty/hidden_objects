import 'dart:async';

/// Ad provider abstraction. Implement this for AdMob / Unity / etc. and pass
/// it to the game controller; nothing else in the game changes.
abstract class AdsService {
  Future<void> init();

  /// Set when the player bought "Remove Ads" (also disables interstitials).
  bool adsRemoved = false;

  /// Shows an optional rewarded ad. Returns true if the reward was earned.
  Future<bool> showRewarded(String placement);

  /// Shows an interstitial at a natural break. Never called mid-level.
  Future<void> showInterstitial(String placement);
}

/// How the mock ad is presented (implemented by the UI layer).
typedef AdPresenter = Future<bool> Function(String kind, String placement);

/// Placeholder used until a real ad SDK is connected: shows a friendly fake ad
/// dialog so the whole flow can be played and tested.
class MockAdsService extends AdsService {
  AdPresenter? presenter;

  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewarded(String placement) async {
    final p = presenter;
    if (p == null) return true;
    return p('rewarded', placement);
  }

  @override
  Future<void> showInterstitial(String placement) async {
    if (adsRemoved) return;
    final p = presenter;
    if (p != null) await p('interstitial', placement);
  }
}

/// Child-safe interstitial pacing: only after a completed level, never in the
/// first minutes, and rarely.
class AdPolicy {
  static const int firstAdLevel = 8;
  static const int levelsBetweenAds = 4;
  static const int minGapMs = 4 * 60 * 1000;

  static bool shouldShowInterstitial({
    required bool adsRemoved,
    required int levelId,
    required int levelsSinceAd,
    required int lastAdMs,
    required int nowMs,
  }) {
    if (adsRemoved) return false;
    if (levelId < firstAdLevel) return false;
    if (levelsSinceAd < levelsBetweenAds) return false;
    if (lastAdMs != 0 && nowMs - lastAdMs < minGapMs) return false;
    return true;
  }
}
