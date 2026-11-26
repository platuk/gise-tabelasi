#!/bin/bash
# App Review ekibi için tanıtım videosu: uygulamayı simülatörde (İngilizce) sahne sahne açar,
# kendi kendine oynarken ekranı kaydeder, her parçanın altına kısa açıklama yazar ve tek MP4'te birleştirir.
# Bütün görüntü uygulamanın kendi ekran kaydıdır. Kullanım (macOS, ios/ klasöründe proje üretilmiş olmalı):
#   tools/review-video.sh <çıktı klasörü>
set -euo pipefail
OUT="${1:-review-video}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE=com.ojfamilia.gisetabelasi
FONT="/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
mkdir -p "$OUT"
WORK="$(mktemp -d)"
python3 -m venv "$WORK/venv"
"$WORK/venv/bin/pip" install --quiet pillow
PY="$WORK/venv/bin/python"

# sahne | saniye | açıklama (satır sonu: \n)
SEGMENTS=(
  "title|6|CupTower: a single-player climbing game.\nWorks fully offline. No account, ads,\nin-app purchases or data collection."
  "help|6|All rules are explained in \"How to play\"\non the title screen. No hidden features."
  "climb|14|Hold the left or right half of the screen\nto run. Jumping is automatic.\nBounce off walls for combos."
  "climb2|10|Bubbles give a boost, slow motion,\nadrenaline or a shield. A new world\nand girder style every 1000 floors."
  "bosses|6|A boss waits every 1000 floors.\nTo reach them instantly, tap BOSS FIGHTS\non the title screen and pick any boss."
  "boss0|16|Boss fight: swipe up to jump; the\ncharacter fires on its own. The screen\nflashes before every side or floor attack."
  "boss3|10|Six hand-made bosses, all drawn\nin code inside the app."
  "boss5|12|The game is portrait iPhone only;\non iPad it runs in compatibility mode."
  "characters|7|Cups are trophies earned by playing\n(1 per 100 floors). They unlock characters\nand cannot be bought."
  "settingsAbout|8|Settings > About: privacy policy\nand support links."
)

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
found = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if "iOS" not in runtime:
        continue
    version = [int(x) for x in re.findall(r"\d+", runtime)]
    for d in devices:
        if "Pro Max" in d["name"]:
            found.append((version, d["name"], d["udid"]))
if not found:
    sys.exit("Pro Max simülatörü yok")
best = max(found)
print(best[2]); print("Simülatör: " + best[1], file=sys.stderr)
')

cd "$ROOT/ios"
xcodebuild build -project GiseTabelasi.xcodeproj -scheme GiseTabelasi -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$RUNNER_TEMP/dd" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= -quiet
APP="$RUNNER_TEMP/dd/Build/Products/Debug-iphonesimulator/CupTower.app"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"
# İlk açılış (ses motoru, önbellek) kayda girmesin.
xcrun simctl launch "$UDID" "$BUNDLE" -screenshot title -AppleLanguages "(en)" -AppleLocale en_US >/dev/null; sleep 5

index=0
: > "$WORK/list.txt"
for entry in "${SEGMENTS[@]}"; do
  IFS='|' read -r scene seconds caption <<< "$entry"
  index=$((index + 1))
  raw="$WORK/raw-$index.mp4"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  sleep 1
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$raw" >/dev/null 2>&1 &
  recorder=$!
  sleep 1
  xcrun simctl launch "$UDID" "$BUNDLE" -screenshot "$scene" -AppleLanguages "(en)" -AppleLocale en_US >/dev/null
  sleep "$seconds"
  kill -INT "$recorder"
  wait "$recorder" || true
  running=$(xcrun simctl spawn "$UDID" launchctl list 2>/dev/null | grep -c "$BUNDLE" || true)
  if [ "${running:-0}" = 0 ]; then echo "::error::Uygulama '$scene' sahnesinde kapandı"; exit 1; fi

  # Açıklama şeridi Pillow ile resim olarak çizilir (Homebrew ffmpeg'de drawtext yok).
  "$PY" - "$WORK/caption-$index.png" "$FONT" "$caption" <<'EOF'
import sys
from PIL import Image, ImageDraw, ImageFont
out, font_path, text = sys.argv[1], sys.argv[2], sys.argv[3].replace("\\n", "\n")
img = Image.new("RGBA", (720, 250), (0, 0, 0, 184))
draw = ImageDraw.Draw(img)
font = ImageFont.truetype(font_path, 30)
box = draw.multiline_textbbox((0, 0), text, font=font, spacing=10, align="center")
w, h = box[2] - box[0], box[3] - box[1]
draw.multiline_text(((720 - w) / 2 - box[0], (250 - h) / 2 - box[1]), text, font=font, fill="white", spacing=10, align="center")
img.save(out)
EOF
  # Uygulama açılışının ilk saniyesi atlanır; 720 genişliğe küçültülür, altta açıklama şeridi.
  ffmpeg -loglevel error -y -ss 1 -i "$raw" -i "$WORK/caption-$index.png" -t "$seconds" \
    -filter_complex "[0:v]scale=720:-2,fps=30[v];[v][1:v]overlay=0:H-h" \
    -c:v libx264 -pix_fmt yuv420p -preset medium -crf 23 -an "$WORK/seg-$index.mp4"
  echo "file '$WORK/seg-$index.mp4'" >> "$WORK/list.txt"
  echo "Parça $index: $scene ($seconds sn)"
done

ffmpeg -loglevel error -y -f concat -safe 0 -i "$WORK/list.txt" -c copy -movflags +faststart "$OUT/CupTower-review-demo.mp4"
ls -la "$OUT"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/CupTower-review-demo.mp4"

if ls ~/Library/Logs/DiagnosticReports 2>/dev/null | grep -i -E "cuptower"; then
  echo "::error::Çökme raporu bulundu"; exit 1
fi
