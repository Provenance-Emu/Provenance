/*******************************************************************************
* Common RSP plugin specifications:  version #1.2 created by zilmar            *
* Revised 2014 by Iconoclast for more compliance, portability and readability. *
*                                                                              *
* All questions or suggestions should go through the EmuTalk plugin forum.     *
* http://www.emutalk.net/forums/showforum.php?f=31                             *
*******************************************************************************/

#ifndef _RSP_H_INCLUDED__
#define _RSP_H_INCLUDED__

#include "my_types.h"

#if defined(__cplusplus)
extern "C" {
#endif

#define PLUGIN_TYPE_RSP             1
#define PLUGIN_TYPE_GFX             2
#define PLUGIN_TYPE_AUDIO           3
#define PLUGIN_TYPE_CONTROLLER      4

#ifndef PLUGIN_API_VERSION
#define PLUGIN_API_VERSION      0x0102
#endif

/* old names from the original specification file */
#define hInst               hinst
#define MemorySwapped       MemoryBswaped

/*
 * Declare RSP_INFO structure instance as:  `RSP_INFO RSP_INFO_NAME;'
 * ... for the ability to use the below convenience macros.
 *
 * Doing the traditional `RSP_INFO rsp_info' declaration has also worked but
 * requires accessing the RCP registers in a less portable way, for example:
 * `*(rsp_info).MI_INTR_REG |= MI_INTR_MASK_SP;'
 * versus
 * `GET_RCP_REG(MI_INTR_REG) |= MI_INTR_MASK_SP;'.
 */
#ifndef RSP_INFO_NAME
#ifdef M64P_PLUGIN_API
#define RSP_INFO_NAME           RSP_info
#else
#define RSP_INFO_NAME           RCP_info_SP
#endif
#define GET_RSP_INFO(member)    ((RSP_INFO_NAME).member)
#define GET_RCP_REG(member)     (*(RSP_INFO_NAME).member)
#endif

typedef struct {
    i32 left;
    i32 top;
    i32 right;
    i32 bottom;
} winapi_rect;

typedef struct {
    p_void hdc;
    int fErase;
    winapi_rect rcPaint;
    int fRestore;
    int fIncUpdate;
    u8 rgbReserved[32];
} winapi_paintstruct;

typedef struct {
    u16 Version;        /* Set to PLUGIN_API_VERSION. */
    u16 Type;           /* Set to PLUGIN_TYPE_RSP. */
    char Name[100];     /* plugin title, to help the user select plugins */

    /* If the plugin supports these memory options, then set them to true. */
    int NormalMemory;   /* a normal byte array */
    int MemorySwapped;  /* a normal byte array choosing the client-side,
                           native hardware's endian over the MIPS target's */
} PLUGIN_INFO;

#if !defined(M64P_PLUGIN_API)
typedef struct {
    p_void hInst;
    int MemorySwapped;

    pu8 RDRAM; /* CPU-RCP dynamic RAM (sensitive to MemorySwapped flag) */
    pu8 DMEM; /* high 4K of SP cache memory (sensitive to MemorySwapped flag) */
    pu8 IMEM; /* low 4K of SP cache memory (sensitive to MemorySwapped flag) */

    pu32 MI_INTR_REG;

    pu32 SP_MEM_ADDR_REG;
    pu32 SP_DRAM_ADDR_REG;
    pu32 SP_RD_LEN_REG;
    pu32 SP_WR_LEN_REG;
    pu32 SP_STATUS_REG;
    pu32 SP_DMA_FULL_REG;
    pu32 SP_DMA_BUSY_REG;
    pu32 SP_PC_REG; /* This was supposed to be defined AFTER semaphore. */
    pu32 SP_SEMAPHORE_REG;
#if 0
    pu32 SP_PC_REG; /* CPU-mapped between SP and DP command buffer regs */
#endif
    pu32 DPC_START_REG;
    pu32 DPC_END_REG;
    pu32 DPC_CURRENT_REG;
    pu32 DPC_STATUS_REG;
    pu32 DPC_CLOCK_REG;
    pu32 DPC_BUFBUSY_REG;
    pu32 DPC_PIPEBUSY_REG;
    pu32 DPC_TMEM_REG;

    p_func CheckInterrupts;
    p_func ProcessDList;
    p_func ProcessAList;
    p_func ProcessRdpList;
    p_func ShowCFB;
} RSP_INFO;
#endif

typedef struct {
    /* menu */
    /* Items should have an ID between 5001 and 5100. */
    p_void hRSPMenu;
    void (*ProcessMenuItem)(int ID);

    /* break points */
    int UseBPoints;
    char BPPanelName[20];
    p_func Add_BPoint;
    void (*CreateBPPanel)(p_void hDlg, winapi_rect rcBox);
    p_func HideBPPanel;
    void (*PaintBPPanel)(winapi_paintstruct ps);
    p_void ShowBPPanel;
    void (*RefreshBpoints)(p_void hList);
    void (*RemoveBpoint)(p_void hList, int index);
    p_void RemoveAllBpoint;

    /* RSP command window */
    p_func Enter_RSP_Commands_Window;
} RSPDEBUG_INFO;

typedef struct {
    p_func UpdateBreakPoints;
    p_func UpdateMemory;
    p_func UpdateR4300iRegisters;
    p_func Enter_BPoint_Window;
    p_func Enter_R4300i_Commands_Window;
    p_func Enter_R4300i_Register_Window;
    p_func Enter_RSP_Commands_Window;
    p_func Enter_Memory_Window;
} DEBUG_INFO;

/******************************************************************************
* name     :  CloseDLL
* optional :  no
* call time:  when the emulator is shutting down or chooses to free memory
* input    :  none
* output   :  none
*******************************************************************************/
EXPORT void CALL CloseDLL(void);

/******************************************************************************
* name     :  DllAbout
* optional :  yes
* call time:  upon a request to see information about the plugin (e.g., authors)
* input    :  a pointer to the window that called this function
* output   :  none
*******************************************************************************/
EXPORT void CALL DllAbout(p_void hParent);

/******************************************************************************
* name     :  DllConfig
* optional :  yes
* call time:  upon a request to configure the plugin (e.g., change settings)
* input    :  a pointer to the window that called this function
* output   :  none
*******************************************************************************/
EXPORT void CALL DllConfig(p_void hParent);

/******************************************************************************
* name     :  DllTest
* optional :  yes
* call time:  upon a request to test the plugin (e.g., system capabilities)
* input    :  a pointer to the window that called this function
* output   :  none
*******************************************************************************/
EXPORT void CALL DllTest(p_void hParent);

/******************************************************************************
* name     :  DoRspCycles
* optional :  no
* call time:  when the R4300 CPU alternates control to execute on the RSP
* input    :  number of cycles meant to be executed (for segmented execution)
* output   :  The number of cycles executed also was intended for cycle-timing
*             attempts, much like Project64 itself originally was, and requires
*             individual experiment.  This value is ignored if the RSP CPU flow
*             was halted when the function completed.  In-depth debate:
*             http://www.emutalk.net/showthread.php?t=43088
*******************************************************************************/
EXPORT u32 CALL DoRspCycles(u32 Cycles);

/******************************************************************************
* name     :  GetDllInfo
* optional :  no
* call time:  during the enumeration of valid plugins the emulator can load
* input    :  a pointer to a PLUGIN_INFO stucture used to determine support
* output   :  none
*******************************************************************************/
EXPORT void CALL GetDllInfo(PLUGIN_INFO * PluginInfo);

/******************************************************************************
* name     :  GetRspDebugInfo
* optional :  yes
* call time:  when the emulator requests information about what the RSP plugin
*             is and is not programmed to debug
* input    :  a pointer to a RSPDEBUG_INFO stucture to determine capabilities
* output   :  none
*******************************************************************************/
EXPORT void CALL GetRspDebugInfo(RSPDEBUG_INFO * RSPDebugInfo);

/******************************************************************************
* name     :  InitiateRSP
* optional :  no
* call time:  after the emulator has successfully loaded the plugin but needs
*             more information about it before proceeding to start emulation
* input    :  a RSP_INFO structure mostly for setting up the RCP memory map
* output   :  none
*******************************************************************************/
EXPORT void CALL InitiateRSP(RSP_INFO Rsp_Info, pu32 CycleCount);

/******************************************************************************
* name     :  InitiateRSPDebugger
* optional :  yes
* call time:  after plugin load, when the emulator is ready to supply an
*             informational structure useful to the RSP plugin for integrating
*             its debugger, if any, with the rest of the emulator
* input    :  a DEBUG_INFO structure offering debugger integration information
* output   :  none
*******************************************************************************/
EXPORT void CALL InitiateRSPDebugger(DEBUG_INFO DebugInfo);

/******************************************************************************
* name     :  RomClosed
* optional :  no
* call time:  when unloading the ROM (sometimes when emulation ends)
* input    :  none
* output   :  none
*******************************************************************************/
EXPORT void CALL RomClosed(void);

/*
 * required?? in version #1.2 of the RSP plugin spec
 * Have not tested a #1.2 implementation yet so shouldn't document them yet.
 *
 * Most of these functions were made to inhibit private plugin distribution
 * from Project64 in its commercial state, and there is no documentation of
 * these in the source to Project64 2.x as of yet.
 */
#if (PLUGIN_API_VERSION >= 0x0102) && !defined(M64P_PLUGIN_API)
EXPORT void CALL RomOpen(void);
EXPORT void CALL EnableDebugging(int Enabled);
EXPORT void CALL PluginLoaded(void);
#endif

/************ profiling **************/
#define Default_ProfilingOn         0
#define Default_IndvidualBlock      0
#define Default_ShowErrors          0
#define Default_AudioHle            0

#define InterpreterCPU      0
#define RecompilerCPU       1

#if defined(__cplusplus)
}
#endif

#endif
