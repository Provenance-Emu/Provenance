#include "share.h"

#include <math.h>

static const uint8 GunSight[]=
{
        0,0,0,0,0,0,1,0,0,0,0,0,0,
        0,0,0,0,0,0,2,0,0,0,0,0,0,
        0,0,0,0,0,0,1,0,0,0,0,0,0,
        0,0,0,0,0,0,2,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,3,0,0,0,0,0,0,
        1,2,1,2,0,3,3,3,0,2,1,2,1,
        0,0,0,0,0,0,3,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,2,0,0,0,0,0,0,
        0,0,0,0,0,0,1,0,0,0,0,0,0,
        0,0,0,0,0,0,2,0,0,0,0,0,0,
        0,0,0,0,0,0,1,0,0,0,0,0,0,
};

static const uint8 MDFNcursor[11*19]=
{
 1,0,0,0,0,0,0,0,0,0,0,
 1,1,0,0,0,0,0,0,0,0,0,
 1,2,1,0,0,0,0,0,0,0,0,
 1,2,2,1,0,0,0,0,0,0,0,
 1,2,2,2,1,0,0,0,0,0,0,
 1,2,2,2,2,1,0,0,0,0,0,
 1,2,2,2,2,2,1,0,0,0,0,
 1,2,2,2,2,2,2,1,0,0,0,
 1,2,2,2,2,2,2,2,1,0,0,
 1,2,2,2,2,2,2,2,2,1,0,
 1,2,2,2,2,2,1,1,1,1,1,
 1,2,2,1,2,2,1,0,0,0,0,
 1,2,1,0,1,2,2,1,0,0,0,
 1,1,0,0,1,2,2,1,0,0,0,
 1,0,0,0,0,1,2,2,1,0,0,
 0,0,0,0,0,1,2,2,1,0,0,
 0,0,0,0,0,0,1,2,2,1,0,
 0,0,0,0,0,0,1,2,2,1,0,
 0,0,0,0,0,0,0,1,1,0,0,
};

static uint8 invert_tab[0x40];
static uint8 pe_white;
static uint8 pe_black;
static uint8 pe_bright_cake;

static uint8 FindClose(uint8 r, uint8 g, uint8 b) MDFN_COLD;
static uint8 FindClose(uint8 r, uint8 g, uint8 b)
{
 double rl, gl, bl;
 int closest = -1;
 double closest_cs = 1000;

 rl = pow((double)r / 255, 2.2 / 1.0);
 gl = pow((double)g / 255, 2.2 / 1.0);
 bl = pow((double)b / 255, 2.2 / 1.0);

 for(unsigned x = 0; x < 0x40; x++)
 {
  double rcl, gcl, bcl;
  double cs;

  rcl = pow((double)ActiveNESPalette[x].r / 255, 2.2 / 1.0);
  gcl = pow((double)ActiveNESPalette[x].g / 255, 2.2 / 1.0);
  bcl = pow((double)ActiveNESPalette[x].b / 255, 2.2 / 1.0);

  cs = fabs(rcl - rl) * 0.2126 + fabs(gcl - gl) * 0.7152 + fabs(bcl - bl) * 0.0722;
  if(cs < closest_cs)
  {
   closest_cs = cs;
   closest = x;
  }
 }

 return(closest);
}

void NESCURSOR_PaletteChanged(void)
{
 pe_white = FindClose(0xFF, 0xFF, 0xFF);
 pe_black = FindClose(0x00, 0x00, 0x00);
 pe_bright_cake = FindClose(0xFF, 0xC0, 0xFF);

 //uint32 st = MDFND_GetTime();
 for(int i = 0; i < 0x40; i++)
 {
  invert_tab[i] = FindClose(ActiveNESPalette[i].r ^ 0x80, ActiveNESPalette[i].g ^ 0x80, ActiveNESPalette[i].b ^ 0x80);
 }
 //printf("%u\n", MDFND_GetTime() - st);
}

void NESCURSOR_DrawGunSight(int w, uint8* pix, int pix_y, int xc, int yc)
{
 const uint8 ctransform[2][2] = { { pe_black, pe_bright_cake }, { pe_white, pe_black } };
 int y = pix_y - yc + 7;

 if(y >= 0 && y < 13)
 {
  for(int x = 0; x < 13; x++)
  {
   uint8 a = GunSight[y*13+x];

   if(a)
   {
    int d = xc + (x - 7);
    if(d >= 0 && d < 256)
    {
     if(a==3)
      pix[d] = invert_tab[pix[d] & 0x3F];
     else
      pix[d] = ctransform[w][(a - 1) & 1];
    }
   }
  }
 }
}


void NESCURSOR_DrawCursor(uint8* pix, int pix_y, int xc, int yc)
{
 const uint32 ctransform[4] = { pe_black, pe_black, pe_white, pe_black };
 int y = pix_y - yc;

 if(y >= 0 && y < 19)
 {
  for(int x = 0; x < 11; x++)
  {
   uint8 a = MDFNcursor[y*11 + x];
   if(a)
   {
    int d = x + xc;

    if(d >= 0 && d < 256)
     pix[d] = ctransform[a & 0x3];
   }
  }
 }
}
