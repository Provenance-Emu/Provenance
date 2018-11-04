/*
	PowerVR interface to plugins
	Handles YUV conversion (slow and ugly -- but hey it works ...)

	Most of this was hacked together when i needed support for YUV-dma for thps2 ;)
*/
#include "types.h"
#include "pvr_mem.h"
#include "ta.h"
#include "pvr_regs.h"
#include "Renderer_if.h"
#include "hw/mem/_vmem.h"

//TODO : move code later to a plugin
//TODO : Fix registers arrays , they must be smaller now doe to the way SB registers are handled
#include "hw/holly/holly_intc.h"


//YUV converter code :)
//inits the YUV converter
u32 YUV_tempdata[512/4];//512 bytes

u32 YUV_dest=0;

u32 YUV_blockcount;

u32 YUV_x_curr;
u32 YUV_y_curr;

u32 YUV_x_size;
u32 YUV_y_size;

void YUV_init()
{
	YUV_x_curr=0;
	YUV_y_curr=0;

	YUV_dest=TA_YUV_TEX_BASE&VRAM_MASK;//TODO : add the masking needed
	TA_YUV_TEX_CNT=0;
	YUV_blockcount=(((TA_YUV_TEX_CTRL>>0)&0x3F)+1)*(((TA_YUV_TEX_CTRL>>8)&0x3F)+1);

	if ((TA_YUV_TEX_CTRL>>16 )&1)
	{
		die ("YUV: Not supported configuration\n");
		YUV_x_size=16;
		YUV_y_size=16;
	}
	else // yesh!!!
	{
		YUV_x_size=(((TA_YUV_TEX_CTRL>>0)&0x3F)+1)*16;
		YUV_y_size=(((TA_YUV_TEX_CTRL>>8)&0x3F)+1)*16;
	}
}


INLINE u8 GetY420(int x, int y,u8* base)
{
	//u32 base=0;
	if (x > 7)
	{
		x -= 8;
		base += 64;
	}

	if (y > 7)
	{
		y -= 8;
		base += 128;
	}
	
	return base[x+y*8];
}

INLINE u8 GetUV420(int x, int y,u8* base)
{
	int realx=x>>1;
	int realy=y>>1;

	return base[realx+realy*8];
}

void YUV_Block8x8(u8* inuv,u8* iny, u8* out)
{
	u8* line_out_0=out+0;
	u8* line_out_1=out+YUV_x_size*2;

	for (int y=0;y<8;y+=2)
	{
		for (int x=0;x<8;x+=2)
		{
			u8 u=inuv[0];
			u8 v=inuv[64];

			line_out_0[0]=u;
			line_out_0[1]=iny[0];
			line_out_0[2]=v;
			line_out_0[3]=iny[1];

			line_out_1[0]=u;
			line_out_1[1]=iny[8+0];
			line_out_1[2]=v;
			line_out_1[3]=iny[8+1];

			inuv+=1;
			iny+=2;

			line_out_0+=4;
			line_out_1+=4;
		}
		iny+=8;
		inuv+=4;

		line_out_0+=YUV_x_size*4-8*2;
		line_out_1+=YUV_x_size*4-8*2;
	}
}

INLINE void YUV_Block384(u8* in, u8* out)
{
	u8* inuv=in;
	u8* iny=in+128;
	u8* p_out=out;

	YUV_Block8x8(inuv+ 0,iny+  0,p_out);                    //(0,0)
	YUV_Block8x8(inuv+ 4,iny+64,p_out+8*2);                 //(8,0)
	YUV_Block8x8(inuv+32,iny+128,p_out+YUV_x_size*8*2);     //(0,8)
	YUV_Block8x8(inuv+36,iny+192,p_out+YUV_x_size*8*2+8*2); //(8,8)
}

INLINE void YUV_ConvertMacroBlock(u8* datap)
{
	//do shit
	TA_YUV_TEX_CNT++;

	YUV_Block384((u8*)datap,vram.data + YUV_dest);

	YUV_dest+=32;

	YUV_x_curr+=16;
	if (YUV_x_curr==YUV_x_size)
	{
		YUV_dest+=15*YUV_x_size*2;
		YUV_x_curr=0;
		YUV_y_curr+=16;
		if (YUV_y_curr==YUV_y_size)
		{
			YUV_y_curr=0;
		}
	}

	if (YUV_blockcount==TA_YUV_TEX_CNT)
	{
		YUV_init();
		
		asic_RaiseInterrupt(holly_YUV_DMA);
	}
}
void YUV_data(u32* data , u32 count)
{
	if (YUV_blockcount==0)
	{
		die("YUV_data : YUV decoder not inited , *WATCH*\n");
		//wtf ? not inited
		YUV_init();
	}

	u32 block_size=(TA_YUV_TEX_CTRL & (1<<24))==0?384:512;

	verify(block_size==384); //no support for 512

	
	count*=32;

	while(count>=block_size)
	{
		YUV_ConvertMacroBlock((u8*)data); //convert block
		data+=block_size>>2;
		count-=block_size;
	}

	verify(count==0);
}

//Regs

//vram 32-64b

//read
u8 DYNACALL pvr_read_area1_8(u32 addr)
{
	printf("8-bit VRAM reads are not possible\n");
	return 0;
}

u16 DYNACALL pvr_read_area1_16(u32 addr)
{
	return *(u16*)&vram[pvr_map32(addr) & VRAM_MASK];
}
u32 DYNACALL pvr_read_area1_32(u32 addr)
{
	return *(u32*)&vram[pvr_map32(addr) & VRAM_MASK];
}

//write
void DYNACALL pvr_write_area1_8(u32 addr,u8 data)
{
	printf("8-bit VRAM writes are not possible\n");
}
void DYNACALL pvr_write_area1_16(u32 addr,u16 data)
{
	*(u16*)&vram[pvr_map32(addr) & VRAM_MASK]=data;
}
void DYNACALL pvr_write_area1_32(u32 addr,u32 data)
{
	*(u32*)&vram[pvr_map32(addr) & VRAM_MASK] = data;
}

void TAWrite(u32 address,u32* data,u32 count)
{
	//printf("TAWrite 0x%08X %d\n",address,count);
	u32 address_w=address&0x1FFFFFF;//correct ?
	if (address_w<0x800000)//TA poly
	{
		ta_vtx_data(data,count);
	}
	else if(address_w<0x1000000) //Yuv Converter
	{
		YUV_data(data,count);
	}
	else //Vram Writef
	{
		//shouldn't really get here (?) -> works on dc :D need to handle lmmodes
		//printf("Vram Write 0x%X , size %d\n",address,count*32);
		memcpy(&vram.data[address&VRAM_MASK],data,count*32);
	}
}

#include "hw/sh4/sh4_mmr.h"

void NOINLINE MemWrite32(void* dst, void* src)
{
	memcpy((u64*)dst,(u64*)src,32);
}

#if HOST_CPU != CPU_ARM

/*
 .global CSYM(TAWriteSQ)
 HIDDEN(TAWriteSQ)
 @r0: addr
 @r1: sq_both
 CSYM(TAWriteSQ):
 BIC     R3, R0, #0xFE000000        @clear unused bits
 AND     R0, R0, #0x20            @SQ#, isolate
 CMP     R3, #0x800000            @TA write?
 ADD     R0, R1, R0                @SQ#, add to SQ ptr
 BCC     CSYM(_Z13ta_vtx_data32Pv)    @TA write?
 */



extern "C" void DYNACALL TAWriteSQ(u32 address,u8* sqb)
{
	u32 address_w=address&0x1FFFFFF;//correct ?
	u8* sq=&sqb[address&0x20];

	if (likely(address_w<0x800000))//TA poly
	{
		ta_vtx_data32(sq);
	}
	else if(likely(address_w<0x1000000)) //Yuv Converter
	{
		YUV_data((u32*)sq,1);
	}
	else //Vram Writef
	{
		//shouldn't really get here (?)
		//printf("Vram Write 0x%X , size %d\n",address,count*32);
		u8* vram=sqb+512+0x04000000;
		MemWrite32(&vram[address_w&(VRAM_MASK-0x1F)],sq);
	}
}
#endif

//Misc interface

//Reset -> Reset - Initialise to default values
void pvr_Reset(bool Manual)
{
	if (!Manual)
		vram.Zero();
}

#define VRAM_BANK_BIT 0x400000

u32 pvr_map32(u32 offset32)
{
		//64b wide bus is achieved by interleaving the banks every 32 bits
		const u32 bank_bit = VRAM_BANK_BIT;
		const u32 static_bits = VRAM_MASK - (VRAM_BANK_BIT * 2 - 1) | 3;
		const u32 offset_bits = (VRAM_BANK_BIT - 1) & ~3;

		u32 bank = (offset32 & VRAM_BANK_BIT) / VRAM_BANK_BIT;

		u32 rv = offset32 & static_bits;

		rv |= (offset32 & offset_bits) * 2;

		rv |= bank * 4;

		return rv;
}


f32 vrf(u32 addr)
{
	return *(f32*)&vram[pvr_map32(addr) & VRAM_MASK];
}
u32 vri(u32 addr)
{
	return *(u32*)&vram[pvr_map32(addr) & VRAM_MASK];
}
