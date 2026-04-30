#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT_DIR/src/export-searchkit.sh"
BUILD_DIR="$ROOT_DIR/build"
OUT="$ROOT_DIR/export-searchkit"

command -v argc >/dev/null 2>&1 || {
  echo "Error: argc is required only for building." >&2
  echo "Install with: brew install argc" >&2
  echo "Server does NOT need argc after build." >&2
  exit 1
}

[[ -f "$SRC" ]] || {
  echo "Error: source file missing: $SRC" >&2
  exit 1
}

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

argc --argc-build "$SRC" "$BUILD_DIR"

BUILT="$BUILD_DIR/$(basename "$SRC")"

[[ -f "$BUILT" ]] || {
  echo "Error: expected built file not found: $BUILT" >&2
  ls -la "$BUILD_DIR" >&2
  exit 1
}

cp "$BUILT" "$OUT"
chmod +x "$OUT"

rm -rf "$BUILD_DIR"

echo "Built: $OUT"