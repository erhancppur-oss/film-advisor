/// Build-time configuration.
///
/// Values are injected with --dart-define so that no secret is committed
/// to the repository:
///   flutter build apk --dart-define=TMDB_API_KEY=xxxx --dart-define=PRIVACY_URL=https://...
class AppConfig {
  AppConfig._();

  /// TMDB v3 API key (32 hex chars) OR v4 "API Read Access Token" (starts with eyJ...).
  static const String tmdbApiKey = String.fromEnvironment('TMDB_API_KEY');

  /// Public URL of the privacy policy (required by Google Play).
  static const String _privacyUrlDefine = String.fromEnvironment('PRIVACY_URL');
  static String get privacyPolicyUrl => _privacyUrlDefine.trim();
  static bool get hasPrivacyUrl => privacyPolicyUrl.startsWith('http');

  /// Contact e-mail shown in About (fill with --dart-define=CONTACT_EMAIL=...).
  static const String contactEmail = String.fromEnvironment('CONTACT_EMAIL');

  static const String appName = 'Film Advisor';
  static const String appVersion = '1.0.0';

  static const String imageBase = 'https://image.tmdb.org/t/p/';

  static bool get hasApiKey => tmdbApiKey.trim().isNotEmpty;

  static String? poster(String? path, {String size = 'w342'}) =>
      (path == null || path.isEmpty) ? null : '$imageBase$size$path';

  static String? backdrop(String? path, {String size = 'w780'}) =>
      (path == null || path.isEmpty) ? null : '$imageBase$size$path';

  static String? profile(String? path) =>
      (path == null || path.isEmpty) ? null : '${imageBase}w185$path';

  static String? logo(String? path) =>
      (path == null || path.isEmpty) ? null : '${imageBase}w92$path';
}
