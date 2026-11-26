# CupTower: App Store başvuru dosyası

Bu klasör App Store Connect'e girilecek her şeyi içerir. Kod tarafı hazır; aşağıdaki **elle yapılacak** adımlar
App Store Connect'te (tarayıcıda) yapılır.

## Elle yapılacaklar (gönderimden önce şart)

| # | Ne | Nerede | Durum |
|---|---|---|---|
| 1 | Uygulama adını **CupTower** yap (şu an "Gişe Tabelası"; ad ile ikon altındaki ad uyuşmazsa 2.3.8'den red) | Uygulama Bilgileri > Ad | Yapılmadı |
| 2 | Alt başlık: `metadata-*.md` | Uygulama Bilgileri | Yapılmadı |
| 3 | **Gizlilik politikası URL'si** (her uygulama için zorunlu, veri toplamasa bile) | Uygulama Gizliliği | Barındırma gerekli: `privacy-policy.md` |
| 4 | **Destek URL'si** (zorunlu) | Sürüm bilgileri | Barındırma gerekli |
| 5 | Uygulama Gizliliği formu: "Veri toplanmıyor" | Uygulama Gizliliği | Yapılmadı |
| 6 | Yaş sınırı anketi: `age-rating.md` | Uygulama Bilgileri > Yaş Sınırı | Yapılmadı |
| 7 | Ekran görüntüleri: 6.9" (1320×2868 ya da 1290×2796), en az 3, en çok 10 | Sürüm > Önizlemeler | Yapılmadı |
| 8 | Açıklama, anahtar kelimeler, tanıtım metni: `metadata-*.md` | Sürüm bilgileri | Yapılmadı |
| 9 | İnceleme notları: `review-notes.md` (boss'lara hızlı ulaşma yolu dahil) | Sürüm > App Review bilgileri | Yapılmadı |
| 10 | Kategori: Oyunlar > Arcade (ikinci: Aksiyon) | Uygulama Bilgileri | Kontrol et |
| 11 | Fiyat: Ücretsiz; uygulama içi satın alma yok | Fiyat ve Bulunabilirlik | Kontrol et |
| 12 | Telif: "© 2026 Cristian Ojeda" (ya da geliştirici adı) | Sürüm bilgileri | Yapılmadı |

## Kodda yapılanlar (bu sürüm)

- Gizlilik bildirimi `ios/App/PrivacyInfo.xcprivacy`: izleme yok, veri toplama yok; UserDefaults (CA92.1) ve
  süre ölçümü (35F9.1) gerekçeleri.
- Şifreleme beyanı: `ITSAppUsesNonExemptEncryption = NO` (her yüklemede soru sorulmaz).
- Başka bir oyunu çağrıştırabilecek öğeler değiştirildi: ahtapot boss'un kaptan şapkası ve adı, ölümde yukarı süzülen hayalet.
- 14 dil; yardım ekranı bütün özellikleri anlatır (gizli özellik yok, 2.3.1 / 5.6).
- Reklam, satın alma, hesap, ağ bağlantısı yok.
