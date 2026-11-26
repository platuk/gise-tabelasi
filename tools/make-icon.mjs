// CupTower uygulama ikonu (1024x1024, saydamlıksız PNG). Kullanım: node tools/make-icon.mjs [önizleme.png]
// 1930'lar afişi: güneş ışınlı zemin, kırmızı perçinli kiriş kulesi, tepesinde iki kulplu altın kupa ve yıldız,
// kalın mürekkep konturlar, kenarda film vinyeti. Her piksel 4x4 alt örnekle (kenar yumuşatma) hesaplanır.
import { writeFileSync, mkdirSync } from "node:fs";
import { deflateSync } from "node:zlib";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT_DIR = join(ROOT, "ios", "App", "Assets.xcassets", "AppIcon.appiconset");
const SIZE = 1024;

const INK = [33, 26, 20];
const CREAM = [250, 238, 208];
const RAY = [255, 208, 96];
const SKY = [242, 150, 70];
const RED = [196, 72, 50];
const RED_DARK = [150, 46, 34];
const GOLD = [250, 196, 62];
const GOLD_DARK = [214, 146, 34];
const GOLD_LIGHT = [255, 236, 150];
const WHITE = [255, 252, 240];
const OUTLINE = 15;

// ---- Şekiller: inside(x, y, g) → g kadar büyütülmüş şeklin içinde mi (g > 0: kontur için).
const ellipse = (cx, cy, rx, ry) => (x, y, g = 0) => ((x - cx) / (rx + g)) ** 2 + ((y - cy) / (ry + g)) ** 2 <= 1;
const rrect = (x0, y0, x1, y1, r) => (x, y, g = 0) => {
  const a = x0 - g, b = y0 - g, c = x1 + g, d = y1 + g, rr = r + g;
  if (x < a || x > c || y < b || y > d) return false;
  const px = Math.min(Math.max(x, a + rr), c - rr);
  const py = Math.min(Math.max(y, b + rr), d - rr);
  return (x - px) ** 2 + (y - py) ** 2 <= rr * rr;
};
const ring = (cx, cy, rx, ry, thickness) => (x, y, g = 0) =>
  ellipse(cx, cy, rx + thickness / 2, ry + thickness / 2)(x, y, g) && !ellipse(cx, cy, rx - thickness / 2, ry - thickness / 2)(x, y, -g);
const and = (a, b) => (x, y, g = 0) => a(x, y, g) && b(x, y, g);
const halfBelow = (yy) => (x, y, g = 0) => y >= yy - g;
// Çokgen: kontur için kenarlara uzaklık kullanılır.
function polygon(points) {
  const inside = (x, y) => {
    let c = false;
    for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
      const [xi, yi] = points[i], [xj, yj] = points[j];
      if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) c = !c;
    }
    return c;
  };
  const dist = (x, y) => {
    let best = Infinity;
    for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
      const [ax, ay] = points[j], [bx, by] = points[i];
      const dx = bx - ax, dy = by - ay;
      const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)));
      best = Math.min(best, Math.hypot(x - (ax + t * dx), y - (ay + t * dy)));
    }
    return best;
  };
  return (x, y, g = 0) => inside(x, y) || (g > 0 && dist(x, y) <= g);
}
function star(cx, cy, outer, inner, rotation = -Math.PI / 2) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? outer : inner;
    const a = rotation + (i * Math.PI) / 5;
    pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
  }
  return polygon(pts);
}

// ---- Sahne (alttan üste çizim sırası). Her katman: { shape, fill(x,y), outline }.
const layers = [];
const add = (shape, fill, outline = true) => layers.push({ shape, fill: typeof fill === "function" ? fill : () => fill, outline });

// Kiriş kulesi: kaydırılmış dört kiriş, perçinler, kirişler arası dikmeler.
const girders = [
  [300, 610, 760, 690],
  [190, 735, 650, 815],
  [360, 860, 840, 940],
  [150, 985, 620, 1065],
];
// Dikmeler (kirişleri bağlayan kafes): kirişlerin arkasında
add(polygon([[455, 690], [485, 690], [400, 735], [370, 735]]), RED_DARK);
add(polygon([[560, 815], [590, 815], [640, 860], [610, 860]]), RED_DARK);
add(polygon([[400, 940], [430, 940], [380, 985], [350, 985]]), RED_DARK);
for (const [x0, y0, x1, y1] of girders.slice().reverse()) {
  const midY = (y0 + y1) / 2;
  add(rrect(x0, y0, x1, y1, 10), (x, y) => {
    for (let rx = x0 + 34; rx < x1 - 20; rx += 54) if ((x - rx) ** 2 + (y - midY) ** 2 <= 11 * 11) return INK;
    if (y < y0 + 16) return [232, 112, 84];
    if (y > y1 - 18) return RED_DARK;
    return RED;
  });
}

// Kupa: kulplar, gövde, ağız, sap, kaide, yıldız, parlaklık.
const cx = 512;
add(ring(318, 360, 78, 92, 34), GOLD);
add(ring(706, 360, 78, 92, 34), GOLD);
const bowl = and(ellipse(cx, 270, 200, 250), halfBelow(270));
add(bowl, (x, y) => {
  if (((x - 418) / 36) ** 2 + ((y - 380) / 90) ** 2 <= 1) return GOLD_LIGHT;
  if (x > 620 && ((x - cx) / 200) ** 2 + ((y - 270) / 250) ** 2 > 0.55) return GOLD_DARK;
  return GOLD;
});
add(ellipse(cx, 270, 200, 44), (x, y) => (((x - cx) / 170) ** 2 + ((y - 278) / 28) ** 2 <= 1 ? GOLD_DARK : GOLD));
add(rrect(cx - 38, 505, cx + 38, 560, 8), GOLD_DARK);
add(rrect(cx - 120, 552, cx + 120, 612, 16), (x, y) => (y < 570 ? GOLD_LIGHT : GOLD));
add(star(cx, 380, 72, 30), WHITE);

function colorAt(x, y) {
  // Zemin: alttaki merkezden yayılan güneş ışınları, kenarda film vinyeti.
  const a = Math.atan2(y - 1100, x - 512);
  const rays = Math.floor(((a + Math.PI) / (2 * Math.PI)) * 32) % 2 === 0;
  let color = rays ? RAY : SKY;
  const d = Math.hypot(x - 512, y - 512) / 724;
  for (const { shape, fill, outline } of layers) {
    if (shape(x, y, 0)) color = fill(x, y);
    else if (outline && shape(x, y, OUTLINE)) color = INK;
  }
  const v = Math.max(0, d - 0.62) * 1.1;
  return color.map((c, i) => c * (1 - v) + INK[i] * v);
}

// Kenar yumuşatma: 4x4 alt örnek.
const S = 4;
const rows = [];
for (let y = 0; y < SIZE; y++) {
  const row = Buffer.alloc(1 + SIZE * 3);
  row[0] = 0;
  for (let x = 0; x < SIZE; x++) {
    let r = 0, g = 0, b = 0;
    for (let sy = 0; sy < S; sy++) for (let sx = 0; sx < S; sx++) {
      const [cr, cg, cb] = colorAt(x + (sx + 0.5) / S, y + (sy + 0.5) / S);
      r += cr; g += cg; b += cb;
    }
    row[1 + x * 3] = Math.round(r / (S * S));
    row[2 + x * 3] = Math.round(g / (S * S));
    row[3 + x * 3] = Math.round(b / (S * S));
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
ihdr[8] = 8;
ihdr[9] = 2; // RGB, alfa yok (App Store ikonu saydam olamaz)
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", deflateSync(Buffer.concat(rows), { level: 9 })),
  chunk("IEND", Buffer.alloc(0)),
]);

mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(join(OUT_DIR, "icon-1024.png"), png);
if (process.argv[2]) writeFileSync(process.argv[2], png);
writeFileSync(join(OUT_DIR, "Contents.json"), JSON.stringify({
  images: [{ filename: "icon-1024.png", idiom: "universal", platform: "ios", size: "1024x1024" }],
  info: { author: "xcode", version: 1 },
}, null, 2) + "\n");
writeFileSync(join(dirname(OUT_DIR), "Contents.json"), JSON.stringify({
  info: { author: "xcode", version: 1 },
}, null, 2) + "\n");
console.log(`İkon yazıldı: ${join(OUT_DIR, "icon-1024.png")} (${png.length} bayt)`);
