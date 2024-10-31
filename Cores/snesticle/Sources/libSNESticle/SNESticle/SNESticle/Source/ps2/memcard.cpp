
#include <kernel.h>
#include <libmc.h>
#include <stdio.h>
#include <string.h>
#include <fileio.h>
#include "types.h"

#include "memcard.h"

static Uint8 _MemCard_IconData[]={
#include "memcard_icon.inc"
};

static Bool _MemCard_bInitialized=FALSE;

int MemCardCreateSave(char *pDir, char *pTitle, Bool bForceWrite)
{
	int icon_size;
	char* icon_buffer;
	mcIcon icon_sys;
	char Path[256];

	static iconIVECTOR bgcolor[4] = {
		{  68,  23, 116,  0 }, // top left
		{ 255, 255, 255,  0 }, // top right
		{ 255, 255, 255,  0 }, // bottom left
		{  68,  23, 116,  0 }, // bottom right
	};

	static iconFVECTOR lightdir[3] = {
		{ 0.5, 0.5, 0.5, 0.0 },
		{ 0.0,-0.4,-0.1, 0.0 },
		{-0.5,-0.5, 0.5, 0.0 },
	};

	static iconFVECTOR lightcol[3] = {
		{ 0.3, 0.3, 0.3, 0.00 },
		{ 0.4, 0.4, 0.4, 0.00 },
		{ 0.5, 0.5, 0.5, 0.00 },
	};

	static iconFVECTOR ambient = { 0.50, 0.50, 0.50, 0.00 };

	if(fioMkdir(pDir) < 0)
	{
		if (!bForceWrite)
		{
		 	return -1;
		}
	}

	// Set up icon.sys. This is the file which controls how our memory card save looks
	// in the PS2 browser screen. It contains info on the bg colour, lighting, save name
	// and icon filenames. Please note that the save name is sjis encoded.

	memset(&icon_sys, 0, sizeof(mcIcon));
	strcpy((char *)icon_sys.head, "PS2D");
	strcpy_sjis((short *)&icon_sys.title, pTitle);
	icon_sys.nlOffset = 16;
	icon_sys.trans = 0x60;
	memcpy(icon_sys.bgCol, bgcolor, sizeof(bgcolor));
	memcpy(icon_sys.lightDir, lightdir, sizeof(lightdir));
	memcpy(icon_sys.lightCol, lightcol, sizeof(lightcol));
	memcpy(icon_sys.lightAmbient, ambient, sizeof(ambient));
	strcpy((char *)icon_sys.view, "icon.icn"); // these filenames are relative to the directory
	strcpy((char *)icon_sys.copy, "icon.icn"); // in which icon.sys resides.
	strcpy((char *)icon_sys.del, "icon.icn");

	// Write icon.sys to the memory card (Note that this filename is fixed)
	sprintf(Path, "%s/icon.sys", pDir);
	if (!MemCardWriteFile(Path, (Uint8 *)&icon_sys, sizeof(icon_sys)))
	{
		return -5;
	}

	// get pointer to icon data
	icon_size = sizeof(_MemCard_IconData);
	icon_buffer = (char *)_MemCard_IconData;

	sprintf(Path, "%s/icon.icn", pDir);
	if (!MemCardWriteFile(Path, (Uint8 *)icon_buffer, icon_size))
	{
		return -6;
	}
	return 0;
}

Bool MemCardCheckNewCard()
{
	int mc_Type, mc_Free, mc_Format;
	int ret;

	if (!_MemCard_bInitialized) return FALSE;

	// get MC info
	mcGetInfo(0,0,&mc_Type,&mc_Free,&mc_Format);
	mcSync(0, NULL, &ret);

	#if 0
	printf("mcGetInfo returned %d\n",ret);
	printf("Type: %d Free: %d Format: %d\n\n", mc_Type, mc_Free, mc_Format);
	#endif

	// new formatted card inserted	
	if (ret == -1)
	{
		// get MC info (again)
		mcGetInfo(0,0,&mc_Type,&mc_Free,&mc_Format);
		mcSync(0, NULL, &ret);

		return TRUE;
	}
	return FALSE;
}

void MemCardInit()
{
	if(mcInit(MC_TYPE_MC) < 0) {
		printf("MemCard: Failed to initialise memcard server!\n");
	} else
	{
		printf("MemCard: Initialized\n");
		_MemCard_bInitialized = TRUE;
	}
}

Bool MemCardWriteFile(char *pPath, Uint8 *pData, Uint32 nBytes)
{
	int fd;

	if (!_MemCard_bInitialized) return FALSE;

	fd = fioOpen(pPath, O_WRONLY | O_CREAT);
	if (fd > 0)
	{
		unsigned int result;
		result = fioWrite(fd, pData, nBytes);
		fioClose(fd);
		printf("MemCard: Write %s (%d)\n", pPath, result);
		return (result == nBytes);
	}
	return FALSE;
}

Bool MemCardReadFile(char *pPath, Uint8 *pData, Uint32 nBytes)
{
	int fd;

	if (!_MemCard_bInitialized) return FALSE;

	fd = fioOpen(pPath, O_RDONLY);
	if (fd > 0)
	{
		unsigned int result;
		result = fioRead(fd, pData, nBytes);
		fioClose(fd);
		printf("MemCard: Read %s (%d)\n", pPath, result);
		return (result == nBytes);
	}
	return FALSE;
}



