#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_root=$(mktemp -d /tmp/album-checks.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
export XDG_DATA_HOME="$test_root/data"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_CACHE_HOME="$test_root/cache"
export GODOT_SILENCE_ROOT_WARNING=1
# Godot can return zero after a script parse/resource error. Preserve its exit
# status and also reject engine errors instead of reporting an empty run as green.
run_godot() {
  local result=0
  godot "$@" > "$test_root/godot.log" 2>&1 || result=$?
  cat "$test_root/godot.log"
  if (( result != 0 )); then return "$result"; fi
  while IFS= read -r line; do
    case "$line" in
      *"SCRIPT ERROR:"*|ERROR:*) return 1 ;;
    esac
  done < "$test_root/godot.log"
}
python3 tests/maps_data_test.py
run_godot --headless --editor --import --quit
for suite in rhythm save character player world npc club wanted vehicle menu editor music_flow integration features presentation maps; do
  if [[ "$suite" == "world" || "$suite" == "npc" || "$suite" == "club" || "$suite" == "wanted" || "$suite" == "vehicle" || "$suite" == "maps" ]]; then
    run_godot --headless --fixed-fps 60 --script "tests/${suite}_test.gd"
  else
    run_godot --headless --script "tests/${suite}_test.gd"
  fi
done
