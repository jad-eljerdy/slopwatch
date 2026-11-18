#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

tools="$PWD/.build/artifacts/slopwatch/Sparkle/bin"
account=local.slopwatch.app
plist=Support/Info.plist
expected=$(/usr/bin/plutil -extract SUPublicEDKey raw "$plist")
actual=$("$tools/generate_keys" --account "$account" -p)
if [[ "$actual" != "$expected" ]]; then
    echo "The public key in Info.plist differs from the signing key." >&2
    exit 1
fi
version=$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$plist")
build=$(/usr/bin/plutil -extract CFBundleVersion raw "$plist")
asset="Slopwatch-$version.dmg"
prefix="https://github.com/jad-eljerdy/slopwatch/releases/download/v$version/"
stage=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/slopwatch-feed.XXXXXX")
trap '/bin/rm -rf "$stage"' EXIT
/bin/cp "dist/$asset" "$stage/$asset"
"$tools/generate_appcast" --account "$account" --maximum-deltas 0 --download-url-prefix "$prefix" "$stage"
"$tools/sign_update" --account "$account" --verify "$stage/appcast.xml"
signature=$(python3 - "$stage/appcast.xml" "$prefix$asset" "$build" "$version" "$stage/$asset" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET

feed, url, build, version, archive = sys.argv[1:]
sparkle = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
items = ET.parse(feed).findall("./channel/item")
if len(items) != 1:
    sys.exit("Expected one release in the update feed.")
item = items[0]
asset = item.find("enclosure")
if (asset is None or asset.get("url") != url or asset.get("length") != str(pathlib.Path(archive).stat().st_size)
        or item.findtext(sparkle + "version") != build or item.findtext(sparkle + "shortVersionString") != version):
    sys.exit("The update feed does not match the packaged release.")
print(asset.attrib[sparkle + "edSignature"])
PY
)
"$tools/sign_update" --account "$account" --verify "$stage/$asset" "$signature"
/bin/mv "$stage/appcast.xml" dist/appcast.xml
echo "$PWD/dist/appcast.xml"
