/* ---------------------------------------------------------------------------------
Implementation file of Branches class
Copyright (c) 2011-2013 AnS

(The MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
------------------------------------------------------------------------------------
Branches - Manager of Branches
[Single instance]

* stores info about Branches (relations of Bookmarks) and the id of current Branch
* also stores the time of the last modification (see fireball) and the time of project beginning (see cloudlet)
* also caches data used in calculations (cached_first_difference, cached_timelines)
* saves and loads the data from a project file. On error: sends warning to caller
* implements the working of Branches Tree: creating, recalculating relations, animating, redrawing, mouseover, clicks
* on demand: reacts on Bookmarks/current Movie changes and recalculates the Branches Tree
* regularly updates animations in Branches Tree and calculates Playback cursor position on the Tree
* stores resources: coordinates for building Branches Tree, animation timings
------------------------------------------------------------------------------------ */

#include "taseditor_project.h"
#include "utils/xstring.h"
#include "zlib.h"
#include <math.h>

#pragma comment(lib, "msimg32.lib")

LRESULT APIENTRY BranchesBitmapWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
WNDPROC hwndBranchesBitmap_oldWndProc;

extern TASEDITOR_CONFIG taseditorConfig;
extern TASEDITOR_WINDOW taseditorWindow;
extern POPUP_DISPLAY popupDisplay;
extern PLAYBACK playback;
extern SELECTION selection;
extern GREENZONE greenzone;
extern TASEDITOR_PROJECT project;
extern HISTORY history;
extern PIANO_ROLL pianoRoll;
extern BOOKMARKS bookmarks;

extern COLORREF bookmark_flash_colors[TOTAL_BOOKMARK_COMMANDS][FLASH_PHASE_MAX+1];

// resources
// corners cursor animation
int corners_cursor_shift[BRANCHES_ANIMATION_FRAMES] = {0, 0, 1, 1, 2, 2, 2, 2, 1, 1, 0, 0 };

BRANCHES::BRANCHES()
{
}

void BRANCHES::init()
{
	free();

	// subclass BranchesBitmap
	hwndBranchesBitmap_oldWndProc = (WNDPROC)SetWindowLong(bookmarks.hwndBranchesBitmap, GWL_WNDPROC, (LONG)BranchesBitmapWndProc);

	// init arrays
	branchX.resize(TOTAL_BOOKMARKS+1);
	branchY.resize(TOTAL_BOOKMARKS+1);
	branchPreviousX.resize(TOTAL_BOOKMARKS+1);
	branchPreviousY.resize(TOTAL_BOOKMARKS+1);
	branchCurrentX.resize(TOTAL_BOOKMARKS+1);
	branchCurrentY.resize(TOTAL_BOOKMARKS+1);

	// init GDI stuff
	HDC win_hdc = GetWindowDC(bookmarks.hwndBranchesBitmap);
	hBitmapDC = CreateCompatibleDC(win_hdc);
	hBranchesBitmap = CreateCompatibleBitmap(win_hdc, BRANCHES_BITMAP_WIDTH, BRANCHES_BITMAP_HEIGHT);
	hOldBitmap = (HBITMAP)SelectObject(hBitmapDC, hBranchesBitmap);
	hBufferDC = CreateCompatibleDC(win_hdc);
	hBufferBitmap = CreateCompatibleBitmap(win_hdc, BRANCHES_BITMAP_WIDTH, BRANCHES_BITMAP_HEIGHT);
	hOldBitmap1 = (HBITMAP)SelectObject(hBufferDC, hBufferBitmap);
	normalBrush = CreateSolidBrush(0x000000);
	borderBrush = CreateSolidBrush(0xb99d7f);
	selectedSlotBrush = CreateSolidBrush(0x5656CA);
	// prepare bg gradient
	vertex[0].x     = 0;
	vertex[0].y     = 0;
	vertex[0].Red   = 0xBF00;
	vertex[0].Green = 0xE200;
	vertex[0].Blue  = 0xEF00;
	vertex[0].Alpha = 0x0000;
	vertex[1].x     = BRANCHES_BITMAP_WIDTH;
	vertex[1].y     = BRANCHES_BITMAP_HEIGHT;
	vertex[1].Red   = 0xE500;
	vertex[1].Green = 0xFB00;
	vertex[1].Blue  = 0xFF00;
	vertex[1].Alpha = 0x0000;
	gRect.UpperLeft  = 0;
	gRect.LowerRight = 1;
	branchesBitmapRect.left = 0;
	branchesBitmapRect.top = 0;
	branchesBitmapRect.right = BRANCHES_BITMAP_WIDTH;
	branchesBitmapRect.bottom = BRANCHES_BITMAP_HEIGHT;
	// prepare branches spritesheet
	hBranchesSpritesheet = LoadBitmap(fceu_hInstance, MAKEINTRESOURCE(IDB_BRANCH_SPRITESHEET));
	hSpritesheetDC = CreateCompatibleDC(win_hdc);
	hOldBitmap2 = (HBITMAP)SelectObject(hSpritesheetDC, hBranchesSpritesheet);
	// create pens
	normalPen = CreatePen(PS_SOLID, 1, 0x0);
	timelinePen = CreatePen(PS_SOLID, 1, 0x0020E0);
	selectPen = CreatePen(PS_SOLID, 2, 0xFF9080);

	// set positions of slots to default coordinates
	for (int i = TOTAL_BOOKMARKS; i >= 0; i--)
	{
		branchX[i] = branchPreviousX[i] = branchCurrentX[i] = EMPTY_BRANCHES_X_BASE;
		branchY[i] = branchPreviousY[i] = branchCurrentY[i] = EMPTY_BRANCHES_Y_BASE + EMPTY_BRANCHES_Y_FACTOR * ((i + TOTAL_BOOKMARKS - 1) % TOTAL_BOOKMARKS);
	}
	reset();
	cornersCursorX = cornersCursorY = 0;
	nextAnimationTime = 0;

	update();
}
void BRANCHES::free()
{
	parents.resize(0);
	cachedFirstDifferences.resize(0);
	cachedTimelines.resize(0);
	branchX.resize(0);
	branchY.resize(0);
	branchPreviousX.resize(0);
	branchPreviousY.resize(0);
	branchCurrentX.resize(0);
	branchCurrentY.resize(0);
	// free GDI stuff
	if (hOldBitmap && hBitmapDC)
	{
		SelectObject(hBitmapDC, hOldBitmap);
		DeleteDC(hBitmapDC);
		hBitmapDC = NULL;
	}
	if (hBranchesBitmap)
	{
		DeleteObject(hBranchesBitmap);
		hBranchesBitmap = NULL;
	}
	if (hOldBitmap1 && hBufferDC)
	{
		SelectObject(hBufferDC, hOldBitmap1);
		DeleteDC(hBufferDC);
		hBufferDC = NULL;
	}
	if (hBufferBitmap)
	{
		DeleteObject(hBufferBitmap);
		hBufferBitmap = NULL;
	}
	if (hOldBitmap2 && hSpritesheetDC)
	{
		SelectObject(hSpritesheetDC, hOldBitmap2);
		DeleteDC(hSpritesheetDC);
		hSpritesheetDC = NULL;
	}
	if (hBranchesSpritesheet)
	{
		DeleteObject(hBranchesSpritesheet);
		hBranchesSpritesheet = NULL;
	}
	if (normalBrush)
	{
		DeleteObject(normalBrush);
		normalBrush = 0;
	}
	if (borderBrush)
	{
		DeleteObject(borderBrush);
		borderBrush = 0;
	}
	if (selectedSlotBrush)
	{
		DeleteObject(selectedSlotBrush);
		selectedSlotBrush = 0;
	}
	if (normalPen)
	{
		DeleteObject(normalPen);
		normalPen = 0;
	}
	if (timelinePen)
	{
		DeleteObject(normalPen);
		timelinePen = 0;
	}
	if (selectPen)
	{
		DeleteObject(normalPen);
		selectPen = 0;
	}
}
void BRANCHES::reset()
{
	parents.resize(TOTAL_BOOKMARKS);
	for (int i = TOTAL_BOOKMARKS-1; i >= 0; i--)
		parents[i] = ITEM_UNDER_MOUSE_CLOUD;

	cachedTimelines.resize(TOTAL_BOOKMARKS);
	cachedFirstDifferences.resize(TOTAL_BOOKMARKS);
	for (int i = TOTAL_BOOKMARKS-1; i >= 0; i--)
	{
		cachedTimelines[i] = ITEM_UNDER_MOUSE_CLOUD;
		cachedFirstDifferences[i].resize(TOTAL_BOOKMARKS);
		for (int t = TOTAL_BOOKMARKS-1; t >= 0; t--)
			cachedFirstDifferences[i][t] = FIRST_DIFFERENCE_UNKNOWN;
	}

	resetVars();
	// set positions of slots to default coordinates
	for (int i = TOTAL_BOOKMARKS; i >= 0; i--)
	{
		branchPreviousX[i] = branchCurrentX[i];
		branchPreviousY[i] = branchCurrentY[i];
		branchX[i] = EMPTY_BRANCHES_X_BASE;
		branchY[i] = EMPTY_BRANCHES_Y_BASE + EMPTY_BRANCHES_Y_FACTOR * ((i + TOTAL_BOOKMARKS - 1) % TOTAL_BOOKMARKS);
	}
	cloudPreviousX = cloudCurrentX;
	cloudX = cloudCurrentX = BRANCHES_CLOUD_X;
	transitionPhase = BRANCHES_TRANSITION_MAX;

	currentBranch = ITEM_UNDER_MOUSE_CLOUD;
	changesSinceCurrentBranch = false;
	fireballSize = 0;

	// set cloud_time and current_pos_time
	setCurrentPosTimestamp();
	strcpy(cloudTimestamp, currentPosTimestamp);
}
void BRANCHES::resetVars()
{
	transitionPhase = currentAnimationFrame = 0;
	playbackCursorX = playbackCursorY = 0;
	branchRightclicked = lastItemUnderMouse = -1;
	mustRecalculateBranchesTree = mustRedrawBranchesBitmap = true;
	nextAnimationTime = clock() + BRANCHES_ANIMATION_TICK;
}

void BRANCHES::update()
{
	if (mustRecalculateBranchesTree)
		recalculateBranchesTree();

	// once per 40 milliseconds update branches_bitmap
	if (clock() > nextAnimationTime)
	{
		// animate branches_bitmap
		nextAnimationTime = clock() + BRANCHES_ANIMATION_TICK;
		currentAnimationFrame = (currentAnimationFrame + 1) % BRANCHES_ANIMATION_FRAMES;
		if (bookmarks.editMode == EDIT_MODE_BRANCHES)
		{
			// update floating "empty" branches
			int floating_phase_target;
			for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
			{
				if (!bookmarks.bookmarksArray[i].notEmpty)
				{
					if (i == bookmarks.itemUnderMouse)
						floating_phase_target = MAX_FLOATING_PHASE;
					else
						floating_phase_target = 0;
					if (bookmarks.bookmarksArray[i].floatingPhase > floating_phase_target)
					{
						bookmarks.bookmarksArray[i].floatingPhase--;
						mustRedrawBranchesBitmap = true;
					} else if (bookmarks.bookmarksArray[i].floatingPhase < floating_phase_target)
					{
						bookmarks.bookmarksArray[i].floatingPhase++;
						mustRedrawBranchesBitmap = true;
					}
				}
			}
			// grow or shrink fireball size
			if (changesSinceCurrentBranch)
			{
				fireballSize++;
				if (fireballSize > BRANCHES_FIREBALL_MAX_SIZE) fireballSize = BRANCHES_FIREBALL_MAX_SIZE;
			} else
			{
				fireballSize--;
				if (fireballSize < 0) fireballSize = 0;
			}
			// also update transition from old to new tree
			if (transitionPhase)
			{
				transitionPhase--;
				// recalculate current positions of branch items
				for (int i = 0; i <= TOTAL_BOOKMARKS; ++i)
				{
					branchCurrentX[i] = (branchX[i] * (BRANCHES_TRANSITION_MAX - transitionPhase) + branchPreviousX[i] * transitionPhase) / BRANCHES_TRANSITION_MAX;
					branchCurrentY[i] = (branchY[i] * (BRANCHES_TRANSITION_MAX - transitionPhase) + branchPreviousY[i] * transitionPhase) / BRANCHES_TRANSITION_MAX;
				}
				cloudCurrentX = (cloudX * (BRANCHES_TRANSITION_MAX - transitionPhase) + cloudPreviousX * transitionPhase) / BRANCHES_TRANSITION_MAX;
				mustRedrawBranchesBitmap = true;
				bookmarks.mustCheckItemUnderMouse = true;
			} else if (!mustRedrawBranchesBitmap)
			{
				// just update sprites
				InvalidateRect(bookmarks.hwndBranchesBitmap, 0, FALSE);
			}
			// calculate Playback cursor position
			int branch, tempBranchX, tempBranchY, parent, parentX, parentY, upperFrame, lowerFrame;
			double distance;
			if (currentBranch != ITEM_UNDER_MOUSE_CLOUD)
			{
				if (changesSinceCurrentBranch)
				{
					parent = ITEM_UNDER_MOUSE_FIREBALL;
				} else
				{
					parent = findFullTimelineForBranch(currentBranch);
					if (parent != currentBranch && bookmarks.bookmarksArray[parent].snapshot.keyFrame == bookmarks.bookmarksArray[currentBranch].snapshot.keyFrame)
						parent = currentBranch;
				}
				do
				{
					branch = parent;
					if (branch == ITEM_UNDER_MOUSE_FIREBALL)
						parent = currentBranch;
					else
						parent = parents[branch];
					if (parent == ITEM_UNDER_MOUSE_CLOUD)
						lowerFrame = -1;
					else
						lowerFrame = bookmarks.bookmarksArray[parent].snapshot.keyFrame;
				} while (parent != ITEM_UNDER_MOUSE_CLOUD && currFrameCounter < lowerFrame);
				if (branch == ITEM_UNDER_MOUSE_FIREBALL)
					upperFrame = currMovieData.getNumRecords() - 1;
				else
					upperFrame = bookmarks.bookmarksArray[branch].snapshot.keyFrame;
				tempBranchX = branchCurrentX[branch];
				tempBranchY = branchCurrentY[branch];
				if (parent == ITEM_UNDER_MOUSE_CLOUD)
				{
					parentX = cloudCurrentX;
					parentY = BRANCHES_CLOUD_Y;
				} else
				{
	 				parentX = branchCurrentX[parent];
					parentY = branchCurrentY[parent];
				}
				if (upperFrame != lowerFrame)
				{
					distance = (double)(currFrameCounter - lowerFrame) / (double)(upperFrame - lowerFrame);
					if (distance > 1.0) distance = 1.0;
				} else
				{
					distance = 1.0;
				}
				playbackCursorX = parentX + distance * (tempBranchX - parentX);
				playbackCursorY = parentY + distance * (tempBranchY - parentY);
			} else
			{
				if (changesSinceCurrentBranch)
				{
					// special case: there's only cloud + fireball
					upperFrame = currMovieData.getNumRecords() - 1;
					lowerFrame = 0;
					parentX = cloudCurrentX;
					parentY = BRANCHES_CLOUD_Y;
					tempBranchX = branchCurrentX[ITEM_UNDER_MOUSE_FIREBALL];
					tempBranchY = branchCurrentY[ITEM_UNDER_MOUSE_FIREBALL];
					if (upperFrame != lowerFrame)
						distance = (double)(currFrameCounter - lowerFrame) / (double)(upperFrame - lowerFrame);
					else
						distance = 0;
					if (distance > 1.0) distance = 1.0;
					playbackCursorX = parentX + distance * (tempBranchX - parentX);
					playbackCursorY = parentY + distance * (tempBranchY - parentY);
				} else
				{
					// special case: there's only cloud
					playbackCursorX = cloudCurrentX;
					playbackCursorY = BRANCHES_CLOUD_Y;
				}
			}
			// move corners cursor to Playback cursor position
			double dx = playbackCursorX - cornersCursorX;
			double dy = playbackCursorY - cornersCursorY;
			distance = sqrt(dx*dx + dy*dy);
			if (distance < CURSOR_MIN_DISTANCE || distance > CURSOR_MAX_DISTANCE)
			{
				// teleport
				cornersCursorX = playbackCursorX;
				cornersCursorY = playbackCursorY;
			} else
			{
				// advance
				double speed = sqrt(distance);
				if (speed < CURSOR_MIN_SPEED)
					speed = CURSOR_MIN_SPEED;
				cornersCursorX += dx * speed / distance;
				cornersCursorY += dy * speed / distance;
			}

			if (lastItemUnderMouse != bookmarks.itemUnderMouse)
			{
				mustRedrawBranchesBitmap = true;
				lastItemUnderMouse = bookmarks.itemUnderMouse;
			}
			if (mustRedrawBranchesBitmap)
				redrawBranchesBitmap();
		}
	}
}

void BRANCHES::save(EMUFILE *os)
{
	// write cloud time
	os->fwrite(cloudTimestamp, TIMESTAMP_LENGTH);
	// write current branch and flag of changes since it
	write32le(currentBranch, os);
	if (changesSinceCurrentBranch)
		write8le((uint8)1, os);
	else
		write8le((uint8)0, os);
	// write current_position time
	os->fwrite(currentPosTimestamp, TIMESTAMP_LENGTH);
	// write all 10 parents
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		write32le(parents[i], os);
	// write cached_timelines
	os->fwrite(&cachedTimelines[0], TOTAL_BOOKMARKS);
	// write cached_first_difference
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		for (int t = 0; t < TOTAL_BOOKMARKS; ++t)
			write32le(cachedFirstDifferences[i][t], os);
}
// returns true if couldn't load
bool BRANCHES::load(EMUFILE *is)
{
	// read cloud time
	if ((int)is->fread(cloudTimestamp, TIMESTAMP_LENGTH) < TIMESTAMP_LENGTH) goto error;
	// read current branch and flag of changes since it
	uint8 tmp;
	if (!read32le(&currentBranch, is)) goto error;
	if (!read8le(&tmp, is)) goto error;
	changesSinceCurrentBranch = (tmp != 0);
	// read current_position time
	if ((int)is->fread(currentPosTimestamp, TIMESTAMP_LENGTH) < TIMESTAMP_LENGTH) goto error;
	// read all 10 parents
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		if (!read32le(&parents[i], is)) goto error;
	// read cached_timelines
	if ((int)is->fread(&cachedTimelines[0], TOTAL_BOOKMARKS) < TOTAL_BOOKMARKS) goto error;
	// read cached_first_difference
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		for (int t = 0; t < TOTAL_BOOKMARKS; ++t)
			if (!read32le(&cachedFirstDifferences[i][t], is)) goto error;
	// all ok
	resetVars();
	return false;
error:
	FCEU_printf("Error loading branches\n");
	return true;
}
// ----------------------------------------------------------
void BRANCHES::redrawBranchesBitmap()
{
	// draw background
	GradientFill(hBitmapDC, vertex, 2, &gRect, 1, GRADIENT_FILL_RECT_H);
	// lines
	int branch, tempBranchX, tempBranchY, parentX, parentY, childID;
	SelectObject(hBitmapDC, normalPen);
	for (int t = children.size() - 1; t >= 0; t--)
	{
		if (t > 0)
		{
			parentX = branchCurrentX[t-1];
			parentY = branchCurrentY[t-1];
		} else
		{
			parentX = cloudCurrentX;
			parentY = BRANCHES_CLOUD_Y;
		}
		for (int i = children[t].size() - 1; i >= 0; i--)
		{
			childID = children[t][i];
			if (childID < TOTAL_BOOKMARKS)
			{
				MoveToEx(hBitmapDC, parentX, parentY, 0);
				LineTo(hBitmapDC, branchCurrentX[childID], branchCurrentY[childID]);
			}
		}
	}
	// lines for current timeline
	if (currentBranch != ITEM_UNDER_MOUSE_CLOUD)
	{
		SelectObject(hBitmapDC, timelinePen);
		if (changesSinceCurrentBranch)
			branch = currentBranch;
		else
			branch = findFullTimelineForBranch(currentBranch);
		while (branch >= 0)
		{
			tempBranchX = branchCurrentX[branch];
			tempBranchY = branchCurrentY[branch];
			MoveToEx(hBitmapDC, tempBranchX, tempBranchY, 0);
			branch = parents[branch];
			if (branch == ITEM_UNDER_MOUSE_CLOUD)
			{
				tempBranchX = cloudCurrentX;
				tempBranchY = BRANCHES_CLOUD_Y;
			} else
			{
	 			tempBranchX = branchCurrentX[branch];
				tempBranchY = branchCurrentY[branch];
			}
			LineTo(hBitmapDC, tempBranchX, tempBranchY);
		}
	}
	if (isSafeToShowBranchesData())
	{
		// lines for item under mouse
		if (bookmarks.itemUnderMouse == ITEM_UNDER_MOUSE_FIREBALL || (bookmarks.itemUnderMouse >= 0 && bookmarks.itemUnderMouse < TOTAL_BOOKMARKS && bookmarks.bookmarksArray[bookmarks.itemUnderMouse].notEmpty))
		{
			SelectObject(hBitmapDC, selectPen);
			if (bookmarks.itemUnderMouse == ITEM_UNDER_MOUSE_FIREBALL)
				branch = currentBranch;
			else
				branch = findFullTimelineForBranch(bookmarks.itemUnderMouse);
			while (branch >= 0)
			{
				tempBranchX = branchCurrentX[branch];
				tempBranchY = branchCurrentY[branch];
				MoveToEx(hBitmapDC, tempBranchX, tempBranchY, 0);
				branch = parents[branch];
				if (branch == ITEM_UNDER_MOUSE_CLOUD)
				{
					tempBranchX = cloudCurrentX;
					tempBranchY = BRANCHES_CLOUD_Y;
				} else
				{
	 				tempBranchX = branchCurrentX[branch];
					tempBranchY = branchCurrentY[branch];
				}
				LineTo(hBitmapDC, tempBranchX, tempBranchY);
			}
		}
	}
	if (changesSinceCurrentBranch)
	{
		if (isSafeToShowBranchesData() && bookmarks.itemUnderMouse == ITEM_UNDER_MOUSE_FIREBALL)
			SelectObject(hBitmapDC, selectPen);
		else
			SelectObject(hBitmapDC, timelinePen);
		if (currentBranch == ITEM_UNDER_MOUSE_CLOUD)
		{
			parentX = cloudCurrentX;
			parentY = BRANCHES_CLOUD_Y;
		} else
		{
			parentX = branchCurrentX[currentBranch];
			parentY = branchCurrentY[currentBranch];
		}
		MoveToEx(hBitmapDC, parentX, parentY, 0);
		tempBranchX = branchCurrentX[ITEM_UNDER_MOUSE_FIREBALL];
		tempBranchY = branchCurrentY[ITEM_UNDER_MOUSE_FIREBALL];
		LineTo(hBitmapDC, tempBranchX, tempBranchY);
	}
	// cloud
	TransparentBlt(hBitmapDC, cloudCurrentX - BRANCHES_CLOUD_HALFWIDTH, BRANCHES_CLOUD_Y - BRANCHES_CLOUD_HALFHEIGHT, BRANCHES_CLOUD_WIDTH, BRANCHES_CLOUD_HEIGHT, hSpritesheetDC, BRANCHES_CLOUD_SPRITESHEET_X, BRANCHES_CLOUD_SPRITESHEET_Y, BRANCHES_CLOUD_WIDTH, BRANCHES_CLOUD_HEIGHT, 0x00FF00);
	// branches rectangles
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
	{
		tempRect.left = branchCurrentX[i] - DIGIT_RECT_HALFWIDTH;
		tempRect.top = branchCurrentY[i] - DIGIT_RECT_HALFHEIGHT;
		tempRect.right = tempRect.left + DIGIT_RECT_WIDTH;
		tempRect.bottom = tempRect.top + DIGIT_RECT_HEIGHT;
		if (!bookmarks.bookmarksArray[i].notEmpty && bookmarks.bookmarksArray[i].floatingPhase > 0)
		{
			tempRect.left += bookmarks.bookmarksArray[i].floatingPhase;
			tempRect.right += bookmarks.bookmarksArray[i].floatingPhase;
		}
		if (bookmarks.bookmarksArray[i].flashPhase)
		{
			// draw colored rect
			HBRUSH color_brush = CreateSolidBrush(bookmark_flash_colors[bookmarks.bookmarksArray[i].flashType][bookmarks.bookmarksArray[i].flashPhase]);
			FrameRect(hBitmapDC, &tempRect, color_brush);
			DeleteObject(color_brush);
		} else
		{
			// draw black rect
			FrameRect(hBitmapDC, &tempRect, normalBrush);
		}
	}
	// digits
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
	{
		tempBranchX = branchCurrentX[i] - DIGIT_BITMAP_HALFWIDTH;
		tempBranchY = branchCurrentY[i] - DIGIT_BITMAP_HALFHEIGHT;
		if (i == currentBranch)
		{
			if (i == bookmarks.itemUnderMouse)
				BitBlt(hBitmapDC, tempBranchX, tempBranchY, DIGIT_BITMAP_WIDTH, DIGIT_BITMAP_HEIGHT, hSpritesheetDC, i * DIGIT_BITMAP_WIDTH + BLUE_DIGITS_SPRITESHEET_DX, MOUSEOVER_DIGITS_SPRITESHEET_DY, SRCCOPY);
			else
				BitBlt(hBitmapDC, tempBranchX, tempBranchY, DIGIT_BITMAP_WIDTH, DIGIT_BITMAP_HEIGHT, hSpritesheetDC, i * DIGIT_BITMAP_WIDTH + BLUE_DIGITS_SPRITESHEET_DX, 0, SRCCOPY);
		} else
		{
			if (!bookmarks.bookmarksArray[i].notEmpty && bookmarks.bookmarksArray[i].floatingPhase > 0)
				tempBranchX += bookmarks.bookmarksArray[i].floatingPhase;
			if (i == bookmarks.itemUnderMouse)
				BitBlt(hBitmapDC, tempBranchX, tempBranchY, DIGIT_BITMAP_WIDTH, DIGIT_BITMAP_HEIGHT, hSpritesheetDC, i * DIGIT_BITMAP_WIDTH, MOUSEOVER_DIGITS_SPRITESHEET_DY, SRCCOPY);
			else
				BitBlt(hBitmapDC, tempBranchX, tempBranchY, DIGIT_BITMAP_WIDTH, DIGIT_BITMAP_HEIGHT, hSpritesheetDC, i * DIGIT_BITMAP_WIDTH, 0, SRCCOPY);
		}
	}
	if (isSafeToShowBranchesData())
	{
		SetBkMode(hBitmapDC, TRANSPARENT);
		// keyframe of item under cursor (except cloud - it doesn't have particular frame)
		if (bookmarks.itemUnderMouse == ITEM_UNDER_MOUSE_FIREBALL || (bookmarks.itemUnderMouse >= 0 && bookmarks.itemUnderMouse < TOTAL_BOOKMARKS && bookmarks.bookmarksArray[bookmarks.itemUnderMouse].notEmpty))
		{
			char framenum_string[DIGITS_IN_FRAMENUM + 1] = {0};
			if (bookmarks.itemUnderMouse < TOTAL_BOOKMARKS)
				U32ToDecStr(framenum_string, bookmarks.bookmarksArray[bookmarks.itemUnderMouse].snapshot.keyFrame, DIGITS_IN_FRAMENUM);
			else
				U32ToDecStr(framenum_string, currFrameCounter, DIGITS_IN_FRAMENUM);
			SetTextColor(hBitmapDC, BRANCHES_TEXT_SHADOW_COLOR);
			TextOut(hBitmapDC, BRANCHES_BITMAP_FRAMENUM_X + 1, BRANCHES_BITMAP_FRAMENUM_Y + 1, (LPCSTR)framenum_string, DIGITS_IN_FRAMENUM);
			SetTextColor(hBitmapDC, BRANCHES_TEXT_COLOR);
			TextOut(hBitmapDC, BRANCHES_BITMAP_FRAMENUM_X, BRANCHES_BITMAP_FRAMENUM_Y, (LPCSTR)framenum_string, DIGITS_IN_FRAMENUM);
		}
		// time of item under cursor
		if (bookmarks.itemUnderMouse > ITEM_UNDER_MOUSE_NONE)
		{
			if (bookmarks.itemUnderMouse == ITEM_UNDER_MOUSE_CLOUD)
			{
				// draw shadow of text
				SetTextColor(hBitmapDC, BRANCHES_TEXT_SHADOW_COLOR);
				TextOut(hBitmapDC, BRANCHES_BITMAP_TIME_X + 1, BRANCHES_BITMAP_TIME_Y + 1, (LPCSTR)cloudTimestamp, TIMESTAMP_LENGTH-1);
				SetTextColor(hBitmapDC, BRANCHES_TEXT_COLOR);
				TextOut(hBitmapDC, BRANCHES_BITMAP_TIME_X, BRANCHES_BITMAP_TIME_Y, (LPCSTR)cloudTimestamp, TIMESTAMP_LENGTH-1);
			} else if (bookmarks.itemUnderMouse == ITEM_UNDER_MOUSE_FIREBALL)
			{
				// fireball - show current_pos_time
				SetTextColor(hBitmapDC, BRANCHES_TEXT_SHADOW_COLOR);
				TextOut(hBitmapDC, BRANCHES_BITMAP_TIME_X + 1, BRANCHES_BITMAP_TIME_Y + 1, (LPCSTR)currentPosTimestamp, TIMESTAMP_LENGTH-1);
				SetTextColor(hBitmapDC, BRANCHES_TEXT_COLOR);
				TextOut(hBitmapDC, BRANCHES_BITMAP_TIME_X, BRANCHES_BITMAP_TIME_Y, (LPCSTR)currentPosTimestamp, TIMESTAMP_LENGTH-1);
			} else if (bookmarks.bookmarksArray[bookmarks.itemUnderMouse].notEmpty)
			{
				SetTextColor(hBitmapDC, BRANCHES_TEXT_SHADOW_COLOR);
				TextOut(hBitmapDC, BRANCHES_BITMAP_TIME_X + 1, BRANCHES_BITMAP_TIME_Y + 1, (LPCSTR)bookmarks.bookmarksArray[bookmarks.itemUnderMouse].snapshot.description, TIMESTAMP_LENGTH-1);
				SetTextColor(hBitmapDC, BRANCHES_TEXT_COLOR);
				TextOut(hBitmapDC, BRANCHES_BITMAP_TIME_X, BRANCHES_BITMAP_TIME_Y, (LPCSTR)bookmarks.bookmarksArray[bookmarks.itemUnderMouse].snapshot.description, TIMESTAMP_LENGTH-1);
			}
		}
	}
	// draw border of canvas
	FrameRect(hBitmapDC, &branchesBitmapRect, borderBrush);
	// finished
	mustRedrawBranchesBitmap = false;
	InvalidateRect(bookmarks.hwndBranchesBitmap, 0, FALSE);
}

// this is called by wndproc on WM_PAINT
void BRANCHES::paintBranchesBitmap(HDC hdc)
{
	int tempBranchX, tempBranchY;
	// "bg"
	BitBlt(hBufferDC, 0, 0, BRANCHES_BITMAP_WIDTH, BRANCHES_BITMAP_HEIGHT, hBitmapDC, 0, 0, SRCCOPY);
	// "sprites"
	// blinking red frame on selected slot
	if (taseditorConfig.oldControlSchemeForBranching && ((currentAnimationFrame + 1) % 6))
	{
		int selected_slot = bookmarks.getSelectedSlot();
		tempRect.left = branchCurrentX[selected_slot] + BRANCHES_SELECTED_SLOT_DX;
		tempRect.left += bookmarks.bookmarksArray[selected_slot].floatingPhase;
		tempRect.top = branchCurrentY[selected_slot] + BRANCHES_SELECTED_SLOT_DY;
		tempRect.right = tempRect.left + BRANCHES_SELECTED_SLOT_WIDTH;
		tempRect.bottom = tempRect.top + BRANCHES_SELECTED_SLOT_HEIGHT;
		FrameRect(hBufferDC, &tempRect, selectedSlotBrush);
	}
	// fireball
	if (fireballSize)
	{
		tempBranchX = branchCurrentX[ITEM_UNDER_MOUSE_FIREBALL] - BRANCHES_FIREBALL_HALFWIDTH;
		tempBranchY = branchCurrentY[ITEM_UNDER_MOUSE_FIREBALL] - BRANCHES_FIREBALL_HALFHEIGHT;
		if (fireballSize >= BRANCHES_FIREBALL_MAX_SIZE)
		{
			TransparentBlt(hBufferDC, tempBranchX, tempBranchY, BRANCHES_FIREBALL_WIDTH, BRANCHES_FIREBALL_HEIGHT, hSpritesheetDC, currentAnimationFrame * BRANCHES_FIREBALL_WIDTH + BRANCHES_FIREBALL_SPRITESHEET_X, BRANCHES_FIREBALL_SPRITESHEET_Y, BRANCHES_FIREBALL_WIDTH, BRANCHES_FIREBALL_HEIGHT, 0x00FF00);
		} else
		{
			TransparentBlt(hBufferDC, tempBranchX, tempBranchY, BRANCHES_FIREBALL_WIDTH, BRANCHES_FIREBALL_HEIGHT, hSpritesheetDC, BRANCHES_FIREBALL_SPRITESHEET_END_X - fireballSize * BRANCHES_FIREBALL_WIDTH, BRANCHES_FIREBALL_SPRITESHEET_Y, BRANCHES_FIREBALL_WIDTH, BRANCHES_FIREBALL_HEIGHT, 0x00FF00);
		}
	}
	// blinking Playback cursor point
	if (currentAnimationFrame % 4)
		TransparentBlt(hBufferDC, playbackCursorX - BRANCHES_MINIARROW_HALFWIDTH, playbackCursorY - BRANCHES_MINIARROW_HALFHEIGHT, BRANCHES_MINIARROW_WIDTH, BRANCHES_MINIARROW_HEIGHT, hSpritesheetDC, BRANCHES_MINIARROW_SPRITESHEET_X, BRANCHES_MINIARROW_SPRITESHEET_Y, BRANCHES_MINIARROW_WIDTH, BRANCHES_MINIARROW_HEIGHT, 0x00FF00);
	// corners cursor
	int current_corners_cursor_shift = BRANCHES_CORNER_BASE_SHIFT + corners_cursor_shift[currentAnimationFrame];
	int corner_x, corner_y;
	// upper left
	corner_x = cornersCursorX - current_corners_cursor_shift - BRANCHES_CORNER_HALFWIDTH;
	corner_y = cornersCursorY - current_corners_cursor_shift - BRANCHES_CORNER_HALFHEIGHT;
	TransparentBlt(hBufferDC, corner_x, corner_y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, hSpritesheetDC, BRANCHES_CORNER1_SPRITESHEET_X, BRANCHES_CORNER1_SPRITESHEET_Y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, 0x00FF00);
	// upper right
	corner_x = cornersCursorX + current_corners_cursor_shift - BRANCHES_CORNER_HALFWIDTH;
	corner_y = cornersCursorY - current_corners_cursor_shift - BRANCHES_CORNER_HALFHEIGHT;
	TransparentBlt(hBufferDC, corner_x, corner_y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, hSpritesheetDC, BRANCHES_CORNER2_SPRITESHEET_X, BRANCHES_CORNER2_SPRITESHEET_Y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, 0x00FF00);
	// lower left
	corner_x = cornersCursorX - current_corners_cursor_shift - BRANCHES_CORNER_HALFWIDTH;
	corner_y = cornersCursorY + current_corners_cursor_shift - BRANCHES_CORNER_HALFHEIGHT;
	TransparentBlt(hBufferDC, corner_x, corner_y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, hSpritesheetDC, BRANCHES_CORNER3_SPRITESHEET_X, BRANCHES_CORNER3_SPRITESHEET_Y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, 0x00FF00);
	// lower right
	corner_x = cornersCursorX + current_corners_cursor_shift - BRANCHES_CORNER_HALFWIDTH;
	corner_y = cornersCursorY + current_corners_cursor_shift - BRANCHES_CORNER_HALFHEIGHT;
	TransparentBlt(hBufferDC, corner_x, corner_y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, hSpritesheetDC, BRANCHES_CORNER4_SPRITESHEET_X, BRANCHES_CORNER4_SPRITESHEET_Y, BRANCHES_CORNER_WIDTH, BRANCHES_CORNER_HEIGHT, 0x00FF00);
	// finish - paste buffer bitmap to screen
	BitBlt(hdc, 0, 0, BRANCHES_BITMAP_WIDTH, BRANCHES_BITMAP_HEIGHT, hBufferDC, 0, 0, SRCCOPY);
}
// ----------------------------------------------------------------------------------------
// getters
int BRANCHES::getParentOf(int child)
{
	return parents[child];
}
int BRANCHES::getCurrentBranch()
{
	return currentBranch;
}
bool BRANCHES::areThereChangesSinceCurrentBranch()
{
	return changesSinceCurrentBranch;
}
// this getter contains formula to decide whether it's safe to show Branches Data now
bool BRANCHES::isSafeToShowBranchesData()
{
	if (bookmarks.editMode == EDIT_MODE_BRANCHES && transitionPhase)
		return false;		// can't show data when Branches Tree is transforming
	return true;
}

void BRANCHES::handleBookmarkSet(int slot)
{
	// new Branch is written into the slot
	invalidateRelationsOfBranchSlot(slot);
	recalculateParents();
	currentBranch = slot;
	changesSinceCurrentBranch = false;
	mustRecalculateBranchesTree = true;
}
void BRANCHES::handleBookmarkDeploy(int slot)
{
	currentBranch = slot;
	changesSinceCurrentBranch = false;
	mustRecalculateBranchesTree = true;
}
void BRANCHES::handleHistoryJump(int newCurrentBranch, bool newChangesSinceCurrentBranch)
{
	recalculateParents();
	currentBranch = newCurrentBranch;
	changesSinceCurrentBranch = newChangesSinceCurrentBranch;
	if (newChangesSinceCurrentBranch)
		setCurrentPosTimestamp();
	mustRecalculateBranchesTree = true;
}

void BRANCHES::invalidateRelationsOfBranchSlot(int slot)
{
	for (int i = TOTAL_BOOKMARKS-1; i >= 0; i--)
	{
		cachedTimelines[i] = ITEM_UNDER_MOUSE_CLOUD;
		cachedFirstDifferences[i][slot] = FIRST_DIFFERENCE_UNKNOWN;
		cachedFirstDifferences[slot][i] = FIRST_DIFFERENCE_UNKNOWN;
		parents[i] = ITEM_UNDER_MOUSE_CLOUD;
	}
}
// returns the frame of first difference between InputLogs of snapshots of two Branches
int BRANCHES::getFirstDifferenceBetween(int firstBranch, int secondBranch)
{
	if (firstBranch == secondBranch)
		return bookmarks.bookmarksArray[firstBranch].snapshot.inputlog.size;

	if (cachedFirstDifferences[firstBranch][secondBranch] == FIRST_DIFFERENCE_UNKNOWN)
	{
		if (bookmarks.bookmarksArray[firstBranch].notEmpty && bookmarks.bookmarksArray[secondBranch].notEmpty)
		{	
			int frame = bookmarks.bookmarksArray[firstBranch].snapshot.inputlog.findFirstChange(bookmarks.bookmarksArray[secondBranch].snapshot.inputlog);
			if (frame < 0)
				frame = bookmarks.bookmarksArray[firstBranch].snapshot.inputlog.size;
			cachedFirstDifferences[firstBranch][secondBranch] = frame;
			cachedFirstDifferences[secondBranch][firstBranch] = frame;
			return frame;
		} else return 0;
	} else
		return cachedFirstDifferences[firstBranch][secondBranch];
}

int BRANCHES::findFullTimelineForBranch(int branchNumber)
{
	if (cachedTimelines[branchNumber] == ITEM_UNDER_MOUSE_CLOUD)
	{
		cachedTimelines[branchNumber] = branchNumber;		// by default
		std::vector<int> candidates;
		int tempKeyFrame, tempParent, maxKeyFrame, maxFirstDifference;
		// 1 - find max_first_difference among Branches that are in the same timeline
		maxFirstDifference = -1;
		int firstDiff;
		for (int i = TOTAL_BOOKMARKS-1; i >= 0; i--)
		{
			if (i != branchNumber && bookmarks.bookmarksArray[i].notEmpty)
			{
				firstDiff = getFirstDifferenceBetween(branchNumber, i);
				if (firstDiff >= bookmarks.bookmarksArray[i].snapshot.keyFrame)
					if (maxFirstDifference < firstDiff)
						maxFirstDifference = firstDiff;
			}
		}
		// 2 - find max_keyframe among those Branches whose first_diff >= max_first_difference
		maxKeyFrame = -1;
		for (int i = TOTAL_BOOKMARKS-1; i >= 0; i--)
		{
			if (bookmarks.bookmarksArray[i].notEmpty)
			{
				if (i != branchNumber && getFirstDifferenceBetween(branchNumber, i) >= maxFirstDifference && getFirstDifferenceBetween(branchNumber, i) >= bookmarks.bookmarksArray[i].snapshot.keyFrame)
				{
					// ensure that this candidate belongs to children/grandchildren of current branch
					tempParent = parents[i];
					while (tempParent != ITEM_UNDER_MOUSE_CLOUD && tempParent != branchNumber)
						tempParent = parents[tempParent];
					if (tempParent == branchNumber)
					{
						candidates.push_back(i);
						tempKeyFrame = bookmarks.bookmarksArray[i].snapshot.keyFrame;
						if (maxKeyFrame < tempKeyFrame)
							maxKeyFrame = tempKeyFrame;
					}
				}
			}
		}
		// 3 - remove those candidates who have keyframe < max_keyframe
		for (int i = candidates.size()-1; i >= 0; i--)
		{
			if (bookmarks.bookmarksArray[candidates[i]].snapshot.keyFrame < maxKeyFrame)
				candidates.erase(candidates.begin() + i);
		}
		// 4 - get first of candidates (if there are many then it will be the Branch with highest id number)
		if (candidates.size())
			cachedTimelines[branchNumber] = candidates[0];
	}
	return cachedTimelines[branchNumber];
}

void BRANCHES::setChangesMadeSinceBranch()
{
	bool oldStateOfChangesSinceCurrentBranch = changesSinceCurrentBranch;
	changesSinceCurrentBranch = true;
	setCurrentPosTimestamp();
	// recalculate branch tree if previous_changes = false
	if (!oldStateOfChangesSinceCurrentBranch)
		mustRecalculateBranchesTree = true;
	else if (bookmarks.itemUnderMouse == ITEM_UNDER_MOUSE_FIREBALL)
		mustRedrawBranchesBitmap = true;	// to redraw fireball's time
}

int BRANCHES::findItemUnderMouse(int mouseX, int mouseY)
{
	int item = ITEM_UNDER_MOUSE_NONE;
	for (int i = 0; i < TOTAL_BOOKMARKS; ++i)
		if (item == ITEM_UNDER_MOUSE_NONE && mouseX >= branchCurrentX[i] - DIGIT_RECT_HALFWIDTH_COLLISION && mouseX < branchCurrentX[i] - DIGIT_RECT_HALFWIDTH_COLLISION + DIGIT_RECT_WIDTH_COLLISION && mouseY >= branchCurrentY[i] - DIGIT_RECT_HALFHEIGHT_COLLISION && mouseY < branchCurrentY[i] - DIGIT_RECT_HALFHEIGHT_COLLISION + DIGIT_RECT_HEIGHT_COLLISION)
			item = i;
	if (item == ITEM_UNDER_MOUSE_NONE && mouseX >= cloudCurrentX - BRANCHES_CLOUD_HALFWIDTH && mouseX < cloudCurrentX - BRANCHES_CLOUD_HALFWIDTH + BRANCHES_CLOUD_WIDTH && mouseY >= BRANCHES_CLOUD_Y - BRANCHES_CLOUD_HALFHEIGHT && mouseY < BRANCHES_CLOUD_Y - BRANCHES_CLOUD_HALFHEIGHT + BRANCHES_CLOUD_HEIGHT)
		item = ITEM_UNDER_MOUSE_CLOUD;
	if (item == ITEM_UNDER_MOUSE_NONE && changesSinceCurrentBranch && mouseX >= branchCurrentX[ITEM_UNDER_MOUSE_FIREBALL] - DIGIT_RECT_HALFWIDTH_COLLISION && mouseX < branchCurrentX[ITEM_UNDER_MOUSE_FIREBALL] - DIGIT_RECT_HALFWIDTH_COLLISION + DIGIT_RECT_WIDTH_COLLISION && mouseY >= branchCurrentY[ITEM_UNDER_MOUSE_FIREBALL] - DIGIT_RECT_HALFHEIGHT_COLLISION && mouseY < branchCurrentY[ITEM_UNDER_MOUSE_FIREBALL] - DIGIT_RECT_HALFHEIGHT_COLLISION + DIGIT_RECT_HEIGHT_COLLISION)
		item = ITEM_UNDER_MOUSE_FIREBALL;
	return item;
}

void BRANCHES::setCurrentPosTimestamp()
{
	time_t raw_time;
	time(&raw_time);
	struct tm * timeinfo = localtime(&raw_time);
	strftime(currentPosTimestamp, TIMESTAMP_LENGTH, "%H:%M:%S", timeinfo);
}

void BRANCHES::recalculateParents()
{
	// find best parent for every Branch
	std::vector<int> candidates;
	int tempKeyFrame, tempParent, maxKeyFrame, maxFirstDifference;
	for (int i1 = TOTAL_BOOKMARKS-1; i1 >= 0; i1--)
	{
		int i = (i1 + 1) % TOTAL_BOOKMARKS;
		if (bookmarks.bookmarksArray[i].notEmpty)
		{
			int keyframe = bookmarks.bookmarksArray[i].snapshot.keyFrame;
			// 1 - find all candidates and max_keyframe among them
			candidates.resize(0);
			maxKeyFrame = -1;
			for (int t1 = TOTAL_BOOKMARKS-1; t1 >= 0; t1--)
			{
				int t = (t1 + 1) % TOTAL_BOOKMARKS;
				tempKeyFrame = bookmarks.bookmarksArray[t].snapshot.keyFrame;
				if (t != i && bookmarks.bookmarksArray[t].notEmpty && tempKeyFrame <= keyframe && getFirstDifferenceBetween(t, i) >= tempKeyFrame)
				{
					// ensure that this candidate doesn't belong to children/grandchildren of this Branch
					tempParent = parents[t];
					while (tempParent != ITEM_UNDER_MOUSE_CLOUD && tempParent != i)
						tempParent = parents[tempParent];
					if (tempParent == ITEM_UNDER_MOUSE_CLOUD)
					{
						// all ok, this is good candidate for being the parent of the Branch
						candidates.push_back(t);
						if (maxKeyFrame < tempKeyFrame)
							maxKeyFrame = tempKeyFrame;
					}
				}
			}
			if (candidates.size())
			{
				// 2 - remove those candidates who have keyframe < max_keyframe
				// and for those who have keyframe == max_keyframe, find max_first_difference
				maxFirstDifference = -1;
				for (int t = candidates.size()-1; t >= 0; t--)
				{
					if (bookmarks.bookmarksArray[candidates[t]].snapshot.keyFrame < maxKeyFrame)
						candidates.erase(candidates.begin() + t);
					else if (maxFirstDifference < getFirstDifferenceBetween(candidates[t], i))
						maxFirstDifference = getFirstDifferenceBetween(candidates[t], i);
				}
				// 3 - remove those candidates who have FirstDifference < max_first_difference
				for (int t = candidates.size()-1; t >= 0; t--)
				{
					if (getFirstDifferenceBetween(candidates[t], i) < maxFirstDifference)
						candidates.erase(candidates.begin() + t);
				}
				// 4 - get first of candidates (if there are many then it will be the Branch with highest id number)
				if (candidates.size())
					parents[i] = candidates[0];
			}
		}
	}
}
void BRANCHES::recalculateBranchesTree()
{
	// save previous values
	for (int i = TOTAL_BOOKMARKS; i >= 0; i--)
	{
		branchPreviousX[i] = (branchX[i] * (BRANCHES_TRANSITION_MAX - transitionPhase) + branchPreviousX[i] * transitionPhase) / BRANCHES_TRANSITION_MAX;
		branchPreviousY[i] = (branchY[i] * (BRANCHES_TRANSITION_MAX - transitionPhase) + branchPreviousY[i] * transitionPhase) / BRANCHES_TRANSITION_MAX;
	}
	cloudPreviousX = (cloudX * (BRANCHES_TRANSITION_MAX - transitionPhase) + cloudPreviousX * transitionPhase) / BRANCHES_TRANSITION_MAX;
	transitionPhase = BRANCHES_TRANSITION_MAX;

	// 0. Prepare arrays
	gridX.resize(0);
	gridY.resize(0);
	children.resize(0);
	gridHeight.resize(0);
	gridX.resize(TOTAL_BOOKMARKS+1);
	gridY.resize(TOTAL_BOOKMARKS+1);
	children.resize(TOTAL_BOOKMARKS+2);		// 0th item is for cloud's children
	gridHeight.resize(TOTAL_BOOKMARKS+1);
	for (int i = TOTAL_BOOKMARKS; i >= 0; i--)
		gridHeight[i] = 1;

	// 1. Define GridX of branches (distribute to levels) and GridHeight of branches
	int current_grid_x = 0;
	std::vector<std::vector<int>> BranchesLevels;

	std::vector<uint8> UndistributedBranches;
	UndistributedBranches.resize(TOTAL_BOOKMARKS);	// 1, 2, 3, 4, 5, 6, 7, 8, 9, 0
	for (int i = UndistributedBranches.size()-1; i >= 0; i--)
		UndistributedBranches[i] = (i + 1) % TOTAL_BOOKMARKS;
	// remove all empty branches
	for (int i = UndistributedBranches.size()-1; i >= 0; i--)
	{
		if (!bookmarks.bookmarksArray[UndistributedBranches[i]].notEmpty)
			UndistributedBranches.erase(UndistributedBranches.begin() + i);
	}
	// highest level: cloud (id = -1)
	BranchesLevels.resize(current_grid_x+1);
	BranchesLevels[current_grid_x].resize(1);
	BranchesLevels[current_grid_x][0] = ITEM_UNDER_MOUSE_CLOUD;
	// go lower until all branches are arranged to levels
	int current_parent;
	while(UndistributedBranches.size())
	{
		current_grid_x++;
		BranchesLevels.resize(current_grid_x+1);
		BranchesLevels[current_grid_x].resize(0);
		for (int t = BranchesLevels[current_grid_x-1].size()-1; t >= 0; t--)
		{
			current_parent = BranchesLevels[current_grid_x-1][t];
			for (int i = UndistributedBranches.size()-1; i >= 0; i--)
			{
				if (parents[UndistributedBranches[i]] == current_parent)
				{
					// assign this branch to current level
					gridX[UndistributedBranches[i]] = current_grid_x;
					BranchesLevels[current_grid_x].push_back(UndistributedBranches[i]);
					// also add it to parent's Children array
					children[current_parent+1].push_back(UndistributedBranches[i]);
					UndistributedBranches.erase(UndistributedBranches.begin() + i);
				}
			}
			if (current_parent >= 0)
			{
				gridHeight[current_parent] = children[current_parent+1].size();
				if (children[current_parent+1].size() > 1)
					recursiveAddHeight(parents[current_parent], gridHeight[current_parent] - 1);
				else
					gridHeight[current_parent] = 1;		// its own height
			}
		}
	}
	if (changesSinceCurrentBranch)
	{
		// also define "current_pos" GridX
		if (currentBranch >= 0)
		{
			if (children[currentBranch+1].size() < MAX_NUM_CHILDREN_ON_CANVAS_HEIGHT)
			{
				// "current_pos" becomes a child of current branch
				gridX[ITEM_UNDER_MOUSE_FIREBALL] = gridX[currentBranch] + 1;
				if ((int)BranchesLevels.size() <= gridX[ITEM_UNDER_MOUSE_FIREBALL])
					BranchesLevels.resize(gridX[ITEM_UNDER_MOUSE_FIREBALL] + 1);
				BranchesLevels[gridX[ITEM_UNDER_MOUSE_FIREBALL]].push_back(ITEM_UNDER_MOUSE_FIREBALL);
				children[currentBranch + 1].push_back(ITEM_UNDER_MOUSE_FIREBALL);
				if (children[currentBranch+1].size() > 1)
					recursiveAddHeight(currentBranch, 1);
			} else
			{
				// special case 0: if there's too many children on one level (more than canvas can show)
				// then "current_pos" becomes special branch above current branch
				gridX[ITEM_UNDER_MOUSE_FIREBALL] = gridX[currentBranch];
				gridY[ITEM_UNDER_MOUSE_FIREBALL] = gridY[currentBranch] - 7;
			}
		} else
		{
			// special case 1: fireball is the one and only child of cloud
			gridX[ITEM_UNDER_MOUSE_FIREBALL] = 1;
			gridY[ITEM_UNDER_MOUSE_FIREBALL] = 0;
			if ((int)BranchesLevels.size() <= gridX[ITEM_UNDER_MOUSE_FIREBALL])
				BranchesLevels.resize(gridX[ITEM_UNDER_MOUSE_FIREBALL] + 1);
			BranchesLevels[gridX[ITEM_UNDER_MOUSE_FIREBALL]].push_back(ITEM_UNDER_MOUSE_FIREBALL);
		}
	}
	// define grid_width
	int grid_width, cloud_prefix = 0;
	if (BranchesLevels.size()-1 > 0)
	{
		grid_width = BRANCHES_CANVAS_WIDTH / (BranchesLevels.size()-1);
		if (grid_width < BRANCHES_GRID_MIN_WIDTH)
			grid_width = BRANCHES_GRID_MIN_WIDTH;
		else if (grid_width > BRANCHES_GRID_MAX_WIDTH)
			grid_width = BRANCHES_GRID_MAX_WIDTH;
	} else grid_width = BRANCHES_GRID_MAX_WIDTH;
	if (grid_width < MIN_CLOUD_LINE_LENGTH)
		cloud_prefix = MIN_CLOUD_LINE_LENGTH - grid_width;

	// 2. Define GridY of branches
	recursiveSetYPos(ITEM_UNDER_MOUSE_CLOUD, 0);
	// define grid_halfheight
	int grid_halfheight;
	int totalHeight = 0;
	for (int i = children[0].size()-1; i >= 0; i--)
		totalHeight += gridHeight[children[0][i]];
	if (totalHeight)
	{
		grid_halfheight = BRANCHES_CANVAS_HEIGHT / (2 * totalHeight);
		if (grid_halfheight < BRANCHES_GRID_MIN_HALFHEIGHT)
			grid_halfheight = BRANCHES_GRID_MIN_HALFHEIGHT;
		else if (grid_halfheight > BRANCHES_GRID_MAX_HALFHEIGHT)
			grid_halfheight = BRANCHES_GRID_MAX_HALFHEIGHT;
	} else grid_halfheight = BRANCHES_GRID_MAX_HALFHEIGHT;
	// special case 2: if chain of branches is too long, the last item (fireball) goes up
	if (changesSinceCurrentBranch)
	{
		if (gridX[ITEM_UNDER_MOUSE_FIREBALL] > MAX_CHAIN_LEN)
		{
			gridX[ITEM_UNDER_MOUSE_FIREBALL] = MAX_CHAIN_LEN;
			gridY[ITEM_UNDER_MOUSE_FIREBALL] -= 2;
		}
	}
	// special case 3: if some branch crosses upper or lower border of canvas
	int parent;
	for (int t = TOTAL_BOOKMARKS; t >= 0; t--)
	{
		if (gridY[t] > MAX_GRID_Y_POS)
		{
			if (t < TOTAL_BOOKMARKS)
				parent = parents[t];
			else
				parent = currentBranch;
			int pos = MAX_GRID_Y_POS;
			for (int i = 0; i < (int)children[parent+1].size(); ++i)
			{
				gridY[children[parent+1][i]] = pos;
				if (children[parent+1][i] == currentBranch)
					gridY[ITEM_UNDER_MOUSE_FIREBALL] = pos;
				pos -= 2;
			}
		} else if (gridY[t] < -MAX_GRID_Y_POS)
		{
			if (t < TOTAL_BOOKMARKS)
				parent = parents[t];
			else
				parent = currentBranch;
			int pos = -MAX_GRID_Y_POS;
			for (int i = children[parent+1].size()-1; i >= 0; i--)
			{
				gridY[children[parent+1][i]] = pos;
				if (children[parent+1][i] == currentBranch)
					gridY[ITEM_UNDER_MOUSE_FIREBALL] = pos;
				pos += 2;
			}
		}
	}
	// special case 4: if cloud has all 10 children, then one child will be out of canvas
	if (children[0].size() == TOTAL_BOOKMARKS)
	{
		// find this child and move it to be visible
		for (int t = TOTAL_BOOKMARKS - 1; t >= 0; t--)
		{
			if (gridY[t] > MAX_GRID_Y_POS)
			{
				gridY[t] = MAX_GRID_Y_POS;
				gridX[t] -= 2;
				// also move fireball to position near this branch
				if (changesSinceCurrentBranch && currentBranch == t)
				{
					gridY[ITEM_UNDER_MOUSE_FIREBALL] = gridY[t];
					gridX[ITEM_UNDER_MOUSE_FIREBALL] = gridX[t] + 1;
				}
				break;
			} else if (gridY[t] < -MAX_GRID_Y_POS)
			{
				gridY[t] = -MAX_GRID_Y_POS;
				gridX[t] -= 2;
				// also move fireball to position near this branch
				if (changesSinceCurrentBranch && currentBranch == t)
				{
					gridY[ITEM_UNDER_MOUSE_FIREBALL] = gridY[t];
					gridX[ITEM_UNDER_MOUSE_FIREBALL] = gridX[t] + 1;
				}
				break;
			}
		}
	}

	// 3. Set pixel positions of branches
	int max_x = 0;
	for (int i = TOTAL_BOOKMARKS-1; i >= 0; i--)
	{
		if (bookmarks.bookmarksArray[i].notEmpty)
		{
			branchX[i] = cloud_prefix + gridX[i] * grid_width;
			branchY[i] = BRANCHES_CLOUD_Y + gridY[i] * grid_halfheight;
		} else
		{
			branchX[i] = EMPTY_BRANCHES_X_BASE;
			branchY[i] = EMPTY_BRANCHES_Y_BASE + EMPTY_BRANCHES_Y_FACTOR * ((i + TOTAL_BOOKMARKS - 1) % TOTAL_BOOKMARKS);
		}
		if (max_x < branchX[i]) max_x = branchX[i];
	}
	if (changesSinceCurrentBranch)
	{
		// also set pixel position of "current_pos"
		branchX[ITEM_UNDER_MOUSE_FIREBALL] = cloud_prefix + gridX[ITEM_UNDER_MOUSE_FIREBALL] * grid_width;
		branchY[ITEM_UNDER_MOUSE_FIREBALL] = BRANCHES_CLOUD_Y + gridY[ITEM_UNDER_MOUSE_FIREBALL] * grid_halfheight;
	} else if (currentBranch >= 0)
	{
		branchX[ITEM_UNDER_MOUSE_FIREBALL] = cloud_prefix + gridX[currentBranch] * grid_width;
		branchY[ITEM_UNDER_MOUSE_FIREBALL] = BRANCHES_CLOUD_Y + gridY[currentBranch] * grid_halfheight;
	} else
	{
		branchX[ITEM_UNDER_MOUSE_FIREBALL] = 0;
		branchY[ITEM_UNDER_MOUSE_FIREBALL] = BRANCHES_CLOUD_Y;
	}
	if (max_x < branchX[ITEM_UNDER_MOUSE_FIREBALL])
		max_x = branchX[ITEM_UNDER_MOUSE_FIREBALL];

	// align whole tree horizontally
	cloudX = (BRANCHES_BITMAP_WIDTH + BASE_HORIZONTAL_SHIFT - max_x) / 2;
	if (cloudX < MIN_CLOUD_X)
		cloudX = MIN_CLOUD_X;
	for (int i = TOTAL_BOOKMARKS-1; i >= 0; i--)
		if (bookmarks.bookmarksArray[i].notEmpty)
			branchX[i] += cloudX;
	branchX[ITEM_UNDER_MOUSE_FIREBALL] += cloudX;

	// finished recalculating
	mustRecalculateBranchesTree = false;
	mustRedrawBranchesBitmap = true;
}
void BRANCHES::recursiveAddHeight(int branchNumber, int amount)
{
	if (branchNumber >= 0)
	{
		gridHeight[branchNumber] += amount;
		if (parents[branchNumber] >= 0)
			recursiveAddHeight(parents[branchNumber], amount);
	}
}
void BRANCHES::recursiveSetYPos(int parent, int parentY)
{
	if (children[parent+1].size())
	{
		// find total height of children
		int totalHeight = 0;
		for (int i = children[parent+1].size()-1; i >= 0; i--)
			totalHeight += gridHeight[children[parent+1][i]];
		// set Y of children and subchildren
		for (int i = children[parent+1].size()-1; i >= 0; i--)
		{
			int child_id = children[parent+1][i];
			gridY[child_id] = parentY + gridHeight[child_id] - totalHeight;
			recursiveSetYPos(child_id, gridY[child_id]);
			parentY += 2 * gridHeight[child_id];
		}
	}
}

// ----------------------------------------------------------------------------------------
LRESULT APIENTRY BranchesBitmapWndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	extern BRANCHES branches;
	switch(msg)
	{
		case WM_SETCURSOR:
		{
			taseditorWindow.mustUpdateMouseCursor = true;
			return true;
		}
		case WM_MOUSEMOVE:
		{
			if (!bookmarks.mouseOverBranchesBitmap)
			{
				bookmarks.mouseOverBranchesBitmap = true;
				bookmarks.tme.hwndTrack = hWnd;
				TrackMouseEvent(&bookmarks.tme);
			}
			bookmarks.handleMouseMove(GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam));
			break;
		}
		case WM_MOUSELEAVE:
		{
			bookmarks.mouseOverBranchesBitmap = false;
			bookmarks.handleMouseMove(-1, -1);
			break;
		}
		case WM_PAINT:
		{
			PAINTSTRUCT ps;
			branches.paintBranchesBitmap(BeginPaint(hWnd, &ps));
			EndPaint(hWnd, &ps);
			return 0;
		}
		case WM_LBUTTONDOWN:
		{
			// single click on Branches Tree = send Playback to the Bookmark
			int branchUnderMouse = bookmarks.itemUnderMouse;
			if (branchUnderMouse == ITEM_UNDER_MOUSE_CLOUD)
			{
				playback.jump(0);
			} else if (branchUnderMouse >= 0 && branchUnderMouse < TOTAL_BOOKMARKS && bookmarks.bookmarksArray[branchUnderMouse].notEmpty)
			{
				bookmarks.command(COMMAND_JUMP, branchUnderMouse);
			} else if (branchUnderMouse == ITEM_UNDER_MOUSE_FIREBALL)
			{
				playback.jump(currMovieData.getNumRecords() - 1);
			}
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		}
		case WM_LBUTTONDBLCLK:
		{
			// double click on Branches Tree = deploy the Branch
			int branchUnderMouse = bookmarks.itemUnderMouse;
			if (branchUnderMouse == ITEM_UNDER_MOUSE_CLOUD)
			{
				playback.jump(0);
			} else if (branchUnderMouse >= 0 && branchUnderMouse < TOTAL_BOOKMARKS && bookmarks.bookmarksArray[branchUnderMouse].notEmpty)
			{
				bookmarks.command(COMMAND_DEPLOY, branchUnderMouse);
			} else if (branchUnderMouse == ITEM_UNDER_MOUSE_FIREBALL)
			{
				playback.jump(currMovieData.getNumRecords() - 1);
			}
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			return 0;
		}
		case WM_RBUTTONDOWN:
		case WM_RBUTTONDBLCLK:
		{
			if (GetFocus() != hWnd)
				SetFocus(hWnd);
			branches.branchRightclicked = branches.findItemUnderMouse(GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam));
			if (branches.branchRightclicked >= 0 && branches.branchRightclicked < TOTAL_BOOKMARKS)
				SetCapture(hWnd);
			return 0;
		}
		case WM_RBUTTONUP:
		{
			if (branches.branchRightclicked >= 0 && branches.branchRightclicked < TOTAL_BOOKMARKS
				&& branches.branchRightclicked == branches.findItemUnderMouse(GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)))
				bookmarks.command(COMMAND_SET, branches.branchRightclicked);
			ReleaseCapture();
			branches.branchRightclicked = ITEM_UNDER_MOUSE_NONE;
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
			branches.branchRightclicked = ITEM_UNDER_MOUSE_NONE;	// ensure that accidental rightclick on BookmarksList won't set Bookmarks when user does rightbutton + wheel
			return SendMessage(pianoRoll.hwndList, msg, wParam, lParam);
		}
	}
	return CallWindowProc(hwndBranchesBitmap_oldWndProc, hWnd, msg, wParam, lParam);
}


