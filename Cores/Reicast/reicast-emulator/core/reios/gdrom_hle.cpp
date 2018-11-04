/*
	Basic gdrom syscall emulation
	Adapted from some (very) old pre-nulldc hle code
*/

#include <stdio.h>
#include "types.h"
#include "hw/sh4/sh4_if.h"
#include "hw/sh4/sh4_mem.h"

#include "gdrom_hle.h"

#define SWAP32(a) ((((a) & 0xff) << 24)  | (((a) & 0xff00) << 8) | (((a) >> 8) & 0xff00) | (((a) >> 24) & 0xff))

//#define debugf printf
#define debugf(...)

void GDROM_HLE_ReadSES(u32 addr)
{
	u32 s = ReadMem32(addr + 0);
	u32 b = ReadMem32(addr + 4);
	u32 ba = ReadMem32(addr + 8);
	u32 bb = ReadMem32(addr + 12);

	printf("GDROM_HLE_ReadSES: doing nothing w/ %d, %d, %d, %d\n", s, b, ba, bb);
}
void GDROM_HLE_ReadTOC(u32 Addr)
{
	u32 s = ReadMem32(Addr + 0);
	u32 b = ReadMem32(Addr + 4);

	u32* pDst = (u32*)GetMemPtr(b, 0);

	//
	debugf("GDROM READ TOC : %X %X \n\n", s, b);

	libGDR_GetToc(pDst, s);

	//The syscall swaps to LE it seems
	for (int i = 0; i < 102; i++) {
		pDst[i] = SWAP32(pDst[i]);
	}
}

void read_sectors_to(u32 addr, u32 sector, u32 count) {
	u8 * pDst = GetMemPtr(addr, 0);

	if (pDst) {
		libGDR_ReadSector(pDst, sector, count, 2048);
	}
	else {
		u8 temp[2048];

		while (count > 0) {
			libGDR_ReadSector(temp, sector, 1, 2048);

			for (int i = 0; i < 2048 / 4; i += 4) {
				WriteMem32(addr, temp[i]);
				addr += 4;
			}

			sector++;
			count--;
		}
	}
	
}

void GDROM_HLE_ReadDMA(u32 addr)
{
	u32 s = ReadMem32(addr + 0x00);
	u32 n = ReadMem32(addr + 0x04);
	u32 b = ReadMem32(addr + 0x08);
	u32 u = ReadMem32(addr + 0x0C);

	

	debugf("GDROM:\tPIO READ Sector=%d, Num=%d, Buffer=0x%08X, Unk01=0x%08X\n", s, n, b, u);
	read_sectors_to(b, s, n);
}

void GDROM_HLE_ReadPIO(u32 addr)
{
	u32 s = ReadMem32(addr + 0x00);
	u32 n = ReadMem32(addr + 0x04);
	u32 b = ReadMem32(addr + 0x08);
	u32 u = ReadMem32(addr + 0x0C);

	debugf("GDROM:\tPIO READ Sector=%d, Num=%d, Buffer=0x%08X, Unk01=0x%08X\n", s, n, b, u);

	read_sectors_to(b, s, n);
}

void GDCC_HLE_GETSCD(u32 addr) {
	u32 s = ReadMem32(addr + 0x00);
	u32 n = ReadMem32(addr + 0x04);
	u32 b = ReadMem32(addr + 0x08);
	u32 u = ReadMem32(addr + 0x0C);

	printf("GDROM: Doing nothing for GETSCD [0]=%d, [1]=%d, [2]=0x%08X, [3]=0x%08X\n", s, n, b, u);
}

#define r Sh4cntx.r


u32 SecMode[4];

void GD_HLE_Command(u32 cc, u32 prm)
{
	switch(cc)
	{
	case GDCC_GETTOC:
		printf("GDROM:\t*FIXME* CMD GETTOC CC:%X PRM:%X\n",cc,prm);
		break;

	case GDCC_GETTOC2:
		GDROM_HLE_ReadTOC(r[5]);
		break;

	case GDCC_GETSES:
		debugf("GDROM:\tGETSES CC:%X PRM:%X\n", cc, prm);
		GDROM_HLE_ReadSES(r[5]);
		break;

	case GDCC_INIT:
		printf("GDROM:\tCMD INIT CC:%X PRM:%X\n",cc,prm);
		break;

	case GDCC_PIOREAD:
		GDROM_HLE_ReadPIO(r[5]);
		break;

	case GDCC_DMAREAD:
		debugf("GDROM:\tCMD DMAREAD CC:%X PRM:%X\n", cc, prm);
		GDROM_HLE_ReadDMA(r[5]);
		break;


	case GDCC_PLAY_SECTOR:
		printf("GDROM:\tCMD PLAYSEC? CC:%X PRM:%X\n",cc,prm);
		break;

	case GDCC_RELEASE:
		printf("GDROM:\tCMD RELEASE? CC:%X PRM:%X\n",cc,prm);
		break;

	case GDCC_STOP:	printf("GDROM:\tCMD STOP CC:%X PRM:%X\n",cc,prm);	break;
	case GDCC_SEEK:	printf("GDROM:\tCMD SEEK CC:%X PRM:%X\n",cc,prm);	break;
	case GDCC_PLAY:	printf("GDROM:\tCMD PLAY CC:%X PRM:%X\n",cc,prm);	break;
	case GDCC_PAUSE:printf("GDROM:\tCMD PAUSE CC:%X PRM:%X\n",cc,prm);	break;

	case GDCC_READ:
		printf("GDROM:\tCMD READ CC:%X PRM:%X\n",cc,prm);
		break;

	case GDCC_GETSCD:
		debugf("GDROM:\tGETSCD CC:%X PRM:%X\n",cc,prm);
		GDCC_HLE_GETSCD(r[5]);
		break;

	default: printf("GDROM:\tUnknown GDROM CC:%X PRM:%X\n",cc,prm); break;
	}
}

void gdrom_hle_op()
{
	static u32 last_cmd = 0xFFFFFFFF;	// only works for last cmd, might help somewhere
	static u32 dwReqID=0xF0FFFFFF;		// ReqID, starting w/ high val

	if( SYSCALL_GDROM == r[6] )		// GDROM SYSCALL
	{
		switch(r[7])				// COMMAND CODE
		{
			// *FIXME* NEED RET
		case GDROM_SEND_COMMAND:	// SEND GDROM COMMAND RET: - if failed + req id
			debugf("\nGDROM:\tHLE SEND COMMAND CC:%X  param ptr: %X\n",r[4],r[5]);
			GD_HLE_Command(r[4],r[5]);
			last_cmd = r[0] = --dwReqID;		// RET Request ID
		break;

		case GDROM_CHECK_COMMAND:	// 
			r[0] = last_cmd == r[4] ? 2 : 0; // RET Finished : Invalid
			debugf("\nGDROM:\tHLE CHECK COMMAND REQID:%X  param ptr: %X -> %X\n", r[4], r[5], r[0]);
			last_cmd = 0xFFFFFFFF;			// INVALIDATE CHECK CMD
		break;

			// NO return, NO params
		case GDROM_MAIN:	
			debugf("\nGDROM:\tHLE GDROM_MAIN\n");
			break;

		case GDROM_INIT:	printf("\nGDROM:\tHLE GDROM_INIT\n");	break;
		case GDROM_RESET:	printf("\nGDROM:\tHLE GDROM_RESET\n");	break;

		case GDROM_CHECK_DRIVE:		// 
			debugf("\nGDROM:\tHLE GDROM_CHECK_DRIVE r4:%X\n",r[4],r[5]);
			WriteMem32(r[4]+0,0x02);	// STANDBY
			WriteMem32(r[4]+4,libGDR_GetDiscType());	// CDROM | 0x80 for GDROM
			r[0]=0;					// RET SUCCESS
		break;

		case GDROM_ABORT_COMMAND:	// 
			printf("\nGDROM:\tHLE GDROM_ABORT_COMMAND r4:%X\n",r[4],r[5]);
			r[0]=-1;				// RET FAILURE
		break;


		case GDROM_SECTOR_MODE:		// 
			printf("GDROM:\tHLE GDROM_SECTOR_MODE PTR_r4:%X\n",r[4]);
			for(int i=0; i<4; i++) {
				SecMode[i] = ReadMem32(r[4]+(i<<2));
				printf("%08X%s",SecMode[i],((3==i) ? "\n" : "\t"));
			}
			r[0]=0;					// RET SUCCESS
		break;

		default: printf("\nGDROM:\tUnknown SYSCALL: %X\n",r[7]); break;
		}
	}
	else							// MISC 
	{
		printf("SYSCALL:\tSYSCALL: %X\n",r[7]);
	}
}