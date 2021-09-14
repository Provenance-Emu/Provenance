/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* surface.h:
**  Copyright (C) 2009-2020 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_SURFACE_H
#define __MDFN_SURFACE_H

namespace Mednafen
{

struct MDFN_Rect
{
 int32 x, y, w, h;
};

enum
{
 MDFN_COLORSPACE_RGB = 0,
 //MDFN_COLORSPACE_LRGB = 1,	// Linear RGB, 16-bit per component, TODO in the future?
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
 uint8 opp;	// Bytes per pixel; 1, 2, 4 (1 is WIP)

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
  int32 pitchinpix;	// New name, new code should use this.
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

}
#endif
