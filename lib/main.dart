import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'l10n/strings.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/tmdb_api.dart';
import 'state/advisor_prefs.dart';
import 'state/library_state.dart';
import 'state/settings_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(
      providers: [
        Provider<TmdbApi>(create: (_) => TmdbApi()),
        ChangeNotifierProvider<SettingsState>(create: (_) => SettingsState(prefs)),
        ChangeNotifierProvider<LibraryState>(create: (_) => LibraryState(prefs)),
        ChangeNotifierProvider<AdvisorPrefs>(create: (_) => AdvisorPrefs(prefs)),
      ],
      child: const FilmAdvisorApp(),
    ),
  );
}

const _seed = Color(0xFF7C5CFF);

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: b,
    surface: b == Brightness.dark ? const Color(0xFF0E0F1A) : null,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class FilmAdvisorApp extends StatelessWidget {
  const FilmAdvisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsState>();
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: st.themeMode,
      locale: st.locale,
      supportedLocales: [for (final l in kAppLanguages) Locale(l.code)],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Root(),
    );
  }
}

/// Configures the API for the active language/region and rebuilds the whole
/// UI (fresh data) whenever one of them changes.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<SettingsState>();
    final lang = S.of(context).lang;
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final region = st.regionFor(deviceLocale);
    context.read<TmdbApi>().configure(languageCode: lang, region: region);

    if (!st.onboarded) return const OnboardingScreen();
    return HomeShell(key: ValueKey('home_${lang}_$region'));
  }
}
