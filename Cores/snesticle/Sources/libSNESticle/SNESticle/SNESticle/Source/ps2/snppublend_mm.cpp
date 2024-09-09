

#include <stdlib.h>
#include "types.h"
#include "prof.h"
#include "snmask.h"
#include "rendersurface.h"
#include "snppurender.h"
#include "snppublend_mm.h"


extern SnesChrLookupT _SnesPPU_PlaneLookup[2];



//
//
//

static void _Color8to32(Uint32 *pDest32, Uint8 *pSrc8, Uint32 *pPal32, Int32 nPixels, SNMaskT *pColorMask, SNMaskT *pHalfColorMask)
{
	Uint32 pLookup = (Uint32)pPal32;
	Uint128 uLookup;
	SnesChrLookupT *pPlaneLookup = &_SnesPPU_PlaneLookup[1];

	__asm__  __volatile__ (
		"srl       %1,%1,16     \n"
		"pcpyh     %0,%1        \n"
		"pcpyld    %0,%0,%0     \n"
		: "=r" (uLookup)
		: "r" (pLookup)
		);    

	__asm__ __volatile__ (
		".set noreorder \n"
		".align 3           \n"
		"_Color8To32_Loop:           \n"
		"lbu		 $15,0x00(%5)    \n"     // $15 = load color mask 
		"addiu		 %5,%5,1		 \n"
		"lbu		 $16,0x00(%6)    \n"     // $16 = load halfcolor mask 
		"addiu		 %6,%6,1		 \n"
		"ld          $8,0x00(%0)     \n"    // load 8 pixels
		"addiu       %0,%0,8         \n"   

		"sll		$15,$15,3		 \n"    // color mask *8
		"sll		$16,$16,3		 \n"    // halfcolor mask *8
		"addu		$15,$15,%4       \n"     
		"addu		$16,$16,%4       \n"     
		"ld			$15,0x00($15)    \n"    // load color mask bits
		"ld			$16,0x00($16)    \n"    // load halfcolor mask bits
		"dsll		$15,$15,1        \n"    // shift color mask << 1
		"daddu		$15,$15,$16		 \n"

		"pextlb      $8,$15,$8        \n"    // 0maa0mbb0mcc0mdd0mee0mff0mgg0mhh
		"psllh       $8,$8,2         \n"    // pixels << 2
		"pextlh      $9,%3,$8        \n"    // $9 = 700000ee 700000ff 700000gg 700000hh
		"pextuh     $10,%3,$8        \n"    // $10= 700000aa 700000bb 700000cc 700000dd
		"lw         $11,0x00($9)     \n"    // 
		"dsrl32      $9,$9,0         \n"    // 
		"lw         $12,0x00($9)     \n"    // 
		"pcpyud      $9,$9,$9        \n"
		"lw         $13,0x00($9)     \n"    // 
		"dsrl32      $9,$9,0         \n"    // 
		"lw         $14,0x00($9)     \n"    // 

		"pextlw     $15,$12,$11      \n"
		"pextlw     $16,$14,$13      \n"

		"lw         $11,0x00($10)    \n"    // 
		"dsrl32     $10,$10,0        \n"    // 
		"lw         $12,0x00($10)    \n"    // 
		"pcpyud     $10,$10,$10      \n"
		"lw         $13,0x00($10)    \n"    // 
		"dsrl32     $10,$10,0        \n"    // 
		"lw         $14,0x00($10)    \n"    // 

		"pextlw     $11,$12,$11      \n"
		"sd         $15,0x00(%1)     \n"
		"pextlw     $13,$14,$13      \n"
		"sd         $16,0x08(%1)     \n"
		"addiu      %2,%2,-8         \n"
		"sd         $11,0x10(%1)     \n"
		"sd         $13,0x18(%1)     \n"
		"bgtz       %2,_Color8To32_Loop \n"
		"addiu      %1,%1,0x20       \n"
		".set reorder \n"

		: "+r" (pSrc8), "+r" (pDest32), "+r" (nPixels)
		: "r" (uLookup), "r" (pPlaneLookup), "r" (pColorMask), "r" (pHalfColorMask)
		: "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15", "$16"
		);    
}


static void _ColorAdd(Uint32 *pDest, Uint32 *pMain, Uint32 *pSub, Uint32 nPixels)
{
	while (nPixels > 0)
	{

    	__asm__ (
    	    "lq          $8,0x00(%1)     \n"
    	    "lq          $9,0x10(%1)     \n"
    	    "lq         $10,0x20(%1)     \n"
    	    "lq         $11,0x30(%1)     \n"

    	    "lq         $12,0x00(%2)     \n"
    	    "lq         $13,0x10(%2)     \n"
    	    "paddub     $8, $8,$12        \n"
    	    "lq         $14,0x20(%2)     \n"
			"paddub     $9, $9,$13        \n"
    	    "lq         $15,0x30(%2)     \n"
			"paddub     $10, $10,$14        \n"
    	    "sq         $8,0x00(%0)     \n"
			"paddub     $11, $11,$15        \n"
    	    "sq         $9,0x10(%0)     \n"
    	    "sq         $10,0x20(%0)     \n"
    	    "sq         $11,0x30(%0)     \n"

    	    : 
    	    : "r" (pDest), "r" (pMain), "r" (pSub)
            : "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15"
    	 );    

		pMain  +=16;
		pSub   +=16;
		pDest  +=16;
		nPixels-=16;
	}
}


static void _ColorSub(Uint32 *pDest, Uint32 *pMain, Uint32 *pSub, Uint32 nPixels)
{
	while (nPixels > 0)
	{

    	__asm__ (
    	    "lq          $8,0x00(%1)     \n"
    	    "lq          $9,0x10(%1)     \n"
    	    "lq         $10,0x20(%1)     \n"
    	    "lq         $11,0x30(%1)     \n"

    	    "lq         $12,0x00(%2)     \n"
    	    "lq         $13,0x10(%2)     \n"
    	    "psubub     $8, $8,$12        \n"
    	    "lq         $14,0x20(%2)     \n"
			"psubub     $9, $9,$13        \n"
    	    "lq         $15,0x30(%2)     \n"
			"psubub     $10, $10,$14        \n"
    	    "sq         $8,0x00(%0)     \n"
			"psubub     $11, $11,$15        \n"
    	    "sq         $9,0x10(%0)     \n"
    	    "sq         $10,0x20(%0)     \n"
    	    "sq         $11,0x30(%0)     \n"

    	    : 
    	    : "r" (pDest), "r" (pMain), "r" (pSub)
            : "$8", "$9", "$10", "$11", "$12", "$13", "$14", "$15"
    	 );    

		pMain  +=16;
		pSub   +=16;
		pDest  +=16;
		nPixels-=16;
	}
}



void SNPPUBlendMM::Exec(SNPPUBlendInfoT *pInfo, Int32 iLine, Uint32 uFixedColor32, SNMaskT *pColorMask, Bool bAddSub, Uint32 uIntensity)
{
    Uint32 uSaveColor;
    PaletteT *pPal = pInfo->Pal;

	// if subscreen is transparent (no opaque bg or objs), then the output color is coldata register
	// if subscreen is masked by color window, then the output color is black
	// if add/sub is being performed on the pixel and 1/2mode is enabled, then 1/2 color result
	// the 1/2 is done even if the main or sub screen color window is masking it ?!
	uSaveColor = pPal->Color32[0];
	pPal->Color32[0] = uFixedColor32;
	PROF_ENTER("Color8to32");
	_Color8to32(pInfo->uSub32, pInfo->uSub8, pPal->Color32, 256, &pColorMask[1], &pColorMask[2]);
	PROF_LEAVE("Color8to32");
	pPal->Color32[0] = uSaveColor;

	// if mainscreen is transparent (no opaque bg or objs), then the output color is cgram[0]
	// if mainscreen is masked by color window, then the output color is black
	// if add/sub is being performed on the pixel and 1/2mode is enabled, then 1/2 color result
	// the 1/2 is done even if the main or sub screen color window is masking it ?!
	PROF_ENTER("Color8to32");
	_Color8to32(pInfo->uMain32, pInfo->uMain8, pPal->Color32, 256, &pColorMask[0], &pColorMask[2]);
	PROF_LEAVE("Color8to32");

	PROF_ENTER("ColorAdd");
	if (bAddSub)
	{
		_ColorSub(pInfo->uLine32, pInfo->uMain32, pInfo->uSub32, 256);
	} else
	{
		_ColorAdd(pInfo->uLine32, pInfo->uMain32, pInfo->uSub32, 256);
	}
	PROF_LEAVE("ColorAdd");

	// submit line to surface
	PROF_ENTER("SubmitLine");
	m_pTarget->RenderLine32(iLine, pInfo->uLine32, 256);
	PROF_LEAVE("SubmitLine");

}


