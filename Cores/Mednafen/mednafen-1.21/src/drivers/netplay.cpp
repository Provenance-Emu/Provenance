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

// FIXME: Minor memory leaks may occur on errors(strdup'd, malloc'd, and new'd memory used in inter-thread messages)

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif
#include "main.h"

#include "netplay.h"
#include "console.h"

#include <trio/trio.h>

#include "video.h"
#include "input.h"

#include <mednafen/AtomicFIFO.h>


static AtomicFIFO<char*, 128> LineFIFO;

class NetplayConsole : public MDFNConsole
{
        public:
        NetplayConsole(void);

        private:
        virtual bool TextHook(const std::string &text) override;
};

static NetplayConsole NetConsole;
static const int PopupTime = 3750;

static int volatile inputable = 0;
static int volatile viewable = 0;
static int64 LastTextTime = -1;

int MDFNDnetplay = 0;  // Only write/read this global variable in the game thread.
static uint32 lpm;

NetplayConsole::NetplayConsole(void)
{

}

// Called from main thread
bool NetplayConsole::TextHook(const std::string &text)
{
	LastTextTime = Time::MonoMS();

	if(LineFIFO.CanWrite())
         LineFIFO.Write(strdup(text.c_str()));

	return(1);
}

// Called from game thread
uint32 Netplay_GetLPM(void)
{
 if(!MDFNDnetplay)
  return ~(uint32)0;

 return lpm;
}

// Called from game thread
void MDFND_NetplaySetHints(bool active, bool behind, uint32 local_players_mask)
{
 if(!MDFNDnetplay && active)
  DoRunNormal();

 if(MDFNDnetplay != active || lpm != local_players_mask)
 {
  MDFNDnetplay = active;
  lpm = local_players_mask;
  //
  Input_NetplayLPMChanged();	// Will call Netplay_GetLPM(), so make sure variables are assigned beforehand.
 }

 NoWaiting &= ~2;
 if(active && behind)
  NoWaiting |= 2;
 //printf("Hint: %d, %d\n", active, behind);
}

// Called from the game thread
void MDFND_NetplayText(const char* text, bool NetEcho)
{
 char *tot = strdup(text);
 char *tmp;

 tmp = tot;

 while(*tmp)
 {
  if((uint8)*tmp < 0x20)
   *tmp = ' ';
  tmp++;
 }

 SendCEvent(CEVT_NP_DISPLAY_TEXT, tot, (void*)NetEcho);
}

// Called from the game thread
void Netplay_ToggleTextView(void)
{
 SendCEvent(CEVT_NP_TOGGLE_TT, NULL, NULL);
}

// Called from main thread
int Netplay_GetTextView(void)
{
 return(viewable);
}

// Called from main thread and game thread
bool Netplay_IsTextInput(void)
{
 return(inputable);
}

// Called from the main thread
bool Netplay_TryTextExit(void)
{
 if(viewable || inputable)
 {
  viewable = FALSE;
  inputable = FALSE;
  LastTextTime = -1;
  return(TRUE);
 }
 else if(LastTextTime > 0 && (int64)Time::MonoMS() < (LastTextTime + PopupTime + 500)) // Allow some extra time if a user tries to escape away an auto popup box but misses
 {
  return(TRUE);
 }
 else
 {
  return(FALSE);
 }
}

// Called from main thread
void Netplay_MT_Draw(const MDFN_PixelFormat& pformat, const int32 screen_w, const int32 screen_h)
{
 if(!viewable) 
  return;

 if(!inputable)
 {
  if((int64)Time::MonoMS() >= (LastTextTime + PopupTime))
  {
   viewable = 0;
   return;
  }
 }
 NetConsole.ShowPrompt(inputable);
 //
 {
  const unsigned fontid = MDFN_GetSettingUI("netplay.console.font");
  const int32 lines = MDFN_GetSettingUI("netplay.console.lines");
  int32 scale = MDFN_GetSettingUI("netplay.console.scale");
  MDFN_Rect srect;
  MDFN_Rect drect;

  if(!scale)
   scale = std::min<int32>(std::max<int32>(1, screen_h / 500), std::max<int32>(1, screen_w / 500));

  srect.x = srect.y = 0;
  srect.w = screen_w / scale;
  srect.h = GetFontHeight(fontid) * lines;

  drect.x = 0;
  drect.y = screen_h - (srect.h * scale);
  drect.w = srect.w * scale;
  drect.h = srect.h * scale;

  BlitRaw(NetConsole.Draw(pformat, srect.w, srect.h, fontid), &srect, &drect);
 }
}

// Called from main thread
int NetplayEventHook(const SDL_Event *event)
{
 if(event->type == SDL_USEREVENT)
  switch(event->user.code)
  {
   case CEVT_NP_LINE_RESPONSE:
	{
	 inputable = (event->user.data1 != NULL);
         if(event->user.data2 != NULL)
	 {
	  viewable = true;
          LastTextTime = Time::MonoMS();
	 }
	}
	break;

   case CEVT_NP_TOGGLE_TT:
	//
	// FIXME: Setting manager mutex needed example!
	//
	if(viewable && !inputable)
	{
	 inputable = TRUE;
	}
	else
	{
	 viewable = !viewable;
	 inputable = viewable;
	}
	break;

   case CEVT_NP_DISPLAY_TEXT:
	NetConsole.WriteLine((char*)event->user.data1);
	free(event->user.data1);

	if(!(bool)event->user.data2)
	{
	 viewable = 1;
	 LastTextTime = Time::MonoMS();
	}
	break;
  }

 if(!inputable)
  return(1);

 return(NetConsole.Event(event));
}

void Netplay_GT_CheckPendingLine(void)
{
 size_t c = LineFIFO.CanRead();

 while(c--)
 {
  char* str = LineFIFO.Read();
  bool inputable_tmp = false, viewable_tmp = false;

  MDFNI_NetplayLine(str, inputable_tmp, viewable_tmp);
  free(str);

  SendCEvent(CEVT_NP_LINE_RESPONSE, (void*)inputable_tmp, (void*)viewable_tmp);
 }
}


