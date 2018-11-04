//structs were getting tooo many , so i moved em here !

#pragma once
//bits that affect drawing (for caching params)
#define PCW_DRAW_MASK (0x000000CC)

#pragma pack(push, 1)   // n = 1
//	Global Param/misc structs
//4B
union PCW
{
	struct
	{
		//Obj Control        //affects drawing ?
		u32 UV_16bit    : 1; //0
		u32 Gouraud     : 1; //0
		u32 Offset      : 1; //1
		u32 Texture     : 1; //1
		u32 Col_Type    : 2; //00
		u32 Volume      : 1; //1
		u32 Shadow      : 1; //1

		u32 Reserved    : 8; //0000 0000

		// Group Control
		u32 User_Clip   : 2;
		u32 Strip_Len   : 2;
		u32 Res_2       : 3;
		u32 Group_En    : 1;

		// Para Control
		u32 ListType    : 3;
		u32 Res_1       : 1;
		u32 EndOfStrip  : 1;
		u32 ParaType    : 3;
	};
	u8 obj_ctrl;
	struct
	{
		u32 padin  : 8;
		u32 S6X    : 1;    //set by TA preprocessing if sz64
		u32 padin2 : 19;
		u32 PTEOS  : 4;
	};
	u32 full;
};


//// ISP/TSP Instruction Word

union ISP_TSP
{
	struct
	{
		u32 Reserved    : 20;
		u32 DCalcCtrl   : 1;
		u32 CacheBypass : 1;
		u32 UV_16b      : 1; //In TA they are replaced
		u32 Gouraud     : 1; //by the ones on PCW
		u32 Offset      : 1; //
		u32 Texture     : 1; // -- up to here --
		u32 ZWriteDis   : 1;
		u32 CullMode    : 2;
		u32 DepthMode   : 3;
	};
	u32 full;
};

union ISP_Modvol
{
	struct
	{
		u32 id         : 26;
		u32 VolumeLast : 1;
		u32 CullMode   : 2;
		u32 DepthMode  : 3;
	};
	u32 full;
};


//// END ISP/TSP Instruction Word


//// TSP Instruction Word

union TSP
{
	struct 
	{
		u32 TexV        : 3;
		u32 TexU        : 3;
		u32 ShadInstr   : 2;
		u32 MipMapD     : 4;
		u32 SupSample   : 1;
		u32 FilterMode  : 2;
		u32 ClampV      : 1;
		u32 ClampU      : 1;
		u32 FlipV       : 1;
		u32 FlipU       : 1;
		u32 IgnoreTexA  : 1;
		u32 UseAlpha    : 1;
		u32 ColorClamp  : 1;
		u32 FogCtrl     : 2;
		u32 DstSelect   : 1; // Secondary Accum
		u32 SrcSelect   : 1; // Primary Accum
		u32 DstInstr    : 3;
		u32 SrcInstr    : 3;
	};
	u32 full;
} ;


//// END TSP Instruction Word


/// Texture Control Word
union TCW
{
	struct
	{
		u32 TexAddr   :21;
		u32 Reserved  : 4;
		u32 StrideSel : 1;
		u32 ScanOrder : 1;
		u32 PixelFmt  : 3;
		u32 VQ_Comp   : 1;
		u32 MipMapped : 1;
	} ;
	struct
	{
		u32 pading_0  :21;
		u32 PalSelect : 6;
	} ;
	u32 full;
};

/// END Texture Control Word

//32B
struct Ta_Dma
{
	//0
	//Parameter Control Word
	PCW pcw;
	//4
	union
	{
		u8  data_8[32-4];
		u32 data_32[8-1];
	};
};

//Poly Param types :/

/*
Polygon Type 0(Packed/Floating Color)
0x00    Parameter Control Word
0x04    ISP/TSP Instruction Word
0x08    TSP Instruction Word
0x0C    Texture Control Word
0x10    (ignored)
0x14    (ignored)
0x18    Data Size for Sort DMA
0x1C    Next Address for Sort DMA
*/
//32B
struct TA_PolyParam0
{
	PCW pcw;
	ISP_TSP isp;

	TSP tsp;
	TCW tcw;

	u32 ign1;
	u32 ign2;

	//for sort dma
	u32 SDMA_SIZE;
	u32 SDMA_ADDR;
};

/*
Polygon Type 1(Intensity, no Offset Color)
0x00    Parameter Control Word
0x04    ISP/TSP Instruction Word
0x08    TSP Instruction Word
0x0C    Texture Control Word
0x10    Face Color Alpha
0x14    Face Color R
0x18    Face Color G
0x1C    Face Color B
*/
//32B
struct TA_PolyParam1
{
	PCW pcw;
	ISP_TSP isp;

	TSP tsp;
	TCW tcw;

	f32 FaceColorA;
	f32 FaceColorR;
	f32 FaceColorG;
	f32 FaceColorB;
};


/*
Polygon Type 2(Intensity, use Offset Color)
0x00    Parameter Control Word
0x04    ISP/TSP Instruction Word
0x08    TSP Instruction Word
0x0C    Texture Control Word
0x10    (ignored)
0x14    (ignored)
0x18    Data Size for Sort DMA
0x1C    Next Address for Sort DMA
0x20    Face Color Alpha
0x24    Face Color R
0x28    Face Color G
0x2C    Face Color B
0x30    Face Offset Color Alpha
0x34    Face Offset Color R
0x38    Face Offset Color G
0x3C    Face Offset Color B
*/
//32B
struct TA_PolyParam2A
{
	PCW pcw;
	ISP_TSP isp;

	TSP tsp;
	TCW tcw;

	u32 ign1;
	u32 ign2;

	//for sort dma
	u32 SDMA_SIZE;
	u32 SDMA_ADDR;
};
//32B
struct TA_PolyParam2B
{
	//Face color
	f32 FaceColorA, FaceColorR,FaceColorG, FaceColorB;
	//Offset color :)
	f32 FaceOffsetA, FaceOffsetR, FaceOffsetG, FaceOffsetB;
};
/*
Polygon Type 3(Packed Color, with Two Volumes)
0x00    Parameter Control Word
0x04    ISP/TSP Instruction Word
0x08    TSP Instruction Word 0
0x0C    Texture Control Word 0
0x10    TSP Instruction Word 1
0x14    Texture Control Word 1
0x18    Data Size for Sort DMA
0x1C    Next Address for Sort DMA
*/
//32B
struct TA_PolyParam3
{
	PCW pcw;
	ISP_TSP isp;

	//for 1st volume
	TSP tsp;
	TCW tcw;

	//for 2nd volume format
	TSP tsp1;
	TCW tcw1;

	//for sort dma
	u32 SDMA_SIZE;
	u32 SDMA_ADDR;
};

/*
Polygon Type 4(Intensity, with Two Volumes)
0x00    Parameter Control Word
0x04    ISP/TSP Instruction Word
0x08    TSP Instruction Word 0
0x0C    Texture Control Word 0
0x10    TSP Instruction Word 1
0x14    Texture Control Word 1
0x18    Data Size for Sort DMA
0x1C    Next Address for Sort DMA
0x20    Face Color Alpha 0
0x24    Face Color R 0
0x28    Face Color G 0
0x2C    Face Color B 0
0x30    Face Color Alpha 1
0x34    Face Color R 1
0x38    Face Color G 1
0x3C    Face Color B 1
*/

//32B
struct TA_PolyParam4A
{
	PCW pcw;
	ISP_TSP isp;

	//for 1st volume
	TSP tsp;
	TCW tcw;

	//for 2nd volume format
	TSP tsp1;
	TCW tcw1;

	//for sort dma
	u32 SDMA_SIZE;
	u32 SDMA_ADDR;
};
//32B
struct TA_PolyParam4B
{
	//Face color 0
	f32 FaceColor0A, FaceColor0R,FaceColor0G, FaceColor0B;
	//Face color 1
	f32 FaceColor1A, FaceColor1R, FaceColor1G, FaceColor1B;
};

///Mod vol param types
struct TA_ModVolParam
{
	PCW pcw;
	ISP_TSP isp;

	u32  ign[8-2];
};

//Sprite
struct TA_SpriteParam
{
	PCW pcw;
	ISP_TSP isp;

	TSP tsp;
	TCW tcw;

	u32 BaseCol;
	u32 OffsCol;

	//for sort DMA
	u32 SDMA_SIZE;
	u32 SDMA_ADDR;
};

//	Vertex Param Structs
//28B
struct TA_Vertex0   // (Non-Textured, Packed Color)
{
	f32 xyz[3];
	u32 ignore_1;
	u32 ignore_2;
	u32 BaseCol;
	u32 ignore_3;
};
//28B
struct TA_Vertex1   // (Non-Textured, Floating Color)
{
	f32 xyz[3];
	f32 BaseA, BaseR,
		BaseG, BaseB;
};
//28B
struct TA_Vertex2   // (Non-Textured, Intensity)
{
	f32 xyz[3];
	u32 ignore_1;
	u32 ignore_2;
	f32 BaseInt;
	u32 ignore_3;
};
//28B
struct TA_Vertex3   // (Packed Color)
{
	f32 xyz[3];
	f32 u,v;
	u32 BaseCol;
	u32 OffsCol;
};
//28B
struct TA_Vertex4   // (Packed Color, 16bit UV)
{
	f32 xyz[3];
	u16 v,u; //note the opposite order here !
	u32 ignore_1;
	u32 BaseCol;
	u32 OffsCol;
};
//28B
struct TA_Vertex5A  // (Floating Color)
{
	f32 xyz[3];
	f32 u,v;
	u32 ignore_1;
	u32 ignore_2;
};
//32B
struct TA_Vertex5B
{
	f32 BaseA, BaseR,
		BaseG, BaseB;
	f32 OffsA, OffsR,
		OffsG, OffsB;
};
//28B
struct TA_Vertex6A  // (Floating Color, 16bit UV)
{
	f32 xyz[3];
	u16 v,u; //note the opposite order here !
	u32 ignore_1;
	u32 ignore_2;
	u32 ignore_3;
};
//32B
struct TA_Vertex6B
{
	f32 BaseA, BaseR,
		BaseG, BaseB;
	f32 OffsA, OffsR,
		OffsG, OffsB;
};
//28B
struct TA_Vertex7   // (Intensity)
{
	f32 xyz[3];
	f32 u,v;
	f32 BaseInt;
	f32 OffsInt;

};
//28B
struct TA_Vertex8   // (Intensity, 16bit UV)
{
	f32 xyz[3];
	u16 v,u; //note the opposite order here !
	u32 ignore_1;
	f32 BaseInt;
	f32 OffsInt;
};
//28B
struct TA_Vertex9   // (Non-Textured, Packed Color, with Two Volumes)
{
	f32 xyz[3];
	u32 BaseCol0;
	u32 BaseCol1;
	u32 ignore_1;
	u32 ignore_2;
};
//28B
struct TA_Vertex10   // (Non-Textured, Intensity, with Two Volumes)
{
	f32 xyz[3];
	f32 BaseInt0;
	f32 BaseInt1;
	u32 ignore_1;
	u32 ignore_2;
};

//28B
struct TA_Vertex11A  // (Textured, Packed Color, with Two Volumes)
{
	f32 xyz[3];
	f32 u0,v0;
	u32 BaseCol0, OffsCol0;
};
//32B
struct TA_Vertex11B
{
	f32 u1,v1;
	u32 BaseCol1, OffsCol1;
	u32 ignore_1, ignore_2;
	u32 ignore_3, ignore_4;
};

//28B
struct TA_Vertex12A   // (Textured, Packed Color, 16bit UV, with Two Volumes)
{
	f32 xyz[3];
	u16 v0,u0; //note the opposite order here !
	u32 ignore_1;
	u32 BaseCol0, OffsCol0;
};
//32B
struct TA_Vertex12B
{
	u16 v1,u1; //note the opposite order here !
	u32 ignore_2;
	u32 BaseCol1, OffsCol1;
	u32 ignore_3, ignore_4;
	u32 ignore_5, ignore_6;
};
//28B
struct TA_Vertex13A  // (Textured, Intensity, with Two Volumes)
{
	f32 xyz[3];
	f32 u0,v0;
	f32 BaseInt0, OffsInt0;
};
//32B
struct TA_Vertex13B
{
	f32 u1,v1;
	f32 BaseInt1, OffsInt1;
	u32 ignore_1, ignore_2;
	u32 ignore_3, ignore_4;
};

//28B
struct TA_Vertex14A  // (Textured, Intensity, 16bit UV, with Two Volumes)
{
	f32 xyz[3];
	u16 v0,u0; //note the opposite order here !
	u32 ignore_1;
	f32 BaseInt0, OffsInt0;
};
//32B
struct TA_Vertex14B
{
	u16 v1,u1; //note the opposite order here !
	u32 ignore_2;
	f32 BaseInt1, OffsInt1;
	u32 ignore_3, ignore_4;
	u32 ignore_5, ignore_6;
};

//28B
struct TA_Sprite0A  // Line ?
{
	f32 x0,y0,z0;
	f32 x1,y1,z1;
	f32 x2;

};
//32B
struct TA_Sprite0B  // Line ?
{
	f32 y2,z2;
	f32 x3,y3;
	u32 ignore_1, ignore_2;
	u32 ignore_3, ignore_4;
};
//28B
struct TA_Sprite1A
{
	f32 x0,y0,z0;
	f32 x1,y1,z1;
	f32 x2;
};
//32B
struct TA_Sprite1B
{
	f32 y2,z2;
	f32 x3,y3;
	u32 ignore_1;

	u16 v0; u16 u0;
	u16 v1; u16 u1;
	u16 v2; u16 u2;
};

//28B
struct TA_ModVolA
{
	PCW pcw;
	f32 x0,y0,z0;
	f32 x1,y1,z1;
	f32 x2;  //3+3+1=7*4=28
};
//32B
struct TA_ModVolB
{
	f32 y2,z2;     //2
	u32 ignore[6]; //8
};

//all together , and pcw ;)
struct TA_VertexParam
{
	union
	{
		struct
		{
			PCW pcw;

			union
			{
				u8 Raw[64-4];

				TA_Vertex0 vtx0;
				TA_Vertex1 vtx1;
				TA_Vertex2 vtx2;
				TA_Vertex3 vtx3;
				TA_Vertex4 vtx4;

				struct
				{
					TA_Vertex5A vtx5A;
					TA_Vertex5B vtx5B;
				};

				struct
				{
					TA_Vertex6A vtx6A;
					TA_Vertex6B vtx6B;
				};

				TA_Vertex7  vtx7;
				TA_Vertex8  vtx8;
				TA_Vertex9  vtx9;
				TA_Vertex10 vtx10;



				struct
				{
					TA_Vertex11A vtx11A;
					TA_Vertex11B vtx11B;
				};


				struct
				{
					TA_Vertex12A vtx12A;
					TA_Vertex12B vtx12B;
				};

				struct
				{
					TA_Vertex13A vtx13A;
					TA_Vertex13B vtx13B;
				};

				struct
				{
					TA_Vertex14A vtx14A;
					TA_Vertex14B vtx14B;
				};

				struct
				{
					TA_Sprite0A spr0A;
					TA_Sprite0B spr0B;
				};

				struct
				{
					TA_Sprite1A spr1A;
					TA_Sprite1B spr1B;
				};
			};

		};
		struct
		{
			TA_ModVolA mvolA;
			TA_ModVolB mvolB;
		};
	};
};

#pragma pack(pop)


const u32 ListType_Opaque=0;
const u32 ListType_Opaque_Modifier_Volume=1;
const u32 ListType_Translucent =2;
const u32 ListType_Translucent_Modifier_Volume=3;
const u32 ListType_Punch_Through=4;
#define IsModVolList(list) (((list)&1)!=0)


//Control Parameter
const u32 ParamType_End_Of_List=0;
const u32 ParamType_User_Tile_Clip=1;
const u32 ParamType_Object_List_Set=2;

//Global Parameter
const u32 ParamType_Polygon_or_Modifier_Volume=4;
const u32 ParamType_Sprite=5;

//Vertex , Sprite or ModVolume Parameter
const u32 ParamType_Vertex_Parameter=7;

//Reserved
const u32 ParamType_Reserved_1=3;
const u32 ParamType_Reserved_2=6;