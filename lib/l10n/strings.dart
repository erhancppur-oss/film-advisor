import 'package:flutter/widgets.dart';

/// Minimal bilingual (Turkish / English) string table.
///
/// Usage: `final s = S.of(context); Text(s.t('home_title'))`
class S {
  final String lang;
  const S(this.lang);

  static S of(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    return S(code == 'tr' ? 'tr' : 'en');
  }

  bool get isTr => lang == 'tr';

  String t(String key, [Map<String, String>? args]) {
    var v = _strings[lang]?[key] ?? _strings['en']![key] ?? key;
    if (args != null) {
      args.forEach((k, val) => v = v.replaceAll('{$k}', val));
    }
    return v;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': _en,
    'tr': _tr,
  };

  static const Map<String, String> _en = {
    // general
    'app_tagline': 'What should I watch tonight?',
    'retry': 'Try again',
    'see_all': 'See all',
    'movie': 'Movie',
    'tv': 'TV show',
    'movies': 'Movies',
    'series': 'TV Shows',
    'cancel': 'Cancel',
    'ok': 'OK',
    'close': 'Close',
    'remove': 'Remove',
    'loading': 'Loading…',
    'no_results': 'Nothing found',
    'min': 'min',
    'unknown': 'Unknown',

    // nav
    'nav_discover': 'Discover',
    'nav_advisor': 'Advisor',
    'nav_search': 'Search',
    'nav_library': 'My Lists',
    'nav_settings': 'Settings',

    // errors
    'err_network': 'No connection. Check your internet and try again.',
    'err_missing_key':
        'TMDB API key is missing. Build the app with --dart-define=TMDB_API_KEY=… (see README).',
    'err_invalid_key': 'The TMDB API key is invalid.',
    'err_rate': 'Too many requests. Please wait a moment.',
    'err_not_found': 'Not found.',
    'err_generic': 'Something went wrong.',

    // onboarding
    'onb_title': 'Welcome to Film Advisor',
    'onb_body':
        'Swipe through trending movies and shows, answer a few questions and get personal recommendations. No sign-up needed – your lists stay on your phone.',
    'onb_choose_lang': 'Choose your language',
    'onb_start': 'Let\'s start',

    // discover
    'sec_trending': 'Trending this week',
    'sec_for_you': 'Recommended for you',
    'sec_now_playing': 'In theaters',
    'sec_popular': 'Popular',
    'sec_top_rated': 'Top rated of all time',
    'sec_upcoming': 'Coming soon',
    'sec_turkish_movies': 'Turkish movies',
    'sec_turkish_series': 'Turkish series',
    'sec_korean': 'Korean dramas',
    'sec_anime': 'Anime',
    'sec_on_air': 'On the air',
    'sec_comedy': 'Comedy picks',
    'sec_scifi': 'Sci‑fi & fantasy',
    'sec_horror': 'Horror nights',
    'sec_docs': 'Documentaries',
    'quick_swipe': 'Quick swipe',
    'surprise_me': 'Surprise me',
    'surprise_loading': 'Rolling the dice…',

    // swipe
    'swipe_hint': 'Swipe right to add to your watchlist, left to skip. Tap for details.',
    'swipe_like': 'WANT',
    'swipe_nope': 'SKIP',
    'swipe_empty': 'You\'ve seen them all!',
    'swipe_more': 'Load more',
    'added_watchlist': 'Added to your watchlist',
    'view_list': 'List view',
    'view_cards': 'Card view',

    // advisor
    'adv_title': 'Find something to watch',
    'adv_intro': 'Answer a few quick questions. You can skip any of them.',
    'adv_start': 'Start',
    'adv_next': 'Next',
    'adv_back': 'Back',
    'adv_skip': 'Doesn\'t matter',
    'adv_show': 'Show recommendations',
    'adv_reset': 'Reset',
    'adv_step': 'Step {n} of {total}',
    'q_content': 'What are you in the mood for?',
    'q_mood': 'How do you want to feel?',
    'q_genres': 'Any specific genres?',
    'q_genres_hint': 'Tap once to include (✓), twice to exclude (✕).',
    'q_era': 'From which era?',
    'q_runtime': 'How much time do you have?',
    'q_quality': 'Rating & popularity',
    'q_language': 'Original language',
    'q_platform': 'Which platforms do you have?',
    'q_platform_hint': 'Only titles available on the selected services in {region}. Leave empty for all.',
    'q_kids': 'Watching with kids',
    'q_kids_hint': 'Family friendly titles only',
    'min_rating': 'Minimum rating: {r}',
    'any_rating': 'Any rating',
    'content_movie': 'A movie',
    'content_tv': 'A series',
    'content_any': 'Either',
    'era_any': 'Any time',
    'era_recent': 'Brand new (last 2 years)',
    'era_y2010s': '2010s',
    'era_y2000s': '2000s',
    'era_y90s': '90s',
    'era_classic': 'Classics (before 1990)',
    'rt_any': 'Doesn\'t matter',
    'rt_short': 'Short',
    'rt_short_d': 'Under 1.5 h / ~30 min episodes',
    'rt_medium': 'Normal',
    'rt_medium_d': '1.5 – 2 h / 30–55 min episodes',
    'rt_long': 'Long',
    'rt_long_d': 'Over 2 h / long episodes',
    'fame_popular': 'Crowd pleasers',
    'fame_popular_d': 'What everyone is watching',
    'fame_acclaimed': 'Critically acclaimed',
    'fame_acclaimed_d': 'Highest rated with many votes',
    'fame_hidden': 'Hidden gems',
    'fame_hidden_d': 'Great but lesser‑known',
    'results_title': 'Your picks',
    'results_relaxed': 'Few exact matches, so we loosened some criteria.',
    'results_none': 'No match for these criteria. Try fewer filters.',
    'change_criteria': 'Change criteria',

    // moods
    'mood_laugh': 'Laugh',
    'mood_feelgood': 'Feel good',
    'mood_thrill': 'On the edge',
    'mood_scare': 'Scared',
    'mood_adrenaline': 'Adrenaline',
    'mood_mindbend': 'Mind‑blown',
    'mood_cry': 'Emotional',
    'mood_romance': 'In love',
    'mood_escape': 'Escape to another world',
    'mood_learn': 'Learn something',

    // genres
    'genre_action': 'Action',
    'genre_adventure': 'Adventure',
    'genre_animation': 'Animation',
    'genre_comedy': 'Comedy',
    'genre_crime': 'Crime',
    'genre_documentary': 'Documentary',
    'genre_drama': 'Drama',
    'genre_family': 'Family',
    'genre_fantasy': 'Fantasy',
    'genre_history': 'History',
    'genre_horror': 'Horror',
    'genre_music': 'Music',
    'genre_mystery': 'Mystery',
    'genre_romance': 'Romance',
    'genre_scifi': 'Science fiction',
    'genre_thriller': 'Thriller',
    'genre_war': 'War',
    'genre_western': 'Western',

    // languages
    'lang_any': 'Any',
    'lang_tr': 'Turkish',
    'lang_en': 'English',
    'lang_ko': 'Korean',
    'lang_ja': 'Japanese',
    'lang_es': 'Spanish',
    'lang_fr': 'French',
    'lang_hi': 'Hindi',
    'lang_de': 'German',
    'lang_it': 'Italian',

    // detail
    'overview': 'Overview',
    'no_overview': 'No overview available yet.',
    'cast': 'Cast',
    'director': 'Director',
    'creators': 'Created by',
    'trailer': 'Trailer',
    'watchlist_add': 'Watchlist',
    'watchlist_added': 'In watchlist',
    'mark_watched': 'Watched?',
    'watched': 'Watched',
    'where_to_watch': 'Where to watch',
    'where_none': 'No streaming info for {region}.',
    'wp_stream': 'Stream',
    'wp_free': 'Free',
    'wp_rent': 'Rent',
    'wp_buy': 'Buy',
    'justwatch': 'Streaming data by JustWatch',
    'more_like_this': 'More like this',
    'similar': 'Similar',
    'seasons': '{n} seasons',
    'episodes': '{n} episodes',
    'votes': '{n} votes',
    'open_tmdb': 'TMDB',
    'open_imdb': 'IMDb',
    'not_interested': 'Not interested',
    'not_interested_done': 'Got it, we won\'t suggest it again.',

    // search
    'search_hint': 'Movies, TV shows…',
    'recent_searches': 'Recent searches',
    'clear': 'Clear',
    'trending_now': 'Trending now',

    // library
    'tab_watchlist': 'To watch',
    'tab_watched': 'Watched',
    'empty_watchlist': 'Your watchlist is empty.\nSwipe right on titles you like or tap “Watchlist”.',
    'empty_watched': 'Titles you mark as watched appear here.',
    'go_advisor': 'Get recommendations',
    'move_watched': 'Mark as watched',
    'move_watchlist': 'Move to watchlist',
    'items_count': '{n} titles',

    // settings
    'settings': 'Settings',
    'set_language': 'Language',
    'set_lang_system': 'System default',
    'set_theme': 'Theme',
    'theme_system': 'System',
    'theme_dark': 'Dark',
    'theme_light': 'Light',
    'set_region': 'Country for streaming & theaters',
    'region_auto': 'Automatic ({r})',
    'set_data': 'Data',
    'clear_data': 'Clear my lists & history',
    'clear_data_confirm': 'This deletes your watchlist, watched list and search history from this device. Continue?',
    'cleared': 'Deleted.',
    'privacy': 'Privacy policy',
    'about': 'About & credits',
    'licenses': 'Open‑source licenses',
    'version': 'Version {v}',
    'about_body':
        'Film Advisor helps you discover movies and TV shows. It is free, has no ads and requires no account. Your lists are stored only on your device.',
    'tmdb_notice': 'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    'tmdb_data': 'Movie and TV data, images and ratings are provided by The Movie Database (TMDB).',
    'justwatch_notice': 'Streaming availability data is provided by JustWatch via TMDB.',
    'contact': 'Contact',
  };

  static const Map<String, String> _tr = {
    // general
    'app_tagline': 'Bu akşam ne izlesem?',
    'retry': 'Tekrar dene',
    'see_all': 'Tümü',
    'movie': 'Film',
    'tv': 'Dizi',
    'movies': 'Filmler',
    'series': 'Diziler',
    'cancel': 'Vazgeç',
    'ok': 'Tamam',
    'close': 'Kapat',
    'remove': 'Kaldır',
    'loading': 'Yükleniyor…',
    'no_results': 'Sonuç bulunamadı',
    'min': 'dk',
    'unknown': 'Bilinmiyor',

    // nav
    'nav_discover': 'Keşfet',
    'nav_advisor': 'Öneri',
    'nav_search': 'Ara',
    'nav_library': 'Listelerim',
    'nav_settings': 'Ayarlar',

    // errors
    'err_network': 'Bağlantı yok. İnternetini kontrol edip tekrar dene.',
    'err_missing_key':
        'TMDB API anahtarı eksik. Uygulamayı --dart-define=TMDB_API_KEY=… ile derle (README\'ye bak).',
    'err_invalid_key': 'TMDB API anahtarı geçersiz.',
    'err_rate': 'Çok fazla istek gönderildi. Biraz bekle.',
    'err_not_found': 'Bulunamadı.',
    'err_generic': 'Bir şeyler ters gitti.',

    // onboarding
    'onb_title': 'Film Advisor\'a hoş geldin',
    'onb_body':
        'Gündemdeki film ve dizileri kaydırarak keşfet, birkaç soruyu cevapla, sana özel öneriler al. Üyelik yok – listelerin sadece telefonunda saklanır.',
    'onb_choose_lang': 'Dil seç',
    'onb_start': 'Başlayalım',

    // discover
    'sec_trending': 'Bu hafta gündemde',
    'sec_for_you': 'Sana özel öneriler',
    'sec_now_playing': 'Vizyondakiler',
    'sec_popular': 'Popüler',
    'sec_top_rated': 'Tüm zamanların en iyileri',
    'sec_upcoming': 'Yakında',
    'sec_turkish_movies': 'Türk filmleri',
    'sec_turkish_series': 'Türk dizileri',
    'sec_korean': 'Kore dizileri',
    'sec_anime': 'Anime',
    'sec_on_air': 'Yayında olanlar',
    'sec_comedy': 'Komedi seçkisi',
    'sec_scifi': 'Bilim kurgu & fantastik',
    'sec_horror': 'Korku geceleri',
    'sec_docs': 'Belgeseller',
    'quick_swipe': 'Hızlı keşif',
    'surprise_me': 'Şansıma ne çıkarsa',
    'surprise_loading': 'Zar atılıyor…',

    // swipe
    'swipe_hint': 'Beğendiğini sağa kaydır (izleme listesine eklenir), geçmek için sola. Detay için dokun.',
    'swipe_like': 'İZLERİM',
    'swipe_nope': 'GEÇ',
    'swipe_empty': 'Hepsine baktın!',
    'swipe_more': 'Daha fazla yükle',
    'added_watchlist': 'İzleme listene eklendi',
    'view_list': 'Liste görünümü',
    'view_cards': 'Kart görünümü',

    // advisor
    'adv_title': 'Sana uygun yapımı bulalım',
    'adv_intro': 'Birkaç kısa soruyu cevapla. İstediğini atlayabilirsin.',
    'adv_start': 'Başla',
    'adv_next': 'İleri',
    'adv_back': 'Geri',
    'adv_skip': 'Fark etmez',
    'adv_show': 'Önerileri göster',
    'adv_reset': 'Sıfırla',
    'adv_step': 'Adım {n} / {total}',
    'q_content': 'Canın ne çekiyor?',
    'q_mood': 'Nasıl hissetmek istersin?',
    'q_genres': 'Belirli türler var mı?',
    'q_genres_hint': 'Bir kez dokun: dahil et (✓), iki kez: hariç tut (✕).',
    'q_era': 'Hangi dönemden olsun?',
    'q_runtime': 'Ne kadar vaktin var?',
    'q_quality': 'Puan ve popülerlik',
    'q_language': 'Orijinal dil',
    'q_platform': 'Hangi platformlar sende var?',
    'q_platform_hint': 'Sadece {region} bölgesinde seçili platformlarda olanlar. Boş bırakırsan hepsi.',
    'q_kids': 'Çocuklarla izleyeceğim',
    'q_kids_hint': 'Sadece aileye uygun yapımlar',
    'min_rating': 'En düşük puan: {r}',
    'any_rating': 'Puan fark etmez',
    'content_movie': 'Film',
    'content_tv': 'Dizi',
    'content_any': 'Fark etmez',
    'era_any': 'Fark etmez',
    'era_recent': 'Yepyeni (son 2 yıl)',
    'era_y2010s': '2010\'lar',
    'era_y2000s': '2000\'ler',
    'era_y90s': '90\'lar',
    'era_classic': 'Klasikler (1990 öncesi)',
    'rt_any': 'Fark etmez',
    'rt_short': 'Kısa',
    'rt_short_d': '1,5 saatten kısa / ~30 dk bölümler',
    'rt_medium': 'Normal',
    'rt_medium_d': '1,5 – 2 saat / 30–55 dk bölümler',
    'rt_long': 'Uzun',
    'rt_long_d': '2 saatten uzun / uzun bölümler',
    'fame_popular': 'Herkesin sevdikleri',
    'fame_popular_d': 'Şu an herkesin izledikleri',
    'fame_acclaimed': 'Eleştirmen beğenisi',
    'fame_acclaimed_d': 'Çok oy almış en yüksek puanlılar',
    'fame_hidden': 'Gizli hazineler',
    'fame_hidden_d': 'Harika ama az bilinenler',
    'results_title': 'Senin için seçtiklerimiz',
    'results_relaxed': 'Tam eşleşme az olduğu için bazı kriterleri esnettik.',
    'results_none': 'Bu kriterlere uyan yapım bulunamadı. Daha az filtre dene.',
    'change_criteria': 'Kriterleri değiştir',

    // moods
    'mood_laugh': 'Gülmek',
    'mood_feelgood': 'İçim ısınsın',
    'mood_thrill': 'Gerilmek',
    'mood_scare': 'Korkmak',
    'mood_adrenaline': 'Adrenalin',
    'mood_mindbend': 'Beynim yansın',
    'mood_cry': 'Duygulanmak',
    'mood_romance': 'Aşk',
    'mood_escape': 'Başka dünyalara kaçış',
    'mood_learn': 'Bir şey öğrenmek',

    // genres
    'genre_action': 'Aksiyon',
    'genre_adventure': 'Macera',
    'genre_animation': 'Animasyon',
    'genre_comedy': 'Komedi',
    'genre_crime': 'Suç',
    'genre_documentary': 'Belgesel',
    'genre_drama': 'Dram',
    'genre_family': 'Aile',
    'genre_fantasy': 'Fantastik',
    'genre_history': 'Tarih',
    'genre_horror': 'Korku',
    'genre_music': 'Müzik',
    'genre_mystery': 'Gizem',
    'genre_romance': 'Romantik',
    'genre_scifi': 'Bilim kurgu',
    'genre_thriller': 'Gerilim',
    'genre_war': 'Savaş',
    'genre_western': 'Western',

    // languages
    'lang_any': 'Fark etmez',
    'lang_tr': 'Türkçe',
    'lang_en': 'İngilizce',
    'lang_ko': 'Korece',
    'lang_ja': 'Japonca',
    'lang_es': 'İspanyolca',
    'lang_fr': 'Fransızca',
    'lang_hi': 'Hintçe',
    'lang_de': 'Almanca',
    'lang_it': 'İtalyanca',

    // detail
    'overview': 'Özet',
    'no_overview': 'Henüz özet bulunmuyor.',
    'cast': 'Oyuncular',
    'director': 'Yönetmen',
    'creators': 'Yaratıcılar',
    'trailer': 'Fragman',
    'watchlist_add': 'Listeme ekle',
    'watchlist_added': 'Listemde',
    'mark_watched': 'İzledin mi?',
    'watched': 'İzledim',
    'where_to_watch': 'Nereden izlenir',
    'where_none': '{region} için platform bilgisi yok.',
    'wp_stream': 'Abonelik',
    'wp_free': 'Ücretsiz',
    'wp_rent': 'Kirala',
    'wp_buy': 'Satın al',
    'justwatch': 'Platform verisi: JustWatch',
    'more_like_this': 'Bunu sevenler bunları da sevdi',
    'similar': 'Benzer yapımlar',
    'seasons': '{n} sezon',
    'episodes': '{n} bölüm',
    'votes': '{n} oy',
    'open_tmdb': 'TMDB',
    'open_imdb': 'IMDb',
    'not_interested': 'İlgilenmiyorum',
    'not_interested_done': 'Tamam, bunu bir daha önermeyeceğiz.',

    // search
    'search_hint': 'Film, dizi ara…',
    'recent_searches': 'Son aramalar',
    'clear': 'Temizle',
    'trending_now': 'Şu an gündemde',

    // library
    'tab_watchlist': 'İzlenecekler',
    'tab_watched': 'İzlediklerim',
    'empty_watchlist': 'İzleme listen boş.\nBeğendiğin yapımları sağa kaydır ya da “Listeme ekle”ye dokun.',
    'empty_watched': 'İzledim olarak işaretlediklerin burada görünür.',
    'go_advisor': 'Öneri al',
    'move_watched': 'İzledim olarak işaretle',
    'move_watchlist': 'İzleneceklere taşı',
    'items_count': '{n} yapım',

    // settings
    'settings': 'Ayarlar',
    'set_language': 'Dil',
    'set_lang_system': 'Sistem dili',
    'set_theme': 'Tema',
    'theme_system': 'Sistem',
    'theme_dark': 'Koyu',
    'theme_light': 'Açık',
    'set_region': 'Platform ve vizyon ülkesi',
    'region_auto': 'Otomatik ({r})',
    'set_data': 'Veriler',
    'clear_data': 'Listelerimi ve geçmişimi sil',
    'clear_data_confirm': 'İzleme listen, izlediklerin ve arama geçmişin bu cihazdan silinecek. Devam edilsin mi?',
    'cleared': 'Silindi.',
    'privacy': 'Gizlilik politikası',
    'about': 'Hakkında ve kaynaklar',
    'licenses': 'Açık kaynak lisansları',
    'version': 'Sürüm {v}',
    'about_body':
        'Film Advisor film ve dizi keşfetmene yardım eder. Ücretsizdir, reklam içermez ve hesap gerektirmez. Listelerin yalnızca cihazında saklanır.',
    'tmdb_notice': 'This product uses the TMDB API but is not endorsed or certified by TMDB.',
    'tmdb_data': 'Film ve dizi bilgileri, görseller ve puanlar The Movie Database (TMDB) tarafından sağlanır.',
    'justwatch_notice': 'Platform (yayın) bilgileri TMDB aracılığıyla JustWatch tarafından sağlanır.',
    'contact': 'İletişim',
  };

  static Set<String> get allKeysEn => _en.keys.toSet();
  static Set<String> get allKeysTr => _tr.keys.toSet();
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
