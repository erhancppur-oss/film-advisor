import '../l10n/strings.dart';
import '../services/tmdb_api.dart';
import 'advisor.dart';
import 'media.dart';

enum TrendKind { category, discover, person, director, oscars, keyword }

/// A ranked list ("Top 10 horror movies", "Top 10 Brad Pitt movies" …).
class TrendDef {
  final String id;
  final TrendKind kind;
  final MediaType type;
  final int limit;
  final String emoji;
  final String titleKey;
  final Map<String, String> args;
  final Map<String, String> params;
  final String? query;

  const TrendDef({
    required this.id,
    required this.kind,
    required this.titleKey,
    this.type = MediaType.movie,
    this.limit = 10,
    this.emoji = '🎬',
    this.args = const {},
    this.params = const {},
    this.query,
  });

  TrendDef withName(String name) => TrendDef(
        id: id,
        kind: kind,
        titleKey: titleKey,
        type: type,
        limit: limit,
        emoji: emoji,
        args: {...args, 'name': name},
        params: params,
        query: query,
      );

  String title(S s) {
    final a = <String, String>{'n': '$limit'};
    args.forEach((k, v) {
      if (k == 'genre') {
        var g = s.t('genre_$v');
        if (const ['tr', 'fr', 'es'].contains(s.lang)) g = g.toLowerCase();
        a[k] = g;
      } else if (k == 'topic') {
        a[k] = s.t(v);
      } else {
        a[k] = v;
      }
    });
    return s.t(titleKey, a);
  }
}

// ---------------------------------------------------------------------- data

Map<String, String> _topGenre(int movieGenre, {MediaType type = MediaType.movie}) => {
      'with_genres': '$movieGenre',
      'sort_by': 'vote_average.desc',
      'vote_count.gte': type == MediaType.movie ? '1500' : '300',
    };

Map<String, String> _decade(int from) => {
      'primary_release_date.gte': '$from-01-01',
      'primary_release_date.lte': '${from + 9}-12-31',
      'sort_by': 'vote_average.desc',
      'vote_count.gte': from >= 2020 ? '1000' : '2000',
    };

class TrendSection {
  final String titleKey;
  final List<TrendDef> items;
  const TrendSection(this.titleKey, this.items);
}

TrendDef _person(String name, {String emoji = '⭐'}) => TrendDef(
      id: 'p_$name',
      kind: TrendKind.person,
      titleKey: 'trend_person_movies',
      query: name,
      args: {'name': name},
      emoji: emoji,
    );

TrendDef _director(String name) => TrendDef(
      id: 'd_$name',
      kind: TrendKind.director,
      titleKey: 'trend_director',
      query: name,
      args: {'name': name},
      emoji: '🎬',
    );

TrendDef _genre(String key, int id, String emoji) => TrendDef(
      id: 'g_$key',
      kind: TrendKind.discover,
      titleKey: 'trend_genre_movies',
      args: {'genre': key},
      params: _topGenre(id),
      emoji: emoji,
    );

TrendDef _kw(String topicKey, String keyword, String emoji) => TrendDef(
      id: 'k_$keyword',
      kind: TrendKind.keyword,
      titleKey: topicKey,
      query: keyword,
      limit: 20,
      emoji: emoji,
    );

List<TrendSection> buildTrendSections() {
  final year = DateTime.now().year;
  return [
    TrendSection('sec_all_time', [
      const TrendDef(
          id: 'top_movies', kind: TrendKind.category, titleKey: 'trend_top_movies', query: 'top_rated',
          limit: 100, emoji: '🏆'),
      const TrendDef(
          id: 'top_tv', kind: TrendKind.category, titleKey: 'trend_top_tv', query: 'top_rated',
          type: MediaType.tv, limit: 100, emoji: '📺'),
      TrendDef(
          id: 'pop_year', kind: TrendKind.discover, titleKey: 'trend_popular_year', limit: 20,
          args: {'year': '$year'}, emoji: '🔥',
          params: {'primary_release_year': '$year', 'sort_by': 'popularity.desc', 'vote_count.gte': '50'}),
      TrendDef(
          id: 'best_year', kind: TrendKind.discover, titleKey: 'trend_year', limit: 20,
          args: {'year': '${year - 1}'}, emoji: '🥇',
          params: {
            'primary_release_year': '${year - 1}',
            'sort_by': 'vote_average.desc',
            'vote_count.gte': '500'
          }),
      const TrendDef(
          id: 'oscars', kind: TrendKind.oscars, titleKey: 'trend_oscars', limit: 54, emoji: '🗽'),
    ]),
    TrendSection('sec_genres_top', [
      _genre('horror', 27, '👻'),
      _genre('scifi', 878, '🚀'),
      _genre('action', 28, '💥'),
      _genre('comedy', 35, '😂'),
      _genre('thriller', 53, '🔪'),
      _genre('crime', 80, '🕵️'),
      _genre('animation', 16, '🧸'),
      _genre('romance', 10749, '❤️'),
      _genre('war', 10752, '🪖'),
      _genre('fantasy', 14, '🐉'),
      _genre('documentary', 99, '🎥'),
      const TrendDef(
          id: 'g_tv_crime', kind: TrendKind.discover, titleKey: 'trend_genre_tv', type: MediaType.tv,
          args: {'genre': 'crime'}, emoji: '🚔',
          params: {'with_genres': '80', 'sort_by': 'vote_average.desc', 'vote_count.gte': '300'}),
    ]),
    TrendSection('sec_actors', [
      _person('Brad Pitt'),
      _person('Leonardo DiCaprio'),
      _person('Tom Hanks'),
      _person('Jason Statham', emoji: '👊'),
      _person('Keanu Reeves', emoji: '🕶️'),
      _person('Denzel Washington'),
      _person('Al Pacino'),
      _person('Robert De Niro'),
      _person('Meryl Streep'),
      _person('Scarlett Johansson'),
      _person('Cem Yılmaz', emoji: '🇹🇷'),
      _person('Kemal Sunal', emoji: '🇹🇷'),
      _person('Şener Şen', emoji: '🇹🇷'),
    ]),
    TrendSection('sec_directors', [
      _director('Christopher Nolan'),
      _director('Quentin Tarantino'),
      _director('Martin Scorsese'),
      _director('Steven Spielberg'),
      _director('Stanley Kubrick'),
      _director('Denis Villeneuve'),
      _director('Nuri Bilge Ceylan'),
    ]),
    TrendSection('sec_world', [
      const TrendDef(
          id: 'tr_movies', kind: TrendKind.discover, titleKey: 'trend_turkish_movies', emoji: '🇹🇷',
          params: {'with_original_language': 'tr', 'sort_by': 'vote_average.desc', 'vote_count.gte': '80'}),
      const TrendDef(
          id: 'tr_tv', kind: TrendKind.discover, titleKey: 'trend_turkish_tv', type: MediaType.tv,
          emoji: '🇹🇷',
          params: {'with_original_language': 'tr', 'sort_by': 'vote_average.desc', 'vote_count.gte': '25'}),
      const TrendDef(
          id: 'kdrama', kind: TrendKind.discover, titleKey: 'trend_kdrama', type: MediaType.tv,
          emoji: '🇰🇷',
          params: {
            'with_original_language': 'ko',
            'with_genres': '18',
            'sort_by': 'vote_average.desc',
            'vote_count.gte': '150'
          }),
      const TrendDef(
          id: 'anime', kind: TrendKind.discover, titleKey: 'trend_anime', type: MediaType.tv,
          emoji: '🇯🇵',
          params: {
            'with_original_language': 'ja',
            'with_genres': '16',
            'sort_by': 'vote_average.desc',
            'vote_count.gte': '300'
          }),
      const TrendDef(
          id: 'bollywood', kind: TrendKind.discover, titleKey: 'trend_bollywood', emoji: '🇮🇳',
          params: {'with_original_language': 'hi', 'sort_by': 'vote_average.desc', 'vote_count.gte': '150'}),
    ]),
    TrendSection('sec_decades', [
      TrendDef(id: 'dec_80', kind: TrendKind.discover, titleKey: 'trend_dec_80', params: _decade(1980), emoji: '📼'),
      TrendDef(id: 'dec_90', kind: TrendKind.discover, titleKey: 'trend_dec_90', params: _decade(1990), emoji: '💿'),
      TrendDef(id: 'dec_00', kind: TrendKind.discover, titleKey: 'trend_dec_00', params: _decade(2000), emoji: '📀'),
      TrendDef(id: 'dec_10', kind: TrendKind.discover, titleKey: 'trend_dec_10', params: _decade(2010), emoji: '📱'),
      TrendDef(id: 'dec_20', kind: TrendKind.discover, titleKey: 'trend_dec_20', params: _decade(2020), emoji: '✨'),
    ]),
    TrendSection('sec_topics', [
      _kw('trend_kw_true_story', 'based on true story', '📰'),
      _kw('trend_kw_time_travel', 'time travel', '⏳'),
      _kw('trend_kw_heist', 'heist', '💰'),
      _kw('trend_kw_zombie', 'zombie', '🧟'),
      _kw('trend_kw_superhero', 'superhero', '🦸'),
      _kw('trend_kw_twist', 'twist ending', '🌀'),
      _kw('trend_kw_space', 'space travel', '🪐'),
      _kw('trend_kw_christmas', 'christmas', '🎄'),
    ]),
  ];
}

/// Oscar Best Picture winners (film release year).
const List<(String, int)> kOscarBestPicture = [
  ('One Battle After Another', 2025),
  ('Anora', 2024),
  ('Oppenheimer', 2023),
  ('Everything Everywhere All at Once', 2022),
  ('CODA', 2021),
  ('Nomadland', 2020),
  ('Parasite', 2019),
  ('Green Book', 2018),
  ('The Shape of Water', 2017),
  ('Moonlight', 2016),
  ('Spotlight', 2015),
  ('Birdman', 2014),
  ('12 Years a Slave', 2013),
  ('Argo', 2012),
  ('The Artist', 2011),
  ("The King's Speech", 2010),
  ('The Hurt Locker', 2008),
  ('Slumdog Millionaire', 2008),
  ('No Country for Old Men', 2007),
  ('The Departed', 2006),
  ('Crash', 2004),
  ('Million Dollar Baby', 2004),
  ('The Lord of the Rings: The Return of the King', 2003),
  ('Chicago', 2002),
  ('A Beautiful Mind', 2001),
  ('Gladiator', 2000),
  ('American Beauty', 1999),
  ('Shakespeare in Love', 1998),
  ('Titanic', 1997),
  ('The English Patient', 1996),
  ('Braveheart', 1995),
  ('Forrest Gump', 1994),
  ("Schindler's List", 1993),
  ('Unforgiven', 1992),
  ('The Silence of the Lambs', 1991),
  ('Dances with Wolves', 1990),
  ('Driving Miss Daisy', 1989),
  ('Rain Man', 1988),
  ('The Last Emperor', 1987),
  ('Platoon', 1986),
  ('Out of Africa', 1985),
  ('Amadeus', 1984),
  ('Terms of Endearment', 1983),
  ('Gandhi', 1982),
  ('Chariots of Fire', 1981),
  ('Ordinary People', 1980),
  ('Kramer vs. Kramer', 1979),
  ('The Deer Hunter', 1978),
  ('Annie Hall', 1977),
  ('Rocky', 1976),
  ("One Flew Over the Cuckoo's Nest", 1975),
  ('The Godfather Part II', 1974),
  ('The Sting', 1973),
  ('The Godfather', 1972),
];

// ---------------------------------------------------------------------- loading

Future<List<MediaItem>> loadTrend(TmdbApi api, TrendDef d) async {
  switch (d.kind) {
    case TrendKind.category:
      return api.collect((p) => api.category(d.type, d.query!, page: p), d.limit);
    case TrendKind.discover:
      return api.collect((p) => api.discover(d.type, d.params, page: p), d.limit);
    case TrendKind.person:
    case TrendKind.director:
      final person = await api.searchPerson(d.query!);
      if (person == null) return const [];
      return api.personTop((person['id'] as num).toInt(), d.type,
          d.kind == TrendKind.director ? 'director' : 'cast', d.limit);
    case TrendKind.keyword:
      final id = await api.searchKeywordId(d.query!);
      if (id == null) return const [];
      final params = {
        'with_keywords': '$id',
        'sort_by': 'vote_average.desc',
        'vote_count.gte': d.type == MediaType.movie ? '300' : '50',
        ...d.params,
      };
      return api.collect((p) => api.discover(d.type, params, page: p), d.limit);
    case TrendKind.oscars:
      final out = <MediaItem>[];
      for (int i = 0; i < kOscarBestPicture.length; i += 10) {
        final chunk = kOscarBestPicture.skip(i).take(10);
        final found = await Future.wait(
          chunk.map((e) => api.findMovie(e.$1, e.$2).catchError((_) => null)),
        );
        out.addAll(found.whereType<MediaItem>());
      }
      return out;
  }
}

// ---------------------------------------------------------------------- custom lists

const _noisePhrases = ['en iyi', 'les meilleurs', 'die besten', 'los mejores', 'las mejores'];
const _noiseWords = {
  'best', 'top', 'filmleri', 'filmler', 'filmi', 'film', 'movies', 'movie', 'films',
  'dizileri', 'diziler', 'dizisi', 'dizi', 'series', 'shows', 'show', 'tv', 'meilleurs',
  'beste', 'besten', 'mejores', 'películas', 'peliculas', 'serien', 'séries',
  'أفضل', 'أفلام', 'مسلسلات',
};

/// Removes "top 10", "best … movies" etc. Keeps the original casing.
String _clean(String q) {
  var s = q.replaceAll(RegExp(r'[0-9]+'), ' ');
  for (final p in _noisePhrases) {
    s = s.replaceAll(RegExp('(^|\\s)$p(?=\\s|\$)', caseSensitive: false), ' ');
  }
  final words = s
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_noiseWords.contains(w.toLowerCase()))
      .toList();
  return words.join(' ').trim();
}

/// Turns free text ("Jason Statham", "aksiyon", "zombie") into a list definition.
Future<TrendDef?> resolveCustomTrend(TmdbApi api, String input, int n, MediaType type) async {
  final q = _clean(input);
  if (q.isEmpty) return null;
  final ql = q.toLowerCase();

  // 1) genre, in any supported language
  for (final g in kGenres) {
    final names = S.allTranslations('genre_${g.key}').map((e) => e.toLowerCase()).toSet()..add(g.key);
    if (names.contains(ql)) {
      final id = g.idFor(type);
      if (id == null) continue;
      return TrendDef(
        id: 'custom_g_${g.key}',
        kind: TrendKind.discover,
        type: type,
        limit: n,
        titleKey: type == MediaType.movie ? 'trend_genre_movies' : 'trend_genre_tv',
        args: {'genre': g.key},
        params: _topGenre(id, type: type),
      );
    }
  }

  // 2) person (actor / director)
  final person = await api.searchPerson(q);
  if (person != null && ((person['popularity'] as num?) ?? 0) >= 1) {
    final name = (person['name'] as String?) ?? q;
    final isDirector = person['known_for_department'] == 'Directing';
    return TrendDef(
      id: 'custom_p_${person['id']}',
      kind: isDirector ? TrendKind.director : TrendKind.person,
      type: type,
      limit: n,
      query: name,
      titleKey: isDirector
          ? 'trend_director'
          : (type == MediaType.movie ? 'trend_person_movies' : 'trend_person_tv'),
      args: {'name': name},
    );
  }

  // 3) keyword / topic
  final kw = await api.searchKeywordId(q);
  if (kw != null) {
    return TrendDef(
      id: 'custom_k_$ql',
      kind: TrendKind.keyword,
      type: type,
      limit: n,
      query: q,
      titleKey: 'trend_kw_custom',
      args: {'name': input.trim()},
    );
  }
  return null;
}
