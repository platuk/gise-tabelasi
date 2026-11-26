# CupTower: App Store başvuru dosyası

App Store sayfasının neredeyse tamamı **otomatik** doldurulur: `.github/workflows/appstore.yml`
(GitHub > Actions > App Store > Run workflow ya da `appstore-N` etiketi).

| # | Ne | Nasıl | Kaynak |
|---|---|---|---|
| 1 | Ad **CupTower: Trophy Climb** / **CupTower: Kupa Kulesi** ("CupTower" başka bir hesapta kayıtlı; ana ekranda yine "CupTower"), alt başlık | API, otomatik (yapıldı) | `metadata.json` |
| 2 | Gizlilik politikası URL'si | API, otomatik | https://platuk.github.io/cuptower/privacy.html |
| 3 | Destek URL'si, pazarlama URL'si | API, otomatik | https://platuk.github.io/cuptower/support.html |
| 4 | Açıklama, anahtar kelimeler, tanıtım metni, telif | API, otomatik | `metadata.json` |
| 5 | Kategori: Oyunlar > Arcade, Aksiyon | API, otomatik | `metadata.json` |
| 6 | Yaş sınırı anketi (beklenen 9+) | API, otomatik | `metadata.json`, `age-rating.md` |
| 7 | App Review notu | API, otomatik | `review-notes.md` |
| 8 | Ekran görüntüleri: 6.9" iPhone, 8 adet, en-US ve tr | Simülatörde çekilir, başlık eklenir, API ile yüklenir | `tools/screenshots.sh`, `tools/frame-screenshots.py` |
| 9 | **Uygulama Gizliliği: "Veri toplanmıyor"** | **Elle** (API'de yok): App Store Connect > Uygulama Gizliliği > Başla > Hayır > Yayımla | — |
| 10 | Fiyat: Ücretsiz | Elle kontrol: Fiyat ve Bulunabilirlik | — |
| 11 | App Review iletişim bilgileri (ad, telefon, e-posta) | Elle: Sürüm > App Review bilgileri | — |
| 12 | Build seçimi ve "İncelemeye gönder" | Elle | — |

Web sayfaları `site/` klasöründedir; ayrı ve herkese açık `platuk/cuptower` deposunda GitHub Pages ile yayımlanır
(ana depo gizli kaldığı için). Güncellemek için: `tools/publish-site.ps1`.

## Kodda yapılanlar

- Gizlilik bildirimi `ios/App/PrivacyInfo.xcprivacy`: izleme yok, izleme alan adı yok, toplanan veri yok;
  gerekçeli API'ler UserDefaults (CA92.1) ve sistem açılış zamanı (35F9.1, `CACurrentMediaTime`).
  TestFlight iş akışı her yüklemede dosyanın pakette ve geçerli olduğunu, görünen adın CupTower olduğunu doğrular.
- Şifreleme beyanı: `ITSAppUsesNonExemptEncryption = NO`.
- Başka bir oyunu çağrıştırabilecek öğeler kaldırıldı: kaptan şapkalı ahtapot boss'u orkestra şefi oldu, adı
  "Maestro Oktavyo / Octavio" (eski "Inkwell" adı başka bir oyunun dünya adıydı), ölümde yukarı süzülen hayalet yerine
  film geri sarma, kaynak kodda başka oyun adı yok.
- Ekran görüntüsü modu (`-screenshot <sahne>`) yalnızca Debug derlemesinde vardır; App Store sürümünde yoktur.
- 14 dil; yardım ekranı bütün özellikleri anlatır (gizli özellik yok).
- Reklam, satın alma, hesap, ağ bağlantısı yok.
