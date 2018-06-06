#ifndef __WSWAN_MEMORY_H
#define __WSWAN_MEMORY_H

namespace MDFN_IEN_WSWAN
{

extern uint8 wsRAM[65536];
extern uint8 *wsCartROM;
extern uint32 eeprom_size;
extern uint8 wsEEPROM[2048];

MDFN_FASTCALL uint8 WSwan_readmem20(uint32);
MDFN_FASTCALL void WSwan_writemem20(uint32 address,uint8 data);

MDFN_FASTCALL uint8 WSwan_readmem20_WW(uint32);
MDFN_FASTCALL void WSwan_writemem20_WW(uint32 address,uint8 data);

void WSwan_MemoryInit(bool lang, bool IsWSC, uint32 ssize, bool IsWW) MDFN_COLD;
void WSwan_MemoryKill(void) MDFN_COLD;

void WSwan_MemoryLoadNV(void);
void WSwan_MemorySaveNV(void);


void WSwan_CheckSoundDMA(void);
void WSwan_MemoryStateAction(StateMem *sm, const unsigned load, const bool data_only);
void WSwan_MemoryReset(void);
MDFN_FASTCALL void WSwan_writeport(uint32 IOPort, uint8 V);
MDFN_FASTCALL uint8 WSwan_readport(uint32 number);

MDFN_FASTCALL void WSwan_writeport_WW(uint32 IOPort, uint8 V);
MDFN_FASTCALL uint8 WSwan_readport_WW(uint32 number);

enum
{
 MEMORY_GSREG_ROMBBSLCT = 0,
 MEMORY_GSREG_BNK1SLCT,
 MEMORY_GSREG_BNK2SLCT,
 MEMORY_GSREG_BNK3SLCT,
};


uint32 WSwan_MemoryGetRegister(const unsigned int id, char *special, const uint32 special_len);
void WSwan_MemorySetRegister(const unsigned int id, uint32 value);

}

#endif
