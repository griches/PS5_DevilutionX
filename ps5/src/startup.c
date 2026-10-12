/*
 * DevilutionX for the PlayStation 5 - what runs before the game's main.
 *
 * The game's main is its own (vendor/devilutionx/Source/main.cpp), so the
 * console's start-up is a constructor: standard error into klog and the
 * shell's splash dismissed, and where a title may keep its files.
 *
 * A title sees its own folder (/app0, which is /data/homebrew/<TITLE_ID>) and
 * nothing else of /data:
 *
 *   /app0/DIABDAT.MPQ      the game's data, from your own copy of Diablo (or spawn.mpq,
 *                          the shareware's); hellfire.mpq and the others beside it
 *   /app0/assets/          DevilutionX's own assets, and /app0/mods/
 *   /app0/userdata/        diablo.ini, the saves, logs
 *   /app0/env.txt          optional: NAME=value lines for the environment
 *
 * SPDX-License-Identifier: MIT
 */
#include <SDL3/SDL_stdinc.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "platform.h"

/* Both copies of the environment: the console's libc keeps what setenv sets
 * apart from the `environ` SDL copies. */
static void
set(const char *name, const char *value, int overwrite)
{
   setenv(name, value, overwrite);
   SDL_SetEnvironmentVariable(SDL_GetEnvironment(), name, value, overwrite != 0);
}

__attribute__((constructor)) static void
ps5_startup(void)
{
   platform_init(PS5_TITLE_NAME);
   mkdir("/app0/userdata", 0777);
   /* PS5 DevLoop's grab takes the title's pictures from here, and removes them */
   mkdir("/app0/userdata/screenshots", 0777);
   chmod("/app0/userdata/screenshots", 0777);

   FILE *file = fopen("/app0/env.txt", "r");
   if (file) {
      char line[512];
      while (fgets(line, sizeof line, file)) {
         line[strcspn(line, "\r\n")] = 0;
         char *equals = strchr(line, '=');
         if (line[0] == '#' || !equals || equals == line)
            continue;
         *equals = 0;
         set(line, equals + 1, 1);
         say("env.txt: %s=%s", line, equals + 1);
      }
      fclose(file);
   }
}
