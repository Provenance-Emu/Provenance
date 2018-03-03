#ifndef GLIDEN64_MUPENPLUS_H
#define GLIDEN64_MUPENPLUS_H

#include "m64p_common.h"
#include "m64p_config.h"
#include "m64p_vidext.h"

#define PLUGIN_VERSION              0x020000
#define VIDEO_PLUGIN_API_VERSION	0x020200
#define CONFIG_API_VERSION          0x020000
#define VIDEXT_API_VERSION          0x030000

/* definitions of pointers to Core config functions */
extern ptr_ConfigOpenSection      ConfigOpenSection;
extern ptr_ConfigDeleteSection    ConfigDeleteSection;
extern ptr_ConfigSaveSection      ConfigSaveSection;
extern ptr_ConfigSaveFile         ConfigSaveFile;
extern ptr_ConfigSetParameter     ConfigSetParameter;
extern ptr_ConfigGetParameter     ConfigGetParameter;
extern ptr_ConfigGetParameterHelp ConfigGetParameterHelp;
extern ptr_ConfigSetDefaultInt    ConfigSetDefaultInt;
extern ptr_ConfigSetDefaultFloat  ConfigSetDefaultFloat;
extern ptr_ConfigSetDefaultBool   ConfigSetDefaultBool;
extern ptr_ConfigSetDefaultString ConfigSetDefaultString;
extern ptr_ConfigGetParamInt      ConfigGetParamInt;
extern ptr_ConfigGetParamFloat    ConfigGetParamFloat;
extern ptr_ConfigGetParamBool     ConfigGetParamBool;
extern ptr_ConfigGetParamString   ConfigGetParamString;
extern ptr_ConfigExternalGetParameter ConfigExternalGetParameter;
extern ptr_ConfigExternalOpen ConfigExternalOpen;
extern ptr_ConfigExternalClose ConfigExternalClose;

extern ptr_ConfigGetSharedDataFilepath ConfigGetSharedDataFilepath;
extern ptr_ConfigGetUserConfigPath     ConfigGetUserConfigPath;
extern ptr_ConfigGetUserDataPath       ConfigGetUserDataPath;
extern ptr_ConfigGetUserCachePath      ConfigGetUserCachePath;


extern ptr_VidExt_Init                  CoreVideo_Init;
extern ptr_VidExt_Quit                  CoreVideo_Quit;
extern ptr_VidExt_ListFullscreenModes   CoreVideo_ListFullscreenModes;
extern ptr_VidExt_SetVideoMode          CoreVideo_SetVideoMode;
extern ptr_VidExt_SetCaption            CoreVideo_SetCaption;
extern ptr_VidExt_ToggleFullScreen      CoreVideo_ToggleFullScreen;
extern ptr_VidExt_ResizeWindow          CoreVideo_ResizeWindow;
extern ptr_VidExt_GL_GetProcAddress     CoreVideo_GL_GetProcAddress;
extern ptr_VidExt_GL_SetAttribute       CoreVideo_GL_SetAttribute;
extern ptr_VidExt_GL_GetAttribute       CoreVideo_GL_GetAttribute;
extern ptr_VidExt_GL_SwapBuffers        CoreVideo_GL_SwapBuffers;

extern ptr_PluginGetVersion             CoreGetVersion;

extern const unsigned int* rdram_size;

extern void(*renderCallback)(int);

extern m64p_handle g_configVideoGeneral;
extern m64p_handle g_configVideoGliden64;
bool Config_SetDefault();

#endif // GLIDEN64_MUPENPLUS_H
