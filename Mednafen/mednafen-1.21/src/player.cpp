/* Mednafen - Multi-system Emulator
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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "mednafen.h"
#include <trio/trio.h>

#include "video.h"
#include "player.h"

static std::string AlbumName, Artist, Copyright;
static std::vector<std::string> SongNames;
static int TotalSongs;

template<typename T>
static INLINE void FastDrawLine(T* buf, int32 pitch, uint32 color, uint32 bmatch, uint32 breplace, const int xs, const int ys, const int ydelta)
{
 int y = ys;
 int y_inc = (ydelta < 0) ? -1 : 1;
 unsigned i_bound = abs(ydelta);	// No +1, or we'll overflow our buffer(we compensate in our calculation of half_point).
 unsigned half_point = (i_bound + 1) >> 1;

 for(unsigned i = 0; i <= half_point; i++, y += y_inc)
 {
  if(bmatch != ~0U)
  {
   uint32 tmpcolor = color;

   if(buf[xs + y * pitch] == bmatch)
    tmpcolor = breplace;

   if(buf[xs + y * pitch] != breplace)
    buf[xs + y * pitch] = tmpcolor;
  }
  else
   buf[xs + y * pitch] = color;
 }
 y -= y_inc;
 for(unsigned i = half_point; i < i_bound; i++, y += y_inc)
 {
  if(bmatch != ~0U)
  {
   uint32 tmpcolor = color;

   if(buf[xs + 1 + y * pitch] == bmatch)
    tmpcolor = breplace;

   if(buf[xs + 1+ y * pitch] != breplace)
    buf[xs + 1 + y * pitch] = tmpcolor;
  }
  else
   buf[xs + 1 + y * pitch] = color;
 }
}

template<typename T>
static void DrawWaveformSub(T* const pixels, const int32 pitch, const uint32 lcolor, const uint32 rcolor, const uint32 ccolor, const int32 w, const int32 h, const int32 numchan, const int16* soundbuf, int32 framecount)
{
 // Now we draw the waveform data.  It should be centered vertically, and extend the screen horizontally from left to right.
 if(framecount)
 {
  const int32 x_scale = (framecount << 8) / w;
  const int32 y_scale = -h;
  int lastX, lastY;

  for(int wc = 0; wc < numchan; wc++)
  {
   uint32 color = wc ? rcolor : lcolor;

   if(numchan == 1) 
    color = ccolor;

   lastX = -1;
   lastY = 0;

   for(int x = 0; x < w; x++)
   {
    const int32 samp = soundbuf[wc + (x * x_scale >> 8) * numchan];
    int ypos;

    ypos = (h / 2) + ((samp * y_scale + 0x4000) >> 15);
    //ypos = (rand() & 0xFFF) - 0x800;

    if(ypos < 0)
     ypos = 0;

    if(ypos >= h)
     ypos = h - 1;

    if(lastX >= 0) 
     FastDrawLine(pixels, pitch, color, wc ? lcolor : ~0U, ccolor, lastX, lastY, ypos - lastY);

    lastX = x;
    lastY = ypos;
   }
  }
 }
}

static INLINE void DrawWaveform(MDFN_Surface* surface, const MDFN_Rect& dr, const int32 numchan, const int16* soundbuf, const int32 framecount)
{
 const uint32 left_color = surface->MakeColor(0x80, 0x80, 0xFF);
 const uint32 right_color = surface->MakeColor(0x80, 0xFF, 0x80);
 const uint32 center_color = surface->MakeColor(0x80, 0xCC, 0xCC);

 switch(surface->format.bpp)
 {
  case 8:
	// TODO(colors):
	DrawWaveformSub(surface->pix<uint8>() + dr.x + dr.y * surface->pitchinpix, surface->pitchinpix, left_color, right_color, center_color, dr.w, dr.h, numchan, soundbuf, framecount);
	break;

  case 16:
	DrawWaveformSub(surface->pix<uint16>() + dr.x + dr.y * surface->pitchinpix, surface->pitchinpix, left_color, right_color, center_color, dr.w, dr.h, numchan, soundbuf, framecount);
	break;

  case 32:
	DrawWaveformSub(surface->pix<uint32>() + dr.x + dr.y * surface->pitchinpix, surface->pitchinpix, left_color, right_color, center_color, dr.w, dr.h, numchan, soundbuf, framecount);
	break;
 }
}

void Player_Init(int tsongs, const std::string &album, const std::string &artist, const std::string &copyright, const std::vector<std::string> &snames, bool override_gi)
{
 AlbumName = album;
 Artist = artist;
 Copyright = copyright;
 SongNames = snames;

 TotalSongs = tsongs;

 if(override_gi)
 {
  MDFNGameInfo->nominal_width = 384;
  MDFNGameInfo->nominal_height = 240;

  MDFNGameInfo->fb_width = 384;
  MDFNGameInfo->fb_height = 240;

  MDFNGameInfo->lcm_width = 384;
  MDFNGameInfo->lcm_height = 240;

  MDFNGameInfo->GameType = GMT_PLAYER;
 }
}

void Player_Draw(MDFN_Surface* surface, MDFN_Rect* dr, int CurrentSong, int16* soundbuf, int32 framecount)
{
 const unsigned fontid = MDFN_FONT_9x18_18x18;
 const uint32 text_color = surface->MakeColor(0xE8, 0xE8, 0xE8);
 const uint32 text_shadow_color = surface->MakeColor(0x00, 0x18, 0x10);
 //const uint32 bg_color = surface->MakeColor(0x20, 0x00, 0x08);

 dr->x = 0;
 dr->y = 0;
 dr->w = surface->w;
 dr->h = surface->h;

 //
 // Draw the background color
 //
 surface->Fill(0x20, 0x00, 0x08, 0);	// FIXME: Fill() changes

 DrawWaveform(surface, *dr, MDFNGameInfo->soundchan, soundbuf, framecount);

 //
 //
 int32 text_y = 2;

 DrawTextShadow(surface, 0, text_y, AlbumName, text_color, text_shadow_color, fontid, dr->w);
 text_y += (13 + 2);

 DrawTextShadow(surface, 0, text_y, Artist, text_color, text_shadow_color, fontid, dr->w);
 text_y += (13 + 2);

 DrawTextShadow(surface, 0, text_y, Copyright, text_color, text_shadow_color, fontid, dr->w);
 text_y += (13 * 2);

 // If each song has an individual name, show this song's name.
 {
  std::string tmpsong = "";

  if((unsigned int)CurrentSong < SongNames.size())
   tmpsong = SongNames[CurrentSong];

  if(tmpsong == "" && TotalSongs > 1)
   tmpsong = std::string(_("Song:"));

  DrawTextShadow(surface, 0, text_y, tmpsong, text_color, text_shadow_color, fontid, dr->w);
 }
 text_y += (13 + 2);

 if(TotalSongs > 1)
 {
  char snbuf[32];
  trio_snprintf(snbuf, 32, "<%d/%d>", CurrentSong + 1, TotalSongs);
  DrawTextShadow(surface, 0, text_y, snbuf, text_color, text_shadow_color, fontid, dr->w);
 }
}
