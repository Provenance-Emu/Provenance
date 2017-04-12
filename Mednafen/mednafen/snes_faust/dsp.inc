/* Mednafen - Multi-system Emulator
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

/*
 $x0: VxVOLL
 $x1: VxVOLR
 $x2: VxPITCHL
 $x3: VxPITCHH
 $x4: VxSRCN
 $x5: VxADSR1
 $x6: VxADSR2
 $x7: VxGAIN
 $x8: VxENVX
 $x9: VxOUTX

 $0C: MVOLL
 $1C: MVOLR

 $2C: EVOLL
 $3C: EVOLR
 $4C: KON
 $5C: KOFF
 $6C: FLG
 $7C: ENDX

 $0D: EFB
 $2D: PMON
 $3D: NON
 $4D: EON
 $5D: DIR
 $6D: ESA
 $7D: EDL

 $xF: FIRx
*/

static INLINE int16 ClampS16(int32 v)
{
 if(v > 32767)
  v = 32767;

 if(v < -32768)
  v = -32768;

 return v;
}

static const int16 ResampHalfImp[512] =
{
    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0, 
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    2,    2,    2,    2,    2, 
    2,    2,    3,    3,    3,    3,    3,    4,    4,    4,    4,    4,    5,    5,    5,    5, 
    6,    6,    6,    6,    7,    7,    7,    8,    8,    8,    9,    9,    9,   10,   10,   10, 
   11,   11,   11,   12,   12,   13,   13,   14,   14,   15,   15,   15,   16,   16,   17,   17, 
   18,   19,   19,   20,   20,   21,   21,   22,   23,   23,   24,   24,   25,   26,   27,   27, 
   28,   29,   29,   30,   31,   32,   32,   33,   34,   35,   36,   36,   37,   38,   39,   40, 
   41,   42,   43,   44,   45,   46,   47,   48,   49,   50,   51,   52,   53,   54,   55,   56, 
   58,   59,   60,   61,   62,   64,   65,   66,   67,   69,   70,   71,   73,   74,   76,   77, 
   78,   80,   81,   83,   84,   86,   87,   89,   90,   92,   94,   95,   97,   99,  100,  102, 
  104,  106,  107,  109,  111,  113,  115,  117,  118,  120,  122,  124,  126,  128,  130,  132, 
  134,  137,  139,  141,  143,  145,  147,  150,  152,  154,  156,  159,  161,  163,  166,  168, 
  171,  173,  175,  178,  180,  183,  186,  188,  191,  193,  196,  199,  201,  204,  207,  210, 
  212,  215,  218,  221,  224,  227,  230,  233,  236,  239,  242,  245,  248,  251,  254,  257, 
  260,  263,  267,  270,  273,  276,  280,  283,  286,  290,  293,  297,  300,  304,  307,  311, 
  314,  318,  321,  325,  328,  332,  336,  339,  343,  347,  351,  354,  358,  362,  366,  370, 
  374,  378,  381,  385,  389,  393,  397,  401,  405,  410,  414,  418,  422,  426,  430,  434, 
  439,  443,  447,  451,  456,  460,  464,  469,  473,  477,  482,  486,  491,  495,  499,  504, 
  508,  513,  517,  522,  527,  531,  536,  540,  545,  550,  554,  559,  563,  568,  573,  577, 
  582,  587,  592,  596,  601,  606,  611,  615,  620,  625,  630,  635,  640,  644,  649,  654, 
  659,  664,  669,  674,  678,  683,  688,  693,  698,  703,  708,  713,  718,  723,  728,  732, 
  737,  742,  747,  752,  757,  762,  767,  772,  777,  782,  787,  792,  797,  802,  806,  811, 
  816,  821,  826,  831,  836,  841,  846,  851,  855,  860,  865,  870,  875,  880,  884,  889, 
  894,  899,  904,  908,  913,  918,  923,  927,  932,  937,  941,  946,  951,  955,  960,  965, 
  969,  974,  978,  983,  988,  992,  997, 1001, 1005, 1010, 1014, 1019, 1023, 1027, 1032, 1036, 
 1040, 1045, 1049, 1053, 1057, 1061, 1066, 1070, 1074, 1078, 1082, 1086, 1090, 1094, 1098, 1102, 
 1106, 1109, 1113, 1117, 1121, 1125, 1128, 1132, 1136, 1139, 1143, 1146, 1150, 1153, 1157, 1160, 
 1164, 1167, 1170, 1174, 1177, 1180, 1183, 1186, 1190, 1193, 1196, 1199, 1202, 1205, 1207, 1210, 
 1213, 1216, 1219, 1221, 1224, 1227, 1229, 1232, 1234, 1237, 1239, 1241, 1244, 1246, 1248, 1251, 
 1253, 1255, 1257, 1259, 1261, 1263, 1265, 1267, 1269, 1270, 1272, 1274, 1275, 1277, 1279, 1280, 
 1282, 1283, 1284, 1286, 1287, 1288, 1290, 1291, 1292, 1293, 1294, 1295, 1296, 1297, 1297, 1298, 
 1299, 1300, 1300, 1301, 1302, 1302, 1303, 1303, 1303, 1304, 1304, 1304, 1304, 1304, 1305, 1305
};

enum
{
 VRO_VOLL = 0x0,
 VRO_VOLR = 0x1,
 VRO_PITCHL = 0x2,
 VRO_PITCHH = 0x3,
 VRO_SRCN = 0x4,
 VRO_ADSR1 = 0x5,
 VRO_ADSR2 = 0x6,
 VRO_GAIN = 0x7,
 VRO_ENVX = 0x8,
 VRO_OUTX = 0x9
};

enum
{
 GRA_MVOLL = 0x0C,
 GRA_MVOLR = 0x1C,

 GRA_EVOLL = 0x2C,
 GRA_EVOLR = 0x3C,
 GRA_KON = 0x4C,
 GRA_KOFF = 0x5C,
 GRA_FLG = 0x6C,
 GRA_ENDX = 0x7C,

 GRA_EFB = 0x0D,
 GRA_PMON = 0x2D,
 GRA_NON = 0x3D,
 GRA_EON = 0x4D,
 GRA_DIR = 0x5D,
 GRA_ESA = 0x6D,
 GRA_EDL = 0x7D,

 GRA_FIR0 = 0x0F,
 GRA_FIR1 = 0x1F,
 GRA_FIR2 = 0x2F,
 GRA_FIR3 = 0x3F,
 GRA_FIR4 = 0x4F,
 GRA_FIR5 = 0x5F,
 GRA_FIR6 = 0x6F,
 GRA_FIR7 = 0x7F,
};

static uint8 Regs[0x80];

struct DSP_HGS
{
 bool KPollCycle;

 uint16 RateCounter;
 //
 uint16 NoiseVal;

 //
 int16 Accum[2];
 int16 EchoAccum[2];
 //

 uint8 IKON;

 //

 uint8 Pending_ENDX;

 //

 uint8 Latch_IKON;
 uint8 Latch_KOFF;

 uint8 Latch_PMON;
 uint8 Latch_NON;
 uint8 Latch_EON;
 uint8 Latch_DIR;

 //
 //
 bool EchoWriteDisable;

 uint8 Latch_EDL;
 uint8 Latch_ESA;

 uint8 Latch_FIR[8];

 int16 EchoFIROut[2];

 int16 EchoFIRBuf[2][8];
 uint8 EchoFIRBufPos;

 uint16 EchoBase;
 uint16 EchoOffset;
 uint16 EchoBound;
};

enum
{
 ADSR_PHASE_ATTACK = 0,
 ADSR_PHASE_DECAY,
 ADSR_PHASE_SUSTAIN,
 ADSR_PHASE_RELEASE
};

struct DSP_Voice
{
 uint16 BRR_Addr;
 uint8 BRR_Offs;	// 0, 2, 4, 6
 uint8 BRR_Header;
 uint8 BRR_Data[2];

 int16 RB[12 * 2];
 uint8 RB_Pos;
 uint8 RB_In;

 uint8 Latch_SRCN;
 uint16 Addr;

 bool StartReload;
 bool LoopReload;

 uint8 Latch_ADSR1;
 uint8 ADSRPhase;
 uint16 ADSRLevel;
 bool ADSRBentFastNext;

 uint8 Pending_ENVX;
 uint8 Pending_OUTX;

 int16 CurSample;

 unsigned Pitch;
 unsigned Phase;
};

static DSP_HGS HGS;
static DSP_Voice Voices[8];

static int16 OutputL; // To avoid distortion, since L and R aren't updated at the same time(and the emulation frame can end between them).
static unsigned OutputBufPos;
static OwlResampler* Resampler;
static double ResampLastRate;
static OwlBuffer ResampBuf[2];

//static uint16 sawthing;

//static int KONCounter[8] = { 9, 9, 9, 9, 9, 9, 9, 9 };

static INLINE bool CheckRC(unsigned rate)
{
 static const uint16 RateMasks[32] =
 {
  0x0000, 0xFFE0, 0x3FF8,
  0x1FE7, 0x7FE0, 0x1FF8,
  0x0FE7, 0x3FE0, 0x0FF8,
  0x07E7, 0x1FE0, 0x07F8,
  0x03E7, 0x0FE0, 0x03F8,
  0x01E7, 0x07E0, 0x01F8,
  0x00E7, 0x03E0, 0x00F8,
  0x0067, 0x01E0, 0x0078,
  0x0027, 0x00E0, 0x0038,
  0x0007, 0x0060, 0x0018,
          0x0020,
          0x0000
 };

 static const uint16 RateXOR[32] =
 {
  0xffff, 0x0000, 0x3e08, 
  0x1d04, 0x0000, 0x1e08, 
  0x0d04, 0x0000, 0x0e08, 
  0x0504, 0x0000, 0x0608, 
  0x0104, 0x0000, 0x0208, 
  0x0104, 0x0000, 0x0008, 
  0x0004, 0x0000, 0x0008, 
  0x0004, 0x0000, 0x0008, 
  0x0004, 0x0000, 0x0008, 
  0x0004, 0x0000, 0x0008, 
          0x0000,
	  0x0000
 };

 return !((HGS.RateCounter & RateMasks[rate]) ^ RateXOR[rate]);
}

static INLINE void ResetRC(void)
{
 HGS.RateCounter = 0;
}

static INLINE void ClockRC(void)
{
 if(!(HGS.RateCounter & 0x7))
  HGS.RateCounter ^= 0x5;
   
 if(!(HGS.RateCounter & 0x18))
  HGS.RateCounter ^= 0x18;

 HGS.RateCounter -= 0x29;
}


static INLINE void RunADSR(const unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 int32 new_env = v->ADSRLevel;
 const uint16 ADSR1 = v->Latch_ADSR1;
 const uint16 ADSR2 = Regs[(voice_num << 4) | VRO_ADSR2];
 const uint16 GAIN = Regs[(voice_num << 4) | VRO_GAIN];
 int32 sl;

 if(v->ADSRPhase == ADSR_PHASE_RELEASE)
  new_env -= 8;
 else
 {
  unsigned rate = 0;
  signed delta = 0;

  if(ADSR1 & 0x80)
  {
   sl = ADSR2 >> 5;

   if(v->ADSRPhase == ADSR_PHASE_ATTACK)
   {
    rate = ((ADSR1 & 0xF) << 1) + 1;

    if(rate == 0x1F)
     delta = 1024;
    else
     delta = 32;
   }
   else if(v->ADSRPhase == ADSR_PHASE_DECAY)
   {
    rate = ((ADSR1 >> 3) & 0xE) | 0x10;
    delta = ~((int32)(v->ADSRLevel - 1) >> 8);
   }
   else if(v->ADSRPhase == ADSR_PHASE_SUSTAIN)
   {
    rate = ADSR2 & 0x1F;
    delta = ~((int32)(v->ADSRLevel - 1) >> 8);
   }
  }
  else
  {
   sl = GAIN >> 5;

   if(GAIN & 0x80)
   {
    rate = GAIN & 0x1F;

    switch((GAIN >> 5) & 0x3)
    {
     case 0: delta = -32; break;
     case 1: delta = ~((int32)(v->ADSRLevel - 1) >> 8); break;
     case 2: delta = 32; break;
     case 3: delta = v->ADSRBentFastNext ? 32 : 8; break;
    }
   }
   else
    new_env = (GAIN & 0x7F) << 4;
  }

  if(CheckRC(rate))
   new_env += delta;

  if(v->ADSRPhase == ADSR_PHASE_DECAY)
  {
   if((new_env >> 8) == sl)
    v->ADSRPhase = ADSR_PHASE_SUSTAIN;
  }

  if(v->ADSRPhase == ADSR_PHASE_ATTACK)
  {
   if(new_env > 0x7FF)
   {
    v->ADSRPhase = ADSR_PHASE_DECAY;
   }
  }
 }
 v->ADSRBentFastNext = (new_env & 0x7FF) < 0x600;

 if(new_env < 0)
  new_env = 0;

 if(new_env > 0x7FF)
  new_env = 0x7FF;

 v->ADSRLevel = new_env;

 //if(voice_num == 4 && v->ADSRLevel)
 // fprintf(stderr, "Phase=%u, Level=%04x\n", v->ADSRPhase, v->ADSRLevel);
}

static INLINE void V1(unsigned voice_num)
{
 Voices[voice_num].Latch_SRCN = Regs[(voice_num << 4) | VRO_SRCN];
}

static INLINE void V2(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 if(v->StartReload)
 {
  v->BRR_Addr =  (APURAM[((HGS.Latch_DIR << 8) + (v->Latch_SRCN << 2) + 0) & 0xFFFF] << 0) |
		 (APURAM[((HGS.Latch_DIR << 8) + (v->Latch_SRCN << 2) + 1) & 0xFFFF] << 8);
  v->BRR_Offs = 0;

  v->StartReload = false;
 }
 else if(v->LoopReload)
 {
  v->BRR_Addr = (APURAM[((HGS.Latch_DIR << 8) + (v->Latch_SRCN << 2) + 2) & 0xFFFF] << 0) |
		(APURAM[((HGS.Latch_DIR << 8) + (v->Latch_SRCN << 2) + 3) & 0xFFFF] << 8);
  v->BRR_Offs = 0;

  v->LoopReload = false;
 }

 v->Pitch = Regs[(voice_num << 4) | VRO_PITCHL];

 v->Latch_ADSR1 = Regs[(voice_num << 4) | VRO_ADSR1];
}

static INLINE void V3a(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 v->Pitch |= (Regs[(voice_num << 4) | VRO_PITCHH] & 0x3F) << 8;

 if(HGS.Latch_PMON & (1U << voice_num) & ~1U)
 {
  //printf("%d, %d, %d\n", v->Pitch, Voices[voice_num - 1].CurSample, ((Voices[voice_num - 1].CurSample >> 6) * (int32)v->Pitch) >> 10);
  v->Pitch += ((Voices[voice_num - 1].CurSample >> 6) * (int32)v->Pitch) >> 10;
  //printf(" %d\n", v->Pitch);
 }
}

static INLINE void V3b(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 v->BRR_Header = APURAM[v->BRR_Addr];
 v->BRR_Data[0] = APURAM[(uint16)(v->BRR_Addr + 1 + v->BRR_Offs + 0)];
}

static INLINE void V3c(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 {
  const int16* const rbp = &v->RB[(v->Phase >> 12) + v->RB_Pos];
  unsigned ph = (v->Phase >> 4) & 0xFF;
  int32 tmp;

  tmp =  ((rbp[0] * ResampHalfImp[255 - ph]) >> 11) + 
         ((rbp[1] * ResampHalfImp[511 - ph]) >> 11) + 
	 ((rbp[2] * ResampHalfImp[256 + ph]) >> 11);

  //if(voice_num == 0 && sign_15_to_s16(tmp) != tmp)
  //{
  // printf("Phase=0x%04x, RB_Pos=0x%02x --- %d %d %d\n", v->Phase, v->RB_Pos, rbp[0], rbp[1], rbp[2]);
  // abort();
  //}

  tmp = sign_15_to_s16(tmp);

  tmp += ((rbp[3] * ResampHalfImp[  0 + ph]) >> 11);

  if(tmp < -16384) 
   tmp = -16384;

  if(tmp > 16383)
   tmp = 16383;

  v->CurSample = tmp;

  if(HGS.Latch_NON & (1U << voice_num))
  {
   v->CurSample = sign_15_to_s16(HGS.NoiseVal);
  }

  //if(voice_num == 0 && KONCounter[voice_num] < 9)
  // printf("%d, Sample calc; Phase=0x%04x, RB_Pos=0x%02x, Pre Envelope: 0x%04x -- %02x %02x %02x\n", KONCounter[voice_num], v->Phase, v->RB_Pos, (uint16)v->CurSample, rbp[0], rbp[1], rbp[2]);
 }

 v->CurSample = ((v->CurSample * v->ADSRLevel) >> 10) &~ 1;

 //if(voice_num == 0 && KONCounter[voice_num] < 9)
 // printf("\t post: 0x%04x\n", (uint16)v->CurSample >> 1);
 //
 //
 //
 if((v->BRR_Header & 0x3) == 0x01)
 {
  v->ADSRLevel = 0;
  v->ADSRPhase = ADSR_PHASE_RELEASE;
 }

 if(HGS.Latch_IKON & (1U << voice_num))
 {
  if(!HGS.KPollCycle)
  {
   //if(voice_num == 5)
   // printf("DEBUG Key On: %u\n", voice_num);
   v->ADSRPhase = ADSR_PHASE_ATTACK;
   v->ADSRLevel = 0;
   v->ADSRBentFastNext = true;
  }
 }
 else
 {
  if((v->RB_In & 0xF) == 12)
   RunADSR(voice_num);

  if((HGS.Latch_KOFF & (1U << voice_num)) || (Regs[GRA_FLG] & 0x80))
  {
   //if(voice_num == 5 && v->ADSRPhase != ADSR_PHASE_RELEASE)
   // printf("DEBUG Key Off: %u\n", voice_num);

   v->ADSRPhase = ADSR_PHASE_RELEASE;

   if(Regs[GRA_FLG] & 0x80)
    v->ADSRLevel = 0;
  }
 }
}

static void V3(unsigned voice_num)
{
 V3a(voice_num);
 V3b(voice_num);
 V3c(voice_num);
}

static void VoiceAccum(unsigned voice_num, unsigned lr)
{
 DSP_Voice* const v = &Voices[voice_num];
 int32 tmp = (v->CurSample * (int8)Regs[(voice_num << 4) | (VRO_VOLL + lr)]) >> 7;

 HGS.Accum[lr] = ClampS16(HGS.Accum[lr] + tmp);

 if(HGS.Latch_EON & (1U << voice_num))
  HGS.EchoAccum[lr] = ClampS16(HGS.EchoAccum[lr] + tmp);
}

static void V4(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];
 bool snork = (v->RB_In == 12);

 VoiceAccum(voice_num, 0);

 if(v->Phase & 0x4000)
 {
  v->Phase &= 0x3FFF;
  v->RB_In -= 4;
 }

 if(v->RB_In == 28)
  v->RB_In = 12;

 if(v->RB_In != 12)
 {
  v->BRR_Data[1] = APURAM[(uint16)(v->BRR_Addr + 1 + v->BRR_Offs + 1)];
  v->BRR_Offs = (v->BRR_Offs + 2) & 0x6;
  if(!v->BRR_Offs)
  {
   v->BRR_Addr += 9;

   if(v->BRR_Header & 0x01)
    v->LoopReload = true;
  }

  //if(voice_num == 0) // && KONCounter[voice_num] < 9)
  // printf("%d, BRR Decode->%u --- Header=0x%02x, data0=0x%02x, data1=0x%02x\n", KONCounter[voice_num], v->RB_Pos, v->BRR_Header, v->BRR_Data[0], v->BRR_Data[1]);

  {
   static const int8 weights[4][2] =
   {
    // i-2, i-1
    {   0,   0 },
    {   0,  60 },
    { -60, 122 },
    { -52, 115 },
   };
   unsigned filter = (v->BRR_Header >> 2) & 0x3;
   unsigned shift = (v->BRR_Header >> 4) & 0xF;
   uint16 brrd = (v->BRR_Data[0] << 8) | v->BRR_Data[1];

   if(shift > 12)
   {
    brrd &= 0x8888;
    brrd |= brrd >> 1;
    brrd |= brrd >> 2;
    shift = 12;
   }

   for(unsigned i = 0; i < 4; i++)
   {
    int32 s = (int32)((uint32)(int16)(brrd & 0xF000) << shift) >> 13;

    s += (v->RB[(v->RB_Pos + i + 10)] * weights[filter][0]) >> 6;
    s += (v->RB[(v->RB_Pos + i + 11)] * weights[filter][1]) >> 6;

    if(s < -32768)
     s = -32768;

    if(s > 32767)
     s = 32767;

    s = sign_15_to_s16(s);

    //if(voice_num == 0) // && KONCounter[voice_num] < 9)
    // printf("\t0x%04x\n", (uint16)s);

    v->RB[v->RB_Pos +  0 + i] = s;
    v->RB[v->RB_Pos + 12 + i] = s;
    brrd <<= 4;
   }
   v->RB_Pos = (v->RB_Pos + 4) % 12;
   v->RB_In += 4;
  }
 }

 if(HGS.Latch_IKON & (1U << voice_num))
 {
  if(!HGS.KPollCycle)
  {
   v->Phase = 0;
   v->RB_Pos = 0;
   v->RB_In = 12;
   v->StartReload = true;
   v->LoopReload = false;
  }
  else
  {
   v->RB_In = 16;
  }
 }
 else if(v->RB_In == 12 && snork)
 {
  //if(voice_num == 0 && KONCounter[voice_num] < 9)
  // printf("%d, Add pitch(phase before add = 0x%04x.\n", KONCounter[voice_num], v->Phase);

  v->Phase += v->Pitch;
  if(v->Phase > 0x7FFF)
   v->Phase = 0x7FFF;
 }
}

static INLINE void V5(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 VoiceAccum(voice_num, 1);

 HGS.Pending_ENDX = Regs[GRA_ENDX];

 if((HGS.Latch_IKON & (1U << voice_num)) && !HGS.KPollCycle)
 {
  HGS.Pending_ENDX &= ~(1U << voice_num);
 }
 else if(v->LoopReload)
 {
  HGS.Pending_ENDX |= 1U << voice_num;
 }
}

static INLINE void V6(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 v->Pending_OUTX = v->CurSample >> 8;
}

static INLINE void V7(unsigned voice_num)
{
 DSP_Voice* const v = &Voices[voice_num];

 Regs[GRA_ENDX] = HGS.Pending_ENDX;

 Voices[voice_num].Pending_ENVX = v->ADSRLevel >> 4;
}

static INLINE void V8(unsigned voice_num)
{
 Regs[(voice_num << 4) | VRO_OUTX] = Voices[voice_num].Pending_OUTX;
}

static INLINE void V9(unsigned voice_num)
{
 Regs[(voice_num << 4) | VRO_ENVX] = Voices[voice_num].Pending_ENVX;
}

static INLINE void ReadEchoBuffer(unsigned lr)
{
 HGS.EchoFIRBuf[lr][HGS.EchoFIRBufPos] = MDFN_de16lsb(&APURAM[(uint16)(HGS.EchoBase + HGS.EchoOffset) + (lr << 1)]) &~ 1;

 if(lr)
  HGS.EchoFIRBufPos = (HGS.EchoFIRBufPos + 1) & 7;
}

static INLINE void RunFIR(unsigned lr)
{
 int32 accum = 0;

 for(unsigned i = 0; i < 7; i++)
  accum += ((int8)HGS.Latch_FIR[i] * HGS.EchoFIRBuf[lr][(HGS.EchoFIRBufPos + i) & 0x7]) >> 7;

 accum = (int16)accum;
 accum += ((int8)HGS.Latch_FIR[7] * HGS.EchoFIRBuf[lr][(HGS.EchoFIRBufPos + 7) & 0x7]) >> 7;
 accum = ClampS16(accum) &~ 1;

 HGS.EchoFIROut[lr] = accum;
}

static INLINE void WriteEchoBuffer(unsigned lr)
{
 uint8* const target = &APURAM[(uint16)(HGS.EchoBase + HGS.EchoOffset) + (lr << 1)];

 // printf("Write: %d, %04x\n", lr, target - APURAM);
 MDFN_en16lsb(target, HGS.EchoAccum[lr] &~ 1);
}

static INLINE int16 CalcOutput(unsigned lr)
{
 int16 m = ClampS16((     HGS.Accum[lr] * (int8)Regs[lr ? GRA_MVOLR : GRA_MVOLL]) >> 7);
 int16 e = ClampS16((HGS.EchoFIROut[lr] * (int8)Regs[lr ? GRA_EVOLR : GRA_EVOLL]) >> 7);
 int16 ret = ClampS16(m + e);

 if(Regs[GRA_FLG] & 0x40)	// Mute
  ret = 0;

 return ret;
}

template<unsigned which>
static void DSP_Cycle(void)
{
 switch(which)
 {
  case 0x00:
	V5(0);
	V2(1);

	TickT01PreDiv();
	TickTimer(2);
	break;

  case 0x01:
	V6(0);
	V3(1);
	break;

  case 0x02:
	V7(0);
	V4(1);
	V1(3);
	break;

  case 0x03:
	V8(0);
	V5(1);
	V2(2);
	break;

  case 0x04:
	V9(0);
	V6(1);
	V3(2);
	break;

  case 0x05:
	V7(1);
	V4(2);
	V1(4);
	break;

  case 0x06:
	V8(1);
	V5(2);
	V2(3);
	break;

  case 0x07:
	V9(1);
	V6(2);
	V3(3);
	break;

  case 0x08:
	V7(2);
	V4(3);
	V1(5);
	break;

  case 0x09:
	V8(2);
	V5(3);
	V2(4);
	break;

  case 0x0A:
	V9(2);
	V6(3);
	V3(4);
	break;

  case 0x0B:
	V7(3);
	V4(4);
	V1(6);
	break;

  case 0x0C:
	V8(3);
	V5(4);
	V2(5);
	break;

  case 0x0D:
	V9(3);
	V6(4);
	V3(5);
	break;

  case 0x0E:
	V7(4);
	V4(5);
	V1(7);
	break;

  case 0x0F:
	V8(4);
	V5(5);
	V2(6);
	break;

  case 0x10:
	V9(4);
	V6(5);
	V3(6);

	TickTimer(2);
	break;

  case 0x11:
	V1(0);
	V7(5);
	V4(6);
	break;

  case 0x12:
	V8(5);
	V5(6);
	V2(7);
	break;

  case 0x13:
	V9(5);
	V6(6);
	V3(7);
	break;

  case 0x14:
	V1(1);
	V7(6);
	V4(7);
	break;

  case 0x15:
	V2(0);
	V8(6);
	V5(7);
	break;

  case 0x16:	// 22
	V3a(0);
	V9(6);
	V6(7);
	//
	ReadEchoBuffer(0);
	HGS.Latch_FIR[0] = Regs[GRA_FIR0];
	break;

  case 0x17:	 // 23
	V7(7);
	//
	ReadEchoBuffer(1);
	HGS.Latch_FIR[1] = Regs[GRA_FIR1];
	HGS.Latch_FIR[2] = Regs[GRA_FIR2];
	break;

  case 0x18:	// 24
	V8(7);
	//
	HGS.Latch_FIR[3] = Regs[GRA_FIR3];
	HGS.Latch_FIR[4] = Regs[GRA_FIR4];
	HGS.Latch_FIR[5] = Regs[GRA_FIR5];
	break;

  case 0x19:	// 25
	V3b(0);
	V9(7);
	//
	HGS.Latch_FIR[6] = Regs[GRA_FIR6];
	HGS.Latch_FIR[7] = Regs[GRA_FIR7];
	RunFIR(0);
	RunFIR(1);
	break;

  case 0x1A:	// 26
	OutputL = CalcOutput(0);
	HGS.Accum[0] = 0;

	HGS.EchoAccum[0] = ClampS16(HGS.EchoAccum[0] + ClampS16((HGS.EchoFIROut[0] * (int8)Regs[GRA_EFB]) >> 7));
	HGS.EchoAccum[1] = ClampS16(HGS.EchoAccum[1] + ClampS16((HGS.EchoFIROut[1] * (int8)Regs[GRA_EFB]) >> 7));
	break;

  case 0x1B:	// 27
	HGS.Latch_PMON = Regs[GRA_PMON];

#if 0
	(&ResampBuf[0].BufPudding()->f)[OutputBufPos] = (int32)((uint32)(int16)sawthing << 7);
	(&ResampBuf[1].BufPudding()->f)[OutputBufPos] = (int32)((uint32)(int16)sawthing << 7);
	sawthing += 32768;
#else
	(&ResampBuf[0].BufPudding()->f)[OutputBufPos] = /*((int16)rand() >> 1)*/ (int32)((uint32)OutputL << 8);
	(&ResampBuf[1].BufPudding()->f)[OutputBufPos] = /*((int16)rand() >> 1)*/ (int32)((uint32)CalcOutput(1) << 8);
#endif
	OutputBufPos = (OutputBufPos + 1) & 1023;
	HGS.Accum[1] = 0;
	break;

  case 0x1C: // 28
	HGS.Latch_NON = Regs[GRA_NON];
	HGS.Latch_EON = Regs[GRA_EON];
	HGS.Latch_DIR = Regs[GRA_DIR];

	//
	//
	HGS.EchoWriteDisable = Regs[GRA_FLG] & 0x20;
	break;

  case 0x1D: // 29
	HGS.Latch_EDL = Regs[GRA_EDL];
	HGS.Latch_ESA = Regs[GRA_ESA];

	if(HGS.KPollCycle)
	 HGS.IKON &= ~HGS.Latch_IKON;

	//
	//
	if(!HGS.EchoWriteDisable)
	 WriteEchoBuffer(0);

	HGS.EchoWriteDisable = Regs[GRA_FLG] & 0x20;
	break;

  case 0x1E: // 30
	if(!HGS.EchoWriteDisable)
	 WriteEchoBuffer(1);
	HGS.EchoAccum[0] = HGS.EchoAccum[1] = 0;

	 //for(unsigned i = 0; i < 8; i++)
	 //{
	 // if(KONCounter[i] < 9)
	 //  KONCounter[i]++;
	 //}

	if(HGS.KPollCycle)
	{
	 HGS.Latch_KOFF = Regs[GRA_KOFF];
	 HGS.Latch_IKON = HGS.IKON;

	 //for(unsigned i = 0; i < 8; i++)
	 //{
	 // if(HGS.Latch_IKON & (1U << i))
	 //  KONCounter[i] = 0;
	 //}
	}
	HGS.KPollCycle = !HGS.KPollCycle;

	ClockRC();

	if(CheckRC(Regs[GRA_FLG] & 0x1F))
	{
	 HGS.NoiseVal = (HGS.NoiseVal >> 1) | (((HGS.NoiseVal << 14) ^ (HGS.NoiseVal << 13)) & 0x4000);
	}

	//
	//
	//
	HGS.EchoBase = HGS.Latch_ESA << 8;

	if(!HGS.EchoOffset)
	 HGS.EchoBound = (HGS.Latch_EDL & 0xF) << 11;

	HGS.EchoOffset += 4;
	if(HGS.EchoOffset >= HGS.EchoBound)
	 HGS.EchoOffset = 0;

	//
	// Order is important..
	//
	V3c(0);
	break;

  case 0x1F:	//31
	V4(0);
	V1(2);
	break;
 }

 SPC700_IOHandler = &DSP_Cycle<(which + 1) & 0x1F>;
}

static void DSP_Reset(bool powering_up)
{
 SPC700_IOHandler = &DSP_Cycle<0>;

 memset(Regs, 0, sizeof(Regs));
 memset(&HGS, 0, sizeof(HGS));
 memset(Voices, 0, sizeof(Voices));

 Regs[GRA_FLG] = 0xE0;
 HGS.EchoWriteDisable = true;

 OutputBufPos = 0;

 HGS.NoiseVal = 0x4000;

 HGS.KPollCycle = false;

 ResetRC();
}

static INLINE uint8 DSP_Read(uint8 A)
{
 return Regs[A & 0x7F];
}

static INLINE void DSP_Write(uint8 A, uint8 V)
{
 //if((A & 0xF0) == 0x40 && ((A & 0xF) <= 0x09)) //0x02 || (A & 0xF) == 0x03)
 // fprintf(stderr, "DSP Write: 0x%02x 0x%02x\n", A, V);

 if(MDFN_LIKELY(A < 0x80))
 {
  if(A == GRA_ENDX)
  {
   V = 0;
   HGS.Pending_ENDX = V;
  }

  if(A == GRA_KON)
  {
   HGS.IKON = V;
  }

  if((A & 0xF) == VRO_ENVX)
   Voices[A >> 4].Pending_ENVX = V;

  if((A & 0xF) == VRO_OUTX)
   Voices[A >> 4].Pending_OUTX = V;

  Regs[A] = V;
 }
}

static void MDFN_COLD DSP_Init(void)
{
 Resampler = NULL;
 ResampLastRate = 0;
}

static void MDFN_COLD DSP_Kill(void)
{
 if(Resampler)
 {
  delete Resampler;
  Resampler = NULL;
 }
}

static void DSP_StartFrame(double dsp_rate, double rate)
{
 if(ResampLastRate != rate)
 {
  if(Resampler)
  {
   delete Resampler;
   Resampler = NULL;
  }

  if(rate)
  {
   Resampler = new OwlResampler(dsp_rate, rate, MDFN_GetSettingF("snes_faust.resamp_rate_error"), 10, MDFN_GetSettingUI("snes_faust.resamp_quality"), 1.1);

   for(unsigned i = 0; i < 2; i++)
    Resampler->ResetBufResampState(&ResampBuf[i]);
  }

  ResampLastRate = rate;
 }
}

static int32 DSP_EndFrame(int16* SoundBuf)
{
 int32 ret = 0;

 //printf("%d\n", ret);
 if(SoundBuf && Resampler)
 {
#if 0
  ret = OutputBufPos;

  for(unsigned i = 0; i < OutputBufPos * 2; i++)
   SoundBuf[i] = (int32)(&ResampBuf[i & 1].BufPudding()->f)[i >> 1] >> 8;
#else
  for(unsigned i = 0; i < 2; i++)
   ret = Resampler->Resample(&ResampBuf[i], OutputBufPos, SoundBuf + i, 0xFFFF);	// FIXME 0xFFFF
#endif
  //ret = OutputBufPos;
  //memcpy(SoundBuf, OutputBuf, OutputBufPos * sizeof(int16) * 2);
  //OutputBufPos = 0;
 }
 else
 {
  for(unsigned i = 0; i < 2; i++)
   ResampBuf[i].ResampleSkipped(OutputBufPos);
 }

 OutputBufPos = 0;

 return ret;
}

static void DSP_StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 uint8 DSP_CycPhase = 0;

 #define DSPCPH(n) { if(&DSP_Cycle<n> == SPC700_IOHandler) DSP_CycPhase = n; }
 DSPCPH(0x00) 
 DSPCPH(0x01)
 DSPCPH(0x02) 
 DSPCPH(0x03) 
 DSPCPH(0x04) 
 DSPCPH(0x05) 
 DSPCPH(0x06) 
 DSPCPH(0x07) 
 DSPCPH(0x08) 
 DSPCPH(0x09) 
 DSPCPH(0x0A) 
 DSPCPH(0x0B) 
 DSPCPH(0x0C) 
 DSPCPH(0x0D) 
 DSPCPH(0x0E) 
 DSPCPH(0x0F) 
 DSPCPH(0x10) 
 DSPCPH(0x11)
 DSPCPH(0x12) 
 DSPCPH(0x13) 
 DSPCPH(0x14) 
 DSPCPH(0x15) 
 DSPCPH(0x16) 
 DSPCPH(0x17) 
 DSPCPH(0x18) 
 DSPCPH(0x19) 
 DSPCPH(0x1A) 
 DSPCPH(0x1B) 
 DSPCPH(0x1C) 
 DSPCPH(0x1D) 
 DSPCPH(0x1E) 
 DSPCPH(0x1F) 
 #undef DSPCPH

 SFORMAT StateRegs[] =
 {
  SFARRAY(Regs, 0x80),

  SFVAR(HGS.KPollCycle),
  SFVAR(HGS.RateCounter),
  SFVAR(HGS.NoiseVal),
  SFARRAY16(HGS.Accum, 2),
  SFARRAY16(HGS.EchoAccum, 2),
  SFVAR(HGS.IKON),
  SFVAR(HGS.Pending_ENDX),
  SFVAR(HGS.Latch_IKON),
  SFVAR(HGS.Latch_KOFF),
  SFVAR(HGS.Latch_PMON),
  SFVAR(HGS.Latch_NON),
  SFVAR(HGS.Latch_EON),
  SFVAR(HGS.Latch_DIR),
  SFVAR(HGS.EchoWriteDisable),
  SFVAR(HGS.Latch_EDL),
  SFVAR(HGS.Latch_ESA),

  SFARRAY(HGS.Latch_FIR, 8),

  SFARRAY16(HGS.EchoFIROut, 2),

  SFARRAY16(&HGS.EchoFIRBuf[0][0], sizeof(HGS.EchoFIRBuf) / sizeof(HGS.EchoFIRBuf[0][0])),
  SFVAR(HGS.EchoFIRBufPos),

  SFVAR(HGS.EchoBase),
  SFVAR(HGS.EchoOffset),
  SFVAR(HGS.EchoBound),

  #define SFVOICE(n)				\
	SFVAR(Voices[n].BRR_Addr),		\
	SFVAR(Voices[n].BRR_Offs),		\
	SFVAR(Voices[n].BRR_Header),		\
	SFARRAY(Voices[n].BRR_Data, 2),		\
	SFARRAY16(Voices[n].RB, 12 * 2),	\
	SFVAR(Voices[n].RB_Pos),		\
	SFVAR(Voices[n].RB_In),			\
	SFVAR(Voices[n].Latch_SRCN),		\
	SFVAR(Voices[n].Addr),			\
	SFVAR(Voices[n].StartReload),		\
	SFVAR(Voices[n].LoopReload),		\
	SFVAR(Voices[n].Latch_ADSR1),		\
	SFVAR(Voices[n].ADSRPhase),		\
	SFVAR(Voices[n].ADSRLevel),		\
	SFVAR(Voices[n].ADSRBentFastNext),	\
	SFVAR(Voices[n].Pending_ENVX),		\
	SFVAR(Voices[n].Pending_OUTX),		\
	SFVAR(Voices[n].CurSample),		\
	SFVAR(Voices[n].Pitch),			\
	SFVAR(Voices[n].Phase)

  SFVOICE(0),
  SFVOICE(1),
  SFVOICE(2),
  SFVOICE(3),
  SFVOICE(4),
  SFVOICE(5),
  SFVOICE(6),
  SFVOICE(7),
  #undef SFVOICE

  SFVAR(OutputL),

  SFVAR(DSP_CycPhase),

//  SFVAR(sawthing),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "DSP");

 if(load)
 {
  HGS.EchoFIRBufPos &= 0x7;

  for(unsigned n = 0; n < 8; n++)
  {
   Voices[n].BRR_Offs &= 0x6;
   Voices[n].RB_Pos %= 12;
  }

  DSP_CycPhase &= 0x1F;
  #define DSPCPHS(n) { if(n == DSP_CycPhase) SPC700_IOHandler = &DSP_Cycle<n>; }
  DSPCPHS(0x00)
  DSPCPHS(0x01)
  DSPCPHS(0x02) 
  DSPCPHS(0x03) 
  DSPCPHS(0x04) 
  DSPCPHS(0x05) 
  DSPCPHS(0x06) 
  DSPCPHS(0x07) 
  DSPCPHS(0x08) 
  DSPCPHS(0x09) 
  DSPCPHS(0x0A) 
  DSPCPHS(0x0B) 
  DSPCPHS(0x0C) 
  DSPCPHS(0x0D) 
  DSPCPHS(0x0E) 
  DSPCPHS(0x0F) 
  DSPCPHS(0x10) 
  DSPCPHS(0x11)
  DSPCPHS(0x12) 
  DSPCPHS(0x13) 
  DSPCPHS(0x14) 
  DSPCPHS(0x15) 
  DSPCPHS(0x16) 
  DSPCPHS(0x17) 
  DSPCPHS(0x18) 
  DSPCPHS(0x19) 
  DSPCPHS(0x1A) 
  DSPCPHS(0x1B) 
  DSPCPHS(0x1C) 
  DSPCPHS(0x1D) 
  DSPCPHS(0x1E) 
  DSPCPHS(0x1F) 
  #undef DSPCPHS

 }

 if(data_only)
 {
  ResampBuf[0].StateAction(sm, load, data_only, "RESBUF0", OutputBufPos);
  ResampBuf[1].StateAction(sm, load, data_only, "RESBUF1", OutputBufPos);
 }
}
