// Geçici uygulama ikonu üretir (1024x1024, saydamlıksız PNG). Kullanım: node tools/make-icon.mjs
// Kırmızı tabela zemini, çevresinde ampuller, ortada üç makara. Özgün çizim gelince değiştirilecek.
import { writeFileSync, mkdirSync } from "node:fs";
import { deflateSync } from "node:zlib";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = join(ROOT, "ios", "App", "Assets.xcassets", "AppIcon.appiconset");
const SIZE = 1024;

const RED = [140, 30, 25];
const CREAM = [245, 232, 204];
const INK = [33, 26, 20];
const BULB = [255, 209, 77];

function inRoundRect(x, y, x0, y0, x1, y1, r) {
  if (x < x0 || x > x1 || y < y0 || y > y1) return false;
  const cx = Math.min(Math.max(x, x0 + r), x1 - r);
  const cy = Math.min(Math.max(y, y0 + r), y1 - r);
  return (x - cx) ** 2 + (y - cy) ** 2 <= r * r;
}

// Ampul merkezleri: tabela kenarında, her kenarda eşit aralıklı.
const bulbs = [];
const inset = 84, count = 8;
for (let i = 0; i < count; i++) {
  const t = inset + ((SIZE - 2 * inset) * i) / (count - 1);
  bulbs.push([t, inset], [t, SIZE - inset], [inset, t], [SIZE - inset, t]);
}

// Ortadaki üç makara kutusu.
const reelW = 170, reelH = 250, gap = 50;
const reelsLeft = (SIZE - (3 * reelW + 2 * gap)) / 2;
const reelTop = (SIZE - reelH) / 2;
const reels = [0, 1, 2].map((i) => {
  const x0 = reelsLeft + i * (reelW + gap);
  return [x0, reelTop, x0 + reelW, reelTop + reelH];
});

function colorAt(x, y) {
  for (const [bx, by] of bulbs) if ((x - bx) ** 2 + (y - by) ** 2 <= 34 * 34) return BULB;
  if (inRoundRect(x, y, 170, 170, SIZE - 170, SIZE - 170, 70)) {
    for (const [x0, y0, x1, y1] of reels) {
      if (inRoundRect(x, y, x0, y0, x1, y1, 28)) {
        const inner = inRoundRect(x, y, x0 + 16, y0 + 16, x1 - 16, y1 - 16, 14);
        if (!inner) return INK;
        // Makaranın ortasında yanan ışık şeridi.
        if (Math.abs(y - (y0 + y1) / 2) <= 22 && x > x0 + 40 && x < x1 - 40) return BULB;
        return CREAM;
      }
    }
    if (!inRoundRect(x, y, 188, 188, SIZE - 188, SIZE - 188, 54)) return INK; // panel çerçevesi
    return CREAM;
  }
  return RED;
}

const rows = [];
for (let y = 0; y < SIZE; y++) {
  const row = Buffer.alloc(1 + SIZE * 3);
  row[0] = 0; // filtre yok
  for (let x = 0; x < SIZE; x++) {
    const [r, g, b] = colorAt(x + 0.5, y + 0.5);
    row[1 + x * 3] = r; row[2 + x * 3] = g; row[3 + x * 3] = b;
  }
  rows.push(row);
}

const CRC_TABLE = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const b of buf) c = CRC_TABLE[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8;  // bit derinliği
ihdr[9] = 2;  // RGB, alfa yok (App Store ikonu saydam olamaz)
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", deflateSync(Buffer.concat(rows), { level: 9 })),
  chunk("IEND", Buffer.alloc(0)),
]);

mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(join(OUT_DIR, "icon-1024.png"), png);
writeFileSync(join(OUT_DIR, "Contents.json"), JSON.stringify({
  images: [{ filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }],
  info: { author: "xcode", version: 1 },
}, null, 2) + "\n");
writeFileSync(join(dirname(OUT_DIR), "Contents.json"), JSON.stringify({
  info: { author: "xcode", version: 1 },
}, null, 2) + "\n");
console.log(`İkon yazıldı: ${join(OUT_DIR, "icon-1024.png")} (${png.length} bayt)`);
