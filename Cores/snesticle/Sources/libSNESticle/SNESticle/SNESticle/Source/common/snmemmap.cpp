
#include <stdlib.h>
#include <stdio.h>
#include "types.h"
#include "snes.h"
#include "console.h"
#include "snmemmap.h"
#include "sndebug.h"

static SnesMemMapT	_SnesMemMap_LoRom[]=
{
	// map slow rom
	{0x00, 0x6F, 0x8000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},

	// map fast rom
	{0x80, 0xEF, 0x8000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},

	// mirror rom in lower 32k (?)
	{0x40, 0x6F, 0x0000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},
	{0xC0, 0xEF, 0x0000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},

	// map sram areas
	{0x70, 0x77, 0x0000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},

	// map ram
	{0x7E, 0x7F, 0x0000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_RAM},

	// map lo-ram / ppu areas
	{0x00, 0x3F, 0x0000, 0x1FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_LORAM},
	{0x00, 0x3F, 0x2000, 0x3FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU0},
	{0x00, 0x3F, 0x4000, 0x5FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU1},

	{0x80, 0xBF, 0x0000, 0x1FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_LORAM},
	{0x80, 0xBF, 0x2000, 0x3FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU0},
	{0x80, 0xBF, 0x4000, 0x5FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU1},

	{0, 0, 0, 0, SNESMEM_TYPE_NONE}
};

static SnesMemMapT	_SnesMemMap_HiRom[]=
{
	// map slow rom
	{0x00, 0x3F, 0x0000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},
	{0x40, 0x6F, 0x0000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},

	// map fast rom
	{0x80, 0xBF, 0x0000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},
	{0xC0, 0xFF, 0x0000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_ROM},

	// map sram areas
	{0x70, 0x77, 0x0000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0x00, 0x0F, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0x10, 0x1F, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0x20, 0x2F, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0x30, 0x3F, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0x80, 0x8F, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0x90, 0x9F, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0xA0, 0xAF, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},
	{0xB0, 0xBF, 0x6000, 0x7FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_SRAM},

	// map ram
	{0x7E, 0x7F, 0x0000, 0xFFFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_RAM},

	// map lo-ram / ppu areas
	{0x00, 0x3F, 0x0000, 0x1FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_LORAM},
	{0x00, 0x3F, 0x2000, 0x3FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU0},
	{0x00, 0x3F, 0x4000, 0x5FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU1},

	{0x80, 0xBF, 0x0000, 0x1FFF, SNCPU_CYCLE_SLOW, SNESMEM_TYPE_LORAM},
	{0x80, 0xBF, 0x2000, 0x3FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU0},
	{0x80, 0xBF, 0x4000, 0x5FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_PPU1},

	{0, 0, 0, 0, SNESMEM_TYPE_NONE}
};


#if SNES_DSP1
static SnesMemMapT	_SnesMemMap_HiRom_DSP1[]=
{
	{0x00, 0x1F, 0x6000, 0x7FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_DSP1},
	{0x80, 0x9F, 0x6000, 0x7FFF, SNCPU_CYCLE_FAST, SNESMEM_TYPE_DSP1},

	{0, 0, 0, 0, SNESMEM_TYPE_NONE}
};
#endif


void SnesSystem::MapMem(SnesMemMapT *pMemMap)
{
	SNCpuT *pCpu = &m_Cpu;
	Uint32 uSize[SNESMEM_TYPE_NUM];
	SnesRom *pRom = m_pRom;

	// determine size of SRAM in bytes 
	m_uSramSize = pRom->GetSRAMBytes();
	if (m_uSramSize > SNES_SRAMSIZE) m_uSramSize = SNES_SRAMSIZE; 
	//uSRAMBytes = (uSRAMBytes + SNCPU_BANK_SIZE - 1)  & ~(SNCPU_BANK_MASK);

	// calculate size of each map type
	Int32 i;
	for (i=0; i < SNESMEM_TYPE_NUM; i++)
	{
		uSize[i] = SNCPU_BANK_SIZE;
	}

	uSize[SNESMEM_TYPE_NONE]	 = 0;
	uSize[SNESMEM_TYPE_UNMAPPED] = 0;
	uSize[SNESMEM_TYPE_ROM]      = pRom->GetBytes();
	uSize[SNESMEM_TYPE_RAM]      = SNES_RAMSIZE;
	uSize[SNESMEM_TYPE_SRAM]     = m_uSramSize;

	while (pMemMap->eMemType!=SNESMEM_TYPE_NONE)
	{
		Uint32 uBank;
		Uint32 uOffset;

		uOffset = pMemMap->uOffset;

		// iterate through bank range
		for (uBank = pMemMap->uStartBank; uBank <= pMemMap->uEndBank; uBank++)
		{
			Uint32 uStartAddr, uEndAddr, nBytes;

			// determine range to map for this bank
			uStartAddr = (uBank << 16) | (Uint32)pMemMap->uStartAddr;
			uEndAddr   = (uBank << 16) | (Uint32)pMemMap->uEndAddr;
			uEndAddr++;

			assert(uStartAddr <= uEndAddr);
			nBytes     = uEndAddr - uStartAddr;

			//ConDebug("Mapping %06X -> %06X %06X %d\n", uStartAddr, uEndAddr, uOffset, pMemMap->eMemType);

			// wrap address to size of memory
			if (uOffset >= uSize[pMemMap->eMemType])
			{
				uOffset = 0; // wrap address
			}

			// wrap byte count to size of memory
			if (nBytes >= uSize[pMemMap->eMemType]) 
			{
				nBytes = uSize[pMemMap->eMemType];
			}

			if (nBytes > 0)
			{
				Uint32 uAlignedBytes = (nBytes + SNCPU_BANK_SIZE - 1)  & ~(SNCPU_BANK_MASK);

				// set memory speed for region
				SNCPUSetMemSpeed(pCpu, uStartAddr, uAlignedBytes, pMemMap->uSpeed);

				switch (pMemMap->eMemType)
				{
				case SNESMEM_TYPE_ROM:
					SNCPUSetBank(pCpu, uStartAddr, nBytes, pRom->GetData() + uOffset, FALSE);
					break;
				case SNESMEM_TYPE_SRAM:
					if (nBytes & (SNCPU_BANK_SIZE - 1))
					{
						// size of sram wont map evenly to our bank size, so we must use a traphandler for reads/writes
						SNCPUSetTrap(pCpu, uStartAddr, uAlignedBytes, ReadSRAM, WriteSRAM);
					}
					else
					{
						// map mirrored
						while (uStartAddr < uEndAddr)
						{
							SNCPUSetBank(pCpu, uStartAddr, nBytes, m_SRam + uOffset, TRUE);
							uStartAddr += nBytes;
						}
					}
					break;
				case SNESMEM_TYPE_RAM:
				case SNESMEM_TYPE_LORAM:
					SNCPUSetBank(pCpu, uStartAddr, nBytes, m_Ram + uOffset, TRUE);
					break;
				case SNESMEM_TYPE_PPU0:
#if SNES_DEBUG
					SNCPUSetTrap(pCpu, uStartAddr, nBytes, Read2000Debug, Write2000Debug);
#else
                    SNCPUSetTrap(pCpu, uStartAddr, nBytes, Read2000, Write2000);
#endif
					break;
				case SNESMEM_TYPE_PPU1:
#if SNES_DEBUG
					SNCPUSetTrap(pCpu, uStartAddr, nBytes, Read4000Debug, Write4000Debug);
#else
                    SNCPUSetTrap(pCpu, uStartAddr, nBytes, Read4000, Write4000);
#endif
					break;
				case SNESMEM_TYPE_DSP1:
					SNCPUSetTrap(&m_Cpu, uStartAddr, nBytes, ReadDSP1, WriteDSP1);
					break;
				default:
					break;
				}
			}
			uOffset += nBytes;
		}

		pMemMap++;
	}
}

#if CODE_DEBUG
void SnesSystem::DumpMemMap()
{
	SNCpuT *pCpu = GetCpu();
	Uint32 uAddr;
	for (uAddr=0; uAddr < SNCPU_MEM_SIZE; uAddr+= SNCPU_BANK_SIZE)
	{
		SNCpuBankT *pBank =  &pCpu->Bank[uAddr >> SNCPU_BANK_SHIFT];
		ConDebug("%06X %p %p %p %d %d\n",
			uAddr,
			pBank->pMem,
			pBank->pReadTrapFunc,
			pBank->pWriteTrapFunc,
			pBank->uBankCycle,
			pBank->bRAM
			);
	}
}
#endif

void SnesSystem::MapMem(SNRomMappingE eRomMapping, Uint32 uFlags)
{
	// set default traps
	SNCPUSetTrap(&m_Cpu,     0, SNCPU_MEM_SIZE, ReadMem, WriteMem);
	SNCPUSetMemSpeed(&m_Cpu, 0, SNCPU_MEM_SIZE, SNCPU_CYCLE_SLOW);

	switch (eRomMapping)
	{
		default:

		// mode 20h
		case SNROM_MAPPING_LOROM:
			MapMem(_SnesMemMap_LoRom);
			break;

		// mode 21h
		case SNROM_MAPPING_HIROM:
			MapMem(_SnesMemMap_HiRom);

#if SNES_DSP1
			if (uFlags & SNROM_FLAG_DSP1)
			{
				MapMem(_SnesMemMap_HiRom_DSP1);
				m_pDsp = &m_DSP1;;
			}
#endif
			break;
	}



#if CODE_DEBUG
//	DumpMemMap();
#endif

}


void SnesSystem::SetFastRom()
{
	SNCPUSetRomSpeed(&m_Cpu, 0x800000, 0x800000, SNCPU_CYCLE_FAST);
}

void SnesSystem::SetSlowRom()
{
	SNCPUSetRomSpeed(&m_Cpu, 0x800000, 0x800000, SNCPU_CYCLE_SLOW);
}

#if 0
void SnesSystem::MapLoRom()
{
	Uint32 uMemAddr;
	Uint32 uRomAddr;
	Uint8 *pRomData;
	Uint32 uRomBytes;
	Uint32 uSRAMBytes;

	SnesRom *pRom = m_pRom;
	SNCpuT *pCpu = &m_Cpu;
	Uint8 *pRam = m_Ram;
	Uint8 *pSRam = m_SRam;

	uRomBytes= pRom->GetBytes();
	pRomData = pRom->GetData();

	// determine size of SRAM in bytes 
	uSRAMBytes = pRom->GetSRAMBytes();
	if (uSRAMBytes > SNES_SRAMSIZE) uSRAMBytes = SNES_SRAMSIZE; 

//	uSRAMBytes = 1024 * 16;
//	uSRAMBytes = SNES_SRAMSIZE;

	// round up to banksize
	uSRAMBytes = (uSRAMBytes + SNCPU_BANK_SIZE - 1)  & ~(SNCPU_BANK_MASK);

	// set default traps
	SNCPUSetTrap(pCpu,     0, SNCPU_MEM_SIZE, ReadMem, WriteMem);
	SNCPUSetMemSpeed(pCpu, 0, SNCPU_MEM_SIZE, SNCPU_CYCLE_SLOW);

	// map slow rom at xx8000 -> xxFFFF
	uRomAddr=0x000000; 
	for (uMemAddr=0x000000; uMemAddr < 0x700000; uMemAddr+=0x10000)
	{
		// mirror 32K at 0000->7FFFF
		if (uMemAddr >= 0x400000)
			SNCPUSetBank(pCpu, uMemAddr | 0x000000, 0x8000, pRomData + uRomAddr, FALSE);
		SNCPUSetBank(pCpu, uMemAddr | 0x008000, 0x8000, pRomData + uRomAddr, FALSE);

		// increment/wrap rom address
		uRomAddr += 0x08000;
		if (uRomAddr >= uRomBytes) uRomAddr = 0;
	}

	// map fast rom at xx8000 -> xxFFFF
	uRomAddr=0x000000; 
	for (uMemAddr=0x800000; uMemAddr < 0xFE0000; uMemAddr+=0x10000)
	{
		// mirror 32K at 0000->7FFFF
		if (uMemAddr >= 0xC00000)
			SNCPUSetBank(pCpu, uMemAddr | 0x000000, 0x8000, pRomData + uRomAddr,  FALSE);
		SNCPUSetBank(pCpu, uMemAddr | 0x008000, 0x8000, pRomData + uRomAddr,  FALSE);

		// increment/wrap rom address
		uRomAddr += 0x08000;
		if (uRomAddr >= uRomBytes) uRomAddr = 0;
	}

	// map i/o area
	uMemAddr=0x000000; 
	while (uMemAddr < 0x400000)
	{
		// map loram at xx0000 -> xx1FFF
		SNCPUSetBank(pCpu, uMemAddr | 0x000000, 0x2000, pRam, TRUE);
		SNCPUSetBank(pCpu, uMemAddr | 0x800000, 0x2000, pRam, TRUE);


		SNCPUSetTrap(pCpu, uMemAddr | 0x002000, 0x2000, Read2000, Write2000);
		SNCPUSetTrap(pCpu, uMemAddr | 0x004000, 0x2000, Read4000, Write4000);
  
		SNCPUSetTrap(pCpu, uMemAddr | 0x802000, 0x2000, Read2000, Write2000);
		SNCPUSetTrap(pCpu, uMemAddr | 0x804000, 0x2000, Read4000, Write4000);
		#if SNES_RAMFAST
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x000000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x800000, 0x2000, SNCPU_CYCLE_FAST);
		#endif

		// i/o area is fast
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x002000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x802000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x004000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x804000, 0x2000, SNCPU_CYCLE_FAST);

		uMemAddr += 0x10000;
	}

	// map sram area 700000 -> 7DFFFF
	if (uSRAMBytes > 0)
	{
		uMemAddr = 0x700000;
		while (uMemAddr < 0x7E0000)
		{
			SNCPUSetBank(pCpu, uMemAddr, uSRAMBytes, pSRam, TRUE);
			uMemAddr += uSRAMBytes;
		}
	}

	// map ram at 7E0000 -> 7FFFFF
	//SNCPUSetTrap(pCpu, 0x7E0000, 0x20000, ReadMem, WriteMem);
	SNCPUSetBank(pCpu, 0x7E0000, 0x20000, pRam, TRUE);

	#if SNES_RAMFAST
	SNCPUSetMemSpeed(pCpu, 0x7E0000, 0x20000, SNCPU_CYCLE_FAST);
	#endif

}


void SnesSystem::MapHiRom()
{
	Uint32 uMemAddr;
	Uint32 uRomAddr;
	Uint8 *pRomData;
	Uint32 uRomBytes;
	Uint32 uSRAMBytes;

	SnesRom *pRom = m_pRom;
	SNCpuT *pCpu = &m_Cpu;
	Uint8 *pRam = m_Ram;
///	Uint8 *pSRam = m_SRam;

	uRomBytes= pRom->GetBytes();
	pRomData = pRom->GetData();

	// determine size of SRAM in bytes 
	uSRAMBytes = pRom->GetSRAMBytes();
	if (uSRAMBytes > SNES_SRAMSIZE) uSRAMBytes = SNES_SRAMSIZE; 
//	uSRAMBytes = SNES_SRAMSIZE;

	// round up to banksize
	uSRAMBytes = (uSRAMBytes + SNCPU_BANK_SIZE - 1)  & ~(SNCPU_BANK_MASK);


	// set default traps
	SNCPUSetTrap(pCpu,     0, SNCPU_MEM_SIZE, ReadMem, WriteMem);
	SNCPUSetMemSpeed(pCpu, 0, SNCPU_MEM_SIZE, SNCPU_CYCLE_SLOW);

	// map 32kb slow rom at 008000 -> 3FFFFF
	uRomAddr=0x000000; 
	for (uMemAddr=0x000000; uMemAddr < 0x400000; uMemAddr+=0x10000)
	{
		SNCPUSetBank(pCpu, uMemAddr | 0x008000, 0x8000, pRomData + uRomAddr + 0x8000, FALSE);

		// increment/wrap rom address
		uRomAddr += 0x10000;
		if (uRomAddr >= uRomBytes) uRomAddr = 0;
	}

	// map 64kb slow rom at 400000 -> xxFFFF
	uRomAddr=0x000000; 
	for (uMemAddr=0x400000; uMemAddr < 0x7E0000; uMemAddr+=0x10000)
	{
		SNCPUSetBank(pCpu, uMemAddr, 0x10000, pRomData + uRomAddr, FALSE);

		// increment/wrap rom address
		uRomAddr += 0x10000;
		if (uRomAddr >= uRomBytes) uRomAddr = 0;
	}


	// map fast 32kb rom at 808000 -> BFFFFF
	uRomAddr=0x000000; 
	for (uMemAddr=0x800000; uMemAddr < 0xC00000; uMemAddr+=0x10000)
	{
		SNCPUSetBank(pCpu, uMemAddr | 0x008000, 0x8000, pRomData + uRomAddr + 0x8000,  FALSE);

		// increment/wrap rom address
		uRomAddr += 0x10000;
		if (uRomAddr >= uRomBytes) uRomAddr = 0;
	}


	// map fast 64kb rom at C00000 -> FFFFFF
	uRomAddr=0x000000; 
	for (uMemAddr=0xC00000; uMemAddr < 0x1000000; uMemAddr+=0x10000)
	{
		SNCPUSetBank(pCpu, uMemAddr, 0x10000, pRomData + uRomAddr,  FALSE);

		// increment/wrap rom address
		uRomAddr += 0x10000;
		if (uRomAddr >= uRomBytes) uRomAddr = 0;
	}


	// map i/o area
	uMemAddr=0x000000; 
	while (uMemAddr < 0x400000)
	{
		// map loram at xx0000 -> xx1FFF
		SNCPUSetBank(pCpu, uMemAddr | 0x000000, 0x2000, pRam, TRUE);
		SNCPUSetBank(pCpu, uMemAddr | 0x800000, 0x2000, pRam, TRUE);


		SNCPUSetTrap(pCpu, uMemAddr | 0x002000, 0x2000, Read2000, Write2000);
		SNCPUSetTrap(pCpu, uMemAddr | 0x004000, 0x2000, Read4000, Write4000);

		SNCPUSetTrap(pCpu, uMemAddr | 0x802000, 0x2000, Read2000, Write2000);
		SNCPUSetTrap(pCpu, uMemAddr | 0x804000, 0x2000, Read4000, Write4000);
#if SNES_RAMFAST
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x000000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x800000, 0x2000, SNCPU_CYCLE_FAST);
#endif

		// i/o area is fast
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x002000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x802000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x004000, 0x2000, SNCPU_CYCLE_FAST);
		SNCPUSetMemSpeed(pCpu, uMemAddr | 0x804000, 0x2000, SNCPU_CYCLE_FAST);

		uMemAddr += 0x10000;
	}


/*

	// map sram area 700000 -> 7?????
	SNCPUSetBank(pCpu, 0x700000, uSRAMBytes, pSRam, TRUE);
*/

	// map ram at 7E0000 -> 7FFFFF
	//SNCPUSetTrap(pCpu, 0x7E0000, 0x20000, ReadMem, WriteMem);
	SNCPUSetBank(pCpu, 0x7E0000, 0x20000, pRam, TRUE);

}
#endif

