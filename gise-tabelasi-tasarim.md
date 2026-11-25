# Gişe Tabelası: Tasarım Notu

Kelime bulmacası. Oyuncu tabelanın harflerini kaydırarak kelimeler kurar, her doğru kelime bir ışığı yakar. Tüm ışıklar yandığında bölüm biter.

## 0. Makara mekaniği

- Tabelada her harf konumu bir makaradır. Oyuncu makarayı yukarı/aşağı kaydırarak o konumdaki harfi değiştirir.
- Tabelada okunan satır bir hedef kelimeyse ışık yanar. Tüm hedefler bulununca bölüm biter.
- Öğretici bölümlerde (1–10) makaraların her kombinasyonu bir hedef kelimedir. Oyuncu gerçek bir kelime kurup reddedilmez.
- Bölümler: `levels/tr.json`, `levels/en.json`. Doğrulama: `node tools/validate-levels.mjs` (hata varsa çıkış kodu 1).
- Aynı bölüm numarası her dilde aynı zorluktadır (kelime uzunluğu ve hedef sayısı eşit). Doğrulayıcı bunu da kontrol eder.

## 1. Diller

- Başlangıç: Türkçe ve İngilizce.
- Her dil için ayrı kelime listesi: `words/tr.json`, `words/en.json`. Yeni dil eklemek sadece yeni dosya demek.
- Arayüz metinleri ayrı çeviri dosyalarında (`locales/tr.json`, `locales/en.json`). Metinler kodun içine yazılmaz.
- Türkçe harfler: ç, ğ, ı, ö, ş, ü ve büyük harf İ. Büyük/küçük harf dönüşümü Türkçe yerel ayarla yapılır (I → ı, i → İ).
- Kelime listesi kaynağı: kendi listen ya da lisansı açık bir kaynak. TDK verisinin kullanım koşulları kontrol edilmeden kullanılmaz.

## 2. Zorluk eğrisi

Kural: her bölüm bir öncekine göre en fazla bir şeyi zorlaştırır (harf sayısı, hamle sınırı ya da süre).

| Bölümler | Harf sayısı | Tabela | Yeni tanıtılan şey |
|---|---|---|---|
| 1–10 | 3–4 | tek satır | sadece kelime bulma |
| 11–30 | 5 | iki satır | bonus (yıldız) kelime |
| 31–60 | 6–7 | iki satır | sınırlı hamle |
| 61+ | 7+ | çok satır | gizli kelime ipucu |

- Her 10 bölümde bir yeni mekanik tanıtılır, aynı anda en fazla bir yeni kural.
- Bölüm içeriği elle hazırlanır. Rastgele üretim, kalite kontrol edilene kadar kullanılmaz.

## 3. Kilit notlar

1. Her bölüm çözülebilir olmalı. Bunu otomatik bir çözücü ile doğrularız.
2. Bir seferde tek yeni kural.
3. Yanlış hamle asla cezalandırıcı değil. Geri alma her zaman var.
4. Dil değiştirmek ilerlemeyi bozmaz.
5. Oyun çevrimdışı çalışır. Ağ hatası oyunu durdurmaz.
6. Gizli özellik yok. Her özellik ayarlar ya da yardım ekranında yazılı. (Apple 5.6 kuralıyla uyumlu olmak için.)
7. Ödeme ekranı yalnızca kullanıcı isterse açılır. Açılış sırasında paywall yok, puan isteği de ilk açılışta yok.

## 4. Hatasız ve bugsuz hedef

Hatasız garanti edilemez, ama hataları yakalayan bir sistem kurulabilir:

- **Bölüm testi:** Her bölüm çözülebilir mi, kelime listesinde var mı. Her değişiklikte otomatik çalışır.
- **Dil testi:** Aynı testler her dil için çalışır. Türkçe karakter ve büyük/küçük harf testleri ayrıca yazılır.
- **Ekran testi:** Küçük (iPhone SE) ve büyük (Pro Max) ekranlarda taşma kontrolü.
- **Kayıt güvenliği:** İlerleme her değişiklikte kaydedilir. Kayıt bozulursa sıfırlamak yerine bir önceki yedeğe dönülür.
- **Test sürümü:** TestFlight ile gerçek cihazlarda deneme. Çökme raporları olmadan yayına çıkılmaz.
- **Yayın kontrol listesi:** Her sürümden önce tüm testler yeşil, kayıt testi geçmiş, gizli özellik yok, metinler iki dilde de tam.

## 5. Açık kararlar

- Türkçe ve İngilizce kelime listelerinin kaynağı.
- Bölüm sayısı ilk sürümde kaç olacak (önerim: 60).
- Maskot karakteri tasarımı ve ara sahne sıklığı.
