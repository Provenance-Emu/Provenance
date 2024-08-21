//
//  MednafenGameCoreC.h
//  MednafenGameCoreC
//
//  Created by Joseph Mattiello on 8/20/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

#pragma once

#define LSB_FIRST

//! Project version number for MednafenGameCoreC.
//FOUNDATION_EXPORT double MednafenGameCoreCVersionNumber;

//! Project version string for MednafenGameCoreC.
//FOUNDATION_EXPORT const unsigned char MednafenGameCoreCVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <MednafenGameCoreC/PublicHeader.h>
//#endif

//#if __cplusplus
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wall"
//#pragma clang diagnostic ignored "-Wextra"

//#include <MednafenGameCoreC/mednafen.h>
//#import <mednafen/settings-driver.h>
//#import <mednafen/state-driver.h>
//#import <mednafen/mednafen-driver.h>
//#import <mednafen/MemoryStream.h>
//#import <mednafen/mempatcher.h>
//#pragma clang dia gnostic pop
//#endif

#if defined(__clang__)
  //
  // Begin clang
  //
  #define MDFN_MAKE_CLANGV(maj,min,pl) (((maj)*100*100) + ((min) * 100) + (pl))
  #define MDFN_CLANG_VERSION    MDFN_MAKE_CLANGV(__clang_major__, __clang_minor__, __clang_patchlevel__)

  #define INLINE inline __attribute__((always_inline))
  #define NO_INLINE __attribute__((noinline))
  #define NO_CLONE

  #if defined(ARCH_X86_32)
    #define MDFN_FASTCALL __attribute__((fastcall))
  #else
    #define MDFN_FASTCALL
  #endif

  #define MDFN_FORMATSTR(a,b,c)
  #define MDFN_WARN_UNUSED_RESULT __attribute__ ((warn_unused_result))
  #define MDFN_NOWARN_UNUSED __attribute__((unused))

  #define MDFN_RESTRICT __restrict__

  #define MDFN_UNLIKELY(n) __builtin_expect((n) != 0, 0)
  #define MDFN_LIKELY(n) __builtin_expect((n) != 0, 1)

  #define MDFN_COLD __attribute__((cold))
  #define MDFN_HOT __attribute__((hot))

  #if MDFN_CLANG_VERSION >= MDFN_MAKE_CLANGV(3,6,0)
   #define MDFN_ASSUME_ALIGNED(p, align) ((decltype(p))__builtin_assume_aligned((p), (align)))
  #else
   #define MDFN_ASSUME_ALIGNED(p, align) (p)
  #endif

  #if defined(WIN32) || defined(DOS)
   #define MDFN_HIDE
  #else
   #define MDFN_HIDE __attribute__((visibility("hidden")))
  #endif
// end clang
#endif


#ifndef FALSE
 #define FALSE 0
#endif

#ifndef TRUE
 #define TRUE 1
#endif

#if !defined(MSB_FIRST) && !defined(LSB_FIRST)
 #error "Define MSB_FIRST or LSB_FIRST!"
#elif defined(MSB_FIRST) && defined(LSB_FIRST)
 #error "Define only one of MSB_FIRST or LSB_FIRST, not both!"
#endif

#ifdef LSB_FIRST
 #define MDFN_IS_BIGENDIAN false
#else
 #define MDFN_IS_BIGENDIAN true
#endif

#ifdef ENABLE_NLS
 #include "gettext.h"
#else
 #define gettext(s) (s)
 #define dgettext(d, s) (s)
 #define dcgettext(d, s, c) (s)
 #define gettext_noop(s) (s)
#endif

#define _(s) gettext(s)

//#import <Foundation/Foundation.h>

//#include <stddef.h>
//#include <assert.h>
//#include <inttypes.h>
//#include <stdint.h>
//#include <limits.h>
//#include <stdio.h>
//#include <stdlib.h>
//#include <stdarg.h>
//#include <string.h>
//#include <errno.h>
//#include <math.h>
//
#ifdef __cplusplus
//#include <cmath>
//#include <limits>
//#include <exception>
//#include <stdexcept>
//#include <type_traits>
//#include <initializer_list>
//#include <utility>
//#include <memory>
//#include <algorithm>
//#include <string>
//#include <vector>
//#include <array>
//#include <list>
//#include <map>
#endif


typedef char int8_t;
typedef int int16_t;
typedef long int32_t;
typedef long long int64_t;

typedef unsigned char uint8_t;
typedef unsigned int uint16_t;
typedef unsigned long uint32_t;
typedef unsigned long long uint64_t;

typedef int8_t int8;
typedef int16_t int16;
typedef int32_t int32;
typedef int64_t int64;

typedef uint8_t uint8;
typedef uint16_t uint16;
typedef uint32_t uint32;
typedef uint64_t uint64;

#if __cplusplus

namespace Mednafen
{

enum MDFNSettingType
{
    // Actual base types
        MDFNST_INT = 0,     // (signed), int8, int16, int32, int64(saved as)
        MDFNST_UINT,    // uint8, uint16, uint32, uint64(saved as)
        MDFNST_BOOL,    // bool. bool. bool!
        MDFNST_FLOAT,   // float, double(saved as).
    MDFNST_STRING,
    MDFNST_ENUM,    // Handled like a string, but validated against the enumeration list, and MDFN_GetSettingUI() returns the number in the enumeration list.
    MDFNST_MULTI_ENUM,

    MDFNST_ALIAS
};


//#define MDFNST_EX_DRIVER = (1U << 16),    // If this is not set, the setting is assumed to be internal.  This...should probably be set automatically?
        
#define MDFNSF_NOFLAGS        0U      // Always 0, makes setting definitions prettier...maybe.

// TODO(cats)
#define MDFNSF_CAT_INPUT            (1U << 8)
#define MDFNSF_CAT_SOUND        (1U << 9)
#define MDFNSF_CAT_VIDEO        (1U << 10)
#define MDFNSF_CAT_INPUT_MAPPING    (1U << 11)    // User-configurable physical->virtual button/axes and hotkey mappings(driver-side code category mainly).

// Setting is used as a path or filename(mostly intended for automatic charset conversion of 0.9.x settings on MS Windows).
#define MDFNSF_CAT_PATH            (1U << 12)

#define MDFNSF_EMU_STATE    (1U << 17) // If the setting affects emulation from the point of view of the emulated program
#define MDFNSF_UNTRUSTED_SAFE    (1U << 18) // If it's safe for an untrusted source to modify it, probably only used in conjunction with
                                          // MDFNST_EX_EMU_STATE and network play

#define MDFNSF_SUPPRESS_DOC    (1U << 19) // Suppress documentation generation for this setting.
#define MDFNSF_COMMON_TEMPLATE    (1U << 20) // Auto-generated common template setting(like nes.xscale, pce.xscale, vb.xscale, nes.enable, pce.enable, vb.enable)
#define MDFNSF_NONPERSISTENT    (1U << 21) // Don't save setting in settings file.

// TODO:
// #define MDFNSF_WILL_BREAK_GAMES (1U << ) // If changing the value of the setting from the default value will break games/programs that would otherwise work.

// TODO(in progress):
#define MDFNSF_REQUIRES_RELOAD    (1U << 24)    // If a game reload is required for the setting to take effect.
#define MDFNSF_REQUIRES_RESTART    (1U << 25)    // If Mednafen restart is required for the setting to take effect.

struct MDFNSetting_EnumList
{
    const char *string;
    int number;
    const char *description;    // Short
    const char *description_extra;    // Extra verbose text appended to the short description.
};

struct MDFNSetting
{
        const char *name;
    unsigned int flags;
        const char *description; // Short
    const char *description_extra;

        MDFNSettingType type;
        const char *default_value;
    const char *minimum;
    const char *maximum;
    bool (*validate_func)(const char *name, const char *value);
    void (*ChangeNotification)(const char *name);
    const MDFNSetting_EnumList *enum_list;
};

struct MDFNCS
{
    char *name;
    char *value;
    char *game_override;    // per-game setting override(netplay_override > game_override > value, in precedence)
    char *netplay_override; // "value" override for network play.

    const MDFNSetting *desc;
    void (*ChangeNotification)(const char *name);

    unsigned int name_hash;
};
//
// Due to how the per-module(and in the future, per-game) settings overrides work, we should
// take care not to call MDFNI_SetSetting*() unless the setting has actually changed due to a user action.
// I.E. do NOT call SetSetting*() unconditionally en-masse at emulator exit/game close to synchronize certain things like input mappings.
//
bool MDFNI_SetSetting(const char *name, const char *value, bool NetplayOverride = false);
//static INLINE bool MDFNI_SetSetting(const char *name, const std::string& value, bool NetplayOverride = false) { return MDFNI_SetSetting(name, value.c_str(), NetplayOverride); }
//static INLINE bool MDFNI_SetSetting(const std::string& name, const std::string& value, bool NetplayOverride = false) { return MDFNI_SetSetting(name.c_str(), value.c_str(), NetplayOverride); }

bool MDFNI_SetSettingB(const char *name, bool value);
//static INLINE bool MDFNI_SetSettingB(const std::string& name, bool value) { return MDFNI_SetSettingB(name.c_str(), value); }

bool MDFNI_SetSettingUI(const char *name, unsigned long long value);
//static INLINE bool MDFNI_SetSettingUI(const std::string& name, uint64 value) { return MDFNI_SetSettingUI(name.c_str(), value); }

void MDFNI_DumpSettingsDef(const char *path) MDFN_COLD;

//const std::vector<MDFNCS>* MDFNI_GetSettings(void);
//std::string MDFNI_GetSettingDefault(const char* name);
//static INLINE std::string MDFNI_GetSettingDefault(const std::string& name) { return MDFNI_GetSettingDefault(name.c_str()); }
//


/// ----------------
/// video/surface.h
/// ----------------

struct MDFN_Rect
{
 int32 x, y, w, h;
};

enum
{
 MDFN_COLORSPACE_RGB = 0,
 //MDFN_COLORSPACE_LRGB = 1,    // Linear RGB, 16-bit per component, TODO in the future?
};

struct MDFN_PaletteEntry
{
 uint8 r, g, b;
};

/*
template<typename T>
static constexpr INLINE uint64 MDFN_PixelFormat_SetTagT(const uint64 tag)
{
 return (tag & ~0xFF) | (sizeof(T) * 8);
}
*/

static constexpr INLINE uint64 MDFN_PixelFormat_MakeTag(const uint8 colorspace,
          const uint8 opp,
          const uint8 rs, const uint8 gs, const uint8 bs, const uint8 as,
          const uint8 rp, const uint8 gp, const uint8 bp, const uint8 ap)
{
  // (8 * 6) = 48
  return ((uint64)colorspace << 56) | ((uint64)opp << 48) |
     ((uint64)rs << (0 * 6)) | ((uint64)gs << (1 * 6)) | ((uint64)bs << (2 * 6)) | ((uint64)as << (3 * 6)) |
     ((uint64)rp << (4 * 6)) | ((uint64)gp << (5 * 6)) | ((uint64)bp << (6 * 6)) | ((uint64)ap << (7 * 6));
}

class MDFN_PixelFormat
{
 public:

 //
 // MDFN_PixelFormat constructors must remain inline for various code to be optimized
 // properly by the compiler.
 //
 INLINE MDFN_PixelFormat(const uint64 tag_) :
        tag(tag_),
        colorspace((uint8)(tag_ >> 56)),
        opp((uint8)(tag_ >> 48)),
        Rshift((tag_ >> (0 * 6)) & 0x3F),
        Gshift((tag_ >> (1 * 6)) & 0x3F),
        Bshift((tag_ >> (2 * 6)) & 0x3F),
        Ashift((tag_ >> (3 * 6)) & 0x3F),
        Rprec((tag_ >> (4 * 6)) & 0x3F),
        Gprec((tag_ >> (5 * 6)) & 0x3F),
        Bprec((tag_ >> (6 * 6)) & 0x3F),
        Aprec((tag_ >> (7 * 6)) & 0x3F)
 {
  //
 }

 INLINE MDFN_PixelFormat() :
            tag(0),
            colorspace(0),
            opp(0),
            Rshift(0), Gshift(0), Bshift(0), Ashift(0),
            Rprec(0), Gprec(0), Bprec(0), Aprec(0)
 {
  //
 }

 INLINE MDFN_PixelFormat(const unsigned int colorspace_,
          const uint8 opp_,
          const uint8 rs, const uint8 gs, const uint8 bs, const uint8 as,
          const uint8 rp = 8, const uint8 gp = 8, const uint8 bp = 8, const uint8 ap = 8) :
            tag(MDFN_PixelFormat_MakeTag(colorspace_, opp_, rs, gs, bs, as, rp, gp, bp, ap)),
            colorspace(colorspace_),
            opp(opp_),
            Rshift(rs), Gshift(gs), Bshift(bs), Ashift(as),
            Rprec(rp), Gprec(gp), Bprec(bp), Aprec(ap)
 {
  //
 }

 //constexpr MDFN_PixelFormat(MDFN_PixelFormat&) = default;
 //constexpr MDFN_PixelFormat(MDFN_PixelFormat&&) = default;
 //MDFN_PixelFormat& operator=(MDFN_PixelFormat&) = default;

 bool operator==(const uint64& t)
 {
  return tag == t;
 }

 bool operator==(const MDFN_PixelFormat& a)
 {
  return tag == a.tag;
 }

 bool operator!=(const MDFN_PixelFormat& a)
 {
  return !(*this == a);
 }

 uint64 tag;

 uint8 colorspace;
 uint8 opp;    // Bytes per pixel; 1, 2, 4 (1 is WIP)

 uint8 Rshift;  // Bit position of the lowest bit of the red component
 uint8 Gshift;  // [...] green component
 uint8 Bshift;  // [...] blue component
 uint8 Ashift;  // [...] alpha component.

 uint8 Rprec;
 uint8 Gprec;
 uint8 Bprec;
 uint8 Aprec;

 // Creates a color value for the surface corresponding to the 8-bit R/G/B/A color passed.
 INLINE uint32 MakeColor(uint8 r, uint8 g, uint8 b, uint8 a = 0) const
 {
  if(opp == 2)
  {
   uint32 ret;

   ret  = ((r * ((1 << Rprec) - 1) + 127) / 255) << Rshift;
   ret |= ((g * ((1 << Gprec) - 1) + 127) / 255) << Gshift;
   ret |= ((b * ((1 << Bprec) - 1) + 127) / 255) << Bshift;
   ret |= ((a * ((1 << Aprec) - 1) + 127) / 255) << Ashift;

   return ret;
  }
  else
   return (r << Rshift) | (g << Gshift) | (b << Bshift) | (a << Ashift);
 }

 INLINE MDFN_PaletteEntry MakePColor(uint8 r, uint8 g, uint8 b) const
 {
  MDFN_PaletteEntry ret;

  ret.r = ((r * ((1 << Rprec) - 1) + 127) / 255) << Rshift;
  ret.g = ((g * ((1 << Gprec) - 1) + 127) / 255) << Gshift;
  ret.b = ((b * ((1 << Bprec) - 1) + 127) / 255) << Bshift;

  return ret;
 }

 INLINE void DecodePColor(const MDFN_PaletteEntry& pe, uint8 &r, uint8 &g, uint8 &b) const
 {
  r = ((pe.r >> Rshift) & ((1 << Rprec) - 1)) * 255 / ((1 << Rprec) - 1);
  g = ((pe.g >> Gshift) & ((1 << Gprec) - 1)) * 255 / ((1 << Gprec) - 1);
  b = ((pe.b >> Bshift) & ((1 << Bprec) - 1)) * 255 / ((1 << Bprec) - 1);
 }

 // Gets the R/G/B/A values for the passed 32-bit surface pixel value
 INLINE void DecodeColor(uint32 value, int &r, int &g, int &b, int &a) const
 {
  if(opp == 2)
  {
   r = ((value >> Rshift) & ((1 << Rprec) - 1)) * 255 / ((1 << Rprec) - 1);
   g = ((value >> Gshift) & ((1 << Gprec) - 1)) * 255 / ((1 << Gprec) - 1);
   b = ((value >> Bshift) & ((1 << Bprec) - 1)) * 255 / ((1 << Bprec) - 1);
   a = ((value >> Ashift) & ((1 << Aprec) - 1)) * 255 / ((1 << Aprec) - 1);
  }
  else
  {
   r = (value >> Rshift) & 0xFF;
   g = (value >> Gshift) & 0xFF;
   b = (value >> Bshift) & 0xFF;
   a = (value >> Ashift) & 0xFF;
  }
 }

 MDFN_HIDE static const uint8 LUT5to8[32];
 MDFN_HIDE static const uint8 LUT6to8[64];
 MDFN_HIDE static const uint8 LUT8to5[256];
 MDFN_HIDE static const uint8 LUT8to6[256];

 INLINE void DecodeColor(uint32 value, int &r, int &g, int &b) const
 {
  int dummy_a;

  DecodeColor(value, r, g, b, dummy_a);
 }

 static INLINE void TDecodeColor(uint64 tag, uint32 c, int* r, int* g, int* b)
 {
  if(tag == IRGB16_1555)
  {
   *r = LUT5to8[(c >> 10) & 0x1F];
   *g = LUT5to8[(c >>  5) & 0x1F];
   *b = LUT5to8[(c >>  0) & 0x1F];
   //*a = 0;
  }
  else if(tag == RGB16_565)
  {
   *r = LUT5to8[(c >> 11) & 0x1F];
   *g = LUT6to8[(c >>  5) & 0x3F];
   *b = LUT5to8[(c >>  0) & 0x1F];
   //*a = 0;
  }
  else
  {
   MDFN_PixelFormat pf = tag;

   pf.DecodeColor(c, *r, *g, *b);
  }
 }

 static INLINE uint32 TMakeColor(uint64 tag, uint8 r, uint8 g, uint8 b)
 {
  if(tag == IRGB16_1555)
   return (LUT8to5[r] << 10) | (LUT8to5[g] << 5) | (LUT8to5[b] << 0);
  else if(tag == RGB16_565)
   return (LUT8to5[r] << 11) | (LUT8to6[g] << 5) | (LUT8to5[b] << 0);
  else
  {
   MDFN_PixelFormat pf = tag;

   return pf.MakeColor(r, g, b);
  }
 }

 enum : uint64
 {
  //
  // All 24 possible RGB-colorspace xxxx32_8888 formats are supported by core Mednafen and emulation modules,
  // but the ones not enumerated here will be less performant.
  //
  // In regards to emulation modules' video output, the alpha channel is for internal use,
  // and should be ignored by driver-side/frontend code.
  //
  ABGR32_8888 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 4, /**/  0,  8, 16, 24, /**/ 8, 8, 8, 8),
  ARGB32_8888 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 4, /**/ 16,  8,  0, 24, /**/ 8, 8, 8, 8),
  RGBA32_8888 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 4, /**/ 24, 16,  8,  0, /**/ 8, 8, 8, 8),
  BGRA32_8888 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 4, /**/  8, 16, 24,  0, /**/ 8, 8, 8, 8),
  //
  // These two RGB16 formats are the only 16-bit formats fully supported by core Mednafen code,
  // and most emulation modules(also see MDFNGI::ExtraVideoFormatSupport)
  //
  // Alpha shift/precision weirdness for internal emulation module use.
  //
  IRGB16_1555 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 2, /**/  10,  5,  0, 16, /**/ 5, 5, 5, 8),
   RGB16_565  = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 2, /**/  11,  5,  0, 16, /**/ 5, 6, 5, 8),
  //
  // Following formats are not supported by emulation modules, and only partially supported by core
  // Mednafen code:
  //
  ARGB16_4444 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 2, /**/   8,  4,  0, 12, /**/ 4, 4, 4, 4),

  //
  // TODO: Following two hackyish formats are only valid when used as a destination pixel format with
  // MDFN_PixelFormatConverter
  //
  // RGB8X3_888 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 3, /**/ 0, 1, 2, 0, /**/ 8, 8, 8, 0),
  // BGR8X3_888 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 3, /**/ 2, 1, 0, 0, /**/ 8, 8, 8, 0),
  //
  // TODO:
  //RGB8P_888 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 1, /**/  0,  0,  0,  8, /**/ 8, 8, 8, 0),
  //RGB8P_666 = MDFN_PixelFormat_MakeTag(MDFN_COLORSPACE_RGB, 1, /**/  0,  0,  0,  8, /**/ 6, 6, 6, 0),
 };
}; // MDFN_PixelFormat;

// 8bpp support is incomplete
class MDFN_Surface
{
 public:

 MDFN_Surface();
 MDFN_Surface(void *const p_pixels, const uint32 p_width, const uint32 p_height, const uint32 p_pitchinpix, const MDFN_PixelFormat &nf, const bool alloc_init_pixels = true);

 ~MDFN_Surface();

 uint8* pixels8;
 uint16* pixels16;
 uint32* pixels;

 private:
 INLINE void pix_(uint8*& z) const { z = pixels8; }
 INLINE void pix_(uint16*& z) const { z = pixels16; }
 INLINE void pix_(uint32*& z) const { z = pixels; }
 public:

 template<typename T>
 INLINE const T* pix(void) const
 {
  T* ret;
  pix_(ret);
  return (const T*)ret;
 }

 template<typename T>
 INLINE T* pix(void)
 {
  T* ret;
  pix_(ret);
  return ret;
 }

 MDFN_PaletteEntry *palette;

 bool pixels_is_external;

 // w, h, and pitch32 should always be > 0
 int32 w;
 int32 h;

 union
 {
  int32 pitch32; // In pixels, not in bytes.
  int32 pitchinpix;    // New name, new code should use this.
 };

 MDFN_PixelFormat format;

 void Fill(uint8 r, uint8 g, uint8 b, uint8 a);
 //void FillOutside(
 void SetFormat(const MDFN_PixelFormat &new_format, bool convert);

 // Creates a 32-bit value for the surface corresponding to the R/G/B/A color passed.
 INLINE uint32 MakeColor(uint8 r, uint8 g, uint8 b, uint8 a = 0) const
 {
  return(format.MakeColor(r, g, b, a));
 }

 // Gets the R/G/B/A values for the passed 32-bit surface pixel value
 INLINE void DecodeColor(uint32 value, int &r, int &g, int &b, int &a) const
 {
  format.DecodeColor(value, r, g, b, a);
 }

 INLINE void DecodeColor(uint32 value, int &r, int &g, int &b) const
 {
  int dummy_a;

  DecodeColor(value, r, g, b, dummy_a);
 }
 private:
 void Init(void *const p_pixels, const uint32 p_width, const uint32 p_height, const uint32 p_pitchinpix, const MDFN_PixelFormat &nf, const bool alloc_init_pixels);
};
} // End namespace Mednafen
#endif
