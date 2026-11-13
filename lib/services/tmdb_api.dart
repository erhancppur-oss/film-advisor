import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/media.dart';

enum ApiErrorKind { missingKey, invalidKey, network, rateLimited, notFound, server }

class ApiException implements Exception {
  final ApiErrorKind kind;
  final String? detail;
  const ApiException(this.kind, [this.detail]);

  @override
  String toString() => 'ApiException($kind${detail == null ? '' : ': $detail'})';
}

class _CacheEntry {
  final DateTime time;
  final Map<String, dynamic> data;
  _CacheEntry(this.time, this.data);
}

/// Thin client for The Movie Database (TMDB) v3 API.
///
/// This product uses the TMDB API but is not endorsed or certified by TMDB.
class TmdbApi {
  TmdbApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, _CacheEntry> _cache = {};
  static const _ttl = Duration(minutes: 15);

  /// TMDB language tag, e.g. tr-TR / en-US
  String language = 'en-US';

  /// ISO 3166-1 country used for theatres & streaming providers.
  String region = 'TR';

  static const Map<String, String> _tmdbLang = {
    'en': 'en-US',
    'tr': 'tr-TR',
    'de': 'de-DE',
    'fr': 'fr-FR',
    'es': 'es-ES',
    'ar': 'ar-SA',
  };

  void configure({required String languageCode, required String region}) {
    final newLang = _tmdbLang[languageCode] ?? 'en-US';
    if (newLang != language || region != this.region) {
      language = newLang;
      this.region = region;
    }
  }

  void clearCache() => _cache.clear();

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? params, String? languageOverride]) async {
    if (!AppConfig.hasApiKey) throw const ApiException(ApiErrorKind.missingKey);
    final key = AppConfig.tmdbApiKey.trim();
    final isBearer = key.startsWith('eyJ');
    final query = <String, String>{
      if (!isBearer) 'api_key': key,
      'language': languageOverride ?? language,
      ...?params,
    };
    final uri = Uri.https('api.themoviedb.org', '/3$path', query);
    final cacheKey = uri.toString();
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().difference(cached.time) < _ttl) {
      return cached.data;
    }

    http.Response res;
    try {
      res = await _client.get(uri, headers: {
        'Accept': 'application/json',
        if (isBearer) 'Authorization': 'Bearer $key',
      }).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.network, 'timeout');
    } catch (e) {
      throw ApiException(ApiErrorKind.network, e.toString());
    }

    switch (res.statusCode) {
      case 200:
        break;
      case 401:
        throw const ApiException(ApiErrorKind.invalidKey);
      case 404:
        throw const ApiException(ApiErrorKind.notFound);
      case 429:
        throw const ApiException(ApiErrorKind.rateLimited);
      default:
        throw ApiException(ApiErrorKind.server, 'HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(ApiErrorKind.server, 'bad json');
    }
    _cache[cacheKey] = _CacheEntry(DateTime.now(), decoded);
    if (_cache.length > 300) {
      final oldest = _cache.entries.reduce((a, b) => a.value.time.isBefore(b.value.time) ? a : b);
      _cache.remove(oldest.key);
    }
    return decoded;
  }

  static String _t(MediaType t) => t == MediaType.movie ? 'movie' : 'tv';

  // ---------------------------------------------------------------- lists

  Future<PagedResult> trending(MediaType? type, {int page = 1, bool daily = false}) async {
    final kind = type == null ? 'all' : _t(type);
    final j = await _get('/trending/$kind/${daily ? 'day' : 'week'}', {'page': '$page'});
    return PagedResult.fromJson(j, forcedType: type);
  }

  /// category: popular, top_rated, now_playing, upcoming, on_the_air, airing_today
  Future<PagedResult> category(MediaType type, String category, {int page = 1}) async {
    final params = <String, String>{'page': '$page'};
    if (category == 'now_playing' || category == 'upcoming') params['region'] = region;
    final j = await _get('/${_t(type)}/$category', params);
    return PagedResult.fromJson(j, forcedType: type);
  }

  Future<PagedResult> discover(MediaType type, Map<String, String> params, {int page = 1}) async {
    final j = await _get('/discover/${_t(type)}', {
      'include_adult': 'false',
      ...params,
      'page': '$page',
    });
    return PagedResult.fromJson(j, forcedType: type);
  }

  Future<PagedResult> search(String query, {int page = 1}) async {
    final j = await _get('/search/multi', {
      'query': query,
      'page': '$page',
      'include_adult': 'false',
    });
    return PagedResult.fromJson(j);
  }

  Future<PagedResult> recommendations(MediaType type, int id, {int page = 1}) async {
    final j = await _get('/${_t(type)}/$id/recommendations', {'page': '$page'});
    return PagedResult.fromJson(j, forcedType: type);
  }

  // ---------------------------------------------------------------- details

  Future<MediaDetail> details(MediaType type, int id) async {
    final append = type == MediaType.movie
        ? 'credits,videos,recommendations,similar,watch/providers,release_dates'
        : 'credits,videos,recommendations,similar,watch/providers,content_ratings,external_ids';
    final lang2 = language.substring(0, 2);
    final j = await _get('/${_t(type)}/$id', {
      'append_to_response': append,
      'include_video_language': '$lang2,en,null',
    });
    var detail = MediaDetail.fromJson(j, type, region);

    // Many titles have no Turkish synopsis yet: fall back to English.
    if (detail.overview.trim().isEmpty && language != 'en-US') {
      try {
        final en = await _get('/${_t(type)}/$id', null, 'en-US');
        detail = detail.copyWith(
          overview: (en['overview'] as String?) ?? '',
          tagline: detail.tagline ?? (en['tagline'] as String?),
        );
      } catch (_) {
        // keep what we have
      }
    }
    return detail;
  }

  Future<PagedResult> similar(MediaType type, int id, {int page = 1}) async {
    final j = await _get('/${_t(type)}/$id/similar', {'page': '$page'});
    return PagedResult.fromJson(j, forcedType: type);
  }

  /// Fetch several pages in parallel and return up to [limit] unique items.
  Future<List<MediaItem>> collect(Future<PagedResult> Function(int page) loader, int limit) async {
    final pages = ((limit + 19) ~/ 20).clamp(1, 10);
    final results = await Future.wait(List.generate(pages, (i) => loader(i + 1)));
    final seen = <String>{};
    final out = <MediaItem>[];
    for (final r in results) {
      for (final m in r.items) {
        if (seen.add(m.key)) out.add(m);
      }
    }
    return out.take(limit).toList();
  }

  // ---------------------------------------------------------------- people & keywords

  /// Returns {id, name, department, popularity} of the best matching person, or null.
  Future<Map<String, dynamic>?> searchPerson(String query) async {
    final j = await _get('/search/person', {'query': query, 'include_adult': 'false'});
    final results = ((j['results'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
    if (results.isEmpty) return null;
    return results.first;
  }

  /// Best rated titles of a person. role: 'cast' or 'director'.
  Future<List<MediaItem>> personTop(int personId, MediaType type, String role, int limit) async {
    final j = await _get('/person/$personId/${type == MediaType.movie ? 'movie' : 'tv'}_credits');
    final key = role == 'director' ? 'crew' : 'cast';
    final raw = ((j[key] as List?) ?? const []).whereType<Map<String, dynamic>>().where((c) {
      if (role == 'director') {
        return c['job'] == 'Director' || (type == MediaType.tv && c['job'] == 'Executive Producer');
      }
      final ch = ((c['character'] as String?) ?? '').toLowerCase();
      if (ch.contains('himself') || ch.contains('herself') || ch == 'self') {
        return false;
      }
      final g = (c['genre_ids'] as List?) ?? const [];
      // skip documentaries, talk shows, news & reality
      return !(g.contains(99) || g.contains(10767) || g.contains(10763) || g.contains(10764));
    }).toList();
    final items = <MediaItem>[];
    final seen = <int>{};
    for (final r in raw) {
      final m = MediaItem.tryParse(r, forcedType: type);
      if (m != null && seen.add(m.id) && m.posterPath != null) items.add(m);
    }
    for (final threshold in const [800, 300, 100, 20, 0]) {
      final pool = items.where((m) => m.voteCount >= threshold).toList();
      if (pool.length >= limit || threshold == 0) {
        pool.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
        return pool.take(limit).toList();
      }
    }
    return const [];
  }

  Future<int?> searchKeywordId(String query) async {
    final j = await _get('/search/keyword', {'query': query}, 'en-US');
    final results = ((j['results'] as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
    if (results.isEmpty) return null;
    final q = query.toLowerCase().trim();
    for (final r in results) {
      if (((r['name'] as String?) ?? '').toLowerCase() == q) return (r['id'] as num).toInt();
    }
    return (results.first['id'] as num).toInt();
  }

  /// Find a movie by its (English) title and release year.
  Future<MediaItem?> findMovie(String title, int year) async {
    final j = await _get('/search/movie', {'query': title, 'include_adult': 'false'});
    final list = PagedResult.fromJson(j, forcedType: MediaType.movie).items;
    if (list.isEmpty) return null;
    for (final m in list) {
      final y = int.tryParse(m.year) ?? 0;
      if ((y - year).abs() <= 1) return m;
    }
    return list.first;
  }

  // ---------------------------------------------------------------- misc

  Future<List<WatchProvider>> watchProviders(MediaType type) async {
    final j = await _get('/watch/providers/${_t(type)}', {'watch_region': region});
    final list = ((j['results'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((e) => WatchProvider.fromJson(e, region: region))
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return list;
  }
}
