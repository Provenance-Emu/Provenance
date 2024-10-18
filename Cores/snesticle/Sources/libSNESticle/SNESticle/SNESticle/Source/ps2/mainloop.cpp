
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fileio.h>
#include <iopheap.h>
#include <libpad.h>
#include "libxpad.h"
#include "libxmtap.h"
#include <libmc.h>
#include <kernel.h>
#include "types.h"
#include "vram.h"
#include "mainloop.h"
#include "console.h"
#include "input.h"
#include "snes.h"
#include "rendersurface.h"
#include "file.h"
#include "dataio.h"
#include "prof.h"
#include "bmpfile.h"
#include "font.h"
#include "poly.h"
#include "texture.h"
#include "mixbuffer.h"
#include "wavfile.h"
#include "snstate.h"
#include "sjpcmbuffer.h"
#include "memcard.h"
#include "pathext.h"
#include "snppucolor.h"
#include "version.h"
#include "emumovie.h"
extern "C" {
#include "cd.h"
#include "ps2dma.h"
#include "sncpu_c.h"
#include "snspc_c.h"
};

#include "nespal.h"
#include "nes.h"
#include "nesstate.h"

#include <sifrpc.h>
#include <loadfile.h>

extern "C" {
#include "ps2ip.h"
#include "netplay_ee.h"
#include "mcsave_ee.h"
};

#include "zlib.h"
extern "C" {
#include "hw.h"
#include "gs.h"
#include "gpfifo.h"
#include "gpprim.h"
};

extern "C" {
#include "titleman.h"
};

extern "C" {
#include "sjpcm.h"
#include "cdvd_rpc.h"
};

extern "C" Int32 SNCPUExecute_ASM(SNCpuT *pCpu);


#define MAINLOOP_MEMCARD (CODE_RELEASE || 0)

#define MAINLOOP_NETPORT (6113)

#if CODE_RELEASE
#define MENU_STARTDIR ""
#define MAINLOOP_STATEPATH "host0:"
#else
#define MENU_STARTDIR "cdfs:/"
#define MAINLOOP_STATEPATH "host0:/cygdrive/d/emu/"
#endif

#define MAINLOOP_SNESSTATEDEBUG (CODE_DEBUG && 0)
#define MAINLOOP_NESSTATEDEBUG (CODE_DEBUG && FALSE)
#define MAINLOOP_HISTORY (CODE_DEBUG && 0)
#define MAINLOOP_MAXSRAMSIZE (64 * 1024)

enum
{					   
	MAINLOOP_ENTRYTYPE_GZ	   ,
	MAINLOOP_ENTRYTYPE_ZIP	   ,
	MAINLOOP_ENTRYTYPE_NESROM  ,
	MAINLOOP_ENTRYTYPE_NESFDSDISK  ,
	MAINLOOP_ENTRYTYPE_NESFDSBIOS,
	MAINLOOP_ENTRYTYPE_SNESROM ,
	MAINLOOP_ENTRYTYPE_SNESPALETTE ,

	MAINLOOP_ENTRYTYPE_NUM 
};

#include "uiBrowser.h"
#include "uiNetwork.h"
#include "uiMenu.h"
#include "uiLog.h"

static class CBrowserScreen *_MainLoop_pBrowserScreen;
static class CNetworkScreen *_MainLoop_pNetworkScreen;
static class CMenuScreen *_MainLoop_pMenuScreen;
static class CLogScreen *_MainLoop_pLogScreen;
static CScreen *_MainLoop_pScreen = NULL;

static SnesSystem *_pSnes;
static SnesRom	  *_pSnesRom;
static NesSystem  *_pNes;
static NesRom	  *_pNesRom;
static NesFDSBios  *_pNesFDSBios;
static NesDisk	  *_pNesFDSDisk;
static Int32 _MainLoop_iDisk=0;
static Bool _MainLoop_bDiskInserted=FALSE;
static Char _RomName[256];

#if MAINLOOP_MEMCARD
static Char _SramPath[256] = "mc0:/SNESticle";
static Char  _MainLoop_SaveTitle[] = "SNESticle\nSNESticle";
#else
static Char _SramPath[256] = "host0:/cygdrive/d/emu/";
#endif

static CEmuSystem  *_pSystem;

static CRenderSurface *_fbTexture[2];
static Uint32 _iframetex=0;

static TextureT _OutTex;
static CWavFile _WavFile;

static Uint8 _RomData[4 * 1024 * 1024 + 1024] __attribute__((aligned(64))) __attribute__ ((section (".bss")));

static SnesStateT		_SnesState;
static NesStateT		_NesState;

static CEmuMovieClip *  s_pMovieClip;


static Uint32 _MainLoop_SRAMChecksum;
static Uint32 _MainLoop_SaveCounter = 0;
static Uint32 _MainLoop_AutoSaveTime = 8 * 60;
static Bool _MainLoop_SRAMUpdated = FALSE;
static Bool _bStateSaved = FALSE;
static Float32 _MainLoop_fOutputIntensity = 0.8f;


static Uint8 _MainLoop_GfxPipe[0x40000] _ALIGN(128) __attribute__ ((section (".bss")));

//static SJPCMMixBuffer _SJPCMMix(32000, TRUE) _ALIGN(16);
static SJPCMMixBuffer *_SJPCMMix;

//static Char * _pSnesWavFileName = "host0:d:/snesps2.wav";

static Char *_pRomFile = 
//"host:c:/emu/snesrom/mario.smc";
NULL
//"cdfs:\\USA\\SUPER~_U.SMC";
//"cdfs:\\ROMS\\Super Mario World.smc";

// "host:c:/emu/Zombies Ate My Neighbors (U) [!].smc";

// "host:c:/emu/Contra 3.smc";
//"host:c:/emu/Castlevania 4.smc";
//"host:c:/emu/Super Bomberman (U).smc";
//"host:c:/emu/Legend of Zelda, The (U).smc";
//"host:c:/emu/Final Fight (U).smc";

//"cdfs:\\ROMS\\mario.smc";
;


static void _MenuDraw();
static void _MenuEnable(Bool bEnable);
static void * _MainLoopNetCallback(NetPlayCallbackE eCallback, char *data, int size);
void MainLoopRender();

static void _MainLoopInputProcess(Uint32);

#if MAINLOOP_HISTORY
static void  _MainLoopResetHistory();
#endif
static void _MainLoopResetInputChecksums();

static Bool _bMenu = FALSE;

static Char _MainLoop_ModalStr[256];
static Int32 _MainLoop_ModalCount=0;

static Char _MainLoop_StatusStr[256];
static Int32 _MainLoop_StatusCount=0;

static Bool _MainLoop_BlackScreen = FALSE;
static Uint32 _MainLoop_uDebugDisplay = 0;

void MainLoopModalPrintf(Int32 Time, Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	vsprintf(_MainLoop_ModalStr, pFormat, argptr);
	va_end(argptr);

	_MainLoop_ModalCount = Time;

	// render frame to display text
	while (Time > 0)
	{
		MainLoopRender();
		Time--;
	}
}

void MainLoopStatusPrintf(Int32 Time, Char *pFormat, ...)
{
	va_list argptr;
	va_start(argptr,pFormat);
	vsprintf(_MainLoop_StatusStr, pFormat, argptr);
	va_end(argptr);

	_MainLoop_StatusCount = Time;
}

void ScrPrintf(Char *pFormat, ...)
{
	va_list argptr;
	char str[256];

	va_start(argptr,pFormat);
	vsprintf(str, pFormat, argptr);
	va_end(argptr);

//	scr_printf("%s", str);
	if (_MainLoop_pLogScreen)
		_MainLoop_pLogScreen->AddMessage(str);

	// render frame to display text
	MainLoopRender();
}

static Uint32 _PathCalcHash(char *pStr)
{
	Uint32 hash = 0;
	while (*pStr)
	{
		hash*=33;
		hash += *pStr;
		pStr++;
	}
	return hash;
}

void PathTruncFileName(Char *pOut, Char *pStr, Int32 nMaxChars)
{
	Uint32 hash;

	hash = _PathCalcHash(pStr);

	// copy string up to maxchars length
	while (*pStr && nMaxChars > 0)
	{
		*pOut++ = *pStr++;
		nMaxChars--;
	}

	// terminate
	*pOut = 0;

	if (nMaxChars <= 0)
	{
		// mangle end of name
		sprintf(pOut - 3, "%03d", hash % 1000);
	}
}

int PathGetMaxFileNameLength(const char *pPath)
{
	if (pPath[0] == 'm' && pPath[1]=='c')
	{
		return 32;
	}
	return 256;
}


static void _MainLoopGetName(Char *pName, Char *pPath)
{
	char *pFileName;

	pFileName = strrchr(pPath, '/');
	if (pFileName==NULL)
	{
		pFileName = pPath;
	} else
	{
		// skip /
		pFileName = pFileName + 1;
	}
	strcpy(pName, pFileName);
}

static Uint32 _CalcChecksum(Uint32 *pData, Uint32 nWords)
{
    Uint32 uSum =0;

    while (nWords > 0)
    {
        uSum+= pData[0];

        pData++;
        nWords--;
    }

    return uSum;
}

                        
static Bool _MainLoopHasSRAM()
{
	return  _pSystem ? (_pSystem->GetSRAMBytes() > 0) : FALSE;
}


static Bool _MainLoopSaveSRAM(Bool bSync)
{
    Int32 nSramBytes = _pSystem ? _pSystem->GetSRAMBytes() : 0;

	if (nSramBytes > 0)
	{
		Char Path[256];
		Char SaveName[256];

		Uint8 *pSRAM;
		pSRAM = _pSystem->GetSRAMData();

		PathTruncFileName(SaveName, _RomName, PathGetMaxFileNameLength(_SramPath) - 4);

        sprintf(Path, "%s/%s.%s", _SramPath, SaveName, _pSystem->GetString(EMUSYS_STRING_SRAMEXT) );

		MCSave_WriteSync(TRUE, NULL);
		MCSave_Write((char *)Path, (char *)pSRAM, nSramBytes);

		if (bSync)
		{
			int result;
			MCSave_WriteSync(TRUE, &result);
			return result ? TRUE : FALSE;
		}
		return TRUE;
	}

	return FALSE;
}

static void _MainLoopLoadSRAM()
{
    Int32 nSramBytes = _pSystem ? _pSystem->GetSRAMBytes() : 0;

	if (nSramBytes > 0)
	{
		Char Path[256];
		Char SaveName[256];

		Uint8 *pSRAM;
		pSRAM = _pSystem->GetSRAMData();

		PathTruncFileName(SaveName, _RomName, PathGetMaxFileNameLength(_SramPath) - 4);

        sprintf(Path, "%s/%s.%s", _SramPath, SaveName, _pSystem->GetString(EMUSYS_STRING_SRAMEXT));
		if (MemCardReadFile(Path, pSRAM, nSramBytes))
		{
            _MainLoop_SRAMChecksum = _CalcChecksum((Uint32 *)pSRAM, nSramBytes / 4);

			ConPrint("SRAM loaded: %s\n", Path);
		}

        _MainLoop_SRAMUpdated = FALSE;
	}

	_MainLoop_SaveCounter = 0;
    _bStateSaved = FALSE;
}



static Bool _MainLoopCheckSRAM()
{
    Int32 nSramBytes = _pSystem ? _pSystem->GetSRAMBytes() : 0;

	if (nSramBytes > 0)
	{
        Uint8 *pSRAM = _pSystem->GetSRAMData();
        Uint32 uChecksum;

        PROF_ENTER("_MainLoopCheckSRAM");
        uChecksum = _CalcChecksum((Uint32 *)pSRAM, nSramBytes / 4);

        if (_MainLoop_SRAMChecksum!=uChecksum)
        {
            #if CODE_DEBUG
            printf("SRAM changed!\n");
            #endif

            _MainLoop_SRAMUpdated = TRUE;
            _MainLoop_SaveCounter = _MainLoop_AutoSaveTime;
            _MainLoop_SRAMChecksum=uChecksum;
        }

        if (_MainLoop_SaveCounter > 0)
        {
            _MainLoop_SaveCounter--;
            if (_MainLoop_SaveCounter==0)
            {
                _MainLoopSaveSRAM(FALSE);
            }
        }

        PROF_LEAVE("_MainLoopCheckSRAM");
    }
	return TRUE;
}



void _MainLoopLoadState()
{
    Char Path[256];


/*
    printf("%d\n", sizeof(_SnesState));
    printf("SNStateCPUT		%d\n",sizeof(SNStateCPUT		));
    printf("SNStatePPUT		%d\n",sizeof(SNStatePPUT		));
    printf("SNStateIOT		%d\n",sizeof(SNStateIOT		    ));
    printf("SNStateDMACT	%d\n",sizeof(SNStateDMACT	    ));
    printf("SNStateSPCT		%d\n",sizeof(SNStateSPCT		));
    printf("SNStateSPCDSPT  %d\n",sizeof(SNStateSPCDSPT     ));
  */
    if (!_pSystem) return;

    if (_pSystem == _pSnes)
    {
	    sprintf(Path, "%s%s.sns", MAINLOOP_STATEPATH, _RomName);

        if (FileReadMem(Path, &_SnesState, sizeof(_SnesState)))
        {
            _bStateSaved = TRUE;

		    ConPrint("State loaded from %s\n", Path);
        }

        if (_bStateSaved)
        {
            _pSnes->RestoreState(&_SnesState);
        }
    } else
    if (_pSystem == _pNes)
    {
	    sprintf(Path, "%s%s.nst", MAINLOOP_STATEPATH, _RomName);

        if (FileReadMem(Path, &_NesState, sizeof(_NesState)))
        {
            _bStateSaved = TRUE;

		    ConPrint("State loaded from %s\n", Path);
        }

        if (_bStateSaved)
        {
            _pNes->RestoreState(&_NesState);
        }
    }

}


void _MainLoopSaveState()
{
    Char Path[256];
    if (!_pSystem) return;

    if (_pSystem == _pSnes)
    {
	    sprintf(Path, "%s%s.sns", MAINLOOP_STATEPATH, _RomName);

        _pSnes->SaveState(&_SnesState);
        _bStateSaved = TRUE;


        if (FileWriteMem(Path, &_SnesState, sizeof(_SnesState)))
        {
		    ConPrint("State saved to %s\n", Path);
        }
    } else
    if (_pSystem == _pNes)
    {
	    sprintf(Path, "%s%s.nst", MAINLOOP_STATEPATH, _RomName);

        _pNes->SaveState(&_NesState);
        _bStateSaved = TRUE;

        if (FileWriteMem(Path, &_NesState, sizeof(_NesState)))
        {
		    ConPrint("State saved to %s\n", Path);
        }
    }
}


static void _MainLoopUnloadRom()
{
    // stop recording if we are recording
    if (s_pMovieClip->IsRecording())
    {
        printf("Movie: Record End\n");
        s_pMovieClip->RecordEnd();
    } 
    // stop playing if we are playing
    if (s_pMovieClip->IsPlaying())
    {
        printf("Movie: Play End\n");
        s_pMovieClip->PlayEnd();
    } 

	// unload old rom
	_pSnes->SetRom(NULL);
	_pSnesRom->Unload();
	_pNes->SetRom(NULL);
	_pNesRom->Unload();
	_pNesFDSDisk->Unload();
    _bStateSaved = FALSE;
    _pSystem = NULL;

	_fbTexture[0]->Clear();
	_fbTexture[1]->Clear();
}

static void _MainLoopSetSampleRate(Uint32 uSampleRate);

static int _MainLoopReadBinaryData(Uint8 *pBuffer, Int32 nBufferBytes, const char *pRomFile)
{
	int nBytes = 0;
    int hFile;

    hFile = fioOpen(pRomFile, O_RDONLY);
    if (hFile < 0)
    {
        return -1;
    }

    nBytes= fioRead(hFile, pBuffer, nBufferBytes);
    fioClose(hFile);

	return nBytes;
}

static int _MainLoopReadGZData(Uint8 *pBuffer, Int32 nBufferBytes, const char *pRomFile)
{
	int nBytes = 0;
    gzFile pFile;

    pFile = gzopen(pRomFile, "rb");
    if (!pFile)
    {
        return -1;
    }
    nBytes = gzread(pFile, pBuffer, nBufferBytes);
    gzclose(pFile);

	return nBytes;
}

extern "C" {
#include "unzip.h"
};

static int _MainLoopReadZipData(Uint8 *pBuffer, Int32 nBufferBytes, const char *pZipFile, char *pFileName)
{
	unzFile hFile;
	unz_file_info file_info;
	char filename[256];
	int nBytes = 0;

	hFile = unzOpen(pZipFile);
	if (!hFile)
    {
        return -1;
    }
	printf("ZIP: file opened\n");

	do
	{
		if (unzGetCurrentFileInfo(hFile, &file_info, filename, sizeof(filename), NULL, 0, NULL, 0) != UNZ_OK)
			break;

		printf("ZIP: file %s (%d)\n", filename, (int)file_info.uncompressed_size);

		if (file_info.uncompressed_size <= (unsigned)nBufferBytes)
		{
			PathExtTypeE eType;
			// do we recognize this file type?
			if (PathExtResolve(filename, &eType, FALSE))
			{
				printf("ZIP: read %s (%d)\n", filename, (int)file_info.uncompressed_size);

				// if so, read it
				if (unzOpenCurrentFile(hFile) == UNZ_OK)
				{
					if (unzReadCurrentFile(hFile, pBuffer, file_info.uncompressed_size) > 0)
					{
						if (pFileName)
							strcpy(pFileName, filename);
						nBytes = (int)file_info.uncompressed_size;
					}
					unzCloseCurrentFile(hFile);
				}
			}
		}

	} while (nBytes == 0 && unzGoToNextFile(hFile) == UNZ_OK);

	printf("ZIP: file closed (%d)\n", nBytes);

	unzClose(hFile);

	return nBytes;
}




static Bool _MainLoopLoadRomData(CEmuRom *pRom, Uint8 *pRomData, Int32 nRomBytes)
{
    CMemFileIO romfile;
    EmuRomLoadErrorE eError;

    // open memoryfile for rom data
    romfile.Open(pRomData, nRomBytes);

	// load rom
    eError = pRom->LoadRom(&romfile);
    romfile.Close();

	if (eError!=EMUROM_LOADERROR_NONE)
	{
        ConPrint("ERROR: loading rom %d\n", eError);
		return FALSE;
	}
	return TRUE;
}

static Bool _MainLoopLoadBios(CEmuRom *pRom, const Char *pFilePath)
{
    CFileIO romfile;
    EmuRomLoadErrorE eError;

    // open memoryfile for rom data
    if (!romfile.Open(pFilePath, "rb"))
	{
        ConPrint("ERROR: loading fds bios!\n");
		return FALSE;
	}

	// load rom
    eError = pRom->LoadRom(&romfile);
    romfile.Close();

	if (eError!=EMUROM_LOADERROR_NONE)
	{
        ConPrint("ERROR: loading rom %d\n", eError);
		return FALSE;
	}
	return TRUE;
}

static Bool _MainLoopLoadSnesPalette(const char *pFileName)
{
	Uint32 *pPalData;
	pPalData = SNPPUColorGetPalette();

	return _MainLoopReadBinaryData((Uint8 *)pPalData, SNPPUCOLOR_NUM * sizeof(Uint32), pFileName) > 0;
}

static Bool _MainLoopExecuteFile(const char *pFileName, Bool bLoadSRAM)
{
	PathExtTypeE eType;
	CEmuRom *pRom = NULL;
	CEmuSystem *pSystem = NULL;
	CEmuRom *pBios = NULL;
	char FileName[256];

	if (pFileName==NULL)
	{
		return FALSE;
	}

	// make copy of filename
	strcpy(FileName, pFileName);

	// see if file exists first...
	int hFile;
    hFile = fioOpen(pFileName, O_RDONLY);
	if (hFile < 0)
	{
		return FALSE;
	}
	fioClose(hFile);


	// resolve file extension of filename
	if (!PathExtResolve(FileName, &eType, TRUE))
	{
		return FALSE;
  	}

	if (eType == MAINLOOP_ENTRYTYPE_SNESPALETTE)
	{
		return _MainLoopLoadSnesPalette(pFileName);
	}

	// unload existing game
    _MainLoopUnloadRom();

    #if MAINLOOP_HISTORY
    _MainLoopResetHistory();
    #endif
	_MainLoopResetInputChecksums();

	int nRomBytes = 0;
	Uint8 *pBuffer = _RomData;
	Int32 nBufferBytes = sizeof(_RomData);

	// clear rom data buffer
    memset(pBuffer, 0, nBufferBytes);

	// load rom data from disk into our buffer
	if (eType == MAINLOOP_ENTRYTYPE_GZ)
	{
		// if its a GZ file, then the next extension is the one we use
		if (!PathExtResolve(FileName, &eType, TRUE))
		{
			return FALSE;
		}

		// load GZ-ipped data
		nRomBytes = _MainLoopReadGZData(pBuffer, nBufferBytes, pFileName);

	} else
	if (eType == MAINLOOP_ENTRYTYPE_ZIP)
	{
		// if it is a ZIP file then we have to look in the file to find the right file to load
		nRomBytes = _MainLoopReadZipData(pBuffer, nBufferBytes, pFileName, FileName);
		if (nRomBytes > 0)
		{
			// resolve extension of unzipped file
			if (!PathExtResolve(FileName, &eType, TRUE))
			{
				return FALSE;
			}
		}

	} else
	{
		// read as binary data
		nRomBytes = _MainLoopReadBinaryData(pBuffer, nBufferBytes, pFileName);
	}

	// was load successful?
	if (nRomBytes <= 0)
	{
		return FALSE;
	}

    printf("ROM data read: %s (%d bytes)\n", pFileName, nRomBytes);

	_MainLoopGetName(_RomName, FileName);
	printf("ROMName: '%s'\n", _RomName);

	// determine what kind of system to use for this rom
	switch (eType)
	{
		case MAINLOOP_ENTRYTYPE_NESROM:
			pSystem = _pNes;
			pRom    = _pNesRom;
			pBios   = NULL;
			_MainLoop_fOutputIntensity = 0.8f;
			break;

		case MAINLOOP_ENTRYTYPE_NESFDSDISK:
			pSystem = _pNes;
			pRom    = _pNesFDSDisk;
			pBios   = _pNesFDSBios;
			_MainLoop_fOutputIntensity = 0.8f;
			break;

		case MAINLOOP_ENTRYTYPE_NESFDSBIOS:
			pSystem = _pNes;
			pRom    = NULL;
			pBios   = _pNesFDSBios;
			_MainLoop_fOutputIntensity = 0.8f;
			break;

		case MAINLOOP_ENTRYTYPE_SNESROM:
			pSystem = _pSnes;
			pRom    = _pSnesRom;
			pBios   = NULL;
			_MainLoop_fOutputIntensity = 1.0f;
			break;
		default:
			return FALSE;
	}

	if (pBios)
	{
		if (pRom==NULL)
		{
			// try to load disksys.rom directly
			if (!_MainLoopLoadBios(pBios, pFileName))
			{
				MainLoopModalPrintf(60*5, "ERROR: Cannot load disksys.rom");
				return FALSE;
			}
		} else
		{
			// can't run disks unless we have the FDS Bios loaded
			if (!pBios->IsLoaded())
			{
				char diskrompath[256];
				char *pFileName;
				strcpy(diskrompath, FileName);
				pFileName = strrchr(diskrompath, '/');
				if (!pFileName) 
					pFileName = strrchr(diskrompath, ':');
				if (!pFileName)
					return FALSE;

				// 
				strcpy(pFileName + 1, "disksys.rom");

				printf("FDSRom: '%s'\n", diskrompath);

				// try to load disksys.rom
				if (!_MainLoopLoadBios(pBios, diskrompath))
				{
					MainLoopModalPrintf(60*5, "ERROR: Cannot load disksys.rom");
					return FALSE;
				}
			}
		}
	}

	if (pRom)
	{
		// attempt to load rom for that system
		if (!_MainLoopLoadRomData(pRom, _RomData, nRomBytes))
		{
			return FALSE;
		}
	}

	if (pBios)
	{
		// setup disk system
		pSystem->SetRom(pBios);
		_pNes->SetNesDisk(_pNesFDSDisk);
	} 
	else
	{
		pSystem->SetRom(pRom);
	}

	pSystem->Reset();

    _pSystem = pSystem;

	ConPrint("ROM Loaded: %s\n", pFileName);

	if (pRom)
	{
		int nRegions, iRegion;
		Char *pRomTitle;
		Char *pRomMapper;

		// print mapper info
		pRomMapper = pRom->GetMapperName();
		if (pRomMapper && !strcmp(pRomMapper, "<unknown>"))
		{
			MainLoopModalPrintf(60*1, "WARNING: Unsupported NES Mapper");
		}

		// print rom title
		pRomTitle = pRom->GetRomTitle();
		if (pRomTitle)
		{
		    printf("Rom Title: %s\n", pRomTitle);
		}

		// print info about rom regions
		nRegions = pRom->GetNumRomRegions();
		for (iRegion=0; iRegion < nRegions; iRegion++)
		{
			printf("%s: %d bytes\n", pRom->GetRomRegionName(iRegion), pRom->GetRomRegionSize(iRegion));
		}
	}

    _MainLoopSetSampleRate(pSystem->GetSampleRate());

	if (bLoadSRAM)
	{
		_MainLoopLoadSRAM();
	}

	// clear screen
    _fbTexture[0]->Clear();
    TextureUpload(&_OutTex, _fbTexture[0]->GetLinePtr(0));

	if (eType == MAINLOOP_ENTRYTYPE_NESFDSDISK)
	{
		// default to disk 0
		_MainLoop_iDisk=0;
		_MainLoop_bDiskInserted=TRUE;
		_pNes->GetMMU()->InsertDisk(_MainLoop_iDisk);
	}

	return TRUE;
}






static void _MainLoopSetPalette(NesPalE eNesPal)
{
	Color32T BasePal[64];
	Int32 iPal;

	memcpy(BasePal, NesPalGetStockPalette(eNesPal), sizeof(BasePal));
//		NesPalGenerate(BasePal, 334.0f, 0.4f);

	for (iPal=0; iPal < NESPAL_NUMPALETTES; iPal++)
	{
		Color32T Palette[64];

		// get palette
		NesPalComposePalette(iPal, Palette, BasePal, 64);

		// set palette for surface
		_fbTexture[0]->SetPaletteEntries(iPal, Palette, 64);
		_fbTexture[1]->SetPaletteEntries(iPal, Palette, 64);
	}
}


static void _MainLoopSetScreen(CScreen *pScreen)
{
	_MainLoop_pScreen = pScreen;
}

static int _MainLoopBrowserEvent(Uint32 Type, Uint32 Parm1, void *Parm2)
{
	switch (Type)
	{
		case 1:
		{
			Char *str = (Char *)Parm2;
	        NetPlayRPCStatusT status;
	        NetPlayGetStatus(&status);

	        if (status.eClientStatus == NETPLAY_STATUS_CONNECTED)
	        {
	            NetPlayClientSendLoadReq(str);
	        } else
			{
				// load rom with sram load
				if (_MainLoopExecuteFile(str, TRUE))
				{
					_MenuEnable(FALSE);
				}else
				{
					MainLoopModalPrintf(60*1, "ERROR: %s\n", str);
				}
			}
			return 1;
		}

		case 2:
		{
			char str[256];
			char *pName = (char *)Parm2;
		    PathExtTypeE eType;

			strcpy(str, pName);

			// figure out what type of file this is
		   	if ( PathExtResolve(str, &eType, TRUE))
			{
				return BROWSER_ENTRYTYPE_EXECUTABLE;
			}

			return BROWSER_ENTRYTYPE_OTHER;
		}
	} 
	return 0;
}

static int _MainLoopNetworkEvent(Uint32 Type, Uint32 Parm1, void *Parm2)
{
    NetPlayRPCStatusT status;
	switch (Type)
	{
		case 1:
            printf("Connecting to %08X\n", Parm1);
            NetPlayClientConnect(Parm1, MAINLOOP_NETPORT);
			break;
		case 2:
            NetPlayGetStatus(&status);
            if (status.eServerStatus == NETPLAY_STATUS_IDLE)
            {
               NetPlayServerStart(MAINLOOP_NETPORT, Parm1);
               NetPlayClientConnect(0x0100007F, MAINLOOP_NETPORT);
           }
           else
           NetPlayServerStop();
			break;
		case 3:
            NetPlayGetStatus(&status);
            if (status.eClientStatus == NETPLAY_STATUS_IDLE)
            {
				return 1;
            } else
            {
                NetPlayClientDisconnect();
				return 0;
            }
			break;
	}

	return 0;
}

static int _MainLoopLogEvent(Uint32 Type, Uint32 Parm1, void *Parm2)
{
	return 0;
}


static char *_MainLoopMenuEntries[]=
{
	"Copy cdrom0: -> mc0:",
	"Copy cdrom0: -> mc1:",
	"Copy host: -> mc0:",
	"Copy mc0: -> mc1:",
	"Copy mc1: -> mc0:",
	"Copy mc0: -> host:",
	"Dump memory -> host:",
	"Add PSX CD to mc0:title.db",
	"Dump mc0:title.db -> tty0:",
	"Copy rom0:libsd -> host:",
	NULL
};


static char *_MainLoop_pInstallFiles[] =
{
	"BOOT.ELF",		"BOOT.ELF",
	"TITLE.DB",		"TITLE.DB",
	"ICON.SYS",		"ICON.SYS",
	"PS2IP.IRX",	"PS2IP.IRX",
	"PS2IPS.IRX",	"PS2IPS.IRX",
	"PS2LINK.IRX",	"PS2LINK.IRX",
	"PS2SMAP.IRX",	"PS2SMAP.IRX",
	"CDVD.IRX",		"CDVD.IRX",
	"SJPCM2.IRX",	"SJPCM2.IRX",
	"MCSAVE.IRX",	"MCSAVE.IRX",
	"NETPLAY.IRX",	"NETPLAY.IRX",
	NULL
};

typedef int (*CopyProgressCallBackT)(char *pDestName, char *pSrcName, int Position, int Total);

int InstallFiles(char *pDestPath, char *pSrcPath, char **ppInstallFiles, CopyProgressCallBackT pCallBack);
int CopyFile(char *pDest, char *pSrc, CopyProgressCallBackT pCallBack);

static int _MainLoopInstallCallback(char *pDestName, char *pSrcName, int Position, int Total)
{
	char str[256];
	sprintf(str, "Copying %d / %d bytes", Position, Total);
	_MainLoop_pMenuScreen->SetText(0, str);
	_MainLoop_pMenuScreen->SetText(1, pSrcName);
	_MainLoop_pMenuScreen->SetText(2, pDestName);
	MainLoopRender();
	return 1;
}

static void _DumpMemory()
{
	int fd;
	fd = fioOpen("host:memdump.bin", O_WRONLY | O_CREAT);
	if (fd >= 0)
	{
		fioWrite(fd, (void *)0x100000, 4 * 1024 * 1024);
		fioClose(fd);
	}
}

static void _GetExploitDir(char *pStr)
{
	int fd;
	char code = 'A';
	char romver[16];

	// Determine the PS2's region.  
	fd = fioOpen("rom0:ROMVER", O_RDONLY);
	fioRead(fd, romver, sizeof romver);
	fioClose(fd);
	code  = (romver[4] == 'E' ? 'E' : (romver[4] == 'J' ? 'I' : 'A'));

	sprintf(pStr, "B%cDATA-SYSTEM", code);
}


static void _AddTitleDB(char *pPath)
{
	FILE *pFile;
	char str[256];

	CDVD_FlushCache();

	pFile = fopen("cdfs:/SYSTEM.CNF", "rt");
//	pFile = fopen("host:/SYSTEM.CNF", "rt");
	if (!pFile)
	{
		MainLoopModalPrintf(60*3, "Unable to open SYSTEM.CNF on cd.");
		return;
	}
	while (fgets(str, sizeof(str), pFile))
	{
		if (!memcmp(str, "BOOT", 4))
		{
			char *pFileStart = strchr(str, '\\');
			char *pFileEnd = strrchr(str, ';');

			if (pFileStart)
			{
				// skip \ in path
				pFileStart+=1;
				if (pFileEnd) *pFileEnd='\0';
				printf("Found '%s'\n", pFileStart);
				fclose(pFile);

				// add to title.db
				if (add_title_db(pPath, pFileStart)==0)
				{
					MainLoopModalPrintf(60*3, "%s added to mc0:title.db", pFileStart);
				} else
				{
					MainLoopModalPrintf(60*3, "Unable to add to %s", pPath);
				}
				fclose(pFile);
				return;
			}
		}
	}
	fclose(pFile);

	MainLoopModalPrintf(60*3, "Unable to find PSX ELF");
}

static int _MainLoopMenuEvent(Uint32 Type, Uint32 Parm1, void *Parm2)
{
	switch (Type)
	{
		case 1:
			{
				char mc0[256];
				char mc1[256];
				char exploit_dir[256];
				char **ppInstallFiles = _MainLoop_pInstallFiles;

				_GetExploitDir(exploit_dir);

				sprintf(mc0, "mc0:/%s", exploit_dir);
				sprintf(mc1, "mc1:/%s", exploit_dir);

				// hack in default destination name for elf
				ppInstallFiles[0] = "BOOT.ELF"; // dest
				switch (Parm1)
				{
					case 0:
						// cdrom->mc0
						ppInstallFiles[1] = VersionGetElfName(); // src
						InstallFiles(mc0, "cdrom0:\\", ppInstallFiles, _MainLoopInstallCallback);
						break;
					case 1:
						ppInstallFiles[1] = VersionGetElfName(); // src
						InstallFiles(mc1, "cdrom0:\\", ppInstallFiles, _MainLoopInstallCallback);
						break;
					case 2:
						ppInstallFiles[1] = "SNESTICLE.ELF"; // src
						InstallFiles(mc0, "host:", ppInstallFiles, _MainLoopInstallCallback);
						break;
					case 3:
						ppInstallFiles[1] = "BOOT.ELF"; // src
						InstallFiles(mc1, mc0, ppInstallFiles, _MainLoopInstallCallback);
						break;
					case 4:
						ppInstallFiles[1] = "BOOT.ELF"; // src
						InstallFiles(mc0, mc1, ppInstallFiles, _MainLoopInstallCallback);
						break;
					case 5:
						ppInstallFiles[0] = "SNESTICLE.ELF"; // dest
						ppInstallFiles[1] = "BOOT.ELF"; // src
						InstallFiles("host:", mc0, ppInstallFiles, _MainLoopInstallCallback);
						break;
					case 6:
						_DumpMemory();
						break;
					case 7:
						sprintf(mc0, "mc0:/%s/TITLE.DB", exploit_dir);
						_AddTitleDB(mc0);
						break;
					case 8:
						sprintf(mc0, "mc0:/%s/TITLE.DB", exploit_dir);
						list_title_db(mc0);
						break;
					case 9: // copy rom0:libsd -> host
						CopyFile("host:LIBSD.IRX", "rom0:LIBSD", NULL);
						break;
					default:
						return 0;
				}
				_MainLoop_pMenuScreen->SetText(0, "");
				_MainLoop_pMenuScreen->SetText(1, "");
				_MainLoop_pMenuScreen->SetText(2, "");
			}
			break;
	}

	return 0;
}
static void *_MainLoopNetCallback(NetPlayCallbackE eCallback, char *data, int size)
{
    switch (eCallback)
    {
        case NETPLAY_CALLBACK_NONE:
            break;

        case NETPLAY_CALLBACK_CONNECTED:
            printf("NetClientEE: Connected\n");
            break;

        case NETPLAY_CALLBACK_DISCONNECTED:
            printf("NetClientEE: Disconnected\n");
            break;

        case NETPLAY_CALLBACK_LOADGAME:
            {
                Bool result = FALSE;

                printf("NetClientEE: Loading the netgame %s\n", data);
                if (size > 0)
                {
                    //  load here (no-sram)
					result = _MainLoopExecuteFile(data, FALSE);
                }

                if (!result)
                {
                    NetPlayClientSendLoadAck(NETPLAY_LOADACK_ERROR);
                }  else
                {
                    NetPlayClientSendLoadAck(NETPLAY_LOADACK_OK);
                }
            }
            break;

        case NETPLAY_CALLBACK_UNLOADGAME:
            printf("NetClientEE: Unloading the netgame\n");
            _MainLoopUnloadRom();
            break;

        case NETPLAY_CALLBACK_STARTGAME:
            printf("NetClientEE: Starting the netgame\n");
            _MenuEnable(FALSE);
            break;

        default:
            printf("NetClientEE: Callback %d\n", eCallback);
            break;

    }
	return NULL;
}

//
//
//

static char _MainLoop_BootDir[256];

static char *_MainLoop_IOPModulePaths[]=
{
	_MainLoop_BootDir,
    "host:",
    "cdrom:\\",
    "rom0:",
    NULL
};


static char *_MainLoop_NetConfigPaths[]=
{
	"mc0:/SNESticle/",
	_MainLoop_BootDir,
    NULL
};


static int _LoadMcModule(const char *path, int argc, const char *argv)
{
    void *iop_mem;
    int ret;
	int fd;
	int size;

	fd= fioOpen(path, O_RDONLY);
	if (fd < 0)
	{
		return -1;
	}
	size = fioLseek(fd, 0, SEEK_END);
	fioClose(fd);

	printf("LoadMcModule %s (%d)\n", path, size);
    iop_mem = SifAllocIopHeap(size);
    if (iop_mem == NULL) {
		return -2;
    }
    ret = SifLoadIopHeap(path, iop_mem);
	ret=0;
    if (ret < 0) {
	    SifFreeIopHeap(iop_mem);
		return -3;
    }

	printf("SifLoadModuleBuffer %08X\n",(Uint32)iop_mem);
    ret = SifLoadModuleBuffer(iop_mem, argc, argv);
	printf("SifLoadModuleBuffer %d\n",ret);
    SifFreeIopHeap(iop_mem);
	return ret;
}


Int32 IOPLoadModule(const Char *pModuleName, Char **ppSearchPaths, int arglen, const char *pArgs)
{
    int ret = -1;
    char ModulePath[256];

    if (ppSearchPaths)
    {
        // iterate through search paths
        while (*ppSearchPaths)
        {
			if (strlen(*ppSearchPaths) > 0)
			{
            	strcpy(ModulePath, *ppSearchPaths);
            	strcat(ModulePath, pModuleName);
				if (ModulePath[0] == 'm' && ModulePath[1]=='c')
				{
					ret = _LoadMcModule(ModulePath, arglen, pArgs);
				} else
				{
            		ret = SifLoadModule(ModulePath, arglen, pArgs);
				}

            	if (ret >= 0)
            	{
            	    // success!
					break;
            	}
			}

            ppSearchPaths++;
        }
    } else
    {
		strcpy(ModulePath, pModuleName);
        ret = SifLoadModule(ModulePath, arglen, pArgs);
    }


    if (ret >= 0)
    {
        // success!
		ScrPrintf("IOP Load: %s\n", ModulePath);
        return ret;
    } else
	{
		ScrPrintf("IOP Fail: %s %d\n", pModuleName, ret);
    	printf("IOP: Failed to load module '%s'\n", pModuleName);

    	// module not loaded
    	return -1;
	}
}


static Bool _MainLoopLoadNetConfig(t_ip_info *pConfig, const char *pConfigPath)
{
	// 
	printf("netconfigload: %s\n", pConfigPath);
	return FALSE;
}

static Bool _MainLoopConfigureNetwork(char **ppSearchPaths, char *pConfigFileName)
{
    t_ip_info config;

	// reset ip configuration
    memset(&config, 0, sizeof(config));

	strcpy(config.netif_name, "sm1");

	// setup default config to have dhcp enabled
	config.dhcp_enabled = 1;
	config.ipaddr.s_addr = 0;
	config.netmask.s_addr = 0;
	config.gw.s_addr = 0;

	// go through all search paths
	while (*ppSearchPaths!=NULL)
	{
		if (strlen(*ppSearchPaths) > 0)
		{
		    char Path[256];

        	sprintf(Path, "%s%s", *ppSearchPaths, pConfigFileName);

			// attempt to load configuration information
			if (_MainLoopLoadNetConfig(&config, Path))
			{
				// loaded!
				break;
			}
		}
		ppSearchPaths++;
	}

// set configuration
	ps2ip_setconfig(&config);

	if (ps2ip_getconfig(config.netif_name,&config))
	{
		// print info about network configuration
		printf("%08X %08X %08X %d\n", config.ipaddr.s_addr, config.netmask.s_addr, config.gw.s_addr, config.dhcp_enabled);
	}

	return TRUE;
}

static Bool _MainLoopInitNetwork(Char **ppSearchPaths)
{
    int ret;
	Bool bLoadedNetwork = FALSE;

	// attempt to load ps2ips (the ps2ip iop rpc server)
	// if it does load, then it means that ps2ip is already set up (from ps2link or some other loader)
	//      and we need not load ps2ip ourselves
    ret = IOPLoadModule("PS2IPS.IRX", ppSearchPaths, 0, NULL);
    if (ret < 0)
    {
		// load ps2ip modules
        IOPLoadModule("PS2IP.IRX", ppSearchPaths, 0, NULL);
        IOPLoadModule("PS2SMAP.IRX", ppSearchPaths, 0, NULL);

        ret = IOPLoadModule("PS2IPS.IRX", ppSearchPaths, 0, NULL);
		if (ret < 0)
		{
			// network not setup
			return FALSE;
		}

		bLoadedNetwork = TRUE;
    }

	// init ps2ip
    printf("ps2ip_Init()\n");
    ps2ip_init();

	// return TRUE if we initialized networking ourselves
	return bLoadedNetwork;
}





static void _MainLoopLoadModules(Char **ppSearchPaths)
{
	Bool bLoadedNetwork;

	#if 0
	if (!EEPuts_Init())
	{
		EEPuts_SetCallback(_MainLoop_Puts);
		IOPLoadModule("EEPUTS.IRX", ppSearchPaths, 0, NULL);
	}
	#endif

//    IOPLoadModule("rom0:SECRMAN", NULL, 0, NULL);

	if (IOPLoadModule("rom0:XSIO2MAN", NULL, 0, NULL) >= 0)
	{
		// use the X version of the iop libs
	    if (IOPLoadModule("rom0:XMTAPMAN", NULL, 0, NULL) >= 0)
		{
			xmtapInit(0);
			xmtapPortOpen(1,0);
		}
	    if (IOPLoadModule("rom0:XPADMAN", NULL, 0, NULL) >= 0)
	    {
	        xpadInit(0);
			InputInit(TRUE);
	    }

	    IOPLoadModule("rom0:XMCMAN", NULL, 0, NULL);
	    if (IOPLoadModule("rom0:XMCSERV", NULL, 0, NULL) >= 0)
		{
			MemCardInit();
			#if MAINLOOP_MEMCARD
			MemCardCreateSave(_SramPath, _MainLoop_SaveTitle, TRUE);
			#endif
		}
	} else
	{
		// use the regular versions
	    IOPLoadModule("rom0:SIO2MAN", NULL, 0, NULL);
	    if (IOPLoadModule("rom0:PADMAN", NULL, 0, NULL) >= 0)
	    {
	        padInit(0);
			InputInit(FALSE);
	    }

	    IOPLoadModule("rom0:MCMAN", NULL, 0, NULL);
	    if (IOPLoadModule("rom0:MCSERV", NULL, 0, NULL) >= 0)
		{
			MemCardInit();
			#if MAINLOOP_MEMCARD
			MemCardCreateSave(_SramPath, _MainLoop_SaveTitle, TRUE);
			#endif
		}
	}

	bLoadedNetwork = _MainLoopInitNetwork(ppSearchPaths);

	// configure network if we started it ourselves
	if (bLoadedNetwork)
	{
		_MainLoopConfigureNetwork(_MainLoop_NetConfigPaths, "ipconfig.dat");
	}

	// load netplay module
    if (IOPLoadModule("NETPLAY.IRX", ppSearchPaths, 0, NULL) >= 0)
    {
        NetPlayInit((void *)_MainLoopNetCallback);
    }

    if (IOPLoadModule("CDVD.IRX", ppSearchPaths, 0, NULL) >= 0)
    {
        printf("CDVD_Init()\n");
        CDVD_Init();
    }

	if (IOPLoadModule("rom0:LIBSD", NULL, 0, NULL) < 0)
	{
    	IOPLoadModule("LIBSD.IRX", ppSearchPaths, 0, NULL);
	}

    if (IOPLoadModule("SJPCM2.IRX", ppSearchPaths, 0, NULL) >= 0)
    {
        printf("SjPCM_Init()\n");
	    if(SjPCM_Init(0, 960*25, SJPCMMIXBUFFER_MAXENQUEUE) < 0) printf("Could not initialize SjPCM\n");

    //    SjPCM_Setvol(0x3FF);
    //    SjPCM_Setvol(0);
    }

	#if 1
    if (IOPLoadModule("MCSAVE.IRX", ppSearchPaths, 0, NULL) >= 0)
    {
        printf("MCSave_Init()\n");
        MCSave_Init(MAINLOOP_MAXSRAMSIZE);
    }
	#endif

	if (bLoadedNetwork)
	{
		// try to load ps2link so we can have host i/o back
	    IOPLoadModule("PS2LINK.IRX", ppSearchPaths, 0, NULL);
	}
}

int CopyFile(char *pDest, char *pSrc, CopyProgressCallBackT pCallBack)
{
	Uint8	Buffer[32*1024];
	int fdSrc, fdDest;
	int nTotalBytes=0;
	int nBytes;
	int nSrcSize;

	fdSrc = fioOpen(pSrc, O_RDONLY);
	if (fdSrc <= 0)
	{
		printf("Unable to open file %s\n", pSrc);
		return -1;
	}

	// get file size
	nSrcSize = fioLseek(fdSrc, 0, SEEK_END);
	fioLseek(fdSrc, 0, SEEK_SET);

	fdDest = fioOpen(pDest, O_WRONLY | O_CREAT);
	if (fdDest <= 0)
	{
		fioClose(fdSrc);
		printf("Unable to open file %s\n", pDest);
		return -2;
	}

	do
	{
		if (pCallBack)
			pCallBack(pDest, pSrc, nTotalBytes, nSrcSize);

		nBytes = fioRead(fdSrc, Buffer, sizeof(Buffer));
		if (nBytes > 0)
		{
			fioWrite(fdDest, Buffer, nBytes);
			nTotalBytes += nBytes;
		}
	} while (nBytes > 0);

	if (pCallBack)
		pCallBack(pDest, pSrc, nTotalBytes, nSrcSize);

	fioClose(fdSrc);
	fioClose(fdDest);
	printf("Copied %s->%s (%d bytes)\n", pSrc, pDest, nTotalBytes);	

	fdDest = fioOpen(pDest, O_RDONLY);
	if (fdDest > 0)
	{
		fioClose(fdDest);
		return 0;
	} else
	{
		printf("ERROR\n");	
		return -3;
	}
}


static Bool _bTrailingPath(char *pStr)
{
	int len;
	char cLastChar;
	len = strlen(pStr);
	if (len <= 0)
	{
		return TRUE;
	}
	cLastChar = pStr[len-1];
	return (cLastChar == '/' || cLastChar=='\\' || cLastChar==':');
}

				 //"mc0:/BADATA-SYSTEM"
int InstallFiles(char *pDestPath, char *pSrcPath, char **ppInstallFiles, CopyProgressCallBackT pCallBack)
{
	Bool bTrailingDest;
	Bool bTrailingSrc;

	printf("InstallFiles %s -> %s\n", ppInstallFiles[0], ppInstallFiles[1]);

	bTrailingSrc = _bTrailingPath(pSrcPath);
	bTrailingDest = _bTrailingPath(pDestPath);

	if (fioMkdir(pDestPath) < 0)
	{
		printf("Unable to create directory %s\n", pDestPath);
	} 

	while (*ppInstallFiles)
	{
		char DestPath[256];
		char SrcPath[256];

		printf("Installing %s -> %s\n", ppInstallFiles[0], ppInstallFiles[1]);

		if (bTrailingSrc)
		{
			sprintf(SrcPath,  "%s%s", pSrcPath, ppInstallFiles[1]);
		} else
		{
			sprintf(SrcPath,  "%s/%s", pSrcPath, ppInstallFiles[1]);
		}

		if (bTrailingDest)
		{
			sprintf(DestPath, "%s%s", pDestPath, ppInstallFiles[0]);
		} else
		{
			sprintf(DestPath, "%s/%s", pDestPath, ppInstallFiles[0]);
		}


		if (CopyFile(DestPath, SrcPath, pCallBack) < 0)
		{
			//
		}

		ppInstallFiles+=2;
	} 
	return 0;
}



/*
void InstallSNESticle()
{
	InstallFiles("mc0:/BADATA-SYSTEM", "host0:", _MainLoop_pInstallFiles, NULL);
}

void InstallLoader()
{
	InstallFiles("mc0:/BADATA-SYSTEM", "host0:", _MainLoop_pLoaderFiles, NULL);
}
*/


char *MainGetBootDir();
char *MainGetBootPath();


int dispx, dispy;

/*
#define MAINLOOP_SCREENWIDTH 256
#define MAINLOOP_SCREENHEIGHT 240
#define MAINLOOP_DISPX 65
#define MAINLOOP_DISPY 17
#define FB0     	0x0000
#define FB1     	0x0400
#define Z0      	0x0800
#define TEXADDR 	0x0B00
#define FONT_TEX  	0x2000
*/
/*
#define MAINLOOP_SCREENWIDTH  640
#define MAINLOOP_SCREENHEIGHT 240
#define MAINLOOP_DISPX 160
#define MAINLOOP_DISPY 17
#define FB0     	0x0000
#define FB1     	0x0C00
#define Z0      	0x1800
#define TEXADDR 	0x2400
#define FONT_TEX 	0x3000
*/
/*
#define MAINLOOP_SCREENWIDTH  512
#define MAINLOOP_SCREENHEIGHT 240
#define MAINLOOP_DISPX 160
#define MAINLOOP_DISPY 17
*/

#define MAINLOOP_SCREENWIDTH 256
#define MAINLOOP_SCREENHEIGHT 240
#define MAINLOOP_DISPX 65
#define MAINLOOP_DISPY 17
#define FB0     	0x0000
#define FB1     	0x0C00
#define Z0      	0x1800
#define TEXADDR 	0x2400
#define FONT_TEX 	0x3000

#if 0
static SNPPUColorCalibT _ColorCalib =
{
	0.9f,
	15.0f,
	0.2f
};
#else
static SNPPUColorCalibT _ColorCalib =
{
	0.9f,
	20.0f,
	0.2f
};
#endif

Bool MainLoopInit()
{
//    assert(0);
    #if PROF_ENABLED
    ProfInit(128 * 1024);
    #endif

	// initialize GS
	GS_InitGraph(GS_NTSC,GS_NONINTERLACE);
	dispx = MAINLOOP_DISPX;
	dispy = MAINLOOP_DISPY;
	GS_SetDispMode(dispx,dispy, MAINLOOP_SCREENWIDTH, MAINLOOP_SCREENHEIGHT);
	GS_SetEnv(MAINLOOP_SCREENWIDTH, MAINLOOP_SCREENHEIGHT, FB0, FB1, GS_PSMCT32, Z0, GS_PSMZ16S);


	GPFifoInit((Uint128 *)_MainLoop_GfxPipe, sizeof(_MainLoop_GfxPipe));
    PolyInit();
    FontInit(FONT_TEX);

	// setup log screen
	_MainLoop_pLogScreen = new CLogScreen();
	_MainLoop_pLogScreen->SetMsgFunc(_MainLoopLogEvent);
	_MainLoopSetScreen(_MainLoop_pLogScreen);
	_bMenu = TRUE;

	const VersionInfoT *pVersionInfo = VersionGetInfo();

	ScrPrintf("%s v%d.%d.%d %s %s %s", 
		pVersionInfo->ApplicationName, 
		pVersionInfo->Version[0],
		pVersionInfo->Version[1],
		pVersionInfo->Version[2],
		pVersionInfo->BuildType,
		pVersionInfo->BuildDate, 
		pVersionInfo->BuildTime);
	ScrPrintf("%s",  pVersionInfo->CopyRight);

	ScrPrintf("BootPath: %s", MainGetBootPath());
	ScrPrintf("BootDir: %s", MainGetBootDir());

	// set boot dir
	strcpy(_MainLoop_BootDir, MainGetBootDir());

    _MainLoopLoadModules(_MainLoop_IOPModulePaths);

	VramInit();

	_SJPCMMix = new SJPCMMixBuffer(32000, TRUE);

	#if CODE_DEBUG
    printf("MainLoopInit\n");
	#endif

	int loop=60 * 2;
	while (loop--)
		WaitForNextVRstart(1);

	// allocate textures
/*	TextureNew(&_frametex[0], 256, 256, TEX_FORMAT_RGB565);
	TextureNew(&_frametex[1], 256, 256, TEX_FORMAT_RGB565);
	_fbTexture[0]->Set((Uint8 *)TextureGetData(&_frametex[0]), _frametex[0].uWidth, _frametex[0].uHeight, _frametex[0].uPitch, PixelFormatGetByEnum(PIXELFORMAT_BGR565));
	_fbTexture[1].Set((Uint8 *)TextureGetData(&_frametex[1]), _frametex[1].uWidth, _frametex[1].uHeight, _frametex[1].uPitch, PixelFormatGetByEnum(PIXELFORMAT_BGR565));
  */
//    _fbTexture[0]->Alloc(256, 256,  PixelFormatGetByEnum(PIXELFORMAT_RGB555));
//    _fbTexture[1].Alloc(256, 256,  PixelFormatGetByEnum(PIXELFORMAT_RGB555));

    // create textures in main ram
    _fbTexture[0] = new CRenderSurface;
    _fbTexture[1] = new CRenderSurface;

    _fbTexture[0]->Alloc(256, 256,  PixelFormatGetByEnum(PIXELFORMAT_RGBA8));
    _fbTexture[1]->Alloc(256, 256,  PixelFormatGetByEnum(PIXELFORMAT_RGBA8));
    _fbTexture[0]->Clear();
    _fbTexture[1]->Clear();
//    printf("%08X\n", (Uint32)_fbTexture[0]->GetLinePtr(0));
//    printf("%08X\n", _fbTexture[1].GetLinePtr(0));

//    TextureNew(&_OutTex, 256, 256, GS_PSMCT16);
    // create texture in vram
    TextureNew(&_OutTex, 256, 256, GS_PSMCT32);
    TextureSetAddr(&_OutTex, TEXADDR );

    TextureUpload(&_OutTex, _fbTexture[0]->GetLinePtr(0));

	_MainLoopSetPalette(NESPAL_FCEU);

	PathExtAdd(MAINLOOP_ENTRYTYPE_GZ,  "gz");
	PathExtAdd(MAINLOOP_ENTRYTYPE_ZIP, "zip");


	SNPPUColorCalibrate(&_ColorCalib);

	// create nes machine
	_pSnes = new SnesSystem();
	_pSnes->Reset();

	_pSnesRom = new SnesRom();
	for (Uint32 iExt=0; iExt < _pSnesRom->GetNumExts(); iExt++)
	{
		PathExtAdd(MAINLOOP_ENTRYTYPE_SNESROM, _pSnesRom->GetExtName(iExt));
	}

	PathExtAdd(MAINLOOP_ENTRYTYPE_SNESPALETTE, "snpal");

	_pNes = new NesSystem();
	_pNes->Reset();

	_pNesRom = new NesRom();
	for (Uint32 iExt=0; iExt < _pNesRom->GetNumExts(); iExt++)
	{
		PathExtAdd(MAINLOOP_ENTRYTYPE_NESROM, _pNesRom->GetExtName(iExt));
	}

	_pNesFDSDisk = new NesDisk();
	for (Uint32 iExt=0; iExt < _pNesFDSDisk->GetNumExts(); iExt++)
	{
		PathExtAdd(MAINLOOP_ENTRYTYPE_NESFDSDISK, _pNesFDSDisk->GetExtName(iExt));
	}

	_pNesFDSBios = new NesFDSBios();
	for (Uint32 iExt=0; iExt < _pNesFDSBios->GetNumExts(); iExt++)
	{
		PathExtAdd(MAINLOOP_ENTRYTYPE_NESFDSBIOS, _pNesFDSBios->GetExtName(iExt));
	}

	s_pMovieClip = new CEmuMovieClip(_pSnes->GetStateSize(), 60 * 60 * 60);

	// init menu
	_MainLoop_pBrowserScreen = new CBrowserScreen(6000);
	_MainLoop_pBrowserScreen->SetMsgFunc(_MainLoopBrowserEvent);
	_MainLoop_pBrowserScreen->SetDir(MENU_STARTDIR);

	_MainLoop_pNetworkScreen = new CNetworkScreen();
	_MainLoop_pNetworkScreen->SetMsgFunc(_MainLoopNetworkEvent);
	_MainLoop_pNetworkScreen->SetPort(MAINLOOP_NETPORT);

	_MainLoop_pMenuScreen = new CMenuScreen();
	_MainLoop_pMenuScreen->SetMsgFunc(_MainLoopMenuEvent);
	_MainLoop_pMenuScreen->SetTitle("Install Menu");
	_MainLoop_pMenuScreen->SetEntries(_MainLoopMenuEntries );


	_MainLoopSetScreen(_MainLoop_pBrowserScreen);
	_bMenu = FALSE;

//	while (1);

	// load snes palette
	_MainLoopLoadSnesPalette("mc0:/SNESticle/default.snpal");

	// load rom
	_MainLoopExecuteFile(_pRomFile, TRUE);
	_bMenu = _pSystem ? FALSE : TRUE;

	SjPCM_Clearbuff();
	SjPCM_Play();
//   SjPCM_Setvol(0xF);

/*
    if (!_WavFile.Open(_pSnesWavFileName, 32000, 16, 2))
    {
         printf("WavOut Open\n");
    }
  */

	InputPoll();

#if 0
	while (1)
	{
		MainLoopRender();
		_MainLoop_pBrowserScreen->SetDir("cdfs:/ROMS/SNES");
		MainLoopRender();
		_MainLoop_pBrowserScreen->SetDir("cdfs:/ROMS/SNES/USA");
	}
#endif

    return TRUE;
}


static Uint16 _MainLoopSnesInput(Uint32 cond)
{
	Uint32 pad = 0;

	if (cond & PAD_LEFT)    pad|= (SNESIO_JOY_LEFT);
	if (cond & PAD_RIGHT)   pad|= (SNESIO_JOY_RIGHT);
	if (cond & PAD_UP)      pad|= (SNESIO_JOY_UP);
	if (cond & PAD_DOWN)    pad|= (SNESIO_JOY_DOWN);

	if (cond & PAD_SQUARE)   pad|= (SNESIO_JOY_Y);
	if (cond & PAD_TRIANGLE) pad|= (SNESIO_JOY_X);
	if (cond & PAD_CROSS)    pad|= (SNESIO_JOY_B);
	if (cond & PAD_CIRCLE)   pad|= (SNESIO_JOY_A);

	if (cond & PAD_L1)   pad|= (SNESIO_JOY_L);
	if (cond & PAD_R1)   pad|= (SNESIO_JOY_R);

	if (cond & PAD_SELECT)  pad|= (SNESIO_JOY_SELECT);
	if (cond & PAD_START)   pad|= (SNESIO_JOY_START);
	return pad;
}


static Uint16 _MainLoopNesInput(Uint32 cond)
{
	Uint8 pad = 0;

	if ((cond & PAD_LEFT) ) pad|= (1<<NESIO_BIT_LEFT);
	if ((cond & PAD_RIGHT)) pad|= (1<<NESIO_BIT_RIGHT);
	if ((cond & PAD_UP)   ) pad|= (1<<NESIO_BIT_UP);
	if ((cond & PAD_DOWN) ) pad|= (1<<NESIO_BIT_DOWN);
	if ((cond & PAD_SQUARE)    ) pad|= (1<<NESIO_BIT_B);
	if ((cond & PAD_CROSS)    ) pad|= (1<<NESIO_BIT_A);

	if ((cond & PAD_TRIANGLE)    ) pad|= (1<<NESIO_BIT_B);
	if ((cond & PAD_CIRCLE)    ) pad|= (1<<NESIO_BIT_A);

	if ((cond & PAD_SELECT)    ) pad|= (1<<NESIO_BIT_SELECT);
	if ((cond & PAD_START)) pad|= (1<<NESIO_BIT_START);
	return pad;
}

static void _MainLoopSetSampleRate(Uint32 uSampleRate)
{
    _SJPCMMix->SetSampleRate(uSampleRate);
}


#if MAINLOOP_SNESSTATEDEBUG
static SnesStateT _TestState[3];
#endif

#if MAINLOOP_NESSTATEDEBUG
static NesStateT _NesTestState[3];
#endif

//extern Bool bStateDebug;

#if MAINLOOP_HISTORY
Uint32 _History[16384 * 2];
Uint32 _nHistory = 0;
#endif

#if MAINLOOP_HISTORY
static void  _MainLoopResetHistory()
{
    _nHistory = 0;
}
#endif

#if MAINLOOP_HISTORY

void _MainLoopSaveHistory()
{
    FileWriteMem("host:game.hst", _History, _nHistory * sizeof(Uint32));
    printf("History written\n");
}
#endif


static Uint32 _uVblankCycle;
static Uint32 _uInputFrame;
static Uint32 _uInputChecksum[5];

static void _MainLoopResetInputChecksums()
{
	_uInputFrame =0;
	memset(_uInputChecksum, 0, sizeof(_uInputChecksum));
}




#if 1
static Bool _ExecuteSnes(CRenderSurface *pSurface, CMixBuffer *pMixBuffer, EmuSysInputT *pInput, EmuSysModeE eMode)
{

        #if !TESTASM  

            #if !MAINLOOP_SNESSTATEDEBUG
//            pMixBuffer=NULL;
//            SNCPUSetExecuteFunc(SNCPUExecute_C);
            SNCPUSetExecuteFunc(SNCPUExecute_ASM);
            SNSPCSetExecuteFunc(SNSPCExecute_C);

		    PROF_ENTER("SnesExecuteFrame");
  		    _pSystem->ExecuteFrame(pInput, pSurface, pMixBuffer, eMode);
		    PROF_LEAVE("SnesExecuteFrame");
            #else

			if (_pSnes->GetFrame() > 50*60)
			{
            	SNCPUSetExecuteFunc(SNCPUExecute_C);
				_pSnes->SaveState(&_TestState[0]);
				_pSnes->ExecuteFrame(pInput, pSurface, NULL);
				_pSnes->SaveState(&_TestState[1]);


            	SNCPUSetExecuteFunc(SNCPUExecute_ASM);
				_pSnes->RestoreState(&_TestState[0]);
				_pSnes->ExecuteFrame(pInput, pSurface, NULL);
				_pSnes->SaveState(&_TestState[2]);

				if (memcmp(&_TestState[1], &_TestState[2],sizeof(SnesStateT)))
				{
					printf("State fault (frame= %d)\n", _pSnes->GetFrame());
            	    SNStateCompare(&_TestState[1],&_TestState[2]);

            	    FileWriteMem("host0:c:/emu/fault.sns", &_TestState[0], sizeof(_TestState[0]));


            	   
					printf("Resuming frame...\n");

//          	      bStateDebug = TRUE;

            	    SNCPUSetExecuteFunc(SNCPUExecute_C);
    				_pSnes->RestoreState(&_TestState[0]);
				    _pSnes->ExecuteFrame(pInput, pSurface, NULL);

            	    SNCPUSetExecuteFunc(SNCPUExecute_ASM);
				    _pSnes->RestoreState(&_TestState[0]);
				    _pSnes->ExecuteFrame(pInput, pSurface, NULL);

            	    while (1);

				}
			} else
			{
	            SNCPUSetExecuteFunc(SNCPUExecute_C);
	            SNSPCSetExecuteFunc(SNSPCExecute_C);

			    PROF_ENTER("SnesExecuteFrame");
	  		    _pSystem->ExecuteFrame(pInput, pSurface, pMixBuffer);
			    PROF_LEAVE("SnesExecuteFrame");
			}
            #endif


//  		    _pSnes->ExecuteFrame(&Input, NULL, &_SJPCMMix);
//  		    _pSnes->ExecuteFrame(&Input, pSurface, NULL);
        #endif

    return TRUE;
}

extern "C" {
#include "ncpu_c.h"
};

static Bool _ExecuteNes(CRenderSurface *pSurface, CMixBuffer *pMixBuffer, EmuSysInputT *pInput, EmuSysModeE eMode)
{

    #if !MAINLOOP_NESSTATEDEBUG

    N6502SetExecuteFunc(NCPUExecute_C);

	PROF_ENTER("NesExecuteFrame");
  	_pSystem->ExecuteFrame(pInput, pSurface, pMixBuffer, eMode);
	PROF_LEAVE("NesExecuteFrame");
    #else

	_pNes->SaveState(&_NesTestState[0]);
	_pNes->ExecuteFrame(pInput, pSurface, NULL);
	_pNes->SaveState(&_NesTestState[1]);

	_pNes->RestoreState(&_NesTestState[0]);
	_pNes->ExecuteFrame(pInput, pSurface, NULL);
	_pNes->SaveState(&_NesTestState[2]);

	if (memcmp(&_NesTestState[1], &_NesTestState[2],sizeof(NesStateT)))
	{
		printf("State fault\n");
	}

    #endif
    return TRUE;
}
#endif




Uint16 _MainLoopInput(Uint32 pad)
{
	if (pad & (PAD_R2|PAD_L2))
    {
        return 0;
    }

    if (_pSystem==_pSnes)
    {
        return _MainLoopSnesInput(pad);
    } else
    if (_pSystem==_pNes)
    {
        return _MainLoopNesInput(pad);
    } 
    return 0;
}

#include "snppublend_gs.h"



void MainLoopRender()
{
	static Uint32 _iFrame=0;
	static int whichdrawbuf = 0;

    // render frame
    GPPrimDisableZBuf();

	if (!_MainLoop_BlackScreen)
	{
//		Float32 fDestColor = (_bMenu || _MainLoop_ModalCount) ? 0.10f : 0.80f;
		Float32 fDestColor = 0.10f;
		
		if  (!_bMenu && !_MainLoop_ModalCount)
		{
			fDestColor = _MainLoop_fOutputIntensity;
		}

		static Float32 fColor=0.0f;
		Float32 dx = 0.0f;
		Float32 dy = 8.0f;

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


        PolyBlend(FALSE);
        PolyTexture(&_OutTex);
//        PolyUV(0,0,256,240);
        PolyUV(0,0,256,240);
		PolyColor4f(fColor, fColor, fColor, 1.0f);
//		PolyColor4f(0.50f, 0.50f, 0.50f, 1.0f);


        PolyRect(dx,dy,MAINLOOP_SCREENWIDTH,MAINLOOP_SCREENHEIGHT);

        PolyBlend(TRUE);
        //PolyTexture(NULL);
        //PolyRect(dx,dy,128,120);
    }


    if (!_bMenu)
    {
		if (s_pMovieClip->IsPlaying())
		{
	        FontSelect(2);
	        FontColor4f(0.5, 0.5f, 0.5f, 1.0f);
	        FontPrintf(240,220, ">");
		}

		if (s_pMovieClip->IsRecording())
		{
	        FontSelect(2);
	        FontColor4f(1.0, 0.0f, 0.0f, 1.0f);
	        FontPrintf(240,220, "O");
		}


		switch (_MainLoop_uDebugDisplay)
        {
		case 0:
/*	        FontSelect(2);
	        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
	        FontPrintf(40,170, "%08X", InputGetPadData(0));
  */

//		        FontSelect(2);
//		        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
//		        FontPrintf(40,190, "%3d", xpadGetFrameCount(0,0));
			break;
		case 1:
		/*
	        FontSelect(2);
	        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
	        FontPrintf(40,190, "%3d %3d", NetInput.InputSize[0], NetInput.OutputSize[0]);
	        FontPrintf(40,200, "%3d %3d", NetInput.InputSize[1], NetInput.OutputSize[1]);
	        FontPrintf(40,210, "%3d %3d", NetInput.InputSize[2], NetInput.OutputSize[2]);
	        FontPrintf(40,220, "%3d %3d", NetInput.InputSize[3], NetInput.OutputSize[3]);
			*/
			break;
		case 2:
	        FontSelect(2);
	        FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
	        FontPrintf(40,170, "%08X", _uInputFrame);
	        FontPrintf(40,180, "%08X", _uInputChecksum[0]);
	        FontPrintf(40,190, "%08X", _uInputChecksum[1]);
	        FontPrintf(40,200, "%08X", _uInputChecksum[2]);
	        FontPrintf(40,210, "%08X", _uInputChecksum[3]);
	        FontPrintf(40,220, "%08X", _uInputChecksum[4]);
			break;
		case 3:
			FontColor4f(1.0, 0.0f, 0.0f, 1.0f);
			FontPrintf(195, 210, "%8d", _uVblankCycle / 1024);
			break;
        }

        FontSelect(2);
		FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
		{

/*
		FontPrintf(15, 180, "%08X %08X Y", (Int32)(_ColorCalib.y_mul * 0x10000), (Int32)(_ColorCalib.y_add * 0x10000));
		FontPrintf(15, 190, "%08X %08X I", (Int32)(_ColorCalib.i_mul * 0x10000), (Int32)(_ColorCalib.i_add * 0x10000));
		FontPrintf(15, 200, "%08X %08X Q", (Int32)(_ColorCalib.q_mul * 0x10000), (Int32)(_ColorCalib.q_add * 0x10000));
  */

		/*
		FontPrintf(195, 180, "%6.3f %6.3f", _ColorCalib.y_mul, _ColorCalib.y_add);
		FontPrintf(195, 190, "%6.3f %6.3f", _ColorCalib.i_mul, _ColorCalib.i_add);
		FontPrintf(195, 200, "%6.3f %6.3f", _ColorCalib.q_mul, _ColorCalib.q_add);
		*/
		}

//			FontPrintf(195, 210, "%8d", _SJPCMMix.GetLastOutput());
    }


	if (_MainLoop_ModalCount > 0)
	{
		FontSelect(0);
		FontColor4f(1.0, 1.0f, 1.0f, 1.0f);
		FontPrintf(128 - FontGetStrWidth(_MainLoop_ModalStr) / 2,100, _MainLoop_ModalStr);

		_MainLoop_ModalCount--;
	} else
	{

		if (_MainLoop_StatusCount > 0)
		{
			FontSelect(0);
			FontColor4f(0.0, 0.8f, 0.8f, 1.0f);
			FontPrintf(20, 200, _MainLoop_StatusStr);

			_MainLoop_StatusCount--;
		} 


		if (_bMenu)
		{
			_MenuDraw();
		} 
	}


	#if CODE_DEBUG
	if (MCSave_WriteSync(FALSE, NULL))
	{
		FontSelect(1);
		FontColor4f(1.0, 0.0f, 0.0f, 1.0f);
		if (_iFrame & 4)
			FontPrintf(235,216, "#");
	}
	#endif



//	FontColor4f(1.0, 0.0f, 0.0f, 1.0f);
//	FontPuts(100, 100, _VersionStr);

//    PolyTexture(NULL);
//	PolyColor4f(0.0f, 1.0f, 0.0f, 1.0f);
//	PolyRect(0, 0, 100, 50);

    PROF_ENTER("GPFlush");
    GPFifoFlush();
    PROF_LEAVE("GPFlush");

    PROF_ENTER("WaitVBlank");

    if ( (_iFrame&15)==0)   _uVblankCycle = ProfCtrGetCycle();
	WaitForNextVRstart(1);
    if ( (_iFrame&15)==0)   _uVblankCycle = ProfCtrGetCycle() - _uVblankCycle;

    PROF_LEAVE("WaitVBlank");

    PROF_ENTER("GSSetCrt");
    GS_SetCrtFB(whichdrawbuf);
    whichdrawbuf ^= 1;
    GS_SetDrawFB(whichdrawbuf);
    PROF_LEAVE("GSSetCrt");

    _iFrame++;
}


Bool MainLoopProcess()
{
    NetPlayRPCInputT NetInput;

    PROF_ENTER("Frame");

    PROF_ENTER("NetPlayRPCProcess");
    NetPlayRPCProcess();
    PROF_LEAVE("NetPlayRPCProcess");

    PROF_ENTER("InputProcess");
    InputPoll();
    PROF_LEAVE("InputProcess");


	_MainLoopInputProcess(InputGetPadData(0) | InputGetPadData(1) | InputGetPadData(2) | InputGetPadData(3));

//	_MainLoopInputProcess(InputGetPadData(0));
//	_MainLoopInputProcess(InputGetPadData(1));

    if (!_bMenu && _pSystem && !_MainLoop_BlackScreen)
    {
        CRenderSurface *pSurface;
        CMixBuffer *pMixBuffer = NULL;
        pSurface = _fbTexture[_iframetex];
		EmuSysInputT Input;
		Int32 iPad;

        /*
        if (_WavFile.IsOpen())
        {
            pMixBuffer = &_WavFile;
        } else
        {
            pMixBuffer = &_SJPCMMix;
        } 
        */                        
        pMixBuffer = _SJPCMMix;
//                pMixBuffer = NULL;

		// read inputs
		for (iPad=0; iPad < 5; iPad++)
		{
			if (InputIsPadConnected(iPad))
			{
				Input.uPad[iPad] = _MainLoopInput(InputGetPadData(iPad));
			} else
			{
				Input.uPad[iPad] = EMUSYS_DEVICE_DISCONNECTED;
			}
		}

		// send controller 1 + 2 inputs combined to 32-bits
		NetInput.InputSend = ((Uint32)Input.uPad[0]) | (((Uint32)Input.uPad[1])<<16);

        PROF_ENTER("NetPlayClientInput");
        NetPlayClientInput(&NetInput);
        PROF_LEAVE("NetPlayClientInput");

        if (NetInput.eGameState == NETPLAY_GAMESTATE_PLAY)
        {
            if ((_pSystem->GetFrame()+1) != NetInput.uFrame)
            {
				#if CODE_DEBUG
                printf("Not executing frame %d %d\n", NetInput.uFrame, _pSystem->GetFrame());
				#endif
                NetInput.eGameState = NETPLAY_GAMESTATE_PAUSE;
            }

			// we are connected, retrieve input data
	        Input.uPad[0] = (Uint16)NetInput.InputRecv[0];
	        Input.uPad[1] = (Uint16)NetInput.InputRecv[1];
	        Input.uPad[2] = (Uint16)NetInput.InputRecv[2];
	        Input.uPad[3] = (Uint16)NetInput.InputRecv[3];
			Input.uPad[4] = EMUSYS_DEVICE_DISCONNECTED;

			if (Input.uPad[2] == EMUSYS_DEVICE_DISCONNECTED)
			{
				// if controller 3 is disconnected, use controller 2 of first peer
				Input.uPad[2] = (Uint16)(NetInput.InputRecv[0]>>16);
			}

			if (Input.uPad[3] == EMUSYS_DEVICE_DISCONNECTED)
			{
				// if controller 4 is disconnected, use controller 2 of second peer
				Input.uPad[3] = (Uint16)(NetInput.InputRecv[1]>>16);
			}
        }  else
		{
            if (s_pMovieClip->IsPlaying())
            {
                if (!s_pMovieClip->PlayFrame(Input))
                {
                    s_pMovieClip->PlayEnd();
                    ConPrint("Movie: Play End\n");
                }
            }
		}

        if (NetInput.eGameState != NETPLAY_GAMESTATE_PAUSE)
        {
			EmuSysModeE eMode;

            #if MAINLOOP_HISTORY
            if (_nHistory < 16384 * 2)
            {
                _History[_nHistory++] = Input.uPad[0];
                _History[_nHistory++] = Input.uPad[1];
                _History[_nHistory++] = Input.uPad[2];
                _History[_nHistory++] = Input.uPad[3];
            }
            #endif

			_uInputFrame    = NetInput.uFrame;
			_uInputChecksum[0] += Input.uPad[0];
			_uInputChecksum[1] += Input.uPad[1];
			_uInputChecksum[2] += Input.uPad[2];
			_uInputChecksum[3] += Input.uPad[3];
			_uInputChecksum[4] += Input.uPad[4];

			eMode = (NetInput.eGameState == NETPLAY_GAMESTATE_IDLE) ? EMUSYS_MODE_ACCURATENONDETERMINISTIC : EMUSYS_MODE_INACCURATEDETERMINISTIC;

            if (s_pMovieClip->IsRecording())
            {
                if (!s_pMovieClip->RecordFrame(Input))
                {
                    s_pMovieClip->RecordEnd();
                    ConPrint("Movie: Reached end of record buffer!\n");
                }
            }

            if (_pSystem==_pSnes)
            {
//                _ExecuteSnes(NULL, NULL, &Input, eMode);
 			    GPPrimDisableZBuf();
                _ExecuteSnes(pSurface, pMixBuffer, &Input, eMode);
//                TextureUpload(&_OutTex, pSurface->GetLinePtr(0));
            } else
            if (_pSystem==_pNes)
            {
                _ExecuteNes(pSurface, pMixBuffer, &Input, eMode);

                TextureUpload(&_OutTex, pSurface->GetLinePtr(0));
            } 

		    _iframetex^=1;
        }

        SjPCM_BufferedAsyncStart();
    }

    _MainLoopCheckSRAM();

	MainLoopRender();

    PROF_LEAVE("Frame");

    #if PROF_ENABLED
    ProfProcess();
    #endif

    return TRUE;
}

void MainLoopShutdown()
{
    FontShutdown();
    PolyShutdown();
}






//
//
//



/*
	Menu stuff

*/

void _MenuEnable(Bool bEnable)
{
	if (bEnable!=_bMenu)
	{
		// if menu is enabled, then attempt to save sram immediately
		if (bEnable)
		{
            #if 1 
			if (_MainLoopHasSRAM() && _MainLoop_SRAMUpdated)
			{
			   	MainLoopModalPrintf(10, "Saving SRAM...");

			    if (_MainLoopHasSRAM())
			    {
					#if MAINLOOP_MEMCARD
					MCSave_WriteSync(1, NULL);

					if (MemCardCheckNewCard())
					{
						printf("New memcard detected\n");
						if (MemCardCreateSave(_SramPath, _MainLoop_SaveTitle, FALSE))
						{
							MemCardCreateSave(_SramPath, _MainLoop_SaveTitle, FALSE);
						}
					}
					#endif

				    if (_MainLoopSaveSRAM(TRUE))
				    {
					    MainLoopModalPrintf(60, "SRAM saved.\n");
				    } else
				    {
					    MainLoopModalPrintf(60 * 1 + 30, "Error Saving SRAM!\n");
				    }
			    }
			}
            #endif
		}

		_bMenu = bEnable;

//    	SjPCM_Clearbuff();
	}
}

#define MENU_REPEAT (16)

//#define MENU_REPEATBUTTONS (PAD_UP|PAD_DOWN|PAD_SQUARE|PAD_CIRCLE)
#define MENU_REPEATBUTTONS (PAD_UP|PAD_DOWN|PAD_SQUARE|PAD_CIRCLE|PAD_CROSS|PAD_TRIANGLE|PAD_LEFT|PAD_RIGHT)

static void _MainLoopInputProcess(Uint32 buttons)
{
	static Uint32 lastbuttons= ~0;
	static Uint32 repeat=0;
	Uint32 trigger;


	if (!(buttons& MENU_REPEATBUTTONS))
	{
		repeat=0;
	}

	// 
	repeat++;
	if (repeat > MENU_REPEAT)
	{
		repeat -= 1;
		lastbuttons &= ~MENU_REPEATBUTTONS;
	}

	trigger = ((buttons ^ lastbuttons) & buttons);
	lastbuttons = buttons;

#if 1
	if (trigger & PAD_R3)
	{
        #if PROF_ENABLED
		ProfStartProfile(1);
        #endif
//		BMPWriteFile("/pc/mnt/c/out.bmp", &_fbTexture[0]);
	}





    #if 0 // CODE_DEBUG
	if (trigger & PAD_L2)
	{
        if (_WavFile.IsOpen())
        {
            _WavFile.Close();
            printf("WavOut Closed\n");
        } else
        {
        /*
            if (!_WavFile.Open(_pSnesWavFileName, 32000, 16, 2))
            {
                 printf("WavOut Open\n");
            }
            */
            if (!_WavFile.Open(_pSnesWavFileName, 48000, 16, 2))
            {
                 printf("WavOut Open\n");
            }

        }
//		BMPWriteFile("/pc/mnt/c/out.bmp", &_fbTexture[0]);
	}
    #endif


    #if 1 // CODE_DEBUG
	if (buttons & PAD_L2)
	{
        if (trigger&PAD_CROSS)
            _MainLoopSaveState();
        if (trigger&PAD_CIRCLE)
            _MainLoopLoadState();
        if (trigger&PAD_TRIANGLE)
		{
            _MainLoop_uDebugDisplay++;
            _MainLoop_uDebugDisplay&=3;
		}

        if (trigger&PAD_L3)
		{
	        // stop recording if we are recording
	        if (s_pMovieClip->IsRecording())
	        {
	            printf("Movie: Record End\n");
	            s_pMovieClip->RecordEnd();
	        } else
	        // stop playing if we are playing
	        if (s_pMovieClip->IsPlaying())
	        {
	            printf("Movie: Play End\n");
	            s_pMovieClip->PlayEnd();
	        } else

	        if (_pSystem)
	        {
	            s_pMovieClip->RecordBegin(_pSystem);
	            printf("Movie: Record Begin\n");
	        }
		}

        if (trigger&PAD_R3)
		{
	        // stop recording if we are recording
	        if (s_pMovieClip->IsRecording())
	        {
	            printf("Movie: Record End\n");
	            s_pMovieClip->RecordEnd();
	        } 

	        // stop playing if we are playing
	        if (s_pMovieClip->IsPlaying())
	        {
	            printf("Movie: Play End\n");
	            s_pMovieClip->PlayEnd();
	        } 
	        if (_pSystem)
	        {
	            s_pMovieClip->PlayBegin(_pSystem);
	            printf("Movie: Play Begin\n");
	        }
		}

    }

			/*
	if (buttons & PAD_R2)
	{
		if (buttons & PAD_SQUARE)
		{
        if (trigger&PAD_LEFT)
			_ColorCalib.i_mul-=0.1f;
        if (trigger&PAD_RIGHT)
			_ColorCalib.i_mul+=0.1f;
        if (trigger&PAD_UP)
			_ColorCalib.i_add+=0.005f;
        if (trigger&PAD_DOWN)
			_ColorCalib.i_add-=0.005f;
		}

		if (buttons & PAD_CROSS)
		{
        if (trigger&PAD_LEFT)
			_ColorCalib.q_mul-=0.01f;
        if (trigger&PAD_RIGHT)
			_ColorCalib.q_mul+=0.01f;
        if (trigger&PAD_UP)
			_ColorCalib.q_add+=0.005f;
        if (trigger&PAD_DOWN)
			_ColorCalib.q_add-=0.005f;
		}

		if (buttons & PAD_CIRCLE)
		{
        if (trigger&PAD_LEFT)
			_ColorCalib.y_mul-=0.01f;
        if (trigger&PAD_RIGHT)
			_ColorCalib.y_mul+=0.01f;
        if (trigger&PAD_UP)
			_ColorCalib.y_add+=0.005f;
        if (trigger&PAD_DOWN)
			_ColorCalib.y_add-=0.005f;
		}

		SNPPUBlendGS::ColorCalibrate(&_ColorCalib);
    }

			  */



    #endif


	#if 0
	if (
	 	((trigger & PAD_R2) && (buttons & PAD_L2)) ||
	 	((trigger & PAD_L2) && (buttons & PAD_R2)) 
	   )
	{
		// toggle menu
		 _MenuEnable(!_bMenu);
		 return;
	}
	#endif

	static int _MenuTriggerTimeout[2] = {0,0};

	if (trigger & PAD_L2)
	{
		_MenuTriggerTimeout[0]=5;
	}

	if (trigger & PAD_R2)
	{
		_MenuTriggerTimeout[1]=5;
	}


	if (_MenuTriggerTimeout[0] > 0)
	{
		if (trigger & PAD_R2)
		{
			_MenuTriggerTimeout[0] = 0;
			 // toggle menu
			 _MenuEnable(!_bMenu);
			 return;
		}
		_MenuTriggerTimeout[0]--;
	}

	if (_MenuTriggerTimeout[1] > 0)
	{
		if (trigger & PAD_L2)
		{
			_MenuTriggerTimeout[1] = 0;
			 // toggle menu
			 _MenuEnable(!_bMenu);
			 return;
		}
		_MenuTriggerTimeout[1]--;
	}


	if (_bMenu)
	{
		if (_MainLoop_pScreen)
		{
		    if (trigger & PAD_R1)
		    {
				if (_MainLoop_pScreen == _MainLoop_pBrowserScreen)
					_MainLoopSetScreen(_MainLoop_pNetworkScreen);
				 else
				if (_MainLoop_pScreen == _MainLoop_pNetworkScreen)
					_MainLoopSetScreen(_MainLoop_pMenuScreen);
				 else
				if (_MainLoop_pScreen == _MainLoop_pMenuScreen)
					_MainLoopSetScreen(_MainLoop_pLogScreen);
				else
					_MainLoopSetScreen(_MainLoop_pBrowserScreen);
		    } else

		    if (trigger & PAD_L1)
		    {
				if (_MainLoop_pScreen == _MainLoop_pBrowserScreen)
					_MainLoopSetScreen(_MainLoop_pLogScreen);
				 else
				if (_MainLoop_pScreen == _MainLoop_pNetworkScreen)
					_MainLoopSetScreen(_MainLoop_pBrowserScreen);
				 else
				if (_MainLoop_pScreen == _MainLoop_pMenuScreen)
					_MainLoopSetScreen(_MainLoop_pNetworkScreen);
				else
				if (_MainLoop_pScreen == _MainLoop_pLogScreen)
					_MainLoopSetScreen(_MainLoop_pMenuScreen);
		    } else
			{
				_MainLoop_pScreen->Input(buttons, trigger);
			}
		}

	}
	else
	{

		if (buttons & PAD_L2)
		{
			if (trigger & PAD_SELECT)
			{
				_MainLoop_BlackScreen^=1;
			}
		}


		// perform cheesy non-deterministic disk switching
		if (trigger & (PAD_R1|PAD_L1) )
		{
			if (_pNesFDSDisk->IsLoaded())
			{
				if (_MainLoop_bDiskInserted)
				{
					// eject disk!
					_MainLoop_bDiskInserted = FALSE;
					_pNes->GetMMU()->InsertDisk(-1);

					MainLoopStatusPrintf(60, "NESFDS Disk Ejected");

					// pick next disk
					if (trigger & PAD_R1)
						_MainLoop_iDisk++;
					else
						_MainLoop_iDisk--;
				} else
				{
					// wrap the number of disks
					if (_MainLoop_iDisk < 0)
					{
						_MainLoop_iDisk = _pNesFDSDisk->GetNumDisks()-1;
					}

					if (_MainLoop_iDisk >= _pNesFDSDisk->GetNumDisks())
					{
						_MainLoop_iDisk = 0;
					}
					// insert disk
					_pNes->GetMMU()->InsertDisk(_MainLoop_iDisk);
					_MainLoop_bDiskInserted = TRUE;


					MainLoopStatusPrintf(60, "NESFDS Disk %d Inserted", _MainLoop_iDisk);
				}
			}
		}


	}
#endif
}







#if MAINLOOP_HISTORY
    if (trigger & PAD_L3)
    {
         _MainLoopSaveHistory();
   }
#endif






static void _MenuDraw()
{
	FontSelect(0);

	PolyTexture(NULL);
    PolyBlend(TRUE);


    t_ip_info config;
    Bool bConfig;
    memset(&config, 0, sizeof(config));
    bConfig = ps2ip_getconfig("sm1",&config);

	// draw current screen
	if (_MainLoop_pScreen)
	{
		_MainLoop_pScreen->Draw();
	}

	int vy = 215;

	FontSelect(2);
//	FontColor4f(1.0, 0.0f, 0.0f, 1.0f);
//	FontColor4f(1.0, 0.5f, 0.5f, 1.0f);
	FontColor4f(0.2, 0.6f, 0.2f, 1.0f);


	const VersionInfoT *pVersionInfo = VersionGetInfo();

	char VersionStr[256];
	
	sprintf(VersionStr, "%s v%d.%d.%d %s", 
		pVersionInfo->ApplicationName, 
		pVersionInfo->Version[0],
		pVersionInfo->Version[1],
		pVersionInfo->Version[2],
		pVersionInfo->BuildType
		);

	FontPuts(256 - 16 - FontGetStrWidth(VersionStr), vy, VersionStr);

//	FontPrintf(8, vy-16, "%d", CDVD_DiskReady(1));





	FontPrintf(8, vy, "%s%d.%d", 
		pVersionInfo->Compiler, 
		pVersionInfo->CompilerVersion[0],  
		pVersionInfo->CompilerVersion[1]
		);
    FontPrintf(48,vy,"IP: %d.%d.%d.%d", 
            (config.ipaddr.s_addr >> 0) & 0xFF,
            (config.ipaddr.s_addr >> 8) & 0xFF,
            (config.ipaddr.s_addr >>16) & 0xFF,
            (config.ipaddr.s_addr >>24) & 0xFF
                    );



	FontSelect(0);
}





#if 1
void *operator new(unsigned x)
{
	void *ptr = malloc(x);
	#if CODE_DEBUG
	printf("new %d %08X\n", x, (unsigned)ptr);
	#endif
	return ptr;
}

void operator delete(void *ptr)
{
	#if CODE_DEBUG
	printf("delete %08X\n", (unsigned)ptr);
	#endif
	free(ptr);
}



void *operator new[](unsigned x)
{
//	printf("new %d\n", x);
	return malloc(x);
}

void operator delete[](void *ptr)
{
//	printf("delete %08X\n", (unsigned)ptr);
	free(ptr);
}

#endif







