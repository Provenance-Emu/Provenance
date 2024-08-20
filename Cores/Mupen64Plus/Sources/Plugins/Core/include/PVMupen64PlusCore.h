#ifndef _PVMupen64PlusCore_h_
#define _PVMupen64PlusCore_h_

//typedef enum {
//  M64EMU_STOPPED = 1,
//  M64EMU_RUNNING,
//  M64EMU_PAUSED
//} m64p_emu_state;
//
//typedef enum {
//  M64CORE_EMU_STATE = 1,
//  M64CORE_VIDEO_MODE,
//  M64CORE_SAVESTATE_SLOT,
//  M64CORE_SPEED_FACTOR,
//  M64CORE_SPEED_LIMITER,
//  M64CORE_VIDEO_SIZE,
//  M64CORE_AUDIO_VOLUME,
//  M64CORE_AUDIO_MUTE,
//  M64CORE_INPUT_GAMESHARK,
//  M64CORE_STATE_LOADCOMPLETE,
//  M64CORE_STATE_SAVECOMPLETE
//} m64p_core_param;
//
//typedef void * m64p_handle;

//#include "../Core/src/api/m64p_types.h"
#include "m64p_types.h"
#include "m64p_frontend.h"

//#include "../Core/src/api/config.h"
//#include "../Core/src/api/m64p_common.h"
//#include "../Core/src/api/m64p_config.h"
//#include "../Core/src/api/m64p_frontend.h"
//#include "../Core/src/api/m64p_vidext.h"
//#include "../Core/src/api/callbacks.h"
//#include "../Core/src/osal/dynamiclib.h"
//#include "../Core/src/Plugins/Core/src/main/version.h"
//#include "../Core/src/plugin/plugin.h"

/*** Controller plugin's ****/
#define PLUGIN_NONE                 1
#define PLUGIN_MEMPAK               2
#define PLUGIN_RUMBLE_PAK           3 /* not implemented for non raw data */
#define PLUGIN_TRANSFER_PAK         4 /* not implemented for non raw data */
#define PLUGIN_RAW                  5 /* the controller plugin is passed in raw data */

/***** Structures *****/
typedef struct {
    unsigned char * RDRAM;
    unsigned char * DMEM;
    unsigned char * IMEM;

    unsigned int * MI_INTR_REG;

    unsigned int * SP_MEM_ADDR_REG;
    unsigned int * SP_DRAM_ADDR_REG;
    unsigned int * SP_RD_LEN_REG;
    unsigned int * SP_WR_LEN_REG;
    unsigned int * SP_STATUS_REG;
    unsigned int * SP_DMA_FULL_REG;
    unsigned int * SP_DMA_BUSY_REG;
    unsigned int * SP_PC_REG;
    unsigned int * SP_SEMAPHORE_REG;

    unsigned int * DPC_START_REG;
    unsigned int * DPC_END_REG;
    unsigned int * DPC_CURRENT_REG;
    unsigned int * DPC_STATUS_REG;
    unsigned int * DPC_CLOCK_REG;
    unsigned int * DPC_BUFBUSY_REG;
    unsigned int * DPC_PIPEBUSY_REG;
    unsigned int * DPC_TMEM_REG;

    void (*CheckInterrupts)(void);
    void (*ProcessDlistList)(void);
    void (*ProcessAlistList)(void);
    void (*ProcessRdpList)(void);
    void (*ShowCFB)(void);
} RSP_INFO;

typedef struct {
    unsigned char * HEADER;  /* This is the rom header (first 40h bytes of the rom) */
    unsigned char * RDRAM;
    unsigned char * DMEM;
    unsigned char * IMEM;

    unsigned int * MI_INTR_REG;

    unsigned int * DPC_START_REG;
    unsigned int * DPC_END_REG;
    unsigned int * DPC_CURRENT_REG;
    unsigned int * DPC_STATUS_REG;
    unsigned int * DPC_CLOCK_REG;
    unsigned int * DPC_BUFBUSY_REG;
    unsigned int * DPC_PIPEBUSY_REG;
    unsigned int * DPC_TMEM_REG;

    unsigned int * VI_STATUS_REG;
    unsigned int * VI_ORIGIN_REG;
    unsigned int * VI_WIDTH_REG;
    unsigned int * VI_INTR_REG;
    unsigned int * VI_V_CURRENT_LINE_REG;
    unsigned int * VI_TIMING_REG;
    unsigned int * VI_V_SYNC_REG;
    unsigned int * VI_H_SYNC_REG;
    unsigned int * VI_LEAP_REG;
    unsigned int * VI_H_START_REG;
    unsigned int * VI_V_START_REG;
    unsigned int * VI_V_BURST_REG;
    unsigned int * VI_X_SCALE_REG;
    unsigned int * VI_Y_SCALE_REG;

    void (*CheckInterrupts)(void);

    /* The GFX_INFO.version parameter was added in version 2.5.1 of the core.
       Plugins should ensure the core is at least this version before
       attempting to read GFX_INFO.version. */
    unsigned int version;
    /* SP_STATUS_REG and RDRAM_SIZE were added in version 2 of GFX_INFO.version.
       Plugins should only attempt to read these values if GFX_INFO.version is at least 2. */

    /* The RSP plugin should set (HALT | BROKE | TASKDONE) *before* calling ProcessDList.
       It should not modify SP_STATUS_REG after ProcessDList has returned.
       This will allow the GFX plugin to unset these bits if it needs. */
    unsigned int * SP_STATUS_REG;
    const unsigned int * RDRAM_SIZE;
} GFX_INFO;

typedef struct {
    unsigned char * RDRAM;
    unsigned char * DMEM;
    unsigned char * IMEM;

    unsigned int * MI_INTR_REG;

    unsigned int * AI_DRAM_ADDR_REG;
    unsigned int * AI_LEN_REG;
    unsigned int * AI_CONTROL_REG;
    unsigned int * AI_STATUS_REG;
    unsigned int * AI_DACRATE_REG;
    unsigned int * AI_BITRATE_REG;

    void (*CheckInterrupts)(void);
} AUDIO_INFO;

typedef struct {
    int Present;
    int RawData;
    int Plugin;
} CONTROL;

typedef union {
    unsigned int Value;
    struct {
        unsigned R_DPAD       : 1;
        unsigned L_DPAD       : 1;
        unsigned D_DPAD       : 1;
        unsigned U_DPAD       : 1;
        unsigned START_BUTTON : 1;
        unsigned Z_TRIG       : 1;
        unsigned B_BUTTON     : 1;
        unsigned A_BUTTON     : 1;

        unsigned R_CBUTTON    : 1;
        unsigned L_CBUTTON    : 1;
        unsigned D_CBUTTON    : 1;
        unsigned U_CBUTTON    : 1;
        unsigned R_TRIG       : 1;
        unsigned L_TRIG       : 1;
        unsigned Reserved1    : 1;
        unsigned Reserved2    : 1;

        signed   X_AXIS       : 8;
        signed   Y_AXIS       : 8;
    };
} BUTTONS;

typedef struct {
    CONTROL *Controls;      /* A pointer to an array of 4 controllers .. eg:
                               CONTROL Controls[4]; */
} CONTROL_INFO;

/* common plugin function pointer types */
typedef void (*ptr_RomClosed)(void);
typedef int  (*ptr_RomOpen)(void);
#if defined(M64P_PLUGIN_PROTOTYPES)
EXPORT int  CALL RomOpen(void);
EXPORT void CALL RomClosed(void);
#endif

/* video plugin function pointer types */
typedef void (*ptr_ChangeWindow)(void);
typedef int  (*ptr_InitiateGFX)(GFX_INFO Gfx_Info);
typedef void (*ptr_MoveScreen)(int x, int y);
typedef void (*ptr_ProcessDList)(void);
typedef void (*ptr_ProcessRDPList)(void);
typedef void (*ptr_ShowCFB)(void);
typedef void (*ptr_UpdateScreen)(void);
typedef void (*ptr_ViStatusChanged)(void);
typedef void (*ptr_ViWidthChanged)(void);
typedef void (*ptr_ReadScreen2)(void *dest, int *width, int *height, int front);
typedef void (*ptr_SetRenderingCallback)(void (*callback)(int));
typedef void (*ptr_ResizeVideoOutput)(int width, int height);
#if defined(M64P_PLUGIN_PROTOTYPES)
EXPORT void CALL ChangeWindow(void);
EXPORT int  CALL InitiateGFX(GFX_INFO Gfx_Info);
EXPORT void CALL MoveScreen(int x, int y);
EXPORT void CALL ProcessDList(void);
EXPORT void CALL ProcessRDPList(void);
EXPORT void CALL ShowCFB(void);
EXPORT void CALL UpdateScreen(void);
EXPORT void CALL ViStatusChanged(void);
EXPORT void CALL ViWidthChanged(void);
EXPORT void CALL ReadScreen2(void *dest, int *width, int *height, int front);
EXPORT void CALL SetRenderingCallback(void (*callback)(int));
EXPORT void CALL ResizeVideoOutput(int width, int height);
#endif

/* frame buffer plugin spec extension */
typedef struct
{
   unsigned int addr;
   unsigned int size;
   unsigned int width;
   unsigned int height;
} FrameBufferInfo;
typedef void (*ptr_FBRead)(unsigned int addr);
typedef void (*ptr_FBWrite)(unsigned int addr, unsigned int size);
typedef void (*ptr_FBGetFrameBufferInfo)(void *p);
#if defined(M64P_PLUGIN_PROTOTYPES)
EXPORT void CALL FBRead(unsigned int addr);
EXPORT void CALL FBWrite(unsigned int addr, unsigned int size);
EXPORT void CALL FBGetFrameBufferInfo(void *p);
#endif

/* audio plugin function pointers */
typedef void (*ptr_AiDacrateChanged)(int SystemType);
typedef void (*ptr_AiLenChanged)(void);
typedef int  (*ptr_InitiateAudio)(AUDIO_INFO Audio_Info);
typedef void (*ptr_ProcessAList)(void);
typedef void (*ptr_SetSpeedFactor)(int percent);
typedef void (*ptr_VolumeUp)(void);
typedef void (*ptr_VolumeDown)(void);
typedef int  (*ptr_VolumeGetLevel)(void);
typedef void (*ptr_VolumeSetLevel)(int level);
typedef void (*ptr_VolumeMute)(void);
typedef const char * (*ptr_VolumeGetString)(void);
#if defined(M64P_PLUGIN_PROTOTYPES)
EXPORT void CALL AiDacrateChanged(int SystemType);
EXPORT void CALL AiLenChanged(void);
EXPORT int  CALL InitiateAudio(AUDIO_INFO Audio_Info);
EXPORT void CALL ProcessAList(void);
EXPORT void CALL SetSpeedFactor(int percent);
EXPORT void CALL VolumeUp(void);
EXPORT void CALL VolumeDown(void);
EXPORT int  CALL VolumeGetLevel(void);
EXPORT void CALL VolumeSetLevel(int level);
EXPORT void CALL VolumeMute(void);
EXPORT const char * CALL VolumeGetString(void);
#endif

/* input plugin function pointers */
typedef void (*ptr_ControllerCommand)(int Control, unsigned char *Command);
typedef void (*ptr_GetKeys)(int Control, BUTTONS *Keys);
typedef void (*ptr_InitiateControllers)(CONTROL_INFO ControlInfo);
typedef void (*ptr_ReadController)(int Control, unsigned char *Command);
typedef void (*ptr_SDL_KeyDown)(int keymod, int keysym);
typedef void (*ptr_SDL_KeyUp)(int keymod, int keysym);
typedef void (*ptr_RenderCallback)(void);
#if defined(M64P_PLUGIN_PROTOTYPES)
EXPORT void CALL ControllerCommand(int Control, unsigned char *Command);
EXPORT void CALL GetKeys(int Control, BUTTONS *Keys);
EXPORT void CALL InitiateControllers(CONTROL_INFO ControlInfo);
EXPORT void CALL ReadController(int Control, unsigned char *Command);
EXPORT void CALL SDL_KeyDown(int keymod, int keysym);
EXPORT void CALL SDL_KeyUp(int keymod, int keysym);
EXPORT void CALL RenderCallback(void);
#endif

/* RSP plugin function pointers */
typedef unsigned int (*ptr_DoRspCycles)(unsigned int Cycles);
typedef void (*ptr_InitiateRSP)(RSP_INFO Rsp_Info, unsigned int *CycleCount);
#if defined(M64P_PLUGIN_PROTOTYPES)
EXPORT unsigned int CALL DoRspCycles(unsigned int Cycles);
EXPORT void CALL InitiateRSP(RSP_INFO Rsp_Info, unsigned int *CycleCount);
#endif

/* PluginGetVersion()
 *
 * This function retrieves version information from a library. This
 * function is the same for the core library and the plugins.
 */
typedef m64p_error (*ptr_PluginGetVersion)(m64p_plugin_type *, int *, int *, const char **, int *);
#if defined(M64P_PLUGIN_PROTOTYPES) || defined(M64P_CORE_PROTOTYPES)
EXPORT m64p_error CALL PluginGetVersion(m64p_plugin_type *, int *, int *, const char **, int *);
#endif

/* CoreGetAPIVersions()
 *
 * This function retrieves API version information from the core.
 */
typedef m64p_error (*ptr_CoreGetAPIVersions)(int *, int *, int *, int *);
#if defined(M64P_CORE_PROTOTYPES)
EXPORT m64p_error CALL CoreGetAPIVersions(int *, int *, int *, int *);
#endif

/* CoreErrorMessage()
 *
 * This function returns a pointer to a NULL-terminated string giving a
 * human-readable description of the error.
*/
typedef const char * (*ptr_CoreErrorMessage)(m64p_error);
#if defined(M64P_CORE_PROTOTYPES)
EXPORT const char * CALL CoreErrorMessage(m64p_error);
#endif

/* PluginStartup()
 *
 * This function initializes a plugin for use by allocating memory, creating
 * data structures, and loading the configuration data.
*/
typedef m64p_error (*ptr_PluginStartup)(m64p_dynlib_handle, void *, void (*)(void *, int, const char *));
#if defined(M64P_PLUGIN_PROTOTYPES) || defined(M64P_CORE_PROTOTYPES)
EXPORT m64p_error CALL PluginStartup(m64p_dynlib_handle, void *, void (*)(void *, int, const char *));
#endif

/* PluginShutdown()
 *
 * This function destroys data structures and releases memory allocated by
 * the plugin library.
*/
typedef m64p_error (*ptr_PluginShutdown)(void);
#if defined(M64P_PLUGIN_PROTOTYPES) || defined(M64P_CORE_PROTOTYPES)
EXPORT m64p_error CALL PluginShutdown(void);
#endif


extern m64p_error plugin_connect(m64p_plugin_type, m64p_dynlib_handle plugin_handle);
extern m64p_error plugin_start(m64p_plugin_type);
extern m64p_error plugin_check(void);

enum { NUM_CONTROLLER = 4 };
extern CONTROL Controls[NUM_CONTROLLER];

/*** Version requirement information ***/
#define RSP_API_VERSION   0x20000
#define GFX_API_VERSION   0x20200
#define AUDIO_API_VERSION 0x20000
#define INPUT_API_VERSION 0x20001

/* video plugin function pointers */
typedef struct _gfx_plugin_functions
{
    ptr_PluginGetVersion getVersion;
    ptr_ChangeWindow     changeWindow;
    ptr_InitiateGFX      initiateGFX;
    ptr_MoveScreen       moveScreen;
    ptr_ProcessDList     processDList;
    ptr_ProcessRDPList   processRDPList;
    ptr_RomClosed        romClosed;
    ptr_RomOpen          romOpen;
    ptr_ShowCFB          showCFB;
    ptr_UpdateScreen     updateScreen;
    ptr_ViStatusChanged  viStatusChanged;
    ptr_ViWidthChanged   viWidthChanged;
    ptr_ReadScreen2      readScreen;
    ptr_SetRenderingCallback setRenderingCallback;
    ptr_ResizeVideoOutput    resizeVideoOutput;

    /* frame buffer plugin spec extension */
    ptr_FBRead          fBRead;
    ptr_FBWrite         fBWrite;
    ptr_FBGetFrameBufferInfo fBGetFrameBufferInfo;
} gfx_plugin_functions;

extern gfx_plugin_functions gfx;

/* audio plugin function pointers */
typedef struct _audio_plugin_functions
{
    ptr_PluginGetVersion  getVersion;
    ptr_AiDacrateChanged  aiDacrateChanged;
    ptr_AiLenChanged      aiLenChanged;
    ptr_InitiateAudio     initiateAudio;
    ptr_ProcessAList      processAList;
    ptr_RomClosed         romClosed;
    ptr_RomOpen           romOpen;
    ptr_SetSpeedFactor    setSpeedFactor;
    ptr_VolumeUp          volumeUp;
    ptr_VolumeDown        volumeDown;
    ptr_VolumeGetLevel    volumeGetLevel;
    ptr_VolumeSetLevel    volumeSetLevel;
    ptr_VolumeMute        volumeMute;
    ptr_VolumeGetString   volumeGetString;
} audio_plugin_functions;

extern audio_plugin_functions audio;

/* input plugin function pointers */
typedef struct _input_plugin_functions
{
    ptr_PluginGetVersion    getVersion;
    ptr_ControllerCommand   controllerCommand;
    ptr_GetKeys             getKeys;
    ptr_InitiateControllers initiateControllers;
    ptr_ReadController      readController;
    ptr_RomClosed           romClosed;
    ptr_RomOpen             romOpen;
    ptr_SDL_KeyDown         keyDown;
    ptr_SDL_KeyUp           keyUp;
    ptr_RenderCallback      renderCallback;
} input_plugin_functions;

extern input_plugin_functions input;

/* RSP plugin function pointers */
typedef struct _rsp_plugin_functions
{
    ptr_PluginGetVersion    getVersion;
    ptr_DoRspCycles         doRspCycles;
    ptr_InitiateRSP         initiateRSP;
    ptr_RomClosed           romClosed;
} rsp_plugin_functions;

extern rsp_plugin_functions rsp;

#endif
