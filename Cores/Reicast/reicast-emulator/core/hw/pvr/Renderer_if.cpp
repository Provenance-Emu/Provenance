#include "Renderer_if.h"
#include "ta.h"
#include "hw/pvr/pvr_mem.h"
#include "rend/TexCache.h"

#include "deps/zlib/zlib.h"

#include "deps/crypto/md5.h"

#if FEAT_HAS_NIXPROF
#include "profiler/profiler.h"
#endif

#define FRAME_MD5 0x1
FILE* fLogFrames;
FILE* fCheckFrames;

/*

	rendv3 ideas
	- multiple backends
	  - ESish
	    - OpenGL ES2.0
	    - OpenGL ES3.0
	    - OpenGL 3.1
	  - OpenGL 4.x
	  - Direct3D 10+ ?
	- correct memory ordering model
	- resource pools
	- threaded ta
	- threaded rendering
	- rtts
	- framebuffers
	- overlays


	PHASES
	- TA submition (memops, dma)

	- TA parsing (defered, rend thread)

	- CORE render (in-order, defered, rend thread)


	submition is done in-order
	- Partial handling of TA values
	- Gotchas with TA contexts

	parsing is done on demand and out-of-order, and might be skipped
	- output is only consumed by renderer

	render is queued on RENDER_START, and won't stall the emulation or might be skipped
	- VRAM integrity is an issue with out-of-order or delayed rendering.
	- selective vram snapshots require ta parsing to complete in order with REND_START / REND_END


	Complications
	- For some apis (gles2, maybe gl31) texture allocation needs to happen on the gpu thread
	- multiple versions of different time snapshots of the same texture are required
	- ta parsing vs frameskip logic


	Texture versioning and staging
	 A memory copy of the texture can be used to temporary store the texture before upload to vram
	 This can be moved to another thread
	 If the api supports async resource creation, we don't need the extra copy
	 Texcache lookups need to be versioned


	rendv2x hacks
	- Only a single pending render. Any renders while still pending are dropped (before parsing)
	- wait and block for parse/texcache. Render is async
*/

u32 VertexCount=0;
u32 FrameCount=1;

Renderer* renderer;
bool renderer_enabled = true;	// Signals the renderer thread to exit

#if !defined(TARGET_NO_THREADS)
cResetEvent rs(false,true);
cResetEvent re(false,true);
#endif

int max_idx,max_mvo,max_op,max_pt,max_tr,max_vtx,max_modt, ovrn;

TA_context* _pvrrc;
void SetREP(TA_context* cntx);

void dump_frame(const char* file, TA_context* ctx, u8* vram, u8* vram_ref = NULL) {
	FILE* fw = fopen(file, "wb");

	//append to it
	fseek(fw, 0, SEEK_END);

	u32 bytes = ctx->tad.End() - ctx->tad.thd_root;

	fwrite("TAFRAME3", 1, 8, fw);

	fwrite(&ctx->rend.isRTT, 1, sizeof(ctx->rend.isRTT), fw);
	fwrite(&ctx->rend.isAutoSort, 1, sizeof(ctx->rend.isAutoSort), fw);
	fwrite(&ctx->rend.fb_X_CLIP.full, 1, sizeof(ctx->rend.fb_X_CLIP.full), fw);
	fwrite(&ctx->rend.fb_Y_CLIP.full, 1, sizeof(ctx->rend.fb_Y_CLIP.full), fw);

	fwrite(ctx->rend.global_param_op.head(), 1, sizeof(PolyParam), fw);
	fwrite(ctx->rend.verts.head(), 1, 4 * sizeof(Vertex), fw);

	u32 t = VRAM_SIZE;
	fwrite(&t, 1, sizeof(t), fw);
	
	u8* compressed;
	uLongf compressed_size;
	u8* src_vram = vram;

	if (vram_ref) {
		src_vram = (u8*)malloc(VRAM_SIZE);

		for (int i = 0; i < VRAM_SIZE; i++) {
			src_vram[i] = vram[i] ^ vram_ref[i];
		}
	}

	compressed = (u8*)malloc(VRAM_SIZE+16);
	compressed_size = VRAM_SIZE;
	verify(compress(compressed, &compressed_size, src_vram, VRAM_SIZE) == Z_OK);
	fwrite(&compressed_size, 1, sizeof(compressed_size), fw);
	fwrite(compressed, 1, compressed_size, fw);
	free(compressed);

	if (src_vram != vram)
		free(src_vram);

	fwrite(&bytes, 1, sizeof(t), fw);
	compressed = (u8*)malloc(bytes + 16);
	compressed_size = VRAM_SIZE;
	verify(compress(compressed, &compressed_size, ctx->tad.thd_root, bytes) == Z_OK);
	fwrite(&compressed_size, 1, sizeof(compressed_size), fw);
	fwrite(compressed, 1, compressed_size, fw);
	free(compressed);

	fclose(fw);
}

TA_context* read_frame(const char* file, u8* vram_ref) {
	
	FILE* fw = fopen(file, "rb");
	char id0[8] = { 0 };
	u32 t = 0;
	u32 t2 = 0;

	fread(id0, 1, 8, fw);

	if (memcmp(id0, "TAFRAME3", 8) != 0) {
		fclose(fw);
		return 0;
	}

	TA_context* ctx = tactx_Alloc();

	ctx->Reset();

	ctx->tad.Clear();

	fread(&ctx->rend.isRTT, 1, sizeof(ctx->rend.isRTT), fw);
	fread(&ctx->rend.isAutoSort, 1, sizeof(ctx->rend.isAutoSort), fw);
	fread(&ctx->rend.fb_X_CLIP.full, 1, sizeof(ctx->rend.fb_X_CLIP.full), fw);
	fread(&ctx->rend.fb_Y_CLIP.full, 1, sizeof(ctx->rend.fb_Y_CLIP.full), fw);

	fread(ctx->rend.global_param_op.head(), 1, sizeof(PolyParam), fw);
	fread(ctx->rend.verts.head(), 1, 4 * sizeof(Vertex), fw);

	fread(&t, 1, sizeof(t), fw);
	verify(t == VRAM_SIZE);

	vram.UnLockRegion(0, VRAM_SIZE);

	fread(&t2, 1, sizeof(t), fw);

	u8* gz_stream = (u8*)malloc(t2);
	fread(gz_stream, 1, t2, fw);
	uncompress(vram.data, (uLongf*)&t, gz_stream, t2);
	free(gz_stream);


	fread(&t, 1, sizeof(t), fw);
	fread(&t2, 1, sizeof(t), fw);
	gz_stream = (u8*)malloc(t2);
	fread(gz_stream, 1, t2, fw);
	uncompress(ctx->tad.thd_data, (uLongf*)&t, gz_stream, t2);
	free(gz_stream);

	ctx->tad.thd_data += t;
	fclose(fw);
    
    return ctx;
}

bool rend_frame(TA_context* ctx, bool draw_osd) {
	bool proc = renderer->Process(ctx);
#if !defined(TARGET_NO_THREADS)
	re.Set();
#endif

	bool do_swp = proc && renderer->Render();

	if (do_swp && draw_osd)
		renderer->DrawOSD();

	return do_swp;
}

bool rend_single_frame()
{
	//wait render start only if no frame pending
	do
	{
#if !defined(TARGET_NO_THREADS)
		rs.Wait();
#endif
		if (!renderer_enabled)
			return false;

		_pvrrc = DequeueRender();
	}
	while (!_pvrrc);
	bool do_swp = rend_frame(_pvrrc, true);

	//clear up & free data ..
	FinishRender(_pvrrc);
	_pvrrc=0;

	return do_swp;
}

void* rend_thread(void* p)
{
#if FEAT_HAS_NIXPROF
	install_prof_handler(1);
#endif

	#if SET_AFNT
	cpu_set_t mask;

	/* CPU_ZERO initializes all the bits in the mask to zero. */

	CPU_ZERO( &mask );



	/* CPU_SET sets only the bit corresponding to cpu. */

	CPU_SET( 1, &mask );



	/* sched_setaffinity returns 0 in success */

	if( sched_setaffinity( 0, sizeof(mask), &mask ) == -1 )

	{

		printf("WARNING: Could not set CPU Affinity, continuing...\n");

	}
	#endif



	if (!renderer->Init())
		die("rend->init() failed\n");

	//we don't know if this is true, so let's not speculate here
	//renderer->Resize(640, 480);

	while (renderer_enabled)
	{
		if (rend_single_frame())
			renderer->Present();
	}

	return NULL;
}

#if !defined(TARGET_NO_THREADS)
cThread rthd(rend_thread,0);
#endif

bool pend_rend = false;

void rend_resize(int width, int height) {
	renderer->Resize(width, height);
}


void rend_start_render()
{
	pend_rend = false;
	bool is_rtt=(FB_W_SOF1& 0x1000000)!=0;
	TA_context* ctx = tactx_Pop(CORE_CURRENT_CTX);

	SetREP(ctx);

	if (ctx)
	{
		if (fLogFrames || fCheckFrames) {
			MD5Context md5;
			u8 digest[16];

			MD5Init(&md5);
			MD5Update(&md5, ctx->tad.thd_root, ctx->tad.End() - ctx->tad.thd_root);
			MD5Final(digest, &md5);

			if (fLogFrames) {
				fputc(FRAME_MD5, fLogFrames);
				fwrite(digest, 1, 16, fLogFrames);
				fflush(fLogFrames);
			}

			if (fCheckFrames) {
				u8 digest2[16];
				int ch = fgetc(fCheckFrames);

				if (ch == EOF) {
					printf("Testing: TA Hash log matches, exiting\n");
					exit(1);
				}
				
				verify(ch == FRAME_MD5);

				fread(digest2, 1, 16, fCheckFrames);

				verify(memcmp(digest, digest2, 16) == 0);

				
			}

			/*
			u8* dig = digest;
			printf("FRAME: %02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X-%02X\n",
				digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
				digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]
				);
			*/
		}

		if (!ctx->rend.Overrun)
		{
			//printf("REP: %.2f ms\n",render_end_pending_cycles/200000.0);
			FillBGP(ctx);
			
			ctx->rend.isRTT=is_rtt;
			ctx->rend.isAutoSort = UsingAutoSort();

			ctx->rend.fb_X_CLIP=FB_X_CLIP;
			ctx->rend.fb_Y_CLIP=FB_Y_CLIP;
			
			max_idx=max(max_idx,ctx->rend.idx.used());
			max_vtx=max(max_vtx,ctx->rend.verts.used());
			max_op=max(max_op,ctx->rend.global_param_op.used());
			max_pt=max(max_pt,ctx->rend.global_param_pt.used());
			max_tr=max(max_tr,ctx->rend.global_param_tr.used());
			
			max_mvo=max(max_mvo,ctx->rend.global_param_mvo.used());
			max_modt=max(max_modt,ctx->rend.modtrig.used());

#if HOST_OS==OS_WINDOWS && 0
			printf("max: idx: %d, vtx: %d, op: %d, pt: %d, tr: %d, mvo: %d, modt: %d, ov: %d\n", max_idx, max_vtx, max_op, max_pt, max_tr, max_mvo, max_modt, ovrn);
#endif
			if (QueueRender(ctx))
			{
				palette_update();
#if !defined(TARGET_NO_THREADS)
				rs.Set();
#else
				rend_single_frame();
#endif
				pend_rend = true;
			}
		}
		else
		{
			ovrn++;
			printf("WARNING: Rendering context is overrun (%d), aborting frame\n",ovrn);
			tactx_Recycle(ctx);
		}
	}
}


void rend_end_render()
{
#if 1 //also disabled the printf, it takes quite some time ...
	#if HOST_OS!=OS_WINDOWS && !(defined(_ANDROID) || defined(TARGET_PANDORA))
		//too much console spam.
		//TODO: how about a counter?
		//if (!re.state) printf("Render > Extended time slice ...\n");
	#endif
#endif

	if (pend_rend) {
#if !defined(TARGET_NO_THREADS)
		re.Wait();
#else
		renderer->Present();
#endif
	}
}

/*
void rend_end_wait()
{
	#if HOST_OS!=OS_WINDOWS && !defined(_ANDROID)
	//	if (!re.state) printf("Render End: Waiting ...\n");
	#endif
	re.Wait();
	pvrrc.InUse=false;
}
*/

bool rend_init()
{
	if ((fLogFrames = fopen(settings.pvr.HashLogFile.c_str(), "wb"))) {
		printf("Saving frame hashes to: '%s'\n", settings.pvr.HashLogFile.c_str());
	}

	if ((fCheckFrames = fopen(settings.pvr.HashCheckFile.c_str(), "rb"))) {
		printf("Comparing frame hashes against: '%s'\n", settings.pvr.HashCheckFile.c_str());
	}

#ifdef NO_REND
	renderer	 = rend_norend();
#else


	switch (settings.pvr.rend) {
		default:
		case 0:
			renderer = rend_GLES2();
			break;
#if HOST_OS == OS_WINDOWS
		case 1:
			renderer = rend_D3D11();
			break;
#endif

#if FEAT_HAS_SOFTREND
		case 2:
			renderer = rend_softrend();
			break;
#endif
	}

#endif

#if !defined(_ANDROID) && HOST_OS != OS_DARWIN
  #if !defined(TARGET_NO_THREADS)
    rthd.Start();
  #else
    if (!renderer->Init()) die("rend->init() failed\n");

    renderer->Resize(640, 480);
  #endif
#endif

#if SET_AFNT
	cpu_set_t mask;



	/* CPU_ZERO initializes all the bits in the mask to zero. */

	CPU_ZERO( &mask );



	/* CPU_SET sets only the bit corresponding to cpu. */

	CPU_SET( 0, &mask );



	/* sched_setaffinity returns 0 in success */

	if( sched_setaffinity( 0, sizeof(mask), &mask ) == -1 )

	{

		printf("WARNING: Could not set CPU Affinity, continuing...\n");

	}
#endif

	return true;
}

void rend_term()
{
	renderer_enabled = false;
#if !defined(TARGET_NO_THREADS)
	rs.Set();
#endif

	if (fCheckFrames)
		fclose(fCheckFrames);

	if (fLogFrames)
		fclose(fLogFrames);

#if !defined(TARGET_NO_THREADS)
	rthd.WaitToEnd();
#endif
}

void rend_vblank()
{
	os_DoEvents();
}
