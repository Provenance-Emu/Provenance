
/*
	TA-VTX handling

	Parsing of the TA stream and generation of vertex data !
*/

#include "ta.h"
#include "ta_ctx.h"
#include "pvr_mem.h"
#include "Renderer_if.h"

u32 ta_type_lut[256];


#define TACALL DYNACALL
#ifdef RELEASE
#undef verify
#define verify(x)
#endif
#define PLD(ptr,offs) //  __asm __volatile ( "pld	 [%0, #" #offs "]\n"::"r" (ptr): );

#if HOST_CPU==CPU_X86
extern u32 TA_VTXC,TA_SPRC,TA_EOSC,TA_PPC,TA_SPC,TA_EOLC,TA_V64HC;

#define TA_VTX (TA_VTXC++)
#define TA_SPR (TA_SPRC++)
#define TA_EOS (TA_EOSC++)
#define TA_PP (TA_PPC++)
#define TA_SP (TA_SPC++)
#define TA_EOL (TA_EOLC++)
#define TA_V64H (TA_V64HC++)
#else
#define TA_VTX 
#define TA_SPR 
#define TA_EOS 
#define TA_PP 
#define TA_SP 
#define TA_EOL 
#define TA_V64H 
#endif

	
//cache state vars
u32 tileclip_val=0;

u8 f32_su8_tbl[65536];
/*
__forceinline
u8 float_to_satu8(float val)
{
	return f32_su8_tbl[((u32&)val)>>16];
}
*/
#define float_to_satu8(val) f32_su8_tbl[((u32&)val)>>16]

/*
	This uses just 1k of lookup, but does more calcs
	The full 64k table will be much faster -- as only a small sub-part of it will be used anyway (the same 1k)
*/
u8 float_to_satu8_2(float val)
{
	s32 vl=(s32&)val>>16;
	u32 m1=(vl-0x3b80)>>31;	//1 if smaller 0x3b80 or negative
	u32 m2=(vl-0x3f80)>>31;  //1 if smaller 0x3f80 or negative
	u32 vo=vl-0x3b80;
	vo &= (~m1>>22);
	
	return f32_su8_tbl[0x3b80+vo] | (~m2>>24);
}

#define saturate01(x) (((s32&)x)<0?0:(s32&)x>0x3f800000?1:x)
u8 float_to_satu8_math(float val)
{
	return u8(saturate01(val)*255);
}

//vdec state variables
ModTriangle* lmr=0;
PolyParam nullPP;

PolyParam* CurrentPP=&nullPP;
List<PolyParam>* CurrentPPlist;

//TA state vars	
DECL_ALIGN(4) static u8 FaceBaseColor[4];
DECL_ALIGN(4) static u8 FaceOffsColor[4];
DECL_ALIGN(4) static u32 SFaceBaseColor;
DECL_ALIGN(4) static u32 SFaceOffsColor;



//splitter function lookup
extern u32 ta_type_lut[256];

void TA_ListCont();
void TA_ListInit();
void TA_SoftReset();

//hehe
//as it seems, bit 1,2 are type, bit 0 is mod volume :p


//misc ones
const u32 ListType_None=-1;


const u32 SZ32=1;
const u32 SZ64=2;

#include "ta_structs.h"

typedef Ta_Dma* DYNACALL TaListFP(Ta_Dma* data,Ta_Dma* data_end);
typedef void TACALL TaPolyParamFP(void* ptr);

//#define TaCmd ((TaListFP*&)sh4rcb.tacmd_void)
TaListFP* TaCmd;
	
u32 CurrentList;
TaListFP* VerxexDataFP;
bool ListIsFinished[5];

f32 f16(u16 v)
{
	u32 z=v<<16;
	return *(f32*)&z;
}

	
#if HOST_CPU==CPU_X86
extern u32 TA_VTX_O;
#define TA_VTX_OVH(n) (TA_VTX_O+=n);
#else
#define TA_VTX_OVH(n)
#endif



#define vdrc vd_rc

	//Splitter function (normally ta_dma_main , modified for split dma's)
	//extern TaListFP* TaCmd;

template<u32 instance>
class FifoSplitter
{
public:

	static void ta_list_start(u32 new_list)
	{
		verify(CurrentList==ListType_None);
		//verify(ListIsFinished[new_list]==false);
		//printf("Starting list %d\n",new_list);
		CurrentList=new_list;
		StartList(CurrentList);
	}

	static Ta_Dma* DYNACALL NullVertexData(Ta_Dma* data,Ta_Dma* data_end)
	{
		printf("TA: Invalid state, ignoring VTX data\n");
		return data+SZ32;
	}

	//part : 0 fill all data , 1 fill upper 32B , 2 fill lower 32B
	//Poly decoder , will be moved to pvr code
	template <u32 poly_type,u32 part>
	__forceinline
	static Ta_Dma* TACALL ta_handle_poly(Ta_Dma* data,Ta_Dma* data_end)
	{
		TA_VertexParam* vp=(TA_VertexParam*)data;
		u32 rv=0;

		if (part==2)
		{
			TA_V64H;
			TaCmd=ta_main;
		}

		switch (poly_type)
		{
#define ver_32B_def(num) \
case num : {\
AppendPolyVertex##num(&vp->vtx##num);\
rv=SZ32; TA_VTX; }\
break;

			//32b , always in one pass :)
			ver_32B_def(0);//(Non-Textured, Packed Color)
			ver_32B_def(1);//(Non-Textured, Floating Color)
			ver_32B_def(2);//(Non-Textured, Intensity)
			ver_32B_def(3);//(Textured, Packed Color)
			ver_32B_def(4);//(Textured, Packed Color, 16bit UV)
			ver_32B_def(7);//(Textured, Intensity)
			ver_32B_def(8);//(Textured, Intensity, 16bit UV)
			ver_32B_def(9);//(Non-Textured, Packed Color, with Two Volumes)
			ver_32B_def(10);//(Non-Textured, Intensity,	with Two Volumes)

#undef ver_32B_def

#define ver_64B_def(num) \
case num : {\
/*process first half*/\
	if (part!=2)\
	{\
	TA_VTX;\
	rv+=SZ32;\
	AppendPolyVertex##num##A(&vp->vtx##num##A);\
	}\
	/*process second half*/\
	if (part==0)\
	{\
	AppendPolyVertex##num##B(&vp->vtx##num##B);\
	rv+=SZ32;\
	}\
	else if (part==2)\
	{\
	AppendPolyVertex##num##B((TA_Vertex##num##B*)data);\
	rv+=SZ32;\
	}\
	}\
	break;


			//64b , may be on 2 pass
			ver_64B_def(5);//(Textured, Floating Color)
			ver_64B_def(6);//(Textured, Floating Color, 16bit UV)
			ver_64B_def(11);//(Textured, Packed Color,	with Two Volumes)	
			ver_64B_def(12);//(Textured, Packed Color, 16bit UV, with Two Volumes)
			ver_64B_def(13);//(Textured, Intensity,	with Two Volumes)
			ver_64B_def(14);//(Textured, Intensity, 16bit UV, with Two Volumes)
#undef ver_64B_def
		}

		return data+rv;
	};

	//Code Splitter/routers
		
	//helper function for dummy dma's.Handles 32B and then switches to ta_main for next data
	static Ta_Dma* TACALL ta_dummy_32(Ta_Dma* data,Ta_Dma* data_end)
	{
		TaCmd=ta_main;
		return data+SZ32;
	}
	static Ta_Dma* TACALL ta_modvolB_32(Ta_Dma* data,Ta_Dma* data_end)
	{
		AppendModVolVertexB((TA_ModVolB*)data);
		TaCmd=ta_main;
		return data+SZ32;
	}
		
	static Ta_Dma* TACALL ta_mod_vol_data(Ta_Dma* data,Ta_Dma* data_end)
	{
		TA_VertexParam* vp=(TA_VertexParam*)data;
		TA_VTX;
		if (data==data_end)
		{
			AppendModVolVertexA(&vp->mvolA);
			//32B more needed , 32B done :)
			TaCmd=ta_modvolB_32;
			return data+SZ32;
		}
		else
		{
			//all 64B done
			AppendModVolVertexA(&vp->mvolA);
			AppendModVolVertexB(&vp->mvolB);
			return data+SZ64;
		}
	}
	static Ta_Dma* TACALL ta_spriteB_data(Ta_Dma* data,Ta_Dma* data_end)
	{
		TA_V64H;
		//32B more needed , 32B done :)
		TaCmd=ta_main;
			
		AppendSpriteVertexB((TA_Sprite1B*)data);

		return data+SZ32;
	}
	static Ta_Dma* TACALL ta_sprite_data(Ta_Dma* data,Ta_Dma* data_end)
	{
		TA_SPR;
		verify(data->pcw.ParaType==ParamType_Vertex_Parameter);
		if (data==data_end)
		{
			//32B more needed , 32B done :)
			TaCmd=ta_spriteB_data;

			TA_VertexParam* vp=(TA_VertexParam*)data;

			AppendSpriteVertexA(&vp->spr1A);
			return data+SZ32;
		}
		else
		{
			TA_VertexParam* vp=(TA_VertexParam*)data;

			AppendSpriteVertexA(&vp->spr1A);
			AppendSpriteVertexB(&vp->spr1B);

			//all 64B doneisimooooo la la la :*iiiiii  niarj
			return data+SZ64;
		}
	}

	template <u32 poly_type,u32 poly_size>
	static Ta_Dma* TACALL ta_poly_data(Ta_Dma* data,Ta_Dma* data_end)
	{
		__assume(data<=data_end);

					//If SZ64  && 32 bytes
#define IS_FIST_HALF ((poly_size!=SZ32) && (data==data_end))

					//If SZ32 && >=32 bytes
					//If SZ64 && > 32 bytes
#define HAS_FULL_DATA (poly_size==SZ32 ? (data<=data_end) : (data<data_end))

#define ITER verify(data->pcw.ParaType==ParamType_Vertex_Parameter);\
PLD(data,128); \
ta_handle_poly<poly_type,0>(data,0); \
if (data->pcw.EndOfStrip) \
	goto strip_end; \
data+=poly_size;

		if (IS_FIST_HALF)
			goto fist_half;

		do
		{
			ITER
		} while (HAS_FULL_DATA);
			
		if (IS_FIST_HALF)
		{
		fist_half:
			ta_handle_poly<poly_type,1>(data,0);
			if (data->pcw.EndOfStrip) EndPolyStrip();
			TaCmd=ta_handle_poly<poly_type,2>;
					
			data+=SZ32;
		}
			
		return data;

strip_end:
		TaCmd=ta_main;
		if (data->pcw.EndOfStrip)
			EndPolyStrip();
		TA_EOS;
		return data+poly_size;
	}

	static void TACALL AppendPolyParam2Full(void* vpp)
	{
		Ta_Dma* pp=(Ta_Dma*)vpp;

		AppendPolyParam2A((TA_PolyParam2A*)&pp[0]);
		AppendPolyParam2B((TA_PolyParam2B*)&pp[1]);
	}

	static void TACALL AppendPolyParam4Full(void* vpp)
	{
		Ta_Dma* pp=(Ta_Dma*)vpp;

		AppendPolyParam4A((TA_PolyParam4A*)&pp[0]);
		AppendPolyParam4B((TA_PolyParam4B*)&pp[1]);
	}
	//Second part of poly data
	template <int t>
	static Ta_Dma* TACALL ta_poly_B_32(Ta_Dma* data,Ta_Dma* data_end)
	{
		if (t==2)
			AppendPolyParam2B((TA_PolyParam2B*)data);
		else
			AppendPolyParam4B((TA_PolyParam4B*)data);
	
		TaCmd=ta_main;
		return data+SZ32;
	}

public:
	
	//Group_En bit seems ignored, thanks p1pkin 
#define group_EN() /*if (data->pcw.Group_En) */{ TileClipMode(data->pcw.User_Clip);}
	static Ta_Dma* TACALL ta_main(Ta_Dma* data,Ta_Dma* data_end)
	{
		do
		{
			PLD(data,128);
			switch (data->pcw.ParaType)
			{
				//Control parameter
				//32Bw3
			case ParamType_End_Of_List:
				{

					if (CurrentList==ListType_None)
					{
						CurrentList=data->pcw.ListType;
						//printf("End_Of_List : list error\n");
					}
					else
					{
						//end of list should be all 0's ...
						EndList(CurrentList);//end a list olny if it was realy started
					}

					//printf("End list %X\n",CurrentList);
					ListIsFinished[CurrentList]=true;
					CurrentList=ListType_None;
					VerxexDataFP=NullVertexData;
					data+=SZ32;
					TA_EOL;
				}
				break;
				//32B
			case ParamType_User_Tile_Clip:
				{

					SetTileClip(data->data_32[3]&63,data->data_32[4]&31,data->data_32[5]&63,data->data_32[6]&31);
					data+=SZ32;
				}
				break;
				//32B
			case ParamType_Object_List_Set:
				{

					die("ParamType_Object_List_Set");
					// *cough* ignore it :p
					data+=SZ32;
				}
				break;

				//Global Parameter
				//ModVolue :32B
				//PolyType :32B/64B
			case ParamType_Polygon_or_Modifier_Volume:
				{

					TA_PP;
					group_EN();
					//Yep , C++ IS lame & limited
					#include "ta_const_df.h"
					if (CurrentList==ListType_None)
						ta_list_start(data->pcw.ListType);	//start a list ;)

					if (IsModVolList(CurrentList))
					{
						//accept mod data
						StartModVol((TA_ModVolParam*)data);
						VerxexDataFP=ta_mod_vol_data;
						data+=SZ32;
					}
					else
					{

						u32 uid=ta_type_lut[data->pcw.obj_ctrl];
						u32 psz=uid>>30;
						u32 pdid=(u8)(uid);
						u32 ppid=(u8)(uid>>8);

						VerxexDataFP=ta_poly_data_lut[pdid];
							

						if (data != data_end || psz==1)
						{

							//poly , 32B/64B
							ta_poly_param_lut[ppid](data);
							data+=psz;
						}
						else
						{

							//AppendPolyParam64A((TA_PolyParamA*)data);
							//64b , first part
							ta_poly_param_a_lut[ppid](data);
							//Handle next 32B ;)
							TaCmd=ta_poly_param_b_lut[ppid];
							data+=SZ32;
						}
					}
				}
				break;
				//32B
				//Sets Sprite info , and switches to ta_sprite_data function
			case ParamType_Sprite:
				{

					TA_SP;
					group_EN();
					if (CurrentList==ListType_None)
						ta_list_start(data->pcw.ListType);	//start a list ;)

					VerxexDataFP=ta_sprite_data;
					//printf("Sprite \n");
					AppendSpriteParam((TA_SpriteParam*)data);
					data+=SZ32;
				}
				break;

				//Variable size
			case ParamType_Vertex_Parameter:
				//log ("vtx");
				{

					//printf("VTX:0x%08X\n",VerxexDataFP);
					//verify(VerxexDataFP!=NullVertexData);
					data=VerxexDataFP(data,data_end);
				}
				break;

				//not handled
				//Assumed to be 32B
			case 3:
			case 6:
				{
					die("Unhandled parameter");
					data+=SZ32;
				}
				break;
			}
		}
		while(data<=data_end);
		return data;
	}

	//Fill in lookup table
	FifoSplitter()
	{
		for (int i=0;i<256;i++)
		{
			PCW pcw;
			pcw.obj_ctrl=i;
			u32 rv=	poly_data_type_id(pcw);
			u32 type= poly_header_type_size(pcw);

			if (type& 0x80)
				rv|=(SZ64<<30);
			else
				rv|=(SZ32<<30);

			rv|=(type&0x7F)<<8;

			ta_type_lut[i]=rv;
		}
		VerxexDataFP = NullVertexData;
	}
	/*
	Volume,Col_Type,Texture,Offset,Gouraud,16bit_UV

	0   0   0   (0) x   invalid Polygon Type 0  Polygon Type 0
	0   0   1   x   x   0       Polygon Type 0  Polygon Type 3
	0   0   1   x   x   1       Polygon Type 0  Polygon Type 4

	0   1   0   (0) x   invalid Polygon Type 0  Polygon Type 1
	0   1   1   x   x   0       Polygon Type 0  Polygon Type 5
	0   1   1   x   x   1       Polygon Type 0  Polygon Type 6

	0   2   0   (0) x   invalid Polygon Type 1  Polygon Type 2
	0   2   1   0   x   0       Polygon Type 1  Polygon Type 7
	0   2   1   0   x   1       Polygon Type 1  Polygon Type 8
	0   2   1   1   x   0       Polygon Type 2  Polygon Type 7
	0   2   1   1   x   1       Polygon Type 2  Polygon Type 8

	0   3   0   (0) x   invalid Polygon Type 0  Polygon Type 2
	0   3   1   x   x   0       Polygon Type 0  Polygon Type 7
	0   3   1   x   x   1       Polygon Type 0  Polygon Type 8

	1   0   0   (0) x   invalid Polygon Type 3  Polygon Type 9
	1   0   1   x   x   0       Polygon Type 3  Polygon Type 11
	1   0   1   x   x   1       Polygon Type 3  Polygon Type 12

	1   2   0   (0) x   invalid Polygon Type 4  Polygon Type 10
	1   2   1   x   x   0       Polygon Type 4  Polygon Type 13
	1   2   1   x   x   1       Polygon Type 4  Polygon Type 14

	1   3   0   (0) x   invalid Polygon Type 3  Polygon Type 10
	1   3   1   x   x   0       Polygon Type 3  Polygon Type 13
	1   3   1   x   x   1       Polygon Type 3  Polygon Type 14

	Sprites :
	(0) (0) 0 (0) (0) invalid Sprite  Sprite Type 0
	(0) (0) 1  x   (0) (1)     Sprite  Sprite Type 1

	*/
	//helpers 0-14
	static u32 poly_data_type_id(PCW pcw)
	{
		if (pcw.Texture)
		{
			//textured
			if (pcw.Volume==0)
			{	//single volume
				if (pcw.Col_Type==0)
				{
					if (pcw.UV_16bit==0)
						return 3;           //(Textured, Packed Color , 32b uv)
					else
						return 4;           //(Textured, Packed Color , 16b uv)
				}
				else if (pcw.Col_Type==1)
				{
					if (pcw.UV_16bit==0)
						return 5;           //(Textured, Floating Color , 32b uv)
					else
						return 6;           //(Textured, Floating Color , 16b uv)
				}
				else
				{
					if (pcw.UV_16bit==0)
						return 7;           //(Textured, Intensity , 32b uv)
					else
						return 8;           //(Textured, Intensity , 16b uv)
				}
			}
			else
			{
				//two volumes
				if (pcw.Col_Type==0)
				{
					if (pcw.UV_16bit==0)
						return 11;          //(Textured, Packed Color, with Two Volumes)	

					else
						return 12;          //(Textured, Packed Color, 16bit UV, with Two Volumes)

				}
				else if (pcw.Col_Type==1)
				{
					//die ("invalid");
					return 0xFFFFFFFF;
				}
				else
				{
					if (pcw.UV_16bit==0)
						return 13;          //(Textured, Intensity, with Two Volumes)	

					else
						return 14;          //(Textured, Intensity, 16bit UV, with Two Volumes)
				}
			}
		}
		else
		{
			//non textured
			if (pcw.Volume==0)
			{	//single volume
				if (pcw.Col_Type==0)
					return 0;               //(Non-Textured, Packed Color)
				else if (pcw.Col_Type==1)
					return 1;               //(Non-Textured, Floating Color)
				else
					return 2;               //(Non-Textured, Intensity)
			}
			else
			{
				//two volumes
				if (pcw.Col_Type==0)
					return 9;               //(Non-Textured, Packed Color, with Two Volumes)
				else if (pcw.Col_Type==1)
				{
					//die ("invalid");
					return 0xFFFFFFFF;
				}
				else
				{
					return 10;              //(Non-Textured, Intensity, with Two Volumes)
				}
			}
		}
	}
	//0-4 | 0x80
	static u32 poly_header_type_size(PCW pcw)
	{
		if (pcw.Volume == 0)
		{
			if ( pcw.Col_Type<2 ) //0,1
			{
				return 0  | 0;              //Polygon Type 0 -- SZ32
			}
			else if ( pcw.Col_Type == 2 )
			{
				if (pcw.Texture)
				{
					if (pcw.Offset)
					{
						return 2 | 0x80;    //Polygon Type 2 -- SZ64
					}
					else
					{
						return 1 | 0;       //Polygon Type 1 -- SZ32
					}
				}
				else
				{
					return 1 | 0;           //Polygon Type 1 -- SZ32
				}
			}
			else	//col_type ==3
			{
				return 0 | 0;               //Polygon Type 0 -- SZ32
			}
		}
		else
		{
			if ( pcw.Col_Type==0 ) //0
			{
				return 3 | 0;              //Polygon Type 3 -- SZ32
			}
			else if ( pcw.Col_Type==2 ) //2
			{
				return 4 | 0x80;           //Polygon Type 4 -- SZ64
			}
			else if ( pcw.Col_Type==3 ) //3
			{
				return 3 | 0;              //Polygon Type 3 -- SZ32
			}
			else
			{
				return 0xFFDDEEAA;//die ("data->pcw.Col_Type==1 && volume ==1");
			}
		}
	}


	void vdec_init()
	{
		VDECInit();
		TaCmd=ta_main;
		CurrentList = ListType_None;
		ListIsFinished[0]=ListIsFinished[1]=ListIsFinished[2]=ListIsFinished[3]=ListIsFinished[4]=false;
	}
		
	__forceinline
		static void SetTileClip(u32 xmin,u32 ymin,u32 xmax,u32 ymax)
	{
		u32 rv=tileclip_val & 0xF0000000;
		rv|=xmin; //6 bits
		rv|=xmax<<6; //6 bits
		rv|=ymin<<12; //5 bits
		rv|=ymax<<17; //5 bits
		tileclip_val=rv;
	}

	__forceinline
		static void TileClipMode(u32 mode)
	{
		tileclip_val=(tileclip_val&(~0xF0000000)) | (mode<<28);
	}

	//list handling
	__forceinline
		static void StartList(u32 ListType)
	{
		if (ListType==ListType_Opaque)
			CurrentPPlist=&vdrc.global_param_op;
		else if (ListType==ListType_Punch_Through)
			CurrentPPlist=&vdrc.global_param_pt;
		else if (ListType==ListType_Translucent)
			CurrentPPlist=&vdrc.global_param_tr;

		CurrentPP=&nullPP;
	}

	__forceinline
		static void EndList(u32 ListType)
	{
		CurrentPP=&nullPP;
		CurrentPPlist=0;
		if (ListType==ListType_Opaque_Modifier_Volume)
		{
			ISP_Modvol p;
			p.id=vdrc.modtrig.used();
			*vdrc.global_param_mvo.Append()=p;
		}
	}

	/*
	if (CurrentPP==0 || CurrentPP->pcw.full!=pp->pcw.full || \
	CurrentPP->tcw.full!=pp->tcw.full || \
	CurrentPP->tsp.full!=pp->tsp.full || \
	CurrentPP->isp.full!=pp->isp.full	) \
	*/
	//Polys  -- update code on sprites if that gets updated too --
	template<class T>
	static void glob_param_bdc_(T* pp)
	{
		if (CurrentPP->pcw.full!=pp->pcw.full || 
			CurrentPP->tcw.full!=pp->tcw.full || 
			CurrentPP->tsp.full!=pp->tsp.full || 
			CurrentPP->isp.full!=pp->isp.full	) 
		{
			PolyParam* d_pp=CurrentPP;
			if (CurrentPP->count!=0)
			{
				d_pp=CurrentPPlist->Append(); 
				CurrentPP=d_pp;
			}
			d_pp->first=vdrc.idx.used(); 
			d_pp->count=0; 

			d_pp->isp=pp->isp; 
			d_pp->tsp=pp->tsp; 
			d_pp->tcw=pp->tcw;
			d_pp->pcw=pp->pcw; 
			d_pp->tileclip=tileclip_val;

			d_pp->texid = -1;

			if (d_pp->pcw.Texture) {
				d_pp->texid = renderer->GetTexture(d_pp->tsp,d_pp->tcw);
			}
		}
	}

	#define glob_param_bdc(pp) glob_param_bdc_( (TA_PolyParam0*)pp)

	#define poly_float_color_(to,a,r,g,b) \
		to[0] = float_to_satu8(r);	\
		to[1] = float_to_satu8(g);	\
		to[2] = float_to_satu8(b);	\
		to[3] = float_to_satu8(a);


	#define poly_float_color(to,src) \
		poly_float_color_(to,pp->src##A,pp->src##R,pp->src##G,pp->src##B)

	//poly param handling
	__forceinline
		static void TACALL AppendPolyParam0(void* vpp)
	{
		TA_PolyParam0* pp=(TA_PolyParam0*)vpp;

		glob_param_bdc(pp);
	}
	__forceinline
		static void TACALL AppendPolyParam1(void* vpp)
	{
		TA_PolyParam1* pp=(TA_PolyParam1*)vpp;

		glob_param_bdc(pp);
		poly_float_color(FaceBaseColor,FaceColor);
	}
	__forceinline
		static void TACALL AppendPolyParam2A(void* vpp)
	{
		TA_PolyParam2A* pp=(TA_PolyParam2A*)vpp;

		glob_param_bdc(pp);
	}
	__forceinline
		static void TACALL AppendPolyParam2B(void* vpp)
	{
		TA_PolyParam2B* pp=(TA_PolyParam2B*)vpp;

		poly_float_color(FaceBaseColor,FaceColor);
		poly_float_color(FaceOffsColor,FaceOffset);
	}
	__forceinline
		static void TACALL AppendPolyParam3(void* vpp)
	{
		TA_PolyParam3* pp=(TA_PolyParam3*)vpp;

		glob_param_bdc(pp);
	}
	__forceinline
		static void TACALL AppendPolyParam4A(void* vpp)
	{
		TA_PolyParam4A* pp=(TA_PolyParam4A*)vpp;

		glob_param_bdc(pp);
	}
	__forceinline
		static void TACALL AppendPolyParam4B(void* vpp)
	{
		TA_PolyParam4B* pp=(TA_PolyParam4B*)vpp;

		poly_float_color(FaceBaseColor,FaceColor0);
	}

	//Poly Strip handling
	//We unite Strips together by duplicating the [last,first].On odd sized strips
	//a second [first] vert is needed to make sure Culling works fine :)
	__forceinline
		static void EndPolyStrip()
	{
		CurrentPP->count=vdrc.idx.used() - CurrentPP->first;

		int vbase=vdrc.verts.used();

		*vdrc.idx.Append()=vbase-1;
		*vdrc.idx.Append()=vbase;

		if (CurrentPP->count&1)
			*vdrc.idx.Append()=vbase;
#if STRIPS_AS_PPARAMS
		if (CurrentPPlist==&vdrc.global_param_tr)
		{
			PolyParam* d_pp =CurrentPPlist->Append(); 
			*d_pp=*CurrentPP;
			CurrentPP=d_pp;
			d_pp->first=vdrc.idx.used(); 
			d_pp->count=0; 
		}
#endif
	}


	
	static inline void update_fz(float z)
	{
		if ((s32&)vdrc.fZ_max<(s32&)z && (s32&)z<0x49800000)
			vdrc.fZ_max=z;
	}

		//Poly Vertex handlers
		//Append vertex base
	template<class T>
	static Vertex* vert_cvt_base_(T* vtx)
	{
		f32 invW=vtx->xyz[2];
		*vdrc.idx.Append()=vdrc.verts.used();
		Vertex* cv=vdrc.verts.Append();
		cv->x=vtx->xyz[0];
		cv->y=vtx->xyz[1];
		cv->z=invW;
		update_fz(invW);
		return cv;
	}

	#define vert_cvt_base Vertex* cv=vert_cvt_base_((TA_Vertex0*)vtx)

		//Resume vertex base (for B part)
	#define vert_res_base \
		Vertex* cv=vdrc.verts.LastPtr();

		//uv 16/32
	#define vert_uv_32(u_name,v_name) \
		cv->u = (vtx->u_name);\
		cv->v = (vtx->v_name);

	#define vert_uv_16(u_name,v_name) \
		cv->u = f16(vtx->u_name);\
		cv->v = f16(vtx->v_name);

		//Color conversions
	#define vert_packed_color_(to,src) \
		{ \
		u32 t=src; \
		to[2] = (u8)(t);t>>=8;\
		to[1] = (u8)(t);t>>=8;\
		to[0] = (u8)(t);t>>=8;\
		to[3] = (u8)(t);      \
		}

	#define vert_float_color_(to,a,r,g,b) \
		to[0] = float_to_satu8(r); \
		to[1] = float_to_satu8(g); \
		to[2] = float_to_satu8(b); \
		to[3] = float_to_satu8(a);

		//Macros to make thins easier ;)
	#define vert_packed_color(to,src) \
		vert_packed_color_(cv->to,vtx->src);

	#define vert_float_color(to,src) \
		vert_float_color_(cv->to,vtx->src##A,vtx->src##R,vtx->src##G,vtx->src##B)

		//Intensity handling

		//Notes:
		//Alpha doesn't get intensity
		//Intensity is clamped before the mul, as well as on face color to work the same as the hardware. [Fixes red dog]

	#define vert_face_base_color(baseint) \
		{ u32 satint=float_to_satu8(vtx->baseint); \
		cv->col[0] = FaceBaseColor[0]*satint/256;  \
		cv->col[1] = FaceBaseColor[1]*satint/256;  \
		cv->col[2] = FaceBaseColor[2]*satint/256;  \
		cv->col[3] = FaceBaseColor[3]; }

	#define vert_face_offs_color(offsint) \
		{ u32 satint=float_to_satu8(vtx->offsint); \
		cv->spc[0] = FaceOffsColor[0]*satint/256;  \
		cv->spc[1] = FaceOffsColor[1]*satint/256;  \
		cv->spc[2] = FaceOffsColor[2]*satint/256;  \
		cv->spc[3] = FaceOffsColor[3]; }

	//vert_float_color_(cv->spc,FaceOffsColor[3],FaceOffsColor[0]*satint/256,FaceOffsColor[1]*satint/256,FaceOffsColor[2]*satint/256); }


	//(Non-Textured, Packed Color)
	__forceinline
		static void AppendPolyVertex0(TA_Vertex0* vtx)
	{
		vert_cvt_base;

		vert_packed_color(col,BaseCol);
	}

	//(Non-Textured, Floating Color)
	__forceinline
		static void AppendPolyVertex1(TA_Vertex1* vtx)
	{
		vert_cvt_base;

		vert_float_color(col,Base);
	}

	//(Non-Textured, Intensity)
	__forceinline
		static void AppendPolyVertex2(TA_Vertex2* vtx)
	{
		vert_cvt_base;

		vert_face_base_color(BaseInt);
	}

	//(Textured, Packed Color)
	__forceinline
		static void AppendPolyVertex3(TA_Vertex3* vtx)
	{
		vert_cvt_base;

		vert_packed_color(col,BaseCol);
		vert_packed_color(spc,OffsCol);

		vert_uv_32(u,v);
	}

	//(Textured, Packed Color, 16bit UV)
	__forceinline
		static void AppendPolyVertex4(TA_Vertex4* vtx)
	{
		vert_cvt_base;

		vert_packed_color(col,BaseCol);
		vert_packed_color(spc,OffsCol);

		vert_uv_16(u,v);
	}

	//(Textured, Floating Color)
	__forceinline
		static void AppendPolyVertex5A(TA_Vertex5A* vtx)
	{
		vert_cvt_base;

		//Colors are on B

		vert_uv_32(u,v);
	}

	__forceinline
		static void AppendPolyVertex5B(TA_Vertex5B* vtx)
	{
		vert_res_base;

		vert_float_color(col,Base);
		vert_float_color(spc,Offs);
	}

	//(Textured, Floating Color, 16bit UV)
	__forceinline
		static void AppendPolyVertex6A(TA_Vertex6A* vtx)
	{
		vert_cvt_base;

		//Colors are on B

		vert_uv_16(u,v);
	}
	__forceinline
		static void AppendPolyVertex6B(TA_Vertex6B* vtx)
	{
		vert_res_base;

		vert_float_color(col,Base);
		vert_float_color(spc,Offs);
	}

	//(Textured, Intensity)
	__forceinline
		static void AppendPolyVertex7(TA_Vertex7* vtx)
	{
		vert_cvt_base;

		vert_face_base_color(BaseInt);
		vert_face_offs_color(OffsInt);

		vert_uv_32(u,v);
	}

	//(Textured, Intensity, 16bit UV)
	__forceinline
		static void AppendPolyVertex8(TA_Vertex8* vtx)
	{
		vert_cvt_base;

		vert_face_base_color(BaseInt);
		vert_face_offs_color(OffsInt);

		vert_uv_16(u,v);

	}

	//(Non-Textured, Packed Color, with Two Volumes)
	__forceinline
		static void AppendPolyVertex9(TA_Vertex9* vtx)
	{
		vert_cvt_base;

		vert_packed_color(col,BaseCol0);
	}

	//(Non-Textured, Intensity,	with Two Volumes)
	__forceinline
		static void AppendPolyVertex10(TA_Vertex10* vtx)
	{
		vert_cvt_base;

		vert_face_base_color(BaseInt0);
	}

	//(Textured, Packed Color,	with Two Volumes)	
	__forceinline
		static void AppendPolyVertex11A(TA_Vertex11A* vtx)
	{
		vert_cvt_base;

		vert_packed_color(col,BaseCol0);
		vert_packed_color(spc,OffsCol0);

		vert_uv_32(u0,v0);
	}
	__forceinline
		static void AppendPolyVertex11B(TA_Vertex11B* vtx)
	{
		vert_res_base;

	}

	//(Textured, Packed Color, 16bit UV, with Two Volumes)
	__forceinline
		static void AppendPolyVertex12A(TA_Vertex12A* vtx)
	{
		vert_cvt_base;

		vert_packed_color(col,BaseCol0);
		vert_packed_color(spc,OffsCol0);

		vert_uv_16(u0,v0);
	}
	__forceinline
		static void AppendPolyVertex12B(TA_Vertex12B* vtx)
	{
		vert_res_base;

	}

	//(Textured, Intensity,	with Two Volumes)
	__forceinline
		static void AppendPolyVertex13A(TA_Vertex13A* vtx)
	{
		vert_cvt_base;

		vert_face_base_color(BaseInt0);
		vert_face_offs_color(OffsInt0);

		vert_uv_32(u0,v0);
	}
	__forceinline
		static void AppendPolyVertex13B(TA_Vertex13B* vtx)
	{
		vert_res_base;

	}

	//(Textured, Intensity, 16bit UV, with Two Volumes)
	__forceinline
		static void AppendPolyVertex14A(TA_Vertex14A* vtx)
	{
		vert_cvt_base;

		vert_face_base_color(BaseInt0);
		vert_face_offs_color(OffsInt0);

		vert_uv_16(u0,v0);
	}
	__forceinline
		static void AppendPolyVertex14B(TA_Vertex14B* vtx)
	{
		vert_res_base;

	}

	//Sprites
	__forceinline
		static void AppendSpriteParam(TA_SpriteParam* spr)
	{
		//printf("Sprite\n");
		PolyParam* d_pp=CurrentPP;
		if (CurrentPP->count!=0)
		{
			d_pp=CurrentPPlist->Append(); 
			CurrentPP=d_pp;
		}

		d_pp->first=vdrc.idx.used(); 
		d_pp->count=0;
		d_pp->isp=spr->isp; 
		d_pp->tsp=spr->tsp; 
		d_pp->tcw=spr->tcw; 
		d_pp->pcw=spr->pcw; 
		d_pp->tileclip=tileclip_val;

		d_pp->texid = -1;
		
		if (d_pp->pcw.Texture) {
			d_pp->texid = renderer->GetTexture(d_pp->tsp,d_pp->tcw);
		}

		SFaceBaseColor=spr->BaseCol;
		SFaceOffsColor=spr->OffsCol;
        
        d_pp->isp.CullMode ^= 1;
	}

	#define append_sprite(indx) \
		vert_packed_color_(cv[indx].col,SFaceBaseColor)\
		vert_packed_color_(cv[indx].spc,SFaceOffsColor)
		//cv[indx].base_int=1;\
		//cv[indx].offset_int=1;

	#define append_sprite_yz(indx,set,st2) \
		cv[indx].y=sv->y##set; \
		cv[indx].z=sv->z##st2; \
		update_fz(sv->z##st2);

	#define sprite_uv(indx,u_name,v_name) \
		cv[indx].u = f16(sv->u_name);\
		cv[indx].v = f16(sv->v_name);

	//Sprite Vertex Handlers
	__forceinline
		static void AppendSpriteVertexA(TA_Sprite1A* sv)
	{
        u16* idx=vdrc.idx.Append(6);
		u32 vbase=vdrc.verts.used();

		idx[0]=vbase+0;
		idx[1]=vbase+1;
		idx[2]=vbase+2;
		idx[3]=vbase+3;
        idx[4]=vbase+3;
        idx[5]=vbase+4;

        CurrentPP->count=vdrc.idx.used()-CurrentPP->first-2;

		Vertex* cv = vdrc.verts.Append(4);

		//Fill static stuff
		append_sprite(0);
		append_sprite(1);
		append_sprite(2);
		append_sprite(3);

		cv[2].x=sv->x0;
		cv[2].y=sv->y0;
		cv[2].z=sv->z0;
		update_fz(sv->z0);

		cv[3].x=sv->x1;
		cv[3].y=sv->y1;
		cv[3].z=sv->z1;
		update_fz(sv->z1);

		cv[1].x=sv->x2;
	}
	static void CaclulateSpritePlane(Vertex* base)
	{
		const Vertex& A=base[2];
		const Vertex& B=base[3];
		const Vertex& C=base[1];
		Vertex& P=base[0];
		//Vector AB = B-A;
		//Vector AC = C-A;
		//Vector AP = P-A;
		float AC_x=C.x-A.x,AC_y=C.y-A.y,AC_z=C.z-A.z,
			AB_x=B.x-A.x,AB_y=B.y-A.y,AB_z=B.z-A.z,
			AP_x=P.x-A.x,AP_y=P.y-A.y;

		float P_y=P.y,P_x=P.x,P_z=P.z,A_x=A.x,A_y=A.y,A_z=A.z;

		float AB_v=B.v-A.v,AB_u=B.u-A.u,
			AC_v=C.v-A.v,AC_u=C.u-A.u;

		float /*P_v,P_u,*/A_v=A.v,A_u=A.u;

		float k3 = (AC_x * AB_y - AC_y * AB_x);

		if (k3 == 0)
		{
			//throw new Exception("WTF?!");
		}

		float k2 = (AP_x * AB_y - AP_y * AB_x) / k3;

		float k1 = 0;

		if (AB_x == 0)
		{
			//if (AB_y == 0)
			//	;
			//    //throw new Exception("WTF?!");

			k1 = (P_y - A_y - k2 * AC_y) / AB_y;
		}
		else
		{
			k1 = (P_x - A_x - k2 * AC_x) / AB_x;
		}

		P.z = A_z + k1 * AB_z + k2 * AC_z;
		P.u = A_u + k1 * AB_u + k2 * AC_u;
		P.v = A_v + k1 * AB_v + k2 * AC_v;
	}
	__forceinline
		static void AppendSpriteVertexB(TA_Sprite1B* sv)
	{
		vert_res_base;
		cv-=3;

		cv[1].y=sv->y2;
		cv[1].z=sv->z2;
		update_fz(sv->z2);

		cv[0].x=sv->x3;
		cv[0].y=sv->y3;


		sprite_uv(2, u0,v0);
		sprite_uv(3, u1,v1);
		sprite_uv(1, u2,v2);
		//sprite_uv(0, u0,v2);//or sprite_uv(u2,v0); ?

		CaclulateSpritePlane(cv);

		update_fz(cv[0].z);

		/*
		if (CurrentPP->count)
		{
			Vertex* vert=vert_reappend;
			vert[-1].x=vert[0].x;
			vert[-1].y=vert[0].y;
			vert[-1].z=vert[0].z;
			CurrentPP->count+=2;
		}*/
#if STRIPS_AS_PPARAMS
		if (CurrentPPlist==&vdrc.global_param_tr)
		{
			PolyParam* d_pp =CurrentPPlist->Append(); 
			*d_pp=*CurrentPP;
			CurrentPP=d_pp;
			d_pp->first=vdrc.idx.used(); 
			d_pp->count=0;
		}
#endif
	}

	//ModVolumes

	//Mod Volume Vertex handlers
	static void StartModVol(TA_ModVolParam* param)
	{
		if (CurrentList!=ListType_Opaque_Modifier_Volume)
			return;
		ISP_Modvol* p=vdrc.global_param_mvo.Append();
		p->full=param->isp.full;
		p->VolumeLast=param->pcw.Volume;
		p->id=vdrc.modtrig.used();
	}
	__forceinline
		static void AppendModVolVertexA(TA_ModVolA* mvv)
	{
		if (CurrentList!=ListType_Opaque_Modifier_Volume)
			return;
		lmr=vdrc.modtrig.Append();

		lmr->x0=mvv->x0;
		lmr->y0=mvv->y0;
		lmr->z0=mvv->z0;
		//update_fz(mvv->z0);

		lmr->x1=mvv->x1;
		lmr->y1=mvv->y1;
		lmr->z1=mvv->z1;
		//update_fz(mvv->z1);

		lmr->x2=mvv->x2;
	}

	__forceinline
		static void AppendModVolVertexB(TA_ModVolB* mvv)
	{
		if (CurrentList!=ListType_Opaque_Modifier_Volume)
			return;
		lmr->y2=mvv->y2;
		lmr->z2=mvv->z2;
		//update_fz(mvv->z2);
	}

	static void VDECInit()
	{
		vd_rc.Clear();

		//allocate storage for BG poly
		vd_rc.global_param_op.Append();
		u16* idx=vd_rc.idx.Append(4);
		int vbase=vd_rc.verts.used();

		idx[0]=vbase+0;
		idx[1]=vbase+1;
		idx[2]=vbase+2;
		idx[3]=vbase+3;
		vd_rc.verts.Append(4);
	}
};


FifoSplitter<0> TAFifo0;

int ta_parse_cnt = 0;

/*
	Also: gotta stage textures here
*/
bool ta_parse_vdrc(TA_context* ctx)
{
	verify( vd_ctx == 0);
	vd_ctx = ctx;
	vd_rc = vd_ctx->rend;
	
	ta_parse_cnt++;
	if (0 == (ta_parse_cnt %  ( settings.pvr.ta_skip + 1)))
	{
		TAFifo0.vdec_init();
		
		Ta_Dma* ta_data=(Ta_Dma*)vd_rc.proc_start;
		Ta_Dma* ta_data_end=((Ta_Dma*)vd_rc.proc_end)-1;

		do
		{
			ta_data =TaCmd(ta_data,ta_data_end);

		}
		while(ta_data<=ta_data_end);
	}
	bool overrun = ctx->rend.Overrun;

	vd_ctx->rend = vd_rc;
	vd_ctx = 0;
	ctx->rend_inuse.Unlock();

	ctx->rend.Overrun = overrun;
	if (overrun)
		printf("Warning: TA context overrun\n");

	return !overrun;
}


//decode a vertex in the native pvr format
//used for bg poly
void decode_pvr_vertex(u32 base,u32 ptr,Vertex* cv)
{
	//ISP
	//TSP
	//TCW
	ISP_TSP isp;
	TSP tsp;
	TCW tcw;

	isp.full=vri(base);
	tsp.full=vri(base+4);
	tcw.full=vri(base+8);

	//XYZ
	//UV
	//Base Col
	//Offset Col

	//XYZ are _allways_ there :)
	cv->x=vrf(ptr);ptr+=4;
	cv->y=vrf(ptr);ptr+=4;
	cv->z=vrf(ptr);ptr+=4;

	if (isp.Texture)
	{	//Do texture , if any
		if (isp.UV_16b)
		{
			u32 uv=vri(ptr);
			cv->u = f16((u16)uv);
			cv->v = f16((u16)(uv >> 16));
			ptr+=4;
		}
		else
		{
			cv->u=vrf(ptr);ptr+=4;
			cv->v=vrf(ptr);ptr+=4;
		}
	}

	//Color
	u32 col=vri(ptr);ptr+=4;
	vert_packed_color_(cv->col,col);
	if (isp.Offset)
	{
		//Intensity color (can be missing too ;p)
		u32 col=vri(ptr);ptr+=4;
		vert_packed_color_(cv->spc,col);
	}
}


#define satu255(x) (((s32&)x)<0?0:(s32&)x>0x437f0000?255:(u8)x)

void vtxdec_init()
{
	/*
		0x3b80 ~ 0x3f80 -> actual useful range. Rest is clamping to 0 or 255 ~
	*/

	for (u32 i=0;i<65536;i++)
	{
		u32 fr=i<<16;
		
		f32_su8_tbl[i]=float_to_satu8_math((f32&)fr);
	}

	for (u32 i=0;i<65536;i++)
	{
		u32 fr=i<<16;
		f32 ff=(f32&)fr;

		verify(float_to_satu8_math(ff)==float_to_satu8_2(ff));
		verify(float_to_satu8_math(ff)==float_to_satu8(ff));

	}
}


static OnLoad ol_vtxdec(&vtxdec_init);

void FillBGP(TA_context* ctx)
{
	
	//Render pre-code
	//--BG poly
	u32 param_base=PARAM_BASE & 0xF00000;


	PolyParam* bgpp=ctx->rend.global_param_op.head();
	Vertex* cv=ctx->rend.verts.head();

	bool PSVM=FPU_SHAD_SCALE.intesity_shadow!=0; //double parameters for volumes

	//Get the strip base
	u32 strip_base=(param_base + ISP_BACKGND_T.tag_address*4);	//this is *not* VRAM_MASK on purpose.It fixes naomi bios and quite a few naomi games
	//i have *no* idea why that happens, they manage to set the render target over there as well
	//and that area is *not* written by the games (they instead write the params on 000000 instead of 800000)
	//could be a h/w bug ? param_base is 400000 and tag is 100000*4
	//Calculate the vertex size
	//Update: Looks like I was handling the bank interleave wrong for 16 megs ram, could that be it?

	u32 strip_vs=3 + ISP_BACKGND_T.skip;
	u32 strip_vert_num=ISP_BACKGND_T.tag_offset;

	if (PSVM && ISP_BACKGND_T.shadow)
	{
		strip_vs+=ISP_BACKGND_T.skip;//2x the size needed :p
	}
	strip_vs*=4;
	//Get vertex ptr
	u32 vertex_ptr=strip_vert_num*strip_vs+strip_base +3*4;
	//now , all the info is ready :p

	bgpp->texid = -1;

	bgpp->isp.full=vri(strip_base);
	bgpp->tsp.full=vri(strip_base+4);
	bgpp->tcw.full=vri(strip_base+8);
	bgpp->count=4;
	bgpp->first=0;
	bgpp->tileclip=0;//disabled ! HA ~

	bgpp->isp.DepthMode=7;// -> this makes things AWFULLY slow .. sometimes
	bgpp->isp.CullMode=0;// -> so that its not culled, or somehow else hidden !
	bgpp->tsp.FogCtrl=2;
	//Set some pcw bits .. I should really get rid of pcw ..
	bgpp->pcw.UV_16bit=bgpp->isp.UV_16b;
	bgpp->pcw.Gouraud=bgpp->isp.Gouraud;
	bgpp->pcw.Offset=bgpp->isp.Offset;
	bgpp->pcw.Texture=bgpp->isp.Texture;

	float scale_x= (SCALER_CTL.hscale) ? 2.f:1.f;	//if AA hack the hacked pos value hacks
	for (int i=0;i<3;i++)
	{
		decode_pvr_vertex(strip_base,vertex_ptr,&cv[i]);
		vertex_ptr+=strip_vs;
	}

	float ZV=0;

	cv[0].x=-2000;
	cv[0].y=-2000;
	cv[0].z=ISP_BACKGND_D.f;

	cv[1].x=640*scale_x + 2000;
	cv[1].y=0;
	cv[1].z=ISP_BACKGND_D.f;

	cv[2].x=-2000;
	cv[2].y=480+2000;
	cv[2].z=ISP_BACKGND_D.f;

	cv[3]=cv[2];
	cv[3].x=640*scale_x+2000;
	cv[3].y=480+2000;
	cv[3].z=ISP_BACKGND_D.f;
}

bool UsingAutoSort()
{
	if (((FPU_PARAM_CFG >> 21) & 1) == 0)
		return ((ISP_FEED_CFG & 1) == 0);
	else
		return ((vri(REGION_BASE) >> 29) & 1) == 0;
}
