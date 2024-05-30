//============================================================================
//
//   SSSS    tt          lll  lll
//  SS  SS   tt           ll   ll
//  SS     tttttt  eeee   ll   ll   aaaa
//   SSSS    tt   ee  ee  ll   ll      aa
//      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
//  SS  SS   tt   ee      ll   ll  aa  aa
//   SSSS     ttt  eeeee llll llll  aaaaa
//
// Copyright (c) 1995-2024 by Bradford W. Mott, Stephen Anthony
// and the Stella Team
//
// See the file "License.txt" for information on usage and redistribution of
// this file, and for a DISCLAIMER OF ALL WARRANTIES.
//
//   Based on code from ScummVM - Scumm Interpreter
//   Copyright (C) 2002-2004 The ScummVM project
//============================================================================

#ifndef FONT_HXX
#define FONT_HXX

#include "bspf.hxx"

struct BBX
{
  Int8 w;
  Int8 h;
  Int8 x;
  Int8 y;
};

/* builtin C-based proportional/fixed font structure */
/* based on The Microwindows Project http://microwindows.org */
struct FontDesc
{
  string_view   name;                   /* font name */
  int           maxwidth;               /* max width in pixels */
  int           height;                 /* height in pixels */
  int           fbbw, fbbh, fbbx, fbby;	/* max bounding box */
  int           ascent;                 /* ascent (baseline) height */
  int           firstchar;              /* first character in bitmap */
  int           size;                   /* font size in glyphs */
  const uInt16* bits;                   /* 16-bit right-padded bitmap data */
  const uInt32* offset;                 /* offsets into bitmap data*/
  const uInt8*  width;                  /* character widths or nullptr if fixed */
  const BBX*    bbx;                    /* character bounding box or nullptr if fixed */
  int           defaultchar;            /* default char (not glyph index) */
  long          bits_size;              /* # words of bitmap_t bits */
};

namespace GUI {

class Font
{
  public:
    explicit Font(const FontDesc& desc);

    const FontDesc& desc() const { return myFontDesc; }

    int getFontHeight() const { return myFontDesc.height; }
    int getLineHeight() const { return myFontDesc.height + 2; }
    int getMaxCharWidth() const { return myFontDesc.maxwidth; }

    int getCharWidth(uInt8 chr) const;

    int getStringWidth(string_view str) const;

  private:
    FontDesc myFontDesc;

  private:
    // Following constructors and assignment operators not supported
    Font() = delete;
    Font(const Font&) = delete;
    Font(Font&&) = delete;
    Font& operator=(const Font&) = delete;
    Font& operator=(Font&&) = delete;
};

} // namespace GUI

#endif
