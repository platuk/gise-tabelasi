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
3. `project.yml` içindeki `com.example` ile başlayan iki değeri kendi kimliğinle değiştir. Eski uygulamanın kimliğini (`com.eroplayer.app`) kullanma.
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

## App Store notları

- Gizlilik formu: "Veri toplanmıyor" (Data Not Collected).
- Yaş sınırı: 4+.
- İnceleme notu: Oyunun tüm özellikleri "Nasıl oynanır" ekranında yazılı. Gizli menü, uzaktan açılan özellik ya da sunucu bağlantısı yok.
