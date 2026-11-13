import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../models/advisor.dart';

/// Wizard steps in order. Each one can be "remembered" so it is not asked again.
const List<String> kAdvisorSteps = [
  'content',
  'mood',
  'genres',
  'era',
  'runtime',
  'quality',
  'language',
  'platforms',
];

/// Question text key for a step (used as title in Settings).
String stepQuestionKey(String step) {
  switch (step) {
    case 'content':
      return 'q_content';
    case 'mood':
      return 'q_mood';
    case 'genres':
      return 'q_genres';
    case 'era':
      return 'q_era';
    case 'runtime':
      return 'q_runtime';
    case 'quality':
      return 'q_quality';
    case 'language':
      return 'q_language';
    default:
      return 'q_platform';
  }
}

/// Remembered answers of the manual advisor + the user's streaming platforms.
class AdvisorPrefs extends ChangeNotifier {
  AdvisorPrefs(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        _saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {}
    }
    final p = _prefs.getString('my_platforms');
    if (p != null) {
      try {
        final m = jsonDecode(p) as Map;
        _platforms = {
          for (final e in m.entries) int.parse(e.key as String): e.value as String,
        };
      } catch (_) {}
    }
  }

  static const _key = 'advisor_saved';
  final SharedPreferences _prefs;
  Map<String, dynamic> _saved = {};
  Map<int, String> _platforms = {};

  bool isSaved(String step) => _saved.containsKey(step);
  List<String> get savedSteps => kAdvisorSteps.where(isSaved).toList();

  /// Platforms used by "On my platforms" (id -> name).
  Map<int, String> get myPlatforms => Map.unmodifiable(_platforms);

  Future<void> setMyPlatforms(Map<int, String> p) async {
    _platforms = Map.of(p);
    await _prefs.setString(
        'my_platforms', jsonEncode(_platforms.map((k, v) => MapEntry('$k', v))));
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(_saved));
    notifyListeners();
  }

  Future<void> remove(String step) async {
    _saved.remove(step);
    await _persist();
  }

  Future<void> clear() async {
    _saved.clear();
    await _persist();
  }

  /// Saves the answer of [step] from [c]. [providerNames] is used for display.
  Future<void> save(String step, AdvisorCriteria c, {Map<int, String>? providerNames}) async {
    switch (step) {
      case 'content':
        _saved[step] = c.content.name;
        break;
      case 'mood':
        _saved[step] = c.moodKey ?? '';
        break;
      case 'genres':
        _saved[step] = {'inc': c.includeGenres.toList(), 'exc': c.excludeGenres.toList()};
        break;
      case 'era':
        _saved[step] = c.era.name;
        break;
      case 'runtime':
        _saved[step] = c.runtime.name;
        break;
      case 'quality':
        _saved[step] = {'fame': c.fame.name, 'min': c.minRating, 'kids': c.withKids};
        break;
      case 'language':
        _saved[step] = c.language ?? '';
        break;
      case 'platforms':
        _saved[step] = {
          for (final id in c.providers) '$id': providerNames?[id] ?? '#$id',
        };
        break;
    }
    await _persist();
  }

  T _byName<T extends Enum>(List<T> values, dynamic name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  /// Applies every remembered answer to [c].
  AdvisorCriteria apply(AdvisorCriteria c) {
    for (final step in savedSteps) {
      final v = _saved[step];
      try {
        switch (step) {
          case 'content':
            c.content = _byName(ContentChoice.values, v, ContentChoice.any);
            break;
          case 'mood':
            c.moodKey = (v as String).isEmpty ? null : v;
            break;
          case 'genres':
            c.includeGenres = ((v as Map)['inc'] as List).cast<String>().toSet();
            c.excludeGenres = (v['exc'] as List).cast<String>().toSet();
            break;
          case 'era':
            c.era = _byName(Era.values, v, Era.any);
            break;
          case 'runtime':
            c.runtime = _byName(RuntimePref.values, v, RuntimePref.any);
            break;
          case 'quality':
            final m = v as Map;
            c.fame = _byName(Fame.values, m['fame'], Fame.popular);
            c.minRating = (m['min'] as num).toDouble();
            c.withKids = m['kids'] == true;
            break;
          case 'language':
            c.language = (v as String).isEmpty ? null : v;
            break;
          case 'platforms':
            c.providers = (v as Map).keys.map((k) => int.parse(k as String)).toSet();
            break;
        }
      } catch (_) {
        // ignore corrupt entry
      }
    }
    return c;
  }

  /// Human readable value for Settings.
  String summary(String step, S s) {
    final v = _saved[step];
    String any() => s.t('adv_skip');
    try {
      switch (step) {
        case 'content':
          return s.t('content_$v');
        case 'mood':
          return (v as String).isEmpty ? any() : s.t('mood_$v');
        case 'genres':
          final inc = ((v as Map)['inc'] as List).map((g) => '✓ ${s.t('genre_$g')}');
          final exc = (v['exc'] as List).map((g) => '✕ ${s.t('genre_$g')}');
          final all = [...inc, ...exc];
          return all.isEmpty ? any() : all.join(', ');
        case 'era':
          return s.t('era_$v');
        case 'runtime':
          return s.t('rt_$v');
        case 'quality':
          final m = v as Map;
          final parts = [
            s.t('fame_${m['fame']}'),
            if ((m['min'] as num) > 0) '★ ${(m['min'] as num).toStringAsFixed(1)}+',
            if (m['kids'] == true) s.t('q_kids'),
          ];
          return parts.join(' · ');
        case 'language':
          return (v as String).isEmpty ? any() : s.t('lang_$v');
        case 'platforms':
          final names = (v as Map).values.cast<String>().toList();
          return names.isEmpty ? any() : names.join(', ');
      }
    } catch (_) {}
    return '';
  }
}
