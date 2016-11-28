// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2003, 2004 Greg Stanton
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// Display.cpp
// ----------------------------------------------------------------------------
#include "Display.h"
#define DISPLAY_LENGTH 320
#define DISPLAY_HEIGHT 292

bool display_stretched = false;
bool display_menuenabled = true;
byte display_zoom = 1;
bool display_fullscreen = false;
std::vector<Mode> display_modes;
Mode display_mode = {640, 480, 8, 0, 0, 0};

static LPDIRECTDRAW display_ddraw = NULL;
static LPDIRECTDRAWSURFACE display_primary = NULL;
static LPDIRECTDRAWSURFACE display_offscreen = NULL;
static LPDIRECTDRAWPALETTE display_palette = NULL;
static LPDIRECTDRAWCLIPPER display_clipper = NULL;
static HWND display_hWnd = NULL;
static word display_palette16[256] = {0};
static byte display_palette24[768] = {0};
static uint display_palette32[256] = {0};

// ----------------------------------------------------------------------------
// ToMode
// ----------------------------------------------------------------------------
static Mode display_ToMode(LPDDSURFACEDESC surfaceDesc) {
  Mode mode = {0};
  if(surfaceDesc != NULL) {
    mode.width = surfaceDesc->dwWidth;
    mode.height = surfaceDesc->dwHeight;
    mode.bpp = surfaceDesc->ddpfPixelFormat.dwRGBBitCount;
    mode.rmask = surfaceDesc->ddpfPixelFormat.dwRBitMask;
    mode.gmask = surfaceDesc->ddpfPixelFormat.dwGBitMask;
    mode.bmask = surfaceDesc->ddpfPixelFormat.dwBBitMask;
  }
  return mode;
}

// ----------------------------------------------------------------------------
// EnumerateModes
// ----------------------------------------------------------------------------
static HRESULT WINAPI display_EnumerateModes(LPDDSURFACEDESC surfaceDesc, LPVOID context) {
  Mode mode = display_ToMode(surfaceDesc);
  if(mode.width != 0 && mode.height != 0 && mode.bpp != 0) {
    display_modes.push_back(mode);
  }
  return DDENUMRET_OK;
}

// ----------------------------------------------------------------------------
// SetClipper
// ----------------------------------------------------------------------------
static bool display_SetClipper( ) {
  HRESULT hr = display_ddraw->CreateClipper(0, &display_clipper, NULL);
  if(FAILED(hr) || display_clipper == NULL) {
    logger_LogError(IDS_DISPLAY1,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  hr = display_clipper->SetHWnd(0, display_hWnd);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY2, "");
    logger_LogError("",common_Format(hr));
    return false;
  }

  hr = display_primary->SetClipper(display_clipper);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY3,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  return true;
}

// ----------------------------------------------------------------------------
// GetColorBits
// ----------------------------------------------------------------------------
static void display_GetColorBits(uint bitMask, uint* shift, uint* bits) {
  *shift = 0;
  if(bitMask) {
    while((bitMask & 1) == 0) {
      (*shift)++;
      bitMask >>= 1;
    }
  }
  *bits = 0;
  while((bitMask & 1) != 0) {
    (*bits)++;
    bitMask >>= 1;
  }
}

// ----------------------------------------------------------------------------
// GetStretchedRect
// ----------------------------------------------------------------------------
static RECT display_GetStretchedRect( ) {
  RECT clientRect;
  GetClientRect(display_hWnd, &clientRect);

  POINT point = {clientRect.left, clientRect.top};
  ClientToScreen(display_hWnd, &point);
  
  RECT targetRect = {0};
  targetRect.left = point.x;
  targetRect.top = point.y;
  targetRect.right = targetRect.left + clientRect.right;
  targetRect.bottom = targetRect.top + clientRect.bottom;
  return targetRect;
}

// ----------------------------------------------------------------------------
// GetCenteredRect
// ----------------------------------------------------------------------------
static RECT display_GetCenteredRect( ) {
  RECT clientRect;
  GetClientRect(display_hWnd, &clientRect);
    
  POINT center = {(clientRect.right + 1)  / 2, (clientRect.bottom + 1) / 2};
  POINT corner = {center.x - ((maria_visibleArea.GetLength( ) * display_zoom) / 2), center.y - ((maria_visibleArea.GetHeight( ) * display_zoom) / 2)};
  ClientToScreen(display_hWnd, &corner);
  
  RECT targetRect;
  targetRect.left = corner.x;
  targetRect.top = corner.y;
  targetRect.right = targetRect.left + (maria_visibleArea.GetLength( ) * display_zoom);
  targetRect.bottom = targetRect.top + (maria_visibleArea.GetHeight( ) * display_zoom);
  return targetRect;
}

// ----------------------------------------------------------------------------
// RestorePrimary
// ----------------------------------------------------------------------------
static bool display_RestorePrimary( ) {
  HRESULT hr = display_primary->Restore( );
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY4,"");
    logger_LogError("",common_Format(hr));    
    return false;
  }
  return true;
}

// ----------------------------------------------------------------------------
// RestoreOffscreen
// ----------------------------------------------------------------------------
static bool display_RestoreOffscreen( ) {
  HRESULT hr = display_offscreen->Restore( );
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY5,"");
    logger_LogError("",common_Format(hr));    
    return false;
  }
  return true;
}

// ----------------------------------------------------------------------------
// ResetPalette08
// ----------------------------------------------------------------------------
static bool display_ResetPalette08( ) {
  if(display_ddraw == NULL) {
    logger_LogError(IDS_DISPLAY6,"");
    return false;
  }  
  if(display_primary == NULL) { 
    logger_LogError(IDS_DISPLAY7,"");
    return false;
  }
  if(display_offscreen == NULL) {
    logger_LogError(IDS_DISPLAY8,"");
    return false;
  }
  if(display_palette == NULL) {
    logger_LogError(IDS_DISPLAY9,"");
    return false;
  }
  
  PALETTEENTRY paletteEntry[256];
  for(int index = 0; index < 256; index++) {
    PALETTEENTRY entry;
    entry.peRed = palette_data[(index * 3) + 0];
    entry.peGreen = palette_data[(index * 3) + 1];
    entry.peBlue = palette_data[(index * 3) + 2];
    entry.peFlags = 0;
    paletteEntry[index] = entry;
  }
  
  HRESULT hr = display_palette->SetEntries(0, 0, 256, paletteEntry); 
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY10,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  return true;
}

// ----------------------------------------------------------------------------
// ResetPalette16
// ----------------------------------------------------------------------------
static bool display_ResetPalette16( ) {
  if(display_ddraw == NULL) {
    logger_LogError(IDS_DISPLAY6,"");
    return false;
  }
  
  DDSURFACEDESC surfaceDesc = {0};
  surfaceDesc.dwSize = sizeof(DDSURFACEDESC);
  HRESULT hr = display_ddraw->GetDisplayMode(&surfaceDesc);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY11,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  Mode mode16 = display_ToMode(&surfaceDesc);
  if(mode16.bpp != 16) {
    for(int index = 0; index < display_modes.size( ); index++) {
      Mode mode = display_modes[index];
      if(mode.bpp == 16) {
        mode16 = mode;  
        break;
      }
    }
  }
  
  uint rshift, rsize;
  uint bshift, bsize;
  uint gshift, gsize;
      
  display_GetColorBits(mode16.rmask, &rshift, &rsize);
  display_GetColorBits(mode16.bmask, &bshift, &bsize);
  display_GetColorBits(mode16.gmask, &gshift, &gsize);
     
  for(uint index = 0; index < 256; index++) {
    word r = ((palette_data[(index * 3) + 0] * (1 << rsize)) / 256) << rshift;
    word g = ((palette_data[(index * 3) + 1] * (1 << gsize)) / 256) << gshift;
    word b = ((palette_data[(index * 3) + 2] * (1 << bsize)) / 256) << bshift;
    display_palette16[index] = r | g | b;
  }
   
  return true;
}

// ----------------------------------------------------------------------------
// ResetPalette24
// ----------------------------------------------------------------------------
static void display_ResetPalette24( ) {
  for(uint index = 0; index < 256; index++) {
    display_palette24[(index * 3) + 0] = palette_data[(index * 3) + 2];
    display_palette24[(index * 3) + 1] = palette_data[(index * 3) + 1];
    display_palette24[(index * 3) + 2] = palette_data[(index * 3) + 0];
  }
}

// ----------------------------------------------------------------------------
// ResetPalette32
// ----------------------------------------------------------------------------
static void display_ResetPalette32( ) {
  for(uint index = 0; index < 256; index++) {
    uint r = palette_data[(index * 3) + 0] << 16;
    uint g = palette_data[(index * 3) + 1] << 8;
    uint b = palette_data[(index * 3) + 2];
    display_palette32[index] = r | g | b;
  }
}

// ----------------------------------------------------------------------------
// ReleaseDirectDraw
// ----------------------------------------------------------------------------
static void display_ReleaseDirectDraw( ) {
  if(display_ddraw != NULL) {
    display_ddraw->Release( );
    display_ddraw = NULL;
  }    
}

// ----------------------------------------------------------------------------
// ReleasePrimary
// ----------------------------------------------------------------------------
static void display_ReleasePrimary( ) {
  if(display_primary != NULL) {
    display_primary->SetPalette(NULL);
    display_primary->SetClipper(NULL);
    display_primary->Release( );
    display_primary = NULL;
  }
}

// ----------------------------------------------------------------------------
// ReleaseOffscreen
// ----------------------------------------------------------------------------
static void display_ReleaseOffscreen( ) {
  if(display_offscreen != NULL) {
    display_offscreen->Release( );
    display_offscreen = NULL;
  }    
}

// ----------------------------------------------------------------------------
// ReleasePalette
// ----------------------------------------------------------------------------
static void display_ReleasePalette( ) {
  if(display_palette != NULL) {
    display_palette->Release( );
    display_palette = NULL;
  }  
}

// ----------------------------------------------------------------------------
// ReleaseClipper
// ----------------------------------------------------------------------------
static void display_ReleaseClipper( ) {
  if(display_clipper != NULL) {
    display_clipper->Release( );
    display_clipper = NULL;
  }  
}

// ----------------------------------------------------------------------------
// Initialize
// ----------------------------------------------------------------------------
bool display_Initialize(HWND hWnd) {
  if(hWnd == NULL) {
    logger_LogError(IDS_DISPLAY12,"");
    return false;
  }

  HRESULT hr = DirectDrawCreate(NULL, &display_ddraw, NULL);
  if(FAILED(hr) || display_ddraw == NULL) {
    logger_LogError(IDS_DISPLAY13,"");
    logger_LogError("",common_Format(hr));
    return false;
  }

  display_modes.clear( );
  hr = display_ddraw->EnumDisplayModes(DDEDM_STANDARDVGAMODES, NULL, NULL, display_EnumerateModes);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY14,"");
    logger_LogError("",common_Format(hr));
    return false;
  }

  display_ReleaseDirectDraw( );
  display_hWnd = hWnd;
  return true;
}

// ----------------------------------------------------------------------------
// SetFullscreen
// ----------------------------------------------------------------------------
bool display_SetFullscreen( ) {
  display_Release( );
  
  HRESULT hr = DirectDrawCreate(NULL, &display_ddraw, NULL);
  if(FAILED(hr) || display_ddraw == NULL) {
    logger_LogError(IDS_DISPLAY13,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  hr = display_ddraw->SetCooperativeLevel(display_hWnd, DDSCL_FULLSCREEN | DDSCL_EXCLUSIVE);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY15,"");
    logger_LogError("",common_Format(hr));    
    return false;
  }
  
  hr = display_ddraw->SetDisplayMode(display_mode.width, display_mode.height, display_mode.bpp);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY16, common_Format(display_mode.width) + "x" + common_Format(display_mode.height) + "x" + common_Format(display_mode.bpp) + ".");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  DDSURFACEDESC primaryDesc = {0};
  primaryDesc.dwSize = sizeof(DDSURFACEDESC);
  primaryDesc.dwFlags = DDSD_CAPS;
  primaryDesc.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE;
    
  hr = display_ddraw->CreateSurface(&primaryDesc, &display_primary, NULL);
  if(FAILED(hr) || display_primary == NULL) {
    logger_LogError(IDS_DISPLAY17,"");
    logger_LogError("",common_Format(hr));
    return false;
  }

  DDSURFACEDESC offscreenDesc = {0};
  offscreenDesc.dwSize = sizeof(DDSURFACEDESC);
  offscreenDesc.dwFlags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH;
  offscreenDesc.ddsCaps.dwCaps = DDSCAPS_OFFSCREENPLAIN;
  offscreenDesc.dwWidth = DISPLAY_LENGTH;

  offscreenDesc.dwHeight = DISPLAY_HEIGHT;
    
  hr = display_ddraw->CreateSurface(&offscreenDesc, &display_offscreen, NULL);
  if(FAILED(hr) || display_offscreen == NULL) {
    logger_LogError(IDS_DISPLAY18,"");
    logger_LogError("",common_Format(hr));
    return false;
  } 
  
  if(!display_SetClipper( )) {
    logger_LogError(IDS_DISPLAY19,"");
    return false;
  }

  if(display_mode.bpp == 8) {
    PALETTEENTRY paletteEntry[256] = {0};
    hr = display_ddraw->CreatePalette(DDPCAPS_8BIT, paletteEntry, &display_palette, NULL);
    if(FAILED(hr) || display_palette == NULL) {
      logger_LogError(IDS_DISPLAY20,"");
      logger_LogError("",common_Format(hr));
      return false;
    }
    hr = display_primary->SetPalette(display_palette);
    if(FAILED(hr)) {
      logger_LogError(IDS_DISPLAY21,"");
      logger_LogError("",common_Format(hr));
      return false;
    }
  }
  
  display_fullscreen = true;
  if(!display_ResetPalette( )) {
    logger_LogError(IDS_DISPLAY22,"");
    return false;
  }

  return true;  
}

// ----------------------------------------------------------------------------
// SetWindowed
// ----------------------------------------------------------------------------
bool display_SetWindowed( ) {
  display_Release( );
  
  HRESULT hr = DirectDrawCreate(NULL, &display_ddraw, NULL);
  if(FAILED(hr) || display_ddraw == NULL) {
    logger_LogError(IDS_DISPLAY13,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  hr = display_ddraw->SetCooperativeLevel(display_hWnd, DDSCL_NORMAL);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY23,"");
    logger_LogError("",common_Format(hr));    
    return false;
  }

  DDSURFACEDESC primaryDesc = {0};
  primaryDesc.dwSize = sizeof(DDSURFACEDESC);
  primaryDesc.dwFlags = DDSD_CAPS;
  primaryDesc.ddsCaps.dwCaps = DDSCAPS_PRIMARYSURFACE;
    
  hr = display_ddraw->CreateSurface(&primaryDesc, &display_primary, NULL);
  if(FAILED(hr) || display_primary == NULL) {
    logger_LogError(IDS_DISPLAY17,"");
    logger_LogError("",common_Format(hr));
    return false;
  }

  DDSURFACEDESC offscreenDesc = {0};
  offscreenDesc.dwSize = sizeof(DDSURFACEDESC);
  offscreenDesc.dwFlags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH;
  offscreenDesc.ddsCaps.dwCaps = DDSCAPS_OFFSCREENPLAIN;
  offscreenDesc.dwWidth = DISPLAY_LENGTH;
  offscreenDesc.dwHeight = DISPLAY_HEIGHT;
    
  hr = display_ddraw->CreateSurface(&offscreenDesc, &display_offscreen, NULL);
  if(FAILED(hr) || display_offscreen == NULL) {
    logger_LogError(IDS_DISPLAY24,"");
    logger_LogError("",common_Format(hr));
    return false;
  } 
  
  if(!display_SetClipper( )) {
    logger_LogError(IDS_DISPLAY19,"");
    return false;
  }
  
  display_fullscreen = false;
  if(!display_ResetPalette( )) {
    logger_LogError(IDS_DISPLAY22,"");
    return false;
  }
  
  return true;  
}

// ----------------------------------------------------------------------------
// Show
// ----------------------------------------------------------------------------
bool display_Show( ) {
  if(display_ddraw == NULL) {
    logger_LogError(IDS_DISPLAY6,"");
    return false;
  }  
  if(display_offscreen == NULL) {
    logger_LogError(IDS_DISPLAY8,"");
    return false;
  }
  if(display_primary == NULL) { 
    logger_LogError(IDS_DISPLAY7,"");
    return false;
  }
  
  uint height = maria_visibleArea.GetHeight( );
  uint length = maria_visibleArea.GetLength( );

  DDSURFACEDESC offscreenDesc = {0};
  offscreenDesc.dwSize = sizeof(DDSURFACEDESC);
  HRESULT hr = display_offscreen->Lock(NULL, &offscreenDesc, DDLOCK_WAIT, NULL);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY25,"");
    logger_LogError("",common_Format(hr));
    if(hr != DDERR_SURFACELOST || !display_RestoreOffscreen( )) {
      return false;
    }
  }
  
  const byte* buffer = maria_surface + ((maria_visibleArea.top - maria_displayArea.top) * maria_visibleArea.GetLength( ));

  if(offscreenDesc.ddpfPixelFormat.dwRGBBitCount == 8) {
    byte* surface = (byte*)offscreenDesc.lpSurface;
    for(uint indexY = 0; indexY < height; indexY++) {
      for(uint indexX = 0; indexX < length; indexX += 4) {
        surface[indexX + 0] = buffer[indexX + 0];
        surface[indexX + 1] = buffer[indexX + 1];
        surface[indexX + 2] = buffer[indexX + 2];
        surface[indexX + 3] = buffer[indexX + 3];
      }
      surface += offscreenDesc.lPitch;
      buffer += length;
    }
  }
  else if(offscreenDesc.ddpfPixelFormat.dwRGBBitCount == 16) {
    word* surface = (word*)offscreenDesc.lpSurface;
    uint pitch = offscreenDesc.lPitch >> 1;
    for(uint indexY = 0; indexY < height; indexY++) {
      for(uint indexX = 0; indexX < length; indexX += 4) {
        surface[indexX + 0] = display_palette16[buffer[indexX + 0]];
        surface[indexX + 1] = display_palette16[buffer[indexX + 1]];
        surface[indexX + 2] = display_palette16[buffer[indexX + 2]];
        surface[indexX + 3] = display_palette16[buffer[indexX + 3]];
      }
      surface += pitch;
      buffer += length;
    }
  }
  else if(offscreenDesc.ddpfPixelFormat.dwRGBBitCount == 24) {
    byte* surface = (byte*)offscreenDesc.lpSurface;
    for(uint indexY = 0; indexY < height; indexY++) {
      for(uint indexX = 0; indexX < length; indexX++) {
        surface[(indexX * 3) + 0] = display_palette24[(buffer[indexX] * 3) + 0];
        surface[(indexX * 3) + 1] = display_palette24[(buffer[indexX] * 3) + 1];
        surface[(indexX * 3) + 2] = display_palette24[(buffer[indexX] * 3) + 2];
      }
      surface += offscreenDesc.lPitch;
      buffer += length;
    }    
  }
  else if(offscreenDesc.ddpfPixelFormat.dwRGBBitCount == 32) {
    uint* surface = (uint*)offscreenDesc.lpSurface;
    uint pitch = offscreenDesc.lPitch >> 2;
    for(uint indexY = 0; indexY < height; indexY++) {
      for(uint indexX = 0; indexX < length; indexX += 4) {
        surface[indexX + 0] = display_palette32[buffer[indexX + 0]];
        surface[indexX + 1] = display_palette32[buffer[indexX + 1]];
        surface[indexX + 2] = display_palette32[buffer[indexX + 2]];
        surface[indexX + 3] = display_palette32[buffer[indexX + 3]];
      }
      surface += pitch;
      buffer += length;
    }
  }

  hr = display_offscreen->Unlock(NULL);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY26,"");
    logger_LogError("",common_Format(hr));
    if(hr != DDERR_SURFACELOST || !display_RestoreOffscreen( )) {
      return false;
    }
  }    

  RECT targetRect = (display_stretched)? display_GetStretchedRect( ): display_GetCenteredRect( );
  RECT sourceRect = {0, 0, maria_visibleArea.GetLength( ), maria_visibleArea.GetHeight( )};
  
  hr = display_primary->Blt(&targetRect, display_offscreen, &sourceRect, DDBLT_WAIT, NULL);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY27,"");
    logger_LogError("",common_Format(hr));  
    if(hr != DDERR_SURFACELOST || !display_RestorePrimary( )) {
      return false;
    }
  }
  
  return true;
}

// ----------------------------------------------------------------------------
// ResetPalette
// ----------------------------------------------------------------------------
bool display_ResetPalette( ) {
  display_ResetPalette24( );
  display_ResetPalette32( );
  if(!display_ResetPalette16( )) {
    logger_LogError(IDS_DISPLAY28,"");
    return false;
  }
  if(display_fullscreen && !display_ResetPalette08( )) {
    logger_LogError(IDS_DISPLAY29,"");
    return false;
  }
  return true;
}

// ----------------------------------------------------------------------------
// TakeScreenshot
// ----------------------------------------------------------------------------
bool display_TakeScreenshot(std::string filename) {
  if(filename.empty( ) || filename.length == 0) {
    logger_LogError(IDS_DISPLAY30,"");
    return false;
  }

  BITMAPFILEHEADER bitmapFileHeader = {0};
  bitmapFileHeader.bfType = 0x4d42;
  bitmapFileHeader.bfSize = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER) + (maria_visibleArea.GetArea( ) * 3);
  bitmapFileHeader.bfReserved1 = 0;
  bitmapFileHeader.bfReserved2 = 0;
  bitmapFileHeader.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);

  BITMAPINFOHEADER bitmapInfoHeader = {0};
  bitmapInfoHeader.biSize = sizeof(BITMAPINFOHEADER);
  bitmapInfoHeader.biWidth = maria_visibleArea.GetLength( );
  bitmapInfoHeader.biHeight = maria_visibleArea.GetHeight( );
  bitmapInfoHeader.biPlanes = 1;
  bitmapInfoHeader.biBitCount = 24;
  
  FILE* file = fopen(filename.c_str( ), "wb");
  if(file == NULL) {
    logger_LogError(IDS_DISPLAY31, filename);
    return false;
  }

  fwrite(&bitmapFileHeader, sizeof(BITMAPFILEHEADER), 1, file);
  fwrite(&bitmapInfoHeader, sizeof(BITMAPINFOHEADER), 1, file);

  const byte* buffer = maria_surface + (maria_visibleArea.top - maria_displayArea.top) * maria_visibleArea.GetLength( );

  for(int row = maria_visibleArea.GetHeight( ) - 1; row >= 0; row--) {
    for(uint column = 0; column < maria_visibleArea.GetLength( ); column++) {
      byte entry = buffer[(row * maria_visibleArea.GetLength( )) + column];
      fwrite(&palette_data[(entry * 3) + 2], 1, 1, file);
      fwrite(&palette_data[(entry * 3) + 1], 1, 1, file);
      fwrite(&palette_data[(entry * 3) + 0], 1, 1, file);
    }
  }  
  
  fclose(file);
  return true;
}

// ----------------------------------------------------------------------------
// Clear
// ----------------------------------------------------------------------------
bool display_Clear( ) {
  if(display_ddraw == NULL) {
    logger_LogError(IDS_DISPLAY6,"");
    return false;
  }  
  if(display_offscreen == NULL) {
    logger_LogError(IDS_DISPLAY8,"");
    return false;
  }
  if(display_primary == NULL) { 
    logger_LogError(IDS_DISPLAY7,"");
    return false;
  }
 
  DDBLTFX bltFx;
  bltFx.dwSize = sizeof(DDBLTFX);
  bltFx.dwFillColor = 0;

  HRESULT hr = display_offscreen->Blt(NULL, NULL, NULL, DDBLT_COLORFILL, &bltFx);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY32,"");
    logger_LogError("",common_Format(hr));    
    return false;
  }
  
  hr = display_primary->Blt(NULL, NULL, NULL, DDBLT_COLORFILL, &bltFx);
  if(FAILED(hr)) {
    logger_LogError(IDS_DISPLAY33,"");
    logger_LogError("",common_Format(hr));
    return false;
  }
  
  return true;
}

// ----------------------------------------------------------------------------
// IsFullscreen
// ----------------------------------------------------------------------------
bool display_IsFullscreen( ) {
  return display_fullscreen;
}

// ----------------------------------------------------------------------------
// Release
// ----------------------------------------------------------------------------
void display_Release( ) {
  display_ReleaseClipper( );
  display_ReleasePalette( );
  display_ReleaseOffscreen( );
  display_ReleasePrimary( );
  display_ReleaseDirectDraw( );
}
