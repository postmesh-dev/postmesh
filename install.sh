#!/bin/sh
set -eu

APP_NAME="postmesh"
VERSION="${POSTMESH_VERSION:-latest}"
INSTALL_DIR="${POSTMESH_INSTALL_DIR:-$HOME/.local/bin}"

REPO="postmesh-dev/postmesh"
SYMLINK="$INSTALL_DIR/$APP_NAME"
INSTALL_JSON="$INSTALL_DIR/install.json"
VERSIONS_DIR="$INSTALL_DIR/versions"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$OS" in
  darwin) PLATFORM="darwin" ;;
  linux)  PLATFORM="linux"  ;;
  *)      echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

case "$ARCH" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="x64"   ;;
  *)             echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

PLATFORM_KEY="${PLATFORM}-${ARCH}"

API_HEADER="Accept: application/vnd.github.v3.raw"

if [ "$VERSION" = "latest" ]; then
  MANIFEST=$(curl -fsSL -H "$API_HEADER" "https://api.github.com/repos/${REPO}/contents/artifacts/latest.json" 2>/dev/null || curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/artifacts/latest.json")
  DESIRED_VERSION=$(echo "$MANIFEST" | sed -n 's/.*"latestStable": *"\([^"]*\)".*/\1/p')
else
  MANIFEST=$(curl -fsSL -H "$API_HEADER" "https://api.github.com/repos/${REPO}/contents/artifacts/releases/${VERSION}.json" 2>/dev/null || curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/artifacts/releases/${VERSION}.json")
  DESIRED_VERSION="$VERSION"
fi

DESIRED_ASSET="postmesh-${DESIRED_VERSION}-${PLATFORM_KEY}.tar.gz"
DESIRED_URL="https://github.com/${REPO}/releases/download/v${DESIRED_VERSION}/${DESIRED_ASSET}"
DESIRED_SHA=$(echo "$MANIFEST" | sed -n '/"'"${PLATFORM_KEY}"'":/,/},/ s/.*"sha256": *"\([^"]*\)".*/\1/p')

if [ -z "$DESIRED_SHA" ]; then
  echo "No asset for ${PLATFORM_KEY} in release ${DESIRED_VERSION}" >&2
  exit 1
fi

INSTALLED_VERSION=""
INSTALLED_SHA=""

if [ -f "$INSTALL_JSON" ]; then
  INSTALLED_VERSION=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$INSTALL_JSON")
  INSTALLED_SHA=$(sed -n 's/.*"archiveSha256": *"\([^"]*\)".*/\1/p' "$INSTALL_JSON")
fi

ACTIVE_VERSION=""
if [ -L "$SYMLINK" ]; then
  ACTIVE_VERSION=$(readlink "$SYMLINK" 2>/dev/null || echo "")
  ACTIVE_VERSION="${ACTIVE_VERSION#versions/}"
  ACTIVE_VERSION="${ACTIVE_VERSION%/postmesh}"
fi

if [ "$DESIRED_VERSION" = "$INSTALLED_VERSION" ] && [ "$ACTIVE_VERSION" = "$INSTALLED_VERSION" ] && [ -f "$SYMLINK" ]; then
  if [ "$INSTALLED_SHA" = "$DESIRED_SHA" ]; then
    echo "$APP_NAME v$DESIRED_VERSION already installed"
    exit 0
  fi
  echo "Checksum mismatch, reinstalling..."
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading $APP_NAME v$DESIRED_VERSION for $PLATFORM_KEY..."
curl -fsSL "$DESIRED_URL" -o "$TMP_DIR/$DESIRED_ASSET"

echo "Verifying checksum..."
if command -v sha256sum >/dev/null 2>&1; then
  ARCHIVE_SHA=$(sha256sum "$TMP_DIR/$DESIRED_ASSET" | cut -d' ' -f1)
else
  ARCHIVE_SHA=$(shasum -a 256 "$TMP_DIR/$DESIRED_ASSET" | cut -d' ' -f1)
fi

if [ "$ARCHIVE_SHA" != "$DESIRED_SHA" ]; then
  echo "Checksum mismatch: expected $DESIRED_SHA, got $ARCHIVE_SHA" >&2
  exit 1
fi

STAGING="$TMP_DIR/staging"
mkdir -p "$STAGING"
tar -xzf "$TMP_DIR/$DESIRED_ASSET" -C "$STAGING"

VERSION_DIR="v$DESIRED_VERSION"
TARGET="$VERSIONS_DIR/$VERSION_DIR"
TARGET_TMP="$TMP_DIR/target"
TARGET_STAGE="$TMP_DIR/target-install"

mkdir -p "$TARGET_TMP"
cp "$STAGING/$APP_NAME" "$TARGET_TMP/$APP_NAME"
chmod +x "$TARGET_TMP/$APP_NAME"

mkdir -p "$VERSIONS_DIR"
rm -rf "$TARGET_STAGE"
mkdir -p "$TARGET_STAGE"
mv "$TARGET_TMP/$APP_NAME" "$TARGET_STAGE/$APP_NAME"
mkdir -p "$TARGET"
mv "$TARGET_STAGE/$APP_NAME" "$TARGET/$APP_NAME"

ln -sf "versions/$VERSION_DIR/$APP_NAME" "$SYMLINK"

INSTALL_JSON_TMP="$TMP_DIR/install.json"
cat > "$INSTALL_JSON_TMP" <<EOF
{
  "version": "$DESIRED_VERSION",
  "archiveSha256": "$ARCHIVE_SHA"
}
EOF

mkdir -p "$INSTALL_DIR"
mv "$INSTALL_JSON_TMP" "$INSTALL_JSON"

echo "Installed $APP_NAME v$DESIRED_VERSION to $SYMLINK"

case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    echo "Run: $APP_NAME help"
    ;;
  *)
    echo
    echo "$INSTALL_DIR is not on your PATH."
    echo "Add this to your shell profile:"
    echo
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo
    echo "Then restart your shell and run:"
    echo
    echo "  $APP_NAME help"
    ;;
esac
