
#include <windows.h>
#include "types.h"
#include "mainloop.h"
#include "input.h"
#include "console.h"
#include "windsound.h"
#include "winddraw.h"
#include "sneswin.h"
#include "winmain.h"
#include "prof.h"

static CSnesWin *_pSnesWin= NULL;

Char *_RomFile = NULL;
//"c:/emu/snesrom/mario.smc"



Uint8 _JoyMap[8];
/*
Uint8 _KeyMap[]=
{
	0x00,		// SNESIO_JOY_R		0x0010
	0x00,		// SNESIO_JOY_L		0x0020
	0x5A,		// SNESIO_JOY_X		0x0040
	0x58,		// SNESIO_JOY_A		0x0080
	VK_RIGHT,	// SNESIO_JOY_RIGHT	0x0100
	VK_LEFT,	// SNESIO_JOY_LEFT	0x0200
	VK_DOWN,	// SNESIO_JOY_DOWN	0x0400
	VK_UP,		// SNESIO_JOY_UP	0x0800
	VK_RETURN,	// SNESIO_JOY_START	0x1000
	VK_TAB,		// SNESIO_JOY_SELECT0x2000
	0x59,		// SNESIO_JOY_Y		0x4000
	0x5B,		// SNESIO_JOY_B		0x8000
};

*/

Uint8 _KeyMap[]=
{
	'C',		// SNESIO_JOY_R		0x0010
	'D',		// SNESIO_JOY_L		0x0020
	'Z',		// SNESIO_JOY_X		0x0040
	'X',		// SNESIO_JOY_A		0x0080
	VK_RIGHT,	// SNESIO_JOY_RIGHT	0x0100
	VK_LEFT,	// SNESIO_JOY_LEFT	0x0200
	VK_DOWN,	// SNESIO_JOY_DOWN	0x0400
	VK_UP,		// SNESIO_JOY_UP	0x0800
	VK_RETURN,	// SNESIO_JOY_START	0x1000
	VK_TAB,		// SNESIO_JOY_SELECT0x2000
	'A',		// SNESIO_JOY_Y		0x4000
	'S',		// SNESIO_JOY_B		0x8000
};


void ConPuts(ConE eCon, const char *pString)
{
	//	printf("%s\n", pString);
	OutputDebugString(pString);
}


Bool MainLoopInit()
{
//	ConPrint("StateSize: %d\n", sizeof(NesStateT));
	#if PROF_ENABLED
	ProfInit(32768);
	#endif

	InputInit();
	InputSetMapping(INPUT_DEVICE_KEYBOARD0, sizeof(_KeyMap), _KeyMap);
	InputSetMapping(INPUT_DEVICE_JOYSTICK0, sizeof(_JoyMap), _JoyMap);

	_pSnesWin = new CSnesWin();
	WinMainSetWin(_pSnesWin);

	_pSnesWin->SetSize(256 * 2, 224 * 2);

	_pSnesWin->SetInput(0, InputGetDevice(INPUT_DEVICE_KEYBOARD0));
//	_pSnesWin->SetInput(0, InputGetDevice(INPUT_DEVICE_JOYSTICK0));

	if (!DDrawInit())
	{
		ConError("Unable to initialize DirectDraw");
		return FALSE;
	}
	_pSnesWin->CreateSurface();

	// init dsound
	DSoundInit(_pSnesWin->GetWnd());
#if CODE_DEBUG
//	DSoundSetFormat(44100, 16, 1, 44100 / 5);
	DSoundSetFormat(32000, 16, 2, 32000 * 2);
//	DSoundSetFormat(32000, 16, 2, 32000);
#else
	DSoundSetFormat(32000, 16, 2, 32000 / 10);
#endif

	if (_RomFile)
	_pSnesWin->LoadRom(_RomFile);

	/*
	ConDebug("SNStateCPUT		%d\n",sizeof(SNStateCPUT		));
	ConDebug("SNStatePPUT		%d\n",sizeof(SNStatePPUT		));
	ConDebug("SNStateIOT		%d\n",sizeof(SNStateIOT		    ));
	ConDebug("SNStateDMACT	%d\n",sizeof(SNStateDMACT	    ));
	ConDebug("SNStateSPCT		%d\n",sizeof(SNStateSPCT		));
	ConDebug("SNStateSPCDSPT  %d\n",sizeof(SNStateSPCDSPT     ));

*/
	return TRUE;
}

Bool MainLoopProcess()
{
	InputPoll();

	PROF_ENTER("Frame");
	_pSnesWin->Process();
	PROF_LEAVE("Frame");

	if (InputGetKey('I'))
	{
	 	ProfStartProfile(1);
	}
#if PROF_ENABLED
	ProfProcess();
#endif
	return TRUE;
}

void MainLoopShutdown()
{
	delete _pSnesWin;
	_pSnesWin = NULL;

	DSoundShutdown();
	DDrawShutdown();
	InputShutdown();

	#if PROF_ENABLED
	ProfShutdown();
	#endif
}



