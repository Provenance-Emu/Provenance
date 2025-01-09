#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include "types.h"
#include "snes.h"
#include "rendersurface.h"
#include "console.h"
#include "prof.h"
#include "sntiming.h"
#include "sndebug.h"


#define SNES_SYNCPPUEVERYLINE (CODE_DEBUG && 0) 


void SnesSystem::SyncSPC(Int32 uExtra)
{
	Int32 nCycles;

#if SNES_DEBUG
    if (g_bStateDebug)
    {
        ConDebug("SyncSPC cpu=%06d spc=%06d\n", 
            SNCPUGetCounter(&m_Cpu, SNCPU_COUNTER_FRAME),
            SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_FRAME)
            );

    }
#endif      

    Int32 CpuTime = SNCPUGetCounter(&m_Cpu, SNCPU_COUNTER_FRAME);
    Int32 SpcTime = SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_FRAME);

    // get cycle count 
    nCycles = CpuTime - SpcTime - m_Spc.Cycles;
    nCycles += uExtra;
    if (nCycles > (SNSPC_CYCLE * SNES_SPCMINCYCLES))
    {
        //SnesDebug("SNSPCExec: %d\n", nCycles);
        // execute SPC
        PROF_ENTER("SNSpcExecute");
        SNSPCExecute(&m_Spc, nCycles);
        PROF_LEAVE("SNSpcExecute");

#if SNSPCIO_WRITEQUEUE
        m_SpcIO.SyncQueueAll();
#endif
    }

#if SNES_DEBUG
    if (g_bStateDebug)
    {
        ConDebug("DoneSyncSPC cpu=%06d spc=%06d\n", 
            SNCPUGetCounter(&m_Cpu, SNCPU_COUNTER_FRAME),
            SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_FRAME)
            );

    }
#endif      

    
    
    
    
    /*
    // get cycle count 
    nCycles = SNCPUGetCounter(&m_Cpu, SNCPU_COUNTER_FRAME) - SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_FRAME);
    nCycles += uExtra;

    // get cycle count 
    PROF_ENTER("SNSpcExecute");
    SNSPCExecuteToCycle( &m_Spc, nCycles );
    PROF_LEAVE("SNSpcExecute");

#if SNSPCIO_WRITEQUEUE
    m_SpcIO.SyncQueueAll();
#endif
*/


    /*
	// get cycle count 
	nCycles = SNCPUGetCounter(&m_Cpu, SNCPU_COUNTER_FRAME) - SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_FRAME);
	nCycles += uExtra;
	if (nCycles > (SNSPC_CYCLE * SNES_SPCMINCYCLES))
	{
		//SnesDebug("SNSPCExec: %d\n", nCycles);
		// execute SPC
        PROF_ENTER("SNSpcExecute");
		SNSPCExecute(&m_Spc, nCycles);
        PROF_LEAVE("SNSpcExecute");

		#if SNSPCIO_WRITEQUEUE
		m_SpcIO.SyncQueueAll();
		#endif
	}
    */
}


inline void SnesSystem::SyncPPU()
{
	// sync ppu to current line
	m_PPU.Sync(m_uLine);
}

#if SNES_DEBUG
Uint8 SNCPU_TRAPFUNC SnesSystem::Read2000Debug(SNCpuT *pCpu, Uint32 uAddr)
{
    Uint8 uData = Read2000(pCpu, uAddr);
    if (Snes_bDebugIO)
        SnesDebugReadData(uAddr, uData);
    return uData;
}
#endif


Uint8 SNCPU_TRAPFUNC SnesSystem::Read2000(SNCpuT *pCpu, Uint32 uAddr)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;
	SnesPPURegsT *pPPURegs = (SnesPPURegsT *)pSnes->m_PPU.GetRegs();

	uAddr &= 0xFFFF;

/*	if (uAddr < 0x2140)
	{
		// ppu read
		return pSnes->m_PPU.Read8(uAddr);
	} else*/
	switch (uAddr)
	{

	case 0x2137: // slhv
		//SnesDebug("readppu_slhv\n");
		pPPURegs->ophct.Reg.w = (SNCPUGetCounter(&pSnes->m_Cpu, SNCPU_COUNTER_LINE) + 14) >> 2;
		pPPURegs->opvct.Reg.w = pSnes->m_uLine & 0x1FF;
		//pPPURegs->opvct.Reg.w |= (pPPURegs->opvct.Reg.w << 8) & 0xFE00;
		//pPPURegs->opvct.Reg.w = 0xE1;
		return 0;

	case 0x2138: // read oam
		#if SNPPU_WRITEQUEUE
		pSnes->SyncPPU();
		#endif
        return pSnes->m_PPU.ReadOAMDATA();

	case 0x213c: // ophct
		return pPPURegs->ophct.Read8();

	case 0x213d: // opvct
		return pPPURegs->opvct.Read8();

	case 0x213e: // stat77
		return pPPURegs->stat77;

	case 0x213f: // stat78
		pPPURegs->ophct.Reset();
		pPPURegs->opvct.Reset();
		return pPPURegs->stat78; // NTSC/PAL bit 4
	case 0x2134: //mpyl
		#if SNPPU_WRITEQUEUE
		pSnes->SyncPPU();
		#endif
		return pPPURegs->mpyl;
	case 0x2135: //mpym
		#if SNPPU_WRITEQUEUE
		pSnes->SyncPPU();
		#endif
		return pPPURegs->mpym;
	case 0x2136: //mpyh
		#if SNPPU_WRITEQUEUE
		pSnes->SyncPPU();
		#endif
		return pPPURegs->mpyh;
	case 0x2139:
		#if SNPPU_WRITEQUEUE
		pSnes->SyncPPU();
		#endif
		return pSnes->m_PPU.ReadVMDATAL();
	case 0x213a:	// vmdatah (video port data hi)
		#if SNPPU_WRITEQUEUE
		pSnes->SyncPPU();
		#endif
		return pSnes->m_PPU.ReadVMDATAH();

	case 0x213b:
		#if SNPPU_WRITEQUEUE
		pSnes->SyncPPU();
		#endif
		return pSnes->m_PPU.ReadCGDATA();

	case 0x2140: // apui00
	case 0x2141: // apui01
	case 0x2142: // apui02
	case 0x2143: // apui03
		pSnes->SyncSPC();
		return pSnes->m_SpcIO.m_Regs.apu_r[uAddr & 3];

	case 0x2180:	// WMDATA
		{
			Uint8 uData;
			// read from ram
			uData = pSnes->m_Ram[pSnes->m_IO.m_Regs.wmadd];
			// increment memory address
			pSnes->m_IO.m_Regs.wmadd++;
			pSnes->m_IO.m_Regs.wmadd &= 0x1FFFF;
			return uData;
		}

	default:
		#if SNES_DEBUG
        if (Snes_bDebugUnhandledIO)
            SnesDebugRead(uAddr);
		#endif
		break;
	}

	return uAddr >> 8;
}

//#define SNES_SPCWRITE_LATENCY (21)
#define SNES_SPCWRITE_LATENCY (0)

#if SNES_DEBUG
void SNCPU_TRAPFUNC SnesSystem::Write2000Debug(SNCpuT *pCpu, Uint32 uAddr, Uint8 uData)
{
    if (Snes_bDebugIO)
        SnesDebugWrite(uAddr, uData);
    Write2000(pCpu, uAddr, uData);
}
#endif

void SNCPU_TRAPFUNC SnesSystem::Write2000(SNCpuT *pCpu, Uint32 uAddr, Uint8 uData)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;

	uAddr &= 0xFFFF;

	if (uAddr < 0x2140)
	{
		// enqueue write to ppu, if it fails (full) then force a sync 
		#if SNPPU_WRITEQUEUE
		while (!pSnes->m_PPU.EnqueueWrite(pSnes->m_uLine, uAddr, uData))
		{
			// sync ppu
			pSnes->SyncPPU();
		}
		#else
		// sync ppu before writing to it
		pSnes->SyncPPU();

		// ppu write
		pSnes->m_PPU.Write8(uAddr, uData);
		#endif
	} else
	{
		switch(uAddr)
		{
			case 0x2140:	// apui00
			case 0x2141:	// apui01
			case 0x2142:	// apui02
			case 0x2143:	// apui03
				// theory:
				// sync for an EXTRA spc cycle here because write does not happen
				// until one cycle later

				#if SNSPCIO_WRITEQUEUE
				// enqueue write, if this fails then the queue is full!
				if (!pSnes->m_SpcIO.EnqueueWrite(SNCPUGetCounter(pCpu, SNCPU_COUNTER_FRAME) + SNES_SPCWRITE_LATENCY, uAddr & 3, uData))
				#endif
				{
					// sync spc immediately, this causes it to "catch up" so we can perform the write
					pSnes->SyncSPC(SNES_SPCWRITE_LATENCY);

					// perform write to spc
					pSnes->m_SpcIO.m_Regs.apu_w[uAddr & 3] =  uData;
				}

				break;

			case 0x2180:	// WMDATA
				// write directly to ram
				pSnes->m_Ram[pSnes->m_IO.m_Regs.wmadd] = uData;
				// increment memory address
				pSnes->m_IO.m_Regs.wmadd++;
				pSnes->m_IO.m_Regs.wmadd &= 0x1FFFF;
				break;
			case 0x2181:	// WMADDL
				pSnes->m_IO.m_Regs.wmadd &= ~0x0000FF;
				pSnes->m_IO.m_Regs.wmadd |= (uData & 0xFF) << 0;
				break;

			case 0x2182:	// WMADDM
				pSnes->m_IO.m_Regs.wmadd &= ~0x00FF00;
				pSnes->m_IO.m_Regs.wmadd |= (uData & 0xFF) << 8;
				break;

			case 0x2183:	// WMADDH
				pSnes->m_IO.m_Regs.wmadd &= ~0xFF0000;
				pSnes->m_IO.m_Regs.wmadd |= (uData & 0x01) << 16;
				break;

			case 0x2184:	// ?? dk country
				break;

			default:
				#if SNES_DEBUG
                if (Snes_bDebugUnhandledIO)
                    SnesDebugWrite(uAddr, uData);
				#endif
				break;
		}
	}
}

#if CODE_DEBUG
Uint8 _CPUHackMem[0x10000];
#endif


#if SNES_DEBUG
Uint8 SNCPU_TRAPFUNC SnesSystem::Read4000Debug(SNCpuT *pCpu, Uint32 uAddr)
{
    Uint8 uData = Read4000(pCpu, uAddr);
    if (Snes_bDebugIO)
        SnesDebugReadData(uAddr, uData);
    return uData;
}
#endif

Uint8 SNCPU_TRAPFUNC SnesSystem::Read4000(SNCpuT *pCpu, Uint32 uAddr)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;
	SnesIO *pIO = &pSnes->m_IO;

	uAddr &= 0xFFFF;

	if (uAddr >= 0x4300 && uAddr < 0x4380)
	{
		// read from DMA controller
		return pSnes->m_DMAC.Read8((uAddr>>4) & 7, uAddr & 0xF);
	} else
	switch (uAddr)
	{
    //
    // 40XX
    //
    case 0x4016:	// serial joystick port
        SNCPUConsumeCycles(&pSnes->m_Cpu, 2);       //access from 4000>41FF is 1.78mhz
        return pIO->ReadSerial0();
    case 0x4017:
        SNCPUConsumeCycles(&pSnes->m_Cpu, 2);       //access from 4000>41FF is 1.78mhz
        return pIO->ReadSerial1();

    //
    // 42XX
    //
    case 0x4202:	// wrmpya (multiplicand-a)
		return 0; // ? pIO->m_Regs.wrmpya
	case 0x4203:	// wrmpyb (multiplicand-b)
		return 0; // ? pIO->m_Regs.wrmpyb = uData;

    case 0x420B:	// mdmaen (DMA enable register)
        return pSnes->m_DMAC.GetMDMAEnable();
    case 0x420C:
        return pSnes->m_DMAC.GetHDMAEnable();

    case 0x4210:	// RDNMI
        {
            Uint8 uData = pIO->m_Regs.rdnmi;

            // clear RDNMI on read
            pIO->m_Regs.rdnmi &= ~0x80;

            // set new nmi signal
            SNCPUSignalNMI(pCpu, pIO->m_Regs.rdnmi & pIO->m_Regs.nmitimen & 0x80);
            return uData;
        }

    case 0x4211:	// TIMEUP 
        {
            Uint8 uData = pIO->m_Regs.timeup;
            pIO->m_Regs.timeup &= ~0x80;
            SNCPUSignalIRQ(pCpu, 0);
            return uData;
        }
    case 0x4212:	// HVBJOY
        return pIO->m_Regs.hvbjoy;

    case 0x4213:	// RDIO
        return 0;

	case 0x4214:	// RDDIVL
		return pIO->m_Regs.rddiv.b.l;

	case 0x4215:	// RDDIVH
		return pIO->m_Regs.rddiv.b.h;

	case 0x4216:	// RDMPYL
		return pIO->m_Regs.rdmpy.b.l;

	case 0x4217:	// RDMPYH
		return pIO->m_Regs.rdmpy.b.h;

	case 0x4218:	// JOY1L
		return pIO->m_Regs.joy1.b.l;
	case 0x4219:	// JOY1H
		return pIO->m_Regs.joy1.b.h;

	case 0x421A:	// JOY2L
		return pIO->m_Regs.joy2.b.l;
	case 0x421B:	// JOY2H
		return pIO->m_Regs.joy2.b.h;

	case 0x421C:	// JOY3L
		return pIO->m_Regs.joy3.b.l;
	case 0x421D:	// JOY3H
		return pIO->m_Regs.joy3.b.h;

	case 0x421E:	// JOY4L
		return pIO->m_Regs.joy4.b.l;
	case 0x421F:	// JOY4H
		return pIO->m_Regs.joy4.b.h;

	default:
		break;
	}
	#if SNES_DEBUG
    if (Snes_bDebugUnhandledIO)
	    SnesDebugRead(uAddr);
	#endif
	return uAddr >> 8;
}

#if SNES_DEBUG
void SNCPU_TRAPFUNC SnesSystem::Write4000Debug(SNCpuT *pCpu, Uint32 uAddr, Uint8 uData)
{
    if (Snes_bDebugIO)
        SnesDebugWrite(uAddr, uData);

    _CPUHackMem[uAddr & 0xFFFF]= uData;

    Write4000(pCpu, uAddr, uData);
}
#endif

void SNCPU_TRAPFUNC SnesSystem::Write4000(SNCpuT *pCpu, Uint32 uAddr, Uint8 uData)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;

	uAddr &= 0xFFFF;

	if (uAddr >= 0x4300 && uAddr < 0x4380)
	{
		// write to DMA controller
		pSnes->m_DMAC.Write8((uAddr>>4) & 7, uAddr & 0xF, uData);
	} else
	{
		SnesIO *pIO = &pSnes->m_IO;

		switch (uAddr)
		{
        case 0x4016:	// reset serial joystick port?
            SNCPUConsumeCycles(&pSnes->m_Cpu, 2);       //access from 4000>41FF is 1.78mhz
            pIO->WriteSerial(uData);
            break;

        case 0x4200:	// nmitimen
            pIO->m_Regs.nmitimen = uData;

            // unconfirmed:
            // should nmi be disabled if someone set 0 to nmitimen register?
            // this breaks final fight
            // has nmi enable been set to zero?
            if ( !( uData & 0x80 ))
            {
                // if so, disable 'BLANK NMI' for good
                if ( pIO->m_Regs.rdnmi & 0x80 )
                {
//                    pIO->m_Regs.rdnmi &= ~0x80;
                }
            }

            // have v-en and h-en been set to zero?
            if ( !(uData & (0x20|0x10)) )
            {
                if ( pIO->m_Regs.timeup & 0x80 )
                {
                    // remove timeup bit
                    pIO->m_Regs.timeup &= ~0x80;
                }
                // clear IRQ
                SNCPUSignalIRQ(pCpu, 0);
            }

            // set new nmi signal
            SNCPUSignalNMI(pCpu, pIO->m_Regs.rdnmi & pIO->m_Regs.nmitimen & 0x80);
            break;

        case 0x4201:	// wrio (programmable i/o port)
            // confirmed:
            // setting this to a value will cause the h/v latching to be controlled
            // by external latching (v-count seemed to stick at E1)
            pIO->m_Regs.wrio = uData;
            break;

		case 0x4202:	// wrmpya (multiplicand-a)
			pIO->m_Regs.wrmpya = uData;
			break;
		case 0x4203:	// wrmpyb (multiplicand-b)
			pIO->m_Regs.wrmpyb = uData;

			// multiply
			pIO->m_Regs.rdmpy.w = pIO->m_Regs.wrmpya * pIO->m_Regs.wrmpyb;
			break;

		case 0x4204:	// wrdivl (multiplier-c low)
			pIO->m_Regs.wrdiv.b.l = uData;
			break;
		case 0x4205:	// wrdivh (multiplier-c high)
			pIO->m_Regs.wrdiv.b.h = uData;
			break;
		case 0x4206:	// wrdivb (divisor-b)
			pIO->m_Regs.wrdivb  = uData;
			if (uData!=0)
			{
				pIO->m_Regs.rddiv.w = pIO->m_Regs.wrdiv.w / pIO->m_Regs.wrdivb;
				pIO->m_Regs.rdmpy.w = pIO->m_Regs.wrdiv.w % pIO->m_Regs.wrdivb;
			} else
			{
                // divide by zero
				pIO->m_Regs.rddiv.w = 0xFFFF;
				pIO->m_Regs.rdmpy.w = pIO->m_Regs.wrdiv.w;
			}
			break;

        case 0x4207:	// htmel (video horizontal IRQ beam position)
            pIO->m_Regs.htime.b.l = uData;
            break;
        case 0x4208:	// htmeh (video horizontal IRQ beam position)
            pIO->m_Regs.htime.b.h = uData & 1;
            break;
        case 0x4209:	// vtmel (video vertical IRQ beam position)
            pIO->m_Regs.vtime.b.l = uData;
            break;
        case 0x420A:	// vtmeh (video vertical IRQ beam position)
            pIO->m_Regs.vtime.b.h = uData & 1;
            break;

		case 0x420B:	// mdmaen (DMA enable register)
			pSnes->m_DMAC.SetMDMAEnable(uData);
			if (uData != 0)
			{
                // we've got DMA, so abort execution
                SNCPUSignalDMA(pCpu, 1);
			}
			break;

		case 0x420C:	// hdmaen (HDMA enable register)
			pSnes->m_DMAC.SetHDMAEnable(uData);
			break;

        case 0x420D:	// memsel (cycle speed register)
            if ((pIO->m_Regs.memsel ^ uData) & 1)
            {
                if (uData & 1)
                {
                    pSnes->SetFastRom();
                } else
                {
                    pSnes->SetSlowRom();
                }
                pIO->m_Regs.memsel = uData;
            }
            break;

		case 0x4211:	// TIMEUP 
			pIO->m_Regs.timeup &= ~0x80;
			SNCPUSignalIRQ(pCpu, 0);
			break;

		case 0x4212:	// HVBJOY
			break;

		case 0x4214:	// RDDIVL
		case 0x4215:	// RDDIVH
		case 0x4216:	// RDMPYL
		case 0x4217:	// RDMPYH 
			break; // mario ??

		default:
			#if SNES_DEBUG
            if (Snes_bDebugUnhandledIO)
			    SnesDebugWrite(uAddr, uData);
			#endif
			break;
		}
	}

}

Uint8 SNCPU_TRAPFUNC SnesSystem::ReadMem(SNCpuT *pCpu, Uint32 uAddr)
{
//	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;
	#if SNES_DEBUG
    if (Snes_bDebugUnhandledIO)
	SnesDebugRead(uAddr);
	#endif
	return 0;
}


void SNCPU_TRAPFUNC SnesSystem::WriteMem(SNCpuT *pCpu, Uint32 uAddr, Uint8 uData)
{
//	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;
	#if SNES_DEBUG
    if (Snes_bDebugUnhandledIO)
        SnesDebugWrite(uAddr, uData);
	#endif
}

Uint8 SNCPU_TRAPFUNC SnesSystem::ReadSRAM(SNCpuT *pCpu, Uint32 uAddr)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;
	Uint8 *pSRAM =  pSnes->GetSRAM();
	return pSRAM[uAddr & (pSnes->m_uSramSize-1)];
}


void SNCPU_TRAPFUNC SnesSystem::WriteSRAM(SNCpuT *pCpu, Uint32 uAddr, Uint8 uData)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;
	Uint8 *pSRAM =  pSnes->GetSRAM();

	pSRAM[uAddr & (pSnes->m_uSramSize-1)] = uData;
}



Uint8 SNCPU_TRAPFUNC SnesSystem::ReadDSP1(SNCpuT *pCpu, Uint32 uAddr)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;

	switch (uAddr & 0xF000)
	{
	case 0x6000:
		return pSnes->m_pDsp->ReadData(uAddr & 0xFFF);
	case 0x7000:
		return pSnes->m_pDsp->ReadStatus(uAddr & 0xFFF);
	}
#if SNES_DEBUG
    if (Snes_bDebugUnhandledIO)
        SnesDebugRead(uAddr);
#endif
	return uAddr >> 8;
}


void SNCPU_TRAPFUNC SnesSystem::WriteDSP1(SNCpuT *pCpu, Uint32 uAddr, Uint8 uData)
{
	SnesSystem *pSnes = (SnesSystem *)pCpu->pUserData;

	switch (uAddr & 0xF000)
	{
	case 0x6000:
		pSnes->m_pDsp->WriteData(uAddr & 0xFFF, uData);
		break;
	default:
		// ??
		#if SNES_DEBUG
        if (Snes_bDebugUnhandledIO)
            SnesDebugWrite(uAddr, uData);
		#endif
		break;
	}

}




//
//
//








//
//
//

SnesSystem::SnesSystem()
{
	m_pRom			= NULL;

	// setup cpu
	SNCPUNew(&m_Cpu);
	m_Cpu.pUserData = (void *)this;

	m_uSramSize = 0;

	// setup spc
	SNSPCNew(&m_Spc);
	SNSPCSetTrapFunc(&m_Spc, SNSpcIO::Read8Trap, SNSpcIO::Write8Trap);
	m_Spc.pUserData  = (void *)&m_SpcIO;
	m_SpcIO.SetSpc(&m_Spc);
	m_SpcIO.SetSpcDsp(&m_SpcDsp);

	// link dsp with mixer(s)
	m_SpcDsp.SetMixer(0,&m_SpcDspMixer);
	m_SpcDsp.SetMixer(1,&m_SpcDspSilentMixer);
	m_SpcDspMixer.SetDsp(&m_SpcDsp);
	m_SpcDspSilentMixer.SetDsp(&m_SpcDsp);
	m_SpcDsp.SetMem(m_Spc.Mem);

	// setup dma controller
	m_DMAC.SetCPU(&m_Cpu);
	m_DMAC.SetPPU(&m_PPU);

	// setup ppu
	m_PPURender.SetPPU(&m_PPU);
	m_PPU.SetPPURender(&m_PPURender);

	m_pDsp = NULL;
}

SnesSystem::~SnesSystem()
{
	SetRom(NULL);
	SNCPUDelete(&m_Cpu);
	SNSPCDelete(&m_Spc);
	m_pDsp = NULL;
}

void SnesSystem::Reset()
{
	SetSlowRom();

	m_PPU.Reset();
	m_DMAC.Reset();
	m_IO.Reset();
	m_SpcIO.Reset();
	m_SpcDsp.Reset();
	m_SpcDspMixer.Reset();
	m_SpcDspSilentMixer.Reset();

	if (m_pDsp)
	{
		m_pDsp->Reset();
	}
	

#if CODE_DEBUG
	memset(_CPUHackMem, 0, sizeof(_CPUHackMem));
#endif

	memset(m_Ram, 0, sizeof(m_Ram));
	memset(m_SRam, 0, sizeof(m_SRam));

	// reset cpu
	SNCPUReset(&m_Cpu, true);
	SNSPCReset(&m_Spc, true);

	m_uFrame=0;
	m_uLine =0;
}

void SnesSystem::SoftReset()
{
	// reset cpu
	SNCPUReset(&m_Cpu, false);
	SNSPCReset(&m_Spc, false);
}


void SnesSystem::SetRom(class Emu::Rom *pRom)
{
	SetSnesRom((SnesRom *)pRom);
}

void SnesSystem::SetSnesRom(SnesRom *pRom)
{
	if (m_pRom)
	{
		// disconnect from current rom
		m_pRom = NULL;
	}

	m_pDsp = NULL;

	// set rom
	m_pRom = pRom;

	if (m_pRom)
	{
		// setup memory mapping for this rom
		MapMem(m_pRom->m_eMapping, m_pRom->m_Flags);
	} 
	else
	{
		// reset mapping
		SNCPUSetBank(&m_Cpu, 0, SNCPU_MEM_SIZE, NULL, TRUE);
		SNCPUSetTrap(&m_Cpu, 0, SNCPU_MEM_SIZE, NULL, NULL);
		m_uSramSize = 0;
	}
}

//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////



void SnesSystem::ExecuteCPU(Int32 nCycles)
{
    // increment cycle counter
    SNCPUAddCycles( &m_Cpu, nCycles );

    while (m_Cpu.Cycles > 0)
    {
        // process signal
        if (m_Cpu.uSignal & (SNCPU_SIGNAL_IRQ | SNCPU_SIGNAL_NMIEDGE | SNCPU_SIGNAL_RESET | SNCPU_SIGNAL_DMA))
        {
            if (m_Cpu.uSignal & SNCPU_SIGNAL_DMA)
            {
                // sync up PPU before DMA (only necessary for read dmas?)
                SyncPPU();

                PROF_ENTER("ProcessMDMA");
                // so, execute DMA for remainder of CPU time
                // this function automatically subtracts from the CPU cycle count as it transfers each byte
#if 1
                m_DMAC.ProcessMDMA();
#else
                {
                    int n = m_Cpu.Cycles;
                    m_Cpu.Cycles = 100000;
                    m_DMAC.ProcessMDMA();
                    m_Cpu.Cycles += n - 100000;
                }
#endif
                PROF_LEAVE("ProcessMDMA");

                // are all MDMAs complete?
                if (m_DMAC.GetMDMAEnable() == 0)
                {
                    // remove DMA signal
                    m_Cpu.uSignal &= ~SNCPU_SIGNAL_DMA;

                    // very interesting
                    #if SNES_DEBUG
                    if (m_Cpu.uSignal != 0)
                    {
                        // this means that a nmi occurred while we were in an dma
                        ConDebug("interesting");
                    }
                    #endif
                } 

                // continue...dont allow CPU to run unless it has cycle time available
                continue;
            } else
            if (m_Cpu.uSignal & SNCPU_SIGNAL_NMIEDGE)
            {
                // execute one instruction here first
                if (!(m_Cpu.uSignal & SNCPU_SIGNAL_WAI))
                {
                    SNCPUExecuteOne(&m_Cpu);
                }

                // perform nmi
                SNCPUNMI(&m_Cpu);
                // clear NMI edge signal
                m_Cpu.uSignal&= ~SNCPU_SIGNAL_NMIEDGE;
            } else
            if (m_Cpu.uSignal & SNCPU_SIGNAL_IRQ)
            {
                // attempt irq
                // irqs will always be attempted until signal has been cleared
                SNCPUIRQ(&m_Cpu);
            } else
            if (m_Cpu.uSignal & SNCPU_SIGNAL_RESET)
            {
                // perform reset (soft)
                SNCPUReset(&m_Cpu, FALSE);

                m_Cpu.uSignal&= ~SNCPU_SIGNAL_RESET;
            } 
        }			

        assert(m_DMAC.GetMDMAEnable() == 0);

        // run CPU!
        SNCPUExecute(&m_Cpu);
    }
}



void SnesSystem::ExecuteWithIRQ(Int32 nCycles, Int32 &nIRQCycles)
{
    if (nIRQCycles >= 0 && nIRQCycles < nCycles)
    {
        // execute up to h-irq
        ExecuteCPU(nIRQCycles);

        // set irq flag 
        m_IO.m_Regs.timeup |= 0x80;
        SNCPUSignalIRQ(&m_Cpu, 1);

        // execute rest of way
        ExecuteCPU(nCycles - nIRQCycles);
    }
    else
    {
        // just execute as normal
        ExecuteCPU(nCycles);
    }

    nIRQCycles -= nCycles;
}



void SnesSystem::ExecuteLine()
{
	SNCPUResetCounter(&m_Cpu, SNCPU_COUNTER_LINE);

    // don't trigger IRQ by default
    int nHIRQCycles = -1;

	// virq enabled?
	if (m_IO.m_Regs.nmitimen & 0x20)
	{
		if (m_uLine == m_IO.m_Regs.vtime.w)
		{
			// hirq enabled?
			if (m_IO.m_Regs.nmitimen & 0x10)
			{
				// calculate cycle time to perform h-irq
				nHIRQCycles = m_IO.m_Regs.htime.w * 4;

			} else
			{
				// trigger at beginning of line
				nHIRQCycles = 0;
			}
		}
	} else
	// hirq enabled?
	if (m_IO.m_Regs.nmitimen & 0x10)
	{
		// calculate cycle time to perform h-irq
		nHIRQCycles = m_IO.m_Regs.htime.w * 4;
	}

	PROF_ENTER("ExecLine");

	SNCPUConsumeCycles(&m_Cpu, SNES_LINECYCLEDELAY);

    // execute CPU during scanline
    ExecuteWithIRQ(SNES_CYCLESPERLINE - SNES_HBLANKCYCLES, nHIRQCycles);

	// set h-blank enable flag
	m_IO.m_Regs.hvbjoy|= 0x40;

    // are we not in vblank?
    if ( !(m_IO.m_Regs.hvbjoy & 0x80) )
    {
        // perform HDMA
        m_DMAC.ProcessHDMA();
    }

    // execute CPU during h-blank
    ExecuteWithIRQ(SNES_HBLANKCYCLES, nHIRQCycles);

	// clear h-blank enable flag
	m_IO.m_Regs.hvbjoy&= ~0x40;
	PROF_LEAVE("ExecLine");
}




void SnesSystem::ExecuteFrame(Emu::SysInputT  *pInput, CRenderSurface *pTarget, CMixBuffer *pSound, ModeE eMode)
{
    m_uLine = 0;

	m_IO.LatchInput(pInput);

	// reset frame cycle counter
	SNCPUResetCounter(&m_Cpu, SNCPU_COUNTER_FRAME);
    SNCPUResetCounter(&m_Cpu, SNCPU_COUNTER_LINE);
	SNSPCResetCounter(&m_Spc, SNCPU_COUNTER_FRAME);

#if SNES_DEBUG
    if (Snes_bDebugFrame)
        SnesDebug("frame\n");
#endif

	m_DMAC.BeginHDMA();

	m_PPURender.BeginRender(pTarget);
	m_PPU.BeginFrame();
	
	for (m_uLine=0; m_uLine < (224+1); m_uLine++)
	{
		#if SNES_SYNCPPUEVERYLINE
		SyncPPU();
		#endif

		ExecuteLine();
	}

	// sync ppu at end of frame (this ensures all rendering has been completed)
	SyncPPU();

	m_PPU.EndFrame();
	m_PPURender.EndRender();

    //ExecuteLine();
    //ExecuteLine();

	// confirmed:
	// nmi is triggered from hi->lo transition (edge level interrupt)
	// rdnmi flag is set at beginning of vbl
	// rdnmi flag is cleared at end of vbl
	// rdnmi flag is cleared on rdnmi read
	// nmi will trigger immediately if nmitimen flag is set while rdnmi flag is set

    PROF_ENTER("ExecVBLANK");
    // set vbl flag at start of vblank
    m_IO.m_Regs.hvbjoy|= 0x80;

	if (m_IO.m_Regs.nmitimen & 1)
	{
		// set joy enable flag at start of vblank
		m_IO.m_Regs.hvbjoy|= 0x01;
		m_IO.UpdateJoyPads();
	}

    // set 'BLANK NMI' flag at beginning of v-blank
    m_IO.m_Regs.rdnmi |= 0x80;
    SNCPUSignalNMI(&m_Cpu, m_IO.m_Regs.rdnmi & m_IO.m_Regs.nmitimen & 0x80);

    for ( ; m_uLine < 262; m_uLine++)
	{
		ExecuteLine();

		if (m_uLine==225+2) // * 60 = 4410 cycles long (3.10 scanlines)
		{
			// done reading joypad
			m_IO.m_Regs.hvbjoy&= ~0x01;
		}
	}

    // clear 'BLANK NMI' flag at end of v-blank
    m_IO.m_Regs.rdnmi &= ~0x80;
    SNCPUSignalNMI(&m_Cpu, m_IO.m_Regs.rdnmi & m_IO.m_Regs.nmitimen & 0x80);

	// clear vbl flag at end of vblank
	m_IO.m_Regs.hvbjoy&= ~0x80;
	PROF_LEAVE("ExecVBLANK");

	//SNCPUConsumeCycles(&m_Cpu, SNES_CYCLESPERLINE);
	//SNCPUExecute(&m_Cpu, SNES_CYCLESPERLINE);

	SyncPPU();
	SyncSPC();

	// update spc timers
	SNSpcTimerSync(&m_SpcIO.m_Regs.spc_timer[0], SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_TOTAL));
	SNSpcTimerSync(&m_SpcIO.m_Regs.spc_timer[1], SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_TOTAL));
	SNSpcTimerSync(&m_SpcIO.m_Regs.spc_timer[2], SNSPCGetCounter(&m_Spc, SNSPC_COUNTER_TOTAL));

	// mix non-deterministic mixer
	PROF_ENTER("SNSpcDspUpdate");
	m_SpcDspMixer.Mix(pSound);
	PROF_LEAVE("SNSpcDspUpdate");

	// ensure that all queued registers have been committed 
	m_SpcDsp.Sync();

	switch (eMode)
	{
		case MODE_INACCURATEDETERMINISTIC:
			m_SpcDsp.UpdateFlags(NULL);
			break;
		case MODE_ACCURATENONDETERMINISTIC:
			// update flags based on real mixer (This should produce most accurate sound, but is not deterministic)
			m_SpcDsp.UpdateFlags(&m_SpcDspMixer);
			break;
		case MODE_ACCURATEDETERMINISTIC:
			// mix silent mixer
			PROF_ENTER("SNSpcDspUpdateSilent");
			m_SpcDspSilentMixer.Mix(NULL);
			PROF_LEAVE("SNSpcDspUpdateSilent");

			// update spc flags based on deterministic mixer
			m_SpcDsp.UpdateFlags(&m_SpcDspSilentMixer);
			break;
	}

	m_uFrame++;
}


Int32 SnesSystem::GetSRAMBytes()
{
    if (m_pRom)
    {
        return m_pRom->GetSRAMBytes();
    } else
    {
        return 0;
    }               
}

Uint8 *SnesSystem::GetSRAMData()
{
    if (m_pRom && (m_pRom->GetSRAMBytes()>0))
    {
        return m_SRam;
    } else
    {
        return 0;
    }               

}

char *SnesSystem::GetString(StringE eString)
{
	switch(eString)
	{
		case STRING_SHORTNAME:	
			return "SNES";
		case STRING_FULLNAME:	
			return "Super Nintendo";
		case STRING_SRAMEXT:	
			return "srm";
		case STRING_STATEEXT:	
			return "sns";
		default:
			return NULL;
	}
}



#if SNES_DEBUG

/*static*/
Char *SnesSystem::GetRegName(Uint32 uAddr)
{
    uAddr &= 0xFFFF;

    switch (uAddr)
    {
    case 0x2134: return "mpyl";
    case 0x2135: return "mpym";
    case 0x2136: return "mpyh";
    case 0x2137: return "slhv";
    case 0x2138: return "oam";
    case 0x2139: return "vmdatal";
    case 0x213a: return "vmdatah";
    case 0x213b: return "cgdata";
    case 0x213c: return "ophct";
    case 0x213d: return "opvct";
    case 0x213e: return "stat77";
    case 0x213f: return "stat78";
    case 0x2140: return "apui00";
    case 0x2141: return "apui01";
    case 0x2142: return "apui02";
    case 0x2143: return "apui03";

    case 0x2180: return "WMDATA";
    case 0x2181: return "WMADDL";
    case 0x2182: return "WMADDM";
    case 0x2183: return "WMADDH";

    case 0x4016:	return "ser0";
    case 0x4017:	return "ser1";

    case 0x4200:	return "nmitimen";
    case 0x4201:	return "wrio";
    case 0x4202:	return "wrmpya";
    case 0x4203:	return "wrmpyb";
    case 0x4204:	return "wrdivl";
    case 0x4205:	return "wrdivh";
    case 0x4206:	return "wrdivb";
    case 0x4207:	return "htmel";
    case 0x4208:	return "htmeh";
    case 0x4209:	return "vtmel";
    case 0x420A:	return "vtmeh";
    case 0x420B:	return "mdmaen";
    case 0x420C:    return "hdmaen";
    case 0x420D:	return "memsel";

    case 0x4210:	return "RDNMI";
    case 0x4211:	return "TIMEUP";
    case 0x4212:	return "HVBJOY";
    case 0x4213:	return "RDIO";
    case 0x4214:	return "RDDIVL";
    case 0x4215:	return "RDDIVH";
    case 0x4216:	return "RDMPYL";
    case 0x4217:	return "RDMPYH";
    case 0x4218:	return "JOY1L";
    case 0x4219:	return "JOY1H";
    case 0x421A:	return "JOY2L";
    case 0x421B:	return "JOY2H";
    case 0x421C:	return "JOY3L";
    case 0x421D:	return "JOY3H";
    case 0x421E:	return "JOY4L";
    case 0x421F:	return "JOY4H";

    default:
        switch (uAddr & 0x430F)
        {
        case 0x4300:  return "dmapx";
        case 0x4301:  return "bbadx";
        case 0x4302:  return "a1txl";
        case 0x4303:  return "a1txh";
        case 0x4304:  return "a1bx";
        case 0x4305:  return "dasxl";
        case 0x4306:  return "dasxh";
        case 0x4307:  return "dasbx";
        case 0x4308:  return "a2axl";
        case 0x4309:  return "a2axh";
        case 0x430A:  return "ntlrx";
        }
        return SnesPPU::GetRegName(uAddr);
    }
}

#endif

