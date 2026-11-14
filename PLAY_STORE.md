# Film Advisor – Google Play Yayın Rehberi (Maximasoft)

Sürüm 1.2.1 · Paket adı: `com.maximasoft.filmadvisor` · Kasım 2026 kurallarına göre hazırlandı.

---

## A. Bir kerelik hazırlık (yaklaşık 10 dakika)

### 1) İmza anahtarını GitHub'a ekle
`imza/` klasöründeki bilgileri repoya **Settings → Secrets and variables → Actions → New repository secret** ile ekle:

| Secret adı | Değer |
|---|---|
| `KEYSTORE_BASE64` | `KEYSTORE_BASE64.txt` dosyasının **tüm içeriği** (tek satır) |
| `KEYSTORE_PASSWORD` | `sifreler.txt` içindeki değer |
| `KEY_PASSWORD` | `sifreler.txt` içindeki değer |
| `KEY_ALIAS` | `upload` |

> ⚠️ `upload-keystore.jks` dosyasını ve şifreleri **güvenli bir yere yedekle** (ör. şifre yöneticisi + harici disk). Bu anahtar olmadan güncelleme yükleyemezsin. Kaybedersen Play Console → Uygulama bütünlüğü → "Yükleme anahtarını sıfırla" ile yenisini isteyebilirsin. Anahtarı kimseyle paylaşma, repoya koyma.

### 2) Gizlilik politikasını yayına al (GitHub Pages)
Repo → **Settings → Pages** → Source: *Deploy from a branch* → Branch: `main`, klasör: `/docs` → **Save**.
Birkaç dakika sonra şu adres açılır:
**https://erhancppur-oss.github.io/film-advisor/privacy-policy.html**
(Uygulama içindeki gizlilik linki de bu adrese ayarlı.)

### 3) İmzalı derlemeyi al
Repo → **Actions → Build Android (APK + AAB) → Run workflow**.
Bitince **Releases** sayfasındaki son sürümde `app-release.aab` dosyası olur → Play'e yüklenecek dosya budur.
(Derleme kaydında "DEBUG key" uyarısı görünmemeli.)

---

## B. Play Console

### 1) Geliştirici hesabı
https://play.google.com/console → 25 USD tek seferlik ücret, kimlik doğrulama. Geliştirici adı: **Maximasoft**.

### 2) Uygulama oluştur
Uygulama adı: `Film Advisor` · Varsayılan dil: **English (United States) – en-US** · Uygulama · **Ücretsiz** · beyanları onayla.

### 3) Mağaza kaydı → Ana mağaza kaydı
Aşağıdaki metinleri kopyala. Türkçe için **Çeviri ekle → Türkçe (tr-TR)**.

**Grafikler**
- Uygulama simgesi: `store/play_icon_512.png`
- Öne çıkan grafik: `store/feature_graphic_1024x500.png`
- Telefon ekran görüntüleri: en az 2 (önerilen 4–8), telefonundan al: Öneri ekranı (6 seçenek), kaydırma kartları, Trendler/Liste oluşturucu, film detayı.

> ⚠️ Ekran görüntülerinde film afişleri stüdyolara aittir; Play bazen telif gerekçesiyle reddediyor. Afişin az göründüğü ekranları (Öneri seçenekleri, Liste oluşturucu, Ayarlar/Hakkında) öne çıkar; afişli ekranlarda mümkünse eski kamu malı filmler (Nosferatu 1922, Metropolis 1927) görünsün.

#### English (en-US)
**App name:** `Film Advisor: Movie & TV Picks`

**Short description:**
`Movie & TV picks by mood, swipe to discover, build top-10 lists. No sign-up.`

**Full description:**
```
What should you watch tonight? Film Advisor finds movies and series you'll love – in seconds.

🎯 6 WAYS TO GET RECOMMENDATIONS
• Pick for me – we choose by the time of day and your taste
• Based on my profile – from what you liked, watched or want to watch
• Choose manually – genre, era, runtime, rating, language, platforms (remember your answers!)
• Find similar – pick a title, get the closest movies & series
• Match my mood – laugh, thrill, cry, adrenaline, mind-blown…
• On my platforms – popular titles on your streaming services

👆 SWIPE TO DISCOVER
Swipe right to save, left to skip. Soft background music changes with every card and matches the genre.

🏆 TRENDS & TOP LISTS – NO TYPING
• Build your own list: genre + year + actor + director + country, top 10/20/50/100
• Top 100 of all time, best of every year, Oscar Best Picture winners
• Top 10 by genre, actor, director, decade and country

🎬 ALL THE DETAILS
Synopsis, cast, trailer, ratings, similar titles and where to stream in your country.

📋 YOUR LISTS STAY ON YOUR PHONE
Watchlist and watched list. No account, no ads, no tracking.

🌍 English, Türkçe, Deutsch, Français, Español, العربية · dark & light theme.

Movie and TV data provided by The Movie Database (TMDB). This product uses the TMDB API but is not endorsed or certified by TMDB. Streaming data by JustWatch.
```

#### Türkçe (tr-TR)
**Uygulama adı:** `Film Advisor: Film & Dizi Öner`

**Kısa açıklama:**
`Moduna göre film ve dizi önerisi, kaydırarak keşif, en iyi 10 listeleri.`

**Tam açıklama:**
```
Bu akşam ne izlesen? Film Advisor sevebileceğin film ve dizileri saniyeler içinde bulur.

🎯 ÖNERİ ALMANIN 6 YOLU
• Benim için sen seç – günün saatine ve zevkine göre biz seçelim
• Profilime göre – beğendiğin, izlediğin ve izleyeceklerinden
• Manuel seçim – tür, dönem, süre, puan, dil, platform (cevaplarını hatırlar!)
• Benzerini seç – bir yapım seç, en yakın film ve dizileri getirelim
• Moduma göre – gülmek, gerilmek, duygulanmak, adrenalin…
• Platformlarımda ne var? – abone olduğun platformlardaki popüler yapımlar

👆 KAYDIRARAK KEŞFET
Beğendiğini sağa kaydır, geçmek için sola. Türe uygun hafif arka plan müziği her kartta değişir.

🏆 TRENDLER VE EN İYİ LİSTELERİ – YAZMADAN
• Kendi listeni oluştur: tür + yıl + oyuncu + yönetmen + ülke, ilk 10/20/50/100
• Tüm zamanların en iyi 100'ü, her yılın en iyileri, Oscar'lı filmler
• Türe, oyuncuya, yönetmene, on yıla ve ülkeye göre en iyi 10'lar

🎬 TÜM DETAYLAR
Özet, oyuncular, fragman, puanlar, benzer yapımlar ve Türkiye'de hangi platformda izlenebileceği.

📋 LİSTELERİN TELEFONUNDA KALIR
İzlenecekler ve izlediklerim. Üyelik yok, reklam yok, takip yok.

🌍 Türkçe, English, Deutsch, Français, Español, العربية · koyu ve açık tema.

Film ve dizi verileri The Movie Database (TMDB) tarafından sağlanır. This product uses the TMDB API but is not endorsed or certified by TMDB. Platform verisi: JustWatch.
```

**Kategori:** Eğlence (Entertainment) · **Etiketler:** Film, Dizi, Öneriler
**İletişim:** e‑posta adresin (zorunlu, mağazada görünür) · **Web sitesi:** isteğe bağlı
**Gizlilik politikası:** https://erhancppur-oss.github.io/film-advisor/privacy-policy.html

### 4) Uygulama içeriği (sol menü → Politika → Uygulama içeriği)

| Bölüm | Cevap |
|---|---|
| Gizlilik politikası | Yukarıdaki URL |
| Reklamlar | **Hayır, reklam içermiyor** |
| Uygulama erişimi | **Tüm işlevler kısıtlama olmadan kullanılabilir** (giriş yok) |
| İçerik derecelendirmesi | Anket: kategori **"Diğer tüm uygulama türleri"**. Şiddet/korku sorularında: uygulama film afişleri ve özetleri gösterdiği için **"hafif/ima eden"** seçenekleri. Kullanıcı etkileşimi: Hayır · Konum paylaşımı: Hayır · Dijital satın alma: Hayır · Kumar: Hayır. Beklenen sonuç ~PEGI 12 / Teen |
| Hedef kitle | **13–15, 16–17, 18+** (13 yaş altını seçme) · Çocukların ilgisini çekebilir mi: **Hayır** |
| Haber uygulaması | Hayır |
| Sağlık / Finans / Devlet | Hayır |
| Veri güvenliği | Aşağıdaki tablo |

**Veri güvenliği formu:**
- Veri topluyor veya paylaşıyor musunuz? → **Evet**
  - **Uygulama etkinliği → Uygulama içi arama geçmişi**: Toplanıyor ✔ · Paylaşılmıyor · **Geçici olarak işleniyor (ephemeral): Evet** · **Zorunlu** · Amaç: **Uygulama işlevselliği**
- Aktarımda şifreleniyor mu? → **Evet**
- Kullanıcılar veri silinmesini isteyebilir mi? → **Evet** (veriler cihazda; Ayarlar'dan silinebilir)
- Hesap oluşturma → **Yok**

(Neden: arama terimleri TMDB'ye gönderiliyor. Cihazda kalan listeler "toplanan veri" sayılmaz.)

### 5) Kapalı test – ZORUNLU (yeni kişisel hesaplar)
1. **Test → Kapalı test → Kanal oluştur** → `app-release.aab` yükle → sürüm notu: "İlk sürüm".
2. **Test kullanıcıları**: e‑posta listesi oluştur, **en az 12 (öneri: 15–20)** Gmail adresi ekle.
3. Katılım linkini paylaş; herkes linkten katılıp uygulamayı Play'den yüklesin.
4. **14 gün kesintisiz** en az 12 kişi testte kalsın.
5. 14 gün sonra **Kontrol paneli → Üretim erişimine başvur** formunu doldur (testte neler denendiği, geri bildirimler, yapılan düzeltmeler).

### 6) Üretim (yayın)
Onay gelince **Üretim → Yeni sürüm oluştur** → aynı veya daha yeni `.aab` → Ülkeler: Tüm ülkeler (veya seçtiklerin) → **İncelemeye gönder**. İnceleme genelde 1–7 gün sürer.

> Play App Signing varsayılan olarak açık; ilk yüklemede onayla.

---

## C. Güncelleme yaparken
1. Kodu değiştir → `main`'e gönder → derleme kendiliğinden çalışır (versionCode her derlemede otomatik artar).
2. Görünen sürüm adı için `pubspec.yaml` içindeki `version:` satırını artır (ör. `1.2.2+1`).
3. Releases'tan yeni `.aab` → Play Console → yeni sürüm.

## D. Kurallara uygunluk özeti
- Hedef API 36 (Android 16) ✔ · AAB ✔ · 16 KB sayfa boyutu ✔ · Sadece İnternet izni ✔
- Reklam/analitik/takip yok ✔ · Hesap yok (hesap silme şartı yok) ✔ · Yetişkin içerik filtreli ✔
- TMDB atfı ve JustWatch atfı uygulamada (Ayarlar → Hakkında) ✔
- Müzik cihazda üretiliyor, telifli ses yok ✔
- **TMDB notu:** API ticari olmayan kullanımda ücretsiz. Reklam veya ücretli özellik eklersen TMDB ticari lisansı gerekir.
