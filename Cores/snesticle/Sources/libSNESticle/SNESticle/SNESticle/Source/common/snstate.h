

#ifndef _SNSTATE_H
#define _SNSTATE_H


struct SNStateCPUT
{
	SNCpuRegsT	Regs;
	Int32		Cycles;							// cycle counter for current execution
	Int32		Counter[SNCPU_COUNTER_NUM];		// counter(s)
	Uint8		uSignal;
};

struct SNStatePPUT
{
	SnesPPURegsT	Regs;
	SnesColor16T	m_CGRAM[SNESPPU_CGRAM_NUM];			// 16-bit palette
	Uint16			m_VRAM[SNESPPU_VRAM_NUMWORDS];
	SnesOAMT		m_OAM;
};

struct SNStateIOT
{
	Emu::SysInputT		Input;
	SnesIORegsT			Regs;
};

struct SNStateDMACT
{
	SnesDMAChT	m_Channels[SNESDMAC_CHANNEL_NUM];
	Uint8		m_MDMAEnable;
	Uint8		m_HDMAEnable;
};



struct SNStateSPCIOT
{
	SNSpcIORegsT		Regs;
};

struct SNStateSPCT
{
	SNSpcRegsT	Regs;
	Int32		Cycles;
	Int32		Counter[SNSPC_COUNTER_NUM];
    Bool        bRomEnable;
	Uint8		uCycleShift;
};

struct SNStateSPCDSPT
{
	Uint8			m_Regs[SNSPCDSP_REG_NUM];
	SNSpcChannelT	m_Channels[SNSPCDSP_CHANNEL_NUM];
};


struct SnesStateT
{
	Uint8			Tag[4];
	Uint32			uFrame;
	Uint32			uLine;

	SNStateCPUT		CPU;
	SNStatePPUT		PPU;
	SNStateIOT		IO;
	SNStateDMACT	DMAC;
	SNStateSPCT		SPC;
	SNStateSPCDSPT	SPCDSP;
	SNStateSPCIOT	SPCIO;

	Uint8			Ram[SNES_RAMSIZE];
	Uint8			SpcRam[SNSPC_RAM_SIZE];
	Uint8			SRam[SNES_SRAMSIZE];
};

void SNStateCompare(SnesStateT *pStateA, SnesStateT *pStateB);


#endif
