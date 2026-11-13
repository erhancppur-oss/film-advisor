import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regions offered for streaming availability & theatrical lists.
const List<String> kRegions = [
  'TR', 'US', 'GB', 'DE', 'FR', 'NL', 'ES', 'IT', 'AZ', 'CA', 'AU', 'AT', 'BE', 'CH', 'SE',
];

class SettingsState extends ChangeNotifier {
  SettingsState(this._prefs) {
    _languageCode = _prefs.getString('language'); // null = system
    _themeMode = ThemeMode.values[(_prefs.getInt('theme') ?? 0).clamp(0, 2)];
    _region = _prefs.getString('region');
    _onboarded = _prefs.getBool('onboarded') ?? false;
  }

  final SharedPreferences _prefs;

  String? _languageCode;
  ThemeMode _themeMode = ThemeMode.system;
  String? _region;
  bool _onboarded = false;

  /// Bottom navigation index (kept here so it survives a locale change rebuild).
  int tabIndex = 0;

  void goToTab(int i) {
    if (tabIndex == i) return;
    tabIndex = i;
    notifyListeners();
  }

  /// App language; English unless the user picked another one.
  String get languageCode => _languageCode ?? 'en';
  Locale get locale => Locale(languageCode);
  ThemeMode get themeMode => _themeMode;
  bool get onboarded => _onboarded;

  /// Region: explicit choice, otherwise derived from device locale, default TR.
  String regionFor(Locale deviceLocale) {
    if (_region != null) return _region!;
    final cc = deviceLocale.countryCode?.toUpperCase();
    if (cc != null && kRegions.contains(cc)) return cc;
    return deviceLocale.languageCode == 'tr' ? 'TR' : (cc ?? 'US');
  }

  String? get explicitRegion => _region;

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    await _prefs.setString('language', code);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await _prefs.setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> setRegion(String? r) async {
    _region = r;
    if (r == null) {
      await _prefs.remove('region');
    } else {
      await _prefs.setString('region', r);
    }
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboarded = true;
    await _prefs.setBool('onboarded', true);
    notifyListeners();
  }
}
