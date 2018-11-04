// nullGDR.cpp : Defines the entry point for the DLL application.
//

#include "ImgReader.h"
//Get a copy of the operators for structs ... ugly , but works :)
#include "common.h"

void GetSessionInfo(u8* out,u8 ses);

void libGDR_ReadSubChannel(u8 * buff, u32 format, u32 len)
{
	if (format==0)
	{
		memcpy(buff,q_subchannel,len);
	}
}

void libGDR_ReadSector(u8 * buff,u32 StartSector,u32 SectorCount,u32 secsz)
{
	GetDriveSector(buff,StartSector,SectorCount,secsz);
	//if (CurrDrive)
	//	CurrDrive->ReadSector(buff,StartSector,SectorCount,secsz);
}

void libGDR_GetToc(u32* toc,u32 area)
{
	GetDriveToc(toc,(DiskArea)area);
}
//TODO : fix up
u32 libGDR_GetDiscType()
{
	if (disc)
		return disc->type;
	else
		return NullDriveDiscType;
}

void libGDR_GetSessionInfo(u8* out,u8 ses)
{
	GetDriveSessionInfo(out,ses);
}
/*
void EXPORT_CALL handle_SwitchDisc(u32 id,void* w,void* p)
{
	//msgboxf("This feature is not yet implemented",MB_ICONWARNING);
	//return;
	TermDrive();
	
	NullDriveDiscType=Busy;
	DriveNotifyEvent(DiskChange,0);
	Sleep(150);	//busy for a bit

	NullDriveDiscType=Open;
	DriveNotifyEvent(DiskChange,0);
	Sleep(150); //tray is open

	while(!InitDrive(2))//no "cancel"
		msgboxf("Init Drive failed, disc must be valid for swap",0x00000010L);

	DriveNotifyEvent(DiskChange,0);
	//new disc is in
}
*/
//It's supposed to reset everything (if not a manual reset)
void libGDR_Reset(bool Manual)
{
	libCore_gdrom_disc_change();
}

//called when entering sh4 thread , from the new thread context (for any thread specific init)
s32 libGDR_Init()
{
	if (!InitDrive())
		return rv_serror;
	libCore_gdrom_disc_change();
	LoadSettings();
	settings.imgread.PatchRegion=true;
	return rv_ok;
}

//called when exiting from sh4 thread , from the new thread context (for any thread specific init) :P
void libGDR_Term()
{
	TermDrive();
}
