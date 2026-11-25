# Gökdelen Swing: Tasarım Notu

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
