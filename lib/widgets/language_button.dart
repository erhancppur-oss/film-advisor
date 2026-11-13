import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/settings_state.dart';

/// Flag button that opens the language picker.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  static Future<void> pick(BuildContext context) async {
    final st = context.read<SettingsState>();
    final s = S.of(context);
    final code = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(s.t('set_language'), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final l in kAppLanguages)
            ListTile(
              leading: Text(l.flag, style: const TextStyle(fontSize: 26)),
              title: Text(l.nativeName),
              trailing: l.code == st.languageCode
                  ? Icon(Icons.check_rounded, color: Theme.of(ctx).colorScheme.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, l.code),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (code != null) await st.setLanguage(code);
  }

  @override
  Widget build(BuildContext context) {
    final code = context.watch<SettingsState>().languageCode;
    final lang = kAppLanguages.firstWhere((l) => l.code == code, orElse: () => kAppLanguages.first);
    return IconButton(
      tooltip: S.of(context).t('set_language'),
      onPressed: () => pick(context),
      icon: Text(lang.flag, style: const TextStyle(fontSize: 22)),
    );
  }
}
