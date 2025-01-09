

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "console.h"
#include "snppu.h"
#include "snppurender.h"
#include "rendersurface.h"
#include "snmask.h"
#include "prof.h"



static Uint8 _SnesPPU_OAMSize[8][2]=
{
	{0, 1},	// 000  8 & 16
	{0, 2},	// 001  8 & 32
	{0, 3}, // 010  8 & 64
	{1, 2}, // 011 16 & 32
	{1, 3}, // 100 16 & 64
	{2, 3}, // 101 32 & 64 
	{0, 0}, // 110 ??
	{0, 0}, // 111 ??
};


void _DecodeOBJEX(Uint8 *pObjEx, SnesRenderObjT *pObjs, Int32 nObjs, Uint8 *pOAMSize)
{
	while (nObjs > 0)
	{
		Uint8	uObjEx;

		// fetch obj byte
		uObjEx = *pObjEx++;

		//uObjEx|=0xAA;

		pObjs->uPosX	   = (uObjEx & 1) << 8; 
		uObjEx>>=1;
		pObjs->uSizeShift  = pOAMSize[uObjEx & 1]; 
		uObjEx>>=1;
		pObjs++;

		pObjs->uPosX	   = (uObjEx & 1) << 8; 
		uObjEx>>=1;
		pObjs->uSizeShift  = pOAMSize[uObjEx & 1]; 
		uObjEx>>=1;
		pObjs++;

		pObjs->uPosX	   = (uObjEx & 1) << 8; 
		uObjEx>>=1;
		pObjs->uSizeShift  = pOAMSize[uObjEx & 1]; 
		uObjEx>>=1;
		pObjs++;

		pObjs->uPosX	   = (uObjEx & 1) << 8; 
		uObjEx>>=1;
		pObjs->uSizeShift  = pOAMSize[uObjEx & 1]; 
		uObjEx>>=1;
		pObjs++;

		nObjs-=4;
	}

}


void _DecodeOBJ(SnesPPUOBJT *pPPUObj, SnesRenderObjT *pObjs, Int32 nObjs, Uint8 *pObjY, Uint8 *pObjSize)
{
	// xxxxxxxx
	// yyyyyyyy
	// CCCCCCCC
	// vhppcccC


	while (nObjs > 0)
	{
		Uint32 uTile;
		Uint8 uAttrib;

		uAttrib = pPPUObj->uAttrib;

		uTile =  pPPUObj->uTile;
		uTile|= ((uAttrib&1)<<8);

		pObjs->uPosX   |= pPPUObj->uX;
		pObjs->uPosY    = pPPUObj->uY + 1;
		pObjs->uPal   = (uAttrib >> 1) & 7;
		pObjs->uPri   = (uAttrib >> 4) & 3;
		pObjs->bHFlip = (uAttrib >> 6) & 1;
		pObjs->uSize  = 8 << pObjs->uSizeShift;
		
		if (uAttrib & 0x80)
		{
			pObjs->uVXOR = pObjs->uSize - 1;
		} else
		{
			pObjs->uVXOR = 0;
		}

		pObjs->uTile = uTile;
		//pObjs->uTile = ((uTile >> 4) << 4) + ((uTile & (0xF>>0)) << 0);
		/*
		switch (pObjs->uSizeShift)
		{
		case 0: // 8x8
		pObjs->uTile = ((uTile >> 4) << 4) + ((uTile & (0xF>>0)) << 0);
		break;
		case 1: // 16x16
		pObjs->uTile = ((uTile >> 3) << 5) + ((uTile & (0xF>>1)) << 1);
		break;
		case 2: // 32x32
		pObjs->uTile = ((uTile >> 2) << 6) + ((uTile & (0xF>>2)) << 2);
		break;
		case 3: // 64x64
		pObjs->uTile = ((uTile >> 1) << 7) + ((uTile & (0xF>>3)) << 3);
		break;
		}
		*/

        *pObjY++    = pObjs->uPosY;
        *pObjSize++ = pObjs->uSize;

		// next obj
		pPPUObj++;
		pObjs++;
		nObjs--;
	}
}



Int32 SnesPPURender::CheckOBJ(SnesRenderObjT *pObjs, Int32 iObj, Int32 nObjs, Uint8 *pObjList, Int32 MaxObjLine, Int32 iLine)
{
	Int32 nObjLine = 0;

	while (nObjs > 0)
	{
		SnesRenderObjT *pObj;
		Uint32 uObjY;

		// get pointer to object
		pObj   = &pObjs[iObj & 0x7F];

		uObjY = iLine - pObj->uPosY;
		uObjY&= 0xFF;

		if (uObjY < pObj->uSize) 
		{
			// we got an obj
			*pObjList =  iObj;
			pObjList++;

			nObjLine++;
			if (nObjLine >= MaxObjLine) break;
		}

		
		iObj++;
		nObjs--;
	}

	return nObjLine;
}







Int32 SnesPPURender::CheckOBJ(Uint8 *pObjY, Uint8 *pObjSize, Int32 iObj, Int32 nObjs, Uint8 *pObjList, Int32 MaxObjLine, Int32 iLine)
{
	Int32 nObjLine = 0;

	while (nObjs > 0)
	{
		Uint32 uObjY, uObjSize;

		iObj &= 0x7F;

		// get pointer to object
        uObjSize = pObjSize[iObj];
		uObjY    = pObjY[iObj];

		uObjY = iLine - uObjY;
		uObjY&= 0xFF;

		if (uObjY < uObjSize) 
		{
			// we got an obj
			*pObjList =  iObj;
			pObjList++;

			nObjLine++;
			if (nObjLine >= MaxObjLine) break;
		}

		iObj++;
		nObjs--;
	}

	return nObjLine;
}



Int32 SnesPPURender::CheckOBJ(Uint8 *pObjList, Int32 iLine)
{
    if (iLine >= 0 && iLine < SNPPU_MAXLINE)
    {
        memcpy(pObjList, m_ObjLine[iLine], SNPPU_MAXOBJ);
        return m_nObjLine[iLine];
    } else
    {
        return 0;
    }
}



void SnesPPURender::UpdateOBJVisibility(Uint8 *pObjY, Uint8 *pObjSize, Int32 iObj, Int32 nObjs)
{
    memset(m_nObjLine, 0, sizeof(m_nObjLine));

	while (nObjs > 0)
	{
		Uint32 uObjY, uObjSize;

		iObj &= 0x7F;

		// get pointer to object
        uObjSize = pObjSize[iObj];
		uObjY    = pObjY[iObj];

        while (uObjSize > 0)
        {
            if (uObjY < SNPPU_MAXLINE)
            {
                if (m_nObjLine[uObjY] < SNPPU_MAXOBJ)
                {
                    m_ObjLine[uObjY][m_nObjLine[uObjY]] = (Uint8)iObj;
                    m_nObjLine[uObjY]++;
                }
            }

            uObjY++;
            uObjSize--;
    		uObjY&= 0xFF;
        }

		iObj++;
		nObjs--;
	}
}






void SnesPPURender::UpdateOBJ(Uint8 *pObjY, Uint8 *pObjSize)
{
	SnesOAMT *pOAM = m_pPPU->GetOAM();
	const SnesPPURegsT *pRegs  = m_pPPU->GetRegs();

	// decode objs
	_DecodeOBJEX(pOAM->ObjEx, m_Objs, SNESPPU_OBJ_NUM, _SnesPPU_OAMSize[(pRegs->obsel >> 5) & 7]);
	_DecodeOBJ(pOAM->Objs, m_Objs, SNESPPU_OBJ_NUM, pObjY, pObjSize);
}

