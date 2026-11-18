#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
bin=$(swift build -c release --show-bin-path)
app="$PWD/dist/Slopwatch.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
install -m 755 "$bin/Slopwatch" "$app/Contents/MacOS/Slopwatch"
install -m 644 Support/Info.plist "$app/Contents/Info.plist"
install -m 644 Sources/Slopwatch/Resources/rates.tsv Support/claude-statusline.sh "$app/Contents/Resources/"
iconset="$PWD/.build/Slopwatch.iconset"
mkdir -p "$iconset"
swift scripts/draw-icon.swift "$PWD/.build/Slopwatch-icon.png"
for size in 16 32 128 256 512; do
    /usr/bin/sips -z "$size" "$size" .build/Slopwatch-icon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    /usr/bin/sips -z "$((size * 2))" "$((size * 2))" .build/Slopwatch-icon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$iconset" -o "$app/Contents/Resources/Slopwatch.icns"
/usr/bin/codesign --force --sign - --timestamp=none "$app"
/usr/bin/codesign --verify --strict "$app"
echo "$app"
