# CupTower (Kupa Kulesi): Tasarım Notu

## Kupalar ve bölümler

- Her 100 katta bir kupa: Bronz, Gümüş, Altın, Elmas, Efsane. Kupa katı kayıt noktasıdır; sonraki oyun oradan başlayabilir.
- Bölüm 1 (0–99): çelik kirişler. Bölüm 2 (100–199): kısa, kayan kirişler (oyuncuyu taşır). Bölüm 3 (200–299): kaygan kirişler. 300+: karışık.
- Zıplama: tırmanışta her zaman otomatik (ayar yok). Boss dövüşü ayrı mod: otomatik zıplama yok, yukarı kaydırarak zıplanır.
- Tempo: dünya zamanı çarpanı kat 0'da 0.8, kat 800'de 1.0, en çok 1.12. Yanan film yavaş başlar (28 pt/sn); azami hızı bölüm başına +35 (150 → 260).
- Duvar taklası: yere basmadan en fazla 10; sonra duvar yalnızca seker.
- Kupa, ödül kupasıdır; karakter kupa ya da fincan değildir (başka bir oyunun karakterine benzememek için).

## Yardım, baloncuklar, karakterler, diriliş

- Yardımcı el: inişte kenarı ≤20 pt kaçıran oyuncu kirişe çekilir (150 pt/sn). Havada hızla (≥300 pt/sn) duvara çarpınca takla + yükselme, ulaşılabilecek en yüksek kirişe yönlendirme.
- Baloncuklar (kat 8+, %8 olasılık): roket (+50 kat), ağır çekim (6 sn, %50), adrenalin (8 sn, ×1.35 hız), kalkan (10 sn).
- 5 karakter, kupa cüzdanıyla açılır (0/1/2/3/5). Gerçek para yok. Yalnızca görünüş.
- Oyun başına bir bedava diriliş: film geri sarılır (◀◀, tarama çizgileri), iris, son kirişe dönüş, 3 sn kalkan.
- Doğrulama: bot 7 kulede tüm bölümleri geçiyor (JS kopyası + Swift testleri).

## Bölümler ve boss (1000 kat)

- Bölüm = 1000 kat; kirişler bölüm başında geniş (200), sonuna doğru daralır (80). Kupa ve kayıt noktası her 100 katta.
- Her bölüm sonunda bir boss; ilki Maestro Oktavyo (orkestra şefi ahtapot; eski adı ve kaptan şapkası başka bir oyunun boss'una fazla benzediği için değiştirildi): film durur, arena kilitlenir, oyuncu otomatik ateş eder, 3 can.
  Saldırılar uyarılıdır (kollar kalkar, parlar). Aşama 1: yelpaze + dalga; aşama 2: + nişanlı mürekkep; aşama 3: + yağmur, daha hızlı.
  Zafer: +500×n puan, +3 kupa, sonraki bölüm. Dövüşte ölünürse sonraki oyun dövüşten başlar.
- Arka plan: kodla "suluboya" boyanan katmanlar (gökyüzü bantları, güneş/ay/yıldızlar, şehir, iki bulut katmanı, kuşlar, zeplin).

## Boss sırası, ses, menü (sürüm 10)

- Boss'lar sırayla (6'lı döngü, can artarak): ahtapot (yelpaze, nişanlı, dalga, yağmur), solucan (fışkırma, çamur), yarasa (halka, yağmur),
  uzaylı (ışın, halka), robot (seken cıvatalar, ışın), bulldog (seken kemikler, fışkırma, dalga). Işın ve fışkırma oyuncunun yerini
  hedefler; uyarı süresince zeminde işaretlenir, 1.25 kat uzun uyarı. Her boss'un kendine özgü hareket yolu vardır.
- Ses: dosya yok, her şey kodla sentezlenir (AVAudioSourceNode). Müzik: tuba, stride piyano, fırçalı davul, klarnet;
  büyük komboda banjo ve trompet; boss'ta minör tango; menüde sakin sürüm. Gramofon süzgeci ve cızırtı. Tempo oyun hızını izler.
- Karakter: komi şapkalı Tıpı (önceki siyah gövde + turta göz + beyaz eldiven ünlü bir karaktere fazla benziyordu),
  her karaktere ayrı oran, manşetli iri eldiven, iri ayakkabı, ifade (kararlı, korku, sevinç, acı), göz kırpma,
  8 çizimlik koşu döngüsü, kuyruk ve kulaklarda takip hareketi, hız çizgileri.
- Menü: perde açılan sinema salonu, sırayla yanan tabela ampulleri, dans eden karakter; Oyna/Devam, Karakterler,
  Boss galerisi (ödülsüz prova), Ayarlar (müzik, efekt, titreşim, sarsıntı, film efektleri, sıfırlama), Nasıl oynanır.
- Ara menüsü: Devam (3-2-1 film geri sayımı), Yeniden başla, Ayarlar, Ana ekran. Arka plana geçince kendiliğinden durur.

## Önceki çalışma adı: Gökdelen Swing

1930'ların lastik hortum çizgi filmleri tarzında, sonsuz yukarı tırmanma oyunu. İlham: Icy Tower'ın hız-zıplama-kombo çekirdeği; görsel dil: dönemin çizgi filmleri. Hiçbir oyunun karakteri, logosu, menüsü ya da adı kullanılmaz.

## Çekirdek

- Koştukça hız kazanılır, hızlı koşan daha yükseğe zıplar (durarak 1 kat, tam hızla 4+ kat).
- Duvardan hızını koruyarak sekme.
- Kombo: 3 sn içinde art arda çok katlı zıplayışlar; puan = (kat sayısı)².
- Tehlike: alttan yükselen **yanan film**; 5. kattan sonra başlar, hızlanır.
- Mekân: inşaatı süren 1930'lar gökdeleni; gökyüzü yükseldikçe akşama ve geceye döner. Her 100 katta bir tam genişlikte dinlenme katı.

## His (öncelik)

| Katman | Durum |
|---|---|
| Film katmanı: gren, toz, çizik, titreme, vinyet, kare kayması | Prototipte (shader) |
| Kesik zamanlama: çizim, alev ve film saniyede 12 kare | Prototipte |
| Kaynayan çizgiler: her karede küçük titreme | Prototipte (karakter, alev) |
| Ezilme/esneme, toz bulutu, yıldızlar, sarsıntı, titreşim | Prototipte |
| Ara yazı kartları, iris kapanışı, "SON" kartı | Prototipte |
| Elle çizilmiş karakter ve suluboya arka planlar | Çizer gerekli |
| Müzik: kombo büyüdükçe enstrüman eklenen caz | Besteci gerekli (kamu malı kayıtlar ayrık enstrümanlı değil) |
| Ses efektleri | Sırada |

## Kilit notlar

1. Kurallar `TowerSimulation`'da, sabit zaman adımıyla ve deterministik: aynı tohum, aynı kule.
2. Her kural değişikliği testle doğrulanır; bot testi oyunun oynanabilir kaldığını kanıtlar.
3. Gizli özellik yok; her şey yardım ekranında yazılı (App Store 5.6).
4. Reklam, satın alma, veri toplama yok.

## Ad, logo, yazı tipi, diller (sürüm 12)

- Ad her yerde CupTower (ürün adı, görünen ad, 14 dilde InfoPlist.strings, logo, zeplin).
- Logo: oyunda "CUP [kupa] TOWER" afiş harfleri; ikon: güneş ışınlı zemin, kiriş kulesi, yıldızlı altın kupa (tools/make-icon.mjs).
- Yazı tipi: Georgia Bold (Türkçe, Kiril, Yunan harfleri eksiksiz); uzun metinler kartta satırlara bölünür, düğmelerde küçülür.
- Diller: en, tr, de, fr, es, it, pt-BR, ru, pl, ja, ko, zh-Hans, zh-Hant, ar. Oyun içi dil düğmesi iOS'un uygulamaya özel dil ayarını açar.
- Kiriş malzemesi bölüm başına (boss'tan sonra) değişir; her 100 katta değil.
