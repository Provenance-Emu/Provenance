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
#include <stdarg.h>

#include <string.h>
#include <math.h>
#include "netplay.h"
#include "console.h"

#include <trio/trio.h>

#include "NetClient.h"

#ifdef HAVE_POSIX_SOCKETS
#include "NetClient_POSIX.h"
#endif

#ifdef WIN32
#include "NetClient_WS2.h"
#endif

static NetClient *Connection = NULL;


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

NetplayConsole::NetplayConsole(void)
{

}

// Called from main thread
bool NetplayConsole::TextHook(const std::string &text)
{
	LastTextTime = SDL_GetTicks();

	SendCEvent(CEVT_NP_LINE, strdup(text.c_str()), NULL);

	return(1);
}

// Call from game thread
static void PrintNetStatus(const char *s)
{
 MDFND_NetplayText(s, FALSE);
}

// Call from game thread
static void PrintNetError(const char *format, ...)
{
 char *temp;

 va_list ap;

 va_start(ap, format);

 temp = trio_vaprintf(format, ap);
 MDFND_NetplayText(temp, FALSE);
 free(temp);

 va_end(ap);
}

// Called from game thread
int MDFND_NetworkConnect(void)
{
 std::string remote_host = MDFN_GetSettingS("netplay.host");
 unsigned int remote_port = MDFN_GetSettingUI("netplay.port");

 if(Connection)
 {
  MDFND_NetworkClose();
 }

 try
 {
  #ifdef HAVE_POSIX_SOCKETS
  Connection = new NetClient_POSIX();
  #elif defined(WIN32)
  Connection = new NetClient_WS2();
  #else
  throw MDFN_Error(0, _("Networking system API support not compiled in."));
  #endif
  Connection->Connect(remote_host.c_str(), remote_port);
 }
 catch(std::exception &e)
 {
  PrintNetError("%s", e.what());
  return(0);
 }

 PrintNetStatus(_("*** Sending initialization data to server."));

 MDFNDnetplay = 1;
 if(!MDFNI_NetplayStart())
 {
  MDFNDnetplay = 0;
  return(0);
 }
 PrintNetStatus(_("*** Connection established."));

 return(1);
}

// Called from game thread
void MDFND_SendData(const void *data, uint32 len)
{
 do
 {
  int32 sent = Connection->Send(data, len);
  assert(sent >= 0);

  data = (uint8*)data + sent;
  len -= sent;

  if(len)
  {
   if(MainExitPending())
    throw MDFN_Error(0, _("Mednafen exit pending."));

   Connection->CanSend(50000);
  }
 } while(len);
}

void MDFND_RecvData(void *data, uint32 len)
{
 NoWaiting &= ~2;

 do
 {
  int32 received = Connection->Receive(data, len);
  assert(received >= 0);

  data = (uint8*)data + received;
  len -= received;

  if(len)
  {
   if(MainExitPending())
    throw MDFN_Error(0, _("Mednafen exit pending."));

   Connection->CanReceive(50000);
  }
 } while(len);

 if(Connection->CanReceive())
  NoWaiting |= 2;
}

// Called from the game thread
void MDFND_NetworkClose(void)
{
 NoWaiting &= ~2;

 if(Connection)
 {
  delete Connection;
  Connection = NULL;
 }

 if(MDFNDnetplay)
 {
  MDFNI_NetplayStop();
  MDFNDnetplay = 0;
  PrintNetStatus(_("*** Disconnected"));
 }
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
 else if(LastTextTime > 0 && (int64)SDL_GetTicks() < (LastTextTime + PopupTime + 500)) // Allow some extra time if a user tries to escape away an auto popup box but misses
 {
  return(TRUE);
 }
 else
 {
  return(FALSE);
 }
}

// Called from main thread
void DrawNetplayTextBuffer(MDFN_Surface *surface, const MDFN_Rect *src_rect)
{
 if(!viewable) 
 {
  return;
 }
 if(!inputable)
 {
  if((int64)SDL_GetTicks() >= (LastTextTime + PopupTime))
  {
   viewable = 0;
   return;
  }
 }
 NetConsole.ShowPrompt(inputable);
 NetConsole.Draw(surface, src_rect);
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
          LastTextTime = SDL_GetTicks();
	 }
	}
	break;

   case CEVT_NP_TOGGLE_TT:
	NetConsole.SetFont(MDFN_GetSettingB("netplay.smallfont") ? MDFN_FONT_5x7 : MDFN_FONT_9x18_18x18);	// FIXME: Setting manager mutex needed example!
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
	 LastTextTime = SDL_GetTicks();
	}
	break;
  }

 if(!inputable)
  return(1);

 return(NetConsole.Event(event));
}

// Called from game thread
int NetplayEventHook_GT(const SDL_Event *event)
{
 if(event->type == SDL_USEREVENT)
 {
  switch(event->user.code)
  {
   case CEVT_NP_LINE:
	{
	 bool inputable_tmp = false, viewable_tmp = false;

	 MDFNI_NetplayLine((const char*)event->user.data1, inputable_tmp, viewable_tmp);
	 free(event->user.data1);

	 SendCEvent(CEVT_NP_LINE_RESPONSE, (void*)inputable_tmp, (void*)viewable_tmp);
	}
	break;
  }
 }
 return(1);
}


