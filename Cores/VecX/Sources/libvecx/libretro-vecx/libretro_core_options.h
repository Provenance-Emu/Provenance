#ifndef LIBRETRO_CORE_OPTIONS_H__
#define LIBRETRO_CORE_OPTIONS_H__

#include <stdlib.h>
#include <string.h>

#include <libretro.h>
#include <retro_inline.h>

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

struct retro_core_option_definition option_defs_us[] = {
#ifdef HAS_GPU    
   {
      "vecx_use_hw",
      "Use Hardware Rendering",
      "Configure the rendering method. You will need to exit and restart the emulator after changing this. (Switching to another game works but just restarting the current one doesn't.)",
      {
         { "Software", NULL},
         { "Hardware", NULL},
         { NULL, NULL },
      },
      "Hardware"
   },
#endif   
   {
      "vecx_res_multi",
      "Internal Resolution Multiplier",
      "Configure the resolution.",
      {
         { "1",   NULL },
         { "2",   NULL },
         { "3",   NULL },
         { "4",   NULL },
         { NULL, NULL },
      },
      "1"
   },
#ifdef HAS_GPU   
   {
       "vecx_res_hw",
       "Hardware Rendering Resolution",
       "Configure the resolution.",
       {
           { "434x540", NULL },
           { "515x640", NULL },
           { "580x720", NULL },
           { "618x768", NULL },
           { "824x1024", NULL },
           { "845x1050", NULL },
           { "869x1080", NULL },
           { "966x1200", NULL },
           { "1159x1440", NULL },
           { "1648x2048", NULL },
           { NULL, NULL }
       },
       "824x1024"
   },
   {
       "vecx_line_brightness",
       "Line brightness",
       "How bright the lines are.",
       {
           { "1", NULL },
           { "2", NULL },
           { "3", NULL },
           { "4", NULL },
           { "5", NULL },
           { "6", NULL },
           { "7", NULL },
           { "8", NULL },
           { "9", NULL },
           { NULL, NULL }
       },
       "4"
   },
   {
       "vecx_line_width",
       "Line width",
       "How wide the lines are. Set higher in low resolutions to avoid aliasing.",
       {
           { "1", NULL },
           { "2", NULL },
           { "3", NULL },
           { "4", NULL },
           { "5", NULL },
           { "6", NULL },
           { "7", NULL },
           { "8", NULL },
           { "9", NULL },
           { NULL, NULL }
       },
       "4"
   },
   {
       "vecx_bloom_brightness",
       "Bloom brightness",
       "How bright the bloom is. 0 to switch bloom off.",
       {
           { "0", NULL },
           { "1", NULL },
           { "2", NULL },
           { "3", NULL },
           { "4", NULL },
           { "5", NULL },
           { "6", NULL },
           { "7", NULL },
           { "8", NULL },
           { "9", NULL },
           { NULL, NULL }
       },
       "4"
   },
   {
       "vecx_bloom_width",
       "Bloom width",
       "Bloom width relative to the line width",
       {
           { "2x", NULL },
           { "3x", NULL },
           { "4x", NULL },
           { "6x", NULL },
           { "8x", NULL },
           { "10x", NULL },
           { "12x", NULL },
           { "14x", NULL },
           { "16x", NULL },
           { NULL, NULL }
       },
       "8x"
   },
#endif   
   {
      "vecx_scale_x",
      "Scale vector display horizontally",
      "Configure the scale.",
      {
       {"0.845",NULL},
       {"0.85",NULL},
       {"0.855",NULL},
       {"0.86",NULL},
       {"0.865",NULL},
       {"0.87",NULL},
       {"0.875",NULL},
       {"0.88",NULL},
       {"0.885",NULL},
       {"0.89",NULL},
       {"0.895",NULL},
       {"0.90",NULL},
       {"0.905",NULL},
       {"0.91",NULL},
       {"0.915",NULL},
       {"0.92",NULL},
       {"0.925",NULL},
       {"0.93",NULL},
       {"0.935",NULL},
       {"0.94",NULL},
       {"0.945",NULL},
       {"0.95",NULL},
       {"0.955",NULL},
       {"0.96",NULL},
       {"0.965",NULL},
       {"0.97",NULL},
       {"0.975",NULL},
       {"0.98",NULL},
       {"0.985",NULL},
       {"0.99",NULL},
       {"0.995",NULL},
       {"1",NULL},
       {"1.005",NULL},
       {"1.01",NULL},
      },
      "1"
   },
   {
      "vecx_scale_y",
      "Scale vector display vertically",
      "Configure the scale.",
      {
       {"0.845",NULL},
       {"0.85",NULL},
       {"0.855",NULL},
       {"0.86",NULL},
       {"0.865",NULL},
       {"0.87",NULL},
       {"0.875",NULL},
       {"0.88",NULL},
       {"0.885",NULL},
       {"0.89",NULL},
       {"0.895",NULL},
       {"0.90",NULL},
       {"0.905",NULL},
       {"0.91",NULL},
       {"0.915",NULL},
       {"0.92",NULL},
       {"0.925",NULL},
       {"0.93",NULL},
       {"0.935",NULL},
       {"0.94",NULL},
       {"0.945",NULL},
       {"0.95",NULL},
       {"0.955",NULL},
       {"0.96",NULL},
       {"0.965",NULL},
       {"0.97",NULL},
       {"0.975",NULL},
       {"0.98",NULL},
       {"0.985",NULL},
       {"0.99",NULL},
       {"0.995",NULL},
       {"1",NULL},
       {"1.005",NULL},
       {"1.01",NULL},
      },
      "1"
   },
   {
      "vecx_shift_x",
      "Horizontal shift",
      "Shift horizontally.",
      {
         { "-0.03",   NULL },
         { "-0.025",   NULL },
         { "-0.02",   NULL },
         { "-0.015",   NULL },
         { "-0.01",   NULL },
         { "-0.005",   NULL },
         { "0",   NULL },
         { "0.005",   NULL },
         { "0.01",   NULL },
         { "0.015",   NULL },
         { "0.02",   NULL },
         { "0.025",   NULL },
         { "0.03",   NULL },
         { NULL, NULL },
      },
      "0"
   },
   {
      "vecx_shift_y",
      "Vertical shift",
      "Shift vertically.",
      {
         { "-0.035",   NULL },
         { "-0.03",   NULL },
         { "-0.025",   NULL },
         { "-0.02",   NULL },
         { "-0.015",   NULL },
         { "-0.01",   NULL },
         { "-0.005",   NULL },
         { "0",   NULL },
         { "0.005",   NULL },
         { "0.01",   NULL },
         { "0.015",   NULL },
         { "0.02",   NULL },
         { "0.025",   NULL },
         { "0.03",   NULL },
         { "0.035",   NULL },
         { "0.04",   NULL },
         { "0.045",   NULL },
         { "0.05",   NULL },
         { "0.055",   NULL },
         { "0.06",   NULL },
         { "0.065",   NULL },
         { "0.07",   NULL },
         { "0.075",   NULL },
         { "0.08",   NULL },
         { "0.085",   NULL },
         { "0.09",   NULL },
         { "0.095",   NULL },
         { "0.1",   NULL },
         { NULL, NULL },
      },
      "0"
   },
   { NULL, NULL, NULL, {{0}}, NULL },
};

/* RETRO_LANGUAGE_JAPANESE */

/* RETRO_LANGUAGE_FRENCH */

/* RETRO_LANGUAGE_SPANISH */

/* RETRO_LANGUAGE_GERMAN */

/* RETRO_LANGUAGE_ITALIAN */

/* RETRO_LANGUAGE_DUTCH */

/* RETRO_LANGUAGE_PORTUGUESE_BRAZIL */

/* RETRO_LANGUAGE_PORTUGUESE_PORTUGAL */

/* RETRO_LANGUAGE_RUSSIAN */

/* RETRO_LANGUAGE_KOREAN */

/* RETRO_LANGUAGE_CHINESE_TRADITIONAL */

/* RETRO_LANGUAGE_CHINESE_SIMPLIFIED */

/* RETRO_LANGUAGE_ESPERANTO */

/* RETRO_LANGUAGE_POLISH */

/* RETRO_LANGUAGE_VIETNAMESE */

/* RETRO_LANGUAGE_ARABIC */

/* RETRO_LANGUAGE_GREEK */

/* RETRO_LANGUAGE_TURKISH */

/*
 ********************************
 * Language Mapping
 ********************************
*/

struct retro_core_option_definition *option_defs_intl[RETRO_LANGUAGE_LAST] = {
   option_defs_us, /* RETRO_LANGUAGE_ENGLISH */
   NULL,           /* RETRO_LANGUAGE_JAPANESE */
   NULL,           /* RETRO_LANGUAGE_FRENCH */
   NULL,           /* RETRO_LANGUAGE_SPANISH */
   NULL,           /* RETRO_LANGUAGE_GERMAN */
   NULL,           /* RETRO_LANGUAGE_ITALIAN */
   NULL,           /* RETRO_LANGUAGE_DUTCH */
   NULL,           /* RETRO_LANGUAGE_PORTUGUESE_BRAZIL */
   NULL,           /* RETRO_LANGUAGE_PORTUGUESE_PORTUGAL */
   NULL,           /* RETRO_LANGUAGE_RUSSIAN */
   NULL,           /* RETRO_LANGUAGE_KOREAN */
   NULL,           /* RETRO_LANGUAGE_CHINESE_TRADITIONAL */
   NULL,           /* RETRO_LANGUAGE_CHINESE_SIMPLIFIED */
   NULL,           /* RETRO_LANGUAGE_ESPERANTO */
   NULL,           /* RETRO_LANGUAGE_POLISH */
   NULL,           /* RETRO_LANGUAGE_VIETNAMESE */
   NULL,           /* RETRO_LANGUAGE_ARABIC */
   NULL,           /* RETRO_LANGUAGE_GREEK */
   NULL,           /* RETRO_LANGUAGE_TURKISH */
};

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

static INLINE void libretro_set_core_options(retro_environment_t environ_cb)
{
   unsigned version = 0;

   if (!environ_cb)
      return;

   if (environ_cb(RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION, &version) && (version == 1))
   {
      struct retro_core_options_intl core_options_intl;
      unsigned language = 0;

      core_options_intl.us    = option_defs_us;
      core_options_intl.local = NULL;

      if (environ_cb(RETRO_ENVIRONMENT_GET_LANGUAGE, &language) &&
          (language < RETRO_LANGUAGE_LAST) && (language != RETRO_LANGUAGE_ENGLISH))
         core_options_intl.local = option_defs_intl[language];

      environ_cb(RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL, &core_options_intl);
   }
   else
   {
      size_t i;
      size_t num_options               = 0;
      struct retro_variable *variables = NULL;
      char **values_buf                = NULL;

      /* Determine number of options */
      while (true)
      {
         if (option_defs_us[num_options].key)
            num_options++;
         else
            break;
      }

      /* Allocate arrays */
      variables  = (struct retro_variable *)calloc(num_options + 1, sizeof(struct retro_variable));
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
            if (num_values > 1)
            {
               size_t j;

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

         variables[i].key   = key;
         variables[i].value = values_buf[i];
      }
      
      /* Set variables */
      environ_cb(RETRO_ENVIRONMENT_SET_VARIABLES, variables);

error:

      /* Clean up */
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
