#ifndef __PCEFAST_PCECD_Drive_H
#define __PCEFAST_PCECD_Drive_H

#include <mednafen/sound/Blip_Buffer.h>

namespace PCE_Fast
{

typedef int32 pcecd_drive_timestamp_t;

struct pcecd_drive_bus_t
{
 // Data bus(FIXME: we should have a variable for the target and the initiator, and OR them together to be truly accurate).
 uint8 DB;

 uint32 signals;
};

extern pcecd_drive_bus_t cd_bus; // Don't access this structure directly by name outside of pcecd_drive.c, but use the macros below.

// Signals under our(the "target") control.
#define PCECD_Drive_IO_mask	0x001
#define PCECD_Drive_CD_mask	0x002
#define PCECD_Drive_MSG_mask	0x004
#define PCECD_Drive_REQ_mask	0x008
#define PCECD_Drive_BSY_mask	0x010

// Signals under the control of the initiator(not us!)
#define PCECD_Drive_kingRST_mask	0x020
#define PCECD_Drive_kingACK_mask	0x040
#define PCECD_Drive_kingSEL_mask	0x100

#define BSY_signal ((const bool)(cd_bus.signals & PCECD_Drive_BSY_mask))
#define ACK_signal ((const bool)(cd_bus.signals & PCECD_Drive_kingACK_mask))
#define RST_signal ((const bool)(cd_bus.signals & PCECD_Drive_kingRST_mask))
#define MSG_signal ((const bool)(cd_bus.signals & PCECD_Drive_MSG_mask))
#define SEL_signal ((const bool)(cd_bus.signals & PCECD_Drive_kingSEL_mask))
#define REQ_signal ((const bool)(cd_bus.signals & PCECD_Drive_REQ_mask))
#define IO_signal ((const bool)(cd_bus.signals & PCECD_Drive_IO_mask))
#define CD_signal ((const bool)(cd_bus.signals & PCECD_Drive_CD_mask))

#define DB_signal ((const uint8)cd_bus.DB)

#define PCECD_Drive_GetDB() DB_signal
#define PCECD_Drive_GetBSY() BSY_signal
#define PCECD_Drive_GetIO() IO_signal
#define PCECD_Drive_GetCD() CD_signal
#define PCECD_Drive_GetMSG() MSG_signal
#define PCECD_Drive_GetREQ() REQ_signal

// Should we phase out getting these initiator-driven signals like this(the initiator really should keep track of them itself)?
#define PCECD_Drive_GetACK() ACK_signal
#define PCECD_Drive_GetRST() RST_signal
#define PCECD_Drive_GetSEL() SEL_signal

void PCECD_Drive_Power(pcecd_drive_timestamp_t system_timestamp);
void PCECD_Drive_SetDB(uint8 data);

// These PCECD_Drive_Set* functions are kind of misnomers, at least in comparison to the PCECD_Drive_Get* functions...
// They will set/clear the bits corresponding to the KING's side of the bus.
void PCECD_Drive_SetACK(bool set);
void PCECD_Drive_SetSEL(bool set);
void PCECD_Drive_SetRST(bool set);

uint32 PCECD_Drive_Run(pcecd_drive_timestamp_t);
void PCECD_Drive_ResetTS(void);

enum
{
 PCECD_Drive_IRQ_DATA_TRANSFER_DONE = 1,
 PCECD_Drive_IRQ_DATA_TRANSFER_READY,
 PCECD_Drive_IRQ_MAGICAL_REQ,
};

void PCECD_Drive_GetCDDAValues(int16 &left, int16 &right);

void PCECD_Drive_Init(int CDDATimeDiv, Blip_Buffer* lrbufs, uint32 TransferRate, uint32 SystemClock, void (*IRQFunc)(int), void (*SSCFunc)(uint8, int)) MDFN_COLD;
void PCECD_Drive_Close(void) MDFN_COLD;

void PCECD_Drive_SetTransferRate(uint32 TransferRate);
void PCECD_Drive_SetCDDAVolume(unsigned vol); // vol of 65536 = 1.0 = maximum.
int PCECD_Drive_StateAction(StateMem *sm, int load, int data_only, const char *sname);

void PCECD_Drive_SetDisc(bool tray_open, CDIF *cdif, bool no_emu_side_effects = false) MDFN_COLD;

}

#endif
