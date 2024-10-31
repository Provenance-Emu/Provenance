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
//============================================================================

#include <cmath>

#include "Rect.hxx"
#include "FrameBuffer.hxx"
#include "FBSurface.hxx"

#ifdef GUI_SUPPORT
  #include "Font.hxx"
#endif

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::readPixels(uInt8* buffer, uInt32 pitch, const Common::Rect& rect) const
{
  auto* src = reinterpret_cast<uInt8*>(myPixels +
      (rect.y() * static_cast<size_t>(myPitch)) + rect.x());

  if(rect.empty())
    std::copy_n(src, width() * height() * 4, buffer);
  else
  {
    const uInt32 w = std::min(rect.w(), width());
    uInt32 h = std::min(rect.h(), height());

    // Copy 'height' lines of width 'pitch' (in bytes for both)
    uInt8* dst = buffer;
    while(h--)
    {
      std::copy_n(src, w * 4, dst);
      src += static_cast<size_t>(myPitch) * 4;
      dst += static_cast<size_t>(pitch) * 4;
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::pixel(uInt32 x, uInt32 y, ColorId color)
{
  // Note: checkbounds() must be done in calling method
  uInt32* buffer = myPixels + (y * static_cast<size_t>(myPitch)) + x;

  *buffer = myPalette[color];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::line(uInt32 x, uInt32 y, uInt32 x2, uInt32 y2, ColorId color)
{
  if(!checkBounds(x, y) || !checkBounds(x2, y2))
    return;

  // draw line using Bresenham algorithm
  Int32 dx = (x2 - x);
  Int32 dy = (y2 - y);

  if(abs(dx) >= abs(dy))
  {
    // x is major axis
    if(dx < 0)
    {
      std::swap(x, x2);
      y = y2;
      dx = -dx;
      dy = -dy;
    }
    const Int32 yd = dy > 0 ? 1 : -1;
    dy = abs(dy);
    Int32 err = dx / 2;
    // now draw the line
    for(; x <= x2; ++x)
    {
      pixel(x, y, color);
      err -= dy;
      if(err < 0)
      {
        err += dx;
        y += yd;
      }
    }
  }
  else
  {
    // y is major axis
    if(dy < 0)
    {
      x = x2;
      std::swap(y, y2);
      dx = -dx;
      dy = -dy;
    }
    const Int32 xd = dx > 0 ? 1 : -1;
    dx = abs(dx);
    Int32 err = dy / 2;
    // now draw the line
    for(; y <= y2; ++y)
    {
      pixel(x, y, color);
      err -= dx;
      if(err < 0)
      {
        err += dy;
        x += xd;
      }
    }
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::hLine(uInt32 x, uInt32 y, uInt32 x2, ColorId color)
{
  if(!checkBounds(x, y) || !checkBounds(x2, 2))
    return;

  uInt32* buffer = myPixels + (y * static_cast<size_t>(myPitch)) + x;
  while(x++ <= x2)
    *buffer++ = myPalette[color];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::vLine(uInt32 x, uInt32 y, uInt32 y2, ColorId color)
{
  if(!checkBounds(x, y) || !checkBounds(x, y2))
    return;

  uInt32* buffer = myPixels + (y * static_cast<size_t>(myPitch)) + x;
  while(y++ <= y2)
  {
    *buffer = myPalette[color];
    buffer += myPitch;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::fillRect(uInt32 x, uInt32 y, uInt32 w, uInt32 h, ColorId color)
{
  while(h--)
    hLine(x, y+h, x+w-1, color);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::drawChar(const GUI::Font& font, uInt8 chr,
                         uInt32 tx, uInt32 ty, ColorId color, ColorId shadowColor)
{
#ifdef GUI_SUPPORT
  if(shadowColor != kNone)
  {
    drawChar(font, chr, tx + 1, ty + 0, shadowColor);
    drawChar(font, chr, tx + 0, ty + 1, shadowColor);
    drawChar(font, chr, tx + 1, ty + 1, shadowColor);
  }

  const FontDesc& desc = font.desc();

  // If this character is not included in the font, use the default char.
  if(chr < desc.firstchar || chr >= desc.firstchar + desc.size)
  {
    if (chr == ' ') return;
    chr = desc.defaultchar;
  }
  chr -= desc.firstchar;

  // Get the bounding box of the character
  int bbw = 0, bbh = 0, bbx = 0, bby = 0;
  if(!desc.bbx)
  {
    bbw = desc.fbbw;
    bbh = desc.fbbh;
    bbx = desc.fbbx;
    bby = desc.fbby;
  }
  else
  {
    bbw = desc.bbx[chr].w;  // NOLINT
    bbh = desc.bbx[chr].h;  // NOLINT
    bbx = desc.bbx[chr].x;  // NOLINT
    bby = desc.bbx[chr].y;  // NOLINT
  }

  const uInt32 cx = tx + bbx;
  const uInt32 cy = ty + desc.ascent - bby - bbh;

  if(!checkBounds(cx , cy) || !checkBounds(cx + bbw - 1, cy + bbh - 1))
    return;

  const uInt16* tmp = desc.bits + (desc.offset ? desc.offset[chr] : (chr * desc.fbbh));
  uInt32* buffer = myPixels + (cy * static_cast<size_t>(myPitch)) + cx;

  for(int y = 0; y < bbh; y++)
  {
    const uInt16 ptr = *tmp++;
    uInt16 mask = 0x8000;

    for(int x = 0; x < bbw; x++, mask >>= 1)
      if(ptr & mask)
        buffer[x] = myPalette[color];

    buffer += myPitch;
  }
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::drawBitmap(const uInt32* bitmap, uInt32 tx, uInt32 ty,
                           ColorId color, uInt32 h)
{
  drawBitmap(bitmap, tx, ty, color, h, h);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::drawBitmap(const uInt32* bitmap, uInt32 tx, uInt32 ty,
                           ColorId color, uInt32 w, uInt32 h)
{
  if(!checkBounds(tx, ty) || !checkBounds(tx + w - 1, ty + h - 1))
    return;

  uInt32* buffer = myPixels + (ty * static_cast<size_t>(myPitch)) + tx;

  for(uInt32 y = 0; y < h; ++y)
  {
    uInt32 mask = 1 << (w - 1);
    for(uInt32 x = 0; x < w; ++x, mask >>= 1)
      if(bitmap[y] & mask)
        buffer[x] = myPalette[color];

    buffer += myPitch;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::drawPixels(const uInt32* data, uInt32 tx, uInt32 ty, uInt32 numpixels)
{
  if(!checkBounds(tx, ty) || !checkBounds(tx + numpixels - 1, ty))
    return;

  uInt32* buffer = myPixels + (ty * static_cast<size_t>(myPitch)) + tx;

  for(uInt32 i = 0; i < numpixels; ++i)
    *buffer++ = data[i];
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::box(uInt32 x, uInt32 y, uInt32 w, uInt32 h,
                    ColorId colorA, ColorId colorB)
{
  hLine(x + 1, y,     x + w - 2, colorA);
  hLine(x,     y + 1, x + w - 1, colorA);
  vLine(x,     y + 1, y + h - 2, colorA);
  vLine(x + 1, y,     y + h - 1, colorA);

  hLine(x + 1,     y + h - 2, x + w - 1, colorB);
  hLine(x + 1,     y + h - 1, x + w - 2, colorB);
  vLine(x + w - 1, y + 1,     y + h - 2, colorB);
  vLine(x + w - 2, y + 1,     y + h - 1, colorB);
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::frameRect(uInt32 x, uInt32 y, uInt32 w, uInt32 h,
                          ColorId color, FrameStyle style)
{
  switch(style)
  {
    case FrameStyle::Solid:
      hLine(x,         y,         x + w - 1, color);
      hLine(x,         y + h - 1, x + w - 1, color);
      vLine(x,         y,         y + h - 1, color);
      vLine(x + w - 1, y,         y + h - 1, color);
      break;

    case FrameStyle::Dashed:
      for(uInt32 i = x; i < x + w; i += 2)
      {
        hLine(i, y, i, color);
        hLine(i, y + h - 1, i, color);
      }
      for(uInt32 i = y; i < y + h; i += 2)
      {
        vLine(x, i, i, color);
        vLine(x + w - 1, i, i, color);
      }
      break;
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void FBSurface::splitString(const GUI::Font& font, string_view s, int w,
                            string& left, string& right)
{
#ifdef GUI_SUPPORT
  uInt32 pos = 0;
  int w2 = 0;
  bool split = false;

  // SLOW algorithm to find the acceptable length. But it is good enough for now.
  for(pos = 0; pos < s.size(); ++pos)
  {
    const int charWidth = font.getCharWidth(s[pos]);
    if(w2 + charWidth > w || s[pos] == '\n')
    {
      split = true;
      break;
    }
    w2 += charWidth;
  }

  if(split)
    for(int i = pos; i > 0; --i)
    {
      if(isWhiteSpace(s[i]))
      {
        left = s.substr(0, i);
        if(s[i] == ' ' || s[pos] == '\n') // skip leading space after line break
          i++;
        right = s.substr(i);
        return;
      }
    }
  left = s.substr(0, pos);
  right = s.substr(pos);
#endif
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int FBSurface::drawString(const GUI::Font& font, string_view s,
                          int x, int y, int w, int h,
                          ColorId color, TextAlign align,
                          int deltax, bool useEllipsis, ColorId shadowColor,
                          size_t linkStart, size_t linkLen, bool underline)
{
  int lines = 0;

#ifdef GUI_SUPPORT
  string inStr{s};

  // draw multiline string
  while(!inStr.empty() && h >= font.getFontHeight() * 2)
  {
    // String is too wide.
    string leftStr, rightStr;

    splitString(font, inStr, w, leftStr, rightStr);
    drawString(font, leftStr, x, y, w, color, align, deltax, false, shadowColor,
               linkStart, linkLen, underline);
    if(linkStart != string::npos)
      linkStart = std::max(0, static_cast<int>(linkStart - leftStr.length()));

    h -= font.getFontHeight();
    y += font.getFontHeight();
    inStr = rightStr;
    lines++;
  }
  if(!inStr.empty())
  {
    drawString(font, inStr, x, y, w, color, align, deltax, useEllipsis, shadowColor,
               linkStart, linkLen, underline);
    lines++;
  }
#endif
  return lines;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
int FBSurface::drawString(const GUI::Font& font, string_view s,
                          int x, int y, int w,
                          ColorId color, TextAlign align,
                          int deltax, bool useEllipsis, ColorId shadowColor,
                          size_t linkStart, size_t linkLen, bool underline)
{
#ifdef GUI_SUPPORT
  const string ELLIPSIS = "\x1d"; // "..."
  const int leftX = x, rightX = x + w;
  int width = font.getStringWidth(s);
  string str;

  if(useEllipsis && width > w)
  {
    // String is too wide. So we shorten it "intelligently", by replacing
    // parts of it by an ellipsis ("..."). There are three possibilities
    // for this: replace the start, the end, or the middle of the string.
    // What is best really depends on the context; but most applications
    // replace the end. So we use that too.
    int w2 = font.getStringWidth(ELLIPSIS);

    // SLOW algorithm to find the acceptable length. But it is good enough for now.
    for(auto c: s)
    {
      const int charWidth = font.getCharWidth(c);
      if(w2 + charWidth > w)
        break;

      w2 += charWidth;
      str += c;
    }
    str += ELLIPSIS;

    width = font.getStringWidth(str);
  }
  else
    str = s;

  if(align == TextAlign::Center)
    x = x + (w - width - 1)/2;
  else if(align == TextAlign::Right)
    x = x + w - width;

  x += deltax;

  int x0 = x, x1 = 0;

  for(size_t i = 0; i < str.size(); ++i)
  {
    w = font.getCharWidth(str[i]);
    if(x + w > rightX)
      break;
    if(x >= leftX)
    {
      if(i == linkStart)
        x0 = x;
      else if(i < linkStart + linkLen)
        x1 = x + w;

      drawChar(font, str[i], x, y,
               (i >= linkStart && i < linkStart + linkLen) ? kTextColorLink : color,
               shadowColor);
    }
    x += w;
  }
  if(underline && x1 > 0)
    hLine(x0, y + font.getFontHeight() - 1, x1, kTextColorLink);

#endif
  return x;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
bool FBSurface::checkBounds(const uInt32 x, const uInt32 y) const
{
  if (x <= width() && y <= height())
    return true;

  cerr << "FBSurface::checkBounds() failed: "
       << x << ", " << y << " vs " << width() << ", " << height() << '\n';
  return false;
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
FullPaletteArray FBSurface::myPalette = { 0 };
