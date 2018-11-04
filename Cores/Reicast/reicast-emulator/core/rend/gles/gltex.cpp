#include "gles.h"
#include "rend/TexCache.h"
#include "hw/pvr/pvr_mem.h"

/*
Textures

Textures are converted to native OpenGL textures
The mapping is done with tcw:tsp -> GL texture. That includes stuff like
filtering/ texture repeat

To save space native formats are used for 1555/565/4444 (only bit shuffling is done)
YUV is converted to 565 (some loss of quality on that)
PALs are decoded to their unpaletted format, 8888 is downcasted to 4444

Mipmaps
	not supported for now

Compression
	look into it, but afaik PVRC is not realtime doable
*/

#if FEAT_HAS_SOFTREND
	#include <xmmintrin.h>
#endif

u16 temp_tex_buffer[1024*1024];
extern u32 decoded_colors[3][65536];

typedef void TexConvFP(PixelBuffer* pb,u8* p_in,u32 Width,u32 Height);

struct PvrTexInfo
{
	const char* name;
	int bpp;        //4/8 for pal. 16 for uv, argb
	GLuint type;
	TexConvFP *PL;
	TexConvFP *TW;
	TexConvFP *VQ;
};

PvrTexInfo format[8]=
{
	{"1555", 16,GL_UNSIGNED_SHORT_5_5_5_1, &tex1555_PL,&tex1555_TW,&tex1555_VQ},	//1555
	{"565", 16,GL_UNSIGNED_SHORT_5_6_5,    &tex565_PL,&tex565_TW,&tex565_VQ},		//565
	{"4444", 16,GL_UNSIGNED_SHORT_4_4_4_4, &tex4444_PL,&tex4444_TW,&tex4444_VQ},	//4444
	{"yuv", 16,GL_UNSIGNED_SHORT_5_6_5,    &texYUV422_PL,&texYUV422_TW,&texYUV422_VQ},	//yuv
	{"UNSUPPORTED BUMP MAPPED POLY", 16,GL_UNSIGNED_SHORT_4_4_4_4,&texBMP_PL,&texBMP_TW,&texBMP_VQ},	//bump_ns
	{"pal4", 4,0,0,texPAL4_TW,0},	//pal4
	{"pla8", 8,0,0,texPAL8_TW,0},	//pal8
	{"ns/1555", 0},	//ns, 1555
};

const u32 MipPoint[8] =
{
	0x00006,//8
	0x00016,//16
	0x00056,//32
	0x00156,//64
	0x00556,//128
	0x01556,//256
	0x05556,//512
	0x15556//1024
};

const GLuint PAL_TYPE[4]=
{GL_UNSIGNED_SHORT_5_5_5_1,GL_UNSIGNED_SHORT_5_6_5,GL_UNSIGNED_SHORT_4_4_4_4,GL_UNSIGNED_SHORT_4_4_4_4};


//Texture Cache :)
struct TextureCacheData
{
	TSP tsp;        //dreamcast texture parameters
	TCW tcw;

	GLuint texID;   //gl texture
	u16* pData;
	int tex_type;

	u32 Lookups;

	//decoded texture info
	u32 sa;         //pixel data start address in vram (might be offset for mipmaps/etc)
	u32 sa_tex;		//texture data start address in vram 
	u32 w,h;        //width & height of the texture
	u32 size;       //size, in bytes, in vram

	PvrTexInfo* tex;
	TexConvFP*  texconv;

	u32 dirty;
	vram_block* lock_block;

	u32 Updates;

	//used for palette updates
	u32  pal_local_rev;         //local palette rev
	u32* pal_table_rev;         //table palette rev pointer
	u32  indirect_color_ptr;    //palette color table index for pal. tex
	                            //VQ quantizers table for VQ tex
	                            //a texture can't be both VQ and PAL at the same time

	void PrintTextureName()
	{
		printf("Texture: %s ",tex?tex->name:"?format?");

		if (tcw.VQ_Comp)
			printf(" VQ");

		if (tcw.ScanOrder==0)
			printf(" TW");

		if (tcw.MipMapped)
			printf(" MM");

		if (tcw.StrideSel)
			printf(" Stride");

		printf(" %dx%d @ 0x%X",8<<tsp.TexU,8<<tsp.TexV,tcw.TexAddr<<3);
		printf("\n");
	}

	void SetRepeatMode(GLuint dir,u32 clamp,u32 mirror)
	{
		if (clamp)
			glTexParameteri (GL_TEXTURE_2D, dir, GL_CLAMP_TO_EDGE);
		else 
			glTexParameteri (GL_TEXTURE_2D, dir, mirror?GL_MIRRORED_REPEAT : GL_REPEAT);
	}

	//Create GL texture from tsp/tcw
	void Create(bool isGL)
	{
		//ask GL for texture ID
		if (isGL) {
			glGenTextures(1, &texID);
		}
		else {
			texID = 0;
		}
		
		pData = 0;
		tex_type = 0;

		//Reset state info ..
		Lookups=0;
		Updates=0;
		dirty=FrameCount;
		lock_block=0;

		//decode info from tsp/tcw into the texture struct
		tex=&format[tcw.PixelFmt==7?0:tcw.PixelFmt];		//texture format table entry

		sa_tex = (tcw.TexAddr<<3) & VRAM_MASK;	//texture start address
		sa = sa_tex;							//data texture start address (modified for MIPs, as needed)
		w=8<<tsp.TexU;                   //tex width
		h=8<<tsp.TexV;                   //tex height

		if (texID) {
			//bind texture to set modes
			glBindTexture(GL_TEXTURE_2D, texID);

			//set texture repeat mode
			SetRepeatMode(GL_TEXTURE_WRAP_S, tsp.ClampU, tsp.FlipU); // glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, (tsp.ClampU ? GL_CLAMP_TO_EDGE : (tsp.FlipU ? GL_MIRRORED_REPEAT : GL_REPEAT))) ;
			SetRepeatMode(GL_TEXTURE_WRAP_T, tsp.ClampV, tsp.FlipV); // glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, (tsp.ClampV ? GL_CLAMP_TO_EDGE : (tsp.FlipV ? GL_MIRRORED_REPEAT : GL_REPEAT))) ;

#ifdef GLES
			glHint(GL_GENERATE_MIPMAP_HINT, GL_NICEST);
#endif

			//set texture filter mode
			if (tsp.FilterMode == 0)
			{
				//disable filtering, mipmaps
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
			}
			else
			{
				//bilinear filtering
				//PowerVR supports also trilinear via two passes, but we ignore that for now
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER, (tcw.MipMapped && settings.rend.UseMipmaps)?GL_LINEAR_MIPMAP_NEAREST:GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
			}
		}

		//PAL texture
		if (tex->bpp==4)
		{
			pal_table_rev=&pal_rev_16[tcw.PalSelect];
			indirect_color_ptr=tcw.PalSelect<<4;
		}
		else if (tex->bpp==8)
		{
			pal_table_rev=&pal_rev_256[tcw.PalSelect>>4];
			indirect_color_ptr=(tcw.PalSelect>>4)<<8;
		}
		else
		{
			pal_table_rev=0;
		}

		//VQ table (if VQ tex)
		if (tcw.VQ_Comp)
			indirect_color_ptr=sa;

			//Convert a pvr texture into OpenGL
		switch (tcw.PixelFmt)
		{

		case 0: //0     1555 value: 1 bit; RGB values: 5 bits each
		case 7: //7     Reserved        Regarded as 1555
		case 1: //1     565      R value: 5 bits; G value: 6 bits; B value: 5 bits
		case 2: //2     4444 value: 4 bits; RGB values: 4 bits each
		case 3: //3     YUV422 32 bits per 2 pixels; YUYV values: 8 bits each
		case 4: //4    -NOT_PROPERLY SUPPORTED- Bump Map        16 bits/pixel; S value: 8 bits; R value: 8 bits -NOT_PROPERLY SUPPORTED-
		case 5: //5     4 BPP Palette   Palette texture with 4 bits/pixel
		case 6: //6     8 BPP Palette   Palette texture with 8 bits/pixel
			if (tcw.ScanOrder && tex->PL)
			{
				//Texture is stored 'planar' in memory, no deswizzle is needed
				verify(tcw.VQ_Comp==0);
				//Planar textures support stride selection, mostly used for non power of 2 textures (videos)
				int stride=w;
				if (tcw.StrideSel) 
					stride=(TEXT_CONTROL&31)*32;
				//Call the format specific conversion code
				texconv=tex->PL;
				//calculate the size, in bytes, for the locking
				size=stride*h*tex->bpp/8;
			}
			else
			{
				verify(w==h || !tcw.MipMapped); // are non square mipmaps supported ? i can't recall right now *WARN*

				if (tcw.VQ_Comp)
				{
					verify(tex->VQ!=0);
					indirect_color_ptr=sa;
					if (tcw.MipMapped)
						sa+=MipPoint[tsp.TexU];
					texconv=tex->VQ;
					size=w*h/8;
				}
				else
				{
					verify(tex->TW!=0)
					if (tcw.MipMapped)
						sa+=MipPoint[tsp.TexU]*tex->bpp/2;
					texconv=tex->TW;
					size=w*h*tex->bpp/8;
				}
			}
			break;
		default:
			printf("Unhandled texture %d\n",tcw.PixelFmt);
			size=w*h*2;
			memset(temp_tex_buffer,0xFFFFFFFF,size);
			texconv=0;
		}
	}

	void Update()
	{
		//texture state tracking stuff
		Updates++;
		dirty=0;

		GLuint textype=tex->type;

		if (pal_table_rev) 
		{
			textype=PAL_TYPE[PAL_RAM_CTRL&3];
			pal_local_rev=*pal_table_rev; //make sure to update the local rev, so it won't have to redo the tex
		}

		palette_index=indirect_color_ptr; //might be used if pal. tex
		vq_codebook=(u8*)&vram[indirect_color_ptr];  //might be used if VQ tex

		//texture conversion work
		PixelBuffer pbt;
		pbt.p_buffer_start=pbt.p_current_line=temp_tex_buffer;
		pbt.pixels_per_line=w;

		u32 stride=w;

		if (tcw.StrideSel && tcw.ScanOrder && tex->PL) 
			stride=(TEXT_CONTROL&31)*32; //I think this needs +1 ?

		if(texconv!=0)
		{
			texconv(&pbt,(u8*)&vram[sa],stride,h);
		}
		else
		{
			//fill it in with a temp color
			printf("UNHANDLED TEXTURE\n");
			memset(temp_tex_buffer,0xF88F8F7F,w*h*2);
		}

		//PrintTextureName();

		//lock the texture to detect changes in it
		lock_block = libCore_vramlock_Lock(sa_tex,sa+size-1,this);

		if (texID) {
			//upload to OpenGL !
			glBindTexture(GL_TEXTURE_2D, texID);
			GLuint comps=textype==GL_UNSIGNED_SHORT_5_6_5?GL_RGB:GL_RGBA;
			glTexImage2D(GL_TEXTURE_2D, 0,comps , w, h, 0, comps, textype, temp_tex_buffer);
			if (tcw.MipMapped && settings.rend.UseMipmaps)
				glGenerateMipmap(GL_TEXTURE_2D);
		}
		else {
			#if FEAT_HAS_SOFTREND
				if (textype == GL_UNSIGNED_SHORT_5_6_5)
					tex_type = 0;
				else if (textype == GL_UNSIGNED_SHORT_5_5_5_1)
					tex_type = 1;
				else if (textype == GL_UNSIGNED_SHORT_4_4_4_4)
					tex_type = 2;

				if (pData) {
					_mm_free(pData);
				}

				pData = (u16*)_mm_malloc(w * h * 16, 16);
				for (int y = 0; y < h; y++) {
					for (int x = 0; x < w; x++) {
						u32* data = (u32*)&pData[(x + y*w) * 8];

						data[0] = decoded_colors[tex_type][temp_tex_buffer[(x + 1) % w + (y + 1) % h * w]];
						data[1] = decoded_colors[tex_type][temp_tex_buffer[(x + 0) % w + (y + 1) % h * w]];
						data[2] = decoded_colors[tex_type][temp_tex_buffer[(x + 1) % w + (y + 0) % h * w]];
						data[3] = decoded_colors[tex_type][temp_tex_buffer[(x + 0) % w + (y + 0) % h * w]];
					}
				}
			#else
				die("Soft rend disabled, invalid code path");
			#endif
		}
	}

	//true if : dirty or paletted texture and revs don't match
	bool NeedsUpdate() { return (dirty) || (pal_table_rev!=0 && *pal_table_rev!=pal_local_rev); }
	
	void Delete()
	{
		if (pData) {
			#if FEAT_HAS_SOFTREND
				_mm_free(pData);
				pData = 0;
			#else
				die("softrend disabled, invalid codepath");
			#endif
		}

		if (texID) {
			glDeleteTextures(1, &texID);
		}
		if (lock_block)
			libCore_vramlock_Unlock_block(lock_block);
		lock_block=0;
	}
};

#include <map>
map<u64,TextureCacheData> TexCache;
typedef map<u64,TextureCacheData>::iterator TexCacheIter;

//TexCacheList<TextureCacheData> TexCache;

struct FBT
{
	u32 TexAddr;
	GLuint depthb,stencilb;
	GLuint tex;
	GLuint fbo;
};

FBT fb_rtt;

void BindRTT(u32 addy, u32 fbw, u32 fbh, u32 channels, u32 fmt)
{
	FBT& rv=fb_rtt;

	if (rv.fbo) glDeleteFramebuffers(1,&rv.fbo);
	if (rv.tex) glDeleteTextures(1,&rv.tex);
	if (rv.depthb) glDeleteRenderbuffers(1,&rv.depthb);
	if (rv.stencilb) glDeleteRenderbuffers(1,&rv.stencilb);

	rv.TexAddr=addy>>3;

	// Find the largest square power of two texture that fits into the viewport

	// Get the currently bound frame buffer object. On most platforms this just gives 0.
	//glGetIntegerv(GL_FRAMEBUFFER_BINDING, &m_i32OriginalFbo);

	// Generate and bind a render buffer which will become a depth buffer shared between our two FBOs
	glGenRenderbuffers(1, &rv.depthb);
	glBindRenderbuffer(GL_RENDERBUFFER, rv.depthb);

	/*
		Currently it is unknown to GL that we want our new render buffer to be a depth buffer.
		glRenderbufferStorage will fix this and in this case will allocate a depth buffer
		m_i32TexSize by m_i32TexSize.
	*/

#ifdef GLES
	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, fbw, fbh);
#else
	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, fbw, fbh);
#endif

	glGenRenderbuffers(1, &rv.stencilb);
	glBindRenderbuffer(GL_RENDERBUFFER, rv.stencilb);
	glRenderbufferStorage(GL_RENDERBUFFER, GL_STENCIL_INDEX8, fbw, fbh);

	// Create a texture for rendering to
	glGenTextures(1, &rv.tex);
	glBindTexture(GL_TEXTURE_2D, rv.tex);

	glTexImage2D(GL_TEXTURE_2D, 0, channels, fbw, fbh, 0, channels, fmt, 0);

	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

	// Create the object that will allow us to render to the aforementioned texture
	glGenFramebuffers(1, &rv.fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, rv.fbo);

	// Attach the texture to the FBO
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rv.tex, 0);

	// Attach the depth buffer we created earlier to our FBO.
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, rv.depthb);

	// Check that our FBO creation was successful
	GLuint uStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);

	verify(uStatus == GL_FRAMEBUFFER_COMPLETE);
}

GLuint gl_GetTexture(TSP tsp, TCW tcw)
{
	if (tcw.TexAddr==fb_rtt.TexAddr && fb_rtt.tex)
	{
		return fb_rtt.tex;
	}

	//lookup texture
	TextureCacheData* tf;
	//= TexCache.Find(tcw.full,tsp.full);
	u64 key=((u64)tcw.full<<32) | tsp.full;

	TexCacheIter tx=TexCache.find(key);

	if (tx!=TexCache.end())
	{
		tf=&tx->second;
	}
	else //create if not existing
	{
		TextureCacheData tfc={0};
		TexCache[key]=tfc;

		tx=TexCache.find(key);
		tf=&tx->second;

		tf->tsp=tsp;
		tf->tcw=tcw;
		tf->Create(true);
	}

	//update if needed
	if (tf->NeedsUpdate())
		tf->Update();

	//update state for opts/stuff
	tf->Lookups++;

	//return gl texture
	return tf->texID;
}


text_info raw_GetTexture(TSP tsp, TCW tcw)
{
	text_info rv = { 0 };

	//lookup texture
	TextureCacheData* tf;
	//= TexCache.Find(tcw.full,tsp.full);
	u64 key = ((u64)tcw.full << 32) | tsp.full;

	TexCacheIter tx = TexCache.find(key);

	if (tx != TexCache.end())
	{
		tf = &tx->second;
	}
	else //create if not existing
	{
		TextureCacheData tfc = { 0 };
		TexCache[key] = tfc;

		tx = TexCache.find(key);
		tf = &tx->second;

		tf->tsp = tsp;
		tf->tcw = tcw;
		tf->Create(false);
	}

	//update if needed
	if (tf->NeedsUpdate())
		tf->Update();

	//update state for opts/stuff
	tf->Lookups++;

	//return gl texture
	rv.height = tf->h;
	rv.width = tf->w;
	rv.pdata = tf->pData;
	rv.textype = tf->tex_type;
	
	
	return rv;
}

void CollectCleanup() {
	vector<u64> list;

	u32 TargetFrame = max((u32)120,FrameCount) - 120;

	for (TexCacheIter i=TexCache.begin();i!=TexCache.end();i++)
	{
		if ( i->second.dirty &&  i->second.dirty < TargetFrame) {
			list.push_back(i->first);
		}

		if (list.size() > 5)
			break;
	}

	for (size_t i=0; i<list.size(); i++) {
		//printf("Deleting %d\n",TexCache[list[i]].texID);
		TexCache[list[i]].Delete();

		TexCache.erase(list[i]);
	}
}

void DoCleanup() {

}
void killtex()
{
	for (TexCacheIter i=TexCache.begin();i!=TexCache.end();i++)
	{
		i->second.Delete();
	}

	TexCache.clear();
}

void rend_text_invl(vram_block* bl)
{
	TextureCacheData* tcd = (TextureCacheData*)bl->userdata;
	tcd->dirty=FrameCount;
	tcd->lock_block=0;

	libCore_vramlock_Unlock_block_wb(bl);
}
