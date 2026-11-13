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

  void configure({required String languageCode, required String region}) {
    final newLang = languageCode == 'tr' ? 'tr-TR' : 'en-US';
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
