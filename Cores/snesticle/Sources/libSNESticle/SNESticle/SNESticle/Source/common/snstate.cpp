
#include <string.h>
#include <stdio.h>
#include "types.h"
#include "console.h"
#include "snes.h"
#include "snstate.h"

void SnesSystem::SaveState(void *pState, Int32 nStateBytes)
{
    if (nStateBytes == sizeof(SnesStateT))
    {
        SaveState((SnesStateT *)pState);
    }
}

void SnesSystem::RestoreState(void *pState, Int32 nStateBytes)
{
    if (nStateBytes == sizeof(SnesStateT))
    {
        RestoreState((SnesStateT *)pState);
    }
}

Int32 SnesSystem::GetStateSize()
{
    return sizeof(SnesStateT);
}



void SnesSystem::SaveState(SnesStateT *pState)
{
	// set tag
	pState->Tag[0] = 'S';
	pState->Tag[1] = 'N';
	pState->Tag[2] = 'S';
	pState->Tag[3] = '\0';

	pState->uFrame = m_uFrame;
	pState->uLine  = m_uLine;

	// copy cpu state
	pState->CPU.Regs = m_Cpu.Regs;
	pState->CPU.Cycles = m_Cpu.Cycles;
	pState->CPU.Counter[0] = m_Cpu.Counter[0];
	pState->CPU.Counter[1] = m_Cpu.Counter[1];
	pState->CPU.Counter[2] = m_Cpu.Counter[2];
	pState->CPU.Counter[3] = m_Cpu.Counter[3];
	pState->CPU.uSignal    = m_Cpu.uSignal;

	pState->SPC.Regs = m_Spc.Regs;
	pState->SPC.Cycles = m_Spc.Cycles;
	pState->SPC.Counter[0] = m_Spc.Counter[0];
	pState->SPC.Counter[1] = m_Spc.Counter[1];
	pState->SPC.uCycleShift = 0;

	m_PPU.SaveState(&pState->PPU);
	m_DMAC.SaveState(&pState->DMAC);
	m_IO.SaveState(&pState->IO);
	m_SpcDsp.SaveState(&pState->SPCDSP);
	m_SpcDspMixer.SaveState(&pState->SPCDSP);
	m_SpcIO.SaveState(&pState->SPCIO);

	// save memory state
	memcpy(pState->Ram, m_Ram, sizeof(pState->Ram));
	memcpy(pState->SRam, m_SRam, sizeof(pState->Ram));

    // copy spc ram
    pState->SPC.bRomEnable = m_Spc.bRomEnable;

    SNSPCSetRomEnable(&m_Spc, FALSE);
	memcpy(pState->SpcRam, m_Spc.Mem, SNSPC_MEM_SIZE);
    SNSPCSetRomEnable(&m_Spc,  pState->SPC.bRomEnable);
}

Bool SnesSystem::RestoreState(SnesStateT *pState)
{
	if (memcmp(pState->Tag, "SNS", 4))
	{
		return FALSE;
	}

	m_uFrame = pState->uFrame;
	m_uLine  = pState->uLine;

	// restore state
	m_Cpu.Regs = pState->CPU.Regs;
	m_Cpu.Cycles = pState->CPU.Cycles;
	m_Cpu.Counter[0] = pState->CPU.Counter[0];
	m_Cpu.Counter[1] = pState->CPU.Counter[1];
	m_Cpu.Counter[2] = pState->CPU.Counter[2];
	m_Cpu.Counter[3] = pState->CPU.Counter[3];
	m_Cpu.nAbortCycles = 0;
	m_Cpu.uSignal    = pState->CPU.uSignal;

	m_Spc.Regs = pState->SPC.Regs;
	m_Spc.Cycles = pState->SPC.Cycles;
	m_Spc.Counter[0] = pState->SPC.Counter[0];
	m_Spc.Counter[1] = pState->SPC.Counter[1];
	m_Spc.uPad = 0;


	m_PPU.RestoreState(&pState->PPU);
	m_DMAC.RestoreState(&pState->DMAC);
	m_IO.RestoreState(&pState->IO);
	m_SpcDsp.RestoreState(&pState->SPCDSP);
	m_SpcDspMixer.RestoreState(&pState->SPCDSP);
	m_SpcIO.RestoreState(&pState->SPCIO);

	// restore memory state
	memcpy(m_Ram, pState->Ram, sizeof(m_Ram));
	memcpy(m_SRam, pState->SRam, sizeof(m_SRam));

    // copy spc ram
    SNSPCSetRomEnable(&m_Spc, FALSE);
	memcpy(m_Spc.Mem, pState->SpcRam, SNSPC_MEM_SIZE);
    SNSPCSetRomEnable(&m_Spc, pState->SPC.bRomEnable);


	// set fast or slow rom
	if (m_IO.m_Regs.memsel & 1)
	{
		SetFastRom();
	} else
	{
		SetSlowRom();
	}

	return TRUE;
}


void SnesIO::SaveState(struct SNStateIOT *pState)
{
	pState->Input = m_Input;
	pState->Regs = m_Regs;
}
void SnesIO::RestoreState(struct SNStateIOT *pState)
{
	m_Input = pState->Input;
	m_Regs = pState->Regs;
}

void SNSpcIO::SaveState(struct SNStateSPCIOT *pState)
{
	pState->Regs = m_Regs;
}
void SNSpcIO::RestoreState(struct SNStateSPCIOT *pState)
{
	m_Regs = pState->Regs;
}

void SnesDMAC::SaveState(struct SNStateDMACT *pState)
{
	pState->m_HDMAEnable = m_HDMAEnable;
	pState->m_MDMAEnable = m_MDMAEnable;
	memcpy(pState->m_Channels, m_Channels, sizeof(pState->m_Channels));
}

void SnesDMAC::RestoreState(struct SNStateDMACT *pState)
{
	m_HDMAEnable = pState->m_HDMAEnable;
	m_MDMAEnable = pState->m_MDMAEnable;
	memcpy(m_Channels, pState->m_Channels, sizeof(m_Channels));
}

void SnesPPU::SaveState(struct SNStatePPUT *pState)
{
	pState->Regs  = m_Regs;
	memcpy(pState->m_CGRAM,   m_CGRAM, sizeof(pState->m_CGRAM));
	memcpy(pState->m_VRAM,    m_VRAM, sizeof(pState->m_VRAM));
	pState->m_OAM = m_OAM;
}

void SnesPPU::RestoreState(struct SNStatePPUT *pState)
{
	m_Regs = pState->Regs;
	memcpy(m_CGRAM,   pState->m_CGRAM, sizeof(m_CGRAM));
	memcpy(m_VRAM,    pState->m_VRAM,  sizeof(m_VRAM));
	m_OAM = pState->m_OAM;
}


void SNSpcDsp::SaveState(struct SNStateSPCDSPT *pState)
{
	memcpy(pState->m_Regs, m_Regs, sizeof(m_Regs));
}

void SNSpcDsp::RestoreState(struct SNStateSPCDSPT *pState)
{
	memcpy(m_Regs, pState->m_Regs, sizeof(m_Regs));
}

void SNSpcDspMix::SaveState(struct SNStateSPCDSPT *pState)
{
	memcpy(pState->m_Channels, m_Channels, sizeof(m_Channels));
}

void SNSpcDspMix::RestoreState(struct SNStateSPCDSPT *pState)
{
	memcpy(m_Channels, pState->m_Channels, sizeof(m_Channels));
}


void _SNStateMemDiff(Char *pTag, Uint8 *pA, Uint8 *pB, Int32 nBytes)
{
    Int32 iOffset;

    for (iOffset=0; iOffset < nBytes; iOffset++)
    {
        if (pA[iOffset]!=pB[iOffset])
        {
            ConDebug("%s: %04X %02X %02X\n", pTag, iOffset, pA[iOffset], pB[iOffset]);
        }
    }

}

void SNStateCompare(SnesStateT *pStateA, SnesStateT *pStateB)
{
    _SNStateMemDiff("Mem", pStateA->Ram, pStateB->Ram, SNES_RAMSIZE);
    _SNStateMemDiff("SpcMem", pStateA->SpcRam, pStateB->SpcRam, SNSPC_RAM_SIZE);
    _SNStateMemDiff("SRM", pStateA->SRam, pStateB->SRam, SNES_SRAMSIZE);
    _SNStateMemDiff("Cpu", (Uint8 *)&pStateA->CPU, (Uint8 *)&pStateB->CPU, sizeof(pStateA->CPU));
    _SNStateMemDiff("SPC", (Uint8 *)&pStateA->SPC, (Uint8 *)&pStateB->SPC, sizeof(pStateA->SPC));
	_SNStateMemDiff("SPCIO", (Uint8 *)&pStateA->SPCIO, (Uint8 *)&pStateB->SPCIO, sizeof(pStateA->SPCIO));
    _SNStateMemDiff("DSP", (Uint8 *)&pStateA->SPCDSP, (Uint8 *)&pStateB->SPCDSP, sizeof(pStateA->SPCDSP));
    _SNStateMemDiff("IO", (Uint8 *)&pStateA->IO, (Uint8 *)&pStateB->IO, sizeof(pStateA->IO));
    _SNStateMemDiff("PPU", (Uint8 *)&pStateA->PPU, (Uint8 *)&pStateB->PPU, sizeof(pStateA->PPU));
    _SNStateMemDiff("DMAC", (Uint8 *)&pStateA->DMAC, (Uint8 *)&pStateB->DMAC, sizeof(pStateA->DMAC));

}



