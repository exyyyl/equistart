#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

export HOME="$TEST_DIR/home"
export EQUILAUNCHER_SOURCE_ONLY=true
mkdir -p "$HOME"

# shellcheck source=../EquiLauncher.sh
source "$ROOT_DIR/EquiLauncher.sh"

version_is_newer "1.2.2" "1.2.1"
version_is_newer "v2.0.0" "1.99.99"
version_is_newer "1.10.0" "1.9.9"

if version_is_newer "1.2.1" "1.2.1"; then
    echo "FAIL: equal versions must not trigger an update" >&2
    exit 1
fi
if version_is_newer "1.2.0" "1.2.1"; then
    echo "FAIL: older versions must not trigger an update" >&2
    exit 1
fi

printf 'All update version tests passed.\n'
