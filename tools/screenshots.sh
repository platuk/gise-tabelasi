#!/bin/bash
# Uygulamayı simülatörde her sahnede (`-screenshot <sahne>`) açar, kendi kendine oynarken ekranı çeker.
# Çıktı: $OUT/<dil>/NN-<sahne>.png. Sonunda uygulama çöktüyse (çökme raporu varsa) hata verir.
# Kullanım (macOS, ios/ klasöründe proje üretilmiş olmalı): tools/screenshots.sh <çıktı klasörü>
# Ortam değişkenleri (hepsi isteğe bağlı):
#   DEVICE_MATCH  simülatör adında aranacak metin (varsayılan "Pro Max": App Store görüntüleri)
#   DEVICE_PICK   "largest" (varsayılan, en yeni sürüm) ya da "smallest" (adı en kısa, ör. iPhone 16e)
#   SCENES        sahneler (varsayılan: appstore/metadata.json)
#   LANGS         "dil:yerel" çiftleri (varsayılan "en:en_US tr:tr_TR")
#   WAIT_SCALE    bekleme süresi çarpanı (uzun oyun testi için)
set -euo pipefail
OUT="${1:-screenshots/raw}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENES="${SCENES:-$(python3 -c "import json;print(' '.join(json.load(open('$ROOT/appstore/metadata.json', encoding='utf-8-sig'))['screenshots']['scenes']))")}"
LANGS="${LANGS:-en:en_US tr:tr_TR}"
WAIT_SCALE="${WAIT_SCALE:-1}"
BUNDLE=com.ojfamilia.gisetabelasi
export DEVICE_MATCH="${DEVICE_MATCH:-Pro Max}" DEVICE_PICK="${DEVICE_PICK:-largest}"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, os, re, sys
data = json.load(sys.stdin)["devices"]
match, pick = os.environ["DEVICE_MATCH"], os.environ["DEVICE_PICK"]
found = []
# "A|B": önce A aranır, yoksa B.
for alternative in match.split("|"):
    for runtime, devices in data.items():
        if "iOS" not in runtime:
            continue
        version = [int(x) for x in re.findall(r"\d+", runtime)]
        for d in devices:
            if alternative in d["name"]:
                found.append((version, d["name"], d["udid"]))
    if found:
        break
if not found:
    sys.exit(f"simülatör yok: {match}")
newest = max(v for v, _, _ in found)
found = [f for f in found if f[0] == newest]
chosen = min(found, key=lambda f: (len(f[1]), f[1])) if pick == "smallest" else max(found, key=lambda f: f[1])
print(chosen[2]); print("Simülatör: " + chosen[1], file=sys.stderr)
')
echo "UDID: $UDID"

cd "$ROOT/ios"
xcodebuild build -project GiseTabelasi.xcodeproj -scheme GiseTabelasi -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$RUNNER_TEMP/dd" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= -quiet
APP="$RUNNER_TEMP/dd/Build/Products/Debug-iphonesimulator/CupTower.app"
test -f "$APP/PrivacyInfo.xcprivacy" && echo "Gizlilik bildirimi pakette: tamam"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

shoot() { # dil yerel ayar sahne sıra
  local lang=$1 locale=$2 scene=$3 index=$4 wait=8
  case "$scene" in
    title|characters|bosses|settings|help) wait=5 ;;
    boss*) wait=11 ;;
  esac
  wait=$(python3 -c "print(int($wait * $WAIT_SCALE))")
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -screenshot "$scene" -AppleLanguages "($lang)" -AppleLocale "$locale" >/dev/null
  sleep "$wait"
  mkdir -p "$OUT/$lang"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$lang/$(printf '%02d' "$index")-$scene.png"
  # Uygulama hâlâ açık mı (çöktüyse süreç listesinde yoktur)?
  local running
  running=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -c "$BUNDLE" || true)
  if [ "${running:-0}" = 0 ]; then
    echo "::error::Uygulama '$scene' sahnesinde kapandı (çökme olabilir)"
    CRASHED=1
  fi
}

CRASHED=0
for pair in $LANGS; do
  lang=${pair%%:*}; locale=${pair##*:}
  # İlk açılış (ses motoru, önbellek) ölçümü bozmasın.
  xcrun simctl launch "$UDID" "$BUNDLE" -screenshot title -AppleLanguages "($lang)" >/dev/null; sleep 4
  i=1
  for scene in $SCENES; do
    shoot "$lang" "$locale" "$scene" "$i"
    i=$((i + 1))
  done
done
ls -R "$OUT"

if ls ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -i -E "cuptower" ; then
  echo "::error::Çökme raporu bulundu"
  for f in ~/Library/Logs/DiagnosticReports/*[Cc]up[Tt]ower*; do head -80 "$f"; done
  exit 1
fi
if [ "$CRASHED" = 1 ]; then exit 1; fi
echo "Çökme yok."
