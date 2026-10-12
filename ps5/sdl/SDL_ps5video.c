/*
 * DevilutionX for the PlayStation 5 - SDL3's video driver for the console.
 *
 * The console has one output and no windows: this gives SDL one display and
 * lets it keep its window bookkeeping (size, flags, events) for a window that
 * is the whole screen. Its Vulkan calls answer for the console: the "library"
 * is RADV, linked into the title, and a window's surface is VK_KHR_display's
 * first display in its first mode. SDL's own Vulkan renderer draws through
 * that, which is how the game's picture reaches the screen.
 *
 * A USB or Bluetooth keyboard and mouse are read here, through the title's
 * platform layer (ps5/src/platform.h), once per event pump. A key's USB HID
 * usage is SDL's scancode. The console gives no characters, so text is made
 * from the key and the modifiers in SDL's default (US) layout while a text
 * field is open. The mouse reports movement only: SDL keeps the pointer, and
 * the game draws it.
 *
 * The display's size is the console's output (3840x2160 on a 4K television,
 * 1920x1080 otherwise), asked of VK_KHR_display at start-up, so SDL's idea of
 * the window is the swapchain's. SDL_PS5_DISPLAY=WIDTHxHEIGHT in the
 * environment overrides it. A few smaller sizes are listed as modes for a
 * title's settings to offer; the output itself never changes.
 *
 * SPDX-License-Identifier: Zlib
 */
#include "SDL_internal.h"

#ifdef SDL_VIDEO_DRIVER_PS5

#include "video/SDL_sysvideo.h"
#include "events/SDL_events_c.h"
#include "events/SDL_keyboard_c.h"
#include "events/SDL_mouse_c.h"

#include "platform.h"

#define PS5_KEYBOARD_ID 1
#define PS5_MOUSE_ID    1

static SDL_Window *ps5_window;
static bool ps5_keyboard_opened, ps5_keyboard_listed;
static bool ps5_mouse_opened, ps5_mouse_listed;
static Uint8 ps5_modifiers;
static Uint32 ps5_mouse_buttons;

#ifdef SDL_VIDEO_VULKAN
#include "video/SDL_vulkan_internal.h"

/* RADV's entry point: there is no Vulkan loader, the driver is in the title */
extern PFN_vkVoidFunction vk_icdGetInstanceProcAddr(VkInstance instance, const char *name);

static bool PS5_Vulkan_LoadLibrary(SDL_VideoDevice *_this, const char *path)
{
    _this->vulkan_config.vkGetInstanceProcAddr = (void *)vk_icdGetInstanceProcAddr;
    _this->vulkan_config.vkEnumerateInstanceExtensionProperties =
        (void *)vk_icdGetInstanceProcAddr(VK_NULL_HANDLE, "vkEnumerateInstanceExtensionProperties");
    if (!_this->vulkan_config.vkEnumerateInstanceExtensionProperties) {
        return SDL_SetError("RADV has no vkEnumerateInstanceExtensionProperties");
    }
    SDL_strlcpy(_this->vulkan_config.loader_path, "radv", SDL_arraysize(_this->vulkan_config.loader_path));
    return true;
}

static void PS5_Vulkan_UnloadLibrary(SDL_VideoDevice *_this)
{
}

static char const *const *PS5_Vulkan_GetInstanceExtensions(SDL_VideoDevice *_this, Uint32 *count)
{
    static const char *const extensions[] = { VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_DISPLAY_EXTENSION_NAME };
    if (count) {
        *count = SDL_arraysize(extensions);
    }
    return extensions;
}

static bool PS5_Vulkan_CreateSurface(SDL_VideoDevice *_this, SDL_Window *window, VkInstance instance,
                                     const struct VkAllocationCallbacks *allocator, VkSurfaceKHR *surface)
{
    return SDL_Vulkan_Display_CreateSurface(_this->vulkan_config.vkGetInstanceProcAddr, instance, allocator, surface);
}

static void PS5_Vulkan_DestroySurface(SDL_VideoDevice *_this, VkInstance instance, VkSurfaceKHR surface,
                                      const struct VkAllocationCallbacks *allocator)
{
    SDL_Vulkan_DestroySurface_Internal(_this->vulkan_config.vkGetInstanceProcAddr, instance, surface, allocator);
}
#endif // SDL_VIDEO_VULKAN

/* The console's output, as VK_KHR_display reports its first display */
static bool PS5_OutputSize(int *w, int *h)
{
#ifdef SDL_VIDEO_VULKAN
    PFN_vkCreateInstance create = (PFN_vkCreateInstance)vk_icdGetInstanceProcAddr(VK_NULL_HANDLE, "vkCreateInstance");
    const char *const extensions[] = { VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_DISPLAY_EXTENSION_NAME };
    VkApplicationInfo application = { .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO, .apiVersion = VK_API_VERSION_1_0 };
    VkInstanceCreateInfo info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &application,
        .enabledExtensionCount = SDL_arraysize(extensions),
        .ppEnabledExtensionNames = extensions,
    };
    VkInstance instance = VK_NULL_HANDLE;
    bool found = false;

    if (!create || create(&info, NULL, &instance) != VK_SUCCESS) {
        return false;
    }
#define PS5_VK(name) PFN_##name name = (PFN_##name)vk_icdGetInstanceProcAddr(instance, #name)
    PS5_VK(vkEnumeratePhysicalDevices);
    PS5_VK(vkGetPhysicalDeviceDisplayPropertiesKHR);
    PS5_VK(vkDestroyInstance);
#undef PS5_VK
    VkPhysicalDevice device = VK_NULL_HANDLE;
    uint32_t count = 1;
    if (vkEnumeratePhysicalDevices && vkGetPhysicalDeviceDisplayPropertiesKHR &&
        vkEnumeratePhysicalDevices(instance, &count, &device) >= VK_SUCCESS && count == 1) {
        VkDisplayPropertiesKHR display;
        count = 1;
        if (vkGetPhysicalDeviceDisplayPropertiesKHR(device, &count, &display) >= VK_SUCCESS && count == 1 &&
            display.physicalResolution.width && display.physicalResolution.height) {
            *w = (int)display.physicalResolution.width;
            *h = (int)display.physicalResolution.height;
            found = true;
        }
    }
    if (vkDestroyInstance) {
        vkDestroyInstance(instance, NULL);
    }
    return found;
#else
    return false;
#endif
}

static bool PS5_VideoInit(SDL_VideoDevice *_this)
{
    SDL_DisplayMode mode;
    int w = 1920, h = 1080;
    const char *size = SDL_getenv("SDL_PS5_DISPLAY");

    if (size && SDL_sscanf(size, "%dx%d", &w, &h) == 2) {
        say("video: %dx%d from SDL_PS5_DISPLAY", w, h);
    } else if (PS5_OutputSize(&w, &h)) {
        say("video: the console's output is %dx%d", w, h);
    } else {
        w = 1920;
        h = 1080;
        say("video: the console's output size is unknown, taking %dx%d", w, h);
    }
    SDL_zero(mode);
    mode.format = SDL_PIXELFORMAT_XRGB8888;
    mode.w = w;
    mode.h = h;
    mode.refresh_rate = 60.0f;
    if (SDL_AddBasicVideoDisplay(&mode) == 0) {
        return false;
    }
    /* either may be plugged in later: the libraries stay open */
    ps5_keyboard_opened = keyboard_open();
    ps5_mouse_opened = mouse_open();
    return true;
}

/* Sizes below the output's, in its shape, for a title's settings to list */
static bool PS5_GetDisplayModes(SDL_VideoDevice *_this, SDL_VideoDisplay *display)
{
    static const int heights[] = { 1080, 720, 540 };
    const SDL_DisplayMode *desktop = &display->desktop_mode;

    for (int i = 0; i < (int)SDL_arraysize(heights); i++) {
        SDL_DisplayMode mode = *desktop;
        if (heights[i] >= desktop->h) {
            continue;
        }
        mode.h = heights[i];
        mode.w = heights[i] * desktop->w / desktop->h;
        SDL_AddFullscreenDisplayMode(display, &mode);
    }
    return true;
}

static bool PS5_SetDisplayMode(SDL_VideoDevice *_this, SDL_VideoDisplay *display, SDL_DisplayMode *mode)
{
    /* the output stays as it is: a title draws at the size it likes and SDL's renderer scales */
    return true;
}

static void PS5_VideoQuit(SDL_VideoDevice *_this)
{
}

/* The HID's modifier byte, a bit each: left Ctrl, Shift, Alt, GUI, then the right ones */
static const SDL_Scancode ps5_modifier_keys[8] = {
    SDL_SCANCODE_LCTRL, SDL_SCANCODE_LSHIFT, SDL_SCANCODE_LALT, SDL_SCANCODE_LGUI,
    SDL_SCANCODE_RCTRL, SDL_SCANCODE_RSHIFT, SDL_SCANCODE_RALT, SDL_SCANCODE_RGUI,
};

static void PS5_PumpKeyboard(Uint64 timestamp)
{
    struct keyboard keyboard;

    if (!ps5_keyboard_opened) {
        return;
    }
    keyboard_poll(&keyboard);
    if (keyboard.connected != ps5_keyboard_listed) {
        ps5_keyboard_listed = keyboard.connected;
        if (keyboard.connected) {
            SDL_AddKeyboard(PS5_KEYBOARD_ID, "Keyboard");
        } else {
            SDL_RemoveKeyboard(PS5_KEYBOARD_ID);
            ps5_modifiers = 0;
        }
    }
    if (!keyboard.connected) {
        return;
    }
    for (int bit = 0; bit < 8; bit++) {
        const Uint8 mask = (Uint8)(1u << bit);
        if ((keyboard.modifiers ^ ps5_modifiers) & mask) {
            SDL_SendKeyboardKey(timestamp, PS5_KEYBOARD_ID, 0xe0 + bit, ps5_modifier_keys[bit],
                                (keyboard.modifiers & mask) != 0);
        }
    }
    ps5_modifiers = keyboard.modifiers;
    for (int i = 0; i < keyboard.event_count; i++) {
        const SDL_Scancode scancode = (SDL_Scancode)keyboard.events[i].usage;
        const bool down = keyboard.events[i].down;

        SDL_SendKeyboardKey(timestamp, PS5_KEYBOARD_ID, keyboard.events[i].usage, scancode, down);
        if (down && ps5_window && SDL_TextInputActive(ps5_window) &&
            !(SDL_GetModState() & (SDL_KMOD_CTRL | SDL_KMOD_ALT | SDL_KMOD_GUI))) {
            const SDL_Keycode key = SDL_GetKeyFromScancode(scancode, SDL_GetModState(), false);
            if (key >= 0x20 && key < 0x7f) {
                const char text[2] = { (char)key, 0 };
                SDL_SendKeyboardText(text);
            }
        }
    }
}

static void PS5_PumpMouse(Uint64 timestamp)
{
    static const struct {
        Uint32 console;
        Uint8 sdl;
    } buttons[] = {
        { MOUSE_LEFT, SDL_BUTTON_LEFT }, { MOUSE_RIGHT, SDL_BUTTON_RIGHT }, { MOUSE_MIDDLE, SDL_BUTTON_MIDDLE },
        { MOUSE_BUTTON4, SDL_BUTTON_X1 }, { MOUSE_BUTTON5, SDL_BUTTON_X2 },
    };
    struct mouse mouse;

    if (!ps5_mouse_opened) {
        return;
    }
    mouse_poll(&mouse);
    if (mouse.connected != ps5_mouse_listed) {
        ps5_mouse_listed = mouse.connected;
        if (mouse.connected) {
            SDL_AddMouse(PS5_MOUSE_ID, "Mouse");
        } else {
            SDL_RemoveMouse(PS5_MOUSE_ID);
        }
    }
    if (!mouse.connected || !ps5_window) {
        return;
    }
    if (mouse.dx || mouse.dy) {
        /* a count is a pixel of a 1080p screen, so the pointer crosses a 4K one as quickly */
        const float scale = ps5_window->h > 0 ? (float)ps5_window->h / 1080.0f : 1.0f;
        SDL_SendMouseMotion(timestamp, ps5_window, PS5_MOUSE_ID, true, mouse.dx * scale, mouse.dy * scale);
    }
    for (int i = 0; i < (int)SDL_arraysize(buttons); i++) {
        if ((mouse.buttons ^ ps5_mouse_buttons) & buttons[i].console) {
            SDL_SendMouseButton(timestamp, ps5_window, PS5_MOUSE_ID, buttons[i].sdl,
                                (mouse.buttons & buttons[i].console) != 0);
        }
    }
    ps5_mouse_buttons = mouse.buttons;
    if (mouse.wheel) {
        SDL_SendMouseWheel(timestamp, ps5_window, PS5_MOUSE_ID, 0.0f, (float)mouse.wheel, SDL_MOUSEWHEEL_NORMAL);
    }
}

static void PS5_PumpEvents(SDL_VideoDevice *_this)
{
    const Uint64 timestamp = SDL_GetTicksNS();

    PS5_PumpKeyboard(timestamp);
    PS5_PumpMouse(timestamp);
}

/* A text field takes the keyboard's keys (PS5_PumpKeyboard); the console's own
 * on-screen keyboard is not opened */
static bool PS5_StartTextInput(SDL_VideoDevice *_this, SDL_Window *window, SDL_PropertiesID props)
{
    return true;
}

static bool PS5_StopTextInput(SDL_VideoDevice *_this, SDL_Window *window)
{
    return true;
}

static bool PS5_CreateWindow(SDL_VideoDevice *_this, SDL_Window *window, SDL_PropertiesID props)
{
    /* The window is the screen, and always has the pad's focus */
    ps5_window = window;
    SDL_SetKeyboardFocus(window);
    SDL_SetMouseFocus(window);
    return true;
}

static void PS5_DestroyWindow(SDL_VideoDevice *_this, SDL_Window *window)
{
    if (ps5_window == window) {
        ps5_window = NULL;
    }
}

static bool PS5_SetWindowPosition(SDL_VideoDevice *_this, SDL_Window *window)
{
    return true;
}

static void PS5_SetWindowSize(SDL_VideoDevice *_this, SDL_Window *window)
{
    /* The size stays the display's */
}

static SDL_FullscreenResult PS5_SetWindowFullscreen(SDL_VideoDevice *_this, SDL_Window *window, SDL_VideoDisplay *display, SDL_FullscreenOp fullscreen)
{
    return SDL_FULLSCREEN_SUCCEEDED;
}

static void PS5_DeleteDevice(SDL_VideoDevice *device)
{
    SDL_free(device);
}

static SDL_VideoDevice *PS5_CreateDevice(void)
{
    SDL_VideoDevice *device = (SDL_VideoDevice *)SDL_calloc(1, sizeof(SDL_VideoDevice));
    if (!device) {
        return NULL;
    }
    device->VideoInit = PS5_VideoInit;
    device->VideoQuit = PS5_VideoQuit;
    device->GetDisplayModes = PS5_GetDisplayModes;
    device->SetDisplayMode = PS5_SetDisplayMode;
    device->PumpEvents = PS5_PumpEvents;
    device->CreateSDLWindow = PS5_CreateWindow;
    device->DestroyWindow = PS5_DestroyWindow;
    device->StartTextInput = PS5_StartTextInput;
    device->StopTextInput = PS5_StopTextInput;
    device->SetWindowPosition = PS5_SetWindowPosition;
    device->SetWindowSize = PS5_SetWindowSize;
    device->SetWindowFullscreen = PS5_SetWindowFullscreen;
#ifdef SDL_VIDEO_VULKAN
    device->Vulkan_LoadLibrary = PS5_Vulkan_LoadLibrary;
    device->Vulkan_UnloadLibrary = PS5_Vulkan_UnloadLibrary;
    device->Vulkan_GetInstanceExtensions = PS5_Vulkan_GetInstanceExtensions;
    device->Vulkan_CreateSurface = PS5_Vulkan_CreateSurface;
    device->Vulkan_DestroySurface = PS5_Vulkan_DestroySurface;
#endif
    device->free = PS5_DeleteDevice;
    device->device_caps = VIDEO_DEVICE_CAPS_FULLSCREEN_ONLY;
    return device;
}

VideoBootStrap PS5_bootstrap = {
    "ps5", "PlayStation 5 video driver",
    PS5_CreateDevice,
    NULL, // no ShowMessageBox implementation
    false
};

#endif // SDL_VIDEO_DRIVER_PS5
