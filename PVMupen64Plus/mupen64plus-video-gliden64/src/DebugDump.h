#ifndef DEBUG_H
#define DEBUG_H

#include "Types.h"

#define DEBUG_LOW		0x01
#define DEBUG_NORMAL	0x02
#define DEBUG_DETAIL	0x04
#define DEBUG_IGNORED	0x08
#define DEBUG_ERROR		0x10

#ifdef DEBUG_DUMP

void DebugMsg(u32 _mode, const char * _format, ...);
void StartDump(u32 _mode);
void EndDump();
void SwitchDump(u32 _mode);
bool IsDump();

static const char *ImageFormatText[] =
{
	"G_IM_FMT_RGBA",
	"G_IM_FMT_YUV",
	"G_IM_FMT_CI",
	"G_IM_FMT_IA",
	"G_IM_FMT_I",
	"G_IM_FMT_INVALID",
	"G_IM_FMT_INVALID",
	"G_IM_FMT_INVALID"
};

static const char *ImageSizeText[] =
{
	"G_IM_SIZ_4b",
	"G_IM_SIZ_8b",
	"G_IM_SIZ_16b",
	"G_IM_SIZ_32b"
};

static const char *SegmentText[] =
{
	"G_MWO_SEGMENT_0", "G_MWO_SEGMENT_1", "G_MWO_SEGMENT_2", "G_MWO_SEGMENT_3",
	"G_MWO_SEGMENT_4", "G_MWO_SEGMENT_5", "G_MWO_SEGMENT_6", "G_MWO_SEGMENT_7",
	"G_MWO_SEGMENT_8", "G_MWO_SEGMENT_9", "G_MWO_SEGMENT_A", "G_MWO_SEGMENT_B",
	"G_MWO_SEGMENT_C", "G_MWO_SEGMENT_D", "G_MWO_SEGMENT_E", "G_MWO_SEGMENT_F"
};

static const char *AAEnableText = "AA_EN";
static const char *DepthCompareText = "Z_CMP";
static const char *DepthUpdateText = "Z_UPD";
static const char *ColorOnCvgText = "CLR_ON_CVG";
static const char *CvgXAlphaText = "CVG_X_ALPHA";
static const char *AlphaCvgSelText = "ALPHA_CVG_SEL";
static const char *ForceBlenderText = "FORCE_BL";

static const char *AlphaCompareText[] =
{
	"G_AC_NONE", "G_AC_THRESHOLD", "G_AC_INVALID", "G_AC_DITHER"
};

static const char *DepthSourceText[] =
{
	"G_ZS_PIXEL", "G_ZS_PRIM"
};

static const char *AlphaDitherText[] =
{
	"G_AD_PATTERN", "G_AD_NOTPATTERN", "G_AD_NOISE", "G_AD_DISABLE"
};

static const char *ColorDitherText[] =
{
	"G_CD_MAGICSQ", "G_CD_BAYER", "G_CD_NOISE", "G_CD_DISABLE"
};

static const char *CombineKeyText[] =
{
	"G_CK_NONE", "G_CK_KEY"
};

static const char *TextureConvertText[] =
{
	"G_TC_CONV", "G_TC_INVALID", "G_TC_INVALID", "G_TC_INVALID", "G_TC_INVALID", "G_TC_FILTCONV", "G_TC_FILT", "G_TC_INVALID"
};

static const char *TextureFilterText[] =
{
	"G_TF_POINT", "G_TF_INVALID", "G_TF_BILERP", "G_TF_AVERAGE"
};

static const char *TextureLUTText[] =
{
	"G_TT_NONE", "G_TT_INVALID", "G_TT_RGBA16", "G_TT_IA16"
};

static const char *TextureLODText[] =
{
	"G_TL_TILE", "G_TL_LOD"
};

static const char *TextureDetailText[] =
{
	"G_TD_CLAMP", "G_TD_SHARPEN", "G_TD_DETAIL"
};

static const char *TexturePerspText[] =
{
	"G_TP_NONE", "G_TP_PERSP"
};

static const char *CycleTypeText[] =
{
	"G_CYC_1CYCLE", "G_CYC_2CYCLE", "G_CYC_COPY", "G_CYC_FILL"
};

static const char *PipelineModeText[] =
{
	"G_PM_NPRIMITIVE", "G_PM_1PRIMITIVE"
};

static const char *CvgDestText[] =
{
	"CVG_DST_CLAMP", "CVG_DST_WRAP", "CVG_DST_FULL", "CVG_DST_SAVE"
};

static const char *DepthModeText[] =
{
	"ZMODE_OPA", "ZMODE_INTER", "ZMODE_XLU", "ZMODE_DEC"
};

static const char *ScissorModeText[] =
{
	"G_SC_NON_INTERLACE", "G_SC_INVALID", "G_SC_EVEN_INTERLACE", "G_SC_ODD_INTERLACE"
};

static const char *saRGBText[] =
{
	"COMBINED", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "NOISE", "1",
	"0", "0", "0", "0",
	"0", "0", "0", "0"
};

static const char *sbRGBText[] =
{
	"COMBINED", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "CENTER", "K4",
	"0", "0", "0", "0",
	"0", "0", "0", "0"
};

static const char *mRGBText[] =
{
	"COMBINED", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "SCALE", "COMBINED_ALPHA",
	"TEXEL0_ALPHA", "TEXEL1_ALPHA", "PRIMITIVE_ALPHA", "SHADE_ALPHA",
	"ENV_ALPHA", "LOD_FRACTION", "PRIM_LOD_FRAC", "K5",
	"0", "0", "0", "0",
	"0", "0", "0", "0",
	"0", "0", "0", "0",
	"0", "0", "0", "0"
};

static const char *aRGBText[] =
{
	"COMBINED", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "1", "0",
};

static const char *saAText[] =
{
	"COMBINED", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "1", "0",
};

static const char *sbAText[] =
{
	"COMBINED", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "1", "0",
};

static const char *mAText[] =
{
	"LOD_FRACTION", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "PRIM_LOD_FRAC", "0",
};

static const char *aAText[] =
{
	"COMBINED", "TEXEL0", "TEXEL1", "PRIMITIVE",
	"SHADE", "ENVIRONMENT", "1", "0",
};



#else

#define DebugMsg(type, A, ...)
#define SwitchDump(A)

#endif // DEBUG_DUMP

#endif // DEBUG_H
