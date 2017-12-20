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
#include <math.h>

#include "video.h"
#include "player.h"

static std::string AlbumName, Artist, Copyright;
static std::vector<std::string> SongNames;
static int TotalSongs;

static INLINE void FastDrawLine(MDFN_Surface *surface, uint32 color, uint32 bmatch, uint32 breplace, const int xs, const int ys, const int ydelta)
{
 uint32* buf = surface->pixels;
 int y = ys;
 int y_inc = (ydelta < 0) ? -1 : 1;
 unsigned i_bound = abs(ydelta);	// No +1, or we'll overflow our buffer(we compensate in our calculation of half_point).
 unsigned half_point = (i_bound + 1) >> 1;

 for(unsigned i = 0; i <= half_point; i++, y += y_inc)
 {
  if(bmatch != ~0U)
  {
   uint32 tmpcolor = color;

   if(buf[xs + y * surface->pitch32] == bmatch)
    tmpcolor = breplace;

   if(buf[xs + y * surface->pitch32] != breplace)
    buf[xs + y * surface->pitch32] = tmpcolor;
  }
  else
   buf[xs + y * surface->pitch32] = color;
 }
 y -= y_inc;
 for(unsigned i = half_point; i < i_bound; i++, y += y_inc)
 {
  if(bmatch != ~0U)
  {
   uint32 tmpcolor = color;

   if(buf[xs + 1 + y * surface->pitch32] == bmatch)
    tmpcolor = breplace;

   if(buf[xs + 1+ y * surface->pitch32] != breplace)
    buf[xs + 1 + y * surface->pitch32] = tmpcolor;
  }
  else
   buf[xs + 1 + y * surface->pitch32] = color;
 }
}

int Player_Init(int tsongs, const std::string &album, const std::string &artist, const std::string &copyright, const std::vector<std::string> &snames)
{
 AlbumName = album;
 Artist = artist;
 Copyright = copyright;
 SongNames = snames;

 TotalSongs = tsongs;

 MDFNGameInfo->nominal_width = 384;
 MDFNGameInfo->nominal_height = 240;

 MDFNGameInfo->fb_width = 384;
 MDFNGameInfo->fb_height = 240;

 MDFNGameInfo->lcm_width = 384;
 MDFNGameInfo->lcm_height = 240;

 MDFNGameInfo->GameType = GMT_PLAYER;

 return(1);
}

int Player_Init(int tsongs, const std::string &album, const std::string &artist, const std::string &copyright, char **snames)
{
 std::vector<std::string> tmpvec;

 if(snames)
 {
  for(int i = 0; i < tsongs; i++)
   tmpvec.push_back(snames[i] ? snames[i] : "");
 }

 return Player_Init(tsongs, album, artist, copyright, tmpvec);
}

void Player_Draw(MDFN_Surface *surface, MDFN_Rect *dr, int CurrentSong, int16 *samples, int32 sampcount)
{
 uint32 *XBuf = surface->pixels;
 //MDFN_Rect *dr = &MDFNGameInfo->DisplayRect;
 const uint32 text_color = surface->MakeColor(0xE8, 0xE8, 0xE8);
 const uint32 text_shadow_color = surface->MakeColor(0x00, 0x18, 0x10);
 const uint32 bg_color = surface->MakeColor(0x20, 0x00, 0x08);
 const uint32 left_color = surface->MakeColor(0x80, 0x80, 0xFF);
 const uint32 right_color = surface->MakeColor(0x80, 0xff, 0x80);
 const uint32 center_color = surface->MakeColor(0x80, 0xCC, 0xCC);

 dr->x = 0;
 dr->y = 0;
 dr->w = 384;
 dr->h = 240;

 // Draw the background color
 for(int y = 0; y < dr->h; y++)
  MDFN_FastU32MemsetM8(&XBuf[y * surface->pitch32], bg_color, dr->w);

 // Now we draw the waveform data.  It should be centered vertically, and extend the screen horizontally from left to right.
 if(sampcount)
 {
  const int32 x_scale = (sampcount << 8) / dr->w;;
  const int32 y_scale = -dr->h;
  int lastX, lastY;


  for(int wc = 0; wc < MDFNGameInfo->soundchan; wc++)
  {
   uint32 color =  wc ? right_color : left_color; //MK_COLOR(0x80, 0xff, 0x80) : MK_COLOR(0x80, 0x80, 0xFF);

   if(MDFNGameInfo->soundchan == 1) 
    color = center_color; //MK_COLOR(0x80, 0xc0, 0xc0);

   lastX = -1;
   lastY = 0;

   for(int x = 0; x < dr->w; x++)
   {
    const int32 samp = samples[wc + (x * x_scale >> 8) * MDFNGameInfo->soundchan];
    int ypos;

    ypos = (dr->h / 2) + ((samp * y_scale + 0x4000) >> 15);
    //ypos = (rand() & 0xFFF) - 0x800;

    if(ypos < 0)
     ypos = 0;

    if(ypos >= dr->h)
     ypos = dr->h - 1;

    if(lastX >= 0) 
     FastDrawLine(surface, color, wc ? left_color : ~0, center_color, lastX, lastY, ypos - lastY);
    lastX = x;
    lastY = ypos;
   }
  }
 }

 XBuf += 2 * surface->pitch32;
 DrawTextTransShadow(XBuf, surface->pitch32 * sizeof(uint32), dr->w, AlbumName, text_color, text_shadow_color, 1);

 XBuf += (13 + 2) * surface->pitch32;
 DrawTextTransShadow(XBuf, surface->pitch32 * sizeof(uint32), dr->w, Artist, text_color, text_shadow_color, 1);

 XBuf += (13 + 2) * surface->pitch32;
 DrawTextTransShadow(XBuf, surface->pitch32 * sizeof(uint32), dr->w, Copyright, text_color, text_shadow_color, 1);

 XBuf += (13 * 2) * surface->pitch32;

 // If each song has an individual name, show this song's name.
 {
  std::string tmpsong = "";

  if((unsigned int)CurrentSong < SongNames.size())
   tmpsong = SongNames[CurrentSong];

  if(tmpsong == "" && TotalSongs > 1)
   tmpsong = std::string(_("Song:"));

  DrawTextTransShadow(XBuf, surface->pitch32 * sizeof(uint32), dr->w, tmpsong, text_color, text_shadow_color, 1);
 }

 XBuf += (13 + 2) * surface->pitch32;
 if(TotalSongs > 1)
 {
  char snbuf[32];
  trio_snprintf(snbuf, 32, "<%d/%d>", CurrentSong + 1, TotalSongs);
  DrawTextTransShadow(XBuf, surface->pitch32 * sizeof(uint32), dr->w, snbuf, text_color, text_shadow_color, 1);
 }
}
