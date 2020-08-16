/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 2002 Ben Parnell
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <algorithm>

#include "common.h"
#include "debugger.h"
#include "../../x6502.h"
#include "../../fceu.h"
#include "../../cart.h" //mbg merge 7/19/06 moved after fceu.h
#include "../../file.h"
#include "../../debug.h"
#include "../../asm.h"
#include "../../version.h"
#include "cdlogger.h"
#include "tracer.h"
#include "memview.h"
#include "main.h" //for GetRomName()
#include "utils/xstring.h"

//Used to determine the current hotkey mapping for the pause key in order to display on the dialog
#include "mapinput.h"
#include "input.h"

using namespace std;

//#define LOG_SKIP_UNMAPPED 4
//#define LOG_ADD_PERIODS 8

// ################################## Start of SP CODE ###########################

#include "debuggersp.h"

extern Name* pageNames[32];
extern int pageNumbersLoaded[32];
extern Name* ramBankNames;

// ################################## End of SP CODE ###########################

//int logaxy = 1, logopdata = 1; //deleteme
int logging_options = LOG_REGISTERS | LOG_PROCESSOR_STATUS | LOG_TO_THE_LEFT | LOG_MESSAGES | LOG_BREAKPOINTS | LOG_CODE_TABBING;
int log_update_window = 0;
//int tracer_open=0;
volatile int logtofile = 0, logging = 0;

HWND hTracer;
bool tracerIsReadyForResizing = false;
int tracerMinWidth = 0;
int tracerMinHeight = 0;
int Tracer_wndx = 0, Tracer_wndy = 0;
int Tracer_wndWidth = 640, Tracer_wndHeight = 500;
int tracerInitialClientWidth = 0, tracerInitialClientHeight = 0;
int tracerCurrentClientWidth = 0, tracerCurrentClientHeight = 0;

// this structure stores the data of an existing window pos and how it should be resized. The data is calculated at runtime
struct WindowItemPosData
{
	HWND itemHWND;
	int initialLeft;
	int initialTop;
	int initialRight;
	int initialBottom;
	unsigned int leftResizeType;
	unsigned int topResizeType;
	unsigned int rightResizeType;
	unsigned int bottomResizeType;
};
std::vector<WindowItemPosData> arrayOfWindowItemPosData;	// the data is filled in WM_INITDIALOG

// this structure holds the data how a known item should be resized. The data is prepared
struct KnownWindowItemPosData
{
	int id;
	unsigned int leftResizeType;
	unsigned int topResizeType;
	unsigned int rightResizeType;
	unsigned int bottomResizeType;
};
//  not all window items have to be mentioned here, others will be resized by default method (WINDOW_ITEM_RESIZE_TYPE_MULTIPLY, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_MULTIPLY, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED)
KnownWindowItemPosData tracerKnownWindowItems[] = {
	IDC_TRACER_LOG, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	IDC_SCRL_TRACER_LOG, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	IDC_BTN_START_STOP_LOGGING, WINDOW_ITEM_RESIZE_TYPE_CENTER_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_CENTER_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	IDC_RADIO_LOG_LAST, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	IDC_TRACER_LOG_SIZE, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	IDC_TEXT_LINES_TO_THIS_WINDOW, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	IDC_RADIO_LOG_TO_FILE, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
	IDC_BTN_LOG_BROWSE, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_LEFT_ALIGNED, WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED,
};

int log_optn_intlst[LOG_OPTION_SIZE]  = {3000000, 1000000, 300000, 100000, 30000, 10000, 3000, 1000, 300, 100};
char *log_optn_strlst[LOG_OPTION_SIZE] = {"3 000 000", "1 000 000", "300 000", "100 000", "30 000", "10 000", "3000", "1000", "300", "100"};
int log_lines_option = 5;	// 10000 lines by default
char *logfilename = 0;
int oldcodecount, olddatacount;

SCROLLINFO tracesi;

char **tracelogbuf = 0;
std::vector<std::vector<uint16>> tracelogbufAddressesLog;
int tracelogbufsize = 0, tracelogbufpos = 0;
int tracelogbufusedsize = 0;

char str_axystate[LOG_AXYSTATE_MAX_LEN] = {0}, str_procstatus[LOG_PROCSTATUS_MAX_LEN] = {0};
char str_tabs[LOG_TABS_MASK+1] = {0}, str_address[LOG_ADDRESS_MAX_LEN] = {0}, str_data[LOG_DATA_MAX_LEN] = {0}, str_disassembly[LOG_DISASSEMBLY_MAX_LEN] = {0};
char str_result[LOG_LINE_MAX_LEN] = {0};
char str_temp[LOG_LINE_MAX_LEN] = {0};
char str_decoration[NL_MAX_MULTILINE_COMMENT_LEN + 10] = {0};
char str_decoration_comment[NL_MAX_MULTILINE_COMMENT_LEN + 10] = {0};
char* tracer_decoration_comment;
char* tracer_decoration_comment_end_pos;
std::vector<uint16> tempAddressesLog;

bool log_old_emu_paused = true;		// thanks to this flag the window only updates once after the game is paused
extern bool JustFrameAdvanced;
extern int currFrameCounter;

FILE *LOG_FP;

char trace_str[35000] = {0};
WNDPROC IDC_TRACER_LOG_oldWndProc = 0;

void ShowLogDirDialog(void);
void BeginLoggingSequence(void);
void ClearTraceLogBuf();
void EndLoggingSequence();
void UpdateLogWindow(void);
void ScrollLogWindowToLastLine();
void UpdateLogText(void);
void EnableTracerMenuItems(void);
int PromptForCDLogger(void);

// returns the address, or EOF if selection cursor points to something else
int Tracer_CheckClickingOnAnAddressOrSymbolicName(unsigned int lineNumber, bool onlyCheckWhenNothingSelected)
{
	if (!tracelogbufsize)
		return EOF;

	// trace_str contains the text in the log window
	int sel_start, sel_end;
	SendDlgItemMessage(hTracer, IDC_TRACER_LOG, EM_GETSEL, (WPARAM)&sel_start, (LPARAM)&sel_end);
	if (onlyCheckWhenNothingSelected)
		if (sel_end > sel_start)
			return EOF;

	// find the "$" before sel_start
	int i = sel_start - 1;
	for (; i > sel_start - 6; i--)
		if (i >= 0 && trace_str[i] == '$')
			break;
	if (i > sel_start - 6)
	{
		char offsetBuffer[5];
		strncpy(offsetBuffer, trace_str + i + 1, 4);
		offsetBuffer[4] = 0;
		// invalidate the string if a space or \r is found in it
		char* firstspace = strstr(offsetBuffer, " ");
		if (!firstspace)
			firstspace = strstr(offsetBuffer, "\r");
		if (!firstspace)
		{
			unsigned int offset;
			if (sscanf(offsetBuffer, "%4X", &offset) != EOF)
			{
				// select the text
				SendDlgItemMessage(hTracer, IDC_TRACER_LOG, EM_SETSEL, (WPARAM)(i + 1), (LPARAM)(i + 5));
				if (hDebug)
					PrintOffsetToSeekAndBookmarkFields(offset);
				return (int)offset;
			}
		}
	}

	if (tracelogbufusedsize == tracelogbufsize)
		lineNumber = (tracelogbufpos + lineNumber) % tracelogbufsize;

	if (lineNumber < tracelogbufAddressesLog.size())
	{
		uint16 addr;
		Name* node;
		char* name;
		int nameLen;
		char* start_pos;
		char* pos;
	
		for (i = tracelogbufAddressesLog[lineNumber].size() - 1; i >= 0; i--)
		{
			addr = tracelogbufAddressesLog[lineNumber][i];
			node = findNode(getNamesPointerForAddress(addr), addr);
			if (node && node->name && *(node->name))
			{
				name = node->name;
				nameLen = strlen(name);
				if (sel_start - nameLen <= 0)
					start_pos = trace_str;
				else
					start_pos = trace_str + (sel_start - nameLen);
				pos = strstr(start_pos, name);
				if (pos && pos <= trace_str + sel_start)
				{
					// clicked on the operand name
					// select the text
					SendDlgItemMessage(hTracer, IDC_TRACER_LOG, EM_SETSEL, (WPARAM)(int)(pos - trace_str), (LPARAM)((int)(pos - trace_str) + nameLen));
					if (hDebug)
						PrintOffsetToSeekAndBookmarkFields(addr);
					return (int)addr;
				}
			}
		}
	}
	
	return EOF;
}

BOOL CALLBACK IDC_TRACER_LOG_WndProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	switch(uMsg)
	{
		case WM_LBUTTONDBLCLK:
		{
			int offset = Tracer_CheckClickingOnAnAddressOrSymbolicName(tracesi.nPos + (GET_Y_LPARAM(lParam) / debugSystem->fixedFontHeight), false);
			if (offset != EOF)
			{
				// open Debugger at this address
				DoDebug(0);
				if (hDebug)
				{
					Disassemble(hDebug, IDC_DEBUGGER_DISASSEMBLY, IDC_DEBUGGER_DISASSEMBLY_VSCR, offset);
					PrintOffsetToSeekAndBookmarkFields(offset);
				}
			}
			return 0;
		}
		case WM_LBUTTONUP:
		{
			Tracer_CheckClickingOnAnAddressOrSymbolicName(tracesi.nPos + (GET_Y_LPARAM(lParam) / debugSystem->fixedFontHeight), true);
			break;
		}
		case WM_RBUTTONDOWN:
		{
			// if nothing is selected, simulate Left-click
			int sel_start, sel_end;
			SendDlgItemMessage(hTracer, IDC_TRACER_LOG, EM_GETSEL, (WPARAM)&sel_start, (LPARAM)&sel_end);
			if (sel_start == sel_end)
			{
				CallWindowProc(IDC_TRACER_LOG_oldWndProc, hwndDlg, WM_LBUTTONDOWN, wParam, lParam);
				CallWindowProc(IDC_TRACER_LOG_oldWndProc, hwndDlg, WM_LBUTTONUP, wParam, lParam);
				return 0;
			}
			break;
		}
		case WM_RBUTTONUP:
		{
			// save current selection
			int sel_start, sel_end;
			SendDlgItemMessage(hTracer, IDC_TRACER_LOG, EM_GETSEL, (WPARAM)&sel_start, (LPARAM)&sel_end);
			// simulate a click
			CallWindowProc(IDC_TRACER_LOG_oldWndProc, hwndDlg, WM_LBUTTONDOWN, wParam, lParam);
			CallWindowProc(IDC_TRACER_LOG_oldWndProc, hwndDlg, WM_LBUTTONUP, wParam, lParam);
			// try bringing Symbolic Debug Naming dialog
			int offset = Tracer_CheckClickingOnAnAddressOrSymbolicName(tracesi.nPos + (GET_Y_LPARAM(lParam) / debugSystem->fixedFontHeight), false);
			if (offset != EOF)
			{
				if (DoSymbolicDebugNaming(offset, hTracer))
				{
					if (hDebug)
						UpdateDebugger(false);
					if (hMemView)
						UpdateCaption();
				} else
				{
					// then restore old selection
					SendDlgItemMessage(hTracer, IDC_TRACER_LOG, EM_SETSEL, (WPARAM)sel_start, (LPARAM)sel_end);
				}
				return 0;
			} else
			{
				// then restore old selection
				SendDlgItemMessage(hTracer, IDC_TRACER_LOG, EM_SETSEL, (WPARAM)sel_start, (LPARAM)sel_end);
			}
			break;
		}
		case WM_MOUSEWHEEL:
		{
			SendMessage(GetDlgItem(hTracer, IDC_SCRL_TRACER_LOG), uMsg, wParam, lParam);
			return 0;
		}
	}
	return CallWindowProc(IDC_TRACER_LOG_oldWndProc, hwndDlg, uMsg, wParam, lParam);
}

BOOL CALLBACK TracerInitialEnumWindowsProc(HWND hwnd, LPARAM lParam)
{
	RECT rect;
	POINT p;

	// create new WindowItemPosData with default settings of resizing the item
	WindowItemPosData windowItemPosData;
	windowItemPosData.itemHWND = hwnd;
	GetWindowRect(hwnd, &rect);
	p.x = rect.left;
	p.y = rect.top;
	ScreenToClient(hTracer, &p);
	windowItemPosData.initialLeft = p.x;
	windowItemPosData.initialTop = p.y;
	p.x = rect.right;
	p.y = rect.bottom;
	ScreenToClient(hTracer, &p);
	windowItemPosData.initialRight = p.x;
	windowItemPosData.initialBottom = p.y;
	windowItemPosData.leftResizeType = WINDOW_ITEM_RESIZE_TYPE_MULTIPLY;
	windowItemPosData.topResizeType = WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED;
	windowItemPosData.rightResizeType = WINDOW_ITEM_RESIZE_TYPE_MULTIPLY;
	windowItemPosData.bottomResizeType = WINDOW_ITEM_RESIZE_TYPE_RIGHT_ALIGNED;

	// try to find the info in tracerKnownWindowItems
	int controlID = GetDlgCtrlID(hwnd);
	int sizeofKnownWindowItemPosData = sizeof(KnownWindowItemPosData);
	int tracerKnownWindowItemsTotal = sizeof(tracerKnownWindowItems) / sizeofKnownWindowItemPosData;
	int i;
	for (i = 0; i < tracerKnownWindowItemsTotal; ++i)
	{
		if (tracerKnownWindowItems[i].id == controlID)
			break;
	}
	if (i < tracerKnownWindowItemsTotal)
	{
		// this item is known, so its resizing method may differ from defaults
		windowItemPosData.leftResizeType = tracerKnownWindowItems[i].leftResizeType;
		windowItemPosData.topResizeType = tracerKnownWindowItems[i].topResizeType;
		windowItemPosData.rightResizeType = tracerKnownWindowItems[i].rightResizeType;
		windowItemPosData.bottomResizeType = tracerKnownWindowItems[i].bottomResizeType;
	}

	arrayOfWindowItemPosData.push_back(windowItemPosData);
	return TRUE;
}
BOOL CALLBACK TracerResizingEnumWindowsProc(HWND hwnd, LPARAM lParam)
{
	// find the data about resizing type
	for (int i = arrayOfWindowItemPosData.size() - 1; i >= 0; i--)
	{
		if (arrayOfWindowItemPosData[i].itemHWND == hwnd)
		{
			// recalculate the coordinates according to the resizing type of the item
			int left = recalculateResizedItemCoordinate(arrayOfWindowItemPosData[i].initialLeft, tracerInitialClientWidth, tracerCurrentClientWidth, arrayOfWindowItemPosData[i].leftResizeType);
			int top = recalculateResizedItemCoordinate(arrayOfWindowItemPosData[i].initialTop, tracerInitialClientHeight, tracerCurrentClientHeight, arrayOfWindowItemPosData[i].topResizeType);
			int right = recalculateResizedItemCoordinate(arrayOfWindowItemPosData[i].initialRight, tracerInitialClientWidth, tracerCurrentClientWidth, arrayOfWindowItemPosData[i].rightResizeType);
			int bottom = recalculateResizedItemCoordinate(arrayOfWindowItemPosData[i].initialBottom, tracerInitialClientHeight, tracerCurrentClientHeight, arrayOfWindowItemPosData[i].bottomResizeType);
			SetWindowPos(hwnd, 0, left, top, right - left, bottom - top, SWP_NOZORDER | SWP_NOOWNERZORDER);
			return TRUE;
		}
	}
	return TRUE;
}

BOOL CALLBACK TracerCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	int i;
	switch(uMsg)
	{
		case WM_INITDIALOG:
		{
			hTracer = hwndDlg;
			// calculate initial size/positions of items
			RECT mainRect;
			GetClientRect(hTracer, &mainRect);
			tracerInitialClientWidth = mainRect.right;
			tracerInitialClientHeight = mainRect.bottom;
			// set min size of the window to current size
			GetWindowRect(hTracer, &mainRect);
			tracerMinWidth = mainRect.right - mainRect.left;
			tracerMinHeight = mainRect.bottom - mainRect.top;
			if (Tracer_wndWidth < tracerMinWidth)
				Tracer_wndWidth = tracerMinWidth;
			if (Tracer_wndHeight < tracerMinHeight)
				Tracer_wndHeight = tracerMinHeight;
			// remember initial positions of all items
			EnumChildWindows(hTracer, TracerInitialEnumWindowsProc, 0);
			// restore position and size from config, also bring the window on top
			if (Tracer_wndx==-32000) Tracer_wndx=0; //Just in case
			if (Tracer_wndy==-32000) Tracer_wndy=0;
			SetWindowPos(hTracer, HWND_TOP, Tracer_wndx, Tracer_wndy, Tracer_wndWidth, Tracer_wndHeight, SWP_NOOWNERZORDER);
			
			// calculate tracesi.nPage
			RECT wrect;
			GetClientRect(GetDlgItem(hwndDlg, IDC_TRACER_LOG), &wrect);
			tracesi.nPage = wrect.bottom / debugSystem->fixedFontHeight;

			// setup font
			SendDlgItemMessage(hwndDlg, IDC_TRACER_LOG, WM_SETFONT, (WPARAM)debugSystem->hFixedFont, FALSE);

			//check the disabled radio button
			CheckRadioButton(hwndDlg,IDC_RADIO_LOG_LAST,IDC_RADIO_LOG_TO_FILE,IDC_RADIO_LOG_LAST);

			//EnableWindow(GetDlgItem(hwndDlg,IDC_SCRL_TRACER_LOG),FALSE);
			// fill in the options for the log size
			for(i = 0;i < LOG_OPTION_SIZE;i++)
			{
				SendDlgItemMessage(hwndDlg, IDC_TRACER_LOG_SIZE, CB_INSERTSTRING, -1, (LPARAM)(LPSTR)log_optn_strlst[i]);
			}
			SendDlgItemMessage(hwndDlg, IDC_TRACER_LOG_SIZE, CB_SETCURSEL, (WPARAM)log_lines_option, 0);
			strcpy(trace_str, "Welcome to the Trace Logger.");
			SetDlgItemText(hwndDlg, IDC_TRACER_LOG, trace_str);
			logtofile = 0;

			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_REGISTERS, (logging_options & LOG_REGISTERS) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_PROCESSOR_STATUS, (logging_options & LOG_PROCESSOR_STATUS) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_NEW_INSTRUCTIONS, (logging_options & LOG_NEW_INSTRUCTIONS) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_NEW_DATA, (logging_options & LOG_NEW_DATA) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_STATUSES_TO_THE_LEFT, (logging_options & LOG_TO_THE_LEFT) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_FRAMES_COUNT, (logging_options & LOG_FRAMES_COUNT) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_CYCLES_COUNT, (logging_options & LOG_CYCLES_COUNT) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_INSTRUCTIONS_COUNT, (logging_options & LOG_INSTRUCTIONS_COUNT) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_MESSAGES, (logging_options & LOG_MESSAGES) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_BREAKPOINTS, (logging_options & LOG_BREAKPOINTS) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_SYMBOLIC_TRACING, (logging_options & LOG_SYMBOLIC) ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_CHECK_CODE_TABBING, (logging_options & LOG_CODE_TABBING) ? BST_CHECKED : BST_UNCHECKED);
			
			EnableWindow(GetDlgItem(hwndDlg, IDC_TRACER_LOG_SIZE), TRUE);
			EnableWindow(GetDlgItem(hwndDlg, IDC_BTN_LOG_BROWSE), FALSE);
			CheckDlgButton(hwndDlg, IDC_CHECK_LOG_UPDATE_WINDOW, log_update_window ? BST_CHECKED : BST_UNCHECKED);
			EnableTracerMenuItems();

			// subclass editfield
			IDC_TRACER_LOG_oldWndProc = (WNDPROC)SetWindowLong(GetDlgItem(hwndDlg, IDC_TRACER_LOG), GWL_WNDPROC, (LONG)IDC_TRACER_LOG_WndProc);
			break;
		}
		case WM_WINDOWPOSCHANGED:
		{
			WINDOWPOS* windowpos = (WINDOWPOS*)lParam;
			if (!(windowpos->flags & SWP_NOSIZE))
			{
				// window was resized
				if (!IsIconic(hwndDlg))
				{
					if (arrayOfWindowItemPosData.size())
					{
						RECT mainRect;
						GetWindowRect(hTracer, &mainRect);
						Tracer_wndWidth = mainRect.right - mainRect.left;
						Tracer_wndHeight = mainRect.bottom - mainRect.top;
						// resize all items
						GetClientRect(hTracer, &mainRect);
						tracerCurrentClientWidth = mainRect.right;
						tracerCurrentClientHeight = mainRect.bottom;
						EnumChildWindows(hTracer, TracerResizingEnumWindowsProc, 0);
						InvalidateRect(hTracer, 0, TRUE);
					}
					// recalculate tracesi.nPage
					RECT wrect;
					GetClientRect(GetDlgItem(hwndDlg, IDC_TRACER_LOG), &wrect);
					int newPageSize = wrect.bottom / debugSystem->fixedFontHeight;
					if (tracesi.nPage != newPageSize)
					{
						tracesi.nPage = newPageSize;
						if ((tracesi.nPos + (int)tracesi.nPage) > tracesi.nMax)
							tracesi.nPos = tracesi.nMax - (int)tracesi.nPage;
						if (tracesi.nPos < tracesi.nMin)
							tracesi.nPos = tracesi.nMin;
						SetScrollInfo(GetDlgItem(hTracer, IDC_SCRL_TRACER_LOG), SB_CTL, &tracesi, TRUE);
						if (!logtofile)
							UpdateLogText();
					}
				}
			}
			if (!(windowpos->flags & SWP_NOMOVE))
			{
				// window was moved
				if (!IsIconic(hwndDlg) && arrayOfWindowItemPosData.size())
				{
					RECT mainRect;
					GetWindowRect(hTracer, &mainRect);
					Tracer_wndWidth = mainRect.right - mainRect.left;
					Tracer_wndHeight = mainRect.bottom - mainRect.top;
					Tracer_wndx = mainRect.left;
					Tracer_wndy = mainRect.top;
					WindowBoundsCheckNoResize(Tracer_wndx, Tracer_wndy, mainRect.right);
				}
			}
			break;
		}
		case WM_GETMINMAXINFO:
		{
			if (tracerMinWidth)
			{
				((MINMAXINFO*)lParam)->ptMinTrackSize.x = tracerMinWidth;
				((MINMAXINFO*)lParam)->ptMinTrackSize.y = tracerMinHeight;
			}
			break;
		}
		case WM_CLOSE:
		case WM_QUIT:
			if (logging)
				EndLoggingSequence();
			ClearTraceLogBuf();
			hTracer = 0;
			EndDialog(hwndDlg,0);
			break;
		case WM_COMMAND:
			switch(HIWORD(wParam))
			{
				case BN_CLICKED:
				{
					switch(LOWORD(wParam))
					{
						case IDC_BTN_START_STOP_LOGGING:
							if (logging)
								EndLoggingSequence();
							else
								BeginLoggingSequence();
							EnableTracerMenuItems();
							break;
						case IDC_RADIO_LOG_LAST:
							logtofile = 0;
							EnableTracerMenuItems();
							break;
						case IDC_RADIO_LOG_TO_FILE:
							logtofile = 1;
							EnableTracerMenuItems();
							break;
						case IDC_CHECK_LOG_REGISTERS:
							logging_options ^= LOG_REGISTERS;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_REGISTERS, (logging_options & LOG_REGISTERS) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_PROCESSOR_STATUS:
							logging_options ^= LOG_PROCESSOR_STATUS;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_PROCESSOR_STATUS, (logging_options & LOG_PROCESSOR_STATUS) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_STATUSES_TO_THE_LEFT:
							logging_options ^= LOG_TO_THE_LEFT;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_STATUSES_TO_THE_LEFT, (logging_options & LOG_TO_THE_LEFT) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_FRAMES_COUNT:
							logging_options ^= LOG_FRAMES_COUNT;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_FRAMES_COUNT, (logging_options & LOG_FRAMES_COUNT) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_CYCLES_COUNT:
							logging_options ^= LOG_CYCLES_COUNT;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_CYCLES_COUNT, (logging_options & LOG_CYCLES_COUNT) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_INSTRUCTIONS_COUNT:
							logging_options ^= LOG_INSTRUCTIONS_COUNT;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_INSTRUCTIONS_COUNT, (logging_options & LOG_INSTRUCTIONS_COUNT) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_MESSAGES:
							logging_options ^= LOG_MESSAGES;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_MESSAGES, (logging_options & LOG_MESSAGES) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_BREAKPOINTS:
							logging_options ^= LOG_BREAKPOINTS;
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_BREAKPOINTS, (logging_options & LOG_BREAKPOINTS) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_SYMBOLIC_TRACING:
							logging_options ^= LOG_SYMBOLIC;
							CheckDlgButton(hwndDlg, IDC_CHECK_SYMBOLIC_TRACING, (logging_options & LOG_SYMBOLIC) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_CODE_TABBING:
							logging_options ^= LOG_CODE_TABBING;
							CheckDlgButton(hwndDlg, IDC_CHECK_CODE_TABBING, (logging_options & LOG_CODE_TABBING) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_NEW_INSTRUCTIONS:
							logging_options ^= LOG_NEW_INSTRUCTIONS;
							if(logging && (!PromptForCDLogger()))
								logging_options &= ~LOG_NEW_INSTRUCTIONS; //turn it back off
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_NEW_INSTRUCTIONS, (logging_options & LOG_NEW_INSTRUCTIONS) ? BST_CHECKED : BST_UNCHECKED);
							//EnableTracerMenuItems();
							break;
						case IDC_CHECK_LOG_NEW_DATA:
							logging_options ^= LOG_NEW_DATA;
							if(logging && (!PromptForCDLogger()))
								logging_options &= ~LOG_NEW_DATA; //turn it back off
							CheckDlgButton(hwndDlg, IDC_CHECK_LOG_NEW_DATA, (logging_options & LOG_NEW_DATA) ? BST_CHECKED : BST_UNCHECKED);
							break;
						case IDC_CHECK_LOG_UPDATE_WINDOW:
						{
							//todo: if this gets unchecked then we need to clear out the window
							log_update_window ^= 1;
							if(!FCEUI_EmulationPaused() && !log_update_window)
							{
								// Assemble the message to pause the game.  Uses the current hotkey mapping dynamically
								strcpy(trace_str, "Pause the game (press ");
								strcat(trace_str, GetKeyComboName(FCEUD_CommandMapping[EMUCMD_PAUSE]));
								strcat(trace_str, " key or snap the Debugger) to update this window.\r\n");
								SetDlgItemText(hTracer, IDC_TRACER_LOG, trace_str);
							}
							break;
						}
						case IDC_BTN_LOG_BROWSE:
							ShowLogDirDialog();
							break;
					}
					break;
				}
			}
			break;
		case WM_MOVING:
			break;

		case WM_VSCROLL:
		{
			if (lParam)
			{
				if (!tracelogbuf)
					break;

				if (!FCEUI_EmulationPaused() && !log_update_window)
					break;

				GetScrollInfo((HWND)lParam,SB_CTL,&tracesi);
				switch(LOWORD(wParam))
				{
					case SB_ENDSCROLL:
					case SB_TOP:
					case SB_BOTTOM: break;
					case SB_LINEUP: tracesi.nPos--; break;
					case SB_LINEDOWN:tracesi.nPos++; break;
					case SB_PAGEUP: tracesi.nPos -= tracesi.nPage; break;
					case SB_PAGEDOWN: tracesi.nPos += tracesi.nPage; break;
					case SB_THUMBPOSITION: //break;
					case SB_THUMBTRACK: tracesi.nPos = tracesi.nTrackPos; break;
				}
				if ((tracesi.nPos + (int)tracesi.nPage) > tracesi.nMax)
					tracesi.nPos = tracesi.nMax - (int)tracesi.nPage;
				if (tracesi.nPos < tracesi.nMin)
					tracesi.nPos = tracesi.nMin;
				SetScrollInfo((HWND)lParam,SB_CTL,&tracesi,TRUE);
				UpdateLogText();
			}
			break;
		}
		case WM_MOUSEWHEEL:
		{
			GetScrollInfo(GetDlgItem(hTracer, IDC_SCRL_TRACER_LOG), SB_CTL, &tracesi);
			i = GET_WHEEL_DELTA_WPARAM(wParam) / WHEEL_DELTA;
			if (i < -1 || i > 1)
				i *= 2;
			tracesi.nPos -= i;
			if ((tracesi.nPos + (int)tracesi.nPage) > tracesi.nMax)
				tracesi.nPos = tracesi.nMax - tracesi.nPage;
			if (tracesi.nPos < tracesi.nMin)
				tracesi.nPos = tracesi.nMin;
			SetScrollInfo(GetDlgItem(hTracer, IDC_SCRL_TRACER_LOG), SB_CTL, &tracesi, TRUE);
			UpdateLogText();
			break;
		}
	}
	return FALSE;
}

void BeginLoggingSequence(void)
{
	char str2[100];
	int i, j;

	if (!PromptForCDLogger())
		return; //do nothing if user selected no and CD Logger is needed

	if (logtofile)
	{
		if(logfilename == NULL) ShowLogDirDialog();
		if (!logfilename) return;
		LOG_FP = fopen(logfilename,"w");
		if (LOG_FP == NULL)
		{
			sprintf(trace_str, "Error Opening File %s", logfilename);
			MessageBox(hTracer, trace_str, "File Error", MB_OK);
			return;
		}
		fprintf(LOG_FP,FCEU_NAME_AND_VERSION" - Trace Log File\n"); //mbg merge 7/19/06 changed string
	} else
	{
		ClearTraceLogBuf();
		// create new log
		log_lines_option = SendDlgItemMessage(hTracer, IDC_TRACER_LOG_SIZE, CB_GETCURSEL, 0, 0);
		if (log_lines_option == CB_ERR)
			log_lines_option = 0;
		strcpy(trace_str, "Allocating Memory...\r\n");
		SetDlgItemText(hTracer, IDC_TRACER_LOG, trace_str);
		tracelogbufsize = j = log_optn_intlst[log_lines_option];
		tracelogbuf = (char**)malloc(j * sizeof(char *));
		for (i = 0;i < j;i++)
		{
			tracelogbuf[i] = (char*)malloc(LOG_LINE_MAX_LEN);
			tracelogbuf[i][0] = 0;
		}
		sprintf(str2, "%d Bytes Allocated...\r\n", j * LOG_LINE_MAX_LEN);
		strcat(trace_str, str2);
		tracelogbufAddressesLog.resize(0);
		tracelogbufAddressesLog.resize(tracelogbufsize);
		// Assemble the message to pause the game.  Uses the current hotkey mapping dynamically
		strcat(trace_str, "Pause the game (press ");
		strcat(trace_str, GetKeyComboName(FCEUD_CommandMapping[EMUCMD_PAUSE]));
		strcat(trace_str, " key or snap the Debugger) to update this window.\r\n");
		SetDlgItemText(hTracer, IDC_TRACER_LOG, trace_str);
		tracelogbufpos = tracelogbufusedsize = 0;
	}
	
	oldcodecount = codecount;
	olddatacount = datacount;

	logging=1;
	SetDlgItemText(hTracer, IDC_BTN_START_STOP_LOGGING,"Stop Logging");
	return;
}

//todo: really speed this up
void FCEUD_TraceInstruction(uint8 *opcode, int size)
{
	if (!logging)
		return;

	unsigned int addr = X.PC;
	uint8 tmp;
	static int unloggedlines;

	// if instruction executed from the RAM, skip this, log all instead
	// TODO: loops folding mame-lyke style
	if (GetPRGAddress(addr) != -1)
	{
		if(((logging_options & LOG_NEW_INSTRUCTIONS) && (oldcodecount != codecount)) ||
		   ((logging_options & LOG_NEW_DATA) && (olddatacount != datacount)))
		{
			//something new was logged
			oldcodecount = codecount;
			olddatacount = datacount;
			if(unloggedlines > 0)
			{
				sprintf(str_result, "(%d lines skipped)", unloggedlines);
				OutputLogLine(str_result);
				unloggedlines = 0;
			}
		} else
		{
			if((logging_options & LOG_NEW_INSTRUCTIONS) ||
				(logging_options & LOG_NEW_DATA))
			{
				if(FCEUI_GetLoggingCD())
					unloggedlines++;
				return;
			}
		}
	}

	if ((addr + size) > 0xFFFF)
	{
		sprintf(str_data, "%02X        ", opcode[0]);
		sprintf(str_disassembly, "OVERFLOW");
	} else
	{
		char* a = 0;
		switch (size)
		{
			case 0:
				sprintf(str_data, "%02X        ", opcode[0]);
				sprintf(str_disassembly,"UNDEFINED");
				break;
			case 1:
			{
				sprintf(str_data, "%02X        ", opcode[0]);
				a = Disassemble(addr + 1, opcode);
				// special case: an RTS opcode
				if (opcode[0] == 0x60)
				{
					// add the beginning address of the subroutine that we exit from
					unsigned int caller_addr = GetMem(((X.S) + 1)|0x0100) + (GetMem(((X.S) + 2)|0x0100) << 8) - 0x2;
					if (GetMem(caller_addr) == 0x20)
					{
						// this was a JSR instruction - take the subroutine address from it
						unsigned int call_addr = GetMem(caller_addr + 1) + (GetMem(caller_addr + 2) << 8);
						sprintf(str_decoration, " (from $%04X)", call_addr);
						strcat(a, str_decoration);
					}
				}
				break;
			}
			case 2:
				sprintf(str_data, "%02X %02X     ", opcode[0],opcode[1]);
				a = Disassemble(addr + 2, opcode);
				break;
			case 3:
				sprintf(str_data, "%02X %02X %02X  ", opcode[0],opcode[1],opcode[2]);
				a = Disassemble(addr + 3, opcode);
				break;
		}

		if (a)
		{
			if (logging_options & LOG_SYMBOLIC)
			{
				loadNameFiles();
				tempAddressesLog.resize(0);
				// Insert Name and Comment lines if needed
				Name* node = findNode(getNamesPointerForAddress(addr), addr);
				if (node)
				{
					if (node->name)
					{
						strcpy(str_decoration, node->name);
						strcat(str_decoration, ":");
						tempAddressesLog.push_back(addr);
						OutputLogLine(str_decoration, &tempAddressesLog);
					}
					if (node->comment)
					{
						// make a copy
						strcpy(str_decoration_comment, node->comment);
						strcat(str_decoration_comment, "\r\n");
						tracer_decoration_comment = str_decoration_comment;
						// divide the str_decoration_comment into strings (Comment1, Comment2, ...)
						char* tracer_decoration_comment_end_pos = strstr(tracer_decoration_comment, "\r\n");
						while (tracer_decoration_comment_end_pos)
						{
							tracer_decoration_comment_end_pos[0] = 0;		// set \0 instead of \r
							strcpy(str_decoration, "; ");
							strcat(str_decoration, tracer_decoration_comment);
							OutputLogLine(str_decoration, &tempAddressesLog);
							tracer_decoration_comment_end_pos += 2;
							tracer_decoration_comment = tracer_decoration_comment_end_pos;
							tracer_decoration_comment_end_pos = strstr(tracer_decoration_comment_end_pos, "\r\n");
						}
					}
				}
				
				replaceNames(ramBankNames, a, &tempAddressesLog);
				for(int i=0;i<ARRAY_SIZE(pageNames);i++)
					replaceNames(pageNames[i], a, &tempAddressesLog);
			}
			strncpy(str_disassembly, a, LOG_DISASSEMBLY_MAX_LEN);
			str_disassembly[LOG_DISASSEMBLY_MAX_LEN - 1] = 0;
		}
	}

	if (size == 1 && GetMem(addr) == 0x60)
	{
		// special case: an RTS opcode
		// add "----------" to emphasize the end of subroutine
		strcat(str_disassembly, " ");
		int i = strlen(str_disassembly);
		for (; i < (LOG_DISASSEMBLY_MAX_LEN - 2); ++i)
			str_disassembly[i] = '-';
		str_disassembly[i] = 0;
	}
	// stretch the disassembly string out if we have to output other stuff.
	if ((logging_options & (LOG_REGISTERS|LOG_PROCESSOR_STATUS)) && !(logging_options & LOG_TO_THE_LEFT))
	{
		for (int i = strlen(str_disassembly); i < (LOG_DISASSEMBLY_MAX_LEN - 1); ++i)
			str_disassembly[i] = ' ';
		str_disassembly[LOG_DISASSEMBLY_MAX_LEN - 1] = 0;
	}

	// Start filling the str_temp line: Frame count, Cycles count, Instructions count, AXYS state, Processor status, Tabs, Address, Data, Disassembly
	if (logging_options & LOG_FRAMES_COUNT)
	{
		sprintf(str_result, "f%-6u ", currFrameCounter);
	} else
	{
		str_result[0] = 0;
	}
	if (logging_options & LOG_CYCLES_COUNT)
	{
		int64 counter_value = timestampbase + (uint64)timestamp - total_cycles_base;
		if (counter_value < 0)	// sanity check
		{
			ResetDebugStatisticsCounters();
			counter_value = 0;
		}
		sprintf(str_temp, "c%-11llu ", counter_value);
		strcat(str_result, str_temp);
	}
	if (logging_options & LOG_INSTRUCTIONS_COUNT)
	{
		sprintf(str_temp, "i%-11llu ", total_instructions);
		strcat(str_result, str_temp);
	}
	
	if (logging_options & LOG_REGISTERS)
	{
		sprintf(str_axystate,"A:%02X X:%02X Y:%02X S:%02X ",(X.A),(X.X),(X.Y),(X.S));
	}
	
	if (logging_options & LOG_PROCESSOR_STATUS)
	{
		tmp = X.P^0xFF;
		sprintf(str_procstatus,"P:%c%c%c%c%c%c%c%c ",
			'N'|(tmp&0x80)>>2,
			'V'|(tmp&0x40)>>1,
			'U'|(tmp&0x20),
			'B'|(tmp&0x10)<<1,
			'D'|(tmp&0x08)<<2,
			'I'|(tmp&0x04)<<3,
			'Z'|(tmp&0x02)<<4,
			'C'|(tmp&0x01)<<5
			);
	}

	if (logging_options & LOG_TO_THE_LEFT)
	{
		if (logging_options & LOG_REGISTERS)
			strcat(str_result, str_axystate);
		if (logging_options & LOG_PROCESSOR_STATUS)
			strcat(str_result, str_procstatus);
	}

	if (logging_options & LOG_CODE_TABBING)
	{
		// add spaces at the beginning of the line according to stack pointer
		int spaces = (0xFF - X.S) & LOG_TABS_MASK;
		for (int i = 0; i < spaces; i++)
			str_tabs[i] = ' ';
		str_tabs[spaces] = 0;
		strcat(str_result, str_tabs);
	} else if (logging_options & LOG_TO_THE_LEFT)
	{
		strcat(str_result, " ");
	}

	sprintf(str_address, "$%04X:", addr);
	strcat(str_result, str_address);
	strcat(str_result, str_data);
	strcat(str_result, str_disassembly);

	if (!(logging_options & LOG_TO_THE_LEFT))
	{
		if (logging_options & LOG_REGISTERS)
			strcat(str_result, str_axystate);
		if (logging_options & LOG_PROCESSOR_STATUS)
			strcat(str_result, str_procstatus);
	}

	OutputLogLine(str_result, &tempAddressesLog);
	
	return;
}

void OutputLogLine(const char *str, std::vector<uint16>* addressesLog, bool add_newline)
{
	if (logtofile)
	{
		fputs(str, LOG_FP);
		if (add_newline)
			fputs("\n", LOG_FP);
		fflush(LOG_FP);
	} else
	{
		if (add_newline)
		{
			strncpy(tracelogbuf[tracelogbufpos], str, LOG_LINE_MAX_LEN - 3);
			tracelogbuf[tracelogbufpos][LOG_LINE_MAX_LEN - 3] = 0;
			strcat(tracelogbuf[tracelogbufpos], "\r\n");
		} else
		{
			strncpy(tracelogbuf[tracelogbufpos], str, LOG_LINE_MAX_LEN - 1);
			tracelogbuf[tracelogbufpos][LOG_LINE_MAX_LEN - 1] = 0;
		}

		if (addressesLog)
			tracelogbufAddressesLog[tracelogbufpos] = (*addressesLog);
		else
			tracelogbufAddressesLog[tracelogbufpos].resize(0);

		tracelogbufpos++;
		if (tracelogbufusedsize < tracelogbufsize)
			tracelogbufusedsize++;
		tracelogbufpos %= tracelogbufsize;
	}
}

void ClearTraceLogBuf(void)
{
	if (tracelogbuf)
	{
		int j = tracelogbufsize;
		for(int i = 0; i < j;i++)
		{
			free(tracelogbuf[i]);
		}
		free(tracelogbuf);
		tracelogbuf = 0;
	}
	tracelogbufAddressesLog.resize(0);
}

void EndLoggingSequence()
{
	if (logtofile)
	{
		fclose(LOG_FP);
	} else
	{
		strcpy(str_result, "Logging finished.");
		OutputLogLine(str_result);
		ScrollLogWindowToLastLine();
		UpdateLogText();
		// do not clear the log window
		// ClearTraceLogBuf();
	}
	logging = 0;
	SetDlgItemText(hTracer, IDC_BTN_START_STOP_LOGGING,"Start Logging");
}

void UpdateLogWindow(void)
{
	//we don't want to continue if the trace logger isn't logging, or if its logging to a file.
	if ((!logging) || logtofile)
		return; 

	// only update the window when some emulation occured
	// and only update the window when emulator is paused or log_update_window=true
	bool emu_paused = (FCEUI_EmulationPaused() != 0);
	if ((!emu_paused && !log_update_window) || (log_old_emu_paused && !JustFrameAdvanced))	//mbg merge 7/19/06 changd to use EmulationPaused()
	{
		log_old_emu_paused = emu_paused;
		return;
	}
	log_old_emu_paused = emu_paused;

	ScrollLogWindowToLastLine();
	UpdateLogText();
	return;
}

void ScrollLogWindowToLastLine()
{
	tracesi.cbSize = sizeof(SCROLLINFO);
	tracesi.fMask = SIF_ALL;
	tracesi.nMin = 0;
	tracesi.nMax = tracelogbufusedsize;
	tracesi.nPos = tracesi.nMax - tracesi.nPage;
	if (tracesi.nPos < tracesi.nMin)
		tracesi.nPos = tracesi.nMin;
	SetScrollInfo(GetDlgItem(hTracer,IDC_SCRL_TRACER_LOG),SB_CTL,&tracesi,TRUE);
}

void UpdateLogText(void)
{
	int j;
	trace_str[0] = 0;

	if (!tracelogbuf || !tracelogbufpos || !tracelogbufsize)
		return;

	int last_line = tracesi.nPos + tracesi.nPage;
	if (last_line > tracesi.nMax)
		last_line = tracesi.nMax;

	int i = tracesi.nPos;
	if (i < tracesi.nMin)
		i = tracesi.nMin;

	for (; i < last_line; i++)
	{
		j = i;
		if (tracelogbufusedsize == tracelogbufsize)
			j = (tracelogbufpos + i) % tracelogbufsize;
		strcat(trace_str, tracelogbuf[j]);
	}
	SetDlgItemText(hTracer, IDC_TRACER_LOG, trace_str);
	//sprintf(str,"nPage = %d, nPos = %d, nMax = %d, nMin = %d",tracesi.nPage,tracesi.nPos,tracesi.nMax,tracesi.nMin);
	//SetDlgItemText(hTracer, IDC_TRACER_STATS, str);
	return;
}

void EnableTracerMenuItems(void)
{
	if (logging)
	{
		EnableWindow(GetDlgItem(hTracer,IDC_RADIO_LOG_LAST),FALSE);
		EnableWindow(GetDlgItem(hTracer,IDC_RADIO_LOG_TO_FILE),FALSE);
		EnableWindow(GetDlgItem(hTracer,IDC_TRACER_LOG_SIZE),FALSE);
		EnableWindow(GetDlgItem(hTracer,IDC_BTN_LOG_BROWSE),FALSE);
		return;
	}

	EnableWindow(GetDlgItem(hTracer,IDC_RADIO_LOG_LAST),TRUE);
	EnableWindow(GetDlgItem(hTracer,IDC_RADIO_LOG_TO_FILE),TRUE);
	EnableWindow(GetDlgItem(hTracer,IDC_TRACER_LOG_SIZE),TRUE);
	EnableWindow(GetDlgItem(hTracer,IDC_BTN_LOG_BROWSE),TRUE);
	EnableWindow(GetDlgItem(hTracer,IDC_CHECK_LOG_NEW_INSTRUCTIONS),TRUE);

	if (logtofile)
	{
		EnableWindow(GetDlgItem(hTracer,IDC_TRACER_LOG_SIZE),FALSE);
		EnableWindow(GetDlgItem(hTracer,IDC_BTN_LOG_BROWSE),TRUE);
		log_update_window = 0;
		EnableWindow(GetDlgItem(hTracer,IDC_CHECK_LOG_UPDATE_WINDOW),FALSE);
	} else
	{
		EnableWindow(GetDlgItem(hTracer,IDC_TRACER_LOG_SIZE),TRUE);
		EnableWindow(GetDlgItem(hTracer,IDC_BTN_LOG_BROWSE),FALSE);
		EnableWindow(GetDlgItem(hTracer,IDC_CHECK_LOG_UPDATE_WINDOW),TRUE);
	}

	return;
}

//this returns 1 if the CD logger is activated when needed, or 0 if the user selected no, not to activate it
int PromptForCDLogger(void)
{
	if ((logging_options & (LOG_NEW_INSTRUCTIONS|LOG_NEW_DATA)) && (!FCEUI_GetLoggingCD()))
	{
		if (MessageBox(hTracer,"In order for some of the features you have selected to take effect,\
 the Code/Data Logger must also be running.\
 Would you like to Start the Code/Data Logger Now?","Start Code/Data Logger?",
			MB_YESNO) == IDYES)
		{
			if (DoCDLogger())
			{
				FCEUI_SetLoggingCD(1);
				SetDlgItemText(hCDLogger, BTN_CDLOGGER_START_PAUSE, "Pause");
				return 1;
			}
			return 0; // CDLogger couldn't start, probably because the game is closed
		}
		return 0; // user selected no so 0 is returned
	}
	return 1;
}

void ShowLogDirDialog(void){
	const char filter[]="6502 Trace Log File (*.log)\0*.log;*.txt\0" "6502 Trace Log File (*.txt)\0*.log;*.txt\0All Files (*.*)\0*.*\0\0"; //'" "' used to prevent octal conversion on the numbers
	char nameo[2048];
	OPENFILENAME ofn;
	memset(&ofn,0,sizeof(ofn));
	ofn.lStructSize=sizeof(ofn);
	ofn.hInstance=fceu_hInstance;
	ofn.lpstrTitle="Log Trace As...";
	ofn.lpstrFilter=filter;
	strcpy(nameo, mass_replace(GetRomName(), "|", ".").c_str());
	ofn.lpstrFile=nameo;
	ofn.nMaxFile=256;
	ofn.Flags=OFN_EXPLORER|OFN_FILEMUSTEXIST|OFN_HIDEREADONLY;
	ofn.hwndOwner = hTracer;
	if(GetSaveFileName(&ofn))
	{
		if (ofn.nFilterIndex == 1)
			AddExtensionIfMissing(nameo, sizeof(nameo), ".log");
		else if (ofn.nFilterIndex == 2)
			AddExtensionIfMissing(nameo, sizeof(nameo), ".txt");
		if(logfilename)
			free(logfilename);
		logfilename = (char*)malloc(strlen(nameo)+1); //mbg merge 7/19/06 added cast
		strcpy(logfilename,nameo);
	}
	return;
}

void DoTracer()
{
	if (!GameInfo)
	{
		FCEUD_PrintError("You must have a game loaded before you can use the Trace Logger.");
		return;
	}
	//if (GameInfo->type==GIT_NSF) { //todo: NSF support!
	//	FCEUD_PrintError("Sorry, you can't yet use the Trace Logger with NSFs.");
	//	return;
	//}

	if (!hTracer)
	{
		arrayOfWindowItemPosData.resize(0);
		CreateDialog(fceu_hInstance,"TRACER",NULL,TracerCallB);
		//hTracer gets set in WM_INITDIALOG
	} else
	{
		ShowWindow(hTracer, SW_SHOWNORMAL);
		SetForegroundWindow(hTracer);
	}
}
