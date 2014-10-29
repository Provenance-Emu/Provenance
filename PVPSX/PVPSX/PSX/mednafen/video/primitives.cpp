#include "video-common.h"

template<typename T, bool fill>
static void SuperDrawRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color, uint32 fill_color)
{
 T *pixels = (T*)surface->pixels + (y * surface->pitchinpix) + x;

 if(w < 1 || h < 1)
  return;

 // Replace these width and height checks with assert()s in the future.
 if(((uint64)x + w) > (uint32)surface->w)
 {
  fprintf(stderr, "Rect xw bug!\n");
  return;
 }

 if(((uint64)y + h) > (uint32)surface->h)
 {
  fprintf(stderr, "Rect yh bug!\n");
  return;
 }

 for(uint32 ix = 0; ix < w; ix++)
 {
  pixels[ix] = border_color;
  pixels[ix + (h - 1) * surface->pitchinpix] = border_color;
 }

 pixels += surface->pitchinpix;

 for(uint32 iy = 1; iy < (h - 1); iy++)
 {
  pixels[0] = border_color;
  pixels[w - 1] = border_color;

  if(fill)
   for(uint32 ix = 1; ix < (w - 1); ix++)
    pixels[ix] = fill_color;

  pixels += surface->pitchinpix;
 }
}


void MDFN_DrawRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color)
{
 SuperDrawRect<uint32, false>(surface, x, y, w, h, border_color, 0);
}

void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 border_color, uint32 fill_color)
{
 SuperDrawRect<uint32, true>(surface, x, y, w, h, border_color, fill_color);
}

void MDFN_DrawFillRect(MDFN_Surface *surface, uint32 x, uint32 y, uint32 w, uint32 h, uint32 fill_color)
{
 SuperDrawRect<uint32, true>(surface, x, y, w, h, fill_color, fill_color);
}
#if 0
void MDFN_DrawLine_P(MDFN_Surface *surface, int x0, int y0, int x1, int y1, uint32 color)
{
 const bool contig = false;
 const int dx = x1 - x0;
 const int dy = y1 - y0;
 const unsigned int abs_dx = abs(dx);
 const unsigned int abs_dy = abs(dy);
 const uint32 pitchinpix = surface->pitchinpix;
 uint32 *pixels = surface->pixels;
 const unsigned int s_w = surface->w;
 const unsigned int s_h = surface->h;

 if(abs_dy > abs_dx)
 {
  unsigned int accum = abs_dy;
  unsigned int accum_step = abs_dx << 1;
  unsigned int accum_comp = abs_dy << 1;
  const int xinc = (dx >> 31) | 1;
  int x = x0;

  if(dy > 0)
  {
   for(int y = y0; y <= y1; y++)
   {
    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
    if(accum >= accum_comp)
    {
     x += xinc;
     accum -= accum_comp;

     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }
    }
   }
  }
  else
  {
   for(int y = y0; y >= y1; y--)
   {
    if(accum > accum_comp)
    {
     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }

     x += xinc;
     accum -= accum_comp;
    }

    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
   }
  }
 }
 else
 {
  unsigned int accum = abs_dx;
  unsigned int accum_step = abs_dy << 1;
  unsigned int accum_comp = abs_dx << 1;
  const int yinc = (dy >> 31) | 1;
  int y = y0;

  if(dx > 0)
  {
   for(int x = x0; x <= x1; x++)
   {
    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
    if(accum >= accum_comp)
    {
     y += yinc;
     accum -= accum_comp;

     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }
    }
   }
  }
  else
  {
   for(int x = x0; x >= x1; x--)
   {
    if(accum > accum_comp)
    {
     if(contig)
     {
      if((unsigned)x < s_w && (unsigned)y < s_h)
       pixels[x + (y * pitchinpix)] = color;
     }

     y += yinc;
     accum -= accum_comp;
    }

    if((unsigned)x < s_w && (unsigned)y < s_h)
     pixels[x + (y * pitchinpix)] = color;

    accum += accum_step;
   }
  }
 }
}
#endif

// Will fail GLORIOUSLY if trying to draw a line where the distance between x coordinates, or between y coordinates, is >= 2**31
// but you'd have to be 2**32 types of crazy to want to draw a line that long anyway.
void MDFN_DrawLine(MDFN_Surface *surface, int x0, int y0, int x1, int y1, uint32 color)
{
 const int dx = x1 - x0;
 const int dy = y1 - y0;
 const unsigned int abs_dx = abs(dx);
 const unsigned int abs_dy = abs(dy);
 const uint32 pitchinpix = surface->pitchinpix;
 uint32 *pixels = surface->pixels;
 const unsigned int s_w = surface->w;
 const unsigned int s_h = surface->h;

 int64 x = ((int64)x0 << 32) + ((int64)1 << 31);
 int64 y = ((int64)y0 << 32) + ((int64)1 << 31);
 int64 x_inc;
 int64 y_inc;
 uint32 k;

 if((abs_dx | abs_dy) == 0)
 {
  k = 0;
  x_inc = 0;
  y_inc = 0;
 }
 else
 {
  if(abs_dx > abs_dy)
  {
   k = abs_dx;
   x_inc = ((int64)dx >> 63) | ((int64)1 << 32);
   //y_inc = (((int64)dy << 32) - ((dy < 0) ? (k - 1) : 0)) / k;
   y_inc = (((int64)dy << 32) + ((dy < 0) ? 0 : (k - 1))) / k;
  }
  else
  {
   k = abs_dy;
   //x_inc = (((int64)dx << 32) - ((dx < 0) ? (k - 1) : 0)) / k;
   x_inc = (((int64)dx << 32) + ((dx < 0) ? 0 : (k - 1))) / k;
   y_inc = (int64)((dy >> 31) | 1) << 32;
  }
 }

 for(uint32 i = 0; i <= k; i++)
 {
  int xc = x >> 32;
  int yc = y >> 32;

  pixels[xc + (yc * pitchinpix)] = color;

  x += x_inc;
  y += y_inc;
 }
}



