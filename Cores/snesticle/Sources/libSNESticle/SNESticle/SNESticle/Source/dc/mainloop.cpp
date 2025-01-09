
#include <kos.h>
#include <arch/cache.h>
#include <stdlib.h>
#include <dc/sound/snd_driver.h>
#include <dc/sound/snd_stream2.h>
#include "types.h"
#include "mainloop.h"
#include "console.h"
#include "input.h"
#include "snes.h"
#include "memsurface.h"
//#include "nespal.h"
//#include "nesspumix.h"
#include "file.h"
#include "prof.h"
#include "font.h"
#include "texture.h"
#include "poly.h"
#include "bmpfile.h"

#define CODE_DEBUG TRUE

//#define MAINLOOP_SAMPLERATE 60000
#define MAINLOOP_SAMPLERATE 44100

char *_VersionStr="SNESticleDC v0.0.1";

/*
#if CODE_DEBUG
#define MENU_STARTDIR "/"
#else
#define MENU_STARTDIR "/cd/"
#endif

#define MENU_DIR_MAXENTRIES 1512
#define MENU_ENTRY_MAXCHARS 64


enum MenuEntryTypeE
{
	MENU_ENTRYTYPE_ROM,
	MENU_ENTRYTYPE_DIR,
	MENU_ENTRYTYPE_OTHER,

	MENU_ENTRYTYPE_NUM,
};

struct MenuDirEntryT
{
	Char name[MENU_ENTRY_MAXCHARS];
	Int32 size;
	MenuEntryTypeE eType;
};

static void _MenuInit();
static Bool _MenuSetDir(Char *pDir);
static void _MenuDraw();
static void _MenuProcess(Uint32 trigger);
static void _MenuEnable(Bool bEnable);

static void _MainLoopInputProcess(cont_cond_t *cond);
*/

extern uint8 romdisk[];

static SnesSystem *_pSnes;
static SnesRom	  *_pRom;
static Char _RomName[256];

Uint8 kbd_matrix[256];
static CMemSurface _fbTexture[2];
static Uint32 _iFrame=0;
static Uint16 *_pFrame=NULL;


//static CNesSPUMixer *_pSPUMixer;

Char *_pRomFile = 
"/rd/mario.smc";

//"/pc/home/iaddis/mario.nes";
//"/pc/cygdrive/c/nesrom/Super Mario Bros 2.nes";
//"/pc/cygdrive/c/nesrom/Super Mario Bros 3.nes";
//"/pc/cygdrive/c/nesrom/wall.nes";
//"/pc/cygdrive/c/nesrom/Mike Tyson's Punchout.nes";
//"/pc/cygdrive/c/nesrom/Legend of Zelda, The.nes";
//"/pc/cygdrive/c/nesrom/Rad Racer.nes";
//"/pc/cygdrive/c/nesrom/Donkey Kong Classics.nes";
//"/pc/cygdrive/c/nesrom/Megaman 2.nes";
//"/pc/cygdrive/c/nesrom/Goonies2.nes";
//"/pc/cygdrive/c/nesrom/Wizards & Warriors.nes";
//"/pc/cygdrive/c/nesrom/contra.nes";
//"/pc/cygdrive/c/nesrom/RC Pro-am.nes";
//"/pc/cygdrive/c/nesrom/RC Pro-am 2.nes";
//"/pc/cygdrive/c/nesrom/Gauntlet 2.nes";

//"/pc/cygdrive/c/nesrom/castlevania 2 - Simon's Quest.nes";
//"/cd/super_mario_bros.nes";


static Char _MainLoop_ModalStr[256];
static Int32 _MainLoop_ModalCount=0;

void MainLoopModalPrintf(Int32 Time, Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	vsprintf(_MainLoop_ModalStr, pFormat, argptr);
	va_end(argptr);

	_MainLoop_ModalCount = Time;
}


static snd_stream _Stream;

static Bool _bMenu = FALSE;
static Bool _Menu_iDoSave = 0;

//#include "nes_apu.h"
   
static Int16 _Data[8192];
static Uint32 _nData;



static void _StreamCallback(snd_stream *stream, int nSamples)
{
//	nSamples = nSamples / 736 * 736;

	if (nSamples > sizeof(_Data)/2)
	{
		nSamples = sizeof(_Data)/2;
	}

	memset(_Data, 0, nSamples * 2);
#if 0
	if (!_bMenu && _pRom->IsLoaded())
	{
		PROF_ENTER("NesSPUMix");
		_pSPUMixer->SetBuffer((Int16 *)_Data, nSamples, MAINLOOP_SAMPLERATE);
		_pNes->GetSPU()->Process(_pSPUMixer);
		PROF_LEAVE("NesSPUMix");
	} else
	{
		Int32 iSample; 
//	printf("%d\n", nSamples);
		for (iSample=0; iSample < nSamples; iSample++)
			_Data[iSample] = _prev_sample;
	}
#endif
	sndstream_write(stream, _Data, nSamples);
} 


static void _MainLoopGetName(Char *pName, Char *pPath)
{
	Char Path[256];
	Int32 i = strlen(pPath);

	strcpy(Path, pPath);

	while (i > 0 && Path[i]!='.' && Path[i]!='/')
	{
		i--;
	}

	if (Path[i]=='.')
	{
		Path[i]= 0;
	}	

	while (i > 0 &&  Path[i]!='/')
	{
		i--;
	}

	if (Path[i]=='/')
	{
		i++;
	}

	strcpy(pName, Path + i);
}


static Bool _MainLoopHasBRAM()
{
	return FALSE;
//	return (_pRom->IsLoaded() && _pRom->m_bBattery);
}

static Bool _MainLoopSaveBRAM()
{
	/*
	if (_pRom->IsLoaded() && _pRom->m_bBattery)
	{
		Char Path[256];
		CMemSpace *pBRAM;

		pBRAM = _pNes->GetBRAM();
		sprintf(Path, "/vmu/a1/%s", _RomName);
		printf("Saving BRAM to %s\n", Path);

		fs_unlink(Path);
		if (FileWriteMem(Path, pBRAM->GetMem(), NES_BRAMSIZE))
		{
			Uint8 data[NES_BRAMSIZE];

			// verify that write happened successfully
			if (FileReadMem(Path, data, NES_BRAMSIZE) && !memcmp(data, pBRAM->GetMem(),sizeof(data)))
			{
				ConPrint("BRAM saved: %s\n", Path);
				return TRUE;
			} 
		} 
	}*/

	return FALSE;
}

static void _MainLoopLoadBRAM()
{
	/*
	if (_pRom->IsLoaded() && _pRom->m_bBattery)
	{
		Char Path[256];
		CMemSpace *pBRAM;

		pBRAM = _pNes->GetBRAM();
		sprintf(Path, "/vmu/a1/%s", _RomName);
		if (FileReadMem(Path, pBRAM->GetMem(), NES_BRAMSIZE))
		{
			ConPrint("BRAM loaded: %s\n", Path);
		}
	}
	*/
}


static Bool _MainLoopLoadRom(Char *pRomFile)
{
	// unload old rom
	_pSnes->SetRom(NULL);
	_pRom->Unload();

	_fbTexture[0].Clear();
	_fbTexture[1].Clear();

	if (pRomFile)
	{
		if (!_pRom->LoadRom(pRomFile))
		{
			MainLoopModalPrintf(60*1, "ERROR: Cannot load rom %s\n", pRomFile);
			return FALSE;
		}

		_MainLoopGetName(_RomName, pRomFile);
		printf("Name: '%s'\n", _RomName);

		_pSnes->SetRom(_pRom);
		_pSnes->Reset();
        printf("SNES Reset\n");

		return TRUE;
	}

	return FALSE;
}


/* Main program: init and loop drawing polygons */

static TextureT _frametex[2];
static Uint32 _iframetex=0;

pvr_init_params_t pvr_params = {
	{ PVR_BINSIZE_32, PVR_BINSIZE_8, PVR_BINSIZE_16, PVR_BINSIZE_8, PVR_BINSIZE_16 },
	512 * 1024
};


static CMemSurface _test;
static TextureT _testtex;

Bool MainLoopInit()
{
	int i;

//    printf("%04X\n", *(Uint32 *)0xFF00001C);
//    printf("%04X\n", *(Uint32 *)0x1F00001C);

	ProfInit(65536);

	fs_romdisk_init(romdisk);

	InputInit();									    

	kbd_set_queue(0);


	// Set the video mode 

//	vid_set_mode_ex(&_VidMode);
	vid_set_mode(DM_640x240_NTSC, PM_RGB888);

//	vid_set_mode(DM_256x240_NTSC, PM_RGB565);
//	vid_set_mode(DM_320x240_NTSC, PM_RGB888);
//	vid_set_mode(DM_320x240_NTSC, PM_RGB565);
//	vid_set_mode(DM_640x480_NTSC_IL, PM_RGB565);

	pvr_init(&pvr_params);

	PolyInit();
	FontInit();

	// allocate textures
    
    
	TextureNew(&_frametex[0], 512, 256, TEX_FORMAT_ARGB1555);
	TextureNew(&_frametex[1], 512, 256, TEX_FORMAT_ARGB1555);
	_fbTexture[0].Set((Uint8 *)TextureGetData(&_frametex[0]), _frametex[0].uWidth, _frametex[0].uHeight, _frametex[0].uPitch, PixelFormatGetByEnum(PIXELFORMAT_BGR555));
	_fbTexture[1].Set((Uint8 *)TextureGetData(&_frametex[1]), _frametex[1].uWidth, _frametex[1].uHeight, _frametex[1].uPitch, PixelFormatGetByEnum(PIXELFORMAT_BGR555));
    
    
    /*
	TextureNew(&_frametex[0], 256, 256, TEX_FORMAT_RGB565);
	TextureNew(&_frametex[1], 256, 256, TEX_FORMAT_RGB565);
	_fbTexture[0].Set((Uint8 *)TextureGetData(&_frametex[0]), _frametex[0].uWidth, _frametex[0].uHeight, _frametex[0].uPitch, PixelFormatGetByEnum(PIXELFORMAT_BGRA8));
	_fbTexture[1].Set((Uint8 *)TextureGetData(&_frametex[1]), _frametex[1].uWidth, _frametex[1].uHeight, _frametex[1].uPitch, PixelFormatGetByEnum(PIXELFORMAT_BGRA8));
    */

	ConDebug("MainLoop - Init\n");
	 
	// create nes machine
	_pSnes = new SnesSystem();
	_pSnes->Reset();

//	_pSPUMixer = new CNesSPUMixer();
	_pRom = new SnesRom();

	/*
	snd_driver_init();				    
	sndstream_new(&_Stream, 0, (MAINLOOP_SAMPLERATE / 60) * 4, 0);
	sndstream_set_callback(&_Stream, _StreamCallback);
	*/

	// init menu
//	_MenuInit();

	_bMenu = FALSE;

	// load rom
	_MainLoopLoadRom(_pRomFile);
//	_bMenu = _pRom->IsLoaded() ? FALSE : TRUE;

//  	sndstream_start(&_Stream, MAINLOOP_SAMPLERATE, 240, 128);

	return TRUE;
}


Uint16 _MainLoopInput(cont_cond_t *cond)
{
	Uint16 pad = 0;

	if (!(cond->buttons & CONT_DPAD_LEFT) ) pad|= SNESIO_JOY_LEFT;
	if (!(cond->buttons & CONT_DPAD_RIGHT)) pad|= SNESIO_JOY_RIGHT;
	if (!(cond->buttons & CONT_DPAD_UP)   ) pad|= SNESIO_JOY_UP;
	if (!(cond->buttons & CONT_DPAD_DOWN) ) pad|= SNESIO_JOY_DOWN;
	if (!(cond->buttons & CONT_A)    ) pad|= SNESIO_JOY_A;
	if (!(cond->buttons & CONT_X)    ) pad|= SNESIO_JOY_X;
	if (!(cond->buttons & CONT_Y)    ) pad|= SNESIO_JOY_Y;
	if (!(cond->buttons & CONT_B)    ) pad|= SNESIO_JOY_B;
	if (!(cond->buttons & CONT_START)) pad|= SNESIO_JOY_START;
	return pad;
}


#define CONT_LTRIG (1<<12)
#define CONT_RTRIG (1<<13)


Uint32 _Ticks=0;
Uint32 _Frames=0;
Int32 __y=0;
Bool MainLoopProcess()
{
	SnesIOInputT Input;
	cont_cond_t cond[4];
	int x,y;
	Int32 iCond;

	PROF_ENTER("Frame");

	InputPoll();

	memset(&Input, 0, sizeof(Input));

	// read controller
	for (iCond=0; iCond < 4; iCond++)
	{
		int result=-1;
//		if (iCond!=2)
		result = cont_get_cond(maple_addr(iCond,0), &cond[iCond]);
		if (!result)
		{	
			if (cond[iCond].ltrig > 0x80) 
			{
				cond[iCond].buttons&=~(CONT_LTRIG);
			}

			if (cond[iCond].rtrig > 0x80) 
			{
				cond[iCond].buttons&=~(CONT_RTRIG);
			}
					   
			Input.uPad[iCond] = _MainLoopInput(&cond[iCond]);

  //			if (iCond==2) printf("%X\n", cond[iCond].buttons);
		}
//		if (iCond==2) printf("%d\n", result);

	}

//	if (_Menu_iDoSave == 0 && _MainLoop_ModalCount==0)
//	_MainLoopInputProcess(&cond[0]);

	// read keyboard
	{
		kbd_state_t *kbdstate;
		kbdstate = kbd_get_state(3, 0);
		if (kbdstate)
		{
			memcpy(kbd_matrix, kbdstate->matrix, sizeof(kbd_matrix));
		}
		else
		{
			memset(kbd_matrix, 0, sizeof(kbd_matrix));
		}
	}

    if (kbd_matrix[KBD_KEY_P])
    {
    	ProfStartProfile(1);
    }


/*
  	x = timer_count(TMU2) * 16;
	_MainLoopUpdateLCD();
  	y = timer_count(TMU2) * 16;
  */

	{
		pvr_poly_hdr_t	poly;

		pvr_scene_begin();


		pvr_list_begin(PVR_LIST_OP_POLY);
		PolyMode(TA_OPAQUE);

		{
			Float32 fDestColor = (_bMenu || _MainLoop_ModalCount) ? 0.10f : 0.80f;
			static Float32 fColor=0.0f;
			Float32 dx = 0.0f;
			Float32 dy = -6.0f;

			if (fColor < fDestColor) 
			{
				fColor+=0.06f;
				if (fColor > fDestColor) 
				{
					fColor = fDestColor;
				}
			} 

			if (fColor > fDestColor) 
			{
				fColor-=0.06f;
				if (fColor < fDestColor) 
				{
					fColor = fDestColor;
				}
			}

			PolyTexture(&_frametex[_iframetex]);
			PolyColor4f(fColor, fColor, fColor, 1.0f);

			PolyUV(0,0, 512, 240);

//			PolyUV(0,0, 256, 240);
			PolyRect(dx, dy, 640.0f, 240.0f);
//			PolyRect(0, 0, 200.0f, 100.0f);
//			PolySprite(dx, dy, 640.0f, 240.0f);
//			PolySprite(160, 50, 320, 100);

			  /*
			pvr_userclip_hdr_t userclip;
			pvr_userclip_compile(&userclip, 0, 0, 50, 80);
//			userclip.xmin = 0.0f;
//			userclip.ymin = 0.0f;
//			userclip.xmax = 100.0f;
//			userclip.ymax = 80.0f;
			userclip.unused[0] = 1234;
			userclip.unused[1] = 1234;
			userclip.unused[2] = 1234;
			userclip.xmin = 0 | (16<<8);
			userclip.ymin = 0;
			userclip.xmax = 20;
			userclip.ymax = 8; // + (__y >> 4); __y++;
			pvr_prim(&userclip, sizeof(userclip));
			*/
		}

		/* End of opaque list */
		pvr_list_finish();

		pvr_list_begin(PVR_LIST_TR_POLY);
		PolyMode(TA_TRANSLUCENT);

//		PolyTexture(&FontGetBios()->Texture);

//		PolyUV(0, 0, 108, 54);
//		PolyRect(30.0f, 30.0f, 108.0f, 54.0f);

		#if CODE_DEBUG
		FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
		FontPrintf(600, 200, "%d", 60 * 8/ _Ticks);
		#endif

//		FontPrintf(32,32, "%d", x-y);

		if (_MainLoop_ModalCount > 0)
		{
			FontSelect(1);
			FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
			FontPrintf(140,100, _MainLoop_ModalStr);

			_MainLoop_ModalCount--;
		} else
		{
			if (_bMenu)
			{
//				_MenuDraw();
			}
		}

		pvr_list_finish();

		/* Finish the frame */
		pvr_scene_finish();

		if (!_bMenu && _MainLoop_ModalCount==0)
		{
			if (_pSnes && _pRom->IsLoaded())
			{
				PROF_ENTER("NesExecuteFrame");
  				_pSnes->ExecuteFrame(&Input, &_fbTexture[_iframetex]);
//        printf("SNES EXEC frame %d\n", _pSnes->GetFrame());

				PROF_LEAVE("NesExecuteFrame");

				_iframetex^=1;
			} 
		}
	}



	PROF_ENTER("pvr_wait_ready");
// 	vid_waitvbl();
 	pvr_wait_ready();
	PROF_LEAVE("pvr_wait_ready");

	#if CODE_DEBUG
	{
		static Uint32 lastvbl=0;
		Uint32 nvbl;
		if (!(_Frames & 7))
		{
			nvbl =	pvr_get_vblank_count();
			_Ticks = nvbl - lastvbl;
			lastvbl = nvbl;
		}
	}
	#endif

	/*
	if (_Menu_iDoSave > 0)
	{
		_Menu_iDoSave--;

		if (_Menu_iDoSave == 0)
		{
			if (_MainLoopHasBRAM())
			{
				if (_MainLoopSaveBRAM())
				{
					MainLoopModalPrintf(60, "BRAM written successfully.\n");
				} else
				{
					MainLoopModalPrintf(60 * 1 + 30, "Error writing BRAM to VMU\n");
				}
			}
		}
	}
	*/

   
//	c = timer_count(TMU2) * 16;
	/*
	PROF_ENTER("SndStreamPoll");
  	sndstream_poll(&_Stream);
	PROF_LEAVE("SndStreamPoll");
	*/
//	b = timer_count(TMU2) * 16;

//	ConDebug("MainLoop - Init 3\n");

/*
	if ((a-b) > 3500000)
	{
		_bDropFrame=TRUE;
	}
	else
	{
		_bDropFrame = FALSE;
	}*/
  
//	if (cond[0].rtrig>0x80) printf("%d %d\n", a-b, c-a);
//	if (cond[0].rtrig>0x80) printf("%d %d %d\n", a-c, c-b, q-p);
//	if (cond[0].rtrig>0x80) printf("%d\n", c-b);

	PROF_LEAVE("Frame");

	ProfProcess();

	_Frames++;

	if (kbd_matrix[KBD_KEY_ESCAPE]) return FALSE;
	return TRUE;
}

void MainLoopShutdown()
{
//	sndstream_stop(&_Stream);

	if (_pSnes && _pRom)
	{
//		_MainLoopSaveBRAM();
		_pSnes->SetRom(NULL);
		_pRom->Unload();
	}

	ConDebug("MainLoop - Shutdown");

//	snd_driver_shutdown();

	InputShutdown();
	FontShutdown();

	pvr_shutdown();

	ProfShutdown();
}




