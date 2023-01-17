#include "TexCache.h"
#include "CustomTexture.h"
#include "deps/xbrz/xbrz.h"
#include "hw/pvr/pvr_mem.h"
#include "hw/mem/_vmem.h"
#include "hw/sh4/modules/mmu.h"

#include <algorithm>
#include <mutex>
#include <xxhash.h>

#include <omp.h>

const u8 *vq_codebook;
u32 palette_index;
bool KillTex=false;
u32 palette16_ram[1024];
u32 palette32_ram[1024];
u32 pal_hash_256[4];
u32 pal_hash_16[64];
bool palette_updated;
extern bool pal_needs_update;

// Rough approximation of LoD bias from D adjust param, only used to increase LoD
const std::array<f32, 16> D_Adjust_LoD_Bias = {
		0.f, -4.f, -2.f, -1.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f, 0.f
};

u32 detwiddle[2][11][1024];
//input : address in the yyyyyxxxxx format
//output : address in the xyxyxyxy format
//U : x resolution , V : y resolution
//twiddle works on 64b words


static u32 twiddle_slow(u32 x,u32 y,u32 x_sz,u32 y_sz)
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

static void BuildTwiddleTables()
{
	for (u32 s = 0; s < 11; s++)
	{
		u32 x_sz = 1024;
		u32 y_sz = 1 << s;
		for (u32 i = 0; i < x_sz; i++)
		{
			detwiddle[0][s][i] = twiddle_slow(i, 0, x_sz, y_sz);
			detwiddle[1][s][i] = twiddle_slow(0, i, y_sz, x_sz);
		}
	}
}

static OnLoad btt(&BuildTwiddleTables);

void palette_update()
{
	if (!pal_needs_update)
		return;
	pal_needs_update = false;
	palette_updated = true;

	if (!isDirectX(config::RendererType))
	{
		switch(PAL_RAM_CTRL&3)
		{
		case 0:
			for (int i=0;i<1024;i++)
			{
				palette16_ram[i] = Unpacker1555::unpack(PALETTE_RAM[i]);
				palette32_ram[i] = Unpacker1555_32<RGBAPacker>::unpack(PALETTE_RAM[i]);
			}
			break;

		case 1:
			for (int i=0;i<1024;i++)
			{
				palette16_ram[i] = UnpackerNop<u16>::unpack(PALETTE_RAM[i]);
				palette32_ram[i] = Unpacker565_32<RGBAPacker>::unpack(PALETTE_RAM[i]);
			}
			break;

		case 2:
			for (int i=0;i<1024;i++)
			{
				palette16_ram[i] = Unpacker4444::unpack(PALETTE_RAM[i]);
				palette32_ram[i] = Unpacker4444_32<RGBAPacker>::unpack(PALETTE_RAM[i]);
			}
			break;

		case 3:
			for (int i=0;i<1024;i++)
				palette32_ram[i] = Unpacker8888<RGBAPacker>::unpack(PALETTE_RAM[i]);
			break;
		}
	}
	else
	{
		switch(PAL_RAM_CTRL&3)
		{

		case 0:
			for (int i=0;i<1024;i++)
			{
				palette16_ram[i] = UnpackerNop<u16>::unpack(PALETTE_RAM[i]);
				palette32_ram[i] = Unpacker1555_32<BGRAPacker>::unpack(PALETTE_RAM[i]);
			}
			break;

		case 1:
			for (int i=0;i<1024;i++)
			{
				palette16_ram[i] = UnpackerNop<u16>::unpack(PALETTE_RAM[i]);
				palette32_ram[i] = Unpacker565_32<BGRAPacker>::unpack(PALETTE_RAM[i]);
			}
			break;

		case 2:
			for (int i=0;i<1024;i++)
			{
				palette16_ram[i] = UnpackerNop<u16>::unpack(PALETTE_RAM[i]);
				palette32_ram[i] = Unpacker4444_32<BGRAPacker>::unpack(PALETTE_RAM[i]);
			}
			break;

		case 3:
			for (int i=0;i<1024;i++)
				palette32_ram[i] = UnpackerNop<u32>::unpack(PALETTE_RAM[i]);
			break;
		}
	}
	for (int i = 0; i < 64; i++)
		pal_hash_16[i] = XXH32(&PALETTE_RAM[i << 4], 16 * 4, 7);
	for (int i = 0; i < 4; i++)
		pal_hash_256[i] = XXH32(&PALETTE_RAM[i << 8], 256 * 4, 7);
}

void forcePaletteUpdate()
{
	pal_needs_update = true;
}


static std::vector<vram_block*> VramLocks[VRAM_SIZE_MAX / PAGE_SIZE];

//List functions
//
static void vramlock_list_remove(vram_block* block)
{
	u32 base = block->start / PAGE_SIZE;
	u32 end = block->end / PAGE_SIZE;

	for (u32 i = base; i <= end; i++)
	{
		std::vector<vram_block*>& list = VramLocks[i];
		for (auto& lock : list)
		{
			if (lock == block)
				lock = nullptr;
		}
	}
}
 
static void vramlock_list_add(vram_block* block)
{
	u32 base = block->start / PAGE_SIZE;
	u32 end = block->end / PAGE_SIZE;

	for (u32 i = base; i <= end; i++)
	{
		std::vector<vram_block*>& list = VramLocks[i];
		// If the list is empty then we need to protect vram, otherwise it's already been done
		if (list.empty() || std::all_of(list.begin(), list.end(), [](vram_block *block) { return block == nullptr; }))
			_vmem_protect_vram(i * PAGE_SIZE, PAGE_SIZE);
		auto it = std::find(list.begin(), list.end(), nullptr);
		if (it != list.end())
			*it = block;
		else
			list.push_back(block);
	}
}
 
static std::mutex vramlist_lock;

bool VramLockedWriteOffset(size_t offset)
{
	if (offset >= VRAM_SIZE)
		return false;

	size_t addr_hash = offset / PAGE_SIZE;
	std::vector<vram_block *>& list = VramLocks[addr_hash];

	{
		std::lock_guard<std::mutex> lockguard(vramlist_lock);

		for (auto& lock : list)
		{
			if (lock != nullptr)
			{
				lock->texture->invalidate();

				if (lock != nullptr)
				{
					ERROR_LOG(PVR, "Error : pvr is supposed to remove lock");
					die("Invalid state");
				}
			}
		}
		list.clear();

		_vmem_unprotect_vram((u32)(offset & ~PAGE_MASK), PAGE_SIZE);
	}

	return true;
}

bool VramLockedWrite(u8* address)
{
	u32 offset = _vmem_get_vram_offset(address);
	if (offset == (u32)-1)
		return false;
	return VramLockedWriteOffset(offset);
}

//unlocks mem
//also frees the handle
static void libCore_vramlock_Unlock_block_wb(vram_block* block)
{
	vramlock_list_remove(block);
	delete block;
}

#ifdef _OPENMP
static inline int getThreadCount()
{
	int tcount = omp_get_num_procs() - 1;
	if (tcount < 1)
		tcount = 1;
	return std::min(tcount, (int)config::MaxThreads);
}

template<typename Func>
void parallelize(Func func, int start, int end)
{
	int tcount = getThreadCount();
#pragma omp parallel num_threads(tcount)
	{
		int num_threads = omp_get_num_threads();
		int thread = omp_get_thread_num();
		int chunk = (end - start) / num_threads;
		func(start + chunk * thread,
				num_threads == thread + 1 ? end
						: (start + chunk * (thread + 1)));
	}
}
#endif

static struct xbrz::ScalerCfg xbrz_cfg;

void UpscalexBRZ(int factor, u32* source, u32* dest, int width, int height, bool has_alpha)
{
#ifdef _OPENMP
	parallelize([=](int start, int end) {
		xbrz::scale(factor, source, dest, width, height, has_alpha ? xbrz::ColorFormat::ARGB : xbrz::ColorFormat::RGB,
				xbrz_cfg, start, end);
	}, 0, height);
#else
	xbrz::scale(factor, source, dest, width, height, has_alpha ? xbrz::ColorFormat::ARGB : xbrz::ColorFormat::RGB, xbrz_cfg);
#endif
}

struct PvrTexInfo
{
	const char* name;
	int bpp;        //4/8 for pal. 16 for yuv, rgb, argb
	TextureType type;
	// Conversion to 16 bpp
	TexConvFP PL;
	TexConvFP TW;
	TexConvFP VQ;
	// Conversion to 32 bpp
	TexConvFP32 PL32;
	TexConvFP32 TW32;
	TexConvFP32 VQ32;
	// Conversion to 8 bpp (palette)
	TexConvFP8 TW8;
};

#define TEX_CONV_TABLE \
const PvrTexInfo pvrTexInfo[8] = \
{	/* name     bpp Final format			   Planar		Twiddled	 VQ				Planar(32b)    Twiddled(32b)  VQ (32b)      Palette (8b)	*/	\
	{"1555", 	16,	TextureType::_5551,        tex1555_PL,  tex1555_TW,  tex1555_VQ,    tex1555_PL32,  tex1555_TW32,  tex1555_VQ32, nullptr },			\
	{"565", 	16, TextureType::_565,         tex565_PL,   tex565_TW,   tex565_VQ,     tex565_PL32,   tex565_TW32,   tex565_VQ32,  nullptr },	    	\
	{"4444", 	16, TextureType::_4444,        tex4444_PL,  tex4444_TW,  tex4444_VQ,    tex4444_PL32,  tex4444_TW32,  tex4444_VQ32, nullptr },	    	\
	{"yuv", 	16, TextureType::_8888,        nullptr,     nullptr,     nullptr,       texYUV422_PL,  texYUV422_TW,  texYUV422_VQ, nullptr },			\
	{"bumpmap", 16, TextureType::_4444,        texBMP_PL,   texBMP_TW,	 texBMP_VQ,     tex4444_PL32,  tex4444_TW32,  tex4444_VQ32, nullptr },			\
	{"pal4", 	4,	TextureType::_5551,		   nullptr,     texPAL4_TW,  texPAL4_VQ,    nullptr,       texPAL4_TW32,  texPAL4_VQ32, texPAL4PT_TW },		\
	{"pal8", 	8,	TextureType::_5551,		   nullptr,     texPAL8_TW,  texPAL8_VQ,    nullptr,       texPAL8_TW32,  texPAL8_VQ32, texPAL8PT_TW },		\
	{"ns/1555", 0},	                                                                                                                                    \
}

namespace opengl {
	TEX_CONV_TABLE;
}
namespace directx {
	TEX_CONV_TABLE;
}
#undef TEX_CONV_TABLE
static const PvrTexInfo *pvrTexInfo = opengl::pvrTexInfo;

extern const u32 VQMipPoint[11] =
{
	0x00000,//1
	0x00001,//2
	0x00002,//4
	0x00006,//8
	0x00016,//16
	0x00056,//32
	0x00156,//64
	0x00556,//128
	0x01556,//256
	0x05556,//512
	0x15556//1024
};
extern const u32 OtherMipPoint[11] =
{
	0x00003,//1
	0x00004,//2
	0x00008,//4
	0x00018,//8
	0x00058,//16
	0x00158,//32
	0x00558,//64
	0x01558,//128
	0x05558,//256
	0x15558,//512
	0x55558//1024
};

static const TextureType PAL_TYPE[4] = {
	TextureType::_5551, TextureType::_565, TextureType::_4444, TextureType::_8888
};

void BaseTextureCacheData::PrintTextureName()
{
#if !defined(NDEBUG) || defined(DEBUGFAST)
	char str[512];
	sprintf(str, "Texture: %s", GetPixelFormatName());

	if (tcw.VQ_Comp)
		strcat(str, " VQ");
	else if (tcw.ScanOrder == 0 || IsPaletted())
		strcat(str, " TW");
	else if (tcw.StrideSel == 1 && !IsPaletted())
		strcat(str, " Stride");

	if (tcw.ScanOrder == 0 && tcw.MipMapped)
		strcat(str, " MM");
	if (tsp.FilterMode != 0)
		strcat(str, " Bilinear");

	sprintf(str + strlen(str), " %dx%d @ 0x%X", 8 << tsp.TexU, 8 << tsp.TexV, tcw.TexAddr << 3);
	std::string id = GetId();
	sprintf(str + strlen(str), " id=%s", id.c_str());
	DEBUG_LOG(RENDERER, "%s", str);
#endif
}

//true if : dirty or paletted texture and hashes don't match
bool BaseTextureCacheData::NeedsUpdate() {
	bool rc = dirty != 0;
	if (tex_type != TextureType::_8)
	{
		if (tcw.PixelFmt == PixelPal4 && palette_hash != pal_hash_16[tcw.PalSelect])
			rc = true;
		else if (tcw.PixelFmt == PixelPal8 && palette_hash != pal_hash_256[tcw.PalSelect >> 4])
			rc = true;
	}

	return rc;
}

void BaseTextureCacheData::protectVRam()
{
	u32 end = sa + size - 1;
	if (end >= VRAM_SIZE)
	{
		WARN_LOG(PVR, "protectVRam: end >= VRAM_SIZE. Tried to lock area out of vram");
		end = VRAM_SIZE - 1;
	}

	if (sa_tex > end)
	{
		WARN_LOG(PVR, "vramlock_Lock: sa_tex > end. Tried to lock negative block");
		return;
	}

	vram_block *block = new vram_block();
	block->end = end;
	block->start = sa_tex;
	block->texture = this;

	{
		std::lock_guard<std::mutex> lock(vramlist_lock);

		if (lock_block == nullptr)
		{
			// This also protects vram if needed
			vramlock_list_add(block);
			lock_block = block;
		}
		else
			delete block;
	}
}

void BaseTextureCacheData::unprotectVRam()
{
	std::lock_guard<std::mutex> lock(vramlist_lock);
	if (lock_block)
		libCore_vramlock_Unlock_block_wb(lock_block);
	lock_block = nullptr;
}

bool BaseTextureCacheData::Delete()
{
	if (custom_load_in_progress > 0)
		return false;

	unprotectVRam();

	free(custom_image_data);
	custom_image_data = nullptr;

	return true;
}

BaseTextureCacheData::BaseTextureCacheData(TSP tsp, TCW tcw)
{
	this->tsp = tsp;
	this->tcw = tcw;

	//Reset state info ..
	Updates = 0;
	dirty = FrameCount;
	lock_block = nullptr;
	custom_image_data = nullptr;
	custom_load_in_progress = 0;
	gpuPalette = false;

	//decode info from tsp/tcw into the texture struct
	tex = &pvrTexInfo[tcw.PixelFmt == PixelReserved ? Pixel1555 : tcw.PixelFmt];	//texture format table entry

	sa_tex = (tcw.TexAddr << 3) & VRAM_MASK;	//texture start address
	sa = sa_tex;								//data texture start address (modified for MIPs, as needed)
	width = 8 << tsp.TexU;						//tex width
	height = 8 << tsp.TexV;						//tex height

	texconv8 = nullptr;

	if (tcw.ScanOrder && (tex->PL || tex->PL32))
	{
		//Texture is stored 'planar' in memory, no deswizzle is needed
		//verify(tcw.VQ_Comp==0);
		if (tcw.VQ_Comp != 0)
		{
			WARN_LOG(RENDERER, "Warning: planar texture with VQ set (invalid)");
			tcw.VQ_Comp = 0;
		}
		if (tcw.MipMapped != 0)
		{
			WARN_LOG(RENDERER, "Warning: planar texture with mipmaps (invalid)");
			tcw.MipMapped = 0;
		}

		//Planar textures support stride selection, mostly used for non power of 2 textures (videos)
		int stride = width;
		if (tcw.StrideSel)
			stride = (TEXT_CONTROL & 31) * 32;

		//Call the format specific conversion code
		texconv = tex->PL;
		texconv32 = tex->PL32;
		//calculate the size, in bytes, for the locking
		size = stride * height * tex->bpp / 8;
	}
	else
	{
		if (!IsPaletted())
		{
			tcw.ScanOrder = 0;
			tcw.StrideSel = 0;
		}
		// Quake 3 Arena uses one
		if (tcw.MipMapped)
			// Mipmapped texture must be square and TexV is ignored
			height = width;

		if (tcw.VQ_Comp)
		{
			verify(tex->VQ != NULL || tex->VQ32 != NULL);
			if (tcw.MipMapped)
				sa += VQMipPoint[tsp.TexU + 3];
			texconv = tex->VQ;
			texconv32 = tex->VQ32;
			size = width * height / 8 + 256 * 8;
		}
		else
		{
			verify(tex->TW != NULL || tex->TW32 != NULL);
			if (tcw.MipMapped)
				sa += OtherMipPoint[tsp.TexU + 3] * tex->bpp / 8;
			texconv = tex->TW;
			texconv32 = tex->TW32;
			size = width * height * tex->bpp / 8;
			texconv8 = tex->TW8;
		}
	}
}

void BaseTextureCacheData::ComputeHash()
{
	u32 hashSize = size;
	if (tcw.VQ_Comp)
	{
		// The size for VQ textures wasn't correctly calculated.
		// We use the old size to compute the hash for backward-compatibility
		// with existing custom texture packs.
		hashSize = size - 256 * 8;
	}
	texture_hash = XXH32(&vram[sa], hashSize, 7);
	if (IsPaletted())
		texture_hash ^= palette_hash;
	old_texture_hash = texture_hash;
	// Include everything but texaddr, reserved and stride. Palette textures don't have ScanOrder
	const u32 tcwMask = IsPaletted() ? 0xF8000000 : 0xFC000000;
	texture_hash ^= tcw.full & tcwMask;
}

void BaseTextureCacheData::Update()
{
	//texture state tracking stuff
	Updates++;
	dirty = 0;
	gpuPalette = false;
	tex_type = tex->type;

	bool has_alpha = false;
	if (IsPaletted())
	{
		if (IsGpuHandledPaletted(tsp, tcw))
		{
			tex_type = TextureType::_8;
			gpuPalette = true;
		}
		else
		{
			tex_type = PAL_TYPE[PAL_RAM_CTRL&3];
			if (tex_type != TextureType::_565)
				has_alpha = true;
		}

		// Get the palette hash to check for future updates
		// TODO get rid of ::palette_index and ::vq_codebook
		if (tcw.PixelFmt == PixelPal4)
		{
			palette_hash = pal_hash_16[tcw.PalSelect];
			::palette_index = tcw.PalSelect << 4;
		}
		else
		{
			palette_hash = pal_hash_256[tcw.PalSelect >> 4];
			::palette_index = (tcw.PalSelect >> 4) << 8;
		}
	}

	if (tcw.VQ_Comp)
		::vq_codebook = &vram[sa_tex];    // might be used if VQ tex

	//texture conversion work
	u32 stride = width;

	if (tcw.StrideSel && tcw.ScanOrder && (tex->PL || tex->PL32))
		stride = (TEXT_CONTROL & 31) * 32;

	u32 original_h = height;
	if (sa_tex > VRAM_SIZE || size == 0 || sa + size > VRAM_SIZE)
	{
		if (sa < VRAM_SIZE && sa + size > VRAM_SIZE && tcw.ScanOrder && stride > 0)
		{
			// Shenmue Space Harrier mini-arcade loads a texture that goes beyond the end of VRAM
			// but only uses the top portion of it
			height = (VRAM_SIZE - sa) * 8 / stride / tex->bpp;
			size = stride * height * tex->bpp/8;
		}
		else
		{
			WARN_LOG(RENDERER, "Warning: invalid texture. Address %08X %08X size %d", sa_tex, sa, size);
			return;
		}
	}
	if (config::CustomTextures)
		custom_texture.LoadCustomTextureAsync(this);

	void *temp_tex_buffer = NULL;
	u32 upscaled_w = width;
	u32 upscaled_h = height;

	PixelBuffer<u16> pb16;
	PixelBuffer<u32> pb32;
	PixelBuffer<u8> pb8;

	// Figure out if we really need to use a 32-bit pixel buffer
	bool textureUpscaling = config::TextureUpscale > 1
			// Don't process textures that are too big
			&& (int)(width * height) <= config::MaxFilteredTextureSize * config::MaxFilteredTextureSize
			// Don't process YUV textures
			&& tcw.PixelFmt != PixelYUV;
	bool need_32bit_buffer = true;
	if (!textureUpscaling
		&& (!IsPaletted() || tex_type != TextureType::_8888)
		&& texconv != NULL
		&& !Force32BitTexture(tex_type))
		need_32bit_buffer = false;
	// TODO avoid upscaling/depost. textures that change too often

	bool mipmapped = IsMipmapped() && !config::DumpTextures;

	if (texconv32 != NULL && need_32bit_buffer)
	{
		if (textureUpscaling)
			// don't use mipmaps if upscaling
			mipmapped = false;
		// Force the texture type since that's the only 32-bit one we know
		tex_type = TextureType::_8888;

		if (mipmapped)
		{
			pb32.init(width, height, true);
			for (u32 i = 0; i <= tsp.TexU + 3u; i++)
			{
				pb32.set_mipmap(i);
				u32 vram_addr;
				if (tcw.VQ_Comp)
				{
					vram_addr = sa_tex + VQMipPoint[i];
					if (i == 0)
					{
						PixelBuffer<u32> pb0;
						pb0.init(2, 2 ,false);
						texconv32(&pb0, (u8*)&vram[vram_addr], 2, 2);
						*pb32.data() = *pb0.data(1, 1);
						continue;
					}
				}
				else
					vram_addr = sa_tex + OtherMipPoint[i] * tex->bpp / 8;
				if (tcw.PixelFmt == PixelYUV && i == 0)
					// Special case for YUV at 1x1 LoD
					pvrTexInfo[Pixel565].TW32(&pb32, &vram[vram_addr], 1, 1);
				else
					texconv32(&pb32, &vram[vram_addr], 1 << i, 1 << i);
			}
			pb32.set_mipmap(0);
		}
		else
		{
			pb32.init(width, height);
			texconv32(&pb32, (u8*)&vram[sa], stride, height);

			// xBRZ scaling
			if (textureUpscaling)
			{
				PixelBuffer<u32> tmp_buf;
				tmp_buf.init(width * config::TextureUpscale, height * config::TextureUpscale);

				if (tcw.PixelFmt == Pixel1555 || tcw.PixelFmt == Pixel4444)
					// Alpha channel formats. Palettes with alpha are already handled
					has_alpha = true;
				UpscalexBRZ(config::TextureUpscale, pb32.data(), tmp_buf.data(), width, height, has_alpha);
				pb32.steal_data(tmp_buf);
				upscaled_w *= config::TextureUpscale;
				upscaled_h *= config::TextureUpscale;
			}
		}
		temp_tex_buffer = pb32.data();
	}
	else if (texconv8 != NULL && tex_type == TextureType::_8)
	{
		if (mipmapped)
		{
			// This shouldn't happen since mipmapped palette textures are converted to rgba
			pb8.init(width, height, true);
			for (u32 i = 0; i <= tsp.TexU + 3u; i++)
			{
				pb8.set_mipmap(i);
				u32 vram_addr = sa_tex + OtherMipPoint[i] * tex->bpp / 8;
				texconv8(&pb8, &vram[vram_addr], 1 << i, 1 << i);
			}
			pb8.set_mipmap(0);
		}
		else
		{
			pb8.init(width, height);
			texconv8(&pb8, &vram[sa], stride, height);
		}
		temp_tex_buffer = pb8.data();
	}
	else if (texconv != NULL)
	{
		if (mipmapped)
		{
			pb16.init(width, height, true);
			for (u32 i = 0; i <= tsp.TexU + 3u; i++)
			{
				pb16.set_mipmap(i);
				u32 vram_addr;
				if (tcw.VQ_Comp)
				{
					vram_addr = sa_tex + VQMipPoint[i];
					if (i == 0)
					{
						PixelBuffer<u16> pb0;
						pb0.init(2, 2 ,false);
						texconv(&pb0, (u8*)&vram[vram_addr], 2, 2);
						*pb16.data() = *pb0.data(1, 1);
						continue;
					}
				}
				else
					vram_addr = sa_tex + OtherMipPoint[i] * tex->bpp / 8;
				texconv(&pb16, (u8*)&vram[vram_addr], 1 << i, 1 << i);
			}
			pb16.set_mipmap(0);
		}
		else
		{
			pb16.init(width, height);
			texconv(&pb16,(u8*)&vram[sa],stride,height);
		}
		temp_tex_buffer = pb16.data();
	}
	else
	{
		//fill it in with a temp color
		WARN_LOG(RENDERER, "UNHANDLED TEXTURE");
		pb16.init(width, height);
		memset(pb16.data(), 0x80, width * height * 2);
		temp_tex_buffer = pb16.data();
		mipmapped = false;
	}
	// Restore the original texture height if it was constrained to VRAM limits above
	height = original_h;

	//lock the texture to detect changes in it
	protectVRam();

	UploadToGPU(upscaled_w, upscaled_h, (const u8 *)temp_tex_buffer, IsMipmapped(), mipmapped);
	if (config::DumpTextures)
	{
		ComputeHash();
		custom_texture.DumpTexture(texture_hash, upscaled_w, upscaled_h, tex_type, temp_tex_buffer);
		NOTICE_LOG(RENDERER, "Dumped texture %x.png. Old hash %x", texture_hash, old_texture_hash);
	}
	PrintTextureName();
}

void BaseTextureCacheData::CheckCustomTexture()
{
	if (IsCustomTextureAvailable())
	{
		tex_type = TextureType::_8888;
		gpuPalette = false;
		UploadToGPU(custom_width, custom_height, custom_image_data, IsMipmapped(), false);
		free(custom_image_data);
		custom_image_data = nullptr;
	}
}

void BaseTextureCacheData::SetDirectXColorOrder(bool enabled) {
	pvrTexInfo = enabled ? directx::pvrTexInfo : opengl::pvrTexInfo;
}

template<typename Packer>
void ReadFramebuffer(const FramebufferInfo& info, PixelBuffer<u32>& pb, int& width, int& height)
{
	width = (info.fb_r_size.fb_x_size + 1) * 2;     // in 16-bit words
	height = info.fb_r_size.fb_y_size + 1;
	int modulus = (info.fb_r_size.fb_modulus - 1) * 2;

	int bpp;
	switch (info.fb_r_ctrl.fb_depth)
	{
		case fbde_0555:
		case fbde_565:
			bpp = 2;
			break;
		case fbde_888:
			bpp = 3;
			width = (width * 2) / 3;		// in pixels
			modulus = (modulus * 2) / 3;	// in pixels
			break;
		case fbde_C888:
			bpp = 4;
			width /= 2;             // in pixels
			modulus /= 2;           // in pixels
			break;
		default:
			die("Invalid framebuffer format\n");
			bpp = 4;
			break;
	}

	u32 addr = info.fb_r_sof1;
	if (info.spg_control.interlace)
	{
		if (width == modulus && info.fb_r_sof2 == info.fb_r_sof1 + width * bpp)
		{
			// Typical case alternating even and odd lines -> take the whole buffer at once
			modulus = 0;
			height *= 2;
		}
		else
		{
			addr = info.spg_status.fieldnum ? info.fb_r_sof2 : info.fb_r_sof1;
		}
	}

	pb.init(width, height);
	u32 *dst = (u32 *)pb.data();
	const u32 fb_concat = info.fb_r_ctrl.fb_concat;

	switch (info.fb_r_ctrl.fb_depth)
	{
		case fbde_0555:    // 555 RGB
			for (int y = 0; y < height; y++)
			{
				for (int i = 0; i < width; i++)
				{
					u16 src = pvr_read32p<u16>(addr);
					*dst++ = Packer::pack(
							(((src >> 10) & 0x1F) << 3) | fb_concat,
							(((src >> 5) & 0x1F) << 3) | fb_concat,
							(((src >> 0) & 0x1F) << 3) | fb_concat,
							0xff);
					addr += bpp;
				}
				addr += modulus * bpp;
			}
			break;

		case fbde_565:    // 565 RGB
			for (int y = 0; y < height; y++)
			{
				for (int i = 0; i < width; i++)
				{
					u16 src = pvr_read32p<u16>(addr);
					*dst++ = Packer::pack(
							(((src >> 11) & 0x1F) << 3) | fb_concat,
							(((src >> 5) & 0x3F) << 2) | (fb_concat & 3),
							(((src >> 0) & 0x1F) << 3) | fb_concat,
							0xFF);
					addr += bpp;
				}
				addr += modulus * bpp;
			}
			break;
		case fbde_888:		// 888 RGB
			for (int y = 0; y < height; y++)
			{
				for (int i = 0; i < width; i += 4)
				{
					u32 src = pvr_read32p<u32>(addr);
					*dst++ = Packer::pack(src >> 16, src >> 8, src, 0xff);
					addr += 4;
					if (i + 1 >= width)
						break;
					u32 src2 = pvr_read32p<u32>(addr);
					*dst++ = Packer::pack(src2 >> 8, src2, src >> 24, 0xff);
					addr += 4;
					if (i + 2 >= width)
						break;
					u32 src3 = pvr_read32p<u32>(addr);
					*dst++ = Packer::pack(src3, src2 >> 24, src2 >> 16, 0xff);
					addr += 4;
					if (i + 3 >= width)
						break;
					*dst++ = Packer::pack(src3 >> 24, src3 >> 16, src3 >> 8, 0xff);
				}
				addr += modulus * bpp;
			}
			break;
		case fbde_C888:     // 0888 RGB
			for (int y = 0; y < height; y++)
			{
				for (int i = 0; i < width; i++)
				{
					u32 src = pvr_read32p<u32>(addr);
					*dst++ = Packer::pack(src >> 16, src >> 8, src, 0xff);
					addr += bpp;
				}
				addr += modulus * bpp;
			}
			break;
	}
}
template void ReadFramebuffer<RGBAPacker>(const FramebufferInfo& info, PixelBuffer<u32>& pb, int& width, int& height);
template void ReadFramebuffer<BGRAPacker>(const FramebufferInfo& info, PixelBuffer<u32>& pb, int& width, int& height);

template<int Red, int Green, int Blue, int Alpha>
void WriteTextureToVRam(u32 width, u32 height, const u8 *data, u16 *dst, FB_W_CTRL_type fb_w_ctrl, u32 linestride)
{
	u32 padding = linestride;
	if (padding / 2 > width)
		padding = padding / 2 - width;
	else
		padding = 0;

	const u16 kval_bit = (fb_w_ctrl.fb_kval & 0x80) << 8;
	const u8 fb_alpha_threshold = fb_w_ctrl.fb_alpha_threshold;

	const u8 *p = data;

	for (u32 l = 0; l < height; l++) {
		switch(fb_w_ctrl.fb_packmode)
		{
		case 0: //0x0   0555 KRGB 16 bit  (default)	Bit 15 is the value of fb_kval[7].
			for (u32 c = 0; c < width; c++) {
				*dst++ = (((p[Red] >> 3) & 0x1F) << 10) | (((p[Green] >> 3) & 0x1F) << 5) | ((p[Blue] >> 3) & 0x1F) | kval_bit;
				p += 4;
			}
			break;
		case 1: //0x1   565 RGB 16 bit
			for (u32 c = 0; c < width; c++) {
				*dst++ = (((p[Red] >> 3) & 0x1F) << 11) | (((p[Green] >> 2) & 0x3F) << 5) | ((p[Blue] >> 3) & 0x1F);
				p += 4;
			}
			break;
		case 2: //0x2   4444 ARGB 16 bit
			for (u32 c = 0; c < width; c++) {
				*dst++ = (((p[Red] >> 4) & 0xF) << 8) | (((p[Green] >> 4) & 0xF) << 4) | ((p[Blue] >> 4) & 0xF) | (((p[Alpha] >> 4) & 0xF) << 12);
				p += 4;
			}
			break;
		case 3://0x3    1555 ARGB 16 bit    The alpha value is determined by comparison with the value of fb_alpha_threshold.
			for (u32 c = 0; c < width; c++) {
				*dst++ = (((p[Red] >> 3) & 0x1F) << 10) | (((p[Green] >> 3) & 0x1F) << 5) | ((p[Blue] >> 3) & 0x1F) | (p[Alpha] > fb_alpha_threshold ? 0x8000 : 0);
				p += 4;
			}
			break;
		}
		dst += padding;
	}
}
template void WriteTextureToVRam<0, 1, 2, 3>(u32 width, u32 height, const u8 *data, u16 *dst, FB_W_CTRL_type fb_w_ctrl, u32 linestride);
template void WriteTextureToVRam<2, 1, 0, 3>(u32 width, u32 height, const u8 *data, u16 *dst, FB_W_CTRL_type fb_w_ctrl, u32 linestride);

template<int bits>
static inline u8 roundColor(u8 in)
{
	u8 out = in >> (8 - bits);
	if (out != 0xffu >> (8 - bits))
		out += (in >> (8 - bits - 1)) & 1;
	return out;
}

template<int Red, int Green, int Blue, int Alpha>
void WriteFramebuffer(u32 width, u32 height, const u8 *data, u32 dstAddr, FB_W_CTRL_type fb_w_ctrl, u32 linestride, FB_X_CLIP_type xclip, FB_Y_CLIP_type yclip)
{
	int bpp;
	switch (fb_w_ctrl.fb_packmode)
	{
		case 0:
		case 1:
		case 2:
		case 3:
			bpp = 2;
			break;
		case 4:
			bpp = 3;
			break;
		case 5:
		case 6:
			bpp = 4;
			break;
		default:
			die("Invalid framebuffer format");
			bpp = 4;
			break;
	}

	u32 padding = linestride;
	if (padding > width * bpp)
		padding = padding - width * bpp;
	else
		padding = 0;

	const u16 kval_bit = (fb_w_ctrl.fb_kval & 0x80) << 8;
	const u8 fb_alpha_threshold = fb_w_ctrl.fb_alpha_threshold;

	const u8 *p = data + 4 * yclip.min * width;
	dstAddr += bpp * yclip.min * (width + padding / bpp);

	for (u32 l = yclip.min; l < height && l <= yclip.max; l++)
	{
		p += 4 * xclip.min;
		dstAddr += bpp * xclip.min;

		switch(fb_w_ctrl.fb_packmode)
		{
		case 0: // 0555 KRGB 16 bit  (default)	Bit 15 is the value of fb_kval[7].
			for (u32 c = xclip.min; c < width && c <= xclip.max; c++) {
				pvr_write32p(dstAddr, (u16)((roundColor<5>(p[Red]) << 10)
						| (roundColor<5>(p[Green]) << 5)
						| roundColor<5>(p[Blue])
						| kval_bit));
				p += 4;
				dstAddr += bpp;
			}
			break;
		case 1: // 565 RGB 16 bit
			for (u32 c = xclip.min; c < width && c <= xclip.max; c++) {
				pvr_write32p(dstAddr, (u16)((roundColor<5>(p[Red]) << 11)
						| (roundColor<6>(p[Green]) << 5)
						| roundColor<5>(p[Blue])));
				p += 4;
				dstAddr += bpp;
			}
			break;
		case 2: // 4444 ARGB 16 bit
			for (u32 c = xclip.min; c < width && c <= xclip.max; c++) {
				pvr_write32p(dstAddr, (u16)((roundColor<4>(p[Red]) << 8)
						| (roundColor<4>(p[Green]) << 4)
						| roundColor<4>(p[Blue])
						| (roundColor<4>(p[Alpha]) << 12)));
				p += 4;
				dstAddr += bpp;
			}
			break;
		case 3: // 1555 ARGB 16 bit    The alpha value is determined by comparison with the value of fb_alpha_threshold.
			for (u32 c = xclip.min; c < width && c <= xclip.max; c++) {
				pvr_write32p(dstAddr, (u16)((roundColor<5>(p[Red]) << 10)
						| (roundColor<5>(p[Green]) << 5)
						| roundColor<5>(p[Blue])
						| (p[Alpha] > fb_alpha_threshold ? 0x8000 : 0)));
				p += 4;
				dstAddr += bpp;
			}
			break;
		case 4: // 888 RGB 24 bit packed
			for (u32 c = xclip.min; c < width - 3u && c <= xclip.max - 3u; c += 4) {
				pvr_write32p(dstAddr, (u32)((p[Blue + 4] << 24) | (p[Red] << 16) | (p[Green] << 8) | p[Blue]));
				p += 4;
				dstAddr += 4;
				pvr_write32p(dstAddr, (u32)((p[Green + 4] << 24) | (p[Blue + 4] << 16) | (p[Red] << 8) | p[Green]));
				p += 4;
				dstAddr += 4;
				pvr_write32p(dstAddr, (u32)((p[Red + 4] << 24) | (p[Green + 4] << 16) | (p[Blue + 4] << 8) | p[Red]));
				p += 8;
				dstAddr += 4;
			}
			break;
		case 5: // 0888 KRGB 32 bit (K is the value of fk_kval.)
			for (u32 c = xclip.min; c < width && c <= xclip.max; c++) {
				pvr_write32p(dstAddr, (u32)((p[Red] << 16) | (p[Green] << 8) | p[Blue] | (fb_w_ctrl.fb_kval << 24)));
				p += 4;
				dstAddr += bpp;
			}
			break;
		case 6: // 8888 ARGB 32 bit
			for (u32 c = xclip.min; c < width && c <= xclip.max; c++) {
				pvr_write32p(dstAddr, (u32)((p[Red] << 16) | (p[Green] << 8) | p[Blue] | (p[Alpha] << 24)));
				p += 4;
				dstAddr += bpp;
			}
			break;
		default:
			break;
		}
		dstAddr += padding + (width - xclip.max - 1) * bpp;
		p += (width - xclip.max - 1) * 4;
	}
}
template void WriteFramebuffer<0, 1, 2, 3>(u32 width, u32 height, const u8 *data, u32 dstAddr, FB_W_CTRL_type fb_w_ctrl,
		u32 linestride, FB_X_CLIP_type xclip, FB_Y_CLIP_type yclip);
template void WriteFramebuffer<2, 1, 0, 3>(u32 width, u32 height, const u8 *data, u32 dstAddr, FB_W_CTRL_type fb_w_ctrl,
		u32 linestride, FB_X_CLIP_type xclip, FB_Y_CLIP_type yclip);

void BaseTextureCacheData::invalidate()
{
	dirty = FrameCount;

	libCore_vramlock_Unlock_block_wb(lock_block);
	lock_block = nullptr;
}

void getRenderToTextureDimensions(u32& width, u32& height, u32& pow2Width, u32& pow2Height)
{
	pow2Width = 8;
	while (pow2Width < width)
		pow2Width *= 2;
	pow2Height = 8;
	while (pow2Height < height)
		pow2Height *= 2;
	if (!config::RenderToTextureBuffer)
	{
		float upscale = config::RenderResolution / 480.f;
		width *= upscale;
		height *= upscale;
		pow2Width *= upscale;
		pow2Height *= upscale;
	}
}

#ifdef TEST_AUTOMATION
#include <stb_image_write.h>

void dump_screenshot(u8 *buffer, u32 width, u32 height, bool alpha, u32 rowPitch, bool invertY)
{
	stbi_flip_vertically_on_write((int)invertY);
	stbi_write_png("screenshot.png", width, height, alpha ? 4 : 3, buffer, rowPitch);
}
#endif
