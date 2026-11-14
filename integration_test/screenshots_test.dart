// Captures real store screenshots on an Android emulator (see .github/workflows/screenshots.yml).
import 'dart:io';

import 'package:film_advisor/l10n/strings.dart';
import 'package:film_advisor/main.dart' as app;
import 'package:film_advisor/models/advisor.dart';
import 'package:film_advisor/models/media.dart';
import 'package:film_advisor/models/trends.dart';
import 'package:film_advisor/screens/advisor_screen.dart';
import 'package:film_advisor/screens/detail_screen.dart';
import 'package:film_advisor/screens/home_shell.dart';
import 'package:film_advisor/screens/trends_screen.dart';
import 'package:film_advisor/services/tmdb_api.dart';
import 'package:film_advisor/state/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const lang = String.fromEnvironment('SHOT_LANG', defaultValue: 'en');

Future<void> wait(WidgetTester t, int ms) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setString('language', lang);
    await prefs.setString('region', lang == 'tr' ? 'TR' : 'US');
    await prefs.setBool('onboarded', true);
    await prefs.setBool('music_on', true);
    await prefs.setInt('theme', ThemeMode.dark.index);

    app.main();
    await wait(tester, 9000);
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pump();
    }
    var n = 0;
    Future<void> shot(String name, {int settle = 0}) async {
      if (settle > 0) await wait(tester, settle);
      n++;
      await binding.takeScreenshot('${lang}_${n.toString().padLeft(2, '0')}_$name');
    }

    final s = S(lang);
    BuildContext ctx() => tester.element(find.byType(HomeShell));
    NavigatorState nav() => tester.state<NavigatorState>(find.byType(Navigator).first);
    final api = ctx().read<TmdbApi>();

    // 1 Discover
    await shot('discover');

    // 2 Advisor hub
    ctx().read<SettingsState>().goToTab(2);
    await shot('advisor', settle: 1500);

    // 3 Swipe deck (mood: adrenaline)
    nav().push(MaterialPageRoute(builder: (_) => const MoodAdvisorScreen()));
    await wait(tester, 1500);
    await tester.tap(find.text(s.t('mood_adrenaline')).last);
    await shot('swipe', settle: 9000);
    nav().popUntil((r) => r.isFirst);
    await wait(tester, 800);

    // 4 Trends / list builder
    ctx().read<SettingsState>().goToTab(1);
    await shot('trends', settle: 5000);

    // 5 Detail of a trending movie
    final trending = await api.trending(MediaType.movie);
    final pick = trending.items.firstWhere((m) => m.backdropPath != null && m.overview.isNotEmpty,
        orElse: () => trending.items.first);
    nav().push(MaterialPageRoute(builder: (_) => DetailScreen(item: pick)));
    await shot('detail', settle: 8000);
    nav().popUntil((r) => r.isFirst);
    await wait(tester, 800);

    // 6 Top 100 of all time
    nav().push(MaterialPageRoute(builder: (_) => RankedListScreen.fromDef(buildTrendSections().first.items.first)));
    await shot('top100', settle: 9000);
    nav().popUntil((r) => r.isFirst);
    await wait(tester, 800);

    // 7 Actor list
    nav().push(MaterialPageRoute(
        builder: (_) => RankedListScreen.fromFilter(ListFilter(actor: const PersonPick('Brad Pitt')))));
    await shot('actor', settle: 9000);
    nav().popUntil((r) => r.isFirst);
    await wait(tester, 800);

    // 8 Manual advisor wizard (genres step)
    nav().push(MaterialPageRoute(builder: (_) => const ManualAdvisorScreen(askAll: true)));
    await wait(tester, 1500);
    await tester.tap(find.text(s.t('content_movie')).last);
    await wait(tester, 1200);
    await tester.tap(find.text(s.t('mood_${kMoods[0].key}')).last);
    await shot('manual', settle: 1500);
  });
}
