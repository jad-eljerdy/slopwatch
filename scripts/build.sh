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
/usr/bin/codesign --force --sign - --timestamp=none "$app"
/usr/bin/codesign --verify --strict "$app"
echo "$app"
