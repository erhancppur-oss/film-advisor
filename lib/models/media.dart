enum MediaType { movie, tv }

MediaType? mediaTypeFromString(String? s) {
  switch (s) {
    case 'movie':
      return MediaType.movie;
    case 'tv':
      return MediaType.tv;
    default:
      return null;
  }
}

double _toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
int _toInt(dynamic v) => v is num ? v.toInt() : 0;
String? _str(dynamic v) => (v is String && v.isNotEmpty) ? v : null;

/// A movie or TV show as it appears in lists.
class MediaItem {
  final int id;
  final MediaType type;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String? date;
  final String overview;
  final List<int> genreIds;
  final String? originalLanguage;
  final double popularity;

  const MediaItem({
    required this.id,
    required this.type,
    required this.title,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0,
    this.voteCount = 0,
    this.date,
    this.overview = '',
    this.genreIds = const [],
    this.originalLanguage,
    this.popularity = 0,
  });

  /// Returns null for entries that are not movies / tv (e.g. people in multi search).
  static MediaItem? tryParse(Map<String, dynamic> j, {MediaType? forcedType}) {
    final type = forcedType ?? mediaTypeFromString(j['media_type'] as String?);
    if (type == null) return null;
    final id = j['id'];
    if (id is! num) return null;
    final title = (type == MediaType.movie
            ? (j['title'] ?? j['original_title'])
            : (j['name'] ?? j['original_name'])) as String? ??
        '';
    return MediaItem(
      id: id.toInt(),
      type: type,
      title: title,
      posterPath: _str(j['poster_path']),
      backdropPath: _str(j['backdrop_path']),
      voteAverage: _toDouble(j['vote_average']),
      voteCount: _toInt(j['vote_count']),
      date: _str(type == MediaType.movie ? j['release_date'] : j['first_air_date']),
      overview: (j['overview'] as String?) ?? '',
      genreIds: (j['genre_ids'] as List?)?.whereType<num>().map((e) => e.toInt()).toList() ??
          ((j['genres'] as List?)
                  ?.whereType<Map>()
                  .map((g) => g['id'])
                  .whereType<num>()
                  .map((e) => e.toInt())
                  .toList() ??
              const []),
      originalLanguage: _str(j['original_language']),
      popularity: _toDouble(j['popularity']),
    );
  }

  String get key => '${type.name}_$id';

  String get year => (date != null && date!.length >= 4) ? date!.substring(0, 4) : '';

  /// Compact representation for local storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'media_type': type.name,
        if (type == MediaType.movie) 'title': title else 'name': title,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'vote_average': voteAverage,
        'vote_count': voteCount,
        if (type == MediaType.movie) 'release_date': date else 'first_air_date': date,
        'genre_ids': genreIds,
        'original_language': originalLanguage,
      };

  @override
  bool operator ==(Object other) => other is MediaItem && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

class PagedResult {
  final List<MediaItem> items;
  final int page;
  final int totalPages;
  final int totalResults;

  const PagedResult(this.items, {this.page = 1, this.totalPages = 1, this.totalResults = 0});

  bool get hasMore => page < totalPages;

  static PagedResult fromJson(Map<String, dynamic> j, {MediaType? forcedType}) {
    final results = (j['results'] as List?) ?? const [];
    final items = <MediaItem>[];
    for (final r in results) {
      if (r is Map<String, dynamic>) {
        final m = MediaItem.tryParse(r, forcedType: forcedType);
        if (m != null) items.add(m);
      }
    }
    return PagedResult(
      items,
      page: _toInt(j['page']).clamp(1, 1 << 30),
      // TMDB caps discover at 500 pages.
      totalPages: _toInt(j['total_pages']).clamp(1, 500),
      totalResults: _toInt(j['total_results']),
    );
  }
}

class Genre {
  final int id;
  final String name;
  const Genre(this.id, this.name);
}

class CastMember {
  final String name;
  final String character;
  final String? profilePath;
  const CastMember(this.name, this.character, this.profilePath);
}

class Video {
  final String key;
  final String name;
  final String site;
  final String type;
  final bool official;
  final String? language;
  const Video(this.key, this.name, this.site, this.type, this.official, this.language);

  String get url => 'https://www.youtube.com/watch?v=$key';
}

class WatchProvider {
  final int id;
  final String name;
  final String? logoPath;
  final int priority;
  const WatchProvider(this.id, this.name, this.logoPath, this.priority);

  static WatchProvider fromJson(Map<String, dynamic> j, {String? region}) {
    int prio = _toInt(j['display_priority']);
    final perRegion = j['display_priorities'];
    if (region != null && perRegion is Map && perRegion[region] is num) {
      prio = (perRegion[region] as num).toInt();
    }
    return WatchProvider(
      _toInt(j['provider_id']),
      (j['provider_name'] as String?) ?? '',
      _str(j['logo_path']),
      prio,
    );
  }
}

class WatchAvailability {
  final String? link;
  final List<WatchProvider> stream;
  final List<WatchProvider> free;
  final List<WatchProvider> rent;
  final List<WatchProvider> buy;
  const WatchAvailability({
    this.link,
    this.stream = const [],
    this.free = const [],
    this.rent = const [],
    this.buy = const [],
  });

  bool get isEmpty => stream.isEmpty && free.isEmpty && rent.isEmpty && buy.isEmpty;
}

/// Full details for the detail page.
class MediaDetail {
  final MediaItem item;
  final String overview;
  final String? tagline;
  final List<Genre> genres;
  final int? runtime;
  final String? status;
  final int? seasons;
  final int? episodes;
  final List<CastMember> cast;
  final List<String> directors;
  final List<Video> videos;
  final List<MediaItem> recommendations;
  final List<MediaItem> similar;
  final WatchAvailability watch;
  final String? certification;
  final String? imdbId;
  final String? homepage;
  final List<String> countries;

  const MediaDetail({
    required this.item,
    required this.overview,
    this.tagline,
    this.genres = const [],
    this.runtime,
    this.status,
    this.seasons,
    this.episodes,
    this.cast = const [],
    this.directors = const [],
    this.videos = const [],
    this.recommendations = const [],
    this.similar = const [],
    this.watch = const WatchAvailability(),
    this.certification,
    this.imdbId,
    this.homepage,
    this.countries = const [],
  });

  Video? get trailer {
    final yt = videos.where((v) => v.site == 'YouTube').toList();
    if (yt.isEmpty) return null;
    int score(Video v) =>
        (v.type == 'Trailer' ? 4 : (v.type == 'Teaser' ? 2 : 0)) + (v.official ? 1 : 0);
    yt.sort((a, b) => score(b).compareTo(score(a)));
    return yt.first;
  }

  MediaDetail copyWith({String? overview, String? tagline}) => MediaDetail(
        item: item,
        overview: overview ?? this.overview,
        tagline: tagline ?? this.tagline,
        genres: genres,
        runtime: runtime,
        status: status,
        seasons: seasons,
        episodes: episodes,
        cast: cast,
        directors: directors,
        videos: videos,
        recommendations: recommendations,
        similar: similar,
        watch: watch,
        certification: certification,
        imdbId: imdbId,
        homepage: homepage,
        countries: countries,
      );

  static MediaDetail fromJson(Map<String, dynamic> j, MediaType type, String region) {
    final item = MediaItem.tryParse(j, forcedType: type)!;
    final genres = ((j['genres'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((g) => Genre(_toInt(g['id']), (g['name'] as String?) ?? ''))
        .toList();

    int? runtime;
    if (type == MediaType.movie) {
      final r = _toInt(j['runtime']);
      runtime = r > 0 ? r : null;
    } else {
      final ert = (j['episode_run_time'] as List?)?.whereType<num>().toList() ?? const [];
      if (ert.isNotEmpty) runtime = ert.first.toInt();
    }

    final credits = (j['credits'] as Map<String, dynamic>?) ?? const {};
    final cast = ((credits['cast'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .take(20)
        .map((c) => CastMember(
              (c['name'] as String?) ?? '',
              (c['character'] as String?) ?? '',
              _str(c['profile_path']),
            ))
        .toList();

    List<String> directors;
    if (type == MediaType.movie) {
      directors = ((credits['crew'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .where((c) => c['job'] == 'Director')
          .map((c) => (c['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
    } else {
      directors = ((j['created_by'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((c) => (c['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    }

    final videos = (((j['videos'] as Map?)?['results'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((v) => Video(
              (v['key'] as String?) ?? '',
              (v['name'] as String?) ?? '',
              (v['site'] as String?) ?? '',
              (v['type'] as String?) ?? '',
              v['official'] == true,
              _str(v['iso_639_1']),
            ))
        .where((v) => v.key.isNotEmpty)
        .toList();

    List<MediaItem> parseList(dynamic m) {
      final results = ((m as Map?)?['results'] as List?) ?? const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map((r) => MediaItem.tryParse(r, forcedType: type))
          .whereType<MediaItem>()
          .toList();
    }

    // Watch providers (data by JustWatch)
    WatchAvailability watch = const WatchAvailability();
    final wp = ((j['watch/providers'] as Map?)?['results'] as Map?)?[region];
    if (wp is Map) {
      List<WatchProvider> pl(String k) => ((wp[k] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => WatchProvider.fromJson(e))
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
      watch = WatchAvailability(
        link: _str(wp['link']),
        stream: pl('flatrate'),
        free: [...pl('free'), ...pl('ads')],
        rent: pl('rent'),
        buy: pl('buy'),
      );
    }

    // Certification / age rating
    String? cert;
    if (type == MediaType.movie) {
      final rd = ((j['release_dates'] as Map?)?['results'] as List?) ?? const [];
      String? find(String country) {
        for (final r in rd.whereType<Map>()) {
          if (r['iso_3166_1'] == country) {
            for (final d in ((r['release_dates'] as List?) ?? const []).whereType<Map>()) {
              final c = _str(d['certification']);
              if (c != null) return c;
            }
          }
        }
        return null;
      }

      cert = find(region) ?? find('US');
    } else {
      final cr = ((j['content_ratings'] as Map?)?['results'] as List?) ?? const [];
      String? find(String country) {
        for (final r in cr.whereType<Map>()) {
          if (r['iso_3166_1'] == country) return _str(r['rating']);
        }
        return null;
      }

      cert = find(region) ?? find('US');
    }

    final countries = type == MediaType.movie
        ? ((j['production_countries'] as List?) ?? const [])
            .whereType<Map>()
            .map((c) => (c['iso_3166_1'] as String?) ?? '')
            .where((s) => s.isNotEmpty)
            .toList()
        : ((j['origin_country'] as List?) ?? const []).whereType<String>().toList();

    return MediaDetail(
      item: item,
      overview: (j['overview'] as String?) ?? '',
      tagline: _str(j['tagline']),
      genres: genres,
      runtime: runtime,
      status: _str(j['status']),
      seasons: type == MediaType.tv ? _toInt(j['number_of_seasons']) : null,
      episodes: type == MediaType.tv ? _toInt(j['number_of_episodes']) : null,
      cast: cast,
      directors: directors,
      videos: videos,
      recommendations: parseList(j['recommendations']),
      similar: parseList(j['similar']),
      watch: watch,
      certification: cert,
      imdbId: _str(j['imdb_id']) ?? _str((j['external_ids'] as Map?)?['imdb_id']),
      homepage: _str(j['homepage']),
      countries: countries,
    );
  }
}
