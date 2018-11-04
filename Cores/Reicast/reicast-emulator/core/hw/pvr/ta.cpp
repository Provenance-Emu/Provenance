#include "ta.h"
#include "ta_ctx.h"

extern u32 ta_type_lut[256];

/*
	Threaded TA Implementation

	Main thread -> ta data -> stored	(tactx)

	Render/TA thread -> ta data -> draw lists -> draw
*/

#if HOST_OS==OS_WINDOWS
extern u32 SQW,DMAW;
#define SQWC(x) (SQW+=x)
#define DMAWC(x) (DMAW+=x)
#else
#define SQWC(x)
#define DMAWC(x)
#endif

#if HOST_CPU == CPU_X86
#include <xmmintrin.h>
struct simd256_t
{
	DECL_ALIGN(32) __m128 data[2];
};
#elif HOST_CPU == CPU_ARM && defined(__ARM_NEON__)
#include <arm_neon.h>
struct simd256_t
{
	DECL_ALIGN(32) uint64x2_t data[2];
};
#else
struct simd256_t
{
DECL_ALIGN(32) u64 data[4];
};
#endif

/*
	Partial TA parsing for in emu-side handling. Properly tracks 32/64 byte state, and
	Calls a helper function every time something important (SOL/EOL, etc) happens

	Uses a state machine, with 3 bits state and 8 bits (PT:OBJ[6:2]) input
*/

enum ta_state
{
	               // -> TAS_NS, TAS_PLV32, TAS_PLHV32, TAS_PLV64, TAS_PLHV64, TAS_MLV64
	TAS_NS,        //

	               // -> TAS_NS, TAS_PLV32, TAS_PLHV32, TAS_PLV64, TAS_PLHV64
	TAS_PLV32,     //polygon list PMV<?>, V32
	
	               // -> TAS_NS, TAS_PLV32, TAS_PLHV32, TAS_PLV64, TAS_PLHV64
	TAS_PLV64,     //polygon list PMV<?>, V64

	               // -> TAS_NS, TAS_MLV64, TAS_MLV64_H
	TAS_MLV64,     //mv list

	               // -> TAS_PLV32
	TAS_PLHV32,    //polygon list PMV<64> 2nd half -> V32

	               // -> TAS_PLV64
	TAS_PLHV64,    //polygon list PMV<64> 2nd half -> V64

	               // -> TAS_PLV64_H
	TAS_PLV64_H,   //polygon list V64 2nd half


	               // -> TAS_MLV64
	TAS_MLV64_H,   //mv list, 64 bit half
};

/* state | PTEOS | OBJ -> next, proc*/

#define ta_cur_state  (ta_fsm[2048])

u8 ta_fsm[2049];	//[2048] stores the current state
u32 ta_fsm_cl=7;


void fill_fsm(ta_state st, s8 pt, s8 obj, ta_state next, u32 proc=0, u32 sz64=0)
{
	for (int i=0;i<8;i++)
	{
		if (pt != -1) i=pt;

		for (int j=0;j<32;j++)
		{
			if (obj != -1) j=obj;
			verify(ta_fsm[(st<<8)+(i<<5)+j]==(0x80+st));
			ta_fsm[(st<<8)+(i<<5)+j]=next | proc*16 /*| sz64*32*/;
			if (obj != -1) break;
		}

		if (pt != -1) break;
	}
}

void fill_fsm()
{
	//initialise to invalid
	for (int i=0;i<2048;i++)
		ta_fsm[i]=(i>>8) | 0x80;


	for (int i=0;i<8;i++)
	{
		switch(i)
		{
		case ParamType_End_Of_List:
			{
				//End of list -> process it !
				fill_fsm(TAS_NS,ParamType_End_Of_List,-1,TAS_NS,1);
				fill_fsm(TAS_PLV32,ParamType_End_Of_List,-1,TAS_NS,1);
				fill_fsm(TAS_PLV64,ParamType_End_Of_List,-1,TAS_NS,1);
				fill_fsm(TAS_MLV64,ParamType_End_Of_List,-1,TAS_NS,1);
			}
			break;

		case ParamType_User_Tile_Clip:
		case ParamType_Object_List_Set:
			{
				//32B commands, no state change
				fill_fsm(TAS_NS,i,-1,TAS_NS);
				fill_fsm(TAS_PLV32,i,-1,TAS_PLV32);
				fill_fsm(TAS_PLV64,i,-1,TAS_PLV64);
				fill_fsm(TAS_MLV64,i,-1,TAS_MLV64);
			}
			break;

		case 3:
		case 6:
			//invalid
			break;

		case ParamType_Polygon_or_Modifier_Volume:
			{
				//right .. its complicated alirte

				for (int k=0;k<32;k++)
				{
					u32 uid=ta_type_lut[k*4];
					u32 vt=uid & 0x7f;

					bool v64 = vt == 5 || vt == 6 || vt == 11 || vt == 12 || vt == 13 || vt == 14;
					bool p64 = uid >> 31;

					ta_state nxt = p64 ? (v64 ? TAS_PLHV64 : TAS_PLHV32) :
										 (v64 ? TAS_PLV64  : TAS_PLV32 ) ;

					fill_fsm(TAS_PLV32,i,k,nxt,0,p64);
					fill_fsm(TAS_PLV64,i,k,nxt,0,p64);
				}
				

				//32B command, no state change
				fill_fsm(TAS_MLV64,i,-1,TAS_MLV64);

				//process and start list
				fill_fsm(TAS_NS,i,-1,TAS_NS,1);
			}
			break;

		case ParamType_Sprite:
			{
				//SPR: 32B -> expect 64B data (PL*)
				fill_fsm(TAS_PLV32,i,-1,TAS_PLV64);
				fill_fsm(TAS_PLV64,i,-1,TAS_PLV64);

				//invalid for ML

				//process and start list
				fill_fsm(TAS_NS,i,-1,TAS_NS,1);
			}
			break;

		case ParamType_Vertex_Parameter:
			{
				//VTX: 32 B -> Expect more of it
				fill_fsm(TAS_PLV32,i,-1,TAS_PLV32,0,0);

				//VTX: 64 B -> Expect next 32B
				fill_fsm(TAS_PLV64,i,-1,TAS_PLV64_H,0,1);

				//MVO: 64B -> expect next 32B
				fill_fsm(TAS_MLV64,i,-1,TAS_MLV64_H,0,1);

				//invalid for NS
			}
			break;
		}
	}
	//?

	fill_fsm(TAS_PLHV32,-1,-1,TAS_PLV32);  //64 PH -> expect V32
	fill_fsm(TAS_PLHV64,-1,-1,TAS_PLV64);  //64 PH -> expect V64

	fill_fsm(TAS_PLV64_H,-1,-1,TAS_PLV64); //64 VH -> expect V64
	fill_fsm(TAS_MLV64_H,-1,-1,TAS_MLV64); //64 MH -> expect M64
}

const HollyInterruptID ListEndInterrupt[5]=
{
	holly_OPAQUE,
	holly_OPAQUEMOD,
	holly_TRANS,
	holly_TRANSMOD,
	holly_PUNCHTHRU
};


NOINLINE void DYNACALL ta_handle_cmd(u32 trans)
{
	Ta_Dma* dat=(Ta_Dma*)(ta_tad.thd_data-32);

	u32 cmd = trans>>4;
	trans&=7;
	//printf("Process state transition: %d || %d -> %d \n",cmd,state_in,trans&0xF);

	if (cmd == 8)
	{
		//printf("Invalid TA Param %d\n", dat->pcw.ParaType);
	}
	else
	{
		if (dat->pcw.ParaType == ParamType_End_Of_List)
		{
			if (ta_fsm_cl==7)
				ta_fsm_cl=dat->pcw.ListType;
			//printf("List %d ended\n",ta_fsm_cl);

			if (ta_fsm_cl==ListType_Translucent)
			{
				//ta_tad.early=os_GetSeconds();
			}
			asic_RaiseInterrupt( ListEndInterrupt[ta_fsm_cl]);
			ta_fsm_cl=7;
			trans=TAS_NS;
		}
		else if (dat->pcw.ParaType == ParamType_Polygon_or_Modifier_Volume)
		{
			if (ta_fsm_cl==7)
				ta_fsm_cl=dat->pcw.ListType;

			if (!IsModVolList(ta_fsm_cl))
				trans=TAS_PLV32;
			else
				trans=TAS_MLV64;

		}
		else if (dat->pcw.ParaType == ParamType_Sprite)
		{
			if (ta_fsm_cl==7)
				ta_fsm_cl=dat->pcw.ListType;

			verify(!IsModVolList(ta_fsm_cl));
			trans=TAS_PLV32;
		}
		else
		{
			die("WTF ?\n");
		}
	}

	u32 state_in = (trans<<8) | (dat->pcw.ParaType<<5) | (dat->pcw.obj_ctrl>>2)%32;
	ta_cur_state=(ta_state)(ta_fsm[state_in]&0xF);
	verify(ta_cur_state<=7);
}

static OnLoad ol_fillfsm(&fill_fsm);

void ta_vtx_ListCont()
{
	SetCurrentTARC(TA_CURRENT_CTX);

	ta_cur_state=TAS_NS;
}
void ta_vtx_ListInit()
{
	SetCurrentTARC(TA_CURRENT_CTX);
	ta_tad.ClearPartial();

	ta_cur_state=TAS_NS;
}
void ta_vtx_SoftReset()
{
	ta_cur_state=TAS_NS;
}

INLINE
void DYNACALL ta_thd_data32_i(void* data)
{
	if (ta_ctx == NULL)
	{
		printf("Warning: data sent to TA prior to ListInit. Implied\n");
		ta_vtx_ListInit();
	}

	simd256_t* dst = (simd256_t*)ta_tad.thd_data;
	simd256_t* src = (simd256_t*)data;

	// First byte is PCW
	PCW pcw = *(PCW*)data;
	
	// Copy the TA data
	*dst = *src;

	ta_tad.thd_data += 32;

	//process TA state
	u32 state_in = (ta_cur_state << 8) | (pcw.ParaType << 5) | ((pcw.obj_ctrl >> 2) & 31);

	u32 trans = ta_fsm[state_in];
	ta_cur_state = (ta_state)trans;
	bool must_handle = trans & 0xF0;


	if (likely(!must_handle))
	{
		return;
	}
	else
	{
		ta_handle_cmd(trans);
	}
}

void DYNACALL ta_vtx_data32(void* data)
{
	SQWC(1);
	ta_thd_data32_i(data);
}

void ta_vtx_data(u32* data, u32 size)
{
	DMAWC(size);
	while(size>4)
	{
		ta_thd_data32_i(data);

		data+=8;
		size--;

		ta_thd_data32_i(data);

		data+=8;
		size--;

		ta_thd_data32_i(data);
		data+=8;
		size--;

		ta_thd_data32_i(data);
		data+=8;
		size--;
	}

	while(size>0)
	{
		ta_thd_data32_i(data);

		data+=8;
		size--;
	}
}
