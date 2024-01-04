/*
    This file is part of Flycast.

    Flycast is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    Flycast is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Flycast.  If not, see <https://www.gnu.org/licenses/>.
 */
#include <cstdio>
#include <cstdarg>
#include <math.h>
#include "types.h"
#ifndef _WIN32
#include <sys/time.h>
#endif
#include <mutex>

#ifdef __SWITCH__
#include <stdlib.h>
#include <string.h>
#include "nswitch.h"
#endif

#include <sys/stat.h>
#include <file/file_path.h>

#include <libretro.h>

#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
#include <glsm/glsm.h>
#include "wsi/gl_context.h"
#endif
#ifdef HAVE_VULKAN
#include "rend/vulkan/vulkan_context.h"
#include <libretro_vulkan.h>
#endif
#ifdef HAVE_D3D11
#include <libretro_d3d.h>
#include "rend/dx11/dx11context_lr.h"
#endif
#include "emulator.h"
#include "hw/sh4/sh4_mem.h"
#include "hw/sh4/sh4_sched.h"
#include "hw/sh4/dyna/blockmanager.h"
#include "keyboard_map.h"
#include "hw/maple/maple_cfg.h"
#include "hw/maple/maple_if.h"
#include "hw/maple/maple_cfg.h"
#include "hw/pvr/spg.h"
#include "hw/naomi/naomi_cart.h"
#include "hw/naomi/card_reader.h"
#include "imgread/common.h"
#include "LogManager.h"
#include "cheats.h"
#include "rend/osd.h"
#include "cfg/option.h"
#include "version.h"
#include "rend/transform_matrix.h"

constexpr char slash = path_default_slash_c();

#define RETRO_DEVICE_TWINSTICK				RETRO_DEVICE_SUBCLASS( RETRO_DEVICE_JOYPAD, 1 )
#define RETRO_DEVICE_TWINSTICK_SATURN		RETRO_DEVICE_SUBCLASS( RETRO_DEVICE_JOYPAD, 2 )
#define RETRO_DEVICE_ASCIISTICK				RETRO_DEVICE_SUBCLASS( RETRO_DEVICE_JOYPAD, 3 )

#define RETRO_ENVIRONMENT_RETROARCH_START_BLOCK 0x800000

#define RETRO_ENVIRONMENT_SET_SAVE_STATE_IN_BACKGROUND (2 | RETRO_ENVIRONMENT_RETROARCH_START_BLOCK)
                                            /* bool * --
                                            * Boolean value that tells the front end to save states in the
                                            * background or not.
                                            */

#define RETRO_ENVIRONMENT_POLL_TYPE_OVERRIDE (4 | RETRO_ENVIRONMENT_RETROARCH_START_BLOCK)
                                            /* unsigned * --
                                            * Tells the frontend to override the poll type behavior. 
                                            * Allows the frontend to influence the polling behavior of the
                                            * frontend.
                                            *
                                            * Will be unset when retro_unload_game is called.
                                            *
                                            * 0 - Don't Care, no changes, frontend still determines polling type behavior.
                                            * 1 - Early
                                            * 2 - Normal
                                            * 3 - Late
                                            */

#include "libretro_core_option_defines.h"
#include "libretro_core_options.h"
#include "vmu_xhair.h"

extern void retro_audio_init(void);
extern void retro_audio_deinit(void);
extern void retro_audio_flush_buffer(void);
extern void retro_audio_upload(void);

std::string arcadeFlashPath;
static bool boot_to_bios;

static bool devices_need_refresh = false;
static int device_type[4] = {-1,-1,-1,-1};
static int astick_deadzone = 0;
static int trigger_deadzone = 0;
static bool digital_triggers = false;
static bool allow_service_buttons = false;
static bool haveCardReader;

static bool libretro_supports_bitmasks = false;

static bool categoriesSupported = false;
static bool platformIsDreamcast = true;
static bool platformIsArcade = false;
static bool threadedRenderingEnabled = true;
static bool oitEnabled = false;
static bool autoSkipFrameEnabled = false;
#ifdef _OPENMP
static bool textureUpscaleEnabled = false;
#endif
static bool vmuScreenSettingsShown = true;
static bool lightgunSettingsShown = true;

u32 kcode[4] = {0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF};
u8 rt[4];
u8 lt[4];
u8 lt2[4];
u8 rt2[4];
u32 vks[4];
s8 joyx[4], joyy[4];
s8 joyrx[4], joyry[4];
s8 joy3x[4], joy3y[4];
// Mouse buttons
// bit 0: Button C
// bit 1: Right button (B)
// bit 2: Left button (A)
// bit 3: Wheel button
u8 mo_buttons[4] = { 0xFF, 0xFF, 0xFF, 0xFF };
// Relative mouse coordinates [-512:511]
float mo_x_delta[4];
float mo_y_delta[4];
float mo_wheel_delta[4];
std::mutex relPosMutex;
// Absolute mouse coordinates
// Range [0:639] [0:479]
// but may be outside this range if the pointer is offscreen or outside the 4:3 window.
s32 mo_x_abs[4];
s32 mo_y_abs[4];

static bool enable_purupuru = true;
static u32 vib_stop_time[4];
static double vib_strength[4];
static double vib_delta[4];

unsigned per_content_vmus = 0;

static bool first_run = true;
static bool rotate_screen;
static bool rotate_game;
static int framebufferWidth;
static int framebufferHeight;
static int maxFramebufferWidth;
static int maxFramebufferHeight;
static float framebufferAspectRatio = 4.f / 3.f;

float libretro_expected_audio_samples_per_run;
unsigned libretro_vsync_swap_interval = 1;
bool libretro_detect_vsync_swap_interval = false;

static retro_perf_callback perf_cb;
static retro_get_cpu_features_t perf_get_cpu_features_cb;

// Callbacks
static retro_log_printf_t         log_cb;
static retro_video_refresh_t      video_cb;
static retro_input_poll_t         poll_cb;
static retro_input_state_t        input_cb;
retro_audio_sample_batch_t        audio_batch_cb;
retro_environment_t               environ_cb;

static retro_rumble_interface rumble;

static void refresh_devices(bool first_startup);
static void init_disk_control_interface();
static bool read_m3u(const char *file);
void gui_display_notification(const char *msg, int duration);
static void updateVibration(u32 port, float power, float inclination, u32 durationMs);

static std::string game_data;
static char g_base_name[128];
static char game_dir[1024];
char game_dir_no_slash[1024];
char vmu_dir_no_slash[PATH_MAX];
char content_name[PATH_MAX];
static char g_roms_dir[PATH_MAX];
static std::mutex mtx_serialization;
static bool gl_ctx_resetting = false;
static bool is_dupe;
static u64 startTime;

// Disk swapping
static struct retro_disk_control_callback retro_disk_control_cb;
static struct retro_disk_control_ext_callback retro_disk_control_ext_cb;
static unsigned disk_initial_index = 0;
static std::string disk_initial_path;
static unsigned disk_index = 0;
static std::vector<std::string> disk_paths;
static std::vector<std::string> disk_labels;
static bool disc_tray_open = false;

void UpdateInputState();
static bool set_variable_visibility(void);

void retro_set_video_refresh(retro_video_refresh_t cb)
{
	video_cb = cb;
}

void retro_set_audio_sample(retro_audio_sample_t cb)
{
	// Nothing to do here
}

void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb)
{
	audio_batch_cb = cb;
}

void retro_set_input_poll(retro_input_poll_t cb)
{
	poll_cb = cb;
}

void retro_set_input_state(retro_input_state_t cb)
{
	input_cb = cb;
}

static void input_set_deadzone_stick(int percent)
{
	if (percent >= 0 && percent <= 100)
		astick_deadzone = (int)(percent * 0.01f * 0x8000);
}

static void input_set_deadzone_trigger(int percent)
{
	if (percent >= 0 && percent <= 100)
		trigger_deadzone = (int)(percent * 0.01f * 0x8000);
}

void retro_set_environment(retro_environment_t cb)
{
	environ_cb = cb;

	// An annoyance: retro_set_environment() can be called
	// multiple times, and depending upon the current frontend
	// state various environment callbacks may be disabled.
	// This means the reported 'categories_supported' status
	// may change on subsequent iterations. We therefore have
	// to record whether 'categories_supported' is true on any
	// iteration, and latch the result
	bool optionCategoriesSupported = false;
	libretro_set_core_options(environ_cb, &optionCategoriesSupported);
	categoriesSupported |= optionCategoriesSupported;

	struct retro_core_options_update_display_callback update_display_cb;
	update_display_cb.callback = set_variable_visibility;
	environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_UPDATE_DISPLAY_CALLBACK, &update_display_cb);

	static const struct retro_controller_description ports_default[] =
	{
			{ "Controller",			RETRO_DEVICE_JOYPAD },
			{ "Arcade Stick",		RETRO_DEVICE_ASCIISTICK },
			{ "Keyboard",			RETRO_DEVICE_KEYBOARD },
			{ "Mouse",				RETRO_DEVICE_MOUSE },
			{ "Light Gun",			RETRO_DEVICE_LIGHTGUN },
			{ "Twin Stick",			RETRO_DEVICE_TWINSTICK },
			{ "Saturn Twin-Stick",	RETRO_DEVICE_TWINSTICK_SATURN },
			{ "Pointer",			RETRO_DEVICE_POINTER },
			{ 0 },
	};
	static const struct retro_controller_info ports[] = {
			{ ports_default,  8 },
			{ ports_default,  8 },
			{ ports_default,  8 },
			{ ports_default,  8 },
			{ 0 },
	};
	environ_cb(RETRO_ENVIRONMENT_SET_CONTROLLER_INFO, (void*)ports);
}

static void retro_keyboard_event(bool down, unsigned keycode, uint32_t character, uint16_t key_modifiers);

// Now comes the interesting stuff
void retro_init()
{
	static bool emuInited;
    settings.dynarec.disable_nvmem=true;

	// Logging
	struct retro_log_callback log;
	if (environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log))
		log_cb = log.log;
	else
		log_cb = NULL;
	LogManager::Init((void *)log_cb);
	NOTICE_LOG(BOOT, "retro_init");

	if (environ_cb(RETRO_ENVIRONMENT_GET_PERF_INTERFACE, &perf_cb))
		perf_get_cpu_features_cb = perf_cb.get_cpu_features;
	else
		perf_get_cpu_features_cb = NULL;

	// Set color mode
	unsigned color_mode = RETRO_PIXEL_FORMAT_XRGB8888;
	environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &color_mode);
    /*
	init_kb_map();
	struct retro_keyboard_callback kb_callback = { &retro_keyboard_event };
	environ_cb(RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK, &kb_callback);
     */
	if (environ_cb(RETRO_ENVIRONMENT_GET_INPUT_BITMASKS, NULL))
		libretro_supports_bitmasks = true;

	init_disk_control_interface();
	retro_audio_init();

#if defined(__APPLE__)
    char *data_dir = NULL;
    if (environ_cb(RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY, &data_dir) && data_dir)
        set_user_data_dir(std::string(data_dir) + "/");
#endif

	if (!addrspace::reserve())
		ERROR_LOG(VMEM, "Cannot reserve memory space");

	os_InstallFaultHandler();
	MapleConfigMap::UpdateVibration = updateVibration;

#if defined(__APPLE__) || (defined(__GNUC__) && defined(__linux__) && !defined(__ANDROID__))
	if (!emuInited)
#endif
		emu.init();
	emuInited = true;
}

void retro_deinit()
{
	INFO_LOG(COMMON, "retro_deinit");
	first_run = true;

	//When auto-save states are enabled this is needed to prevent the core from shutting down before
	//any save state actions are still running - which results in partial saves
	{
		std::lock_guard<std::mutex> lock(mtx_serialization);
	}
	os_UninstallFaultHandler();
	
#if defined(__APPLE__) || (defined(__GNUC__) && defined(__linux__) && !defined(__ANDROID__))
	addrspace::release();
#else
	emu.term();
#endif
	libretro_supports_bitmasks = false;
	categoriesSupported = false;
	platformIsDreamcast = true;
	platformIsArcade = false;
	threadedRenderingEnabled = true;
	oitEnabled = false;
	autoSkipFrameEnabled = false;
#ifdef _OPENMP
	textureUpscaleEnabled = false;
#endif
	vmuScreenSettingsShown = true;
	lightgunSettingsShown = true;
	libretro_vsync_swap_interval = 1;
	libretro_detect_vsync_swap_interval = false;
	LogManager::Shutdown();

	retro_audio_deinit();
}

static bool set_variable_visibility(void)
{
	struct retro_core_option_display option_display;
	struct retro_variable var;
	bool updated = false;

	bool platformWasDreamcast = platformIsDreamcast;
	bool platformWasArcade = platformIsArcade;

	platformIsDreamcast = settings.platform.isConsole();
	platformIsArcade = settings.platform.isArcade();

	// Show/hide platform-dependent options
	if (first_run || (platformIsDreamcast != platformWasDreamcast) || (platformIsArcade != platformWasArcade))
	{
		// Show/hide NAOMI/Atomiswave options
		option_display.visible = platformIsArcade;
		option_display.key = CORE_OPTION_NAME "_allow_service_buttons";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);

		// Show/hide Dreamcast options
		option_display.visible = platformIsDreamcast;
		option_display.key = CORE_OPTION_NAME "_boot_to_bios";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_hle_bios";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_gdrom_fast_loading";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_cable_type";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_broadcast";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_language";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_force_wince";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_enable_purupuru";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_per_content_vmus";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.visible = platformIsDreamcast || settings.platform.isAtomiswave();
		option_display.key = CORE_OPTION_NAME "_emulate_bba";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_upnp";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);

		vmuScreenSettingsShown = option_display.visible;
		for (unsigned i = 0; i < 4; i++)
		{
			char key[256];
			option_display.key = key;

			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_display");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_position");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_size_mult");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_pixel_on_color");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_pixel_off_color");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_opacity");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		}

		// Show/hide manual option visibility toggles
		// > Only show if categories are not supported
		option_display.visible = platformIsDreamcast && !categoriesSupported;
		option_display.key = CORE_OPTION_NAME "_show_vmu_screen_settings";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);

		updated = true;
	}

	// Show/hide additional manual option visibility toggles
	// > Only show if categories are not supported
	if (first_run)
	{
		option_display.visible = !categoriesSupported;
		option_display.key = CORE_OPTION_NAME "_show_lightgun_settings";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		updated = true;
	}

	// Show/hide settings-dependent options

	// Only for threaded renderer
	bool threadedRenderingWasEnabled = threadedRenderingEnabled;
	threadedRenderingEnabled = true;
	var.key = CORE_OPTION_NAME "_threaded_rendering";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && !strcmp(var.value, "disabled"))
		threadedRenderingEnabled = false;

	if (first_run || (threadedRenderingEnabled != threadedRenderingWasEnabled))
	{
		option_display.visible = threadedRenderingEnabled;
		option_display.key = CORE_OPTION_NAME "_auto_skip_frame";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		updated = true;
	}

#if defined(HAVE_OIT) || defined(HAVE_VULKAN) || defined(HAVE_D3D11)
	// Only for per-pixel renderers
	bool oitWasEnabled = oitEnabled;
	oitEnabled = false;
	var.key = CORE_OPTION_NAME "_alpha_sorting";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && !strcmp(var.value, "per-pixel (accurate)"))
		oitEnabled = true;

	if (first_run || (oitEnabled != oitWasEnabled))
	{
		option_display.visible = oitEnabled;
		option_display.key = CORE_OPTION_NAME "_oit_abuffer_size";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		option_display.key = CORE_OPTION_NAME "_oit_layers";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		updated = true;
	}
#endif

#ifdef _OPENMP
	// Only if texture upscaling is enabled
	bool textureUpscaleWasEnabled = textureUpscaleEnabled;
	textureUpscaleEnabled = false;
	var.key = CORE_OPTION_NAME "_texupscale";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && strcmp(var.value, "off"))
		textureUpscaleEnabled = true;

	if (first_run || (textureUpscaleEnabled != textureUpscaleWasEnabled))
	{
		option_display.visible = textureUpscaleEnabled;
		option_display.key = CORE_OPTION_NAME "_texupscale_max_filtered_texture_size";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		updated = true;
	}
#endif

	// Only if automatic frame skipping is disabled
	bool autoSkipFrameWasEnabled = autoSkipFrameEnabled;

	autoSkipFrameEnabled = false;
	var.key = CORE_OPTION_NAME "_auto_skip_frame";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && strcmp(var.value, "disabled"))
		autoSkipFrameEnabled = true;

	if (first_run ||
		 (autoSkipFrameEnabled != autoSkipFrameWasEnabled) ||
		 (threadedRenderingEnabled != threadedRenderingWasEnabled))
	{
		option_display.visible = (!autoSkipFrameEnabled || !threadedRenderingEnabled);
		option_display.key = CORE_OPTION_NAME "_detect_vsync_swap_interval";
		environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		updated = true;
	}

	// If categories are supported, no further action is required
	if (categoriesSupported)
		return updated;

	// Show/hide VMU screen options
	bool vmuScreenSettingsWereShown = vmuScreenSettingsShown;

	if (platformIsDreamcast)
	{
		vmuScreenSettingsShown = true;
		var.key = CORE_OPTION_NAME "_show_vmu_screen_settings";

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && !strcmp(var.value, "disabled"))
			vmuScreenSettingsShown = false;
	}
	else
		vmuScreenSettingsShown = false;

	if (first_run || (vmuScreenSettingsShown != vmuScreenSettingsWereShown))
	{
		option_display.visible = vmuScreenSettingsShown;

		for (unsigned i = 0; i < 4; i++)
		{
			char key[256];
			option_display.key = key;

			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_display");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_position");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_size_mult");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_pixel_on_color");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_pixel_off_color");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_vmu", i + 1, "_screen_opacity");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		}

		updated = true;
	}

	// Show/hide light gun options
	bool lightgunSettingsWereShown = lightgunSettingsShown;
	lightgunSettingsShown = true;
	var.key = CORE_OPTION_NAME "_show_lightgun_settings";

	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && !strcmp(var.value, "disabled"))
		lightgunSettingsShown = false;

	if (first_run || (lightgunSettingsShown != lightgunSettingsWereShown))
	{
		option_display.visible = lightgunSettingsShown;

		for (unsigned i = 0; i < 4; i++)
		{
			char key[256];
			option_display.key = key;

			snprintf(key, sizeof(key), "%s%u%s", CORE_OPTION_NAME "_lightgun", i + 1, "_crosshair");
			environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY, &option_display);
		}

		updated = true;
	}

	return updated;
}

static void setGameGeometry(retro_game_geometry& geometry)
{
	geometry.aspect_ratio = framebufferAspectRatio;
	if (rotate_screen)
		geometry.aspect_ratio = 1 / geometry.aspect_ratio;
	geometry.max_width = std::max(framebufferHeight * 16 / 9, framebufferWidth);
	geometry.max_height = geometry.max_width;
	// Avoid gigantic window size at startup
	geometry.base_width = 640;
	geometry.base_height = 480;
}

void setAVInfo(retro_system_av_info& avinfo)
{
	double sample_rate = 44100.0;
	double fps = SPG_CONTROL.NTSC ? 59.94 : SPG_CONTROL.PAL ? 50.0 : 60.0;

	setGameGeometry(avinfo.geometry);
	avinfo.timing.sample_rate = sample_rate;
	avinfo.timing.fps = fps / (double)libretro_vsync_swap_interval;

	libretro_expected_audio_samples_per_run = sample_rate / fps;
}

void retro_resize_renderer(int w, int h, float aspectRatio)
{
	if (w == framebufferWidth && h == framebufferHeight && aspectRatio == framebufferAspectRatio)
		return;
	framebufferWidth = w;
	framebufferHeight = h;
	framebufferAspectRatio = aspectRatio;
	bool avinfoNeeded = framebufferHeight > maxFramebufferHeight || framebufferWidth > maxFramebufferWidth;
	maxFramebufferHeight = std::max(maxFramebufferHeight, framebufferHeight);
	maxFramebufferWidth = std::max(maxFramebufferWidth, framebufferWidth);

	if (avinfoNeeded)
	{
		retro_system_av_info avinfo;
		setAVInfo(avinfo);
		environ_cb(RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO, &avinfo);
	}
	else
	{
		retro_game_geometry geometry;
		setGameGeometry(geometry);
		environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, &geometry);
	}
}

static void setRotation()
{
	int rotation = 0;
	if (rotate_game)
	{
		if (!rotate_screen)
			rotation = 1;
		rotate_screen = !rotate_screen;
	}
	else
	{
		if (rotate_screen)
			rotation = 3;
	}
	environ_cb(RETRO_ENVIRONMENT_SET_ROTATION, &rotation);
}

static void update_variables(bool first_startup)
{
	bool wasThreadedRendering = config::ThreadedRendering;
	bool prevRotateScreen = rotate_screen;
	bool prevDetectVsyncSwapInterval = libretro_detect_vsync_swap_interval;
	bool emulateBba = config::EmulateBBA;
	config::Settings::instance().setRetroEnvironment(environ_cb);
	config::Settings::instance().setOptionDefinitions(option_defs_us);
	config::Settings::instance().load(false);

	retro_variable var;

	var.key = CORE_OPTION_NAME "_per_content_vmus";
	unsigned previous_per_content_vmus = per_content_vmus;
	per_content_vmus = 0;
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
	{
		if (!strcmp("VMU A1", var.value))
			per_content_vmus = 1;
		else if (!strcmp("All VMUs", var.value))
			per_content_vmus = 2;
	}
	if (!first_startup && per_content_vmus != previous_per_content_vmus
			&& settings.platform.isConsole())
	{
		// Recreate the VMUs so that the save location is taken into account.
		// Don't do this at startup because we don't know the system type yet
		// and the VMUs haven't been created anyway
		maple_ReconnectDevices();
	}

	var.key = CORE_OPTION_NAME "_screen_rotation";
	rotate_screen = false;
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && !strcmp("vertical", var.value))
		rotate_screen = true;

	var.key = CORE_OPTION_NAME "_internal_resolution";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
	{
		char str[100];
		snprintf(str, sizeof(str), "%s", var.value);

		char *pch = strtok(str, "x");
		pch = strtok(NULL, "x");
		if (pch != nullptr)
			config::RenderResolution = strtoul(pch, NULL, 0);

		DEBUG_LOG(COMMON, "Got height: %u", (int)config::RenderResolution);
	}

	var.key = CORE_OPTION_NAME "_boot_to_bios";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
	{
		if (!strcmp(var.value, "enabled"))
			boot_to_bios = true;
		else if (!strcmp(var.value, "disabled"))
			boot_to_bios = false;
	}
	else
		boot_to_bios = false;

	var.key = CORE_OPTION_NAME "_alpha_sorting";
	var.value = nullptr;
	RenderType previous_renderer = config::RendererType;
	environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var);
	if (var.value != nullptr && !strcmp(var.value, "per-pixel (accurate)"))
	{
		switch (config::RendererType)
		{
		case RenderType::Vulkan:
			config::RendererType = RenderType::Vulkan_OIT;
			break;
		case RenderType::DirectX11:
			config::RendererType = RenderType::DirectX11_OIT;
			break;
		case RenderType::OpenGL:
			config::RendererType = RenderType::OpenGL_OIT;
			break;
		default:
			break;
		}
		config::PerStripSorting = false;	// Not used
	}
	else
	{
		switch (config::RendererType)
		{
		case RenderType::Vulkan_OIT:
			config::RendererType = RenderType::Vulkan;
			break;
		case RenderType::DirectX11_OIT:
			config::RendererType = RenderType::DirectX11;
			break;
		case RenderType::OpenGL_OIT:
			config::RendererType = RenderType::OpenGL;
			break;
		default:
			break;
		}
		config::PerStripSorting = var.value != nullptr && !strcmp(var.value, "per-strip (fast, least accurate)");
	}

	if (!first_startup && previous_renderer != config::RendererType) {
		rend_term_renderer();
		rend_init_renderer();
	}

#if defined(HAVE_OIT) || defined(HAVE_VULKAN) || defined(HAVE_D3D11)
	var.key = CORE_OPTION_NAME "_oit_abuffer_size";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
	{
		if (!strcmp(var.value, "512MB"))
			config::PixelBufferSize = 0x20000000u;
		else if (!strcmp(var.value, "1GB"))
			config::PixelBufferSize = 0x40000000u;
		else if (!strcmp(var.value, "2GB"))
			config::PixelBufferSize = 0x7ff00000u;
		else if (!strcmp(var.value, "4GB"))
			config::PixelBufferSize = 0xFFFFFFFFu;
		else
			config::PixelBufferSize = 0x20000000u;
	}
	else
		config::PixelBufferSize = 0x20000000u;
#endif

	if ((config::AutoSkipFrame != 0) && config::ThreadedRendering)
		libretro_detect_vsync_swap_interval = false;
	else
	{
		var.key = CORE_OPTION_NAME "_detect_vsync_swap_interval";
		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
		{
			if (!strcmp(var.value, "enabled"))
				libretro_detect_vsync_swap_interval = true;
			else if (!strcmp(var.value, "disabled"))
				libretro_detect_vsync_swap_interval = false;
		}
		else
			libretro_detect_vsync_swap_interval = false;
	}

	if (first_startup)
	{
		if (config::ThreadedRendering)
		{
			bool save_state_in_background = true ;
			unsigned poll_type_early      = 1; /* POLL_TYPE_EARLY */
			environ_cb(RETRO_ENVIRONMENT_SET_SAVE_STATE_IN_BACKGROUND, &save_state_in_background);
			environ_cb(RETRO_ENVIRONMENT_POLL_TYPE_OVERRIDE, &poll_type_early);
		}

		config::Cable = 3;
		var.key = CORE_OPTION_NAME "_cable_type";
		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
		{
			if (!strcmp("VGA", var.value))
				config::Cable = 0;
			else if (!strcmp("TV (RGB)", var.value))
				config::Cable = 2;
		}
	}

	var.key = CORE_OPTION_NAME "_enable_purupuru";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
	{
		if (enable_purupuru != (strcmp("enabled", var.value) == 0) && settings.platform.isConsole())
		{
			enable_purupuru = strcmp("enabled", var.value) == 0;
			for (int i = 0; i < MAPLE_PORTS; i++) {
				if (config::MapleMainDevices[i] == MDT_SegaController)
					config::MapleExpansionDevices[i][1] = enable_purupuru ? MDT_PurupuruPack : MDT_SegaVMU;
				else if (config::MapleMainDevices[i] == MDT_LightGun || config::MapleMainDevices[i] == MDT_TwinStick
						|| config::MapleMainDevices[i] == MDT_AsciiStick)
					config::MapleExpansionDevices[i][0] = enable_purupuru ? MDT_PurupuruPack : MDT_SegaVMU;
			}

			if (!first_startup)
				maple_ReconnectDevices();
		}
	}

	var.key = CORE_OPTION_NAME "_analog_stick_deadzone";
	var.value = NULL;
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
		input_set_deadzone_stick( atoi( var.value ) );

	var.key = CORE_OPTION_NAME "_trigger_deadzone";
	var.value = NULL;
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
		input_set_deadzone_trigger( atoi( var.value ) );

	var.key = CORE_OPTION_NAME "_digital_triggers";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
	{
		if (!strcmp("enabled", var.value))
			digital_triggers = true;
		else
			digital_triggers = false;
	}
	else
		digital_triggers = false;

	var.key = CORE_OPTION_NAME "_allow_service_buttons";
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
	{
		if (!strcmp("enabled", var.value))
			allow_service_buttons = true;
		else
			allow_service_buttons = false;
	}
	else
		allow_service_buttons = false;

	char key[256];
	key[0] = '\0';

	var.key = key ;
	for (int i = 0 ; i < 4 ; i++)
	{
		lightgun_params[i].offscreen = true;
		lightgun_params[i].x = 0;
		lightgun_params[i].y = 0;
		lightgun_params[i].dirty = true;
		lightgun_params[i].colour = LIGHTGUN_COLOR_OFF;

		snprintf(key, sizeof(key), CORE_OPTION_NAME "_lightgun%d_crosshair", i+1) ;

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value  )
		{
			if (!strcmp("disabled", var.value))
				lightgun_params[i].colour = LIGHTGUN_COLOR_OFF;
			else if (!strcmp("White", var.value))
				lightgun_params[i].colour = LIGHTGUN_COLOR_WHITE;
			else if (!strcmp("Red", var.value))
				lightgun_params[i].colour = LIGHTGUN_COLOR_RED;
			else if (!strcmp("Green", var.value))
				lightgun_params[i].colour = LIGHTGUN_COLOR_GREEN;
			else if (!strcmp("Blue", var.value))
				lightgun_params[i].colour = LIGHTGUN_COLOR_BLUE;
		}
		if (lightgun_params[i].colour == LIGHTGUN_COLOR_OFF)
			config::CrosshairColor[i] = 0;
		else
			config::CrosshairColor[i] = lightgun_palette[lightgun_params[i].colour * 3]
										| (lightgun_palette[lightgun_params[i].colour * 3 + 1] << 8)
										| (lightgun_palette[lightgun_params[i].colour * 3 + 2] << 16)
										| 0xff000000;

		vmu_lcd_status[i * 2] = false;
		vmu_lcd_changed[i * 2] = true;
		vmu_screen_params[i].vmu_screen_position = UPPER_LEFT;
		vmu_screen_params[i].vmu_screen_size_mult = 1;
		vmu_screen_params[i].vmu_pixel_on_R = VMU_SCREEN_COLOR_MAP[VMU_DEFAULT_ON].r;
		vmu_screen_params[i].vmu_pixel_on_G = VMU_SCREEN_COLOR_MAP[VMU_DEFAULT_ON].g;
		vmu_screen_params[i].vmu_pixel_on_B = VMU_SCREEN_COLOR_MAP[VMU_DEFAULT_ON].b;
		vmu_screen_params[i].vmu_pixel_off_R = VMU_SCREEN_COLOR_MAP[VMU_DEFAULT_OFF].r;
		vmu_screen_params[i].vmu_pixel_off_G = VMU_SCREEN_COLOR_MAP[VMU_DEFAULT_OFF].g;
		vmu_screen_params[i].vmu_pixel_off_B = VMU_SCREEN_COLOR_MAP[VMU_DEFAULT_OFF].b;
		vmu_screen_params[i].vmu_screen_opacity = 0xFF;

		snprintf(key, sizeof(key), CORE_OPTION_NAME "_vmu%d_screen_display", i+1);

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && !strcmp("enabled", var.value) )
			vmu_lcd_status[i * 2] = true;

		snprintf(key, sizeof(key), CORE_OPTION_NAME "_vmu%d_screen_position", i+1);

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
		{
			if (!strcmp("Upper Left", var.value))
				vmu_screen_params[i].vmu_screen_position = UPPER_LEFT;
			else if (!strcmp("Upper Right", var.value))
				vmu_screen_params[i].vmu_screen_position = UPPER_RIGHT;
			else if (!strcmp("Lower Left", var.value))
				vmu_screen_params[i].vmu_screen_position = LOWER_LEFT;
			else if (!strcmp("Lower Right", var.value))
				vmu_screen_params[i].vmu_screen_position = LOWER_RIGHT;
		}

		snprintf(key, sizeof(key), CORE_OPTION_NAME "_vmu%d_screen_size_mult", i+1);

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
		{
			if (!strcmp("1x", var.value))
				vmu_screen_params[i].vmu_screen_size_mult = 1;
			else if (!strcmp("2x", var.value))
				vmu_screen_params[i].vmu_screen_size_mult = 2;
			else if (!strcmp("3x", var.value))
				vmu_screen_params[i].vmu_screen_size_mult = 3;
			else if (!strcmp("4x", var.value))
				vmu_screen_params[i].vmu_screen_size_mult = 4;
			else if (!strcmp("5x", var.value))
				vmu_screen_params[i].vmu_screen_size_mult = 5;
		}

		snprintf(key, sizeof(key), CORE_OPTION_NAME "_vmu%d_screen_opacity", i + 1);

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
		{
			if (!strcmp("100%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 255;
			else if (!strcmp("90%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 9*25.5;
			else if (!strcmp("80%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 8*25.5;
			else if (!strcmp("70%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 7*25.5;
			else if (!strcmp("60%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 6*25.5;
			else if (!strcmp("50%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 5*25.5;
			else if (!strcmp("40%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 4*25.5;
			else if (!strcmp("30%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 3*25.5;
			else if (!strcmp("20%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 2*25.5;
			else if (!strcmp("10%", var.value))
				vmu_screen_params[i].vmu_screen_opacity = 1*25.5;
		}

		snprintf(key, sizeof(key), CORE_OPTION_NAME "_vmu%d_pixel_on_color", i + 1);

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && strlen(var.value)>1)
		{
			int color_idx = atoi(var.value+(strlen(var.value)-2));
			vmu_screen_params[i].vmu_pixel_on_R = VMU_SCREEN_COLOR_MAP[color_idx].r;
			vmu_screen_params[i].vmu_pixel_on_G = VMU_SCREEN_COLOR_MAP[color_idx].g;
			vmu_screen_params[i].vmu_pixel_on_B = VMU_SCREEN_COLOR_MAP[color_idx].b;
		}

		snprintf(key, sizeof(key), CORE_OPTION_NAME "_vmu%d_pixel_off_color", i+1);

		if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value && strlen(var.value)>1)
		{
			int color_idx = atoi(var.value+(strlen(var.value)-2));
			vmu_screen_params[i].vmu_pixel_off_R = VMU_SCREEN_COLOR_MAP[color_idx].r;
			vmu_screen_params[i].vmu_pixel_off_G = VMU_SCREEN_COLOR_MAP[color_idx].g;
			vmu_screen_params[i].vmu_pixel_off_B = VMU_SCREEN_COLOR_MAP[color_idx].b;
		}
	}

	set_variable_visibility();

	if (!first_startup)
	{
		if (wasThreadedRendering != config::ThreadedRendering)
		{
			config::ThreadedRendering = wasThreadedRendering;
			try {
				emu.stop();
				config::ThreadedRendering = !wasThreadedRendering;
				emu.start();
			} catch (const FlycastException& e) {
				ERROR_LOG(COMMON, "%s", e.what());
			}
		}
		if (rotate_screen != (prevRotateScreen ^ rotate_game))
		{
			setRotation();
			retro_game_geometry geometry;
			setGameGeometry(geometry);
			environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, &geometry);
		}
		else
			rotate_screen ^= rotate_game;
		if (rotate_game)
			config::Widescreen.override(false);

		if ((libretro_detect_vsync_swap_interval != prevDetectVsyncSwapInterval) &&
			 !libretro_detect_vsync_swap_interval &&
			 (libretro_vsync_swap_interval != 1))
		{
			libretro_vsync_swap_interval = 1;
			retro_system_av_info avinfo;
			setAVInfo(avinfo);
			environ_cb(RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO, &avinfo);
		}
		// must *not* be changed once a game is started
		config::EmulateBBA.override(emulateBba);
	}
}

void retro_run()
{
	bool updated = false;
	if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated) && updated)
		update_variables(false);

	if (devices_need_refresh)
		refresh_devices(false);

#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
	if (isOpenGL(config::RendererType))
		glsm_ctl(GLSM_CTL_STATE_BIND, nullptr);
#endif

	// On the first call, we start the emulator
	if (first_run)
		emu.start();

	poll_cb();
	UpdateInputState();
	bool fastforward = false;
	if (environ_cb(RETRO_ENVIRONMENT_GET_FASTFORWARDING, &fastforward))
		settings.input.fastForwardMode = fastforward;

	is_dupe = true;
	try {
		if (config::ThreadedRendering)
		{
			// Render
			for (int i = 0; i < 5 && is_dupe; i++)
				is_dupe = !emu.render();
		}
		else
		{
			startTime = sh4_sched_now64();
			emu.render();
		}
	} catch (const FlycastException& e) {
		ERROR_LOG(COMMON, "%s", e.what());
		gui_display_notification(e.what(), 5000);
		environ_cb(RETRO_ENVIRONMENT_SHUTDOWN, NULL);
	}

#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
	if (isOpenGL(config::RendererType))
		glsm_ctl(GLSM_CTL_STATE_UNBIND, nullptr);
#endif

	video_cb(is_dupe ? 0 : RETRO_HW_FRAME_BUFFER_VALID, framebufferWidth, framebufferHeight, 0);

	if (!config::ThreadedRendering || config::LimitFPS)
		retro_audio_upload();
	else
		retro_audio_flush_buffer();

	first_run = false;
}

static bool loadGame()
{
	try {
		emu.loadGame(game_data.c_str());
	} catch (const FlycastException& e) {
		ERROR_LOG(BOOT, "%s", e.what());
		gui_display_notification(e.what(), 5000);
        retro_unload_game();
		return false;
	}

	return true;
}

void retro_reset()
{
	std::lock_guard<std::mutex> lock(mtx_serialization);

	emu.unloadGame();

	config::ScreenStretching = 100;
	loadGame();
	if (rotate_game)
		config::Widescreen.override(false);
	config::Rotate90 = false;

	retro_game_geometry geometry;
	setGameGeometry(geometry);
	environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, &geometry);
	blankVmus();
	retro_audio_flush_buffer();

	emu.start();
}

#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
static void context_reset()
{
	INFO_LOG(RENDERER, "GL context_reset");
	gl_ctx_resetting = false;
	glsm_ctl(GLSM_CTL_STATE_CONTEXT_RESET, NULL);
	glsm_ctl(GLSM_CTL_STATE_SETUP, NULL);
	rend_term_renderer();
	theGLContext.init();
	rend_init_renderer();
}

static void context_destroy()
{
	gl_ctx_resetting = true;
	rend_term_renderer();
	glsm_ctl(GLSM_CTL_STATE_CONTEXT_DESTROY, NULL);
}
#endif

static void extract_directory(char *buf, const char *path, size_t size)
{
	strncpy(buf, path, size - 1);
	buf[size - 1] = '\0';

	char *base = find_last_slash(buf);
	if (base)
		*base = '\0';
	else
		strncpy(buf, ".", size - 1);
}

static uint32_t map_gamepad_button(unsigned device, unsigned id)
{
	static const uint32_t dc_joymap[] =
	{
			/* JOYPAD_B      */ DC_BTN_A,
			/* JOYPAD_Y      */ DC_BTN_X,
			/* JOYPAD_SELECT */ 0,
			/* JOYPAD_START  */ DC_BTN_START,
			/* JOYPAD_UP     */ DC_DPAD_UP,
			/* JOYPAD_DOWN   */ DC_DPAD_DOWN,
			/* JOYPAD_LEFT   */ DC_DPAD_LEFT,
			/* JOYPAD_RIGHT  */ DC_DPAD_RIGHT,
			/* JOYPAD_A      */ DC_BTN_B,
			/* JOYPAD_X      */ DC_BTN_Y,
	};

	static const uint32_t dc_lg_joymap[] =
	{
			/* deprecated */ 		0,
			/* deprecated */ 		0,
			/* LIGHTGUN_TRIGGER */	DC_BTN_A,
			/* LIGHTGUN_AUX_A */	DC_BTN_B,
			/* LIGHTGUN_AUX_B */ 	0,
			/* deprecated */ 		0,
			/* LIGHTGUN_START */	DC_BTN_START,
			/* LIGHTGUN_SELECT */ 	0,
			/* LIGHTGUN_AUX_C */	0,
			/* LIGHTGUN_UP   */ 	DC_DPAD_UP,
			/* LIGHTGUN_DOWN   */ 	DC_DPAD_DOWN,
			/* LIGHTGUN_LEFT   */ 	DC_DPAD_LEFT,
			/* LIGHTGUN_RIGHT  */ 	DC_DPAD_RIGHT,
	};

	static const uint32_t aw_joymap[] =
	{
			/* JOYPAD_B      */ AWAVE_BTN0_KEY, /* BTN1 */
			/* JOYPAD_Y      */ AWAVE_BTN2_KEY, /* BTN3 */
			/* JOYPAD_SELECT */ AWAVE_COIN_KEY,
			/* JOYPAD_START  */ AWAVE_START_KEY,
			/* JOYPAD_UP     */ AWAVE_UP_KEY,
			/* JOYPAD_DOWN   */ AWAVE_DOWN_KEY,
			/* JOYPAD_LEFT   */ AWAVE_LEFT_KEY,
			/* JOYPAD_RIGHT  */ AWAVE_RIGHT_KEY,
			/* JOYPAD_A      */ AWAVE_BTN1_KEY, /* BTN2 */
			/* JOYPAD_X      */ AWAVE_BTN3_KEY, /* BTN4 */
			/* JOYPAD_L      */ 0,
			/* JOYPAD_R      */ AWAVE_BTN4_KEY, /* BTN5 */
			/* JOYPAD_L2     */ 0,
			/* JOYPAD_R2     */ 0,
			/* JOYPAD_L3     */ AWAVE_TEST_KEY,
			/* JOYPAD_R3     */ AWAVE_SERVICE_KEY,
	};

	static const uint32_t aw_lg_joymap[] =
	{
			/* deprecated */ 		0,
			/* deprecated */ 		0,
			/* LIGHTGUN_TRIGGER */	AWAVE_TRIGGER_KEY,
			/* LIGHTGUN_AUX_A */	AWAVE_BTN0_KEY,
			/* LIGHTGUN_AUX_B */ 	AWAVE_BTN1_KEY,
			/* deprecated */ 		0,
			/* LIGHTGUN_START */	AWAVE_START_KEY,
			/* LIGHTGUN_SELECT */ 	AWAVE_COIN_KEY,
			/* LIGHTGUN_AUX_C */	AWAVE_BTN2_KEY,
			/* LIGHTGUN_UP   */ 	AWAVE_UP_KEY,
			/* LIGHTGUN_DOWN   */ 	AWAVE_DOWN_KEY,
			/* LIGHTGUN_LEFT   */ 	AWAVE_LEFT_KEY,
			/* LIGHTGUN_RIGHT  */ 	AWAVE_RIGHT_KEY,
	};

	static const uint32_t nao_joymap[] =
	{
			/* JOYPAD_B      */ NAOMI_BTN0_KEY, /* BTN1 */
			/* JOYPAD_Y      */ NAOMI_BTN2_KEY, /* BTN3 */
			/* JOYPAD_SELECT */ NAOMI_COIN_KEY,
			/* JOYPAD_START  */ NAOMI_START_KEY,
			/* JOYPAD_UP     */ NAOMI_UP_KEY,
			/* JOYPAD_DOWN   */ NAOMI_DOWN_KEY,
			/* JOYPAD_LEFT   */ NAOMI_LEFT_KEY,
			/* JOYPAD_RIGHT  */ NAOMI_RIGHT_KEY,
			/* JOYPAD_A      */ NAOMI_BTN1_KEY, /* BTN2 */
			/* JOYPAD_X      */ NAOMI_BTN3_KEY, /* BTN4 */
			/* JOYPAD_L      */ NAOMI_BTN5_KEY, /* BTN6 */
			/* JOYPAD_R      */ NAOMI_BTN4_KEY, /* BTN5 */
			/* JOYPAD_L2     */ NAOMI_BTN7_KEY, /* BTN8 */
			/* JOYPAD_R2     */ NAOMI_BTN6_KEY, /* BTN7 */
			/* JOYPAD_L3     */ NAOMI_TEST_KEY,
			/* JOYPAD_R3     */ NAOMI_SERVICE_KEY,
	};

	static const uint32_t nao_lg_joymap[] =
	{
			/* deprecated */ 		0,
			/* deprecated */ 		0,
			/* LIGHTGUN_TRIGGER */	NAOMI_BTN0_KEY,
			/* LIGHTGUN_AUX_A */	NAOMI_BTN1_KEY,
			/* LIGHTGUN_AUX_B */ 	NAOMI_BTN2_KEY,
			/* deprecated */ 		0,
			/* LIGHTGUN_START */	NAOMI_START_KEY,
			/* LIGHTGUN_SELECT */ 	NAOMI_COIN_KEY,
			/* LIGHTGUN_AUX_C */	NAOMI_BTN3_KEY,
			/* LIGHTGUN_UP   */ 	NAOMI_UP_KEY,
			/* LIGHTGUN_DOWN   */ 	NAOMI_DOWN_KEY,
			/* LIGHTGUN_LEFT   */ 	NAOMI_LEFT_KEY,
			/* LIGHTGUN_RIGHT  */ 	NAOMI_RIGHT_KEY,
	};

	const uint32_t *joymap;
	size_t joymap_size;

	switch (settings.platform.system)
	{
	case DC_PLATFORM_DREAMCAST:
	case DC_PLATFORM_DEV_UNIT:
		switch (device)
		{
		case RETRO_DEVICE_JOYPAD:
		case RETRO_DEVICE_POINTER:
			joymap = dc_joymap;
			joymap_size = std::size(dc_joymap);
			break;
		case RETRO_DEVICE_LIGHTGUN:
			joymap = dc_lg_joymap;
			joymap_size = std::size(dc_lg_joymap);
			break;
		default:
			return 0;
		}
		break;

	case DC_PLATFORM_NAOMI:
	case DC_PLATFORM_NAOMI2:
		switch (device)
		{
		case RETRO_DEVICE_JOYPAD:
		case RETRO_DEVICE_POINTER:
			joymap = nao_joymap;
			joymap_size = std::size(nao_joymap);
			break;
		case RETRO_DEVICE_LIGHTGUN:
			joymap = nao_lg_joymap;
			joymap_size = std::size(nao_lg_joymap);
			break;
		default:
			return 0;
		}
		break;

	case DC_PLATFORM_ATOMISWAVE:
		switch (device)
		{
		case RETRO_DEVICE_JOYPAD:
		case RETRO_DEVICE_POINTER:
			joymap = aw_joymap;
			joymap_size = std::size(aw_joymap);
			break;
		case RETRO_DEVICE_LIGHTGUN:
			joymap = aw_lg_joymap;
			joymap_size = std::size(aw_lg_joymap);
			break;
		default:
			return 0;
		}
		break;

	default:
		return 0;
	}

	if (id >= joymap_size)
		return 0;
	uint32_t mapped = joymap[id];
	// Hack to bind Button 9 instead of Service when not used
	if (id == RETRO_DEVICE_ID_JOYPAD_R3 && device == RETRO_DEVICE_JOYPAD
			&& settings.platform.isNaomi()
			&& !allow_service_buttons)
		mapped = NAOMI_BTN8_KEY;
	return mapped;
}

static const char *get_button_name(unsigned device, unsigned id, const char *default_name)
{
	if (NaomiGameInputs == NULL)
		return default_name;
	uint32_t mask = map_gamepad_button(device, id);
	if (mask == 0)
		return NULL;
	for (int i = 0; NaomiGameInputs->buttons[i].source != 0; i++)
		if (NaomiGameInputs->buttons[i].source == mask)
		{
			if (NaomiGameInputs->buttons[i].name[0] != '\0')
				return NaomiGameInputs->buttons[i].name;
			else
				return default_name;
		}
	return NULL;
}

static const char *get_axis_name(unsigned index, const char *default_name)
{
	if (NaomiGameInputs == NULL)
		return default_name;
	for (int i = 0; NaomiGameInputs->axes[i].name != NULL; i++)
		if (NaomiGameInputs->axes[i].axis == index)
		{
			if (NaomiGameInputs->axes[i].name[0] != '\0')
				return NaomiGameInputs->axes[i].name;
			else
				return default_name;
		}

	return NULL;
}

static void set_input_descriptors()
{
	struct retro_input_descriptor desc[22 * 4 + 1];
	int descriptor_index = 0;
	if (settings.platform.isArcade())
	{
		const char *name;

		for (unsigned i = 0; i < MAPLE_PORTS; i++)
		{
			switch (config::MapleMainDevices[i])
			{
			case MDT_LightGun:
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_LEFT, "D-Pad Left");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_LEFT, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_UP, "D-Pad Up");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_UP, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_DOWN, "D-Pad Down");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_DOWN, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_RIGHT, "D-Pad Right") ;
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_RIGHT, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER, "Trigger");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_AUX_A, "Button 1");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_AUX_A, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_AUX_B, "Button 2");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_AUX_B, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_AUX_C, "Button 3");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_AUX_C, name };
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_RELOAD, "Reload" };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_SELECT, "Coin");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SELECT, name };
				name = get_button_name(RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_START, "Start");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_START, name };
				break;

			case MDT_SegaController:
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_LEFT, "D-Pad Left");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_UP, "D-Pad Up");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_DOWN, "D-Pad Down");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_B, "Button 1");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_A, "Button 2");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_Y, "Button 3");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_X, "Button 4");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_R, "Button 5");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R, name };
				name = haveCardReader ? "Insert Card" : get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_L, "Button 6");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_R2, "Button 7");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_L2, "Button 8");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_START, "Start");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_SELECT, "Coin");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_L3, "Test");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3, name };
				name = get_button_name(RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_R3, "Service");
				if (name != NULL)
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R3, name };
				name = get_axis_name(0, "Axis 1");
				if (name != NULL && name[0] != '\0')
					desc[descriptor_index++] = { i, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X, name };
				name = get_axis_name(1, "Axis 2");
				if (name != NULL && name[0] != '\0')
					desc[descriptor_index++] = { i, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_Y, name };
				name = get_axis_name(2, "Axis 3");
				if (name != NULL && name[0] != '\0')
					desc[descriptor_index++] = { i, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X, name };
				name = get_axis_name(3, "Axis 4");
				if (name != NULL && name[0] != '\0')
					desc[descriptor_index++] = { i, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_Y, name };
				name = get_axis_name(4, NULL);
				if (name != NULL && name[0] != '\0')
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2, name };
				name = get_axis_name(5, NULL);
				if (name != NULL && name[0] != '\0')
					desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2, name };
				break;

			default:
				break;
			}
		}
	}
	else
	{
		for (unsigned i = 0; i < MAPLE_PORTS; i++)
		{
			switch (config::MapleMainDevices[i])
			{
			case MDT_SegaController:
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "A" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "B" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "X" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2,    "L Trigger" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2,    "R Trigger" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X, "Analog X" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_Y, "Analog Y" };
				break;

			case MDT_TwinStick:
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "L-Stick Left" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "L-Stick Up" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "L-Stick Down" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "L-Stick Right" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_B,     "R-Stick Down" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_A,     "R-Stick Right" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_X,     "R-Stick Up" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "R-Stick Left" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_L,    "L Turbo" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_R,    "R Turbo" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_L2,    "L Trigger" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_R2,    "R Trigger" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_SELECT,    "Special" };
				break;

			case MDT_AsciiStick:
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "Stick Left" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "Stick Up" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "Stick Down" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "Stick Right" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_B,     "A" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_A,     "B" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_X,     "Y" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_Y,     "X" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_L,    "C" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_R,    "Z" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_START,    "Start" };
				break;

			case MDT_LightGun:
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_LEFT,  "D-Pad Left" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_UP,    "D-Pad Up" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_DOWN,  "D-Pad Down" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_DPAD_RIGHT, "D-Pad Right" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER,	   "A" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_START,      "Start" };
				desc[descriptor_index++] = { i, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_AUX_A,      "B" };
				break;

			default:
				break;
			}
		}
	}
	desc[descriptor_index++] = { 0 };

	environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc);
}

static void extract_basename(char *buf, const char *path, size_t size)
{
	const char *base = find_last_slash(path);
	if (!base)
		base = path;
	else
		base++;

	strncpy(buf, base, size - 1);
	buf[size - 1] = '\0';
}

static void remove_extension(char *buf, const char *path, size_t size)
{
	char *base;
	strncpy(buf, path, size - 1);
	buf[size - 1] = '\0';

	base = strrchr(buf, '.');

	if (base)
		*base = '\0';
}

#ifdef HAVE_VULKAN
static VulkanContext theVulkanContext;

static void retro_vk_context_reset()
{
	NOTICE_LOG(RENDERER, "retro_vk_context_reset");
	retro_hw_render_interface* vulkan;
	if (!environ_cb(RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE, (void**)&vulkan) || !vulkan)
	{
		ERROR_LOG(RENDERER, "Get Vulkan HW interface failed");
		return;
	}
	theVulkanContext.init((retro_hw_render_interface_vulkan *)vulkan);
	rend_term_renderer();
	rend_init_renderer();
}

static void retro_vk_context_destroy()
{
	NOTICE_LOG(RENDERER, "retro_vk_context_destroy");
	rend_term_renderer();
	theVulkanContext.term();
}

static bool set_vulkan_hw_render()
{
	retro_hw_render_callback hw_render{};
	hw_render.context_type = RETRO_HW_CONTEXT_VULKAN;
	hw_render.version_major = VK_API_VERSION_1_0;
	hw_render.version_minor = 0;
	hw_render.context_reset = retro_vk_context_reset;
	hw_render.context_destroy = retro_vk_context_destroy;
	hw_render.debug_context = false;

	if (!environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render))
		return false;

	static const struct retro_hw_render_context_negotiation_interface_vulkan negotiation_interface = {
			RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN,
			RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN_VERSION,
			VkGetApplicationInfo,
			VkCreateDevice,
			nullptr,
	};
	environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE, (void *)&negotiation_interface);

	if (config::RendererType == RenderType::OpenGL_OIT || config::RendererType == RenderType::DirectX11_OIT)
		config::RendererType = RenderType::Vulkan_OIT;
	else if (config::RendererType != RenderType::Vulkan_OIT)
		config::RendererType = RenderType::Vulkan;
	return true;
}
#else
static bool set_vulkan_hw_render()
{
	return false;
}
#endif

static bool set_opengl_hw_render(u32 preferred)
{
#if defined(HAVE_OPENGL) || defined(HAVE_OPENGLES)
	glsm_ctx_params_t params = {0};

	params.context_reset         = context_reset;
	params.context_destroy       = context_destroy;
	params.environ_cb            = environ_cb;
#if defined(TARGET_NO_STENCIL)
	params.stencil               = false;
#else
	params.stencil               = true;
#endif
	params.imm_vbo_draw          = NULL;
	params.imm_vbo_disable       = NULL;
#if defined(__APPLE__) && defined(HAVE_OPENGL)
	preferred = RETRO_HW_CONTEXT_OPENGL_CORE;
#endif
#ifdef HAVE_OIT
	if (config::RendererType == RenderType::OpenGL_OIT)
	{
		params.context_type          = (retro_hw_context_type)preferred;
		if (preferred == RETRO_HW_CONTEXT_OPENGL)
		{
			// There are some weirdness with RA's gl context's versioning :
			// - any value above 3.0 won't provide a valid context, while the GLSM_CTL_STATE_CONTEXT_INIT call returns true...
			// - the only way to overwrite previously set version with zero values is to set them directly in hw_render, otherwise they are ignored (see glsm_state_ctx_init logic)
			// FIXME what's the point of this?
			retro_hw_render_callback hw_render;
			hw_render.version_major = 3;
			hw_render.version_minor = 0;
		}
		else
		{
			params.major = 4;
			params.minor = 3;
		}
	}
	else
#endif
	{
#ifndef HAVE_OPENGLES
		params.context_type          = (retro_hw_context_type)preferred;
		params.major                 = 3;
		params.minor                 = preferred == RETRO_HW_CONTEXT_OPENGL_CORE ? 2 : 0;
#endif
		config::RendererType = RenderType::OpenGL;
	}

	if (glsm_ctl(GLSM_CTL_STATE_CONTEXT_INIT, &params))
		return true;

#if defined(HAVE_GL3)
	params.context_type       = (retro_hw_context_type)preferred;
	params.major              = 3;
	params.minor              = 0;
#else
	params.context_type       = (retro_hw_context_type)preferred;
	params.major              = 0;
	params.minor              = 0;
#endif
	config::RendererType = RenderType::OpenGL;
	return glsm_ctl(GLSM_CTL_STATE_CONTEXT_INIT, &params);
#else
	return false;
#endif
}

#ifdef HAVE_D3D11
static void dx11_context_reset()
{
	NOTICE_LOG(RENDERER, "DX11 context reset");
	retro_hw_render_interface_d3d11 *hw_render = nullptr;
	if (!environ_cb(RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE, &hw_render) || hw_render == nullptr || hw_render->interface_type != RETRO_HW_RENDER_INTERFACE_D3D11)
		return;
	if (hw_render->interface_version != RETRO_HW_RENDER_INTERFACE_D3D11_VERSION)
	{
		WARN_LOG(RENDERER, "Unsupported interface version %d, expecting %d", hw_render->interface_version, RETRO_HW_RENDER_INTERFACE_D3D11_VERSION);
		return;
	}
	rend_term_renderer();
	theDX11Context.term();

	theDX11Context.init(hw_render->device, hw_render->context, hw_render->D3DCompile, hw_render->featureLevel);
	if (config::RendererType == RenderType::OpenGL_OIT || config::RendererType == RenderType::Vulkan_OIT)
		config::RendererType = RenderType::DirectX11_OIT;
	else if (config::RendererType != RenderType::DirectX11_OIT)
		config::RendererType = RenderType::DirectX11;
	rend_init_renderer();
}

static void dx11_context_destroy()
{
	NOTICE_LOG(RENDERER, "DX11 context destroyed");
	rend_term_renderer();
	theDX11Context.term();
}
#endif

static bool set_dx11_hw_render()
{
#ifdef HAVE_D3D11
	retro_hw_render_callback hw_render_{};
	hw_render_.context_type = RETRO_HW_CONTEXT_DIRECT3D;
	hw_render_.version_major = 11;
	hw_render_.version_minor = 0;
	hw_render_.context_reset = dx11_context_reset;
	hw_render_.context_destroy = dx11_context_destroy;

	if (!environ_cb(RETRO_ENVIRONMENT_SET_HW_RENDER, &hw_render_))
	{
		WARN_LOG(RENDERER, "DX11 hardware rendering not available");
		return false;
	}
	return true;
#else
	return false;
#endif
}

// Loading/unloading games
bool retro_load_game(const struct retro_game_info *game)
{
#if defined(IOS)
	bool can_jit;
	if (environ_cb(RETRO_ENVIRONMENT_GET_JIT_CAPABLE, &can_jit) && !can_jit) {
		// jit is required both for performance and for audio. trying to run
		// without the jit will cause a crash.
		gui_display_notification("Cannot run without JIT", 5000);
		return false;
	}
#endif

	NOTICE_LOG(BOOT, "retro_load_game: %s", game->path);

	extract_basename(g_base_name, game->path, sizeof(g_base_name));
	extract_directory(game_dir, game->path, sizeof(game_dir));

	// Storing rom dir for later use
	snprintf(g_roms_dir, sizeof(g_roms_dir), "%s%c", game_dir, slash);

	if (environ_cb(RETRO_ENVIRONMENT_GET_RUMBLE_INTERFACE, &rumble) && log_cb)
		log_cb(RETRO_LOG_DEBUG, "Rumble interface supported!\n");

	const char *dir = NULL;
	if (!(environ_cb(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, &dir) && dir))
		dir = game_dir;

	snprintf(game_dir, sizeof(game_dir), "%s%cdc%c", dir, slash, slash);
	snprintf(game_dir_no_slash, sizeof(game_dir_no_slash), "%s%cdc", dir, slash);

	// Per-content VMU additions START
	// > Get save directory
	const char *vmu_dir = NULL;
	if (!(environ_cb(RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY, &vmu_dir) && vmu_dir))
		vmu_dir = game_dir;

	snprintf(vmu_dir_no_slash, sizeof(vmu_dir_no_slash), "%s", vmu_dir);

	// > Get content name
	remove_extension(content_name, g_base_name, sizeof(content_name));

	if (content_name[0] == '\0')
		snprintf(content_name, sizeof(content_name), "vmu_save");
	// Per-content VMU additions END

	update_variables(true);

	char *ext = strrchr(g_base_name, '.');

	{
		/* Check for extension .lst, .bin, .dat or .zip. If found, we will set the system type
		 * automatically to Naomi or AtomisWave. */
		if (ext)
		{
			log_cb(RETRO_LOG_INFO, "File extension is: %s\n", ext);
			if (!strcmp(".lst", ext)
					|| !strcmp(".bin", ext) || !strcmp(".BIN", ext)
					|| !strcmp(".dat", ext) || !strcmp(".DAT", ext)
					|| !strcmp(".zip", ext) || !strcmp(".ZIP", ext)
					|| !strcmp(".7z", ext) || !strcmp(".7Z", ext))
			{
				settings.platform.system = naomi_cart_GetPlatform(game->path);
				// Users should use the superior format instead, let's warn them
				if (!strcmp(".lst", ext)
						|| !strcmp(".bin", ext) || !strcmp(".BIN", ext)
						|| !strcmp(".dat", ext) || !strcmp(".DAT", ext))
				{
					struct retro_message msg;
					// Sadly, this callback is only able to display short messages, so we can't give proper explanations...
					msg.msg = "Please upgrade to MAME romsets or expect issues";
					msg.frames = 1200;
					environ_cb(RETRO_ENVIRONMENT_SET_MESSAGE, &msg);
				}
			}
			// If m3u playlist found load the paths into array
			else if (!strcmp(".m3u", ext) || !strcmp(".M3U", ext))
			{
				if (!read_m3u(game->path))
				{
					if (log_cb)
						log_cb(RETRO_LOG_ERROR, "%s\n", "[libretro]: failed to read m3u file ...\n");
					return false;
				}
			}
		}
	}

	if (game->path[0] == '\0')
	{
		if (settings.platform.isConsole())
			boot_to_bios = true;
		else
			return false;
	}
	if (settings.platform.isArcade())
		boot_to_bios = false;

	if (boot_to_bios)
		game_data.clear();
	// if an m3u file was loaded, disk_paths will already be populated so load the game from there
	else if (disk_paths.size() > 0)
	{
		disk_index = 0;

		// Attempt to set initial disk index
		if (disk_paths.size() > 1
				&& disk_initial_index > 0
				&& disk_initial_index < disk_paths.size()
				&& disk_paths[disk_initial_index].compare(disk_initial_path) == 0)
			disk_index = disk_initial_index;

		game_data = disk_paths[disk_index];
	}
	else
	{
		char disk_label[PATH_MAX];
		disk_label[0] = '\0';

		disk_paths.push_back(game->path);

		fill_short_pathname_representation(disk_label, game->path, sizeof(disk_label));
		disk_labels.push_back(disk_label);

		game_data = game->path;
	}

	{
		char data_dir[1024];

		snprintf(data_dir, sizeof(data_dir), "%s%s", game_dir, "data");

		INFO_LOG(COMMON, "Creating dir: %s", data_dir);
		struct stat buf;
		if (stat(data_dir, &buf) < 0)
		{
			path_mkdir(data_dir);
		}
	}

	u32 preferred;
	if (!environ_cb(RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER, &preferred))
		preferred = RETRO_HW_CONTEXT_DUMMY;
	bool foundRenderApi = false;

	if (preferred == RETRO_HW_CONTEXT_OPENGL || preferred == RETRO_HW_CONTEXT_OPENGL_CORE
			|| preferred == RETRO_HW_CONTEXT_OPENGLES2 || preferred == RETRO_HW_CONTEXT_OPENGLES3
			|| preferred == RETRO_HW_CONTEXT_OPENGLES_VERSION)
	{
		foundRenderApi = set_opengl_hw_render(preferred);
	}
	else if (preferred == RETRO_HW_CONTEXT_VULKAN)
	{
		foundRenderApi = set_vulkan_hw_render();
	}
	else if (preferred == RETRO_HW_CONTEXT_DIRECT3D)
	{
		foundRenderApi = set_dx11_hw_render();
	}
	else
	{
		// fallback when not supported (or auto-switching disabled), let's try all supported drivers
		foundRenderApi = set_dx11_hw_render();
		if (!foundRenderApi)
			foundRenderApi = set_vulkan_hw_render();
#if defined(HAVE_OPENGLES)
		if (!foundRenderApi)
			foundRenderApi = set_opengl_hw_render(RETRO_HW_CONTEXT_OPENGLES3);
		if (!foundRenderApi)
			foundRenderApi = set_opengl_hw_render(RETRO_HW_CONTEXT_OPENGLES2);
#else
		if (!foundRenderApi)
			foundRenderApi = set_opengl_hw_render(RETRO_HW_CONTEXT_OPENGL_CORE);
		if (!foundRenderApi)
			foundRenderApi = set_opengl_hw_render(RETRO_HW_CONTEXT_OPENGL);
#endif
	}

	if (!foundRenderApi)
		return false;

	if (settings.platform.isArcade())
	{
		if (environ_cb(RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY, &dir)
				&& dir != nullptr
				&& strcmp(dir, g_roms_dir) != 0)
		{
			static char save_dir[PATH_MAX];
			snprintf(save_dir, sizeof(save_dir), "%s%creicast%c", dir, slash, slash);

			struct stat buf;
			if (stat(save_dir, &buf) < 0)
			{
				DEBUG_LOG(BOOT, "Creating dir: %s", save_dir);
				path_mkdir(save_dir);
			}
			arcadeFlashPath = std::string(save_dir) + g_base_name;
		} else {
			arcadeFlashPath = std::string(g_roms_dir) + g_base_name;
		}
		INFO_LOG(BOOT, "Setting flash base path to %s", arcadeFlashPath.c_str());
	}

	config::ScreenStretching = 100;
	if (!loadGame())
		return false;

	rotate_game = config::Rotate90;
	if (rotate_game)
		config::Widescreen.override(false);
	config::Rotate90 = false;	// actual framebuffer rotation is done by frontend

	setRotation();

	if (settings.content.gameId == "INITIAL D"
			|| settings.content.gameId == "INITIAL D Ver.2"
			|| settings.content.gameId == "INITIAL D Ver.3"
			|| settings.content.gameId == "INITIAL D CYCRAFT")
		haveCardReader = true;
	else
		haveCardReader = false;
	refresh_devices(true);

	// System may have changed - have to update hidden core options
	set_variable_visibility();

	return true;
}

bool retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info)
{
	return false;
}

void retro_unload_game()
{
	INFO_LOG(COMMON, "Flycast unloading game");
	emu.unloadGame();
	game_data.clear();
	disk_paths.clear();
	disk_labels.clear();
	blankVmus();
}


// Memory/Serialization
void *retro_get_memory_data(unsigned type)
{
   if (type == RETRO_MEMORY_SYSTEM_RAM)
      return &mem_b[0];
   return nullptr;
}

size_t retro_get_memory_size(unsigned type)
{
   if (type == RETRO_MEMORY_SYSTEM_RAM)
      return RAM_SIZE;
   return 0;
}

size_t retro_serialize_size()
{
	DEBUG_LOG(SAVESTATE, "retro_serialize_size");
	std::lock_guard<std::mutex> lock(mtx_serialization);

	if (!first_run)
		try {
			emu.stop();
		} catch (const FlycastException& e) {
			ERROR_LOG(COMMON, "%s", e.what());
			return 0;
		}

	Serializer ser;
	dc_serialize(ser);
	if (!first_run)
		emu.start();

	return ser.size();
}

bool retro_serialize(void *data, size_t size)
{
	DEBUG_LOG(SAVESTATE, "retro_serialize %d bytes", (int)size);
	std::lock_guard<std::mutex> lock(mtx_serialization);

	if (!first_run)
		try {
			emu.stop();
		} catch (const FlycastException& e) {
			ERROR_LOG(COMMON, "%s", e.what());
			return false;
		}

	Serializer ser(data, size);
	dc_serialize(ser);
	if (!first_run)
		emu.start();

	return true;
}

bool retro_unserialize(const void * data, size_t size)
{
	DEBUG_LOG(SAVESTATE, "retro_unserialize");
	std::lock_guard<std::mutex> lock(mtx_serialization);

	if (!first_run)
		try {
			emu.stop();
		} catch (const FlycastException& e) {
			ERROR_LOG(COMMON, "%s", e.what());
			return false;
		}

	try {
		Deserializer deser(data, size);
		dc_loadstate(deser);
	    retro_audio_flush_buffer();
		if (!first_run)
			emu.start();

		return true;
	} catch (const Deserializer::Exception& e) {
		ERROR_LOG(SAVESTATE, "Loading state failed: %s", e.what());
		return false;
	}
}

// Cheats
void retro_cheat_reset()
{
   // Nothing to do here
}
void retro_cheat_set(unsigned unused, bool unused1, const char* unused2)
{
   // Nothing to do here
}


// Get info
const char* retro_get_system_directory()
{
   const char* dir;
   environ_cb(RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY, &dir);
   return dir ? dir : ".";
}

void retro_get_system_info(struct retro_system_info *info)
{
   info->library_name = "Flycast";
#ifndef GIT_VERSION
#define GIT_VERSION "undefined"
#endif
   info->library_version = GIT_VERSION;
   info->valid_extensions = "chd|cdi|elf|cue|gdi|lst|bin|dat|zip|7z|m3u";
   info->need_fullpath = true;
   info->block_extract = true;
}

void retro_get_system_av_info(retro_system_av_info *info)
{
	NOTICE_LOG(RENDERER, "retro_get_system_av_info: Res=%d", (int)config::RenderResolution);

	if (cheatManager.isWidescreen())
	{
		retro_message msg;
		msg.msg = "Widescreen cheat activated";
		msg.frames = 120;
		environ_cb(RETRO_ENVIRONMENT_SET_MESSAGE, &msg);
	}
	framebufferWidth = config::RenderResolution * 16 / 9;
	framebufferHeight = config::RenderResolution;
	setAVInfo(*info);
	maxFramebufferWidth = info->geometry.max_width;
	maxFramebufferHeight = info->geometry.max_height;
}

unsigned retro_get_region()
{
   return config::Broadcast == 0 ? RETRO_REGION_NTSC :  RETRO_REGION_PAL;
}

// Controller
void retro_set_controller_port_device(unsigned in_port, unsigned device)
{
	if (device_type[in_port] != (int)device && in_port < MAPLE_PORTS)
	{
		devices_need_refresh = true;
		device_type[in_port] = device;
		switch (device)
		{
			case RETRO_DEVICE_JOYPAD:
				config::MapleMainDevices[in_port] = MDT_SegaController;
				if (settings.platform.isConsole()) {
					config::MapleExpansionDevices[in_port][0] = MDT_SegaVMU;
					config::MapleExpansionDevices[in_port][1] = enable_purupuru ? MDT_PurupuruPack : MDT_SegaVMU;
				}
				break;
			case RETRO_DEVICE_TWINSTICK:
			case RETRO_DEVICE_TWINSTICK_SATURN:
				config::MapleMainDevices[in_port] = MDT_TwinStick;
				if (settings.platform.isConsole()) {
					config::MapleExpansionDevices[in_port][0] = enable_purupuru ? MDT_PurupuruPack : MDT_SegaVMU;
					config::MapleExpansionDevices[in_port][1] = MDT_None;
				}
				break;
			case RETRO_DEVICE_ASCIISTICK:
				config::MapleMainDevices[in_port] = MDT_AsciiStick;
				if (settings.platform.isConsole()) {
					config::MapleExpansionDevices[in_port][0] = enable_purupuru ? MDT_PurupuruPack : MDT_SegaVMU;
					config::MapleExpansionDevices[in_port][1] = MDT_None;
				}
				break;
			case RETRO_DEVICE_KEYBOARD:
                /*
				config::MapleMainDevices[in_port] = MDT_Keyboard;
				if (settings.platform.isConsole()) {
					config::MapleExpansionDevices[in_port][0] = MDT_None;
					config::MapleExpansionDevices[in_port][1] = MDT_None;
				}
                 */
				break;
			case RETRO_DEVICE_MOUSE:
				config::MapleMainDevices[in_port] = MDT_Mouse;
				if (settings.platform.isConsole()) {
					config::MapleExpansionDevices[in_port][0] = MDT_None;
					config::MapleExpansionDevices[in_port][1] = MDT_None;
				}
				break;
			case RETRO_DEVICE_LIGHTGUN:
			case RETRO_DEVICE_POINTER:
				config::MapleMainDevices[in_port] = MDT_LightGun;
				if (settings.platform.isConsole()) {
					config::MapleExpansionDevices[in_port][0] = enable_purupuru ? MDT_PurupuruPack : MDT_SegaVMU;
					config::MapleExpansionDevices[in_port][1] = MDT_None;
				}
				break;
			default:
				config::MapleMainDevices[in_port] = MDT_None;
				if (settings.platform.isConsole()) {
					config::MapleExpansionDevices[in_port][0] = MDT_None;
					config::MapleExpansionDevices[in_port][1] = MDT_None;
				}
				break;
		}
	}
}

static void refresh_devices(bool first_startup)
{
   devices_need_refresh = false;
   set_input_descriptors();

   if (!first_startup)
   {
      if (settings.platform.isConsole())
         maple_ReconnectDevices();

      if (rumble.set_rumble_state)
      {
         for(int i = 0; i < MAPLE_PORTS; i++)
         {
            rumble.set_rumble_state(i, RETRO_RUMBLE_STRONG, 0);
            rumble.set_rumble_state(i, RETRO_RUMBLE_WEAK,   0);
         }
      }
   }
   else if (settings.platform.isConsole())
   {
      mcfg_DestroyDevices();
      mcfg_CreateDevices();
   }
}

// API version (to detect version mismatch)
unsigned retro_api_version()
{
   return RETRO_API_VERSION;
}

void retro_rend_present()
{
	if (!config::ThreadedRendering)
		is_dupe = false;
}

static uint32_t get_time_ms()
{
   return (uint32_t)(os_GetSeconds() * 1000.0);
}

static void get_analog_stick( retro_input_state_t input_state_cb,
                       int player_index,
                       int stick,
                       s8* p_analog_x,
                       s8* p_analog_y )
{
   int analog_x, analog_y;
   analog_x = input_state_cb( player_index, RETRO_DEVICE_ANALOG, stick, RETRO_DEVICE_ID_ANALOG_X );
   analog_y = input_state_cb( player_index, RETRO_DEVICE_ANALOG, stick, RETRO_DEVICE_ID_ANALOG_Y );

   // Analog stick deadzone (borrowed code from parallel-n64 core)
   if ( astick_deadzone > 0 )
   {
      static const int ASTICK_MAX = 0x8000;

      // Convert cartesian coordinate analog stick to polar coordinates
      double radius = sqrt(analog_x * analog_x + analog_y * analog_y);
      double angle = atan2(analog_y, analog_x);

      if (radius > astick_deadzone)
      {
         // Re-scale analog stick range to negate deadzone (makes slow movements possible)
         radius = (radius - astick_deadzone)*((float)ASTICK_MAX/(ASTICK_MAX - astick_deadzone));

         // Convert back to cartesian coordinates
         analog_x = (int)round(radius * cos(angle));
         analog_y = (int)round(radius * sin(angle));

         // Clamp to correct range
         if (analog_x > +32767) analog_x = +32767;
         if (analog_x < -32767) analog_x = -32767;
         if (analog_y > +32767) analog_y = +32767;
         if (analog_y < -32767) analog_y = -32767;
      }
      else
      {
         analog_x = 0;
         analog_y = 0;
      }
   }

   // output
   *p_analog_x = (s8)(analog_x >> 8);
   *p_analog_y = (s8)(analog_y >> 8);
}

static uint16_t apply_trigger_deadzone( uint16_t input )
{
   if ( trigger_deadzone > 0 )
   {
      if ( input > trigger_deadzone )
      {
         // Re-scale analog range
         static const int TRIGGER_MAX = 0x8000;
         const float scale = ((float)TRIGGER_MAX/(float)(TRIGGER_MAX - trigger_deadzone));
         float scaled      = (input - trigger_deadzone)*scale;

         input = (int)round(scaled);
         if (input > +32767)
            input = +32767;
      }
      else
         input = 0;
   }

   return input;
}

static uint16_t get_analog_trigger(
      int16_t ret,
      retro_input_state_t input_state_cb,
      int player_index,
      int id )
{
   // NOTE: Analog triggers were added Nov 2017. Not all front-ends support this
   // feature (or pre-date it) so we need to handle this in a graceful way.

   // First, try and get an analog value using the new libretro API constant
   uint16_t trigger = input_state_cb( player_index,
                       RETRO_DEVICE_ANALOG,
                       RETRO_DEVICE_INDEX_ANALOG_BUTTON,
                       id );

   if ( trigger == 0 )
   {
      // If we got exactly zero, we're either not pressing the button, or the front-end
      // is not reporting analog values. We need to do a second check using the classic
      // digital API method, to at least get some response - better than nothing.

      // NOTE: If we're really just not holding the trigger, we're still going to get zero.

      trigger = (ret & (1 << id)) ? 0x7FFF : 0;
   }
   else
   {
      // We got something, which means the front-end can handle analog buttons.
      // So we apply a deadzone to the input and use it.

      trigger = apply_trigger_deadzone( trigger );
   }

   return trigger;
}

static void setDeviceButtonState(u32 port, int deviceType, int btnId)
{
	uint32_t dc_key = map_gamepad_button(deviceType, btnId);
	bool is_down = input_cb(port, deviceType, 0, btnId);
	if (is_down)
		kcode[port] &= ~dc_key;
	else
		kcode[port] |= dc_key;
}

static void setDeviceButtonStateFromBitmap(u32 bitmap, u32 port, int deviceType, int btnId)
{
	uint32_t dc_key = map_gamepad_button(deviceType, btnId);
	bool is_down    = bitmap & (1 << btnId);
	if (is_down)
		kcode[port] &= ~dc_key;
	else
		kcode[port] |= dc_key;
}

// don't call map_gamepad_button, we supply the DC bit directly.
static void setDeviceButtonStateDirect(u32 bitmap, u32 port, int deviceType, int btnId, int dc_bit)
{
	uint32_t dc_key = 1 << dc_bit;
	bool is_down    = bitmap & (1 << btnId);
	if (is_down)
		kcode[port] &= ~dc_key;
	else
		kcode[port] |= dc_key;
}

static void updateMouseState(u32 port)
{
	std::lock_guard<std::mutex> lock(relPosMutex);

   mo_x_delta[port] += input_cb(port, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_X);
   mo_y_delta[port] += input_cb(port, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_Y);

   bool btn_state   = input_cb(port, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_LEFT);
   if (btn_state)
	  mo_buttons[port] &= ~(1 << 2);
   else
	  mo_buttons[port] |= 1 << 2;
   btn_state = input_cb(port, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_RIGHT);
   if (btn_state)
	  mo_buttons[port] &= ~(1 << 1);
   else
	  mo_buttons[port] |= 1 << 1;
   btn_state = input_cb(port, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_MIDDLE);
   if (btn_state)
	  mo_buttons[port] &= ~(1 << 3);
   else
	  mo_buttons[port] |= 1 << 3;
   if (input_cb(port, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_WHEELDOWN))
	  mo_wheel_delta[port] -= 10;
   else if (input_cb(port, RETRO_DEVICE_MOUSE, 0, RETRO_DEVICE_ID_MOUSE_WHEELUP))
	  mo_wheel_delta[port] += 10;
}

static void updateLightgunCoordinates(u32 port)
{
	int x;
	int y;
	if (device_type[port] == RETRO_DEVICE_LIGHTGUN)
	{
		x = input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X);
		y = input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_Y);
	}
	else
	{
		x = input_cb(port, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_X);
		y = input_cb(port, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_Y);
	}
	if (config::Widescreen && config::ScreenStretching == 100 && !config::EmulateFramebuffer)
		mo_x_abs[port] = 640.f * ((x + 0x8000) * 4.f / 3.f / 0x10000 - (4.f / 3.f - 1.f) / 2.f);
	else
		mo_x_abs[port] = (x + 0x8000) * 640.f / 0x10000;
	mo_y_abs[port] = (y + 0x8000) * 480.f / 0x10000;

	lightgun_params[port].offscreen = false;
	lightgun_params[port].x = mo_x_abs[port];
	lightgun_params[port].y = mo_y_abs[port];
}

void updateLightgunCoordinatesFromAnalogStick(int port)
{
	int x = input_cb(port, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X);
	mo_x_abs[port] = 320 + x * 320 / 32767;
	int y = input_cb(port, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_Y);
	mo_y_abs[port] = 240 + y * 240 / 32767;

	lightgun_params[port].offscreen = false;
	lightgun_params[port].x = mo_x_abs[port];
	lightgun_params[port].y = mo_y_abs[port];
}

static void UpdateInputStateNaomi(u32 port)
{
	switch (config::MapleMainDevices[port])
	{
	case MDT_LightGun:
		if (device_type[port] == RETRO_DEVICE_LIGHTGUN)
		{
			//
			// -- buttons
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_AUX_A);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_AUX_B);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_AUX_C);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_START);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_SELECT);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_UP);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_DOWN);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_LEFT);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_RIGHT);

			bool force_offscreen = false;

			if (input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_RELOAD))
			{
				force_offscreen = true;
				if (settings.platform.isAtomiswave())
					kcode[port] &= ~AWAVE_TRIGGER_KEY;
				else
					kcode[port] &= ~NAOMI_BTN0_KEY;
			}

			if (force_offscreen || input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_IS_OFFSCREEN))
			{
				mo_x_abs[port] = 0;
				mo_y_abs[port] = 0;
				lightgun_params[port].offscreen = true;

				if (input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER) || input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_RELOAD))
				{
					if (settings.platform.isNaomi())
						kcode[port] &= ~NAOMI_BTN1_KEY;
				}
			}
			else
			{
				updateLightgunCoordinates(port);
			}
		}
		else
		{
			// RETRO_DEVICE_POINTER
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_B);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_START);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_UP);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_DOWN);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_LEFT);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_RIGHT);

			int pressed = input_cb(port, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_PRESSED);
			int count = input_cb(port, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_COUNT);
			if (count > 1)
			{
				// reload
				mo_x_abs[port] = 0;
				mo_y_abs[port] = 0;
				lightgun_params[port].offscreen = true;
			}
			else if (count == 1)
			{
				updateLightgunCoordinates(port);
			}
			if (pressed)
			{
				if (settings.platform.isAtomiswave())
					kcode[port] &= ~AWAVE_TRIGGER_KEY;
				else
					kcode[port] &= ~NAOMI_BTN0_KEY;
			}
			else
			{
				if (settings.platform.isAtomiswave())
					kcode[port] |= AWAVE_TRIGGER_KEY;
				else
					kcode[port] |= NAOMI_BTN0_KEY;
			}
		}
		break;

	default:
		{
			//
			// -- buttons
			int16_t ret = 0;
			if (libretro_supports_bitmasks)
				ret = input_cb(port, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK);
			else
			{
				for (int id = RETRO_DEVICE_ID_JOYPAD_B; id <= RETRO_DEVICE_ID_JOYPAD_R3; ++id)
					if (input_cb(port, RETRO_DEVICE_JOYPAD, 0, id))
						ret |= (1 << id);
			}

			for (int id = RETRO_DEVICE_ID_JOYPAD_B; id <= RETRO_DEVICE_ID_JOYPAD_R3; ++id)
			{
				switch (id)
				{
				case RETRO_DEVICE_ID_JOYPAD_L3:
					if (allow_service_buttons)
						setDeviceButtonStateFromBitmap(ret, port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_L3);
					break;
				case RETRO_DEVICE_ID_JOYPAD_R3:
					if (settings.platform.isNaomi()
							|| allow_service_buttons)
						setDeviceButtonStateFromBitmap(ret, port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_R3);
					break;
				case RETRO_DEVICE_ID_JOYPAD_L:
					if (haveCardReader)
					{
						 if (ret & (1 << RETRO_DEVICE_ID_JOYPAD_L))
							 card_reader::insertCard(port);
					}
					else
						setDeviceButtonStateFromBitmap(ret, port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_L);
					break;
				default:
					setDeviceButtonStateFromBitmap(ret, port, RETRO_DEVICE_JOYPAD, id);
					break;
				}
			}
			//
			// -- analog stick

			get_analog_stick(input_cb, port, RETRO_DEVICE_INDEX_ANALOG_LEFT, &joyx[port], &joyy[port] );
			get_analog_stick(input_cb, port, RETRO_DEVICE_INDEX_ANALOG_RIGHT, &joyrx[port], &joyry[port]);
			lt[port] = get_analog_trigger(ret, input_cb, port, RETRO_DEVICE_ID_JOYPAD_L2) / 128;
			rt[port] = get_analog_trigger(ret, input_cb, port, RETRO_DEVICE_ID_JOYPAD_R2) / 128;

			if (NaomiGameInputs != NULL)
			{
				for (int i = 0; NaomiGameInputs->axes[i].name != NULL; i++)
				{
					if (NaomiGameInputs->axes[i].type == Half)
					{
						/* Note:
						 * - Analog stick axes have a range of [-128, 127]
						 * - Analog triggers have a range of [0, 255] */
						switch (NaomiGameInputs->axes[i].axis)
						{
						case 0:
							/* Left stick X: [-128, 127] */
							joyx[port] = std::max((int)joyx[port], 0) * 2;
							break;
						case 1:
							/* Left stick Y: [-128, 127] */
							joyy[port] = std::max((int)joyy[port], 0) * 2;
							break;
						case 2:
							/* Right stick X: [-128, 127] */
							joyrx[port] = std::max((int)joyrx[port], 0) * 2;
							break;
						case 3:
							/* Right stick Y: [-128, 127] */
							joyry[port] = std::max((int)joyry[port], 0) * 2;
						break;
							/* Case 4/5 correspond to right/left trigger.
							 * These inputs are always classified as 'Half',
							 * and already have the correct range - so no
							 * further action is required */
						}
					}
				}
			}

			// -- mouse, for rotary encoders
			updateMouseState(port);
			// lightgun with analog stick
			if (settings.input.lightgunGame)
			{
				updateLightgunCoordinatesFromAnalogStick(port);
				if (input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_RELOAD))
				{
					mo_x_abs[port] = 0;
					mo_y_abs[port] = 0;
					lightgun_params[port].offscreen = true;
					if (settings.platform.isAtomiswave())
						kcode[port] &= ~AWAVE_TRIGGER_KEY;
					else
						kcode[port] &= ~NAOMI_BTN0_KEY;
				}
				else if (settings.platform.isAtomiswave())
				{
					// map btn0 to trigger, btn1 to btn0, etc.
					u32 k = kcode[port] | (AWAVE_BTN0_KEY | AWAVE_BTN1_KEY | AWAVE_BTN2_KEY | AWAVE_BTN3_KEY | AWAVE_TRIGGER_KEY);
					if ((kcode[port] & AWAVE_BTN0_KEY) == 0)
						k &= ~AWAVE_TRIGGER_KEY;
					if ((kcode[port] & AWAVE_BTN1_KEY) == 0)
						k &= ~AWAVE_BTN0_KEY;
					if ((kcode[port] & AWAVE_BTN2_KEY) == 0)
						k &= ~AWAVE_BTN1_KEY;
					if ((kcode[port] & AWAVE_BTN3_KEY) == 0)
						k &= ~AWAVE_BTN2_KEY;
					kcode[port] = k;
				}
			}
		}
		break;
	}

	// Avoid Left+Right or Up+Down buttons being pressed together as this crashes some games
	if (settings.platform.isAtomiswave())
	{
		if ((kcode[port] & (AWAVE_UP_KEY|AWAVE_DOWN_KEY)) == 0)
			kcode[port] |= AWAVE_UP_KEY|AWAVE_DOWN_KEY;
		if ((kcode[port] & (AWAVE_LEFT_KEY|AWAVE_RIGHT_KEY)) == 0)
			kcode[port] |= AWAVE_LEFT_KEY|AWAVE_RIGHT_KEY;
	}
	else
	{
		if ((kcode[port] & (NAOMI_UP_KEY|NAOMI_DOWN_KEY)) == 0)
			kcode[port] |= NAOMI_UP_KEY|NAOMI_DOWN_KEY;
		if ((kcode[port] & (NAOMI_LEFT_KEY|NAOMI_RIGHT_KEY)) == 0)
			kcode[port] |= NAOMI_LEFT_KEY|NAOMI_RIGHT_KEY;
	}
}

static void UpdateInputState(u32 port)
{
	if (gl_ctx_resetting)
		return;

	if (settings.platform.isArcade())
	{
		UpdateInputStateNaomi(port);
		return;
	}
	if (rumble.set_rumble_state != NULL && vib_stop_time[port] > 0)
	{
		if (get_time_ms() >= vib_stop_time[port])
		{
			vib_stop_time[port] = 0;
			rumble.set_rumble_state(port, RETRO_RUMBLE_STRONG, 0);
		}
		else if (vib_delta[port] > 0.0)
		{
			u32 rem_time = vib_stop_time[port] - get_time_ms();
			rumble.set_rumble_state(port, RETRO_RUMBLE_STRONG, 65535 * vib_strength[port] * rem_time * vib_delta[port]);
		}
	}
   
	lightgun_params[port].offscreen = true;

	switch (config::MapleMainDevices[port])
	{
	case MDT_SegaController:
		{
			int16_t ret = 0;
			//
			// -- buttons

			if (libretro_supports_bitmasks)
				ret = input_cb(port, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK);
			else
			{
				for (int id = RETRO_DEVICE_ID_JOYPAD_B; id <= RETRO_DEVICE_ID_JOYPAD_R3; ++id)
					if (input_cb(port, RETRO_DEVICE_JOYPAD, 0, id))
						ret |= (1 << id);
			}

			for (int id = RETRO_DEVICE_ID_JOYPAD_B; id <= RETRO_DEVICE_ID_JOYPAD_X; ++id)
				setDeviceButtonStateFromBitmap(ret, port, RETRO_DEVICE_JOYPAD, id);

			//
			// -- analog stick

			get_analog_stick( input_cb, port, RETRO_DEVICE_INDEX_ANALOG_LEFT, &(joyx[port]), &(joyy[port]) );

			//
			// -- triggers

			if ( digital_triggers )
			{
				// -- digital left trigger
				if (ret & (1 << RETRO_DEVICE_ID_JOYPAD_L2))
					lt[port]=0xFF;
				else
					lt[port]=0;
				// -- digital right trigger
				if (ret & (1 << RETRO_DEVICE_ID_JOYPAD_R2))
					rt[port]=0xFF;
				else
					rt[port]=0;
			}
			else
			{
				// -- analog triggers
				lt[port] = get_analog_trigger(ret, input_cb, port, RETRO_DEVICE_ID_JOYPAD_L2 ) / 128;
				rt[port] = get_analog_trigger(ret, input_cb, port, RETRO_DEVICE_ID_JOYPAD_R2 ) / 128;
			}
		}
		break;

	case MDT_AsciiStick:
		{
			int16_t ret = 0;

			if (libretro_supports_bitmasks)
				ret = input_cb(port, RETRO_DEVICE_ASCIISTICK, 0, RETRO_DEVICE_ID_JOYPAD_MASK);
			else
			{
				for (int id = RETRO_DEVICE_ID_JOYPAD_B; id <= RETRO_DEVICE_ID_JOYPAD_R3; ++id)
					if (input_cb(port, RETRO_DEVICE_ASCIISTICK, 0, id))
						ret |= (1 << id);
			}

			kcode[port] = 0xFFFF; // active-low

			// stick
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_UP, 4 );
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_DOWN, 5 );
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_LEFT, 6 );
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_RIGHT, 7 );

			// buttons
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_B,  2 ); // A
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_A,  1 ); // B
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_Y, 10 ); // X
			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_X,  9 ); // Y

			// Z
			{
				uint32_t dc_key = 1 << 8; // Z
				bool is_down = (ret & (1 << RETRO_DEVICE_ID_JOYPAD_L )) ||
							   (ret & (1 << RETRO_DEVICE_ID_JOYPAD_L2));
				if (is_down)
					kcode[port] &= ~dc_key;
				else
					kcode[port] |= dc_key;
			}

			// C
			{
				uint32_t dc_key = 1 << 0; // C
				bool is_down = (ret & (1 << RETRO_DEVICE_ID_JOYPAD_R)) ||
							   (ret & (1 << RETRO_DEVICE_ID_JOYPAD_R2));
				if (is_down)
					kcode[port] &= ~dc_key;
				else
					kcode[port] |= dc_key;
			}

			setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_ASCIISTICK, RETRO_DEVICE_ID_JOYPAD_START, 3 ); // Start

			// unused inputs
			lt[port]=0;
			rt[port]=0;
			joyx[port]=0;
			joyy[port]=0;
		}
		break;

	case MDT_TwinStick:
		{
			int16_t ret = 0;

			kcode[port] = 0xFFFF; // active-low
			
			if ( device_type[port] == RETRO_DEVICE_TWINSTICK_SATURN )
			{
				// NOTE: This is a remapping of the RetroPad layout in the block below to make using a real
				// Saturn Twin-Stick controller (via a USB adapter) less effort.

				// The Saturn Twin-Stick identifies as a regular Saturn controller internally but with its controls
				// wired to the two sticks without much rhyme or reason. The mapping below untangles that layout
				// into DC compatible inputs, without requiring a change for the Reicast and Beetle Saturn cores.

				// Hope that makes sense!!

				// NOTE: the dc_bits below are the same, only the retro id values have been rearranged.

				if (libretro_supports_bitmasks)
					ret = input_cb(port, RETRO_DEVICE_TWINSTICK_SATURN, 0, RETRO_DEVICE_ID_JOYPAD_MASK);
				else
				{
					for (int id = RETRO_DEVICE_ID_JOYPAD_B; id <= RETRO_DEVICE_ID_JOYPAD_R3; ++id)
						if (input_cb(port, RETRO_DEVICE_TWINSTICK_SATURN, 0, id))
							ret |= (1 << id);
				}

				// left-stick
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_UP, 4 );
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_DOWN, 5 );
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_LEFT, 6 );
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_RIGHT, 7 );
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_L2, 10 ); // left-trigger
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_R2, 9 ); // left-turbo

				// right-stick
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_X, 12 ); // up
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_L, 15 ); // right
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_A, 13 ); // down
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_Y, 14 ); // left
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_B, 2 ); // right-trigger
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_R, 1 ); // right-turbo

				// misc control
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_START, 3 );
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK_SATURN, RETRO_DEVICE_ID_JOYPAD_SELECT, 11 ); //D
			}
			else
			{
				int analog;

				const int thresh = 11000; // about 33%, allows for 8-way movement

				if (libretro_supports_bitmasks)
					ret = input_cb(port, RETRO_DEVICE_TWINSTICK, 0, RETRO_DEVICE_ID_JOYPAD_MASK);
				else
				{
					for (int id = RETRO_DEVICE_ID_JOYPAD_B; id <= RETRO_DEVICE_ID_JOYPAD_R3; ++id)
						if (input_cb(port, RETRO_DEVICE_TWINSTICK, 0, id))
							ret |= (1 << id);
				}

				// LX
				analog = input_cb( port, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X );
				if ( analog < -thresh )
					kcode[port] &= ~( 1 << 6 ); // L
				else if ( analog > thresh )
					kcode[port] &= ~( 1 << 7 ); // R
				else
				{
					// digital
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_LEFT, 6 );
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_RIGHT, 7 );
				}

				// LY
				analog = input_cb( port, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_Y );
				if ( analog < -thresh )
					kcode[port] &= ~( 1 << 4 ); // U
				else if ( analog > thresh )
					kcode[port] &= ~( 1 << 5 ); // D
				else
				{
					// digital
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_UP, 4 );
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_DOWN, 5 );
				}

				// RX
				analog = input_cb( port, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X );
				if ( analog < -thresh )
					kcode[port] &= ~( 1 << 14 ); // L
				else if ( analog > thresh )
					kcode[port] &= ~( 1 << 15 ); // R
				else
				{
					// digital
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_Y, 14 ); // left
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_A, 15 ); // right
				}

				// RY
				analog = input_cb( port, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_Y );
				if ( analog < -thresh )
					kcode[port] &= ~( 1 << 12 ); // U
				else if ( analog > thresh )
					kcode[port] &= ~( 1 << 13 ); // D
				else
				{
					// digital
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_X, 12 ); // up
					setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_B, 13 ); // down
				}

				// left-stick buttons
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_L2, 10 ); // left-trigger
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_L, 9 ); // left-turbo

				// right-stick buttons
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_R2, 2 ); // right-trigger
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_R, 1 ); // right-turbo

				// misc control
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_START, 3 );
				setDeviceButtonStateDirect(ret, port, RETRO_DEVICE_TWINSTICK, RETRO_DEVICE_ID_JOYPAD_SELECT, 11 ); //D
			}
			
			// unused inputs
			lt[port]=0;
			rt[port]=0;
			joyx[port]=0;
			joyy[port]=0;
		}
		break;

	case MDT_LightGun:
		if (device_type[port] == RETRO_DEVICE_LIGHTGUN)
		{
			//
			// -- buttons
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_AUX_A);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_START);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_UP);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_DOWN);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_LEFT);
			setDeviceButtonState(port, RETRO_DEVICE_LIGHTGUN, RETRO_DEVICE_ID_LIGHTGUN_DPAD_RIGHT);

			bool force_offscreen = false;

			if (input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_RELOAD))
			{
				force_offscreen = true;
				kcode[port] &= ~DC_BTN_A;
			}

			if (force_offscreen || input_cb(port, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_IS_OFFSCREEN))
			{
				mo_x_abs[port] = -1000;
				mo_y_abs[port] = -1000;
				lightgun_params[port].offscreen = true;

				lightgun_params[port].x = mo_x_abs[port];
				lightgun_params[port].y = mo_y_abs[port];
			}
			else
			{
				updateLightgunCoordinates(port);
			}
		}
		else
		{
			// RETRO_DEVICE_POINTER
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_B);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_START);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_UP);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_DOWN);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_LEFT);
			setDeviceButtonState(port, RETRO_DEVICE_JOYPAD, RETRO_DEVICE_ID_JOYPAD_RIGHT);

			int pressed = input_cb(port, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_PRESSED);
			int count = input_cb(port, RETRO_DEVICE_POINTER, 0, RETRO_DEVICE_ID_POINTER_COUNT);
			if (count > 1)
			{
				// reload
				mo_x_abs[port] = -1000;
				mo_y_abs[port] = -1000;
				lightgun_params[port].offscreen = true;

				lightgun_params[port].x = mo_x_abs[port];
				lightgun_params[port].y = mo_y_abs[port];
			}
			else if (count == 1)
			{
				updateLightgunCoordinates(port);
			}
			if (pressed)
				kcode[port] &= ~DC_BTN_A;
			else
				kcode[port] |= DC_BTN_A;
		}
		break;

	case MDT_Mouse:
		updateMouseState(port);
		break;

	default:
		break;
	}
}

void UpdateInputState()
{
	UpdateInputState(0);
	UpdateInputState(1);
	UpdateInputState(2);
	UpdateInputState(3);
}

static void updateVibration(u32 port, float power, float inclination, u32 durationMs)
{
	if (!rumble.set_rumble_state)
		return;

	vib_strength[port] = power;

	rumble.set_rumble_state(port, RETRO_RUMBLE_STRONG, (u16)(65535 * power));
	vib_stop_time[port] = get_time_ms() + durationMs;
	vib_delta[port] = inclination;
}

u8 kb_key[4][6];	// normal keys pressed
u8 kb_shift[4];	// modifier keys pressed (bitmask)
static int kb_used;

static void release_key(unsigned dc_keycode)
{
	if (dc_keycode == 0)
		return;

	if (kb_used > 0)
	{
		for (int i = 0; i < 6; i++)
		{
			if (kb_key[0][i] == dc_keycode)
			{
				kb_used--;
				for (int j = i; j < 5; j++)
					kb_key[0][j] = kb_key[0][j + 1];
				kb_key[0][5] = 0;
			}
		}
	}
}

static void retro_keyboard_event(bool down, unsigned keycode, uint32_t character, uint16_t key_modifiers)
{
	// Dreamcast keyboard emulation
	if (keycode == RETROK_LSHIFT || keycode == RETROK_RSHIFT)
	{
		if (!down)
			kb_shift[0] &= ~(0x02 | 0x20);
		else
			kb_shift[0] |= (0x02 | 0x20);
	}
	if (keycode == RETROK_LCTRL || keycode == RETROK_RCTRL)
	{
		if (!down)
			kb_shift[0] &= ~(0x01 | 0x10);
		else
			kb_shift[0] |= (0x01 | 0x10);
	}
	// Make sure modifier keys are released
	if ((key_modifiers & RETROKMOD_SHIFT) == 0)
	{
		release_key(kb_map[RETROK_LSHIFT]);
		release_key(kb_map[RETROK_LSHIFT]);
	}
	if ((key_modifiers & RETROKMOD_CTRL) == 0)
	{
		release_key(kb_map[RETROK_LCTRL]);
		release_key(kb_map[RETROK_RCTRL]);
	}

	u8 dc_keycode = kb_map[keycode];
	if (dc_keycode != 0)
	{
		if (down)
		{
			if (kb_used < 6)
			{
				bool found = false;
				for (int i = 0; !found && i < 6; i++)
				{
					if (kb_key[0][i] == dc_keycode)
						found = true;
				}
				if (!found)
				{
					kb_key[0][kb_used] = dc_keycode;
					kb_used++;
				}
			}
		}
		else
		{
			release_key(dc_keycode);
		}
	}
}

void fatal_error(const char* text, ...)
{
	if (log_cb)
	{
		va_list args;
		char temp[2048];
		va_start(args, text);
		vsprintf(temp, text, args);
		va_end(args);
		strcat(temp, "\n");
		log_cb(RETRO_LOG_ERROR, temp);
	}
}

[[noreturn]] void os_DebugBreak()
{
	ERROR_LOG(COMMON, "DEBUGBREAK!");
	//exit(-1);
#ifdef __SWITCH__
	svcExitProcess();
#else
	__builtin_trap();
#endif
}

static bool retro_set_eject_state(bool ejected)
{
	disc_tray_open = ejected;
	if (ejected)
	{
		DiscOpenLid();
		return true;
	}
	else
	{
		try {
			return DiscSwap(disk_paths[disk_index]);
		} catch (const FlycastException& e) {
			ERROR_LOG(GDROM, "%s", e.what());
			return false;
		}
	}
}

static bool retro_get_eject_state()
{
	return disc_tray_open;
}

static unsigned retro_get_image_index()
{
	return disk_index;
}

static bool retro_set_image_index(unsigned index)
{
	disk_index = index;
	if (disk_index >= disk_paths.size())
	{
		// No disk in drive
		settings.content.path.clear();
		return true;
	}
	settings.content.path = disk_paths[index];

	if (disc_tray_open)
		return true;

	try {
		return DiscSwap(settings.content.path);
	} catch (const FlycastException& e) {
		ERROR_LOG(GDROM, "%s", e.what());
		return false;
	}
}

static unsigned retro_get_num_images()
{
	return disk_paths.size();
}

static bool retro_add_image_index()
{
	disk_paths.push_back("");
	disk_labels.push_back("");

	return true;
}

static bool retro_replace_image_index(unsigned index, const struct retro_game_info *info)
{
	if (index >= disk_paths.size() || index >= disk_labels.size())
		return false;

	if (info == nullptr)
	{
		disk_paths.erase(disk_paths.begin() + index);
		disk_labels.erase(disk_labels.begin() + index);

		if (disk_index >= index && disk_index > 0)
			disk_index--;
	}
	else
	{
		char disk_label[PATH_MAX];
		disk_label[0] = '\0';

		disk_paths[index] = info->path;

		fill_short_pathname_representation(disk_label, info->path, sizeof(disk_label));
		disk_labels[index] = disk_label;
	}

	return true;
}

static bool retro_set_initial_image(unsigned index, const char *path)
{
	if (!path || *path == '\0')
		return false;

	disk_initial_index = index;
	disk_initial_path  = path;

	return true;
}

static bool retro_get_image_path(unsigned index, char *path, size_t len)
{
	if (len < 1)
		return false;

	if (index >= disk_paths.size())
		return false;

	if (disk_paths[index].empty())
		return false;

	strncpy(path, disk_paths[index].c_str(), len - 1);
	path[len - 1] = '\0';

	return true;
}

static bool retro_get_image_label(unsigned index, char *label, size_t len)
{
	if (len < 1)
		return false;

	if (index >= disk_paths.size() || index >= disk_labels.size())
		return false;

	if (disk_labels[index].empty())
		return false;

	strncpy(label, disk_labels[index].c_str(), len - 1);
	label[len - 1] = '\0';

	return true;
}

static void init_disk_control_interface()
{
	unsigned dci_version = 0;

	retro_disk_control_cb.set_eject_state     = retro_set_eject_state;
	retro_disk_control_cb.get_eject_state     = retro_get_eject_state;
	retro_disk_control_cb.set_image_index     = retro_set_image_index;
	retro_disk_control_cb.get_image_index     = retro_get_image_index;
	retro_disk_control_cb.get_num_images      = retro_get_num_images;
	retro_disk_control_cb.add_image_index     = retro_add_image_index;
	retro_disk_control_cb.replace_image_index = retro_replace_image_index;

	retro_disk_control_ext_cb.set_eject_state     = retro_set_eject_state;
	retro_disk_control_ext_cb.get_eject_state     = retro_get_eject_state;
	retro_disk_control_ext_cb.set_image_index     = retro_set_image_index;
	retro_disk_control_ext_cb.get_image_index     = retro_get_image_index;
	retro_disk_control_ext_cb.get_num_images      = retro_get_num_images;
	retro_disk_control_ext_cb.add_image_index     = retro_add_image_index;
	retro_disk_control_ext_cb.replace_image_index = retro_replace_image_index;
	retro_disk_control_ext_cb.set_initial_image   = retro_set_initial_image;
	retro_disk_control_ext_cb.get_image_path      = retro_get_image_path;
	retro_disk_control_ext_cb.get_image_label     = retro_get_image_label;

	disk_initial_index = 0;
	disk_initial_path.clear();
	if (environ_cb(RETRO_ENVIRONMENT_GET_DISK_CONTROL_INTERFACE_VERSION, &dci_version) && (dci_version >= 1))
		environ_cb(RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE, &retro_disk_control_ext_cb);
	else
		environ_cb(RETRO_ENVIRONMENT_SET_DISK_CONTROL_INTERFACE, &retro_disk_control_cb);
}

static bool read_m3u(const char *file)
{
	char line[PATH_MAX];
	char name[PATH_MAX];
	FILE *f = fopen(file, "r");

	if (!f)
	{
		log_cb(RETRO_LOG_ERROR, "Could not read file\n");
		return false;
	}

	while (fgets(line, sizeof(line), f) && disk_index <= disk_paths.size())
	{
		if (line[0] == '#')
			continue;

		char *carriage_return = strchr(line, '\r');
		if (carriage_return)
			*carriage_return = '\0';

		char *newline = strchr(line, '\n');
		if (newline)
			*newline = '\0';

		// Remove any beginning and ending quotes as these can cause issues when feeding the paths into command line later
		if (line[0] == '"')
			memmove(line, line + 1, strlen(line));

		if (line[strlen(line) - 1] == '"')
			line[strlen(line) - 1]  = '\0';

		if (line[0] != '\0')
		{
			char disk_label[PATH_MAX];
			disk_label[0] = '\0';

			if (path_is_absolute(line))
				snprintf(name, sizeof(name), "%s", line);
			else
				snprintf(name, sizeof(name), "%s%s", g_roms_dir, line);
			disk_paths.push_back(name);

			fill_short_pathname_representation(disk_label, name, sizeof(disk_label));
			disk_labels.push_back(disk_label);

			disk_index++;
		}
	}

	fclose(f);
	return disk_index != 0;
}

void gui_display_notification(const char *msg, int duration)
{
	retro_message retromsg;
	retromsg.msg = msg;
	retromsg.frames = duration / 17;
	environ_cb(RETRO_ENVIRONMENT_SET_MESSAGE, &retromsg);
}

void os_RunInstance(int argc, const char *argv[]) { }
