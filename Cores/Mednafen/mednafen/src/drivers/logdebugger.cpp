/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* logdebugger.cpp:
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

// TODO:  horizontal scrolling

#include "main.h"
#include "logdebugger.h"
#include "debugger.h"
#include "prompt.h"

#include <trio/trio.h>
#include <map>

typedef struct
{
 char *type;
 char *text;
} LogEntry;

class LogInstance
{
 public:

 LogInstance()
 {
  entries.clear();
  LogScroll = 0;
  HScroll = 0;
  MaxWidth = 0;
 }

 ~LogInstance()
 {

 }

 std::vector<LogEntry> entries;
 uint32 LogScroll; 
 uint32 HScroll;
 uint32 MaxWidth;
};

static bool IsActive = FALSE;
static bool LoggingActive = FALSE;

//static std::vector<LogEntry> DeathLog;

static std::map<std::string, LogInstance> NeoDeathLog;

static LogInstance *WhichLog = NULL;

// Called from the game thread.
static void TheLogger(const char *type, const char *text)
{
 LogEntry nle;

 nle.type = strdup(type);
 nle.text = strdup(text);

 NeoDeathLog["All"].entries.push_back(nle);
 NeoDeathLog[std::string(type)].entries.push_back(nle);

 if((WhichLog->entries.size() - WhichLog->LogScroll) == 33)
  WhichLog->LogScroll++;
}


// Call this function from the game thread.
void LogDebugger_SetActive(bool newia)
{
 if(CurGame->Debugger)
 {
  

  IsActive = newia;
  if(newia)
  {
   if(!WhichLog)
   {
    WhichLog = &NeoDeathLog["All"];
   }
  }
  else
  {
   //InEditMode = FALSE;
   //LowNib = FALSE;
  }
 }
}

// Call this function from the game thread
void LogDebugger_Draw(MDFN_Surface *surface, const MDFN_Rect *rect, const MDFN_Rect *screen_rect)
{
 if(!IsActive)
  return;

 //
 //
 //
 const MDFN_PixelFormat pf_cache = surface->format;
 const uint32 lifecolors[4] = {	 pf_cache.MakeColor(0xe0, 0xd0, 0xd0, 0xFF), pf_cache.MakeColor(0xd0, 0xe0, 0xd0, 0xFF),
				 pf_cache.MakeColor(0xd0, 0xd0, 0xEF, 0xFF), pf_cache.MakeColor(0xd4, 0xd4, 0xd4, 0xFF) };
 int32 y = 0;
 char logmessage[256];
 
 trio_snprintf(logmessage, sizeof(logmessage), "%s (%d messages)", LoggingActive ? "Logging Enabled" : "Logging Disabled", (int)WhichLog->entries.size());
 DrawText(surface, 0, y, logmessage, pf_cache.MakeColor(0x20, 0xFF, 0x20, 0xFF), MDFN_FONT_6x13_12x13, rect->w);
 y += 13;

 std::map<std::string, LogInstance>::iterator dl_iter;
 int32 groups_x = 0;

 for(dl_iter = NeoDeathLog.begin(); dl_iter != NeoDeathLog.end(); dl_iter++)
 {
  uint32 group_color = pf_cache.MakeColor(0x80, 0x80, 0x80, 0xFF);
  char group_string[256];

  trio_snprintf(group_string, 256, "%s(%d)", dl_iter->first.c_str(), (int)dl_iter->second.entries.size());

  if(&dl_iter->second == WhichLog)
   group_color = pf_cache.MakeColor(0xFF, 0x80, 0x80, 0xFF);

  groups_x += 6 + DrawText(surface, groups_x, y, group_string, group_color, MDFN_FONT_6x13_12x13);
 }

 y += 13;

 for(uint32 i = WhichLog->LogScroll; i < (WhichLog->LogScroll + 32) && i < WhichLog->entries.size(); i++)
 {
  int32 type_x = 0;
  char tmpbuf[64];

  trio_snprintf(tmpbuf, 64, "%d", i);
  type_x = DrawText(surface, type_x, y, tmpbuf, pf_cache.MakeColor(0x80, 0x80, 0xD0, 0xFF), MDFN_FONT_5x7);
  type_x += 1;
  type_x += DrawText(surface, type_x, y, WhichLog->entries[i].type, pf_cache.MakeColor(0xFF, 0x40, 0x40, 0xFF), MDFN_FONT_6x13_12x13);
  type_x += 5;
  DrawText(surface, type_x, y, WhichLog->entries[i].text, lifecolors[i & 3], MDFN_FONT_6x13_12x13);
  y += 13;
 }
}

static void ChangePos(int64 delta)
{
 int64 NewScroll = (int64)WhichLog->LogScroll + delta;

 if(NewScroll > ((int64)WhichLog->entries.size() - 32))
 {
  NewScroll = (int64)WhichLog->entries.size() - 32;
 }

 if(NewScroll < 0) 
 {
  NewScroll = 0;
 }

 WhichLog->LogScroll = NewScroll;
}

// Warning:  Will only work with +1/-1 deltas for now
static void LogGroupSelect(int delta)
{
 std::map<std::string, LogInstance>::iterator dl_iter;
 std::vector<LogInstance *> acorn_eaters;
 int which = 0;
 int newt;

 for(dl_iter = NeoDeathLog.begin(); dl_iter != NeoDeathLog.end(); dl_iter++)
 {
  if(WhichLog == &dl_iter->second)
   which = acorn_eaters.size();

  acorn_eaters.push_back(&dl_iter->second);
 }

 newt = which + delta;

 if(newt < 0)
 {
  newt += acorn_eaters.size();
 }
 else
  newt %= acorn_eaters.size();

 WhichLog = acorn_eaters[newt];
}


// Call this from the game thread
int LogDebugger_Event(const SDL_Event *event)
{
 switch(event->type)
 {
  case SDL_KEYDOWN:
	switch(event->key.keysym.sym)
	{
	 default: break;

         case SDLK_MINUS: Debugger_GT_ModOpacity(-8);
                          break;
         case SDLK_EQUALS: Debugger_GT_ModOpacity(8);
                           break;


	 case SDLK_HOME: WhichLog->LogScroll = 0; 
			 break;

	 case SDLK_END: ChangePos(1 << 30); 
			break;

	 case SDLK_LEFT:
	 case SDLK_COMMA: 
			 LogGroupSelect(-1); 
			 break;

	 case SDLK_RIGHT:
	 case SDLK_PERIOD: LogGroupSelect(1);
			   break;

	 case SDLK_UP: ChangePos(-1); 
		       break;

	 case SDLK_DOWN: ChangePos(1); 
			 break;

	 case SDLK_PAGEUP: ChangePos(-32); 
			   break;

	 case SDLK_PAGEDOWN: ChangePos(32); 
			     break;

	 case SDLK_t:LoggingActive = !LoggingActive;
		     if(CurGame->Debugger->SetLogFunc)
			CurGame->Debugger->SetLogFunc(LoggingActive ? TheLogger : NULL);
		     break;
	}
	break;

 }

 return(1);
}

