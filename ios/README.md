# Gişe Tabelası: iOS

SwiftUI, iOS 17+, yalnızca iPhone, dikey ekran. İnternet, reklam, satın alma ve veri toplama yok.

## Klasörler

- `GameCore/`: oyun mantığı (bölüm okuma, makara çevirme, geri alma, kilit, ilerleme kaydı). Arayüzden bağımsız, testli Swift paketi.
- `App/`: SwiftUI ekranları, tema, Türkçe/İngilizce metinler.
- `../levels/`: bölüm verisi. Uygulama bu dosyaları doğrudan paketler, kopya tutulmaz.
- `../tools/`: Node doğrulayıcıları. Her derlemeden önce otomatik çalışır.

## Mac'te ilk kurulum

1. Xcode 15 veya üstü kurulu olmalı.
2. Araçları kur:
   ```sh
   brew install xcodegen node
   ```
3. Paket kimliği `com.ojfamilia.gisetabelasi` (`project.yml`). Eski uygulamanın kimliği (`com.eroplayer.app`) kullanılmaz.
4. Projeyi üret ve aç:
   ```sh
   cd ios
   xcodegen generate
   open GiseTabelasi.xcodeproj
   ```
5. Xcode'da Signing & Capabilities altında takımını seç, bir simülatör seçip çalıştır.

## Testler

```sh
node tools/validate-levels.mjs   # bölümler: kurulabilirlik, alfabe, diller arası eşitlik
node tools/check-strings.mjs     # metinler: iki dilde aynı anahtarlar, koddaki her anahtar tanımlı
cd ios/GameCore && swift test    # oyun mantığı: her bölüm baştan sona oynanıp bitirilebiliyor mu, kilit ve kayıt
```

Xcode her derlemeden önce ilk iki kontrolü çalıştırır, hata varsa derleme durur.

## TestFlight (Mac'siz)

GitHub > Actions > **TestFlight** > Run workflow. Uygulamayı imzalayıp App Store Connect'e yükler. Gerekli gizli değerler `.github/workflows/testflight.yml` dosyasının başında yazılı. Build numarası her çalıştırmada otomatik artar.

Geçici ikon `node tools/make-icon.mjs` ile üretilir; özgün çizim gelince `ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` değiştirilir.

## App Store notları

- Gizlilik formu: "Veri toplanmıyor" (Data Not Collected).
- Yaş sınırı: 4+.
- İnceleme notu: Oyunun tüm özellikleri "Nasıl oynanır" ekranında yazılı. Gizli menü, uzaktan açılan özellik ya da sunucu bağlantısı yok.
