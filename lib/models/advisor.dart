import 'media.dart';

/// A genre that exists (possibly under a different id) for both movies and TV.
class UnifiedGenre {
  final String key; // l10n key: genre_<key>
  final int? movieId;
  final int? tvId;
  const UnifiedGenre(this.key, this.movieId, this.tvId);

  int? idFor(MediaType t) => t == MediaType.movie ? movieId : tvId;
}

const List<UnifiedGenre> kGenres = [
  UnifiedGenre('action', 28, 10759),
  UnifiedGenre('adventure', 12, 10759),
  UnifiedGenre('animation', 16, 16),
  UnifiedGenre('comedy', 35, 35),
  UnifiedGenre('crime', 80, 80),
  UnifiedGenre('documentary', 99, 99),
  UnifiedGenre('drama', 18, 18),
  UnifiedGenre('family', 10751, 10751),
  UnifiedGenre('fantasy', 14, 10765),
  UnifiedGenre('history', 36, null),
  UnifiedGenre('horror', 27, null),
  UnifiedGenre('music', 10402, null),
  UnifiedGenre('mystery', 9648, 9648),
  UnifiedGenre('romance', 10749, null),
  UnifiedGenre('scifi', 878, 10765),
  UnifiedGenre('thriller', 53, null),
  UnifiedGenre('war', 10752, 10768),
  UnifiedGenre('western', 37, 37),
];

class Mood {
  final String key; // l10n key: mood_<key>
  final String emoji;
  final List<int> movieGenres;
  final List<int> tvGenres;
  final List<int> movieExclude;
  final List<int> tvExclude;
  const Mood(this.key, this.emoji, this.movieGenres, this.tvGenres,
      {this.movieExclude = const [], this.tvExclude = const []});
}

const List<Mood> kMoods = [
  Mood('laugh', '😂', [35], [35], movieExclude: [27], tvExclude: []),
  Mood('feelgood', '🥰', [10751, 35, 16, 10402], [10751, 35],
      movieExclude: [27, 53], tvExclude: [80]),
  Mood('thrill', '😱', [53, 80, 9648], [80, 9648]),
  Mood('scare', '👻', [27], [9648, 10765]),
  Mood('adrenaline', '💥', [28, 12], [10759]),
  Mood('mindbend', '🤯', [878, 9648], [10765, 9648]),
  Mood('cry', '😢', [18, 10749], [18], movieExclude: [35, 27]),
  Mood('romance', '❤️', [10749], [18], movieExclude: [27]),
  Mood('escape', '🧙', [14, 12, 16], [10765]),
  Mood('learn', '🧠', [99, 36], [99]),
];

enum ContentChoice { movie, tv, any }

enum Era { any, recent, y2010s, y2000s, y90s, classic }

enum RuntimePref { any, short, medium, long }

enum Fame { popular, acclaimed, hidden }

class LanguageOption {
  final String key; // l10n: lang_<key>
  final String? code;
  const LanguageOption(this.key, this.code);
}

const List<LanguageOption> kLanguages = [
  LanguageOption('any', null),
  LanguageOption('tr', 'tr'),
  LanguageOption('en', 'en'),
  LanguageOption('ko', 'ko'),
  LanguageOption('ja', 'ja'),
  LanguageOption('es', 'es'),
  LanguageOption('fr', 'fr'),
  LanguageOption('hi', 'hi'),
  LanguageOption('de', 'de'),
  LanguageOption('it', 'it'),
];

/// User answers from the advisor wizard. Converted into TMDB /discover params.
class AdvisorCriteria {
  ContentChoice content;
  String? moodKey;
  Set<String> includeGenres;
  Set<String> excludeGenres;
  Era era;
  RuntimePref runtime;
  double minRating;
  Fame fame;
  String? language;
  Set<int> providers;
  bool withKids;

  AdvisorCriteria({
    this.content = ContentChoice.any,
    this.moodKey,
    Set<String>? includeGenres,
    Set<String>? excludeGenres,
    this.era = Era.any,
    this.runtime = RuntimePref.any,
    this.minRating = 6.5,
    this.fame = Fame.popular,
    this.language,
    Set<int>? providers,
    this.withKids = false,
  })  : includeGenres = includeGenres ?? <String>{},
        excludeGenres = excludeGenres ?? <String>{},
        providers = providers ?? <int>{};

  AdvisorCriteria copy() => AdvisorCriteria(
        content: content,
        moodKey: moodKey,
        includeGenres: {...includeGenres},
        excludeGenres: {...excludeGenres},
        era: era,
        runtime: runtime,
        minRating: minRating,
        fame: fame,
        language: language,
        providers: {...providers},
        withKids: withKids,
      );

  AdvisorCriteria relaxed() => AdvisorCriteria(
        content: content,
        moodKey: moodKey,
        includeGenres: includeGenres,
        excludeGenres: excludeGenres,
        era: Era.any,
        runtime: RuntimePref.any,
        minRating: minRating > 5 ? 5 : minRating,
        fame: Fame.popular,
        language: language,
        providers: providers,
        withKids: withKids,
      );

  List<MediaType> get types {
    switch (content) {
      case ContentChoice.movie:
        return [MediaType.movie];
      case ContentChoice.tv:
        return [MediaType.tv];
      case ContentChoice.any:
        return [MediaType.movie, MediaType.tv];
    }
  }

  Mood? get mood {
    for (final m in kMoods) {
      if (m.key == moodKey) return m;
    }
    return null;
  }

  Map<String, String> toDiscoverParams(MediaType type, String region) {
    final p = <String, String>{'include_adult': 'false', 'include_video': 'false'};
    final isMovie = type == MediaType.movie;

    // ----- genres -----
    final include = <int>{};
    final exclude = <int>{};
    if (includeGenres.isNotEmpty) {
      for (final g in kGenres) {
        if (includeGenres.contains(g.key)) {
          final id = g.idFor(type);
          if (id != null) include.add(id);
        }
      }
    } else if (mood != null) {
      include.addAll(isMovie ? mood!.movieGenres : mood!.tvGenres);
      exclude.addAll(isMovie ? mood!.movieExclude : mood!.tvExclude);
    }
    for (final g in kGenres) {
      if (excludeGenres.contains(g.key)) {
        final id = g.idFor(type);
        if (id != null) exclude.add(id);
      }
    }
    if (withKids) {
      if (isMovie) {
        p['certification_country'] = 'US';
        p['certification.lte'] = 'PG';
        exclude.addAll([27, 53, 80]);
      } else {
        if (include.isEmpty) include.addAll([10762, 10751]);
        exclude.addAll([80, 10768]);
      }
    }
    include.removeAll(exclude);
    if (include.isNotEmpty) p['with_genres'] = include.join('|'); // OR
    if (exclude.isNotEmpty) p['without_genres'] = exclude.join(',');

    // ----- era -----
    final now = DateTime.now();
    int? from, to;
    switch (era) {
      case Era.any:
        break;
      case Era.recent:
        from = now.year - 2;
        break;
      case Era.y2010s:
        from = 2010;
        to = 2019;
        break;
      case Era.y2000s:
        from = 2000;
        to = 2009;
        break;
      case Era.y90s:
        from = 1990;
        to = 1999;
        break;
      case Era.classic:
        to = 1989;
        break;
    }
    final dateKey = isMovie ? 'primary_release_date' : 'first_air_date';
    if (from != null) p['$dateKey.gte'] = '$from-01-01';
    if (to != null) {
      p['$dateKey.lte'] = '$to-12-31';
    } else {
      // never recommend unreleased titles
      final m = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      p['$dateKey.lte'] = '${now.year}-$m-$d';
    }

    // ----- runtime -----
    switch (runtime) {
      case RuntimePref.any:
        break;
      case RuntimePref.short:
        p['with_runtime.lte'] = isMovie ? '95' : '30';
        if (isMovie) p['with_runtime.gte'] = '60';
        break;
      case RuntimePref.medium:
        p['with_runtime.gte'] = isMovie ? '90' : '30';
        p['with_runtime.lte'] = isMovie ? '130' : '55';
        break;
      case RuntimePref.long:
        p['with_runtime.gte'] = isMovie ? '130' : '50';
        break;
    }

    // ----- rating & fame -----
    double minR = minRating;
    switch (fame) {
      case Fame.popular:
        p['sort_by'] = 'popularity.desc';
        p['vote_count.gte'] = isMovie ? '500' : '150';
        break;
      case Fame.acclaimed:
        p['sort_by'] = 'vote_average.desc';
        p['vote_count.gte'] = isMovie ? '1500' : '400';
        break;
      case Fame.hidden:
        p['sort_by'] = 'vote_average.desc';
        p['vote_count.gte'] = isMovie ? '60' : '25';
        p['vote_count.lte'] = isMovie ? '900' : '250';
        if (minR < 7) minR = 7;
        break;
    }
    if (language != null && fame != Fame.hidden) {
      // Non-English catalogues have fewer votes; loosen the threshold.
      final current = int.parse(p['vote_count.gte']!);
      p['vote_count.gte'] = (current ~/ 5).clamp(10, 100000).toString();
    }
    if (minR > 0) p['vote_average.gte'] = minR.toStringAsFixed(1);

    // ----- language -----
    if (language != null) p['with_original_language'] = language!;

    // ----- platforms -----
    if (providers.isNotEmpty) {
      p['with_watch_providers'] = providers.join('|');
      p['watch_region'] = region;
    }
    return p;
  }
}
