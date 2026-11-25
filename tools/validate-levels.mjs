// Bölüm doğrulayıcı. Kullanım: node tools/validate-levels.mjs
// Her dil dosyasını (levels/*.json) kontrol eder; hata varsa çıkış kodu 1 olur.
import { readFileSync, readdirSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const LEVELS_DIR = process.argv[2] ?? join(ROOT, "levels");

const ALPHABETS = {
  tr: [..."ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ"],
  en: [..."ABCDEFGHIJKLMNOPQRSTUVWXYZ"],
};

// İlk bölümlerde (öğretici) tabeladaki her kombinasyon bir hedef kelime olmalı,
// böylece oyuncu gerçek bir kelime kurup "reddedilme" yaşamaz.
const TUTORIAL_LAST_LEVEL = 10;

function combinations(reels) {
  return reels.reduce((acc, reel) => acc.flatMap((p) => reel.map((l) => p + l)), [""]);
}

function validateFile(file) {
  const errors = [];
  const err = (msg) => errors.push(`${basename(file)}: ${msg}`);

  let data;
  try {
    data = JSON.parse(readFileSync(file, "utf8"));
  } catch (e) {
    return [`${basename(file)}: JSON okunamadı: ${e.message}`];
  }

  const lang = data.language;
  const alphabet = ALPHABETS[lang];
  if (!alphabet) return [`${basename(file)}: bilinmeyen dil "${lang}"`];
  if (basename(file, ".json") !== lang) err(`dosya adı dil koduyla aynı değil (${lang})`);
  if (!Array.isArray(data.levels) || data.levels.length === 0) return [...errors, `${basename(file)}: bölüm yok`];

  let prevLen = 0;
  data.levels.forEach((lvl, i) => {
    const tag = `bölüm ${lvl.id}`;
    if (lvl.id !== i + 1) err(`${tag}: id sırası bozuk (beklenen ${i + 1})`);

    const { reels, targets } = lvl;
    if (!Array.isArray(reels) || reels.length < 3) { err(`${tag}: en az 3 makara gerekli`); return; }
    if (!Array.isArray(targets) || targets.length < 2) { err(`${tag}: en az 2 hedef kelime gerekli`); return; }

    reels.forEach((reel, r) => {
      if (!Array.isArray(reel) || reel.length === 0) err(`${tag}: makara ${r + 1} boş`);
      if (new Set(reel).size !== reel.length) err(`${tag}: makara ${r + 1} içinde tekrar eden harf`);
      for (const l of reel) {
        if ([...l].length !== 1) err(`${tag}: makara ${r + 1} içinde tek harf olmayan değer "${l}"`);
        else if (!alphabet.includes(l)) err(`${tag}: "${l}" ${lang} alfabesinde yok ya da büyük harf değil`);
      }
    });

    if (new Set(targets).size !== targets.length) err(`${tag}: tekrar eden hedef kelime`);

    for (const w of targets) {
      const letters = [...w];
      if (w !== w.toLocaleUpperCase(lang)) err(`${tag}: "${w}" büyük harfle yazılmamış`);
      if (letters.length !== reels.length) { err(`${tag}: "${w}" uzunluğu makara sayısına eşit değil`); continue; }
      letters.forEach((l, p) => {
        if (!reels[p].includes(l)) err(`${tag}: "${w}" kurulamıyor, "${l}" harfi makara ${p + 1} üzerinde yok`);
      });
    }

    const combos = combinations(reels);
    if (lvl.id <= TUTORIAL_LAST_LEVEL) {
      const extra = combos.filter((c) => !targets.includes(c));
      if (extra.length) err(`${tag}: öğretici bölümde hedef olmayan kombinasyonlar var: ${extra.join(", ")}`);
    }

    // Zorluk geriye gitmez: kelime uzunluğu hiç azalmaz.
    if (reels.length < prevLen) err(`${tag}: kelime uzunluğu önceki bölümden kısa`);
    prevLen = reels.length;
  });

  return errors;
}

// Aynı bölüm numarasının her dilde aynı zorlukta olması (makara sayısı, hedef sayısı).
function validateParity(allData) {
  const errors = [];
  const [base, ...others] = allData;
  for (const other of others) {
    if (other.data.levels.length !== base.data.levels.length) {
      errors.push(`${other.lang}: bölüm sayısı ${base.lang} ile aynı değil`);
      continue;
    }
    base.data.levels.forEach((b, i) => {
      const o = other.data.levels[i];
      if (b.reels.length !== o.reels.length) errors.push(`bölüm ${b.id}: kelime uzunluğu ${base.lang}/${other.lang} arasında farklı`);
      if (b.targets.length !== o.targets.length) errors.push(`bölüm ${b.id}: hedef sayısı ${base.lang}/${other.lang} arasında farklı`);
    });
  }
  return errors;
}

const files = readdirSync(LEVELS_DIR).filter((f) => f.endsWith(".json")).sort();
let errors = [];
const allData = [];
for (const f of files) {
  const path = join(LEVELS_DIR, f);
  const fileErrors = validateFile(path);
  errors = errors.concat(fileErrors);
  if (!fileErrors.length) allData.push({ lang: basename(f, ".json"), data: JSON.parse(readFileSync(path, "utf8")) });
}
if (allData.length > 1) errors = errors.concat(validateParity(allData));

if (errors.length) {
  console.error(`HATA (${errors.length}):`);
  for (const e of errors) console.error("  - " + e);
  process.exit(1);
}
console.log(`Tamam: ${files.length} dil dosyası, ${allData.reduce((n, d) => n + d.data.levels.length, 0)} bölüm doğrulandı.`);
