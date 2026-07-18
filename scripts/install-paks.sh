#!/usr/bin/env bash
#
# install-paks.sh — copy your legally-owned Doom 3 game data into the tree so
# the freshly built dhewm3 can boot the real game.
#
# This copies NON-FREE data that YOU already own (from your own Doom 3
# install). Nothing here is distributed with dhewm3, and the copied *.pk4
# files are git-ignored so they can never be committed.
#
# Usage:
#   scripts/install-paks.sh
#   DOOM3_PAKS=/path/to/Doom\ 3/base scripts/install-paks.sh
#
# DOOM3_PAKS should point at the "base" folder of your Doom 3 install.
# Defaults to the common Steam-on-Linux location.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
src="${DOOM3_PAKS:-$HOME/.steam/steam/steamapps/common/Doom 3/base}"

if [ ! -d "$src" ]; then
    echo "error: game-data folder not found: $src" >&2
    echo "point DOOM3_PAKS at the 'base' folder of your Doom 3 install." >&2
    exit 1
fi

shopt -s nullglob
paks=("$src"/pak*.pk4)
if [ "${#paks[@]}" -eq 0 ]; then
    echo "error: no pak*.pk4 files in $src" >&2
    exit 1
fi

mkdir -p "$repo/base"
cp -v "${paks[@]}" "$repo/base/"

# Resurrection of Evil (optional): copy its paks into d3xp/ if you own it.
roe="$(dirname "$src")/d3xp"
if [ -d "$roe" ]; then
    roe_paks=("$roe"/pak*.pk4)
    if [ "${#roe_paks[@]}" -gt 0 ]; then
        mkdir -p "$repo/d3xp"
        cp -v "${roe_paks[@]}" "$repo/d3xp/"
    fi
fi

echo "done — game data copied into base/ (and d3xp/ if present)."
