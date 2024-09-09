
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include <commdlg.h>
#include "System/types.h"
#include "console.h"
#include "dataio.h"
#include "sneswin.h"
#include "winddraw.h"
#include "windsound.h"
#include "resource\resource.h"
#include "winmain.h"
#include "bmpfile.h"
#include "path.h"
#include "file.h"
#include "inputdevice.h"
#include "snesmemview.h"
#include "snppucolor.h"
#include "emumovie.h"
#include "sndebug.h"
#include "sncpu_c.h"
#include "snspc_c.h"

static Char _SnesWin_ClassName[]="SNESticleClass";
static Char _SnesWin_AppName[]="SNESticle";

//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////



//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////


Emu::MovieClip *s_pMovieClip;


//
//
//
typedef Uint8 (*ReadByteFuncPtrT)(void *pUserData, Uint32 Addr);

static Uint8 _ReadByteCPU(void *pUserData, Uint32 Addr)
{
	SNCpuT *pCPU = (SNCpuT *)pUserData;
	return SNCPUPeek8(pCPU, Addr);
}

static Uint8 _ReadByteSPC(void *pUserData, Uint32 Addr)
{
	SNSpcT *pSPC = (SNSpcT *)pUserData;
	return SNSPCPeek8(pSPC, Addr);
}


static Uint8 _ReadBytePPU(void *pUserData, Uint32 Addr)
{
	SnesPPU *pPPU = (SnesPPU *)pUserData;
	return *pPPU->GetVramPtr(Addr>>1) >> ((Addr&1)<<3);
}


static Bool _DumpMem(Char *pPath, ReadByteFuncPtrT pFunc, void *pUserData, Uint32 Addr, Uint32 EndAddr)
{
	FILE *pFile;
	pFile = fopen(pPath, "wb");
	if (pFile)
	{
		while (Addr < EndAddr)
		{
			fputc(pFunc(pUserData, Addr), pFile);
			Addr++;
		}
		fclose(pFile);
		return TRUE;
	}
	return FALSE;
}



//
//
//


void CSnesWin::OnPaint()
{
	// get client rect
	RECT DestRect;

	GetClientRect(GetWnd(), &DestRect);
	DestRect.bottom -= GetStatusHeight();

	ClientToScreen(GetWnd(), (LPPOINT)&DestRect.left);
	ClientToScreen(GetWnd(), (LPPOINT)&DestRect.right);

	DDrawBltFrame(&DestRect, &m_DDSurface);
}

void CSnesWin::OnMenuCommand(Uint32 uCmd)
{
	switch (uCmd)
	{
	case ID_FILE_EXIT:
		Destroy();
		break;

	case ID_EMU_RESET:
		Reset();
		break;

	case ID_EMU_SOFTRESET:
		SoftReset();
		break;

	case ID_EMU_SAVESTATE:
		SaveState();
		break;

	case ID_EMU_RESTORESTATE:
		RestoreState();
		break;

    case ID_EMU_PLAYMOVIE:
        // stop recording if we are recording
        if (s_pMovieClip->IsRecording())
        {
            s_pMovieClip->RecordEnd();
        }
        // stop playing if we are playing
        if (s_pMovieClip->IsPlaying())
        {
            s_pMovieClip->PlayEnd();
        }

        if (m_Rom.IsLoaded())
        {
            s_pMovieClip->PlayBegin(&m_Snes);
            ConPrint("Movie: Play Begin\n");
        }
        break;

    case ID_EMU_RECORDMOVIE:
        // stop recording if we are recording
        if (s_pMovieClip->IsRecording())
        {
            s_pMovieClip->RecordEnd();
        }
        // stop playing if we are playing
        if (s_pMovieClip->IsPlaying())
        {
            s_pMovieClip->PlayEnd();
        }

        if (m_Rom.IsLoaded())
        {
            s_pMovieClip->RecordBegin(&m_Snes);
            ConPrint("Movie: Record Begin\n");
        }
        break;

    case ID_EMU_STOPMOVIE:
        // stop recording if we are recording
        if (s_pMovieClip->IsRecording())
        {
            s_pMovieClip->RecordEnd();
            ConPrint("Movie: Recording Stopped\n");
        }
        // stop recording if we are recording
        if (s_pMovieClip->IsPlaying())
        {
            s_pMovieClip->PlayEnd();
            ConPrint("Movie: Playing Stopped\n");
        }
        break;


	case ID_EMU_DUMPCPUMEM:
		DumpCPUMem();
		break;

	case ID_EMU_DUMPPPUMEM:
		DumpPPUMem();
		break;

	case ID_DUMP_SPCMEM:
		DumpSPCMem();
		break;

	
	case ID_FILE_SCREENSHOT:
		ScreenShot();
		break;

	case ID_FILE_OPENROM:
		OpenRomDlg();
		break;

	case ID_FILE_CLOSEROM:
		FreeRom();
		break;

	case ID_EMU_PAUSE:
		Pause();
		break;

	case ID_DISASM_CPUMEMORY:
		DisasmCPUMemory();
		break;

	case ID_DISASM_SPCMEMORY:
		DisasmSPCMemory();
		break;

	case ID_VIEW_MEMORY:
		{
			CSnesMemView *pView;
			pView = new CSnesMemView();
			pView->SetView(&m_Snes, &m_Rom,  SNESMEMVIEW_CPU);
		}
		break;

		/*

	case ID_VIEW_DISASM:
		{
			CNesDisasmView *pView;
			pView = new CNesDisasmView();
			pView->SetView(&m_Snes);
		}
		break;
*/
	case ID_VIEW_CONSOLE:
		AllocConsole();
		break;

		/*
	case ID_VIEW_STATUSBAR:
		if (HasStatusBar())
		{
			DestroyStatusBar();
		} else
		{
			CreateStatusBar();
		}
		break;
		*/
	
	case ID_EMU_STEPFRAME:
		StepFrame();
		break;

	case ID_HELP_ABOUT:
		break;
	}
}

void CSnesWin::StepFrame()
{
	m_eState = SNESWIN_STATE_STEPFRAME;
}

void CSnesWin::Pause()
{
	if (m_eState == SNESWIN_STATE_RUN)
	{
		ConPrint("SNES Paused\n");
		m_eState = SNESWIN_STATE_PAUSED;
	}
	else
	if (m_eState == SNESWIN_STATE_PAUSED)
	{
		ConPrint("SNES Resumed\n");
		m_eState = SNESWIN_STATE_RUN;
	}
}

void CSnesWin::SetActive(Bool bActive)
{
	CGepWin::SetActive(bActive);
	//DSoundSetMixer(bActive ?  &m_Mixer : NULL);
}

static SNPPUColorCalibT _ColorCalib =
{
	0.9f,
	15.0f,
	0.2f
};

CSnesWin::CSnesWin()
{
	Create(_SnesWin_ClassName, _SnesWin_AppName, WS_OVERLAPPEDWINDOW & (~WS_SIZEBOX) & (~WS_MAXIMIZEBOX), MAKEINTRESOURCE(IDR_MENU1));
	CreateStatusBar();

	WinMainSetAccelerator(LoadAccelerators(WinMainGetInstance(), MAKEINTRESOURCE(IDR_ACCELERATOR1)));

	strcpy(m_DirState, "");
	strcpy(this->m_DirRom, "");
	strcpy(this->m_DirDump, "");
	strcpy(this->m_DirScreenshot, "");
	strcpy(this->m_DirState, "");

	m_pDevice[0] = NULL;
	m_pDevice[1] = NULL;
	m_pDevice[2] = NULL;
	m_pDevice[3] = NULL;
	m_pDevice[4] = NULL;
	
	m_Snes.Reset();
	m_eState = SNESWIN_STATE_IDLE;

	SNPPUColorCalibrate(&_ColorCalib);

	s_pMovieClip = new Emu::MovieClip(m_Snes.GetStateSize(), 60 * 60 * 60);
}

CSnesWin::~CSnesWin()
{
	FreeRom();

    delete s_pMovieClip;
}

void CSnesWin::CreateMixer()
{
//	DSoundSetMixer(&m_Mixer);

//	m_Mixer.SetVolume(0);
}


void CSnesWin::CreateSurface()
{
	DDrawSetWindowed(GetWnd(), 0);

	m_DDSurface.Alloc(256, 224, DDrawGetPixelFormat());
	m_DDSurface.SetLineOffset(0);
	m_DDSurface.Clear();

//	UpdatePalette();
}



void CSnesWin::SetInput(Int32 iPort, CInputDevice *pDevice)
{
	m_pDevice[iPort] = pDevice;
}



void CSnesWin::ReadInput(Emu::SysInputT *pInput)
{
	Int32 iDevice;

	// read bits from all devices
	for (iDevice=0; iDevice < SNESIO_DEVICE_NUM; iDevice++)
	{
		Uint32 Bits;

		if (m_pDevice[iDevice])
		{
			 Bits= m_pDevice[iDevice]->GetBits();

	//		if (Bits) ConDebug("%02X\n", Bits);

			Bits<<=4;
		
			if (Bits & SNESIO_JOY_LEFT)
			{
				Bits &= ~SNESIO_JOY_RIGHT;
			}

			if (Bits & SNESIO_JOY_DOWN)
			{
				Bits &= ~SNESIO_JOY_UP;
			}
		} else
		{
			// not connected
			Bits = EMUSYS_DEVICE_DISCONNECTED;
		}

		pInput->uPad[iDevice] = Bits;
	}
}
static SnesStateT _TestState[3];

int SNSPCExecute_9X(SNSpcT *pSpc);

int SNCPUExecute_9X(SNCpuT *pCpu);

Bool g_bStateDebug = FALSE;


//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////






void CSnesWin::Process()
{
	if (m_Rom.IsLoaded())
	{
		if (m_eState == SNESWIN_STATE_RUN || m_eState== SNESWIN_STATE_STEPFRAME)
		{
			Emu::SysInputT Input;
			CMixBuffer *pMixBuffer = NULL;

			ReadInput(&Input);

            if (s_pMovieClip->IsPlaying())
            {
                if (!s_pMovieClip->PlayFrame(Input))
                {
                    s_pMovieClip->PlayEnd();
                    ConPrint("Movie: Play End\n");
                }
            }

            if (s_pMovieClip->IsRecording())
            {
                if (!s_pMovieClip->RecordFrame(Input))
                {
                    s_pMovieClip->RecordEnd();
                    ConPrint("Movie: Reached end of record buffer!\n");
                }
            }

            
            if (m_WavFile.IsOpen())
			{
				pMixBuffer = &m_WavFile;
			} else
			{
				pMixBuffer =  DSoundGetBuffer();
			}
			//pMixBuffer = NULL;

			#if 0
			SNCPUSetExecuteFunc(SNCPUExecute_C);
			//SNSPCSetExecuteFunc(SNSPCExecute_C);
			
			SNSPCSetExecuteFunc(SNSPCExecute_C);
			m_Snes.SaveState(&_TestState[0]);
			m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC);
			m_Snes.SaveState(&_TestState[1]);

			SNSPCSetExecuteFunc(SNSPCExecute_9X);
			m_Snes.RestoreState(&_TestState[0]);
			m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC);
			m_Snes.SaveState(&_TestState[2]);

			if (memcmp(&_TestState[1], &_TestState[2],sizeof(SnesStateT)))
			{
				ConDebug("State fault\n");
				SNStateCompare(&_TestState[1], &_TestState[2]);

				g_bStateDebug = TRUE;
				ConRedirect(CON_DEBUG, "snspc_c.log");
				SNSPCSetDebug(TRUE, 10000000);
				SNSPCSetExecuteFunc(SNSPCExecute_C);
				m_Snes.RestoreState(&_TestState[0]);
				m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC);
				m_Snes.SaveState(&_TestState[1]);
				ConRedirect(CON_DEBUG, NULL);

				SNSPCSetExecuteFunc(SNSPCExecute_9X);
				ConRedirect(CON_DEBUG, "snspc_9x.log");
				m_Snes.RestoreState(&_TestState[0]);
				m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC);
				m_Snes.SaveState(&_TestState[2]);
				g_bStateDebug = FALSE;
				SNSPCSetDebug(FALSE, 0);
				ConRedirect(CON_DEBUG, NULL);

				SNStateCompare(&_TestState[1], &_TestState[2]);
			}
			#elif 0
		
			SNSPCSetExecuteFunc(SNSPCExecute_C);
			SNCPUSetExecuteFunc(SNCPUExecute_C);
			m_Snes.SaveState(&_TestState[0]);
			m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC );
			m_Snes.SaveState(&_TestState[1]);

			SNCPUSetExecuteFunc(SNCPUExecute_C);
			m_Snes.RestoreState(&_TestState[0]);
			m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC);
			m_Snes.SaveState(&_TestState[2]);

			if (memcmp(&_TestState[1], &_TestState[2],sizeof(SnesStateT)))
			{
				ConDebug("State fault\n");
				SNStateCompare(&_TestState[1], &_TestState[2]);

				g_bStateDebug = TRUE;
				ConRedirect(CON_DEBUG, "sncpu_c.log");
				SNCPUSetDebug(TRUE, 1);
				SNCPUSetExecuteFunc(SNCPUExecute_C);
				m_Snes.RestoreState(&_TestState[0]);
				m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC);
				m_Snes.SaveState(&_TestState[1]);
				ConRedirect(CON_DEBUG, NULL);

				SNCPUSetExecuteFunc(SNCPUExecute_C);
				ConRedirect(CON_DEBUG, "sncpu_9x.log");
				m_Snes.RestoreState(&_TestState[0]);
				m_Snes.ExecuteFrame(&Input, &m_DDSurface, NULL, Emu::System::MODE_INACCURATEDETERMINISTIC);
				m_Snes.SaveState(&_TestState[2]);
				g_bStateDebug = FALSE;
				SNCPUSetDebug(FALSE, 0);
				ConRedirect(CON_DEBUG, NULL);

				SNStateCompare(&_TestState[1], &_TestState[2]);
				
			}
			#else
			//pMixBuffer=NULL;
			SNCPUSetExecuteFunc(SNCPUExecute_C);
 	//	SNCPUSetExecuteFunc(SNCPUExecute_9X);
			SNSPCSetExecuteFunc(SNSPCExecute_C);
			//SNSPCSetExecuteFunc(SNSPCExecute_9X);
			m_Snes.ExecuteFrame(&Input, &m_DDSurface, pMixBuffer, Emu::System::MODE_ACCURATENONDETERMINISTIC);
			#endif


			if (m_eState == SNESWIN_STATE_STEPFRAME)
			{
#if CODE_DEBUG
                ConPrint("Frame: %d\n", m_Snes.GetFrame());
#endif

				m_eState = SNESWIN_STATE_PAUSED;
			}

#if !CODE_DEBUG
			DDrawWaitVBlank();
#endif
			OnPaint();
		}
	}

}

void CSnesWin::ScreenShot()
{
	// write frame to file
	Char Path[PATH_MAX];

	if (m_Rom.IsLoaded())
	{
		do
		{
			char name[256];
			// create file name
			sprintf(name, "%s%03d", m_Name, m_uScreenShot);

			m_uScreenShot++;

			// resolve path
			PathResolve(Path, name, m_DirScreenshot, ".bmp");
		} while(FileExists(Path));

		BMPWriteFile(Path, &m_DDSurface, NULL);

		ConPrint("Screenshot saved to %s\n", Path);
	}
}




Bool CSnesWin::LoadRom(char *pFilePath)
{
	Char Path[PATH_MAX];
	Char Ext[256];
	Char Title[256];
	Emu::Rom::LoadErrorE  eRomError;
	CFileIO FileIO;

	FreeRom();

	// resolve path
	PathResolve(Path, pFilePath, m_DirRom, ".smc");

	PathGetFileExt(Ext, Path);

	if (!FileIO.Open(Path, "rb"))
	{
		ConError("ERROR: Cannot open rom file '%s'\n", Path);
		return FALSE;
	}

	eRomError = m_Rom.LoadRom(&FileIO);
	if (eRomError != Emu::Rom::LOADERROR_NONE)
	{
		ConError("ERROR: Cannot load rom %s (error %d)\n", Path, eRomError);
		return FALSE;
	}

	FileIO.Close();

	// set rom
	m_Snes.SetRom(&m_Rom);

	// get rom name
	PathGetFileName(m_Name, Path);

	//ConPrint("ROM Loaded: %s %dK PRG - %dK CHR\n", m_Name, m_Rom.m_Prg.GetSize() / 1024, m_Rom.m_Chr.GetSize() / 1024);
	ConPrint("ROM Loaded: %s\n", m_Name);


	// set window title
	sprintf(Title, "%s - %s", m_Name, _SnesWin_AppName);
	SetTitle(Title);

	m_Snes.Reset();
	//m_Mixer.Reset();
	//DSoundSetMixer(&m_Mixer);

	m_uScreenShot = 0;
	m_eState = SNESWIN_STATE_RUN;
	//m_eState = SNESWIN_STATE_PAUSED;

	//m_WavFile.Open("snes.wav", 32000, 16, 2);
//	m_MixConvert.SetOutput(DSoundGetBuffer());
//	m_MixConvert.SetSampleRate(32000);

	//ConRedirect(CON_DEBUG, "spcio.log");


	LoadBRAM();

    CPath path;

    path.SetPath(Path);
    path.SetExt(".log");

#if SNES_DEBUG
    SnesDebugEnd();
    SnesDebugBegin(&m_Snes, path.GetPath());
#endif
    
	return TRUE;
}


void CSnesWin::FreeRom()
{
#if SNES_DEBUG
    SnesDebugEnd();
#endif

    SaveBRAM();

	m_WavFile.Close();

	m_Snes.SetRom(NULL);
	m_Rom.Unload();
	m_DDSurface.Clear();

	//m_Mixer.Reset();
	//DSoundSetMixer(NULL);

	// set window title
	SetTitle(_SnesWin_AppName);

	SetName("");
	m_eState = SNESWIN_STATE_IDLE;
}


void CSnesWin::OpenRomDlg()
{
	OPENFILENAME ofn;
	char szFile[260];       // buffer for filename

	szFile[0]=0;

	// Initialize OPENFILENAME
	ZeroMemory(&ofn, sizeof(OPENFILENAME));
	ofn.lStructSize = sizeof(OPENFILENAME);
	ofn.hwndOwner = GetWnd();
	ofn.lpstrFile = szFile;
	ofn.nMaxFile = sizeof(szFile);
	ofn.lpstrFilter = "SNES Roms\0*.SMC;*.FIG\0";
	ofn.nFilterIndex = 1;
	ofn.lpstrFileTitle = NULL;
	ofn.nMaxFileTitle = 0;
	ofn.lpstrInitialDir = NULL;
	ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

	// Display the Open dialog box. 
	if (GetOpenFileName(&ofn)) 
	{
		LoadRom(ofn.lpstrFile);
	} 
}


void CSnesWin::DumpCPUMem()
{
	Char Path[PATH_MAX];

	PathResolve(Path, m_Name, m_DirDump, ".cpu.bin");

	if (_DumpMem(Path, _ReadByteCPU, m_Snes.GetCpu(), 0x000000, 0x1000000))
	{
		ConPrint("CPU Mem dumped to %s\n", Path);
	}
}


void CSnesWin::DumpPPUMem()
{
	Char Path[PATH_MAX];

	PathResolve(Path, m_Name, m_DirDump, ".ppu.bin");

	if (_DumpMem(Path, _ReadBytePPU, m_Snes.GetPPU(), 0x0000, 0x10000))
	{
		ConPrint("PPU Mem dumped to %s\n", Path);
	}
}


void CSnesWin::DumpSPCMem()
{
	Char Path[PATH_MAX];

	PathResolve(Path, m_Name, m_DirDump, ".spc.bin");

	if (_DumpMem(Path, _ReadByteSPC, m_Snes.GetSpc(), 0x0000, 0x10000))
	{
		ConPrint("SPC Mem dumped to %s\n", Path);
	}
}


void CSnesWin::SaveBRAM()
{
	if (m_Rom.IsLoaded() && m_Rom.GetSRAMBytes() > 0)
	{
		Char Path[PATH_MAX];
		Uint8 *pSRAM;

		pSRAM = m_Snes.GetSRAM();

		PathResolve(Path, m_Name, m_DirDump, ".srm");

		if (FileWriteMem(Path, pSRAM, m_Rom.GetSRAMBytes()))
		{
			ConPrint("SRAM saved: %s\n", Path);
		}
	}
}

void CSnesWin::LoadBRAM()
{
	if (m_Rom.IsLoaded() && m_Rom.GetSRAMBytes() > 0)
	{
		Char Path[PATH_MAX];
		Uint8 *pSRAM;

		pSRAM = m_Snes.GetSRAM();

		PathResolve(Path, m_Name, m_DirDump, ".srm");

		if (FileReadMem(Path, pSRAM, m_Rom.GetSRAMBytes()))
		{
			ConPrint("SRAM loaded: %s\n", Path);
		}
	}
}




static Uint32 _DisasmCPU(FILE *pFile, SNCpuT *pCpu, Uint32 uAddr, Uint8 *pFlags)
{
	Uint8 Opcode[4];
	Char Str[256];
	Int32 nBytes;
	Int32 iByte;

	// read memory
	SNCPUPeekMem(pCpu, uAddr, Opcode, sizeof(Opcode));

	// disassemble
	nBytes = SNDisasm(Str, Opcode, uAddr, pFlags);

	fprintf(pFile, "%06X: ", uAddr);
	//printf("%02X ", uFlags);

	for (iByte=0; iByte < nBytes; iByte++)
	{
		fprintf(pFile,"%02X ", Opcode[iByte]);
	}

	for (; iByte < 4; iByte++)
	{
		fprintf(pFile, "   ");
	}

	fprintf(pFile, "%c ", (uAddr == pCpu->Regs.rPC) ? '>' : ' ');

	fprintf(pFile, "%s\n", Str);

	return nBytes;
}


void CSnesWin::DisasmCPUMemory()
{
	FILE *pFile;
	Char Path[PATH_MAX];

	PathResolve(Path, m_Name, m_DirDump, ".cpu.asm");

	pFile = fopen(Path, "wt");
	if (pFile)
	{
		Uint32 Addr;
		SNCpuT *pCPU;
		Uint8 Flags = 0xFF;

		pCPU = m_Snes.GetCpu();

		for (Addr=0xC00000; Addr < 0xD00000; )
		{
			Addr += _DisasmCPU(pFile, pCPU, Addr + 0x000000, &Flags);
		}
		fclose(pFile);

		ConPrint("CPU Mem disasm to %s\n", Path);
	}
}




static Uint32 _DisasmSPC(FILE *pFile, SNSpcT *pCpu, Uint32 uAddr)
{
	Uint8 Opcode[4];
	Char Str[256];
	Int32 nBytes;
	Int32 iByte;

	// read memory
	SNSPCPeekMem(pCpu, uAddr, Opcode, sizeof(Opcode));

	// disassemble
	nBytes = SNSPCDisasm(Str, Opcode, uAddr);

	fprintf(pFile, "%06X: ", uAddr);
	//printf("%02X ", uFlags);

	for (iByte=0; iByte < nBytes; iByte++)
	{
		fprintf(pFile,"%02X ", Opcode[iByte]);
	}

	for (; iByte < 4; iByte++)
	{
		fprintf(pFile, "   ");
	}

	fprintf(pFile, "%c ", (uAddr == pCpu->Regs.rPC) ? '>' : ' ');

	fprintf(pFile, "%s\n", Str);

	return nBytes;
}


void CSnesWin::DisasmSPCMemory()
{
	FILE *pFile;
	Char Path[PATH_MAX];

	PathResolve(Path, m_Name, m_DirDump, ".spc.asm");

	pFile = fopen(Path, "wt");
	if (pFile)
	{
		Uint32 Addr;
		SNSpcT *pCPU;

		pCPU = m_Snes.GetSpc();

		for (Addr=0; Addr < 0x10000; )
		{
			Addr += _DisasmSPC(pFile, pCPU, Addr);
		}
		fclose(pFile);

		ConPrint("SPC Mem disasm to %s\n", Path);
	}
}


void CSnesWin::SaveState()
{
	Char Path[PATH_MAX];

	if (m_Rom.IsLoaded())
	{
		PathResolve(Path, m_Name, m_DirState, ".sns");

		m_Snes.SaveState(&m_State);

		if (FileWriteMem(Path, &m_State, sizeof(m_State)))
		{
			ConPrint("State saved to %s\n", Path);
		}
	}
}

void CSnesWin::RestoreState()
{
	Char Path[PATH_MAX];

	if (m_Rom.IsLoaded())
	{
		PathResolve(Path, m_Name, m_DirState, ".sns");

		if (FileReadMem(Path, &m_State, sizeof(m_State)))
		{
			m_Snes.RestoreState(&m_State);

			ConPrint("State loaded from %s\n", Path);
		}
	}
}


void CSnesWin::Reset()
{
	if (m_Rom.IsLoaded())
	{
		SaveBRAM();
		m_Snes.Reset();
		ConPrint("SNES Reset\n");
		LoadBRAM();
	}
}

void CSnesWin::SoftReset()
{
	if (m_Rom.IsLoaded())
	{
		m_Snes.SoftReset();
		ConPrint("SNES Reset (soft)\n");
	}
}

void CSnesWin::SetName(Char *pName)
{
	strcpy(m_Name, pName);
}


void CSnesWin::OnDestroy()
{
	PostQuitMessage (0) ;
}



void CSnesWin::PathResolve(char *pOutPath, const Char *pFilePath, const Char *pDir, const Char *pExt)
{
	CPath path;

	path.SetPath(pFilePath);

	if (!path.HasDir())
	{
		path.SetDir(pDir);
	}

	if (!path.HasExt() && pExt)
	{
		path.SetExt(pExt);
	}

	strcpy(pOutPath, path.GetPath());
}

