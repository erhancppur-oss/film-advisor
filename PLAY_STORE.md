# Google Play'de Yayınlama Rehberi – Film Advisor

Bu dosya; mağaza metinlerini, Play Console formlarına verilecek cevapları ve yayın kontrol listesini içerir. (Kurallar Kasım 2026 itibarıyla kontrol edilmiştir; Play Console'daki güncel uyarıları her zaman esas al.)

---

## 1. Uygulamada zaten karşılanan teknik kurallar

| Kural | Durum |
|---|---|
| Yeni uygulamalar **Android 16 (API 36)** hedeflemeli (31 Ağustos 2026'dan beri) | `tool/prepare_android.py` `targetSdk = maxOf(36, …)` ayarlıyor |
| Yükleme formatı **AAB** (Android App Bundle) | CI `app-release.aab` üretiyor |
| 16 KB sayfa boyutu uyumu | Güncel Flutter stable ile otomatik (CI hep son stable'ı kullanır) |
| Gereksiz izin yok | Sadece `INTERNET` izni var |
| Gizlilik politikası | `docs/privacy-policy.html` (TR + EN) + uygulama içinde link |
| Reklam / takip / analytics SDK yok | Data safety formu basit |
| Hesap yok → hesap silme zorunluluğu yok | ✔ |
| Yetişkin içerik yok | Tüm TMDB isteklerinde `include_adult=false` |
| TMDB atıf şartı | Ayarlar → Hakkında: TMDB logosu + "This product uses the TMDB API but is not endorsed or certified by TMDB." |
| JustWatch atfı | Detay sayfasında ve Hakkında'da |
| Kenardan kenara (edge‑to‑edge), tahmini geri hareketi, büyük ekran | Flutter yönetiyor; ekran yönü kilitlenmedi (API 36'da büyük ekranlarda kilit yok sayılıyor) |

## 2. Hesap ve test şartı (ÖNEMLİ)

* Play Console geliştirici hesabı: tek seferlik 25 USD + kimlik doğrulama.
* **13 Kasım 2023'ten sonra açılmış kişisel hesaplarda**, üretime (herkese açık) çıkmadan önce **en az 12 test kullanıcısıyla, kesintisiz 14 gün kapalı test** zorunlu. Test kullanıcısı sayısı 14 gün boyunca 12'nin altına düşmesin; 15–20 kişiyle başla.
  * Play Console → Test → **Kapalı test** → yeni kanal → AAB yükle → test kullanıcılarının Gmail adreslerini ekle → katılım linkini paylaş.
  * 14 gün sonra "Üretim erişimi için başvur" formunu doldur (testte ne öğrendiğini, ne düzelttiğini anlat).
* Şirket (organizasyon) hesabıysa bu şart yok ama D‑U‑N‑S numarası gerekir.

## 3. TMDB lisans notu

* TMDB API'si **ticari olmayan** kullanım için ücretsiz. Uygulamayı **ücretsiz ve reklamsız** dağıttığın sürece bu kapsamdasın.
* İleride **reklam, uygulama içi satın alma veya abonelik** eklersen bu ticari kullanım sayılır ve TMDB ile ayrı ticari lisans anlaşması gerekir.
* TMDB logosunu uygulama logosundan daha az belirgin kullan, onay/ortaklık ima etme. Resmi logoyu https://www.themoviedb.org/about/logos-attribution adresinden indirip `assets/tmdb_logo.png` olarak koy (dosya yoksa uygulama metin rozeti gösterir).

## 4. Mağaza kaydı metinleri

### Türkçe (tr-TR)

**Uygulama adı (≤30):** `Film Advisor: Film & Dizi Öner`

**Kısa açıklama (≤80):**
`Ruh haline göre film ve dizi önerisi al, kaydırarak keşfet, izleme listeni tut.`

**Tam açıklama:**
```
Bu akşam ne izlesen? Film Advisor birkaç soruyla zevkine uygun film ve dizileri bulur.

🎯 KİŞİSEL ÖNERİ SİHİRBAZI
• Film mi dizi mi, ruh halin (gülmek, gerilmek, duygulanmak…), türler
• Dönem, süre, minimum puan, "gizli hazineler" ya da "eleştirmen beğenisi"
• Orijinal dil (Türk yapımları, Kore dizileri, anime…)
• Sahip olduğun platformlar ve çocuklarla izleme modu

👆 KAYDIRARAK KEŞFET
• Beğendiğini sağa kaydır, izleme listene eklensin; geçmek için sola
• "Şansıma ne çıkarsa" ile rastgele kaliteli bir yapım

🎬 HER ŞEY TEK YERDE
• Gündemdekiler, vizyondakiler, yakında çıkacaklar, Türk film ve dizileri
• Özet, oyuncular, fragman, puanlar, benzer yapımlar
• Türkiye'de hangi platformda izlenebileceği (JustWatch verisi)

📋 LİSTELERİN SENDE
• İzlenecekler ve izlediklerin listesi
• Üyelik yok, reklam yok; verilerin sadece telefonunda saklanır

🌍 Türkçe ve İngilizce arayüz, koyu/açık tema.

Film ve dizi verileri The Movie Database (TMDB) tarafından sağlanır. This product uses the TMDB API but is not endorsed or certified by TMDB.
```

### English (en-US)

**App name:** `Film Advisor: Movie & TV Picks`

**Short description:**
`Get movie & TV picks for your mood, swipe to discover and keep a watchlist.`

**Full description:**
```
What should you watch tonight? Film Advisor finds movies and shows that match your taste with a few quick questions.

🎯 PERSONAL ADVISOR
• Movie or series, your mood (laugh, thrill, cry…), genres
• Era, runtime, minimum rating, "hidden gems" or "critically acclaimed"
• Original language (Turkish, Korean dramas, anime…)
• The streaming services you have, plus a family-friendly mode

👆 SWIPE TO DISCOVER
• Swipe right to add to your watchlist, left to skip
• "Surprise me" picks a great random title

🎬 EVERYTHING IN ONE PLACE
• Trending, in theaters, coming soon, top rated
• Synopsis, cast, trailer, ratings, similar titles
• Where to stream in your country (data by JustWatch)

📋 YOUR LISTS, YOUR DEVICE
• Watchlist and watched list
• No sign-up, no ads; your data stays on your phone

🌍 English and Turkish interface, dark/light theme.

Movie and TV data provided by The Movie Database (TMDB). This product uses the TMDB API but is not endorsed or certified by TMDB.
```

**Kategori:** Eğlence (Entertainment) · **Etiketler:** Film, Dizi, Öneri
**İletişim e‑postası:** zorunlu (Play Console'da görünür).
**Gizlilik politikası URL'si:** GitHub Pages linkin (README'de anlatılıyor).

### Grafikler
* `store/play_icon_512.png` – 512×512 uygulama simgesi ✔
* `store/feature_graphic_1024x500.png` – öne çıkan grafik ✔
* **Ekran görüntüleri:** telefon için en az 2 (önerilen 4–8), 1080×1920 gibi 9:16.

> ⚠️ **Ekran görüntülerinde telif riski:** Film afişleri stüdyolara aittir. Play, mağaza görsellerinde başkasına ait eserlerin izinsiz kullanımını reddedebiliyor (TMDB kullanan bazı uygulamalar bu yüzden reddedildi). Güvenli yol: Ekran görüntülerinde **öneri sihirbazı, ayarlar, liste** gibi afişin az olduğu ekranları öne çıkar; afiş görünen ekranlarda **kamu malı filmler** (ör. *Nosferatu* 1922, *Metropolis* 1927, *Night of the Living Dead* 1968) seç. Açıklamada "Netflix", "IMDb" gibi markaları anahtar kelime olarak doldurma.

## 5. Play Console form cevapları

### Uygulama içeriği → Gizlilik politikası
GitHub Pages URL'si.

### Reklamlar
**Hayır, uygulamamda reklam yok.**

### Uygulama erişimi
**Tüm işlevler özel erişim gerektirmeden kullanılabilir.** (Giriş yok.)

### İçerik derecelendirmesi (IARC anketi)
* Kategori: oyun değil → **"Diğer tüm uygulama türleri"** seçeneği.
* Şiddet/korku: Uygulama kendisi şiddet üretmez ama **film afişleri ve özetleri** korku/şiddet ima edebilir → ilgili sorulara dürüstçe "evet, hafif/ima" cevabı ver.
* Kullanıcı etkileşimi / sohbet: **Hayır** · Konum paylaşımı: **Hayır** · Dijital satın alma: **Hayır** · Kumar: **Hayır**.
* Beklenen sonuç ~PEGI 12 / ESRB Teen. Dürüst cevap ver; yanlış beyan uygulamanın kaldırılmasına yol açar.

### Hedef kitle ve içerik
* Hedef yaş grupları: **13–15, 16–17, 18+** (13 yaş altı **seçme** → "Aileler" politikası ve ek şartlar devreye girer).
* "Uygulama çocukların ilgisini çekebilir mi?" → **Hayır** (genel film/dizi rehberi).

### Veri güvenliği (Data safety)
Uygulama sunucuna veri göndermiyor; ancak arama terimleri ve IP adresi TMDB API'sine gidiyor. **Güvenli (muhafazakâr) cevap:**

* Veri toplanıyor mu? **Evet**
  * **Uygulama etkinliği → Uygulama içi arama geçmişi**: Toplanıyor · Paylaşılmıyor* · **Geçici olarak işleniyor (ephemeral): Evet** · Zorunlu · Amaç: **Uygulama işlevselliği**
* Aktarım sırasında şifreleniyor mu? **Evet** (HTTPS)
* Kullanıcı verilerin silinmesini isteyebilir mi? Veriler sunucuda tutulmuyor; cihazdaki veriler Ayarlar'dan silinebilir → "Evet / uygulama içinden" seçebilirsin.
* Hesap oluşturma: **Yok**

\* Kullanıcının kendi başlattığı arama ile istenen içeriğin üçüncü taraftan getirilmesi Google'ın "kullanıcı tarafından başlatılan aktarım" istisnasına girer. Emin değilsen "Paylaşılıyor (TMDB, uygulama işlevi)" olarak işaretlemek de kabul edilebilir; fazla beyan, eksik beyandan daha güvenlidir.

Cihazda tutulan izleme listesi/ayarlar "toplanan veri" **sayılmaz** (cihazdan çıkmıyor).

### Diğer beyanlar
Haber uygulaması: Hayır · Sağlık: Hayır · Finans: Hayır · Devlet uygulaması: Hayır · COVID: Hayır.

## 6. Yayın adımları (özet)

1. README'deki gibi TMDB anahtarı + GitHub Secrets ayarla, upload keystore oluştur.
2. GitHub Actions'tan **imzalı** `app-release.aab` indir.
3. Play Console → Uygulama oluştur (Ücretsiz) → Mağaza kaydı → Uygulama içeriği formları.
4. **Play App Signing**'i kabul et (varsayılan). Upload anahtarını kaybetme (kaybedersen Play'den sıfırlama talep edilebilir).
5. Kapalı test kanalına AAB yükle → 12+ test kullanıcısı → 14 gün.
6. Üretim erişimi başvurusu → onay → Üretim sürümü oluştur → incelemeye gönder (genelde birkaç gün).
7. Her güncellemede `pubspec.yaml` içindeki `version` adını artır (versionCode'u CI otomatik artırır).

## 7. Yayın öncesi kontrol listesi

- [ ] `docs/privacy-policy.html` içindeki [DEVELOPER NAME] ve [CONTACT EMAIL] dolduruldu, GitHub Pages yayında
- [ ] `PRIVACY_URL`, `CONTACT_EMAIL`, `APP_ID` GitHub değişkenleri girildi
- [ ] `assets/tmdb_logo.png` resmi TMDB logosu eklendi
- [ ] Uygulama kimliği (`APP_ID`) benzersiz, örn. `com.adsoyad.filmadvisor` — **yayından sonra değiştirilemez**
- [ ] Release AAB upload keystore ile imzalı (CI'da "DEBUG key" uyarısı yok)
- [ ] Gerçek cihazda: Türkçe/İngilizce, internet yokken hata ekranı, fragman/IMDb linkleri, kaydırma
- [ ] Ekran görüntüleri telif açısından kontrol edildi
- [ ] İçerik derecelendirmesi, hedef kitle, veri güvenliği, reklam formları dolduruldu
