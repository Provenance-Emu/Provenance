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
#include <trio/trio.h>

#include <math.h>

#include <vector>

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

static void Draw(EmulateSpecStruct* espec)
{
 espec->DisplayRect.x = DemoRandU32() & 31;
 espec->DisplayRect.y = DemoRandU32() & 31;

 espec->DisplayRect.w = 400;
 espec->DisplayRect.h = 300 << Interlace;
 
 if(!espec->skip)
 {
  espec->surface->Fill(DemoRandU32() & 0xFF, DemoRandU32() & 0xFF, DemoRandU32() & 0xFF, 0);

  if(cur_test_mode == 1)
  {
   char width_text[16];

   espec->DisplayRect.w = 800 / (1 + ((w2_select >> 8) & 31));
   trio_snprintf(width_text, sizeof(width_text), "%d", espec->DisplayRect.w);

   MDFN_DrawFillRect(espec->surface, espec->DisplayRect.x, espec->DisplayRect.y, espec->DisplayRect.w, espec->DisplayRect.h, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x7F, 0x00, 0xFF));

   for(int z = 0; z < std::min<int32>(espec->DisplayRect.w, espec->DisplayRect.h) / 2; z += 7)
    MDFN_DrawFillRect(espec->surface, espec->DisplayRect.x + z, espec->DisplayRect.y + z, espec->DisplayRect.w - z * 2, espec->DisplayRect.h - z * 2, espec->surface->MakeColor(0, (z * 8) & 0xFF, 0), espec->surface->MakeColor(0, 0, (z * 17) & 0xFF));

   DrawTextTransShadow(espec->surface->pixels + espec->DisplayRect.x + (espec->DisplayRect.y + espec->DisplayRect.h / 2 - 9) * espec->surface->pitchinpix, espec->surface->pitchinpix << 2, espec->DisplayRect.w, width_text, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), true, MDFN_FONT_9x18_18x18);
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
   int w2_font = MDFN_FONT_9x18_18x18;
   char w2_text[16];

   if(w2 < 8)
    w2_font = MDFN_FONT_4x5;
   else if(w2 < 16)
    w2_font = MDFN_FONT_5x7;
   else if(w2 < 20)
    w2_font = MDFN_FONT_6x13_12x13;


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

   MDFN_DrawFillRect(espec->surface, espec->DisplayRect.x, y0, w0, y1 - y0, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x7F, 0x00, 0xFF));
   DrawTextTransShadow(espec->surface->pixels + espec->DisplayRect.x + (y0 + (y1 - y0) / 2 - 9) * espec->surface->pitchinpix, espec->surface->pitchinpix << 2, w0, "400", espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), true, MDFN_FONT_9x18_18x18);

   MDFN_DrawFillRect(espec->surface, espec->DisplayRect.x, y1, w1, y2 - y1, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x00, 0x7F, 0xFF));
   DrawTextTransShadow(espec->surface->pixels + espec->DisplayRect.x + (y1 + (y2 - y1) / 2 - 9) * espec->surface->pitchinpix, espec->surface->pitchinpix << 2, w1, "800", espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), true, MDFN_FONT_9x18_18x18);

   MDFN_DrawFillRect(espec->surface, espec->DisplayRect.x, y2, w2, y3 - y2, espec->surface->MakeColor(0xFF, 0xFF, 0xFF), espec->surface->MakeColor(0x00, 0x00, 0xFF));
   DrawTextTransShadow(espec->surface->pixels + espec->DisplayRect.x + (y2 + (y3 - y2) / 2 - 9) * espec->surface->pitchinpix, espec->surface->pitchinpix << 2, w2, w2_text, espec->surface->MakeColor(0xFF, 0, 0), espec->surface->MakeColor(0, 0, 0), true, w2_font);
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

 for(unsigned i = 0; i < 2; i++)
 {
  {
   uint8 cur_cstate = *controller_ptr[i];

   if((cur_cstate ^ last_cstate[i]) & cur_cstate & 1)
    Interlace = !Interlace;

   if((cur_cstate ^ last_cstate[i]) & cur_cstate & 2)
    cur_test_mode = (cur_test_mode + 1) % 2;

   last_cstate[i] = cur_cstate;
  }

  {
   uint8 weak = MDFN_de16lsb(&controller_ptr[i][3]) >> 7;
   uint8 strong = MDFN_de16lsb(&controller_ptr[i][5]) >> 7;

   MDFN_en16lsb(&controller_ptr[i][1], (weak << 0) | (strong << 8));
  }
 }

 Draw(espec);

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

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
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

static MDFNSetting DEMOSettings[] = 
{
 { "demo.resamp_quality", MDFNSF_NOFLAGS, gettext_noop("Sound quality."), gettext_noop("Higher values correspond to better SNR and better preservation of higher frequencies(\"brightness\"), at the cost of increased computational complexity and a negligible increase in latency.\n\nHigher values will also slightly increase the probability of sample clipping(relevant if Mednafen's volume control settings are set too high), due to increased (time-domain) ringing."), MDFNST_INT, "3", "0", "5" },
 { "demo.resamp_rate_error", MDFNSF_NOFLAGS, gettext_noop("Sound output rate tolerance."), gettext_noop("Lower values correspond to better matching of the output rate of the resampler to the actual desired output rate, at the expense of increased RAM usage and poorer CPU cache utilization."), MDFNST_FLOAT, "0.0000009", "0.0000001", "0.0000350" },
 { NULL }
};

static const char* SwitchPositions[] =
{
 gettext_noop("Waffles 0"),
 gettext_noop("Oranges 1"),
 gettext_noop("Monkeys 2"),
 gettext_noop("Zebra-Z 3"),
 gettext_noop("Snorkle 4")
};

static const IDIISG IDII =
{
 { "toggle_ilace", "Toggle Interlace Mode", 0, IDIT_BUTTON, NULL },
 { "stm", "Select Test Mode", 1, IDIT_BUTTON, NULL },
 IDIIS_Switch("swt", "Switch Meow", 2, SwitchPositions, sizeof(SwitchPositions) / sizeof(SwitchPositions[0])),
 { "rumble", "RUMBLOOS", -1, IDIT_RUMBLE, NULL },
 { "rcweak", "Rumble Control Weak", 3, IDIT_BUTTON_ANALOG, NULL },
 { "rcstrong", "Rumble Control Strong", 4, IDIT_BUTTON_ANALOG, NULL },
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

 NULL, //InstallReadPatch,
 NULL, //RemoveReadPatches,
 NULL,
 NULL, //&CheatFormatInfo,
 false,
 StateAction,
 Emulate,
 NULL,
 SetInput,
 NULL,
 DoSimpleCommand,
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

