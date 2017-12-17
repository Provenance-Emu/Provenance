#ifndef __MDFN_SNES_FAUST_CPU_H
#define __MDFN_SNES_FAUST_CPU_H

namespace MDFN_IEN_SNES_FAUST
{

class CPU65816;

typedef uint8 (MDFN_FASTCALL *readfunc)(uint32 A);
typedef void (MDFN_FASTCALL *writefunc)(uint32 A, uint8 V);

struct CPU_Misc
{
 uint32 timestamp;
 uint32 next_event_ts;
 uint32 running_mask;

 enum
 {
  HALTED_NOT = 0,
  HALTED_WAI = 1,
  HALTED_STP = 2,
  HALTED_DMA = 3
 };

 uint8 halted;
 uint8 mdr;

 uint8 CombinedNIState;
 bool NMILineState;
 bool PrevNMILineState;

 readfunc ReadFuncs[256];	// A and B bus read handlers
 writefunc WriteFuncs[256];	// A and B bus write handlers

 readfunc ReadFuncsA[256];	// A-bus only read handlers
 writefunc WriteFuncsA[256];	// A-bus only write handlers

 // Direct, not through RWIndex.
 readfunc DM_ReadFuncsB[256];
 writefunc DM_WriteFuncsB[256];

 // +1 so we can avoid a masking for 16-bit reads/writes(note that this
 // may result in the address passed to the read/write handlers being
 // 0x1000000 instead of 0x000000 in some cases, so code with that in mind.
 uint8 RWIndex[256 * 65536 + 1];

 INLINE uint8 ReadA(uint32 A)
 {
  uint8 ret = ReadFuncsA[RWIndex[A]](A);

  mdr = ret;

  return ret;
 }

 INLINE void WriteA(uint32 A, uint8 V)
 {
  mdr = V;
  WriteFuncsA[RWIndex[A]](A, V);
 }

 INLINE uint8 ReadB(uint8 A)
 {
  uint8 ret = DM_ReadFuncsB[A](A);

  mdr = ret;

  return ret;
 }

 INLINE void WriteB(uint8 A, uint8 V)
 {
  mdr = V;
  DM_WriteFuncsB[A](A, V);
 }

 //
 //
 //
 void RunDMA(void);
 void EventHandler(void);
};

extern CPU_Misc CPUM;

INLINE uint8 CPU_Read(uint32 A)
{
 uint8 ret = CPUM.ReadFuncs[CPUM.RWIndex[A]](A);

 CPUM.mdr = ret;

 return ret;
}

INLINE void CPU_Write(uint32 A, uint8 V)
{
 CPUM.mdr = V;
 CPUM.WriteFuncs[CPUM.RWIndex[A]](A, V);
}

INLINE void CPU_IO(void)
{
 CPUM.timestamp += 6;
}

INLINE void CPU_SetIRQ(bool active)
{
 CPUM.CombinedNIState &= ~0x04;
 CPUM.CombinedNIState |= active ? 0x04 : 0x00;
}

INLINE void CPU_SetNMI(bool active)
{
 if((CPUM.NMILineState ^ active) & active)
  CPUM.CombinedNIState |= 0x01;

 CPUM.NMILineState = active;
}

void CPU_Init(void);
void CPU_Reset(bool powering_up);
void CPU_StateAction(StateMem* sm, const unsigned load, const bool data_only);
void CPU_Run(void);

INLINE void CPU_Exit(void)
{
 CPUM.running_mask = 0;
 CPUM.next_event_ts = 0;
}

}

#endif
