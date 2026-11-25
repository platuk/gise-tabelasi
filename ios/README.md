# Gökdelen Swing / Skyscraper Swing: iOS

1930'lar çizgi film tarzında sonsuz tırmanma oyunu. SwiftUI (menüler) + SpriteKit (oyun), iOS 17+, yalnızca iPhone, dikey. İnternet, reklam, satın alma ve veri toplama yok.

## Klasörler

- `GameCore/`: oyunun kuralları (`TowerSimulation`): fizik, kirişler, kombo, yanan film. Arayüzden bağımsız, deterministik, testli.
- `App/Game/`: SpriteKit sahnesi, lastik hortum karakter, film shader'ı, kontroller.
- `App/Views/`: başlık, oyun sonu ve yardım ekranları.
- `../tools/check-strings.mjs`: TR/EN metin anahtarlarını kodla karşılaştırır; her derlemeden önce çalışır.

## Testler

```sh
node tools/check-strings.mjs
cd ios/GameCore && swift test
```

`swift test`, bir botun kuleyi 40 kat tırmanabildiğini de doğrular (kurallar ve kiriş yerleşimi oynanabilir mi).

## Mac'siz derleme ve TestFlight

- Her gönderimde GitHub Actions (`.github/workflows/ci.yml`) metinleri doğrular, `swift test` çalıştırır ve uygulamayı derler.
- GitHub > Actions > **TestFlight** > Run workflow: imzalayıp App Store Connect'e yükler (`testflight.yml`).

## Mac'te çalıştırma

```sh
brew install xcodegen node
cd ios && xcodegen generate && open GiseTabelasi.xcodeproj
```

Paket kimliği `com.ojfamilia.gisetabelasi` (`project.yml`). Xcode proje/hedef adı tarihsel olarak `GiseTabelasi` kaldı; kullanıcıya görünmez.

## App Store notları

- Gizlilik formu: "Veri toplanmıyor" (Data Not Collected). Yaş: 4+.
- İnceleme notu: Tüm özellikler "Nasıl oynanır" ekranında yazılı. Gizli menü, uzaktan açılan özellik ya da sunucu bağlantısı yok.
- App Store Connect'teki uygulama adı hâlâ "Gişe Tabelası"; yayından önce değiştirilecek.
