import 'dart:math' as math;

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
}
