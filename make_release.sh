#!/bin/bash

# --- Color Codes ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

VERSION="1.1.0"
RELEASE_NAME="equistart-v$VERSION"
ZIP_FILE="$RELEASE_NAME.zip"

echo -e "${CYAN}[*] Creating release v$VERSION...${NC}"

# 1. Tagging in Git
if [ -d ".git" ]; then
    echo -e "${CYAN}[*] Tagging v$VERSION in Git...${NC}"
    git tag -a "v$VERSION" -m "Release v$VERSION"
    echo -e "${GREEN}[+] Tag created.${NC}"
fi

# 2. Creating Archive
FILES_TO_INCLUDE=(
    "EquiLauncher.bat"
    "launcher.ps1"
    "Add-To-Startup.bat"
    "EquiLauncher.sh"
    "make_release.sh"
    "make_release.ps1"
    "README.md"
)

echo -e "${CYAN}[*] Creating archive $ZIP_FILE...${NC}"
rm -f "$ZIP_FILE"
zip -r "$ZIP_FILE" "${FILES_TO_INCLUDE[@]}"

echo -e "${GREEN}[+] Release archive created: $ZIP_FILE${NC}"
echo -e "${CYAN}[!] Done!${NC}"
