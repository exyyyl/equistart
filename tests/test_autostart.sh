#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

export HOME="$TEST_DIR/home"
export EQUILAUNCHER_SOURCE_ONLY=true
mkdir -p "$HOME" "$TEST_DIR/work"

# shellcheck source=../EquiLauncher.sh
source "$ROOT_DIR/EquiLauncher.sh"
WORK_DIR="$TEST_DIR/work"
OS="Linux"

EVENTS=""
record() { EVENTS="${EVENTS}${EVENTS:+ }$1"; }
find_discord_index() { printf '%s\n' "$TEST_DIR/index.js"; }
download_file() {
    printf '#!/bin/sh\nexit 0\n' > "$2"
    chmod +x "$2"
}
discord_is_running() { return "$DISCORD_RUNNING_STATUS"; }
confirm_restart_for_repair() { record prompt; return "$CONFIRM_STATUS"; }
kill_discord() { record kill; }
launch_discord() { record launch; }
run_equicord_installer() { record install; }

reset_case() {
    EVENTS=""
    rm -f "$WORK_DIR/VencordInstallerCli-linux"
    rm -rf "$TEST_DIR/resources"
    printf '%s\n' "$1" > "$TEST_DIR/index.js"
}

assert_events() {
    if [ "$EVENTS" != "$1" ]; then
        printf 'FAIL: expected events [%s], got [%s]\n' "$1" "$EVENTS" >&2
        exit 1
    fi
}

# Broken patch + running Discord + Later: never terminate or relaunch Discord.
reset_case "module.exports = {};"
DISCORD_RUNNING_STATUS=0
CONFIRM_STATUS=1
install_vencord true
assert_events "prompt"

# Broken patch + running Discord + Restart now: explicit consent permits restart.
reset_case "module.exports = {};"
DISCORD_RUNNING_STATUS=0
CONFIRM_STATUS=0
install_vencord true
assert_events "prompt kill launch"

# Broken patch + manual run: retain the existing immediate repair behavior.
reset_case "module.exports = {};"
DISCORD_RUNNING_STATUS=0
CONFIRM_STATUS=1
install_vencord false
assert_events "kill launch"

# Healthy patch + running Discord at startup: do nothing.
reset_case "// Vencord"
DISCORD_RUNNING_STATUS=0
CONFIRM_STATUS=1
install_vencord true
assert_events ""

# A failed installer must be reported and Discord reopened instead of claiming success.
reset_case "module.exports = {};"
DISCORD_RUNNING_STATUS=1
CONFIRM_STATUS=1
if install_equicord false; then
    printf 'FAIL: missing post-install marker was accepted\n' >&2
    exit 1
fi
assert_events "install launch"

# Current installer format: _app.asar is authoritative even when index.js has no marker.
reset_case "module.exports = require('./core.asar');"
mkdir -p "$TEST_DIR/resources"
touch "$TEST_DIR/resources/_app.asar"
DISCORD_RUNNING_STATUS=0
CONFIRM_STATUS=1
install_vencord true
assert_events ""

printf 'All autostart behavior tests passed.\n'
