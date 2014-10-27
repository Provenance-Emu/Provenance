//#define BM_HELPER(fg) { fg(0), fg(1), fg(2), fg(3) }

#define POLY_HELPER_SUB(bm, cv, tm, mam)	\
	 G_Command_DrawPolygon<3 + ((cv & 0x8) >> 3), ((cv & 0x10) >> 4), ((cv & 0x4) >> 2), ((cv & 0x2) >> 1) ? bm : -1, ((cv & 1) ^ 1) & ((cv & 0x4) >> 2), tm, mam >

#define POLY_HELPER_FG(bm, cv)						\
	 {								\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 1),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 1),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
		POLY_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
	 }

#define POLY_HELPER(cv)														\
	{ 															\
	 { POLY_HELPER_FG(0, cv), POLY_HELPER_FG(1, cv), POLY_HELPER_FG(2, cv), POLY_HELPER_FG(3, cv) },			\
	 1 + (3 /*+ ((cv & 0x8) >> 3)*/) * ( 1 + ((cv & 0x4) >> 2) + ((cv & 0x10) >> 4) ) - ((cv & 0x10) >> 4),			\
	 1,															\
 	 false															\
	}

//
//

#define SPR_HELPER_SUB(bm, cv, tm, mam) G_Command_DrawSprite<(cv >> 3) & 0x3,	((cv & 0x4) >> 2), ((cv & 0x2) >> 1) ? bm : -1, ((cv & 1) ^ 1) & ((cv & 0x4) >> 2), tm, mam>

#define SPR_HELPER_FG(bm, cv)						\
	 {								\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 0),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 0 : 0), 1),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 1 : 0), 1),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
		SPR_HELPER_SUB(bm, cv, ((cv & 0x4) ? 2 : 0), 1),	\
	 }


#define SPR_HELPER(cv)												\
	{													\
	 { SPR_HELPER_FG(0, cv), SPR_HELPER_FG(1, cv), SPR_HELPER_FG(2, cv), SPR_HELPER_FG(3, cv) },		\
	 2 + ((cv & 0x4) >> 2) + ((cv & 0x18) ? 0 : 1),								\
	 2 | ((cv & 0x4) >> 2) | ((cv & 0x18) ? 0 : 1),		/* |, not +, for this */			\
	 false													\
	}

//
//

#define LINE_HELPER_SUB(bm, cv, mam) G_Command_DrawLine<((cv & 0x08) >> 3), ((cv & 0x10) >> 4), ((cv & 0x2) >> 1) ? bm : -1, mam>

#define LINE_HELPER_FG(bm, cv)											\
	 {													\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 0),									\
		LINE_HELPER_SUB(bm, cv, 1),									\
		LINE_HELPER_SUB(bm, cv, 1),									\
		LINE_HELPER_SUB(bm, cv, 1),									\
		LINE_HELPER_SUB(bm, cv, 1)									\
	 }

#define LINE_HELPER(cv)												\
	{ 													\
	 { LINE_HELPER_FG(0, cv), LINE_HELPER_FG(1, cv), LINE_HELPER_FG(2, cv), LINE_HELPER_FG(3, cv) },	\
	 3 + ((cv & 0x10) >> 4),										\
	 1,													\
	 false													\
	}

//
//


#define OTHER_HELPER_FG(bm, arg_ptr) { arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr, arg_ptr }
#define OTHER_HELPER(arg_cs, arg_fbcs, arg_ss, arg_ptr) { { OTHER_HELPER_FG(0, arg_ptr), OTHER_HELPER_FG(1, arg_ptr), OTHER_HELPER_FG(2, arg_ptr), OTHER_HELPER_FG(3, arg_ptr) }, arg_cs, arg_fbcs, arg_ss }
#define OTHER_HELPER_X2(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X4(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X2(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X2(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X8(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X4(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X4(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X16(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X8(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X8(arg_cs, arg_fbcs, arg_ss, arg_ptr)
#define OTHER_HELPER_X32(arg_cs, arg_fbcs, arg_ss, arg_ptr)	OTHER_HELPER_X16(arg_cs, arg_fbcs, arg_ss, arg_ptr), OTHER_HELPER_X16(arg_cs, arg_fbcs, arg_ss, arg_ptr)

#define NULLCMD_FG(bm) { NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL } 
#define NULLCMD() { { NULLCMD_FG(0), NULLCMD_FG(1), NULLCMD_FG(2), NULLCMD_FG(3) }, 1, 1, true }


 /* 0x00 */
 NULLCMD(),
 OTHER_HELPER(1, 2, false, G_Command_ClearCache),
 OTHER_HELPER(3, 3, false, G_Command_FBFill),

 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),

 /* 0x10 */
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),

 OTHER_HELPER(1, 1, false,  G_Command_IRQ),

 /* 0x20 */
 POLY_HELPER(0x20),
 POLY_HELPER(0x21),
 POLY_HELPER(0x22),
 POLY_HELPER(0x23),
 POLY_HELPER(0x24),
 POLY_HELPER(0x25),
 POLY_HELPER(0x26),
 POLY_HELPER(0x27),
 POLY_HELPER(0x28),
 POLY_HELPER(0x29),
 POLY_HELPER(0x2a),
 POLY_HELPER(0x2b),
 POLY_HELPER(0x2c),
 POLY_HELPER(0x2d),
 POLY_HELPER(0x2e),
 POLY_HELPER(0x2f),
 POLY_HELPER(0x30),
 POLY_HELPER(0x31),
 POLY_HELPER(0x32),
 POLY_HELPER(0x33),
 POLY_HELPER(0x34),
 POLY_HELPER(0x35),
 POLY_HELPER(0x36),
 POLY_HELPER(0x37),
 POLY_HELPER(0x38),
 POLY_HELPER(0x39),
 POLY_HELPER(0x3a),
 POLY_HELPER(0x3b),
 POLY_HELPER(0x3c),
 POLY_HELPER(0x3d),
 POLY_HELPER(0x3e),
 POLY_HELPER(0x3f),

 LINE_HELPER(0x40),
 LINE_HELPER(0x41),
 LINE_HELPER(0x42),
 LINE_HELPER(0x43),
 LINE_HELPER(0x44),
 LINE_HELPER(0x45),
 LINE_HELPER(0x46),
 LINE_HELPER(0x47),
 LINE_HELPER(0x48),
 LINE_HELPER(0x49),
 LINE_HELPER(0x4a),
 LINE_HELPER(0x4b),
 LINE_HELPER(0x4c),
 LINE_HELPER(0x4d),
 LINE_HELPER(0x4e),
 LINE_HELPER(0x4f),
 LINE_HELPER(0x50),
 LINE_HELPER(0x51),
 LINE_HELPER(0x52),
 LINE_HELPER(0x53),
 LINE_HELPER(0x54),
 LINE_HELPER(0x55),
 LINE_HELPER(0x56),
 LINE_HELPER(0x57),
 LINE_HELPER(0x58),
 LINE_HELPER(0x59),
 LINE_HELPER(0x5a),
 LINE_HELPER(0x5b),
 LINE_HELPER(0x5c),
 LINE_HELPER(0x5d),
 LINE_HELPER(0x5e),
 LINE_HELPER(0x5f),

 SPR_HELPER(0x60),
 SPR_HELPER(0x61),
 SPR_HELPER(0x62),
 SPR_HELPER(0x63),
 SPR_HELPER(0x64),
 SPR_HELPER(0x65),
 SPR_HELPER(0x66),
 SPR_HELPER(0x67),
 SPR_HELPER(0x68),
 SPR_HELPER(0x69),
 SPR_HELPER(0x6a),
 SPR_HELPER(0x6b),
 SPR_HELPER(0x6c),
 SPR_HELPER(0x6d),
 SPR_HELPER(0x6e),
 SPR_HELPER(0x6f),
 SPR_HELPER(0x70),
 SPR_HELPER(0x71),
 SPR_HELPER(0x72),
 SPR_HELPER(0x73),
 SPR_HELPER(0x74),
 SPR_HELPER(0x75),
 SPR_HELPER(0x76),
 SPR_HELPER(0x77),
 SPR_HELPER(0x78),
 SPR_HELPER(0x79),
 SPR_HELPER(0x7a),
 SPR_HELPER(0x7b),
 SPR_HELPER(0x7c),
 SPR_HELPER(0x7d),
 SPR_HELPER(0x7e),
 SPR_HELPER(0x7f),

 /* 0x80 ... 0x9F */
 OTHER_HELPER_X32(4, 2, false, G_Command_FBCopy),

 /* 0xA0 ... 0xBF */
 OTHER_HELPER_X32(3, 2, false, G_Command_FBWrite),

 /* 0xC0 ... 0xDF */
 OTHER_HELPER_X32(3, 2, false, G_Command_FBRead),

 /* 0xE0 */

 NULLCMD(),
 OTHER_HELPER(1, 2, false, G_Command_DrawMode),
 OTHER_HELPER(1, 2, false, G_Command_TexWindow),
 OTHER_HELPER(1, 1, true,  G_Command_Clip0),
 OTHER_HELPER(1, 1, true,  G_Command_Clip1),
 OTHER_HELPER(1, 1, true,  G_Command_DrawingOffset),
 OTHER_HELPER(1, 2, false, G_Command_MaskSetting),

 NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),

 /* 0xF0 */
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),

