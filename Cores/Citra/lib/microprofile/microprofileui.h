#pragma once
// This is free and unencumbered software released into the public domain.
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.
// In jurisdictions that recognize copyright laws, the author or authors
// of this software dedicate any and all copyright interest in the
// software to the public domain. We make this dedication for the benefit
// of the public at large and to the detriment of our heirs and
// successors. We intend this dedication to be an overt act of
// relinquishment in perpetuity of all present and future rights to this
// software under copyright law.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
// For more information, please refer to <http://unlicense.org/>
//
// ***********************************************************************
//
//
//


#ifndef MICROPROFILE_ENABLED
#error "microprofile.h must be included before including microprofileui.h"
#endif

#ifndef MICROPROFILEUI_ENABLED
#define MICROPROFILEUI_ENABLED MICROPROFILE_ENABLED
#endif

#ifndef MICROPROFILEUI_API
#define MICROPROFILEUI_API
#endif


#if 0 == MICROPROFILEUI_ENABLED
#define MicroProfileMouseButton(foo, bar) do{}while(0)
#define MicroProfileMousePosition(foo, bar, z) do{}while(0)
#define MicroProfileModKey(key) do{}while(0)
#define MicroProfileDraw(foo, bar) do{}while(0)
#define MicroProfileIsDrawing() 0
#define MicroProfileToggleDisplayMode() do{}while(0)
#define MicroProfileSetDisplayMode(f) do{}while(0)
#else

#ifndef MICROPROFILE_DRAWCURSOR
#define MICROPROFILE_DRAWCURSOR 0
#endif

#ifndef MICROPROFILE_DETAILED_BAR_NAMES
#define MICROPROFILE_DETAILED_BAR_NAMES 1
#endif

#ifndef MICROPROFILE_TEXT_WIDTH
#define MICROPROFILE_TEXT_WIDTH 5
#endif

#ifndef MICROPROFILE_TEXT_HEIGHT
#define MICROPROFILE_TEXT_HEIGHT 8
#endif

#ifndef MICROPROFILE_DETAILED_BAR_HEIGHT
#define MICROPROFILE_DETAILED_BAR_HEIGHT 12
#endif

#ifndef MICROPROFILE_DETAILED_CONTEXT_SWITCH_HEIGHT
#define MICROPROFILE_DETAILED_CONTEXT_SWITCH_HEIGHT 7
#endif

#ifndef MICROPROFILE_GRAPH_WIDTH
#define MICROPROFILE_GRAPH_WIDTH 256
#endif

#ifndef MICROPROFILE_GRAPH_HEIGHT
#define MICROPROFILE_GRAPH_HEIGHT 256
#endif

#ifndef MICROPROFILE_BORDER_SIZE
#define MICROPROFILE_BORDER_SIZE 1
#endif

#ifndef MICROPROFILE_HELP_LEFT
#define MICROPROFILE_HELP_LEFT "Left-Click"
#endif

#ifndef MICROPROFILE_HELP_ALT
#define MICROPROFILE_HELP_ALT "Alt-Click"
#endif

#ifndef MICROPROFILE_HELP_MOD
#define MICROPROFILE_HELP_MOD "Mod"
#endif

#ifndef MICROPROFILE_BAR_WIDTH
#define MICROPROFILE_BAR_WIDTH 100
#endif

#ifndef MICROPROFILE_CUSTOM_MAX
#define MICROPROFILE_CUSTOM_MAX 8
#endif

#ifndef MICROPROFILE_CUSTOM_MAX_TIMERS
#define MICROPROFILE_CUSTOM_MAX_TIMERS 64
#endif

#ifndef MICROPROFILE_CUSTOM_PADDING
#define MICROPROFILE_CUSTOM_PADDING 12
#endif


#define MICROPROFILE_FRAME_HISTORY_HEIGHT 50
#define MICROPROFILE_FRAME_HISTORY_WIDTH 7
#define MICROPROFILE_FRAME_HISTORY_COLOR_CPU 0xffff7f27 //255 127 39
#define MICROPROFILE_FRAME_HISTORY_COLOR_GPU 0xff37a0ee //55 160 238
#define MICROPROFILE_FRAME_HISTORY_COLOR_HIGHTLIGHT 0x7733bb44
#define MICROPROFILE_FRAME_COLOR_HIGHTLIGHT 0x20009900
#define MICROPROFILE_FRAME_COLOR_HIGHTLIGHT_GPU 0x20996600
#define MICROPROFILE_NUM_FRAMES (MICROPROFILE_MAX_FRAME_HISTORY - (MICROPROFILE_GPU_FRAME_DELAY+1))

#define MICROPROFILE_TOOLTIP_MAX_STRINGS (32 + MICROPROFILE_MAX_GROUPS*2)
#define MICROPROFILE_TOOLTIP_STRING_BUFFER_SIZE (4*1024)
#define MICROPROFILE_TOOLTIP_MAX_LOCKED 3


enum
{
    MICROPROFILE_CUSTOM_BARS = 0x1,
    MICROPROFILE_CUSTOM_BAR_SOURCE_MAX = 0x2,
    MICROPROFILE_CUSTOM_BAR_SOURCE_AVG = 0,
    MICROPROFILE_CUSTOM_STACK = 0x4,
    MICROPROFILE_CUSTOM_STACK_SOURCE_MAX = 0x8,
    MICROPROFILE_CUSTOM_STACK_SOURCE_AVG = 0,
};


MICROPROFILEUI_API void MicroProfileDraw(uint32_t nWidth, uint32_t nHeight); //! call if drawing microprofilers
MICROPROFILEUI_API bool MicroProfileIsDrawing();
MICROPROFILEUI_API void MicroProfileToggleGraph(MicroProfileToken nToken);
MICROPROFILEUI_API bool MicroProfileDrawGraph(uint32_t nScreenWidth, uint32_t nScreenHeight);
MICROPROFILEUI_API void MicroProfileToggleDisplayMode(); //switch between off, bars, detailed
MICROPROFILEUI_API void MicroProfileSetDisplayMode(int); //switch between off, bars, detailed
MICROPROFILEUI_API void MicroProfileClearGraph();
MICROPROFILEUI_API void MicroProfileMousePosition(uint32_t nX, uint32_t nY, int nWheelDelta);
MICROPROFILEUI_API void MicroProfileModKey(uint32_t nKeyState);
MICROPROFILEUI_API void MicroProfileMouseButton(uint32_t nLeft, uint32_t nRight);
MICROPROFILEUI_API void MicroProfileDrawLineVertical(int nX, int nTop, int nBottom, uint32_t nColor);
MICROPROFILEUI_API void MicroProfileDrawLineHorizontal(int nLeft, int nRight, int nY, uint32_t nColor);
MICROPROFILEUI_API void MicroProfileLoadPreset(const char* pSuffix);
MICROPROFILEUI_API void MicroProfileSavePreset(const char* pSuffix);

MICROPROFILEUI_API void MicroProfileDrawText(int nX, int nY, uint32_t nColor, const char* pText, uint32_t nNumCharacters);
MICROPROFILEUI_API void MicroProfileDrawBox(int nX, int nY, int nX1, int nY1, uint32_t nColor, MicroProfileBoxType = MicroProfileBoxTypeFlat);
MICROPROFILEUI_API void MicroProfileDrawLine2D(uint32_t nVertices, float* pVertices, uint32_t nColor);
MICROPROFILEUI_API void MicroProfileDumpTimers();

MICROPROFILEUI_API void MicroProfileInitUI();

MICROPROFILEUI_API void MicroProfileCustomGroupToggle(const char* pCustomName);
MICROPROFILEUI_API void MicroProfileCustomGroupEnable(const char* pCustomName);
MICROPROFILEUI_API void MicroProfileCustomGroupEnable(uint32_t nIndex);
MICROPROFILEUI_API void MicroProfileCustomGroupDisable();
MICROPROFILEUI_API void MicroProfileCustomGroup(const char* pCustomName, uint32_t nMaxTimers, uint32_t nAggregateFlip, float fReferenceTime, uint32_t nFlags);
MICROPROFILEUI_API void MicroProfileCustomGroupAddTimer(const char* pCustomName, const char* pGroup, const char* pTimer);

#ifdef MICROPROFILEUI_IMPL
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <math.h>
#include <algorithm>
#include <array>

MICROPROFILE_DEFINE(g_MicroProfileDetailed, "MicroProfile", "Detailed View", 0x8888000);
MICROPROFILE_DEFINE(g_MicroProfileDrawGraph, "MicroProfile", "Draw Graph", 0xff44ee00);
MICROPROFILE_DEFINE(g_MicroProfileDrawBarView, "MicroProfile", "DrawBarView", 0x00dd77);
MICROPROFILE_DEFINE(g_MicroProfileDraw,"MicroProfile", "Draw", 0x737373);


struct MicroProfileStringArray
{
    const char* ppStrings[MICROPROFILE_TOOLTIP_MAX_STRINGS];
    char Buffer[MICROPROFILE_TOOLTIP_STRING_BUFFER_SIZE];
    char* pBufferPos;
    uint32_t nNumStrings;
};

struct MicroProfileGroupMenuItem
{
    uint32_t nIsCategory;
    uint32_t nCategoryIndex;
    uint32_t nIndex;
    const char* pName;
};

struct MicroProfileCustom
{
    char pName[MICROPROFILE_NAME_MAX_LEN];
    uint32_t nFlags;
    uint32_t nAggregateFlip;
    uint32_t nNumTimers;
    uint32_t nMaxTimers;
    uint64_t nGroupMask;
    float fReference;
    uint64_t* pTimers;
};

struct SOptionDesc
{
    SOptionDesc(){}
    SOptionDesc(uint8_t nSubType, uint8_t nIndex, const char* fmt, ...):nSubType(nSubType), nIndex(nIndex)
    {
        va_list args;
        va_start (args, fmt);
        vsprintf(Text, fmt, args);
        va_end(args);
    }
    char Text[32];
    uint8_t nSubType;
    uint8_t nIndex;
    bool bSelected;
};
static const std::array<uint32_t, 6> g_MicroProfileAggregatePresets{0, 10, 20, 30, 60, 120};
static const std::array<float, 10> g_MicroProfileReferenceTimePresets{5.f, 10.f, 15.f,20.f, 33.33f, 66.66f, 100.f, 250.f, 500.f, 1000.f};
static const std::array<uint32_t, 4> g_MicroProfileOpacityPresets{0x40, 0x80, 0xc0, 0xff};
static const std::array<const char*, 7> g_MicroProfilePresetNames
{
    MICROPROFILE_DEFAULT_PRESET,
    "Render",
    "GPU",
    "Lighting",
    "AI",
    "Visibility",
    "Sound",
};

enum
{
    MICROPROFILE_NUM_REFERENCE_PRESETS = g_MicroProfileReferenceTimePresets.size(),
    MICROPROFILE_NUM_OPACITY_PRESETS = g_MicroProfileOpacityPresets.size(),
#if MICROPROFILE_CONTEXT_SWITCH_TRACE
    MICROPROFILE_OPTION_SIZE = MICROPROFILE_NUM_REFERENCE_PRESETS + MICROPROFILE_NUM_OPACITY_PRESETS * 2 + 2 + 7,
#else
    MICROPROFILE_OPTION_SIZE = MICROPROFILE_NUM_REFERENCE_PRESETS + MICROPROFILE_NUM_OPACITY_PRESETS * 2 + 2 + 3,
#endif
};

struct MicroProfileUI
{
    //menu/mouse over stuff
    uint64_t nHoverToken;
    int64_t  nHoverTime;
    int      nHoverFrame;
#if MICROPROFILE_DEBUG
    uint64_t nHoverAddressEnter;
    uint64_t nHoverAddressLeave;
#endif

    uint32_t nWidth;
    uint32_t nHeight;


    int nOffsetX;
    int nOffsetY;
    float fDetailedOffset; //display offset relative to start of latest displayable frame.
    float fDetailedRange; //no. of ms to display
    float fDetailedOffsetTarget;
    float fDetailedRangeTarget;
    uint32_t nOpacityBackground;
    uint32_t nOpacityForeground;
    bool bShowSpikes;



    uint32_t                nMouseX;
    uint32_t                nMouseY;
    uint32_t                nMouseDownX;
    uint32_t                nMouseDownY;
    int                     nMouseWheelDelta;
    uint32_t                nMouseDownLeft;
    uint32_t                nMouseDownRight;
    uint32_t                nMouseLeft;
    uint32_t                nMouseRight;
    uint32_t                nMouseLeftMod;
    uint32_t                nMouseRightMod;
    uint32_t                nModDown;
    uint32_t                nActiveMenu;

    MicroProfileLogEntry* pDisplayMouseOver;

    int64_t                 nRangeBegin;
    int64_t                 nRangeEnd;
    int64_t                 nRangeBeginGpu;
    int64_t                 nRangeEndGpu;
    uint32_t                nRangeBeginIndex;
    uint32_t                nRangeEndIndex;
    MicroProfileThreadLog*  pRangeLog;
    uint32_t                nHoverColor;
    uint32_t                nHoverColorShared;

    MicroProfileStringArray LockedToolTips[MICROPROFILE_TOOLTIP_MAX_LOCKED];
    uint32_t                nLockedToolTipColor[MICROPROFILE_TOOLTIP_MAX_LOCKED];
    int                     LockedToolTipFront;

    MicroProfileGroupMenuItem   GroupMenu[MICROPROFILE_MAX_GROUPS + MICROPROFILE_MAX_CATEGORIES];
    uint32_t                    GroupMenuCount;


    uint32_t                    nCustomActive;
    uint32_t                    nCustomTimerCount;
    uint32_t                    nCustomCount;
    MicroProfileCustom          Custom[MICROPROFILE_CUSTOM_MAX];
    uint64_t                    CustomTimer[MICROPROFILE_CUSTOM_MAX_TIMERS];

    SOptionDesc Options[MICROPROFILE_OPTION_SIZE];


};

MicroProfileUI g_MicroProfileUI;
#define UI g_MicroProfileUI
static const std::array<uint32_t, 2> g_nMicroProfileBackColors{  0x474747, 0x313131 };
#define MICROPROFILE_NUM_CONTEXT_SWITCH_COLORS 16
static const std::array<uint32_t, MICROPROFILE_NUM_CONTEXT_SWITCH_COLORS> g_nMicroProfileContextSwitchThreadColors //palette generated by http://tools.medialab.sciences-po.fr/iwanthue/index.php
{
    0x63607B,
    0x755E2B,
    0x326A55,
    0x523135,
    0x904F42,
    0x87536B,
    0x346875,
    0x5E6046,
    0x35404C,
    0x224038,
    0x413D1E,
    0x5E3A26,
    0x5D6161,
    0x4C6234,
    0x7D564F,
    0x5C4352,
};


void MicroProfileInitUI()
{
    static bool bInitialized = false;
    if(!bInitialized)
    {
        bInitialized = true;
        g_MicroProfileUI = {};
        UI.nActiveMenu = UINT32_MAX;
        UI.fDetailedOffsetTarget = UI.fDetailedOffset = 0.f;
        UI.fDetailedRangeTarget = UI.fDetailedRange = 50.f;

        UI.nOpacityBackground = 0xff<<24;
        UI.nOpacityForeground = 0xff<<24;

        UI.bShowSpikes = false;

        UI.nWidth = 100;
        UI.nHeight = 100;

        UI.nCustomActive = UINT32_MAX;
        UI.nCustomTimerCount = 0;
        UI.nCustomCount = 0;

        int nIndex = 0;
        UI.Options[nIndex++] = SOptionDesc(0xff, 0, "%s", "Reference");
        for(int i = 0; i < MICROPROFILE_NUM_REFERENCE_PRESETS; ++i)
        {
            UI.Options[nIndex++] = SOptionDesc(0, i, "  %6.2fms", g_MicroProfileReferenceTimePresets[i]);
        }
        UI.Options[nIndex++] = SOptionDesc(0xff, 0, "%s", "BG Opacity");
        for(int i = 0; i < MICROPROFILE_NUM_OPACITY_PRESETS; ++i)
        {
            UI.Options[nIndex++] = SOptionDesc(1, i, "  %7d%%", (i+1)*25);
        }
        UI.Options[nIndex++] = SOptionDesc(0xff, 0, "%s", "FG Opacity");
        for(int i = 0; i < MICROPROFILE_NUM_OPACITY_PRESETS; ++i)
        {
            UI.Options[nIndex++] = SOptionDesc(2, i, "  %7d%%", (i+1)*25);
        }
        UI.Options[nIndex++] = SOptionDesc(0xff, 0, "%s", "Spike Display");
        UI.Options[nIndex++] = SOptionDesc(3, 0, "%s", "  Enable");

#if MICROPROFILE_CONTEXT_SWITCH_TRACE
        UI.Options[nIndex++] = SOptionDesc(0xff, 0, "%s", "CSwitch Trace");
        UI.Options[nIndex++] = SOptionDesc(4, 0, "%s", "  Enable");
        UI.Options[nIndex++] = SOptionDesc(4, 1, "%s", "  All Threads");
        UI.Options[nIndex++] = SOptionDesc(4, 2, "%s", "  No Bars");
#endif
        MP_ASSERT(nIndex == MICROPROFILE_OPTION_SIZE);
    }
}

void MicroProfileSetDisplayMode(int nValue)
{
    MicroProfile& S = *MicroProfileGet();
    nValue = nValue >= 0 && nValue < 4 ? nValue : S.nDisplay;
    S.nDisplay = nValue;
    UI.nOffsetY = 0;
}

void MicroProfileToggleDisplayMode()
{
    MicroProfile& S = *MicroProfileGet();
    S.nDisplay = (S.nDisplay + 1) % 4;
    UI.nOffsetY = 0;
}


void MicroProfileStringArrayClear(MicroProfileStringArray* pArray)
{
    pArray->nNumStrings = 0;
    pArray->pBufferPos = &pArray->Buffer[0];
}

void MicroProfileStringArrayAddLiteral(MicroProfileStringArray* pArray, const char* pLiteral)
{
    MP_ASSERT(pArray->nNumStrings < MICROPROFILE_TOOLTIP_MAX_STRINGS);
    pArray->ppStrings[pArray->nNumStrings++] = pLiteral;
}

void MicroProfileStringArrayFormat(MicroProfileStringArray* pArray, const char* fmt, ...)
{
    MP_ASSERT(pArray->nNumStrings < MICROPROFILE_TOOLTIP_MAX_STRINGS);
    pArray->ppStrings[pArray->nNumStrings++] = pArray->pBufferPos;
    va_list args;
    va_start (args, fmt);
    pArray->pBufferPos += 1 + vsprintf(pArray->pBufferPos, fmt, args);
    va_end(args);
    MP_ASSERT(pArray->pBufferPos < pArray->Buffer + MICROPROFILE_TOOLTIP_STRING_BUFFER_SIZE);
}
void MicroProfileStringArrayCopy(MicroProfileStringArray* pDest, MicroProfileStringArray* pSrc)
{
    memcpy(&pDest->ppStrings[0], &pSrc->ppStrings[0], sizeof(pDest->ppStrings));
    memcpy(&pDest->Buffer[0], &pSrc->Buffer[0], sizeof(pDest->Buffer));
    for(uint32_t i = 0; i < MICROPROFILE_TOOLTIP_MAX_STRINGS; ++i)
    {
        if(i < pSrc->nNumStrings)
        {
            if(pSrc->ppStrings[i] >= &pSrc->Buffer[0] && pSrc->ppStrings[i] < &pSrc->Buffer[0] + MICROPROFILE_TOOLTIP_STRING_BUFFER_SIZE)
            {
                pDest->ppStrings[i] += &pDest->Buffer[0] - &pSrc->Buffer[0];
            }
        }
    }
    pDest->nNumStrings = pSrc->nNumStrings;
}

void MicroProfileFloatWindowSize(const char** ppStrings, uint32_t nNumStrings, uint32_t* pColors, uint32_t& nWidth, uint32_t& nHeight, uint32_t* pStringLengths = 0)
{
    uint32_t* nStringLengths = pStringLengths ? pStringLengths : (uint32_t*)alloca(nNumStrings * sizeof(uint32_t));
    uint32_t nTextCount = nNumStrings/2;
    for(uint32_t i = 0; i < nTextCount; ++i)
    {
        uint32_t i0 = i * 2;
        uint32_t s0, s1;
        nStringLengths[i0] = s0 = (uint32_t)strlen(ppStrings[i0]);
        nStringLengths[i0+1] = s1 = (uint32_t)strlen(ppStrings[i0+1]);
        nWidth = MicroProfileMax(s0+s1, nWidth);
    }
    nWidth = (MICROPROFILE_TEXT_WIDTH+1) * (2+nWidth) + 2 * MICROPROFILE_BORDER_SIZE;
    if(pColors)
        nWidth += MICROPROFILE_TEXT_WIDTH + 1;
    nHeight = (MICROPROFILE_TEXT_HEIGHT+1) * nTextCount + 2 * MICROPROFILE_BORDER_SIZE;
}

void MicroProfileDrawFloatWindow(uint32_t nX, uint32_t nY, const char** ppStrings, uint32_t nNumStrings, uint32_t nColor, uint32_t* pColors = 0)
{
    uint32_t nWidth = 0, nHeight = 0;
    uint32_t* nStringLengths = (uint32_t*)alloca(nNumStrings * sizeof(uint32_t));
    MicroProfileFloatWindowSize(ppStrings, nNumStrings, pColors, nWidth, nHeight, nStringLengths);
    uint32_t nTextCount = nNumStrings/2;
    if(nX + nWidth > UI.nWidth)
        nX = UI.nWidth - nWidth;
    if(nY + nHeight > UI.nHeight)
        nY = UI.nHeight - nHeight;
    MicroProfileDrawBox(nX-1, nY-1, nX + nWidth+1, nY + nHeight+1, 0xff000000|nColor);
    MicroProfileDrawBox(nX, nY, nX + nWidth, nY + nHeight, 0xff000000);
    if(pColors)
    {
        nX += MICROPROFILE_TEXT_WIDTH+1;
        nWidth -= MICROPROFILE_TEXT_WIDTH+1;
    }
    for(uint32_t i = 0; i < nTextCount; ++i)
    {
        int i0 = i * 2;
        if(pColors)
        {
            MicroProfileDrawBox(nX-MICROPROFILE_TEXT_WIDTH, nY, nX, nY + MICROPROFILE_TEXT_WIDTH, pColors[i]|0xff000000);
        }
        MicroProfileDrawText(nX + 1, nY + 1, UINT32_MAX, ppStrings[i0], (uint32_t)strlen(ppStrings[i0]));
        MicroProfileDrawText(nX + nWidth - nStringLengths[i0+1] * (MICROPROFILE_TEXT_WIDTH+1), nY + 1, UINT32_MAX, ppStrings[i0+1], (uint32_t)strlen(ppStrings[i0+1]));
        nY += (MICROPROFILE_TEXT_HEIGHT+1);
    }
}
void MicroProfileDrawTextBox(uint32_t nX, uint32_t nY, const char** ppStrings, uint32_t nNumStrings, uint32_t nColor, uint32_t* pColors = 0)
{
    uint32_t nWidth = 0, nHeight = 0;
    uint32_t* nStringLengths = (uint32_t*)alloca(nNumStrings * sizeof(uint32_t));
    for(uint32_t i = 0; i < nNumStrings; ++i)
    {
        nStringLengths[i] = (uint32_t)strlen(ppStrings[i]);
        nWidth = MicroProfileMax(nWidth, nStringLengths[i]);
        nHeight++;
    }
    nWidth = (MICROPROFILE_TEXT_WIDTH+1) * (2+nWidth) + 2 * MICROPROFILE_BORDER_SIZE;
    nHeight = (MICROPROFILE_TEXT_HEIGHT+1) * nHeight + 2 * MICROPROFILE_BORDER_SIZE;
    if(nX + nWidth > UI.nWidth)
        nX = UI.nWidth - nWidth;
    if(nY + nHeight > UI.nHeight)
        nY = UI.nHeight - nHeight;
    MicroProfileDrawBox(nX, nY, nX + nWidth, nY + nHeight, 0xff000000);
    for(uint32_t i = 0; i < nNumStrings; ++i)
    {
        MicroProfileDrawText(nX + 1, nY + 1, UINT32_MAX, ppStrings[i], (uint32_t)strlen(ppStrings[i]));
        nY += (MICROPROFILE_TEXT_HEIGHT+1);
    }
}



void MicroProfileToolTipMeta(MicroProfileStringArray* pToolTip)
{
    MicroProfile& S = *MicroProfileGet();
    if(UI.nRangeBeginIndex != UI.nRangeEndIndex && UI.pRangeLog)
    {
        uint64_t nMetaSum[MICROPROFILE_META_MAX] = {0};
        uint64_t nMetaSumInclusive[MICROPROFILE_META_MAX] = {0};
        int nStackDepth = 0;
        uint32_t nRange[2][2];
        MicroProfileThreadLog* pLog = UI.pRangeLog;


        MicroProfileGetRange(UI.nRangeEndIndex, UI.nRangeBeginIndex, nRange);
        for(uint32_t i = 0; i < 2; ++i)
        {
            uint32_t nStart = nRange[i][0];
            uint32_t nEnd = nRange[i][1];
            for(uint32_t j = nStart; j < nEnd; ++j)
            {
                MicroProfileLogEntry LE = pLog->Log[j];
                int nType = MicroProfileLogType(LE);
                switch(nType)
                {
                case MP_LOG_META:
                    {
                        int64_t nMetaIndex = MicroProfileLogTimerIndex(LE);
                        int64_t nMetaCount = MicroProfileLogGetTick(LE);
                        MP_ASSERT(nMetaIndex < MICROPROFILE_META_MAX);
                        if(nStackDepth>1)
                        {
                            nMetaSumInclusive[nMetaIndex] += nMetaCount;
                        }
                        else
                        {
                            nMetaSum[nMetaIndex] += nMetaCount;
                        }
                    }
                    break;
                case MP_LOG_LEAVE:
                    if(nStackDepth)
                    {
                        nStackDepth--;
                    }
                    else
                    {
                        for(int i = 0; i < MICROPROFILE_META_MAX; ++i)
                        {
                            nMetaSumInclusive[i] += nMetaSum[i];
                            nMetaSum[i] = 0;
                        }
                    }
                    break;
                case MP_LOG_ENTER:
                    nStackDepth++;
                    break;
                }

            }
        }
        bool bSpaced = false;
        for(int i = 0; i < MICROPROFILE_META_MAX; ++i)
        {
            if(S.MetaCounters[i].pName && (nMetaSum[i]||nMetaSumInclusive[i]))
            {
                if(!bSpaced)
                {
                    bSpaced = true;
                    MicroProfileStringArrayAddLiteral(pToolTip, "");
                    MicroProfileStringArrayAddLiteral(pToolTip, "");
                }
                MicroProfileStringArrayFormat(pToolTip, "%s excl", S.MetaCounters[i].pName);
                MicroProfileStringArrayFormat(pToolTip, "%5d", nMetaSum[i]);
                MicroProfileStringArrayFormat(pToolTip, "%s incl", S.MetaCounters[i].pName);
                MicroProfileStringArrayFormat(pToolTip, "%5d", nMetaSum[i] + nMetaSumInclusive[i]);
            }
        }
    }
}

void MicroProfileDrawFloatTooltip(uint32_t nX, uint32_t nY, uint32_t nToken, uint64_t nTime)
{
    MicroProfile& S = *MicroProfileGet();

    uint32_t nIndex = MicroProfileGetTimerIndex(nToken);
    uint32_t nAggregateFrames = S.nAggregateFrames ? S.nAggregateFrames : 1;
    uint32_t nAggregateCount = S.Aggregate[nIndex].nCount ? S.Aggregate[nIndex].nCount : 1;

    uint32_t nGroupId = MicroProfileGetGroupIndex(nToken);
    uint32_t nTimerId = MicroProfileGetTimerIndex(nToken);
    bool bGpu = S.GroupInfo[nGroupId].Type == MicroProfileTokenTypeGpu;

    float fToMs = MicroProfileTickToMsMultiplier(bGpu ? MicroProfileTicksPerSecondGpu() : MicroProfileTicksPerSecondCpu());

    float fMs = fToMs * (nTime);
    float fFrameMs = fToMs * (S.Frame[nIndex].nTicks);
    float fAverage = fToMs * (S.Aggregate[nIndex].nTicks/nAggregateFrames);
    float fCallAverage = fToMs * (S.Aggregate[nIndex].nTicks / nAggregateCount);
    float fMax = fToMs * (S.AggregateMax[nIndex]);

    float fFrameMsExclusive = fToMs * (S.FrameExclusive[nIndex]);
    float fAverageExclusive = fToMs * (S.AggregateExclusive[nIndex]/nAggregateFrames);
    float fMaxExclusive = fToMs * (S.AggregateMaxExclusive[nIndex]);

    float fGroupAverage = fToMs * (S.AggregateGroup[nGroupId] / nAggregateFrames);
    float fGroupMax = fToMs * (S.AggregateGroupMax[nGroupId]);
    float fGroup = fToMs * (S.FrameGroup[nGroupId]);


    MicroProfileStringArray ToolTip;
    MicroProfileStringArrayClear(&ToolTip);
    const char* pGroupName = S.GroupInfo[nGroupId].pName;
    const char* pTimerName = S.TimerInfo[nTimerId].pName;
    MicroProfileStringArrayAddLiteral(&ToolTip, "Timer:");
    MicroProfileStringArrayFormat(&ToolTip, "%s", pTimerName);

#if MICROPROFILE_DEBUG
    MicroProfileStringArrayFormat(&ToolTip,"0x%p", UI.nHoverAddressEnter);
    MicroProfileStringArrayFormat(&ToolTip,"0x%p", UI.nHoverAddressLeave);
#endif

    if(nTime != (uint64_t)0)
    {
        MicroProfileStringArrayAddLiteral(&ToolTip, "Time:");
        MicroProfileStringArrayFormat(&ToolTip,"%6.3fms",  fMs);
        MicroProfileStringArrayAddLiteral(&ToolTip, "");
        MicroProfileStringArrayAddLiteral(&ToolTip, "");
    }

    MicroProfileStringArrayAddLiteral(&ToolTip, "Frame Time:");
    MicroProfileStringArrayFormat(&ToolTip,"%6.3fms",  fFrameMs);

    MicroProfileStringArrayAddLiteral(&ToolTip, "Average:");
    MicroProfileStringArrayFormat(&ToolTip,"%6.3fms",  fAverage);

    MicroProfileStringArrayAddLiteral(&ToolTip, "Max:");
    MicroProfileStringArrayFormat(&ToolTip,"%6.3fms",  fMax);

    MicroProfileStringArrayAddLiteral(&ToolTip, "");
    MicroProfileStringArrayAddLiteral(&ToolTip, "");

    MicroProfileStringArrayAddLiteral(&ToolTip, "Frame Call Average:");
    MicroProfileStringArrayFormat(&ToolTip,"%6.3fms",  fCallAverage);

    MicroProfileStringArrayAddLiteral(&ToolTip, "Frame Call Count:");
    MicroProfileStringArrayFormat(&ToolTip, "%6d",  nAggregateCount / nAggregateFrames);

    MicroProfileStringArrayAddLiteral(&ToolTip, "");
    MicroProfileStringArrayAddLiteral(&ToolTip, "");

    MicroProfileStringArrayAddLiteral(&ToolTip, "Exclusive Frame Time:");
    MicroProfileStringArrayFormat(&ToolTip, "%6.3fms",  fFrameMsExclusive);

    MicroProfileStringArrayAddLiteral(&ToolTip, "Exclusive Average:");
    MicroProfileStringArrayFormat(&ToolTip, "%6.3fms",  fAverageExclusive);

    MicroProfileStringArrayAddLiteral(&ToolTip, "Exclusive Max:");
    MicroProfileStringArrayFormat(&ToolTip, "%6.3fms",  fMaxExclusive);

    MicroProfileStringArrayAddLiteral(&ToolTip, "");
    MicroProfileStringArrayAddLiteral(&ToolTip, "");

    MicroProfileStringArrayAddLiteral(&ToolTip, "Group:");
    MicroProfileStringArrayFormat(&ToolTip, "%s", pGroupName);
    MicroProfileStringArrayAddLiteral(&ToolTip, "Frame Time:");
    MicroProfileStringArrayFormat(&ToolTip, "%6.3f", fGroup);
    MicroProfileStringArrayAddLiteral(&ToolTip, "Frame Average:");
    MicroProfileStringArrayFormat(&ToolTip, "%6.3f", fGroupAverage);
    MicroProfileStringArrayAddLiteral(&ToolTip, "Frame Max:");
    MicroProfileStringArrayFormat(&ToolTip, "%6.3f", fGroupMax);




    MicroProfileToolTipMeta(&ToolTip);


    MicroProfileDrawFloatWindow(nX, nY+20, &ToolTip.ppStrings[0], ToolTip.nNumStrings, S.TimerInfo[nTimerId].nColor);

    if(UI.nMouseLeftMod)
    {
        int nIndex = (g_MicroProfileUI.LockedToolTipFront + MICROPROFILE_TOOLTIP_MAX_LOCKED - 1) % MICROPROFILE_TOOLTIP_MAX_LOCKED;
        g_MicroProfileUI.nLockedToolTipColor[nIndex] = S.TimerInfo[nTimerId].nColor;
        MicroProfileStringArrayCopy(&g_MicroProfileUI.LockedToolTips[nIndex], &ToolTip);
        g_MicroProfileUI.LockedToolTipFront = nIndex;

    }
}


void MicroProfileZoomTo(int64_t nTickStart, int64_t nTickEnd)
{
    MicroProfile& S = *MicroProfileGet();

    int64_t nStart = S.Frames[S.nFrameCurrent].nFrameStartCpu;
    float fToMs = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondCpu());
    UI.fDetailedOffsetTarget = MicroProfileLogTickDifference(nStart, nTickStart) * fToMs;
    UI.fDetailedRangeTarget = MicroProfileLogTickDifference(nTickStart, nTickEnd) * fToMs;
}

void MicroProfileCenter(int64_t nTickCenter)
{
    MicroProfile& S = *MicroProfileGet();
    int64_t nStart = S.Frames[S.nFrameCurrent].nFrameStartCpu;
    float fToMs = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondCpu());
    float fCenter = MicroProfileLogTickDifference(nStart, nTickCenter) * fToMs;
    UI.fDetailedOffsetTarget = UI.fDetailedOffset = fCenter - 0.5f * UI.fDetailedRange;
}
#ifdef MICROPROFILE_DEBUG
uint64_t* g_pMicroProfileDumpStart = 0;
uint64_t* g_pMicroProfileDumpEnd = 0;
void MicroProfileDebugDumpRange()
{
    MicroProfile& S = *MicroProfileGet();
    if(g_pMicroProfileDumpStart != g_pMicroProfileDumpEnd)
    {
        uint64_t* pStart = g_pMicroProfileDumpStart;
        uint64_t* pEnd = g_pMicroProfileDumpEnd;
        while(pStart != pEnd)
        {
            uint64_t nTick = MicroProfileLogGetTick(*pStart);
            uint64_t nToken = MicroProfileLogTimerIndex(*pStart);
            uint32_t nTimerId = MicroProfileGetTimerIndex(nToken);

            const char* pTimerName = S.TimerInfo[nTimerId].pName;
            char buffer[256];
            int type = MicroProfileLogType(*pStart);

            const char* pBegin = type == MP_LOG_LEAVE ? "END" :
                (type == MP_LOG_ENTER ? "BEGIN" : "META");
            snprintf(buffer, 255, "DUMP 0x%p: %s :: %llx: %s\n", pStart, pBegin,  nTick, pTimerName);
#ifdef _WIN32
            OutputDebugString(buffer);
#else
            printf("%s", buffer);
#endif
            pStart++;
        }

        g_pMicroProfileDumpStart = g_pMicroProfileDumpEnd;
    }
}
#define MP_DEBUG_DUMP_RANGE() MicroProfileDebugDumpRange();
#else
#define MP_DEBUG_DUMP_RANGE() do{} while(0)
#endif

#define MICROPROFILE_HOVER_DIST 0.5f

void MicroProfileDrawDetailedContextSwitchBars(uint32_t nY, uint32_t nThreadId, uint32_t nContextSwitchStart, uint32_t nContextSwitchEnd, int64_t nBaseTicks, uint32_t nBaseY)
{
    MicroProfile& S = *MicroProfileGet();
    int64_t nTickIn = -1;
    uint32_t nThreadBefore = UINT32_MAX;
    float fToMs = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondCpu());
    float fMsToScreen = UI.nWidth / UI.fDetailedRange;
    float fMouseX = (float)UI.nMouseX;
    float fMouseY = (float)UI.nMouseY;


    for(uint32_t j = nContextSwitchStart; j != nContextSwitchEnd; j = (j+1) % MICROPROFILE_CONTEXT_SWITCH_BUFFER_SIZE)
    {
        MP_ASSERT(j < MICROPROFILE_CONTEXT_SWITCH_BUFFER_SIZE);
        MicroProfileContextSwitch CS = S.ContextSwitch[j];

        if(nTickIn == -1)
        {
            if(CS.nThreadIn == nThreadId)
            {
                nTickIn = CS.nTicks;
                nThreadBefore = CS.nThreadOut;
            }
        }
        else
        {
            if(CS.nThreadOut == nThreadId)
            {
                int64_t nTickOut = CS.nTicks;
                float fMsStart = fToMs * MicroProfileLogTickDifference(nBaseTicks, nTickIn);
                float fMsEnd = fToMs * MicroProfileLogTickDifference(nBaseTicks, nTickOut);
                if(fMsStart <= fMsEnd)
                {
                    float fXStart = fMsStart * fMsToScreen;
                    float fXEnd = fMsEnd * fMsToScreen;
                    float fYStart = (float)nY;
                    float fYEnd = fYStart + (MICROPROFILE_DETAILED_CONTEXT_SWITCH_HEIGHT);
                    uint32_t nColor = g_nMicroProfileContextSwitchThreadColors[CS.nCpu%MICROPROFILE_NUM_CONTEXT_SWITCH_COLORS];
                    float fXDist = MicroProfileMax(fXStart - fMouseX, fMouseX - fXEnd);
                    bool bHover = fXDist < MICROPROFILE_HOVER_DIST && fYStart <= fMouseY && fMouseY <= fYEnd && nBaseY < fMouseY;
                    if(bHover)
                    {
                        UI.nRangeBegin = nTickIn;
                        UI.nRangeEnd = nTickOut;
                        S.nContextSwitchHoverTickIn = nTickIn;
                        S.nContextSwitchHoverTickOut = nTickOut;
                        S.nContextSwitchHoverThread = CS.nThreadOut;
                        S.nContextSwitchHoverThreadBefore = nThreadBefore;
                        S.nContextSwitchHoverThreadAfter = CS.nThreadIn;
                        S.nContextSwitchHoverCpuNext = CS.nCpu;
                        nColor = UI.nHoverColor;
                    }
                    if(CS.nCpu == S.nContextSwitchHoverCpu)
                    {
                        nColor = UI.nHoverColorShared;
                    }
                    MicroProfileDrawBox(fXStart, fYStart, fXEnd, fYEnd, nColor|UI.nOpacityForeground, MicroProfileBoxTypeFlat);
                }
                nTickIn = -1;
            }
        }
    }
}

void MicroProfileDrawDetailedBars(uint32_t nWidth, uint32_t nHeight, int nBaseY, int nSelectedFrame)
{
    MicroProfile& S = *MicroProfileGet();
    MP_DEBUG_DUMP_RANGE();
    int nY = nBaseY - UI.nOffsetY;
    [[maybe_unused]] int64_t nNumBoxes = 0;
    [[maybe_unused]] int64_t nNumLines = 0;

    uint32_t nFrameNext = (S.nFrameCurrent+1) % MICROPROFILE_MAX_FRAME_HISTORY;
    MicroProfileFrameState* pFrameCurrent = &S.Frames[S.nFrameCurrent];
    MicroProfileFrameState* pFrameNext = &S.Frames[nFrameNext];

    UI.nRangeBegin = 0;
    UI.nRangeEnd = 0;
    UI.nRangeBeginGpu = 0;
    UI.nRangeEndGpu = 0;
    UI.nRangeBeginIndex = UI.nRangeEndIndex = 0;
    UI.pRangeLog = 0;
    int64_t nFrameStartCpu = pFrameCurrent->nFrameStartCpu;
    int64_t nFrameStartGpu = pFrameCurrent->nFrameStartGpu;
    int64_t nTicksPerSecondCpu = MicroProfileTicksPerSecondCpu();
    int64_t nTicksPerSecondGpu = MicroProfileTicksPerSecondGpu();
    float fToMsCpu = MicroProfileTickToMsMultiplier(nTicksPerSecondCpu);
    float fToMsGpu = MicroProfileTickToMsMultiplier(nTicksPerSecondGpu);

    float fDetailedOffset = UI.fDetailedOffset;
    float fDetailedRange = UI.fDetailedRange;


    int64_t nDetailedOffsetTicksCpu = MicroProfileMsToTick(fDetailedOffset, MicroProfileTicksPerSecondCpu());
    int64_t nDetailedOffsetTicksGpu = MicroProfileMsToTick(fDetailedOffset, MicroProfileTicksPerSecondGpu());
    int64_t nBaseTicksCpu = nDetailedOffsetTicksCpu + nFrameStartCpu;
    int64_t nBaseTicksGpu = nDetailedOffsetTicksGpu + nFrameStartGpu;
    int64_t nBaseTicksEndCpu = nBaseTicksCpu + MicroProfileMsToTick(fDetailedRange, MicroProfileTicksPerSecondCpu());

    int64_t nTickReferenceCpu = 0, nTickReferenceGpu = 0;
    static int64_t nRefCpu = 0, nRefGpu = 0;
    if(MicroProfileGetGpuTickReference(&nTickReferenceCpu, &nTickReferenceGpu))
    {
        if(0 == nRefCpu || std::abs(nRefCpu-nBaseTicksCpu) > std::abs(nTickReferenceCpu-nBaseTicksCpu))
        {
            nRefCpu = nTickReferenceCpu;
            nRefGpu = nTickReferenceGpu;
        }
        else
        {
            nTickReferenceCpu = nRefCpu;
            nTickReferenceGpu = nRefGpu;
        }
        nBaseTicksGpu = (nBaseTicksCpu - nTickReferenceCpu) * nTicksPerSecondGpu / nTicksPerSecondCpu + nTickReferenceGpu;
    }
    int64_t nBaseTicksEndGpu = nBaseTicksCpu + MicroProfileMsToTick(fDetailedRange, MicroProfileTicksPerSecondCpu());

    MicroProfileFrameState* pFrameFirst = pFrameCurrent;
    int64_t nGapTime = MicroProfileTicksPerSecondCpu() * MICROPROFILE_GAP_TIME / 1000;
    for(uint32_t i = 0; i < MICROPROFILE_MAX_FRAME_HISTORY - MICROPROFILE_GPU_FRAME_DELAY; ++i)
    {
        uint32_t nNextIndex = (S.nFrameCurrent + MICROPROFILE_MAX_FRAME_HISTORY - i) % MICROPROFILE_MAX_FRAME_HISTORY;
        pFrameFirst = &S.Frames[nNextIndex];
        if(pFrameFirst->nFrameStartCpu <= nBaseTicksCpu-nGapTime)
            break;
    }

    float fMsBase = fToMsCpu * nDetailedOffsetTicksCpu;
    float fMs = fDetailedRange;
    float fMsEnd = fMs + fMsBase;
    float fWidth = (float)nWidth;
    float fMsToScreen = fWidth / fMs;

    {
        float fRate = floor(2*(log10(fMs)-1))/2;
        float fStep = powf(10.f, fRate);
        float fRcpStep = 1.f / fStep;
        int nColorIndex = (int)(floor(fMsBase*fRcpStep));
        float fStart = floor(fMsBase*fRcpStep) * fStep;
        for(float f = fStart; f < fMsEnd; )
        {
            float fStart = f;
            float fNext = f + fStep;
            MicroProfileDrawBox(((fStart-fMsBase) * fMsToScreen), nBaseY, (fNext-fMsBase) * fMsToScreen+1, nBaseY + nHeight, UI.nOpacityBackground | g_nMicroProfileBackColors[nColorIndex++ & 1]);
            f = fNext;
        }
    }

    nY += MICROPROFILE_TEXT_HEIGHT+1;
    MicroProfileLogEntry* pMouseOver = UI.pDisplayMouseOver;
    MicroProfileLogEntry* pMouseOverNext = 0;
    uint64_t nMouseOverToken = pMouseOver ? MicroProfileLogTimerIndex(*pMouseOver) : MICROPROFILE_INVALID_TOKEN;
    float fMouseX = (float)UI.nMouseX;
    float fMouseY = (float)UI.nMouseY;
    uint64_t nHoverToken = MICROPROFILE_INVALID_TOKEN;
    int64_t nHoverTime = 0;

    static int nHoverCounter = 155;
    static int nHoverCounterDelta = 10;
    nHoverCounter += nHoverCounterDelta;
    if(nHoverCounter >= 245)
        nHoverCounterDelta = -10;
    else if(nHoverCounter < 100)
        nHoverCounterDelta = 10;
    UI.nHoverColor = (nHoverCounter<<24)|(nHoverCounter<<16)|(nHoverCounter<<8)|nHoverCounter;
    uint32_t nHoverCounterShared = nHoverCounter>>2;
    UI.nHoverColorShared = (nHoverCounterShared<<24)|(nHoverCounterShared<<16)|(nHoverCounterShared<<8)|nHoverCounterShared;

    uint32_t nLinesDrawn[MICROPROFILE_STACK_MAX]={0};

    uint32_t nContextSwitchHoverThreadAfter = S.nContextSwitchHoverThreadAfter;
    uint32_t nContextSwitchHoverThreadBefore = S.nContextSwitchHoverThreadBefore;
    S.nContextSwitchHoverThread = S.nContextSwitchHoverThreadAfter = S.nContextSwitchHoverThreadBefore = UINT32_MAX;

    uint32_t nContextSwitchStart = UINT32_MAX;
    uint32_t nContextSwitchEnd = UINT32_MAX;
    S.nContextSwitchHoverCpuNext = 0xff;
    S.nContextSwitchHoverTickIn = -1;
    S.nContextSwitchHoverTickOut = -1;
    if(S.bContextSwitchRunning)
    {
        MicroProfileContextSwitchSearch(&nContextSwitchStart, &nContextSwitchEnd, nBaseTicksCpu, nBaseTicksEndCpu);
    }

    bool bSkipBarView = S.bContextSwitchRunning && S.bContextSwitchNoBars;

    if(!bSkipBarView)
    {
        for(uint32_t i = 0; i < MICROPROFILE_MAX_THREADS; ++i)
        {
            MicroProfileThreadLog* pLog = S.Pool[i];
            if(!pLog)
                continue;

            uint32_t nPut = pFrameNext->nLogStart[i];
            ///note: this may display new samples as old data, but this will only happen when
            //       unpaused, where the detailed view is hardly perceptible
            uint32_t nFront = S.Pool[i]->nPut.load(std::memory_order_relaxed);
            MicroProfileFrameState* pFrameLogFirst = pFrameCurrent;
            MicroProfileFrameState* pFrameLogLast = pFrameNext;
            uint32_t nGet = pFrameLogFirst->nLogStart[i];
            do
            {
                MP_ASSERT(pFrameLogFirst >= &S.Frames[0] && pFrameLogFirst < &S.Frames[MICROPROFILE_MAX_FRAME_HISTORY]);
                uint32_t nNewGet = pFrameLogFirst->nLogStart[i];
                bool bIsValid = false;
                if(nPut < nFront)
                {
                    bIsValid = nNewGet <= nPut || nNewGet >= nFront;
                }
                else
                {
                    bIsValid = nNewGet <= nPut && nNewGet >= nFront;
                }
                if(bIsValid)
                {
                    nGet = nNewGet;
                    pFrameLogFirst--;
                    if(pFrameLogFirst < &S.Frames[0])
                        pFrameLogFirst = &S.Frames[MICROPROFILE_MAX_FRAME_HISTORY-1];
                }
                else
                {
                    break;
                }
            }while(pFrameLogFirst != pFrameFirst);


            if (nGet == UINT32_MAX) {
                continue;
            }
            MP_ASSERT(nGet != UINT32_MAX);

            nPut = pFrameLogLast->nLogStart[i];

            uint32_t nRange[2][2] = { {0, 0}, {0, 0}, };

            MicroProfileGetRange(nPut, nGet, nRange);
            if(nPut == nGet)
                continue;
            uint32_t nMaxStackDepth = 0;

            bool bGpu = pLog->nGpu != 0;
            float fToMs = bGpu ? fToMsGpu : fToMsCpu;
            int64_t nBaseTicks = bGpu ? nBaseTicksGpu : nBaseTicksCpu;
            char ThreadName[MicroProfileThreadLog::THREAD_MAX_LEN + 16];
            uint64_t nThreadId = pLog->nThreadId;
            snprintf(ThreadName, sizeof(ThreadName)-1, "%04" PRIx64 ": %s", nThreadId, &pLog->ThreadName[0] );
            nY += 3;
            uint32_t nThreadColor = UINT32_MAX;
            if(pLog->nThreadId == nContextSwitchHoverThreadAfter || pLog->nThreadId == nContextSwitchHoverThreadBefore)
                nThreadColor = UI.nHoverColorShared|0x906060;
            MicroProfileDrawText(0, nY, nThreadColor, &ThreadName[0], (uint32_t)strlen(&ThreadName[0]));
            nY += 3;
            nY += MICROPROFILE_TEXT_HEIGHT + 1;

            if(S.bContextSwitchRunning)
            {
                MicroProfileDrawDetailedContextSwitchBars(nY, pLog->nThreadId, nContextSwitchStart, nContextSwitchEnd, nBaseTicks, nBaseY);
                nY -= MICROPROFILE_DETAILED_BAR_HEIGHT;
                nY += MICROPROFILE_DETAILED_CONTEXT_SWITCH_HEIGHT+1;
            }

            uint32_t nYDelta = MICROPROFILE_DETAILED_BAR_HEIGHT;
            uint32_t nStack[MICROPROFILE_STACK_MAX];
            uint32_t nStackPos = 0;
            for(uint32_t j = 0; j < 2; ++j)
            {
                uint32_t nStart = nRange[j][0];
                uint32_t nEnd = nRange[j][1];
                for(uint32_t k = nStart; k < nEnd; ++k)
                {
                    MicroProfileLogEntry* pEntry = &pLog->Log[k];
                    int nType = MicroProfileLogType(*pEntry);
                    if(MP_LOG_ENTER == nType)
                    {
                        MP_ASSERT(nStackPos < MICROPROFILE_STACK_MAX);
                        nStack[nStackPos++] = k;
                    }
                    else if(MP_LOG_META == nType)
                    {

                    }
                    else if(MP_LOG_LEAVE == nType)
                    {
                        if(0 == nStackPos)
                        {
                            continue;
                        }

                        MicroProfileLogEntry* pEntryEnter = &pLog->Log[nStack[nStackPos-1]];
                        if(MicroProfileLogTimerIndex(*pEntryEnter) != MicroProfileLogTimerIndex(*pEntry))
                        {
                            //uprintf("mismatch %llx %llx\n", pEntryEnter->nToken, pEntry->nToken);
                            continue;
                        }
                        int64_t nTickStart = MicroProfileLogGetTick(*pEntryEnter);
                        int64_t nTickEnd = MicroProfileLogGetTick(*pEntry);
                        uint64_t nTimerIndex = MicroProfileLogTimerIndex(*pEntry);
                        uint32_t nColor = S.TimerInfo[nTimerIndex].nColor;
                        if(nMouseOverToken == nTimerIndex)
                        {
                            if(pEntry == pMouseOver)
                            {
                                nColor = UI.nHoverColor;
                                if(bGpu)
                                {
                                    UI.nRangeBeginGpu = *pEntryEnter;
                                    UI.nRangeEndGpu = *pEntry;
                                    uint32_t nCpuBegin = (nStack[nStackPos-1] + 1) % MICROPROFILE_BUFFER_SIZE;
                                    uint32_t nCpuEnd = (k + 1) % MICROPROFILE_BUFFER_SIZE;
                                    MicroProfileLogEntry LogCpuBegin = pLog->Log[nCpuBegin];
                                    MicroProfileLogEntry LogCpuEnd = pLog->Log[nCpuEnd];
                                    if(MicroProfileLogType(LogCpuBegin)==3 && MicroProfileLogType(LogCpuEnd) == 3)
                                    {
                                        UI.nRangeBegin = LogCpuBegin;
                                        UI.nRangeEnd = LogCpuEnd;
                                    }
                                    UI.nRangeBeginIndex = nStack[nStackPos-1];
                                    UI.nRangeEndIndex = k;
                                    UI.pRangeLog = pLog;
                                }
                                else
                                {
                                    UI.nRangeBegin = *pEntryEnter;
                                    UI.nRangeEnd = *pEntry;
                                    UI.nRangeBeginIndex = nStack[nStackPos-1];
                                    UI.nRangeEndIndex = k;
                                    UI.pRangeLog = pLog;

                                }
                            }
                            else
                            {
                                nColor = UI.nHoverColorShared;
                            }
                        }

                        nMaxStackDepth = MicroProfileMax(nMaxStackDepth, nStackPos);
                        float fMsStart = fToMs * MicroProfileLogTickDifference(nBaseTicks, nTickStart);
                        float fMsEnd = fToMs * MicroProfileLogTickDifference(nBaseTicks, nTickEnd);
                        float fXStart = fMsStart * fMsToScreen;
                        float fXEnd = fMsEnd * fMsToScreen;
                        float fYStart = (float)(nY + nStackPos * nYDelta);
                        float fYEnd = fYStart + (MICROPROFILE_DETAILED_BAR_HEIGHT);
                        float fXDist = MicroProfileMax(fXStart - fMouseX, fMouseX - fXEnd);
                        bool bHover = fXDist < MICROPROFILE_HOVER_DIST && fYStart <= fMouseY && fMouseY <= fYEnd && nBaseY < fMouseY;
                        uint32_t nIntegerWidth = (uint32_t)(fXEnd - fXStart);
                        if(nIntegerWidth)
                        {
                            if(bHover && UI.nActiveMenu == UINT32_MAX)
                            {
                                nHoverToken = MicroProfileLogTimerIndex(*pEntry);
    #if MICROPROFILE_DEBUG
                                UI.nHoverAddressEnter = (uint64_t)pEntryEnter;
                                UI.nHoverAddressLeave = (uint64_t)pEntry;
    #endif
                                nHoverTime = MicroProfileLogTickDifference(nTickStart, nTickEnd);
                                pMouseOverNext = pEntry;
                            }

                            MicroProfileDrawBox(fXStart, fYStart, fXEnd, fYEnd, nColor|UI.nOpacityForeground, MicroProfileBoxTypeBar);
#if MICROPROFILE_DETAILED_BAR_NAMES
                            if(nIntegerWidth>3*MICROPROFILE_TEXT_WIDTH)
                            {
                                float fXStartText = MicroProfileMax(fXStart, 0.f);
                                int nTextWidth = (int)(fXEnd - fXStartText);
                                int nCharacters = (nTextWidth - 2*MICROPROFILE_TEXT_WIDTH) / MICROPROFILE_TEXT_WIDTH;
                                if(nCharacters>0)
                                {
                                    MicroProfileDrawText(fXStartText + 1, fYStart + 1, UINT32_MAX, S.TimerInfo[nTimerIndex].pName, MicroProfileMin<uint32_t>(S.TimerInfo[nTimerIndex].nNameLen, nCharacters));
                                }
                            }
#endif
                            ++nNumBoxes;
                        }
                        else
                        {
                            float fXAvg = 0.5f * (fXStart + fXEnd);
                            int nLineX = (int)floor(fXAvg+0.5f);
                            if(nLineX != (int)nLinesDrawn[nStackPos])
                            {
                                if(bHover && UI.nActiveMenu == UINT32_MAX)
                                {
                                    nHoverToken = (uint32_t)MicroProfileLogTimerIndex(*pEntry);
                                    nHoverTime = MicroProfileLogTickDifference(nTickStart, nTickEnd);
                                    pMouseOverNext = pEntry;
                                }
                                nLinesDrawn[nStackPos] = nLineX;
                                MicroProfileDrawLineVertical(nLineX, fYStart + 0.5f, fYEnd + 0.5f, nColor|UI.nOpacityForeground);
                                ++nNumLines;
                            }
                        }
                        nStackPos--;
                        if(0 == nStackPos)
                        {
                            if(bGpu ? (nTickStart > nBaseTicksEndGpu) : (nTickStart > nBaseTicksEndCpu))
                            {
                                break;
                            }
                        }
                    }
                }
            }
            nY += nMaxStackDepth * nYDelta + MICROPROFILE_DETAILED_BAR_HEIGHT+1;
        }
    }
    if(S.bContextSwitchRunning && (S.bContextSwitchAllThreads||S.bContextSwitchNoBars))
    {
        uint32_t nNumThreads = 0;
        uint32_t nThreads[MICROPROFILE_MAX_CONTEXT_SWITCH_THREADS];
        for(uint32_t i = 0; i < MICROPROFILE_MAX_THREADS && S.Pool[i]; ++i)
            nThreads[nNumThreads++] = S.Pool[i]->nThreadId;
        uint32_t nNumThreadsBase = nNumThreads;
        if(S.bContextSwitchAllThreads)
        {
            for(uint32_t i = nContextSwitchStart; i != nContextSwitchEnd; i = (i+1) % MICROPROFILE_CONTEXT_SWITCH_BUFFER_SIZE)
            {
                MicroProfileContextSwitch CS = S.ContextSwitch[i];
                ThreadIdType nThreadId = CS.nThreadIn;
                if(nThreadId)
                {
                    bool bSeen = false;
                    for(uint32_t j = 0; j < nNumThreads; ++j)
                    {
                        if(nThreads[j] == nThreadId)
                        {
                            bSeen = true;
                            break;
                        }
                    }
                    if(!bSeen)
                    {
                        nThreads[nNumThreads++] = nThreadId;
                    }
                }
                if(nNumThreads == MICROPROFILE_MAX_CONTEXT_SWITCH_THREADS)
                {
                    S.nOverflow = 10;
                    break;
                }
            }
            std::sort(&nThreads[nNumThreadsBase], &nThreads[nNumThreads]);
        }
        uint32_t nStart = nNumThreadsBase;
        if(S.bContextSwitchNoBars)
            nStart = 0;
        for(uint32_t i = nStart; i < nNumThreads; ++i)
        {
            ThreadIdType nThreadId = nThreads[i];
            if(nThreadId)
            {
                char ThreadName[MicroProfileThreadLog::THREAD_MAX_LEN + 16];
                const char* cLocal = MicroProfileIsLocalThread(nThreadId) ? "*": " ";

#if defined(_WIN32)
                // nThreadId is 32-bit on Windows
                int nStrLen = snprintf(ThreadName, sizeof(ThreadName)-1, "%04x: %s%s", nThreadId, cLocal, i < nNumThreadsBase ? &S.Pool[i]->ThreadName[0] : MICROPROFILE_THREAD_NAME_FROM_ID(nThreadId) );
#else
                int nStrLen = snprintf(ThreadName, sizeof(ThreadName)-1, "%04" PRIx64 ": %s%s", nThreadId, cLocal, i < nNumThreadsBase ? &S.Pool[i]->ThreadName[0] : MICROPROFILE_THREAD_NAME_FROM_ID(nThreadId) );
#endif
                uint32_t nThreadColor = UINT32_MAX;
                if(nThreadId == nContextSwitchHoverThreadAfter || nThreadId == nContextSwitchHoverThreadBefore)
                    nThreadColor = UI.nHoverColorShared|0x906060;
                MicroProfileDrawDetailedContextSwitchBars(nY+2, nThreadId, nContextSwitchStart, nContextSwitchEnd, nBaseTicksCpu, nBaseY);
                MicroProfileDrawText(0, nY, nThreadColor, &ThreadName[0], nStrLen);
                nY += MICROPROFILE_TEXT_HEIGHT+1;
            }
        }
    }

    S.nContextSwitchHoverCpu = S.nContextSwitchHoverCpuNext;

    UI.pDisplayMouseOver = pMouseOverNext;

    if(!S.nRunning)
    {
        if(nHoverToken != MICROPROFILE_INVALID_TOKEN && nHoverTime)
        {
            UI.nHoverToken = nHoverToken;
            UI.nHoverTime = nHoverTime;
        }

        if(nSelectedFrame != -1)
        {
            UI.nRangeBegin = S.Frames[nSelectedFrame].nFrameStartCpu;
            UI.nRangeEnd = S.Frames[(nSelectedFrame+1)%MICROPROFILE_MAX_FRAME_HISTORY].nFrameStartCpu;
            UI.nRangeBeginGpu = S.Frames[nSelectedFrame].nFrameStartGpu;
            UI.nRangeEndGpu = S.Frames[(nSelectedFrame+1)%MICROPROFILE_MAX_FRAME_HISTORY].nFrameStartGpu;
        }
        if(UI.nRangeBegin != UI.nRangeEnd)
        {
            float fMsStart = fToMsCpu * MicroProfileLogTickDifference(nBaseTicksCpu, UI.nRangeBegin);
            float fMsEnd = fToMsCpu * MicroProfileLogTickDifference(nBaseTicksCpu, UI.nRangeEnd);
            float fXStart = fMsStart * fMsToScreen;
            float fXEnd = fMsEnd * fMsToScreen;
            MicroProfileDrawBox(fXStart, nBaseY, fXEnd, nHeight, MICROPROFILE_FRAME_COLOR_HIGHTLIGHT, MicroProfileBoxTypeFlat);
            MicroProfileDrawLineVertical(fXStart, nBaseY, nHeight, MICROPROFILE_FRAME_COLOR_HIGHTLIGHT | 0x44000000);
            MicroProfileDrawLineVertical(fXEnd, nBaseY, nHeight, MICROPROFILE_FRAME_COLOR_HIGHTLIGHT | 0x44000000);

            fMsStart += fDetailedOffset;
            fMsEnd += fDetailedOffset;
            char sBuffer[32];
            uint32_t nLenStart = snprintf(sBuffer, sizeof(sBuffer)-1, "%.2fms", fMsStart);
            float fStartTextWidth = (float)((1+MICROPROFILE_TEXT_WIDTH) * nLenStart);
            float fStartTextX = fXStart - fStartTextWidth - 2;
            MicroProfileDrawBox(fStartTextX, nBaseY, fStartTextX + fStartTextWidth + 2, MICROPROFILE_TEXT_HEIGHT + 2 + nBaseY, 0x33000000, MicroProfileBoxTypeFlat);
            MicroProfileDrawText(fStartTextX+1, nBaseY, UINT32_MAX, sBuffer, nLenStart);
            uint32_t nLenEnd = snprintf(sBuffer, sizeof(sBuffer)-1, "%.2fms", fMsEnd);
            MicroProfileDrawBox(fXEnd+1, nBaseY, fXEnd+1+(1+MICROPROFILE_TEXT_WIDTH) * nLenEnd + 3, MICROPROFILE_TEXT_HEIGHT + 2 + nBaseY, 0x33000000, MicroProfileBoxTypeFlat);
            MicroProfileDrawText(fXEnd+2, nBaseY+1, UINT32_MAX, sBuffer, nLenEnd);

            if(UI.nMouseRight)
            {
                MicroProfileZoomTo(UI.nRangeBegin, UI.nRangeEnd);
            }
        }

        if(UI.nRangeBeginGpu != UI.nRangeEndGpu)
        {
            float fMsStart = fToMsGpu * MicroProfileLogTickDifference(nBaseTicksGpu, UI.nRangeBeginGpu);
            float fMsEnd = fToMsGpu * MicroProfileLogTickDifference(nBaseTicksGpu, UI.nRangeEndGpu);
            float fXStart = fMsStart * fMsToScreen;
            float fXEnd = fMsEnd * fMsToScreen;
            MicroProfileDrawBox(fXStart, nBaseY, fXEnd, nHeight, MICROPROFILE_FRAME_COLOR_HIGHTLIGHT_GPU, MicroProfileBoxTypeFlat);
            MicroProfileDrawLineVertical(fXStart, nBaseY, nHeight, MICROPROFILE_FRAME_COLOR_HIGHTLIGHT_GPU | 0x44000000);
            MicroProfileDrawLineVertical(fXEnd, nBaseY, nHeight, MICROPROFILE_FRAME_COLOR_HIGHTLIGHT_GPU | 0x44000000);

            nBaseY += MICROPROFILE_TEXT_HEIGHT+1;

            fMsStart += fDetailedOffset;
            fMsEnd += fDetailedOffset;
            char sBuffer[32];
            uint32_t nLenStart = snprintf(sBuffer, sizeof(sBuffer)-1, "%.2fms", fMsStart);
            float fStartTextWidth = (float)((1+MICROPROFILE_TEXT_WIDTH) * nLenStart);
            float fStartTextX = fXStart - fStartTextWidth - 2;
            MicroProfileDrawBox(fStartTextX, nBaseY, fStartTextX + fStartTextWidth + 2, MICROPROFILE_TEXT_HEIGHT + 2 + nBaseY, 0x33000000, MicroProfileBoxTypeFlat);
            MicroProfileDrawText(fStartTextX+1, nBaseY, UINT32_MAX, sBuffer, nLenStart);
            uint32_t nLenEnd = snprintf(sBuffer, sizeof(sBuffer)-1, "%.2fms", fMsEnd);
            MicroProfileDrawBox(fXEnd+1, nBaseY, fXEnd+1+(1+MICROPROFILE_TEXT_WIDTH) * nLenEnd + 3, MICROPROFILE_TEXT_HEIGHT + 2 + nBaseY, 0x33000000, MicroProfileBoxTypeFlat);
            MicroProfileDrawText(fXEnd+2, nBaseY+1, UINT32_MAX, sBuffer, nLenEnd);
        }
    }
}


void MicroProfileDrawDetailedFrameHistory(uint32_t nWidth, uint32_t nHeight, uint32_t nBaseY, uint32_t nSelectedFrame)
{
    MicroProfile& S = *MicroProfileGet();

    const uint32_t nBarHeight = MICROPROFILE_FRAME_HISTORY_HEIGHT;
    float fBaseX = (float)nWidth;
    float fDx = fBaseX / MICROPROFILE_NUM_FRAMES;

    uint32_t nLastIndex =  (S.nFrameCurrent+1) % MICROPROFILE_MAX_FRAME_HISTORY;
    MicroProfileDrawBox(0, nBaseY, nWidth, nBaseY+MICROPROFILE_FRAME_HISTORY_HEIGHT, 0xff000000 | g_nMicroProfileBackColors[0], MicroProfileBoxTypeFlat);
    float fToMs = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondCpu()) * S.fRcpReferenceTime;
    float fToMsGpu = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondGpu()) * S.fRcpReferenceTime;


    MicroProfileFrameState* pFrameCurrent = &S.Frames[S.nFrameCurrent];
    uint64_t nFrameStartCpu = pFrameCurrent->nFrameStartCpu;
    int64_t nDetailedOffsetTicksCpu = MicroProfileMsToTick(UI.fDetailedOffset, MicroProfileTicksPerSecondCpu());
    int64_t nCpuStart = nDetailedOffsetTicksCpu + nFrameStartCpu;
    int64_t nCpuEnd = nCpuStart + MicroProfileMsToTick(UI.fDetailedRange, MicroProfileTicksPerSecondCpu());;


    float fSelectionStart = (float)nWidth;
    float fSelectionEnd = 0.f;
    for(uint32_t i = 0; i < MICROPROFILE_NUM_FRAMES; ++i)
    {
        uint32_t nIndex = (S.nFrameCurrent + MICROPROFILE_MAX_FRAME_HISTORY - i) % MICROPROFILE_MAX_FRAME_HISTORY;
        MicroProfileFrameState* pCurrent = &S.Frames[nIndex];
        MicroProfileFrameState* pNext = &S.Frames[nLastIndex];

        int64_t nTicks = pNext->nFrameStartCpu - pCurrent->nFrameStartCpu;
        int64_t nTicksGpu = pNext->nFrameStartGpu - pCurrent->nFrameStartGpu;
        float fScale = fToMs * nTicks;
        float fScaleGpu = fToMsGpu * nTicksGpu;
        fScale = fScale > 1.f ? 0.f : 1.f - fScale;
        fScaleGpu = fScaleGpu > 1.f ? 0.f : 1.f - fScaleGpu;
        float fXEnd = fBaseX;
        float fXStart = fBaseX - fDx;
        fBaseX = fXStart;
        uint32_t nColor = MICROPROFILE_FRAME_HISTORY_COLOR_CPU;
        if(nIndex == nSelectedFrame)
            nColor = UINT32_MAX;
        MicroProfileDrawBox(fXStart, nBaseY + fScale * nBarHeight, fXEnd, nBaseY+MICROPROFILE_FRAME_HISTORY_HEIGHT, nColor, MicroProfileBoxTypeBar);
        if(pNext->nFrameStartCpu > nCpuStart)
        {
            fSelectionStart = fXStart;
        }
        if(pCurrent->nFrameStartCpu < nCpuEnd && fSelectionEnd == 0.f)
        {
            fSelectionEnd = fXEnd;
        }
        nLastIndex = nIndex;
    }
    MicroProfileDrawBox(fSelectionStart, nBaseY, fSelectionEnd, nBaseY+MICROPROFILE_FRAME_HISTORY_HEIGHT, MICROPROFILE_FRAME_HISTORY_COLOR_HIGHTLIGHT, MicroProfileBoxTypeFlat);
}
void MicroProfileDrawDetailedView(uint32_t nWidth, uint32_t nHeight)
{
    MicroProfile& S = *MicroProfileGet();

    MICROPROFILE_SCOPE(g_MicroProfileDetailed);
    uint32_t nBaseY = MICROPROFILE_TEXT_HEIGHT + 1;

    int nSelectedFrame = -1;
    if(UI.nMouseY > nBaseY && UI.nMouseY <= nBaseY + MICROPROFILE_FRAME_HISTORY_HEIGHT && UI.nActiveMenu == UINT32_MAX)
    {

        nSelectedFrame = ((MICROPROFILE_NUM_FRAMES) * (UI.nWidth-UI.nMouseX) / UI.nWidth);
        nSelectedFrame = (S.nFrameCurrent + MICROPROFILE_MAX_FRAME_HISTORY - nSelectedFrame) % MICROPROFILE_MAX_FRAME_HISTORY;
        UI.nHoverFrame = nSelectedFrame;
        if(UI.nMouseRight)
        {
            int64_t nRangeBegin = S.Frames[nSelectedFrame].nFrameStartCpu;
            int64_t nRangeEnd = S.Frames[(nSelectedFrame+1)%MICROPROFILE_MAX_FRAME_HISTORY].nFrameStartCpu;
            MicroProfileZoomTo(nRangeBegin, nRangeEnd);
        }
        if(UI.nMouseDownLeft)
        {
            uint64_t nFrac = (1024 * (MICROPROFILE_NUM_FRAMES) * (UI.nMouseX) / UI.nWidth) % 1024;
            int64_t nRangeBegin = S.Frames[nSelectedFrame].nFrameStartCpu;
            int64_t nRangeEnd = S.Frames[(nSelectedFrame+1)%MICROPROFILE_MAX_FRAME_HISTORY].nFrameStartCpu;
            MicroProfileCenter(nRangeBegin + (nRangeEnd-nRangeBegin) * nFrac / 1024);
        }
    }
    else
    {
        UI.nHoverFrame = -1;
    }

    MicroProfileDrawDetailedBars(nWidth, nHeight, nBaseY + MICROPROFILE_FRAME_HISTORY_HEIGHT, nSelectedFrame);
    MicroProfileDrawDetailedFrameHistory(nWidth, nHeight, nBaseY, nSelectedFrame);
}

void MicroProfileDrawTextRight(uint32_t nX, uint32_t nY, uint32_t nColor, const char* pStr, uint32_t nStrLen)
{
    MicroProfileDrawText(nX - nStrLen * (MICROPROFILE_TEXT_WIDTH+1), nY, nColor, pStr, nStrLen);
}
void MicroProfileDrawHeader(int32_t nX, uint32_t nWidth, const char* pName)
{
    if(pName)
    {
        MicroProfileDrawBox(nX-8, MICROPROFILE_TEXT_HEIGHT + 2, nX + nWidth+5, MICROPROFILE_TEXT_HEIGHT + 2 + (MICROPROFILE_TEXT_HEIGHT+1), 0xff000000|g_nMicroProfileBackColors[1]);
        MicroProfileDrawText(nX, MICROPROFILE_TEXT_HEIGHT + 2, UINT32_MAX, pName, (uint32_t)strlen(pName));
    }
}


typedef void (*MicroProfileLoopGroupCallback)(uint32_t nTimer, uint32_t nIdx, uint64_t nGroupMask, uint32_t nX, uint32_t nY, void* pData);

void MicroProfileLoopActiveGroupsDraw(int32_t nX, int32_t nY, const char* pName, MicroProfileLoopGroupCallback CB, void* pData)
{
    MicroProfile& S = *MicroProfileGet();
    nY += MICROPROFILE_TEXT_HEIGHT + 2;
    uint64_t nGroup = S.nAllGroupsWanted ? S.nGroupMask : S.nActiveGroupWanted;
    uint32_t nCount = 0;
    for(uint32_t j = 0; j < MICROPROFILE_MAX_GROUPS; ++j)
    {
        uint64_t nMask = 1ULL << j;
        if(nMask & nGroup)
        {
            nY += MICROPROFILE_TEXT_HEIGHT + 1;
            for(uint32_t i = 0; i < S.nTotalTimers;++i)
            {
                uint64_t nTokenMask = MicroProfileGetGroupMask(S.TimerInfo[i].nToken);
                if(nTokenMask & nMask)
                {
                    if(nY >= 0)
                        CB(i, nCount, nMask, nX, nY, pData);

                    nCount += 2;
                    nY += MICROPROFILE_TEXT_HEIGHT + 1;

                    if(nY > (int)UI.nHeight)
                        return;
                }
            }

        }
    }
}


void MicroProfileCalcTimers(float* pTimers, float* pAverage, float* pMax, float* pCallAverage, float* pExclusive, float* pAverageExclusive, float* pMaxExclusive, uint64_t nGroup, uint32_t nSize)
{
    MicroProfile& S = *MicroProfileGet();

    uint32_t nCount = 0;
    uint64_t nMask = 1;

    for(uint32_t j = 0; j < MICROPROFILE_MAX_GROUPS; ++j)
    {
        if(nMask & nGroup)
        {
            const float fToMs = MicroProfileTickToMsMultiplier(S.GroupInfo[j].Type == MicroProfileTokenTypeGpu ? MicroProfileTicksPerSecondGpu() : MicroProfileTicksPerSecondCpu());
            for(uint32_t i = 0; i < S.nTotalTimers;++i)
            {
                uint64_t nTokenMask = MicroProfileGetGroupMask(S.TimerInfo[i].nToken);
                if(nTokenMask & nMask)
                {
                    {
                        uint32_t nTimer = i;
                        uint32_t nIdx = nCount;
                        uint32_t nAggregateFrames = S.nAggregateFrames ? S.nAggregateFrames : 1;
                        uint32_t nAggregateCount = S.Aggregate[nTimer].nCount ? S.Aggregate[nTimer].nCount : 1;
                        float fToPrc = S.fRcpReferenceTime;
                        float fMs = fToMs * (S.Frame[nTimer].nTicks);
                        float fPrc = MicroProfileMin(fMs * fToPrc, 1.f);
                        float fAverageMs = fToMs * (S.Aggregate[nTimer].nTicks / nAggregateFrames);
                        float fAveragePrc = MicroProfileMin(fAverageMs * fToPrc, 1.f);
                        float fMaxMs = fToMs * (S.AggregateMax[nTimer]);
                        float fMaxPrc = MicroProfileMin(fMaxMs * fToPrc, 1.f);
                        float fCallAverageMs = fToMs * (S.Aggregate[nTimer].nTicks / nAggregateCount);
                        float fCallAveragePrc = MicroProfileMin(fCallAverageMs * fToPrc, 1.f);
                        float fMsExclusive = fToMs * (S.FrameExclusive[nTimer]);
                        float fPrcExclusive = MicroProfileMin(fMsExclusive * fToPrc, 1.f);
                        float fAverageMsExclusive = fToMs * (S.AggregateExclusive[nTimer] / nAggregateFrames);
                        float fAveragePrcExclusive = MicroProfileMin(fAverageMsExclusive * fToPrc, 1.f);
                        float fMaxMsExclusive = fToMs * (S.AggregateMaxExclusive[nTimer]);
                        float fMaxPrcExclusive = MicroProfileMin(fMaxMsExclusive * fToPrc, 1.f);
                        pTimers[nIdx] = fMs;
                        pTimers[nIdx+1] = fPrc;
                        pAverage[nIdx] = fAverageMs;
                        pAverage[nIdx+1] = fAveragePrc;
                        pMax[nIdx] = fMaxMs;
                        pMax[nIdx+1] = fMaxPrc;
                        pCallAverage[nIdx] = fCallAverageMs;
                        pCallAverage[nIdx+1] = fCallAveragePrc;
                        pExclusive[nIdx] = fMsExclusive;
                        pExclusive[nIdx+1] = fPrcExclusive;
                        pAverageExclusive[nIdx] = fAverageMsExclusive;
                        pAverageExclusive[nIdx+1] = fAveragePrcExclusive;
                        pMaxExclusive[nIdx] = fMaxMsExclusive;
                        pMaxExclusive[nIdx+1] = fMaxPrcExclusive;
                    }
                    nCount += 2;
                }
            }
        }
        nMask <<= 1;
    }
}

#define SBUF_MAX 32

void MicroProfileDrawBarArrayCallback(uint32_t nTimer, uint32_t nIdx, uint64_t nGroupMask, uint32_t nX, uint32_t nY, void* pExtra)
{
    const uint32_t nHeight = MICROPROFILE_TEXT_HEIGHT;
    const uint32_t nTextWidth = 6 * (1+MICROPROFILE_TEXT_WIDTH);
    const float fWidth = (float)MICROPROFILE_BAR_WIDTH;

    float* pTimers = ((float**)pExtra)[0];
    float* pTimers2 = ((float**)pExtra)[1];
    MicroProfile& S = *MicroProfileGet();
    char sBuffer[SBUF_MAX];
    if (pTimers2 && pTimers2[nIdx] > 0.1f)
        snprintf(sBuffer, SBUF_MAX-1, "%5.2f %3.1fx", pTimers[nIdx], pTimers[nIdx] / pTimers2[nIdx]);
    else
        snprintf(sBuffer, SBUF_MAX-1, "%5.2f", pTimers[nIdx]);
    if (!pTimers2)
        MicroProfileDrawBox(nX + nTextWidth, nY, nX + nTextWidth + fWidth * pTimers[nIdx+1], nY + nHeight, UI.nOpacityForeground|S.TimerInfo[nTimer].nColor, MicroProfileBoxTypeBar);
    MicroProfileDrawText(nX, nY, UINT32_MAX, sBuffer, (uint32_t)strlen(sBuffer));
}


uint32_t MicroProfileDrawBarArray(int32_t nX, int32_t nY, float* pTimers, const char* pName, uint32_t nTotalHeight, float* pTimers2 = NULL)
{
    const uint32_t nTextWidth = 6 * (1+MICROPROFILE_TEXT_WIDTH);
    const uint32_t nWidth = MICROPROFILE_BAR_WIDTH;

    MicroProfileDrawLineVertical(nX-5, 0, nTotalHeight+nY, UI.nOpacityBackground|g_nMicroProfileBackColors[0]|g_nMicroProfileBackColors[1]);
    float* pTimersArray[2] = {pTimers, pTimers2};
    MicroProfileLoopActiveGroupsDraw(nX, nY, pName, MicroProfileDrawBarArrayCallback, pTimersArray);
    MicroProfileDrawHeader(nX, nTextWidth + nWidth, pName);
    return nWidth + 5 + nTextWidth;

}
void MicroProfileDrawBarCallCountCallback(uint32_t nTimer, uint32_t nIdx, uint64_t nGroupMask, uint32_t nX, uint32_t nY, void* pExtra)
{
    MicroProfile& S = *MicroProfileGet();
    char sBuffer[SBUF_MAX];
    int nLen = snprintf(sBuffer, SBUF_MAX-1, "%5d", S.Frame[nTimer].nCount);//fix
    MicroProfileDrawText(nX, nY, UINT32_MAX, sBuffer, nLen);
}

uint32_t MicroProfileDrawBarCallCount(int32_t nX, int32_t nY, const char* pName)
{
    MicroProfileLoopActiveGroupsDraw(nX, nY, pName, MicroProfileDrawBarCallCountCallback, 0);
    const uint32_t nTextWidth = 6 * MICROPROFILE_TEXT_WIDTH;
    MicroProfileDrawHeader(nX, 5 + nTextWidth, pName);
    return 5 + nTextWidth;
}

struct MicroProfileMetaAverageArgs
{
    uint64_t* pCounters;
    float fRcpFrames;
};

void MicroProfileDrawBarMetaAverageCallback(uint32_t nTimer, uint32_t nIdx, uint64_t nGroupMask, uint32_t nX, uint32_t nY, void* pExtra)
{
    MicroProfileMetaAverageArgs* pArgs = (MicroProfileMetaAverageArgs*)pExtra;
    uint64_t* pCounters = pArgs->pCounters;
    float fRcpFrames = pArgs->fRcpFrames;
    char sBuffer[SBUF_MAX];
    int nLen = snprintf(sBuffer, SBUF_MAX-1, "%5.2f", pCounters[nTimer] * fRcpFrames);
    MicroProfileDrawText(nX - nLen * (MICROPROFILE_TEXT_WIDTH+1), nY, UINT32_MAX, sBuffer, nLen);
}

uint32_t MicroProfileDrawBarMetaAverage(int32_t nX, int32_t nY, uint64_t* pCounters, const char* pName, uint32_t nTotalHeight)
{
    if(!pName)
        return 0;
    MicroProfileDrawLineVertical(nX-5, 0, nTotalHeight+nY, UI.nOpacityBackground|g_nMicroProfileBackColors[0]|g_nMicroProfileBackColors[1]);
    uint32_t nTextWidth = (1+MICROPROFILE_TEXT_WIDTH) * MicroProfileMax<uint32_t>(6, (uint32_t)strlen(pName));
    float fRcpFrames = 1.f / (MicroProfileGet()->nAggregateFrames ? MicroProfileGet()->nAggregateFrames : 1);
    MicroProfileMetaAverageArgs Args = {pCounters, fRcpFrames};
    MicroProfileLoopActiveGroupsDraw(nX + nTextWidth, nY, pName, MicroProfileDrawBarMetaAverageCallback, &Args);
    MicroProfileDrawHeader(nX, 5 + nTextWidth, pName);
    return 5 + nTextWidth;
}


void MicroProfileDrawBarMetaCountCallback(uint32_t nTimer, uint32_t nIdx, uint64_t nGroupMask, uint32_t nX, uint32_t nY, void* pExtra)
{
    uint64_t* pCounters = (uint64_t*)pExtra;
    char sBuffer[SBUF_MAX];
    int nLen = snprintf(sBuffer, SBUF_MAX-1, "%5" PRIu64, pCounters[nTimer]);
    MicroProfileDrawText(nX - nLen * (MICROPROFILE_TEXT_WIDTH+1), nY, UINT32_MAX, sBuffer, nLen);
}

uint32_t MicroProfileDrawBarMetaCount(int32_t nX, int32_t nY, uint64_t* pCounters, const char* pName, uint32_t nTotalHeight)
{
    if(!pName)
        return 0;

    MicroProfileDrawLineVertical(nX-5, 0, nTotalHeight+nY, UI.nOpacityBackground|g_nMicroProfileBackColors[0]|g_nMicroProfileBackColors[1]);
    uint32_t nTextWidth = (1+MICROPROFILE_TEXT_WIDTH) * MicroProfileMax<uint32_t>(6, (uint32_t)strlen(pName));
    MicroProfileLoopActiveGroupsDraw(nX + nTextWidth, nY, pName, MicroProfileDrawBarMetaCountCallback, pCounters);
    MicroProfileDrawHeader(nX, 5 + nTextWidth, pName);
    return 5 + nTextWidth;
}

void MicroProfileDrawBarLegendCallback(uint32_t nTimer, uint32_t nIdx, uint64_t nGroupMask, uint32_t nX, uint32_t nY, void* pExtra)
{
    MicroProfile& S = *MicroProfileGet();
    if (S.TimerInfo[nTimer].bGraph)
    {
        MicroProfileDrawText(nX, nY, S.TimerInfo[nTimer].nColor, ">", 1);
    }
    MicroProfileDrawTextRight(nX, nY, S.TimerInfo[nTimer].nColor, S.TimerInfo[nTimer].pName, (uint32_t)strlen(S.TimerInfo[nTimer].pName));
    if(UI.nMouseY >= nY && UI.nMouseY < nY + MICROPROFILE_TEXT_HEIGHT+1)
    {
        UI.nHoverToken = nTimer;
        UI.nHoverTime = 0;
    }
}

uint32_t MicroProfileDrawBarLegend(int32_t nX, int32_t nY, uint32_t nTotalHeight, uint32_t nMaxWidth)
{
    MicroProfileDrawLineVertical(nX-5, nY, nTotalHeight, UI.nOpacityBackground | g_nMicroProfileBackColors[0]|g_nMicroProfileBackColors[1]);
    MicroProfileLoopActiveGroupsDraw(nMaxWidth, nY, 0, MicroProfileDrawBarLegendCallback, 0);
    return nX;
}

bool MicroProfileDrawGraph(uint32_t nScreenWidth, uint32_t nScreenHeight)
{
    MicroProfile& S = *MicroProfileGet();

    MICROPROFILE_SCOPE(g_MicroProfileDrawGraph);
    bool bEnabled = false;
    for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
        if(S.Graph[i].nToken != MICROPROFILE_INVALID_TOKEN)
            bEnabled = true;
    if(!bEnabled)
        return false;

    uint32_t nX = nScreenWidth - MICROPROFILE_GRAPH_WIDTH;
    uint32_t nY = nScreenHeight - MICROPROFILE_GRAPH_HEIGHT;
    MicroProfileDrawBox(nX, nY, nX + MICROPROFILE_GRAPH_WIDTH, nY + MICROPROFILE_GRAPH_HEIGHT, 0x88000000 | g_nMicroProfileBackColors[0]);
    bool bMouseOver = UI.nMouseX >= nX && UI.nMouseY >= nY;
    float fMouseXPrc =(float(UI.nMouseX - nX)) / MICROPROFILE_GRAPH_WIDTH;
    if(bMouseOver)
    {
        float fXAvg = fMouseXPrc * MICROPROFILE_GRAPH_WIDTH + nX;
        MicroProfileDrawLineVertical(fXAvg, nY, nY + MICROPROFILE_GRAPH_HEIGHT, UINT32_MAX);
    }


    float fY = (float)nScreenHeight;
    float fDX = MICROPROFILE_GRAPH_WIDTH * 1.f / MICROPROFILE_GRAPH_HISTORY;
    float fDY = MICROPROFILE_GRAPH_HEIGHT;
    uint32_t nPut = S.nGraphPut;
    float* pGraphData = (float*)alloca(sizeof(float)* MICROPROFILE_GRAPH_HISTORY*2);
    for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
    {
        if(S.Graph[i].nToken != MICROPROFILE_INVALID_TOKEN)
        {
            uint32_t nGroupId = MicroProfileGetGroupIndex(S.Graph[i].nToken);
            bool bGpu = S.GroupInfo[nGroupId].Type == MicroProfileTokenTypeGpu;
            float fToMs = MicroProfileTickToMsMultiplier(bGpu ? MicroProfileTicksPerSecondGpu() : MicroProfileTicksPerSecondCpu());
            float fToPrc = fToMs * S.fRcpReferenceTime * 3 / 4;

            float fX = (float)nX;
            for(uint32_t j = 0; j < MICROPROFILE_GRAPH_HISTORY; ++j)
            {
                float fWeigth = MicroProfileMin(fToPrc * (S.Graph[i].nHistory[(j+nPut)%MICROPROFILE_GRAPH_HISTORY]), 1.f);
                pGraphData[(j*2)] = fX;
                pGraphData[(j*2)+1] = fY - fDY * fWeigth;
                fX += fDX;
            }
            MicroProfileDrawLine2D(MICROPROFILE_GRAPH_HISTORY, pGraphData, S.TimerInfo[MicroProfileGetTimerIndex(S.Graph[i].nToken)].nColor);
        }
    }
    {
        float fY1 = 0.25f * MICROPROFILE_GRAPH_HEIGHT + nY;
        float fY2 = 0.50f * MICROPROFILE_GRAPH_HEIGHT + nY;
        float fY3 = 0.75f * MICROPROFILE_GRAPH_HEIGHT + nY;
        MicroProfileDrawLineHorizontal(nX, nX + MICROPROFILE_GRAPH_WIDTH, fY1, 0xffdd4444);
        MicroProfileDrawLineHorizontal(nX, nX + MICROPROFILE_GRAPH_WIDTH, fY2, 0xff000000| g_nMicroProfileBackColors[0]);
        MicroProfileDrawLineHorizontal(nX, nX + MICROPROFILE_GRAPH_WIDTH, fY3, 0xff000000|g_nMicroProfileBackColors[0]);

        char buf[32];
        int nLen = snprintf(buf, sizeof(buf)-1, "%5.2fms", S.fReferenceTime);
        MicroProfileDrawText(nX+1, fY1 - (2+MICROPROFILE_TEXT_HEIGHT), UINT32_MAX, buf, nLen);
    }



    if(bMouseOver)
    {
        uint32_t pColors[MICROPROFILE_MAX_GRAPHS];
        MicroProfileStringArray Strings;
        MicroProfileStringArrayClear(&Strings);
        uint32_t nTextCount = 0;
        uint32_t nGraphIndex = (S.nGraphPut + MICROPROFILE_GRAPH_HISTORY - int(MICROPROFILE_GRAPH_HISTORY*(1.f - fMouseXPrc))) % MICROPROFILE_GRAPH_HISTORY;

        uint32_t nX = UI.nMouseX;
        uint32_t nY = UI.nMouseY + 20;

        for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
        {
            if(S.Graph[i].nToken != MICROPROFILE_INVALID_TOKEN)
            {
                uint32_t nGroupId = MicroProfileGetGroupIndex(S.Graph[i].nToken);
                bool bGpu = S.GroupInfo[nGroupId].Type == MicroProfileTokenTypeGpu;
                float fToMs = MicroProfileTickToMsMultiplier(bGpu ? MicroProfileTicksPerSecondGpu() : MicroProfileTicksPerSecondCpu());
                uint32_t nIndex = MicroProfileGetTimerIndex(S.Graph[i].nToken);
                uint32_t nColor = S.TimerInfo[nIndex].nColor;
                const char* pName = S.TimerInfo[nIndex].pName;
                pColors[nTextCount++] = nColor;
                MicroProfileStringArrayAddLiteral(&Strings, pName);
                MicroProfileStringArrayFormat(&Strings, "%5.2fms", fToMs * (S.Graph[i].nHistory[nGraphIndex]));
            }
        }
        if(nTextCount)
        {
            MicroProfileDrawFloatWindow(nX, nY, Strings.ppStrings, Strings.nNumStrings, 0, pColors);
        }

        if(UI.nMouseRight)
        {
            for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
            {
                S.Graph[i].nToken = MICROPROFILE_INVALID_TOKEN;
            }
        }
    }

    return bMouseOver;
}

void MicroProfileDumpTimers()
{
    MicroProfile& S = *MicroProfileGet();

    uint64_t nActiveGroup = S.nGroupMask;

    uint32_t nNumTimers = S.nTotalTimers;
    uint32_t nBlockSize = 2 * nNumTimers;
    float* pTimers = (float*)alloca(nBlockSize * 7 * sizeof(float));
    float* pAverage = pTimers + nBlockSize;
    float* pMax = pTimers + 2 * nBlockSize;
    float* pCallAverage = pTimers + 3 * nBlockSize;
    float* pTimersExclusive = pTimers + 4 * nBlockSize;
    float* pAverageExclusive = pTimers + 5 * nBlockSize;
    float* pMaxExclusive = pTimers + 6 * nBlockSize;
    MicroProfileCalcTimers(pTimers, pAverage, pMax, pCallAverage, pTimersExclusive, pAverageExclusive, pMaxExclusive, nActiveGroup, nNumTimers);

    MICROPROFILE_PRINTF("%11s, ", "Time");
    MICROPROFILE_PRINTF("%11s, ", "Average");
    MICROPROFILE_PRINTF("%11s, ", "Max");
    MICROPROFILE_PRINTF("%11s, ", "Call Avg");
    MICROPROFILE_PRINTF("%9s, ", "Count");
    MICROPROFILE_PRINTF("%11s, ", "Excl");
    MICROPROFILE_PRINTF("%11s, ", "Avg Excl");
    MICROPROFILE_PRINTF("%11s, \n", "Max Excl");

    for(uint32_t j = 0; j < MICROPROFILE_MAX_GROUPS; ++j)
    {
        uint64_t nMask = 1ULL << j;
        if(nMask & nActiveGroup)
        {
            MICROPROFILE_PRINTF("%s\n", S.GroupInfo[j].pName);
            for(uint32_t i = 0; i < S.nTotalTimers;++i)
            {
                uint64_t nTokenMask = MicroProfileGetGroupMask(S.TimerInfo[i].nToken);
                if(nTokenMask & nMask)
                {
                    uint32_t nIdx = i * 2;
                    MICROPROFILE_PRINTF("%9.2fms, ", pTimers[nIdx]);
                    MICROPROFILE_PRINTF("%9.2fms, ", pAverage[nIdx]);
                    MICROPROFILE_PRINTF("%9.2fms, ", pMax[nIdx]);
                    MICROPROFILE_PRINTF("%9.2fms, ", pCallAverage[nIdx]);
                    MICROPROFILE_PRINTF("%9d, ", S.Frame[i].nCount);
                    MICROPROFILE_PRINTF("%9.2fms, ", pTimersExclusive[nIdx]);
                    MICROPROFILE_PRINTF("%9.2fms, ", pAverageExclusive[nIdx]);
                    MICROPROFILE_PRINTF("%9.2fms, ", pMaxExclusive[nIdx]);
                    MICROPROFILE_PRINTF("%s\n", S.TimerInfo[i].pName);
                }
            }
        }
    }
}

void MicroProfileDrawBarView(uint32_t nScreenWidth, uint32_t nScreenHeight)
{
    MicroProfile& S = *MicroProfileGet();

    uint64_t nActiveGroup = S.nAllGroupsWanted ? S.nGroupMask : S.nActiveGroupWanted;
    if(!nActiveGroup)
        return;
    MICROPROFILE_SCOPE(g_MicroProfileDrawBarView);

    const uint32_t nHeight = MICROPROFILE_TEXT_HEIGHT;
    int nColorIndex = 0;
    uint32_t nMaxTimerNameLen = 1;
    uint32_t nNumTimers = 0;
    uint32_t nNumGroups = 0;
    for(uint32_t j = 0; j < MICROPROFILE_MAX_GROUPS; ++j)
    {
        if(nActiveGroup & (1ULL << j))
        {
            nNumTimers += S.GroupInfo[j].nNumTimers;
            nNumGroups += 1;
            nMaxTimerNameLen = MicroProfileMax(nMaxTimerNameLen, S.GroupInfo[j].nMaxTimerNameLen);
        }
    }
    uint32_t nTimerWidth = 2+(4+nMaxTimerNameLen) * (MICROPROFILE_TEXT_WIDTH+1);
    uint32_t nX = nTimerWidth + UI.nOffsetX;
    uint32_t nY = nHeight + 3 - UI.nOffsetY;
    uint32_t nBlockSize = 2 * nNumTimers;
    float* pTimers = (float*)alloca(nBlockSize * 7 * sizeof(float));
    float* pAverage = pTimers + nBlockSize;
    float* pMax = pTimers + 2 * nBlockSize;
    float* pCallAverage = pTimers + 3 * nBlockSize;
    float* pTimersExclusive = pTimers + 4 * nBlockSize;
    float* pAverageExclusive = pTimers + 5 * nBlockSize;
    float* pMaxExclusive = pTimers + 6 * nBlockSize;
    MicroProfileCalcTimers(pTimers, pAverage, pMax, pCallAverage, pTimersExclusive, pAverageExclusive, pMaxExclusive, nActiveGroup, nNumTimers);
    uint32_t nWidth = 0;
    {
        uint32_t nMetaIndex = 0;
        for(uint32_t i = 1; i ; i <<= 1)
        {
            if(S.nBars & i)
            {
                if(i >= MP_DRAW_META_FIRST)
                {
                    if(nMetaIndex < MICROPROFILE_META_MAX && S.MetaCounters[nMetaIndex].pName)
                    {
                        uint32_t nStrWidth = strlen(S.MetaCounters[nMetaIndex].pName);
                        if(S.nBars & MP_DRAW_TIMERS)
                            nWidth += 6 + (1+MICROPROFILE_TEXT_WIDTH) * (nStrWidth);
                        if(S.nBars & MP_DRAW_AVERAGE)
                            nWidth += 6 + (1+MICROPROFILE_TEXT_WIDTH) * (nStrWidth + 4);
                        if(S.nBars & MP_DRAW_MAX)
                            nWidth += 6 + (1+MICROPROFILE_TEXT_WIDTH) * (nStrWidth + 4);
                    }
                }
                else
                {
                    nWidth += MICROPROFILE_BAR_WIDTH + 6 + 6 * (1+MICROPROFILE_TEXT_WIDTH);
                    if(i & MP_DRAW_CALL_COUNT)
                        nWidth += 6 + 6 * MICROPROFILE_TEXT_WIDTH;
                }
            }
            if(i >= MP_DRAW_META_FIRST)
            {
                ++nMetaIndex;
            }
        }
        nWidth += (1+nMaxTimerNameLen) * (MICROPROFILE_TEXT_WIDTH+1);
        for(uint32_t i = 0; i < nNumTimers+nNumGroups+1; ++i)
        {
            uint32_t nY0 = nY + i * (nHeight + 1);
            bool bInside = (UI.nActiveMenu == UINT32_MAX) && ((UI.nMouseY >= nY0) && (UI.nMouseY < (nY0 + nHeight + 1)));
            MicroProfileDrawBox(nX, nY0, nWidth+nX, nY0 + (nHeight+1)+1, UI.nOpacityBackground | (g_nMicroProfileBackColors[nColorIndex++ & 1] + ((bInside) ? 0x002c2c2c : 0)));
        }
        nX += 10;
    }
    int nTotalHeight = (nNumTimers+nNumGroups+1) * (nHeight+1);
    uint32_t nLegendOffset = 1;
    if(S.nBars & MP_DRAW_TIMERS)
        nX += MicroProfileDrawBarArray(nX, nY, pTimers, "Time", nTotalHeight) + 1;
    if(S.nBars & MP_DRAW_AVERAGE)
        nX += MicroProfileDrawBarArray(nX, nY, pAverage, "Average", nTotalHeight) + 1;
    if(S.nBars & MP_DRAW_MAX)
        nX += MicroProfileDrawBarArray(nX, nY, pMax, (!UI.bShowSpikes) ? "Max Time" : "Max Time, Spike", nTotalHeight, UI.bShowSpikes ? pAverage : NULL) + 1;
    if(S.nBars & MP_DRAW_CALL_COUNT)
    {
        nX += MicroProfileDrawBarArray(nX, nY, pCallAverage, "Call Average", nTotalHeight) + 1;
        nX += MicroProfileDrawBarCallCount(nX, nY, "Count") + 1;
    }
    if(S.nBars & MP_DRAW_TIMERS_EXCLUSIVE)
        nX += MicroProfileDrawBarArray(nX, nY, pTimersExclusive, "Exclusive Time", nTotalHeight) + 1;
    if(S.nBars & MP_DRAW_AVERAGE_EXCLUSIVE)
        nX += MicroProfileDrawBarArray(nX, nY, pAverageExclusive, "Exclusive Average", nTotalHeight) + 1;
    if(S.nBars & MP_DRAW_MAX_EXCLUSIVE)
        nX += MicroProfileDrawBarArray(nX, nY, pMaxExclusive, (!UI.bShowSpikes) ? "Exclusive Max Time" :"Excl Max Time, Spike", nTotalHeight, UI.bShowSpikes ? pAverageExclusive : NULL) + 1;

    for(int i = 0; i < MICROPROFILE_META_MAX; ++i)
    {
        if(0 != (S.nBars & (MP_DRAW_META_FIRST<<i)) && S.MetaCounters[i].pName)
        {
            uint32_t nBufferSize = strlen(S.MetaCounters[i].pName) + 32;
            char* buffer = (char*)alloca(nBufferSize);
            if(S.nBars & MP_DRAW_TIMERS)
                nX += MicroProfileDrawBarMetaCount(nX, nY, &S.MetaCounters[i].nCounters[0], S.MetaCounters[i].pName, nTotalHeight) + 1;
            if(S.nBars & MP_DRAW_AVERAGE)
            {
                snprintf(buffer, nBufferSize-1, "%s Avg", S.MetaCounters[i].pName);
                nX += MicroProfileDrawBarMetaAverage(nX, nY, &S.MetaCounters[i].nAggregate[0], buffer, nTotalHeight) + 1;
            }
            if(S.nBars & MP_DRAW_MAX)
            {
                snprintf(buffer, nBufferSize-1, "%s Max", S.MetaCounters[i].pName);
                nX += MicroProfileDrawBarMetaCount(nX, nY, &S.MetaCounters[i].nAggregateMax[0], buffer, nTotalHeight) + 1;
            }
        }
    }
    nX = 0;
    nY = nHeight + 3 - UI.nOffsetY;
    for(uint32_t i = 0; i < nNumTimers+nNumGroups+1; ++i)
    {
        const uint32_t nY0 = nY + i * (nHeight + 1);
        const bool bInside = (UI.nActiveMenu == UINT32_MAX) && ((UI.nMouseY >= nY0) && (UI.nMouseY < (nY0 + nHeight + 1)));
        MicroProfileDrawBox(nX, nY0, nTimerWidth, nY0 + (nHeight+1)+1, 0xff0000000 | (g_nMicroProfileBackColors[nColorIndex++ & 1] + ((bInside) ? 0x002c2c2c : 0)));
    }
    nX += MicroProfileDrawBarLegend(nX, nY, nTotalHeight, nTimerWidth-5) + 1;

    for(uint32_t j = 0; j < MICROPROFILE_MAX_GROUPS; ++j)
    {
        if(nActiveGroup & (1ULL << j))
        {
            MicroProfileDrawText(nX, nY + (1+nHeight) * nLegendOffset, UINT32_MAX, S.GroupInfo[j].pName, S.GroupInfo[j].nNameLen);
            nLegendOffset += S.GroupInfo[j].nNumTimers+1;
        }
    }
    MicroProfileDrawHeader(nX, nTimerWidth-5, "Group");
    MicroProfileDrawTextRight(nTimerWidth-3, MICROPROFILE_TEXT_HEIGHT + 2, UINT32_MAX, "Timer", 5);
    MicroProfileDrawLineVertical(nTimerWidth, 0, nTotalHeight+nY, UI.nOpacityBackground|g_nMicroProfileBackColors[0]|g_nMicroProfileBackColors[1]);
    MicroProfileDrawLineHorizontal(0, nWidth, 2*MICROPROFILE_TEXT_HEIGHT + 3, UI.nOpacityBackground|g_nMicroProfileBackColors[0]|g_nMicroProfileBackColors[1]);
}

typedef const char* (*MicroProfileSubmenuCallback)(int, bool* bSelected);
typedef void (*MicroProfileClickCallback)(int);


const char* MicroProfileUIMenuMode(int nIndex, bool* bSelected)
{
    MicroProfile& S = *MicroProfileGet();
    switch(nIndex)
    {
        case 0:
            *bSelected = S.nDisplay == MP_DRAW_DETAILED;
            return "Detailed";
        case 1:
            *bSelected = S.nDisplay == MP_DRAW_BARS;
            return "Timers";
        case 2:
            *bSelected = S.nDisplay == MP_DRAW_HIDDEN;
            return "Hidden";
        case 3:
            *bSelected = true;
            return "Off";
        case 4:
            *bSelected = true;
            return "------";
        case 5:
            *bSelected = S.nForceEnable != 0;
            return "Force Enable";

        default: return 0;
    }
}

const char* MicroProfileUIMenuGroups(int nIndex, bool* bSelected)
{
    MicroProfile& S = *MicroProfileGet();
    *bSelected = false;
    if(nIndex == 0)
    {
        *bSelected = S.nAllGroupsWanted != 0;
        return "[ALL]";
    }
    else
    {
        nIndex = nIndex-1;
        if(static_cast<uint32_t>(nIndex) < UI.GroupMenuCount)
        {
            MicroProfileGroupMenuItem& Item = UI.GroupMenu[nIndex];
            static char buffer[MICROPROFILE_NAME_MAX_LEN+32];
            if(Item.nIsCategory)
            {
                uint64_t nGroupMask = S.CategoryInfo[Item.nIndex].nGroupMask;
                *bSelected = nGroupMask == (nGroupMask & S.nActiveGroupWanted);
                snprintf(buffer, sizeof(buffer)-1, "[%s]", Item.pName);
            }
            else
            {
                *bSelected = 0 != (S.nActiveGroupWanted & (1ULL << Item.nIndex));
                snprintf(buffer, sizeof(buffer)-1, "   %s", Item.pName);
            }
            return buffer;
        }
        return 0;
    }
}

const char* MicroProfileUIMenuAggregate(int nIndex, bool* bSelected)
{
    MicroProfile& S = *MicroProfileGet();
    if(static_cast<uint32_t>(nIndex) < g_MicroProfileAggregatePresets.size())
    {
        uint32_t val = g_MicroProfileAggregatePresets[nIndex];
        *bSelected = S.nAggregateFlip == val;
        if (0 == val)
        {
            return "Infinite";
        }
        else
        {
            static char buf[128];
            snprintf(buf, sizeof(buf)-1, "%7u", val);
            return buf;
        }
    }
    return 0;

}

const char* MicroProfileUIMenuTimers(int nIndex, bool* bSelected)
{
    MicroProfile& S = *MicroProfileGet();
    *bSelected = 0 != (S.nBars & (1 << nIndex));
    switch(nIndex)
    {
        case 0: return "Time";
        case 1: return "Average";
        case 2: return "Max";
        case 3: return "Call Count";
        case 4: return "Exclusive Timers";
        case 5: return "Exclusive Average";
        case 6: return "Exclusive Max";
    }
    int nMetaIndex = nIndex - 7;
    if(nMetaIndex < MICROPROFILE_META_MAX)
    {
        return S.MetaCounters[nMetaIndex].pName;
    }
    return 0;
}

const char* MicroProfileUIMenuOptions(int nIndex, bool* bSelected)
{
    MicroProfile& S = *MicroProfileGet();
    if(nIndex >= MICROPROFILE_OPTION_SIZE) return 0;
    switch(UI.Options[nIndex].nSubType)
    {
    case 0:
        *bSelected = S.fReferenceTime == g_MicroProfileReferenceTimePresets[UI.Options[nIndex].nIndex];
        break;
    case 1:
        *bSelected = UI.nOpacityBackground>>24 == g_MicroProfileOpacityPresets[UI.Options[nIndex].nIndex];
        break;
    case 2:
        *bSelected = UI.nOpacityForeground>>24 == g_MicroProfileOpacityPresets[UI.Options[nIndex].nIndex];
        break;
    case 3:
        *bSelected = UI.bShowSpikes;
        break;
#if MICROPROFILE_CONTEXT_SWITCH_TRACE
    case 4:
        {
            switch(UI.Options[nIndex].nIndex)
            {
            case 0:
                *bSelected = S.bContextSwitchRunning;
                break;
            case 1:
                *bSelected = S.bContextSwitchAllThreads;
                break;
            case 2:
                *bSelected = S.bContextSwitchNoBars;
                break;
            }
        }
        break;
#endif
    }
    return UI.Options[nIndex].Text;
}

const char* MicroProfileUIMenuPreset(int nIndex, bool* bSelected)
{
    static char buf[128];
    *bSelected = false;
    int nNumPresets = static_cast<int>(g_MicroProfilePresetNames.size());
    int nIndexSave = nIndex - nNumPresets - 1;
    if (nIndex == nNumPresets)
    {
        return "--";
    }
    else if(nIndexSave >=0 && nIndexSave < nNumPresets)
    {
        snprintf(buf, sizeof(buf)-1, "Save '%s'", g_MicroProfilePresetNames[nIndexSave]);
        return buf;
    }
    else if(nIndex < nNumPresets)
    {
        snprintf(buf, sizeof(buf)-1, "Load '%s'", g_MicroProfilePresetNames[nIndex]);
        return buf;
    }
    else
    {
        return 0;
    }
}

const char* MicroProfileUIMenuCustom(int nIndex, bool* bSelected)
{
    if(UINT32_MAX == UI.nCustomActive)
    {
        *bSelected = nIndex == 0;
    }
    else
    {
        *bSelected = nIndex-2 == static_cast<int>(UI.nCustomActive);
    }
    switch(nIndex)
    {
    case 0: return "Disable";
    case 1: return "--";
    default:
        nIndex -= 2;
        if(static_cast<uint32_t>(nIndex) < UI.nCustomCount)
        {
            return UI.Custom[nIndex].pName;
        }
        else
        {
            return 0;
        }
    }
}

const char* MicroProfileUIMenuEmpty(int nIndex, bool* bSelected)
{
    return 0;
}


void MicroProfileUIClickMode(int nIndex)
{
    MicroProfile& S = *MicroProfileGet();
    switch(nIndex)
    {
        case 0:
            S.nDisplay = MP_DRAW_DETAILED;
            break;
        case 1:
            S.nDisplay = MP_DRAW_BARS;
            break;
        case 2:
            S.nDisplay = MP_DRAW_HIDDEN;
            break;
        case 3:
            S.nDisplay = 0;
            break;
        case 4:
            break;
        case 5:
            S.nForceEnable = !S.nForceEnable;
            break;
    }
}

void MicroProfileUIClickGroups(int nIndex)
{
    MicroProfile& S = *MicroProfileGet();
    if(nIndex == 0)
        S.nAllGroupsWanted = 1-S.nAllGroupsWanted;
    else
    {
        nIndex -= 1;
        if(static_cast<uint32_t>(nIndex) < UI.GroupMenuCount)
        {
            MicroProfileGroupMenuItem& Item = UI.GroupMenu[nIndex];
            if(Item.nIsCategory)
            {
                uint64_t nGroupMask = S.CategoryInfo[Item.nIndex].nGroupMask;
                if(nGroupMask != (nGroupMask & S.nActiveGroupWanted))
                {
                    S.nActiveGroupWanted |= nGroupMask;
                }
                else
                {
                    S.nActiveGroupWanted &= ~nGroupMask;
                }
            }
            else
            {
                MP_ASSERT(Item.nIndex < S.nGroupCount);
                S.nActiveGroupWanted ^= (1ULL << Item.nIndex);
            }
        }
    }
}

void MicroProfileUIClickAggregate(int nIndex)
{
    MicroProfile& S = *MicroProfileGet();
    S.nAggregateFlip = g_MicroProfileAggregatePresets[nIndex];
    if(0 == S.nAggregateFlip)
    {
        S.nAggregateClear = 1;
    }
}

void MicroProfileUIClickTimers(int nIndex)
{
    MicroProfile& S = *MicroProfileGet();
    S.nBars ^= (1 << nIndex);
}

void MicroProfileUIClickOptions(int nIndex)
{
    MicroProfile& S = *MicroProfileGet();
    switch(UI.Options[nIndex].nSubType)
    {
    case 0:
        S.fReferenceTime = g_MicroProfileReferenceTimePresets[UI.Options[nIndex].nIndex];
        S.fRcpReferenceTime = 1.f / S.fReferenceTime;
        break;
    case 1:
        UI.nOpacityBackground = g_MicroProfileOpacityPresets[UI.Options[nIndex].nIndex]<<24;
        break;
    case 2:
        UI.nOpacityForeground = g_MicroProfileOpacityPresets[UI.Options[nIndex].nIndex]<<24;
        break;
    case 3:
        UI.bShowSpikes = !UI.bShowSpikes;
        break;
#if MICROPROFILE_CONTEXT_SWITCH_TRACE
    case 4:
        {
            switch(UI.Options[nIndex].nIndex)
            {
            case 0:
                if(S.bContextSwitchRunning)
                {
                    MicroProfileStopContextSwitchTrace();
                }
                else
                {
                    MicroProfileStartContextSwitchTrace();
                }
                break;
            case 1:
                S.bContextSwitchAllThreads = !S.bContextSwitchAllThreads;
                break;
            case 2:
                S.bContextSwitchNoBars= !S.bContextSwitchNoBars;
                break;

            }
        }
        break;
#endif
    }
}

void MicroProfileUIClickPreset(int nIndex)
{
    int nNumPresets = static_cast<int>(g_MicroProfilePresetNames.size());
    int nIndexSave = nIndex - nNumPresets - 1;
    if(nIndexSave >= 0 && nIndexSave < nNumPresets)
    {
        MicroProfileSavePreset(g_MicroProfilePresetNames[nIndexSave]);
    }
    else if(nIndex >= 0 && nIndex < nNumPresets)
    {
        MicroProfileLoadPreset(g_MicroProfilePresetNames[nIndex]);
    }
}

void MicroProfileUIClickCustom(int nIndex)
{
    if(nIndex == 0)
    {
        MicroProfileCustomGroupDisable();
    }
    else
    {
        MicroProfileCustomGroupEnable(nIndex-2);
    }

}

void MicroProfileUIClickEmpty(int nIndex)
{

}


void MicroProfileDrawMenu(uint32_t nWidth, uint32_t nHeight)
{
    MicroProfile& S = *MicroProfileGet();

    uint32_t nX = 0;
    uint32_t nY = 0;

#define SBUF_SIZE 256
    char buffer[256];
    MicroProfileDrawBox(nX, nY, nX + nWidth, nY + (MICROPROFILE_TEXT_HEIGHT+1)+1, 0xff000000|g_nMicroProfileBackColors[1]);

#define MICROPROFILE_MENU_MAX 16
    const char* pMenuText[MICROPROFILE_MENU_MAX] = {0};
    uint32_t    nMenuX[MICROPROFILE_MENU_MAX] = {0};
    uint32_t nNumMenuItems = 0;

    int nLen = snprintf(buffer, 127, "MicroProfile");
    MicroProfileDrawText(nX, nY, UINT32_MAX, buffer, nLen);
    nX += (sizeof("MicroProfile")+2) * (MICROPROFILE_TEXT_WIDTH+1);
    pMenuText[nNumMenuItems++] = "Mode";
    pMenuText[nNumMenuItems++] = "Groups";
    char AggregateText[64];
    snprintf(AggregateText, sizeof(AggregateText)-1, "Aggregate[%d]", S.nAggregateFlip ? S.nAggregateFlip : S.nAggregateFlipCount);
    pMenuText[nNumMenuItems++] = &AggregateText[0];
    pMenuText[nNumMenuItems++] = "Timers";
    pMenuText[nNumMenuItems++] = "Options";
    pMenuText[nNumMenuItems++] = "Preset";
    pMenuText[nNumMenuItems++] = "Custom";
    const int nPauseIndex = nNumMenuItems;
    pMenuText[nNumMenuItems++] = S.nRunning ? "Pause" : "Unpause";
    pMenuText[nNumMenuItems++] = "Help";

    if(S.nOverflow)
    {
        pMenuText[nNumMenuItems++] = "!BUFFERSFULL!";
    }


    if(UI.GroupMenuCount != S.nGroupCount + S.nCategoryCount)
    {
        UI.GroupMenuCount = S.nGroupCount + S.nCategoryCount;
        for(uint32_t i = 0; i < S.nCategoryCount; ++i)
        {
            UI.GroupMenu[i].nIsCategory = 1;
            UI.GroupMenu[i].nCategoryIndex = i;
            UI.GroupMenu[i].nIndex = i;
            UI.GroupMenu[i].pName = S.CategoryInfo[i].pName;
        }
        for(uint32_t i = 0; i < S.nGroupCount; ++i)
        {
            uint32_t idx = i + S.nCategoryCount;
            UI.GroupMenu[idx].nIsCategory = 0;
            UI.GroupMenu[idx].nCategoryIndex = S.GroupInfo[i].nCategory;
            UI.GroupMenu[idx].nIndex = i;
            UI.GroupMenu[idx].pName = S.GroupInfo[i].pName;
        }
        std::sort(&UI.GroupMenu[0], &UI.GroupMenu[UI.GroupMenuCount],
            [] (const MicroProfileGroupMenuItem& l, const MicroProfileGroupMenuItem& r) -> bool
            {
                if(l.nCategoryIndex < r.nCategoryIndex)
                {
                    return true;
                }
                else if(r.nCategoryIndex < l.nCategoryIndex)
                {
                    return false;
                }
                if(r.nIsCategory || l.nIsCategory)
                {
                    return l.nIsCategory > r.nIsCategory;
                }
                return MP_STRCASECMP(l.pName, r.pName)<0;
            }
        );
    }

    MicroProfileSubmenuCallback GroupCallback[MICROPROFILE_MENU_MAX] =
    {
        MicroProfileUIMenuMode,
        MicroProfileUIMenuGroups,
        MicroProfileUIMenuAggregate,
        MicroProfileUIMenuTimers,
        MicroProfileUIMenuOptions,
        MicroProfileUIMenuPreset,
        MicroProfileUIMenuCustom,
        MicroProfileUIMenuEmpty,
        MicroProfileUIMenuEmpty,
        MicroProfileUIMenuEmpty,
    };

    MicroProfileClickCallback CBClick[MICROPROFILE_MENU_MAX] =
    {
        MicroProfileUIClickMode,
        MicroProfileUIClickGroups,
        MicroProfileUIClickAggregate,
        MicroProfileUIClickTimers,
        MicroProfileUIClickOptions,
        MicroProfileUIClickPreset,
        MicroProfileUIClickCustom,
        MicroProfileUIClickEmpty,
        MicroProfileUIClickEmpty,
        MicroProfileUIClickEmpty,
    };


    uint32_t nSelectMenu = UINT32_MAX;
    for(uint32_t i = 0; i < nNumMenuItems; ++i)
    {
        nMenuX[i] = nX;
        uint32_t nLen = (uint32_t)strlen(pMenuText[i]);
        uint32_t nEnd = nX + nLen * (MICROPROFILE_TEXT_WIDTH+1);
        if(UI.nMouseY <= MICROPROFILE_TEXT_HEIGHT && UI.nMouseX <= nEnd && UI.nMouseX >= nX)
        {
            MicroProfileDrawBox(nX-1, nY, nX + nLen * (MICROPROFILE_TEXT_WIDTH+1), nY +(MICROPROFILE_TEXT_HEIGHT+1)+1, 0xff888888);
            nSelectMenu = i;
            if((UI.nMouseLeft || UI.nMouseRight) && i == (uint32_t)nPauseIndex)
            {
                S.nToggleRunning = 1;
            }
        }
        MicroProfileDrawText(nX, nY, UINT32_MAX, pMenuText[i], (uint32_t)strlen(pMenuText[i]));
        nX += (nLen+1) * (MICROPROFILE_TEXT_WIDTH+1);
    }
    uint32_t nMenu = nSelectMenu != UINT32_MAX ? nSelectMenu : UI.nActiveMenu;
    UI.nActiveMenu = nMenu;
    if(UINT32_MAX != nMenu)
    {
        nX = nMenuX[nMenu];
        nY += MICROPROFILE_TEXT_HEIGHT+1;
        MicroProfileSubmenuCallback CB = GroupCallback[nMenu];
        int nNumLines = 0;
        bool bSelected = false;
        const char* pString = CB(nNumLines, &bSelected);
        uint32_t nWidth = 0, nHeight = 0;
        while(pString)
        {
            nWidth = MicroProfileMax<int>(nWidth, (int)strlen(pString));
            nNumLines++;
            pString = CB(nNumLines, &bSelected);
        }
        nWidth = (2+nWidth) * (MICROPROFILE_TEXT_WIDTH+1);
        nHeight = nNumLines * (MICROPROFILE_TEXT_HEIGHT+1);
        if(UI.nMouseY <= nY + nHeight+0 && UI.nMouseY >= nY-0 && UI.nMouseX <= nX + nWidth + 0 && UI.nMouseX >= nX - 0)
        {
            UI.nActiveMenu = nMenu;
        }
        else if(nSelectMenu == UINT32_MAX)
        {
            UI.nActiveMenu = UINT32_MAX;
        }
        MicroProfileDrawBox(nX, nY, nX + nWidth, nY + nHeight, 0xff000000|g_nMicroProfileBackColors[1]);
        for(int i = 0; i < nNumLines; ++i)
        {
            bool bSelected = false;
            const char* pString = CB(i, &bSelected);
            if(UI.nMouseY >= nY && UI.nMouseY < nY + MICROPROFILE_TEXT_HEIGHT + 1)
            {
                if(UI.nMouseLeft || UI.nMouseRight)
                {
                    CBClick[nMenu](i);
                }
                MicroProfileDrawBox(nX, nY, nX + nWidth, nY + MICROPROFILE_TEXT_HEIGHT + 1, 0xff888888);
            }
            int nLen = snprintf(buffer, SBUF_SIZE-1, "%c %s", bSelected ? '*' : ' ' ,pString);
            MicroProfileDrawText(nX, nY, UINT32_MAX, buffer, nLen);
            nY += MICROPROFILE_TEXT_HEIGHT+1;
        }
    }


    {
        static char FrameTimeMessage[64];
        float fToMs = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondCpu());
        uint32_t nAggregateFrames = S.nAggregateFrames ? S.nAggregateFrames : 1;
        float fMs = fToMs * (S.nFlipTicks);
        float fAverageMs = fToMs * (S.nFlipAggregateDisplay / nAggregateFrames);
        float fMaxMs = fToMs * S.nFlipMaxDisplay;
        int nLen = snprintf(FrameTimeMessage, sizeof(FrameTimeMessage)-1, "Time[%6.2f] Avg[%6.2f] Max[%6.2f]", fMs, fAverageMs, fMaxMs);
        pMenuText[nNumMenuItems++] = &FrameTimeMessage[0];
        MicroProfileDrawText(nWidth - nLen * (MICROPROFILE_TEXT_WIDTH+1), 0, UINT32_MAX, FrameTimeMessage, nLen);
    }
}


void MicroProfileMoveGraph()
{

    int nZoom = UI.nMouseWheelDelta;
    int nPanX = 0;
    int nPanY = 0;
    static int X = 0, Y = 0;
    if(UI.nMouseDownLeft && !UI.nModDown)
    {
        nPanX = UI.nMouseX - X;
        nPanY = UI.nMouseY - Y;
    }
    X = UI.nMouseX;
    Y = UI.nMouseY;

    if(nZoom)
    {
        float fOldRange = UI.fDetailedRange;
        if(nZoom>0)
        {
            UI.fDetailedRangeTarget = UI.fDetailedRange *= UI.nModDown ? 1.40f : 1.05f;
        }
        else
        {
            float fNewDetailedRange = UI.fDetailedRange / (UI.nModDown ? 1.40f : 1.05f);
            if(fNewDetailedRange < 1e-4f) //100ns
                fNewDetailedRange = 1e-4f;
            UI.fDetailedRangeTarget = UI.fDetailedRange = fNewDetailedRange;
        }

        float fDiff = fOldRange - UI.fDetailedRange;
        float fMousePrc = MicroProfileMax((float)UI.nMouseX / UI.nWidth ,0.f);
        UI.fDetailedOffsetTarget = UI.fDetailedOffset += fDiff * fMousePrc;

    }
    if(nPanX)
    {
        UI.fDetailedOffsetTarget = UI.fDetailedOffset += -nPanX * UI.fDetailedRange / UI.nWidth;
    }
    UI.nOffsetY -= nPanY;
    UI.nOffsetX += nPanX;
    if(UI.nOffsetX > 0)
        UI.nOffsetX = 0;
    if(UI.nOffsetY<0)
        UI.nOffsetY = 0;
}

void MicroProfileDrawCustom(uint32_t nWidth, uint32_t nHeight)
{
    if(UINT32_MAX != UI.nCustomActive)
    {
        MicroProfile& S = *MicroProfileGet();
        MP_ASSERT(UI.nCustomActive < MICROPROFILE_CUSTOM_MAX);
        MicroProfileCustom* pCustom = &UI.Custom[UI.nCustomActive];
        uint32_t nCount = pCustom->nNumTimers;
        uint32_t nAggregateFrames = S.nAggregateFrames ? S.nAggregateFrames : 1;
        uint32_t nExtraOffset = 1 + ((pCustom->nFlags & MICROPROFILE_CUSTOM_STACK) != 0 ? 3 : 0);
        uint32_t nOffsetYBase = nHeight - (nExtraOffset+nCount)* (1+MICROPROFILE_TEXT_HEIGHT) - MICROPROFILE_CUSTOM_PADDING;
        uint32_t nOffsetY = nOffsetYBase;
        float fReference = pCustom->fReference;
        float fRcpReference = 1.f / fReference;
        uint32_t nReducedWidth = UI.nWidth - 2*MICROPROFILE_CUSTOM_PADDING - MICROPROFILE_GRAPH_WIDTH;

        char Buffer[MICROPROFILE_NAME_MAX_LEN*2+1];
        float* pTime = (float*)alloca(sizeof(float)*nCount);
        float* pTimeAvg = (float*)alloca(sizeof(float)*nCount);
        float* pTimeMax = (float*)alloca(sizeof(float)*nCount);
        uint32_t* pColors = (uint32_t*)alloca(sizeof(uint32_t)*nCount);
        uint32_t nMaxOffsetX = 0;
        MicroProfileDrawBox(MICROPROFILE_CUSTOM_PADDING-1, nOffsetY-1, MICROPROFILE_CUSTOM_PADDING+nReducedWidth+1, UI.nHeight - MICROPROFILE_CUSTOM_PADDING+1, 0x88000000|g_nMicroProfileBackColors[0]);

        for(uint32_t i = 0; i < nCount; ++i)
        {
            uint16_t nTimerIndex = MicroProfileGetTimerIndex(pCustom->pTimers[i]);
            uint16_t nGroupIndex = MicroProfileGetGroupIndex(pCustom->pTimers[i]);
            float fToMs = MicroProfileTickToMsMultiplier(S.GroupInfo[nGroupIndex].Type == MicroProfileTokenTypeGpu ? MicroProfileTicksPerSecondGpu() : MicroProfileTicksPerSecondCpu());
            pTime[i] = S.Frame[nTimerIndex].nTicks * fToMs;
            pTimeAvg[i] = fToMs * (S.Aggregate[nTimerIndex].nTicks / nAggregateFrames);
            pTimeMax[i] = fToMs * (S.AggregateMax[nTimerIndex]);
            pColors[i] = S.TimerInfo[nTimerIndex].nColor;
        }

        MicroProfileDrawText(MICROPROFILE_CUSTOM_PADDING + 3*MICROPROFILE_TEXT_WIDTH, nOffsetY, UINT32_MAX, "Avg", sizeof("Avg")-1);
        MicroProfileDrawText(MICROPROFILE_CUSTOM_PADDING + 13*MICROPROFILE_TEXT_WIDTH, nOffsetY, UINT32_MAX, "Max", sizeof("Max")-1);
        for(uint32_t i = 0; i < nCount; ++i)
        {
            nOffsetY += (1+MICROPROFILE_TEXT_HEIGHT);
            uint16_t nTimerIndex = MicroProfileGetTimerIndex(pCustom->pTimers[i]);
            uint16_t nGroupIndex = MicroProfileGetGroupIndex(pCustom->pTimers[i]);
            MicroProfileTimerInfo* pTimerInfo = &S.TimerInfo[nTimerIndex];
            int nSize;
            uint32_t nOffsetX = MICROPROFILE_CUSTOM_PADDING;
            nSize = snprintf(Buffer, sizeof(Buffer)-1, "%6.2f", pTimeAvg[i]);
            MicroProfileDrawText(nOffsetX, nOffsetY, UINT32_MAX, Buffer, nSize);
            nOffsetX += (nSize+2) * (MICROPROFILE_TEXT_WIDTH+1);
            nSize = snprintf(Buffer, sizeof(Buffer)-1, "%6.2f", pTimeMax[i]);
            MicroProfileDrawText(nOffsetX, nOffsetY, UINT32_MAX, Buffer, nSize);
            nOffsetX += (nSize+2) * (MICROPROFILE_TEXT_WIDTH+1);
            nSize = snprintf(Buffer, sizeof(Buffer)-1, "%s:%s", S.GroupInfo[nGroupIndex].pName, pTimerInfo->pName);
            MicroProfileDrawText(nOffsetX, nOffsetY, pTimerInfo->nColor, Buffer, nSize);
            nOffsetX += (nSize+2) * (MICROPROFILE_TEXT_WIDTH+1);
            nMaxOffsetX = MicroProfileMax(nMaxOffsetX, nOffsetX);
        }
        uint32_t nMaxWidth = nReducedWidth- nMaxOffsetX;

        if(pCustom->nFlags & MICROPROFILE_CUSTOM_BARS)
        {
            nOffsetY = nOffsetYBase;
            float* pMs = pCustom->nFlags & MICROPROFILE_CUSTOM_BAR_SOURCE_MAX ? pTimeMax : pTimeAvg;
            const char* pString = pCustom->nFlags & MICROPROFILE_CUSTOM_BAR_SOURCE_MAX ? "Max" : "Avg";
            MicroProfileDrawText(nMaxOffsetX, nOffsetY, UINT32_MAX, pString, static_cast<uint32_t>(strlen(pString)));
            int nSize = snprintf(Buffer, sizeof(Buffer)-1, "%6.2fms", fReference);
            MicroProfileDrawText(nReducedWidth - (1+nSize) * (MICROPROFILE_TEXT_WIDTH+1), nOffsetY, UINT32_MAX, Buffer, nSize);
            for(uint32_t i = 0; i < nCount; ++i)
            {
                nOffsetY += (1+MICROPROFILE_TEXT_HEIGHT);
                uint32_t nWidth = MicroProfileMin(nMaxWidth, (uint32_t)(nMaxWidth * pMs[i] * fRcpReference));
                MicroProfileDrawBox(nMaxOffsetX, nOffsetY, nMaxOffsetX+nWidth, nOffsetY+MICROPROFILE_TEXT_HEIGHT, pColors[i]|0xff000000);
            }
        }
        if(pCustom->nFlags & MICROPROFILE_CUSTOM_STACK)
        {
            nOffsetY += 2*(1+MICROPROFILE_TEXT_HEIGHT);
            const char* pString = pCustom->nFlags & MICROPROFILE_CUSTOM_STACK_SOURCE_MAX ? "Max" : "Avg";
            MicroProfileDrawText(MICROPROFILE_CUSTOM_PADDING, nOffsetY, UINT32_MAX, pString, static_cast<uint32_t>(strlen(pString)));
            int nSize = snprintf(Buffer, sizeof(Buffer)-1, "%6.2fms", fReference);
            MicroProfileDrawText(nReducedWidth - (1+nSize) * (MICROPROFILE_TEXT_WIDTH+1), nOffsetY, UINT32_MAX, Buffer, nSize);
            nOffsetY += (1+MICROPROFILE_TEXT_HEIGHT);
            float fPosX = MICROPROFILE_CUSTOM_PADDING;
            float* pMs = pCustom->nFlags & MICROPROFILE_CUSTOM_STACK_SOURCE_MAX ? pTimeMax : pTimeAvg;
            for(uint32_t i = 0; i < nCount; ++i)
            {
                float fWidth = pMs[i] * fRcpReference * nReducedWidth;
                uint32_t nX = fPosX;
                fPosX += fWidth;
                uint32_t nXEnd = fPosX;
                if(nX < nXEnd)
                {
                    MicroProfileDrawBox(nX, nOffsetY, nXEnd, nOffsetY+MICROPROFILE_TEXT_HEIGHT, pColors[i]|0xff000000);
                }
            }
        }
    }
}
void MicroProfileDraw(uint32_t nWidth, uint32_t nHeight)
{
    MICROPROFILE_SCOPE(g_MicroProfileDraw);
    MicroProfile& S = *MicroProfileGet();

    {
        static int once = 0;
        if(0 == once)
        {
            std::recursive_mutex& m = MicroProfileGetMutex();
            m.lock();
            MicroProfileInitUI();



            uint32_t nDisplay = S.nDisplay;
            MicroProfileLoadPreset(MICROPROFILE_DEFAULT_PRESET);
            once++;
            S.nDisplay = nDisplay;// dont load display, just state
            m.unlock();

        }
    }


    if(S.nDisplay)
    {
        std::recursive_mutex& m = MicroProfileGetMutex();
        m.lock();
        UI.nWidth = nWidth;
        UI.nHeight = nHeight;
        UI.nHoverToken = MICROPROFILE_INVALID_TOKEN;
        UI.nHoverTime = 0;
        UI.nHoverFrame = -1;
        if(S.nDisplay != MP_DRAW_DETAILED)
            S.nContextSwitchHoverThread = S.nContextSwitchHoverThreadAfter = S.nContextSwitchHoverThreadBefore = UINT32_MAX;
        MicroProfileMoveGraph();


        if(S.nDisplay == MP_DRAW_DETAILED)
        {
            MicroProfileDrawDetailedView(nWidth, nHeight);
        }
        else if(S.nDisplay == MP_DRAW_BARS && S.nBars)
        {
            MicroProfileDrawBarView(nWidth, nHeight);
        }

        MicroProfileDrawMenu(nWidth, nHeight);
        bool bMouseOverGraph = MicroProfileDrawGraph(nWidth, nHeight);
        MicroProfileDrawCustom(nWidth, nHeight);
        bool bHidden = S.nDisplay == MP_DRAW_HIDDEN;
        if(!bHidden)
        {
            uint32_t nLockedToolTipX = 3;
            bool bDeleted = false;
            for(int i = 0; i < MICROPROFILE_TOOLTIP_MAX_LOCKED; ++i)
            {
                int nIndex = (g_MicroProfileUI.LockedToolTipFront + i) % MICROPROFILE_TOOLTIP_MAX_LOCKED;
                if(g_MicroProfileUI.LockedToolTips[nIndex].ppStrings[0])
                {
                    uint32_t nToolTipWidth = 0, nToolTipHeight = 0;
                    MicroProfileFloatWindowSize(g_MicroProfileUI.LockedToolTips[nIndex].ppStrings, g_MicroProfileUI.LockedToolTips[nIndex].nNumStrings, 0, nToolTipWidth, nToolTipHeight, 0);
                    uint32_t nStartY = nHeight - nToolTipHeight - 2;
                    if(!bDeleted && UI.nMouseY > nStartY && UI.nMouseX > nLockedToolTipX && UI.nMouseX <= nLockedToolTipX + nToolTipWidth && (UI.nMouseLeft || UI.nMouseRight) )
                    {
                        bDeleted = true;
                        int j = i;
                        for(; j < MICROPROFILE_TOOLTIP_MAX_LOCKED-1; ++j)
                        {
                            int nIndex0 = (g_MicroProfileUI.LockedToolTipFront + j) % MICROPROFILE_TOOLTIP_MAX_LOCKED;
                            int nIndex1 = (g_MicroProfileUI.LockedToolTipFront + j+1) % MICROPROFILE_TOOLTIP_MAX_LOCKED;
                            MicroProfileStringArrayCopy(&g_MicroProfileUI.LockedToolTips[nIndex0], &g_MicroProfileUI.LockedToolTips[nIndex1]);
                        }
                        MicroProfileStringArrayClear(&g_MicroProfileUI.LockedToolTips[(g_MicroProfileUI.LockedToolTipFront + j) % MICROPROFILE_TOOLTIP_MAX_LOCKED]);
                    }
                    else
                    {
                        MicroProfileDrawFloatWindow(nLockedToolTipX, nHeight-nToolTipHeight-2, &g_MicroProfileUI.LockedToolTips[nIndex].ppStrings[0], g_MicroProfileUI.LockedToolTips[nIndex].nNumStrings, g_MicroProfileUI.nLockedToolTipColor[nIndex]);
                        nLockedToolTipX += nToolTipWidth + 4;
                    }
                }
            }

            if(UI.nActiveMenu == 8)
            {
                if(S.nDisplay & MP_DRAW_DETAILED)
                {
                    MicroProfileStringArray DetailedHelp;
                    MicroProfileStringArrayClear(&DetailedHelp);
                    MicroProfileStringArrayFormat(&DetailedHelp, "%s", MICROPROFILE_HELP_LEFT);
                    MicroProfileStringArrayAddLiteral(&DetailedHelp, "Toggle Graph");
                    MicroProfileStringArrayFormat(&DetailedHelp, "%s", MICROPROFILE_HELP_ALT);
                    MicroProfileStringArrayAddLiteral(&DetailedHelp, "Zoom");
                    MicroProfileStringArrayFormat(&DetailedHelp, "%s + %s", MICROPROFILE_HELP_MOD, MICROPROFILE_HELP_LEFT);
                    MicroProfileStringArrayAddLiteral(&DetailedHelp, "Lock Tooltip");
                    MicroProfileStringArrayAddLiteral(&DetailedHelp, "Drag");
                    MicroProfileStringArrayAddLiteral(&DetailedHelp, "Pan View");
                    MicroProfileStringArrayAddLiteral(&DetailedHelp, "Mouse Wheel");
                    MicroProfileStringArrayAddLiteral(&DetailedHelp, "Zoom");
                    MicroProfileDrawFloatWindow(nWidth, MICROPROFILE_FRAME_HISTORY_HEIGHT+20, DetailedHelp.ppStrings, DetailedHelp.nNumStrings, 0xff777777);

                    MicroProfileStringArray DetailedHistoryHelp;
                    MicroProfileStringArrayClear(&DetailedHistoryHelp);
                    MicroProfileStringArrayFormat(&DetailedHistoryHelp, "%s", MICROPROFILE_HELP_LEFT);
                    MicroProfileStringArrayAddLiteral(&DetailedHistoryHelp, "Center View");
                    MicroProfileStringArrayFormat(&DetailedHistoryHelp, "%s", MICROPROFILE_HELP_ALT);
                    MicroProfileStringArrayAddLiteral(&DetailedHistoryHelp, "Zoom to frame");
                    MicroProfileDrawFloatWindow(nWidth, 20, DetailedHistoryHelp.ppStrings, DetailedHistoryHelp.nNumStrings, 0xff777777);



                }
                else if(0 != (S.nDisplay & MP_DRAW_BARS) && S.nBars)
                {
                    MicroProfileStringArray BarHelp;
                    MicroProfileStringArrayClear(&BarHelp);
                    MicroProfileStringArrayFormat(&BarHelp, "%s", MICROPROFILE_HELP_LEFT);
                    MicroProfileStringArrayAddLiteral(&BarHelp, "Toggle Graph");
                    MicroProfileStringArrayFormat(&BarHelp, "%s + %s", MICROPROFILE_HELP_MOD, MICROPROFILE_HELP_LEFT);
                    MicroProfileStringArrayAddLiteral(&BarHelp, "Lock Tooltip");
                    MicroProfileStringArrayAddLiteral(&BarHelp, "Drag");
                    MicroProfileStringArrayAddLiteral(&BarHelp, "Pan View");
                    MicroProfileDrawFloatWindow(nWidth, MICROPROFILE_FRAME_HISTORY_HEIGHT+20, BarHelp.ppStrings, BarHelp.nNumStrings, 0xff777777);

                }
                MicroProfileStringArray Debug;
                MicroProfileStringArrayClear(&Debug);
                MicroProfileStringArrayAddLiteral(&Debug, "Memory Usage");
                MicroProfileStringArrayFormat(&Debug, "%4.2fmb", S.nMemUsage / (1024.f * 1024.f));
                MicroProfileStringArrayAddLiteral(&Debug, "Web Server Port");
                MicroProfileStringArrayFormat(&Debug, "%d", MicroProfileWebServerPort());
                uint32_t nFrameNext = (S.nFrameCurrent+1) % MICROPROFILE_MAX_FRAME_HISTORY;
                MicroProfileFrameState* pFrameCurrent = &S.Frames[S.nFrameCurrent];
                MicroProfileFrameState* pFrameNext = &S.Frames[nFrameNext];


                MicroProfileStringArrayAddLiteral(&Debug, "");
                MicroProfileStringArrayAddLiteral(&Debug, "");
                MicroProfileStringArrayAddLiteral(&Debug, "Usage");
                MicroProfileStringArrayAddLiteral(&Debug, "markers [frames] ");

#if MICROPROFILE_CONTEXT_SWITCH_TRACE
                MicroProfileStringArrayAddLiteral(&Debug, "Context Switch");
                MicroProfileStringArrayFormat(&Debug, "%9d [%7d]", S.nContextSwitchUsage, MICROPROFILE_CONTEXT_SWITCH_BUFFER_SIZE / S.nContextSwitchUsage );
#endif

                for(int i = 0; i < MICROPROFILE_MAX_THREADS; ++i)
                {
                    if(pFrameCurrent->nLogStart[i] && S.Pool[i])
                    {
                        uint32_t nEnd = pFrameNext->nLogStart[i];
                        uint32_t nStart = pFrameCurrent->nLogStart[i];
                        uint32_t nUsage = nStart < nEnd ? (nEnd - nStart) : (nEnd + MICROPROFILE_BUFFER_SIZE - nStart);
                        uint32_t nFrameSupport = MICROPROFILE_BUFFER_SIZE / nUsage;
                        MicroProfileStringArrayFormat(&Debug, "%s", &S.Pool[i]->ThreadName[0]);
                        MicroProfileStringArrayFormat(&Debug, "%9d [%7d]", nUsage, nFrameSupport);
                    }
                }

                MicroProfileDrawFloatWindow(0, nHeight-10, Debug.ppStrings, Debug.nNumStrings, 0xff777777);
            }



            if(UI.nActiveMenu == UINT32_MAX && !bMouseOverGraph)
            {
                if(UI.nHoverToken != MICROPROFILE_INVALID_TOKEN)
                {
                    MicroProfileDrawFloatTooltip(UI.nMouseX, UI.nMouseY, UI.nHoverToken, UI.nHoverTime);
                }
                else if(S.nContextSwitchHoverThreadAfter != UINT32_MAX && S.nContextSwitchHoverThreadBefore != UINT32_MAX)
                {
                    float fToMs = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondCpu());
                    MicroProfileStringArray ToolTip;
                    MicroProfileStringArrayClear(&ToolTip);
                    MicroProfileStringArrayAddLiteral(&ToolTip, "Context Switch");
                    MicroProfileStringArrayFormat(&ToolTip, "%04x", S.nContextSwitchHoverThread);
                    MicroProfileStringArrayAddLiteral(&ToolTip, "Before");
                    MicroProfileStringArrayFormat(&ToolTip, "%04x", S.nContextSwitchHoverThreadBefore);
                    MicroProfileStringArrayAddLiteral(&ToolTip, "After");
                    MicroProfileStringArrayFormat(&ToolTip, "%04x", S.nContextSwitchHoverThreadAfter);
                    MicroProfileStringArrayAddLiteral(&ToolTip, "Duration");
                    int64_t nDifference = MicroProfileLogTickDifference(S.nContextSwitchHoverTickIn, S.nContextSwitchHoverTickOut);
                    MicroProfileStringArrayFormat(&ToolTip, "%6.2fms", fToMs * nDifference );
                    MicroProfileStringArrayAddLiteral(&ToolTip, "CPU");
                    MicroProfileStringArrayFormat(&ToolTip, "%d", S.nContextSwitchHoverCpu);
                    MicroProfileDrawFloatWindow(UI.nMouseX, UI.nMouseY+20, &ToolTip.ppStrings[0], ToolTip.nNumStrings, UINT32_MAX);


                }
                else if(UI.nHoverFrame != -1)
                {
                    uint32_t nNextFrame = (UI.nHoverFrame+1)%MICROPROFILE_MAX_FRAME_HISTORY;
                    int64_t nTick = S.Frames[UI.nHoverFrame].nFrameStartCpu;
                    int64_t nTickNext = S.Frames[nNextFrame].nFrameStartCpu;
                    int64_t nTickGpu = S.Frames[UI.nHoverFrame].nFrameStartGpu;
                    int64_t nTickNextGpu = S.Frames[nNextFrame].nFrameStartGpu;

                    float fToMs = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondCpu());
                    float fToMsGpu = MicroProfileTickToMsMultiplier(MicroProfileTicksPerSecondGpu());
                    float fMs = fToMs * (nTickNext - nTick);
                    float fMsGpu = fToMsGpu * (nTickNextGpu - nTickGpu);
                    MicroProfileStringArray ToolTip;
                    MicroProfileStringArrayClear(&ToolTip);
                    MicroProfileStringArrayFormat(&ToolTip, "Frame %d", UI.nHoverFrame);
    #if MICROPROFILE_DEBUG
                    MicroProfileStringArrayFormat(&ToolTip, "%p", &S.Frames[UI.nHoverFrame]);
    #else
                    MicroProfileStringArrayAddLiteral(&ToolTip, "");
    #endif
                    MicroProfileStringArrayAddLiteral(&ToolTip, "CPU Time");
                    MicroProfileStringArrayFormat(&ToolTip, "%6.2fms", fMs);
                    MicroProfileStringArrayAddLiteral(&ToolTip, "GPU Time");
                    MicroProfileStringArrayFormat(&ToolTip, "%6.2fms", fMsGpu);
                    #if MICROPROFILE_DEBUG
                    for(int i = 0; i < MICROPROFILE_MAX_THREADS; ++i)
                    {
                        if(S.Frames[UI.nHoverFrame].nLogStart[i])
                        {
                            MicroProfileStringArrayFormat(&ToolTip, "%d", i);
                            MicroProfileStringArrayFormat(&ToolTip, "%d", S.Frames[UI.nHoverFrame].nLogStart[i]);
                        }
                    }
                    #endif
                    MicroProfileDrawFloatWindow(UI.nMouseX, UI.nMouseY+20, &ToolTip.ppStrings[0], ToolTip.nNumStrings, UINT32_MAX);
                }
                if(UI.nMouseLeft)
                {
                    if(UI.nHoverToken != MICROPROFILE_INVALID_TOKEN)
                        MicroProfileToggleGraph(UI.nHoverToken);
                }
            }
        }

#if MICROPROFILE_DRAWCURSOR
        {
            float fCursor[8] =
            {
                MicroProfileMax(0, (int)UI.nMouseX-3), UI.nMouseY,
                MicroProfileMin(nWidth, UI.nMouseX+3), UI.nMouseY,
                UI.nMouseX, MicroProfileMax((int)UI.nMouseY-3, 0),
                UI.nMouseX, MicroProfileMin(nHeight, UI.nMouseY+3),
            };
            MicroProfileDrawLine2D(2, &fCursor[0], 0xff00ff00);
            MicroProfileDrawLine2D(2, &fCursor[4], 0xff00ff00);
        }
#endif
        m.unlock();
    }
    else if(UI.nCustomActive != UINT32_MAX)
    {
        std::recursive_mutex& m = MicroProfileGetMutex();
        m.lock();
        MicroProfileDrawGraph(nWidth, nHeight);
        MicroProfileDrawCustom(nWidth, nHeight);
        m.unlock();

    }
    UI.nMouseLeft = UI.nMouseRight = 0;
    UI.nMouseLeftMod = UI.nMouseRightMod = 0;
    UI.nMouseWheelDelta = 0;
    if(S.nOverflow)
        S.nOverflow--;

    UI.fDetailedOffset = UI.fDetailedOffset + (UI.fDetailedOffsetTarget - UI.fDetailedOffset) * MICROPROFILE_ANIM_DELAY_PRC;
    UI.fDetailedRange = UI.fDetailedRange + (UI.fDetailedRangeTarget - UI.fDetailedRange) * MICROPROFILE_ANIM_DELAY_PRC;


}

bool MicroProfileIsDrawing()
{
    MicroProfile& S = *MicroProfileGet();
    return S.nDisplay != 0;
}

void MicroProfileToggleGraph(MicroProfileToken nToken)
{
    MicroProfile& S = *MicroProfileGet();
    uint32_t nTimerId = MicroProfileGetTimerIndex(nToken);
    nToken &= 0xffff;
    int32_t nMinSort = 0x7fffffff;
    int32_t nFreeIndex = -1;
    int32_t nMinIndex = 0;
    int32_t nMaxSort = 0x80000000;
    for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
    {
        if(S.Graph[i].nToken == MICROPROFILE_INVALID_TOKEN)
            nFreeIndex = i;
        if(S.Graph[i].nToken == nToken)
        {
            S.Graph[i].nToken = MICROPROFILE_INVALID_TOKEN;
            S.TimerInfo[nTimerId].bGraph = false;
            return;
        }
        if(S.Graph[i].nKey < nMinSort)
        {
            nMinSort = S.Graph[i].nKey;
            nMinIndex = i;
        }
        if(S.Graph[i].nKey > nMaxSort)
        {
            nMaxSort = S.Graph[i].nKey;
        }
    }
    int nIndex = nFreeIndex > -1 ? nFreeIndex : nMinIndex;
    if (nFreeIndex == -1)
    {
        uint32_t idx = MicroProfileGetTimerIndex(S.Graph[nIndex].nToken);
        S.TimerInfo[idx].bGraph = false;
    }
    S.Graph[nIndex].nToken = nToken;
    S.Graph[nIndex].nKey = nMaxSort+1;
    memset(&S.Graph[nIndex].nHistory[0], 0, sizeof(S.Graph[nIndex].nHistory));
    S.TimerInfo[nTimerId].bGraph = true;
}


void MicroProfileMousePosition(uint32_t nX, uint32_t nY, int nWheelDelta)
{
    UI.nMouseX = nX;
    UI.nMouseY = nY;
    UI.nMouseWheelDelta = nWheelDelta;
}

void MicroProfileModKey(uint32_t nKeyState)
{
    UI.nModDown = nKeyState ? 1 : 0;
}

void MicroProfileClearGraph()
{
    MicroProfile& S = *MicroProfileGet();
    for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
    {
        if(S.Graph[i].nToken != 0)
        {
            S.Graph[i].nToken = MICROPROFILE_INVALID_TOKEN;
        }
    }
}

void MicroProfileMouseButton(uint32_t nLeft, uint32_t nRight)
{
    bool bCanRelease = abs((int)(UI.nMouseDownX - UI.nMouseX)) + abs((int)(UI.nMouseDownY - UI.nMouseY)) < 3;

    if(0 == nLeft && UI.nMouseDownLeft && bCanRelease)
    {
        if(UI.nModDown)
            UI.nMouseLeftMod = 1;
        else
            UI.nMouseLeft = 1;
    }

    if(0 == nRight && UI.nMouseDownRight && bCanRelease)
    {
        if(UI.nModDown)
            UI.nMouseRightMod = 1;
        else
            UI.nMouseRight = 1;
    }
    if((nLeft || nRight) && !(UI.nMouseDownLeft || UI.nMouseDownRight))
    {
        UI.nMouseDownX = UI.nMouseX;
        UI.nMouseDownY = UI.nMouseY;
    }

    UI.nMouseDownLeft = nLeft;
    UI.nMouseDownRight = nRight;

}

void MicroProfileDrawLineVertical(int nX, int nTop, int nBottom, uint32_t nColor)
{
    MicroProfileDrawBox(nX, nTop, nX + 1, nBottom, nColor);
}

void MicroProfileDrawLineHorizontal(int nLeft, int nRight, int nY, uint32_t nColor)
{
    MicroProfileDrawBox(nLeft, nY, nRight, nY + 1, nColor);
}



#include <stdio.h>

#define MICROPROFILE_PRESET_HEADER_MAGIC 0x28586813
#define MICROPROFILE_PRESET_HEADER_VERSION 0x00000102
struct MicroProfilePresetHeader
{
    uint32_t nMagic;
    uint32_t nVersion;
    //groups, threads, aggregate, reference frame, graphs timers
    uint32_t nGroups[MICROPROFILE_MAX_GROUPS];
    uint32_t nThreads[MICROPROFILE_MAX_THREADS];
    uint32_t nGraphName[MICROPROFILE_MAX_GRAPHS];
    uint32_t nGraphGroupName[MICROPROFILE_MAX_GRAPHS];
    uint32_t nAllGroupsWanted;
    uint32_t nAllThreadsWanted;
    uint32_t nAggregateFlip;
    float fReferenceTime;
    uint32_t nBars;
    uint32_t nDisplay;
    uint32_t nOpacityBackground;
    uint32_t nOpacityForeground;
    uint32_t nShowSpikes;
};

#ifndef MICROPROFILE_PRESET_FILENAME_FUNC
#define MICROPROFILE_PRESET_FILENAME_FUNC MicroProfilePresetFilename
static const char* MicroProfilePresetFilename(const char* pSuffix)
{
    static char filename[512];
    snprintf(filename, sizeof(filename)-1, ".microprofilepreset.%s", pSuffix);
    return filename;
}
#endif

void MicroProfileSavePreset(const char* pPresetName)
{
    std::lock_guard<std::recursive_mutex> Lock(MicroProfileGetMutex());
    FILE* F = fopen(MICROPROFILE_PRESET_FILENAME_FUNC(pPresetName), "wb");
    if(!F) return;

    MicroProfile& S = *MicroProfileGet();

    MicroProfilePresetHeader Header;
    memset(&Header, 0, sizeof(Header));
    Header.nAggregateFlip = S.nAggregateFlip;
    Header.nBars = S.nBars;
    Header.fReferenceTime = S.fReferenceTime;
    Header.nAllGroupsWanted = S.nAllGroupsWanted;
    Header.nAllThreadsWanted = S.nAllThreadsWanted;
    Header.nMagic = MICROPROFILE_PRESET_HEADER_MAGIC;
    Header.nVersion = MICROPROFILE_PRESET_HEADER_VERSION;
    Header.nDisplay = S.nDisplay;
    Header.nOpacityBackground = UI.nOpacityBackground;
    Header.nOpacityForeground = UI.nOpacityForeground;
    Header.nShowSpikes = UI.bShowSpikes ? 1 : 0;
    fwrite(&Header, sizeof(Header), 1, F);
    uint64_t nMask = 1;
    for(uint32_t i = 0; i < MICROPROFILE_MAX_GROUPS; ++i)
    {
        if(S.nActiveGroupWanted & nMask)
        {
            uint32_t offset = ftell(F);
            const char* pName = S.GroupInfo[i].pName;
            int nLen = (int)strlen(pName)+1;
            fwrite(pName, nLen, 1, F);
            Header.nGroups[i] = offset;
        }
        nMask <<= 1;
    }
    for(uint32_t i = 0; i < MICROPROFILE_MAX_THREADS; ++i)
    {
        MicroProfileThreadLog* pLog = S.Pool[i];
        if(pLog && S.nThreadActive[i])
        {
            uint32_t nOffset = ftell(F);
            const char* pName = &pLog->ThreadName[0];
            int nLen = (int)strlen(pName)+1;
            fwrite(pName, nLen, 1, F);
            Header.nThreads[i] = nOffset;
        }
    }
    for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
    {
        MicroProfileToken nToken = S.Graph[i].nToken;
        if(nToken != MICROPROFILE_INVALID_TOKEN)
        {
            uint32_t nGroupIndex = MicroProfileGetGroupIndex(nToken);
            uint32_t nTimerIndex = MicroProfileGetTimerIndex(nToken);
            const char* pGroupName = S.GroupInfo[nGroupIndex].pName;
            const char* pTimerName = S.TimerInfo[nTimerIndex].pName;
            MP_ASSERT(pGroupName);
            MP_ASSERT(pTimerName);
            int nGroupLen = (int)strlen(pGroupName)+1;
            int nTimerLen = (int)strlen(pTimerName)+1;

            uint32_t nOffsetGroup = ftell(F);
            fwrite(pGroupName, nGroupLen, 1, F);
            uint32_t nOffsetTimer = ftell(F);
            fwrite(pTimerName, nTimerLen, 1, F);
            Header.nGraphName[i] = nOffsetTimer;
            Header.nGraphGroupName[i] = nOffsetGroup;
        }
    }
    fseek(F, 0, SEEK_SET);
    fwrite(&Header, sizeof(Header), 1, F);

    fclose(F);

}



void MicroProfileLoadPreset(const char* pSuffix)
{
    std::lock_guard<std::recursive_mutex> Lock(MicroProfileGetMutex());
    FILE* F = fopen(MICROPROFILE_PRESET_FILENAME_FUNC(pSuffix), "rb");
    if(!F)
    {
        return;
    }
    fseek(F, 0, SEEK_END);
    int nSize = ftell(F);
    char* const pBuffer = (char*)alloca(nSize);
    fseek(F, 0, SEEK_SET);
    int nRead = (int)fread(pBuffer, nSize, 1, F);
    fclose(F);
    if(1 != nRead)
        return;

    MicroProfile& S = *MicroProfileGet();

    MicroProfilePresetHeader& Header = *(MicroProfilePresetHeader*)pBuffer;

    if(Header.nMagic != MICROPROFILE_PRESET_HEADER_MAGIC || Header.nVersion != MICROPROFILE_PRESET_HEADER_VERSION)
    {
        return;
    }

    S.nAggregateFlip = Header.nAggregateFlip;
    S.nBars = Header.nBars;
    S.fReferenceTime = Header.fReferenceTime;
    S.fRcpReferenceTime = 1.f / Header.fReferenceTime;
    S.nAllGroupsWanted = Header.nAllGroupsWanted;
    S.nAllThreadsWanted = Header.nAllThreadsWanted;
    S.nDisplay = Header.nDisplay;
    S.nActiveGroupWanted = 0;
    UI.nOpacityBackground = Header.nOpacityBackground;
    UI.nOpacityForeground = Header.nOpacityForeground;
    UI.bShowSpikes = Header.nShowSpikes == 1;

    memset(&S.nThreadActive[0], 0, sizeof(S.nThreadActive));

    for(uint32_t i = 0; i < MICROPROFILE_MAX_GROUPS; ++i)
    {
        if(Header.nGroups[i])
        {
            const char* pGroupName = pBuffer + Header.nGroups[i];
            for(uint32_t j = 0; j < MICROPROFILE_MAX_GROUPS; ++j)
            {
                if(0 == MP_STRCASECMP(pGroupName, S.GroupInfo[j].pName))
                {
                    S.nActiveGroupWanted |= (1ULL << j);
                }
            }
        }
    }
    for(uint32_t i = 0; i < MICROPROFILE_MAX_THREADS; ++i)
    {
        if(Header.nThreads[i])
        {
            const char* pThreadName = pBuffer + Header.nThreads[i];
            for(uint32_t j = 0; j < MICROPROFILE_MAX_THREADS; ++j)
            {
                MicroProfileThreadLog* pLog = S.Pool[j];
                if(pLog && 0 == MP_STRCASECMP(pThreadName, &pLog->ThreadName[0]))
                {
                    S.nThreadActive[j] = 1;
                }
            }
        }
    }
    for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
    {
        MicroProfileToken nPrevToken = S.Graph[i].nToken;
        S.Graph[i].nToken = MICROPROFILE_INVALID_TOKEN;
        if(Header.nGraphName[i] && Header.nGraphGroupName[i])
        {
            const char* pGraphName = pBuffer + Header.nGraphName[i];
            const char* pGraphGroupName = pBuffer + Header.nGraphGroupName[i];
            for(uint32_t j = 0; j < S.nTotalTimers; ++j)
            {
                uint64_t nGroupIndex = S.TimerInfo[j].nGroupIndex;
                if(0 == MP_STRCASECMP(pGraphName, S.TimerInfo[j].pName) && 0 == MP_STRCASECMP(pGraphGroupName, S.GroupInfo[nGroupIndex].pName))
                {
                    MicroProfileToken nToken = MicroProfileMakeToken(1ULL << nGroupIndex, (uint16_t)j);
                    S.Graph[i].nToken = nToken;         // note: group index is stored here but is checked without in MicroProfileToggleGraph()!
                    S.TimerInfo[j].bGraph = true;
                    if(nToken != nPrevToken)
                    {
                        memset(&S.Graph[i].nHistory, 0, sizeof(S.Graph[i].nHistory));
                    }
                    break;
                }
            }
        }
    }
}

uint32_t MicroProfileCustomGroupFind(const char* pCustomName)
{
    for(uint32_t i = 0; i < UI.nCustomCount; ++i)
    {
        if(!MP_STRCASECMP(pCustomName, UI.Custom[i].pName))
        {
            return i;
        }
    }
    return UINT32_MAX;
}

uint32_t MicroProfileCustomGroup(const char* pCustomName)
{
    for(uint32_t i = 0; i < UI.nCustomCount; ++i)
    {
        if(!MP_STRCASECMP(pCustomName, UI.Custom[i].pName))
        {
            return i;
        }
    }
    MP_ASSERT(UI.nCustomCount < MICROPROFILE_CUSTOM_MAX);
    uint32_t nIndex = UI.nCustomCount;
    UI.nCustomCount++;
    memset(&UI.Custom[nIndex], 0, sizeof(UI.Custom[nIndex]));
    size_t nLen = strlen(pCustomName);
    if(nLen > MICROPROFILE_NAME_MAX_LEN-1)
        nLen = MICROPROFILE_NAME_MAX_LEN-1;
    memcpy(&UI.Custom[nIndex].pName[0], pCustomName, nLen);
    UI.Custom[nIndex].pName[nLen] = '\0';
    return nIndex;
}
void MicroProfileCustomGroup(const char* pCustomName, uint32_t nMaxTimers, uint32_t nAggregateFlip, float fReferenceTime, uint32_t nFlags)
{
    uint32_t nIndex = MicroProfileCustomGroup(pCustomName);
    MP_ASSERT(UI.Custom[nIndex].pTimers == 0);//only call once!
    UI.Custom[nIndex].pTimers = &UI.CustomTimer[UI.nCustomTimerCount];
    UI.Custom[nIndex].nMaxTimers = nMaxTimers;
    UI.Custom[nIndex].fReference = fReferenceTime;
    UI.nCustomTimerCount += nMaxTimers;
    MP_ASSERT(UI.nCustomTimerCount <= MICROPROFILE_CUSTOM_MAX_TIMERS); //bump MICROPROFILE_CUSTOM_MAX_TIMERS
    UI.Custom[nIndex].nFlags = nFlags;
    UI.Custom[nIndex].nAggregateFlip = nAggregateFlip;
}

void MicroProfileCustomGroupEnable(uint32_t nIndex)
{
    if(nIndex < UI.nCustomCount)
    {
        MicroProfile& S = *MicroProfileGet();
        S.nForceGroupUI = UI.Custom[nIndex].nGroupMask;
        MicroProfileSetAggregateFrames(UI.Custom[nIndex].nAggregateFlip);
        S.fReferenceTime = UI.Custom[nIndex].fReference;
        S.fRcpReferenceTime = 1.f / UI.Custom[nIndex].fReference;
        UI.nCustomActive = nIndex;

        for(uint32_t i = 0; i < MICROPROFILE_MAX_GRAPHS; ++i)
        {
            if(S.Graph[i].nToken != MICROPROFILE_INVALID_TOKEN)
            {
                uint32_t nTimerId = MicroProfileGetTimerIndex(S.Graph[i].nToken);
                S.TimerInfo[nTimerId].bGraph = false;
                S.Graph[i].nToken = MICROPROFILE_INVALID_TOKEN;
            }
        }

        for(uint32_t i = 0; i < UI.Custom[nIndex].nNumTimers; ++i)
        {
            if(i == MICROPROFILE_MAX_GRAPHS)
            {
                break;
            }
            S.Graph[i].nToken = UI.Custom[nIndex].pTimers[i];
            S.Graph[i].nKey = i;
            uint32_t nTimerId = MicroProfileGetTimerIndex(S.Graph[i].nToken);
            S.TimerInfo[nTimerId].bGraph = true;
        }
    }
}

void MicroProfileCustomGroupToggle(const char* pCustomName)
{
    uint32_t nIndex = MicroProfileCustomGroupFind(pCustomName);
    if(nIndex == UINT32_MAX || nIndex == UI.nCustomActive)
    {
        MicroProfileCustomGroupDisable();
    }
    else
    {
        MicroProfileCustomGroupEnable(nIndex);
    }
}

void MicroProfileCustomGroupEnable(const char* pCustomName)
{
    uint32_t nIndex = MicroProfileCustomGroupFind(pCustomName);
    MicroProfileCustomGroupEnable(nIndex);
}
void MicroProfileCustomGroupDisable()
{
    MicroProfile& S = *MicroProfileGet();
    S.nForceGroupUI = 0;
    UI.nCustomActive = UINT32_MAX;
}

void MicroProfileCustomGroupAddTimer(const char* pCustomName, const char* pGroup, const char* pTimer)
{
    uint32_t nIndex = MicroProfileCustomGroupFind(pCustomName);
    if(UINT32_MAX == nIndex)
    {
        return;
    }
    uint32_t nTimerIndex = UI.Custom[nIndex].nNumTimers;
    MP_ASSERT(nTimerIndex < UI.Custom[nIndex].nMaxTimers);
    uint64_t nToken = MicroProfileFindToken(pGroup, pTimer);
    MP_ASSERT(nToken != MICROPROFILE_INVALID_TOKEN); //Timer must be registered first.
    UI.Custom[nIndex].pTimers[nTimerIndex] = nToken;
    uint16_t nGroup = MicroProfileGetGroupIndex(nToken);
    UI.Custom[nIndex].nGroupMask |= (1ULL << nGroup);
    UI.Custom[nIndex].nNumTimers++;
}

#undef UI

#endif
#endif
