import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'synth.dart';

export 'synth.dart' show Sfx, SongSpec;

/// A background music track. Give it an [assetPath] (relative to `assets/`)
/// to use a real audio file, or a [synth] spec for generated music.
class MusicTrack {
  const MusicTrack(this.id, {this.assetPath, this.synth});
  final String id;
  final String? assetPath;
  final SongSpec? synth;
}

/// Music + sound effects. Every call is fail-safe: audio problems (autoplay
/// policies, missing codecs, no device) must never break the game.
class AudioService {
  final Map<String, MusicTrack> _tracks = {};
  final Map<String, Uint8List> _musicCache = {};
  final Map<String, Future<Uint8List>> _pending = {};
  final Map<Sfx, Uint8List> _sfxCache = {};
  final List<AudioPlayer> _sfxPlayers = [];
  AudioPlayer? _music;
  int _sfxNext = 0;
  String? _current;
  String? _wanted;
  bool _ready = false;

  double musicVolume = 0.6;
  double sfxVolume = 0.85;
  bool muted = false;

  double get _musicGain => muted ? 0.0 : musicVolume * 0.7;

  void registerTrack(MusicTrack t) => _tracks[t.id] = t;
  void registerTracks(Iterable<MusicTrack> ts) {
    for (final t in ts) {
      registerTrack(t);
    }
  }

  Future<void> init({double? music, double? sfx, bool? mute}) async {
    if (music != null) musicVolume = music;
    if (sfx != null) sfxVolume = sfx;
    if (mute != null) muted = mute;
    try {
      _music = AudioPlayer();
      await _music!.setReleaseMode(ReleaseMode.loop);
      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.stop);
        _sfxPlayers.add(p);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  Future<Uint8List> _load(MusicTrack t) {
    return _pending.putIfAbsent(t.id, () async {
      final spec = t.synth;
      if (spec == null) return Uint8List(0);
      final bytes = await compute(synthSong, spec);
      _musicCache[t.id] = bytes;
      return bytes;
    });
  }

  /// Generate tracks in the background so they start instantly later.
  void preload(Iterable<String> ids) {
    for (final id in ids) {
      final t = _tracks[id];
      if (t != null && t.assetPath == null) {
        unawaited(_load(t).catchError((Object _) => Uint8List(0)));
      }
    }
  }

  Future<void> playMusic(String id) async {
    _wanted = id;
    if (!_ready) return;
    if (_current == id) return;
    final t = _tracks[id];
    final player = _music;
    if (t == null || player == null) return;
    try {
      Source src;
      if (t.assetPath != null) {
        src = AssetSource(t.assetPath!);
      } else {
        final bytes = _musicCache[id] ?? await _load(t);
        if (bytes.isEmpty) return;
        src = BytesSource(bytes);
      }
      if (_wanted != id) return; // a newer request superseded this one
      await player.stop();
      await player.setVolume(_musicGain);
      await player.play(src);
      _current = id;
    } catch (e) {
      debugPrint('Music failed: $e');
    }
  }

  /// Call after a user gesture (needed on the web) to (re)start music.
  Future<void> ensureMusic() async {
    final w = _wanted;
    if (w != null && _current != w) await playMusic(w);
  }

  Future<void> stopMusic() async {
    _wanted = null;
    _current = null;
    try {
      await _music?.stop();
    } catch (_) {}
  }

  Future<void> pauseAll() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> resumeAll() async {
    try {
      if (_current != null) {
        await _music?.resume();
      } else {
        await ensureMusic();
      }
    } catch (_) {}
  }

  void apply({double? music, double? sfx, bool? mute}) {
    if (music != null) musicVolume = music;
    if (sfx != null) sfxVolume = sfx;
    if (mute != null) muted = mute;
    try {
      _music?.setVolume(_musicGain);
    } catch (_) {}
  }

  void sfx(Sfx s) {
    if (!_ready || muted || sfxVolume <= 0.01 || _sfxPlayers.isEmpty) return;
    try {
      final bytes = _sfxCache.putIfAbsent(s, () => buildSfx(s));
      final p = _sfxPlayers[_sfxNext++ % _sfxPlayers.length];
      unawaited(p.play(BytesSource(bytes), volume: sfxVolume).catchError((Object _) {}));
    } catch (e) {
      debugPrint('SFX failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _music?.dispose();
      for (final p in _sfxPlayers) {
        await p.dispose();
      }
    } catch (_) {}
  }
}
