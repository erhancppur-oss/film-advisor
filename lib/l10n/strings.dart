import 'package:flutter/widgets.dart';

import 'lang_ar.dart';
import 'lang_de.dart';
import 'lang_en.dart';
import 'lang_es.dart';
import 'lang_fr.dart';
import 'lang_tr.dart';

class AppLanguage {
  final String code;
  final String nativeName;
  final String flag;
  const AppLanguage(this.code, this.nativeName, this.flag);
}

/// Supported UI languages. English is the default.
const List<AppLanguage> kAppLanguages = [
  AppLanguage('en', 'English', '🇬🇧'),
  AppLanguage('tr', 'Türkçe', '🇹🇷'),
  AppLanguage('de', 'Deutsch', '🇩🇪'),
  AppLanguage('fr', 'Français', '🇫🇷'),
  AppLanguage('es', 'Español', '🇪🇸'),
  AppLanguage('ar', 'العربية', '🇸🇦'),
];

const Map<String, Map<String, String>> _tables = {
  'en': stringsEn,
  'tr': stringsTr,
  'de': stringsDe,
  'fr': stringsFr,
  'es': stringsEs,
  'ar': stringsAr,
};

/// String lookup. Usage: `S.of(context).t('key', {'n': '3'})`
class S {
  final String lang;
  const S(this.lang);

  static S of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return S(_tables.containsKey(code) ? code : 'en');
  }

  String t(String key, [Map<String, String>? args]) {
    var v = _tables[lang]?[key] ?? stringsEn[key] ?? key;
    if (args != null) {
      args.forEach((k, val) => v = v.replaceAll('{$k}', val));
    }
    return v;
  }

  /// The value of [key] in every language (used to recognise genre names).
  static List<String> allTranslations(String key) =>
      _tables.values.map((m) => m[key]).whereType<String>().toList();
}

String apiErrorKey(Object error) {
  final s = error.toString();
  if (s.contains('missingKey')) return 'err_missing_key';
  if (s.contains('invalidKey')) return 'err_invalid_key';
  if (s.contains('network')) return 'err_network';
  if (s.contains('rateLimited')) return 'err_rate';
  if (s.contains('notFound')) return 'err_not_found';
  return 'err_generic';
}
