import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/player_data.dart';

/// Where raw save strings live. Swap for a file / database if you like.
abstract class SaveStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class PrefsSaveStore implements SaveStore {
  SharedPreferences? _p;
  Future<SharedPreferences> get _prefs async => _p ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _prefs).getString(key);

  @override
  Future<void> write(String key, String value) async {
    await (await _prefs).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _prefs).remove(key);
  }
}

/// In-memory store (tests, or when storage is unavailable).
class MemorySaveStore implements SaveStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Optional cloud sync. The default does nothing, so the game is fully
/// offline; plug in Firebase / Play Games / your backend later.
abstract class CloudSync {
  bool get available;
  Future<PlayerData?> pull();
  Future<void> push(PlayerData data);
}

class NoopCloudSync implements CloudSync {
  @override
  bool get available => false;
  @override
  Future<PlayerData?> pull() async => null;
  @override
  Future<void> push(PlayerData data) async {}
}

/// Reliable local persistence: debounced writes, a rolling backup and
/// corruption fallback so progress is never lost.
class SaveService {
  SaveService(this.store, {CloudSync? cloud}) : cloud = cloud ?? NoopCloudSync();

  static const String mainKey = 'save_v1';
  static const String backupKey = 'save_v1_bak';

  final SaveStore store;
  final CloudSync cloud;
  Timer? _debounce;
  String? _lastJson;
  PlayerData? _pendingData;

  Future<PlayerData> load() async {
    PlayerData? data = await _tryParse(mainKey);
    data ??= await _tryParse(backupKey);
    data ??= PlayerData();
    if (cloud.available) {
      try {
        final remote = await cloud.pull();
        if (remote != null) data.mergeFrom(remote);
      } catch (e) {
        debugPrint('Cloud pull failed (ignored): $e');
      }
    }
    return data;
  }

  Future<PlayerData?> _tryParse(String key) async {
    try {
      final raw = await store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw);
      if (j is Map<String, dynamic>) {
        _lastJson = raw;
        return PlayerData.fromJson(j);
      }
    } catch (e) {
      debugPrint('Save "$key" unreadable: $e');
    }
    return null;
  }

  /// Coalesces bursts of changes into a single write.
  void scheduleSave(PlayerData data) {
    _pendingData = data;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => flush());
  }

  Future<void> flush() async {
    _debounce?.cancel();
    final data = _pendingData;
    if (data == null) return;
    _pendingData = null;
    await save(data);
  }

  Future<void> save(PlayerData data) async {
    try {
      final json = jsonEncode(data.toJson());
      if (json == _lastJson) return;
      final prev = _lastJson;
      if (prev != null) await store.write(backupKey, prev);
      await store.write(mainKey, json);
      _lastJson = json;
      if (cloud.available) {
        unawaited(cloud.push(data).catchError((Object _) {}));
      }
    } catch (e) {
      debugPrint('Save failed: $e');
    }
  }

  Future<void> wipe() async {
    _debounce?.cancel();
    _pendingData = null;
    _lastJson = null;
    await store.remove(mainKey);
    await store.remove(backupKey);
  }
}
