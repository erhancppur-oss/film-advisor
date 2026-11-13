import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/settings_state.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = context.watch<SettingsState>();
    final cs = Theme.of(context).colorScheme;
    final current = st.languageCode;

    Widget langButton(AppLanguage l) {
      final selected = current == l.code;
      return Material(
        color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => st.setLanguage(l.code),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(l.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(l.nativeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(children: [
            const SizedBox(height: 24),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/icon/icon.png',
                    width: 112,
                    height: 112,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.movie_filter_rounded, size: 112, color: cs.primary)),
              ),
            ),
            const SizedBox(height: 28),
            Text(s.t('onb_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(s.t('app_tagline'),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Text(s.t('onb_body'),
                textAlign: TextAlign.center, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 36),
            Text(s.t('onb_choose_lang'),
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [for (final l in kAppLanguages) langButton(l)],
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => st.setLanguage(current).then((_) => st.completeOnboarding()),
              child: Text(s.t('onb_start'), style: const TextStyle(fontSize: 16)),
            ),
          ]),
        ),
      ),
    );
  }
}
