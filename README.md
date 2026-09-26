# Seek & Sparkle - kids hidden-object adventure (Flutter)

Run `./bootstrap.sh` once (creates platform folders, runs analyze + tests), then `flutter run`.

Add content without engine changes:
- New world: add a `world_XX.dart` builder and register it in `lib/data/worlds/worlds.dart`, plus music in `lib/data/audio_catalog.dart`.
- New/hand-tuned levels: `HandAuthoredSource` or `JsonLevelSource` in `lib/data/level_repository.dart`.
- Real music: set `MusicTrack.assetPath` and drop files in `assets/audio/`.
- Backends: implement `LeaderboardService`, `AdsService`, `PurchaseService`, `AnalyticsSink`, `CloudSync`.
