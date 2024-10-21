#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1 // for fopencookie hack in serialize_size
#endif

#include <stdlib.h>

#include "libretro.h"
#include "../gb_core/gb.h"
#include "dmy_renderer.h"

#define RETRO_MEMORY_GAMEBOY_1_SRAM ((1 << 8) | RETRO_MEMORY_SAVE_RAM)
#define RETRO_MEMORY_GAMEBOY_1_RTC ((2 << 8) | RETRO_MEMORY_RTC)
#define RETRO_MEMORY_GAMEBOY_2_SRAM ((3 << 8) | RETRO_MEMORY_SAVE_RAM)
#define RETRO_MEMORY_GAMEBOY_2_RTC ((3 << 8) | RETRO_MEMORY_RTC)

#define RETRO_GAME_TYPE_GAMEBOY_LINK_2P 0x101

static const struct retro_variable vars_single[] = {
    { "tgbdual_gblink_enable", "Link cable emulation (reload); disabled|enabled" },
    { NULL, NULL },
};

static const struct retro_variable vars_dual[] = {
    { "tgbdual_gblink_enable", "Link cable emulation (reload); disabled|enabled" },
    { "tgbdual_screen_placement", "Screen layout; left-right|top-down" },
    { "tgbdual_switch_screens", "Switch player screens; normal|switched" },
    { "tgbdual_single_screen_mp", "Show player screens; both players|player 1 only|player 2 only" },
    { "tgbdual_audio_output", "Audio output; Game Boy #1|Game Boy #2" },
    { NULL, NULL },
};

static const struct retro_subsystem_memory_info gb1_memory[] = {
    { "srm", RETRO_MEMORY_GAMEBOY_1_SRAM },
    { "rtc", RETRO_MEMORY_GAMEBOY_1_RTC },
};

static const struct retro_subsystem_memory_info gb2_memory[] = {
    { "srm", RETRO_MEMORY_GAMEBOY_2_SRAM },
    { "rtc", RETRO_MEMORY_GAMEBOY_2_RTC },
};

static const struct retro_subsystem_rom_info gb_roms[] = {
    { "GameBoy #1", "gb|gbc", false, false, false, gb1_memory, 1 },
    { "GameBoy #2", "gb|gbc", false, false, false, gb2_memory, 1 },
};

   static const struct retro_subsystem_info subsystems[] = {
      { "2 Player Game Boy Link", "gb_link_2p", gb_roms, 2, RETRO_GAME_TYPE_GAMEBOY_LINK_2P },
      { NULL },
};

enum mode{
    MODE_SINGLE_GAME,
    MODE_SINGLE_GAME_DUAL,
    MODE_DUAL_GAME
};

static enum mode mode = MODE_SINGLE_GAME;

gb *g_gb[2];
dmy_renderer *render[2];

retro_log_printf_t log_cb;
retro_video_refresh_t video_cb;
retro_audio_sample_batch_t audio_batch_cb;
retro_environment_t environ_cb;
retro_input_poll_t input_poll_cb;
retro_input_state_t input_state_cb;

extern bool _screen_2p_vertical;
extern bool _screen_switched;
extern int _show_player_screens;
static size_t _serialize_size[2]         = { 0, 0 };

bool gblink_enable                       = false;
int audio_2p_mode                        = 0;
// used to make certain core options only take effect once on core startup
bool already_checked_options             = false;
bool libretro_supports_persistent_buffer = false;
bool libretro_supports_bitmasks          = false;
struct retro_system_av_info *my_av_info  = (retro_system_av_info*)malloc(sizeof(*my_av_info));

void retro_get_system_info(struct retro_system_info *info)
{
   info->library_name     = "TGB Dual";
#ifndef GIT_VERSION
#define GIT_VERSION ""
#endif
   info->library_version  = "v0.8.3" GIT_VERSION;
   info->need_fullpath    = false;
   info->valid_extensions = "gb|dmg|gbc|cgb|sgb";
}

void retro_get_system_av_info(struct retro_system_av_info *info)
{
   int w = 160, h = 144;
   info->geometry.max_width = w * 2;
   info->geometry.max_height = h * 2;

   if (g_gb[1] && _show_player_screens == 2)
   {
      // screen orientation for dual gameboy mode
      if(_screen_2p_vertical)
         h *= 2;
      else
         w *= 2;
   }

   info->timing.fps            = 4194304.0 / 70224.0;
   info->timing.sample_rate    = 44100.0f;
   info->geometry.base_width   = w;
   info->geometry.base_height  = h;
   info->geometry.aspect_ratio = float(w) / float(h);
   memcpy(my_av_info, info, sizeof(*my_av_info));
}



void retro_init(void)
{
   unsigned level = 4;
   struct retro_log_callback log;

   if(environ_cb(RETRO_ENVIRONMENT_GET_LOG_INTERFACE, &log))
      log_cb = log.log;
   else
      log_cb = NULL;

   environ_cb(RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL, &level);

   if (environ_cb(RETRO_ENVIRONMENT_GET_INPUT_BITMASKS, NULL))
      libretro_supports_bitmasks = true;
}

void retro_deinit(void)
{
   libretro_supports_bitmasks          = false;
}

static void check_variables(void)
{
   struct retro_variable var;

   // check whether link cable mode is enabled
   var.key = "tgbdual_gblink_enable";
   var.value = NULL;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      if (!already_checked_options) { // only apply this setting on init
         if (!strcmp(var.value, "disabled"))
            gblink_enable = false;
         else if (!strcmp(var.value, "enabled"))
            gblink_enable = true;
      }
   }
   else
      gblink_enable = false;

   // check whether screen placement is horz (side-by-side) or vert
   var.key = "tgbdual_screen_placement";
   var.value = NULL;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      if (!strcmp(var.value, "left-right"))
         _screen_2p_vertical = false;
      else if (!strcmp(var.value, "top-down"))
         _screen_2p_vertical = true;
   }
   else
      _screen_2p_vertical = false;

   // check whether player 1 and 2's screen placements are swapped
   var.key = "tgbdual_switch_screens";
   var.value = NULL;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      if (!strcmp(var.value, "normal"))
         _screen_switched = false;
      else if (!strcmp(var.value, "switched"))
         _screen_switched = true;
   }
   else
      _screen_switched = false;

   // check whether to show both players' screens, p1 only, or p2 only
   var.key = "tgbdual_single_screen_mp";
   var.value = NULL;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      if (!strcmp(var.value, "both players"))
         _show_player_screens = 2;
      else if (!strcmp(var.value, "player 1 only"))
         _show_player_screens = 0;
      else if (!strcmp(var.value, "player 2 only"))
         _show_player_screens = 1;
   }
   else
      _show_player_screens = 2;

   int screenw = 160, screenh = 144;
   if (gblink_enable && _show_player_screens == 2)
   {
      if (_screen_2p_vertical)
         screenh *= 2;
      else
         screenw *= 2;
   }
   my_av_info->geometry.base_width = screenw;
   my_av_info->geometry.base_height = screenh;
   my_av_info->geometry.aspect_ratio = float(screenw) / float(screenh);

   already_checked_options = true;
   environ_cb(RETRO_ENVIRONMENT_SET_GEOMETRY, my_av_info);

   // check whether player 1 and 2's screen placements are swapped
   var.key = "tgbdual_audio_output";
   var.value = NULL;
   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE, &var) && var.value)
   {
      if (!strcmp(var.value, "Game Boy #1"))
         audio_2p_mode = 0;
      else if (!strcmp(var.value, "Game Boy #2"))
         audio_2p_mode = 1;
   }
   else
      _screen_switched = false;
}


bool retro_load_game(const struct retro_game_info *info)
{
   size_t rom_size;
   byte *rom_data;
   const struct retro_game_info_ext *info_ext = NULL;
   environ_cb(RETRO_ENVIRONMENT_SET_VARIABLES, (void *)vars_single);
   check_variables();

   unsigned i;

   struct retro_input_descriptor desc[] = {
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "A" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT, "Select" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },

      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "A" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT, "Select" },

      { 0 },
   };

   if (!info)
      return false;

   for (i = 0; i < 2; i++)
   {
      g_gb[i]   = NULL;
      render[i] = NULL;
   }

   environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc);

   render[0] = new dmy_renderer(0);
   g_gb[0]   = new gb(render[0], true, true);

   if (environ_cb(RETRO_ENVIRONMENT_GET_GAME_INFO_EXT, &info_ext) &&
       info_ext->persistent_data)
   {
      rom_data                            = (byte*)info_ext->data;
      rom_size                            = info_ext->size;
      libretro_supports_persistent_buffer = true;
   }
   else
   {
      rom_data                            = (byte*)info->data;
      rom_size                            = info->size;
   }

   if (!g_gb[0]->load_rom(rom_data, rom_size, NULL, 0,
            libretro_supports_persistent_buffer))
      return false;

   for (i = 0; i < 2; i++)
      _serialize_size[i] = 0;

   if (gblink_enable)
   {
      mode      = MODE_SINGLE_GAME_DUAL;
      environ_cb(RETRO_ENVIRONMENT_SET_VARIABLES, (void *)vars_dual);

      render[1] = new dmy_renderer(1);
      g_gb[1]   = new gb(render[1], true, true);

      if (!g_gb[1]->load_rom(rom_data, rom_size, NULL, 0,
               libretro_supports_persistent_buffer))
         return false;

      // for link cables and IR:
      g_gb[0]->set_target(g_gb[1]);
      g_gb[1]->set_target(g_gb[0]);
   }
   else
      mode = MODE_SINGLE_GAME;

   check_variables();

   return true;
}


bool retro_load_game_special(unsigned type, const struct retro_game_info *info, size_t num_info)
{
    if (type != RETRO_GAME_TYPE_GAMEBOY_LINK_2P)
        return false; /* all other types are unhandled for now */

   environ_cb(RETRO_ENVIRONMENT_SET_VARIABLES, (void *)vars_dual);
   unsigned i;

   struct retro_input_descriptor desc[] = {
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "A" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "Prev Audio Mode" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Next Audio Mode" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT, "Select" },
      { 0, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },

      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_LEFT,  "D-Pad Left" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_UP,    "D-Pad Up" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_DOWN,  "D-Pad Down" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_RIGHT, "D-Pad Right" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_B,     "B" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_A,     "A" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_L,     "Prev Audio Mode" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_R,     "Next Audio Mode" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_START, "Start" },
      { 1, RETRO_DEVICE_JOYPAD, 0, RETRO_DEVICE_ID_JOYPAD_SELECT, "Select" },

      { 0 },
   };

   if (!info)
      return false;

   for (i = 0; i < 2; i++)
   {
      g_gb[i]   = NULL;
      render[i] = NULL;
   }

   check_variables();

   environ_cb(RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS, desc);

   render[0] = new dmy_renderer(0);
   g_gb[0]   = new gb(render[0], true, true);
   if (!g_gb[0]->load_rom((byte*)info[0].data, info[0].size, NULL, 0, false))
      return false;

   for (i = 0; i < 2; i++)
      _serialize_size[i] = 0;

   if (gblink_enable)
   {
      render[1] = new dmy_renderer(1);
      g_gb[1] = new gb(render[1], true, true);

      if (!g_gb[1]->load_rom((byte*)info[1].data, info[1].size, NULL, 0,
               false))
         return false;

      // for link cables and IR:
      g_gb[0]->set_target(g_gb[1]);
      g_gb[1]->set_target(g_gb[0]);
   }

   mode = MODE_DUAL_GAME;
   return true;
}


void retro_unload_game(void)
{
   unsigned i;
   for(i = 0; i < 2; ++i)
   {
      if (g_gb[i])
      {
         delete g_gb[i];
         g_gb[i] = NULL;
         delete render[i];
         render[i] = NULL;
      }
   }
   free(my_av_info);
   libretro_supports_persistent_buffer = false;
}

void retro_reset(void)
{
   for(int i = 0; i < 2; ++i)
   {
      if (g_gb[i])
         g_gb[i]->reset();
   }
}

void retro_run(void)
{
   bool updated = false;

   if (environ_cb(RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE, &updated) && updated)
      check_variables();

   input_poll_cb();

   for (int line = 0;line < 154; line++)
   {
      if (g_gb[0])
         g_gb[0]->run();
      if (g_gb[1])
         g_gb[1]->run();
   }
}



void *retro_get_memory_data_tgbdual(unsigned id)
{
    switch(mode)
    {
        case MODE_SINGLE_GAME:
        case MODE_SINGLE_GAME_DUAL: /* todo: hook this properly */
        {
            switch(id)
            {
                case RETRO_MEMORY_SAVE_RAM:
                    return g_gb[0]->get_rom()->get_sram();
                case RETRO_MEMORY_RTC:
                    return &(render[0]->fixed_time);
                case RETRO_MEMORY_VIDEO_RAM:
                    return g_gb[0]->get_cpu()->get_vram();
                case RETRO_MEMORY_SYSTEM_RAM:
                    return g_gb[0]->get_cpu()->get_ram();
                default:
                    break;
            }
        }
        case MODE_DUAL_GAME:
        {
            switch(id)
            {
                case RETRO_MEMORY_GAMEBOY_1_SRAM:
                    return g_gb[0]->get_rom()->get_sram();
                case RETRO_MEMORY_GAMEBOY_1_RTC:
                    return &(render[0]->fixed_time);
                case RETRO_MEMORY_GAMEBOY_2_SRAM:
                    return g_gb[1]->get_rom()->get_sram();
                case RETRO_MEMORY_GAMEBOY_2_RTC:
                    return &(render[1]->fixed_time);
                default:
                    break;
            }
        }
    }
   return NULL;
}

size_t retro_get_memory_size_tgbdual(unsigned id)
{
    switch(mode)
    {
        case MODE_SINGLE_GAME:
        case MODE_SINGLE_GAME_DUAL: /* todo: hook this properly */
        {
            switch(id)
            {
                case RETRO_MEMORY_SAVE_RAM:
                    return g_gb[0]->get_rom()->get_sram_size();
                case RETRO_MEMORY_RTC:
                    return sizeof(render[0]->fixed_time);
                case RETRO_MEMORY_VIDEO_RAM:
                    if (g_gb[0]->get_rom()->get_info()->gb_type >= 3)
                        return 0x2000*2; //sizeof(cpu::vram);
                    return 0x2000;
                case RETRO_MEMORY_SYSTEM_RAM:
                    if (g_gb[0]->get_rom()->get_info()->gb_type >= 3)
                        return 0x2000*4; //sizeof(cpu::ram);
                    return 0x2000;
                default:
                    break;
            }
        }
        case MODE_DUAL_GAME:
        {
            switch(id)
            {
                case RETRO_MEMORY_GAMEBOY_1_SRAM:
                    return g_gb[0]->get_rom()->get_sram_size();
                case RETRO_MEMORY_GAMEBOY_1_RTC:
                    return sizeof(render[0]->fixed_time);
                case RETRO_MEMORY_GAMEBOY_2_SRAM:
                    return g_gb[1]->get_rom()->get_sram_size();
                case RETRO_MEMORY_GAMEBOY_2_RTC:
                    return sizeof(render[1]->fixed_time);
                default:
                    break;
            }
        }
    }
   return 0;
}



// question: would saving both gb's into the same file be desirable ever?
// answer: yes, it's most likely needed to sync up netplay and for bsv records.
size_t retro_serialize_size(void)
{
   if (!(_serialize_size[0] + _serialize_size[1]))
   {
      unsigned i;

      for(i = 0; i < 2; ++i)
      {
         if (g_gb[i])
            _serialize_size[i] = g_gb[i]->get_state_size();
      }
   }
   return _serialize_size[0] + _serialize_size[1];
}

bool retro_serialize(void *data, size_t size)
{
   if (size == retro_serialize_size())
   {
      unsigned i;
      uint8_t *ptr = (uint8_t*)data;

      for(i = 0; i < 2; ++i)
      {
         if (g_gb[i])
         {
            g_gb[i]->save_state_mem(ptr);
            ptr += _serialize_size[i];
         }
      }

      return true;
   }
   return false;
}

bool retro_unserialize(const void *data, size_t size)
{
   if (size == retro_serialize_size())
   {
      unsigned i;
      uint8_t *ptr = (uint8_t*)data;

      for(i = 0; i < 2; ++i)
      {
         if (g_gb[i])
         {
            g_gb[i]->restore_state_mem(ptr);
            ptr += _serialize_size[i];
         }
      }
      return true;
   }
   return false;
}



void retro_cheat_reset(void)
{
   for(int i=0; i<2; ++i)
   {
      if(g_gb[i])
         g_gb[i]->get_cheat()->clear();
   }
}

void retro_cheat_set(unsigned index, bool enabled, const char *code)
{
#if 1==0
   if (log_cb)
      log_cb(RETRO_LOG_INFO, "CHEAT:  id=%d, enabled=%d, code='%s'\n", index, enabled, code);
   // FIXME: work in progress.
   // As it stands, it seems TGB Dual only has support for Gameshark codes.
   // Unfortunately, the cheat.xml that ships with bsnes seems to only have
   // Game Genie codes, which are ROM patches rather than RAM.
   // http://nocash.emubase.de/pandocs.htm#gamegeniesharkcheats
   if(false && g_gb[0])
   {
      cheat_dat cdat;
      cheat_dat *tmp=&cdat;

      strncpy(cdat.name, code, sizeof(cdat.name));

      tmp->enable = true;
      tmp->next = NULL;

      while(false)
      { // basically, iterate over code.split('+')
         // TODO: remove all non-alnum chars here
         if (false)
         { // if strlen is 9, game genie
            // game genie format: for "ABCDEFGHI",
            // AB   = New data
            // FCDE = Memory address, XORed by 0F000h
            // GIH  = Check data (can be ignored for our purposes)
            word scramble;
            sscanf(code, "%2hhx%4hx", &tmp->dat, &scramble);
            tmp->code = 1; // TODO: test if this is correct for ROM patching
            tmp->adr = (((scramble&0xF) << 12) ^ 0xF000) | (scramble >> 4);
         }
         else if (false)
         { // if strlen is 8, gameshark
            // gameshark format for "ABCDEFGH",
            // AB    External RAM bank number
            // CD    New Data
            // GHEF  Memory Address (internal or external RAM, A000-DFFF)
            byte adrlo, adrhi;
            sscanf(code, "%2hhx%2hhx%2hhx%2hhx", &tmp->code, &tmp->dat, &adrlo, &adrhi);
            tmp->adr = (adrhi<<8) | adrlo;
         }
         if(false)
         { // if there are more cheats left in the string
            tmp->next = new cheat_dat;
            tmp = tmp->next;
         }
      }
   }
   g_gb[0].get_cheat().add_cheat(&cdat);
#endif
}


// start boilerplate

unsigned retro_api_version(void) { return RETRO_API_VERSION; }
unsigned retro_get_region(void) { return RETRO_REGION_NTSC; }

void retro_set_controller_port_device(unsigned port, unsigned device) { }

void retro_set_video_refresh(retro_video_refresh_t cb) { video_cb = cb; }
void retro_set_audio_sample(retro_audio_sample_t cb) { }
void retro_set_audio_sample_batch_tgbdual(retro_audio_sample_batch_t cb) { audio_batch_cb = cb; }
void retro_set_input_poll(retro_input_poll_t cb) { input_poll_cb = cb; }
void retro_set_input_state(retro_input_state_t cb) { input_state_cb = cb; }


void retro_set_environment(retro_environment_t cb)
{
   static const struct retro_system_content_info_override content_overrides[] = {
      {
         "gb|dmg|gbc|cgb|sgb", /* extensions */
         false,    /* need_fullpath */
         true      /* persistent_data */
      },
      { NULL, false, false }
   };
   environ_cb = cb;
   cb(RETRO_ENVIRONMENT_SET_SUBSYSTEM_INFO, (void*)subsystems);
   /* Request a persistent content data buffer */
   cb(RETRO_ENVIRONMENT_SET_CONTENT_INFO_OVERRIDE,
         (void*)content_overrides);
}

// end boilerplate
