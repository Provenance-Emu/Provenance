
#include <stdio.h>
#include "libxpad.h"
#include "libxmtap.h"
#include "libpad.h"
#include "types.h"
#include "input.h"

extern "C" {
#include "hw.h"
};

static char _Input_PadBuf[INPUT_MAXPADS][256] __attribute__((aligned(64))) __attribute__ ((section (".bss")));
static Uint32 _Input_PadData[INPUT_MAXPADS];
static int _Input_bPadConnected[INPUT_MAXPADS];
static Bool _Input_bInitialized = FALSE;
static Bool _Input_bXPad = FALSE;
static Int32 _Input_nPads = 0;

static Uint8 _Input_PadPort[INPUT_MAXPADS][2]=
{
	{0,0},
	{1,0},
	{1,1},
	{1,2},
	{1,3},
};

static int _Input_GetPadState(int p, int s)
{
	if (_Input_bXPad)
		return xpadGetState(p,s);
	else
		return padGetState(p,s);

}


static void _Input_WaitPadReady(int p, int s) 
{
	int ret;
	do
    {
		ret = _Input_GetPadState(p, s);
        WaitForNextVRstart(1); 
    }  while((ret != PAD_STATE_STABLE) && (ret != PAD_STATE_FINDCTP1) &&  (ret != PAD_STATE_DISCONN)) ;
}

static int _Input_InitPad(int port, int slot, char* buffer)
{
    int ret;

	if (_Input_bXPad)
	{
		if((ret = xpadPortOpen(port, slot, buffer)) == 0) 
		{
			printf("Failed to open pad port=%d slot=%d\n", port, slot);
			return -1;
	    }

		_Input_WaitPadReady(port, slot);

		xpadExitPressMode(port, slot);

		#if 0
		xpadSetMainMode(port, slot, PAD_MMODE_DUALSHOCK, PAD_MMODE_UNLOCK);
		#else
		xpadSetMainMode(port, slot, PAD_MMODE_DIGITAL, PAD_MMODE_LOCK);
		#endif

	} else
	{
		if((ret = padPortOpen(port, slot, buffer)) == 0) 
		{
			printf("Failed to open pad port=%d slot=%d\n", port, slot);
			return -1;
	    }

		_Input_WaitPadReady(port, slot);

		#if 0
		padSetMainMode(port, slot, PAD_MMODE_DUALSHOCK, PAD_MMODE_UNLOCK);
		#else
		padSetMainMode(port, slot, PAD_MMODE_DIGITAL, PAD_MMODE_LOCK);
		#endif
	}

	_Input_WaitPadReady(port, slot);

    return 0;
}

Bool   InputIsPadConnected(Uint32 uPad)
{
	return (uPad < (Uint32)_Input_nPads) ? _Input_bPadConnected[uPad] : FALSE;
}

Uint32 InputGetPadData(Uint32 uPad)
{
	return InputIsPadConnected(uPad) ? _Input_PadData[uPad] : 0;
}


void InputInit(Bool bXLib)
{
	int iPad;

	_Input_bXPad = bXLib;

	_Input_nPads = bXLib ? INPUT_MAXPADS : 2;

	// initialize all pads
	for (iPad=0; iPad < _Input_nPads; iPad++)
	{
	    _Input_InitPad(_Input_PadPort[iPad][0], _Input_PadPort[iPad][1], _Input_PadBuf[iPad]);
	}

	_Input_bInitialized = TRUE;
}

void InputShutdown()
{
	if (_Input_bInitialized)
	{
		int iPad;
		// de-initialize all pads
		for (iPad=0; iPad < _Input_nPads; iPad++)
		{
			if (_Input_bXPad)
			{
				xpadPortClose(_Input_PadPort[iPad][0], _Input_PadPort[iPad][1]);
			} else
			{
				padPortClose(_Input_PadPort[iPad][0], _Input_PadPort[iPad][1]);
			}
		}
	}

	_Input_nPads = 0;
	_Input_bInitialized = FALSE;
}


void InputPoll()
{
	int iPad;

	if (!_Input_bInitialized)
	{
		return;
	}

	for (iPad=0; iPad < _Input_nPads; iPad++)
	{
		Uint32 uData = 0;

		if (_Input_bPadConnected[iPad])
		{
   			struct padButtonStatus padStatus; 

			if (_Input_bXPad)
				xpadRead(_Input_PadPort[iPad][0], _Input_PadPort[iPad][1], &padStatus); // port, slot, buttons
			else
				padRead(_Input_PadPort[iPad][0], _Input_PadPort[iPad][1], &padStatus); // port, slot, buttons

			uData = 0xffff ^ ((padStatus.btns[0] << 8) | padStatus.btns[1]);
			#if 0
			if (padStatus.ljoy_h < (0x80-0x30)) uData|=PAD_LEFT;
			if (padStatus.ljoy_h > (0x80+0x30)) uData|=PAD_RIGHT;
			if (padStatus.ljoy_v < (0x80-0x30)) uData|=PAD_UP;
			if (padStatus.ljoy_v > (0x80+0x30)) uData|=PAD_DOWN;
			#endif
		}

		_Input_PadData[iPad]  = uData;
	}

	for (iPad=0; iPad < _Input_nPads; iPad++)
	{
		//check controller status
		int state;

		if (_Input_bXPad)
			state = xpadGetState(_Input_PadPort[iPad][0], _Input_PadPort[iPad][1]);
		else
			state = padGetState(_Input_PadPort[iPad][0], _Input_PadPort[iPad][1]);

		if(state == PAD_STATE_STABLE || state == PAD_STATE_FINDCTP1)  
		{
			if(_Input_bPadConnected[iPad] == 0) 
			{
				printf("Input: Pad %d inserted!\n", iPad + 1);
				WaitForNextVRstart(1);
			}
			_Input_bPadConnected[iPad] = 1;
		} else 
		{
			if(_Input_bPadConnected[iPad] == 1) 
			{
				printf("Input: Pad %d removed!\n", iPad + 1);
			}
			// pad is not connected
			_Input_bPadConnected[iPad] = 0;
		}
	}
}
