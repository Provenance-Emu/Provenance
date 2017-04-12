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

#include <stdarg.h>
#include <string.h>
#include <zlib.h>
#include <string>
#include <math.h>
#include <trio/trio.h>

#include <vector>
#include <list>
#include <map>

#include "netplay.h"
#include "netplay-driver.h"
#include "general.h"
#include "string/trim.h"
#include "state.h"
#include "movie.h"
#include <mednafen/hash/md5.h>
#include "mempatcher.h"

#include "MemoryStream.h"

#include "driver.h"

int MDFNnetplay=0;

static std::map<std::string, uint32> PlayersList;
static char *OurNick = NULL;

static bool Joined = false;
static uint32 LocalPlayersMask = 0;
static uint32 LocalInputStateSize = 0;
static uint32 TotalInputStateSize = 0;
static uint8 PortVtoLVMap[16];
static uint8 PortLVtoVMap[16];
static std::vector<uint8> PreNPPortDataPortData[16];
static std::vector<uint8> PostEmulatePortData[16];
static bool StateLoaded;	// Set to true/false in Netplay_Update() call paths, used in Netplay_PostProcess()
				// to determine where to pull switch data from.

static std::unique_ptr<uint8[]> incoming_buffer;	// TotalInputStateSize + 1
static std::unique_ptr<uint8[]> outgoing_buffer;	// 1 + LocalInputStateSize + 4

static void RebuildPortVtoVMap(const uint32 PortDevIdx[])
{
 const unsigned NumPorts = MDFNGameInfo->PortInfo.size();

 memset(PortVtoLVMap, 0xFF, sizeof(PortVtoLVMap));
 memset(PortLVtoVMap, 0xFF, sizeof(PortLVtoVMap));

 for(unsigned x = 0; x < NumPorts; x++)
 {
  if(LocalPlayersMask & (1U << x))
  {
   for(unsigned n = 0; n <= x; n++)
   {
    auto const* IDII_N = &MDFNGameInfo->PortInfo[n].DeviceInfo[PortDevIdx[n]].IDII;
    auto const* IDII_X = &MDFNGameInfo->PortInfo[x].DeviceInfo[PortDevIdx[x]].IDII;

    if(PortLVtoVMap[n] == 0xFF && IDII_N == IDII_X)
    {
     PortLVtoVMap[n] = x;
     PortVtoLVMap[x] = n;
     break;
    }
   }
  }
 }
}

static void SetLPM(const uint32 v, const uint32 PortDevIdx[], const uint32 PortLen[])
{
 LocalPlayersMask = v;
 LocalInputStateSize = 0; 

 for(unsigned x = 0; x < MDFNGameInfo->PortInfo.size(); x++)
 {
  if(LocalPlayersMask & (1U << x))
   LocalInputStateSize += PortLen[x];
 }

 outgoing_buffer.reset(nullptr);
 outgoing_buffer.reset(new uint8[1 + LocalInputStateSize + 4]);

 RebuildPortVtoVMap(PortDevIdx);
}


static void NetError(const char *format, ...)
{
 char *temp = NULL;
 va_list ap;

 va_start(ap, format);
 temp = trio_vaprintf(format, ap);
 va_end(ap);

 MDFND_NetplayText(temp, FALSE);
 MDFND_NetworkClose();
 free(temp);
}

static void NetPrintText(const char *format, ...)
{
 char *temp = NULL;
 va_list ap;

 va_start(ap, format);
 temp = trio_vaprintf(format, ap);
 va_end(ap);

 MDFND_NetplayText(temp, FALSE);
 free(temp);
}


void MDFNI_NetplayStop(void)
{
	if(MDFNnetplay)
	{
	 Joined = false;
	 MDFNnetplay = 0;
 	 MDFN_FlushGameCheats(1);	/* Don't save netplay cheats. */
 	 MDFN_LoadGameCheats(0);		/* Reload our original cheats. */
	 if(OurNick)
	 {
	  free(OurNick);
	  OurNick = NULL;
	 }
	 PlayersList.clear();
	 incoming_buffer.reset(nullptr);
	 outgoing_buffer.reset(nullptr);
	}
	else puts("Check your code!");
}

struct login_data_t
{
 uint8 gameid[16];
 uint8 password[16];

 uint8 protocol_version;
 uint8 total_controllers;
 uint8 padding0[2];

 uint8 emu_name_len[4];			// Length of emulator name and version string(up to 64 bytes) - (note that any non-0
					// bytes < 0x20 in this string will be replaced by 0x20).

 uint8 padding1[8];

 uint8 controller_data_size[16];

 uint8 padding3[16];

 uint8 controller_type[16];

 uint8 local_players;
};

#if 0
// WIP, mostly just ideas now, nothing to justify implementing it.
struct p4_login_data_t
{
 uint8 magic[16];		// MEDNAFEN_NETPLAY
 uint8 protocol_version[4];	// uint32

 //
 //
 //
 uint8 password[16];		//
 uint8 nickname[256];		//

 //
 //
 //
 uint8 game_id[32];
 uint8 emu_id[256];

 uint8 total_controllers;	// Total number of controllers(max 32)
 uint8 controller_type[32];
 uint8 controller_data_size[32];
 uint8 local_controllers;	// Number of local controllers.
};
#endif

int NetplayStart(const uint32 PortDeviceCache[16], const uint32 PortDataLenCache[16])
{
 try
 {
  const char *emu_id = PACKAGE " " MEDNAFEN_VERSION;
  const uint32 local_players = MDFN_GetSettingUI("netplay.localplayers");
  const std::string nickname = MDFN_GetSettingS("netplay.nick");
  const std::string game_key = MDFN_GetSettingS("netplay.gamekey");
  const std::string connect_password = MDFN_GetSettingS("netplay.password");
  login_data_t *ld = NULL;
  std::vector<uint8> sendbuf;

  PlayersList.clear();
  MDFNnetplay = true;

  sendbuf.resize(4 + sizeof(login_data_t) + nickname.size() + strlen(emu_id));

  MDFN_en32lsb(&sendbuf[0], sendbuf.size() - 4);
  ld = (login_data_t*)&sendbuf[4];

  if(game_key != "")
  {
   md5_context md5;
   uint8 md5out[16];

   md5.starts();
   md5.update(MDFNGameInfo->MD5, 16);
   md5.update((uint8 *)game_key.c_str(), game_key.size());
   md5.finish(md5out);
   memcpy(ld->gameid, md5out, 16);
  }
  else
   memcpy(ld->gameid, MDFNGameInfo->MD5, 16);

  if(connect_password != "")
  {
   md5_context md5;
   uint8 md5out[16];

   md5.starts();
   md5.update((uint8*)connect_password.c_str(), connect_password.size());
   md5.finish(md5out);
   memcpy(ld->password, md5out, 16);
  }

  assert(MDFNGameInfo->PortInfo.size() <= 16);

  ld->protocol_version = 3;

  // Set input device number thingies here.
  ld->total_controllers = MDFNGameInfo->PortInfo.size(); // Total number of ports

  MDFN_en32lsb(ld->emu_name_len, strlen(emu_id));

  // Controller data sizes.
  for(unsigned x = 0; x < MDFNGameInfo->PortInfo.size(); x++)
   ld->controller_data_size[x] = PortDataLenCache[x];

  // Controller types
  for(unsigned x = 0; x < MDFNGameInfo->PortInfo.size(); x++)
   ld->controller_type[x] = PortDeviceCache[x];	// FIXME: expand controller_type from 8-bit -> 32-bit

  ld->local_players = local_players;

  if(nickname != "")
   memcpy(&sendbuf[4 + sizeof(login_data_t)], nickname.c_str(), nickname.size());

  memcpy(&sendbuf[4 + sizeof(login_data_t) + nickname.size()], emu_id, strlen(emu_id));

  MDFND_SendData(&sendbuf[0], sendbuf.size());

  TotalInputStateSize = 0;
  for(unsigned x = 0; x < MDFNGameInfo->PortInfo.size(); x++)
    TotalInputStateSize += PortDataLenCache[x];

  // Hack so the server can always encode its command data length properly(a matching "hack" exists in the server).
  if(TotalInputStateSize < 4)
   TotalInputStateSize = 4;

  incoming_buffer.reset(nullptr);
  incoming_buffer.reset(new uint8[TotalInputStateSize + 1]);

  SetLPM(0, PortDeviceCache, PortDataLenCache);
  Joined = false;

  //
  //
  //
  for(unsigned x = 0; x < MDFNGameInfo->PortInfo.size(); x++)
  {
   PreNPPortDataPortData[x].assign(PortDataLenCache[x], 0);
   PostEmulatePortData[x].assign(PortDataLenCache[x], 0);
  }

  MDFN_FlushGameCheats(0);	/* Save our pre-netplay cheats. */

  if(MDFNMOV_IsPlaying())		/* Recording's ok during netplay, playback is not. */
   MDFNMOV_Stop();
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
  return(false);
 }

 //printf("%d\n", TotalInputStateSize);

 return(1);
}

static void SendCommand(uint8 cmd, uint32 len, const void* data = NULL)
{
 outgoing_buffer[0] = cmd;
 memset(&outgoing_buffer[1], 0, LocalInputStateSize);
 MDFN_en32lsb(&outgoing_buffer[1 + LocalInputStateSize], len);
 MDFND_SendData(&outgoing_buffer[0], LocalInputStateSize + 1 + 4);

 if(data != NULL)
 {
  MDFND_SendData(data, len);
 }
}

bool NetplaySendCommand(uint8 cmd, uint32 len, const void* data)
{
 try
 {
  SendCommand(cmd, len, data);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
  return(false);
 }
 return(true);
}

static std::string GenerateMPSString(uint32 mps, bool ctlr_string = false)
{
 char tmpbuf[256];

 tmpbuf[0] = 0;

 if(!mps)
 {
  if(!ctlr_string)
   trio_snprintf(tmpbuf, sizeof(tmpbuf), _("a lurker"));
 }
 else
  trio_snprintf(tmpbuf, sizeof(tmpbuf), ("%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s"), ctlr_string ? ((mps == round_up_pow2(mps)) ? _("controller") : _("controllers")) : ((mps == round_up_pow2(mps)) ? _("player") : _("players")),
				       (mps & 0x0001) ? " 1" : "",
				       (mps & 0x0002) ? " 2" : "",
				       (mps & 0x0004) ? " 3" : "",
				       (mps & 0x0008) ? " 4" : "",
                                       (mps & 0x0010) ? " 5" : "",
                                       (mps & 0x0020) ? " 6" : "",
                                       (mps & 0x0040) ? " 7" : "",
                                       (mps & 0x0080) ? " 8" : "",
                                       (mps & 0x0100) ? " 9" : "",
                                       (mps & 0x0200) ? " 10" : "",
                                       (mps & 0x0400) ? " 11" : "",
                                       (mps & 0x0800) ? " 12" : "",
                                       (mps & 0x1000) ? " 13" : "",
                                       (mps & 0x2000) ? " 14" : "",
                                       (mps & 0x4000) ? " 15" : "",
                                       (mps & 0x8000) ? " 16" : "");


 return(std::string(tmpbuf));
}

static void MDFNI_NetplaySwap(uint8 a, uint8 b)
{
 try
 {
  SendCommand(MDFNNPCMD_CTRLR_SWAP, (a << 0) | (b << 8));
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

static void MDFNI_NetplayTake(uint32 mask)
{
 try
 {
  SendCommand(MDFNNPCMD_CTRLR_TAKE, mask);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

static void MDFNI_NetplayDrop(uint32 mask)
{
 try
 {
  SendCommand(MDFNNPCMD_CTRLR_DROP, mask);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

static void MDFNI_NetplayDupe(uint32 mask)
{
 try
 {
  SendCommand(MDFNNPCMD_CTRLR_DUPE, mask);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

static void MDFNI_NetplayList(void)
{
 try
 {
  for(auto& it : PlayersList)
  {
   NetPrintText(_("** <%s> is %s"), it.first.c_str(), GenerateMPSString(it.second).c_str());
  }
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}


static void MDFNI_NetplayPing(void)
{
 try
 {
  uint64 now_time;

  now_time = MDFND_GetTime();

  // Endianness doesn't matter, since it will be echoed back only to us.
  SendCommand(MDFNNPCMD_ECHO, sizeof(now_time), &now_time);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}
#if 0
static void MDFNI_NetplayIntegrity(void)
{
 try
 {
  SendCommand(MDFNNPCMD_INTEGRITY, 0);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}
#endif
static void MDFNI_NetplayText(const char *text)
{
 try
 {
  uint32 len;

  if(!Joined) return;

  len = strlen(text);

  SendCommand(MDFNNPCMD_TEXT, len, text);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

static void MDFNI_NetplayChangeNick(const char* newnick)
{
 try
 {
  uint32 len;

  if(!Joined) return;

  len = strlen(newnick);

  SendCommand(MDFNNPCMD_SETNICK, len, newnick);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

static void MDFNI_NetplayQuit(const char *quit_message)
{
 try
 {
  SendCommand(MDFNNPCMD_QUIT, strlen(quit_message), quit_message);
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}


//
// Integrity checking is experimental, and needs work to function properly(in the emulator cores).
//
static int SendIntegrity(void)
{
 MemoryStream sm(65536);
 md5_context md5;
 uint8 digest[16];

 // Do not do a raw/data-only state for speed, due to lack of endian and bool conversion.
 MDFNSS_SaveSM(&sm, false);

 md5.starts();
 md5.update(sm.map(), sm.size());
 md5.finish(digest);

 SendCommand(MDFNNPCMD_INTEGRITY_RES, 16, digest);

 return(1);
}


static void SendState(void)
{
 std::vector<uint8> cbuf;
 uLongf clen;

 {
  MemoryStream sm(65536);

  MDFNSS_SaveSM(&sm, false);

  clen = sm.size() + sm.size() / 1000 + 12;
  cbuf.resize(4 + clen);
  MDFN_en32lsb(&cbuf[0], sm.size());
  compress2((Bytef *)&cbuf[0] + 4, &clen, (Bytef *)sm.map(), sm.size(), 7);
 }

 SendCommand(MDFNNPCMD_LOADSTATE, clen + 4, &cbuf[0]);
}

static void RecvState(const uint32 clen)
{
 std::vector<uint8> cbuf;

 if(clen < 4)
 {
  throw MDFN_Error(0, _("Compressed save state data is too small: %u"), clen);
 }

 if(clen > 8 * 1024 * 1024) // Compressed length sanity check - 8 MiB max.
 {
  throw MDFN_Error(0, _("Compressed save state data is too large: %u"), clen);
 }

 cbuf.resize(clen);

 MDFND_RecvData(&cbuf[0], clen);

 uLongf len = MDFN_de32lsb(&cbuf[0]);
 if(len > 12 * 1024 * 1024) // Uncompressed length sanity check - 12 MiB max.
 {
  throw MDFN_Error(0, _("Uncompressed save state data is too large: %llu"), (unsigned long long)len);
 }

 MemoryStream sm(len, -1);

 uncompress((Bytef *)sm.map(), &len, (Bytef *)&cbuf[0] + 4, clen - 4);

 MDFNSS_LoadSM(&sm, false);

 if(MDFNMOV_IsRecording())
  MDFNMOV_RecordState();
}

void NetplaySendState(void)
{
 try
 {
  SendState();
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

static void ProcessCommand(const uint8 cmd, const uint32 raw_len, const uint32 PortDevIdx[], uint8* const PortData[], const uint32 PortLen[], int NumPorts)
{
  switch(cmd)
  {
   case 0: break; // No command

   default: MDFN_DoSimpleCommand(cmd);
	    break;

   case MDFNNPCMD_INTEGRITY:
			SendIntegrity();
			break;

   case MDFNNPCMD_REQUEST_STATE:
			SendState();
	  	 	break;

   case MDFNNPCMD_LOADSTATE:
			RecvState(raw_len);
			StateLoaded = true;
			MDFN_DispMessage(_("Remote state loaded."));
			break;

   case MDFNNPCMD_SET_MEDIA:
			{
			 uint8 buf[4 * 4];

			 MDFND_RecvData(buf, sizeof(buf));

			 MDFN_UntrustedSetMedia(MDFN_de32lsb(&buf[0]), MDFN_de32lsb(&buf[4]), MDFN_de32lsb(&buf[8]), MDFN_de32lsb(&buf[12]));
			}
			break;

   case MDFNNPCMD_SERVERTEXT:
			{
			 static const uint32 MaxLength = 2000;
                         uint8 neobuf[MaxLength + 1];
                         char *textbuf = NULL;
                         const uint32 totallen = raw_len;

                         if(totallen > MaxLength) // Sanity check
                         {
                          throw MDFN_Error(0, _("Text length is too long: %u"), totallen);
                         }

                         MDFND_RecvData(neobuf, totallen);

			 neobuf[totallen] = 0;
			 trio_asprintf(&textbuf, "** %s", neobuf);
                         MDFND_NetplayText(textbuf, FALSE);
                         free(textbuf);
			}
			break;

   case MDFNNPCMD_ECHO:
			{
                         uint32 totallen = raw_len;
			 uint64 then_time;
			 uint64 now_time;

			 if(totallen != sizeof(then_time))
			 {
                          throw MDFN_Error(0, _("Echo response length is incorrect size: %u"), totallen);
			 }

                         MDFND_RecvData(&then_time, sizeof(then_time));

			 now_time = MDFND_GetTime();

                         char *textbuf = NULL;
			 trio_asprintf(&textbuf, _("*** Round-trip time: %llu ms"), (unsigned long long)(now_time - then_time));
                         MDFND_NetplayText(textbuf, FALSE);
                         free(textbuf);
			}
			break;

   case MDFNNPCMD_TEXT:
			{
			 static const uint32 MaxLength = 2000;
			 char neobuf[MaxLength + 1];
			 const uint32 totallen = raw_len;
                         uint32 nicklen;
                         bool NetEcho = false;
                         char *textbuf = NULL;

			 if(totallen < 4)
			 {
			  throw MDFN_Error(0, _("Text command length is too short: %u"), totallen);
	  		 }

			 if(totallen > MaxLength) // Sanity check
			 {
                          throw MDFN_Error(0, _("Text command length is too long: %u"), totallen);
			 }

			 MDFND_RecvData(neobuf, totallen);

			 nicklen = MDFN_de32lsb(neobuf);
			 if(nicklen > (totallen - 4)) // Sanity check
			 {
			  throw MDFN_Error(0, _("Received nickname length is too long: %u"), nicklen);
			 }

                         neobuf[totallen] = 0;

			 if(nicklen)
			 {
			  memmove(neobuf, neobuf + 4, nicklen);
			  neobuf[nicklen] = 0;

			  if(OurNick && !strcasecmp(OurNick, neobuf))
			  {
                           trio_asprintf(&textbuf, "> %s", &neobuf[4 + nicklen]);
			   NetEcho = true;
			  }
			  else
			   trio_asprintf(&textbuf, "<%s> %s", neobuf, &neobuf[4 + nicklen]);
			 }
		         else
			 {
			  trio_asprintf(&textbuf, "* %s", &neobuf[4]);
			 }
                         MDFND_NetplayText(textbuf, NetEcho);
			 free(textbuf);
			}
			break;

   case MDFNNPCMD_NICKCHANGED:
			{
			 static const uint32 MaxLength = 2000;
                         uint8 neobuf[MaxLength + 1];
                         uint8 *newnick;
                         char *textbuf = NULL;
			 const uint32 len = raw_len;

                         if(len > MaxLength) // Sanity check
                         {
                          throw MDFN_Error(0, _("Nickname change length is too long: %u"), len);
                         }

                         MDFND_RecvData(neobuf, len);

			 neobuf[len] = 0;

			 newnick = (uint8*)strchr((char*)neobuf, '\n');

			 if(newnick)
			 {
			  bool IsMeow = FALSE;
			  *newnick = 0;
			  newnick++;
			  if(OurNick)
			  {
			   if(!strcasecmp((char*)neobuf, (char*)OurNick))
			   {
			    free(OurNick);
			    OurNick = strdup((char*)newnick);
			    textbuf = trio_aprintf(_("* You are now known as <%s>."), newnick);
			    IsMeow = TRUE;
			   }
			  }
			  if(!textbuf)
			   textbuf = trio_aprintf(_("* <%s> is now known as <%s>"), neobuf, newnick);
                          MDFND_NetplayText(textbuf, IsMeow);
			  free(textbuf);

			  // Update players list.
			  {
			   const std::string ons = std::string((const char*)neobuf);
			   const std::string nns = std::string((const char*)newnick);

			   if(ons != nns)
			   {
	 	 	    auto ons_it = PlayersList.find(ons);
			    auto nns_it = PlayersList.find(nns);

			    if(ons_it == PlayersList.end() || nns_it != PlayersList.end())
			     MDFND_NetplayText(_("[BUG] Players list state out of sync."), false);
			    else
			    {
			     PlayersList[nns] = ons_it->second;
			     PlayersList.erase(ons_it);
			    }
			   }
			  }
			 }
			}
			break;

    case MDFNNPCMD_CTRL_CHANGE:
			{
			 const uint32 len = raw_len;

			 //
                         // Joined = true;
                         SendCommand(MDFNNPCMD_CTRL_CHANGE_ACK, len);
			 //
			 //
                         LocalInputStateSize = 0;
			 SetLPM(len, PortDevIdx, PortLen);
			}
			break;

   case MDFNNPCMD_CTRLR_SWAP_NOTIF:
			{
			 const uint32 cm = raw_len;
			 char textbuf[512];
			 const uint8 c0 = cm & 0xFF;
			 const uint8 c1 = (cm >> 8) & 0xFF;

			 trio_snprintf(textbuf, sizeof(textbuf), _("* All instances of controllers %u and %u have been swapped."), c0 + 1, c1 + 1);
			 MDFND_NetplayText(textbuf, false);

			 for(auto& it : PlayersList)
			 {
			  uint32 mps = it.second;
			  bool c0b, c1b;

			  // Grab bits first before any clearing.
		 	  c0b = ((c0 < sizeof(mps) * 8) ? ((mps >> c0) & 1) : false);
			  c1b = ((c1 < sizeof(mps) * 8) ? ((mps >> c1) & 1) : false);

			  if(c0 < sizeof(mps) * 8)
			  {
			   mps &= ~((uint32)1 << c0);
			   mps |= (uint32)c1b << c0;
			  }
			  
			  if(c1 < sizeof(mps) * 8)
			  {
			   mps &= ~((uint32)1 << c1);
			   mps |= (uint32)c0b << c1;
			  }

			  it.second = mps;
			 }
			}
			break;

   case MDFNNPCMD_CTRLR_TAKE_NOTIF:
   case MDFNNPCMD_CTRLR_DROP_NOTIF:
   case MDFNNPCMD_CTRLR_DUPE_NOTIF:
			{
			 static const uint32 MaxNicknameLength = 1000;
			 static const uint32 MaxLength = 12 + MaxNicknameLength;
			 const char *fstr = NULL;
			 const uint32 len = raw_len;
			 uint8 ntf_buf[MaxLength + 1];
			 char *textbuf = NULL;

			 if(len < 12)
			  throw MDFN_Error(0, _("Take/drop/dupe notification is too short: %u"), len);

			 if(len > MaxLength)
			  throw MDFN_Error(0, _("Take/drop/dupe notification is too long: %u"), len);

			 MDFND_RecvData(ntf_buf, len);
			 ntf_buf[len] = 0;

 	 	 	 switch(cmd)
			 {
			  case MDFNNPCMD_CTRLR_TAKE_NOTIF:
			  	fstr = _("* <%s> took all instances of %s, and is now %s.");
				break;

			  case MDFNNPCMD_CTRLR_DUPE_NOTIF:
			 	fstr = _("* <%s> took copies of %s, and is now %s.");
				break;

			  case MDFNNPCMD_CTRLR_DROP_NOTIF:
				fstr = _("* <%s> dropped %s, and is now %s.");
				break;
			 }
                         trio_asprintf(&textbuf, fstr, ntf_buf + 12, GenerateMPSString(MDFN_de32lsb(&ntf_buf[0]), true).c_str(), GenerateMPSString(MDFN_de32lsb(&ntf_buf[4]), false).c_str());
	                 MDFND_NetplayText(textbuf, false);
			 free(textbuf);

			 // Update players list.
			 {
			  auto it = PlayersList.find(std::string((const char*)ntf_buf + 12));

			  if(it == PlayersList.end())
			   MDFND_NetplayText(_("[BUG] Players list state out of sync."), false);
			  else
			   it->second = MDFN_de32lsb(&ntf_buf[4]);
			 }
			}
			break;

   case MDFNNPCMD_YOUJOINED:
   case MDFNNPCMD_YOULEFT:
   case MDFNNPCMD_PLAYERLEFT:
   case MDFNNPCMD_PLAYERJOINED:
			{
			 static const uint32 MaxLength = 2000;
                         uint8 neobuf[MaxLength + 1];
                         char *textbuf = NULL;
			 uint32 mps;
                         std::string mps_string;
			 const uint32 len = raw_len;

			 if(len < 8)
			 {
                          throw MDFN_Error(0, _("Join/Left length is too short: %u"), len);
		         }

                         if(len > MaxLength) // Sanity check
                         {
                          throw MDFN_Error(0, _("Join/Left length is too long: %u"), len);
                         }

                         MDFND_RecvData(neobuf, len);
			 neobuf[len] = 0; // NULL-terminate the string

			 mps = MDFN_de32lsb(&neobuf[0]);

			 mps_string = GenerateMPSString(mps);

			 if(cmd == MDFNNPCMD_YOULEFT)
			 {
			  // Uhm, not supported yet!
			  SetLPM(0, PortDevIdx, PortLen);
			  Joined = FALSE;
			 }
			 else if(cmd == MDFNNPCMD_YOUJOINED)
			 {
			  if(OurNick) // This shouldn't happen, really...
			  {
			   free(OurNick);
			   OurNick = NULL;
			  }
			  OurNick = strdup((char*)neobuf + 8);

                          trio_asprintf(&textbuf, _("* You, %s, have connected as: %s"), neobuf + 8, mps_string.c_str());

			  SetLPM(mps, PortDevIdx, PortLen);
			  Joined = TRUE;

			  SendCommand(MDFNNPCMD_SETFPS, MDFNGameInfo->fps);
			 }
			 else if(cmd == MDFNNPCMD_PLAYERLEFT)
			 {
                                  trio_asprintf(&textbuf, _("* %s(%s) has left"), neobuf + 8, mps_string.c_str());
			 }
			 else
			 {
                                  trio_asprintf(&textbuf, _("* %s has connected as: %s"), neobuf + 8, mps_string.c_str());
			 }

	                 MDFND_NetplayText(textbuf, FALSE);
			 free(textbuf);

			 // Update players list.
			 if(cmd == MDFNNPCMD_YOUJOINED || cmd == MDFNNPCMD_PLAYERJOINED)
			 {
			  PlayersList[std::string((const char*)neobuf + 8)] = mps;
			 }
			 else
			 {
			  auto it = PlayersList.find(std::string((const char*)neobuf + 8));

			  if(it == PlayersList.end())
			   MDFND_NetplayText(_("[BUG] Players list state out of sync."), false);
			  else
			   PlayersList.erase(it);
			 }
			}
			break;
  }
}

#if 0
       for(auto const& idii : *IDII_N)
       {
        if(idii.Type == IDIT_SWITCH)
        {
	 const uint32 cur = BitsExtract(&PortData[n][0], idii.BitOffset, idii.BitSize);
         const uint32 prev = BitsExtract(&PrevPortData[n][0], idii.BitOffset, idii.BitSize);
         const uint32 delta = cur - prev;

	 printf("%d\n", delta);

	 // We mustn't modify PortData with this filter, only outgoing_buffer(because we can load state in the middle of this function,
	 // which will load new port data that doesn't have this filter applied, and things go boom-boom)!
	 BitsIntract(&outgoing_buffer[wpos], idii.BitOffset, idii.BitSize, delta);
        }
       }
#endif

#if 0
    if(LocalPlayersMask & (1 << x))
    {
     for(unsigned n = 0; n <= x; n++)
     {
      auto const* IDII_N = &MDFNGameInfo->PortInfo[n].DeviceInfo[PortDevIdx[n]].IDII;
      auto const* IDII_X = &MDFNGameInfo->PortInfo[x].DeviceInfo[PortDevIdx[x]].IDII;

      if(!Taken[n] && IDII_N == IDII_X)
      {
       memcpy(outgoing_buffer + wpos, PortData[n], PortLen[n]);
       Taken[n] = TRUE;
       wpos += PortLen[n];
       break;
      }
     }
    }
#endif

void Netplay_Update(const uint32 PortDevIdx[], uint8* const PortData[], const uint32 PortLen[])
{
 const unsigned NumPorts = MDFNGameInfo->PortInfo.size();

 StateLoaded = false;

 try
 {
  //
  //
  //
  if(Joined)
  {
   outgoing_buffer[0] = 0; 	// Not a command

   for(unsigned x = 0, wpos = 1; x < NumPorts; x++)
   {
    if(!PortLen[x])
     continue;

    memcpy(PreNPPortDataPortData[x].data(), PortData[x], PortLen[x]);

    auto n = PortVtoLVMap[x];
    if(n != 0xFF)
    {
     memcpy(&outgoing_buffer[wpos], PortData[n], PortLen[n]);
     wpos += PortLen[n];
    }
   }
   MDFND_SendData(&outgoing_buffer[0], 1 + LocalInputStateSize);
  }
  //
  //
  //
  uint8 cmd;
  uint32 cmd_raw_len;

  do
  {
   MDFND_RecvData(&incoming_buffer[0], TotalInputStateSize + 1);

   cmd = incoming_buffer[TotalInputStateSize];
   cmd_raw_len = MDFN_de32lsb(&incoming_buffer[0]);

   if(cmd != 0)
    ProcessCommand(cmd, cmd_raw_len, PortDevIdx, PortData, PortLen, NumPorts);
  } while(cmd != 0);

  //
  // Update local port data buffers with data received.
  //
  for(unsigned x = 0, rpos = 0; x < NumPorts; x++)
  {
   memcpy(PortData[x], &incoming_buffer[rpos], PortLen[x]);
   rpos += PortLen[x];
  }
 }
 catch(std::exception &e)
 {
  NetError("%s", e.what());
 }
}

void Netplay_PostProcess(const uint32 PortDevIdx[], uint8* const PortData[], const uint32 PortLen[])
{
 const unsigned NumPorts = MDFNGameInfo->PortInfo.size();

 //
 // Make a backup copy of the current port data, then zero the port data(specifically for rumble and status bits).
 //
 for(unsigned x = 0; x < NumPorts; x++)
 {
  if(!PortLen[x])
   continue;

  assert(PostEmulatePortData[x].size() == PortLen[x]);
  assert(PreNPPortDataPortData[x].size() == PortLen[x]);

  memcpy(PostEmulatePortData[x].data(), PortData[x], PortLen[x]);
  memset(PortData[x], 0, PortLen[x]);
 }

 //
 // Remap rumble and status(along with other data that doesn't matter), and copy switch state bits
 // into the current port data from a backup copy saved BEFORE all netplay shenanigans(including load remote save state),
 // as a kludgey way of keeping switches from getting into a delay/feedback loop and going bonkers.
 //
 for(unsigned x = 0; x < NumPorts; x++)
 {
  if(PortLVtoVMap[x] != 0xFF)
   memcpy(PortData[x], PostEmulatePortData[PortLVtoVMap[x]].data(), PortLen[x]);

  for(auto const& idii : MDFNGameInfo->PortInfo[x].DeviceInfo[PortDevIdx[x]].IDII)
  {
   switch(idii.Type)
   {
    default:
	break;
    case IDIT_SWITCH:
	{
	 uint32 tmp;

	 tmp = BitsExtract(PreNPPortDataPortData[x].data(), idii.BitOffset, idii.BitSize);
	 BitsIntract(PortData[x], idii.BitOffset, idii.BitSize, tmp);
	}
	break;
   }
  }
 }
}

//
//
//
//

struct CommandEntry
{
 const char *name;
 bool (*func)(const char* arg);
 const char *help_args;
 const char *help_desc;
};

static bool CC_server(const char *arg);
static bool CC_quit(const char *arg);
static bool CC_help(const char *arg);
static bool CC_nick(const char *arg);
static bool CC_ping(const char *arg);
//static bool CC_integrity(const char *arg);
static bool CC_gamekey(const char *arg);
static bool CC_swap(const char *arg);
static bool CC_dupe(const char *arg);
static bool CC_drop(const char *arg);
static bool CC_take(const char *arg);
static bool CC_list(const char *arg);

static CommandEntry ConsoleCommands[]   =
{
 { "/server", CC_server,	gettext_noop("[REMOTE_HOST] [PORT]"), "Connects to REMOTE_HOST(IP address or FQDN), on PORT." },

 { "/connect", CC_server,	NULL, NULL },

 { "/gamekey", CC_gamekey,	gettext_noop("[GAMEKEY]"), gettext_noop("Changes the game key to the specified GAMEKEY.") },

 { "/quit", CC_quit,		gettext_noop("[MESSAGE]"), gettext_noop("Disconnects from the netplay server.") },

 { "/help", CC_help,		"", gettext_noop("Help, I'm drowning in a sea of cliche metaphors!") },

 { "/nick", CC_nick,		gettext_noop("NICKNAME"), gettext_noop("Changes your nickname to the specified NICKNAME.") },

 { "/swap", CC_swap,		gettext_noop("A B"), gettext_noop("Swap/Exchange all instances of controllers A and B(numbered from 1).") },

 { "/dupe", CC_dupe,            gettext_noop("[A] [...]"), gettext_noop("Duplicate and take instances of specified controller(s).") },
 { "/drop", CC_drop,            gettext_noop("[A] [...]"), gettext_noop("Drop all instances of specified controller(s).") },
 { "/take", CC_take,            gettext_noop("[A] [...]"), gettext_noop("Take all instances of specified controller(s).") },

 { "/list", CC_list,		"", "List players in game." },

 { "/ping", CC_ping,		"", "Pings the server." },

 //{ "/integrity", CC_integrity,	"", "Starts netplay integrity check sequence." },

 { NULL, NULL },
};


static bool CC_server(const char *arg)
{
 char server[300];
 unsigned int port = 0;

 server[0] = 0;

 switch(trio_sscanf(arg, "%299s %u", server, &port))
 {
  default:
  case 0:
	break;

  case 1:
	MDFNI_SetSetting("netplay.host", server);
	break;

  case 2:
	MDFNI_SetSetting("netplay.host", server);
	MDFNI_SetSettingUI("netplay.port", port);
	break;
 }

 MDFND_NetworkConnect();

 return(false);
}

static bool CC_gamekey(const char *arg)
{
 MDFNI_SetSetting("netplay.gamekey", arg);

 if(arg[0] == 0)
  NetPrintText(_("** Game key cleared."));
 else
 {
  NetPrintText(_("** Game key changed to: %s"), arg);
 }

 if(MDFNnetplay)
 {
  NetPrintText(_("** Caution: Changing the game key will not affect the current netplay session."));
 }

// SendCEvent(CEVT_NP_SETGAMEKEY, strdup(arg), NULL);
 return(true);
}

static bool CC_quit(const char *arg)
{
 if(MDFNnetplay)
 {
  MDFNI_NetplayQuit(arg);
  MDFND_NetworkClose();
 }
 else
 {
  NetPrintText(_("*** Not connected!"));
  return(true);
 }

 return(false);
}

static bool CC_list(const char *arg)
{
 if(MDFNnetplay)
  MDFNI_NetplayList();
 else
 {
  NetPrintText(_("*** Not connected!"));
  return(true);
 }

 return(true);
}

static bool CC_swap(const char *arg)
{
 int a = 0, b = 0;

 if(sscanf(arg, "%u %u", &a, &b) == 2 && a && b)
 {
  uint32 sc = ((a - 1) & 0xFF) | (((b - 1) & 0xFF) << 8);

  if(MDFNnetplay)
   MDFNI_NetplaySwap((sc >> 0) & 0xFF, (sc >> 8) & 0xFF);
  else
  {
   NetPrintText(_("*** Not connected!"));
   return(true);
  }
 }
 else
 {
  NetPrintText(_("*** %s command requires at least %u non-zero integer argument(s)."), "SWAP", 2);
  return(true);
 }

 return(false);
}

static bool CC_dupe(const char *arg)
{
 int tmp[32];
 int count;


 memset(tmp, 0, sizeof(tmp));
 count = sscanf(arg, "%u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u",
			&tmp[0x00], &tmp[0x01], &tmp[0x02], &tmp[0x03], &tmp[0x04], &tmp[0x05], &tmp[0x06], &tmp[0x07],
			&tmp[0x08], &tmp[0x09], &tmp[0x0A], &tmp[0x0B], &tmp[0x0C], &tmp[0x0D], &tmp[0x0E], &tmp[0x0F],
                        &tmp[0x00], &tmp[0x01], &tmp[0x02], &tmp[0x03], &tmp[0x04], &tmp[0x05], &tmp[0x06], &tmp[0x07],
                        &tmp[0x08], &tmp[0x09], &tmp[0x0A], &tmp[0x0B], &tmp[0x0C], &tmp[0x0D], &tmp[0x0E], &tmp[0x0F]);

 if(count > 0)
 {
  uint32 mask = 0;

  for(int i = 0; i < 32; i++)
  {
   if(tmp[i] > 0)
    mask |= 1U << (unsigned)(tmp[i] - 1);
  }

  if(MDFNnetplay)
   MDFNI_NetplayDupe(mask);
  else
  {
   NetPrintText(_("*** Not connected!"));
   return(true);
  }
 }
 else
 {
  NetPrintText(_("*** %s command requires at least %u non-zero integer argument(s)."), "DUPE", 1);
  return(true);
 }

 return(false);
}

static bool CC_drop(const char *arg)
{
 int tmp[32];
 int count;


 memset(tmp, 0, sizeof(tmp));
 count = sscanf(arg, "%u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u",
                        &tmp[0x00], &tmp[0x01], &tmp[0x02], &tmp[0x03], &tmp[0x04], &tmp[0x05], &tmp[0x06], &tmp[0x07],
                        &tmp[0x08], &tmp[0x09], &tmp[0x0A], &tmp[0x0B], &tmp[0x0C], &tmp[0x0D], &tmp[0x0E], &tmp[0x0F],
                        &tmp[0x00], &tmp[0x01], &tmp[0x02], &tmp[0x03], &tmp[0x04], &tmp[0x05], &tmp[0x06], &tmp[0x07],
                        &tmp[0x08], &tmp[0x09], &tmp[0x0A], &tmp[0x0B], &tmp[0x0C], &tmp[0x0D], &tmp[0x0E], &tmp[0x0F]);

 if(count > 0)
 {
  uint32 mask = 0;

  for(int i = 0; i < 32; i++)
  {
   if(tmp[i] > 0)
    mask |= 1U << (unsigned)(tmp[i] - 1);
  }

  if(MDFNnetplay)
   MDFNI_NetplayDrop(mask);
  else
  {
   NetPrintText(_("*** Not connected!"));
   return(true);
  }
 }
 else
 {
  NetPrintText(_("*** %s command requires at least %u non-zero integer argument(s)."), "DROP", 1);
  return(true);
 }

 return(false);
}

static bool CC_take(const char *arg)
{
 int tmp[32];
 int count;


 memset(tmp, 0, sizeof(tmp));
 count = sscanf(arg, "%u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u",
                        &tmp[0x00], &tmp[0x01], &tmp[0x02], &tmp[0x03], &tmp[0x04], &tmp[0x05], &tmp[0x06], &tmp[0x07],
                        &tmp[0x08], &tmp[0x09], &tmp[0x0A], &tmp[0x0B], &tmp[0x0C], &tmp[0x0D], &tmp[0x0E], &tmp[0x0F],
                        &tmp[0x00], &tmp[0x01], &tmp[0x02], &tmp[0x03], &tmp[0x04], &tmp[0x05], &tmp[0x06], &tmp[0x07],
                        &tmp[0x08], &tmp[0x09], &tmp[0x0A], &tmp[0x0B], &tmp[0x0C], &tmp[0x0D], &tmp[0x0E], &tmp[0x0F]);

 if(count > 0)
 {
  uint32 mask = 0;

  for(int i = 0; i < 32; i++)
  {
   if(tmp[i] > 0)
    mask |= 1U << (unsigned)(tmp[i] - 1);
  }

  if(MDFNnetplay)
   MDFNI_NetplayTake(mask);
  else
  {
   NetPrintText(_("*** Not connected!"));
   return(true);
  }
 }
 else
 {
  NetPrintText(_("*** %s command requires at least %u non-zero integer argument(s)."), "TAKE", 1);
  return(true);
 }

 return(false);
}

static bool CC_ping(const char *arg)
{
 if(MDFNnetplay)
  MDFNI_NetplayPing();
 else
 {
  NetPrintText(_("*** Not connected!"));
  return(true);
 }

 return(false);
}

#if 0
static bool CC_integrity(const char *arg)
{
 if(MDFNnetplay)
  MDFNI_NetplayIntegrity();
 else
 {
  NetPrintText(_("*** Not connected!"));
  return(true);
 }

 return(FALSE);
}
#endif

static bool CC_help(const char *arg)
{
 for(unsigned int x = 0; ConsoleCommands[x].name; x++)
 {
  if(ConsoleCommands[x].help_desc)
  {
   char help_buf[512];
   trio_snprintf(help_buf, 512, "%s %s  -  %s", ConsoleCommands[x].name, _(ConsoleCommands[x].help_args), _(ConsoleCommands[x].help_desc));
   MDFND_NetplayText(help_buf, false);
  }
 }
 return(true);
}

static bool CC_nick(const char *arg)
{
 MDFNI_SetSetting("netplay.nick", arg);

 if(MDFNnetplay)
  MDFNI_NetplayChangeNick(arg);

 return(true);
}

void MDFNI_NetplayLine(const char *text, bool &inputable, bool &viewable)
{
	 inputable = viewable = false;

         for(unsigned int x = 0; ConsoleCommands[x].name; x++)
	 {
          if(!strncasecmp(ConsoleCommands[x].name, (char*)text, strlen(ConsoleCommands[x].name)) && text[strlen(ConsoleCommands[x].name)] <= 0x20)
          {
	   char *trim_text = strdup((char*)&text[strlen(ConsoleCommands[x].name)]);

	   MDFN_trim(trim_text);

           inputable = viewable = ConsoleCommands[x].func(trim_text);

           free(trim_text);
           return;
          }
	 }

         if(text[0] != 0)	// Is non-empty line?
	 {
	  MDFNI_NetplayText(text);
	  viewable = true;
         }
}
