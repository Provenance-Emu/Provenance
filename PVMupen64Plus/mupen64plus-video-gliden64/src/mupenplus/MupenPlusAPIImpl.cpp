#include "GLideN64_mupenplus.h"
#include "../PluginAPI.h"
#include "../GLideN64.h"
#include "../Config.h"
#include <DisplayWindow.h>

#ifdef OS_WINDOWS
#define DLSYM(a, b) GetProcAddress(a, b)
#else
#include <dlfcn.h>
#define DLSYM(a, b) dlsym(a, b)
#endif // OS_WINDOWS

ptr_ConfigGetSharedDataFilepath ConfigGetSharedDataFilepath = nullptr;
ptr_ConfigGetUserConfigPath ConfigGetUserConfigPath = nullptr;
ptr_ConfigGetUserDataPath ConfigGetUserDataPath = nullptr;
ptr_ConfigGetUserCachePath ConfigGetUserCachePath = nullptr;
ptr_ConfigOpenSection      ConfigOpenSection = nullptr;
ptr_ConfigDeleteSection ConfigDeleteSection = nullptr;
ptr_ConfigSaveSection ConfigSaveSection = nullptr;
ptr_ConfigSaveFile ConfigSaveFile = nullptr;
ptr_ConfigSetDefaultInt    ConfigSetDefaultInt = nullptr;
ptr_ConfigSetDefaultFloat  ConfigSetDefaultFloat = nullptr;
ptr_ConfigSetDefaultBool   ConfigSetDefaultBool = nullptr;
ptr_ConfigSetDefaultString ConfigSetDefaultString = nullptr;
ptr_ConfigGetParamInt      ConfigGetParamInt = nullptr;
ptr_ConfigGetParamFloat    ConfigGetParamFloat = nullptr;
ptr_ConfigGetParamBool     ConfigGetParamBool = nullptr;
ptr_ConfigGetParamString   ConfigGetParamString = nullptr;
ptr_ConfigExternalGetParameter ConfigExternalGetParameter = nullptr;
ptr_ConfigExternalOpen ConfigExternalOpen = nullptr;
ptr_ConfigExternalClose ConfigExternalClose = nullptr;

/* definitions of pointers to Core video extension functions */
ptr_VidExt_Init                  CoreVideo_Init = nullptr;
ptr_VidExt_Quit                  CoreVideo_Quit = nullptr;
ptr_VidExt_ListFullscreenModes   CoreVideo_ListFullscreenModes = nullptr;
ptr_VidExt_SetVideoMode          CoreVideo_SetVideoMode = nullptr;
ptr_VidExt_SetCaption            CoreVideo_SetCaption = nullptr;
ptr_VidExt_ToggleFullScreen      CoreVideo_ToggleFullScreen = nullptr;
ptr_VidExt_ResizeWindow          CoreVideo_ResizeWindow = nullptr;
ptr_VidExt_GL_GetProcAddress     CoreVideo_GL_GetProcAddress = nullptr;
ptr_VidExt_GL_SetAttribute       CoreVideo_GL_SetAttribute = nullptr;
ptr_VidExt_GL_GetAttribute       CoreVideo_GL_GetAttribute = nullptr;
ptr_VidExt_GL_SwapBuffers        CoreVideo_GL_SwapBuffers = nullptr;

ptr_PluginGetVersion             CoreGetVersion = nullptr;

const unsigned int* rdram_size = nullptr;

void(*renderCallback)(int) = nullptr;

m64p_error PluginAPI::PluginStartup(m64p_dynlib_handle _CoreLibHandle)
{
	ConfigGetSharedDataFilepath = (ptr_ConfigGetSharedDataFilepath)	DLSYM(_CoreLibHandle, "ConfigGetSharedDataFilepath");
	ConfigGetUserConfigPath = (ptr_ConfigGetUserConfigPath)	DLSYM(_CoreLibHandle, "ConfigGetUserConfigPath");
	ConfigGetUserCachePath = (ptr_ConfigGetUserCachePath)DLSYM(_CoreLibHandle, "ConfigGetUserCachePath");
	ConfigGetUserDataPath = (ptr_ConfigGetUserDataPath)DLSYM(_CoreLibHandle, "ConfigGetUserDataPath");

	ConfigOpenSection = (ptr_ConfigOpenSection)DLSYM(_CoreLibHandle, "ConfigOpenSection");
	ConfigDeleteSection = (ptr_ConfigDeleteSection)DLSYM(_CoreLibHandle, "ConfigDeleteSection");
	ConfigSaveSection = (ptr_ConfigSaveSection)DLSYM(_CoreLibHandle, "ConfigSaveSection");
	ConfigSaveFile = (ptr_ConfigSaveFile)DLSYM(_CoreLibHandle, "ConfigSaveFile");
	ConfigSetDefaultInt = (ptr_ConfigSetDefaultInt)DLSYM(_CoreLibHandle, "ConfigSetDefaultInt");
	ConfigSetDefaultFloat = (ptr_ConfigSetDefaultFloat)DLSYM(_CoreLibHandle, "ConfigSetDefaultFloat");
	ConfigSetDefaultBool = (ptr_ConfigSetDefaultBool)DLSYM(_CoreLibHandle, "ConfigSetDefaultBool");
	ConfigSetDefaultString = (ptr_ConfigSetDefaultString)DLSYM(_CoreLibHandle, "ConfigSetDefaultString");
	ConfigGetParamInt = (ptr_ConfigGetParamInt)DLSYM(_CoreLibHandle, "ConfigGetParamInt");
	ConfigGetParamFloat = (ptr_ConfigGetParamFloat)DLSYM(_CoreLibHandle, "ConfigGetParamFloat");
	ConfigGetParamBool = (ptr_ConfigGetParamBool)DLSYM(_CoreLibHandle, "ConfigGetParamBool");
	ConfigGetParamString = (ptr_ConfigGetParamString)DLSYM(_CoreLibHandle, "ConfigGetParamString");
	ConfigExternalGetParameter = (ptr_ConfigExternalGetParameter)DLSYM(_CoreLibHandle, "ConfigExternalGetParameter");
	ConfigExternalOpen = (ptr_ConfigExternalOpen)DLSYM(_CoreLibHandle, "ConfigExternalOpen");
	ConfigExternalClose = (ptr_ConfigExternalClose)DLSYM(_CoreLibHandle, "ConfigExternalClose");

	/* Get the core Video Extension function pointers from the library handle */
	CoreVideo_Init = (ptr_VidExt_Init) DLSYM(_CoreLibHandle, "VidExt_Init");
	CoreVideo_Quit = (ptr_VidExt_Quit) DLSYM(_CoreLibHandle, "VidExt_Quit");
	CoreVideo_ListFullscreenModes = (ptr_VidExt_ListFullscreenModes) DLSYM(_CoreLibHandle, "VidExt_ListFullscreenModes");
	CoreVideo_SetVideoMode = (ptr_VidExt_SetVideoMode) DLSYM(_CoreLibHandle, "VidExt_SetVideoMode");
	CoreVideo_SetCaption = (ptr_VidExt_SetCaption) DLSYM(_CoreLibHandle, "VidExt_SetCaption");
	CoreVideo_ToggleFullScreen = (ptr_VidExt_ToggleFullScreen) DLSYM(_CoreLibHandle, "VidExt_ToggleFullScreen");
	CoreVideo_ResizeWindow = (ptr_VidExt_ResizeWindow) DLSYM(_CoreLibHandle, "VidExt_ResizeWindow");
	CoreVideo_GL_GetProcAddress = (ptr_VidExt_GL_GetProcAddress) DLSYM(_CoreLibHandle, "VidExt_GL_GetProcAddress");
	CoreVideo_GL_SetAttribute = (ptr_VidExt_GL_SetAttribute) DLSYM(_CoreLibHandle, "VidExt_GL_SetAttribute");
	CoreVideo_GL_GetAttribute = (ptr_VidExt_GL_GetAttribute) DLSYM(_CoreLibHandle, "VidExt_GL_GetAttribute");
	CoreVideo_GL_SwapBuffers = (ptr_VidExt_GL_SwapBuffers) DLSYM(_CoreLibHandle, "VidExt_GL_SwapBuffers");

	CoreGetVersion = (ptr_PluginGetVersion) DLSYM(_CoreLibHandle, "PluginGetVersion");

	if (Config_SetDefault()) {
		config.version = ConfigGetParamInt(g_configVideoGliden64, "configVersion");
		if (config.version != CONFIG_VERSION_CURRENT) {
			ConfigDeleteSection("Video-GLideN64");
			ConfigSaveFile();
			Config_SetDefault();
		}
	}
	return M64ERR_SUCCESS;
}

m64p_error PluginAPI::PluginShutdown()
{
#ifdef RSPTHREAD
	_callAPICommand(acRomClosed);
	delete m_pRspThread;
	m_pRspThread = nullptr;
#endif
	return M64ERR_SUCCESS;
}

m64p_error PluginAPI::PluginGetVersion(
	m64p_plugin_type * _PluginType,
	int * _PluginVersion,
	int * _APIVersion,
	const char ** _PluginNamePtr,
	int * _Capabilities
)
{
	/* set version info */
	if (_PluginType != nullptr)
		*_PluginType = M64PLUGIN_GFX;

	if (_PluginVersion != nullptr)
		*_PluginVersion = PLUGIN_VERSION;

	if (_APIVersion != nullptr)
		*_APIVersion = VIDEO_PLUGIN_API_VERSION;

	if (_PluginNamePtr != nullptr)
		*_PluginNamePtr = pluginName;

	if (_Capabilities != nullptr)
	{
		*_Capabilities = 0;
	}

	return M64ERR_SUCCESS;
}

void PluginAPI::SetRenderingCallback(void (*callback)(int))
{
	renderCallback = callback;
}

void PluginAPI::ResizeVideoOutput(int _Width, int _Height)
{
	dwnd().setWindowSize(_Width, _Height);
}

void PluginAPI::ReadScreen2(void * _dest, int * _width, int * _height, int _front)
{
	dwnd().readScreen2(_dest, _width, _height, _front);
}
