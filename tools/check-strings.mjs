// Metin doğrulayıcı. Kullanım: node tools/check-strings.mjs
// 1) Her dilin Localizable.strings dosyası aynı anahtarlara sahip mi?
// 2) Swift kodunda kullanılan her anahtar dosyalarda var mı? Kullanılmayan anahtar var mı?
// 3) Biçim yer tutucuları (%lld, %@) diller arasında aynı mı?
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const APP = join(ROOT, "ios", "App");
const RES = join(APP, "Resources");
const LANGS = ["tr", "en"];

function parseStrings(file) {
  const text = readFileSync(file, "utf8");
  const map = new Map();
  const re = /^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$/;
  text.split(/\r?\n/).forEach((line, i) => {
    if (!line.trim() || line.trim().startsWith("//")) return;
    const m = line.match(re);
    if (!m) throw new Error(`${file}:${i + 1}: okunamayan satır: ${line}`);
    if (map.has(m[1])) throw new Error(`${file}:${i + 1}: tekrar eden anahtar ${m[1]}`);
    map.set(m[1], m[2]);
  });
  return map;
}

function swiftFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) return swiftFiles(p);
    return name.endsWith(".swift") ? [p] : [];
  });
}

// %lld, %@ ve sıralı biçimleri (%1$lld) aynı türe indirger.
const placeholders = (s) => (s.match(/%(?:\d+\$)?(?:lld|@|d)/g) || []).map((p) => p.replace(/\d+\$/, "")).sort().join(",");
const errors = [];

const tables = Object.fromEntries(LANGS.map((l) => [l, parseStrings(join(RES, `${l}.lproj`, "Localizable.strings"))]));
const [base, ...others] = LANGS;
for (const other of others) {
  for (const k of tables[base].keys()) if (!tables[other].has(k)) errors.push(`${other}: eksik anahtar "${k}"`);
  for (const k of tables[other].keys()) if (!tables[base].has(k)) errors.push(`${base}: eksik anahtar "${k}"`);
  for (const [k, v] of tables[base]) {
    if (tables[other].has(k) && placeholders(v) !== placeholders(tables[other].get(k))) {
      errors.push(`"${k}": yer tutucular ${base}/${other} arasında farklı`);
    }
  }
}

// Koddaki anahtarlar: "nokta.ile.ayrılmış" biçimindeki dize sabitleri; araya \(...) girebilir.
const used = new Set();
const keyRe = /"([a-z]+(?:\.[a-zA-Z]+)+)((?: \\\([^)]*\))*)"/g;
for (const f of swiftFiles(APP)) {
  const src = readFileSync(f, "utf8");
  for (const m of src.matchAll(keyRe)) {
    // SF Symbols adları (systemName:/systemImage:) metin anahtarı değildir.
    if (/system(Name|Image):\s*$/.test(src.slice(Math.max(0, m.index - 16), m.index))) continue;
    used.add(m[1]);
  }
}
const baseKeys = new Map([...tables[base].keys()].map((k) => [k.split(" ")[0], k]));
for (const k of used) if (!baseKeys.has(k)) errors.push(`kodda kullanılan "${k}" metin dosyalarında yok`);
for (const [short] of baseKeys) if (!used.has(short)) errors.push(`"${short}" metin dosyasında var ama kodda kullanılmıyor`);

if (errors.length) {
  console.error(`HATA (${errors.length}):`);
  errors.forEach((e) => console.error("  - " + e));
  process.exit(1);
}
console.log(`Tamam: ${LANGS.length} dil, ${tables[base].size} metin anahtarı, kodda ${used.size} anahtar kullanılıyor.`);
