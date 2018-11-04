#include "_vmem.h"
#include "hw/aica/aica_if.h"
#include "hw/sh4/dyna/blockmanager.h"

#define HANDLER_MAX 0x1F
#define HANDLER_COUNT (HANDLER_MAX+1)

//top registered handler
_vmem_handler       _vmem_lrp;

//handler tables
_vmem_ReadMem8FP*   _vmem_RF8[HANDLER_COUNT];
_vmem_WriteMem8FP*  _vmem_WF8[HANDLER_COUNT];

_vmem_ReadMem16FP*  _vmem_RF16[HANDLER_COUNT];
_vmem_WriteMem16FP* _vmem_WF16[HANDLER_COUNT];

_vmem_ReadMem32FP*  _vmem_RF32[HANDLER_COUNT];
_vmem_WriteMem32FP* _vmem_WF32[HANDLER_COUNT];

//upper 8b of the address
void* _vmem_MemInfo_ptr[0x100];


void _vmem_get_ptrs(u32 sz,bool write,void*** vmap,void*** func)
{
	*vmap=_vmem_MemInfo_ptr;
	switch(sz)
	{
	case 1:
		*func=write?(void**)_vmem_WF8:(void**)_vmem_RF8;
		return;

	case 2:
		*func=write?(void**)_vmem_WF16:(void**)_vmem_RF16;
		return;

	case 4:
	case 8:
		*func=write?(void**)_vmem_WF32:(void**)_vmem_RF32;
		return;

	default:
		die("invalid size");
	}
}

void* _vmem_get_ptr2(u32 addr,u32& mask)
{
	u32   page=addr>>24;
	unat  iirf=(unat)_vmem_MemInfo_ptr[page];
	void* ptr=(void*)(iirf&~HANDLER_MAX);

	if (ptr==0) return 0;

	mask=0xFFFFFFFF>>iirf;
	return ptr;
}

void* _vmem_read_const(u32 addr,bool& ismem,u32 sz)
{
	u32   page=addr>>24;
	unat  iirf=(unat)_vmem_MemInfo_ptr[page];
	void* ptr=(void*)(iirf&~HANDLER_MAX);

	if (ptr==0)
	{
		ismem=false;
		const unat id=iirf;
		if (sz==1)
		{
			return (void*)_vmem_RF8[id/4];
		}
		else if (sz==2)
		{
			return (void*)_vmem_RF16[id/4];
		}
		else if (sz==4)
		{
			return (void*)_vmem_RF32[id/4];
		}
		else
		{
			die("Invalid size");
		}
	}
	else
	{
		ismem=true;
		addr<<=iirf;
		addr>>=iirf;

		return &(((u8*)ptr)[addr]);
	}
	die("Invalid memory size");

	return 0;
}

void* _vmem_page_info(u32 addr,bool& ismem,u32 sz,u32& page_sz,bool rw)
{
	u32   page=addr>>24;
	unat  iirf=(unat)_vmem_MemInfo_ptr[page];
	void* ptr=(void*)(iirf&~HANDLER_MAX);
	
	if (ptr==0)
	{
		ismem=false;
		const unat id=iirf;
		page_sz=24;
		if (sz==1)
		{
			return rw?(void*)_vmem_RF8[id/4]:(void*)_vmem_WF8[id/4];
		}
		else if (sz==2)
		{
			return rw?(void*)_vmem_RF16[id/4]:(void*)_vmem_WF16[id/4];
		}
		else if (sz==4)
		{
			return rw?(void*)_vmem_RF32[id/4]:(void*)_vmem_WF32[id/4];
		}
		else
		{
			die("Invalid size");
		}
	}
	else
	{
		ismem=true;

		page_sz=32-(iirf&0x1F);

		return ptr;
	}
	die("Invalid memory size");

	return 0;
}

template<typename T,typename Trv>
INLINE Trv DYNACALL _vmem_readt(u32 addr)
{
	const u32 sz=sizeof(T);

	u32   page=addr>>24;	//1 op, shift/extract
	unat  iirf=(unat)_vmem_MemInfo_ptr[page]; //2 ops, insert + read [vmem table will be on reg ]
	void* ptr=(void*)(iirf&~HANDLER_MAX);     //2 ops, and // 1 op insert

	if (likely(ptr!=0))
	{
		addr<<=iirf;
		addr>>=iirf;

		T data=(*((T*)&(((u8*)ptr)[addr])));
		return data;
	}
	else
	{
		const u32 id=iirf;
		if (sz==1)
		{
			return (T)_vmem_RF8[id/4](addr);
		}
		else if (sz==2)
		{
			return (T)_vmem_RF16[id/4](addr);
		}
		else if (sz==4)
		{
			return _vmem_RF32[id/4](addr);
		}
		else if (sz==8)
		{
			T rv=_vmem_RF32[id/4](addr);
			rv|=(T)((u64)_vmem_RF32[id/4](addr+4)<<32);
			
			return rv;
		}
		else
		{
			die("Invalid size");
		}
	}
}
template<typename T>
INLINE void DYNACALL _vmem_writet(u32 addr,T data)
{
	const u32 sz=sizeof(T);

	u32 page=addr>>24;
	unat  iirf=(unat)_vmem_MemInfo_ptr[page];
	void* ptr=(void*)(iirf&~HANDLER_MAX);

	if (likely(ptr!=0))
	{
		addr<<=iirf;
		addr>>=iirf;

		*((T*)&(((u8*)ptr)[addr]))=data;
	}
	else
	{
		const u32 id=iirf;
		if (sz==1)
		{
			 _vmem_WF8[id/4](addr,data);
		}
		else if (sz==2)
		{
			 _vmem_WF16[id/4](addr,data);
		}
		else if (sz==4)
		{
			 _vmem_WF32[id/4](addr,data);
		}
		else if (sz==8)
		{
			_vmem_WF32[id/4](addr,(u32)data);
			_vmem_WF32[id/4](addr+4,(u32)((u64)data>>32));
		}
		else
		{
			die("Invalid size");
		}
	}
}

//ReadMem/WriteMem functions
//ReadMem
u32 DYNACALL _vmem_ReadMem8SX32(u32 Address) { return _vmem_readt<s8,s32>(Address); }
u32 DYNACALL _vmem_ReadMem16SX32(u32 Address) { return _vmem_readt<s16,s32>(Address); }

u8 DYNACALL _vmem_ReadMem8(u32 Address) { return _vmem_readt<u8,u8>(Address); }
u16 DYNACALL _vmem_ReadMem16(u32 Address) { return _vmem_readt<u16,u16>(Address); }
u32 DYNACALL _vmem_ReadMem32(u32 Address) { return _vmem_readt<u32,u32>(Address); }
u64 DYNACALL _vmem_ReadMem64(u32 Address) { return _vmem_readt<u64,u64>(Address); }

//WriteMem
void DYNACALL _vmem_WriteMem8(u32 Address,u8 data) { _vmem_writet<u8>(Address,data); }
void DYNACALL _vmem_WriteMem16(u32 Address,u16 data) { _vmem_writet<u16>(Address,data); }
void DYNACALL _vmem_WriteMem32(u32 Address,u32 data) { _vmem_writet<u32>(Address,data); }
void DYNACALL _vmem_WriteMem64(u32 Address,u64 data) { _vmem_writet<u64>(Address,data); }

//0xDEADC0D3 or 0
#define MEM_ERROR_RETURN_VALUE 0xDEADC0D3

//phew .. that was lota asm code ;) lets go back to C :D
//default mem handlers ;)
//default read handlers
u8 DYNACALL _vmem_ReadMem8_not_mapped(u32 addresss)
{
	printf("[sh4]Read8 from 0x%X, not mapped [_vmem default handler]\n",addresss);
	return (u8)MEM_ERROR_RETURN_VALUE;
}
u16 DYNACALL _vmem_ReadMem16_not_mapped(u32 addresss)
{
	printf("[sh4]Read16 from 0x%X, not mapped [_vmem default handler]\n",addresss);
	return (u16)MEM_ERROR_RETURN_VALUE;
}
u32 DYNACALL _vmem_ReadMem32_not_mapped(u32 addresss)
{
	printf("[sh4]Read32 from 0x%X, not mapped [_vmem default handler]\n",addresss);
	return (u32)MEM_ERROR_RETURN_VALUE;
}
//default write handers
void DYNACALL _vmem_WriteMem8_not_mapped(u32 addresss,u8 data)
{
	printf("[sh4]Write8 to 0x%X=0x%X, not mapped [_vmem default handler]\n",addresss,data);
}
void DYNACALL _vmem_WriteMem16_not_mapped(u32 addresss,u16 data)
{
	printf("[sh4]Write16 to 0x%X=0x%X, not mapped [_vmem default handler]\n",addresss,data);
}
void DYNACALL _vmem_WriteMem32_not_mapped(u32 addresss,u32 data)
{
	printf("[sh4]Write32 to 0x%X=0x%X, not mapped [_vmem default handler]\n",addresss,data);
}
//code to register handlers
//0 is considered error :)
_vmem_handler _vmem_register_handler(
									 _vmem_ReadMem8FP* read8,
									 _vmem_ReadMem16FP* read16,
									 _vmem_ReadMem32FP* read32,

									 _vmem_WriteMem8FP* write8,
									 _vmem_WriteMem16FP* write16,
									 _vmem_WriteMem32FP* write32
									 )
{
	_vmem_handler rv=_vmem_lrp++;

	verify(rv<HANDLER_COUNT);

	_vmem_RF8[rv] =read8==0  ? _vmem_ReadMem8_not_mapped  : read8;
	_vmem_RF16[rv]=read16==0 ? _vmem_ReadMem16_not_mapped : read16;
	_vmem_RF32[rv]=read32==0 ? _vmem_ReadMem32_not_mapped : read32;

	_vmem_WF8[rv] =write8==0 ? _vmem_WriteMem8_not_mapped : write8;
	_vmem_WF16[rv]=write16==0? _vmem_WriteMem16_not_mapped: write16;
	_vmem_WF32[rv]=write32==0? _vmem_WriteMem32_not_mapped: write32;

	return rv;
}
u32 FindMask(u32 msk)
{
	u32 s=-1;
	u32 rv=0;

	while(msk!=s>>rv)
		rv++;

	return rv;
}

//map a registered handler to a mem region
void _vmem_map_handler(_vmem_handler Handler,u32 start,u32 end)
{
	verify(start<0x100);
	verify(end<0x100);
	verify(start<=end);
	for (u32 i=start;i<=end;i++)
	{
		_vmem_MemInfo_ptr[i]=((u8*)0)+(0x00000000 + Handler*4);
	}
}

//map a memory block to a mem region
void _vmem_map_block(void* base,u32 start,u32 end,u32 mask)
{
	verify(start<0x100);
	verify(end<0x100);
	verify(start<=end);
	verify((0xFF & (unat)base)==0);
	verify(base!=0);
	u32 j=0;
	for (u32 i=start;i<=end;i++)
	{
		_vmem_MemInfo_ptr[i]=&(((u8*)base)[j&mask]) + FindMask(mask) - (j & mask);
		j+=0x1000000;
	}
}

void _vmem_mirror_mapping(u32 new_region,u32 start,u32 size)
{
	u32 end=start+size-1;
	verify(start<0x100);
	verify(end<0x100);
	verify(start<=end);
	verify(!((start>=new_region) && (end<=new_region)));

	u32 j=new_region;
	for (u32 i=start;i<=end;i++)
	{
		_vmem_MemInfo_ptr[j&0xFF]=_vmem_MemInfo_ptr[i&0xFF];
		j++;
	}
}

//init/reset/term
void _vmem_init()
{
	_vmem_reset();
}

void _vmem_reset()
{
	//clear read tables
	memset(_vmem_RF8,0,sizeof(_vmem_RF8));
	memset(_vmem_RF16,0,sizeof(_vmem_RF16));
	memset(_vmem_RF32,0,sizeof(_vmem_RF32));
	
	//clear write tables
	memset(_vmem_WF8,0,sizeof(_vmem_WF8));
	memset(_vmem_WF16,0,sizeof(_vmem_WF16));
	memset(_vmem_WF32,0,sizeof(_vmem_WF32));
	
	//clear meminfo table
	memset(_vmem_MemInfo_ptr,0,sizeof(_vmem_MemInfo_ptr));

	//reset registration index
	_vmem_lrp=0;

	//register default functions (0) for slot 0
	verify(_vmem_register_handler(0,0,0,0,0,0)==0);
}

void _vmem_term()
{

}

#include "hw/pvr/pvr_mem.h"
#include "hw/sh4/sh4_mem.h"

u8* virt_ram_base;

void* malloc_pages(size_t size) {

	u8* rv = (u8*)malloc(size + PAGE_SIZE);

	return rv + PAGE_SIZE - ((unat)rv % PAGE_SIZE);
}

bool _vmem_reserve_nonvmem()
{
	virt_ram_base = 0;

	p_sh4rcb=(Sh4RCB*)malloc_pages(sizeof(Sh4RCB));

	mem_b.size=RAM_SIZE;
	mem_b.data=(u8*)malloc_pages(RAM_SIZE);

	vram.size=VRAM_SIZE;
	vram.data=(u8*)malloc_pages(VRAM_SIZE);

	aica_ram.size=ARAM_SIZE;
	aica_ram.data=(u8*)malloc_pages(ARAM_SIZE);

	return true;
}

void _vmem_bm_reset_nvmem();

void _vmem_bm_reset() {
	if (virt_ram_base) {
		#if !defined(TARGET_NO_NVMEM)
			_vmem_bm_reset_nvmem();
		#endif
	}

#if FEAT_SHREC != DYNAREC_NONE
    if (!virt_ram_base || HOST_OS == OS_DARWIN) {
		bm_vmem_pagefill((void**)p_sh4rcb->fpcb, FPCB_SIZE);
	}
#endif
}

#if !defined(TARGET_NO_NVMEM)

#define MAP_RAM_START_OFFSET  0
#define MAP_VRAM_START_OFFSET (MAP_RAM_START_OFFSET+RAM_SIZE)
#define MAP_ARAM_START_OFFSET (MAP_VRAM_START_OFFSET+VRAM_SIZE)

#if HOST_OS==OS_WINDOWS
#include <Windows.h>
HANDLE mem_handle;

void* _nvmem_map_buffer(u32 dst,u32 addrsz,u32 offset,u32 size, bool w)
{
	void* ptr;
	void* rv;

	u32 map_times=addrsz/size;
	verify((addrsz%size)==0);
	verify(map_times>=1);

	rv= MapViewOfFileEx(mem_handle,FILE_MAP_READ | (w?FILE_MAP_WRITE:0),0,offset,size,&virt_ram_base[dst]);
	if (!rv)
		return 0;

	for (u32 i=1;i<map_times;i++)
	{
		dst+=size;
		ptr=MapViewOfFileEx(mem_handle,FILE_MAP_READ | (w?FILE_MAP_WRITE:0),0,offset,size,&virt_ram_base[dst]);
		if (!ptr) return 0;
	}

	return rv;
}


void* _nvmem_unused_buffer(u32 start,u32 end)
{
	void* ptr=VirtualAlloc(&virt_ram_base[start],end-start,MEM_RESERVE,PAGE_NOACCESS);

	if (ptr == 0)
		return 0;

	return ptr;
}

void* _nvmem_alloc_mem()
{
	mem_handle=CreateFileMapping(INVALID_HANDLE_VALUE,0,PAGE_READWRITE ,0,RAM_SIZE + VRAM_SIZE +ARAM_SIZE,0);

	void* rv=(u8*)VirtualAlloc(0,512*1024*1024 + sizeof(Sh4RCB) + ARAM_SIZE,MEM_RESERVE,PAGE_NOACCESS);
	if (rv) VirtualFree(rv,0,MEM_RELEASE);
	return rv;
}

#else
	#include <sys/mman.h>
	#include <sys/types.h>
	#include <sys/stat.h>
	#include <fcntl.h>
	#include <errno.h>
	#include <unistd.h>

#ifndef MAP_NOSYNC
#define MAP_NOSYNC       0 //missing from linux :/ -- could be the cause of android slowness ?
#endif

#ifdef _ANDROID
#include <linux/ashmem.h>

#ifndef ASHMEM_DEVICE
#define ASHMEM_DEVICE "/dev/ashmem"
#endif
int ashmem_create_region(const char *name, size_t size)
{
	int fd, ret;

	fd = open(ASHMEM_DEVICE, O_RDWR);
	if (fd < 0)
		return fd;

	if (name) {
		char buf[ASHMEM_NAME_LEN];

		strlcpy(buf, name, sizeof(buf));
		ret = ioctl(fd, ASHMEM_SET_NAME, buf);
		if (ret < 0)
			goto error;
	}

	ret = ioctl(fd, ASHMEM_SET_SIZE, size);
	if (ret < 0)
		goto error;

	return fd;

error:
	close(fd);
	return ret;
}
#endif

	int fd;
	void* _nvmem_unused_buffer(u32 start,u32 end)
	{
		void* ptr=mmap(&virt_ram_base[start], end-start, PROT_NONE, MAP_FIXED | MAP_PRIVATE | MAP_ANON, -1, 0);
		if (MAP_FAILED==ptr)
			return 0;
		return ptr;
	}

	
	void* _nvmem_map_buffer(u32 dst,u32 addrsz,u32 offset,u32 size, bool w)
	{
		void* ptr;
		void* rv;

		printf("MAP %08X w/ %d\n",dst,offset);
		u32 map_times=addrsz/size;
		verify((addrsz%size)==0);
		verify(map_times>=1);
		u32 prot=PROT_READ|(w?PROT_WRITE:0);
		rv= mmap(&virt_ram_base[dst], size, prot, MAP_SHARED | MAP_NOSYNC | MAP_FIXED, fd, offset);
		if (MAP_FAILED==rv || rv!=(void*)&virt_ram_base[dst] || (mprotect(rv,size,prot)!=0)) 
		{
			printf("MAP1 failed %d\n",errno);
			return 0;
		}

		for (u32 i=1;i<map_times;i++)
		{
			dst+=size;
			ptr=mmap(&virt_ram_base[dst], size, prot , MAP_SHARED | MAP_NOSYNC | MAP_FIXED, fd, offset);
			if (MAP_FAILED==ptr || ptr!=(void*)&virt_ram_base[dst] || (mprotect(rv,size,prot)!=0))
			{
				printf("MAP2 failed %d\n",errno);
				return 0;
			}
		}

		return rv;
	}

	void* _nvmem_alloc_mem()
	{
        
#if HOST_OS == OS_DARWIN
		string path = get_writable_data_path("/dcnzorz_mem");
        fd = open(path.c_str(),O_CREAT|O_RDWR|O_TRUNC,S_IRWXU|S_IRWXG|S_IRWXO);
        unlink(path.c_str());
        verify(ftruncate(fd,RAM_SIZE + VRAM_SIZE +ARAM_SIZE)==0);
#elif !defined(_ANDROID)
		fd = shm_open("/dcnzorz_mem", O_CREAT | O_EXCL | O_RDWR,S_IREAD | S_IWRITE);
		shm_unlink("/dcnzorz_mem");
		if (fd==-1)
		{
			fd = open("dcnzorz_mem",O_CREAT|O_RDWR|O_TRUNC,S_IRWXU|S_IRWXG|S_IRWXO);
			unlink("dcnzorz_mem");
		}

		verify(ftruncate(fd,RAM_SIZE + VRAM_SIZE +ARAM_SIZE)==0);
#else

		fd = ashmem_create_region(0,RAM_SIZE + VRAM_SIZE +ARAM_SIZE);
		if (false)//this causes writebacks to flash -> slow and stuttery 
		{
		fd = open("/data/data/com.reicast.emulator/files/dcnzorz_mem",O_CREAT|O_RDWR|O_TRUNC,S_IRWXU|S_IRWXG|S_IRWXO);
		unlink("/data/data/com.reicast.emulator/files/dcnzorz_mem");
		}
#endif

		

		u32 sz= 512*1024*1024 + sizeof(Sh4RCB) + ARAM_SIZE + 0x10000;
		void* rv=mmap(0, sz, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
		verify(rv != NULL);
		munmap(rv,sz);
		return (u8*)rv + 0x10000 - unat(rv)%0x10000;//align to 64 KB (Needed for linaro mmap not to extend to next region)
	}
#endif

#define map_buffer(dsts,dste,offset,sz,w) {ptr=_nvmem_map_buffer(dsts,dste-dsts,offset,sz,w);if (!ptr) return false;}
#define unused_buffer(start,end) {ptr=_nvmem_unused_buffer(start,end);if (!ptr) return false;}

u32 pagecnt;
void _vmem_bm_reset_nvmem()
{
	#if defined(TARGET_NO_NVMEM)
		return;
	#endif

	#if (HOST_OS == OS_DARWIN)
		//On iOS & nacl we allways allocate all of the mapping table
		mprotect(p_sh4rcb, sizeof(p_sh4rcb->fpcb), PROT_READ | PROT_WRITE);
		return;
	#endif
	pagecnt=0;

#if HOST_OS==OS_WINDOWS
	VirtualFree(p_sh4rcb,sizeof(p_sh4rcb->fpcb),MEM_DECOMMIT);
#else
	mprotect(p_sh4rcb, sizeof(p_sh4rcb->fpcb), PROT_NONE);
	madvise(p_sh4rcb,sizeof(p_sh4rcb->fpcb),MADV_DONTNEED);
    #ifdef MADV_REMOVE
	madvise(p_sh4rcb,sizeof(p_sh4rcb->fpcb),MADV_REMOVE);
    #else
    //OSX, IOS
    madvise(p_sh4rcb,sizeof(p_sh4rcb->fpcb),MADV_FREE);
    #endif
#endif

	printf("Freeing fpcb\n");
}

bool BM_LockedWrite(u8* address)
{
	if (!_nvmem_enabled())
		return false;
	
#if FEAT_SHREC != DYNAREC_NONE
	u32 addr=address-(u8*)p_sh4rcb->fpcb;

	address=(u8*)p_sh4rcb->fpcb+ (addr&~PAGE_MASK);

	if (addr<sizeof(p_sh4rcb->fpcb))
	{
		//printf("Allocated %d PAGES [%08X]\n",++pagecnt,addr);

#if HOST_OS==OS_WINDOWS
		verify(VirtualAlloc(address,PAGE_SIZE,MEM_COMMIT,PAGE_READWRITE));
#else
		mprotect (address, PAGE_SIZE, PROT_READ | PROT_WRITE);
#endif

		bm_vmem_pagefill((void**)address,PAGE_SIZE);
		
		return true;
	}
#else
die("BM_LockedWrite and NO REC");
#endif
	return false;
}

bool _vmem_reserve()
{
	void* ptr=0;

	verify((sizeof(Sh4RCB)%PAGE_SIZE)==0);

	if (settings.dynarec.disable_nvmem)
		return _vmem_reserve_nonvmem();

	virt_ram_base=(u8*)_nvmem_alloc_mem();

	if (virt_ram_base==0)
		return _vmem_reserve_nonvmem();
	
	p_sh4rcb=(Sh4RCB*)virt_ram_base;

#if HOST_OS==OS_WINDOWS
	//verify(p_sh4rcb==VirtualAlloc(p_sh4rcb,sizeof(Sh4RCB),MEM_RESERVE|MEM_COMMIT,PAGE_READWRITE));
	verify(p_sh4rcb==VirtualAlloc(p_sh4rcb,sizeof(Sh4RCB),MEM_RESERVE,PAGE_NOACCESS));

	verify(VirtualAlloc((u8*)p_sh4rcb + sizeof(p_sh4rcb->fpcb),sizeof(Sh4RCB)-sizeof(p_sh4rcb->fpcb),MEM_COMMIT,PAGE_READWRITE));
#else
	verify(p_sh4rcb==mmap(p_sh4rcb,sizeof(Sh4RCB),PROT_NONE,MAP_PRIVATE | MAP_ANON, -1, 0));
	mprotect((u8*)p_sh4rcb + sizeof(p_sh4rcb->fpcb),sizeof(Sh4RCB)-sizeof(p_sh4rcb->fpcb),PROT_READ|PROT_WRITE);
#endif
	virt_ram_base+=sizeof(Sh4RCB);

	//Area 0
	//[0x00000000 ,0x00800000) -> unused
	unused_buffer(0x00000000,0x00800000);

	//I wonder, aica ram warps here ?.?
	//I really should check teh docs before codin ;p
	//[0x00800000,0x00A00000);
	map_buffer(0x00800000,0x01000000,MAP_ARAM_START_OFFSET,ARAM_SIZE,false);
	map_buffer(0x20000000,0x20000000+ARAM_SIZE,MAP_ARAM_START_OFFSET,ARAM_SIZE,true);

	aica_ram.size=ARAM_SIZE;
	aica_ram.data=(u8*)ptr;
	//[0x01000000 ,0x04000000) -> unused
	unused_buffer(0x01000000,0x04000000);
	

	//Area 1
	//[0x04000000,0x05000000) -> vram (16mb, warped on dc)
	map_buffer(0x04000000,0x05000000,MAP_VRAM_START_OFFSET,VRAM_SIZE,true);
	
	vram.size=VRAM_SIZE;
	vram.data=(u8*)ptr;

	//[0x05000000,0x06000000) -> unused (32b path)
	unused_buffer(0x05000000,0x06000000);

	//[0x06000000,0x07000000) -> vram   mirror
	map_buffer(0x06000000,0x07000000,MAP_VRAM_START_OFFSET,VRAM_SIZE,true);


	//[0x07000000,0x08000000) -> unused (32b path) mirror
	unused_buffer(0x07000000,0x08000000);
	
	//Area 2
	//[0x08000000,0x0C000000) -> unused
	unused_buffer(0x08000000,0x0C000000);
	
	//Area 3
	//[0x0C000000,0x0D000000) -> main ram
	//[0x0D000000,0x0E000000) -> main ram mirror
	//[0x0E000000,0x0F000000) -> main ram mirror
	//[0x0F000000,0x10000000) -> main ram mirror
	map_buffer(0x0C000000,0x10000000,MAP_RAM_START_OFFSET,RAM_SIZE,true);
	
	mem_b.size=RAM_SIZE;
	mem_b.data=(u8*)ptr;
	
	printf("A8\n");

	//Area 4
	//Area 5
	//Area 6
	//Area 7
	//all -> Unused 
	//[0x10000000,0x20000000) -> unused
	unused_buffer(0x10000000,0x20000000);

	printf("vmem reserve: base: %08X, aram: %08x, vram: %08X, ram: %08X\n",virt_ram_base,aica_ram.data,vram.data,mem_b.data);

	printf("Resetting mem\n");

	aica_ram.Zero();
	vram.Zero();
	mem_b.Zero();

	printf("Mem alloc successful!");

	return virt_ram_base!=0;
}
#else

bool _vmem_reserve()
{
	return _vmem_reserve_nonvmem();
}
#endif

void _vmem_release()
{
	//TODO
}
