/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* memdebugger.h:
**  Copyright (C) 2007-2016 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_DRIVERS_MEMDEBUGGER_H
#define __MDFN_DRIVERS_MEMDEBUGGER_H

#include <iconv.h>

class MemDebuggerPrompt;

class MemDebugger
{
 public:

 MemDebugger();
 ~MemDebugger();

 void Draw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *screen_rect);
 int Event(const SDL_Event *event);
 void SetActive(bool newia);

 private:

 bool ICV_Init(const char *newcode);
 void ChangePos(int64 delta);

 std::vector<uint8> TextToBS(const std::string& text);
 void PromptFinish(const std::string& pstring);
 bool DoBSSearch(const std::vector<uint8>& thebytes);
 bool DoRSearch(const std::vector<uint8>& thebytes);


 int32 DrawWaveform(MDFN_Surface* surface, const int32 base_y, const uint32 hcenterw);
 void DrawAtCursorInfo(MDFN_Surface* surface, const int32 base_y, const uint32 hcenterw);

 // Local cache variable set after game load to reduce dereferences and make the code nicer.
 // (the game structure's debugger info struct doesn't change during emulation, so this is safe)
 const std::vector<AddressSpaceType> *AddressSpaces;
 const AddressSpaceType *ASpace; // Current address space

 bool IsActive;
 std::vector<uint32> ASpacePos;
 std::vector<uint64> SizeCache;
 std::vector<uint64> GoGoPowerDD;

 int CurASpace; // Current address space number

 bool LowNib;
 bool InEditMode;
 bool InTextArea; // Right side text vs left side numbers, selected via TAB

 std::string BSS_String, RS_String, TS_String;
 char *error_string;
 uint32 error_time;

 typedef enum
 {
  None = 0,
  Goto,
  GotoDD,
  ByteStringSearch,
  RelSearch,
  TextSearch,
  DumpMem,
  LoadMem,
  SetCharset,
 } PromptType;

 iconv_t ict;
 iconv_t ict_to_utf8;
 iconv_t ict_utf8_to_game;

 std::string GameCode;

 PromptType InPrompt;

 MemDebuggerPrompt *myprompt;
 SDL_Keycode PromptTAKC;

 friend class MemDebuggerPrompt;
};

#endif
