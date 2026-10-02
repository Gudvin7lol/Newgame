#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHUNK_DIR="$SCRIPT_DIR/chunks"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

B64="$TMP_DIR/zamer_import_ultra.b64"
ZIP="$TMP_DIR/zamer_import_ultra.zip"
EXPECTED_SHA="52a945c9a5dac10fcbdc98600da80ba8f25d96f5cf0c07a6d9a575a8788876ef"

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

: > "$B64"
for part in "${parts[@]}"; do
  test -s "$CHUNK_DIR/$part"
  cat "$CHUNK_DIR/$part" >> "$B64"
done

python3 - "$B64" "$ZIP" "$EXPECTED_SHA" "$CHUNK_DIR" <<'PY'
from __future__ import annotations

import base64
import hashlib
import sys
from pathlib import Path

b64_path = Path(sys.argv[1])
zip_path = Path(sys.argv[2])
expected = sys.argv[3]
chunk_dir = Path(sys.argv[4])
raw = b64_path.read_text().replace('\n', '').replace('\r', '')


def matches(encoded: str) -> bytes | None:
    try:
        decoded = base64.b64decode(encoded, validate=True)
    except Exception:
        return None
    if hashlib.sha256(decoded).hexdigest() == expected:
        return decoded
    return None

# Normal path for an intact pack.
decoded = matches(raw)
if decoded is not None:
    zip_path.write_bytes(decoded)
    print('Import pack SHA verified without recovery.')
    raise SystemExit(0)

# One connector write produced part_08b1 with 2047 bytes instead of the
# intended 2048. Recover the single missing base64 symbol, but accept a
# candidate only when the complete ZIP matches the pinned SHA-256.
part_names = [
    'part_00a.b64', 'part_00b.b64', 'part_01.b64', 'part_02.b64',
    'part_03.b64', 'part_04.b64', 'part_05.b64', 'part_06.b64',
    'part_07.b64', 'part_08a.b64',
]
prefix_len = sum(len((chunk_dir / name).read_text().replace('\n', '').replace('\r', '')) for name in part_names)
broken = (chunk_dir / 'part_08b1.b64').read_text().replace('\n', '').replace('\r', '')
if len(broken) != 2047 or len(raw) % 4 != 3:
    raise SystemExit('Import pack is corrupt in an unexpected way; refusing recovery.')

alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
# A truncation at a connector split is most likely near the split edge, so
# test edge positions first, then the full chunk as a deterministic fallback.
positions = list(range(max(0, len(broken) - 32), len(broken) + 1))
positions += [p for p in range(len(broken) + 1) if p not in set(positions)]

for local_pos in positions:
    absolute = prefix_len + local_pos
    for symbol in alphabet:
        candidate = raw[:absolute] + symbol + raw[absolute:]
        decoded = matches(candidate)
        if decoded is not None:
            zip_path.write_bytes(decoded)
            print(f'Recovered missing base64 symbol at part_08b1 offset {local_pos}; SHA verified.')
            raise SystemExit(0)

raise SystemExit('Unable to recover import pack to the pinned SHA-256.')
PY

unzip -t "$ZIP" >/dev/null
python3 "$SCRIPT_DIR/apply_import.py" "$ZIP"
echo "Imported visual pack restored and source integration applied."
