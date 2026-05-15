#!/usr/bin/env bash
# Fetches the latest bufo asset collection from https://github.com/tfritzy/bufo.fun
# and copies the images and bufo-data.json into Resources/.
set -euo pipefail

REPO_URL="https://github.com/tfritzy/bufo.fun.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_DIR="$ROOT_DIR/Resources"
TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

echo "Cloning $REPO_URL ..."
git clone --depth 1 "$REPO_URL" "$TMP_DIR/bufo.fun"

SRC="$TMP_DIR/bufo.fun/site/public"

if [[ ! -d "$SRC/bufos" ]]; then
  echo "Could not find bufos/ in upstream layout" >&2
  exit 1
fi

mkdir -p "$DEST_DIR/Bufos"
rm -f "$DEST_DIR/Bufos/"*.png "$DEST_DIR/Bufos/"*.gif "$DEST_DIR/Bufos/"*.jpg "$DEST_DIR/Bufos/"*.jpeg 2>/dev/null || true

cp "$SRC"/bufos/*.png "$SRC"/bufos/*.gif "$SRC"/bufos/*.jpg "$SRC"/bufos/*.jpeg "$DEST_DIR/Bufos/" 2>/dev/null || true
cp "$SRC/bufo-data.json" "$DEST_DIR/bufo-data.json"

COUNT=$(find "$DEST_DIR/Bufos" -type f \( -name '*.png' -o -name '*.gif' -o -name '*.jpg' -o -name '*.jpeg' \) | wc -l | tr -d ' ')
echo "Fetched $COUNT bufo assets into $DEST_DIR/Bufos"
