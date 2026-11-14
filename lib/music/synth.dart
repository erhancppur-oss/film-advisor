// Procedural background-music generator.
//
// Every track is composed and rendered on the device from a (theme, index)
// seed, so the app ships no audio files and there are no copyright issues.
// Each theme has its own tempo range, scales, chord progressions, rhythms and
// instruments; the seed varies key, tempo, progression, patterns, melody and
// instrument choices, giving [kTracksPerTheme] different pieces per theme.
//
// Pure Dart (no Flutter imports) so it can run in a background isolate and in
// unit tests.

import 'dart:math' as math;
import 'dart:typed_data';

const int kSampleRate = 22050;
const int kTracksPerTheme = 36;

const List<String> kMusicThemes = [
  'ambient',
  'horror',
  'comedy',
  'action',
  'suspense',
  'drama',
  'romance',
  'scifi',
  'epic',
  'playful',
  'documentary',
  'western',
  'upbeat',
];

// ------------------------------------------------------------------ scales

const _major = [0, 2, 4, 5, 7, 9, 11];
const _minor = [0, 2, 3, 5, 7, 8, 10];
const _dorian = [0, 2, 3, 5, 7, 9, 10];
const _phrygian = [0, 1, 3, 5, 7, 8, 10];
const _harmMinor = [0, 2, 3, 5, 7, 8, 11];
const _lydian = [0, 2, 4, 6, 7, 9, 11];
const _mixolydian = [0, 2, 4, 5, 7, 9, 10];

// ------------------------------------------------------------------ random

class _Rng {
  int _s;
  _Rng(int seed) : _s = ((seed * 2654435761) + 1013904223) & 0xffffffff {
    if (_s == 0) _s = 0x2545F491;
    for (int i = 0; i < 8; i++) {
      _next();
    }
  }

  int _next() {
    var x = _s;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    _s = x & 0xffffffff;
    return _s;
  }

  double next() => _next() / 4294967296.0;
  int nextInt(int n) => math.min(n - 1, (next() * n).floor());
  bool chance(double p) => next() < p;
  T pick<T>(List<T> l) => l[nextInt(l.length)];
  double range(double a, double b) => a + (b - a) * next();
  double noise() => next() * 2 - 1;
}

int _hash(String s) {
  int h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

double _tanh(double x) {
  final e = math.exp(2 * x.clamp(-10.0, 10.0));
  return (e - 1) / (e + 1);
}

double _mtof(num midi) => 440.0 * math.pow(2, (midi - 69) / 12).toDouble();

// ------------------------------------------------------------------ song

class _Song {
  _Song(this.rng);

  final _Rng rng;
  final int sr = kSampleRate;

  double bpm = 100;
  int beats = 4;
  int bars = 8;
  int length = 0;
  int tail = 0;
  late Float64List main;
  late Float64List echo;

  int root = 50;
  List<int> scale = _minor;
  List<int> prog = const [0, 0, 0, 0];
  double swing = 0;

  double reverbWet = 0.25;
  double reverbFb = 0.8;
  double echoBeats = 0.75;
  double echoFb = 0.35;
  double masterCut = 0.7;

  void setup(double bpmMin, double bpmMax, {int beatsPerBar = 4, double targetSec = 36}) {
    bpm = rng.range(bpmMin, bpmMax).roundToDouble();
    beats = beatsPerBar;
    final barSec = beats * 60 / bpm;
    final pl = prog.length;
    int b = (targetSec / barSec).round();
    b = math.max(pl, (b / pl).round() * pl);
    while (b * barSec > 50 && b > pl) {
      b -= pl;
    }
    bars = b;
    length = (bars * barSec * sr).round();
    tail = (4.0 * sr).round();
    main = Float64List(length + tail);
    echo = Float64List(length + tail);
    root = 45 + rng.nextInt(9); // A2 .. F3
  }

  double get beatSec => 60 / bpm;
  double get totalSec => length / sr;

  /// Sample index of a beat position (with optional swing on off-beat 8ths).
  int at(double beat) {
    var b = beat;
    if (swing > 0) {
      final frac = b - b.floorToDouble();
      if ((frac - 0.5).abs() < 1e-6) b += swing;
    }
    return (b * beatSec * sr).round();
  }

  int deg(int d, {int octave = 0}) {
    final n = scale.length;
    final o = (d / n).floor();
    final i = d - o * n;
    return root + scale[i] + 12 * (o + octave);
  }

  List<int> chord(int d, {int size = 3, int octave = 0}) =>
      [for (int k = 0; k < size; k++) deg(d + 2 * k, octave: octave)];

  int chordAt(int bar) => prog[bar % prog.length];
}

// ------------------------------------------------------------------ instruments

/// Generic oscillator voice. wave: 0 sine, 1 triangle, 2 saw, 3 square.
void _tone(
  Float64List b,
  int start,
  double freq,
  double dur,
  double vol, {
  int wave = 0,
  double atk = 0.01,
  double dec = 0,
  double sus = 1,
  double rel = 0.15,
  double cut = 1,
  double? cutEnd,
  double vib = 0,
  double vibRate = 5,
  double glideTo = 0,
  double tremolo = 0,
  double tremRate = 6,
}) {
  const sr = kSampleRate;
  final nOn = math.max(1, (dur * sr).round());
  final nRel = math.max(1, (rel * sr).round());
  final n = nOn + nRel;
  final a = math.max(1, (atk * sr).round());
  final dc = math.max(1, (dec * sr).round());
  double ph = 0, lp = 0, lp2 = 0;
  double level = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    double env;
    if (i < nOn) {
      if (i < a) {
        env = i / a;
      } else if (dec > 0 && i < a + dc) {
        env = 1 - (1 - sus) * ((i - a) / dc);
      } else {
        env = dec > 0 ? sus : 1.0;
      }
      level = env;
    } else {
      env = level * (1 - (i - nOn) / nRel);
    }
    final t = i / sr;
    var fr = freq;
    if (glideTo > 0) fr = freq * math.pow(glideTo / freq, math.min(1.0, t / dur)).toDouble();
    if (vib > 0) fr *= 1 + vib * math.sin(2 * math.pi * vibRate * t) * math.min(1.0, t / 0.35);
    ph += fr / sr;
    ph -= ph.floorToDouble();
    double x;
    switch (wave) {
      case 1:
        x = 4 * (ph - 0.5).abs() - 1;
        break;
      case 2:
        x = 2 * ph - 1;
        break;
      case 3:
        x = ph < 0.5 ? 1.0 : -1.0;
        break;
      default:
        x = math.sin(2 * math.pi * ph);
    }
    final c = cutEnd == null ? cut : cut + (cutEnd - cut) * math.min(1.0, i / n);
    lp += c * (x - lp);
    lp2 += c * (lp - lp2);
    var y = wave == 0 ? x : lp2;
    if (tremolo > 0) y *= 1 - tremolo * (0.5 + 0.5 * math.sin(2 * math.pi * tremRate * t));
    b[idx] += y * env * vol;
  }
}

/// Lush pad: two detuned oscillators per note.
void _pad(Float64List b, int start, List<int> notes, double dur, double vol,
    {int wave = 2, double cut = 0.08, double? cutEnd, double atk = 0.6, double rel = 0.8}) {
  final v = vol / notes.length;
  for (final m in notes) {
    final f = _mtof(m);
    _tone(b, start, f * 1.003, dur, v * 0.5, wave: wave, atk: atk, rel: rel, cut: cut, cutEnd: cutEnd);
    _tone(b, start, f * 0.997, dur, v * 0.5, wave: wave, atk: atk, rel: rel, cut: cut, cutEnd: cutEnd);
  }
}

/// FM voice: bells, electric piano, marimba, xylophone …
void _fm(Float64List b, int start, double f, double vol,
    {double ratio = 1, double index = 1, double decay = 0.8, double idxDecay = 0.3, double atk = 0.003}) {
  const sr = kSampleRate;
  final n = (math.min(6.0, decay * 5) * sr).round();
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    final t = i / sr;
    final env = (t < atk ? t / atk : 1.0) * math.exp(-t / decay);
    final m = math.sin(2 * math.pi * f * ratio * t) * index * math.exp(-t / idxDecay);
    b[idx] += math.sin(2 * math.pi * f * t + m) * env * vol;
  }
}

/// Karplus-Strong plucked string (guitar, harp, pizzicato).
void _pluck(Float64List b, int start, double f, double vol, _Rng rng,
    {double dur = 1.2, double bright = 0.5, double damp = 0.996}) {
  const sr = kSampleRate;
  final period = math.max(2, (sr / f).round());
  final buf = Float64List(period);
  double lp = 0, mean = 0;
  for (int k = 0; k < period; k++) {
    lp += bright * (rng.noise() - lp);
    buf[k] = lp;
    mean += lp;
  }
  mean /= period;
  double peak = 1e-9;
  for (int k = 0; k < period; k++) {
    buf[k] -= mean;
    peak = math.max(peak, buf[k].abs());
  }
  final g = vol / peak;
  final n = (dur * sr).round();
  int p = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx >= b.length) break;
    final cur = buf[p];
    final nxt = buf[p + 1 == period ? 0 : p + 1];
    buf[p] = damp * 0.5 * (cur + nxt);
    final fade = i > n - 400 ? (n - i) / 400 : 1.0;
    if (idx >= 0) b[idx] += cur * g * fade;
    p = p + 1 == period ? 0 : p + 1;
  }
}

void _kick(Float64List b, int start, double vol, {double decay = 0.18, double low = 45}) {
  const sr = kSampleRate;
  final n = (decay * 3 * sr).round();
  double ph = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    final t = i / sr;
    ph += (low + 90 * math.exp(-t / 0.035)) / sr;
    b[idx] += math.sin(2 * math.pi * ph) * math.exp(-t / decay) * vol;
  }
}

void _snare(Float64List b, int start, double vol, _Rng rng, {double decay = 0.09}) {
  const sr = kSampleRate;
  final n = (decay * 4 * sr).round();
  double lp = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    final t = i / sr;
    final nz = rng.noise();
    lp += 0.35 * (nz - lp);
    final hp = nz - lp;
    final body = math.sin(2 * math.pi * 185 * t) * math.exp(-t / 0.035);
    b[idx] += (hp * 0.75 * math.exp(-t / decay) + body * 0.5) * vol;
  }
}

void _hat(Float64List b, int start, double vol, _Rng rng, {bool open = false}) {
  const sr = kSampleRate;
  final decay = open ? 0.13 : 0.025;
  final n = (decay * 5 * sr).round();
  double lp1 = 0, lp2 = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    final t = i / sr;
    final nz = rng.noise();
    lp1 += 0.5 * (nz - lp1);
    final h1 = nz - lp1;
    lp2 += 0.5 * (h1 - lp2);
    b[idx] += (h1 - lp2) * math.exp(-t / decay) * vol;
  }
}

void _shaker(Float64List b, int start, double vol, _Rng rng) {
  const sr = kSampleRate;
  final n = (0.12 * sr).round();
  double lp = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    final t = i / sr;
    final nz = rng.noise();
    lp += 0.4 * (nz - lp);
    final env = t < 0.02 ? t / 0.02 : math.exp(-(t - 0.02) / 0.03);
    b[idx] += (nz - lp) * env * vol;
  }
}

void _clap(Float64List b, int start, double vol, _Rng rng) {
  const sr = kSampleRate;
  for (final off in const [0.0, 0.011, 0.022]) {
    _snare(b, start + (off * sr).round(), vol * 0.45, rng, decay: 0.015);
  }
  _snare(b, start + (0.03 * sr).round(), vol * 0.6, rng, decay: 0.06);
}

void _tom(Float64List b, int start, double f, double vol, {double decay = 0.28}) {
  const sr = kSampleRate;
  final n = (decay * 3 * sr).round();
  double ph = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    final t = i / sr;
    ph += f * (1 + 0.6 * math.exp(-t / 0.05)) / sr;
    b[idx] += math.sin(2 * math.pi * ph) * math.exp(-t / decay) * vol;
  }
}

/// Filtered-noise swell (wind, risers, reverse cymbals).
void _swell(Float64List b, int start, double dur, double vol, _Rng rng,
    {double fFrom = 300, double fTo = 3000, double q = 0.25, bool rising = true}) {
  const sr = kSampleRate;
  final n = (dur * sr).round();
  double low = 0, band = 0;
  for (int i = 0; i < n; i++) {
    final idx = start + i;
    if (idx < 0) continue;
    if (idx >= b.length) break;
    final x = i / n;
    final fc = fFrom * math.pow(fTo / fFrom, x).toDouble();
    final fco = 2 * math.sin(math.pi * math.min(fc, sr / 6) / sr);
    final high = rng.noise() - low - q * band;
    band += fco * high;
    low += fco * band;
    final env = rising ? x * x * (x > 0.97 ? (1 - x) / 0.03 : 1.0) : (1 - x) * (1 - x) * math.min(1.0, x / 0.05);
    b[idx] += band * env * vol;
  }
}

// ------------------------------------------------------------------ patterns

typedef _Play = void Function(int start, int midi, double durBeats, double vel);

const _calm = [
  [2.0, 2.0],
  [1.0, 1.0, 2.0],
  [3.0, 1.0],
  [2.0, 1.0, 1.0],
  [1.5, 0.5, 2.0],
  [4.0],
  [-1.0, 1.0, 2.0],
  [1.0, 3.0],
];
const _busy = [
  [0.5, 0.5, 1.0, 1.0, 1.0],
  [1.0, 0.5, 0.5, 1.0, 1.0],
  [0.5, 0.5, 0.5, 0.5, 2.0],
  [1.0, 1.0, 0.5, 0.5, 1.0],
  [0.75, 0.25, 1.0, 1.0, 1.0],
  [1.5, 0.5, 1.0, 1.0],
];
const _stacc = [
  [0.5, -0.5, 0.5, -0.5, 1.0, 1.0],
  [0.5, 0.5, 0.5, 0.5, -1.0, 1.0],
  [1.0, -0.5, 0.5, 1.0, 1.0],
  [0.5, 0.5, 1.0, 0.5, 0.5, 1.0],
  [0.25, 0.25, 0.5, 1.0, -1.0, 1.0],
];
const _waltz = [
  [2.0, 1.0],
  [1.0, 1.0, 1.0],
  [3.0],
  [1.5, 0.5, 1.0],
];

/// Motif-based melody: a 2-bar motif repeated over the chord changes.
void _melody(_Song s, _Play play,
    {required List<List<double>> rhythms,
    int lo = 7,
    int hi = 16,
    double rest = 0.1,
    bool Function(int bar)? active,
    double vel = 1}) {
  final rng = s.rng;
  final motifs = <List<List<double>>>[];
  for (int m = 0; m < 2; m++) {
    final pat = rng.pick(rhythms);
    final notes = <List<double>>[];
    double beat = 0;
    int prev = rng.pick(const [0, 2, 4]);
    for (final d in pat) {
      if (d < 0) {
        beat += -d;
        continue;
      }
      final strong = (beat - beat.floorToDouble()).abs() < 1e-6 && beat.toInt() % 2 == 0;
      int rel = strong ? rng.pick(const [0, 2, 4, 7]) : prev + rng.pick(const [-2, -1, 1, 1, 2]);
      rel = rel.clamp(-3, 9);
      notes.add([beat, d, rel.toDouble()]);
      prev = rel;
      beat += d;
    }
    motifs.add(notes);
  }
  final n = s.scale.length;
  for (int bar = 0; bar < s.bars; bar++) {
    if (active != null && !active(bar)) continue;
    var motif = motifs[bar % 2];
    if (bar % 4 == 3 && rng.chance(0.6)) {
      motif = [
        for (final x in motif) [x[0], x[1], x[2] + (rng.chance(0.4) ? rng.pick(const [-1, 1, 2]) : 0)]
      ];
    }
    final cr = s.chordAt(bar);
    for (final note in motif) {
      if (rng.chance(rest)) continue;
      int d = cr + note[2].toInt();
      while (d < lo) {
        d += n;
      }
      while (d > hi) {
        d -= n;
      }
      play(s.at(bar * s.beats + note[0]), s.deg(d), note[1], vel * rng.range(0.85, 1.0));
    }
  }
}

/// Broken-chord arpeggio.
void _arp(_Song s, void Function(int start, int midi, double dur) play,
    {double step = 0.5, List<int> order = const [0, 1, 2, 1], int size = 3, int octave = 0, bool Function(int bar)? active}) {
  final per = (s.beats / step).round();
  for (int bar = 0; bar < s.bars; bar++) {
    if (active != null && !active(bar)) continue;
    final ch = s.chord(s.chordAt(bar), size: size, octave: octave);
    for (int k = 0; k < per; k++) {
      play(s.at(bar * s.beats + k * step), ch[order[k % order.length] % ch.length], step);
    }
  }
}

// ------------------------------------------------------------------ themes

void _ambient(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_major, _lydian, _dorian, _mixolydian]);
  s.prog = r.pick(const [
    [0, 3, 0, 4],
    [0, 5, 3, 4],
    [0, 2, 3, 0],
    [3, 0, 4, 5],
    [0, 3, 5, 4],
  ]);
  s.setup(58, 74);
  s.reverbWet = 0.55;
  s.reverbFb = 0.86;
  s.masterCut = 0.5;
  final barLen = s.beats * s.beatSec;
  for (int bar = 0; bar < s.bars; bar++) {
    _pad(s.main, s.at(bar * s.beats.toDouble()), s.chord(s.chordAt(bar), size: 4), barLen, 0.5,
        wave: r.chance(0.5) ? 1 : 2, cut: 0.05, atk: barLen * 0.4, rel: barLen * 0.6);
  }
  final bellRatio = r.pick(const [3.5, 2.0, 4.0, 1.5]);
  for (double beat = 0; beat < s.bars * s.beats; beat += r.pick(const [1.0, 1.5, 2.0])) {
    if (!r.chance(0.55)) continue;
    final bar = beat ~/ s.beats;
    final m = s.deg(s.chordAt(bar) + r.pick(const [7, 9, 11, 14]));
    _fm(s.echo, s.at(beat), _mtof(m), 0.18, ratio: bellRatio, index: 1.2, decay: 1.8, idxDecay: 0.6);
  }
  if (r.chance(0.6)) {
    _arp(s, (st, m, d) => _pluck(s.main, st, _mtof(m), 0.12, r, dur: 1.5, bright: 0.25),
        step: 1.0, order: r.pick(const [
          [0, 1, 2, 1],
          [0, 2, 1, 2]
        ]));
  }
}

void _horror(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_phrygian, _harmMinor, _minor]);
  s.prog = const [0, 0, 0, 0];
  s.setup(56, 76, targetSec: 40);
  s.reverbWet = 0.6;
  s.reverbFb = 0.88;
  s.masterCut = 0.45;
  final total = s.totalSec + 3;
  // low drones
  final low = s.root - 12;
  _tone(s.main, 0, _mtof(low), total, 0.35, wave: 1, cut: 0.04, atk: 3, rel: 1, tremolo: 0.4, tremRate: 0.3);
  _tone(s.main, 0, _mtof(low) * 1.006, total, 0.25, atk: 4, rel: 1);
  final interval = r.pick(const [1, 6, 11]);
  _tone(s.main, (s.totalSec * 0.25 * s.sr).round(), _mtof(low + 12 + interval), s.totalSec * 0.6, 0.1,
      wave: 2, cut: 0.03, atk: 4, rel: 3, tremolo: 0.6, tremRate: r.range(3, 7));
  // wind / risers
  for (int k = 0, c = 2 + r.nextInt(3); k < c; k++) {
    final st = r.range(0, s.totalSec - 4);
    _swell(s.main, (st * s.sr).round(), r.range(3, 6), 0.35, r,
        fFrom: r.range(150, 500), fTo: r.range(1500, 4000), q: r.range(0.08, 0.3), rising: r.chance(0.7));
  }
  // dissonant bell clusters
  for (int k = 0, c = 3 + r.nextInt(5); k < c; k++) {
    final st = (r.range(0, s.totalSec) * s.sr).round();
    final base = s.root + 12 + r.nextInt(12);
    for (final off in [0, 1, r.pick(const [6, 13])]) {
      _fm(s.main, st, _mtof(base + off), 0.12, ratio: 1.414, index: 2.5, decay: 2.5, idxDecay: 1.2);
    }
  }
  final variant = r.nextInt(4);
  if (variant == 0 || r.chance(0.3)) {
    // detuned music box
    _melody(s, (st, m, d, v) {
      _fm(s.echo, st, _mtof(m + 12), 0.16 * v, ratio: 5.0, index: 0.8, decay: 1.2, idxDecay: 0.2);
      _fm(s.echo, st, _mtof(m + 12) * 1.004, 0.08 * v, ratio: 5.0, index: 0.8, decay: 1.2, idxDecay: 0.2);
    }, rhythms: _calm, rest: 0.3, active: (b) => b >= s.bars ~/ 3);
  }
  if (variant == 1 || r.chance(0.3)) {
    // heartbeat
    for (int bar = 0; bar < s.bars; bar++) {
      if (bar < 2) continue;
      _kick(s.main, s.at(bar * s.beats.toDouble()), 0.55, decay: 0.12, low: 40);
      _kick(s.main, s.at(bar * s.beats + 0.35), 0.4, decay: 0.12, low: 40);
    }
  }
  if (variant == 2 || r.chance(0.3)) {
    // low piano stabs
    for (int k = 0, c = 2 + r.nextInt(3); k < c; k++) {
      final st = s.at(r.nextInt(s.bars) * s.beats.toDouble());
      for (final off in const [0, 1, 6]) {
        _fm(s.main, st, _mtof(low + off), 0.3, ratio: 1, index: 3, decay: 1.6, idxDecay: 0.4);
      }
    }
  }
  if (variant == 3 || r.chance(0.3)) {
    // high string tremolo (minor second)
    final st = s.at((s.bars ~/ 2) * s.beats.toDouble());
    final m = s.root + 24 + r.nextInt(5);
    _tone(s.main, st, _mtof(m), s.totalSec * 0.4, 0.08, wave: 2, cut: 0.2, atk: 2, rel: 2, tremolo: 0.9, tremRate: 12);
    _tone(s.main, st, _mtof(m + 1), s.totalSec * 0.4, 0.06, wave: 2, cut: 0.2, atk: 3, rel: 2, tremolo: 0.9, tremRate: 13);
  }
}

void _comedy(_Song s) {
  final r = s.rng;
  s.scale = r.chance(0.8) ? _major : _mixolydian;
  s.prog = r.pick(const [
    [0, 5, 3, 4],
    [0, 3, 4, 0],
    [1, 4, 0, 5],
    [0, 4, 5, 3],
    [0, 3, 1, 4],
    [0, 0, 3, 4],
  ]);
  s.setup(108, 142);
  s.swing = r.chance(0.5) ? 0.14 : 0;
  s.reverbWet = 0.15;
  s.masterCut = 0.75;
  final tuba = r.chance(0.5);
  for (int bar = 0; bar < s.bars; bar++) {
    final ch = s.chord(s.chordAt(bar));
    for (int beat = 0; beat < s.beats; beat++) {
      final st = s.at(bar * s.beats + beat.toDouble());
      if (beat.isEven) {
        final m = (beat == 0 ? ch[0] : ch[2]) - 12;
        if (tuba) {
          _tone(s.main, st, _mtof(m), s.beatSec * 0.45, 0.45, wave: 1, cut: 0.15, atk: 0.02, rel: 0.05);
        } else {
          _pluck(s.main, st, _mtof(m), 0.5, r, dur: 0.5, bright: 0.4, damp: 0.985);
        }
      } else {
        for (final m in ch) {
          _pluck(s.main, st, _mtof(m), 0.13, r, dur: 0.35, bright: 0.6, damp: 0.98);
        }
      }
    }
  }
  final inst = r.nextInt(4);
  _melody(s, (st, m, d, v) {
    switch (inst) {
      case 0: // xylophone
        _fm(s.main, st, _mtof(m + 12), 0.35 * v, ratio: 4, index: 1.3, decay: 0.22, idxDecay: 0.05);
        break;
      case 1: // bassoon
        _tone(s.main, st, _mtof(m - 12), d * s.beatSec * 0.6, 0.3 * v, wave: 3, cut: 0.12, atk: 0.02, rel: 0.05);
        break;
      case 2: // clarinet
        _tone(s.main, st, _mtof(m), d * s.beatSec * 0.7, 0.25 * v, wave: 3, cut: 0.25, atk: 0.02, rel: 0.06, vib: 0.004);
        break;
      default: // pizzicato
        _pluck(s.main, st, _mtof(m + 12), 0.4 * v, r, dur: 0.4, bright: 0.7, damp: 0.98);
    }
  }, rhythms: _stacc, rest: 0.08, active: (b) => b >= s.prog.length || r.chance(0.5));
  for (double beat = 0.5; beat < s.bars * s.beats; beat += 1) {
    if (r.chance(0.45)) _fm(s.main, s.at(beat), r.pick(const [900.0, 1200.0]), 0.18, ratio: 2.4, index: 2, decay: 0.05, idxDecay: 0.02);
    _shaker(s.main, s.at(beat), 0.12, r);
  }
  // slide whistle gags
  for (int bar = s.prog.length - 1; bar < s.bars; bar += s.prog.length) {
    if (!r.chance(0.35)) continue;
    final up = r.chance(0.5);
    final f = _mtof(s.root + 24);
    _tone(s.main, s.at(bar * s.beats + 2.0), up ? f : f * 2, s.beatSec * 1.5, 0.12,
        glideTo: up ? f * 2 : f, vib: 0.01, atk: 0.03, rel: 0.05);
  }
}

void _action(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_minor, _minor, _phrygian, _harmMinor]);
  s.prog = r.pick(const [
    [0, 5, 6, 0],
    [0, 3, 5, 4],
    [0, 6, 5, 6],
    [0, 0, 5, 6],
    [0, 2, 6, 3],
    [0, 5, 3, 6],
  ]);
  s.setup(132, 168);
  s.reverbWet = 0.18;
  s.masterCut = 0.8;
  final kickPat = r.pick(const [
    [0.0, 1.5, 2.0],
    [0.0, 0.75, 2.0, 2.5],
    [0.0, 1.0, 2.0, 3.0],
    [0.0, 2.5, 3.0],
  ]);
  final ostPat = r.pick(const [
    [0, 0, 7, 0, 0, 0, 10, 0],
    [0, 0, 0, 3, 0, 0, 5, 3],
    [0, 12, 0, 7, 0, 12, 0, 10],
    [0, 0, 7, 7, 5, 5, 3, 3],
  ]);
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    final fill = bar % 4 == 3;
    for (final k in kickPat) {
      _kick(s.main, s.at(b0 + k), 0.9);
    }
    _snare(s.main, s.at(b0 + 1), 0.6, r);
    _snare(s.main, s.at(b0 + 3), 0.6, r);
    for (int i = 0; i < 16; i++) {
      if (fill && i >= 12) {
        _tom(s.main, s.at(b0 + i * 0.25), _mtof(s.root - 12 - (i - 12) * 3), 0.55);
      } else {
        _hat(s.main, s.at(b0 + i * 0.25), i % 4 == 0 ? 0.25 : 0.12, r);
      }
    }
    final cr = s.deg(s.chordAt(bar)) - 12;
    for (int i = 0; i < 16; i++) {
      final m = cr + ostPat[i % ostPat.length];
      _tone(s.main, s.at(b0 + i * 0.25), _mtof(m), s.beatSec * 0.18, 0.22, wave: 2, cut: 0.22, atk: 0.003, rel: 0.03);
    }
    if (bar % 2 == 0) {
      for (final acc in r.pick(const [
        [0.0, 1.5],
        [0.0, 2.5, 3.0],
        [0.0]
      ])) {
        _pad(s.main, s.at(b0 + acc), s.chord(s.chordAt(bar)), s.beatSec * 0.35, 0.35, cut: 0.3, atk: 0.01, rel: 0.12);
      }
    }
    if (bar % 8 == 0) _kick(s.main, s.at(b0), 0.8, decay: 0.6, low: 35);
  }
  if (r.chance(0.6)) {
    _melody(s, (st, m, d, v) {
      _tone(s.main, st, _mtof(m), d * s.beatSec * 0.9, 0.2 * v, wave: 2, cut: 0.25, atk: 0.04, rel: 0.1, vib: 0.005);
    }, rhythms: _busy, active: (b) => b >= s.bars ~/ 2);
  }
}

void _suspense(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_minor, _dorian, _harmMinor]);
  s.prog = r.pick(const [
    [0, 0, 5, 4],
    [0, 3, 0, 4],
    [0, 5, 3, 4],
    [0, 1, 0, 4],
    [0, 0, 3, 3],
  ]);
  s.setup(86, 112);
  s.reverbWet = 0.35;
  s.masterCut = 0.55;
  final barLen = s.beats * s.beatSec;
  final pluckPulse = r.chance(0.5);
  final tick = r.chance(0.6);
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    final cr = s.deg(s.chordAt(bar)) - 12;
    _pad(s.main, s.at(b0), s.chord(s.chordAt(bar)), barLen, 0.22, cut: 0.05, atk: 0.4, rel: 0.6);
    for (int i = 0; i < s.beats * 2; i++) {
      final st = s.at(b0 + i * 0.5);
      if (pluckPulse) {
        _pluck(s.main, st, _mtof(cr), 0.3, r, dur: 0.3, bright: 0.2, damp: 0.975);
      } else {
        _tone(s.main, st, _mtof(cr), s.beatSec * 0.25, 0.28, wave: 1, cut: 0.1, rel: 0.04);
      }
      if (tick) _fm(s.main, st, i.isEven ? 2200.0 : 1800.0, 0.06, ratio: 1.5, index: 1, decay: 0.02, idxDecay: 0.01);
    }
    if (r.chance(0.6)) {
      final m = s.deg(s.chordAt(bar) + r.pick(const [7, 9, 11]));
      _fm(s.echo, s.at(b0 + r.pick(const [0.0, 1.0, 2.0, 2.5])), _mtof(m), 0.2, ratio: 1, index: 1.5, decay: 1.2, idxDecay: 0.3);
    }
    if (bar % 8 == 7) _swell(s.main, s.at(b0), barLen, 0.25, r, fFrom: 400, fTo: 3000);
  }
}

void _drama(_Song s) {
  final r = s.rng;
  final minor = r.chance(0.6);
  s.scale = minor ? _minor : _major;
  s.prog = minor
      ? r.pick(const [
          [0, 5, 2, 6],
          [0, 3, 6, 2],
          [0, 5, 3, 4],
          [0, 3, 5, 4],
        ])
      : r.pick(const [
          [5, 3, 0, 4],
          [0, 4, 5, 3],
          [0, 5, 3, 4],
          [3, 4, 2, 5],
        ]);
  s.setup(60, 82, beatsPerBar: r.chance(0.25) ? 3 : 4);
  s.reverbWet = 0.45;
  s.reverbFb = 0.85;
  s.masterCut = 0.55;
  final barLen = s.beats * s.beatSec;
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    _pad(s.main, s.at(b0), s.chord(s.chordAt(bar)), barLen, 0.28, cut: 0.07, atk: 0.8, rel: 1.0);
    _tone(s.main, s.at(b0), _mtof(s.deg(s.chordAt(bar)) - 12), barLen, 0.22, wave: 2, cut: 0.05, atk: 0.4, rel: 0.6);
  }
  final order = r.pick(const [
    [0, 1, 2, 1],
    [0, 2, 1, 2],
    [0, 1, 2, 3]
  ]);
  _arp(s, (st, m, d) => _fm(s.main, st, _mtof(m + 12), 0.16, ratio: 1, index: 1.2, decay: 1.4, idxDecay: 0.4),
      step: 0.5, order: order, size: 4);
  _melody(s, (st, m, d, v) {
    _tone(s.main, st, _mtof(m + 12), d * s.beatSec, 0.17 * v, wave: 2, cut: 0.16, atk: 0.18, rel: 0.4, vib: 0.006);
  }, rhythms: s.beats == 3 ? _waltz : _calm, active: (b) => b >= s.prog.length);
}

void _romance(_Song s) {
  final r = s.rng;
  s.scale = r.chance(0.8) ? _major : _lydian;
  s.prog = r.pick(const [
    [0, 5, 3, 4],
    [3, 0, 4, 5],
    [0, 2, 3, 4],
    [0, 4, 5, 3],
    [3, 4, 2, 5],
    [0, 3, 0, 4],
  ]);
  s.setup(64, 84, beatsPerBar: r.chance(0.3) ? 3 : 4);
  s.reverbWet = 0.45;
  s.masterCut = 0.55;
  final barLen = s.beats * s.beatSec;
  for (int bar = 0; bar < s.bars; bar++) {
    _pad(s.main, s.at(bar * s.beats.toDouble()), s.chord(s.chordAt(bar), size: 4), barLen, 0.22,
        wave: 1, cut: 0.08, atk: 1.0, rel: 1.0);
  }
  _arp(s, (st, m, d) => _fm(s.main, st, _mtof(m), 0.17, ratio: 1, index: 0.8, decay: 1.8, idxDecay: 0.5),
      step: s.beats == 3 ? 1.0 : 0.5, order: const [0, 1, 2, 3, 2, 1], size: 4);
  final flute = r.chance(0.6);
  _melody(s, (st, m, d, v) {
    if (flute) {
      _tone(s.main, st, _mtof(m + 12), d * s.beatSec, 0.2 * v, atk: 0.1, rel: 0.3, vib: 0.005, vibRate: 5);
    } else {
      _fm(s.main, st, _mtof(m + 12), 0.25 * v, ratio: 1, index: 1.0, decay: 1.5, idxDecay: 0.4);
    }
  }, rhythms: s.beats == 3 ? _waltz : _calm, active: (b) => b % (s.prog.length * 2) >= s.prog.length || r.chance(0.3));
  if (r.chance(0.5)) {
    for (int bar = s.prog.length - 1; bar < s.bars; bar += s.prog.length * 2) {
      final start = bar * s.beats + s.beats - 1.0;
      for (int k = 0; k < 8; k++) {
        _pluck(s.main, s.at(start) + (k * 0.06 * s.sr).round(), _mtof(s.deg(7 + k)), 0.14, r, dur: 1.5, bright: 0.5);
      }
    }
  }
}

void _scifi(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_dorian, _minor, _phrygian, _lydian]);
  s.prog = r.pick(const [
    [0, 5, 6, 0],
    [0, 2, 5, 4],
    [0, 0, 3, 3],
    [0, 6, 5, 4],
    [0, 3, 0, 6],
  ]);
  s.setup(100, 124);
  s.reverbWet = 0.35;
  s.echoBeats = r.pick(const [0.75, 0.5, 1.5]);
  s.echoFb = 0.45;
  s.masterCut = 0.65;
  final barLen = s.beats * s.beatSec;
  final order = r.pick(const [
    [0, 1, 2, 3],
    [0, 2, 1, 3],
    [0, 1, 2, 1, 3, 2],
    [3, 2, 1, 0]
  ]);
  final sq = r.chance(0.6) ? 3 : 2;
  _arp(s, (st, m, d) {
    _tone(s.echo, st, _mtof(m), s.beatSec * 0.2, 0.13, wave: sq, cut: 0.3, atk: 0.003, rel: 0.05);
  }, step: 0.25, order: order, size: 4, octave: 1);
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    _pad(s.main, s.at(b0), s.chord(s.chordAt(bar)), barLen, 0.25, cut: 0.03, cutEnd: 0.2, atk: 0.8, rel: 0.8);
    _tone(s.main, s.at(b0), _mtof(s.deg(s.chordAt(bar)) - 12), barLen, 0.35, atk: 0.05, rel: 0.2);
  }
  if (r.chance(0.5)) {
    for (int bar = 0; bar < s.bars; bar++) {
      final b0 = bar * s.beats.toDouble();
      _kick(s.main, s.at(b0), 0.6);
      _kick(s.main, s.at(b0 + 2), 0.5);
      for (int i = 0; i < 4; i++) {
        _hat(s.main, s.at(b0 + i + 0.5), 0.12, r);
      }
    }
  }
  for (int k = 0, c = 4 + r.nextInt(6); k < c; k++) {
    _fm(s.echo, (r.range(0, s.totalSec) * s.sr).round(), r.range(800, 2400), 0.1, ratio: 2, index: 3, decay: 0.08, idxDecay: 0.04);
  }
}

void _epic(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_minor, _dorian, _minor]);
  s.prog = r.pick(const [
    [0, 5, 2, 6],
    [5, 6, 0, 0],
    [0, 4, 5, 3],
    [0, 6, 5, 4],
    [5, 3, 0, 4],
    [0, 5, 6, 4],
  ]);
  s.setup(80, 108);
  s.reverbWet = 0.45;
  s.reverbFb = 0.85;
  s.masterCut = 0.6;
  final barLen = s.beats * s.beatSec;
  final ost = r.chance(0.6);
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    _pad(s.main, s.at(b0), s.chord(s.chordAt(bar)), barLen, 0.3, cut: 0.1, atk: 0.5, rel: 0.8);
    _pad(s.main, s.at(b0), s.chord(s.chordAt(bar), octave: 1), barLen, 0.12, wave: 1, cut: 0.15, atk: 1.0, rel: 1.0);
    _tone(s.main, s.at(b0), _mtof(s.deg(s.chordAt(bar)) - 12), barLen, 0.3, wave: 2, cut: 0.06, atk: 0.2, rel: 0.5);
    for (final t in const [0.0, 2.5, 3.0]) {
      _tom(s.main, s.at(b0 + t), _mtof(s.root - 24), t == 0 ? 0.8 : 0.5, decay: 0.4);
    }
    if (ost) {
      final cr = s.deg(s.chordAt(bar));
      for (int i = 0; i < s.beats * 2; i++) {
        _tone(s.main, s.at(b0 + i * 0.5), _mtof(cr + (i % 4 == 2 ? 7 : 0)), s.beatSec * 0.3, 0.14,
            wave: 2, cut: 0.25, atk: 0.005, rel: 0.05);
      }
    }
    if (bar % 4 == 3) _swell(s.main, s.at(b0), barLen, 0.2, r, fFrom: 1000, fTo: 6000, q: 0.5);
  }
  _melody(s, (st, m, d, v) {
    _tone(s.main, st, _mtof(m), d * s.beatSec, 0.22 * v, wave: 2, cut: 0.13, atk: 0.12, rel: 0.3, vib: 0.004);
  }, rhythms: r.chance(0.5) ? _calm : _busy, active: (b) => b >= s.prog.length);
}

void _playful(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_major, _major, _lydian, _mixolydian]);
  s.prog = r.pick(const [
    [0, 3, 4, 0],
    [0, 4, 5, 3],
    [0, 5, 1, 4],
    [3, 4, 0, 0],
    [0, 3, 0, 4],
  ]);
  s.setup(110, 134);
  s.swing = r.chance(0.4) ? 0.12 : 0;
  s.reverbWet = 0.2;
  s.masterCut = 0.75;
  final claps = r.chance(0.5);
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    final cr = s.deg(s.chordAt(bar)) - 12;
    for (int i = 0; i < s.beats * 2; i++) {
      final m = cr + (i.isEven ? 0 : 7);
      _pluck(s.main, s.at(b0 + i * 0.5), _mtof(m), 0.32, r, dur: 0.4, bright: 0.45, damp: 0.98);
      _shaker(s.main, s.at(b0 + i * 0.5), 0.08, r);
    }
    if (claps) {
      _clap(s.main, s.at(b0 + 1), 0.35, r);
      _clap(s.main, s.at(b0 + 3), 0.35, r);
    }
  }
  _melody(s, (st, m, d, v) {
    _fm(s.main, st, _mtof(m + 12), 0.32 * v, ratio: 4, index: 1.5, decay: 0.32, idxDecay: 0.06);
  }, rhythms: _busy);
  _melody(s, (st, m, d, v) {
    _fm(s.echo, st, _mtof(m + 24), 0.12 * v, ratio: 3.5, index: 0.6, decay: 0.8, idxDecay: 0.2);
  }, rhythms: _calm, rest: 0.4, active: (b) => b.isOdd);
}

void _documentary(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_major, _dorian, _mixolydian]);
  s.prog = r.pick(const [
    [0, 4, 5, 3],
    [0, 3, 5, 4],
    [0, 2, 3, 4],
    [5, 3, 0, 4],
  ]);
  s.setup(72, 96);
  s.reverbWet = 0.35;
  s.masterCut = 0.6;
  final barLen = s.beats * s.beatSec;
  for (int bar = 0; bar < s.bars; bar++) {
    _pad(s.main, s.at(bar * s.beats.toDouble()), s.chord(s.chordAt(bar)), barLen, 0.2, wave: 1, cut: 0.08, atk: 0.6, rel: 0.8);
  }
  _arp(s, (st, m, d) => _pluck(s.main, st, _mtof(m), 0.18, r, dur: 0.8, bright: 0.3, damp: 0.99),
      step: 0.5, order: r.pick(const [
        [0, 1, 2, 1],
        [0, 2, 1, 2],
        [0, 1, 2, 3]
      ]), size: 4);
  _melody(s, (st, m, d, v) => _fm(s.main, st, _mtof(m + 12), 0.22 * v, ratio: 1, index: 1.1, decay: 1.3, idxDecay: 0.35),
      rhythms: _calm, rest: 0.25, active: (b) => b >= s.prog.length);
  if (r.chance(0.4)) {
    for (int bar = 0; bar < s.bars; bar++) {
      _kick(s.main, s.at(bar * s.beats.toDouble()), 0.35);
      for (int i = 0; i < s.beats * 2; i++) {
        _shaker(s.main, s.at(bar * s.beats + i * 0.5), 0.06, r);
      }
    }
  }
}

void _western(_Song s) {
  final r = s.rng;
  s.scale = r.pick(const [_dorian, _minor, _mixolydian]);
  s.prog = r.pick(const [
    [0, 6, 5, 4],
    [0, 3, 0, 4],
    [0, 6, 3, 0],
    [0, 0, 6, 6],
    [0, 4, 0, 6],
  ]);
  final waltz = r.chance(0.3);
  s.setup(86, 112, beatsPerBar: waltz ? 3 : 4);
  s.reverbWet = 0.4;
  s.echoBeats = 0.75;
  s.echoFb = 0.4;
  s.masterCut = 0.6;
  final strum = waltz
      ? const [0.0, 1.0, 2.0]
      : r.pick(const [
          [0.0, 1.0, 1.5, 2.0, 3.0, 3.5],
          [0.0, 1.0, 2.0, 2.5, 3.0],
          [0.0, 0.5, 1.5, 2.0, 3.0],
        ]);
  final horse = r.chance(0.5);
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    final ch = s.chord(s.chordAt(bar));
    final voicing = [ch[0] - 12, ch[2] - 12, ch[0], ch[1], ch[2]];
    for (final pos in strum) {
      final down = (pos - pos.floorToDouble()) < 0.25;
      final st = s.at(b0 + pos);
      final order = down ? voicing : voicing.reversed.toList();
      for (int k = 0; k < order.length; k++) {
        _pluck(s.main, st + (k * 0.012 * s.sr).round(), _mtof(order[k]), down ? 0.12 : 0.08, r,
            dur: 0.9, bright: 0.55, damp: 0.993);
      }
    }
    _pluck(s.main, s.at(b0), _mtof(ch[0] - 24), 0.35, r, dur: 1.0, bright: 0.3);
    if (!waltz) _pluck(s.main, s.at(b0 + 2), _mtof(ch[2] - 24), 0.3, r, dur: 1.0, bright: 0.3);
    if (horse) {
      for (int i = 0; i < s.beats * 2; i++) {
        _fm(s.main, s.at(b0 + i * 0.5), i.isEven ? 700.0 : 520.0, 0.12, ratio: 2.4, index: 2, decay: 0.04, idxDecay: 0.02);
      }
    }
  }
  _melody(s, (st, m, d, v) {
    _tone(s.echo, st, _mtof(m + 12), d * s.beatSec, 0.2 * v, atk: 0.05, rel: 0.2, vib: 0.012, vibRate: 5.5);
  }, rhythms: waltz ? _waltz : _calm, active: (b) => b % (s.prog.length * 2) >= s.prog.length);
}

void _upbeat(_Song s) {
  final r = s.rng;
  s.scale = r.chance(0.6) ? _major : _minor;
  s.prog = r.pick(const [
    [0, 5, 3, 4],
    [5, 3, 0, 4],
    [0, 4, 5, 3],
    [0, 3, 5, 4],
  ]);
  s.setup(112, 126);
  s.reverbWet = 0.18;
  s.masterCut = 0.8;
  for (int bar = 0; bar < s.bars; bar++) {
    final b0 = bar * s.beats.toDouble();
    final cr = s.deg(s.chordAt(bar)) - 12;
    for (int i = 0; i < 4; i++) {
      _kick(s.main, s.at(b0 + i), 0.8, decay: 0.15);
      _hat(s.main, s.at(b0 + i + 0.5), 0.18, r, open: true);
    }
    _clap(s.main, s.at(b0 + 1), 0.45, r);
    _clap(s.main, s.at(b0 + 3), 0.45, r);
    for (int i = 0; i < 8; i++) {
      _tone(s.main, s.at(b0 + i * 0.5), _mtof(cr + (i % 4 == 3 ? 12 : 0)), s.beatSec * 0.35, 0.3,
          wave: 2, cut: 0.15, atk: 0.005, rel: 0.04);
    }
    for (final pos in const [0.5, 1.5, 2.5, 3.5]) {
      _pad(s.main, s.at(b0 + pos), s.chord(s.chordAt(bar)), s.beatSec * 0.3, 0.25, cut: 0.25, atk: 0.005, rel: 0.08);
    }
  }
  _melody(s, (st, m, d, v) {
    _tone(s.main, st, _mtof(m + 12), d * s.beatSec * 0.85, 0.15 * v, wave: 3, cut: 0.3, atk: 0.01, rel: 0.06);
  }, rhythms: _busy, active: (b) => b >= s.prog.length);
}

// ------------------------------------------------------------------ effects & output

void _applyEcho(_Song s) {
  final d = math.max(1, (s.echoBeats * s.beatSec * s.sr).round());
  final e = s.echo;
  for (int i = d; i < e.length; i++) {
    e[i] += e[i - d] * s.echoFb;
  }
  for (int i = 0; i < e.length; i++) {
    s.main[i] += e[i];
  }
}

void _applyReverb(_Song s) {
  final x = s.main;
  final n = x.length;
  final wet = Float64List(n);
  const scale = kSampleRate / 44100;
  for (final base in const [1116, 1188, 1277, 1356, 1422, 1491]) {
    final len = (base * scale).round();
    final buf = Float64List(len);
    double store = 0;
    int p = 0;
    for (int i = 0; i < n; i++) {
      final y = buf[p];
      store = y * 0.6 + store * 0.4;
      buf[p] = x[i] * 0.03 + store * s.reverbFb;
      wet[i] += y;
      p = p + 1 == len ? 0 : p + 1;
    }
  }
  for (final base in const [556, 441, 341]) {
    final len = (base * scale).round();
    final buf = Float64List(len);
    int p = 0;
    for (int i = 0; i < n; i++) {
      final bo = buf[p];
      final inp = wet[i];
      wet[i] = -inp + bo;
      buf[p] = inp + bo * 0.5;
      p = p + 1 == len ? 0 : p + 1;
    }
  }
  for (int i = 0; i < n; i++) {
    x[i] += wet[i] * s.reverbWet;
  }
}

Float64List _finish(_Song s) {
  _applyEcho(s);
  _applyReverb(s);
  final x = s.main;
  // master low-pass + DC block
  double lp = 0, dcIn = 0, dcOut = 0;
  for (int i = 0; i < x.length; i++) {
    lp += s.masterCut * (x[i] - lp);
    dcOut = lp - dcIn + 0.995 * dcOut;
    dcIn = lp;
    x[i] = dcOut;
  }
  // wrap the tail onto the start → seamless loop
  final out = Float64List(s.length);
  for (int i = 0; i < s.length; i++) {
    out[i] = x[i];
  }
  for (int i = 0; i < s.tail && i < s.length; i++) {
    out[i] += x[s.length + i];
  }
  // loudness-normalise (equal perceived level across themes) + soft limiter
  double sum = 0;
  for (final v in out) {
    if (v.isFinite) sum += v * v;
  }
  final rms = math.sqrt(sum / out.length) + 1e-9;
  final g = 0.17 / rms;
  for (int i = 0; i < out.length; i++) {
    final v = out[i];
    out[i] = v.isFinite ? _tanh(v * g) * 0.95 : 0;
  }
  return out;
}

/// Renders a track as mono samples in [-1, 1].
Float64List renderTrack(String theme, int index) {
  final rng = _Rng(_hash(theme) * 1009 + index * 7919 + 17);
  final s = _Song(rng);
  switch (theme) {
    case 'horror':
      _horror(s);
      break;
    case 'comedy':
      _comedy(s);
      break;
    case 'action':
      _action(s);
      break;
    case 'suspense':
      _suspense(s);
      break;
    case 'drama':
      _drama(s);
      break;
    case 'romance':
      _romance(s);
      break;
    case 'scifi':
      _scifi(s);
      break;
    case 'epic':
      _epic(s);
      break;
    case 'playful':
      _playful(s);
      break;
    case 'documentary':
      _documentary(s);
      break;
    case 'western':
      _western(s);
      break;
    case 'upbeat':
      _upbeat(s);
      break;
    default:
      _ambient(s);
  }
  return _finish(s);
}

/// 16-bit mono WAV file bytes.
Uint8List encodeWav(Float64List samples, {int sampleRate = kSampleRate}) {
  final n = samples.length;
  final bd = ByteData(44 + n * 2);
  void str(int o, String v) {
    for (int i = 0; i < v.length; i++) {
      bd.setUint8(o + i, v.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  bd.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, 1, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 2, Endian.little);
  bd.setUint16(32, 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  str(36, 'data');
  bd.setUint32(40, n * 2, Endian.little);
  for (int i = 0; i < n; i++) {
    final v = (samples[i] * 32767).round().clamp(-32768, 32767);
    bd.setInt16(44 + i * 2, v, Endian.little);
  }
  return bd.buffer.asUint8List();
}

/// Entry point for `compute()`: [theme, index] -> WAV bytes.
Uint8List renderWav(List<Object> args) => encodeWav(renderTrack(args[0] as String, args[1] as int));
