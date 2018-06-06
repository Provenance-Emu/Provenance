#include "mapinc.h"

static uint8 CHRBanks[4], PRGBank16;
static uint8 WRAM[8192];

static void Sync(void)
{
 setprg16(0x8000, PRGBank16);
 for(int x = 0; x < 4; x++)
  setchr2(x * 2048, CHRBanks[x]);
}

static DECLFW(M190PWrite)
{
 PRGBank16 = ((A >> 11) & 0x8) | (V & 0x7);
 Sync();
}

static DECLFW(M190CWrite)
{
 CHRBanks[A & 0x3] = V;
 Sync();
}

static void Power(CartInfo *info)
{
 for(int x = 0; x < 4; x++)
  CHRBanks[x] = x;
 PRGBank16 = 0;
 Sync();
 setprg16(0xc000, 0);
 setprg8r(0x10, 0x6000, 0);
 if(!info->battery)
  memset(WRAM, 0xFF, 8192);
}

static int StateAction(StateMem *sm, int load, int data_only)
{
 SFORMAT StateRegs[] =
 {
  SFPTR8(CHRBanks, 4),
  SFVAR(PRGBank16),
  SFPTR8(WRAM, 8192),
  SFEND
 };

 int ret = MDFNSS_StateAction(sm, load, data_only, StateRegs, "MAPR");
 if(load)
  Sync();
 return(ret);
}

int Mapper190_Init(CartInfo *info)
{
 SetWriteHandler(0x8000, 0x9FFF, M190PWrite);
 SetWriteHandler(0xC000, 0xDFFF, M190PWrite);
 SetWriteHandler(0xA000, 0xBFFF, M190CWrite);
 SetWriteHandler(0x6000, 0x7FFF, CartBW);
 SetReadHandler(0x6000, 0xFFFF, CartBR);
 info->Power = Power;
 info->StateAction = StateAction;
 SetupCartPRGMapping(0x10, WRAM, 8192, 1);
 if(info->battery)
 {
  memset(WRAM, 0xFF, 8192);
  info->SaveGame[0] = WRAM;
  info->SaveGameLen[0] = 8192;
 }
 return(1);
}

