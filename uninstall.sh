#!/bin/sh
set -eu

APP="postmesh"
PURGE="false"

for arg in "$@"; do
  case "$arg" in
    --purge) PURGE="true" ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

BIN_DIR="${POSTMESH_INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${POSTMESH_MODELS_PATH:-$HOME/.local/share/postmesh}"

echo "Uninstalling $APP..."

rm -f "$BIN_DIR/$APP"
rm -f "$BIN_DIR/install.json"
rm -rf "$BIN_DIR/versions"

if [ "$PURGE" = "true" ]; then
  echo "Purging data, including models..."
  rm -rf "$DATA_DIR"
else
  echo "Kept data (models, config): $DATA_DIR"
  echo
  echo "To remove everything, run:"
  echo "  curl -fsSL https://raw.githubusercontent.com/postmesh-dev/postmesh/refs/tags/latest/uninstall.sh | sh -s -- --purge"
fi

echo "Uninstalled $APP."
