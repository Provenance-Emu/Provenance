/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

#ifndef _SPC7110_H_
#define _SPC7110_H_

#define SPC7110_DECOMP_BUFFER_SIZE	64

// for snapshot only
struct SSPC7110Snapshot
{
	uint8	r4801;
	uint8	r4802;
	uint8	r4803;
	uint8	r4804;
	uint8	r4805;
	uint8	r4806;
	uint8	r4807;
	uint8	r4808;
	uint8	r4809;
	uint8	r480a;
	uint8	r480b;
	uint8	r480c;

	uint8	r4811;
	uint8	r4812;
	uint8	r4813;
	uint8	r4814;
	uint8	r4815;
	uint8	r4816;
	uint8	r4817;
	uint8	r4818;

	uint8	r481x;

	bool8	r4814_latch;			// bool
	bool8	r4815_latch;			// bool

	uint8	r4820;
	uint8	r4821;
	uint8	r4822;
	uint8	r4823;
	uint8	r4824;
	uint8	r4825;
	uint8	r4826;
	uint8	r4827;
	uint8	r4828;
	uint8	r4829;
	uint8	r482a;
	uint8	r482b;
	uint8	r482c;
	uint8	r482d;
	uint8	r482e;
	uint8	r482f;

	uint8	r4830;
	uint8	r4831;
	uint8	r4832;
	uint8	r4833;
	uint8	r4834;

	uint32	dx_offset;				// unsigned
	uint32	ex_offset;				// unsigned
	uint32	fx_offset;				// unsigned

	uint8	r4840;
	uint8	r4841;
	uint8	r4842;

	int32	rtc_state;				// enum RTC_State
	int32	rtc_mode;				// enum RTC_Mode
	uint32	rtc_index;				// unsigned

	uint32	decomp_mode;			// unsigned
	uint32	decomp_offset;			// unsigned

	uint8	decomp_buffer[SPC7110_DECOMP_BUFFER_SIZE];

	uint32	decomp_buffer_rdoffset;	// unsigned
	uint32	decomp_buffer_wroffset;	// unsigned
	uint32	decomp_buffer_length;	// unsigned

	struct ContextState
	{
		uint8	index;
		uint8	invert;
	}	context[32];
};

extern struct SSPC7110Snapshot	s7snap;

void S9xInitSPC7110 (void);
void S9xResetSPC7110 (void);
void S9xSPC7110PreSaveState (void);
void S9xSPC7110PostLoadState (int);
void S9xSetSPC7110 (uint8, uint16);
uint8 S9xGetSPC7110 (uint16);
uint8 S9xGetSPC7110Byte (uint32);
uint8 * S9xGetBasePointerSPC7110 (uint32);

#endif
