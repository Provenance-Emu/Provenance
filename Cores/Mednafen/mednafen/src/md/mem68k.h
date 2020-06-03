#ifndef _MEM68K_H_
#define _MEM68K_H_

namespace MDFN_IEN_MD
{

/* Function prototypes */
unsigned int m68k_read_bus_8(unsigned int address);
unsigned int m68k_read_bus_16(unsigned int address);

void m68k_lockup_w_8(unsigned int address, unsigned int value);
void m68k_lockup_w_16(unsigned int address, unsigned int value);
unsigned int m68k_lockup_r_8(unsigned int address);
unsigned int m68k_lockup_r_16(unsigned int address);

extern uint32 obsim;

MDFN_FASTCALL void Main68K_BusRESET(bool state);
MDFN_FASTCALL void Main68K_BusRMW(uint32 A, uint8 (MDFN_FASTCALL *cb)(M68K*, uint8));
MDFN_FASTCALL unsigned Main68K_BusIntAck(uint8 level);
MDFN_FASTCALL uint8 Main68K_BusRead8(uint32 A);
MDFN_FASTCALL uint16 Main68K_BusRead16(uint32 A);
MDFN_FASTCALL uint16 Main68K_BusReadInstr(uint32 A);
MDFN_FASTCALL void Main68K_BusWrite8(uint32 A, uint8 V);
MDFN_FASTCALL void Main68K_BusWrite16(uint32 A, uint16 V);

// Debug(ger) functions:
MDFN_FASTCALL uint8 Main68K_BusPeek8(uint32 A);
MDFN_FASTCALL uint16 Main68K_BusPeek16(uint32 A);
MDFN_FASTCALL void Main68K_BusPoke8(uint32 A, uint8 V);

}

#endif /* _MEM68K_H_ */
