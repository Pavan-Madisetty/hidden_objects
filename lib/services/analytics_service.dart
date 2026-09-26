import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'save_service.dart';

/// Event names used across the game.
class Ev {
  static const appOpened = 'app_opened';
  static const levelStarted = 'level_started';
  static const levelCompleted = 'level_completed';
  static const levelFailed = 'level_failed';
  static const levelQuit = 'level_quit';
  static const levelReplayed = 'level_replayed';
  static const hintUsed = 'hint_used';
  static const objectFound = 'object_found';
  static const dailyStarted = 'daily_challenge_started';
  static const dailyCompleted = 'daily_challenge_completed';
  static const adWatched = 'ad_watched';
  static const rewardClaimed = 'reward_claimed';
  static const worldUnlocked = 'world_unlocked';
  static const sessionEnd = 'session_duration';
  static const purchase = 'purchase';
}

/// Sends events somewhere (Firebase, your backend...). Implement this and add
/// it to [LocalAnalytics.sinks].
abstract class AnalyticsSink {
  void send(String name, Map<String, Object?> params);
}

class DebugSink implements AnalyticsSink {
  @override
  void send(String name, Map<String, Object?> params) {
    if (kDebugMode) debugPrint('[analytics] $name $params');
  }
}

abstract class AnalyticsService {
  Future<void> init();
  bool get enabled;
  set enabled(bool v);
  void log(String name, [Map<String, Object?> params = const {}]);
  Future<Map<String, LevelStat>> funnel();
}

/// Aggregated per-level statistics, used to find where players get stuck.
class LevelStat {
  LevelStat({this.starts = 0, this.completes = 0, this.fails = 0, this.quits = 0, this.totalMs = 0, this.hints = 0});
  int starts;
  int completes;
  int fails;
  int quits;
  int totalMs;
  int hints;

  double get completionRate => starts == 0 ? 0 : completes / starts;
  double get avgSeconds => completes == 0 ? 0 : totalMs / completes / 1000.0;

  Map<String, dynamic> toJson() => {
        's': starts,
        'c': completes,
        'f': fails,
        'q': quits,
        't': totalMs,
        'h': hints,
      };

  factory LevelStat.fromJson(Map<String, dynamic> j) => LevelStat(
        starts: (j['s'] as num?)?.toInt() ?? 0,
        completes: (j['c'] as num?)?.toInt() ?? 0,
        fails: (j['f'] as num?)?.toInt() ?? 0,
        quits: (j['q'] as num?)?.toInt() ?? 0,
        totalMs: (j['t'] as num?)?.toInt() ?? 0,
        hints: (j['h'] as num?)?.toInt() ?? 0,
      );
}

/// Privacy friendly analytics: no personal data, no device ids. Events go to
/// pluggable sinks and a small local funnel so drop-off is visible even when
/// fully offline.
class LocalAnalytics implements AnalyticsService {
  LocalAnalytics(this.store, {List<AnalyticsSink>? sinks}) : sinks = sinks ?? [DebugSink()];

  static const String _key = 'funnel_v1';
  final SaveStore store;
  final List<AnalyticsSink> sinks;
  final Map<String, LevelStat> _stats = {};
  Timer? _debounce;

  @override
  bool enabled = true;

  @override
  Future<void> init() async {
    try {
      final raw = await store.read(_key);
      if (raw != null) {
        final j = jsonDecode(raw);
        if (j is Map<String, dynamic>) {
          j.forEach((k, v) {
            if (v is Map<String, dynamic>) _stats[k] = LevelStat.fromJson(v);
          });
        }
      }
    } catch (_) {}
  }

  @override
  void log(String name, [Map<String, Object?> params = const {}]) {
    if (!enabled) return;
    for (final s in sinks) {
      try {
        s.send(name, params);
      } catch (_) {}
    }
    final lvl = params['level'];
    if (lvl != null) {
      final key = lvl.toString();
      final st = _stats.putIfAbsent(key, () => LevelStat());
      switch (name) {
        case Ev.levelStarted:
          st.starts++;
          break;
        case Ev.levelCompleted:
          st.completes++;
          st.totalMs += ((params['seconds'] as num?)?.toInt() ?? 0) * 1000;
          break;
        case Ev.levelFailed:
          st.fails++;
          break;
        case Ev.levelQuit:
          st.quits++;
          break;
        case Ev.hintUsed:
          st.hints++;
          break;
        default:
          return;
      }
      _persistSoon();
    }
  }

  void _persistSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      final m = _stats.map((k, v) => MapEntry(k, v.toJson()));
      unawaited(store.write(_key, jsonEncode(m)).catchError((Object _) {}));
    });
  }

  @override
  Future<Map<String, LevelStat>> funnel() async => Map.of(_stats);
}
