#include <algorithm>
#include <string>
#include "GLideN64_Windows.h"
#include <commctrl.h>
#include "../PluginAPI.h"
#include "../RSP.h"

#ifdef OS_WINDOWS
EXTERN_C IMAGE_DOS_HEADER __ImageBase;
#endif

BOOL CALLBACK FindToolBarProc( HWND _hWnd, LPARAM lParam )
{
	if (GetWindowLong( _hWnd, GWL_STYLE ) & RBS_VARHEIGHT) {
		hToolBar = _hWnd;
		return FALSE;
	}
	return TRUE;
}

int PluginAPI::InitiateGFX(const GFX_INFO & _gfxInfo)
{
	_initiateGFX(_gfxInfo);

	hWnd = _gfxInfo.hWnd;
	hStatusBar = _gfxInfo.hStatusBar;
	hToolBar = NULL;

	EnumChildWindows( hWnd, FindToolBarProc, 0 );
	return TRUE;
}

void PluginAPI::FindPluginPath(wchar_t * _strPath)
{
	if (_strPath == NULL)
		return;
	::GetModuleFileName((HINSTANCE)&__ImageBase, _strPath, PLUGIN_PATH_SIZE);
	std::wstring pluginPath(_strPath);
	std::replace(pluginPath.begin(), pluginPath.end(), L'\\', L'/');
	std::wstring::size_type pos = pluginPath.find_last_of(L"/");
	wcscpy(_strPath, pluginPath.substr(0, pos).c_str());
}

void PluginAPI::GetUserDataPath(wchar_t * _strPath)
{
	FindPluginPath(_strPath);
}

void PluginAPI::GetUserCachePath(wchar_t * _strPath)
{
	FindPluginPath(_strPath);
}
