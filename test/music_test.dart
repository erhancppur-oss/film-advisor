import 'dart:math' as math;

import 'package:film_advisor/music/music_service.dart';
import 'package:film_advisor/music/synth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every music theme renders valid, distinct loops', () {
    for (final theme in kMusicThemes) {
      final hashes = <int>{};
      for (final idx in const [0, 17, 35]) {
        final sw = Stopwatch()..start();
        final x = renderTrack(theme, idx);
        sw.stop();
        double peak = 0, sum = 0;
        int h = 0;
        for (int i = 0; i < x.length; i++) {
          final v = x[i];
          expect(v.isFinite, isTrue);
          peak = math.max(peak, v.abs());
          sum += v * v;
          if (i % 997 == 0) h = (h * 31 + (v * 1000).round()) & 0x7fffffff;
        }
        final rms = math.sqrt(sum / x.length);
        final sec = x.length / kSampleRate;
        // ignore: avoid_print
        print('MUSIC $theme#$idx  ${sec.toStringAsFixed(1)}s  peak=${peak.toStringAsFixed(2)} '
            'rms=${rms.toStringAsFixed(3)}  render=${sw.elapsedMilliseconds}ms');
        expect(sec, inInclusiveRange(15, 55));
        expect(rms, greaterThan(0.02));
        hashes.add(h);
      }
      expect(hashes.length, 3, reason: '$theme tracks should differ');
    }
    final wav = encodeWav(renderTrack('comedy', 3));
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
  });

  test('genre to music mapping', () {
    expect(themeForGenres([27, 53]), 'horror'); // horror thriller
    expect(themeForGenres([35, 27]), 'horror'); // horror comedy
    expect(themeForGenres([16, 35, 10751]), 'playful'); // animated comedy
    expect(themeForGenres([28, 35]), 'action'); // action comedy
    expect(themeForGenres([35, 28]), 'comedy'); // comedy first
    expect(themeForGenres([35, 10749]), 'romance'); // rom-com
    expect(themeForGenres([18, 10749]), 'romance');
    expect(themeForGenres([18, 36]), 'drama'); // historical drama
    expect(themeForGenres([36, 10752, 18]), 'epic');
    expect(themeForGenres([12, 14, 10751]), 'epic'); // fantasy adventure (Harry Potter)
    expect(themeForGenres([878, 28, 12]), 'scifi');
    expect(themeForGenres([28, 878]), 'action');
    expect(themeForGenres([80, 18]), 'suspense'); // crime drama
    expect(themeForGenres([53]), 'suspense');
    expect(themeForGenres([9648, 80]), 'suspense');
    expect(themeForGenres([99]), 'documentary');
    expect(themeForGenres([37]), 'western');
    expect(themeForGenres([10402, 18]), 'upbeat');
    expect(themeForGenres([10765, 10759]), 'scifi'); // TV sci-fi & fantasy
    expect(themeForGenres([10759, 18]), 'action'); // TV action
    expect(themeForGenres([10768]), 'epic');
    expect(themeForGenres([]), 'ambient');
  });
}
