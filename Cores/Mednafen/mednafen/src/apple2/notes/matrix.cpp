// red, 90 degrees
// green, 235.8 degrees?
// blue, 0 degrees

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
    "Mednafen",

/*
    { 99.1, 247.5, 0.0 }, //     { 98.0, 246.5, 0.0 },

    {
     { 1.56, 0.00, 0.00 },
     { 0.00, 0.60, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
*/

    { 102.5, 237.7, 0.0 },

    {
     { 1.44, 0.00, 0.00 },
     { 0.00, 0.58, 0.00 },
     { 0.00, 0.00, 2.00 },
    }
   },

   //
   // Sanyo LA7620
   //
   {
    "LA7620",

    { 104.0, 238.0, 0.0 },

    {
     { 1.80, 0.00, 0.00 },
     { 0.00, 0.60, 0.00 },
     { 0.00, 0.00, 2.00 },
    },
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
};

void fit(void)
{
 float y[16] = { 0 };
 float i[16] = { 0 };
 float q[16] = { 0 };
 float rs[16];
 float gs[16];
 float bs[16];

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

/*
 y[16] = 0.5;
 i[16] = sin(((0 +  33.0) / 360.0) * (M_PI * 2.0));
 q[16] = sin(((0 +  33.0) / 360.0) * (M_PI * 2.0));

 printf("%f %f\n", i[16], q[16]);
 abort();
*/

 for(double red_angle = 101.4; red_angle <= 112.0; red_angle += 0.1)
/*
double red_angle = 90.0;
double green_angle = 235.8;
double blue_angle = 0;
double red_gain = 1.13983;
double green_gain = 0.70;
double blue_gain = 2.03211;
*/

#if 0
double red_angle = 99.1;
double green_angle = 247.5;
double blue_angle = 0;
double red_gain = 1.56;
double green_gain = 0.60;
double blue_gain = 2.00;
#endif

#if 0
double red_angle = 112.0;
double green_angle = 252.0;
double blue_angle = 0;
double red_gain = 1.66;
double green_gain = 0.60;
double blue_gain = 2.00;
#endif

#if 0
double red_angle = 104.0;
double green_angle = 238.0;
double blue_angle = 0;
double red_gain = 1.80;
double green_gain = 0.60;
double blue_gain = 2.00;
#endif

#if 0
double red_angle = 105.0;
double green_angle = 236.0;
double blue_angle = 0;
double red_gain = 1.56;
double green_gain = 0.66;
double blue_gain = 2.00;
#endif
 {
  for(double red_gain = 1.40/*1.10*/; red_gain <= 1.95; red_gain += 0.01)
  {
   for(double green_angle = 236.0; green_angle <= 256.0; green_angle += 0.1)
   {
    for(double green_gain = 0.4; green_gain <= 0.75; green_gain += 0.01)
    {
     double blue_angle = 0.0;
     double blue_gain = 2.0;
     bool ok = true;
     static double min_error = 999999;
     double error = 0;

     for(unsigned pat = 0x00; pat < 0x10; pat++)
     {
      float r, g, b;

      r = y[pat] + red_gain * (sin((red_angle - 33.0) * M_PI * 2 / 360.0) * i[pat] + cos((red_angle - 33.0) * M_PI * 2 / 360.0) * q[pat]);
      g = y[pat] + green_gain * (sin((green_angle - 33.0) * M_PI * 2 / 360.0) * i[pat] + cos((green_angle - 33.0) * M_PI * 2 / 360.0) * q[pat]);
      b = y[pat] + blue_gain * (sin((blue_angle - 33.0) * M_PI * 2 / 360.0) * i[pat] + cos((blue_angle - 33.0) * M_PI * 2 / 360.0) * q[pat]);

      r = std::min<float>(1.0, std::max<float>(0.0, r));
      g = std::min<float>(1.0, std::max<float>(0.0, g));
      b = std::min<float>(1.0, std::max<float>(0.0, b));

/*
      // dark blue
      //if(pat == 0x2 && ((r / g) >= 1.002)) || g >= 0.194))
      // ok = false;     

      // dark green
      if(pat == 0x4 && (g / b) < 1.55)
       ok = false;

      // light blue
      if(pat == 0x7 && fabs(1.0 - (r / g)) >= 0.0085)
       ok = false;

      // orange
      if(pat == 0x9 && ((r / g < 2.0) || (r / g >= 2.29)))
       ok = false;

      // light green
      if(pat == 0xC && (g / r < 4.13))
       ok = false;

      // yellow
      if(pat == 0xD && ((r / g) < 0.099 || (r / g) > 1.010))
       ok = false;
*/
      // red
      if(pat == 0x1 && r < 0.60)
       ok = false;


      // light blue
      if(pat == 0x7 && r > g)
       ok = false;

      // orange
      if(pat == 0x9 && r < g)
       ok = false;

      // light green
      if(pat == 0xC && (r > 0.25 || g < 0.70))
       ok = false;

      // yellow
      if(pat == 0xD && r < g)
       ok = false;

#if 0
      if(fabs(1.0 - (y[pat] / (r * 0.299 + 0.587 * g + 0.114 * b))) > 0.06)
       ok = false;
#else
      double alt_y = pow(pow(r, 2.2) * 0.2126 + pow(g, 2.2) * 0.7152 + pow(b, 2.2) * 0.0722, 1.0 / 2.2);

      if(fabs(1.0 - (y[pat] / alt_y)) > 0.24)
       ok = false;

      error += pow(y[pat] - alt_y, 2.0);
#endif
      rs[pat] = r;
      gs[pat] = g;
      bs[pat] = b; 
     }

     if(ok && error < min_error) // && (green_gain <= 0.609 && green_gain >= 0.599) && red_angle >= 99.09 && red_angle <= 99.11)
     {
      min_error = error;

      printf("%f %f, %f %f --- %f\n", red_angle, red_gain, green_angle, green_gain, sqrt(error));

      for(unsigned pat = 0; pat < 16; pat++)
       printf(" %d y=%f, i=%f, q=%f; %f\n", pat, y[pat], i[pat], q[pat], pow(pow(rs[pat], 2.2) * 0.2126 + pow(gs[pat], 2.2) * 0.7152 + pow(bs[pat], 2.2) * 0.0722, 1.0 / 2.2) / y[pat]);

      printf("\n");
     }
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
  //fit2();
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
    i += d.m[cci][kk]/*(1.0 / 0.877)*/ * sin((d.angles[kk] - 33.0) * M_PI * 2 / 360.0);
    q += d.m[cci][kk]/*(1.0 / 0.493)*/ * cos((d.angles[kk] - 33.0) * M_PI * 2 / 360.0);
   }

   printf("  { % f, % f }, // (%.1f° * % .3f) + (%.1f° * % .3f) + (%.1f° * % .3f),\n", i, q, d.angles[0], d.m[cci][0], d.angles[1], d.m[cci][1], d.angles[2], d.m[cci][2]);
  }
  printf(" },\n\n");
 }
}
