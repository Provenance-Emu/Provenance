/*
	PowerVR interface to plugins
	Handles YUV conversion (slow and ugly -- but hey it works ...)

	Most of this was hacked together when i needed support for YUV-dma for thps2 ;)
*/
// Unlock VRAM before writing via memcpy
#include "pvr_mem.h"
#include "hw/mem/_vmem.h"
#include "Renderer_if.h"
#include "ta.h"
#include "hw/holly/sb.h"
#include "hw/holly/holly_intc.h"
#include "serialize.h"

static u32 pvr_map32(u32 offset32);

VArray2 vram;

// YUV converter code
static SQBuffer YUV_tempdata[512 / sizeof(SQBuffer)];	// 512 bytes

static u32 YUV_dest;
static u32 YUV_blockcount;

static u32 YUV_x_curr;
static u32 YUV_y_curr;

static u32 YUV_x_size;
static u32 YUV_y_size;

static u32 YUV_index;

void YUV_init()
{
	YUV_x_curr=0;
	YUV_y_curr=0;

	YUV_dest = TA_YUV_TEX_BASE & VRAM_MASK;
	TA_YUV_TEX_CNT=0;
	YUV_blockcount = (TA_YUV_TEX_CTRL.yuv_u_size + 1) * (TA_YUV_TEX_CTRL.yuv_v_size + 1);

	if (TA_YUV_TEX_CTRL.yuv_tex != 0)
	{
		die ("YUV: Not supported configuration\n");
		YUV_x_size=16;
		YUV_y_size=16;
	}
	else
	{
		YUV_x_size = (TA_YUV_TEX_CTRL.yuv_u_size + 1) * 16;
		YUV_y_size = (TA_YUV_TEX_CTRL.yuv_v_size + 1) * 16;
	}
	YUV_index = 0;
}

static void YUV_Block8x8(const u8* inuv, const u8* iny, u8* out)
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

static void YUV_Block384(const u8 *in, u8 *out)
{
	const u8 *inuv = in;
	const u8 *iny = in + 128;
	u8* p_out = out;

	YUV_Block8x8(inuv+ 0,iny+  0,p_out);                    //(0,0)
	YUV_Block8x8(inuv+ 4,iny+64,p_out+8*2);                 //(8,0)
	YUV_Block8x8(inuv+32,iny+128,p_out+YUV_x_size*8*2);     //(0,8)
	YUV_Block8x8(inuv+36,iny+192,p_out+YUV_x_size*8*2+8*2); //(8,8)
}

static void YUV_ConvertMacroBlock(const u8 *datap)
{
	//do shit
	TA_YUV_TEX_CNT++;

	YUV_Block384(datap, vram.data + YUV_dest);

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

static void YUV_data(const SQBuffer *data, u32 count)
{
	if (YUV_blockcount==0)
	{
		die("YUV_data : YUV decoder not inited , *WATCH*\n");
		//wtf ? not inited
		YUV_init();
	}

	u32 block_size = TA_YUV_TEX_CTRL.yuv_form == 0 ? 384 : 512;
	verify(block_size == 384); // no support for 512
	block_size /= sizeof(SQBuffer);

	while (count > 0)
	{
		if (YUV_index + count >= block_size)
		{
			//more or exactly one block remaining
			u32 dr = block_size - YUV_index;				//remaining bytes til block end
			if (YUV_index == 0)
			{
				// Avoid copy
				YUV_ConvertMacroBlock((const u8 *)data);	//convert block
			}
			else
			{
				memcpy(&YUV_tempdata[YUV_index], data, dr * sizeof(SQBuffer));	//copy em
				YUV_ConvertMacroBlock((const u8 *)&YUV_tempdata[0]);	//convert block
				YUV_index = 0;
			}
			data += dr;											//count em
			count -= dr;
		}
		else
		{	//less that a whole block remaining
			memcpy(&YUV_tempdata[YUV_index], data, count * sizeof(SQBuffer));	//append it
			YUV_index += count;
			count = 0;
		}
	}

	verify(count==0);
}

void YUV_serialize(Serializer& ser)
{
	ser << YUV_tempdata;
	ser << YUV_dest;
	ser << YUV_blockcount;
	ser << YUV_x_curr;
	ser << YUV_y_curr;
	ser << YUV_x_size;
	ser << YUV_y_size;
	ser << YUV_index;
}
void YUV_deserialize(Deserializer& deser)
{
	deser >> YUV_tempdata;
	deser >> YUV_dest;
	deser >> YUV_blockcount;
	deser >> YUV_x_curr;
	deser >> YUV_y_curr;
	deser >> YUV_x_size;
	deser >> YUV_y_size;
	if (deser.version() >= Deserializer::V16)
		deser >> YUV_index;
	else
		YUV_index = 0;
}

//vram 32-64b

//read
template<typename T>
T DYNACALL pvr_read32p(u32 addr)
{
	return *(T *)&vram[pvr_map32(addr)];
}
template u8 pvr_read32p<u8>(u32 addr);
template u16 pvr_read32p<u16>(u32 addr);
template u32 pvr_read32p<u32>(u32 addr);
template float pvr_read32p<float>(u32 addr);

//write
template<typename T>
void DYNACALL pvr_write32p(u32 addr, T data)
{
	if (sizeof(T) == 1)
	{
		INFO_LOG(MEMORY, "%08x: 8-bit VRAM writes are not possible", addr);
		return;
	}
	u32 vaddr = addr & VRAM_MASK;
	if (vaddr >= fb_watch_addr_start && vaddr < fb_watch_addr_end)
		fb_dirty = true;
    
    if (pvr_map32(addr) >= 0 &&  pvr_map32(addr) <  VRAM_SIZE && &data && ((data)  || (vram[pvr_map32(addr)]))) {
        _vmem_unprotect_vram(0, VRAM_SIZE);
        std::memcpy((void*)(&vram[0] + pvr_map32(addr)),
                    (void*)&data,
                    sizeof(T));
    }
    //*(T *)&vram[pvr_map32(addr)] = data;
}
template void pvr_write32p<u8>(u32 addr, u8 data);
template void pvr_write32p<u16>(u32 addr, u16 data);
template void pvr_write32p<u32>(u32 addr, u32 data);

void DYNACALL TAWrite(u32 address, const SQBuffer *data, u32 count)
{
	if ((address & 0x800000) == 0)
		// TA poly
		ta_vtx_data(data, count);
	else
		// YUV Converter
		YUV_data(data, count);
}

void DYNACALL TAWriteSQ(u32 address, const SQBuffer *sqb)
{
	u32 address_w = address & 0x01FFFFE0;
	const SQBuffer *sq = &sqb[(address >> 5) & 1];

	if (likely(address_w < 0x800000)) //TA poly
	{
		ta_vtx_data32(sq);
	}
	else if (likely(address_w < 0x1000000)) //Yuv Converter
	{
		YUV_data(sq, 1);
	}
	else //Vram Writef
	{
		// Used by WinCE
		DEBUG_LOG(MEMORY, "Vram TAWriteSQ 0x%X SB_LMMODE0 %d", address, SB_LMMODE0);
		bool path64b = (unlikely(address & 0x02000000) ? SB_LMMODE1 : SB_LMMODE0) == 0;
		if (path64b)
		{
			// 64b path
			SQBuffer *dest = (SQBuffer *)&vram[address_w & VRAM_MASK];
			*dest = *sq;
		}
		else
		{
			// 32b path
			for (u32 i = 0; i < sizeof(SQBuffer); i += 4)
				pvr_write32p<u32>(address_w + i, *(const u32 *)&sq->data[i]);
		}
	}
}

//Misc interface

#define VRAM_BANK_BIT 0x400000

static u32 pvr_map32(u32 offset32)
{
	//64b wide bus is achieved by interleaving the banks every 32 bits
	const u32 static_bits = VRAM_MASK - (VRAM_BANK_BIT * 2 - 1) + 3;
	const u32 offset_bits = (VRAM_BANK_BIT - 1) & ~3;

	u32 bank = (offset32 & VRAM_BANK_BIT) / VRAM_BANK_BIT;

	u32 rv = offset32 & static_bits;

	rv |= (offset32 & offset_bits) * 2;

	rv |= bank * 4;
	
	return rv;
}

template<typename T, bool upper>
T DYNACALL pvr_read_area4(u32 addr)
{
	bool access32 = (upper ? SB_LMMODE1 : SB_LMMODE0) == 1;
	if (access32)
		return pvr_read32p<T>(addr);
	else
		return *(T*)&vram[addr & VRAM_MASK];
}
template u8 pvr_read_area4<u8, false>(u32 addr);
template u16 pvr_read_area4<u16, false>(u32 addr);
template u32 pvr_read_area4<u32, false>(u32 addr);
template u8 pvr_read_area4<u8, true>(u32 addr);
template u16 pvr_read_area4<u16, true>(u32 addr);
template u32 pvr_read_area4<u32, true>(u32 addr);

template<typename T, bool upper>
void DYNACALL pvr_write_area4(u32 addr, T data)
{
	bool access32 = (upper ? SB_LMMODE1 : SB_LMMODE0) == 1;
	if (access32)
		pvr_write32p(addr, data);
	else
		*(T*)&vram[addr & VRAM_MASK] = data;
}
template void pvr_write_area4<u8, false>(u32 addr, u8 data);
template void pvr_write_area4<u16, false>(u32 addr, u16 data);
template void pvr_write_area4<u32, false>(u32 addr, u32 data);
template void pvr_write_area4<u8, true>(u32 addr, u8 data);
template void pvr_write_area4<u16, true>(u32 addr, u16 data);
template void pvr_write_area4<u32, true>(u32 addr, u32 data);
