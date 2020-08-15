/* ---------------------------------------------------------------------------------
Implementation file of POPUP_DISPLAY class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Popup display - Manager of popup windows
[Single instance]

* implements all operations with popup windows: initialization, redrawing, centering, screenshot decompression and conversion
* regularly inspects changes of Bookmarks Manager and shows/updates/hides popup windows
* on demand: updates contents of popup windows
* stores resources: coordinates and appearance of popup windows, timings of fade in/out
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "zlib.h"

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern BOOKMARKS bookmarks;
extern BRANCHES branches;
extern PIANO_ROLL pianoRoll;
extern MARKERS_MANAGER markersManager;
extern PLAYBACK playback;

LRESULT CALLBACK screenshotBitmapWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);
LRESULT APIENTRY noteDescriptionWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);

// resources
char szClassName[] = "ScreenshotBitmap";
char szClassName2[] = "NoteDescription";

POPUP_DISPLAY::POPUP_DISPLAY()
{
	hwndScreenshotBitmap = 0;
	hwndNoteDescription = 0;
	// create BITMAPINFO
	screenshotBmi = (LPBITMAPINFO)malloc(sizeof(BITMAPINFOHEADER) + 256 * sizeof(RGBQUAD));	// 256 color in palette
	screenshotBmi->bmiHeader.biSize = sizeof(screenshotBmi->bmiHeader);
	screenshotBmi->bmiHeader.biWidth = SCREENSHOT_WIDTH;
	screenshotBmi->bmiHeader.biHeight = -SCREENSHOT_HEIGHT;		// negative value = top-down bmp
	screenshotBmi->bmiHeader.biPlanes = 1;
	screenshotBmi->bmiHeader.biBitCount = 8;
	screenshotBmi->bmiHeader.biCompression = BI_RGB;
	screenshotBmi->bmiHeader.biSizeImage = 0;

	// register SCREENSHOT_DISPLAY window class
	winCl1.hInstance = fceu_hInstance;
	winCl1.lpszClassName = szClassName;
	winCl1.lpfnWndProc = screenshotBitmapWndProc;
	winCl1.style = CS_DBLCLKS;
	winCl1.cbSize = sizeof(WNDCLASSEX);
	winCl1.hIcon = 0;
	winCl1.hIconSm = 0;
	winCl1.hCursor = 0;
	winCl1.lpszMenuName = 0;
	winCl1.cbClsExtra = 0;
	winCl1.cbWndExtra = 0;
	winCl1.hbrBackground = 0;
	if (!RegisterClassEx(&winCl1))
		FCEU_printf("Error registering SCREENSHOT_DISPLAY window class\n");

	// register NOTE_DESCRIPTION window class
	winCl2.hInstance = fceu_hInstance;
	winCl2.lpszClassName = szClassName2;
	winCl2.lpfnWndProc = noteDescriptionWndProc;
	winCl2.style = CS_DBLCLKS;
	winCl2.cbSize = sizeof(WNDCLASSEX);
	winCl2.hIcon = 0;
	winCl2.hIconSm = 0;
	winCl2.hCursor = 0;
	winCl2.lpszMenuName = 0;
	winCl2.cbClsExtra = 0;
	winCl2.cbWndExtra = 0;
	winCl2.hbrBackground = 0;
	if (!RegisterClassEx(&winCl2))
		FCEU_printf("Error registering NOTE_DESCRIPTION window class\n");

	// create blendfunction
	blend.BlendOp = AC_SRC_OVER;
	blend.BlendFlags = 0;
	blend.AlphaFormat = 0;
	blend.SourceConstantAlpha = 255;
}

void POPUP_DISPLAY::init()
{
	free();
	// fill scr_bmp palette with current palette colors
	extern PALETTEENTRY *color_palette;
	for (int i = 0; i < 256; ++i)
	{
		screenshotBmi->bmiColors[i].rgbRed = color_palette[i].peRed;
		screenshotBmi->bmiColors[i].rgbGreen = color_palette[i].peGreen;
		screenshotBmi->bmiColors[i].rgbBlue = color_palette[i].peBlue;
	}
	HDC win_hdc = GetWindowDC(pianoRoll.hwndList);
	screenshotHBitmap = CreateDIBSection(win_hdc, screenshotBmi, DIB_RGB_COLORS, (void**)&screenshotRasterPointer, 0, 0);
	// calculate coordinates of popup windows (relative to TAS Editor window)
	updateBecauseParentWindowMoved();
}
void POPUP_DISPLAY::free()
{
	reset();
	if (screenshotHBitmap)
	{
		DeleteObject(screenshotHBitmap);
		screenshotHBitmap = 0;
	}
}
void POPUP_DISPLAY::reset()
{
	currentlyDisplayedBookmark = ITEM_UNDER_MOUSE_NONE;
	nextUpdateTime = screenshotBitmapPhase = 0;
	if (hwndScreenshotBitmap)
	{
		DestroyWindow(hwndScreenshotBitmap);
		hwndScreenshotBitmap = 0;
	}
	if (hwndNoteDescription)
	{
		DestroyWindow(hwndNoteDescription);
		hwndNoteDescription = 0;
	}
}

void POPUP_DISPLAY::update()
{
	// once per 40 milliseconds update popup windows alpha
	if (clock() > nextUpdateTime)
	{
		nextUpdateTime = clock() + DISPLAY_UPDATE_TICK;
		if (branches.isSafeToShowBranchesData() && bookmarks.itemUnderMouse >= 0 && bookmarks.itemUnderMouse < TOTAL_BOOKMARKS && bookmarks.bookmarksArray[bookmarks.itemUnderMouse].notEmpty)
		{
			if (taseditorConfig.displayBranchScreenshots && !hwndScreenshotBitmap)
			{
				// create window
				hwndScreenshotBitmap = CreateWindowEx(WS_EX_LAYERED | WS_EX_TRANSPARENT, szClassName, szClassName, WS_POPUP, taseditorConfig.windowX + screenshotBitmapX, taseditorConfig.windowY + screenshotBitmapY, SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT, taseditorWindow.hwndTASEditor, NULL, fceu_hInstance, NULL);
				redrawScreenshotBitmap();
				ShowWindow(hwndScreenshotBitmap, SW_SHOWNA);
			}
			if (taseditorConfig.displayBranchDescriptions && !hwndNoteDescription)
			{
				RECT wrect;
				GetWindowRect(playback.hwndPlaybackMarkerEditField, &wrect);
				descriptionX = screenshotBitmapX + (SCREENSHOT_WIDTH - (wrect.right - wrect.left)) / 2;
				hwndNoteDescription = CreateWindowEx(WS_EX_LAYERED | WS_EX_TRANSPARENT, szClassName2, szClassName2, WS_POPUP, taseditorConfig.windowX + descriptionX, taseditorConfig.windowY + descriptionY, wrect.right - wrect.left, wrect.bottom - wrect.top, taseditorWindow.hwndTASEditor, NULL, fceu_hInstance, NULL);
				changeDescriptionText();
				ShowWindow(hwndNoteDescription, SW_SHOWNA);
			}
			// change screenshot_bitmap pic and description text if needed
			if (currentlyDisplayedBookmark != bookmarks.itemUnderMouse)
			{
				if (taseditorConfig.displayBranchScreenshots)
					changeScreenshotBitmap();
				if (taseditorConfig.displayBranchDescriptions)
					changeDescriptionText();
				currentlyDisplayedBookmark = bookmarks.itemUnderMouse;
			}
			if (screenshotBitmapPhase < SCREENSHOT_BITMAP_PHASE_MAX)
			{
				screenshotBitmapPhase++;
				// update alpha
				int phase_alpha = screenshotBitmapPhase;
				if (phase_alpha > SCREENSHOT_BITMAP_PHASE_ALPHA_MAX) phase_alpha = SCREENSHOT_BITMAP_PHASE_ALPHA_MAX;
				if (hwndScreenshotBitmap)
				{
					SetLayeredWindowAttributes(hwndScreenshotBitmap, 0, (255 * phase_alpha) / SCREENSHOT_BITMAP_PHASE_ALPHA_MAX, LWA_ALPHA);
					UpdateLayeredWindow(hwndScreenshotBitmap, 0, 0, 0, 0, 0, 0, &blend, ULW_ALPHA);
				}
				if (hwndNoteDescription)
				{
					SetLayeredWindowAttributes(hwndNoteDescription, 0, (255 * phase_alpha) / SCREENSHOT_BITMAP_PHASE_ALPHA_MAX, LWA_ALPHA);
					UpdateLayeredWindow(hwndNoteDescription, 0, 0, 0, 0, 0, 0, &blend, ULW_ALPHA);
				}
			}
		} else
		{
			// fade and finally hide screenshot
			if (screenshotBitmapPhase > 0)
				screenshotBitmapPhase--;
			if (screenshotBitmapPhase > 0)
			{
				// update alpha
				int phase_alpha = screenshotBitmapPhase;
				if (phase_alpha > SCREENSHOT_BITMAP_PHASE_ALPHA_MAX)
					phase_alpha = SCREENSHOT_BITMAP_PHASE_ALPHA_MAX;
				else if (phase_alpha < 0)
					phase_alpha = 0;
				if (hwndScreenshotBitmap)
				{
					SetLayeredWindowAttributes(hwndScreenshotBitmap, 0, (255 * phase_alpha) / SCREENSHOT_BITMAP_PHASE_ALPHA_MAX, LWA_ALPHA);
					UpdateLayeredWindow(hwndScreenshotBitmap, 0, 0, 0, 0, 0, 0, &blend, ULW_ALPHA);
				}
				if (hwndNoteDescription)
				{
					SetLayeredWindowAttributes(hwndNoteDescription, 0, (255 * phase_alpha) / SCREENSHOT_BITMAP_PHASE_ALPHA_MAX, LWA_ALPHA);
					UpdateLayeredWindow(hwndNoteDescription, 0, 0, 0, 0, 0, 0, &blend, ULW_ALPHA);
				}
			} else
			{
				// destroy popup windows
				screenshotBitmapPhase = 0;
				if (hwndScreenshotBitmap)
				{
					DestroyWindow(hwndScreenshotBitmap);
					hwndScreenshotBitmap = 0;
				}
				if (hwndNoteDescription)
				{
					DestroyWindow(hwndNoteDescription);
					hwndNoteDescription = 0;
				}
				// immediately redraw the window below those
				UpdateWindow(taseditorWindow.hwndTASEditor);
			}
		}
	}
}

void POPUP_DISPLAY::changeScreenshotBitmap()
{
	// uncompress
	uLongf destlen = SCREENSHOT_SIZE;
	int e = uncompress(&screenshotRasterPointer[0], &destlen, &bookmarks.bookmarksArray[bookmarks.itemUnderMouse].savedScreenshot[0], bookmarks.bookmarksArray[bookmarks.itemUnderMouse].savedScreenshot.size());
	if (e != Z_OK && e != Z_BUF_ERROR)
	{
		// error decompressing
		FCEU_printf("Error decompressing screenshot %d\n", bookmarks.itemUnderMouse);
		// at least fill bitmap with zeros
		memset(&screenshotRasterPointer[0], 0, SCREENSHOT_SIZE);
	}
	redrawScreenshotBitmap();
}
void POPUP_DISPLAY::redrawScreenshotBitmap()
{
	HBITMAP temp_bmp = (HBITMAP)SendMessage(hwndScreenshotPicture, STM_SETIMAGE, IMAGE_BITMAP, (LPARAM)screenshotHBitmap);
	if (temp_bmp && temp_bmp != screenshotHBitmap)
		DeleteObject(temp_bmp);
}
void POPUP_DISPLAY::changeDescriptionText()
{
	// retrieve info from the pointed bookmark's Markers
	int frame = bookmarks.bookmarksArray[bookmarks.itemUnderMouse].snapshot.keyFrame;
	int markerID = markersManager.getMarkerAboveFrame(bookmarks.bookmarksArray[bookmarks.itemUnderMouse].snapshot.markers, frame);
	char new_text[MAX_NOTE_LEN];
	strcpy(new_text, markersManager.getNoteCopy(bookmarks.bookmarksArray[bookmarks.itemUnderMouse].snapshot.markers, markerID).c_str());
	SetWindowText(hwndNoteText, new_text);
}

void POPUP_DISPLAY::updateBecauseParentWindowMoved()
{
	// calculate new positions relative to IDC_BOOKMARKS_BOX
	RECT temp_rect, parent_rect;
	GetWindowRect(taseditorWindow.hwndTASEditor, &parent_rect);
	GetWindowRect(GetDlgItem(taseditorWindow.hwndTASEditor, IDC_BOOKMARKS_BOX), &temp_rect);
	screenshotBitmapX = temp_rect.left - SCREENSHOT_WIDTH - SCREENSHOT_BITMAP_DX - parent_rect.left;
	screenshotBitmapY = (temp_rect.bottom - SCREENSHOT_HEIGHT) - parent_rect.top;
	RECT wrect;
	GetWindowRect(playback.hwndPlaybackMarkerEditField, &wrect);
	descriptionX = screenshotBitmapX + (SCREENSHOT_WIDTH - (wrect.right - wrect.left)) / 2;
	descriptionY = screenshotBitmapY + SCREENSHOT_HEIGHT + SCREENSHOT_BITMAP_DESCRIPTION_GAP;
	// if popup windows are currently shown, update their positions
	if (hwndScreenshotBitmap)
		SetWindowPos(hwndScreenshotBitmap, 0, taseditorConfig.windowX + screenshotBitmapX, taseditorConfig.windowY + screenshotBitmapY, 0, 0, SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE);
	if (hwndNoteDescription)
		SetWindowPos(hwndNoteDescription, 0, taseditorConfig.windowX + descriptionX, taseditorConfig.windowY + descriptionY, 0, 0, SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE);
}
// ----------------------------------------------------------------------------------------
LRESULT APIENTRY screenshotBitmapWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	extern POPUP_DISPLAY popupDisplay;
	switch(message)
	{
		case WM_CREATE:
		{
			// create static bitmap placeholder
			popupDisplay.hwndScreenshotPicture = CreateWindow(WC_STATIC, NULL, SS_BITMAP | WS_CHILD | WS_VISIBLE, 0, 0, 255, 255, hwnd, NULL, NULL, NULL);
			return 0;
		}
		default:
			return DefWindowProc(hwnd, message, wParam, lParam);
	}
}
LRESULT APIENTRY noteDescriptionWndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
	extern POPUP_DISPLAY popupDisplay;
	switch(message)
	{
		case WM_CREATE:
		{
			// create static text field
			RECT wrect;
			GetWindowRect(playback.hwndPlaybackMarkerEditField, &wrect);
			popupDisplay.hwndNoteText = CreateWindow(WC_STATIC, NULL, WS_CHILD | WS_VISIBLE | SS_CENTER | SS_ENDELLIPSIS | SS_SUNKEN, 1, 1, wrect.right - wrect.left - 2, wrect.bottom - wrect.top - 2, hwnd, NULL, NULL, NULL);
			SendMessage(popupDisplay.hwndNoteText, WM_SETFONT, (WPARAM)pianoRoll.hMarkersEditFont, 0);
			return 0;
		}
		default:
			return DefWindowProc(hwnd, message, wParam, lParam);
	}
}


