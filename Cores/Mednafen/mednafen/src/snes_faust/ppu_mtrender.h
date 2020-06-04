#include <atomic>
#include <mednafen/MThreading.h>

namespace MDFN_IEN_SNES_FAUST
{

namespace PPU_MTRENDER
{

struct PPU_S
{
 uint32 LineTarget;
 uint32 scanline;

 uint8 Status[2];	// $3E and $3F.

 uint8 ScreenMode;	// $33
 uint8 INIDisp;
 uint8 BGMode;
 uint8 Mosaic;
 uint8 MosaicYOffset;

 uint8 BGSC[4];

 uint8 BGNBA[2];

 uint8 BGOFSPrev;
 uint16 BGHOFS[4];
 uint16 BGVOFS[4];

 uint16 VRAM_Addr;
 bool VMAIN_IncMode;
 unsigned VMAIN_AddrInc;
 unsigned VMAIN_AddrTransMaskA;
 unsigned VMAIN_AddrTransShiftB;
 unsigned VMAIN_AddrTransMaskC;

 uint8 M7Prev;
 uint8 M7SEL;
 int16 M7Matrix[4];
 int16 M7Center[2];
 int16 M7HOFS;
 int16 M7VOFS;

 bool CGRAM_Toggle;
 uint8 CGRAM_Buffer;
 uint8 CGRAM_Addr;
 uint16 CGRAM[256];

 uint8 MSEnable;
 uint8 SSEnable;

 uint8 WMSettings[3];
 uint8 WMMainEnable;
 uint8 WMSubEnable;
 uint16 WMLogic;
 uint8 WindowPos[2][2];
 unsigned WindowPieces[5];	// Derived data, calculated at start of rendering for a scanline.

 uint8 CGWSEL;
 uint8 CGADSUB;
 uint16 FixedColor;

 uint8 OBSEL;
 uint8 OAMADDL;
 uint8 OAMADDH;
 uint8 OAM_Buffer;
 uint32 OAM_Addr;
 uint8 OAM[512];
 uint8 OAMHI[32];

 uint16 VRAM[32768];
 //
 //
 //
 union
 {
  struct
  {
   int16 x;
   uint8 y_offset;
   uint8 tilebase;
   uint8 paloffs;
   uint8 prio;
   uint8 w;
   uint8 h;
   uint8 hfxor;
   bool n;
  } SpriteList[32];

  uint32 objbuf[8 + 256 + 8];
 };

 unsigned SpriteTileCount;
 uint16 SpriteTileTab[16];
 struct
 {
  //uint64 td;	// 4bpp->8bpp, |'d with palette offset + 128; 8-bits * 8
  uint32 tda;
  uint32 tdb;
  int32 x;
  uint32 prio_or;
 } SpriteTileList[34];
 //
 //
 //
 uint8 Sprite_WHTab[8][2][2];
 uint8 inctab[4];
 uint32 ttab[4][3];
 //
 EmulateSpecStruct* es;
 uint32 (*DoHFilter)(void* const t_in, const uint32 w, const bool hires);
 uint32 HFilter_PrevW;
 bool HFilter_Auto512;
 bool HFilter_Out512;
};

MDFN_HIDE extern struct PPU_S PPU;

#define GLBVAR(x) static auto& x = PPU.x;
 GLBVAR(LineTarget)
 GLBVAR(scanline)
 GLBVAR(Status)
 GLBVAR(ScreenMode)
 GLBVAR(INIDisp)
 GLBVAR(BGMode)
 GLBVAR(Mosaic)
 GLBVAR(MosaicYOffset)
 GLBVAR(BGSC)
 GLBVAR(BGNBA)
 GLBVAR(BGOFSPrev)
 GLBVAR(BGHOFS)
 GLBVAR(BGVOFS)
 GLBVAR(VRAM_Addr)
 GLBVAR(VMAIN_IncMode)
 GLBVAR(VMAIN_AddrInc)
 GLBVAR(VMAIN_AddrTransMaskA)
 GLBVAR(VMAIN_AddrTransShiftB)
 GLBVAR(VMAIN_AddrTransMaskC)
 GLBVAR(M7Prev)
 GLBVAR(M7SEL)
 GLBVAR(M7Matrix)
 GLBVAR(M7Center)
 GLBVAR(M7HOFS)
 GLBVAR(M7VOFS)
 GLBVAR(CGRAM_Toggle)
 GLBVAR(CGRAM_Buffer)
 GLBVAR(CGRAM_Addr)
 GLBVAR(CGRAM)
 GLBVAR(MSEnable)
 GLBVAR(SSEnable)
 GLBVAR(WMSettings)
 GLBVAR(WMMainEnable)
 GLBVAR(WMSubEnable)
 GLBVAR(WMLogic)
 GLBVAR(WindowPos)
 GLBVAR(WindowPieces)
 GLBVAR(CGWSEL)
 GLBVAR(CGADSUB)
 GLBVAR(FixedColor)
 GLBVAR(OBSEL)
 GLBVAR(OAMADDL)
 GLBVAR(OAMADDH)
 GLBVAR(OAM_Buffer)
 GLBVAR(OAM_Addr)
 GLBVAR(OAM)
 GLBVAR(OAMHI)
 GLBVAR(VRAM)

 GLBVAR(es)
 GLBVAR(DoHFilter)
 GLBVAR(HFilter_PrevW)
 GLBVAR(HFilter_Auto512)
 GLBVAR(HFilter_Out512)
#undef GLBVAR

enum
{
 COMMAND_BASE = 0x80,

 COMMAND_EXIT,
 COMMAND_RENDER_LINE,
 COMMAND_RESET_LINE_TARGET,
 COMMAND_ENTER_VBLANK,
 COMMAND_FETCH_SPRITE_DATA
};

struct WQ_Entry
{
 uint8 Command;
 uint8 Arg8;
};

struct ITC_S
{
 uint8 padding0[64];
 std::array<WQ_Entry, 65536> WQ;
 uint8 padding1[64];
 size_t WritePos;
 size_t ReadPos;
 //
 uint8 padding2[64 - sizeof(WritePos) - sizeof(ReadPos)];
 std::atomic_int_least32_t TMP_WritePos;
 std::atomic_int_least32_t TMP_ReadPos;

 MThreading::Sem* RT_WakeupSem;
 MThreading::Sem* WakeupSem;
 MThreading::Thread* RThread;
};

MDFN_HIDE extern struct ITC_S ITC;

static void Wakeup(bool wait_until_empty = false)
{
 //printf("Sending wakeup.\n");
 ITC.TMP_WritePos.store(ITC.WritePos, std::memory_order_release);
 ITC.ReadPos = ITC.TMP_ReadPos.load(std::memory_order_acquire);

 if(ITC.ReadPos != ITC.WritePos)
 {
  MThreading::Sem_Post(ITC.RT_WakeupSem);

  if(wait_until_empty)
  {
   do
   {
    MThreading::Sem_TimedWait(ITC.WakeupSem, 1);
    ITC.ReadPos = ITC.TMP_ReadPos.load(std::memory_order_acquire);
   } while(ITC.ReadPos != ITC.WritePos);
  }
 }
}

static MDFN_HOT void WWQ(uint8 Command, uint8 Arg8 = 0)
{
 WQ_Entry* e = &ITC.WQ[ITC.WritePos];

 e->Command = Command;
 e->Arg8 = Arg8;
 //
 size_t nwp = (ITC.WritePos + 1) % ITC.WQ.size();
/*
 while(MDFN_UNLIKELY(nwp == ITC.ReadPos))
 {
  SNES_DBG("[PPUMT] fifo full\n");
  // FIXME, more efficient solution
  Wakeup();
  MThreading::WaitSemTimeout(ITC.WakeupSem, 15);
 }
*/
 if(MDFN_UNLIKELY(nwp == ITC.ReadPos))
 {
  SNES_DBG("[PPUMT] fifo full\n");
  // FIXME, more efficient solution
  Wakeup(true);
 }
 //
 ITC.WritePos = nwp;
}

static INLINE void MTIF_ResetLineTarget(bool PAL, bool ilaceon, bool field)
{
 //printf("Reset line target\n");
 WWQ(COMMAND_RESET_LINE_TARGET, PAL | (ilaceon << 1) | (field << 2));
}

static INLINE void MTIF_EnterVBlank(bool PAL, const bool skip)
{
 WWQ(COMMAND_ENTER_VBLANK, PAL | (skip << 7));
 if(skip)
  Wakeup();
}

static INLINE void MTIF_Sync(void)
{
 //uint64 st = Time::MonoUS();
 //unsigned borp = 0;
 Wakeup(true);
 //printf("End frame: %lld, %u\n", (long long)(Time::MonoUS() - st), borp);
}

static INLINE void MTIF_RenderLine(uint32 l)
{
 //printf("RenderLine %d\n", l);
 WWQ(COMMAND_RENDER_LINE, l);
 if((l & 0x3) == 0x1 || l == 0xE0 || l == 0xEF)
  Wakeup();
 else
 {
  ITC.TMP_WritePos.store(ITC.WritePos, std::memory_order_release);
  ITC.ReadPos = ITC.TMP_ReadPos.load(std::memory_order_acquire);
 }
}

static INLINE void MTIF_FetchSpriteData(signed line_y)
{
 assert((signed)(uint8)line_y == line_y);
 WWQ(COMMAND_FETCH_SPRITE_DATA, line_y);
}

static INLINE void MTIF_Write(uint8 A, uint8 V)
{
 WWQ(A, V);
}

static INLINE void MTIF_Read(uint8 A)
{
 WWQ(A, 0);
}

void MTIF_Init(const uint64 affinity) MDFN_COLD;
void MTIF_Reset(bool powering_up) MDFN_COLD;
void MTIF_StartFrame(EmulateSpecStruct* espec, const unsigned hfilter);
void MTIF_Kill(void) MDFN_COLD;
}
}
