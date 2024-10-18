/*
  _____     ___ ____
   ____|   |    ____|      PS2 OpenSource Project
  |     ___|   |____       (C) 2001 Nick Van Veen (nickvv@xtra.co.nz)
  ------------------------------------------------------------------------
  gs.h
  		Macro's and structures related to the Graphics Synthesiser.

*/
#ifndef _HW1_H_
#define _HW1_H_

#include <tamtypes.h>

//
// GS Privileged registers.
//

#define GS_PMODE	*((volatile unsigned long int*)0x12000000)
#define GS_SMODE2	*((volatile unsigned long int*)0x12000020)
#define GS_DISPFB1	*((volatile unsigned long int*)0x12000070)
#define GS_DISPLAY1	*((volatile unsigned long int*)0x12000080)
#define GS_BGCOLOUR	*((volatile unsigned long int*)0x120000E0)

//
// GIF registers
//

#define GIF_CTRL	*((volatile unsigned long int*)0x12001000)

//
// Misc macro's
//

#define GIF_SET_TAG(nloop, eop, pre, prim, flg, nreg) \
	( (u64)(nloop) | ((u64)(eop)<<15) | ((u64)(pre) << 46) | \
	((u64)(prim)<<47) | ((u64)(flg)<<58) | ((u64)(nreg)<<60) )



// GS Regs
#define GS_REG_PRIM			0x00
#define GS_REG_RGBAQ		0x01
#define GS_REG_UV			0x03
#define GS_REG_XYZ2			0x05
#define GS_REG_TEX0_1		0x06
#define GS_REG_TEX0_2		0x07
#define GS_REG_CLAMP_1		0x08
#define GS_REG_CLAMP_2		0x09
#define GS_REG_TEX1_1		0x14
#define GS_REG_TEX1_2		0x15
#define GS_REG_XYOFFSET_1	0x18
#define GS_REG_XYOFFSET_2	0x19
#define GS_REG_PRMODECONT	0x1A
#define GS_REG_TEXCLUT		0x1C
#define GS_REG_TEXA			0x3B
#define GS_REG_TEXFLUSH		0x3F
#define GS_REG_SCISSOR_1	0x40
#define GS_REG_SCISSOR_2	0x41
#define GS_REG_ALPHA_1		0x42
#define GS_REG_ALPHA_2		0x43
#define GS_REG_DTHE			0x45
#define GS_REG_COLCLAMP		0x46
#define GS_REG_TEST_1		0x47
#define GS_REG_TEST_2		0x48
#define GS_REG_PABE			0x49
#define GS_REG_FRAME_1		0x4C
#define GS_REG_FRAME_2		0x4D
#define GS_REG_ZBUF_1		0x4E
#define GS_REG_ZBUF_2		0x4F
#define GS_REG_BITBLTBUF	0x50
#define GS_REG_TRXPOS		0x51
#define GS_REG_TRXREG		0x52
#define GS_REG_TRXDIR		0x53





#define GS_INTERLACE	1
#define GS_NONINTERLACE	0
#define GS_PAL			3
#define GS_NTSC			2

#define GS_PSMCT32		0x00
#define GS_PSMCT24		0x01
#define GS_PSMCT16		0x02
#define GS_PSMCT16S		0x0A
#define GS_PSGPU24		0x12

#define GS_PSMT8		0x13
#define GS_PSMT4		0x14
#define GS_PSMT8H		0x1B
#define GS_PSMT4HL		0x24
#define GS_PSMT4HH		0x2C

#define GS_PSMZ32		0x00
#define GS_PSMZ24		0x01
#define GS_PSMZ16		0x02
#define GS_PSMZ16S		0x0A

//
// Macro's used to set the contents of GS registers
//

#define GS_SET_ALPHA(a, b, c, d, fix) \
	((u64)(a)        | ((u64)(b) << 2) | ((u64)(c) << 4) | \
	((u64)(d) << 6) | ((u64)(fix) << 32))

#define GS_SET_RGBAQ(r, g, b, a, q) \
	((u64)(r)        | ((u64)(g) << 8) | ((u64)(b) << 16) | \
	((u64)(a) << 24) | ((u64)(q) << 32))

#define GS_SET_RGBA(r, g, b, a) \
	((u64)(r)        | ((u64)(g) << 8) | ((u64)(b) << 16) | ((u64)(a) << 24))

#define GS_SET_XYZ(x, y, z) \
	((u64)(x&0xFFFF) | ((u64)(y&0xFFFF) << 16) | ((u64)(z&0xFFFF) << 32))

#define GS_SET_UV(u, v) ((u64)(u&0xFFFF) | ((u64)(v&0xFFFF) << 16))


#define GS_SET_FRAME(fbp, fbw, psm, fbmask) \
	( (u64)(fbp) | (u64)((u64)(fbw) << 16) | (u64)((u64)(psm) << 24) | (u64)((u64)(fbmask) << 32) )

#define GS_SET_XYOFFSET(ofx, ofy) ((u64)(ofx) | ((u64)(ofy) << 32))

#define GS_SET_ZBUF(zbp, psm, zmsk) \
	( (u64)(zbp) | ((u64)(psm) << 24) | ((u64)(zmsk) << 32) )

#define GS_SET_TEST(ate, atst, aref, afail, date, datm, zte, ztst) \
	( (u64)(ate)         | ((u64)(atst) << 1) | ((u64)(aref) << 4)  | ((u64)(afail) << 12) | \
	((u64)(date) << 14) | ((u64)(datm) << 15) | ((u64)(zte) << 16)  | ((u64)(ztst) << 17) )

#define GS_SET_SCISSOR(scax0, scax1, scay0, scay1) \
	( (u64)(scax0) | ((u64)(scax1) << 16) | ((u64)(scay0) << 32) | ((u64)(scay1) << 48) )

#define GS_SET_PRIM(prim, iip, tme, fge, abe, aa1, fst, ctxt, fix) \
	((u64)(prim)      | ((u64)(iip) << 3)  | ((u64)(tme) << 4) | \
	((u64)(fge) << 5) | ((u64)(abe) << 6)  | ((u64)(aa1) << 7) | \
	((u64)(fst) << 8) | ((u64)(ctxt) << 9) | ((u64)(fix) << 10))

#define GS_SET_DISPFB(fbp, fbw, psm, dbx, dby) \
	((u64)(fbp) | ((u64)(fbw) << 9) | ((u64)(psm) << 15) | ((u64)(dbx) << 32) | ((u64)(dby) << 43))

#define GS_SET_BITBLTBUF(sbp, sbw, spsm, dbp, dbw, dpsm) \
	((u64)(sbp)         | ((u64)(sbw) << 16) | \
	((u64)(spsm) << 24) | ((u64)(dbp) << 32) | \
	((u64)(dbw) << 48)  | ((u64)(dpsm) << 56))

#define GS_SET_TRXDIR(xdr) ((u64)(xdr))

#define GS_SET_TRXPOS(ssax, ssay, dsax, dsay, dir) \
	((u64)(ssax)        | ((u64)(ssay) << 16) | \
	((u64)(dsax) << 32) | ((u64)(dsay) << 48) | \
	((u64)(dir) << 59))

#define GS_SET_TRXREG(rrw, rrh) \
	((u64)(rrw) | ((u64)(rrh) << 32))

#define GS_SET_TEX0(tbp, tbw, psm, tw, th, tcc, tfx, cbp, cpsm, csm, csa, cld) \
	((u64)(tbp)         | ((u64)(tbw) << 14) | ((u64)(psm) << 20)  | ((u64)(tw) << 26) | \
	((u64)(th) << 30)   | ((u64)(tcc) << 34) | ((u64)(tfx) << 35)  | ((u64)(cbp) << 37) | \
	((u64)(cpsm) << 51) | ((u64)(csm) << 55) | ((u64)(csa) << 56)  | ((u64)(cld) << 61))

#define GS_SET_CLAMP(wms, wmt, minu, maxu, minv, maxv) \
	((u64)(wms)         | ((u64)(wmt) << 2) | ((u64)(minu) << 4)  | ((u64)(maxu) << 14) | \
	((u64)(minv) << 24) | ((u64)(maxv) << 34))

#define GS_SET_TEXA(ta0, aem, ta1) \
	((u64)(ta0) | ((u64)(aem) << 15) | ((u64)(ta1) << 32))

typedef struct {
	unsigned long NLOOP:15;
	unsigned long EOP:1;
	unsigned long pad1:16;
	unsigned long pad2:14;
	unsigned long PRE:1;
	unsigned long PRIM:11;
	unsigned long FLG:2;
	unsigned long NREG:4;
	unsigned long REGS0:4;
	unsigned long REGS1:4;
	unsigned long REGS2:4;
	unsigned long REGS3:4;
	unsigned long REGS4:4;
	unsigned long REGS5:4;
	unsigned long REGS6:4;
	unsigned long REGS7:4;
	unsigned long REGS8:4;
	unsigned long REGS9:4;
	unsigned long REGS10:4;
	unsigned long REGS11:4;
	unsigned long REGS12:4;
	unsigned long REGS13:4;
	unsigned long REGS14:4;
	unsigned long REGS15:4;
} GifTag __attribute__((aligned(16)));

void GS_InitGraph(int mode, int interlace); // Initialise the GS
void GS_SetEnv(int width, int height, int fbp1, int fbp2, int psm, int zbp, int zbpsm); // Set up drawing enviroment
void GS_SetDrawFB(int buffer); // Set the active drawing enviroment
void GS_SetCrtFB(int buffer); // Set the active display enviroment
void GS_SetDispMode(int dx, int dy, int width, int height); // Set the GS display mode
u64 GS_GetFrameReg();
u64 GS_GetOffsetReg();

//
// DMA stuff - will be moved to dmalib src soon.
//

typedef struct {
	u16		qwc;
	u32		pad1:10;
	u32		pce:2;
	u32		id:3;
	u32		irq:1;
	u32		*next;
	u64		pad2;
} DmaTag __attribute__ ((aligned(16)));


#define DMA_SET_TAG(qwc,pce,id,irq,next) \
  ( (u64)(qwc) | ((u64)(pce) << 16) | ((u64)(id) << 28) | ((u64)(irq) << 31) | ((u64)(next) << 32) )

#define DMA_ID_REFE		0x00
#define DMA_ID_CNT		0x01
#define DMA_ID_NEXT		0x02
#define DMA_ID_REF		0x03
#define DMA_ID_REFS		0x04
#define DMA_ID_CALL		0x05
#define DMA_ID_RET		0x06
#define DMA_ID_END		0x07

#endif /* _HW1_H_ */


