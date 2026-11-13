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
    final current = Localizations.localeOf(context).languageCode;

    Widget langButton(String code, String label, String flag) {
      final selected = current == code;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Material(
            color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => st.setLanguage(code),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2),
                ),
                child: Column(children: [
                  Text(flag, style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
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
            const Spacer(),
            Text(s.t('onb_choose_lang'),
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(children: [
              langButton('tr', 'Türkçe', '🇹🇷'),
              langButton('en', 'English', '🇬🇧'),
            ]),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () {
                if (st.languageCode == null) st.setLanguage(current == 'tr' ? 'tr' : 'en');
                st.completeOnboarding();
              },
              child: Text(s.t('onb_start'), style: const TextStyle(fontSize: 16)),
            ),
          ]),
        ),
      ),
    );
  }
}
