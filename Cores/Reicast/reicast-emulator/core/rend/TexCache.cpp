#include "TexCache.h"
#include "hw/pvr/pvr_regs.h"
#include "hw/mem/_vmem.h"

u8* vq_codebook;
u32 palette_index;
bool KillTex=false;

u32 detwiddle[2][8][1024];
//input : address in the yyyyyxxxxx format
//output : address in the xyxyxyxy format
//U : x resolution , V : y resolution
//twiddle works on 64b words


u32 twiddle_slow(u32 x,u32 y,u32 x_sz,u32 y_sz)
{
	u32 rv=0;//low 2 bits are directly passed  -> needs some misc stuff to work.However
			 //Pvr internally maps the 64b banks "as if" they were twiddled :p

	u32 sh=0;
	x_sz>>=1;
	y_sz>>=1;
	while(x_sz!=0 || y_sz!=0)
	{
		if (y_sz)
		{
			u32 temp=y&1;
			rv|=temp<<sh;

			y_sz>>=1;
			y>>=1;
			sh++;
		}
		if (x_sz)
		{
			u32 temp=x&1;
			rv|=temp<<sh;

			x_sz>>=1;
			x>>=1;
			sh++;
		}
	}	
	return rv;
}

void BuildTwiddleTables()
{
	for (u32 s=0;s<8;s++)
	{
		u32 x_sz=1024;
		u32 y_sz=8<<s;
		for (u32 i=0;i<x_sz;i++)
		{
			detwiddle[0][s][i]=twiddle_slow(i,0,x_sz,y_sz);
			detwiddle[1][s][i]=twiddle_slow(0,i,y_sz,x_sz);
		}
	}
}

static OnLoad btt(&BuildTwiddleTables);

void palette_update()
{
	if (pal_needs_update==false)
		return;
	memcpy(pal_rev_256,_pal_rev_256,sizeof(pal_rev_256));
	memcpy(pal_rev_16,_pal_rev_16,sizeof(pal_rev_16));

#define PixelPacker pp_dx
	pal_needs_update=false;
	switch(PAL_RAM_CTRL&3)
	{
	case 0:
		for (int i=0;i<1024;i++)
		{
			palette_ram[i]=ARGB1555(PALETTE_RAM[i]);
		}
		break;

	case 1:
		for (int i=0;i<1024;i++)
		{
			palette_ram[i]=ARGB565(PALETTE_RAM[i]);
		}
		break;

	case 2:
		for (int i=0;i<1024;i++)
		{
			palette_ram[i]=ARGB4444(PALETTE_RAM[i]);
		}
		break;

	case 3:
		for (int i=0;i<1024;i++)
		{
			palette_ram[i]=ARGB8888(PALETTE_RAM[i]);
		}
		break;
	}

}


using namespace std;

vector<vram_block*> VramLocks[VRAM_SIZE/PAGE_SIZE];
//vram 32-64b
VArray2 vram;

//List functions
//
void vramlock_list_remove(vram_block* block)
{
	u32 base = block->start/PAGE_SIZE;
	u32 end = block->end/PAGE_SIZE;

	for (u32 i=base;i<=end;i++)
	{
		vector<vram_block*>* list=&VramLocks[i];
		for (size_t j=0;j<list->size();j++)
		{
			if ((*list)[j]==block)
			{
				(*list)[j]=0;
			}
		}
	}
}
 
void vramlock_list_add(vram_block* block)
{
	u32 base = block->start/PAGE_SIZE;
	u32 end = block->end/PAGE_SIZE;


	for (u32 i=base;i<=end;i++)
	{
		vector<vram_block*>* list=&VramLocks[i];
		for (u32 j=0;j<list->size();j++)
		{
			if ((*list)[j]==0)
			{
				(*list)[j]=block;
				goto added_it;
			}
		}

		list->push_back(block);
added_it:
		i=i;
	}
}
 
cMutex vramlist_lock;

//simple IsInRange test
inline bool IsInRange(vram_block* block,u32 offset)
{
	return (block->start<=offset) && (block->end>=offset);
}


vram_block* libCore_vramlock_Lock(u32 start_offset64,u32 end_offset64,void* userdata)
{
	vram_block* block=(vram_block* )malloc(sizeof(vram_block));
 
	if (end_offset64>(VRAM_SIZE-1))
	{
		msgboxf("vramlock_Lock_64: end_offset64>(VRAM_SIZE-1) \n Tried to lock area out of vram , possibly bug on the pvr plugin",MBX_OK);
		end_offset64=(VRAM_SIZE-1);
	}

	if (start_offset64>end_offset64)
	{
		msgboxf("vramlock_Lock_64: start_offset64>end_offset64 \n Tried to lock negative block , possibly bug on the pvr plugin",MBX_OK);
		start_offset64=0;
	}

	

	block->end=end_offset64;
	block->start=start_offset64;
	block->len=end_offset64-start_offset64+1;
	block->userdata=userdata;
	block->type=64;

	{
		vramlist_lock.Lock();
	
		vram.LockRegion(block->start,block->len);

		//TODO: Fix this for 32M wrap as well
		if (_nvmem_enabled() && VRAM_SIZE == 0x800000) {
			vram.LockRegion(block->start + VRAM_SIZE, block->len);
		}
		
		vramlock_list_add(block);
		
		vramlist_lock.Unlock();
	}

	return block;
}


bool VramLockedWrite(u8* address)
{
	size_t offset=address-vram.data;

	if (offset<VRAM_SIZE)
	{

		size_t addr_hash = offset/PAGE_SIZE;
		vector<vram_block*>* list=&VramLocks[addr_hash];
		
		{
			vramlist_lock.Lock();

			for (size_t i=0;i<list->size();i++)
			{
				if ((*list)[i])
				{
					libPvr_LockedBlockWrite((*list)[i],(u32)offset);
				
					if ((*list)[i])
					{
						msgboxf("Error : pvr is supposed to remove lock",MBX_OK);
						dbgbreak;
					}

				}
			}
			list->clear();

			vram.UnLockRegion((u32)offset&(~(PAGE_SIZE-1)),PAGE_SIZE);

			//TODO: Fix this for 32M wrap as well
			if (_nvmem_enabled() && VRAM_SIZE == 0x800000) {
				vram.UnLockRegion((u32)offset&(~(PAGE_SIZE-1)) + VRAM_SIZE,PAGE_SIZE);
			}
			
			vramlist_lock.Unlock();
		}

		return true;
	}
	else
		return false;
}

//unlocks mem
//also frees the handle
void libCore_vramlock_Unlock_block(vram_block* block)
{
	vramlist_lock.Lock();
	libCore_vramlock_Unlock_block_wb(block);
	vramlist_lock.Unlock();
}

void libCore_vramlock_Unlock_block_wb(vram_block* block)
{
		//VRAM_SIZE/PAGE_SIZE;
	if (block->end>VRAM_SIZE)
		msgboxf("Error : block end is after vram , skipping unlock",MBX_OK);
	else
	{
		vramlock_list_remove(block);
		//more work needed
		free(block);
	}
}
