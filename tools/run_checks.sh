#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_root=$(mktemp -d /tmp/album-checks.XXXXXX)
trap 'rm -rf "$test_root"' EXIT
export XDG_DATA_HOME="$test_root/data"
export XDG_CONFIG_HOME="$test_root/config"
export XDG_CACHE_HOME="$test_root/cache"
export GODOT_SILENCE_ROOT_WARNING=1
godot --headless --editor --import --quit
for suite in rhythm save player world music_flow integration; do
  if [[ "$suite" == "world" ]]; then
    godot --headless --fixed-fps 60 --script "tests/${suite}_test.gd"
  else
    godot --headless --script "tests/${suite}_test.gd"
  fi
done
