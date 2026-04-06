#!/usr/bin/env bash
set -euo pipefail

# ── Colors ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

TOTAL_STEPS=6
step()    { echo -e "\n${BLUE}[$1/$TOTAL_STEPS]${NC} ${CYAN}$2${NC}"; }
success() { echo -e "  ${GREEN}✓ $1${NC}"; }
warn()    { echo -e "  ${YELLOW}⚠ $1${NC}"; }
error()   { echo -e "  ${RED}✗ $1${NC}"; exit 1; }

REPO="LeoManrique/LeoSync"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
TMP_DIR="/tmp/leosync-install"

# ── Step 1: Detect platform ──
step 1 "Detecting platform"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)        ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) error "Unsupported architecture: $ARCH" ;;
esac

case "$OS" in
  darwin) PLATFORM="macOS-$ARCH" ;;
  linux)  PLATFORM="linux-$ARCH" ;;
  *)      error "Unsupported OS: $OS (this script supports macOS and Linux)" ;;
esac
success "Platform: $PLATFORM"

# ── Step 2: Check if LeoSync is running ──
step 2 "Checking for running instances"

if pgrep -x "LeoSync" >/dev/null 2>&1 || pgrep -x "leosync" >/dev/null 2>&1; then
  error "LeoSync is currently running. Please close it before installing/updating."
fi
success "No running instances found"

# ── Step 3: Fetch latest release ──
step 3 "Fetching latest release from GitHub"

RELEASE_JSON=$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "$API_URL" 2>/dev/null) \
  || error "Failed to fetch release info from GitHub. Check your internet connection."

TAG=$(echo "$RELEASE_JSON" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
[ -z "$TAG" ] && error "Could not parse release tag from GitHub API"

VERSION="${TAG#v}"
success "Latest version: $VERSION (tag: $TAG)"

# ── Step 4: Download artifact ──
step 4 "Downloading artifact"

case "$OS" in
  darwin) ARTIFACT="LeoSync-$VERSION-$PLATFORM.zip" ;;
  linux)  ARTIFACT="LeoSync-$VERSION-$PLATFORM.tar.gz" ;;
esac

DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*'"$ARTIFACT"'"' | head -1 | sed 's/.*"browser_download_url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
[ -z "$DOWNLOAD_URL" ] && error "Could not find artifact $ARTIFACT in release $TAG"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

curl -fSL --progress-bar -o "$TMP_DIR/$ARTIFACT" "$DOWNLOAD_URL" \
  || error "Failed to download $ARTIFACT"
success "Downloaded $ARTIFACT"

# ── Step 5: Install ──
step 5 "Installing LeoSync"

case "$OS" in
  darwin)
    unzip -qo "$TMP_DIR/$ARTIFACT" -d "$TMP_DIR"
    if [ -d "/Applications/LeoSync.app" ]; then
      rm -rf "/Applications/LeoSync.app"
      warn "Replaced existing /Applications/LeoSync.app"
    fi
    mv "$TMP_DIR/LeoSync.app" "/Applications/LeoSync.app"
    xattr -cr "/Applications/LeoSync.app" 2>/dev/null || true
    success "Installed to /Applications/LeoSync.app"
    ;;
  linux)
    tar -xzf "$TMP_DIR/$ARTIFACT" -C "$TMP_DIR"
    sudo install -Dm755 "$TMP_DIR/LeoSync" "/usr/local/bin/leosync"
    success "Installed binary to /usr/local/bin/leosync"

    # Desktop entry
    sudo tee "/usr/share/applications/leosync.desktop" > /dev/null <<EOF
[Desktop Entry]
Name=LeoSync
Comment=Cross-platform file sync
Exec=leosync
Icon=leosync
Type=Application
Categories=Utility;Network;
StartupNotify=true
EOF
    success "Created desktop entry"
    ;;
esac

# ── Step 6: Cleanup ──
step 6 "Cleaning up"

rm -rf "$TMP_DIR"
success "Temporary files removed"

echo -e "\n${GREEN}═══ LeoSync $VERSION installed successfully ═══${NC}"
case "$OS" in
  darwin) echo -e "  ${CYAN}Open LeoSync from /Applications or Spotlight${NC}" ;;
  linux)  echo -e "  ${CYAN}Run 'leosync' or find LeoSync in your app launcher${NC}" ;;
esac
