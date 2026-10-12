#!/usr/bin/env bash
# DevilutionX for the PlayStation 5 - pack the built title folder as a release archive.
#
#   ps5/tools/package-release.sh VERSION      (through tools/vm.sh package-release 0.1.0)
#
# Writes dist/DevilutionX-PS5-vVERSION.zip: the title folder dist/<TITLE_ID>/ as the
# console takes it (eboot.bin, sce_sys/, sce_module/, assets/, mods/, licenses/), with
# SOURCE.txt beside eboot.bin naming the revision of every part the build linked and
# the licences it is offered under. No game data, save or setting goes in, and it
# refuses if one is in the folder.
#
# After the Dusklight port's package-release.sh.
# SPDX-License-Identifier: MIT
set -euo pipefail
version=${1:?usage: package-release.sh VERSION}
ps5=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(dirname "$ps5")
vulkan=$(cd -- "${PS5_VULKAN_DIR:-$root/../PS5_Vulkan}" && pwd)
game="$root/vendor/devilutionx"
title_id=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["titleId"])' "$ps5/sce_sys/param.json")
app="$root/dist/$title_id"
for file in eboot.bin sce_sys/param.json sce_sys/icon0.png sce_sys/pic0.dds sce_sys/pic1.dds sce_module/libc.prx \
        assets/ASSETS_VERSION mods licenses/DevilutionX-LICENSE.md; do
    [[ -e $app/$file ]] || { echo "missing $app/$file: run build.sh first" >&2; exit 2; }
done
stray=$(find "$app" \( -iname '*.mpq' -o -iname '*.sv' -o -iname '*.hsv' -o -name userdata -o -name 'env.txt' \
    -o -name 'radv-shader-cache' \) -print -quit)
[[ -z $stray ]] || { echo "game data, a save or a setting in the title folder ($stray): a release never carries it" >&2; exit 2; }
# the submodule's working tree carries the console's patch: that is not a change here
[[ -z $(git -C "$root" status --porcelain --ignore-submodules=dirty) ]] ||
    { echo "uncommitted changes: a release is built from a commit" >&2; exit 2; }
provenance="$vulkan/.deps/native/radv-release/PROVENANCE.txt"
cp "$root/licenses/GPL-3.0.txt" "$root/licenses/MIT.txt" "$root/licenses/Zlib.txt" "$app/licenses/"
cp "$root/LICENSING.md" "$app/licenses/LICENSING.md"
cat > "$app/SOURCE.txt" <<SOURCE
DevilutionX for PlayStation 5, version $version
An unofficial homebrew build, free of charge and for non-commercial use. Not
affiliated with the DevilutionX project, Blizzard Entertainment or Sony
Interactive Entertainment.

This is a MODIFIED build of DevilutionX: ps5/patches/devilutionx.patch is
applied to it (where settings and saves go, no hardware pointer, a screenshot
hook), and it is built with SDL3 and this port's console drivers.

Licences. DevilutionX is under the Sustainable Use License 1.0
(licenses/DevilutionX-LICENSE.md): personal or non-commercial use, and passed
on free of charge only. The console's start-up code and platform layer are
under the GNU General Public License, version 3 (licenses/GPL-3.0.txt). Those
two licences set different conditions on a combined program, which
licenses/LICENSING.md describes; this build is offered free of charge, with
all of its source, at the revisions below.

The port (patches, SDL3 drivers, platform layer, build)
  $(git -C "$root" remote get-url origin 2>/dev/null || echo "this repository")
  $(git -C "$root" rev-parse HEAD)
The game's code: DevilutionX (Sustainable Use License 1.0), with ps5/patches/devilutionx.patch
  https://github.com/diasurgical/devilutionX
  $(git -C "$game" rev-parse HEAD)
SDL3 (Zlib), with ps5/patches/sdl.patch and the drivers in ps5/sdl
  https://github.com/libsdl-org/SDL
  $(sed -n 's/^tag=//p' "$ps5/tools/setup-sdl.sh")
The Vulkan driver: RADV, from PS5_Mesa (MIT)
  https://github.com/mihawk-99/PS5_Mesa
  $(sed -n 's/^revision: //p' "$provenance")
The link recipe, CRT, libc.prx and packaging: PS5_Vulkan (GPL-3.0)
  https://github.com/mihawk-99/PS5_Vulkan
  $(git -C "$vulkan" rev-parse HEAD)
The platform layer and SDK: PS5_PayloadSDK (GPL-3.0), over ps5-payload-dev/sdk v0.42
  https://github.com/mihawk-99/PS5_PayloadSDK
  title: $(sed -n 's/^sdk_revision=//p' "$ps5/tools/setup-sdk.sh")
  RADV archive: $(sed -n 's/^sdk: //p' "$provenance")
The libraries DevilutionX fetches (Lua, SDL3_image, SDL3_mixer, libpng, bzip2,
SheenBidi, libsmackerdec, mpqfs, fmt, sol2, magic_enum, unordered_dense and
others) are at the versions DevilutionX names at the revision above.
Compiler: $(${PS5_CLANG:-clang} --version | head -1)

No game data is included. Diablo and Hellfire belong to Blizzard Entertainment;
this title does nothing without DIABDAT.MPQ from your own copy of Diablo, placed
beside eboot.bin. The pictures in sce_sys/ were made for this port and contain
nothing of Blizzard's.

eboot.bin sha256: $(sha256sum "$app/eboot.bin" | cut -d' ' -f1)
SOURCE
out="$root/dist/DevilutionX-PS5-v$version.zip"
rm -f "$out"
(cd "$root/dist" && zip -q -r -X "$out" "$title_id" -x '*/.DS_Store')
printf '==> %s (%s bytes)\n' "$out" "$(stat -c %s "$out")"
unzip -l "$out" | tail -n +4 | awk '{print "    " $1, $4}' | grep -v "/assets/\|/mods/" | head -30
