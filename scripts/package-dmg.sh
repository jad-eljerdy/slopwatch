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
/bin/mkdir "$stage/volume"
/usr/bin/ditto --norsrc --noextattr "$app" "$stage/volume/Slopwatch.app"
/bin/ln -s /Applications "$stage/volume/Applications"
/usr/bin/hdiutil create -fs HFS+ -format UDZO -volname Slopwatch -srcfolder "$stage/volume" "$stage/release.dmg"
/usr/bin/hdiutil verify "$stage/release.dmg"
/bin/mv -f "$stage/release.dmg" "$dmg"
/usr/bin/shasum -a 256 "$dmg"
