#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
CATALOG_DIR="$APP_ROOT/assets/models/zamer_catalog"
mkdir -p "$CATALOG_DIR"

fetch_glb() {
  local id="$1"
  local url="$2"
  local tmp
  tmp="$(mktemp)"
  echo "[cc0-furniture] fetching $id"
  curl --fail --location --silent --show-error \
    --retry 4 --retry-delay 2 --connect-timeout 20 --max-time 180 \
    "$url" -o "$tmp"
  test -s "$tmp"
  mv "$tmp" "$CATALOG_DIR/$id.glb"
}

install_all_lods() {
  local id="$1"
  cp "$CATALOG_DIR/$id.glb" "$CATALOG_DIR/${id}_lod1.glb"
  cp "$CATALOG_DIR/$id.glb" "$CATALOG_DIR/${id}_lod2.glb"
}

# CC0 1.0 Universal.
# Upholstered king bed with headboard, duvet, pillows, bolster and runner.
# Source: https://3dassets.dev/assets/hotel-and-resort-operations-bed-king-upholstered-819ff50d
fetch_glb "bed-160" "https://cdn.3dassets.dev/assets/25738/v1/model.glb"
install_all_lods "bed-160"
cp "$CATALOG_DIR/bed-160.glb" "$CATALOG_DIR/bed-180.glb"
cp "$CATALOG_DIR/bed-160.glb" "$CATALOG_DIR/bed-180_lod1.glb"
cp "$CATALOG_DIR/bed-160.glb" "$CATALOG_DIR/bed-180_lod2.glb"

# CC0 1.0 Universal.
# Three-seat lobby sofa with separate seat/back cushions and bolster arms.
# Source: https://3dassets.dev/assets/hotel-and-resort-operations-lobby-sofa-79174bf1
fetch_glb "sofa-3" "https://cdn.3dassets.dev/assets/25866/v1/model.glb"
install_all_lods "sofa-3"

echo "[cc0-furniture] installed bed-160, bed-180 and sofa-3 for LOD0/1/2"
