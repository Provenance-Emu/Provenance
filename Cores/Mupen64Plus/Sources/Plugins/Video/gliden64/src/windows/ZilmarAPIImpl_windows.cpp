#include "GLideN64_Windows.h"
#include "../PluginAPI.h"
#include "../GLideN64.h"
#include "../GLideNUI/GLideNUI.h"
#include "../Config.h"
#include "../Revision.h"
#include <DisplayWindow.h>

void PluginAPI::DllAbout(/*HWND _hParent*/)
{
	Config_LoadConfig();
	wchar_t strIniFolderPath[PLUGIN_PATH_SIZE];
	api().FindPluginPath(strIniFolderPath);
	RunAbout(strIniFolderPath);
}

void PluginAPI::CaptureScreen(char * _Directory)
{
	dwnd().setCaptureScreen(_Directory);
}

void PluginAPI::DllConfig(HWND _hParent)
{
	Config_DoConfig(/*_hParent*/);
}

void PluginAPI::GetDllInfo(PLUGIN_INFO * PluginInfo)
{
	PluginInfo->Version = 0x103;
	PluginInfo->Type = PLUGIN_TYPE_GFX;
	sprintf(PluginInfo->Name, "%s rev.%s", pluginName, PLUGIN_REVISION);
	PluginInfo->NormalMemory = FALSE;
	PluginInfo->MemoryBswaped = TRUE;
}
