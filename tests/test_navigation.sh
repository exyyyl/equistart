#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Load only navigation functions: no Discord discovery, downloads or user-directory writes.
eval "$(sed -n '/# --- Interactive screens ---/,/# Allow behavior tests/p' "$ROOT_DIR/EquiLauncher.sh")"
show_page() { printf 'PAGE:%s\n' "${1:-home}"; }
run_normal() { printf 'ACTION:launch:%s\n' "$1"; return 17; }
run_debug() { printf 'ACTION:debug:%s\n' "$1"; }
add_startup() { printf 'ACTION:startup:%s\n' "$1"; }
RED="" NC=""

# A failed launch must still return home and allow two subsequent actions.
output="$(run_menu <<'INPUT'
1
2

2
1

3
2

0
INPUT
)"
for event in 'ACTION:launch:Vencord' 'ACTION:debug:Equicord' 'ACTION:startup:Vencord' 'Действие завершилось с ошибкой'; do
    [[ "$output" == *"$event"* ]] || { printf 'Missing event: %s\n' "$event" >&2; exit 1; }
done
[[ "$(printf '%s\n' "$output" | grep -c 'PAGE:home')" -eq 4 ]]

# Back, invalid input and EOF must not execute an action or trap the user in a loop.
output="$(run_menu <<'INPUT'
1
9
0
0
INPUT
)"
[[ "$output" != *'ACTION:'* ]]
[[ "$(printf '%s\n' "$output" | grep -c 'PAGE:home')" -eq 2 ]]
run_menu </dev/null >/dev/null
printf 'All navigation tests passed.\n'
