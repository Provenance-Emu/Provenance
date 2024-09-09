
#include <stdio.h>
#include <string.h>
#include <sifrpc.h>
#include <loadfile.h>
#include <kernel.h>
#include <fileio.h>
#include <iopheap.h>
#include <iopcontrol.h>

#include "types.h"
#include "console.h"
#include "mainloop.h"

extern "C" {
#include "excepHandler.h"
#include "cd.h"
#include "hw.h"
};



const char *updateloader = "rom0:UDNL ";
const char *eeloadcnf = "rom0:EELOADCNF";

static char *_Main_pBootPath;
static char _Main_BootDir[256];


char *MainGetBootDir()
{
	return _Main_BootDir;
}

char *MainGetBootPath()
{
	return _Main_pBootPath;
}

void MainSetBootDir(const char *pPath)
{
	int i;
	strcpy(_Main_BootDir, pPath);

	i = strlen(_Main_BootDir);

	// search backward for start of filename
	while (i>0 
			&& _Main_BootDir[i]!='/'
			&& _Main_BootDir[i]!='\\'
			&& _Main_BootDir[i]!=':'
		) i--;

	i++;

	_Main_BootDir[i] = 0;
}

/* Reset the IOP and all of its subsystems.  */
int full_reset()
{
	char imgcmd[64];
	int fd;


	/* The CDVD must be initialized here (before shutdown) or else the PS2
	   could hang on reboot.  I'm not sure why this happens.  */
	if (cdvdInit(CDVD_INIT_NOWAIT) < 0)
		return -1;

	/* Here we detect which IOP image we want to reset with.  Older Japanese
	   models don't have EELOADCNF, so we fall back on the default image
	   if necessary.  */
	*imgcmd = '\0';

	if ((fd = fioOpen(eeloadcnf, O_RDONLY)) >= 0) {
		fioClose(fd);

		strcpy(imgcmd, updateloader);
		strcat(imgcmd, eeloadcnf);
	}
//	scr_printf("rebooting with imgcmd '%s'\n", *imgcmd ? imgcmd : "(null)");

	if (cdvdInit(CDVD_EXIT) < 0)
		return -1;

//	scr_printf("Shutting down subsystems.\n");

	cdvdExit();
	fioExit();
	SifExitIopHeap();
	SifLoadFileExit();
	SifExitRpc();

	SifIopReset(imgcmd, 0);
	while (!SifIopSync()) ;

	SifInitRpc(0);
	FlushCache(0);

	// initialize cdvd
//    cdvdInit(CDVD_INIT_NOWAIT);

	return 0;
}








/* Your program's main entry point */
int main(int argc, char **argv) 
{
    int iArg;
//    init_scr();

	if (argc>=1)
	{
		_Main_pBootPath = argv[0];
	}

	MainSetBootDir(_Main_pBootPath);

	SifInitRpc(0);

	if (_Main_pBootPath[0]=='m' && _Main_pBootPath[1]=='c')
	{
//		installExceptionHandlers();

		// reset if loaded from memory card
		full_reset();
	}

	// initialize cdvd
    cdvdInit(CDVD_INIT_NOWAIT);

    for (iArg=0; iArg < argc; iArg++)
    {
        printf("%d: %s\n", iArg, argv[iArg]);
    }

	DmaReset();

    install_VRstart_handler();

	ConInit();

	if (MainLoopInit())
	{
		// do stuff here
		while (MainLoopProcess())
		{
		}

		MainLoopShutdown();
	}

	ConShutdown();

	return 0;
}

