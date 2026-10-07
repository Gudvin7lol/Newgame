#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-assets/textures/pbr12}"

command -v ktx >/dev/null 2>&1 || {
  echo "ktx CLI is required" >&2
  exit 2
}

count=0
while IFS= read -r -d '' src; do
  dst="${src%.png}.ktx2"
  name="$(basename "$src")"
  normal_args=()
  case "$name" in
    basecolor.png)
      format="R8G8B8A8_SRGB"
      transfer="srgb"
      ;;
    normal.png)
      format="R8G8B8A8_UNORM"
      transfer="linear"
      normal_args=(--normalize --normal-mode)
      ;;
    orm.png)
      format="R8G8B8A8_UNORM"
      transfer="linear"
      normal_args=()
      ;;
    *)
      continue
      ;;
  esac

  rm -f "$dst"
  ktx create \
    --format "$format" \
    --generate-mipmap \
    --mipmap-wrap wrap \
    --encode uastc \
    --uastc-quality 2 \
    --zstd 12 \
    --assign-tf "$transfer" \
    "${normal_args[@]}" \
    "$src" "$dst"
  ktx validate "$dst" >/dev/null
  count=$((count + 1))
done < <(
  find "$ROOT" -type f \
    \( -path '*/performance/basecolor.png' -o \
       -path '*/performance/normal.png' -o \
       -path '*/performance/orm.png' -o \
       -path '*/quality/basecolor.png' -o \
       -path '*/quality/normal.png' -o \
       -path '*/quality/orm.png' \) \
    -print0
)

if (( count < 72 )); then
  echo "Expected at least 72 KTX2 textures, cooked $count" >&2
  exit 3
fi
echo "Cooked and validated $count UASTC KTX2 textures."
