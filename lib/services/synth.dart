import 'dart:math';
import 'dart:typed_data';

/// Tiny offline synthesiser. Every sound effect and every music loop in the
/// game is generated here, so the game ships with (soft, child friendly)
/// audio without any binary assets - and any track can be replaced by a real
/// audio file later (see AudioService.registerTrack).

const int kRate = 22050;

enum Sfx {
  tap,
  found,
  wrong,
  drawer,
  door,
  complete,
  coin,
  star,
  hint,
  unlock,
  daily,
  pop,
}

/// Describes a generative music loop.
class SongSpec {
  const SongSpec({
    required this.bpm,
    required this.root,
    required this.scale,
    required this.seed,
    this.bars = 8,
    this.chordRoots = const [0, -3, -7, -5],
    this.minor = const [false, true, false, false],
    this.density = 0.62,
  });

  final int bpm;

  /// MIDI note of the tonic.
  final int root;

  /// Semitone offsets of the scale used for the melody.
  final List<int> scale;
  final int seed;
  final int bars;
  final List<int> chordRoots;
  final List<bool> minor;

  /// Probability that a melody step plays a note (lower = calmer).
  final double density;
}

double _hz(num midi) => 440.0 * pow(2.0, (midi - 69) / 12.0);

class _Lcg {
  _Lcg(int seed) : _s = (seed * 2654435761) & 0x7fffffff;
  int _s;
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }
}

class _Buf {
  _Buf(double seconds) : data = Float64List((seconds * kRate).ceil());
  final Float64List data;

  /// Adds a note. [timbre]: 0 soft sine, 1 bell, 2 warm (saw-ish), 3 pad.
  void tone(
    double start,
    double dur,
    double hz, {
    double vol = 0.3,
    double attack = 0.008,
    double decay = 3.0,
    int timbre = 1,
    double? slideTo,
    double release = 0.0,
  }) {
    final i0 = (start * kRate).floor();
    final n = (dur * kRate).floor();
    for (var k = 0; k < n; k++) {
      final idx = i0 + k;
      if (idx < 0) continue;
      if (idx >= data.length) break;
      final t = k / kRate;
      final f = slideTo == null ? hz : hz + (slideTo - hz) * (t / dur);
      final ph = 2 * pi * f * t;
      double w;
      switch (timbre) {
        case 0:
          w = sin(ph);
          break;
        case 1:
          w = sin(ph) + 0.28 * sin(2 * ph) + 0.10 * sin(3.01 * ph);
          break;
        case 2:
          w = sin(ph) + 0.35 * sin(2 * ph) + 0.18 * sin(3 * ph) + 0.08 * sin(4 * ph);
          break;
        default:
          w = 0.6 * sin(ph) + 0.4 * sin(2 * pi * f * 1.004 * t);
      }
      var env = t < attack ? t / attack : 1.0;
      if (timbre == 3) {
        // sustained pad with gentle release
        final rel = release <= 0 ? 0.4 : release;
        final tail = (dur - t) / rel;
        env *= tail < 1 ? max(0.0, tail) : 1.0;
      } else {
        env *= exp(-decay * t);
      }
      data[idx] += w * env * vol;
    }
  }

  /// Soft filtered noise (whooshes, creaks).
  void noise(double start, double dur, {double vol = 0.2, double lp = 0.12, int seed = 7}) {
    final rnd = Random(seed);
    final i0 = (start * kRate).floor();
    final n = (dur * kRate).floor();
    var y = 0.0;
    for (var k = 0; k < n; k++) {
      final idx = i0 + k;
      if (idx < 0) continue;
      if (idx >= data.length) break;
      final x = rnd.nextDouble() * 2 - 1;
      y += lp * (x - y);
      final p = k / n;
      final env = sin(pi * p); // fade in and out
      data[idx] += y * env * vol * 3.0;
    }
  }

  Float64List finish({double peak = 0.85}) {
    var m = 0.0;
    for (final v in data) {
      final a = v.abs();
      if (a > m) m = a;
    }
    final g = m > 0 ? peak / m : 1.0;
    final n = data.length;
    final fade = min(n ~/ 2, (0.02 * kRate).floor());
    for (var i = 0; i < n; i++) {
      var v = data[i] * g;
      if (i < fade) v *= i / fade;
      if (i > n - fade) v *= (n - i) / fade;
      data[i] = v;
    }
    return data;
  }
}

Uint8List encodeWav(Float64List s) {
  final n = s.length;
  final bytes = Uint8List(44 + n * 2);
  final b = ByteData.view(bytes.buffer);
  void ascii(int off, String t) {
    for (var i = 0; i < t.length; i++) {
      b.setUint8(off + i, t.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + n * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little);
  b.setUint16(22, 1, Endian.little);
  b.setUint32(24, kRate, Endian.little);
  b.setUint32(28, kRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final v = ((s[i] < -1.0 ? -1.0 : (s[i] > 1.0 ? 1.0 : s[i])) * 32767).round();
    b.setInt16(44 + i * 2, v, Endian.little);
  }
  return bytes;
}

/// Sound effect -> WAV bytes.
Uint8List buildSfx(Sfx sfx) {
  Float64List out;
  switch (sfx) {
    case Sfx.tap: {
      final b = _Buf(0.1)..tone(0, 0.09, 660, vol: 0.3, decay: 30, timbre: 0);
      out = b.finish(peak: 0.5);
      break;
    }
    case Sfx.pop: {
      final b = _Buf(0.2)..tone(0, 0.16, 520, slideTo: 900, vol: 0.3, decay: 12, timbre: 0);
      out = b.finish(peak: 0.5);
      break;
    }
    case Sfx.found: {
      final b = _Buf(0.7)
        ..tone(0.0, 0.5, _hz(84), vol: 0.3, decay: 6)
        ..tone(0.07, 0.5, _hz(88), vol: 0.3, decay: 6)
        ..tone(0.14, 0.55, _hz(91), vol: 0.3, decay: 5);
      out = b.finish(peak: 0.7);
      break;
    }
    case Sfx.wrong: {
      final b = _Buf(0.25)..tone(0, 0.22, 300, slideTo: 200, vol: 0.3, decay: 8, timbre: 0);
      out = b.finish(peak: 0.35);
      break;
    }
    case Sfx.drawer: {
      final b = _Buf(0.45)
        ..noise(0.0, 0.32, vol: 0.18, lp: 0.09, seed: 3)
        ..tone(0.0, 0.3, 110, slideTo: 80, vol: 0.4, decay: 9, timbre: 0)
        ..tone(0.28, 0.15, 620, vol: 0.12, decay: 14, timbre: 0);
      out = b.finish(peak: 0.6);
      break;
    }
    case Sfx.door: {
      final b = _Buf(0.6)
        ..noise(0.0, 0.45, vol: 0.12, lp: 0.05, seed: 5)
        ..tone(0.0, 0.45, 190, slideTo: 280, vol: 0.18, decay: 3, timbre: 2)
        ..tone(0.42, 0.15, 90, vol: 0.4, decay: 14, timbre: 0);
      out = b.finish(peak: 0.6);
      break;
    }
    case Sfx.coin: {
      final b = _Buf(0.45)
        ..tone(0.0, 0.3, _hz(88), vol: 0.3, decay: 9)
        ..tone(0.07, 0.35, _hz(93), vol: 0.3, decay: 8);
      out = b.finish(peak: 0.6);
      break;
    }
    case Sfx.star: {
      final b = _Buf(0.7)
        ..tone(0.0, 0.45, _hz(91), vol: 0.3, decay: 7)
        ..tone(0.07, 0.45, _hz(96), vol: 0.3, decay: 7)
        ..tone(0.14, 0.5, _hz(100), vol: 0.3, decay: 6);
      out = b.finish(peak: 0.65);
      break;
    }
    case Sfx.hint: {
      final b = _Buf(0.9)
        ..tone(0.0, 0.7, 880, slideTo: 1320, vol: 0.14, attack: 0.15, timbre: 3, release: 0.3)
        ..tone(0.0, 0.7, 883, slideTo: 1326, vol: 0.14, attack: 0.15, timbre: 3, release: 0.3)
        ..tone(0.45, 0.4, _hz(96), vol: 0.2, decay: 8);
      out = b.finish(peak: 0.5);
      break;
    }
    case Sfx.complete: {
      final b = _Buf(2.0);
      const notes = [72, 76, 79, 84];
      for (var i = 0; i < notes.length; i++) {
        b.tone(i * 0.13, 0.7, _hz(notes[i]), vol: 0.28, decay: 4);
      }
      for (final n in notes) {
        b.tone(0.55, 1.4, _hz(n), vol: 0.12, decay: 2.2);
      }
      out = b.finish(peak: 0.75);
      break;
    }
    case Sfx.unlock: {
      final b = _Buf(2.4);
      const notes = [67, 71, 74, 79, 83];
      for (var i = 0; i < notes.length; i++) {
        b.tone(i * 0.14, 0.8, _hz(notes[i]), vol: 0.26, decay: 3.5);
      }
      for (final n in [67, 71, 74, 79]) {
        b.tone(0.75, 1.6, _hz(n), vol: 0.12, decay: 1.8);
      }
      out = b.finish(peak: 0.75);
      break;
    }
    case Sfx.daily: {
      final b = _Buf(1.6);
      const notes = [79, 83, 86, 91];
      for (var i = 0; i < notes.length; i++) {
        b.tone(i * 0.09, 0.6, _hz(notes[i]), vol: 0.26, decay: 4.5);
      }
      for (final n in [79, 83, 86]) {
        b.tone(0.4, 1.1, _hz(n), vol: 0.12, decay: 2.5);
      }
      out = b.finish(peak: 0.7);
      break;
    }
  }
  return encodeWav(out);
}

/// Music loop -> WAV bytes (top-level so it can run inside `compute`).
Uint8List synthSong(SongSpec s) {
  final beat = 60.0 / s.bpm;
  final barLen = beat * 4;
  final total = barLen * s.bars;
  final buf = _Buf(total);
  final rng = _Lcg(s.seed);
  final n = s.scale.length;
  var deg = n ~/ 2 + 1;

  for (var bar = 0; bar < s.bars; bar++) {
    final t0 = bar * barLen;
    final ci = bar % s.chordRoots.length;
    final croot = s.root + s.chordRoots[ci];
    final third = s.minor[ci % s.minor.length] ? 3 : 4;

    // warm pad
    for (final off in [0, third, 7]) {
      buf.tone(t0, barLen + 0.15, _hz(croot - 12 + off), vol: 0.09, attack: 0.35, timbre: 3, release: 0.5);
    }
    // soft bass
    buf.tone(t0, beat * 1.6, _hz(croot - 24), vol: 0.16, attack: 0.02, decay: 2.2, timbre: 0);
    buf.tone(t0 + beat * 2, beat * 1.6, _hz(croot - 24 + 7), vol: 0.12, attack: 0.02, decay: 2.2, timbre: 0);

    // melody: eighth notes with rests, walking gently around the scale
    for (var k = 0; k < 8; k++) {
      if (k != 0 && rng.next() > s.density) continue;
      final r = rng.next();
      final step = r < 0.18 ? -2 : (r < 0.42 ? -1 : (r < 0.58 ? 0 : (r < 0.82 ? 1 : 2)));
      deg = deg + step < 0 ? 0 : (deg + step > n * 2 - 1 ? n * 2 - 1 : deg + step);
      final midi = s.root + 12 + s.scale[deg % n] + 12 * (deg ~/ n);
      buf.tone(t0 + k * beat / 2, beat * 1.5, _hz(midi), vol: 0.17, decay: 2.8, timbre: 1);
    }
  }
  return encodeWav(buf.finish(peak: 0.8));
}
