#!/usr/bin/env bash
# Builds dist/GoblinPawnStars-<version>.zip from the addon folder.
# The archive contains a single GoblinPawnStars/ directory, which is exactly what
# goes into Interface/AddOns.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON_DIR="$ROOT/addon/GoblinPawnStars"
TOC="$ADDON_DIR/GoblinPawnStars.toc"

if [[ ! -f "$TOC" ]]; then
    echo "error: TOC not found at $TOC" >&2
    exit 1
fi

VERSION="$(grep -m1 '^## Version:' "$TOC" | sed 's/^## Version:[[:space:]]*//' | tr -d '\r')"
if [[ -z "$VERSION" ]]; then
    echo "error: could not read version from TOC" >&2
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/GoblinPawnStars"
mkdir -p "$ROOT/dist"

# Copy only shippable files.
while IFS= read -r -d '' file; do
    relative="${file#"$ADDON_DIR"/}"
    mkdir -p "$STAGE/GoblinPawnStars/$(dirname "$relative")"
    cp "$file" "$STAGE/GoblinPawnStars/$relative"
done < <(find "$ADDON_DIR" -type f ! -name '.DS_Store' ! -name '*.zip' -print0)

cp "$ROOT/README.md" "$STAGE/GoblinPawnStars/README.md"
cp "$ROOT/CHANGELOG.md" "$STAGE/GoblinPawnStars/CHANGELOG.md"

# Repository docs referenced by the README, kept alongside it inside the ZIP so
# the banner and testing checklist still resolve after extraction.
for extra in TESTING.md LICENSE AI-DISCLOSURE.md docs/assets/banner.svg \
    docs/screenshots/*.png docs/screenshots/README.md; do
    if [[ -f "$ROOT/$extra" ]]; then
        mkdir -p "$STAGE/GoblinPawnStars/$(dirname "$extra")"
        cp "$ROOT/$extra" "$STAGE/GoblinPawnStars/$extra"
    fi
done

ZIP="$ROOT/dist/GoblinPawnStars-$VERSION.zip"
rm -f "$ZIP"
(
    cd "$STAGE"
    if command -v zip >/dev/null 2>&1; then
        zip -qr "$ZIP" GoblinPawnStars -x '*.DS_Store' -x '__MACOSX/*'
    elif command -v 7z >/dev/null 2>&1; then
        # Windows Git Bash often ships 7-Zip but not Info-ZIP. 7z writes proper
        # forward-slash zip entries, unlike Compress-Archive on some versions.
        7z a -tzip -mx=9 "$ZIP" GoblinPawnStars >/dev/null
    else
        echo "error: neither zip nor 7z is available" >&2
        exit 1
    fi
)

echo "Built $ZIP"
unzip -l "$ZIP" | tail -n 3
