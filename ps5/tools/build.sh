#!/usr/bin/env bash
# DevilutionX for the PlayStation 5 - build the game into dist/<TITLE_ID>/.
#
#   ps5/tools/build.sh [ninja arguments]
#
# Applies the console's patch to vendor/devilutionx (tools/setup-source.sh),
# configures it with the payload SDK's CMake toolchain (once) and
# ps5/cmake/ps5-game.cmake, which gives it SDL3 with the console's drivers and
# the title's link (tools/link-title.sh). The title folder gets eboot.bin,
# sce_sys/, DevilutionX's own assets (assets/ and mods/) and
# the licences. No game data: DIABDAT.MPQ is yours, placed beside eboot.bin.
#
#   PS5_BUILD_DIR    the build tree (default build/game; the Linux VM's own disk
#                    is several times faster than the shared folder)
#   PS5_VULKAN_DIR   the PS5_Vulkan checkout (default ../PS5_Vulkan)
#
# SPDX-License-Identifier: MIT
set -euo pipefail

ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
bash "$ps5/tools/setup-source.sh"
sdl=$(bash "$ps5/tools/setup-sdl.sh")
sdk=$(bash "$ps5/tools/setup-sdk.sh")
build=${PS5_BUILD_DIR:-$root/build/game}
ninja=$(command -v ninja || echo "$HOME/.local/bin/ninja")
export PS5_CLANG=${PS5_CLANG:-$(command -v clang || true)}

if [[ ! -f $build/build.ninja ]]; then
    mkdir -p "$build"
    cmake -S "$root/vendor/devilutionx" -B "$build" -G Ninja -DCMAKE_MAKE_PROGRAM="$ninja" \
        -DCMAKE_TOOLCHAIN_FILE="$sdk/toolchain/prospero.cmake" \
        -DCMAKE_PROJECT_DevilutionX_INCLUDE="$ps5/cmake/ps5-game.cmake" \
        -DPS5_PORT_DIR="$root" -DPS5_VULKAN_DIR="$vulkan" -DSDL_DIR="$sdl" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_VERBOSE_MAKEFILE=OFF > "$build/configure.log" 2>&1 \
        || { tail -60 "$build/configure.log" >&2; exit 1; }
fi
"$ninja" -C "$build" "${@:-devilutionx}"

# DevilutionX's own assets, beside eboot.bin (the build made them for the game to find)
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$ps5/sce_sys/param.json")
app="${PS5_DIST_DIR:-$root/dist}/$title_id"
if [[ -d $app ]]; then
    "$ninja" -C "$build" devilutionx_copied_assets hellfire_copied_assets > /dev/null
    rm -rf "$app/assets" "$app/mods"
    cp -R "$build/assets" "$app/assets"
    cp -R "$build/mods" "$app/mods"
    printf '    assets: %s files, mods: %s files\n' "$(find "$app/assets" -type f | wc -l)" "$(find "$app/mods" -type f | wc -l)"
fi
