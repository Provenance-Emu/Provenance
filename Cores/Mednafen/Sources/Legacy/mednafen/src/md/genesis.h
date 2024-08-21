
#ifndef _GENESIS_H_
#define _GENESIS_H_

namespace MDFN_IEN_MD
{

MDFN_HIDE extern uint8 (MDFN_FASTCALL *MD_ExtRead8)(uint32 address);
MDFN_HIDE extern uint16 (MDFN_FASTCALL *MD_ExtRead16)(uint32 address);
MDFN_HIDE extern void (MDFN_FASTCALL *MD_ExtWrite8)(uint32 address, uint8 value);
MDFN_HIDE extern void (MDFN_FASTCALL *MD_ExtWrite16)(uint32 address, uint16 value);

class MDVDP;

/* Global variables */
alignas(8) MDFN_HIDE extern uint8 work_ram[0x10000];
alignas(8) MDFN_HIDE extern uint8 zram[0x2000];
MDFN_HIDE extern uint8 zbusreq;
MDFN_HIDE extern uint8 zbusack;
MDFN_HIDE extern uint8 zreset;
MDFN_HIDE extern uint8 zirq;
MDFN_HIDE extern uint32 zbank;
MDFN_HIDE extern uint8 gen_running;
MDFN_HIDE extern M68K Main68K;
MDFN_HIDE extern MDVDP MainVDP;

/* Function prototypes */
void gen_init(void);
void gen_reset(bool poweron);
void gen_shutdown(void);
int gen_busack_r(void);
void gen_busreq_w(int state);
void gen_reset_w(int state);
void gen_bank_w(int state);
int z80_irq_callback(int param);
void m68k_irq_ack_callback(int int_level);

}

#endif /* _GEN_H_ */

