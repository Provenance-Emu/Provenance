#ifndef __MDFN_PCE_PCECD_H
#define __MDFN_PCE_PCECD_H

namespace MDFN_IEN_PCE
{

typedef struct
{
	double CDDA_Volume;
	double ADPCM_Volume;
	bool ADPCM_ExtraPrecision;
} PCECD_Settings;

enum
{
 CD_GSREG_BSY = 0,
 CD_GSREG_REQ,	// RO
 CD_GSREG_MSG,	// RO
 CD_GSREG_CD,	// RO
 CD_GSREG_IO,	// RO
 CD_GSREG_SEL,

 CD_GSREG_ADPCM_CONTROL,
 CD_GSREG_ADPCM_FREQ,
 CD_GSREG_ADPCM_CUR,
 CD_GSREG_ADPCM_WRADDR,
 CD_GSREG_ADPCM_RDADDR,
 CD_GSREG_ADPCM_LENGTH,
 CD_GSREG_ADPCM_PLAYNIBBLE,

 CD_GSREG_ADPCM_PLAYING,
 CD_GSREG_ADPCM_HALFREACHED,
 CD_GSREG_ADPCM_ENDREACHED,
};

uint32 PCECD_GetRegister(const unsigned int id, char *special, const uint32 special_len);
void PCECD_SetRegister(const unsigned int id, const uint32 value);


MDFN_FASTCALL int32 PCECD_Run(uint32 in_timestamp);
void PCECD_ResetTS(uint32 ts_base = 0);
void PCECD_ProcessADPCMBuffer(const uint32 rsc);

void PCECD_Init(const PCECD_Settings *settings, void (*irqcb)(bool), double master_clock, int32* adbuf, int32* hrbuf_l, int32* hrbuf_r) MDFN_COLD;
bool PCECD_SetSettings(const PCECD_Settings *settings);

void PCECD_Close() MDFN_COLD;

// Returns number of cycles until next CD event.
int32 PCECD_Power(uint32 timestamp);

MDFN_FASTCALL uint8 PCECD_Read(uint32 timestamp, uint32, int32 &next_event, const bool PeekMode = false);
MDFN_FASTCALL int32 PCECD_Write(uint32 timestamp, uint32, uint8 data) MDFN_WARN_UNUSED_RESULT;

bool PCECD_IsBRAMEnabled();

void PCECD_StateAction(StateMem *sm, const unsigned load, const bool data_only);

void ADPCM_PeekRAM(uint32 Address, uint32 Length, uint8 *Buffer);
void ADPCM_PokeRAM(uint32 Address, uint32 Length, const uint8 *Buffer);

}
#endif

