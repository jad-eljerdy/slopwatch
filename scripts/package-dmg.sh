#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

zsh scripts/build.sh --arch arm64 --arch x86_64
app="$PWD/dist/Slopwatch.app"
version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist")
dmg="$PWD/dist/Slopwatch-$version.dmg"
for arch in arm64 x86_64; do
    /usr/bin/lipo "$app/Contents/MacOS/Slopwatch" -verify_arch "$arch"
done
/usr/bin/codesign --verify --strict --all-architectures "$app"

stage=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/slopwatch-dmg.XXXXXX")
trap '/bin/rm -rf "$stage"' EXIT
installer="$PWD/Support/Installer"
tools="$PWD/.build/dmg-tools"
if [[ ! -x "$tools/bin/python" ]]; then
    python3 -m venv "$tools"
fi
"$tools/bin/python" -m pip --disable-pip-version-check install -q -r "$installer/requirements.txt"
swift "$installer/draw-background.swift" "$version" "$stage"
"$tools/bin/dmgbuild" -s "$installer/settings.py" -D "app=$app" \
    -D "background=$stage/background.png" Slopwatch "$stage/release.dmg"
/usr/bin/hdiutil verify "$stage/release.dmg"
/bin/mv -f "$stage/release.dmg" "$dmg"
/usr/bin/shasum -a 256 "$dmg"
