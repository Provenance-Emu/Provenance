// GFX-Pipe by Vzzrzzn, modifications by Sjeep

#include <tamtypes.h>
#include <kernel.h>
#include "types.h"
#include "gs.h"
#include "gslist.h"
#include "gpfifo.h"
#include "gpprim.h"

void GPPrimRect(unsigned x1, unsigned y1, unsigned c1, unsigned x2, unsigned y2, unsigned c2, unsigned z, unsigned abe)
{
    GSListSpace(256);

    x1+=0x8000;
    y1+=0x8000;
    x2+=0x8000;
    y2+=0x8000;

    GSGifTagOpen(GIF_SET_TAG(1, 1, 0, 0, 1, 4), 0x5510);
    
	GSGifReg(GS_SET_PRIM(0x06, 0, 0, 0, abe, 0, 1, 0, 0));
	GSGifReg(c1);
	GSGifReg(GS_SET_XYZ(x1,y1,z));
	GSGifReg(GS_SET_XYZ(x2,y2,z));
    
    GSGifTagClose();


}


void GPPrimEnableZBuf(void)
{
    GSListSpace(128);
    GSGifTagOpenAD();
    GSGifRegAD(GS_REG_TEST_1, 0x00070000);
    GSGifTagCloseAD();
}

void GPPrimDisableZBuf(void)
{
    GSListSpace(128);
    GSGifTagOpenAD();
    GSGifRegAD(GS_REG_TEST_1, 0x00030000);
    GSGifTagCloseAD();

}

void GPPrimTexRect(u32 x1, u32 y1, u32 u1, u32 v1, u32 x2, u32 y2, u32 u2, u32 v2, u32 z, u32 colour, unsigned abe)
{
    GSListSpace(256);

    x1+=0x8000;
    y1+=0x8000;
    x2+=0x8000;
    y2+=0x8000;
    
    GSGifTagOpen(GIF_SET_TAG(1, 1, 0, 0, 1, 6), 0xF535310);
    
	GSGifReg(GS_SET_PRIM(0x06, 0, 1, 0, abe, 0, 1, 0, 0));
	GSGifReg(colour);
	GSGifReg(GS_SET_UV(u1, v1));
	GSGifReg(GS_SET_XYZ(x1,y1,z));
	GSGifReg(GS_SET_UV(u2, v2));
	GSGifReg(GS_SET_XYZ(x2,y2,z));
    
    GSGifTagClose();
}


void GPPrimSetTex(u32 tbp, u32 tbw, u32 texwidthlog2, u32 texheightlog2, u32 tpsm, u32 cbp, u32 cbw, u32 cpsm, int filter)
{
    GSListSpace(128);

    GSGifTagOpenAD();
    
    // texclut  <- not really necessary but if i get lazy in future ...
	GSGifRegAD(GS_REG_TEXCLUT,256/64);

    // texflush
    GSGifRegAD(GS_REG_TEXFLUSH,0);

    // texa: TA0 = 128, AEM = 1, TA1 = 0
	GSGifRegAD(GS_REG_TEXA,GS_SET_TEXA(128, 1, 0));

    if (filter)
    {
        // tex1_1
        GSGifRegAD(GS_REG_TEX1_1, (1<<5) | (1<<6));
    } else
    {
        GSGifRegAD(GS_REG_TEX1_2, 0x0000000000000040);
    }

	// tex0_1
//	GSGifRegAD(GS_REG_TEX0_1,GS_SET_TEX0(tbp/256, tbw/64, tpsm, texwidthlog2, texheightlog2, 1, 0, cbp/256, cpsm, 1, 0, 1));
	GSGifRegAD(GS_REG_TEX0_1,GS_SET_TEX0(tbp, tbw/64, tpsm, texwidthlog2, texheightlog2, 1, 0, cbp, cpsm, 1, 0, 1));

    // clamp_1
	GSGifRegAD(GS_REG_CLAMP_1,GS_SET_CLAMP(0, 0, 0, 0, 0, 0));

    // alpha_1: A = Cs, B = Cd, C = As, D = Cd
    GSGifRegAD(GS_REG_ALPHA_1, 0x0000007f00000044);

    // pabe
    GSGifRegAD(GS_REG_PABE, 0x0000000000000000);
    
    GSGifTagCloseAD();
}


// send a byte-packed texture from RDRAM to VRAM
// TBP = VRAM_address
// TBW = buffer_width_in_pixels  -- dependent on pxlfmt
// xofs, yofs in units of pixels
// pxlfmt = 0x00 (32-bit), 0x02 (16-bit), 0x13 (8-bit), 0x14 (4-bit)
// wpxls, hpxls = width, height in units of pixels
// tex -- must be qword aligned !!!
void GPPrimUploadTexture(int TBP, int TBW, int xofs, int yofs, int pxlfmt, void *tex, int wpxls, int hpxls)
{
    int numq;

    numq = wpxls * hpxls;
    switch (pxlfmt)
    {
    case 0x00: numq = (numq+0x03) >> 2; break;
    case 0x02: numq = (numq+0x07) >> 3; break;
    case 0x13: numq = (numq+0x0F) >> 4; break;
    case 0x14: numq = (numq+0x1F) >> 5; break;
    default:   numq = 0;
    }

    GSListSpace(128);

    GSGifTagOpenAD();

//    GSGifRegAD(GS_REG_BITBLTBUF,GS_SET_BITBLTBUF( 0, (TBW/64), pxlfmt,  (TBP/256), (TBW/64), pxlfmt));
    GSGifRegAD(GS_REG_BITBLTBUF,GS_SET_BITBLTBUF( 0, (TBW/64), pxlfmt,  TBP, (TBW/64), pxlfmt));
    GSGifRegAD(GS_REG_TRXPOS,GS_SET_TRXPOS(0,0,xofs,yofs,0));
    GSGifRegAD(GS_REG_TRXREG,GS_SET_TRXREG(wpxls, hpxls));
    GSGifRegAD(GS_REG_TRXDIR,GS_SET_TRXDIR(0));
    
    GSGifTagCloseAD();
    
    // image gif tag
    GSGifTagImage(numq);

    // close last dma cnt
    GSDmaCntClose();

    // dma image data
    GSDmaRef(tex, numq);


    // start new dma cnt
    GSDmaCntOpen();
}









