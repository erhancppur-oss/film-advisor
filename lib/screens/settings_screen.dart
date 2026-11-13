import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../l10n/strings.dart';
import '../services/tmdb_api.dart';
import '../state/advisor_prefs.dart';
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

    final lang = kAppLanguages.firstWhere((l) => l.code == st.languageCode,
        orElse: () => kAppLanguages.first);

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
          leading: Text(lang.flag, style: const TextStyle(fontSize: 22)),
          title: Text(s.t('set_language')),
          subtitle: Text(lang.nativeName),
          onTap: () => _pick<String>(
            context,
            title: s.t('set_language'),
            current: st.languageCode,
            options: {for (final l in kAppLanguages) l.code: '${l.flag}  ${l.nativeName}'},
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
        const _RememberedPrefs(),
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
        const Center(child: _VersionText(small: true)),
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

class _VersionText extends StatelessWidget {
  const _VersionText({this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = snap.data?.version ?? AppConfig.appVersion;
        final b = snap.data?.buildNumber ?? '';
        return Text(
          b.isEmpty ? s.t('version', {'v': v}) : s.t('version_build', {'v': v, 'b': b}),
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: small ? 12 : 14,
            fontWeight: small ? FontWeight.normal : FontWeight.w600,
          ),
        );
      },
    );
  }
}

/// Remembered answers of the manual advisor; deletable one by one.
class _RememberedPrefs extends StatelessWidget {
  const _RememberedPrefs();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final prefs = context.watch<AdvisorPrefs>();
    final steps = prefs.savedSteps;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        leading: const Icon(Icons.bookmark_added_outlined),
        title: Text(s.t('set_advisor_prefs')),
        subtitle: steps.isEmpty ? Text(s.t('no_saved_prefs')) : null,
        trailing: steps.isEmpty
            ? null
            : TextButton(onPressed: prefs.clear, child: Text(s.t('delete_all'))),
      ),
      for (final st in steps)
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 56, right: 8),
          title: Text(s.t(stepQuestionKey(st)), style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(prefs.summary(st, s), maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: s.t('remove'),
            icon: Icon(Icons.delete_outline_rounded, color: cs.error),
            onPressed: () => prefs.remove(st),
          ),
        ),
    ]);
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final small = TextStyle(fontSize: 12, color: cs.outline, height: 1.4);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('about'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/icon/icon.png',
                width: 96,
                height: 96,
                errorBuilder: (_, __, ___) => const Icon(Icons.movie_filter_rounded, size: 96)),
          ),
        ),
        const SizedBox(height: 14),
        Text(AppConfig.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Center(child: _VersionText()),
        const SizedBox(height: 22),
        // ---- developer credit (large)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C5CFF), Color(0xFFFF5CA8)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            s.t('developed_by', {'dev': AppConfig.developer}),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(s.t('about_body'), textAlign: TextAlign.center, style: small),
        const SizedBox(height: 18),
        // ---- TMDB attribution (required by TMDB API terms) – small
        Center(
          child: Image.asset(
            'assets/tmdb_logo.png',
            height: 22,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0D253F),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('TMDB',
                  style: TextStyle(
                      color: Color(0xFF01B4E4), fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(s.t('tmdb_notice'), textAlign: TextAlign.center, style: small),
        Text(s.t('tmdb_data'), textAlign: TextAlign.center, style: small),
        Text(s.t('justwatch_notice'), textAlign: TextAlign.center, style: small),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, children: [
          TextButton(
            onPressed: () => openUrl(context, 'https://www.themoviedb.org/'),
            child: const Text('themoviedb.org', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => openUrl(context, 'https://www.justwatch.com/'),
            child: const Text('justwatch.com', style: TextStyle(fontSize: 12)),
          ),
        ]),
        if (AppConfig.contactEmail.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.mail_outline_rounded, size: 20),
            title: Text(s.t('contact'), style: const TextStyle(fontSize: 13)),
            subtitle: Text(AppConfig.contactEmail, style: const TextStyle(fontSize: 12)),
            onTap: () => openUrl(context, 'mailto:${AppConfig.contactEmail}'),
          ),
        if (AppConfig.hasPrivacyUrl)
          ListTile(
            dense: true,
            leading: const Icon(Icons.privacy_tip_outlined, size: 20),
            title: Text(s.t('privacy'), style: const TextStyle(fontSize: 13)),
            onTap: () => openUrl(context, AppConfig.privacyPolicyUrl),
          ),
        const SizedBox(height: 8),
        Text('© ${DateTime.now().year} ${AppConfig.developer}',
            textAlign: TextAlign.center, style: small),
      ]),
    );
  }
}
