// g++ -Wall -std=gnu++11 -O2 -o matrix matrix.cpp
#include <math.h>
#include <stdio.h>
#include <algorithm>

static const struct DecoderParams
{
 const char* name;
 float angles[3];
 float m[3][3];
} decoders[] =
{
   //
   //
   //
   {
    "Standard",

    { 123.0, 33.0, 0.0 },

    {
     {  0.96,  0.62, 0.000 },
     { -0.28, -0.64, 0.000 },
     { -1.11,  1.70, 0.000 },
    }
   },

   //
   //
   //
   {
    "Mednafen",
    { 109.3, 236.0, 0.0 },

    {
     { 1.20, 0.00, 0.00 },
     { 0.00, 0.65, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },



   //
   // CXA1213 NTSC
   //
   {
    "CXA1213",

    { 99.0, 240.0, 11.0 },
    {
     { 1.54, 0.00, 0.00 },
     { 0.00, 0.60, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // CXA2025 Japan
   //

   {
    "CXA2025 Japan",

    { 95.0, 240.0, 0.0 },

    {
     { 1.56, 0.00, 0.00 },
     { 0.00, 0.60, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // CXA2025 USA
   //
   {
    "CXA2025 USA",
    { 112.0, 252.0, 0.0 },

    {
     { 1.66, 0.00, 0.00 },
     { 0.00, 0.60, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // CXA2060 Japan
   //
   {
    "CXA2060 Japan",
    { 95.0, 236.0, 0.0 },

    {
     { 1.56, 0.00, 0.00 },
     { 0.00, 0.66, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // CXA2060 USA
   //
   {
    "CXA2060 USA",
    { 102.0, 236.0, 0.0 },

    {
     { 1.56, 0.00, 0.00 },
     { 0.00, 0.60, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // CXA2095 Japan
   //
   {
    "CXA2095 Japan",
    { 95.0, 236.0, 0.0 },

    {
     { 1.20, 0.00, 0.00 },
     { 0.00, 0.66, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // CXA2095 USA
   //
   {
    "CXA2095 USA",

    { 105.0, 236.0, 0.0 },

    {
     { 1.56, 0.00, 0.00 },
     { 0.00, 0.66, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // uA788
   //
   {
    "uA788",

    { 109.0, 259.0, 3.0 },

    {
     { 1.52, 0.00, 0.00 },
     { 0.00, 0.40, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

/*
   //
   //
   //
   {
    "magnavox atc test",

    { 105.0, 345.0, 0.0 },

    {
     {  1.0 / 0.877, 0, 0 },
     { -0.51 / 0.877, -0.19 / 0.493, 0 },
     { 0, 1.0 / 0.493 },
    }
   },
*/
};

void fit(void)
{
 float y[16] = { 0 };
 float i[16] = { 0 };
 float q[16] = { 0 };

 for(unsigned pat = 0x00; pat < 0x10; pat++)
 {
  for(int x = 0; x < 4; x++)
  {
   bool C = (pat >> x) & 1;

   y[pat] += C;
   i[pat] += sin(((x / 4.0) + 123.0 / 360.0) * (M_PI * 2.0)) * C;
   q[pat] += sin(((x / 4.0) +  33.0 / 360.0) * (M_PI * 2.0)) * C;
   //printf("%d, %d, %f\n", cd_i, x, demod_tab[cd_i][x]);
  }
  y[pat] /= 4.0;
  i[pat] /= 4.0;
  q[pat] /= 4.0;
 }

 for(double red_angle = 90.0; red_angle <= 112.0; red_angle += 0.1)
 {
  for(double red_gain = 1.10; red_gain <= 1.66; red_gain += 0.01)
  {
   for(double green_angle = 236.0; green_angle <= 252.0; green_angle += 0.1)
   {
    for(double green_gain = 0.4; green_gain <= 0.66; green_gain += 0.01)
    {
     float blue_angle = 0.0;
     float blue_gain = 2.0;
     bool ok = true;
   float gorp = 0;

     for(unsigned pat = 0x00; pat < 0x10; pat++)
     {
      float r, g, b;

      r = y[pat] + red_gain * (sin((red_angle - 33.0) * M_PI * 2 / 360.0) * i[pat] + cos((red_angle - 33.0) * M_PI * 2 / 360.0) * q[pat]);
      g = y[pat] + green_gain * (sin((green_angle - 33.0) * M_PI * 2 / 360.0) * i[pat] + cos((green_angle - 33.0) * M_PI * 2 / 360.0) * q[pat]);
      b = y[pat] + blue_gain * (sin((blue_angle - 33.0) * M_PI * 2 / 360.0) * i[pat] + cos((blue_angle - 33.0) * M_PI * 2 / 360.0) * q[pat]);

      r = std::min<float>(1.0, std::max<float>(0.0, r));
      g = std::min<float>(1.0, std::max<float>(0.0, g));
      b = std::min<float>(1.0, std::max<float>(0.0, b));

      if(pat == 0xD && ((r / g) >= 1.010 || (r / g) <= 0.095)) //fabs(1.0 - (r / g)) >= 0.005)
       ok = false;

      if(pat == 0x7 && (r / g) >= 1.005) //&& fabs(1.0 - (r / g)) >= 0.005)
       ok = false;

      //if(pat == 0x8 && r >= g)
      // ok = false;

      if(pat == 0x9 && (g > r))
       ok = false;
      //if(pat == 0x9 && fabs(2.0 - (r / g)) >= 0.010)
      // ok = false;

      //if(pat == 0xC && ((g / r) < 3.25 || (g / r) >= 4.0))
      // ok = false;

      if(pat == 0xC)
      {
       gorp = g;
       if(g < 0.725)
        ok = false;
      }
     }

     if(ok)
      printf("%f %f %f, %f %f\n", gorp, red_angle, red_gain, green_angle, green_gain);
    }
   }
  }
 }
}


int main(int argc, char* argv[])
{
 if(argc > 1)
 {
  fit();
  return 0;
 };

 for(auto const& d : decoders)
 {
  printf(" //\n");
  printf(" // %s\n", d.name);
  printf(" //\n");
  printf(" {\n");
  for(unsigned cci = 0; cci < 3; cci++)
  {
   float i = 0, q = 0;

   for(unsigned kk = 0; kk < 3; kk++)
   {
    i += d.m[cci][kk]/*(1.0 / 0.877)*/ * sin((d.angles[kk] /*- 33.0*/) * M_PI * 2 / 360.0);
    q += d.m[cci][kk]/*(1.0 / 0.493)*/ * cos((d.angles[kk] /*- 33.0*/) * M_PI * 2 / 360.0);
   }

   printf("  { % f, % f }, // (%.1f° * % .3f) + (%.1f° * % .3f) + (%.1f° * % .3f),\n", i, q, d.angles[0], d.m[cci][0], d.angles[1], d.m[cci][1], d.angles[2], d.m[cci][2]);
  }
  printf(" },\n\n");
 }
}
