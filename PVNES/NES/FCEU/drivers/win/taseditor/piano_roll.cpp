/* ---------------------------------------------------------------------------------
Implementation file of PIANO_ROLL class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Piano Roll - Piano Roll interface
[Single instance]

* implements the working of Piano Roll List: creating, redrawing, scrolling, mouseover, clicks, drag
* regularly updates the size of the List according to current movie Input
* on demand: scrolls visible area of the List to any given item: to Playback Cursor, to Selection Cursor, to "undo pointer", to a Marker
* saves and loads current position of vertical scrolling from a project file. On error: scrolls the List to the beginning
* implements the working of Piano Roll List Header: creating, redrawing, animating, mouseover, clicks
* regularly updates lights in the Header according to button presses data from Recorder and Alt key state
* on demand: launches flashes in the Header
* implements the working of mouse wheel: List scrolling, Playback cursor movement, Selection cursor movement, scrolling across gaps in Input/Markers
* implements context menu on Right-click
* stores resources: save id, ids of columns, widths of columns, tables of colors, gradient of Hot Changes, gradient of Header flashings, timings of flashes, all fonts used in TAS Editor, images
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "utils/xstring.h"
#include "uxtheme.h"
#include <math.h>

#pragma comment(lib, "UxTheme.lib")

extern int joysticksPerFrame[INPUT_TYPES_TOTAL];
extern char buttonNames[NUM_JOYPAD_BUTTONS][2];

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern BOOKMARKS bookmarks;
extern PLAYBACK playback;
extern RECORDER recorder;
extern GREENZONE greenzone;
extern HISTORY history;
extern MARKERS_MANAGER markersManager;
extern SELECTION selection;
extern EDITOR editor;

extern int getInputType(MovieData& md);

LRESULT APIENTRY headerWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY listWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
WNDPROC hwndListOldWndProc = 0, hwndHeaderOldWndproc = 0;

LRESULT APIENTRY markerDragBoxWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);

// resources
char pianoRollSaveID[PIANO_ROLL_ID_LEN] = "PIANO_ROLL";
char pianoRollSkipSaveID[PIANO_ROLL_ID_LEN] = "PIANO_ROLX";
//COLORREF hotChangesColors[16] = { 0x0, 0x495249, 0x666361, 0x855a45, 0xa13620, 0xbd003f, 0xd6006f, 0xcc008b, 0xba00a1, 0x8b00ad, 0x5c00bf, 0x0003d1, 0x0059d6, 0x0077d9, 0x0096db, 0x00aede };
COLORREF hotChangesColors[16] = { 0x0, 0x004035, 0x185218, 0x5e5c34, 0x804c00, 0xba0300, 0xd10038, 0xb21272, 0xba00ab, 0x6f00b0, 0x3700c2, 0x000cba, 0x002cc9, 0x0053bf, 0x0072cf, 0x3c8bc7 };
COLORREF headerLightsColors[11] = { 0x0, 0x007313, 0x009100, 0x1daf00, 0x42c700, 0x65d900, 0x91e500, 0xb0f000, 0xdaf700, 0xf0fc7c, 0xfcffba };

char markerDragBoxClassName[] = "MarkerDragBox";

PIANO_ROLL::PIANO_ROLL()
{
	hwndMarkerDragBox = 0;
	// register MARKER_DRAG_BOX window class
	winCl.hInstance = fceu_hInstance;
	winCl.lpszClassName = markerDragBoxClassName;
	winCl.lpfnWndProc = markerDragBoxWndProc;
	winCl.style = CS_SAVEBITS| CS_DBLCLKS;
	winCl.cbSize = sizeof(WNDCLASSEX);
	winCl.hIcon = 0;
	winCl.hIconSm = 0;
	winCl.hCursor = 0;
	winCl.lpszMenuName = 0;
	winCl.cbClsExtra = 0;
	winCl.cbWndExtra = 0;
	winCl.hbrBackground = 0;
	if (!RegisterClassEx(&winCl))
		FCEU_printf("Error registering MARKER_DRAG_BOX window class\n");

	// create blendfunction
	blend.BlendOp = AC_SRC_OVER;
	blend.BlendFlags = 0;
	blend.AlphaFormat = 0;
	blend.SourceConstantAlpha = 255;

}

void PIANO_ROLL::init()
{
	free();
	// create fonts for main listview
	hMainListFont = CreateFont(14, 7,				/*Height,Width*/
		0, 0,										/*escapement,orientation*/
		FW_BOLD, FALSE, FALSE, FALSE,				/*weight, italic, underline, strikeout*/
		ANSI_CHARSET, OUT_DEVICE_PRECIS, CLIP_MASK,	/*charset, precision, clipping*/
		DEFAULT_QUALITY, DEFAULT_PITCH,				/*quality, and pitch*/
		"Arial");									/*font name*/
	hMainListSelectFont = CreateFont(15, 10,		/*Height,Width*/
		0, 0,										/*escapement,orientation*/
		FW_BOLD, FALSE, FALSE, FALSE,				/*weight, italic, underline, strikeout*/
		ANSI_CHARSET, OUT_DEVICE_PRECIS, CLIP_MASK,	/*charset, precision, clipping*/
		DEFAULT_QUALITY, DEFAULT_PITCH,				/*quality, and pitch*/
		"Courier New");								/*font name*/
	// create fonts for Marker notes fields
	hMarkersFont = CreateFont(16, 8,				/*Height,Width*/
		0, 0,										/*escapement,orientation*/
		FW_BOLD, FALSE, FALSE, FALSE,				/*weight, italic, underline, strikeout*/
		ANSI_CHARSET, OUT_DEVICE_PRECIS, CLIP_MASK,	/*charset, precision, clipping*/
		DEFAULT_QUALITY, DEFAULT_PITCH,				/*quality, and pitch*/
		"Arial");									/*font name*/
	hMarkersEditFont = CreateFont(16, 7,			/*Height,Width*/
		0, 0,										/*escapement,orientation*/
		FW_NORMAL, FALSE, FALSE, FALSE,				/*weight, italic, underline, strikeout*/
		ANSI_CHARSET, OUT_DEVICE_PRECIS, CLIP_MASK,	/*charset, precision, clipping*/
		DEFAULT_QUALITY, DEFAULT_PITCH,				/*quality, and pitch*/
		"Arial");									/*font name*/
	hTaseditorAboutFont = CreateFont(24, 10,		/*Height,Width*/
		0, 0,										/*escapement,orientation*/
		FW_NORMAL, FALSE, FALSE, FALSE,				/*weight, italic, underline, strikeout*/
		ANSI_CHARSET, OUT_DEVICE_PRECIS, CLIP_MASK,	/*charset, precision, clipping*/
		DEFAULT_QUALITY, DEFAULT_PITCH,				/*quality, and pitch*/
		"Arial");								/*font name*/

	bgBrush = CreateSolidBrush(GetSysColor(COLOR_BTNFACE));
	markerDragBoxBrushNormal = CreateSolidBrush(MARKED_FRAMENUM_COLOR);
	markerDragBoxBrushBind = CreateSolidBrush(BINDMARKED_FRAMENUM_COLOR);

	hwndList = GetDlgItem(taseditorWindow.hwndTASEditor, IDC_LIST1);
	// prepare the main listview
	ListView_SetExtendedListViewStyleEx(hwndList, LVS_EX_DOUBLEBUFFER|LVS_EX_FULLROWSELECT|LVS_EX_GRIDLINES, LVS_EX_DOUBLEBUFFER|LVS_EX_FULLROWSELECT|LVS_EX_GRIDLINES);
	// subclass the header
	hwndHeader = ListView_GetHeader(hwndList);
	hwndHeaderOldWndproc = (WNDPROC)SetWindowLong(hwndHeader, GWL_WNDPROC, (LONG)headerWndProc);
	// subclass the whole listview
	hwndListOldWndProc = (WNDPROC)SetWindowLong(hwndList, GWL_WNDPROC, (LONG)listWndProc);
	// disable Visual Themes for header
	SetWindowTheme(hwndHeader, L"", L"");
	// setup images for the listview
	hImgList = ImageList_Create(13, 13, ILC_COLOR8 | ILC_MASK, 1, 1);
	HBITMAP bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_0));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_1));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_2));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_3));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_4));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_5));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_6));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_7));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_8));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_9));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_10));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_11));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_12));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_13));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_14));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_15));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_16));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_17));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_18));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_19));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_0));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_1));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_2));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_3));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_4));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_5));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_6));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_7));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_8));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_9));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_10));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_11));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_12));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_13));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_14));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_15));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_16));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_17));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_18));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_PLAYBACK_19));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_0));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_1));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_2));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_3));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_4));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_5));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_6));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_7));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_8));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_9));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_10));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_11));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_12));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_13));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_14));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_15));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_16));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_17));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_18));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_PIANO_LOSTPOS_19));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_TE_ARROW));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_TE_GREEN_ARROW));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	bmp = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_TE_GREEN_BLUE_ARROW));
	ImageList_AddMasked(hImgList, bmp, 0xFFFFFF);
	DeleteObject(bmp);
	ListView_SetImageList(hwndList, hImgList, LVSIL_SMALL);
	// setup 0th column
	LVCOLUMN lvc;
	// icons column
	lvc.mask = LVCF_WIDTH;
	lvc.cx = COLUMN_ICONS_WIDTH;
	ListView_InsertColumn(hwndList, 0, &lvc);
	// find rows top/height (for mouseover hittest calculations)
	ListView_SetItemCountEx(hwndList, 1, LVSICF_NOSCROLL|LVSICF_NOINVALIDATEALL);
	RECT temp_rect;
	if (ListView_GetSubItemRect(hwndList, 0, 0, LVIR_BOUNDS, &temp_rect) && temp_rect.bottom != temp_rect.top)
	{
		listTopMargin = temp_rect.top;
		listRowHeight = temp_rect.bottom - temp_rect.top;
	} else
	{
		// couldn't get rect, set default values
		listTopMargin = 20;
		listRowHeight = 14;
	}
	ListView_SetItemCountEx(hwndList, 0, LVSICF_NOSCROLL|LVSICF_NOINVALIDATEALL);
	// find header height
	RECT wrect;
	if (GetWindowRect(hwndHeader, &wrect))
		listHeaderHeight = wrect.bottom - wrect.top;
	else
		listHeaderHeight = 20;

	hrMenu = LoadMenu(fceu_hInstance,"TASEDITORCONTEXTMENUS");
	headerColors.resize(TOTAL_COLUMNS);
	// fill TrackMouseEvent struct
	tme.cbSize = sizeof(tme);
	tme.dwFlags = TME_LEAVE;
	tme.hwndTrack = hwndHeader;
	dragMode = DRAG_MODE_NONE;
	rightButtonDragMode = false;
}
void PIANO_ROLL::free()
{
	if (hMainListFont)
	{
		DeleteObject(hMainListFont);
		hMainListFont = 0;
	}
	if (hMainListSelectFont)
	{
		DeleteObject(hMainListSelectFont);
		hMainListSelectFont = 0;
	}
	if (hMarkersFont)
	{
		DeleteObject(hMarkersFont);
		hMarkersFont = 0;
	}
	if (hMarkersEditFont)
	{
		DeleteObject(hMarkersEditFont);
		hMarkersEditFont = 0;
	}
	if (hTaseditorAboutFont)
	{
		DeleteObject(hTaseditorAboutFont);
		hTaseditorAboutFont = 0;
	}
	if (bgBrush)
	{
		DeleteObject(bgBrush);
		bgBrush = 0;
	}
	if (markerDragBoxBrushNormal)
	{
		DeleteObject(markerDragBoxBrushNormal);
		markerDragBoxBrushNormal = 0;
	}
	if (markerDragBoxBrushBind)
	{
		DeleteObject(markerDragBoxBrushBind);
		markerDragBoxBrushBind = 0;
	}
	if (hImgList)
	{
		ImageList_Destroy(hImgList);
		hImgList = 0;
	}
	headerColors.resize(0);
}
void PIANO_ROLL::reset()
{
	mustRedrawList = mustCheckItemUnderMouse = true;
	playbackCursorOffset = 0;
	shiftHeld = ctrlHeld = altHeld = false;
	shiftTimer = ctrlTimer = shiftActions—ount = ctrlActions—ount = 0;
	nextHeaderUpdateTime = headerItemUnderMouse = 0;
	// delete all columns except 0th
	while (ListView_DeleteColumn(hwndList, 1)) {}
	// setup columns
	numColumns = 1;
	LVCOLUMN lvc;
	// frame number column
	lvc.mask = LVCF_WIDTH | LVCF_TEXT | LVCF_FMT;
	lvc.fmt = LVCFMT_CENTER;
	lvc.cx = COLUMN_FRAMENUM_WIDTH;
	lvc.pszText = "Frame#";
	ListView_InsertColumn(hwndList, numColumns++, &lvc);
	// pads columns
	lvc.cx = COLUMN_BUTTON_WIDTH;
	int num_joysticks = joysticksPerFrame[getInputType(currMovieData)];
	for (int joy = 0; joy < num_joysticks; ++joy)
	{
		for (int btn = 0; btn < NUM_JOYPAD_BUTTONS; ++btn)
		{
			lvc.pszText = buttonNames[btn];
			ListView_InsertColumn(hwndList, numColumns++, &lvc);
		}
	}
	// add 2nd frame number column if needed
	if (numColumns >= NUM_COLUMNS_NEED_2ND_FRAMENUM)
	{
		
		lvc.cx = COLUMN_FRAMENUM_WIDTH;
		lvc.pszText = "Frame#";
		ListView_InsertColumn(hwndList, numColumns++, &lvc);
	}
}
void PIANO_ROLL::update()
{
	updateLinesCount();

	// update state of Shift/Ctrl/Alt holding
	bool last_shift_held = shiftHeld, last_ctrl_held = ctrlHeld, last_alt_held = altHeld;
	shiftHeld = (GetAsyncKeyState(VK_SHIFT) < 0);
	ctrlHeld = (GetAsyncKeyState(VK_CONTROL) < 0);
	altHeld = (GetAsyncKeyState(VK_MENU) < 0);
	// check doubletap of Shift/Ctrl
	if (last_shift_held != shiftHeld)
	{
		if ((int)(shiftTimer + GetDoubleClickTime()) > clock())
		{
			shiftActions—ount++;
			if (shiftActions—ount >= DOUBLETAP_COUNT)
			{
				if (taseditorWindow.TASEditorIsInFocus)
					followPlaybackCursor();
				shiftActions—ount = ctrlActions—ount = 0;
			}
		} else
		{
			shiftActions—ount = 0;
		}
		shiftTimer = clock();
	}
	if (last_ctrl_held != ctrlHeld)
	{
		if ((int)(ctrlTimer + GetDoubleClickTime()) > clock())
		{
			ctrlActions—ount++;
			if (ctrlActions—ount >= DOUBLETAP_COUNT)
			{
				if (taseditorWindow.TASEditorIsInFocus)
					followSelection();
				ctrlActions—ount = shiftActions—ount = 0;
			}
		} else
		{
			ctrlActions—ount = 0;
		}
		ctrlTimer = clock();
	}

	if (mustCheckItemUnderMouse)
	{
		// find row and column
		POINT p;
		if (GetCursorPos(&p))
		{
			ScreenToClient(hwndList, &p);
			// perform hit test
			LVHITTESTINFO info;
			info.pt.x = p.x;
			info.pt.y = p.y;
			ListView_SubItemHitTest(hwndList, &info);
			rowUnderMouse = info.iItem;
			realRowUnderMouse = rowUnderMouse;
			if (realRowUnderMouse < 0)
			{
				realRowUnderMouse = ListView_GetTopIndex(hwndList) + (p.y - listTopMargin) / listRowHeight;
				if (realRowUnderMouse < 0) realRowUnderMouse--;
			}
			columnUnderMouse = info.iSubItem;
		}
		// and don't check until mouse moves or Piano Roll scrolls
		mustCheckItemUnderMouse = false;
		taseditorWindow.mustUpdateMouseCursor = true;
	}

	// update dragging
	if (dragMode != DRAG_MODE_NONE)
	{
		// check if user released left button
		if (GetAsyncKeyState(GetSystemMetrics(SM_SWAPBUTTON) ? VK_RBUTTON : VK_LBUTTON) >= 0)
			finishDrag();
	}
	if (rightButtonDragMode)
	{
		// check if user released right button
		if (GetAsyncKeyState(GetSystemMetrics(SM_SWAPBUTTON) ? VK_LBUTTON : VK_RBUTTON) >= 0)
			rightButtonDragMode = false;
	}
	// perform drag
	switch (dragMode)
	{
		case DRAG_MODE_PLAYBACK:
		{
			handlePlaybackCursorDragging();
			break;
		}
		case DRAG_MODE_MARKER:
		{
			// if suddenly source frame lost its Marker, abort drag
			if (!markersManager.getMarkerAtFrame(markerDragFrameNumber))
			{
				if (hwndMarkerDragBox)
				{
					DestroyWindow(hwndMarkerDragBox);
					hwndMarkerDragBox = 0;
				}
				dragMode = DRAG_MODE_NONE;
				break;
			}
			// when dragging, always show semi-transparent yellow rectangle under mouse
			POINT p = {0, 0};
			GetCursorPos(&p);
			markerDragBoxX = p.x - markerDragBoxDX;
			markerDragBoxY = p.y - markerDragBoxDY;
			if (!hwndMarkerDragBox)
			{
				hwndMarkerDragBox = CreateWindowEx(WS_EX_LAYERED | WS_EX_TRANSPARENT, markerDragBoxClassName, markerDragBoxClassName, WS_POPUP, markerDragBoxX, markerDragBoxY, COLUMN_FRAMENUM_WIDTH, listRowHeight, taseditorWindow.hwndTASEditor, NULL, fceu_hInstance, NULL);
				ShowWindow(hwndMarkerDragBox, SW_SHOWNA);
			} else
			{
				SetWindowPos(hwndMarkerDragBox, 0, markerDragBoxX, markerDragBoxY, 0, 0, SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE);
			}
			SetLayeredWindowAttributes(hwndMarkerDragBox, 0, MARKER_DRAG_BOX_ALPHA, LWA_ALPHA);
			UpdateLayeredWindow(hwndMarkerDragBox, 0, 0, 0, 0, 0, 0, &blend, ULW_ALPHA);
			break;
		}
		case DRAG_MODE_SET:
		case DRAG_MODE_UNSET:
		{
			POINT p;
			if (GetCursorPos(&p))
			{
				ScreenToClient(hwndList, &p);
				int drawing_current_x = p.x + GetScrollPos(hwndList, SB_HORZ);
				int drawing_current_y = p.y + GetScrollPos(hwndList, SB_VERT) * listRowHeight;
				// draw (or erase) line from [drawing_current_x, drawing_current_y] to (drawing_last_x, drawing_last_y)
				int total_dx = drawingLastX - drawing_current_x, total_dy = drawingLastY - drawing_current_y;
				if (!shiftHeld)
				{
					// when user is not holding Shift, draw only vertical lines
					total_dx = 0;
					drawing_current_x = drawingLastX;
					p.x = drawing_current_x - GetScrollPos(hwndList, SB_HORZ);
				}
				LVHITTESTINFO info;
				int row_index, column_index, joy, bit;
				int min_row_index = currMovieData.getNumRecords(), max_row_index = -1;
				bool changes_made = false;
				if (altHeld)
				{
					// special mode: draw pattern
					int selection_beginning = selection.getCurrentRowsSelectionBeginning();
					if (selection_beginning >= 0)
					{
						// perform hit test
						info.pt.x = p.x;
						info.pt.y = p.y;
						ListView_SubItemHitTest(hwndList, &info);
						row_index = info.iItem;
						if (row_index < 0)
							row_index = ListView_GetTopIndex(hwndList) + (info.pt.y - listTopMargin) / listRowHeight;
						// pad movie size if user tries to draw pattern below Piano Roll limit
						if (row_index >= currMovieData.getNumRecords())
							currMovieData.insertEmpty(-1, row_index + 1 - currMovieData.getNumRecords());
						column_index = info.iSubItem;
						if (row_index >= 0 && column_index >= COLUMN_JOYPAD1_A && column_index <= COLUMN_JOYPAD4_R)
						{
							joy = (column_index - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
							bit = (column_index - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
							editor.setInputUsingPattern(selection_beginning, row_index, joy, bit, drawingStartTimestamp);
						}
					}
				} else
				{
					double total_len = sqrt((double)(total_dx * total_dx + total_dy * total_dy));
					int drawing_min_line_len = listRowHeight;		// = min(list_row_width, list_row_height) in pixels
					for (double len = 0; len < total_len; len += drawing_min_line_len)
					{
						// perform hit test
						info.pt.x = p.x + (len / total_len) * total_dx;
						info.pt.y = p.y + (len / total_len) * total_dy;
						ListView_SubItemHitTest(hwndList, &info);
						row_index = info.iItem;
						if (row_index < 0)
							row_index = ListView_GetTopIndex(hwndList) + (info.pt.y - listTopMargin) / listRowHeight;
						// pad movie size if user tries to draw below Piano Roll limit
						if (row_index >= currMovieData.getNumRecords())
							currMovieData.insertEmpty(-1, row_index + 1 - currMovieData.getNumRecords());
						column_index = info.iSubItem;
						if (row_index >= 0 && column_index >= COLUMN_JOYPAD1_A && column_index <= COLUMN_JOYPAD4_R)
						{
							joy = (column_index - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
							bit = (column_index - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
							if (dragMode == DRAG_MODE_SET && !currMovieData.records[row_index].checkBit(joy, bit))
							{
								currMovieData.records[row_index].setBit(joy, bit);
								changes_made = true;
								if (min_row_index > row_index) min_row_index = row_index;
								if (max_row_index < row_index) max_row_index = row_index;
							} else if (dragMode == DRAG_MODE_UNSET && currMovieData.records[row_index].checkBit(joy, bit))
							{
								currMovieData.records[row_index].clearBit(joy, bit);
								changes_made = true;
								if (min_row_index > row_index) min_row_index = row_index;
								if (max_row_index < row_index) max_row_index = row_index;
							}
						}
					}
					if (changes_made)
					{
						if (dragMode == DRAG_MODE_SET)
							greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_SET, min_row_index, max_row_index, 0, NULL, drawingStartTimestamp));
						else
							greenzone.invalidateAndUpdatePlayback(history.registerChanges(MODTYPE_UNSET, min_row_index, max_row_index, 0, NULL, drawingStartTimestamp));
					}
				}
				drawingLastX = drawing_current_x;
				drawingLastY = drawing_current_y;
			}
			break;
		}
		case DRAG_MODE_SELECTION:
		{
			int new_drag_selection_ending_frame = realRowUnderMouse;
			// if trying to select above Piano Roll, select from frame 0
			if (new_drag_selection_ending_frame < 0)
				new_drag_selection_ending_frame = 0;
			else if (new_drag_selection_ending_frame >= currMovieData.getNumRecords())
				new_drag_selection_ending_frame = currMovieData.getNumRecords() - 1;
			if (new_drag_selection_ending_frame >= 0 && new_drag_selection_ending_frame != dragSelectionEndingFrame)
			{
				// change Selection shape
				if (new_drag_selection_ending_frame >= dragSelectionStartingFrame)
				{
					// selecting from upper to lower
					if (dragSelectionEndingFrame < dragSelectionStartingFrame)
					{
						selection.clearRegionOfRowsSelection(dragSelectionEndingFrame, dragSelectionStartingFrame);
						selection.setRegionOfRowsSelection(dragSelectionStartingFrame, new_drag_selection_ending_frame + 1);
					} else	// both ending_frame and new_ending_frame are >= starting_frame
					{
						if (dragSelectionEndingFrame > new_drag_selection_ending_frame)
							selection.clearRegionOfRowsSelection(new_drag_selection_ending_frame + 1, dragSelectionEndingFrame + 1);
						else
							selection.setRegionOfRowsSelection(dragSelectionEndingFrame + 1, new_drag_selection_ending_frame + 1);
					}
				} else
				{
					// selecting from lower to upper
					if (dragSelectionEndingFrame > dragSelectionStartingFrame)
					{
						selection.clearRegionOfRowsSelection(dragSelectionStartingFrame + 1, dragSelectionEndingFrame + 1);
						selection.setRegionOfRowsSelection(new_drag_selection_ending_frame, dragSelectionStartingFrame);
					} else	// both ending_frame and new_ending_frame are <= starting_frame
					{
						if (dragSelectionEndingFrame < new_drag_selection_ending_frame)
							selection.clearRegionOfRowsSelection(dragSelectionEndingFrame, new_drag_selection_ending_frame);
						else
							selection.setRegionOfRowsSelection(new_drag_selection_ending_frame, dragSelectionEndingFrame);
					}
				}
				dragSelectionEndingFrame = new_drag_selection_ending_frame;
			}
			break;
		}
		case DRAG_MODE_DESELECTION:
		{
			int new_drag_selection_ending_frame = realRowUnderMouse;
			// if trying to deselect above Piano Roll, deselect from frame 0
			if (new_drag_selection_ending_frame < 0)
				new_drag_selection_ending_frame = 0;
			else if (new_drag_selection_ending_frame >= currMovieData.getNumRecords())
				new_drag_selection_ending_frame = currMovieData.getNumRecords() - 1;
			if (new_drag_selection_ending_frame >= 0 && new_drag_selection_ending_frame != dragSelectionEndingFrame)
			{
				// change Deselection shape
				if (new_drag_selection_ending_frame >= dragSelectionStartingFrame)
					// deselecting from upper to lower
					selection.clearRegionOfRowsSelection(dragSelectionStartingFrame, new_drag_selection_ending_frame + 1);
				else
					// deselecting from lower to upper
					selection.clearRegionOfRowsSelection(new_drag_selection_ending_frame, dragSelectionStartingFrame + 1);
				dragSelectionEndingFrame = new_drag_selection_ending_frame;
			}
			break;
		}
	}
	// update MarkerDragBox when it's flying away
	if (hwndMarkerDragBox && dragMode != DRAG_MODE_MARKER)
	{
		markerDragCountdown--;
		if (markerDragCountdown > 0)
		{
			markerDragBoxDY += MARKER_DRAG_GRAVITY;
			markerDragBoxX += markerDragBoxDX;
			markerDragBoxY += markerDragBoxDY;
			SetWindowPos(hwndMarkerDragBox, 0, markerDragBoxX, markerDragBoxY, 0, 0, SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE);
			SetLayeredWindowAttributes(hwndMarkerDragBox, 0, markerDragCountdown * MARKER_DRAG_ALPHA_PER_TICK, LWA_ALPHA);
			UpdateLayeredWindow(hwndMarkerDragBox, 0, 0, 0, 0, 0, 0, &blend, ULW_ALPHA);
		} else
		{
			DestroyWindow(hwndMarkerDragBox);
			hwndMarkerDragBox = 0;
		}
	}
	// scroll Piano Roll if user is dragging cursor outside
	if (dragMode != DRAG_MODE_NONE || rightButtonDragMode)
	{
		POINT p;
		if (GetCursorPos(&p))
		{
			ScreenToClient(hwndList, &p);
			RECT wrect;
			GetClientRect(hwndList, &wrect);
			int scroll_dx = 0, scroll_dy = 0;
			if (dragMode != DRAG_MODE_MARKER)		// in DRAG_MODE_MARKER user can't scroll Piano Roll horizontally
			{
				if (p.x < DRAG_SCROLLING_BORDER_SIZE)
					scroll_dx = p.x - DRAG_SCROLLING_BORDER_SIZE;
				else if (p.x > (wrect.right - wrect.left - DRAG_SCROLLING_BORDER_SIZE))
					scroll_dx = p.x - (wrect.right - wrect.left - DRAG_SCROLLING_BORDER_SIZE);
			}
			if (p.y < (listHeaderHeight + DRAG_SCROLLING_BORDER_SIZE))
				scroll_dy = p.y - (listHeaderHeight + DRAG_SCROLLING_BORDER_SIZE);
			else if (p.y > (wrect.bottom - wrect.top - DRAG_SCROLLING_BORDER_SIZE))
				scroll_dy = p.y - (wrect.bottom - wrect.top - DRAG_SCROLLING_BORDER_SIZE);
			if (scroll_dx || scroll_dy)
				ListView_Scroll(hwndList, scroll_dx, scroll_dy);
		}
	}
	// redraw list if needed
	if (mustRedrawList)
	{
		InvalidateRect(hwndList, 0, false);
		mustRedrawList = false;
	}

	// once per 40 milliseconds update colors alpha in the Header
	if (clock() > nextHeaderUpdateTime)
	{
		nextHeaderUpdateTime = clock() + HEADER_LIGHT_UPDATE_TICK;
		bool changes_made = false;
		int light_value = 0;
		// 1 - update Frame# columns' heads
		//if (GetAsyncKeyState(VK_MENU) & 0x8000) light_value = HEADER_LIGHT_HOLD; else
		if (dragMode == DRAG_MODE_NONE && (headerItemUnderMouse == COLUMN_FRAMENUM || headerItemUnderMouse == COLUMN_FRAMENUM2))
			light_value = (selection.getCurrentRowsSelectionSize() > 0) ? HEADER_LIGHT_MOUSEOVER_SEL : HEADER_LIGHT_MOUSEOVER;
		if (headerColors[COLUMN_FRAMENUM] < light_value)
		{
			headerColors[COLUMN_FRAMENUM]++;
			changes_made = true;
		} else if (headerColors[COLUMN_FRAMENUM] > light_value)
		{
			headerColors[COLUMN_FRAMENUM]--;
			changes_made = true;
		}
		headerColors[COLUMN_FRAMENUM2] = headerColors[COLUMN_FRAMENUM];
		// 2 - update Input columns' heads
		int i = numColumns-1;
		if (i == COLUMN_FRAMENUM2) i--;
		for (; i >= COLUMN_JOYPAD1_A; i--)
		{
			light_value = 0;
			if (recorder.currentJoypadData[(i - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS] & (1 << ((i - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS)))
				light_value = HEADER_LIGHT_HOLD;
			else if (dragMode == DRAG_MODE_NONE && headerItemUnderMouse == i)
				light_value = (selection.getCurrentRowsSelectionSize() > 0) ? HEADER_LIGHT_MOUSEOVER_SEL : HEADER_LIGHT_MOUSEOVER;
			if (headerColors[i] < light_value)
			{
				headerColors[i]++;
				changes_made = true;
			} else if (headerColors[i] > light_value)
			{
				headerColors[i]--;
				changes_made = true;
			}
		}
		// 3 - redraw
		if (changes_made)
			redrawHeader();
	}

}

void PIANO_ROLL::save(EMUFILE *os, bool really_save)
{
	if (really_save)
	{
		updateLinesCount();
		// write "PIANO_ROLL" string
		os->fwrite(pianoRollSaveID, PIANO_ROLL_ID_LEN);
		// write current top item
		int top_item = ListView_GetTopIndex(hwndList);
		write32le(top_item, os);
	} else
	{
		// write "PIANO_ROLX" string
		os->fwrite(pianoRollSkipSaveID, PIANO_ROLL_ID_LEN);
	}
}
// returns true if couldn't load
bool PIANO_ROLL::load(EMUFILE *is, unsigned int offset)
{
	reset();
	updateLinesCount();
	if (offset)
	{
		if (is->fseek(offset, SEEK_SET)) goto error;
	} else
	{
		// scroll to the beginning
		ListView_EnsureVisible(hwndList, 0, FALSE);
		return false;
	}
	// read "PIANO_ROLL" string
	char save_id[PIANO_ROLL_ID_LEN];
	if ((int)is->fread(save_id, PIANO_ROLL_ID_LEN) < PIANO_ROLL_ID_LEN) goto error;
	if (!strcmp(pianoRollSkipSaveID, save_id))
	{
		// string says to skip loading Piano Roll
		FCEU_printf("No Piano Roll data in the file\n");
		// scroll to the beginning
		ListView_EnsureVisible(hwndList, 0, FALSE);
		return false;
	}
	if (strcmp(pianoRollSaveID, save_id)) goto error;		// string is not valid
	// read current top item and scroll Piano Roll there
	int top_item;
	if (!read32le(&top_item, is)) goto error;
	ListView_EnsureVisible(hwndList, currMovieData.getNumRecords() - 1, FALSE);
	ListView_EnsureVisible(hwndList, top_item, FALSE);
	return false;
error:
	FCEU_printf("Error loading Piano Roll data\n");
	// scroll to the beginning
	ListView_EnsureVisible(hwndList, 0, FALSE);
	return true;
}
// ----------------------------------------------------------------------
void PIANO_ROLL::redraw()
{
	mustRedrawList = true;
	mustCheckItemUnderMouse = true;
}
void PIANO_ROLL::redrawRow(int index)
{
	ListView_RedrawItems(hwndList, index, index);
}
void PIANO_ROLL::redrawHeader()
{
	InvalidateRect(hwndHeader, 0, false);
}

// -------------------------------------------------------------------------
void PIANO_ROLL::updateLinesCount()
{
	// update the number of items in the list
	int currLVItemCount = ListView_GetItemCount(hwndList);
	int movie_size = currMovieData.getNumRecords();
	if (currLVItemCount != movie_size)
		ListView_SetItemCountEx(hwndList, movie_size, LVSICF_NOSCROLL|LVSICF_NOINVALIDATEALL);
}
bool PIANO_ROLL::isLineVisible(int frame)
{
	int top = ListView_GetTopIndex(hwndList);
	if (frame >= top && frame < top + ListView_GetCountPerPage(hwndList))
		return true;
	return false;
}

void PIANO_ROLL::centerListAroundLine(int rowIndex)
{
	int numItemsPerPage = ListView_GetCountPerPage(hwndList);
	int lowerBorder = (numItemsPerPage - 1) / 2;
	int upperBorder = (numItemsPerPage - 1) - lowerBorder;
	int index = rowIndex + lowerBorder;
	if (index >= currMovieData.getNumRecords())
		index = currMovieData.getNumRecords()-1;
	ListView_EnsureVisible(hwndList, index, false);
	index = rowIndex - upperBorder;
	if (index < 0)
		index = 0;
	ListView_EnsureVisible(hwndList, index, false);
}
void PIANO_ROLL::setListTopRow(int rowIndex)
{
	ListView_Scroll(hwndList, 0, listRowHeight * (rowIndex - ListView_GetTopIndex(hwndList)));
}

void PIANO_ROLL::recalculatePlaybackCursorOffset()
{
	int frame = playback.getPauseFrame();
	if (frame < 0)
		frame = currFrameCounter;

	playbackCursorOffset = frame - ListView_GetTopIndex(hwndList);
	if (playbackCursorOffset < 0)
	{
		playbackCursorOffset = 0;
	} else
	{
		int numItemsPerPage = ListView_GetCountPerPage(hwndList);
		if (playbackCursorOffset > numItemsPerPage - 1)
			playbackCursorOffset = numItemsPerPage - 1;
	}
}

void PIANO_ROLL::followPlaybackCursor()
{
	centerListAroundLine(currFrameCounter);
}
void PIANO_ROLL::followPlaybackCursorIfNeeded(bool followPauseframe)
{
	if (taseditorConfig.followPlaybackCursor)
	{
		if (playback.getPauseFrame() < 0)
			ListView_EnsureVisible(hwndList, currFrameCounter, FALSE);
		else if (followPauseframe)
			ListView_EnsureVisible(hwndList, playback.getPauseFrame(), FALSE);
	}
}
void PIANO_ROLL::updatePlaybackCursorPositionInPianoRoll()
{
	if (taseditorConfig.followPlaybackCursor)
	{
		if (playback.getPauseFrame() < 0)
			setListTopRow(currFrameCounter - playbackCursorOffset);
	}
}
void PIANO_ROLL::followPauseframe()
{
	if (playback.getPauseFrame() >= 0)
		centerListAroundLine(playback.getPauseFrame());
}
void PIANO_ROLL::followUndoHint()
{
	int keyframe = history.getUndoHint();
	if (taseditorConfig.followUndoContext && keyframe >= 0)
	{
		if (!isLineVisible(keyframe))
			centerListAroundLine(keyframe);
	}
}
void PIANO_ROLL::followSelection()
{
	RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
	if (current_selection->size() == 0) return;

	int list_items = ListView_GetCountPerPage(hwndList);
	int selection_start = *current_selection->begin();
	int selection_end = *current_selection->rbegin();
	int selection_items = 1 + selection_end - selection_start;
	
	if (selection_items <= list_items)
	{
		// selected region can fit in screen
		int lower_border = (list_items - selection_items) / 2;
		int upper_border = (list_items - selection_items) - lower_border;
		int index = selection_end + lower_border;
		if (index >= currMovieData.getNumRecords())
			index = currMovieData.getNumRecords()-1;
		ListView_EnsureVisible(hwndList, index, false);
		index = selection_start - upper_border;
		if (index < 0)
			index = 0;
		ListView_EnsureVisible(hwndList, index, false);
	} else
	{
		// selected region is too big to fit in screen
		// oh well, just center at selection_start
		centerListAroundLine(selection_start);
	}
}
void PIANO_ROLL::followMarker(int markerID)
{
	if (markerID > 0)
	{
		int frame = markersManager.getMarkerFrameNumber(markerID);
		if (frame >= 0)
			centerListAroundLine(frame);
	} else
	{
		ListView_EnsureVisible(hwndList, 0, false);
	}
}
void PIANO_ROLL::ensureTheLineIsVisible(int rowIndex)
{
	ListView_EnsureVisible(hwndList, rowIndex, false);
}

void PIANO_ROLL::handleColumnSet(int column, bool altPressed)
{
	if (column == COLUMN_FRAMENUM || column == COLUMN_FRAMENUM2)
	{
		// user clicked on "Frame#" - apply ColumnSet to Markers
		if (altPressed)
		{
			if (editor.handleColumnSetUsingPattern())
				setLightInHeaderColumn(COLUMN_FRAMENUM, HEADER_LIGHT_MAX);
		} else
		{
			if (editor.handleColumnSet())
				setLightInHeaderColumn(COLUMN_FRAMENUM, HEADER_LIGHT_MAX);
		}
	} else
	{
		// user clicked on Input column - apply ColumnSet to Input
		int joy = (column - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
		int button = (column - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
		if (altPressed)
		{
			if (editor.handleInputColumnSetUsingPattern(joy, button))
				setLightInHeaderColumn(column, HEADER_LIGHT_MAX);
		} else
		{
			if (editor.handleInputColumnSet(joy, button))
				setLightInHeaderColumn(column, HEADER_LIGHT_MAX);
		}
	}
}

void PIANO_ROLL::setLightInHeaderColumn(int column, int level)
{
	if (column < COLUMN_FRAMENUM || column >= numColumns || level < 0 || level > HEADER_LIGHT_MAX)
		return;

	if (headerColors[column] != level)
	{
		headerColors[column] = level;
		redrawHeader();
		nextHeaderUpdateTime = clock() + HEADER_LIGHT_UPDATE_TICK;
	}
}

void PIANO_ROLL::startDraggingPlaybackCursor()
{
	if (dragMode == DRAG_MODE_NONE)
	{
		dragMode = DRAG_MODE_PLAYBACK;
		// call it once
		handlePlaybackCursorDragging();
	}
}
void PIANO_ROLL::startDraggingMarker(int mouseX, int mouseY, int rowIndex, int columnIndex)
{
	if (dragMode == DRAG_MODE_NONE)
	{
		// start dragging the Marker
		dragMode = DRAG_MODE_MARKER;
		markerDragFrameNumber = rowIndex;
		markerDragCountdown = MARKER_DRAG_COUNTDOWN_MAX;
		RECT temp_rect;
		if (ListView_GetSubItemRect(hwndList, rowIndex, columnIndex, LVIR_BOUNDS, &temp_rect))
		{
			markerDragBoxDX = mouseX - temp_rect.left;
			markerDragBoxDY = mouseY - temp_rect.top;
		} else
		{
			markerDragBoxDX = 0;
			markerDragBoxDY = 0;
		}
		// redraw the row to show that Marker was lifted
		redrawRow(rowIndex);
	}
}
void PIANO_ROLL::startSelectingDrag(int start_frame)
{
	if (dragMode == DRAG_MODE_NONE)
	{
		dragMode = DRAG_MODE_SELECTION;
		dragSelectionStartingFrame = start_frame;
		dragSelectionEndingFrame = dragSelectionStartingFrame;	// assuming that start_frame is already selected
	}
}
void PIANO_ROLL::startDeselectingDrag(int start_frame)
{
	if (dragMode == DRAG_MODE_NONE)
	{
		dragMode = DRAG_MODE_DESELECTION;
		dragSelectionStartingFrame = start_frame;
		dragSelectionEndingFrame = dragSelectionStartingFrame;	// assuming that start_frame is already deselected
	}
}

void PIANO_ROLL::handlePlaybackCursorDragging()
{
	int target_frame = realRowUnderMouse;
	if (target_frame < 0)
		target_frame = 0;
	if (currFrameCounter != target_frame)
		playback.jump(target_frame);
}

void PIANO_ROLL::finishDrag()
{
	switch (dragMode)
	{
		case DRAG_MODE_MARKER:
		{
			// place Marker here
			if (markersManager.getMarkerAtFrame(markerDragFrameNumber))
			{
				POINT p = {0, 0};
				GetCursorPos(&p);
				int mouse_x = p.x, mouse_y = p.y;
				ScreenToClient(hwndList, &p);
				RECT wrect;
				GetClientRect(hwndList, &wrect);
				if (p.x < 0 || p.x > (wrect.right - wrect.left) || p.y < 0 || p.y > (wrect.bottom - wrect.top))
				{
					// user threw the Marker away
					markersManager.removeMarkerFromFrame(markerDragFrameNumber);
					redrawRow(markerDragFrameNumber);
					history.registerMarkersChange(MODTYPE_MARKER_REMOVE, markerDragFrameNumber);
					selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
					// calculate vector of movement
					POINT p = {0, 0};
					GetCursorPos(&p);
					markerDragBoxDX = (mouse_x - markerDragBoxDX) - markerDragBoxX;
					markerDragBoxDY = (mouse_y - markerDragBoxDY) - markerDragBoxY;
					if (markerDragBoxDX || markerDragBoxDY)
					{
						// limit max speed
						double marker_drag_box_speed = sqrt((double)(markerDragBoxDX * markerDragBoxDX + markerDragBoxDY * markerDragBoxDY));
						if (marker_drag_box_speed > MARKER_DRAG_MAX_SPEED)
						{
							markerDragBoxDX *= MARKER_DRAG_MAX_SPEED / marker_drag_box_speed;
							markerDragBoxDY *= MARKER_DRAG_MAX_SPEED / marker_drag_box_speed;
						}
					}
					markerDragCountdown = MARKER_DRAG_COUNTDOWN_MAX;
				} else
				{
					if (rowUnderMouse >= 0 && (columnUnderMouse <= COLUMN_FRAMENUM || columnUnderMouse >= COLUMN_FRAMENUM2))
					{
						if (rowUnderMouse == markerDragFrameNumber)
						{
							// it was just double-click and release
							// if Selection points at dragged Marker, set focus to lower Note edit field
							int dragged_marker_id = markersManager.getMarkerAtFrame(markerDragFrameNumber);
							int selection_marker_id = markersManager.getMarkerAboveFrame(selection.getCurrentRowsSelectionBeginning());
							if (dragged_marker_id == selection_marker_id)
							{
								SetFocus(selection.hwndSelectionMarkerEditField);
								// select all text in case user wants to overwrite it
								SendMessage(selection.hwndSelectionMarkerEditField, EM_SETSEL, 0, -1); 
							}
						} else if (markersManager.getMarkerAtFrame(rowUnderMouse))
						{
							int dragged_marker_id = markersManager.getMarkerAtFrame(markerDragFrameNumber);
							int destination_marker_id = markersManager.getMarkerAtFrame(rowUnderMouse);
							// swap Notes of these Markers
							char dragged_marker_note[MAX_NOTE_LEN];
							strcpy(dragged_marker_note, markersManager.getNoteCopy(dragged_marker_id).c_str());
							if (strcmp(markersManager.getNoteCopy(destination_marker_id).c_str(), dragged_marker_note))
							{
								// notes are different, swap them
								markersManager.setNote(dragged_marker_id, markersManager.getNoteCopy(destination_marker_id).c_str());
								markersManager.setNote(destination_marker_id, dragged_marker_note);
								history.registerMarkersChange(MODTYPE_MARKER_SWAP, markerDragFrameNumber, rowUnderMouse);
								selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
								setLightInHeaderColumn(COLUMN_FRAMENUM, HEADER_LIGHT_MAX);
							}
						} else
						{
							// move Marker
							int new_marker_id = markersManager.setMarkerAtFrame(rowUnderMouse);
							if (new_marker_id)
							{
								markersManager.setNote(new_marker_id, markersManager.getNoteCopy(markersManager.getMarkerAtFrame(markerDragFrameNumber)).c_str());
								// and delete it from old frame
								markersManager.removeMarkerFromFrame(markerDragFrameNumber);
								history.registerMarkersChange(MODTYPE_MARKER_DRAG, markerDragFrameNumber, rowUnderMouse, markersManager.getNoteCopy(markersManager.getMarkerAtFrame(rowUnderMouse)).c_str());
								selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
								setLightInHeaderColumn(COLUMN_FRAMENUM, HEADER_LIGHT_MAX);
								redrawRow(rowUnderMouse);
							}
						}
					}
					redrawRow(markerDragFrameNumber);
					if (hwndMarkerDragBox)
					{
						DestroyWindow(hwndMarkerDragBox);
						hwndMarkerDragBox = 0;
					}
				}
			} else
			{
				// abort drag
				if (hwndMarkerDragBox)
				{
					DestroyWindow(hwndMarkerDragBox);
					hwndMarkerDragBox = 0;
				}
			}
			break;
		}
	}
	dragMode = DRAG_MODE_NONE;
	mustCheckItemUnderMouse = true;
}

void PIANO_ROLL::getDispInfo(NMLVDISPINFO* nmlvDispInfo)
{
	LVITEM& item = nmlvDispInfo->item;
	if (item.mask & LVIF_TEXT)
	{
		switch(item.iSubItem)
		{
			case COLUMN_ICONS:
			{
				item.iImage = bookmarks.findBookmarkAtFrame(item.iItem);
				if (item.iImage < 0)
				{
					// no bookmark at this frame
					if (item.iItem == playback.getLastPosition())
					{
						if (item.iItem == currFrameCounter)
							item.iImage = GREEN_BLUE_ARROW_IMAGE_ID;
						else
							item.iImage = GREEN_ARROW_IMAGE_ID;
					} else if (item.iItem == currFrameCounter)
					{
						item.iImage = BLUE_ARROW_IMAGE_ID;
					}
				} else
				{
					// bookmark at this frame
					if (item.iItem == playback.getLastPosition())
						item.iImage += BOOKMARKS_WITH_GREEN_ARROW;
					else if (item.iItem == currFrameCounter)
						item.iImage += BOOKMARKS_WITH_BLUE_ARROW;
				}
				break;
			}
			case COLUMN_FRAMENUM:
			case COLUMN_FRAMENUM2:
			{
				U32ToDecStr(item.pszText, item.iItem, DIGITS_IN_FRAMENUM);
				break;
			}
			case COLUMN_JOYPAD1_A: case COLUMN_JOYPAD1_B: case COLUMN_JOYPAD1_S: case COLUMN_JOYPAD1_T:
			case COLUMN_JOYPAD1_U: case COLUMN_JOYPAD1_D: case COLUMN_JOYPAD1_L: case COLUMN_JOYPAD1_R:
			case COLUMN_JOYPAD2_A: case COLUMN_JOYPAD2_B: case COLUMN_JOYPAD2_S: case COLUMN_JOYPAD2_T:
			case COLUMN_JOYPAD2_U: case COLUMN_JOYPAD2_D: case COLUMN_JOYPAD2_L: case COLUMN_JOYPAD2_R:
			case COLUMN_JOYPAD3_A: case COLUMN_JOYPAD3_B: case COLUMN_JOYPAD3_S: case COLUMN_JOYPAD3_T:
			case COLUMN_JOYPAD3_U: case COLUMN_JOYPAD3_D: case COLUMN_JOYPAD3_L: case COLUMN_JOYPAD3_R:
			case COLUMN_JOYPAD4_A: case COLUMN_JOYPAD4_B: case COLUMN_JOYPAD4_S: case COLUMN_JOYPAD4_T:
			case COLUMN_JOYPAD4_U: case COLUMN_JOYPAD4_D: case COLUMN_JOYPAD4_L: case COLUMN_JOYPAD4_R:
			{
				int joy = (item.iSubItem - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
				int bit = (item.iSubItem - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
				uint8 data = ((int)currMovieData.records.size() > item.iItem) ? currMovieData.records[item.iItem].joysticks[joy] : 0;
				if (data & (1<<bit))
				{
					item.pszText[0] = buttonNames[bit][0];
					item.pszText[2] = 0;
				} else
				{
					if (taseditorConfig.enableHotChanges && history.getCurrentSnapshot().inputlog.getHotChangesInfo(item.iItem, item.iSubItem - COLUMN_JOYPAD1_A))
					{
						item.pszText[0] = 45;	// "-"
						item.pszText[1] = 0;
					} else item.pszText[0] = 0;
				}
			}
			break;
		}
	}
}

LONG PIANO_ROLL::handleCustomDraw(NMLVCUSTOMDRAW* msg)
{
	switch(msg->nmcd.dwDrawStage)
	{
		case CDDS_PREPAINT:
			return CDRF_NOTIFYITEMDRAW;
		case CDDS_ITEMPREPAINT:
			return CDRF_NOTIFYSUBITEMDRAW;
		case CDDS_SUBITEMPREPAINT:
		{
			int cell_x = msg->iSubItem;
			int cell_y = msg->nmcd.dwItemSpec;
			if (cell_x > COLUMN_ICONS)
			{
				int frame_lag = greenzone.lagLog.getLagInfoAtFrame(cell_y);
				// text color
				if (taseditorConfig.enableHotChanges && cell_x >= COLUMN_JOYPAD1_A && cell_x <= COLUMN_JOYPAD4_R)
					msg->clrText = hotChangesColors[history.getCurrentSnapshot().inputlog.getHotChangesInfo(cell_y, cell_x - COLUMN_JOYPAD1_A)];
				else
					msg->clrText = NORMAL_TEXT_COLOR;
				// bg color and text font
				if (cell_x == COLUMN_FRAMENUM || cell_x == COLUMN_FRAMENUM2)
				{
					// font
					if (markersManager.getMarkerAtFrame(cell_y))
						SelectObject(msg->nmcd.hdc, hMainListSelectFont);
					else
						SelectObject(msg->nmcd.hdc, hMainListFont);
					// bg
					// frame number
					if (cell_y == history.getUndoHint())
					{
						// undo hint here
						if (markersManager.getMarkerAtFrame(cell_y) && (dragMode != DRAG_MODE_MARKER || markerDragFrameNumber != cell_y))
						{
							msg->clrTextBk = (taseditorConfig.bindMarkersToInput) ? BINDMARKED_UNDOHINT_FRAMENUM_COLOR : MARKED_UNDOHINT_FRAMENUM_COLOR;
						} else
						{
							msg->clrTextBk = UNDOHINT_FRAMENUM_COLOR;
						}
					} else if (cell_y == currFrameCounter || cell_y == (playback.getFlashingPauseFrame() - 1))
					{
						// this is current frame
						if (markersManager.getMarkerAtFrame(cell_y) && (dragMode != DRAG_MODE_MARKER || markerDragFrameNumber != cell_y))
						{
							msg->clrTextBk = (taseditorConfig.bindMarkersToInput) ? CUR_BINDMARKED_FRAMENUM_COLOR : CUR_MARKED_FRAMENUM_COLOR;
						} else
						{
							msg->clrTextBk = CUR_FRAMENUM_COLOR;
						}
					} else if (markersManager.getMarkerAtFrame(cell_y) && (dragMode != DRAG_MODE_MARKER || markerDragFrameNumber != cell_y))
					{
						// this is marked frame
						msg->clrTextBk = (taseditorConfig.bindMarkersToInput) ? BINDMARKED_FRAMENUM_COLOR : MARKED_FRAMENUM_COLOR;
					} else if (cell_y < greenzone.getSize())
					{
						if (!greenzone.isSavestateEmpty(cell_y))
						{
							// the frame is normal Greenzone frame
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = LAG_FRAMENUM_COLOR;
							else
								msg->clrTextBk = GREENZONE_FRAMENUM_COLOR;
						} else if (!greenzone.isSavestateEmpty(cell_y & EVERY16TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY8TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY4TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY2ND))
						{
							// the frame is in a gap (in Greenzone tail)
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = PALE_LAG_FRAMENUM_COLOR;
							else
								msg->clrTextBk = PALE_GREENZONE_FRAMENUM_COLOR;
						} else 
						{
							// the frame is above Greenzone tail
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = VERY_PALE_LAG_FRAMENUM_COLOR;
							else if (frame_lag == LAGGED_NO)
								msg->clrTextBk = VERY_PALE_GREENZONE_FRAMENUM_COLOR;
							else
								msg->clrTextBk = NORMAL_FRAMENUM_COLOR;
						}
					} else
					{
						// the frame is below Greenzone head
						if (frame_lag == LAGGED_YES)
							msg->clrTextBk = VERY_PALE_LAG_FRAMENUM_COLOR;
						else if (frame_lag == LAGGED_NO)
							msg->clrTextBk = VERY_PALE_GREENZONE_FRAMENUM_COLOR;
						else
							msg->clrTextBk = NORMAL_FRAMENUM_COLOR;
					}
				} else if ((cell_x - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS == 0 || (cell_x - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS == 2)
				{
					// pad 1 or 3
					// font: empty cells have "SelectFont" (so that "-" is wide), non-empty have normal font
					int joy = (cell_x - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
					int bit = (cell_x - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
					if ((int)currMovieData.records.size() <= cell_y ||
						((currMovieData.records[cell_y].joysticks[joy]) & (1<<bit)) )
						SelectObject(msg->nmcd.hdc, hMainListFont);
					else
						SelectObject(msg->nmcd.hdc, hMainListSelectFont);
					// bg
					if (cell_y == history.getUndoHint())
					{
						// undo hint here
						msg->clrTextBk = UNDOHINT_INPUT_COLOR1;
					} else if (cell_y == currFrameCounter || cell_y == (playback.getFlashingPauseFrame() - 1))
					{
						// this is current frame
						msg->clrTextBk = CUR_INPUT_COLOR1;
					} else if (cell_y < greenzone.getSize())
					{
						if (!greenzone.isSavestateEmpty(cell_y))
						{
							// the frame is normal Greenzone frame
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = LAG_INPUT_COLOR1;
							else
								msg->clrTextBk = GREENZONE_INPUT_COLOR1;
						} else if (!greenzone.isSavestateEmpty(cell_y & EVERY16TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY8TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY4TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY2ND))
						{
							// the frame is in a gap (in Greenzone tail)
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = PALE_LAG_INPUT_COLOR1;
							else
								msg->clrTextBk = PALE_GREENZONE_INPUT_COLOR1;
						} else
						{
							// the frame is above Greenzone tail
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = VERY_PALE_LAG_INPUT_COLOR1;
							else if (frame_lag == LAGGED_NO)
								msg->clrTextBk = VERY_PALE_GREENZONE_INPUT_COLOR1;
							else
								msg->clrTextBk = NORMAL_INPUT_COLOR1;
						}
					} else
					{
						// the frame is below Greenzone head
						if (frame_lag == LAGGED_YES)
							msg->clrTextBk = VERY_PALE_LAG_INPUT_COLOR1;
						else if (frame_lag == LAGGED_NO)
							msg->clrTextBk = VERY_PALE_GREENZONE_INPUT_COLOR1;
						else
							msg->clrTextBk = NORMAL_INPUT_COLOR1;
					}
				} else if ((cell_x - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS == 1 || (cell_x - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS == 3)
				{
					// pad 2 or 4
					// font: empty cells have "SelectFont", non-empty have normal font
					int joy = (cell_x - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
					int bit = (cell_x - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
					if ((int)currMovieData.records.size() <= cell_y ||
						((currMovieData.records[cell_y].joysticks[joy]) & (1<<bit)) )
						SelectObject(msg->nmcd.hdc, hMainListFont);
					else
						SelectObject(msg->nmcd.hdc, hMainListSelectFont);
					// bg
					if (cell_y == history.getUndoHint())
					{
						// undo hint here
						msg->clrTextBk = UNDOHINT_INPUT_COLOR2;
					} else if (cell_y == currFrameCounter || cell_y == (playback.getFlashingPauseFrame() - 1))
					{
						// this is current frame
						msg->clrTextBk = CUR_INPUT_COLOR2;
					} else if (cell_y < greenzone.getSize())
					{
						if (!greenzone.isSavestateEmpty(cell_y))
						{
							// the frame is normal Greenzone frame
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = LAG_INPUT_COLOR2;
							else
								msg->clrTextBk = GREENZONE_INPUT_COLOR2;
						} else if (!greenzone.isSavestateEmpty(cell_y & EVERY16TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY8TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY4TH)
							|| !greenzone.isSavestateEmpty(cell_y & EVERY2ND))
						{
							// the frame is in a gap (in Greenzone tail)
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = PALE_LAG_INPUT_COLOR2;
							else
								msg->clrTextBk = PALE_GREENZONE_INPUT_COLOR2;
						} else
						{
							// the frame is above Greenzone tail
							if (frame_lag == LAGGED_YES)
								msg->clrTextBk = VERY_PALE_LAG_INPUT_COLOR2;
							else if (frame_lag == LAGGED_NO)
								msg->clrTextBk = VERY_PALE_GREENZONE_INPUT_COLOR2;
							else
								msg->clrTextBk = NORMAL_INPUT_COLOR2;
						}
					} else
					{
						// the frame is below Greenzone head
						if (frame_lag == LAGGED_YES)
							msg->clrTextBk = VERY_PALE_LAG_INPUT_COLOR2;
						else if (frame_lag == LAGGED_NO)
							msg->clrTextBk = VERY_PALE_GREENZONE_INPUT_COLOR2;
						else
							msg->clrTextBk = NORMAL_INPUT_COLOR2;
					}
				}
			}
		}
		return CDRF_DODEFAULT;
	default:
		return CDRF_DODEFAULT;
	}
}

LONG PIANO_ROLL::handleHeaderCustomDraw(NMLVCUSTOMDRAW* msg)
{
	switch(msg->nmcd.dwDrawStage)
	{
	case CDDS_PREPAINT:
		SelectObject(msg->nmcd.hdc, hMainListFont);
		return CDRF_NOTIFYITEMDRAW;
	case CDDS_ITEMPREPAINT:
		{
			int cell_x = msg->nmcd.dwItemSpec;
			if (cell_x < numColumns)
			{
				int cur_color = headerColors[cell_x];
				if (cur_color)
					SetTextColor(msg->nmcd.hdc, headerLightsColors[cur_color]);
			}
		}
	default:
		return CDRF_DODEFAULT;
	}
}

// ----------------------------------------------------
void PIANO_ROLL::handleRightClick(LVHITTESTINFO& info)
{
	if (selection.isRowSelected(info.iItem))
	{
		RowsSelection* current_selection = selection.getCopyOfCurrentRowsSelection();
		HMENU sub = GetSubMenu(hrMenu, 0);
		SetMenuDefaultItem(sub, ID_SELECTED_SETMARKERS, false);
		// inspect current Selection and disable inappropriate menu items
		RowsSelection::iterator current_selection_begin(current_selection->begin());
		RowsSelection::iterator current_selection_end(current_selection->end());
		bool set_found = false, unset_found = false;
		for(RowsSelection::iterator it(current_selection_begin); it != current_selection_end; it++)
		{
			if (markersManager.getMarkerAtFrame(*it))
				set_found = true;
			else 
				unset_found = true;
		}
		if (unset_found)
			EnableMenuItem(sub, ID_SELECTED_SETMARKERS, MF_BYCOMMAND | MF_ENABLED);
		else
			EnableMenuItem(sub, ID_SELECTED_SETMARKERS, MF_BYCOMMAND | MF_DISABLED | MF_GRAYED);
		if (set_found)
			EnableMenuItem(sub, ID_SELECTED_REMOVEMARKERS, MF_BYCOMMAND | MF_ENABLED);
		else
			EnableMenuItem(sub, ID_SELECTED_REMOVEMARKERS, MF_BYCOMMAND | MF_DISABLED | MF_GRAYED);
		POINT pt = info.pt;
		ClientToScreen(hwndList, &pt);
		TrackPopupMenu(sub, 0, pt.x, pt.y, 0, taseditorWindow.hwndTASEditor, 0);
	}
}

bool PIANO_ROLL::checkIfTheresAnIconAtFrame(int frame)
{
	if (frame == currFrameCounter)
		return true;
	if (frame == playback.getLastPosition())
		return true;
	if (frame == playback.getPauseFrame())
		return true;
	if (bookmarks.findBookmarkAtFrame(frame) >= 0)
		return true;
	return false;
}

void PIANO_ROLL::crossGaps(int zDelta)
{
	POINT p;
	if (GetCursorPos(&p))
	{
		ScreenToClient(hwndList, &p);
		RECT wrect;
		GetClientRect(hwndList, &wrect);
		if (p.x >= 0 && p.x < wrect.right - wrect.left && p.y >= listTopMargin && p.y < wrect.bottom - wrect.top)
		{
			// perform hit test
			LVHITTESTINFO info;
			info.pt.x = p.x;
			info.pt.y = p.y;
			ListView_SubItemHitTest(hwndList, &info);
			int row_index = info.iItem;
			int column_index = info.iSubItem;
			if (row_index >= 0 && column_index >= COLUMN_ICONS && column_index <= COLUMN_FRAMENUM2)
			{
				if (column_index == COLUMN_ICONS)
				{
					// cross gaps in Icons
					if (zDelta < 0)
					{
						// search down
						int last_frame = currMovieData.getNumRecords() - 1;
						if (row_index < last_frame)
						{
							int frame = row_index + 1;
							bool result_of_closest_frame = checkIfTheresAnIconAtFrame(frame);
							while ((++frame) <= last_frame)
							{
								if (checkIfTheresAnIconAtFrame(frame) != result_of_closest_frame)
								{
									// found different result, so we crossed the gap
									ListView_Scroll(hwndList, 0, listRowHeight * (frame - row_index));
									break;
								}
							}
						}
					} else
					{
						// search up
						int first_frame = 0;
						if (row_index > first_frame)
						{
							int frame = row_index - 1;
							bool result_of_closest_frame = checkIfTheresAnIconAtFrame(frame);
							while ((--frame) >= first_frame)
							{
								if (checkIfTheresAnIconAtFrame(frame) != result_of_closest_frame)
								{
									// found different result, so we crossed the gap
									ListView_Scroll(hwndList, 0, listRowHeight * (frame - row_index));
									break;
								}
							}
						}
					}
				} else if (column_index == COLUMN_FRAMENUM || column_index == COLUMN_FRAMENUM2)
				{
					// cross gaps in Markers
					if (zDelta < 0)
					{
						// search down
						int last_frame = currMovieData.getNumRecords() - 1;
						if (row_index < last_frame)
						{
							int frame = row_index + 1;
							bool result_of_closest_frame = (markersManager.getMarkerAtFrame(frame) != 0);
							while ((++frame) <= last_frame)
							{
								if ((markersManager.getMarkerAtFrame(frame) != 0) != result_of_closest_frame)
								{
									// found different result, so we crossed the gap
									ListView_Scroll(hwndList, 0, listRowHeight * (frame - row_index));
									break;
								}
							}
						}
					} else
					{
						// search up
						int first_frame = 0;
						if (row_index > first_frame)
						{
							int frame = row_index - 1;
							bool result_of_closest_frame = (markersManager.getMarkerAtFrame(frame) != 0);
							while ((--frame) >= first_frame)
							{
								if ((markersManager.getMarkerAtFrame(frame) != 0) != result_of_closest_frame)
								{
									// found different result, so we crossed the gap
									ListView_Scroll(hwndList, 0, listRowHeight * (frame - row_index));
									break;
								}
							}
						}
					}
				} else
				{
					// cross gaps in Input
					int joy = (column_index - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
					int button = (column_index - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
					if (zDelta < 0)
					{
						// search down
						int last_frame = currMovieData.getNumRecords() - 1;
						if (row_index < last_frame)
						{
							int frame = row_index + 1;
							bool result_of_closest_frame = currMovieData.records[frame].checkBit(joy, button);
							while ((++frame) <= last_frame)
							{
								if (currMovieData.records[frame].checkBit(joy, button) != result_of_closest_frame)
								{
									// found different result, so we crossed the gap
									ListView_Scroll(hwndList, 0, listRowHeight * (frame - row_index));
									break;
								}
							}
						}
					} else
					{
						// search up
						int first_frame = 0;
						if (row_index > first_frame)
						{
							int frame = row_index - 1;
							bool result_of_closest_frame = currMovieData.records[frame].checkBit(joy, button);
							while ((--frame) >= first_frame)
							{
								if (currMovieData.records[frame].checkBit(joy, button) != result_of_closest_frame)
								{
									// found different result, so we crossed the gap
									ListView_Scroll(hwndList, 0, listRowHeight * (frame - row_index));
									break;
								}
							}
						}
					}
				}
			}
		}
	}	
}
// -------------------------------------------------------------------------
LRESULT APIENTRY headerWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	extern PIANO_ROLL pianoRoll;
	switch(msg)
	{
	case WM_SETCURSOR:
		// no column resizing cursor, always show arrow
		SetCursor(LoadCursor(0, IDC_ARROW));
		return true;
	case WM_MOUSEMOVE:
	{
		// perform hit test on header items
		HD_HITTESTINFO info;
		info.pt.x = GET_X_LPARAM(lParam) + HEADER_DX_FIX;
		info.pt.y = GET_Y_LPARAM(lParam);
		SendMessage(hWnd, HDM_HITTEST, 0, (LPARAM)&info);
		pianoRoll.headerItemUnderMouse = info.iItem;
		// ensure that WM_MOUSELEAVE will be catched
		TrackMouseEvent(&pianoRoll.tme);
		break;
	}
	case WM_MOUSELEAVE:
	{
		pianoRoll.headerItemUnderMouse = -1;
		break;
	}
	case WM_LBUTTONDOWN:
	case WM_LBUTTONDBLCLK:
		{
			if (selection.getCurrentRowsSelectionSize())
			{
				// perform hit test on header items
				HD_HITTESTINFO info;
				info.pt.x = GET_X_LPARAM(lParam) + HEADER_DX_FIX;
				info.pt.y = GET_Y_LPARAM(lParam);
				SendMessage(hWnd, HDM_HITTEST, 0, (LPARAM)&info);
				if (info.iItem >= COLUMN_FRAMENUM && info.iItem <= COLUMN_FRAMENUM2)
					pianoRoll.handleColumnSet(info.iItem, (GetKeyState(VK_MENU) < 0));
			}
		}
		return true;
	}
	return CallWindowProc(hwndHeaderOldWndproc, hWnd, msg, wParam, lParam);
}

// The subclass wndproc for the listview
LRESULT APIENTRY listWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	extern PIANO_ROLL pianoRoll;
	switch(msg)
	{
		case WM_CHAR:
		case WM_KILLFOCUS:
			return 0;
		case WM_SETCURSOR:
			if (LOWORD(lParam) == HTCLIENT)
			{
				pianoRoll.mustCheckItemUnderMouse = true;
				return true;
			}
			break;
		case WM_MOUSEMOVE:
		{
			pianoRoll.mustCheckItemUnderMouse = true;
			return 0;
		}
		case WM_NOTIFY:
		{
			if (((LPNMHDR)lParam)->hwndFrom == pianoRoll.hwndHeader)
			{
				switch (((LPNMHDR)lParam)->code)
				{
				case HDN_BEGINTRACKW:
				case HDN_BEGINTRACKA:
				case HDN_TRACK:
					return true;	// no column resizing
				case NM_CUSTOMDRAW:
					return pianoRoll.handleHeaderCustomDraw((NMLVCUSTOMDRAW*)lParam);
				}
			}
			break;
		}
		case WM_KEYDOWN:
			return 0;
		case WM_TIMER:
			// disable timer of entering edit mode (there's no edit mode anyway)
			return 0;
		case WM_LBUTTONDOWN:
		case WM_LBUTTONDBLCLK:
		{
			int fwKeys = GET_KEYSTATE_WPARAM(wParam);
			bool alt_pressed = (GetKeyState(VK_MENU) < 0);
			// perform hit test
			LVHITTESTINFO info;
			info.pt.x = GET_X_LPARAM(lParam);
			info.pt.y = GET_Y_LPARAM(lParam);
			ListView_SubItemHitTest(hWnd, &info);
			int row_index = info.iItem;
			int column_index = info.iSubItem;
			if (column_index == COLUMN_ICONS)
			{
				// clicked on the "icons" column
				pianoRoll.startDraggingPlaybackCursor();
			} else if (column_index == COLUMN_FRAMENUM || column_index == COLUMN_FRAMENUM2)
			{
				// clicked on the "Frame#" column
				if (row_index >= 0)
				{
					if (msg == WM_LBUTTONDBLCLK)
					{
						// doubleclick - set Marker and start dragging it
						if (!markersManager.getMarkerAtFrame(row_index))
						{
							if (markersManager.setMarkerAtFrame(row_index))
							{
								selection.mustFindCurrentMarker = playback.mustFindCurrentMarker = true;
								history.registerMarkersChange(MODTYPE_MARKER_SET, row_index);
								pianoRoll.redrawRow(row_index);
							}
						}
						pianoRoll.startDraggingMarker(GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam), row_index, column_index);
					} else
					{
						if (fwKeys & MK_SHIFT)
						{
							// select region from selection_beginning to row_index
							int selection_beginning = selection.getCurrentRowsSelectionBeginning();
							if (selection_beginning >= 0)
							{
								if (selection_beginning < row_index)
									selection.setRegionOfRowsSelection(selection_beginning, row_index + 1);
								else
									selection.setRegionOfRowsSelection(row_index, selection_beginning + 1);
							}
							pianoRoll.startSelectingDrag(row_index);
						} else if (alt_pressed)
						{
							// make Selection by Pattern
							int selection_beginning = selection.getCurrentRowsSelectionBeginning();
							if (selection_beginning >= 0)
							{
								selection.clearAllRowsSelection();
								if (selection_beginning < row_index)
									selection.setRegionOfRowsSelectionUsingPattern(selection_beginning, row_index);
								else
									selection.setRegionOfRowsSelectionUsingPattern(row_index, selection_beginning);
							}
							if (selection.isRowSelected(row_index))
								pianoRoll.startDeselectingDrag(row_index);
							else
								pianoRoll.startSelectingDrag(row_index);
						} else if (fwKeys & MK_CONTROL)
						{
							// clone current selection, so that user will be able to revert
							if (selection.getCurrentRowsSelectionSize() > 0)
								selection.addCurrentSelectionToHistory();
							if (selection.isRowSelected(row_index))
							{
								selection.clearSingleRowSelection(row_index);
								pianoRoll.startDeselectingDrag(row_index);
							} else
							{
								selection.setRowSelection(row_index);
								pianoRoll.startSelectingDrag(row_index);
							}
						} else	// just click
						{
							selection.clearAllRowsSelection();
							selection.setRowSelection(row_index);
							pianoRoll.startSelectingDrag(row_index);
						}
					}
				}
			} else if (column_index >= COLUMN_JOYPAD1_A && column_index <= COLUMN_JOYPAD4_R)
			{
				// clicked on Input
				if (row_index >= 0)
				{
					if (!alt_pressed && !(fwKeys & MK_SHIFT))
					{
						// clicked without Shift/Alt - bring Selection cursor to this row
						selection.clearAllRowsSelection();
						selection.setRowSelection(row_index);
					}
					// toggle Input
					pianoRoll.drawingStartTimestamp = clock();
					int joy = (column_index - COLUMN_JOYPAD1_A) / NUM_JOYPAD_BUTTONS;
					int button = (column_index - COLUMN_JOYPAD1_A) % NUM_JOYPAD_BUTTONS;
					int selection_beginning = selection.getCurrentRowsSelectionBeginning();
					if (alt_pressed && selection_beginning >= 0)
						editor.setInputUsingPattern(selection_beginning, row_index, joy, button, pianoRoll.drawingStartTimestamp);
					else if ((fwKeys & MK_SHIFT) && selection_beginning >= 0)
						editor.toggleInput(selection_beginning, row_index, joy, button, pianoRoll.drawingStartTimestamp);
					else
						editor.toggleInput(row_index, row_index, joy, button, pianoRoll.drawingStartTimestamp);
					// and start dragging/drawing
					if (pianoRoll.dragMode == DRAG_MODE_NONE)
					{
						if (taseditorConfig.drawInputByDragging)
						{
							// if clicked this click created buttonpress, then start painting, else start erasing
							if (currMovieData.records[row_index].checkBit(joy, button))
								pianoRoll.dragMode = DRAG_MODE_SET;
							else
								pianoRoll.dragMode = DRAG_MODE_UNSET;
							pianoRoll.drawingLastX = GET_X_LPARAM(lParam) + GetScrollPos(pianoRoll.hwndList, SB_HORZ);
							pianoRoll.drawingLastY = GET_Y_LPARAM(lParam) + GetScrollPos(pianoRoll.hwndList, SB_VERT) * pianoRoll.listRowHeight;
						} else
						{
							pianoRoll.dragMode = DRAG_MODE_OBSERVE;
						}
					}
				}
			}
			return 0;
		}
		case WM_MBUTTONDOWN:
		case WM_MBUTTONDBLCLK:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			playback.handleMiddleButtonClick();
			return 0;
		}
		case WM_MOUSEWHEEL:
		{
			bool alt_pressed = (GetKeyState(VK_MENU) < 0);
			int fwKeys = GET_KEYSTATE_WPARAM(wParam);
			int zDelta = GET_WHEEL_DELTA_WPARAM(wParam);
			if (fwKeys & MK_SHIFT)
			{
				// Shift + wheel = Playback rewind full(speed)/forward full(speed)
				if (zDelta < 0)
					playback.handleForwardFull(-zDelta / WHEEL_DELTA);
				else if (zDelta > 0)
					playback.handleRewindFull(zDelta / WHEEL_DELTA);
			} else if (fwKeys & MK_CONTROL)
			{
				// Ctrl + wheel = Selection rewind full(speed)/forward full(speed)
				if (zDelta < 0)
					selection.jumpToNextMarker(-zDelta / WHEEL_DELTA);
				else if (zDelta > 0)
					selection.jumpToPreviousMarker(zDelta / WHEEL_DELTA);
			} else if (fwKeys & MK_RBUTTON)
			{
				// Right button + wheel = rewind/forward Playback
				int delta = zDelta / WHEEL_DELTA;
				if (delta < -1 || delta > 1)
					delta *= PLAYBACK_WHEEL_BOOST;
				int destination_frame;
				if (FCEUI_EmulationPaused() || playback.getPauseFrame() < 0)
					destination_frame = currFrameCounter - delta;
				else
					destination_frame = playback.getPauseFrame() - delta;
				if (destination_frame < 0)
					destination_frame = 0;
				playback.jump(destination_frame);
			} else if (history.isCursorOverHistoryList())
			{
				return SendMessage(history.hwndHistoryList, WM_MOUSEWHEEL_RESENT, wParam, lParam);
			} else if (alt_pressed)
			{
				// cross gaps in Input/Markers
				pianoRoll.crossGaps(zDelta);
			} else
			{
				// normal scrolling - make it 2x faster than usual
				CallWindowProc(hwndListOldWndProc, hWnd, msg, MAKELONG(fwKeys, zDelta * PIANO_ROLL_SCROLLING_BOOST), lParam);
			}
			return 0;
		}
		case WM_RBUTTONDOWN:
		case WM_RBUTTONDBLCLK:
			pianoRoll.rightButtonDragMode = true;
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		case WM_RBUTTONUP:
		{
			// perform hit test
			LVHITTESTINFO info;
			info.pt.x = GET_X_LPARAM(lParam);
			info.pt.y = GET_Y_LPARAM(lParam);
			ListView_SubItemHitTest(hWnd, &info);
			// show context menu if user right-clicked on Frame#
			if (info.iSubItem <= COLUMN_FRAMENUM || info.iSubItem >= COLUMN_FRAMENUM2)
				pianoRoll.handleRightClick(info);
			return 0;
		}
		case WM_NCLBUTTONDOWN:
		{
			if (wParam == HTBORDER)
			{
				POINT p;
				p.x = GET_X_LPARAM(lParam);
				p.y = GET_Y_LPARAM(lParam);
				ScreenToClient(pianoRoll.hwndList, &p);
				if (p.x <= 0)
				{
					// user clicked on left border of the Piano Roll
					// consider this as a "misclick" on Piano Roll's first column
					pianoRoll.startDraggingPlaybackCursor();
					return 0;
				}
			}
			break;
		}
		case WM_MOUSEACTIVATE:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
            break;
		}
		case LVM_ENSUREVISIBLE:
		{
			// Piano Roll probably scrolls
			pianoRoll.mustCheckItemUnderMouse = true;
			break;
		}
		case WM_VSCROLL:
		{
			// fix for known WinXP bug
			if (LOWORD(wParam) == SB_LINEUP)
			{
				ListView_Scroll(pianoRoll.hwndList, 0, -pianoRoll.listRowHeight);
				return 0;
			} else if (LOWORD(wParam) == SB_LINEDOWN)
			{
				ListView_Scroll(pianoRoll.hwndList, 0, pianoRoll.listRowHeight);
				return 0;
			}
			break;
		}
		case WM_HSCROLL:
		{
			if (LOWORD(wParam) == SB_LINELEFT)
			{
				ListView_Scroll(pianoRoll.hwndList, -COLUMN_BUTTON_WIDTH, 0);
				return 0;
			} else if (LOWORD(wParam) == SB_LINERIGHT)
			{
				ListView_Scroll(pianoRoll.hwndList, COLUMN_BUTTON_WIDTH, 0);
				return 0;
			}
			break;
		}

	}
	return CallWindowProc(hwndListOldWndProc, hWnd, msg, wParam, lParam);
}
// ----------------------------------------------------------------------------------------
LRESULT APIENTRY markerDragBoxWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	extern PIANO_ROLL pianoRoll;
	switch(message)
	{
		case WM_CREATE:
		{
			// create static bitmap placeholder
			char framenum[DIGITS_IN_FRAMENUM + 1];
			U32ToDecStr(framenum, pianoRoll.markerDragFrameNumber, DIGITS_IN_FRAMENUM);
			pianoRoll.hwndMarkerDragBoxText = CreateWindow(WC_STATIC, framenum, SS_CENTER| WS_CHILD | WS_VISIBLE, 0, 0, COLUMN_FRAMENUM_WIDTH, pianoRoll.listRowHeight, hwnd, NULL, NULL, NULL);
			SendMessage(pianoRoll.hwndMarkerDragBoxText, WM_SETFONT, (WPARAM)pianoRoll.hMainListSelectFont, 0);
			return 0;
		}
		case WM_CTLCOLORSTATIC:
		{
			// change color of static text fields
			if ((HWND)lParam == pianoRoll.hwndMarkerDragBoxText)
			{
				SetTextColor((HDC)wParam, NORMAL_TEXT_COLOR);
				SetBkMode((HDC)wParam, TRANSPARENT);
				if (taseditorConfig.bindMarkersToInput)
					return (LRESULT)(pianoRoll.markerDragBoxBrushBind);
				else
					return (LRESULT)(pianoRoll.markerDragBoxBrushNormal);
			}
			break;
		}
	}
	return DefWindowProc(hwnd, message, wParam, lParam);
}

