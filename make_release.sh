#!/bin/bash

# --- Color Codes ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

set -euo pipefail

VERSION="1.2.1"
RELEASE_NAME="equistart-v$VERSION"

echo -e "${CYAN}[*] Creating release v$VERSION...${NC}"

create_archive() {
    local platform="$1"
    shift
    local archive="${RELEASE_NAME}-${platform}.zip"

    echo -e "${CYAN}[*] Creating archive $archive...${NC}"
    rm -f "$archive"
    zip -q "$archive" "$@"
    echo -e "${GREEN}[+] Created: $archive${NC}"
}

create_archive "windows" EquiLauncher.bat launcher.ps1 Add-To-Startup.bat README.md
create_archive "macos" EquiLauncher.sh README.md
create_archive "linux" EquiLauncher.sh README.md

echo -e "${CYAN}[!] Done!${NC}"
