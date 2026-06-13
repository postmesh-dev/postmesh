#!/bin/sh
set -eu

APP_NAME="postmesh"
VERSION="${INSTALL_VERSION:-${POSTMESH_VERSION:-latest}}"
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

# ── Resolve version and asset info ──────────────────────────
if [ -n "${POSTMESH_INSTALL_ARCHIVE:-}" ]; then
  if [ ! -f "$POSTMESH_INSTALL_ARCHIVE" ]; then
    echo "POSTMESH_INSTALL_ARCHIVE not found: $POSTMESH_INSTALL_ARCHIVE" >&2
    exit 1
  fi
  DESIRED_VERSION="${INSTALL_VERSION:-0.0.0-local}"
  DESIRED_ASSET="$(basename "$POSTMESH_INSTALL_ARCHIVE")"
  DESIRED_SHA="${POSTMESH_INSTALL_ARCHIVE_SHA:-}"
else
  if [ "$VERSION" = "latest" ]; then
    MANIFEST=$(curl -fsSL -H "$API_HEADER" "https://api.github.com/repos/${REPO}/contents/artifacts/latest.json" 2>/dev/null || curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/artifacts/latest.json")
    DESIRED_VERSION=$(echo "$MANIFEST" | grep -o '"latestStable"[^,]*' | sed 's/.*"\([^"]*\)"$/\1/')
    if [ -z "$DESIRED_VERSION" ]; then
      echo "No stable release available. Use INSTALL_VERSION=<version> to install a specific release candidate." >&2
      exit 1
    fi
  else
    MANIFEST=$(curl -fsSL -H "$API_HEADER" "https://api.github.com/repos/${REPO}/contents/artifacts/releases/${VERSION}.json" 2>/dev/null || curl -fsSL "https://raw.githubusercontent.com/${REPO}/main/artifacts/releases/${VERSION}.json")
    DESIRED_VERSION="$VERSION"
  fi

  DESIRED_ASSET="postmesh-${DESIRED_VERSION}-${PLATFORM_KEY}.tar.gz"
  DESIRED_URL="https://github.com/${REPO}/releases/download/v${DESIRED_VERSION}/${DESIRED_ASSET}"
  DESIRED_SHA=$(echo "$MANIFEST" | awk -v asset="$DESIRED_ASSET" '
    index($0, asset) { found = 1 }
    found && index($0, "\"sha256\"") {
      line = $0
      sub(/^.*"sha256"[[:space:]]*:[[:space:]]*"/, "", line)
      sub(/".*$/, "", line)
      print line
      exit
    }
  ')

  if [ -z "$DESIRED_SHA" ]; then
    echo "No asset for ${PLATFORM_KEY} in release ${DESIRED_VERSION}" >&2
    exit 1
  fi
  if ! echo "$DESIRED_SHA" | grep -Eq '^[0-9a-f]{64}$'; then
    echo "Invalid checksum metadata for ${DESIRED_ASSET}: ${DESIRED_SHA}" >&2
    exit 1
  fi
fi

# ── Check if already installed ──────────────────────────────
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

# ── Download or copy the archive ────────────────────────────
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [ -n "${POSTMESH_INSTALL_ARCHIVE:-}" ]; then
  cp "$POSTMESH_INSTALL_ARCHIVE" "$TMP_DIR/$DESIRED_ASSET"
elif [ -n "${POSTMESH_ARCHIVE_DIR:-}" ]; then
  if [ ! -f "$POSTMESH_ARCHIVE_DIR/$DESIRED_ASSET" ]; then
    echo "Archive not found: $POSTMESH_ARCHIVE_DIR/$DESIRED_ASSET" >&2
    exit 1
  fi
  cp "$POSTMESH_ARCHIVE_DIR/$DESIRED_ASSET" "$TMP_DIR/$DESIRED_ASSET"
else
  echo "Downloading $APP_NAME v$DESIRED_VERSION for $PLATFORM_KEY..."
  curl -fsSL "$DESIRED_URL" -o "$TMP_DIR/$DESIRED_ASSET"
fi

# ── Verify checksum ─────────────────────────────────────────
if [ -n "${DESIRED_SHA:-}" ]; then
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
else
  ARCHIVE_SHA="local"
fi

# ── Install ─────────────────────────────────────────────────
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
if [ -f "$STAGING/postmesh-migrate" ]; then
  cp "$STAGING/postmesh-migrate" "$TARGET_TMP/postmesh-migrate"
  chmod +x "$TARGET_TMP/postmesh-migrate"
fi

mkdir -p "$VERSIONS_DIR"
rm -rf "$TARGET_STAGE"
mkdir -p "$TARGET_STAGE"
mv "$TARGET_TMP/$APP_NAME" "$TARGET_STAGE/$APP_NAME"
if [ -f "$TARGET_TMP/postmesh-migrate" ]; then
  mv "$TARGET_TMP/postmesh-migrate" "$TARGET_STAGE/postmesh-migrate"
fi
mkdir -p "$TARGET"
mv "$TARGET_STAGE/$APP_NAME" "$TARGET/$APP_NAME"
if [ -f "$TARGET_STAGE/postmesh-migrate" ]; then
  mv "$TARGET_STAGE/postmesh-migrate" "$TARGET/postmesh-migrate"
fi

ln -sf "versions/$VERSION_DIR/$APP_NAME" "$SYMLINK"

# Run database migration on the main database
MIGRATE_BIN="$TARGET/postmesh-migrate"
if [ -f "$MIGRATE_BIN" ]; then
  echo "Running database migration..."
  "$MIGRATE_BIN" 2>&1 || echo "Warning: database migration failed" >&2
fi

# Install shell completions (only for the user's current shell by default)
SHELL_NAME="${SHELL##*/}"
BASH_COMPLETIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
ZSH_COMPLETIONS_DIR="${ZDOTDIR:-$HOME}/.zsh/completions"

install_completion() {
  local shell="$1"
  local target="$2"
  local tmpf="$TMP_DIR/${shell}-completion"
  "$TARGET/$APP_NAME" completion --shell "$shell" > "$tmpf" 2>/dev/null || true
  if ! cmp -s "$target" "$tmpf" 2>/dev/null; then
    mv "$tmpf" "$target"
    if [ "$shell" = "zsh" ]; then
      echo "  fpath+=\"$ZSH_COMPLETIONS_DIR\"  # add to ~/.zshrc before compinit"
    else
      echo "  source $target"
    fi
  else
    rm -f "$tmpf"
  fi
}

case "$SHELL_NAME" in
  bash)
    mkdir -p "$BASH_COMPLETIONS_DIR"
    install_completion bash "$BASH_COMPLETIONS_DIR/$APP_NAME"
    ;;
  zsh)
    mkdir -p "$ZSH_COMPLETIONS_DIR"
    install_completion zsh "$ZSH_COMPLETIONS_DIR/_$APP_NAME"
    ;;
  *)
    # Unknown shell — install both as best-effort
    mkdir -p "$BASH_COMPLETIONS_DIR"
    install_completion bash "$BASH_COMPLETIONS_DIR/$APP_NAME"
    mkdir -p "$ZSH_COMPLETIONS_DIR"
    install_completion zsh "$ZSH_COMPLETIONS_DIR/_$APP_NAME"
    ;;
esac

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
