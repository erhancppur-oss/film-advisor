import 'package:film_advisor/models/advisor.dart';
import 'package:film_advisor/models/media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advisor builds discover params for movies', () {
    final c = AdvisorCriteria(
      content: ContentChoice.movie,
      moodKey: 'laugh',
      era: Era.y90s,
      runtime: RuntimePref.short,
      minRating: 7,
      fame: Fame.acclaimed,
      language: 'tr',
      providers: {8, 337},
    );
    final p = c.toDiscoverParams(MediaType.movie, 'TR');
    expect(p['with_genres'], '35');
    expect(p['without_genres'], '27');
    expect(p['primary_release_date.gte'], '1990-01-01');
    expect(p['primary_release_date.lte'], '1999-12-31');
    expect(p['with_runtime.lte'], '95');
    expect(p['vote_average.gte'], '7.0');
    expect(p['with_original_language'], 'tr');
    expect(p['watch_region'], 'TR');
    expect(p['with_watch_providers'], '8|337');
    expect(p['include_adult'], 'false');
  });

  test('genre include/exclude maps to tv ids', () {
    final c = AdvisorCriteria(
      content: ContentChoice.tv,
      includeGenres: {'scifi', 'horror'},
      excludeGenres: {'animation'},
    );
    final p = c.toDiscoverParams(MediaType.tv, 'TR');
    expect(p['with_genres'], '10765'); // horror has no tv id
    expect(p['without_genres'], '16');
    expect(p.containsKey('first_air_date.lte'), isTrue);
  });

  test('media item parsing', () {
    final m = MediaItem.tryParse({
      'id': 603,
      'media_type': 'movie',
      'title': 'The Matrix',
      'vote_average': 8,
      'release_date': '1999-03-31',
    });
    expect(m, isNotNull);
    expect(m!.year, '1999');
    expect(m.voteAverage, 8.0);
    expect(MediaItem.tryParse({'id': 1, 'media_type': 'person'}), isNull);
  });
}
