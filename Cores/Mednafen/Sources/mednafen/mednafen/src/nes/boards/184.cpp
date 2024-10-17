#include "mapinc.h"

static uint8 latch;
static bool fzalt;

static void Sync(void)
{
 if(fzalt)
 {
  setprg16(0x8000, latch & 0x7);
 }
 else
 {
  setchr4(0x0000, latch & 0x7);
  setchr4(0x1000, (latch >> 4) & 0x7);
 }
}

static DECLFW(Mapper184_write)
{
 latch = V & 0x77;
 Sync();
}

static void Power(CartInfo *info)
{
 latch = 0;
 setchr8(0);
 setprg32(0x8000, ~0U);
 Sync();
}

static int StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] = 
 {
  SFVAR(latch),
  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");
 if(load)
  Sync();
 return(ret);
}

int Mapper184_Init(CartInfo *info)
{
 fzalt = (CHRsize[0] <= 8192 && PRGsize[0] > 32768);

 SetWriteHandler(0x6000, 0x7FFF, Mapper184_write);
 SetReadHandler(0x8000, 0xFFFF, CartBR);

 info->Power = Power;
 info->StateAction = StateAction;

 return(1);
}

