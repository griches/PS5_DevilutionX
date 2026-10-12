# Licences

This repository holds the PS5 port's own files. Each source file names its
licence in its header; this is the summary.

| Path | Licence | Text |
| --- | --- | --- |
| `ps5/tools/png-to-title-dds.py` (encoder from PS5 RetroArch, by Mihawk) | GPL-3.0-or-later | [`licenses/GPL-3.0.txt`](licenses/GPL-3.0.txt) |
| `ps5/src/platform.c`, `ps5/src/platform.h` and the tools taken from the PS5 Vulkan Template (by Mihawk, after Sascha Willems' Vulkan examples) | MIT | [`licenses/MIT.txt`](licenses/MIT.txt) |
| The rest of `ps5/src/`, `ps5/tools/`, `ps5/cmake/`, `ps5/stubs/` and `ps5/art/make-title-art.sh` (written for this and the earlier ports) | MIT | [`licenses/MIT.txt`](licenses/MIT.txt) |
| `ps5/sdl/` (SDL3 drivers for the console) and `ps5/patches/sdl.patch` | Zlib, as SDL | [`licenses/Zlib.txt`](licenses/Zlib.txt) |
| `ps5/patches/devilutionx.patch` | Sustainable Use License 1.0, as DevilutionX | `vendor/devilutionx/LICENSE.md` |

## What is built from elsewhere

Nothing below is stored in this repository; the build takes each from its own
project, under that project's licence.

| Part | Project | Licence |
| --- | --- | --- |
| The game's code | [DevilutionX](https://github.com/diasurgical/devilutionX) (the `vendor/devilutionx` submodule) | Sustainable Use License 1.0: personal or non-commercial use, redistribution free of charge only |
| Libraries DevilutionX fetches | Lua, SDL3_image, SDL3_mixer, libpng, bzip2, SheenBidi, libsmackerdec, mpqfs, fmt, sol2, magic_enum, unordered_dense and others | each its own |
| Windowing, input and sound | [SDL3](https://github.com/libsdl-org/SDL) | Zlib |
| The Vulkan driver | RADV from [PS5_Mesa](https://github.com/mihawk-99/PS5_Mesa), linked by [PS5_Vulkan](https://github.com/mihawk-99/PS5_Vulkan) | MIT (Mesa); GPL-3.0 (PS5_Vulkan's link recipe, CRT and tools) |
| The platform layer and SDK | [PS5_PayloadSDK](https://github.com/mihawk-99/PS5_PayloadSDK), a fork of ps5-payload-dev/sdk | GPL-3.0 |

## A built title

A built `eboot.bin` links DevilutionX (Sustainable Use License: non-commercial
use, passed on free of charge only) with the GPL-3.0 platform layer and CRT of
the PS5 stack. The two licences set conditions that do not fit together on one
program: the GPL allows no restriction beyond its own on a combined work, and
the Sustainable Use License does not let its code be relicensed under the GPL.

Releases of this port are made anyway, by Gary Riches' decision (2026-10-12),
on these terms: free of charge, for non-commercial use, with the licence texts
and the source of every part at the revisions built (`SOURCE.txt` in each
release). That meets what each licence asks of a distributor except the point
above, which only the authors of one side or the other can settle: by a
linking permission from the authors of the GPL-3.0 parts, by permission from
the DevilutionX maintainers, or by a build that does not link the GPL-3.0
parts (DevilutionX's own PS5 packaging, `Packaging/ps5` upstream, builds
against the stock payload SDK). If either asks, the builds come down.

## What is not covered

- **The game.** Diablo and Hellfire, `DIABDAT.MPQ` and everything in it belong
  to Blizzard Entertainment. None of it is in this repository or in any build
  of it. A title built from here does nothing without game data you provide.
- **Artwork.** `ps5/sce_sys/icon0.png`, `pic0.dds`, `pic1.dds` and their
  sources in `ps5/art/` were made for this port by Gary Riches with an image
  generator (a cathedral above a village, and its doorway). Nothing in them is
  Blizzard's.
- **Button symbols.** The cross, circle, square and triangle the game shows
  are in DevilutionX's own font; they are Sony's marks whoever draws them.
- **Trademarks.** "Diablo" and "Hellfire" are trademarks of Blizzard
  Entertainment. "PlayStation", "PS5" and "DualSense" are trademarks of Sony
  Interactive Entertainment Inc. This project is not affiliated with or
  endorsed by either, or by the DevilutionX project.
