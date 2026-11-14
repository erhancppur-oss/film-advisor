import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'synth.dart';

/// Picks a music theme from TMDB genre ids (movie or TV).
String themeForGenres(List<int> g) {
  bool has(List<int> ids) => ids.any(g.contains);
  if (has(const [27])) return 'horror';
  if (has(const [35])) return 'comedy';
  if (has(const [28, 10759])) return 'action';
  if (has(const [878, 10765])) return 'scifi';
  if (has(const [16, 10751, 10762])) return 'playful';
  if (has(const [53, 80, 9648])) return 'suspense';
  if (has(const [10752, 10768, 14, 12])) return 'epic';
  if (has(const [10749])) return 'romance';
  if (has(const [37])) return 'western';
  if (has(const [10402])) return 'upbeat';
  if (has(const [99, 36])) return 'documentary';
  if (has(const [18])) return 'drama';
  return 'ambient';
}

/// Theme for an advisor mood key.
String themeForMood(String? mood) {
  switch (mood) {
    case 'laugh':
      return 'comedy';
    case 'feelgood':
      return 'playful';
    case 'thrill':
      return 'suspense';
    case 'scare':
      return 'horror';
    case 'adrenaline':
      return 'action';
    case 'mindbend':
      return 'scifi';
    case 'cry':
      return 'drama';
    case 'romance':
      return 'romance';
    case 'escape':
      return 'epic';
    case 'learn':
      return 'documentary';
    default:
      return 'ambient';
  }
}

class _Entry {
  String theme;
  int index;
  _Entry(this.theme, this.index);
}

/// Soft background music that follows the screen the user is looking at.
class MusicService extends ChangeNotifier with WidgetsBindingObserver {
  MusicService(this._prefs) {
    _enabled = _prefs.getBool('music_on') ?? true;
    WidgetsBinding.instance.addObserver(this);
    _player.setReleaseMode(ReleaseMode.loop).catchError((_) {});
    _player
        .setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build())
        .catchError((_) {});
    _stack.add(_Entry('ambient', _rnd.nextInt(kTracksPerTheme)));
  }

  final SharedPreferences _prefs;
  final AudioPlayer _player = AudioPlayer();
  final List<_Entry> _stack = [];
  final Map<String, int> _lastIndex = {};
  final Random _rnd = Random();
  final Map<String, Future<String>> _rendering = {};

  bool _enabled = true;
  bool _foreground = true;
  bool _started = false;
  String? _playingKey;
  int _gen = 0;
  double _volume = 0;
  Timer? _fade;
  Directory? _dir;

  bool get enabled => _enabled;

  static const double _ambientVolume = 0.22;
  static const double _themeVolume = 0.32;

  /// Call once the first frame is shown.
  void start() {
    if (_started) return;
    _started = true;
    _apply();
  }

  Future<void> setEnabled(bool on) async {
    _enabled = on;
    await _prefs.setBool('music_on', on);
    notifyListeners();
    _apply();
  }

  Future<void> toggle() => setEnabled(!_enabled);

  /// A screen with a theme became visible. Returns a token for [pop].
  Object push(String theme, {int? seed}) {
    var idx = seed == null ? _rnd.nextInt(kTracksPerTheme) : seed.abs() % kTracksPerTheme;
    if (_lastIndex[theme] == idx) idx = (idx + 1 + _rnd.nextInt(kTracksPerTheme - 1)) % kTracksPerTheme;
    _lastIndex[theme] = idx;
    final e = _Entry(theme, idx);
    _stack.add(e);
    _apply();
    return e;
  }

  /// Change the theme of an existing entry (e.g. once genres are known).
  void retheme(Object token, String theme) {
    if (token is! _Entry || token.theme == theme) return;
    final i = _stack.indexOf(token);
    if (i < 0) return;
    token.theme = theme;
    if (i == _stack.length - 1) _apply();
  }

  void pop(Object token) {
    final wasTop = _stack.isNotEmpty && identical(_stack.last, token);
    _stack.removeWhere((e) => identical(e, token));
    if (_stack.isEmpty) _stack.add(_Entry('ambient', 0));
    if (wasTop) _apply();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    _foreground = fg;
    if (!fg) {
      _gen++;
      _fade?.cancel();
      _player.pause().catchError((_) {});
    } else {
      _apply(resume: true);
    }
  }

  Future<String> _file(String theme, int idx) async {
    _dir ??= Directory('${(await getTemporaryDirectory()).path}/music');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    final f = File('${_dir!.path}/v1_${theme}_$idx.wav');
    if (await f.exists()) return f.path;
    final bytes = await compute(renderWav, <Object>[theme, idx]);
    await f.writeAsBytes(bytes, flush: true);
    _trimCache();
    return f.path;
  }

  Future<void> _trimCache() async {
    try {
      final files = _dir!.listSync().whereType<File>().toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      for (final f in files.skip(24)) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  void _fadeTo(double target, {Duration d = const Duration(milliseconds: 900), VoidCallback? done}) {
    _fade?.cancel();
    const steps = 18;
    final from = _volume;
    int k = 0;
    _fade = Timer.periodic(Duration(milliseconds: d.inMilliseconds ~/ steps), (t) {
      k++;
      _volume = from + (target - from) * (k / steps);
      _player.setVolume(_volume.clamp(0.0, 1.0)).catchError((_) {});
      if (k >= steps) {
        t.cancel();
        done?.call();
      }
    });
  }

  Future<void> _apply({bool resume = false}) async {
    if (!_started) return;
    final gen = ++_gen;
    if (!_enabled || !_foreground) {
      _fadeTo(0, d: const Duration(milliseconds: 500), done: () {
        if (gen == _gen) _player.pause().catchError((_) {});
      });
      if (!_enabled) _playingKey = null;
      return;
    }
    final e = _stack.last;
    final key = '${e.theme}_${e.index}';
    final target = e.theme == 'ambient' ? _ambientVolume : _themeVolume;
    if (key == _playingKey) {
      if (resume || _player.state != PlayerState.playing) {
        await _player.resume().catchError((_) {});
      }
      _fadeTo(target);
      return;
    }
    try {
      final path = await (_rendering[key] ??= _file(e.theme, e.index));
      _rendering.remove(key);
      if (gen != _gen) return;
      final c = Completer<void>();
      _fadeTo(0, d: const Duration(milliseconds: 600), done: c.complete);
      await c.future;
      if (gen != _gen) return;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(DeviceFileSource(path), volume: 0);
      _playingKey = key;
      _volume = 0;
      if (gen != _gen) return;
      _fadeTo(target, d: const Duration(milliseconds: 1600));
    } catch (err) {
      _rendering.remove(key);
      debugPrint('music error: $err');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fade?.cancel();
    _player.dispose();
    super.dispose();
  }
}

/// Mixin for screens that set a music theme while visible.
mixin MusicTheme<T extends StatefulWidget> on State<T> {
  Object? _musicToken;
  MusicService? _music;

  void startMusic(MusicService music, String theme, {int? seed}) {
    _music = music;
    _musicToken = music.push(theme, seed: seed);
  }

  void changeMusicTheme(String theme) {
    if (_musicToken != null) _music?.retheme(_musicToken!, theme);
  }

  @override
  void dispose() {
    if (_musicToken != null) _music?.pop(_musicToken!);
    super.dispose();
  }
}
