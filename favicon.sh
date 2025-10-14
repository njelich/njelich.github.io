#!/bin/bash

# === Colors ===
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
  echo -e "${BLUE}➤${NC} $1"
}

info() {
  echo -e "${YELLOW}ℹ${NC} $1"
}

success() {
  echo -e "${GREEN}✔${NC} $1"
}

error() {
  echo -e "${RED}✖${NC} $1"
}

# === Validate Input ===
if [ -z "$1" ]; then
  error "Please provide an image filename (e.g., ./favicon-generator.sh logo.png)"
  exit 1
fi

INPUT_IMAGE="$1"

if [ ! -f "$INPUT_IMAGE" ]; then
  error "Image file '$INPUT_IMAGE' not found!"
  exit 1
fi

# === Dependency Checks ===
for cmd in magick pngcrush; do
  if ! command -v $cmd &>/dev/null; then
    error "$cmd is not installed. On Fedora, run: sudo dnf install $cmd"
    exit 1
  fi
done

# === Setup ===
BASE_NAME=$(basename "$INPUT_IMAGE" | sed 's/\.[^.]*$//')
OUTPUT_DIR="./$BASE_NAME"
TMP_DIR="/tmp/favicon-gen-$BASE_NAME"

mkdir -p "$TMP_DIR" "$OUTPUT_DIR"

# === Icon Size Arrays ===
FAVICON_SIZES=("16" "32" "48" "64" "128" "192" "256" "512")
APPLE_TOUCH_SIZES=("57" "60" "72" "76" "83" "114" "120" "144" "152" "167" "180")
APPLE_ICON_SIZES=("${APPLE_TOUCH_SIZES[@]}")
MS_ICON_SIZES=("70" "144" "150" "310")
GENERIC_ICON_SIZES=("16" "32" "96" "192")
ANDROID_ICON_SIZE=("36" "48" "72" "96" "144" "192" "512")
WEB_MANIFEST_SIZE=("192" "512")

# === Generate Favicon PNGs ===
log "Generating favicons..."
for SIZE in "${FAVICON_SIZES[@]}"; do
  magick "$INPUT_IMAGE" -resize "${SIZE}x${SIZE}" "$TMP_DIR/favicon-${SIZE}x${SIZE}.png"
done
success "Favicon PNGs generated."

# === Generate favicon.ico ===
log "Generating favicon.ico..."
magick "${TMP_DIR}/favicon-16x16.png" "${TMP_DIR}/favicon-32x32.png" "${TMP_DIR}/favicon-48x48.png" \
       "${TMP_DIR}/favicon-64x64.png" "${TMP_DIR}/favicon-128x128.png" "${TMP_DIR}/favicon-192x192.png" \
       "${TMP_DIR}/favicon-256x256.png" "${TMP_DIR}/favicon-512x512.png" \
       "$TMP_DIR/favicon.ico"
success "favicon.ico generated."

# === Apple Touch Icons ===
log "Generating apple-touch-icon-*..."
for SIZE in "${APPLE_TOUCH_SIZES[@]}"; do
  magick "$INPUT_IMAGE" -resize "${SIZE}x${SIZE}" "$TMP_DIR/apple-touch-icon-${SIZE}x${SIZE}.png"
done
success "Apple Touch Icons generated."

# === Apple Icons ===
log "Generating apple-icon-*..."
for SIZE in "${APPLE_ICON_SIZES[@]}"; do
  magick "$INPUT_IMAGE" -resize "${SIZE}x${SIZE}" "$TMP_DIR/apple-icon-${SIZE}x${SIZE}.png"
done
success "Apple Icons generated."

# === Microsoft Tiles ===
log "Generating ms-icon-*..."
for SIZE in "${MS_ICON_SIZES[@]}"; do
  magick "$INPUT_IMAGE" -resize "${SIZE}x${SIZE}" "$TMP_DIR/ms-icon-${SIZE}x${SIZE}.png"
done
success "Microsoft icons generated."

# === Generic icon-* ===
log "Generating icon-*..."
for SIZE in "${GENERIC_ICON_SIZES[@]}"; do
  magick "$INPUT_IMAGE" -resize "${SIZE}x${SIZE}" "$TMP_DIR/icon-${SIZE}x${SIZE}.png"
done
success "Generic icons generated."

# === Android Chrome Icon ===
log "Generating android-chrome-* icons..."
for SIZE in "${ANDROID_ICON_SIZE[@]}"; do
  magick "$INPUT_IMAGE" -resize "${SIZE}x${SIZE}" "$TMP_DIR/android-chrome-${SIZE}x${SIZE}.png"
done
success "Android Chrome icons generated."

# === Web Manifest Icons ===
log "Generating web-app-manifest-* icons..."
WEB_MANIFEST_SIZES=("192" "512")
for SIZE in "${WEB_MANIFEST_SIZES[@]}"; do
  magick "$INPUT_IMAGE" -resize "${SIZE}x${SIZE}" "$TMP_DIR/web-app-manifest-${SIZE}x${SIZE}.png"
done
success "Web App Manifest icons generated."

# === Compress PNG Files ===
log "Compressing PNG files with pngcrush..."
for FILE in "$TMP_DIR"/*.png; do
  BASENAME=$(basename "$FILE")
  pngcrush -brute -reduce "$FILE" "$OUTPUT_DIR/$BASENAME" > /dev/null 2>&1
done
success "PNG files compressed."

# === Move favicon.ico ===
mv "$TMP_DIR/favicon.ico" "$OUTPUT_DIR/"

info "All icons saved in: ${OUTPUT_DIR}"
success "Icon generation complete! 🎉"