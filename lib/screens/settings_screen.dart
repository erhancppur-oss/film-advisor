import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../services/tmdb_api.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import 'detail_screen.dart' show openUrl;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<SettingsState>();
    final currentRegion = context.read<TmdbApi>().region;

    String langLabel() {
      switch (st.languageCode) {
        case 'tr':
          return 'Türkçe';
        case 'en':
          return 'English';
        default:
          return s.t('set_lang_system');
      }
    }

    String themeLabel() {
      switch (st.themeMode) {
        case ThemeMode.dark:
          return s.t('theme_dark');
        case ThemeMode.light:
          return s.t('theme_light');
        case ThemeMode.system:
          return s.t('theme_system');
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings'))),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.language_rounded),
          title: Text(s.t('set_language')),
          subtitle: Text(langLabel()),
          onTap: () => _pick<String?>(
            context,
            title: s.t('set_language'),
            current: st.languageCode,
            options: {null: s.t('set_lang_system'), 'tr': 'Türkçe', 'en': 'English'},
            onSelected: st.setLanguage,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: Text(s.t('set_theme')),
          subtitle: Text(themeLabel()),
          onTap: () => _pick<ThemeMode>(
            context,
            title: s.t('set_theme'),
            current: st.themeMode,
            options: {
              ThemeMode.system: s.t('theme_system'),
              ThemeMode.dark: s.t('theme_dark'),
              ThemeMode.light: s.t('theme_light'),
            },
            onSelected: st.setThemeMode,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.public_rounded),
          title: Text(s.t('set_region')),
          subtitle: Text(st.explicitRegion ?? s.t('region_auto', {'r': currentRegion})),
          onTap: () => _pick<String?>(
            context,
            title: s.t('set_region'),
            current: st.explicitRegion,
            options: {
              null: s.t('region_auto', {'r': currentRegion}),
              for (final r in kRegions) r: r,
            },
            onSelected: st.setRegion,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: Text(s.t('clear_data')),
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                content: Text(s.t('clear_data_confirm')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false), child: Text(s.t('cancel'))),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true), child: Text(s.t('ok'))),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await context.read<LibraryState>().clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(s.t('cleared'))));
              }
            }
          },
        ),
        const Divider(),
        if (AppConfig.hasPrivacyUrl)
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(s.t('privacy')),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => openUrl(context, AppConfig.privacyPolicyUrl),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: Text(s.t('about')),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AboutScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(s.t('licenses')),
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppConfig.appName,
            applicationVersion: AppConfig.appVersion,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(s.t('version', {'v': AppConfig.appVersion}),
              style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required T current,
    required Map<T, String> options,
    required Future<void> Function(T) onSelected,
  }) async {
    final result = await showModalBottomSheet<_Choice<T>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final e in options.entries)
              ListTile(
                title: Text(e.value),
                trailing: e.key == current
                    ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, _Choice<T>(e.key)),
              ),
          ]),
        ),
      ),
    );
    if (result != null) await onSelected(result.value);
  }
}

class _Choice<T> {
  final T value;
  const _Choice(this.value);
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('about'))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset('assets/icon/icon.png',
                width: 64,
                height: 64,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.movie_filter_rounded, size: 64)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppConfig.appName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(s.t('version', {'v': AppConfig.appVersion}), style: TextStyle(color: cs.outline)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Text(s.t('about_body'), style: const TextStyle(height: 1.45)),
        const SizedBox(height: 28),
        // ---- TMDB attribution (required by TMDB API terms)
        Center(
          child: Image.asset(
            'assets/tmdb_logo.png',
            height: 40,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D253F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('TMDB',
                  style: TextStyle(
                      color: Color(0xFF01B4E4), fontWeight: FontWeight.w900, fontSize: 22)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(s.t('tmdb_notice'),
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(s.t('tmdb_data'), textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
        Center(
          child: TextButton(
            onPressed: () => openUrl(context, 'https://www.themoviedb.org/'),
            child: const Text('www.themoviedb.org'),
          ),
        ),
        const SizedBox(height: 16),
        Text(s.t('justwatch_notice'), textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
        Center(
          child: TextButton(
            onPressed: () => openUrl(context, 'https://www.justwatch.com/'),
            child: const Text('www.justwatch.com'),
          ),
        ),
        const SizedBox(height: 16),
        if (AppConfig.contactEmail.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.mail_outline_rounded),
            title: Text(s.t('contact')),
            subtitle: Text(AppConfig.contactEmail),
            onTap: () => openUrl(context, 'mailto:${AppConfig.contactEmail}'),
          ),
        if (AppConfig.hasPrivacyUrl)
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(s.t('privacy')),
            onTap: () => openUrl(context, AppConfig.privacyPolicyUrl),
          ),
      ]),
    );
  }
}
