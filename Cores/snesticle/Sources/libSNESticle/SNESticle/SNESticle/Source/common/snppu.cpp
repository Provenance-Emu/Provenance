
#include <string.h>
#include <stdio.h>
#include "types.h"
#include "console.h"
#include "snppu.h"
#include "prof.h"
#include "sntiming.h"
#include "sndebug.h"

#define SNPPU_VERSION_5C77 (0x01)
#define SNPPU_VERSION_5C78 (0x01)

void SnesPPU::WriteCGDATA(Uint8 uData)
{
	Uint32 uCGAddr;

	uCGAddr = m_Regs.cgadd.w >> 1;
	uCGAddr&= SNESPPU_CGRAM_NUM-1;
	if (!(m_Regs.cgadd.w&1))
	{
		// lower byte
		m_CGRAM[uCGAddr] &= 0xFF00;
		m_CGRAM[uCGAddr] |= uData;
	} else
	{
		// upper byte
		m_CGRAM[uCGAddr] &= 0x00FF;
		m_CGRAM[uCGAddr] |= uData << 8;
	}

	// increment color address
	m_Regs.cgadd.w++;

	// update palette for surface
//	m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_PAL);
	m_pRender->UpdateCGRAM(uCGAddr, m_CGRAM[uCGAddr]);
}


Uint8 SnesPPU::ReadCGDATA()
{
	Uint32 uCGAddr;
	Uint8 uData;

	uCGAddr = m_Regs.cgadd.w >> 1;
	uCGAddr&= SNESPPU_CGRAM_NUM-1;
	if (!(m_Regs.cgadd.w&1))
	{
		// lower byte
		uData =  m_CGRAM[uCGAddr] & 0xFF;
	} else
	{
		// upper byte
		uData =  (m_CGRAM[uCGAddr] >> 8);
	}

	// increment color address
	m_Regs.cgadd.w++;

	return uData;
}


static Uint32 _SwizzleVramAddr(Uint32 uVramAddr, Uint32 uFullGraphic)
{
	switch (uFullGraphic)
	{
	case 0:
	default:
		//	0: 0aaaaaaaaaaaaaaa -> 0aaaaaaaaaaaaaaa
		return uVramAddr & 0x7FFF;

	case 1:
		// 32:  0aaaaaaabbbccccc -> 0aaaaaaacccccbbb
		return (uVramAddr & 0x7F00) | ((uVramAddr &0x1F)<<3) | ((uVramAddr>>5) & 0x07);

	case 2:
		//	64:  0aaaaaabbbcccccc -> 0aaaaaaccccccbbb
		return (uVramAddr & 0x7E00) | ((uVramAddr &0x3F)<<3) | ((uVramAddr>>6) & 0x07);

	case 3:
		//	128: 0aaaaabbbccccccc -> 0aaaaacccccccbbb
		return (uVramAddr & 0x7C00) | ((uVramAddr &0x7F)<<3) | ((uVramAddr>>7) & 0x07);
	}
}


void SnesPPU::WriteVMDATAL(Uint8 uData)
{
	SnesReg16T *pVram = (SnesReg16T *)m_VRAM;
	Uint32 uVramAddr;

	// calculate vram address
	uVramAddr = _SwizzleVramAddr(m_Regs.vmaddr.w, (m_Regs.vmain >> 2) & 3);

	// set read latch
	m_Regs.vmreadlatch.w  = m_Regs.vmaddr.w;

	// write to vram
	pVram[uVramAddr].b.l = uData;

	// increment vram addr
	m_Regs.vmaddr.w += m_Regs.vminc[0];

	m_pRender->UpdateVRAM(uVramAddr);
}

void SnesPPU::WriteVMDATAH(Uint8 uData)
{
	SnesReg16T *pVram = (SnesReg16T *)m_VRAM;
	Uint32 uVramAddr;

	// calculate vram address
	uVramAddr = _SwizzleVramAddr(m_Regs.vmaddr.w, (m_Regs.vmain >> 2) & 3);

	// set read latch
	m_Regs.vmreadlatch.w  = m_Regs.vmaddr.w;

	// write to vram
	pVram[uVramAddr].b.h = uData;

	// increment vram addr
	m_Regs.vmaddr.w += m_Regs.vminc[1];

	m_pRender->UpdateVRAM(uVramAddr);
}



void SnesPPU::WriteVMDATALH(Uint8 uDataL, Uint8 uDataH)
{
	SnesReg16T *pVram = (SnesReg16T *)m_VRAM;
	Uint32 uVramAddr;

	// calculate vram address
	uVramAddr = _SwizzleVramAddr(m_Regs.vmaddr.w, (m_Regs.vmain >> 2) & 3);

	// write to vram
	pVram[uVramAddr].b.l = uDataL;

	if (m_Regs.vminc[0])
	{
		// increment vram addr
		m_Regs.vmaddr.w += m_Regs.vminc[0];

		// re-calculate vram address
		uVramAddr = _SwizzleVramAddr(m_Regs.vmaddr.w, (m_Regs.vmain >> 2) & 3);
	}

	// write to vram
	pVram[uVramAddr].b.h = uDataH;

	// increment vram addr
	m_Regs.vmaddr.w += m_Regs.vminc[1];

	m_pRender->UpdateVRAM(uVramAddr);
}



Uint8 SnesPPU::ReadVMDATAL()
{
	Uint8 uData;
	SnesReg16T *pVram = (SnesReg16T *)m_VRAM;
	Uint32 uVramAddr;

	// calculate vram address
	uVramAddr = _SwizzleVramAddr(m_Regs.vmreadlatch.w, (m_Regs.vmain >> 2) & 3);

	if (m_Regs.vminc[0])
	{
		m_Regs.vmreadlatch.w  = m_Regs.vmaddr.w;

		// increment vram addr
		m_Regs.vmaddr.w += m_Regs.vminc[0];
	}

	// fetch data from latch
	uData = pVram[uVramAddr].b.l;

	return uData;
}

Uint8 SnesPPU::ReadVMDATAH()
{
	Uint8 uData;
	SnesReg16T *pVram = (SnesReg16T *)m_VRAM;
	Uint32 uVramAddr;

	// calculate vram address
	uVramAddr = _SwizzleVramAddr(m_Regs.vmreadlatch.w, (m_Regs.vmain >> 2) & 3);

	if (m_Regs.vminc[1])
	{
		m_Regs.vmreadlatch.w  = m_Regs.vmaddr.w;

		// increment vram addr
		m_Regs.vmaddr.w += m_Regs.vminc[1];
	}

	// fetch data from latch
	uData = pVram[uVramAddr].b.h;

	return uData;
}




void SnesPPU::WriteOAMDATA(Uint8 uData)
{
	Uint8	*pOamData = (Uint8 *)&m_OAM;
	Uint32 oamaddr;

	// get oam addr
	oamaddr =  m_Regs.oamaddr.w & 0x3FF;
	
	if (oamaddr >= sizeof(m_OAM))
	{
		oamaddr &= (sizeof(m_OAM) - 1);
	}

	assert(oamaddr < sizeof(m_OAM));

	// write data to OAM
	pOamData[oamaddr] = uData;

	// set oam addr
	m_Regs.oamaddr.w++;

	m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_OBJ);
}

Uint8 SnesPPU::ReadOAMDATA()
{
	Uint8	*pOamData = (Uint8 *)&m_OAM;
	Uint32 oamaddr;

	// get oam addr
	oamaddr =  m_Regs.oamaddr.w & 0x3FF;

	if (oamaddr >= sizeof(m_OAM))
	{
		oamaddr &= (sizeof(m_OAM) - 1);
	}

	assert(oamaddr < sizeof(m_OAM));

	// set oam addr
	m_Regs.oamaddr.w++;

	// write data to OAM
	return pOamData[oamaddr];
}


void SnesPPU::UpdateMatMul()
{
	Int32 iMulA, iMulB;
	Int32 iProduct;

	iMulA = (Int16)m_Regs.m7a.w;
	iMulB = (Int16)m_Regs.m7b.w;

	iProduct = iMulA * (iMulB >> 8);

	m_Regs.mpyl = (Uint8)(iProduct  >> 0);
	m_Regs.mpym = (Uint8)(iProduct  >> 8);
	m_Regs.mpyh = (Uint8)(iProduct  >> 16);
}






void SnesPPU::Write8(Uint32 uAddr, Uint8 uData)
{
	//if (uAddr!= 0x2118 && uAddr!= 0x2119 && uAddr!= 0x2122  && uAddr!= 0x2104)
	//ConDebug("write8[%06X]:ppu.%s=%02X\n", uAddr, GetRegName(uAddr), uData);

	switch (uAddr)
	{
	case 0x2100:	// inidisp (screen display)
		m_Regs.inidisp = uData;
		break;

	case 0x2101:	// obsel (oam size)
		if (m_Regs.obsel != uData)
		{
			m_Regs.obsel = uData;
			m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_OBJ);
		}
		break;

	case 0x2102:	// oamaddl (oam address low)
		m_Regs.oamaddr.w &= 0x8000; 
		m_Regs.oamaddr.w |= (uData &0xFF) << 1;  

		if (m_Regs.oamaddr.w & 0x8000)	
			m_Regs.oampri.w   = (m_Regs.oamaddr.w & 0x1FF) >> 2;

		m_Regs.oamaddrlatch.w = m_Regs.oamaddr.w;
		break;
	case 0x2103:	// oamaddh (oam address high)
		m_Regs.oamaddr.w &= 0x1FF; 
		m_Regs.oamaddr.w |= (uData&0x01) << 9; 
		m_Regs.oamaddr.w |= (uData&0x80) << 8; 

		if (m_Regs.oamaddr.w & 0x8000)	
			m_Regs.oampri.w   = (m_Regs.oamaddr.w & 0x1FF) >> 2;

		m_Regs.oamaddrlatch.w = m_Regs.oamaddr.w;
		break;

	case 0x2104:	// oamdata (oam data)
		WriteOAMDATA(uData);
		break;

	case 0x2105:	// bgmode (screen mode)
        if (m_Regs.bgmode!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_BGSCR | SNESPPURENDER_UPDATE_BGCHR);
		m_Regs.bgmode = uData;
		break;

	case 0x2106:	// mosaic (screen pixelation)
		m_Regs.mosaic = uData;
		break;

	case 0x2107:	// bg1sc (BG1 vram location)
        if (m_Regs.bg1sc!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_BGSCR);
		m_Regs.bg1sc = uData;
		break;
	case 0x2108:	// bg2sc (BG2 vram location)
        if (m_Regs.bg2sc!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_BGSCR);
		m_Regs.bg2sc = uData;
		break;
	case 0x2109:	// bg3sc (BG3 vram location)
        if (m_Regs.bg3sc!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_BGSCR);
		m_Regs.bg3sc = uData;
		break;
	case 0x210A:	// bg4sc (BG4 vram location)
        if (m_Regs.bg4sc!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_BGSCR);
		m_Regs.bg4sc = uData;
		break;
	case 0x210B:	// bg12nba (BG1 & BG2 vram location)
        if (m_Regs.bg12nba !=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_BGCHR);
		m_Regs.bg12nba = uData;
		break;
	case 0x210C:	// bg34nba (BG3 & BG4 vram location)
        if (m_Regs.bg34nba !=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_BGCHR);
		m_Regs.bg34nba = uData;
		break;

	case 0x210D:	// bg1hofs 
		m_Regs.bg1hofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;
	case 0x210E:	// bg1vofs 
		m_Regs.bg1vofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;
	case 0x210F:	// bg2hofs 
		m_Regs.bg2hofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;
	case 0x2110:	// bg2vofs 
		m_Regs.bg2vofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;
	case 0x2111:	// bg3hofs 
		m_Regs.bg3hofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;
	case 0x2112:	// bg3vofs 
		m_Regs.bg3vofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;
	case 0x2113:	// bg4hofs 
		m_Regs.bg4hofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;
	case 0x2114:	// bg4vofs 
		m_Regs.bg4vofs.w = (uData << 8) | m_Regs.bgofslo;
		m_Regs.bgofslo = uData;
		break;

	case 0x2115:	// vmain (video port control)
		{
			static Uint8 _SNPPU_VramInc[4]={1,32,128,128};
			//ConDebug("write8[%06X]:ppu.%s=%02X\n", uAddr, GetRegName(uAddr), uData);
			m_Regs.vmain = uData;
			if (uData & 0x80)
			{	// auto-inc on 2119
				m_Regs.vminc[0] = 0;
				m_Regs.vminc[1] = _SNPPU_VramInc[uData & 3];
			} else
			{
				m_Regs.vminc[0] = _SNPPU_VramInc[uData & 3];
				m_Regs.vminc[1] = 0;
			}
		}
		break;

	case 0x2116:	// vmaddl (video port address low)
		m_Regs.vmaddr.b.l = uData;
		m_Regs.vmreadlatch.b.l  = uData;
		break;
	case 0x2117:	// vmaddh (video port address hi)
		m_Regs.vmaddr.b.h = uData;
		m_Regs.vmreadlatch.b.h  = uData;
		break;

	case 0x2118:	// vmdatal (video port data low)
		WriteVMDATAL(uData);
		break;
	case 0x2119:	// vmdatah (video port data hi)
		WriteVMDATAH(uData);
		break;

	case 0x211A:	// m7sel (mode 7 setting)
		m_Regs.m7sel = uData;
		break;

	case 0x211B:	// m7a
		m_Regs.m7a.Write8LoHi(uData);
		UpdateMatMul();
		break;
	case 0x211C:	// m7b
		m_Regs.m7b.Write8LoHi(uData);
		UpdateMatMul();
		break;
	case 0x211D:	// m7c
		m_Regs.m7c.Write8LoHi(uData);
		break;
	case 0x211E:	// m7d
		m_Regs.m7d.Write8LoHi(uData);
		break;
	case 0x211F:	// m7x
		m_Regs.m7x.Write8LoHi(uData);
		break;
	case 0x2120:	// m7y
		m_Regs.m7y.Write8LoHi(uData);
		break;

	case 0x2121:	// cgadd (color address)
		m_Regs.cgadd.w = uData << 1;
		break;
	case 0x2122:	// cgdata (color data)
		WriteCGDATA(uData);
		break;

	case 0x2123:	// window registers
        if (m_Regs.w12sel!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.w12sel = uData;
		break;
	case 0x2124:	
        if (m_Regs.w34sel!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.w34sel = uData;
		break;
	case 0x2125:
        if (m_Regs.wobjsel!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.wobjsel = uData;
		break;
	case 0x2126:	
        if (m_Regs.wh0!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.wh0 = uData;
		break;
	case 0x2127:	
        if (m_Regs.wh1!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.wh1 = uData;
		break;
	case 0x2128:	
        if (m_Regs.wh2!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.wh2 = uData;
		break;
	case 0x2129:	
        if (m_Regs.wh3!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.wh3 = uData;
		break;
	case 0x212A:	
        if (m_Regs.wbglog!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.wbglog = uData;
		break;
	case 0x212B:	
        if (m_Regs.wobjlog!=uData) 
		    m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_WINDOW);
		m_Regs.wobjlog = uData;
		break;

	case 0x212C:	// TM (main screen designation)
		m_Regs.tm = uData;
		break;
	case 0x212D:	// TS (sub screen designation)
		m_Regs.ts = uData;
		break;
	case 0x212E:	// TMW (window mask main screen designation)
		m_Regs.tmw = uData;
		break;
	case 0x212F:	// TSW (window mask sub screen designation)
		m_Regs.tsw = uData;
		break;

	case 0x2130:	// CGWSEL 
		m_Regs.cgwsel = uData;
		break;
	case 0x2131:	// CGADSUB 
		m_Regs.cgadsub = uData;
		break;
	case 0x2132:	// COLDATA 
		//m_Regs.coldata = 0;
		if (uData & 0x20)
		{
			// red
			m_Regs.coldata &= ~(0x1F << 0);
			m_Regs.coldata |= (uData & 0x1F) << 0;
		}

		if (uData & 0x40)
		{
			// green
			m_Regs.coldata &= ~(0x1F << 5);
			m_Regs.coldata |= (uData & 0x1F) << 5;
		}

		if (uData & 0x80)
		{
			// blue
			m_Regs.coldata &= ~(0x1F << 10);
			m_Regs.coldata |= (uData & 0x1F) << 10;
		}
		break;

	case 0x2133:	// SETINI (screen mode)
		m_Regs.setini = uData;
		break;

	case 0x2134:
	    break;

	case 0x2135: //mpym
		break;

	case 0x2139:
		break;
	case 0x213A:
		break;

	default:
		#if SNES_DEBUG
        if (Snes_bDebugUnhandledIO)
            SnesDebugRead(uAddr);
		#endif
		break;

	}
}



/*
Uint8 SnesPPU::Read8(Uint32 uAddr)
{
	switch (uAddr)
	{
	case 0x2137: // slhv
		ConDebug("readppu_slhv\n");
		return 0;
	case 0x213c: // ophct
		return m_Regs.ophct.Read8();

	case 0x213d: // opvct
		return m_Regs.opvct.Read8();

	case 0x213e: // stat77
		return m_Regs.stat77;

	case 0x213f: // stat78
		m_Regs.ophct.Reset();
		m_Regs.opvct.Reset();
		return m_Regs.stat78;
	case 0x2134: //mpyl
		return m_Regs.mpyl;
	case 0x2135: //mpym
		return m_Regs.mpym;
	case 0x2136: //mpyh
		return m_Regs.mpyh;
	default:
		ConDebug("readppu[%06X]\n", uAddr);
	}
	return 0;
}
*/




void SnesPPU::BeginFrame()
{
	m_uLine   = 0;
    m_bVBlank = FALSE;
}

void SnesPPU::EndFrame()
{
    m_bVBlank = TRUE;

	// toggle field
	m_Regs.stat78^=0x80;

    // forced blanking?
    if (!(m_Regs.inidisp & 0x80))
    {
        // reset oam addr to latched value
        // RTYPE-3 needs this
        m_Regs.oamaddr.w = m_Regs.oamaddrlatch.w;
    }
}


Bool SnesPPU::EnqueueWrite(Uint32 uLine, Uint32 uAddr, Uint8 uData)
{
	return m_Queue.Enqueue(uLine, uAddr, uData);
}

void SnesPPU::Sync(Uint32 uLine)
{
	SNQueueElementT *pElement;

    // are we rendering?
	if (!m_bVBlank)
	{
		while (m_uLine <= uLine)
		{
			// dequeue all pending writes before this line
			while ( (pElement=m_Queue.Dequeue(m_uLine)) != NULL)
			{
				// perform write
				Write8(pElement->uAddr, pElement->uData);
			}

            // are we within a frame?
			if (m_uLine > 0 && m_uLine < (224 + 1))
			{
                // render a line
				PROF_ENTER("PPURender");
				m_pRender->RenderLine(m_uLine);;
				PROF_LEAVE("PPURender");
			}

			m_uLine  ++;
		}
	}

	// dequeue all pending writes
	while ( (pElement=m_Queue.Dequeue()) != NULL)
	{
		// perform write
		Write8(pElement->uAddr, pElement->uData);
	}
}

void SnesPPU::Reset()
{
	m_pRender->SetUpdateFlags(SNESPPURENDER_UPDATE_ALL);
	m_Queue.Reset();
	m_uLine = 0;

	memset(&m_Regs, 0, sizeof(m_Regs));
	memset(&m_CGRAM, 0, sizeof(m_CGRAM));
	memset(&m_VRAM, 0, sizeof(m_VRAM));
	memset(&m_OAM, 0, sizeof(m_OAM));

	// confirmed:
	m_Regs.stat77 =  SNPPU_VERSION_5C77;
	m_Regs.stat78 =  SNPPU_VERSION_5C78; 
}

SnesPPU::SnesPPU()
{
	m_pRender = NULL;
}

#if SNES_DEBUG

Char *SnesPPU::GetRegName(Uint32 uAddr)
{
    switch (uAddr)
    {
	    case 0x2100: return "inidisp";
	    case 0x2101: return "obsel";
	    case 0x2102: return "oamaddl";
	    case 0x2103: return "oamaddh";
	    case 0x2104: return "oamdata";
	    case 0x2105: return "bgmode";
	    case 0x2106: return "mosaic";
	    case 0x2107: return "bg1sc";
	    case 0x2108: return "bg2sc";
	    case 0x2109: return "bg3sc";
	    case 0x210A: return "bg4sc";
	    case 0x210B: return "bg12nba";
	    case 0x210C: return "bg34nba";
	    case 0x210D: return "bg1hofs";
	    case 0x210E: return "bg1vofs";
	    case 0x210F: return "bg2hofs";
	    case 0x2110: return "bg2vofs";
	    case 0x2111: return "bg3hofs";
	    case 0x2112: return "bg3vofs";
	    case 0x2113: return "bg4hofs";
	    case 0x2114: return "bg4vofs";
	    case 0x2115: return "vmain";
	    case 0x2116: return "vmaddl";
	    case 0x2117: return "vmaddh";
	    case 0x2118: return "vmdatal";
	    case 0x2119: return "vmdatah";
	    case 0x211A: return "m7sel";
	    case 0x211B: return "m7a";
	    case 0x211C: return "m7b";
	    case 0x211D: return "m7c";
	    case 0x211E: return "m7d";
	    case 0x211F: return "m7x";
	    case 0x2120: return "m7y";
	    case 0x2121: return "cgadd";
	    case 0x2122: return "cgdata";
	    case 0x2123: return "w12sel";
	    case 0x2124: return "w34sel";
	    case 0x2125: return "wobjsel";
	    case 0x2126: return "wh0";
	    case 0x2127: return "wh1";
	    case 0x2128: return "wh2";
	    case 0x2129: return "wh3";
	    case 0x212A: return "wbglog";
	    case 0x212B: return "wobjlog";
	    case 0x212C: return "tm";
	    case 0x212D: return "ts";
	    case 0x212E: return "tmw";
	    case 0x212F: return "tsw";
	    case 0x2130: return "cgwsel";
	    case 0x2131: return "cgadsub";
	    case 0x2132: return "coldata";
	    case 0x2133: return "setini";
		default:
			return NULL;
    }
}
#endif
