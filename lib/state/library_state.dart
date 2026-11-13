import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media.dart';

/// The user's personal lists. Stored ONLY on the device (no account, no server).
class LibraryState extends ChangeNotifier {
  LibraryState(this._prefs) {
    _watchlist = _load('watchlist');
    _watched = _load('watched');
    _disliked = (_prefs.getStringList('disliked') ?? const []).toSet();
    _recentSearches = _prefs.getStringList('recent_searches') ?? <String>[];
  }

  final SharedPreferences _prefs;

  late List<MediaItem> _watchlist;
  late List<MediaItem> _watched;
  late Set<String> _disliked;
  late List<String> _recentSearches;

  List<MediaItem> get watchlist => List.unmodifiable(_watchlist);
  List<MediaItem> get watched => List.unmodifiable(_watched);
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  bool isInWatchlist(MediaItem m) => _watchlist.any((e) => e.key == m.key);
  bool isWatched(MediaItem m) => _watched.any((e) => e.key == m.key);
  bool isDisliked(MediaItem m) => _disliked.contains(m.key);

  /// Items that should not be recommended again.
  bool isKnown(MediaItem m) => isInWatchlist(m) || isWatched(m) || isDisliked(m);

  /// Most recent liked items; used as seeds for "For you".
  List<MediaItem> get seeds => [..._watchlist.take(4), ..._watched.take(3)];

  List<MediaItem> _load(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return <MediaItem>[];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => MediaItem.tryParse(e))
          .whereType<MediaItem>()
          .toList();
    } catch (_) {
      return <MediaItem>[];
    }
  }

  Future<void> _save() async {
    await _prefs.setString('watchlist', jsonEncode(_watchlist.map((e) => e.toJson()).toList()));
    await _prefs.setString('watched', jsonEncode(_watched.map((e) => e.toJson()).toList()));
    await _prefs.setStringList('disliked', _disliked.toList());
  }

  Future<void> toggleWatchlist(MediaItem m) async {
    if (isInWatchlist(m)) {
      _watchlist.removeWhere((e) => e.key == m.key);
    } else {
      _watchlist.insert(0, m);
      _disliked.remove(m.key);
    }
    notifyListeners();
    await _save();
  }

  Future<void> addToWatchlist(MediaItem m) async {
    if (isInWatchlist(m)) return;
    _watchlist.insert(0, m);
    _disliked.remove(m.key);
    notifyListeners();
    await _save();
  }

  Future<void> toggleWatched(MediaItem m) async {
    if (isWatched(m)) {
      _watched.removeWhere((e) => e.key == m.key);
    } else {
      _watched.insert(0, m);
      _watchlist.removeWhere((e) => e.key == m.key);
    }
    notifyListeners();
    await _save();
  }

  Future<void> dislike(MediaItem m) async {
    _disliked.add(m.key);
    // keep the set bounded
    if (_disliked.length > 2000) {
      _disliked = _disliked.skip(_disliked.length - 2000).toSet();
    }
    notifyListeners();
    await _save();
  }

  Future<void> remove(MediaItem m) async {
    _watchlist.removeWhere((e) => e.key == m.key);
    _watched.removeWhere((e) => e.key == m.key);
    notifyListeners();
    await _save();
  }

  Future<void> addRecentSearch(String q) async {
    final t = q.trim();
    if (t.isEmpty) return;
    _recentSearches.remove(t);
    _recentSearches.insert(0, t);
    if (_recentSearches.length > 10) _recentSearches = _recentSearches.sublist(0, 10);
    notifyListeners();
    await _prefs.setStringList('recent_searches', _recentSearches);
  }

  Future<void> clearRecentSearches() async {
    _recentSearches = <String>[];
    notifyListeners();
    await _prefs.remove('recent_searches');
  }

  Future<void> clearAll() async {
    _watchlist = <MediaItem>[];
    _watched = <MediaItem>[];
    _disliked = <String>{};
    _recentSearches = <String>[];
    notifyListeners();
    await _prefs.remove('watchlist');
    await _prefs.remove('watched');
    await _prefs.remove('disliked');
    await _prefs.remove('recent_searches');
  }
}
