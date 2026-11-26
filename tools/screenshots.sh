#!/bin/bash
# App Store ekran görüntüleri: uygulamayı iPhone 6.9" simülatöründe her sahnede (`-screenshot <sahne>`) açar,
# kendi kendine oynarken ekranı çeker. Çıktı: $OUT/<dil>/NN-<sahne>.png (1320x2868, ham).
# Kullanım (macOS, ios/ klasöründe proje üretilmiş olmalı): tools/screenshots.sh <çıktı klasörü>
set -euo pipefail
OUT="${1:-screenshots/raw}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCENES=$(python3 -c "import json;print(' '.join(json.load(open('$ROOT/appstore/metadata.json'))['screenshots']['scenes']))")
BUNDLE=com.ojfamilia.gisetabelasi

# En büyük iPhone (Pro Max) simülatörü.
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys, re
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if "Pro Max" in d["name"]:
            version = [int(x) for x in re.findall(r"\d+", runtime)]
            key = (version, d["name"])
            if best is None or key > best[0]:
                best = (key, d["udid"], d["name"])
print(best[1]); print(best[2], file=sys.stderr)
')
echo "Simülatör: $UDID"

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
    title|characters|bosses) wait=5 ;;
    boss*) wait=11 ;;
  esac
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE" -screenshot "$scene" -AppleLanguages "($lang)" -AppleLocale "$locale" >/dev/null
  sleep "$wait"
  mkdir -p "$OUT/$lang"
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$lang/$(printf '%02d' "$index")-$scene.png"
}

for pair in "en:en_US" "tr:tr_TR"; do
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
