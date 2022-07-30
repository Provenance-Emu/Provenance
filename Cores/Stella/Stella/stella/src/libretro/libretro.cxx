#ifndef _MSC_VER
#include <stdbool.h>
#include <sched.h>
#endif
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

#ifdef _MSC_VER
#define snprintf _snprintf
#endif

#include "libretro.h"

#include "StellaLIBRETRO.hxx"
#include "Event.hxx"
#include "NTSCFilter.hxx"
#include "PaletteHandler.hxx"
#include "Version.hxx"


static StellaLIBRETRO stella;

static retro_log_printf_t log_cb;
static retro_video_refresh_t video_cb;
static retro_input_poll_t input_poll_cb;
static retro_input_state_t input_state_cb;
static retro_environment_t environ_cb;
static retro_audio_sample_t audio_cb;
static retro_audio_sample_batch_t audio_batch_cb;
static bool libretro_supports_bitmasks;

// libretro UI settings
static int setting_ntsc, setting_pal;
static int setting_stereo;
static int setting_phosphor, setting_console, setting_phosphor_blend;
static int stella_paddle_joypad_sensitivity;
static int stella_paddle_analog_sensitivity;
static int setting_crop_hoverscan, crop_left;
static NTSCFilter::Preset setting_filter;
static const char* setting_palette;

static bool system_reset;

static unsigned input_devices[4];
static Controller::Type input_type[2];


// TODO input:
// https://github.com/libretro/blueMSX-libretro/blob/master/libretro.c
// https://github.com/libretro/libretro-o2em/blob/master/libretro.c

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
uint32_t libretro_read_rom(void* data)
{
  memcpy(data, stella.getROM(), stella.getROMSize());

  return stella.getROMSize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static void update_input()
{
  if(!input_poll_cb) return;
  input_poll_cb();

#define EVENT stella.setInputEvent
  int32_t input_bitmask[4];
#define GET_BITMASK(pad) if (libretro_supports_bitmasks) \
      input_bitmask[(pad)] = input_state_cb((pad), RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_MASK); \
    else \
    { \
        input_bitmask[(pad)] = 0; \
        for (int i = 0; i <= RETRO_DEVICE_ID_JOYPAD_R3; i++) \
          input_bitmask[(pad)] |= input_state_cb((pad), RETRO_DEVICE_JOYPAD, 0, i) ? (1 << i) : 0; \
    }
#define MASK_EVENT(evt, pad, id) stella.setInputEvent((evt), (input_bitmask[(pad)] & (1 << id)) ? 1 : 0)

  int pad = 0;
  GET_BITMASK(pad)
  switch(input_type[0])
  {
    case Controller::Type::BoosterGrip:
      MASK_EVENT(Event::LeftJoystickFire9, pad, RETRO_DEVICE_ID_JOYPAD_Y);
      [[fallthrough]];
    case Controller::Type::Genesis:
      MASK_EVENT(Event::LeftJoystickFire5, pad, RETRO_DEVICE_ID_JOYPAD_A);
      [[fallthrough]];
    case Controller::Type::Joystick:
      MASK_EVENT(Event::LeftJoystickLeft, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::LeftJoystickRight, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::LeftJoystickUp, pad, RETRO_DEVICE_ID_JOYPAD_UP);
      MASK_EVENT(Event::LeftJoystickDown, pad, RETRO_DEVICE_ID_JOYPAD_DOWN);
      MASK_EVENT(Event::LeftJoystickFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      break;

    case Controller::Type::Driving:
      MASK_EVENT(Event::LeftDrivingCCW, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::LeftDrivingCW, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::LeftDrivingFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      break;

    case Controller::Type::Paddles:
      MASK_EVENT(Event::LeftPaddleAIncrease, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::LeftPaddleADecrease, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::LeftPaddleAFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      EVENT(Event::LeftPaddleAAnalog, input_state_cb(pad, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X));
      pad++;

      GET_BITMASK(pad)
      MASK_EVENT(Event::LeftPaddleBIncrease, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::LeftPaddleBDecrease, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::LeftPaddleBFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      EVENT(Event::LeftPaddleBAnalog, input_state_cb(pad, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X));
      break;

    case Controller::Type::Lightgun:
    {
      // scale from -0x8000..0x7fff to image rect
      const Common::Rect& rect =  stella.getImageRect();
      const Int32 x = (input_state_cb(pad, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X) + 0x8000) * rect.w() / 0x10000;
      const Int32 y = (input_state_cb(pad, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_Y) + 0x8000) * rect.h() / 0x10000;

      EVENT(Event::MouseAxisXValue, x);
      EVENT(Event::MouseAxisYValue, y);
      EVENT(Event::MouseButtonLeftValue, input_state_cb(pad, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER));
      EVENT(Event::MouseButtonRightValue, input_state_cb(pad, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER));
      break;
    }

    default:
      break;
  }
  pad++;
  GET_BITMASK(pad)

  switch(input_type[1])
  {
    case Controller::Type::BoosterGrip:
      MASK_EVENT(Event::RightJoystickFire9, pad, RETRO_DEVICE_ID_JOYPAD_Y);
      [[fallthrough]];
    case Controller::Type::Genesis:
      MASK_EVENT(Event::RightJoystickFire5, pad, RETRO_DEVICE_ID_JOYPAD_A);
      [[fallthrough]];
    case Controller::Type::Joystick:
      MASK_EVENT(Event::RightJoystickLeft, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::RightJoystickRight, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::RightJoystickUp, pad, RETRO_DEVICE_ID_JOYPAD_UP);
      MASK_EVENT(Event::RightJoystickDown, pad, RETRO_DEVICE_ID_JOYPAD_DOWN);
      MASK_EVENT(Event::RightJoystickFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      break;

    case Controller::Type::Driving:
      MASK_EVENT(Event::RightDrivingCCW, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::RightDrivingCW, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::RightDrivingFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      break;

    case Controller::Type::Paddles:
      MASK_EVENT(Event::RightPaddleAIncrease, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::RightPaddleADecrease, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::RightPaddleAFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      EVENT(Event::RightPaddleAAnalog, input_state_cb(pad, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT, RETRO_DEVICE_ID_ANALOG_X));
      pad++;

      GET_BITMASK(pad)
      MASK_EVENT(Event::RightPaddleBIncrease, pad, RETRO_DEVICE_ID_JOYPAD_LEFT);
      MASK_EVENT(Event::RightPaddleBDecrease, pad, RETRO_DEVICE_ID_JOYPAD_RIGHT);
      MASK_EVENT(Event::RightPaddleBFire, pad, RETRO_DEVICE_ID_JOYPAD_B);
      EVENT(Event::RightPaddleBAnalog, input_state_cb(pad, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_RIGHT, RETRO_DEVICE_ID_ANALOG_X));
      break;

    default:
      break;
  }

  // Notes:
  // - Each event can only be assigned once, in case of conflicts ususally the latest assignment will be active
  // - The follwing events can also be used by analog devices
  MASK_EVENT(Event::ConsoleLeftDiffA,  0, RETRO_DEVICE_ID_JOYPAD_L);
  MASK_EVENT(Event::ConsoleLeftDiffB,  0, RETRO_DEVICE_ID_JOYPAD_L2);
  MASK_EVENT(Event::ConsoleColor,      0, RETRO_DEVICE_ID_JOYPAD_L3);
  MASK_EVENT(Event::ConsoleRightDiffA, 0, RETRO_DEVICE_ID_JOYPAD_R);
  MASK_EVENT(Event::ConsoleRightDiffB, 0, RETRO_DEVICE_ID_JOYPAD_R2);
  MASK_EVENT(Event::ConsoleBlackWhite, 0, RETRO_DEVICE_ID_JOYPAD_R3);
  MASK_EVENT(Event::ConsoleSelect,     0, RETRO_DEVICE_ID_JOYPAD_SELECT);
  MASK_EVENT(Event::ConsoleReset,      0, RETRO_DEVICE_ID_JOYPAD_START);

#undef EVENT
#undef MASK_EVENT
#undef GET_BITMASK
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static void update_geometry()
{
  struct retro_system_av_info av_info;

  retro_get_system_av_info(&av_info);

  environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, &av_info);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static void update_system_av()
{
  struct retro_system_av_info av_info;

  retro_get_system_av_info(&av_info);

  environ_cb(RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO, &av_info);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static void update_variables(bool init = false)
{
  bool geometry_update = false;

  struct retro_variable var;

#define RETRO_GET(x) \
  var.key = x; \
  var.value = NULL; \
  if(environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)

  RETRO_GET("stella_filter")
  {
    NTSCFilter::Preset value = NTSCFilter::Preset::OFF;

    if(!strcmp(var.value, "disabled"))            value = NTSCFilter::Preset::OFF;
    else if(!strcmp(var.value, "composite"))      value = NTSCFilter::Preset::COMPOSITE;
    else if(!strcmp(var.value, "s-video"))        value = NTSCFilter::Preset::SVIDEO;
    else if(!strcmp(var.value, "rgb"))            value = NTSCFilter::Preset::RGB;
    else if(!strcmp(var.value, "badly adjusted")) value = NTSCFilter::Preset::BAD;

    if(setting_filter != value)
    {
      stella.setVideoFilter(value);

      geometry_update = true;
      setting_filter = value;
    }
  }

  RETRO_GET("stella_crop_hoverscan")
  {
    setting_crop_hoverscan = !strcmp(var.value, "enabled");

    geometry_update = true;
  }

  RETRO_GET("stella_ntsc_aspect")
  {
    int value = 0;

    if(!strcmp(var.value, "par")) value = 0;
    else value = atoi(var.value);

    if(setting_ntsc != value)
    {
      stella.setVideoAspectNTSC(value);

      geometry_update = true;
      setting_ntsc = value;
    }
  }

  RETRO_GET("stella_pal_aspect")
  {
    int value = 0;

    if(!strcmp(var.value, "par")) value = 0;
    else value = atoi(var.value);

    if(setting_pal != value)
    {
      stella.setVideoAspectPAL(value);

      setting_pal = value;
      geometry_update = true;
    }
  }

  RETRO_GET("stella_palette")
  {
    if(setting_palette != var.value)
    {
      stella.setVideoPalette(var.value);

      setting_palette = var.value;
    }
  }

  RETRO_GET("stella_console")
  {
    int value = 0;

    if(!strcmp(var.value, "auto")) value = 0;
    else if(!strcmp(var.value, "ntsc")) value = 1;
    else if(!strcmp(var.value, "pal")) value = 2;
    else if(!strcmp(var.value, "secam")) value = 3;
    else if(!strcmp(var.value, "ntsc50")) value = 4;
    else if(!strcmp(var.value, "pal60")) value = 5;
    else if(!strcmp(var.value, "secam60")) value = 6;

    if(setting_console != value)
    {
      stella.setConsoleFormat(value);

      setting_console = value;
      system_reset = true;
    }
  }

  RETRO_GET("stella_stereo")
  {
    int value = 0;

    if(!strcmp(var.value, "auto")) value = 0;
    else if(!strcmp(var.value, "off")) value = 1;
    else if(!strcmp(var.value, "on")) value = 2;

    if(setting_stereo != value)
    {
      stella.setAudioStereo(value);

      setting_stereo = value;
    }
  }

  RETRO_GET("stella_phosphor")
  {
    int value = 0;

    if(!strcmp(var.value, "auto")) value = 0;
    else if(!strcmp(var.value, "off")) value = 1;
    else if(!strcmp(var.value, "on")) value = 2;

    if(setting_phosphor != value)
    {
      stella.setVideoPhosphor(value, setting_phosphor_blend);

      setting_phosphor = value;
    }
  }

  RETRO_GET("stella_phosphor_blend")
  {
    int value = 0;

    value = atoi(var.value);

    if(setting_phosphor_blend != value)
    {
      stella.setVideoPhosphor(setting_phosphor, value);

      setting_phosphor_blend = value;
    }
  }

  RETRO_GET("stella_paddle_joypad_sensitivity")
  {
    int value = 0;

    value = atoi(var.value);

    if(stella_paddle_joypad_sensitivity != value)
    {
      if(!init) stella.setPaddleJoypadSensitivity(value);

      stella_paddle_joypad_sensitivity = value;
    }
  }

  RETRO_GET("stella_paddle_analog_sensitivity")
  {
    int value = 0;

    value = atoi(var.value);

    if(stella_paddle_analog_sensitivity != value)
    {
      if(!init) stella.setPaddleAnalogSensitivity(value);

      stella_paddle_analog_sensitivity = value;
    }
  }

  if(!init && !system_reset)
  {
    crop_left = setting_crop_hoverscan ? (stella.getVideoZoom() == 2 ? 26 : 8) : 0;

    if(geometry_update) update_geometry();
  }

#undef RETRO_GET
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
static bool reset_system()
{
  // clean restart
  stella.destroy();

  // apply pre-boot settings first
  update_variables(true);

  // start system
  if(!stella.create(log_cb ? true : false)) return false;

  // get auto-detect controllers
  input_type[0] = stella.getLeftControllerType();
  input_type[1] = stella.getRightControllerType();
  stella.setPaddleJoypadSensitivity(stella_paddle_joypad_sensitivity);
  stella.setPaddleAnalogSensitivity(stella_paddle_analog_sensitivity);

  system_reset = false;

  // reset libretro window, apply post-boot settings
  update_variables(false);

  return true;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
unsigned retro_api_version()
{
  return RETRO_API_VERSION;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
unsigned retro_get_region()
{
  return stella.getVideoNTSC() ? RETRO_REGION_NTSC : RETRO_REGION_PAL;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb) { audio_cb = cb; }
void retro_set_audio_sample_batch(retro_audio_sample_batch_t cb) { audio_batch_cb = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { input_poll_cb = cb; }
void retro_set_input_state(retro_input_state_t cb) { input_state_cb = cb; }

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_get_system_info(struct retro_system_info *info)
{
  *info = retro_system_info{};  // reset to defaults

  info->library_name = stella.getCoreName();
#ifndef GIT_VERSION
#define GIT_VERSION ""
#endif
  info->library_version = STELLA_VERSION GIT_VERSION;
  info->valid_extensions = stella.getROMExtensions();
  info->need_fullpath = false;
  info->block_extract = false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_get_system_av_info(struct retro_system_av_info *info)
{
  *info = retro_system_av_info{};  // reset to defaults

  info->timing.fps            = stella.getVideoRate();
  info->timing.sample_rate    = stella.getAudioRate();

  info->geometry.base_width   = stella.getRenderWidth() - crop_left *
      (stella.getVideoZoom() == 1 ? 2 : 1);
  info->geometry.base_height  = stella.getRenderHeight();

  info->geometry.max_width    = stella.getVideoWidthMax();
  info->geometry.max_height   = stella.getVideoHeightMax();

  info->geometry.aspect_ratio = stella.getVideoAspectPar() *
      (float) info->geometry.base_width / (float) info->geometry.base_height;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_set_controller_port_device(unsigned port, unsigned device)
{
  if(port < 4)
  {
    switch (device)
    {
      case RETRO_DEVICE_NONE:
      case RETRO_DEVICE_JOYPAD:
      case RETRO_DEVICE_ANALOG:
      case RETRO_DEVICE_LIGHTGUN:
      //case RETRO_DEVICE_KEYBOARD:
      //case RETRO_DEVICE_MOUSE:
        input_devices[port] = device;
        break;

      default:
        if (log_cb) log_cb(RETRO_LOG_ERROR, "%s\n", "[libretro]: Invalid device, setting type to RETRO_DEVICE_JOYPAD ...");
        input_devices[port] = RETRO_DEVICE_JOYPAD;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_set_environment(retro_environment_t cb)
{
  environ_cb = cb;

  static struct retro_variable variables[] = {
    // Adding more variables and rearranging them is safe.
    { "stella_console", "Console display; auto|ntsc|pal|secam|ntsc50|pal60|secam60" },
    { "stella_palette", "Palette colors; standard|z26|user|custom" },
    { "stella_filter", "TV effects; disabled|composite|s-video|rgb|badly adjusted" },
    { "stella_ntsc_aspect", "NTSC aspect %; par|100|101|102|103|104|105|106|107|108|109|110|111|112|113|114|115|116|117|118|119|120|121|122|123|124|125|50|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99" },
    { "stella_pal_aspect", "PAL aspect %; par|100|101|102|103|104|105|106|107|108|109|110|111|112|113|114|115|116|117|118|119|120|121|122|123|124|125|50|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99" },
    { "stella_crop_hoverscan", "Crop horizontal overscan; disabled|enabled" },
    { "stella_stereo", "Stereo sound; auto|off|on" },
    { "stella_phosphor", "Phosphor mode; auto|off|on" },
    { "stella_phosphor_blend", "Phosphor blend %; 60|65|70|75|80|85|90|95|100|0|5|10|15|20|25|30|35|40|45|50|55" },
    { "stella_paddle_joypad_sensitivity", "Paddle joypad sensitivity; 3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19|20|1|2" },
    { "stella_paddle_analog_sensitivity", "Paddle analog sensitivity; 20|21|22|23|24|25|26|27|28|29|30|0|1|2|3|4|5|6|7|8|9|10|11|12|13|14|15|16|17|18|19" },
    { NULL, NULL },
  };

  environ_cb(RETRO_ENVIRONMENT_SET_VARIABLES, variables);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_init()
{
  struct retro_log_callback log;
  unsigned level = 4;

  log_cb = NULL;
  if(environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log)) log_cb = log.log;

  environ_cb(RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL, &level);
  libretro_supports_bitmasks = environ_cb(RETRO_ENVIRONMENT_GET_INPUT_BITMASKS, NULL);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool retro_load_game(const struct retro_game_info *info)
{
  enum retro_pixel_format fmt = RETRO_PIXEL_FORMAT_XRGB8888;

  // Tell libretro we allow those 4 different types of devices for player 0
  static const struct retro_controller_description player0_controller_description[] = {
    { "None", RETRO_DEVICE_NONE },
    { "Joystick", RETRO_DEVICE_JOYPAD },
    { "Analog", RETRO_DEVICE_ANALOG },
    { "Lightgun", RETRO_DEVICE_LIGHTGUN }
  };
  // Tell libretro we allow those 3 different types of devices for other players
  static const struct retro_controller_description other_player_controller_description[] = {
    { "None", RETRO_DEVICE_NONE },
    { "Joystick", RETRO_DEVICE_JOYPAD },
    { "Analog", RETRO_DEVICE_ANALOG }
  };
  // Tell libretro we allow those types for 4 players
  static const struct retro_controller_info controller_infos[5] = {
    { player0_controller_description, 4 },
    { other_player_controller_description, 3 },
    { other_player_controller_description, 3 },
    { other_player_controller_description, 3 },
    { NULL, 0 }
  };

  static const struct retro_input_descriptor desc[] = {
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,     "Up" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,   "Down" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,   "Left" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT,  "Right" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,      "Trigger" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,      "Fire" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,      "Booster" },

    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT, "Select" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,  "Reset" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,      "Left Difficulty A" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,      "Right Difficulty A" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2,     "Left Difficulty B" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2,     "Right Difficulty B" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3,     "Color" },
    { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R3,     "Black/White" },

    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,     "Up" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,   "Down" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,   "Left" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT,  "Right" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,      "Trigger" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,      "Fire" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_Y,      "Booster" },

    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT, "Select" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START,  "Reset" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,      "Left Difficulty A" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,      "Right Difficulty A" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L2,     "Left Difficulty B" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R2,     "Right Difficulty B" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L3,     "Color" },
    { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R3,     "Black/White" },

    { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,   "Left" },
    { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT,  "Right" },
    { 2, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,      "Fire" },

    { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,   "Left" },
    { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT,  "Right" },
    { 3, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,      "Fire" },

    { 0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT,   RETRO_DEVICE_ID_ANALOG_X, "Axis" },
    { 0, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_BUTTON, RETRO_DEVICE_ID_JOYPAD_B, "Button" },

    { 1, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT,   RETRO_DEVICE_ID_ANALOG_X, "Axis" },
    { 1, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_BUTTON, RETRO_DEVICE_ID_JOYPAD_B, "Button" },

    { 2, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT,   RETRO_DEVICE_ID_ANALOG_X, "Axis" },
    { 2, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_BUTTON, RETRO_DEVICE_ID_JOYPAD_B, "Button" },

    { 3, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_LEFT,   RETRO_DEVICE_ID_ANALOG_X, "Axis" },
    { 3, RETRO_DEVICE_ANALOG, RETRO_DEVICE_INDEX_ANALOG_BUTTON, RETRO_DEVICE_ID_JOYPAD_B, "Button" },

    { 0, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X, "Screen X" },
    { 0, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_SCREEN_Y, "Screen Y" },
    { 0, RETRO_DEVICE_LIGHTGUN, 0, RETRO_DEVICE_ID_LIGHTGUN_TRIGGER,  "Button" },

    { 0, 0, 0, 0, NULL },
  };

  if(!info || info->size > stella.getROMMax()) return false;

  // Send controller infos to libretro
  environ_cb(RETRO_ENVIRONMENT_SET_CONTROLLER_INFO, (void*)controller_infos);
  // Send controller input descriptions to libretro
  environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, (void*)desc);

  if(!environ_cb(RETRO_ENVIRONMENT_SET_PIXEL_FORMAT, &fmt))
  {
    if(log_cb) log_cb(RETRO_LOG_INFO, "[Stella]: XRGB8888 is not supported.\n");
    return false;
  }

  stella.setROM(info->path, info->data, info->size);

  return reset_system();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool retro_load_game_special(unsigned game_type, const struct retro_game_info *info, size_t num_info)
{
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_reset()
{
  stella.reset();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_run()
{
  bool updated = false;

  if(environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated) && updated)
    update_variables();

  if(system_reset)
  {
    reset_system();
    update_system_av();
    return;
  }


  update_input();


  stella.runFrame();

  if(stella.getVideoResize())
    update_geometry();


  //printf("retro_run - %d %d %d - %d\n", stella.getVideoWidth(), stella.getVideoHeight(), stella.getVideoPitch(), stella.getAudioSize() );

  if(stella.getVideoReady())
    video_cb(reinterpret_cast<uInt32*>(stella.getVideoBuffer()) + crop_left, stella.getVideoWidth() - crop_left, stella.getVideoHeight(), stella.getVideoPitch());

  if(stella.getAudioReady())
    audio_batch_cb(stella.getAudioBuffer(), stella.getAudioSize());
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_unload_game()
{
  stella.destroy();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_deinit()
{
  stella.destroy();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t retro_serialize_size()
{
  int runahead = -1;
  if(environ_cb(RETRO_ENVIRONMENT_GET_AUDIO_VIDEO_ENABLE, &runahead))
  {
    // maximum state size possible
    if(runahead & 4)
      return 0x100000;
  }

  return stella.getStateSize();
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool retro_serialize(void *data, size_t size)
{
  return stella.saveState(data, size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool retro_unserialize(const void *data, size_t size)
{
  return stella.loadState(data, size);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void *retro_get_memory_data(unsigned id)
{
  switch (id)
  {
    case RETRO_MEMORY_SYSTEM_RAM:
      return stella.getRAM();

    default:
      return NULL;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
size_t retro_get_memory_size(unsigned id)
{
  switch (id)
  {
    case RETRO_MEMORY_SYSTEM_RAM:
      return stella.getRAMSize();

    default:
      return 0;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_cheat_reset()
{
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void retro_cheat_set(unsigned index, bool enabled, const char *code)
{
}
