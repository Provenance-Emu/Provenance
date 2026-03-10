#ifndef LIBRETRO_CORE_OPTIONS_H__
#define LIBRETRO_CORE_OPTIONS_H__

#include <stdlib.h>
#include <string.h>

#include <libretro.h>
#include <retro_inline.h>

#ifndef HAVE_NO_LANGEXTRA
#include "libretro_core_options_intl.h"
#endif

/*
 ********************************
 * VERSION: 2.0
 ********************************
 *
 * - 2.0: Add support for core options v2 interface
 * - 1.3: Move translations to libretro_core_options_intl.h
 *        - libretro_core_options_intl.h includes BOM and utf-8
 *          fix for MSVC 2010-2013
 *        - Added HAVE_NO_LANGEXTRA flag to disable translations
 *          on platforms/compilers without BOM support
 * - 1.2: Use core options v1 interface when
 *        RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION is >= 1
 *        (previously required RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION == 1)
 * - 1.1: Support generation of core options v0 retro_core_option_value
 *        arrays containing options with a single value
 * - 1.0: First commit
*/

#ifdef __cplusplus
extern "C" {
#endif

/*
 ********************************
 * Core Option Definitions
 ********************************
*/

/* RETRO_LANGUAGE_ENGLISH */

/* Default language:
 * - All other languages must include the same keys and values
 * - Will be used as a fallback in the event that frontend language
 *   is not available
 * - Will be used as a fallback for any missing entries in
 *   frontend language definition */


struct retro_core_option_v2_category option_cats_us[] = {
   {
      "system",
      "System",
      "Configure region / base hardware selection / ROM mapping / Sega CD RAM cart."
   },
   {
      "video",
      "Video",
      "Configure aspect ratio / LCD filter / video renderer."
   },
   {
      "audio",
      "Audio",
      "Configure sample rate / emulated audio devices / low pass filter / DAC noise."
   },
   {
      "input",
      "Input",
      "Configure input devices."
   },
   {
      "performance",
      "Performance",
#ifdef DRC_SH2
      "Configure dynamic recompiler / frameskipping."
#else
      "Configure frameskipping parameters."
#endif
   },
   {
      "hacks",
      "Emulation Hacks",
      "Configure sprite limit removal / processor overclocking."
   },
   { NULL, NULL, NULL },
};

struct retro_core_option_v2_definition option_defs_us[] = {
   {
      "picodrive_region",
      "System Region",
      "Region",
      "Specify which region the system is from. 'PAL'/'Europe' is 50hz while 'NTSC'/'US' is 60hz. Games may run faster or slower than normal (or produce errors) if the incorrect region is selected.",
      NULL,
      "system",
      {
         { "Auto",       NULL },
         { "Japan NTSC", NULL },
         { "Japan PAL",  NULL },
         { "US",         NULL },
         { "Europe",     NULL },
         { NULL, NULL },
      },
      "Auto"
   },
   {
      "picodrive_smstype",
      "Master System Type",
      NULL,
      "Choose which type of hardware (SMS or Game Gear) the core should emulate when running Master System content.",
      NULL,
      "system",
      {
         { "Auto",          NULL },
         { "Game Gear",     NULL },
         { "Master System", NULL },
         { "SG-1000"      , NULL },
         { "SC-3000"      , NULL },
         { NULL, NULL },
       },
      "Auto"
   },
   {
      "picodrive_smsmapper",
      "Master System ROM Mapping",
      NULL,
      "Choose which ROM mapper the core should apply. 'Auto' will work for a wide range of content, but in some cases automatic detection fails.",
      NULL,
      "system",
      {
         { "Auto",          NULL },
         { "Sega",          NULL },
         { "Codemasters",   NULL },
         { "Korea",         NULL },
         { "Korea MSX",     NULL },
         { "Korea X-in-1",  NULL },
         { "Korea 4-Pak",   NULL },
         { "Korea Janggun", NULL },
         { "Korea Nemesis", NULL },
         { "Taiwan 8K RAM", NULL },
         { NULL, NULL },
       },
      "Auto"
   },
   {
      "picodrive_smstms",
      "Master System Palette in TMS modes",
      NULL,
      "Choose which colour palette should be used when an SMS game runs in one of the SG-1000 graphics modes.",
      NULL,
      "system",
      {
         { "SMS",           NULL },
         { "SG-1000",       NULL },
         { NULL, NULL },
       },
      "SMS"
   },
   {
      "picodrive_ramcart",
      "Sega CD RAM Cart",
      NULL,
      "Emulate a Sega CD RAM cart, used for save game data. WARNING: When enabled, internal save data (BRAM) will be discarded.",
      NULL,
      "system",
      {
         { "disabled", NULL },
         { "enabled",  NULL },
         { NULL, NULL },
      },
      "disabled"
   },
   {
      "picodrive_aspect",
      "Core-Provided Aspect Ratio",
      NULL,
      "Choose the preferred content aspect ratio. This will only apply when RetroArch's aspect ratio is set to 'Core Provided' in the Video settings.",
      NULL,
      "video",
      {
         { "PAR", NULL },
         { "4/3", "4:3" },
         { "CRT", NULL },
         { NULL, NULL },
      },
      "PAR"
   },
   {
      "picodrive_ggghost",
      "LCD Ghosting Filter",
      NULL,
      "Apply an image 'ghosting' filter to mimic the display characteristics of the Game Gear and 'Genesis Nomad' LCD panels.",
      NULL,
      "video",
      {
         { "off",    "disabled" },
         { "weak",   "Weak" },
         { "normal", "Normal" },
         { NULL, NULL },
      },
      "off"
   },
   {
      "picodrive_renderer",
      "Video Renderer",
      "Renderer",
      "Specify video rendering method. 'Accurate' is slowest, but most exact. 'Good' is faster, but fails if colors change mid-frame too often. 'Fast' renders the complete frame in one pass, and is incompatible with games that rely on mid-frame palette/sprite table updates.",
      NULL,
      "video",
      {
         { "accurate", "Accurate" },
         { "good",     "Good" },
         { "fast",     "Fast" },
         { NULL, NULL },
      },
      "accurate"
   },
   {
      "picodrive_sound_rate",
      "Audio Sample Rate (Hz)",
      "Sample Rate (Hz)",
      "Higher values increase sound quality. Lower values may increase performance. Native is the Mega Drive sound chip rate (~53000). Select this if you want the most accurate audio.",
      NULL,
      "audio",
      {
         { "16000", NULL },
         { "22050", NULL },
         { "32000", NULL },
         { "44100", NULL },
         { "native", NULL },
         { NULL, NULL },
      },
      "44100"
   },
   {
      "picodrive_fm_filter",
      "FM filtering",
      NULL,
      "Enable filtering for Mega Drive FM sound at non-native bitrates. Sound output will improve, at the price of being noticeably slower",
      NULL,
      "audio",
      {
         { "off", "disabled" },
         { "on",  "enabled" },
         { NULL, NULL },
      },
      "off"
   },
   {
      "picodrive_smsfm",
      "Master System FM Sound Unit",
      NULL,
      "Enable emulation of the SMS FM Sound Unit. This produces higher quality audio in some games, but non-Japanese titles may fail to run.",
      NULL,
      "audio",
      {
         { "off", "disabled" },
         { "on",  "enabled" },
         { NULL, NULL },
      },
      "off"
   },
   {
      "picodrive_dacnoise",
      "Mega Drive FM DAC noise",
      NULL,
      "Enable emulation of YM2612 DAC noise. This option generates a distortion which existed on most Model 1 Mega Drive/Genesis, but not on newer models.",
      NULL,
      "audio",
      {
         { "off", "disabled" },
         { "on",  "enabled" },
         { NULL, NULL },
      },
      "off"
   },
   {
      "picodrive_audio_filter",
      "Audio Filter",
      NULL,
      "Enable a low pass audio filter to better simulate the characteristic sound of a Model 1 Mega Drive/Genesis. Note that only Model 1 and its add-ons (Sega CD, 32X) employed a physical low pass filter.",
      NULL,
      "audio",
      {
         { "disabled", NULL },
         { "low-pass", "Low-Pass" },
         { NULL, NULL },
      },
      "disabled"
   },
   {
      "picodrive_lowpass_range",
      "Low-Pass Filter %",
      NULL,
      "Specify the cut-off frequency of the low pass audio filter. A higher value increases the perceived 'strength' of the filter, since a wider range of the high frequency spectrum is attenuated.",
      NULL,
      "audio",
      {
         { "5",  NULL },
         { "10", NULL },
         { "15", NULL },
         { "20", NULL },
         { "25", NULL },
         { "30", NULL },
         { "35", NULL },
         { "40", NULL },
         { "45", NULL },
         { "50", NULL },
         { "55", NULL },
         { "60", NULL },
         { "65", NULL },
         { "70", NULL },
         { "75", NULL },
         { "80", NULL },
         { "85", NULL },
         { "90", NULL },
         { "95", NULL },
         { NULL, NULL },
      },
      "60"
   },
   {
      "picodrive_input1",
      "Input Device 1",
      NULL,
      "Choose which type of controller is plugged into slot 1. Note that a multiplayer adaptor uses both slots.",
      NULL,
      "input",
      {
         { "3 button pad", "3 Button Pad" },
         { "6 button pad", "6 Button Pad" },
         { "team player", "Sega 4 Player Adaptor" },
         { "4way play", "EA 4way Play Adaptor" },
         { "None", NULL },
         { NULL, NULL },
      },
      "3 button pad"
   },
   {
      "picodrive_input2",
      "Input Device 2",
      NULL,
      "Choose which type of controller is plugged into slot 2. This setting is ignored when a multiplayer adaptor is plugged into slot 1.",
      NULL,
      "input",
      {
         { "3 button pad", "3 Button Pad" },
         { "6 button pad", "6 Button Pad" },
         { "None", NULL },
         { NULL, NULL },
      },
      "3 button pad"
   },
#ifdef DRC_SH2
   {
      "picodrive_drc",
      "Dynamic Recompilers",
      NULL,
      "Enable dynamic recompilers which help to improve performance. Less accurate than interpreter CPU cores, but significantly faster.",
      NULL,
      "performance",
      {
         { "enabled",  NULL },
         { "disabled", NULL },
         { NULL, NULL },
      },
      "enabled"
   },
#endif
   {
      "picodrive_frameskip",
      "Frameskip",
      NULL,
      "Skip frames to avoid audio buffer under-run (crackling). Improves performance at the expense of visual smoothness. 'Auto' skips frames when advised by the frontend. 'Manual' utilises the 'Frameskip Threshold (%)' setting.",
      NULL,
      "performance",
      {
         { "disabled", NULL },
         { "auto",     "Auto" },
         { "manual",   "Manual" },
         { NULL, NULL },
      },
      "disabled"
   },
   {
      "picodrive_frameskip_threshold",
      "Frameskip Threshold (%)",
      NULL,
      "When 'Frameskip' is set to 'Manual', specifies the audio buffer occupancy threshold (percentage) below which frames will be skipped. Higher values reduce the risk of crackling by causing frames to be dropped more frequently.",
      NULL,
      "performance",
      {
         { "15", NULL },
         { "18", NULL },
         { "21", NULL },
         { "24", NULL },
         { "27", NULL },
         { "30", NULL },
         { "33", NULL },
         { "36", NULL },
         { "39", NULL },
         { "42", NULL },
         { "45", NULL },
         { "48", NULL },
         { "51", NULL },
         { "54", NULL },
         { "57", NULL },
         { "60", NULL },
         { NULL, NULL },
      },
      "33"
   },
   {
      "picodrive_sprlim",
      "No Sprite Limit",
      NULL,
      "Removes the original sprite-per-scanline hardware limit. This reduces flickering but can cause visual glitches, as some games exploit the hardware limit to generate special effects.",
      NULL,
      "hacks",
      {
         { "disabled", NULL },
         { "enabled",  NULL },
         { NULL, NULL },
      },
      "disabled"
   },
   {
      "picodrive_overclk68k",
      "68K Overclock",
      NULL,
      "Overclock the emulated 68K chip. Can reduce slowdown, but may cause glitches.",
      NULL,
      "hacks",
      {
         { "disabled", NULL },
         { "+25%",     NULL },
         { "+50%",     NULL },
         { "+75%",     NULL },
         { "+100%",    NULL },
         { "+200%",    NULL },
         { "+400%",    NULL },
         { NULL, NULL },
      },
      "disabled"
   },
   { NULL, NULL, NULL, NULL, NULL, NULL, {{0}}, NULL },
};

struct retro_core_options_v2 options_us = {
   option_cats_us,
   option_defs_us
};

/*
 ********************************
 * Language Mapping
 ********************************
*/

#ifndef HAVE_NO_LANGEXTRA
struct retro_core_options_v2 *options_intl[RETRO_LANGUAGE_LAST] = {
   &options_us, /* RETRO_LANGUAGE_ENGLISH */
   NULL,        /* RETRO_LANGUAGE_JAPANESE */
   NULL,        /* RETRO_LANGUAGE_FRENCH */
   NULL,        /* RETRO_LANGUAGE_SPANISH */
   NULL,        /* RETRO_LANGUAGE_GERMAN */
   NULL,        /* RETRO_LANGUAGE_ITALIAN */
   NULL,        /* RETRO_LANGUAGE_DUTCH */
   NULL,        /* RETRO_LANGUAGE_PORTUGUESE_BRAZIL */
   NULL,        /* RETRO_LANGUAGE_PORTUGUESE_PORTUGAL */
   NULL,        /* RETRO_LANGUAGE_RUSSIAN */
   NULL,        /* RETRO_LANGUAGE_KOREAN */
   NULL,        /* RETRO_LANGUAGE_CHINESE_TRADITIONAL */
   NULL,        /* RETRO_LANGUAGE_CHINESE_SIMPLIFIED */
   NULL,        /* RETRO_LANGUAGE_ESPERANTO */
   NULL,        /* RETRO_LANGUAGE_POLISH */
   NULL,        /* RETRO_LANGUAGE_VIETNAMESE */
   NULL,        /* RETRO_LANGUAGE_ARABIC */
   NULL,        /* RETRO_LANGUAGE_GREEK */
   &options_tr, /* RETRO_LANGUAGE_TURKISH */
   NULL,        /* RETRO_LANGUAGE_SLOVAK */
   NULL,        /* RETRO_LANGUAGE_PERSIAN */
   NULL,        /* RETRO_LANGUAGE_HEBREW */
   NULL,        /* RETRO_LANGUAGE_ASTURIAN */
   NULL,        /* RETRO_LANGUAGE_FINNISH */
};
#endif

/*
 ********************************
 * Functions
 ********************************
*/

/* Handles configuration/setting of core options.
 * Should be called as early as possible - ideally inside
 * retro_set_environment(), and no later than retro_load_game()
 * > We place the function body in the header to avoid the
 *   necessity of adding more .c files (i.e. want this to
 *   be as painless as possible for core devs)
 */

static INLINE void libretro_set_core_options(retro_environment_t environ_cb,
      bool *categories_supported)
{
   unsigned version  = 0;
#ifndef HAVE_NO_LANGEXTRA
   unsigned language = 0;
#endif

   if (!environ_cb || !categories_supported)
      return;

   *categories_supported = false;

   if (!environ_cb(RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION, &version))
      version = 0;

   if (version >= 2)
   {
#ifndef HAVE_NO_LANGEXTRA
      struct retro_core_options_v2_intl core_options_intl;

      core_options_intl.us    = &options_us;
      core_options_intl.local = NULL;

      if (environ_cb(RETRO_ENVIRONMENT_GET_LANGUAGE, &language) &&
          (language < RETRO_LANGUAGE_LAST) && (language != RETRO_LANGUAGE_ENGLISH))
         core_options_intl.local = options_intl[language];

      *categories_supported = environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL,
            &core_options_intl);
#else
      *categories_supported = environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2,
            &options_us);
#endif
   }
   else
   {
      size_t i, j;
      size_t option_index              = 0;
      size_t num_options               = 0;
      struct retro_core_option_definition
            *option_v1_defs_us         = NULL;
#ifndef HAVE_NO_LANGEXTRA
      size_t num_options_intl          = 0;
      struct retro_core_option_v2_definition
            *option_defs_intl          = NULL;
      struct retro_core_option_definition
            *option_v1_defs_intl       = NULL;
      struct retro_core_options_intl
            core_options_v1_intl;
#endif
      struct retro_variable *variables = NULL;
      char **values_buf                = NULL;

      /* Determine total number of options */
      while (true)
      {
         if (option_defs_us[num_options].key)
            num_options++;
         else
            break;
      }

      if (version >= 1)
      {
         /* Allocate US array */
         option_v1_defs_us = (struct retro_core_option_definition *)
               calloc(num_options + 1, sizeof(struct retro_core_option_definition));

         /* Copy parameters from option_defs_us array */
         for (i = 0; i < num_options; i++)
         {
            struct retro_core_option_v2_definition *option_def_us = &option_defs_us[i];
            struct retro_core_option_value *option_values         = option_def_us->values;
            struct retro_core_option_definition *option_v1_def_us = &option_v1_defs_us[i];
            struct retro_core_option_value *option_v1_values      = option_v1_def_us->values;

            option_v1_def_us->key           = option_def_us->key;
            option_v1_def_us->desc          = option_def_us->desc;
            option_v1_def_us->info          = option_def_us->info;
            option_v1_def_us->default_value = option_def_us->default_value;

            /* Values must be copied individually... */
            while (option_values->value)
            {
               option_v1_values->value = option_values->value;
               option_v1_values->label = option_values->label;

               option_values++;
               option_v1_values++;
            }
         }

#ifndef HAVE_NO_LANGEXTRA
         if (environ_cb(RETRO_ENVIRONMENT_GET_LANGUAGE, &language) &&
             (language < RETRO_LANGUAGE_LAST) && (language != RETRO_LANGUAGE_ENGLISH) &&
             options_intl[language])
            option_defs_intl = options_intl[language]->definitions;

         if (option_defs_intl)
         {
            /* Determine number of intl options */
            while (true)
            {
               if (option_defs_intl[num_options_intl].key)
                  num_options_intl++;
               else
                  break;
            }

            /* Allocate intl array */
            option_v1_defs_intl = (struct retro_core_option_definition *)
                  calloc(num_options_intl + 1, sizeof(struct retro_core_option_definition));

            /* Copy parameters from option_defs_intl array */
            for (i = 0; i < num_options_intl; i++)
            {
               struct retro_core_option_v2_definition *option_def_intl = &option_defs_intl[i];
               struct retro_core_option_value *option_values           = option_def_intl->values;
               struct retro_core_option_definition *option_v1_def_intl = &option_v1_defs_intl[i];
               struct retro_core_option_value *option_v1_values        = option_v1_def_intl->values;

               option_v1_def_intl->key           = option_def_intl->key;
               option_v1_def_intl->desc          = option_def_intl->desc;
               option_v1_def_intl->info          = option_def_intl->info;
               option_v1_def_intl->default_value = option_def_intl->default_value;

               /* Values must be copied individually... */
               while (option_values->value)
               {
                  option_v1_values->value = option_values->value;
                  option_v1_values->label = option_values->label;

                  option_values++;
                  option_v1_values++;
               }
            }
         }

         core_options_v1_intl.us    = option_v1_defs_us;
         core_options_v1_intl.local = option_v1_defs_intl;

         environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL, &core_options_v1_intl);
#else
         environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS, option_v1_defs_us);
#endif
      }
      else
      {
         /* Allocate arrays */
         variables  = (struct retro_variable *)calloc(num_options + 1,
               sizeof(struct retro_variable));
         values_buf = (char **)calloc(num_options, sizeof(char *));

         if (!variables || !values_buf)
            goto error;

         /* Copy parameters from option_defs_us array */
         for (i = 0; i < num_options; i++)
         {
            const char *key                        = option_defs_us[i].key;
            const char *desc                       = option_defs_us[i].desc;
            const char *default_value              = option_defs_us[i].default_value;
            struct retro_core_option_value *values = option_defs_us[i].values;
            size_t buf_len                         = 3;
            size_t default_index                   = 0;

            values_buf[i] = NULL;

            if (desc)
            {
               size_t num_values = 0;

               /* Determine number of values */
               while (true)
               {
                  if (values[num_values].value)
                  {
                     /* Check if this is the default value */
                     if (default_value)
                        if (strcmp(values[num_values].value, default_value) == 0)
                           default_index = num_values;

                     buf_len += strlen(values[num_values].value);
                     num_values++;
                  }
                  else
                     break;
               }

               /* Build values string */
               if (num_values > 0)
               {
                  buf_len += num_values - 1;
                  buf_len += strlen(desc);

                  values_buf[i] = (char *)calloc(buf_len, sizeof(char));
                  if (!values_buf[i])
                     goto error;

                  strcpy(values_buf[i], desc);
                  strcat(values_buf[i], "; ");

                  /* Default value goes first */
                  strcat(values_buf[i], values[default_index].value);

                  /* Add remaining values */
                  for (j = 0; j < num_values; j++)
                  {
                     if (j != default_index)
                     {
                        strcat(values_buf[i], "|");
                        strcat(values_buf[i], values[j].value);
                     }
                  }
               }
            }

            variables[option_index].key   = key;
            variables[option_index].value = values_buf[i];
            option_index++;
         }

         /* Set variables */
         environ_cb(RETRO_ENVIRONMENT_SET_VARIABLES, variables);
      }

error:
      /* Clean up */

      if (option_v1_defs_us)
      {
         free(option_v1_defs_us);
         option_v1_defs_us = NULL;
      }

#ifndef HAVE_NO_LANGEXTRA
      if (option_v1_defs_intl)
      {
         free(option_v1_defs_intl);
         option_v1_defs_intl = NULL;
      }
#endif

      if (values_buf)
      {
         for (i = 0; i < num_options; i++)
         {
            if (values_buf[i])
            {
               free(values_buf[i]);
               values_buf[i] = NULL;
            }
         }

         free(values_buf);
         values_buf = NULL;
      }

      if (variables)
      {
         free(variables);
         variables = NULL;
      }
   }
}

#ifdef __cplusplus
}
#endif

#endif
