import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config.dart';
import '../l10n/strings.dart';
import 'detail_screen.dart' show openUrl;

/// "About & credits" – opens by sliding up from the bottom; its sections rise in one after another.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static Route<void> route() => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, __, ___) => const AboutScreen(),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
            child: child,
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final small = TextStyle(fontSize: 12.5, height: 1.5, color: cs.onSurfaceVariant);

    var i = 0;
    Widget r(Widget w) => _Reveal(delay: Duration(milliseconds: 260 + 90 * i++), child: w);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: s.t('close'),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(s.t('about')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          // ---- identity
          r(Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/icon/icon.png',
                    width: 108,
                    height: 108,
                    errorBuilder: (_, __, ___) => const Icon(Icons.movie_creation_outlined, size: 108)),
              ),
            ),
          )),
          const SizedBox(height: 18),
          r(Column(children: [
            Text(AppConfig.appName,
                textAlign: TextAlign.center,
                style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(s.t('app_tagline'), textAlign: TextAlign.center, style: small),
            const SizedBox(height: 10),
            const _VersionPill(),
          ])),
          const SizedBox(height: 28),
          // ---- developer
          r(Column(children: [
            Row(children: [
              Expanded(child: Divider(color: cs.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(s.t('developed_by_label'),
                    style: TextStyle(fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w600, color: cs.outline)),
              ),
              Expanded(child: Divider(color: cs.outlineVariant)),
            ]),
            const SizedBox(height: 10),
            Text(AppConfig.developer.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 7, height: 1.1)),
            const SizedBox(height: 6),
            Text(s.t('developed_by', {'dev': AppConfig.developer}), textAlign: TextAlign.center, style: small),
          ])),
          const SizedBox(height: 28),
          // ---- about
          r(_Section(
            icon: Icons.info_outline_rounded,
            title: s.t('about_section'),
            child: Text(s.t('about_body'), style: small),
          )),
          // ---- highlights
          r(_Section(
            icon: Icons.auto_awesome_outlined,
            title: s.t('about_highlights'),
            child: Column(children: [
              for (final h in const [
                (Icons.tune_rounded, 'about_h1'),
                (Icons.format_list_numbered_rounded, 'about_h2'),
                (Icons.graphic_eq_rounded, 'about_h3'),
                (Icons.translate_rounded, 'about_h4'),
                (Icons.lock_outline_rounded, 'about_h5'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(h.$1, size: 18, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.t(h.$2), style: small)),
                  ]),
                ),
            ]),
          )),
          // ---- data sources
          r(_Section(
            icon: Icons.dataset_outlined,
            title: s.t('about_data'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset(
                'assets/tmdb_logo.png',
                height: 18,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF0D253F), borderRadius: BorderRadius.circular(5)),
                  child: const Text('TMDB',
                      style: TextStyle(color: Color(0xFF01B4E4), fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 8),
              Text(s.t('tmdb_notice'), style: small.copyWith(fontWeight: FontWeight.w600)),
              Text(s.t('tmdb_data'), style: small),
              const SizedBox(height: 6),
              Text(s.t('justwatch_notice'), style: small),
              Wrap(spacing: 4, children: [
                TextButton(
                  onPressed: () => openUrl(context, 'https://www.themoviedb.org/'),
                  child: const Text('themoviedb.org', style: TextStyle(fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => openUrl(context, 'https://www.justwatch.com/'),
                  child: const Text('justwatch.com', style: TextStyle(fontSize: 12)),
                ),
              ]),
            ]),
          )),
          // ---- legal
          r(_Section(
            icon: Icons.gavel_rounded,
            title: s.t('about_legal'),
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Column(children: [
              if (AppConfig.hasPrivacyUrl)
                _LinkTile(
                  icon: Icons.privacy_tip_outlined,
                  label: s.t('privacy'),
                  onTap: () => openUrl(context, AppConfig.privacyPolicyUrl),
                ),
              _LinkTile(
                icon: Icons.description_outlined,
                label: s.t('licenses'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: AppConfig.appName,
                  applicationVersion: AppConfig.appVersion,
                  applicationLegalese: '© ${DateTime.now().year} ${AppConfig.developer}',
                ),
              ),
              if (AppConfig.contactEmail.isNotEmpty)
                _LinkTile(
                  icon: Icons.mail_outline_rounded,
                  label: '${s.t('contact')} · ${AppConfig.contactEmail}',
                  onTap: () => openUrl(context, 'mailto:${AppConfig.contactEmail}'),
                ),
            ]),
          )),
          const SizedBox(height: 18),
          r(Text('© ${DateTime.now().year} ${AppConfig.developer} · ${s.t('rights')}',
              textAlign: TextAlign.center, style: small.copyWith(fontSize: 11.5, color: cs.outline))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child, this.padding});
  final IconData icon;
  final String title;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            Icon(icon, size: 18, color: cs.onSurface),
            const SizedBox(width: 10),
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w800)),
          ]),
        ),
        Padding(padding: padding ?? const EdgeInsets.fromLTRB(16, 4, 16, 16), child: child),
      ]),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final v = snap.data?.version ?? AppConfig.appVersion;
        final b = snap.data?.buildNumber ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            b.isEmpty ? s.t('version', {'v': v}) : s.t('version_build', {'v': v, 'b': b}),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
          ),
        );
      },
    );
  }
}

/// Fades a child in while it rises from below.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.delay, required this.child});
  final Duration delay;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (_, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, 40 * (1 - _a.value)), child: child),
      ),
    );
  }
}
