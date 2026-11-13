# Film Advisor 🎬

Film ve dizi keşif + öneri uygulaması (Flutter, Android). Veriler ücretsiz **TMDB API**'den gelir. Türkçe / İngilizce arayüz.

> This product uses the TMDB API but is not endorsed or certified by TMDB.

## Özellikler

* **Keşfet**: Filmler / Diziler sekmeleri, otomatik dönen büyük afiş karuseli, sağa‑sola kaydırılan satırlar (gündem, vizyonda, popüler, en iyiler, yakında, Türk film/dizileri, Kore dizileri, anime, komedi, bilim kurgu, korku, belgesel). "Tümü" ile sonsuz kaydırmalı ızgara. Aşağı çekip yenileme.
* **Öneri sihirbazı (8 adım)**: film/dizi → ruh hali → türler (dahil et ✓ / hariç tut ✕) → dönem → süre → popülerlik & min. puan & çocuk modu → orijinal dil → platformlar (Netflix, Prime, Disney+… bölgeye göre canlı liste). Az sonuç çıkarsa kriterleri otomatik esnetir.
* **Tinder tarzı kaydırma**: sağa = izleme listesine ekle, sola = geç (bir daha önerilmez), dokun = detay. Kart / ızgara görünümü.
* **Hızlı keşif** ve **"Şansıma ne çıkarsa"** (rastgele kaliteli yapım).
* **Sana özel** satırı: listendeki yapımlara göre TMDB önerileri.
* **Detay sayfası**: özet (Türkçesi yoksa İngilizceye düşer), tür, süre, yaş sınırı, puan, oyuncular, yönetmen, fragman (YouTube), TMDB/IMDb linki, **nereden izlenir** (JustWatch verisi; abonelik/kirala/satın al), benzer yapımlar, "ilgilenmiyorum".
* **Arama**: film+dizi birlikte, son aramalar, gündemdekiler.
* **Listelerim**: İzlenecekler / İzlediklerim (sadece cihazda).
* **Ayarlar**: dil (sistem/TR/EN), tema (sistem/koyu/açık), platform ülkesi (TR varsayılan), verileri sil, gizlilik politikası, hakkında & TMDB/JustWatch atıfları, açık kaynak lisansları.
* İlk açılışta dil seçimli karşılama ekranı. Reklam yok, hesap yok, takip yok.

## Proje yapısı

```
lib/
  main.dart               uygulama, tema, dil
  config.dart             --dart-define ile gelen ayarlar
  l10n/strings.dart       TR/EN metinler
  models/                 MediaItem, detay, öneri kriterleri → TMDB discover parametreleri
  services/tmdb_api.dart  TMDB istemcisi (önbellek, hata türleri)
  state/                  ayarlar ve listeler (SharedPreferences)
  screens/                keşfet, öneri, sonuçlar, detay, arama, listeler, ayarlar
  widgets/                karusel, satırlar, kaydırma destesi
tool/prepare_android.py   android/ klasörünü oluşturur + Play ayarları (targetSdk 36, imzalama, izinler)
.github/workflows/        bulutta APK + AAB derleme
docs/privacy-policy.html  gizlilik politikası (GitHub Pages)
store/                    Play Store simgesi ve öne çıkan grafik
PLAY_STORE.md             mağaza metinleri, form cevapları, yayın kontrol listesi
```

## 1) TMDB API anahtarı al (ücretsiz)

1. https://www.themoviedb.org/signup ile hesap aç.
2. Ayarlar → **API** → "Developer" (ticari olmayan) başvurusu. Uygulama açıklamasına "Free, ad‑free movie recommendation app for Android" yaz.
3. **API Key** (32 karakter) ya da **API Read Access Token** (eyJ… ile başlar) — ikisi de çalışır.

## 2a) En kolay yol: GitHub ile bulutta derle (bilgisayara bir şey kurmadan)

1. GitHub'da yeni (tercihen **private**) repo aç, bu klasörün içeriğini yükle.
2. Repo → **Settings → Secrets and variables → Actions**:
   * **Secrets**: `TMDB_API_KEY`
   * **Variables**: `APP_ID` (örn. `com.adsoyad.filmadvisor`), `PRIVACY_URL`, `CONTACT_EMAIL`
3. **Actions** sekmesi → "Build Android (APK + AAB)" → *Run workflow*. ~10 dk sonra artifact olarak `app-release.apk` (telefona kurup dene) ve `app-release.aab` (Play'e yüklenecek) iner.

### Gizlilik politikasını yayınla (GitHub Pages)
`docs/privacy-policy.html` içindeki `[DEVELOPER NAME]` ve `[CONTACT EMAIL]` alanlarını doldur. Repo → Settings → Pages → *Deploy from branch* → `main` / `/docs`. URL: `https://KULLANICIADI.github.io/REPO/privacy-policy.html` → bunu `PRIVACY_URL` değişkenine yaz. (Pages için repo public olmalı ya da politikayı ayrı public bir repoda/Google Sites'ta yayınla.)

### Play için imzalama anahtarı (upload key)
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w 0 upload-keystore.jks > keystore.b64      # macOS: base64 -i upload-keystore.jks
```
Secrets: `KEYSTORE_BASE64` (keystore.b64 içeriği), `KEYSTORE_PASSWORD`, `KEY_ALIAS` (=upload), `KEY_PASSWORD`.
**.jks dosyasını ve şifreleri güvenli yerde yedekle, repoya koyma.** Bu secretlar yoksa derleme debug anahtarıyla imzalanır (test için olur, Play kabul etmez).

## 2b) Kendi bilgisayarında derle

Gerekenler: Flutter (stable, ≥ 3.29), Android Studio (SDK 36), JDK 17.

```bash
python3 tool/prepare_android.py --app-id com.adsoyad.filmadvisor   # android/ oluşturur ve ayarlar
flutter pub get
dart run flutter_launcher_icons
flutter run --dart-define=TMDB_API_KEY=ANAHTARIN
# yayın:
flutter build appbundle --release --dart-define=TMDB_API_KEY=ANAHTARIN --dart-define=PRIVACY_URL=https://...
```
İmzalama için `android/key.properties`:
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/tam/yol/upload-keystore.jks
```

## 3) Play Store'a yükle
Tüm adımlar, mağaza metinleri (TR/EN), veri güvenliği/içerik derecelendirmesi cevapları ve **12 test kullanıcısı / 14 gün** kuralı: **[PLAY_STORE.md](PLAY_STORE.md)**

## Notlar
* API anahtarı APK içine gömülür; TMDB bu kullanıma izin verir, ama anahtarı public repoya yazma (secret kullan).
* TMDB yalnızca **ticari olmayan** kullanımda ücretsizdir. Reklam / satın alma eklersen TMDB ticari lisansı gerekir.
* Resmi TMDB logosunu `assets/tmdb_logo.png` olarak ekle (https://www.themoviedb.org/about/logos-attribution).
