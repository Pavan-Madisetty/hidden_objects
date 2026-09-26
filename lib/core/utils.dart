import 'dart:math';
import 'dart:ui';

/// Returns [c] with the given opacity (0..1). Works on every Flutter version.
Color alpha(Color c, double opacity) =>
    c.withAlpha((opacity.clamp(0.0, 1.0) * 255).round());

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

Color lighten(Color c, [double amount = 0.15]) => mix(c, const Color(0xFFFFFFFF), amount);
Color darken(Color c, [double amount = 0.15]) => mix(c, const Color(0xFF000000), amount);

/// yyyymmdd key for a date.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  if (key.length != 8) return DateTime(2000);
  return DateTime(int.parse(key.substring(0, 4)), int.parse(key.substring(4, 6)),
      int.parse(key.substring(6, 8)));
}

/// Number of whole calendar days from [a] to [b] (b - a).
int daysBetweenKeys(String a, String b) {
  final da = parseDayKey(a);
  final db = parseDayKey(b);
  final ua = DateTime.utc(da.year, da.month, da.day);
  final ub = DateTime.utc(db.year, db.month, db.day);
  return ub.difference(ua).inDays;
}

/// Key of the Monday that starts the week containing [d].
String weekKey(DateTime d) {
  final monday = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
  return dayKey(monday);
}

/// Stable (platform independent) string hash.
int stableHash(String s) {
  var h = 2166136261;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 16777619) & 0x7fffffff;
  }
  return h;
}

/// Small deterministic RNG wrapper so generated content is reproducible.
class Rng {
  Rng(int seed) : _r = Random(seed);
  final Random _r;
  int nextInt(int max) => max <= 0 ? 0 : _r.nextInt(max);
  double nextDouble() => _r.nextDouble();
  bool chance(double p) => _r.nextDouble() < p;
  T pick<T>(List<T> list) => list[_r.nextInt(list.length)];
  List<T> shuffled<T>(Iterable<T> items) {
    final l = items.toList();
    for (var i = l.length - 1; i > 0; i--) {
      final j = _r.nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
    return l;
  }
}

String formatSeconds(int s) {
  final m = s ~/ 60;
  final r = s % 60;
  return '$m:${r.toString().padLeft(2, '0')}';
}

int clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
