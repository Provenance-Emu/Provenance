/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <mednafen/mednafen.h>
#include <mednafen/sound/OwlResampler.h>
#include <mednafen/video/primitives.h>
#include <mednafen/video/text.h>
#include <mednafen/Time.h>
#include <trio/trio.h>

namespace MDFN_IEN_DEMO
{

static uint8* controller_ptr[2] = { NULL, NULL };
static uint8 last_cstate[2];

static OwlResampler* HRRes = NULL;
static OwlBuffer* HRBufs[2] = { NULL, NULL };

static const int DEMO_MASTER_CLOCK = 9000000;
static const int DEMO_FRAME_RATE = 80;
static bool Interlace;
static bool InterlaceField;
static int middle_size;
static int middle_size_inc;
static unsigned w2_select;

static unsigned cur_test_mode;

static double phase;
static double phase_inc;

static void Power(void)
{
 for(unsigned i = 0; i < 2; i++)
  last_cstate[i] = 0;

 Interlace = false;
 InterlaceField = 0;

 middle_size = 24;
 middle_size_inc = 1;

 w2_select = 0;

 cur_test_mode = 0;

 phase = 0;
 phase_inc = 0;
}

static void SetSoundRate(double rate)
{
 if(HRRes)
 {
  delete HRRes;
  HRRes = NULL;
 }

 if(rate > 0)
 {
  HRRes = new OwlResampler(DEMO_MASTER_CLOCK / 8, rate, MDFN_GetSettingF("demo.resamp_rate_error"), 20, MDFN_GetSettingF("demo.resamp_quality"));

  for(unsigned ch = 0; ch < 2; ch++)
   HRRes->ResetBufResampState(HRBufs[ch]);
 }
}

static inline uint32_t DemoRandU32(void)
{
 static uint32_t x = 123456789;
 static uint32_t y = 987654321;
 static uint32_t z = 43219876;
 static uint32_t c = 6543217;
 uint64_t t;

 x = 314527869 * x + 1234567;
 y ^= y << 5; y ^= y >> 7; y ^= y << 22;
 t = 4294584393ULL * z + c; c = t >> 32; z = t;

 return(x + y + z);
}

static void Draw(EmulateSpecStruct* espec, const uint8* weak, const uint8* strong, const uint16 (*axis)[2])
{
 espec->DisplayRect.x = DemoRandU32() & 31;
 espec->DisplayRect.y = DemoRandU32() & 31;

 espec->DisplayRect.w = 400;
 espec->DisplayRect.h = 300 << Interlace;
 
 if(Interlace)
  espec->skip = false;

 if(!espec->skip)
 {
  if(cur_test_mode == 5)
   espec->surface->Fill(0xFF, 0xFF, 0xFF, 0);
  else if(cur_test_mode == 2 || cur_test_mode == 3 || cur_test_mode == 4)
   espec->surface->Fill(0, 0, 0, 0);
  else
   espec->surface->Fill(DemoRandU32() & 0xFF, DemoRandU32() & 0xFF, DemoRandU32() & 0xFF, 0);

  if(cur_test_mode == 5)
  {
   espec->DisplayRect.x = 0;
   espec->DisplayRect.y = 0;
   espec->DisplayRect.h = 300 << Interlace;
   espec->DisplayRect.w = 0;

   espec->LineWidths[0] = 0;

   static const int wtab[4] = { 330, 352, 660, 704 };

   for(int y = espec->DisplayRect.y; y < (espec->DisplayRect.y + espec->DisplayRect.h); y++)
    espec->LineWidths[y] = wtab[DemoRandU32() & 0x3];
  }
  else if(cur_test_mode == 4)
  {
   espec->DisplayRect.x = 0;
   espec->DisplayRect.y = 0;
   espec->DisplayRect.h = 240 << Interlace;
   espec->DisplayRect.w = 1;

   for(int y = 0; y < 240; y++)
   {
    uint32 color;

    if(y >= 120)
    {
     uint8 r = 0, g = 0, b = 0;

     if(y & 1) 
      r = 0xFF;
     else
      b = 0xFF;

     color = espec->surface->MakeColor(r, g, b);
    }
    else
    {
     color = espec->surface->MakeColor(0, 0, 0);
     if(y & 1) 
      color = espec->surface->MakeColor(0xFF, 0xFF, 0xFF);
    }

    MDFN_DrawLine(espec->surface, 0, (y << Interlace) + 0, 0, (y << Interlace) + Interlace, color);
   }
  }
  else if(cur_test_mode == 2 || cur_test_mode == 3)
  {
   espec->DisplayRect.x = 0;
   espec->DisplayRect.y = 0;
   espec->DisplayRect.h = 240 << Interlace;
   espec->DisplayRect.w = 640 >> (cur_test_mode == 3);

   for(int i = 0; i < 34; i++)
   {
    const unsigned cs = i / 7;
    uint32 bcol = espec->surface->MakeColor(0, 0, 0xFF * (cs == 4));
    uint32 color = espec->surface->MakeColor(0xFF, 0xFF, 0xFF);

    if(cs)
     color = espec->surface->MakeColor(0xFF * (cs == 1 || cs == 4), 0xFF * (cs == 2), 0xFF * (cs == 3));

    for(unsigned x = 0; x < (640 >> (cur_test_mode == 3)); x++)
    {
     MDFN_DrawLine(espec->surface, x, (i * 7) << Interlace, x, (i * 7 + 7) << Interlace, (x % ((i % 7) + (cs == 4) + 1)) ? bcol : color);
    }
   }
  }
  else if(cur_test_mode == 1)
  {
   char width_text[16];

   espec->DisplayRect.w = 800 / (1 + ((w2_select >> 8) & 31));
   trio_snprintf(width_text, sizeof(width_text), "%d", espec->DisplayRect.w);

   MDFN_DrawFillRect(espec->surface, espec->DisplayRect.x, espec->DisplayRect.y, espec->DisplayRect.w, espec->DisplayRect.h, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x7F, 0x00, 0xFF));

   for(int z = 0; z < std::min<int32>(espec->DisplayRect.w, espec->DisplayRect.h) / 2; z += 7)
    MDFN_DrawFillRect(espec->surface, espec->DisplayRect.x + z, espec->DisplayRect.y + z, espec->DisplayRect.w - z * 2, espec->DisplayRect.h - z * 2, espec->surface->MakeColor(0, (z * 8) & 0xFF, 0), espec->surface->MakeColor(0, 0, (z * 17) & 0xFF));

   DrawTextShadow(espec->surface, espec->DisplayRect.x, espec->DisplayRect.y + espec->DisplayRect.h / 2 - 9, width_text, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_9x18_18x18, espec->DisplayRect.w);
  }
  else
  {
   int y0 = espec->DisplayRect.y;
   int y1 = espec->DisplayRect.y + (espec->DisplayRect.h - middle_size) / 3;
   int y2 = espec->DisplayRect.y + (espec->DisplayRect.h - middle_size) / 3 + middle_size;
   int y3 = espec->DisplayRect.y + espec->DisplayRect.h;
   static const int w2_tab[16] = { 200, 160, 100, 80, 50, 40, 32, 25,
				   20,  16,  10,  8,  5,  4,  2,  1 };
   int w0 = 400;
   int w1 = 800;
   int w2 = w2_tab[((w2_select >> 8) & 0xF)];
   int w2_font;
   char w2_text[16];

   w2_font = MDFN_FONT_9x18_18x18;
   if(w2 < 18)
    w2_font = MDFN_FONT_6x13_12x13;
   if(w2 < 12)
    w2_font = MDFN_FONT_5x7;


   trio_snprintf(w2_text, sizeof(w2_text), "%d", w2);

   espec->LineWidths[0] = 0;
   for(int y = espec->DisplayRect.y; y < (espec->DisplayRect.y + espec->DisplayRect.h); y++)
   {
    int w = w0;

    if(y >= y1)
     w = w1;

    if(y >= y2)
     w = w2;

    espec->LineWidths[y] = w;
   }

   assert( (y0 + (y1 - y0) / 2 - 9) >= 0);

   MDFN_Rect w0r = { espec->DisplayRect.x, y0, w0, y1 - y0 };
   MDFN_Rect w1r = { espec->DisplayRect.x, y1, w1, y2 - y1 };
   MDFN_Rect w2r = { espec->DisplayRect.x, y2, w2, y3 - y2 };

   MDFN_DrawFillRect(espec->surface, w0r.x, w0r.y, w0r.w, w0r.h, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x7F, 0x00, 0xFF));
   DrawTextShadow(espec->surface, w0r, espec->DisplayRect.x, (y0 + (y1 - y0) / 2 - 9), "400", espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_6x13_12x13, w0);
   for(int i = 0; i < 2; i++)
   {
    char weakstr[64];
    char strongstr[64];
    char xstr[64];
    char ystr[64];
    trio_snprintf(weakstr, sizeof(weakstr),     "  Weak: %3d", weak[i]);
    trio_snprintf(strongstr, sizeof(strongstr), "Strong: %3d", strong[i]);

    trio_snprintf(xstr, sizeof(xstr), "X: %5d", axis[i][0]);
    trio_snprintf(ystr, sizeof(ystr), "Y: %5d", axis[i][1]);

    DrawTextShadow(espec->surface, w0r, espec->DisplayRect.x + (i ? 342 : 3), (y0 + (y1 - y0) / 2 - 8), weakstr, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_5x7);
    DrawTextShadow(espec->surface, w0r, espec->DisplayRect.x + (i ? 342 : 3), (y0 + (y1 - y0) / 2 + 1), strongstr, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_5x7);

    DrawTextShadow(espec->surface, w0r, espec->DisplayRect.x + (i ? 260 : 85), (y0 + (y1 - y0) / 2 - 8), xstr, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_5x7);
    DrawTextShadow(espec->surface, w0r, espec->DisplayRect.x + (i ? 260 : 85), (y0 + (y1 - y0) / 2 + 1), ystr, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_5x7);
   }
   MDFN_DrawFillRect(espec->surface, w1r.x, w1r.y, w1r.w, w1r.h, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x00, 0x7F, 0xFF));
   DrawTextShadow(espec->surface, w1r, espec->DisplayRect.x, (y1 + (y2 - y1) / 2 - 9), "800", espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_9x18_18x18, w1);

   DrawTextShadow(espec->surface, w1r, espec->DisplayRect.x + 4, (y1 + (y2 - y1) / 2 - 13), Time::StrTime(Time::LocalTime()).c_str(), espec->surface->MakeColor(0xFF, 0xFF, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_6x13_12x13);
   DrawTextShadow(espec->surface, w1r, espec->DisplayRect.x + 4, (y1 + (y2 - y1) / 2 -  0), Time::StrTime(Time::UTCTime()).c_str(), espec->surface->MakeColor(0xFF, 0xFF, 0), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_6x13_12x13);

   {
    char tstr[64];
    trio_snprintf(tstr, sizeof(tstr), "%10u", Time::MonoMS());
    DrawTextShadow(espec->surface, w1r, espec->DisplayRect.x + w1 - 13 * 6 - 4, (y1 + (y2 - y1) / 2 - 13), tstr, espec->surface->MakeColor(0xFF, 0x00, 0xFF), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_6x13_12x13);
    trio_snprintf(tstr, sizeof(tstr), "%20llu", (unsigned long long)Time::MonoUS());
    DrawTextShadow(espec->surface, w1r, espec->DisplayRect.x + w1 - 20 * 6 - 4, (y1 + (y2 - y1) / 2 -  0), tstr, espec->surface->MakeColor(0xFF, 0x00, 0xFF), espec->surface->MakeColor(0, 0, 0), MDFN_FONT_6x13_12x13);
   }

   MDFN_DrawFillRect(espec->surface, w2r.x, w2r.y, w2r.w, w2r.h, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x00, 0x00, 0xFF));
   DrawTextShadow(espec->surface, w2r, espec->DisplayRect.x, (y2 + (y3 - y2) / 2 - 9), w2_text, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), w2_font, w2);
  }
 }
 middle_size += middle_size_inc;
 if(middle_size >= 240)
  middle_size_inc = -1;
 if(middle_size <= 0)
  middle_size_inc = 1;

 w2_select += 9;
}


static void Emulate(EmulateSpecStruct* espec)
{
 int hrc = DEMO_MASTER_CLOCK / DEMO_FRAME_RATE / 8;

 if(espec->SoundFormatChanged)
  SetSoundRate(espec->SoundRate);

 uint8 weak[2], strong[2];
 uint16 axis[2][2];

 for(unsigned i = 0; i < 2; i++)
 {
  {
   uint8 cur_cstate = *controller_ptr[i];

   if(cur_test_mode == 5)
   {
    if(cur_cstate & 1)
     Interlace = DemoRandU32() & 1;
   }
   else if((cur_cstate ^ last_cstate[i]) & cur_cstate & 1)
    Interlace = !Interlace;

   if((cur_cstate ^ last_cstate[i]) & cur_cstate & 2)
    cur_test_mode = (cur_test_mode + 1) % 6;

   last_cstate[i] = cur_cstate;
  }

  {
   weak[i] = MDFN_de16lsb(&controller_ptr[i][3]) >> 8;
   strong[i] = MDFN_de16lsb(&controller_ptr[i][5]) >> 8;

   MDFN_en16lsb(&controller_ptr[i][1], (weak[i] << 0) | (strong[i] << 8));
  }
  axis[i][0] = MDFN_de16lsb(&controller_ptr[i][7]);
  axis[i][1] = MDFN_de16lsb(&controller_ptr[i][9]);
  assert(MDFN_de32lsb(&controller_ptr[i][11]) == 0);
 }

 Draw(espec, weak, strong, axis);

 {
  int sc = 0;

  {
   static const double phase_inc_inc = 0.000000002;

   for(int r = 0; r < hrc; r++)
   {
    (&HRBufs[0]->BufPudding()->f)[r] = 256 * 32767 * 0.20 * sin(phase);
    (&HRBufs[1]->BufPudding()->f)[r] = ((int32)DemoRandU32() >> 8);

    phase += phase_inc;
    phase_inc += phase_inc_inc;
   }
  }


  for(int ch = 0; ch < 2; ch++)
  {
   if(HRRes)
   {
    sc = HRRes->Resample(HRBufs[ch], hrc, espec->SoundBuf + (espec->SoundBufSize * 2) + ch, espec->SoundBufMaxSize - espec->SoundBufSize);
   }
   else
   {
    HRBufs[ch]->ResampleSkipped(hrc);
   }
  }

  espec->SoundBufSize += sc;
 }

 espec->MasterCycles = DEMO_MASTER_CLOCK / DEMO_FRAME_RATE;
 espec->InterlaceOn = Interlace;
 espec->InterlaceField = InterlaceField;

 if(Interlace)
  InterlaceField = !InterlaceField;
 else
  InterlaceField = 0;
}

static bool TestMagic(MDFNFILE* fp)
{
 return(false);
}

static void Cleanup(void)
{
 for(unsigned ch = 0; ch < 2; ch++)
 {
  if(HRBufs[ch])
  {
   delete HRBufs[ch];
   HRBufs[ch] = NULL;
  }
 }

 if(HRRes)
 {
  delete HRRes;
  HRRes = NULL;
 }
}

static void Load(MDFNFILE* fp)
{
 try
 {
  std::vector<uint64> dlist = MDFN_GetSettingMultiUI("demo.multi_enum");

  MDFN_printf("Loaded desserts:");

  for(uint64 dle : dlist)
   MDFN_printf(" %llu", (unsigned long long)dle);

  MDFN_printf("\n");

  for(unsigned ch = 0; ch < 2; ch++)
   HRBufs[ch] = new OwlBuffer();

  Power();
 }
 catch(...)
 {
  Cleanup();
  throw;
 }
}


static void CloseGame(void)
{
 Cleanup();
}

struct DemoStateTest
{
 uint8 a;
 int8 b;
 uint16 c;
 int16 d;
 uint32 e;
 int32 f;
 uint64 g;
 int64 h;
 bool i;
 float j;
 double k;

 uint8 arr_a[7];
 int8 arr_b[7];
 uint16 arr_c[7];
 int16 arr_d[7];
 uint32 arr_e[7];
 int32 arr_f[7];
 uint64 arr_g[7];
 int64 arr_h[7];
 bool arr_i[7];
 float arr_j[7];
 double arr_k[7];

 uint8 alt_arr_a[7];
 int8 alt_arr_b[7];
 uint16 alt_arr_c[7];
 int16 alt_arr_d[7];
 uint32 alt_arr_e[7];
 int32 alt_arr_f[7];
 uint64 alt_arr_g[7];
 int64 alt_arr_h[7];
 bool alt_arr_i[7];
 float alt_arr_j[7];
 double alt_arr_k[7];

 struct
 {
  uint8 a;
  int8 b;
  uint16 c;
  int16 d;
  uint32 e;
  int32 f;
  uint64 g;
  int64 h;
  bool i;
  float j;
  double k;

  uint8 arr_a[7];
  int8 arr_b[7];
  uint16 arr_c[7];
  int16 arr_d[7];
  uint32 arr_e[7];
  int32 arr_f[7];
  uint64 arr_g[7];
  int64 arr_h[7];
  bool arr_i[7];
  float arr_j[7];
  double arr_k[7];

  uint8 alt_arr_a[7];
  int8 alt_arr_b[7];
  uint16 alt_arr_c[7];
  int16 alt_arr_d[7];
  uint32 alt_arr_e[7];
  int32 alt_arr_f[7];
  uint64 alt_arr_g[7];
  int64 alt_arr_h[7];
  bool alt_arr_i[7];
  float alt_arr_j[7];
  double alt_arr_k[7];
 } __attribute__((__packed__)) stt[15];
} __attribute__((__packed__));

static void randomoo(DemoStateTest* ptr, size_t count)
{
 uint64 lcg[2] = { 0xDEADBEEFCAFEBABEULL, 0x0123456789ABCDEFULL };

 for(size_t i = 0; i < count; i++)
 {
  ((uint8*)ptr)[i] = (lcg[0] ^ lcg[1]) >> 28;
  lcg[0] = (19073486328125ULL * lcg[0]) + 1;
  lcg[1] = (6364136223846793005ULL * lcg[1]) + 1442695040888963407ULL;
 }
 ptr->i = *(uint8*)&ptr->i & 0x1;
 for(unsigned i = 0; i < 7; i++)
 {
  ptr->arr_i[i] = *(uint8*)&ptr->arr_i[i] & 0x1;
  ptr->alt_arr_i[i] = *(uint8*)&ptr->arr_i[i] & 0x1;
 }

 for(auto& s : ptr->stt)
 {
  s.i = *(uint8*)&s.i & 0x1;
  for(unsigned i = 0; i < 7; i++)
  {
   s.arr_i[i] = *(uint8*)&s.arr_i[i] & 0x1;
   s.alt_arr_i[i] = *(uint8*)&s.arr_i[i] & 0x1;
  }
 }
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 std::unique_ptr<DemoStateTest[]> dst(new DemoStateTest[2]);

 if(load)
  memset(&dst[0], 0, sizeof(DemoStateTest));
 else
  randomoo(&dst[0], sizeof(DemoStateTest));

 randomoo(&dst[1], sizeof(DemoStateTest));

 SFORMAT MoreStateRegs[] =
 {
  SFVAR(dst[0].a),
  SFVAR(dst[0].b),
  SFVAR(dst[0].c),
  SFVAR(dst[0].d),
  SFVAR(dst[0].e),
  SFVAR(dst[0].f),
  SFVAR(dst[0].g),
  SFVAR(dst[0].h),
  SFVAR(dst[0].i),
  SFVAR(dst[0].j),
  SFVAR(dst[0].k),

  SFPTR8(dst[0].arr_a, 7),
  SFPTR8(dst[0].arr_b, 7),
  SFPTR16(dst[0].arr_c, 7),
  SFPTR16(dst[0].arr_d, 7),
  SFPTR32(dst[0].arr_e, 7),
  SFPTR32(dst[0].arr_f, 7),
  SFPTR64(dst[0].arr_g, 7),
  SFPTR64(dst[0].arr_h, 7),
  SFPTRB(dst[0].arr_i, 7),
  SFPTRF(dst[0].arr_j, 7),
  SFPTRD(dst[0].arr_k, 7),

  SFVAR(dst[0].alt_arr_a),
  SFVAR(dst[0].alt_arr_b),
  SFVAR(dst[0].alt_arr_c),
  SFVAR(dst[0].alt_arr_d),
  SFVAR(dst[0].alt_arr_e),
  SFVAR(dst[0].alt_arr_f),
  SFVAR(dst[0].alt_arr_g),
  SFVAR(dst[0].alt_arr_h),
  SFVAR(dst[0].alt_arr_i),
  SFVAR(dst[0].alt_arr_j),
  SFVAR(dst[0].alt_arr_k),

  SFVAR(dst[0].stt->i, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->h, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->g, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->f, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->e, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->d, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->c, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->b, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->a, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->j, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->k, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTRB(dst[0].stt->arr_i, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR8(dst[0].stt->arr_a, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR32(dst[0].stt->arr_e, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR8(dst[0].stt->arr_b, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR32(dst[0].stt->arr_f, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR16(dst[0].stt->arr_c, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR64(dst[0].stt->arr_g, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR16(dst[0].stt->arr_d, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTR64(dst[0].stt->arr_h, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTRF(dst[0].stt->arr_j, 7, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFPTRD(dst[0].stt->arr_k, 7, 15, sizeof(*dst[0].stt), dst[0].stt),

  SFVAR(dst[0].stt->alt_arr_i, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_a, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_e, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_b, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_f, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_c, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_g, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_d, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_h, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_j, 15, sizeof(*dst[0].stt), dst[0].stt),
  SFVAR(dst[0].stt->alt_arr_k, 15, sizeof(*dst[0].stt), dst[0].stt),

  SFEND
 };

 SFORMAT StateRegs[] =
 {
  SFLINK(nullptr),
  SFLINK(MoreStateRegs),
  //
  //
  //
  SFVAR(Interlace),
  SFVAR(InterlaceField),

  SFVAR(middle_size),
  SFVAR(middle_size_inc),

  SFVAR(w2_select),

  SFVAR(cur_test_mode),

  SFVAR(phase),
  SFVAR(phase_inc),  

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAIN");

 if(memcmp(&dst[0], &dst[1], sizeof(DemoStateTest)))
  abort();

 if(load)
 {
  if(middle_size_inc != -1 && middle_size_inc != 1)
   middle_size_inc = 1;

  if(middle_size >= 240)
  {
   middle_size = 240;
   middle_size_inc = -1;
  }

  if(middle_size <= 0)
  {
   middle_size = 0;
   middle_size_inc = 1;
  }
 }
}


static const FileExtensionSpecStruct KnownExtensions[] =
{
 { NULL, NULL }
};

static void SetInput(unsigned port, const char *type, uint8 *ptr)
{
 controller_ptr[port] = (uint8 *)ptr;
}

static void DoSimpleCommand(int cmd)
{
 switch(cmd)
 {
  case MDFN_MSC_RESET:
  case MDFN_MSC_POWER: Power(); break;
 }
}

static const MDFNSetting_EnumList MultiEnum_List[] =
{
 { "cookie", 0, gettext_noop("Monster.") },
 { "cake", 1, gettext_noop("Lie.") },
 { "cobbler", 2, gettext_noop("Shoe.") },
 { "strudel", 3, gettext_noop("Steve.") },

 { NULL, 0 },
};

static const MDFNSetting DEMOSettings[] = 
{
 { "demo.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("Sound quality."), gettext_noop("Higher values correspond to better SNR and better preservation of higher frequencies(\"brightness\"), at the cost of increased computational complexity and a negligible increase in latency.\n\nHigher values will also slightly increase the probability of sample clipping(relevant if Mednafen's volume control settings are set too high), due to increased (time-domain) ringing."), MDFNST_INT, "3", "0", "5" },
 { "demo.resamp_rate_error", MDFNSF_NOFLAGS, gettext_noop("Sound output rate tolerance."), gettext_noop("Lower values correspond to better matching of the output rate of the resampler to the actual desired output rate, at the expense of increased RAM usage and poorer CPU cache utilization."), MDFNST_FLOAT, "0.0000009", "0.0000001", "0.0000350" },

 { "demo.multi_enum", MDFNSF_NOFLAGS, gettext_noop("Multi-enum test."), nullptr, MDFNST_MULTI_ENUM, "", nullptr, nullptr, nullptr, nullptr, MultiEnum_List },

 { NULL }
};

static const IDIIS_SwitchPos SwitchPositions[] =
{
 { "waffles", gettext_noop("Waffles 0"), gettext_noop("With extra churned ungulate squeezings and concentrated tree blood.") },
 { "oranges", gettext_noop("Oranges 1"), gettext_noop("Blood oranges, of course.") },
 { "monkeys", gettext_noop("Monkeys 2"), gettext_noop("Quiet, well-behaved monkeys that don't try to eat your face.") },
 { "zebraz", gettext_noop("Zebra-Z 3"), gettext_noop("Zebras wearing sunglasses.") },
 { "snorkle", gettext_noop("Snorkle 4"), gettext_noop("? ? ?") },
};

static const IDIISG IDII =
{
 IDIIS_Button("toggle_ilace", "Toggle Interlace Mode", 0, NULL),
 IDIIS_Button("stm", "Select Test Mode", 1, NULL),
 IDIIS_Switch("swt", "Switch Meow", 2, SwitchPositions),
 IDIIS_Rumble(),
 IDIIS_AnaButton("rcweak", "Rumble Control Weak", 3),
 IDIIS_AnaButton("rcstrong", "Rumble Control Strong", 4),
 IDIIS_Axis("stick", "Stick", "left", "LEFT", "right", "RIGHT", 5),
 IDIIS_Axis("stick", "Stick", "up", "UP", "down", "DOWN", 6),
 IDIIS_Padding<32>(),
};

static std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 {
  "controller",
  "Controller",
  NULL,
  IDII,
 }
};

static const std::vector<InputPortInfoStruct> PortInfo =
{
 { "port1", "Port 1", InputDeviceInfo },
 { "port2", "Port 2", InputDeviceInfo },
};
}

using namespace MDFN_IEN_DEMO;

MDFNGI EmulatedDEMO =
{
 "demo",
 "Mednafen Demo/Example Module",
 KnownExtensions,
 MODPRIO_INTERNAL_LOW,
 NULL,
 PortInfo,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,

 NULL, //SetLayerEnableMask,
 NULL, //"Background\0Sprites\0Window\0",

 NULL,
 NULL,

 NULL,
 0,

 CheatInfo_Empty,

 false,
 StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
 NULL,
 DEMOSettings,
 MDFN_MASTERCLOCK_FIXED(DEMO_MASTER_CLOCK),
 (uint32)((double)DEMO_MASTER_CLOCK / (450 * 250) * 65536 * 256),
 true, // Multires possible?

 800,	// lcm_width
 600,	// lcm_height
 NULL,	// Dummy

 400,	// Nominal width
 300,	// Nominal height

 1024,	// Framebuffer width
 768,	// Framebuffer height

 2,     // Number of output sound channels
};

