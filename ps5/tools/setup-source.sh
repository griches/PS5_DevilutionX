#!/usr/bin/env bash
# DevilutionX for the PlayStation 5 - the game's sources, with the console's changes.
#
#   ps5/tools/setup-source.sh    apply ps5/patches/devilutionx.patch to vendor/devilutionx
#
# vendor/devilutionx is DevilutionX at an upstream revision. What the console
# needs changed in it is kept here as a patch, not as a fork. A patch already
# applied is left alone, so this can run before every build.
#
# SPDX-License-Identifier: MIT
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source="$root/vendor/devilutionx"
patch="$root/ps5/patches/devilutionx.patch"
[[ -f $source/CMakeLists.txt ]] || git -C "$root" submodule update --init vendor/devilutionx
[[ -s $patch ]] || exit 0
if git -C "$source" apply --reverse --check "$patch" 2>/dev/null; then
    exit 0 # applied already
fi
git -C "$source" apply --check "$patch" || {
    echo "setup-source.sh: devilutionx.patch does not apply to $source (a different upstream revision, or edits not yet saved to the patch?)" >&2
    exit 2
}
git -C "$source" apply --whitespace=nowarn "$patch"
echo "setup-source.sh: applied devilutionx.patch" >&2
