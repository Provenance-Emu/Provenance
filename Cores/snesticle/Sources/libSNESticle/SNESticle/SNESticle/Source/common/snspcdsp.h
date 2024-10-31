

#ifndef _SNSPCDSP_H
#define _SNSPCDSP_H

#include "snqueue.h"
#include "snspcmixi.h"

#define SNSPCDSP_WRITEQUEUE (TRUE)
#define SNSPCDSP_MAXMIXERS (2)

#define SNSPCDSP_CHANNEL_NUM 8
#define SNSPCDSP_ENVELOPE_BITS (23)
#define SNSPCDSP_ENVELOPE_MAX (1 << SNSPCDSP_ENVELOPE_BITS)
#define SNSPCDSP_ENVELOPE_MIN (0)
#define SNSPCDSP_SAMPLERATE (32000)

#define SNSPCDSP_ECHOBUFFER_SIZE (512 * 2 * 15 * 48000 / SNSPCDSP_SAMPLERATE)

enum SNSpcDspRegE
{
	SNSPCDSP_REG_VOLL            = 0x00,
	SNSPCDSP_REG_VOLR            = 0x01,
	SNSPCDSP_REG_PITCHLO         = 0x02,
	SNSPCDSP_REG_PITCHHI         = 0x03,
	SNSPCDSP_REG_SRCN            = 0x04,
	SNSPCDSP_REG_ADSR1           = 0x05,
	SNSPCDSP_REG_ADSR2           = 0x06,
	SNSPCDSP_REG_GAIN            = 0x07,
	SNSPCDSP_REG_ENVX            = 0x08,
	SNSPCDSP_REG_OUTX            = 0x09,
	
	SNSPCDSP_REG_MVOLL           = 0x0C,
    SNSPCDSP_REG_MVOLR           = 0x1C,
    SNSPCDSP_REG_EVOLL           = 0x2C,
    SNSPCDSP_REG_EVOLR           = 0x3C,
    SNSPCDSP_REG_KON             = 0x4C,
    SNSPCDSP_REG_KOFF            = 0x5C,
    SNSPCDSP_REG_FLG             = 0x6C,
    SNSPCDSP_REG_ENDX            = 0x7C,

    SNSPCDSP_REG_EFB             = 0x0D,
    SNSPCDSP_REG_PMON            = 0x2D,
    SNSPCDSP_REG_NOV             = 0x3D,
    SNSPCDSP_REG_EON             = 0x4D,
    SNSPCDSP_REG_DIR             = 0x5D,
    SNSPCDSP_REG_ESA             = 0x6D,
    SNSPCDSP_REG_EDL             = 0x7D,

    SNSPCDSP_REG_ECHOFIR0        = 0x0F,
    SNSPCDSP_REG_ECHOFIR1        = 0x1F,
    SNSPCDSP_REG_ECHOFIR2        = 0x2F,
    SNSPCDSP_REG_ECHOFIR3        = 0x3F,
    SNSPCDSP_REG_ECHOFIR4        = 0x4F,
    SNSPCDSP_REG_ECHOFIR5        = 0x5F,
    SNSPCDSP_REG_ECHOFIR6        = 0x6F,
    SNSPCDSP_REG_ECHOFIR7        = 0x7F,

    SNSPCDSP_REG_NUM = 128
};

enum SNSpcEnvStateE
{
	SNSPCDSP_ENVSTATE_SILENCE,
	SNSPCDSP_ENVSTATE_KEYON,

	SNSPCDSP_ENVSTATE_ATTACK,
	SNSPCDSP_ENVSTATE_DECAY,
	SNSPCDSP_ENVSTATE_SUSTAIN,
	SNSPCDSP_ENVSTATE_RELEASE,
	SNSPCDSP_ENVSTATE_DIRECT,
	SNSPCDSP_ENVSTATE_INCREASELINEAR,
	SNSPCDSP_ENVSTATE_INCREASEBENTLINE,
	SNSPCDSP_ENVSTATE_DECREASELINEAR,
	SNSPCDSP_ENVSTATE_DECREASEEXP,

	SNSPCDSP_ENVSTATE_NUM,
};




struct SNSpcVoiceRegsT
{
	Int8	vol_l;
	Int8	vol_r;
	Uint8	pitch_lo;
	Uint8	pitch_hi;
	Uint8	srcn;
	Uint8	adsr1;
	Uint8	adsr2;
	Uint8	gain;
	Uint8	envx;
	Uint8	outx;
	Uint8	pad[6];
};

struct SNSpcChannelT
{
	SNSpcEnvStateE	eEnvState;		// envelope state
	Int32			iEnvelope;		// envelope position 16.16
	Int32			nEnvCount;		// number of ticks until next envelope update (16.16)

	Int32			iPhase;			// sample position within current block (16.16?)
	Uint16			uBlockAddr;		// address in spc mem of next block
	Uint16			uOldBlockAddr;

	Uint8			envx;
	Uint8			outx;
	Uint8			endx;
	Uint8			pad;

	Int16			BlockData[2][16];	// decoded data of current block plus previous 2 samples
};

struct SNSpcFIRFilterT
{
	Int16	Line[16];		// filter line (doubled)
	Int32	iPos;			// position within filter line
};

struct SNSpcEchoT
{
	SNSpcFIRFilterT	Filter[2];		// filter for left/right
	Uint16			uEchoAddr;
};


class    SNSpcDsp
{
	Uint8			m_Regs[SNSPCDSP_REG_NUM];

	Uint8			*m_pMem;		// pointer to sample memory

	ISNSpcDspMix	*m_pMixer[SNSPCDSP_MAXMIXERS];;

	#if SNSPCDSP_WRITEQUEUE
	SNQueue	m_Queue;
	#endif

	void	KeyOn(Int32 iChannel);
	void	KeyOff(Int32 iChannel);

public:

	SNSpcDsp();

	inline const SNSpcVoiceRegsT *GetVoiceRegs(Int32 iChannel) {return (SNSpcVoiceRegsT *)&m_Regs[iChannel<<4]; }
	Uint16	GetSampleDir(Uint8 uSrcN, Uint32 uOffset);

	void	SetMixer(Int32 iMixer, class ISNSpcDspMix	*pMixer) {m_pMixer[iMixer] = pMixer;}

	Bool	EnqueueWrite(Uint32 uCycle, Uint32 uAddr, Uint8 uData);
	void	Sync(Uint32 uCycle);
	void	Sync(void);

	void	Reset();
	void	Write8(Uint32 uAddr, Uint8 uData);
	Uint8	Read8(Uint32 uAddr);

	inline Uint8	GetReg(SNSpcDspRegE eReg) {return m_Regs[eReg];}
	inline void	SetMem(Uint8 *pMem) {m_pMem = pMem;}
	inline Uint8 *GetMem() {return m_pMem;}

	void	UpdateFlags(ISNSpcDspMix *pMixer);

	void	SaveState(struct SNStateSPCDSPT *pState);
	void	RestoreState(struct SNStateSPCDSPT *pState);
};









#endif





