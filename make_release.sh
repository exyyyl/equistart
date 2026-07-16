#!/bin/bash

# --- Color Codes ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

set -euo pipefail

VERSION="1.3.0"
RELEASE_NAME="equistart-v$VERSION"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo -e "${CYAN}[*] Creating release v$VERSION...${NC}"

create_archive() {
    local platform="$1"
    local guide="$2"
    shift 2
    local archive="${RELEASE_NAME}-${platform}.zip"
    local stage="$BUILD_DIR/$platform"

    echo -e "${CYAN}[*] Creating archive $archive...${NC}"
    rm -f "$archive"
    mkdir -p "$stage"
    cp "$@" "$stage/"
    cp "$guide" "$stage/README.md"
    (cd "$stage" && zip -q "$OLDPWD/$archive" ./*)
    echo -e "${GREEN}[+] Created: $archive${NC}"
}

create_archive "windows" "release-guides/README.windows.md" EquiLauncher.bat launcher.ps1 Add-To-Startup.bat
create_archive "macos" "release-guides/README.macos.md" EquiLauncher.sh
create_archive "linux" "release-guides/README.linux.md" EquiLauncher.sh

echo -e "${CYAN}[!] Done!${NC}"
