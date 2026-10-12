# DevilutionX for PlayStation 5

A PS5 homebrew build of [DevilutionX](https://github.com/diasurgical/devilutionX),
the source port of Diablo and Hellfire, as an installed title (`PPSA99308`) with
a controller, a keyboard and a mouse. The game draws its picture in software, as
it always has; SDL3's Vulkan renderer puts it on the screen through RADV, from
the [PS5 Vulkan](https://github.com/mihawk-99/PS5_Vulkan) stack.

It needs a PS5 that already runs homebrew, and **your own copy of Diablo**
(`DIABDAT.MPQ`). No game data, Blizzard artwork, Sony software or keys are
included here.

This is an unofficial build. DevilutionX has a PS5 port of its own
(`Packaging/ps5` upstream, launched through websrv); this one is separate and
is not supported by the DevilutionX project: please do not take its problems
to them.

**Free of charge, for non-commercial use.** A built `eboot.bin` links
DevilutionX (Sustainable Use License) with GPL-3.0 parts of the PS5 stack, and
the two licences' conditions do not fit together on one program:
[`LICENSING.md`](LICENSING.md) says where that stands.

## Status

Tested on one console (firmware 13.60, a 3840x2160 output) on 2026-10-12, with
the retail `DIABDAT.MPQ`, at DevilutionX `b0a3b7ba`. "Seen" means it ran there
and was looked at through [PS5 DevLoop](https://github.com/griches/PS5_DevLoop)
(a virtual controller and the title's own frames) or read in the console's
log; nothing else is claimed.

| Area | Seen on the console | Not yet verified |
| --- | --- | --- |
| Start-up | The intro film, the main menu, a new hero, and into Tristram | Hellfire (needs `hellfire.mpq`), the shareware `spawn.mpq` |
| Picture | Fills the screen at 960x540 (the default) and at 1280x720; Settings lists 1080p, 720p, 540p and 480p | 1080p and 480p in play; a 1080p television |
| Controller | Menus (Cross confirms, Circle goes back), walking with the left stick, the inventory, picking an item up, the game menu, the modifier hint overlays | Each button in play; rumble |
| Button prompts | The DualSense's symbols: "△ to use" on a potion, and the bindings in Settings > Padmapping | Every prompt in the game |
| Keyboard and mouse | Both libraries load and open at start-up | **Everything else: no keyboard or mouse was plugged in.** The code is the Quake III port's, which was played with both |
| Saving | Save Game from the menu; the hero and the save found again after a restart | |
| Settings | Resolution changed and changed back; kept in `userdata/diablo.ini` | Every other option |
| Sound | | Nobody has listened yet |
| Exit | Exit Diablo and Quit Game both close the title (exit status 0) | Closing it from the home screen |
| Multiplayer | | Not built: `NONET` is on |

Known limits:

- **The game menu is Options and the touchpad button together.** DevilutionX
  uses Start as a modifier (hold it to see what the other buttons do), and
  opens its menu with Start and Select; the touchpad's click is Select here,
  because the console keeps the Create button for itself.
- **A hero's name is the random one the game offers** unless a keyboard is
  plugged in: the console's on-screen keyboard is not opened.
- **Text from a keyboard is US layout.** The console gives key codes and no
  characters, so the driver makes the characters itself.
- **Assets are loose files** (`assets/`, `mods/`), not `devilutionx.mpq`:
  Ubuntu's `smpq`, which would pack them, aborts on arm64.

## Controls

**Controller.** These are DevilutionX's defaults for a PlayStation pad, read
from its source (`InitPadmapActions` in `Source/diablo.cpp`).

In menus: D-pad or left stick to move, **Cross** to confirm, **Circle** to go
back, **Square** to delete a hero.

In the game:

| Button | Does |
| --- | --- |
| Left stick, D-pad | Walk |
| Right stick | Move the pointer |
| Circle | Main action: attack, talk, and lift or place an item in the inventory |
| Triangle | Second action: pick up from the ground, open chests and doors, use an item in the inventory |
| Square | Cast the active spell |
| Cross | Open the quick spell list to choose the active spell; close a panel |
| L1 / R1 | Drink a health / a mana potion from the belt |
| L2 / R2 | Character sheet / inventory |
| L3 | Automap |
| R3 | Left mouse click at the pointer |

Two buttons change what the others do while held, and the game draws the
choices on screen while you hold them:

| Hold | Then | Does |
| --- | --- | --- |
| Options | D-pad, face buttons | Opens a panel: the icons shown are character, inventory, map, quests, spell book |
| Touchpad button | Face buttons | Sets or casts a spell hotkey (the four empty squares) |
| Touchpad button | L2 / R2 | Quest log / spell book |
| Touchpad button | D-pad | Moves the pointer |
| Touchpad button | L1 or R3 | Left click (L1) / right click (R3); R1 is right click too |
| Options | Touchpad button | **The game menu** (save, options, quit) |

Settings > Padmapping lists every action with its button and changes any of
them.

**Keyboard and mouse** are the PC game's: left click to move and attack, right
click to cast, `I` inventory, `C` character, `Tab` the map, `Esc` the menu,
`1` to `8` the belt. The game switches its prompts between the two by whichever
you touched last: move the mouse and it says "Right click to use", press a
button on the pad and it shows the pad's symbol.

## Install

1. Unpack a [release](https://github.com/griches/PS5_DevilutionX/releases)'s zip,
   or build it (below), which fills `dist/PPSA99308/`.
2. Copy the `PPSA99308` folder to `/data/homebrew/PPSA99308/` on the console
   (`ps5/tools/vm.sh deploy` does it over FTP from a build).
3. Put your `DIABDAT.MPQ` beside `eboot.bin`, in `/data/homebrew/PPSA99308/`.
   `hellfire.mpq`, `hfmonk.mpq`, `hfmusic.mpq` and `hfvoice.mpq` go there too
   if you have Hellfire.
4. Launch "DevilutionX" from the home screen.

Settings and saves are kept in `/data/homebrew/PPSA99308/userdata/`.

If the tile does not appear, look in `/data/shadowmount/debug.log`:
ShadowMountPlus registers a folder when it first sees it, tries twice, and
loses its hook into the system when the console wakes from rest mode ("AppInstallAll
hook is no longer installed"). Restarting ShadowMountPlus registers the title.
Deploy the whole folder at once, icon included, so that the first try has
everything.

## Build

On macOS, through the Linux VM the other ports use (`ps5`, in Lima, with
PS5_Vulkan, PS5_Mesa and PS5_PayloadSDK under `~/ps5`):

```bash
git submodule update --init
ps5/tools/vm.sh build      # dist/PPSA99308/
ps5/tools/vm.sh deploy     # to the console, over FTP
ps5/tools/vm.sh run        # launch, and follow the console's log until the game quits
```

`gettext` must be installed in the VM (for the translations).

## How it works

- **`vendor/devilutionx`** is upstream at a pinned revision. What the console
  needs changed is `ps5/patches/devilutionx.patch`, applied before each build:
  where settings and saves go, no hardware pointer, and the screenshot hook
  for PS5 DevLoop. After editing the submodule, run
  `git -C vendor/devilutionx diff > ps5/patches/devilutionx.patch`. Upstream's
  files end their lines with CR LF: `ps5/tools/edit-source.py` replaces text
  without rewriting the rest.
- **`ps5/cmake/ps5-game.cmake`** is included by DevilutionX's own CMake build
  right after `project()`. It chooses SDL3, hands the build this port's
  patched SDL tree, sets the console's options (960x540, PlayStation
  prompts, no networking) and replaces the link with PS5_Vulkan's.
- **`ps5/sdl/`** holds SDL3's drivers for the console. The video driver gives
  SDL one display, whose size it asks of `VK_KHR_display`, and a window
  that is the whole screen; SDL's Vulkan renderer draws through RADV. The same
  driver reads the keyboard and the mouse once per event pump and turns them
  into SDL's events.
- **`ps5/src/platform.c`** is the console itself: the log, the pad,
  libSceMouse and libSceKeyboard, the sound output.
- **960x540** is the default because it is a whole number of the screen's
  pixels on both a 4K and a 1080p output, in the screen's shape. The game's
  original 640x480 view is "480p" in Settings.

Things the build had to be told, each with its comment in
`ps5-game.cmake` or `link-title.sh`: Lua looks for a separate maths library
and POSIX's `_setjmp`; SDL3_image builds without PNG support, silently, unless
it is shown the libpng DevilutionX fetched (no screenshots otherwise); zlib is
already inside the RADV archive.

## Test hooks

- `/app0/devloop-shot`: when PS5 DevLoop creates this file the game writes its
  next frame to `userdata/screenshots/` (`ps5loop.py grab --title devilutionx`).
  The picture is the game's own 8-bit frame, with a palette whose alpha is 0:
  drop the transparency before looking at it.
- `/app0/env.txt`: `NAME=value` lines for the environment, read before the
  game starts. `SDL_PS5_DISPLAY=1920x1080` overrides the output size.

## Artwork

The icon and the background were made for this port by Gary Riches with an
image generator: `ps5/art/`, and `ps5/art/make-title-art.sh` turns them into
`ps5/sce_sys/`. Nothing in them is Blizzard's.
