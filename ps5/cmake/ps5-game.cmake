# DevilutionX for the PlayStation 5 - what the console adds to DevilutionX's own build.
#
# tools/build.sh configures vendor/devilutionx itself with the payload SDK's
# toolchain, and names this file as CMAKE_PROJECT_DevilutionX_INCLUDE: CMake
# includes it right after the project() call, before the build reads its
# options and looks for its dependencies. It provides:
#
#   SDL3     .deps/SDL, patched (tools/setup-sdl.sh), with the drivers in ps5/sdl;
#            DevilutionX fetches SDL3 itself, and is told to take this tree
#   zlib     the headers of the zlib inside the RADV archive
#   options  the console's choices among DevilutionX's own
#
# and makes the executable's link PS5_Vulkan's (tools/link-title.sh, with RADV).
#
# SPDX-License-Identifier: MIT

foreach(required PS5_PORT_DIR PS5_VULKAN_DIR SDL_DIR)
	if(NOT ${required})
		message(FATAL_ERROR "ps5-game.cmake: ${required} is not set (use ps5/tools/build.sh)")
	endif()
endforeach()
set(ps5 ${PS5_PORT_DIR}/ps5)

# -fno-omit-frame-pointer: the console's crash backtraces are frame-pointer walks.
add_compile_options(-g1 -ffunction-sections -fdata-sections -fno-omit-frame-pointer)
# The console's CPU is a Zen 2: the toolchain's default is the first x86-64.
add_compile_options(-march=znver2)
# An init array, in the order the source has: tools/cc-init-array.sh has the reason
set(CMAKE_C_COMPILER_LAUNCHER sh ${ps5}/tools/cc-init-array.sh)
set(CMAKE_CXX_COMPILER_LAUNCHER sh ${ps5}/tools/cc-init-array.sh)

# The console: klog, the pad, the mouse and the keyboard, and the libc names a title cannot import
add_library(ps5_platform STATIC ${ps5}/src/platform.c ${ps5}/src/shims.c ${ps5}/src/startup.c)
target_include_directories(ps5_platform PUBLIC ${ps5}/src)
target_include_directories(ps5_platform PRIVATE ${SDL_DIR}/include)
file(READ ${ps5}/sce_sys/param.json param_json)
string(JSON PS5_TITLE_NAME GET "${param_json}" localizedParameters en-US titleName)
target_compile_definitions(ps5_platform PRIVATE "PS5_TITLE_NAME=\"${PS5_TITLE_NAME}\"")
set_target_properties(ps5_platform PROPERTIES ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
# By its file, not its target: it is linked whole into the title (below)
set(ps5_platform_archive ${CMAKE_BINARY_DIR}/libps5_platform.a)

# SDL3: threads, time and files as a FreeBSD has them; video, input and audio from ps5/sdl
set(USE_SDL3 ON CACHE BOOL "" FORCE)
set(DEVILUTIONX_SYSTEM_SDL3 OFF CACHE BOOL "" FORCE)
set(DEVILUTIONX_STATIC_SDL3 ON CACHE BOOL "" FORCE)
set(FETCHCONTENT_SOURCE_DIR_SDL3 ${SDL_DIR} CACHE PATH "" FORCE)
set(SDL_PS5_PORT_DIR ${ps5}/sdl CACHE INTERNAL "")
set(SDL_PS5_PLATFORM_DIR ${ps5}/src CACHE INTERNAL "")
# no X11 and no Wayland, on purpose
set(SDL_UNIX_CONSOLE_BUILD ON CACHE BOOL "" FORCE)
foreach(off SDL_TEST_LIBRARY SDL_TESTS SDL_EXAMPLES SDL_INSTALL
		SDL_X11 SDL_WAYLAND SDL_KMSDRM SDL_RPI SDL_ROCKCHIP SDL_VIVANTE SDL_OFFSCREEN SDL_DUMMYVIDEO
		SDL_OPENGL SDL_OPENGLES SDL_VULKAN SDL_RENDER_VULKAN SDL_GPU SDL_RENDER_GPU SDL_CAMERA SDL_OPENVR
		SDL_OSS SDL_ALSA SDL_JACK SDL_PIPEWIRE SDL_PULSEAUDIO SDL_SNDIO SDL_DISKAUDIO SDL_DUMMYAUDIO
		SDL_DBUS SDL_IBUS SDL_LIBURING SDL_LIBUDEV SDL_HIDAPI SDL_HIDAPI_LIBUSB SDL_VIRTUAL_JOYSTICK
		SDL_DLOPEN_NOTES SDL_DEPS_SHARED SDL_ASSEMBLY_UNUSED)
	set(${off} OFF CACHE BOOL "" FORCE)
endforeach()
# (SDL_VULKAN and SDL_RENDER_VULKAN are SDL's switches for a desktop's loader:
# ps5/patches/sdl.patch turns Vulkan and its renderer on for the console itself)
set(Vulkan_INCLUDE_DIR ${PS5_VULKAN_DIR}/.deps/native/radv-release/include CACHE PATH "" FORCE)
include_directories(SYSTEM ${Vulkan_INCLUDE_DIR})

# zlib is in the RADV archive already (Mesa's own): its headers, and nothing to link
set(DEVILUTIONX_SYSTEM_ZLIB ON CACHE BOOL "" FORCE)
set(ZLIB_INCLUDE_DIR ${PS5_VULKAN_DIR}/.deps/native/zlib/root/usr/include CACHE PATH "" FORCE)
set(ZLIB_LIBRARY ${ps5_platform_archive} CACHE FILEPATH "" FORCE)

# The console's C library has the maths functions: Lua's build looks for a libm of their own
set(LIBM ${ps5_platform_archive} CACHE FILEPATH "" FORCE)

# ... and setjmp and longjmp under those names only (Lua asks for POSIX's _setjmp and _longjmp)
add_compile_definitions(_setjmp=setjmp _longjmp=longjmp)

# Everything else DevilutionX needs it builds from the sources it names itself
foreach(from_source BZIP2 LUA SDL_IMAGE SDL_MIXER LIBPNG SHEENBIDI UNORDERED_DENSE MAGIC_ENUM LIBFMT)
	set(DEVILUTIONX_SYSTEM_${from_source} OFF CACHE BOOL "" FORCE)
endforeach()
foreach(static SDL_IMAGE SDL_MIXER LIBPNG)
	set(DEVILUTIONX_STATIC_${static} ON CACHE BOOL "" FORCE)
endforeach()

# SDL3_image looks for an installed libpng and, finding none, builds without PNG (no
# screenshots, no pictures read): it is shown the libpng DevilutionX has just fetched
set(PNG_LIBRARY png_static CACHE STRING "" FORCE)
set(PNG_PNG_INCLUDE_DIR ${CMAKE_BINARY_DIR}/_deps/libpng-src CACHE PATH "" FORCE)
# ... and would load it at run time: a title has only what is linked into it
set(SDLIMAGE_DEPS_SHARED OFF CACHE BOOL "" FORCE)
set(SDLIMAGE_PNG_SHARED OFF CACHE BOOL "" FORCE)
set(SDLMIXER_DEPS_SHARED OFF CACHE BOOL "" FORCE)

# DevilutionX's options, as the console has them
set(DEVILUTIONX_GAMEPAD_TYPE PlayStation CACHE STRING "" FORCE)
# 960x540: a quarter of a 4K output each way, and half of 1080p, so every pixel is a whole
# number of the screen's, in the screen's shape (the game's own 640x480 stays in its settings)
set(DEFAULT_WIDTH 960 CACHE STRING "" FORCE)
set(DEFAULT_HEIGHT 540 CACHE STRING "" FORCE)
# its assets as loose files in assets/ and mods/, which the game reads as readily as an
# archive of them (Ubuntu's smpq, which would pack them, aborts on arm64)
set(BUILD_ASSETS_MPQ OFF CACHE BOOL "" FORCE)
set(NONET ON CACHE BOOL "" FORCE)
foreach(off BUILD_TESTING DISCORD_INTEGRATION SCREEN_READER_INTEGRATION ASAN UBSAN CPACK)
	set(${off} OFF CACHE BOOL "" FORCE)
endforeach()
set(DISABLE_LTO ON CACHE BOOL "" FORCE)
set(DEVILUTIONX_DISABLE_STRIP ON CACHE BOOL "" FORCE)

# The link: every object and archive CMake would hand the linker goes to
# PS5_Vulkan's recipe instead (RADV, the platform layer, the CRT, the fake SELF)
set(CMAKE_CXX_LINK_EXECUTABLE
	"bash ${ps5}/tools/link-title.sh ${CMAKE_BINARY_DIR} ${PS5_VULKAN_DIR} ${PS5_PAYLOAD_SDK} --whole-archive ${ps5_platform_archive} --no-whole-archive <OBJECTS> <LINK_LIBRARIES>")
# (the start-up constructor in the platform archive has no caller: hence whole)

# The platform archive is named by its file in the link, so the game does not
# depend on it by itself (the game's target exists once its CMakeLists.txt has run)
function(ps5_late_fixes)
	add_dependencies(devilutionx ps5_platform)
	set_property(TARGET devilutionx APPEND PROPERTY LINK_DEPENDS ${ps5_platform_archive})
endfunction()
cmake_language(DEFER DIRECTORY ${CMAKE_SOURCE_DIR} CALL ps5_late_fixes)
