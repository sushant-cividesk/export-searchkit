#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${REPO:-sushant-cividesk/export-searchkit}"
BIN="${BIN:-export-searchkit}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

TMP_FILE="$(mktemp)"
URL="https://github.com/${REPO}/releases/latest/download/${BIN}"

cleanup() {
  rm -f "$TMP_FILE" 2>/dev/null || true
}
trap cleanup EXIT

echo "Downloading latest ${BIN} from:"
echo "  ${URL}"

curl -fsSL "$URL" -o "$TMP_FILE"
chmod +x "$TMP_FILE"

if [[ -w "$INSTALL_DIR" ]]; then
  install -m 0755 "$TMP_FILE" "$INSTALL_DIR/$BIN"
else
  sudo install -m 0755 "$TMP_FILE" "$INSTALL_DIR/$BIN"
fi

echo "Installed: $INSTALL_DIR/$BIN"
"$INSTALL_DIR/$BIN" --help