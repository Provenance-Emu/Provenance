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

#include "common.h"
#include "ppuview.h"
#include "../../debug.h"
#include "../../palette.h"
#include "../../fceu.h"
#include "../../cart.h"

HWND hPPUView;

extern uint8 *VPage[8];
extern uint8 PALRAM[0x20];

int PPUViewPosX, PPUViewPosY;
bool PPUView_maskUnusedGraphics = true;
bool PPUView_invertTheMask = false;
int PPUView_sprite16Mode = 0;

uint8 palcache[32] = { 0xFF }; //palette cache
uint8 chrcache0[0x1000], chrcache1[0x1000], logcache0[0x1000], logcache1[0x1000]; //cache CHR, fixes a refresh problem when right-clicking
uint8 *pattern0, *pattern1; //pattern table bitmap arrays
uint8 *ppuv_palette;
static int pindex0 = 0, pindex1 = 0;
int PPUViewScanline = 0, PPUViewer = 0;
int PPUViewSkip;
int PPUViewRefresh = 15;
int mouse_x, mouse_y;

#define PATTERNWIDTH        128
#define PATTERNHEIGHT        128
#define PATTERNBITWIDTH        PATTERNWIDTH*3
#define PATTERNDESTX_BASE 7
#define PATTERNDESTY_BASE 18
#define ZOOM                        2

#define PALETTEWIDTH        32*4*4
#define PALETTEHEIGHT        32*2
#define PALETTEBITWIDTH        PALETTEWIDTH*3
#define PALETTEDESTX_BASE 7
#define PALETTEDESTY_BASE 18

#define TBM_SETPOS            (WM_USER+5)
#define TBM_SETRANGE        (WM_USER+6)
#define TBM_GETPOS            (WM_USER)

int patternDestX = PATTERNDESTX_BASE;
int patternDestY = PATTERNDESTY_BASE;
int paletteDestX = PALETTEDESTX_BASE;
int paletteDestY = PALETTEDESTY_BASE;

BITMAPINFO bmInfo;
HDC pDC,TmpDC0,TmpDC1;
HBITMAP TmpBmp0,TmpBmp1;
HGDIOBJ TmpObj0,TmpObj1;

BITMAPINFO bmInfo2;
HDC TmpDC2,TmpDC3;
HBITMAP TmpBmp2,TmpBmp3;
HGDIOBJ TmpObj2,TmpObj3;


void PPUViewDoBlit()
{
    if (!hPPUView)
		return;
    if (PPUViewSkip < PPUViewRefresh)
	{
        PPUViewSkip++;
        return;
    }
    PPUViewSkip = 0;

    StretchBlt(pDC, patternDestX, patternDestY, PATTERNWIDTH * ZOOM, PATTERNHEIGHT * ZOOM, TmpDC0, 0, PATTERNHEIGHT - 1, PATTERNWIDTH, -PATTERNHEIGHT, SRCCOPY);
    StretchBlt(pDC, patternDestX + (PATTERNWIDTH * ZOOM) + 1, patternDestY, PATTERNWIDTH * ZOOM, PATTERNHEIGHT * ZOOM, TmpDC1, 0, PATTERNHEIGHT - 1, PATTERNWIDTH, -PATTERNHEIGHT, SRCCOPY);
    StretchBlt(pDC, paletteDestX, paletteDestY, PALETTEWIDTH, PALETTEHEIGHT, TmpDC2, 0, PALETTEHEIGHT - 1, PALETTEWIDTH, -PALETTEHEIGHT, SRCCOPY);
}

//---------CDLogger VROM
extern unsigned char *cdloggervdata;
extern unsigned int cdloggerVideoDataSize;

void DrawPatternTable(uint8 *bitmap, uint8 *table, uint8 *log, uint8 pal)
{
    int i,j,k,x,y,index=0;
    int p=0,tmp;
    uint8 chr0,chr1,logs,shift;
    uint8 *pbitmap = bitmap;

    pal <<= 2;
    for (i = 0; i < (16 >> PPUView_sprite16Mode); i++)		//Columns
	{
        for (j = 0; j < 16; j++)	//Rows
		{
            //-----------------------------------------------
			for (k = 0; k < (PPUView_sprite16Mode + 1); k++) {
				for (y = 0; y < 8; y++)
				{
			        chr0 = table[index];
					chr1 = table[index + 8];
					logs = log[index] & log[index + 8];
	                tmp = 7;
					shift=(PPUView_maskUnusedGraphics && debug_loggingCD && (((logs & 3) != 0) == PPUView_invertTheMask))?3:0;
					for (x = 0; x < 8; x++)
					{
						p  =  (chr0 >> tmp) & 1;
						p |= ((chr1 >> tmp) & 1) << 1;
						p = palcache[p | pal];
						tmp--;
						*(uint8*)(pbitmap++) = palo[p].b >> shift;
						*(uint8*)(pbitmap++) = palo[p].g >> shift;
						*(uint8*)(pbitmap++) = palo[p].r >> shift;
					}
					index++;
					pbitmap += (PATTERNBITWIDTH-24);
				}
	            index+=8;
			}
			pbitmap -= ((PATTERNBITWIDTH<<(3+PPUView_sprite16Mode))-24);
			//------------------------------------------------
        }
		pbitmap += (PATTERNBITWIDTH*((8<<PPUView_sprite16Mode)-1));
    }
}

void FCEUD_UpdatePPUView(int scanline, int refreshchr)
{
	if(!PPUViewer) return;
	if(scanline != -1 && scanline != PPUViewScanline) return;

    int x,y,i;
    uint8 *pbitmap = ppuv_palette;

    if(!hPPUView) return;
    if(PPUViewSkip < PPUViewRefresh) return;

    if(refreshchr)
	{
        for (i = 0, x=0x1000; i < 0x1000; i++, x++)
		{
            chrcache0[i] = VPage[i>>10][i];
            chrcache1[i] = VPage[x>>10][x];
			if (debug_loggingCD) {
				if (cdloggerVideoDataSize)
				{
					int addr;
					addr = &VPage[i >> 10][i] - CHRptr[0];
					if ((addr >= 0) && (addr < (int)cdloggerVideoDataSize))
						logcache0[i] = cdloggervdata[addr];
					addr = &VPage[x >> 10][x] - CHRptr[0];
					if ((addr >= 0) && (addr < (int)cdloggerVideoDataSize))
						logcache1[i] = cdloggervdata[addr];
				} else {
					logcache0[i] = cdloggervdata[i];
					logcache1[i] = cdloggervdata[x];
				}
			}
        }
    }

    // update palette only if required
    if (memcmp(palcache, PALRAM, 32) != 0)
	{
		// bbit note: let para know that this if is useless and
        // will not work because of the lines below that change
		// palcache which will make it not equal next time

		// cache palette content
        memcpy(palcache,PALRAM,32);
        palcache[0x10] = palcache[0x00];
        palcache[0x14] = palcache[0x00];
        palcache[0x18] = palcache[0x00];
        palcache[0x1C] = palcache[0x00];

		//draw palettes
		for (y = 0; y < PALETTEHEIGHT; y++)
		{
			for (x = 0; x < PALETTEWIDTH; x++)
			{
				i = (((y>>5)<<4)+(x>>5));
				*(uint8*)(pbitmap++) = palo[palcache[i]].b;
				*(uint8*)(pbitmap++) = palo[palcache[i]].g;
				*(uint8*)(pbitmap++) = palo[palcache[i]].r;
			}
		}

		//draw line seperators on palette
		pbitmap = (ppuv_palette+PALETTEBITWIDTH*31);
		for (x = 0; x < PALETTEWIDTH*2; x++)
		{
				*(uint8*)(pbitmap++) = 0;
				*(uint8*)(pbitmap++) = 0;
				*(uint8*)(pbitmap++) = 0;
		}
		pbitmap = (ppuv_palette-3);
		for (y = 0; y < 64*3; y++)
		{
			if (!(y%3)) pbitmap += (32*4*3);
			for (x = 0; x < 6; x++)
			{
				*(uint8*)(pbitmap++) = 0;
			}
			pbitmap += ((32*4*3)-6);
		}
		memcpy(palcache,PALRAM,32);        //palcache which will make it not equal next time
	}

    DrawPatternTable(pattern0,chrcache0,logcache0,pindex0);
    DrawPatternTable(pattern1,chrcache1,logcache1,pindex1);

	//PPUViewDoBlit();
}

void KillPPUView()
{
        //GDI cleanup
        DeleteObject(TmpBmp0);
        SelectObject(TmpDC0,TmpObj0);
        DeleteDC(TmpDC0);
        DeleteObject(TmpBmp1);
        SelectObject(TmpDC1,TmpObj1);
        DeleteDC(TmpDC1);
        DeleteObject(TmpBmp2);
        SelectObject(TmpDC2,TmpObj2);
        DeleteDC(TmpDC2);
        ReleaseDC(hPPUView,pDC);

        DestroyWindow(hPPUView);
        hPPUView=NULL;
        PPUViewer=0;
        PPUViewSkip=0;
}

BOOL CALLBACK PPUViewCallB(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    RECT wrect;
    char str[20];

    switch(uMsg)
	{
        case WM_INITDIALOG:
		{
			if (PPUViewPosX==-32000) PPUViewPosX=0; //Just in case
			if (PPUViewPosY==-32000) PPUViewPosY=0;
            SetWindowPos(hwndDlg,0,PPUViewPosX,PPUViewPosY,0,0,SWP_NOSIZE|SWP_NOZORDER|SWP_NOOWNERZORDER);

			// calculate bitmaps positions relative to their groupboxes
			RECT rect;
			POINT pt;
			GetWindowRect(GetDlgItem(hwndDlg, GRP_PPUVIEW_TABLES), &rect);
			pt.x = rect.left;
			pt.y = rect.top;
			ScreenToClient(hwndDlg, &pt);
			patternDestX = pt.x + PATTERNDESTX_BASE;
			patternDestY = pt.y + PATTERNDESTY_BASE;
			GetWindowRect(GetDlgItem(hwndDlg, LBL_PPUVIEW_PALETTES), &rect);
			pt.x = rect.left;
			pt.y = rect.top;
			ScreenToClient(hwndDlg, &pt);
			paletteDestX = pt.x + PALETTEDESTX_BASE;
			paletteDestY = pt.y + PALETTEDESTY_BASE;

            //prepare the bitmap attributes
            //pattern tables
            memset(&bmInfo.bmiHeader,0,sizeof(BITMAPINFOHEADER));
            bmInfo.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
            bmInfo.bmiHeader.biWidth = PATTERNWIDTH;
            bmInfo.bmiHeader.biHeight = PATTERNHEIGHT;
            bmInfo.bmiHeader.biPlanes = 1;
            bmInfo.bmiHeader.biBitCount = 24;

            //palettes
            memset(&bmInfo2.bmiHeader,0,sizeof(BITMAPINFOHEADER));
            bmInfo2.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
            bmInfo2.bmiHeader.biWidth = PALETTEWIDTH;
            bmInfo2.bmiHeader.biHeight = PALETTEHEIGHT;
            bmInfo2.bmiHeader.biPlanes = 1;
            bmInfo2.bmiHeader.biBitCount = 24;

            //create memory dcs
            pDC = GetDC(hwndDlg); // GetDC(GetDlgItem(hwndDlg,GRP_PPUVIEW_TABLES));
            TmpDC0 = CreateCompatibleDC(pDC); //pattern table 0
            TmpDC1 = CreateCompatibleDC(pDC); //pattern table 1
            TmpDC2 = CreateCompatibleDC(pDC); //palettes

            //create bitmaps and select them into the memory dc's
            TmpBmp0 = CreateDIBSection(pDC,&bmInfo,DIB_RGB_COLORS,(void**)&pattern0,0,0);
            TmpObj0 = SelectObject(TmpDC0,TmpBmp0);
            TmpBmp1 = CreateDIBSection(pDC,&bmInfo,DIB_RGB_COLORS,(void**)&pattern1,0,0);
            TmpObj1 = SelectObject(TmpDC1,TmpBmp1);
            TmpBmp2 = CreateDIBSection(pDC,&bmInfo2,DIB_RGB_COLORS,(void**)&ppuv_palette,0,0);
            TmpObj2 = SelectObject(TmpDC2,TmpBmp2);

            //Refresh Trackbar
            SendDlgItemMessage(hwndDlg,CTL_PPUVIEW_TRACKBAR,TBM_SETRANGE,0,(LPARAM)MAKELONG(0,25));
            SendDlgItemMessage(hwndDlg,CTL_PPUVIEW_TRACKBAR,TBM_SETPOS,1,PPUViewRefresh);

			CheckDlgButton(hwndDlg, IDC_MASK_UNUSED_GRAPHICS, PPUView_maskUnusedGraphics ? BST_CHECKED : BST_UNCHECKED);
			CheckDlgButton(hwndDlg, IDC_INVERT_THE_MASK, PPUView_invertTheMask ? BST_CHECKED : BST_UNCHECKED);

			CheckDlgButton(hwndDlg, IDC_SPRITE16_MODE, PPUView_sprite16Mode ? BST_CHECKED : BST_UNCHECKED);

			EnableWindow(GetDlgItem(hwndDlg, IDC_INVERT_THE_MASK), PPUView_maskUnusedGraphics ?  true : false);

            //Set Text Limit
            SendDlgItemMessage(hwndDlg,IDC_PPUVIEW_SCANLINE,EM_SETLIMITTEXT,3,0);

            //force redraw the first time the PPU Viewer is opened
            PPUViewSkip=100;

            //clear cache
            memset(palcache,0,32);
            memset(chrcache0,0,0x1000);
            memset(chrcache1,0,0x1000);
            memset(logcache0,0,0x1000);
            memset(logcache1,0,0x1000);

            PPUViewer=1;
            break;
		}
        case WM_PAINT:
                PPUViewDoBlit();
                break;
        case WM_CLOSE:
        case WM_QUIT:
                KillPPUView();
                break;
        case WM_MOVING:
                break;
        case WM_MOVE:
				if (!IsIconic(hwndDlg)) {
                GetWindowRect(hwndDlg,&wrect);
                PPUViewPosX = wrect.left;
                PPUViewPosY = wrect.top;

				#ifdef WIN32
				WindowBoundsCheckNoResize(PPUViewPosX,PPUViewPosY,wrect.right);
				#endif
				}
                break;
        case WM_LBUTTONDBLCLK:
        case WM_LBUTTONDOWN:
		{
			// redraw now
			PPUViewSkip = PPUViewRefresh;
            FCEUD_UpdatePPUView(-1, 0);
            PPUViewDoBlit();
            break;
		}
        case WM_RBUTTONDBLCLK:
        case WM_RBUTTONDOWN:
		{
            mouse_x = GET_X_LPARAM(lParam);
            mouse_y = GET_Y_LPARAM(lParam);
            if(((mouse_x >= patternDestX) && (mouse_x < (patternDestX + (PATTERNWIDTH * ZOOM)))) && (mouse_y >= patternDestY) && (mouse_y < (patternDestY + (PATTERNHEIGHT * ZOOM))))
			{
                if (pindex0 == 7)
					pindex0 = 0;
                else
					pindex0++;
            } else if(((mouse_x >= patternDestX + (PATTERNWIDTH * ZOOM) + 1) && (mouse_x < (patternDestX + (PATTERNWIDTH * ZOOM) * 2 + 1))) && (mouse_y >= patternDestY) && (mouse_y < (patternDestY + (PATTERNHEIGHT * ZOOM))))
			{
                if (pindex1 == 7)
					pindex1 = 0;
                else
					pindex1++;
            }
			// redraw now
			PPUViewSkip = PPUViewRefresh;
            FCEUD_UpdatePPUView(-1, 0);
            PPUViewDoBlit();
            break;
		}
        case WM_MOUSEMOVE:
                mouse_x = GET_X_LPARAM(lParam);
                mouse_y = GET_Y_LPARAM(lParam);
                if (((mouse_x >= patternDestX) && (mouse_x < (patternDestX + (PATTERNWIDTH * ZOOM)))) && (mouse_y >= patternDestY) && (mouse_y < (patternDestY + (PATTERNHEIGHT * ZOOM))))
				{
					int A = (mouse_x - patternDestX) / (8 * ZOOM);
					int B = (mouse_y - patternDestY) / (8 * ZOOM);
                    if(PPUView_sprite16Mode) {
						A *= 2;
						mouse_x = (A & 0xE) + (B & 1);
						mouse_y = (B & 0xE) + ((A >> 4) & 1);
					} else {
						mouse_x = A;
						mouse_y = B;
					}
                    sprintf(str,"Tile: $%X%X",mouse_y,mouse_x);
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE1,str);
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE2,"Tile:");
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_PALETTES,"Palettes");
                } else if (((mouse_x >= patternDestX + (PATTERNWIDTH * ZOOM) + 1) && (mouse_x < (patternDestX + (PATTERNWIDTH * ZOOM) * 2 + 1))) && (mouse_y >= patternDestY) && (mouse_y < (patternDestY + (PATTERNHEIGHT * ZOOM))))
				{
					int A = (mouse_x - (patternDestX + (PATTERNWIDTH * ZOOM) + 1)) / (8 * ZOOM);
					int B = (mouse_y - patternDestY) / (8 * ZOOM);
                    if(PPUView_sprite16Mode) {
						A *= 2;
						mouse_x = (A & 0xE) + (B & 1);
						mouse_y = (B & 0xE) + ((A >> 4) & 1);
					} else {
						mouse_x = A;
						mouse_y = B;
					}
                    sprintf(str,"Tile: $%X%X",mouse_y,mouse_x);
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE2,str);
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE1,"Tile:");
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_PALETTES,"Palettes");
                }
                else if(((mouse_x >= paletteDestX) && (mouse_x < (paletteDestX + PALETTEWIDTH))) && (mouse_y >= paletteDestY) && (mouse_y < (paletteDestY + PALETTEHEIGHT)))
				{
                    mouse_x = (mouse_x - paletteDestX) / 32;
                    mouse_y = (mouse_y - paletteDestY) / 32;
                    sprintf(str,"Palette: $%02X",palcache[(mouse_y<<4)|mouse_x]);
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE1,"Tile:");
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE2,"Tile:");
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_PALETTES,str);
                } else
				{
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE1,"Tile:");
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_TILE2,"Tile:");
                    SetDlgItemText(hwndDlg,LBL_PPUVIEW_PALETTES,"Palettes");
                }
                break;
        case WM_NCACTIVATE:
                sprintf(str,"%d",PPUViewScanline);
                SetDlgItemText(hwndDlg,IDC_PPUVIEW_SCANLINE,str);
                break;
        case WM_COMMAND:
		{
            switch(HIWORD(wParam))
			{
				case EN_UPDATE:
				{
                    GetDlgItemText(hwndDlg,IDC_PPUVIEW_SCANLINE,str,4);
                    sscanf(str,"%d",&PPUViewScanline);
                    if(PPUViewScanline > 239) PPUViewScanline = 239;
                    break;
				}
				case BN_CLICKED:
				{
					switch(LOWORD(wParam))
					{
						case IDC_MASK_UNUSED_GRAPHICS:
						{
							PPUView_maskUnusedGraphics ^= 1;
							CheckDlgButton(hwndDlg, IDC_MASK_UNUSED_GRAPHICS, PPUView_maskUnusedGraphics ? BST_CHECKED : BST_UNCHECKED);
							EnableWindow(GetDlgItem(hwndDlg, IDC_INVERT_THE_MASK), PPUView_maskUnusedGraphics ?  true : false);
							// redraw now
							PPUViewSkip = PPUViewRefresh;
							FCEUD_UpdatePPUView(-1, 0);
							PPUViewDoBlit();
							break;
						}
						case IDC_INVERT_THE_MASK:
						{
							PPUView_invertTheMask ^= 1;
							CheckDlgButton(hwndDlg, IDC_INVERT_THE_MASK, PPUView_invertTheMask ? BST_CHECKED : BST_UNCHECKED);
							// redraw now
							PPUViewSkip = PPUViewRefresh;
							FCEUD_UpdatePPUView(-1, 0);
							PPUViewDoBlit();
							break;
						}
						case IDC_SPRITE16_MODE:
						{
							PPUView_sprite16Mode ^= 1;
							CheckDlgButton(hwndDlg, IDC_SPRITE16_MODE, PPUView_sprite16Mode ? BST_CHECKED : BST_UNCHECKED);
							// redraw now
							PPUViewSkip = PPUViewRefresh;
							FCEUD_UpdatePPUView(-1, 0);
							PPUViewDoBlit();
							break;
						}
					}
				}
            }
            break;
		}
        case WM_HSCROLL:
            if(lParam)
			{
				//refresh trackbar
				PPUViewRefresh = SendDlgItemMessage(hwndDlg,CTL_PPUVIEW_TRACKBAR,TBM_GETPOS,0,0);
			}
            break;
    }
    return FALSE;
}

void DoPPUView()
{
        if(!GameInfo) {
                FCEUD_PrintError("You must have a game loaded before you can use the PPU Viewer.");
                return;
        }
        if(GameInfo->type==GIT_NSF) {
                FCEUD_PrintError("Sorry, you can't use the PPU Viewer with NSFs.");
                return;
        }

        if(!hPPUView) hPPUView = CreateDialog(fceu_hInstance,"PPUVIEW",NULL,PPUViewCallB);
        if(hPPUView)
		{
			//SetWindowPos(hPPUView,HWND_TOP,0,0,0,0,SWP_NOSIZE|SWP_NOMOVE|SWP_NOOWNERZORDER);
			ShowWindow(hPPUView, SW_SHOWNORMAL);
			SetForegroundWindow(hPPUView);
			// redraw now
			PPUViewSkip = PPUViewRefresh;
			FCEUD_UpdatePPUView(-1,1);
			PPUViewDoBlit();
        }
}
