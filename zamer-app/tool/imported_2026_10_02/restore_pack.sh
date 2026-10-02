#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHUNK_DIR="$SCRIPT_DIR/chunks"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

B64="$TMP_DIR/zamer_import_ultra.b64"
ZIP="$TMP_DIR/zamer_import_ultra.zip"
: > "$B64"

parts=(
  part_00a.b64
  part_00b.b64
  part_01.b64
  part_02.b64
  part_03.b64
  part_04.b64
  part_05.b64
  part_06.b64
  part_07.b64
  part_08a.b64
  part_08b1.b64
  part_08b2.b64
  part_09.b64
  part_10.b64
  part_11.b64
  part_12.b64
  part_13a.b64
  part_14.b64
)

for part in "${parts[@]}"; do
  test -s "$CHUNK_DIR/$part"
  cat "$CHUNK_DIR/$part" >> "$B64"
done

base64 --decode "$B64" > "$ZIP"
echo "52a945c9a5dac10fcbdc98600da80ba8f25d96f5cf0c07a6d9a575a8788876ef  $ZIP" | sha256sum -c -
unzip -t "$ZIP" >/dev/null

python3 "$SCRIPT_DIR/apply_import.py" "$ZIP"
echo "Imported visual pack restored and source integration applied."
