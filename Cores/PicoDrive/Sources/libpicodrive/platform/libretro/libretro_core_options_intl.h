#ifndef LIBRETRO_CORE_OPTIONS_INTL_H__
#define LIBRETRO_CORE_OPTIONS_INTL_H__

#if defined(_MSC_VER) && (_MSC_VER >= 1500 && _MSC_VER < 1900)
/* https://support.microsoft.com/en-us/kb/980263 */
#pragma execution_character_set("utf-8")
#pragma warning(disable:4566)
#endif

#include <libretro.h>

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


struct retro_core_option_v2_category option_cats_tr[] = {
   { NULL, NULL, NULL },
};

struct retro_core_option_v2_definition option_defs_tr[] = {
   {
      "picodrive_input1",
      "Giriş cihazı 1",
      NULL,
      "Hangi tür kontrolör'ün yuva 1'e takılı olduğunu seçin.",
      NULL,
      NULL,
      {
         { "3 button pad", NULL },
         { "6 button pad", NULL },
         { "None",         "hiçbiri" },
         { NULL, NULL },
      },
      "3 button pad"
   },
   {
      "picodrive_input2",
      "Giriş cihazı 2",
      NULL,
      "Hangi tür kontrolör'ün yuva 2'e takılı olduğunu seçin",
      NULL,
      NULL,
      {
         { "3 button pad", NULL },
         { "6 button pad", NULL },
         { "None",         "hiçbiri" },
         { NULL, NULL },
      },
      "3 button pad"
   },
   {
      "picodrive_sprlim",
      "Sprite sınırı yok",
      NULL,
      "Sprite sınırını kaldırmak için bunu etkinleştirin.",
      NULL,
      NULL,
      {
         { NULL, NULL },
      },
      "disabled"
   },
   {
      "picodrive_ramcart",
      "Sega CD RAM Kartuşu",
      NULL,
      "Oyun verilerini kaydetmek için kullanılan bir MegaCD RAM kartuşunu taklit edin.",
      NULL,
      NULL,
      {
         { NULL, NULL },
      },
      "disabled"
   },
   {
      "picodrive_region",
      "Bölge",
      NULL,
      "Belirli bir bölgeye zorlayın.",
      NULL,
      NULL,
      {
         { "Auto",       "Otomatik" },
         { "Japan NTSC", "Japonya NTSC" },
         { "Japan PAL",  "Japonya PAL" },
         { "US",         NULL },
         { "Europe",     "Avrupa" },
         { NULL, NULL },
      },
      "Auto"
   },
   {
      "picodrive_aspect",
      "Core tarafından belirlenen en boy oranı",
      NULL,
      "Core tarafından sağlanan en boy oranını seçin. RetroArch'ın en boy oranı, Video ayarlarında sağlanan Core olarak ayarlanmalıdır.",
      NULL,
      NULL,
      {
         { NULL, NULL },
      },
      "PAR"
   },
   {
      "picodrive_overclk68k",
      "68K Hızaşırtma",
      NULL,
      "Öykünülmüş 68K yongasına Hızaşırtma uygulayın.",
      NULL,
      NULL,
      {
         { NULL, NULL },
      },
      "disabled"
   },
#ifdef DRC_SH2
   {
      "picodrive_drc",
      "Dinamik Yeniden Derleyici",
      NULL,
      "Performansı artırmaya yardımcı olan dinamik yeniden derleyicileri etkinleştirin. Tercüman CPU çekirdeğinden daha az hassas, ancak çok daha hızlıdır.",
      NULL,
      NULL,
      {
         { NULL, NULL },
      },
      "enabled"
   },
#endif
   {
      "picodrive_audio_filter",
      "Ses Filtresi",
      NULL,
      "Model 1 Genesis'in karakteristik sesini daha iyi simüle etmek için düşük geçişli bir ses filtresini etkinleştirin. Master System ve PICO başlıkları kullanılırken bu seçenek yoksayılır. Sadece Genesis ve eklenti donanımı (Sega CD, 32X) fiziksel düşük geçiş filtresi kullanır.",
      NULL,
      NULL,
      {
         { "disabled", "devre dışı" },
         { "low-pass", "alçak geçiş" },
         { NULL, NULL },
      },
      "disabled"
   },
   {
      "picodrive_lowpass_range",
      "Alçak geçiş filtresi %",
      NULL,
      "Ses düşük geçiş filtresinin kesme frekansını belirtin. Daha yüksek bir değer, yüksek frekans spektrumunun daha geniş bir aralığı azaltıldığı için filtrenin algılanan gücünü arttırır.",
      NULL,
      NULL,
      {
         { NULL, NULL },
      },
      "60"
   },
   { NULL, NULL, NULL, NULL, NULL, NULL, {{0}}, NULL },
};

struct retro_core_options_v2 options_tr = {
   option_cats_tr,
   option_defs_tr
};

#ifdef __cplusplus
}
#endif

#endif
