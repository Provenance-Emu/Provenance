
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <conio.h>

#include "types.h"
#include "snes.h"

SnesSystem _Snes;
SnesRom _Rom;

static Uint32 _Disasm(SNCpuT *pCpu, Uint32 uAddr, Uint8 *pFlags)
{
	Uint8 Opcode[4];
	Char Str[256];
    Int32 nBytes;
    Int32 iByte;

	// read memory
	SNCPUReadMem(pCpu, uAddr, Opcode, sizeof(Opcode));

	// disassemble
	nBytes = SNDisasm(Str, Opcode, uAddr, pFlags);

	printf("%06X: ", uAddr);
    //printf("%02X ", uFlags);


    for (iByte=0; iByte < nBytes; iByte++)
    {
        printf("%02X ", Opcode[iByte]);
    }

    for (; iByte < 4; iByte++)
    {
        printf("   ");
    }

	printf("%c ", (uAddr == pCpu->Regs.rPC) ? '>' : ' ');

    printf("%s\n", Str);

	return nBytes;
}

void _DisasmRom(SnesRom *pRom, Uint32 uStartAddr, Uint32 uEndAddr)
{
    Uint32 PC;
    Uint8 uFlags=0x30;
	Uint8 *pRomData;

	pRomData = pRom->GetData();

    PC = 0;
    while (PC < 980)
    {
        Char Str[256];
        Int32 nBytes;
        Int32 iByte;

        nBytes = SNDisasm(Str, pRomData + PC, PC, &uFlags);

        printf("%06X: ", PC);
        //printf("%02X ", uFlags);

        for (iByte=0; iByte < nBytes; iByte++)
        {
            printf("%02X ", pRomData[PC]);
            PC++;
        }

        for (; iByte < 4; iByte++)
        {
            printf("   ");
        }

        printf("%s\n", Str);
    }
}

void _Execute(SNCpuT *pCpu, Uint32 uCycles, Uint32 uBreakpoint)
{
	if (uBreakpoint!=0)
	{
		Int32 nCycles = uCycles;
		while (nCycles > 0)
		{
			if (pCpu->Regs.rPC == uBreakpoint) break;
			pCpu->Cycles = 1;
			SNCPUExecute_C(pCpu, 1);
			nCycles--;
		}
	} else
	{
		SNCPUExecute_C(pCpu, uCycles);
	}
}


void DebugLoop(SnesSystem *pSnes)
{
	SNCpuT *pCpu = &pSnes->m_Cpu;
	bool bDone=false;
	Uint32 uBreakpoint = 0;

	while (!bDone)
	{
		Char	cKey;
		Uint8 uFlags;
		Uint32 uAddr;

		cKey = getch();

		switch(cKey)
		{
		case 'R':
			pSnes->Reset();
			//SNCPUReset(pCpu, true);
			printf("SNES Reset\n");
			break;
		case 'r':
			SNCPUDumpRegs(pCpu);
			break;
		case 'd':
			uAddr = pCpu->Regs.rPC;
			uFlags = pCpu->Regs.rP;
			for (int i=0; i < 10; i++)
				uAddr += _Disasm(pCpu, uAddr, &uFlags);
			break;

		case 'D':
			uAddr = 0x8000;
			uFlags = 0;
			for (uAddr=0x8000; uAddr < 0x10000; )
				uAddr += _Disasm(pCpu, uAddr, &uFlags);
			break;


		case 'b':
			printf("BP: ");
			scanf("%X", &uBreakpoint);
			break;

		case 'i':
			SNCPUIRQ(pCpu);
			printf("IRQ\n");
			break;

		case 'n':
			SNCPUNMI(pCpu);
			printf("NMI\n");
			break;

		case 'e':
			_Execute(pCpu, 2684659 / 60, uBreakpoint);
			break;

		case 'f':
			printf("frame\n");
			if (pSnes->m_IO.nmitimen & 0x80)
			{
				printf("NMI\n");
				SNCPUNMI(pCpu);
			}
			_Execute(pCpu, 2684659 / 60, uBreakpoint);
			break;

		case 't':
			uFlags = pCpu->Regs.rP;
			_Disasm(pCpu, pCpu->Regs.rPC, &uFlags);
			pCpu->Cycles = 0;
			SNCPUExecute_C(pCpu, 1);
			SNCPUDumpRegs(pCpu);
			break;

		case 'q':
			bDone=true;
			break;
		}
	}
}


int main(int argc, char *argv[])
{
	if (!_Rom.LoadRom("c:\\snesrom\\mario.smc"))
	{
		return 0;
	}

	_Snes.SetRom(&_Rom);
	_Snes.Reset();
	DebugLoop(&_Snes);
	return 0;
}

