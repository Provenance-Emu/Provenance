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

#include "main.h"
#include <trio/trio.h>
#include <time.h>
#include <map>
#include "debugger.h"
#include "gfxdebugger.h"
#include "memdebugger.h"
#include "logdebugger.h"
#include "prompt.h"
#include "video.h"

static MemDebugger* memdbg = NULL;
static FILE *TraceLog = NULL;
static std::string TraceLogSpec;
static int64 TraceLogEnd;
static unsigned TraceLogRTO;

static bool NeedInit;
static bool WatchLogical; // Watch logical memory addresses, not physical
static bool IsActive;
static bool CompactMode = FALSE;

static unsigned int WhichMode; // 0 = normal, 1 = gfx, 2 = memory

static bool NeedPCBPToggle;
static int NeedStep;	// 0 =, 1 = , 2 = 
static int NeedRun;
static bool InSteppingMode;

static std::vector<uint32> PCBreakPoints;
static std::string ReadBreakpoints, IOReadBreakpoints, AuxReadBreakpoints;
static std::string WriteBreakpoints, IOWriteBreakpoints, AuxWriteBreakpoints;
static std::string OpBreakpoints;

static MDFN_Surface* DebuggerSurface[2] = { NULL, NULL };
static MDFN_Rect DebuggerRect[2];

static int volatile DMTV_BackBuffer;
static MDFN_Surface* volatile DMTV_Surface;
static MDFN_Rect* volatile DMTV_Rect;

//
// Used for translating mouse coordinates and whatnot.  Doesn't really matter if it's not atomically updated, there
// are sanity checks to prevent dividing by zero, and it'll just cause mouse coordinate translation to be wonky for a tiny fraction of a second.
//
static MDFN_Rect volatile dlc_screen_dest_rect = { 0 };

static int DebuggerOpacity;

typedef std::vector<std::string> DisComment;
static std::map<uint64, DisComment> Comments; // Lower 32 bits == address, upper 32 bits == 4 bytes data match

static void CPUCallback(uint32 PC, bool bpoint);	// Called from game thread.

bool Debugger_GT_IsInSteppingMode(void)
{
 return(InSteppingMode);
}

static uint32 GetPC(void)
{
 RegGroupType *rg = (*CurGame->Debugger->RegGroups)[0];

 return rg->GetRegister(rg->Regs[0].id, NULL, 0); // FIXME
}

static void MemPoke(uint32 A, uint32 V, uint32 Size, bool hl, bool logical)
{
 AddressSpaceType *found = NULL;

 if(logical)
 {
  for(unsigned int x = 0; x < CurGame->Debugger->AddressSpaces->size(); x++)
   if((*CurGame->Debugger->AddressSpaces)[x].name == "logical")
   {
    found = &(*CurGame->Debugger->AddressSpaces)[x];
    break;
   }
 }
 else
 {
  for(unsigned int x = 0; x < CurGame->Debugger->AddressSpaces->size(); x++)
   if((*CurGame->Debugger->AddressSpaces)[x].name == "physical")
   {
    found = &(*CurGame->Debugger->AddressSpaces)[x];
    break;
   }
 }

 if(!found)
 {
  for(unsigned int x = 0; x < CurGame->Debugger->AddressSpaces->size(); x++)
   if((*CurGame->Debugger->AddressSpaces)[x].name == "cpu")
   {
    found = &(*CurGame->Debugger->AddressSpaces)[x];
    break;
   }
 }

 if(found)
 {
  uint8 tmp_buffer[4];

  // FIXME if we ever add a non-LSB-first system!
  tmp_buffer[0] = V;
  tmp_buffer[1] = V >> 8;
  tmp_buffer[2] = V >> 16;
  tmp_buffer[3] = V >> 24;
  found->PutAddressSpaceBytes(found->name.c_str(), A, Size, Size, hl, tmp_buffer);
 }
 else
  puts("Error");
}

static unsigned long long ParsePhysAddr(const char *za)
{
 unsigned long long ret = 0;

 if(strchr(za, ':'))
 {
  unsigned int bank = 0, offset = 0;

  if(!strcasecmp(CurGame->shortname, "wswan"))
  {
   trio_sscanf(za, "%04x:%04x", &bank, &offset);
   ret = ((bank << 4) + offset) & 0xFFFFF;
  }
  else
  {
   trio_sscanf(za, "%02x:%04x", &bank, &offset);
   ret = (bank * 8192) | (offset & 0x1FFF);
  }
 }
 else
  trio_sscanf(za, "%llx", &ret);

 return(ret);
}

static void UpdateCoreHooks(void)
{
 bool BPInUse = PCBreakPoints.size() || ReadBreakpoints.size() || WriteBreakpoints.size() || IOReadBreakpoints.size() ||
	IOWriteBreakpoints.size() || AuxReadBreakpoints.size() || AuxWriteBreakpoints.size() || OpBreakpoints.size();
 bool CPUCBNeeded = BPInUse || TraceLog || InSteppingMode || (NeedStep == 2);

 CurGame->Debugger->EnableBranchTrace(BPInUse || TraceLog || IsActive);
 CurGame->Debugger->SetCPUCallback(CPUCBNeeded ? CPUCallback : NULL, TraceLog || InSteppingMode || (NeedStep == 2));
}

static void UpdatePCBreakpoints(void)
{
 CurGame->Debugger->FlushBreakPoints(BPOINT_PC);

 for(unsigned int x = 0; x < PCBreakPoints.size(); x++)
 {
  CurGame->Debugger->AddBreakPoint(BPOINT_PC, PCBreakPoints[x], PCBreakPoints[x], 1);
 }
 UpdateCoreHooks();
}

static INLINE bool IsPCBreakPoint(uint32 A)
{
 unsigned int max = PCBreakPoints.size();

 for(unsigned int x = 0; x < max; x++)
  if(PCBreakPoints[x] == A)
   return(1);
 return(0);
}

static void TogglePCBreakPoint(uint32 A)
{
 for(unsigned int x = 0; x < PCBreakPoints.size(); x++)
 {
  if(PCBreakPoints[x] == A)
  {
   PCBreakPoints.erase(PCBreakPoints.begin() + x);

   UpdatePCBreakpoints();

   return;
  }
 }
 PCBreakPoints.push_back(A);

 UpdatePCBreakpoints();
}

static void UpdateBreakpoints(const std::string &Breakpoints, int type)
{
 size_t len = Breakpoints.size();
 const char *zestring = Breakpoints.c_str();
 unsigned int last_x, x;
 bool two_parter = 0;
 bool logical = 1;

 CurGame->Debugger->FlushBreakPoints(type);

 for(last_x = x = 0; x < len; x++)
 {
  if(zestring[x] == '-')
   two_parter = 1;
  else if(zestring[x] == '*')
  {
   logical = 0;
   last_x++;
  }
  else if(zestring[x] == ' ' || x == len - 1)
  {
   uint32 A1, A2;

   if(two_parter)
   {
    char sa1[64], sa2[64];

    if(!logical)
    {
     if(trio_sscanf(zestring + last_x, "%63[^-]%*[-]%63s", sa1, sa2) < 2) continue;

     //printf("%s %s\n", sa1, sa2);
     A1 = ParsePhysAddr(sa1);
     A2 = ParsePhysAddr(sa2);
    }
    else
     if(trio_sscanf(zestring + last_x, "%x%*[-]%x", &A1, &A2) < 2) continue;

    two_parter = 0;
   }
   else
   {
    if(!logical)
    {
     char sa1[64];

     trio_sscanf(zestring + last_x, "%s", sa1);

     A1 = ParsePhysAddr(sa1);
    }
    else
     if(trio_sscanf(zestring + last_x, "%x", &A1) != 1) continue;

    A2 = A1;
   }
   //printf("%04x %04x %d\n", A1, A2, logical);
   CurGame->Debugger->AddBreakPoint(type, A1, A2, logical);
   last_x = x + 1;
   logical = 1;
  }
 }
 UpdateCoreHooks();
}


static void UpdateBreakpoints(void)
{
 UpdatePCBreakpoints();
 UpdateBreakpoints(ReadBreakpoints, BPOINT_READ);
 UpdateBreakpoints(WriteBreakpoints, BPOINT_WRITE);
 UpdateBreakpoints(IOReadBreakpoints, BPOINT_IO_READ);
 UpdateBreakpoints(IOWriteBreakpoints, BPOINT_IO_WRITE);
 UpdateBreakpoints(AuxReadBreakpoints, BPOINT_AUX_READ);
 UpdateBreakpoints(AuxWriteBreakpoints, BPOINT_AUX_WRITE);
 UpdateBreakpoints(OpBreakpoints, BPOINT_OP);
}

static unsigned RegsPosX;
static unsigned RegsPosY;
static bool InRegs;
static uint32 RegsCols;
static uint32 RegsColsCounts[16];	// FIXME[5];
static uint32 RegsColsPixOffset[16];	//[5];
static uint32 RegsWhichFont[16];	//[5];
static uint32 RegsTotalWidth;

static std::string CurRegLongName;
static std::string CurRegDetails;

#define MK_COLOR_A(r,g,b,a) (pf_cache.MakeColor(r, g, b, a))

static void Regs_Init(const int max_height_hint)
{
 RegsPosX = RegsPosY = 0;
 InRegs = false;
 RegsCols = 0;

 memset(RegsColsCounts, 0, sizeof(RegsColsCounts));
 memset(RegsColsPixOffset, 0, sizeof(RegsColsPixOffset));
 memset(RegsWhichFont, 0, sizeof(RegsWhichFont));
 RegsTotalWidth = 0;

 CurRegLongName = "";
 CurRegDetails = "";

 //
 //
 //
 RegsCols = 0;
 RegsTotalWidth = 0;

 memset(RegsColsCounts, 0, sizeof(RegsColsCounts));

 int pw_offset = 0;
 for(unsigned int r = 0; r < CurGame->Debugger->RegGroups->size(); r++)
 {
     uint32 pw = 0;
     int x;

     for(x = 0; (*CurGame->Debugger->RegGroups)[r]->Regs[x].bsize; x++)
     {
      if((*CurGame->Debugger->RegGroups)[r]->Regs[x].bsize != 0xFFFF)
      {
       uint32 tmp_pw = strlen((*CurGame->Debugger->RegGroups)[r]->Regs[x].name.c_str());
       unsigned int bsize = (*CurGame->Debugger->RegGroups)[r]->Regs[x].bsize;

       if(bsize & 0x100)
	tmp_pw += ((bsize & 0xFF) + 3) / 4 + 2 + 2;
       else
        tmp_pw += bsize * 2 + 2 + 2;

       if(tmp_pw > pw)
        pw = tmp_pw;
      }

      RegsColsCounts[r]++;
     }

     if(r == (CurGame->Debugger->RegGroups->size() - 1))
      pw -= 2;

     if(x * 7 > max_height_hint)
     {
      pw *= 4;
      RegsWhichFont[r] = MDFN_FONT_4x5;
     }
     else
     {
      pw *= 5;
      RegsWhichFont[r] = MDFN_FONT_5x7;
     }

     RegsCols++;
     RegsColsPixOffset[r] = pw_offset;

     //printf("Column %d, Offset %d\n", r, pw_offset);

     pw_offset += pw;
 }
 RegsTotalWidth = pw_offset;
}

static void Regs_DrawGroup(RegGroupType *rg, MDFN_Surface *surface, uint32 *pixels, int highlight, uint32 which_font)
{
  const MDFN_PixelFormat pf_cache = surface->format;
  uint32 pitch32 = surface->pitchinpix;
  uint32 *row = pixels;
  unsigned int meowcow = 0;
  RegType *rec = rg->Regs;

  while(rec->bsize)
  {
   char nubuf[256];
   uint32 color = MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF);
   uint32 rname_color = MK_COLOR_A(0xE0, 0xFF, 0xFF, 0xFF);

   std::string *details_ptr = NULL;
   char details_string[256];
   uint32 details_string_len = sizeof(details_string);

   details_string[0] = 0;

   if(highlight != -1)
   {
    if((unsigned int)highlight == meowcow)
    {
     CurRegLongName = rec->long_name;
     rname_color = color = MK_COLOR_A(0xFF, 0x00, 0x00, 0xFF);
     details_ptr = &CurRegDetails;
    }
   }
   int prew = DrawTextTrans(row, surface->pitchinpix << 2, 128, rec->name.c_str(), rname_color, 0, which_font);

   if(rec->bsize != 0xFFFF)
   {
    uint32 regval;

    regval = rg->GetRegister(rec->id, details_ptr ? details_string : NULL, details_string_len);

    if(rec->bsize & 0x100)
    {
     char fstring[7] = ": %08X";
     int nib_size = ((rec->bsize & 0xFF) + 3) / 4;

     fstring[3] = '0' + (nib_size / 10);
     fstring[4] = '0' + (nib_size % 10);

     trio_snprintf(nubuf, 256, fstring, regval);
    }
    else
    {
     if(rec->bsize == 4)
      trio_snprintf(nubuf, 256, ": %08X", regval);
     else if(rec->bsize == 3)
      trio_snprintf(nubuf, 256, ": %06X", regval);
     else if(rec->bsize == 2)
      trio_snprintf(nubuf, 256, ": %04X", regval);
     else if(rec->bsize == 1)
      trio_snprintf(nubuf, 256, ": %02X", regval);
    }

    if(details_ptr && details_string[0])
     *details_ptr = std::string(details_string);

    DrawTextTrans(row + prew, surface->pitchinpix << 2, 64, nubuf, color, 0, which_font);
   }

   if(which_font == MDFN_FONT_5x7)
    row += 7 * pitch32;
   else if(which_font == MDFN_FONT_4x5)
    row += 6 * pitch32;
   else
    row += 18 * pitch32;

   rec++;
   meowcow++;
  }
}




static int DIS_ENTRIES = 58;
static int DisFont = MDFN_FONT_5x7;
static int DisFontHeight = 7;

static uint32 WatchAddr = 0x0000, WatchAddrPhys = 0x0000;
static uint32 DisAddr = 0x0000;
static uint32 DisCOffs = 0xFFFFFFFF;
static int NeedDisAddrChange = 0;

static void DrawZP(MDFN_Surface *surface, uint32 *pixels)
{
 const MDFN_PixelFormat pf_cache = surface->format;
 uint32 addr = CurGame->Debugger->ZPAddr;

 for(int y = -1; y < 17; y++)
  for(int x = -1; x < 17; x++)
  {
   uint8 zebyte = CurGame->Debugger->MemPeek(addr, 1, 1, TRUE);
   char tbuf[32];
   int r, g, b;
   bool NeedInc = FALSE;

   if((y == -1 || y == 16) && (x == -1 || x == 16)) continue;

   if(y == -1 || y == 16)
   {
    r = 0x00;
    g = 0xE0;
    b = 0x00;
    trio_snprintf(tbuf, 32, "x%1X", x);
   }
   else if(x == -1 || x == 16)
   {
    r = 0x00;
    g = 0xE0;
    b = 0x00;
    trio_snprintf(tbuf, 32, "%1Xx", y);
   }
   else
   {
    trio_snprintf(tbuf, 32, "%02X", zebyte);

    r = 0x00;
    g = 0x00;
    b = 0x00;

    if(x & 4) { r += 0xeF; }
    if(y & 4) { b += 0xFF; g += 0x80; }
    if(!(x & 4) && !(y & 4))
     r = g = b = 0xE0;
    NeedInc = TRUE;
   }

   DrawTextTrans(pixels + (x + 1) * 13 + (y + 1) * 10 * surface->pitchinpix, surface->pitchinpix << 2, 1024, tbuf, MK_COLOR_A(r, g, b, 0xFF), FALSE, MDFN_FONT_5x7);
   if(NeedInc)
    addr++;
  }

}

typedef enum
{
 None = 0,
 DisGoto,
 WatchGoto,
 EditRegs,
 PokeMe,
 PokeMeHL,
 ReadBPS,
 WriteBPS,
 IOReadBPS,
 IOWriteBPS,
 AuxReadBPS,
 AuxWriteBPS,
 OpBPS,
 ForceInt,
 TraceLogPrompt
} PromptType;

// FIXME, cleanup, less spaghetti:
static PromptType InPrompt = None;
static RegType *CurRegIP;
static RegGroupType *CurRegGroupIP;

class DebuggerPrompt : public HappyPrompt
{
	public:

	DebuggerPrompt(const std::string &ptext, const std::string &zestring) : HappyPrompt(ptext, zestring)
	{

	}
	~DebuggerPrompt()
	{

	}
	private:

	void TheEnd(const std::string &pstring)
	{
                  char *tmp_c_str = strdup(pstring.c_str());

                  if(InPrompt == DisGoto)
                  {
		   unsigned long long tmpaddr;

                   if(trio_sscanf(tmp_c_str, "%llx", &tmpaddr) == 1)
		   {
		    DisAddr = tmpaddr;
                    DisAddr &= ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
	            DisAddr &= ~(CurGame->Debugger->InstructionAlignment - 1);
		    DisCOffs = 0xFFFFFFFF;
		   }
                  }
                  else if(InPrompt == ReadBPS)
                  {
                   ReadBreakpoints = std::string(tmp_c_str);
                   UpdateBreakpoints(ReadBreakpoints, BPOINT_READ);
                  }
                  else if(InPrompt == WriteBPS)
                  {
                   WriteBreakpoints = std::string(tmp_c_str);
                   UpdateBreakpoints(WriteBreakpoints, BPOINT_WRITE);
                  }
                  else if(InPrompt == IOReadBPS)
                  {
                   IOReadBreakpoints = std::string(tmp_c_str);
                   UpdateBreakpoints(IOReadBreakpoints, BPOINT_IO_READ);
                  }
                  else if(InPrompt == IOWriteBPS)
                  {
                   IOWriteBreakpoints = std::string(tmp_c_str);
                   UpdateBreakpoints(IOWriteBreakpoints, BPOINT_IO_WRITE);
                  }
                  else if(InPrompt == AuxReadBPS)
                  {
                   AuxReadBreakpoints = std::string(tmp_c_str);
                   UpdateBreakpoints(AuxReadBreakpoints, BPOINT_AUX_READ);
                  }
                  else if(InPrompt == AuxWriteBPS)
                  {
                   AuxWriteBreakpoints = std::string(tmp_c_str);
                   UpdateBreakpoints(AuxWriteBreakpoints, BPOINT_AUX_WRITE);
                  }
                  else if(InPrompt == OpBPS)
                  {
                   OpBreakpoints = std::string(tmp_c_str);
                   UpdateBreakpoints(OpBreakpoints, BPOINT_OP);
                  }
		  else if(InPrompt == TraceLogPrompt)
		  {
		   if(pstring != TraceLogSpec)
		   {
		    TraceLogSpec = pstring;

		    if(TraceLog)
		    {
		     fclose(TraceLog);
		     TraceLog = NULL;
		     UpdateCoreHooks();
		    }

		    unsigned int endpc;
		    char tmpfn[256];
		    int num = trio_sscanf(tmp_c_str, "%255s %x", tmpfn, &endpc);
		    if(num >= 1)
		    {
		     if((TraceLog = fopen(tmpfn, "ab")))
		     {
		      time_t lovelytime;
		      lovelytime = time(NULL);

		      if(ftell(TraceLog) != 0)
		       trio_fprintf(TraceLog, "\n\n\n");

		      trio_fprintf(TraceLog, "Tracing began: %s", asctime(gmtime(&lovelytime)));
		      trio_fprintf(TraceLog, "[ADDRESS]: [INSTRUCTION]   [REGISTERS(before instruction exec)]");
		      if(num == 1)
		       TraceLogEnd = -1;
		      else
		       TraceLogEnd = endpc;
		      TraceLogRTO = 0;
		      UpdateCoreHooks();
		     }
		    }
		   }
		  }
                  else if(InPrompt == ForceInt)
                  {
                   CurGame->Debugger->IRQ(atoi(tmp_c_str));
                  }
                  else if(InPrompt == PokeMe || InPrompt == PokeMeHL)
                  {
		   const bool hl = (InPrompt == PokeMeHL);
                   uint32 A = 0, V = 0, S = 1;
                   bool logical = true;
                   char *meow_str = tmp_c_str;
		   int ssf_ret;

                   if(meow_str[0] == '*')
                   {
                    meow_str++;
                    logical = false;
                   }

                   if(logical)
                    ssf_ret = trio_sscanf(tmp_c_str, "%x %x %d", &A, &V, &S);
                   else
                   {
                    char sa[64];

                    ssf_ret = trio_sscanf(tmp_c_str, "%63s %x %d", sa, &V, &S);

                    A = ParsePhysAddr(sa);
                   }

                   if(ssf_ret >= 2) // Allow size to be omitted, implicit as '1'
                   {
                    A &= ((1ULL << CurGame->Debugger->LogAddrBits) - 1);

                    if(S < 1) S = 1;
                    if(S > 4) S = 4;

		    MemPoke(A, V, S, hl, logical);
                   }
                  }
                  else if(InPrompt == EditRegs)
                  {
                   unsigned long long RegValue = 0;

                   trio_sscanf(tmp_c_str, "%llx", &RegValue);

		   if(CurRegGroupIP->SetRegister)
                    CurRegGroupIP->SetRegister(CurRegIP->id, RegValue);
		   else
		    puts("Null SetRegister!");
                  }
                  else if(InPrompt == WatchGoto)
                  {
                   if(WatchLogical)
                   {
                    trio_sscanf(tmp_c_str, "%x", &WatchAddr);
                    WatchAddr &= 0xFFF0;
                   }
                   else
                   {
                    trio_sscanf(tmp_c_str, "%x", &WatchAddrPhys);
                    WatchAddrPhys &= (((uint64)1 << CurGame->Debugger->PhysAddrBits) - 1);
                    WatchAddrPhys &= ~0xF;
                   }
                  }
                  free(tmp_c_str);
                  InPrompt = None;

	}
};

struct DisasmEntry
{
 std::string text;
 uint32 A;
 uint32 COffs;
 bool ForcedResync;
};


static DebuggerPrompt *myprompt = NULL;

//
//
//
void Debugger_GTR_PassBlit(void)
{
 DMTV_Rect = &DebuggerRect[DMTV_BackBuffer];
 DMTV_Surface = DebuggerSurface[DMTV_BackBuffer];

 DMTV_BackBuffer ^= 1;
}

void Debugger_MT_DrawToScreen(const MDFN_PixelFormat& pf, signed screen_w, signed screen_h)
{
 if(!DMTV_Rect || !DMTV_Surface || !DMTV_Rect->w || !DMTV_Rect->h)
  return;

 MDFN_Surface* debsurf = DMTV_Surface;
 MDFN_Rect* debrect = DMTV_Rect;
 MDFN_Rect zederect;
 int xm = screen_w / debrect->w;
 int ym = screen_h / debrect->h;

 debsurf->SetFormat(pf, true);

 if(xm < 1) xm = 1;
 if(ym < 1) ym = 1;

 // Allow it to be compacted horizontally, but don't stretch it out, as it's hard(IMHO) to read.
 if(xm > ym) xm = ym;
 if(ym > (2 * xm)) ym = 2 * xm;

 zederect.w = debrect->w * xm;
 zederect.h = debrect->h * ym;

 zederect.x = (screen_w - zederect.w) / 2;
 zederect.y = (screen_h - zederect.h) / 2;

 *(MDFN_Rect*)&dlc_screen_dest_rect = zederect;
 BlitRaw(debsurf, debrect, &zederect);
}

void Debugger_GT_Draw(void)
{
 MDFN_Surface* surface = DebuggerSurface[DMTV_BackBuffer];
 MDFN_Rect* rect = &DebuggerRect[DMTV_BackBuffer];
 MDFN_Rect screen_rect = *(MDFN_Rect*)&dlc_screen_dest_rect;

 if(!IsActive)
 {
  rect->w = 0;
  rect->h = 0;
  return;
 }

 //
 // Kludges to prevent div by zero.  We're a little sloppy with the dest rect thingy...
 //
 if(!screen_rect.w)
  screen_rect.w = 1;

 if(!screen_rect.h)
  screen_rect.h = 1;


 switch(WhichMode)
 {
  default:
  case 0: rect->w = CompactMode ? 512 : 640;
	  rect->h = CompactMode ? 448 : 480;
	  break;

  case 1: rect->w = 384;
	  rect->h = 320;
	  break;

  case 2: rect->w = 320;
	  rect->h = 240;
	  break;

  case 3: rect->w = 512;
	  rect->h = 448;
	  break;
 }

 if(WhichMode == 1)
 {
  surface->Fill(0, 0, 0, 0);

  GfxDebugger_Draw(surface, rect, &screen_rect);
  return;
 }
 else if(WhichMode == 2)
 {
  surface->Fill(0, 0, 0, DebuggerOpacity);

  memdbg->Draw(surface, rect, &screen_rect);
  return;
 }
 else if(WhichMode == 3)
 {
  surface->Fill(0, 0, 0, DebuggerOpacity);

  LogDebugger_Draw(surface, rect, &screen_rect);
  return;
 }

 const MDFN_PixelFormat pf_cache = surface->format;
 uint32 *pixels = surface->pixels;
 uint32 pitch32 = surface->pitchinpix;

 surface->Fill(0, 0, 0, DebuggerOpacity);

 // We need to disassemble (maximum_instruction_size * (DIS_ENTRIES / 2) * 3)
 // bytes to make sure we can center our desired DisAddr, and
 // that we have enough disassembled datums for displayaling and
 // worshipping cactus mules.


 int PreBytes = CurGame->Debugger->MaxInstructionSize * ((DIS_ENTRIES + 1) / 2) * 2;
 int DisBytes = CurGame->Debugger->MaxInstructionSize * ((DIS_ENTRIES + 1) / 2) * 3;

 uint32 A = (DisAddr - PreBytes) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);

 std::vector<DisasmEntry> DisBuffer;
 int indexcow = -1;
 const uint32 PC = GetPC();

 while(DisBytes > 0)
 {
  DisasmEntry NewEntry;
  uint32 lastA = A;
  char dis_text_buf[256];
  uint32 ResyncAddr;

  // Handling resynch address ->0 wrapping is a bit more complex...
  {
   const uint32 da_distance = (DisAddr - A - 1) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
   const uint32 pc_distance = (PC - A - 1) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
   uint32 distance;

   distance = da_distance;
   ResyncAddr = DisAddr;

   if(pc_distance < distance)
   {
    distance = pc_distance;
    ResyncAddr = PC;
   }

   // Handle comment forced resynchronizations
   {
    std::map<uint64, DisComment>::const_iterator it;

    for(it = Comments.begin(); it != Comments.end(); it++)
    {
     uint32 comment_distance = ((uint32)it->first - A - 1) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);

     if(comment_distance < distance)
     {
      // FIXME: data byte validation

      distance = comment_distance;
      ResyncAddr = (uint32)it->first;
     }
    }
   }

  }

  //printf("%08x %08x\n", A, DisAddr);
  CurGame->Debugger->Disassemble(A, ResyncAddr, dis_text_buf); // A is passed by reference to Disassemble()

  NewEntry.A = lastA;
  NewEntry.text = std::string(dis_text_buf);
  NewEntry.COffs = 0xFFFFFFFF;

  const uint64 a_m_la  = (A - lastA) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
  const uint64 ra_m_la = (ResyncAddr - lastA) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);

  //printf("A=%16llx lastA=%16llx a_m_la=%16llx ra_m_la=%16llx RA=%16llx\n", (unsigned long long)A, (unsigned long long)lastA, a_m_la, ra_m_la, (unsigned long long)ResyncAddr);

  // Resynch if necessary
  if(ra_m_la != 0 && a_m_la > ra_m_la)
  {
   A = ResyncAddr;
   NewEntry.ForcedResync = true;
  }
  else
   NewEntry.ForcedResync = false;

  DisBytes -= a_m_la;


  {
   std::map<uint64, DisComment>::const_iterator it = Comments.find(lastA);

   if(it != Comments.end())
   {
    //const std::string &rawstring = it->second;
    const DisComment &zec = it->second;
    DisasmEntry CommentEntry;

    CommentEntry.A = lastA;
    CommentEntry.ForcedResync = false;

    for(uint32 i = 0; i < zec.size(); i++)
    {
     CommentEntry.COffs = i;
     CommentEntry.text = zec[i];

     if(CommentEntry.A == DisAddr && CommentEntry.COffs == DisCOffs)
      indexcow = DisBuffer.size();

     DisBuffer.push_back(CommentEntry);
    }
   }
  }

  if(NewEntry.A == DisAddr && (NewEntry.COffs == DisCOffs || indexcow == -1))	// Also handles case where comments disappear out from underneath us.
   indexcow = DisBuffer.size();

  DisBuffer.push_back(NewEntry);
 }

 char addr_text_fs[64];	 // Format string.

 trio_snprintf(addr_text_fs, 64, " %%0%0dX%%s", (CurGame->Debugger->LogAddrBits + 3) / 4);

 for(int x = 0; x < DIS_ENTRIES; x++)
 {
  int32 dbi = indexcow - (DIS_ENTRIES / 2) + x;

  if(dbi < 0 || dbi >= (int32)DisBuffer.size())
  {
   puts("Disassembly error!");
   break;
  }

  if(DisBuffer[dbi].COffs != 0xFFFFFFFF)	// Comment
  {
   uint32 color = MK_COLOR_A(0xFF, 0xA5, 0x00, 0xFF);
   uint32 cursor_color = MK_COLOR_A(0xFF, 0x80, 0xE0, 0xFF);
   //char textbuf[256];

   //trio_snprintf(textbuf, sizeof(textbuf), "// %s", DisBuffer[dbi].text.c_str());

   if(DisBuffer[dbi].A == DisAddr && DisBuffer[dbi].COffs == DisCOffs)
    DrawTextTrans(pixels + x * DisFontHeight * pitch32, surface->pitchinpix << 2, rect->w, ">", cursor_color, 0, DisFont);

   DrawTextTrans(pixels + 5 + x * DisFontHeight * pitch32, surface->pitchinpix << 2, rect->w, DisBuffer[dbi].text.c_str(), color, 0, DisFont);
  }
  else						// Disassembly
  {
   std::string dis_str = DisBuffer[dbi].text;
   uint32 dis_A = DisBuffer[dbi].A;

   char addr_text[64];
   uint32 color = MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF);
   uint32 addr_color = MK_COLOR_A(0xa0, 0xa0, 0xFF, 0xFF);

   trio_snprintf(addr_text, 256, addr_text_fs, dis_A, (DisBuffer[dbi].ForcedResync ? "!!" : ": "));

   if(dis_A == DisAddr && DisBuffer[dbi].COffs == DisCOffs)
   {
    addr_text[0] = '>';
    if(!InRegs)
    {
     if(dis_A == PC)
      addr_color = color = MK_COLOR_A(0xFF, 0x00, 0x00, 0xFF);
     else
      addr_color = color = MK_COLOR_A(0xFF, 0x80, 0xE0, 0xFF);
    }

    if(NeedPCBPToggle)
    {
     if(DisCOffs == 0xFFFFFFFF)
      TogglePCBreakPoint(dis_A);
     NeedPCBPToggle = 0;
    }
   }

   if(dis_A == PC && (dis_A != DisAddr || InRegs))
    addr_color = color = MK_COLOR_A(0x00, 0xFF, 0x00, 0xFF);

   if(IsPCBreakPoint(dis_A))
    addr_text[0] = addr_text[0] == '>' ? '#' : '*';

   int addrpixlen;

   addrpixlen = DrawTextTrans(pixels + x * DisFontHeight * pitch32, surface->pitchinpix << 2, rect->w, addr_text, addr_color, 0, DisFont);
   DrawTextTrans(pixels + x * DisFontHeight * pitch32 + addrpixlen, surface->pitchinpix << 2, rect->w - strlen(addr_text) * 5, dis_str.c_str(), color, 0, DisFont);
  }
 }

 if(NeedDisAddrChange)
 {
  if((indexcow + NeedDisAddrChange) >= (int32)DisBuffer.size())
  {
   puts("Error, gack!");
  }
  else
  {
   DisAddr = DisBuffer[indexcow + NeedDisAddrChange].A;
   DisCOffs = DisBuffer[indexcow + NeedDisAddrChange].COffs;
   NeedDisAddrChange = 0;
  }
 }

 CurRegLongName = "";
 CurRegDetails = "";

 for(unsigned int rp = 0; rp < CurGame->Debugger->RegGroups->size(); rp++)
  Regs_DrawGroup((*CurGame->Debugger->RegGroups)[rp], surface, pixels + rect->w - RegsTotalWidth + RegsColsPixOffset[rp], (InRegs && RegsPosX == rp) ? (int)RegsPosY : -1, RegsWhichFont[rp]); // 175

 if(CurGame->Debugger->ZPAddr != (uint32)~0UL)
  DrawZP(surface, pixels + 324 + 224 * pitch32);

 int moo = 8;

 if(CompactMode)
  moo = 16;

 if(InRegs)
 {
  DrawTextTrans(pixels + (rect->h - (moo + 2) * 7) * pitch32, surface->pitchinpix << 2, surface->w, CurRegLongName.c_str(), MK_COLOR_A(0xa0, 0xa0, 0xFF, 0xFF), TRUE, 1);
  DrawTextTrans(pixels + (rect->h - (moo + 1) * 7) * pitch32, surface->pitchinpix << 2, surface->w, CurRegDetails.c_str(), MK_COLOR_A(0x60, 0xb0, 0xFF, 0xFF), TRUE, 1);
 }
 else if(CurGame->Debugger->GetBranchTrace)
 {
  const int btrace_rows = 4;
  const int btrace_cols = 96;
  std::vector<BranchTraceResult> btrace = CurGame->Debugger->GetBranchTrace();
  uint32 *btpixels = pixels + (rect->h - (moo + 2) * 7) * pitch32 + 7; // + ((128 - btrace_cols) / 2) * 5;
  int draw_position = btrace_rows * btrace_cols;
  bool color_osc = false;
  const uint32 hcolors[2] = { MK_COLOR_A(0x60, 0xb0, 0xfF, 0xFF), MK_COLOR_A(0xb0, 0x70, 0xfF, 0xFF) };

  for(int i = (int)btrace.size() - 1; i >= 0; i--)
  {
   char strbuf[4][256];	// [0] = from, [1] = arrow/special, [2] = to, [3] = ...
   int strbuf_len;
   int new_draw_position;
   int col, row;
   uint32 *pix_tmp;

   trio_snprintf(strbuf[0], 256, "%s", btrace[i].from);

   if(btrace[i].code[0])
    trio_snprintf(strbuf[1], 256, "[%s‣]", btrace[i].code);
   else
    trio_snprintf(strbuf[1], 256, "‣");

   if(btrace[i].count > 1)
    trio_snprintf(strbuf[2], 256, "%s(*%d)", btrace[i].to, btrace[i].count);
   else
    trio_snprintf(strbuf[2], 256, "%s", btrace[i].to);

   if(i == ((int)btrace.size() - 1))
    strbuf[3][0] = 0;
   else
    snprintf(strbuf[3], 256, "…");

//trio_snprintf(tmp, sizeof(tmp), "%04X%s%04X(*%d)", bt->from, arrow, bt->to, bt->branch_count);

   strbuf_len = (GetTextPixLength(strbuf[0], MDFN_FONT_5x7) +
		 GetTextPixLength(strbuf[1], MDFN_FONT_5x7) +
	         GetTextPixLength(strbuf[2], MDFN_FONT_5x7) + 5 + GetTextPixLength(strbuf[3], MDFN_FONT_5x7) + 4) / 5;
   new_draw_position = draw_position - strbuf_len;

   if(new_draw_position < 0)
    break;

   if(((draw_position - 1) / btrace_cols) > (new_draw_position / btrace_cols))
    new_draw_position = ((new_draw_position / btrace_cols) + 1) * btrace_cols - strbuf_len;

   col = new_draw_position % btrace_cols;
   row = new_draw_position / btrace_cols;

   pix_tmp = btpixels + col * 5 + row * 10 * pitch32;
   pix_tmp += DrawTextTrans(pix_tmp, surface->pitchinpix << 2, rect->w, strbuf[0], (btrace[i].count > 1) ? MK_COLOR_A(0xe0, 0xe0, 0x00, 0xFF) : hcolors[color_osc], false, MDFN_FONT_5x7);
   pix_tmp += DrawTextTrans(pix_tmp, surface->pitchinpix << 2, rect->w, strbuf[1], btrace[i].code[0] ? MK_COLOR_A(0xb0, 0xFF, 0xff, 0xFF) : MK_COLOR_A(0xb0, 0xb0, 0xff, 0xFF), false, MDFN_FONT_5x7);

   color_osc = !color_osc;

   pix_tmp += DrawTextTrans(pix_tmp, surface->pitchinpix << 2, rect->w, strbuf[2], (btrace[i].count > 1) ? MK_COLOR_A(0xe0, 0xe0, 0x00, 0xFF) : hcolors[color_osc], false, MDFN_FONT_5x7);
   pix_tmp += 2;
   pix_tmp += DrawTextTrans(pix_tmp, surface->pitchinpix << 2, rect->w, strbuf[3], MK_COLOR_A(0x60, 0x70, 0x80, 0xFF), false, MDFN_FONT_5x7);
   pix_tmp += 3;
   draw_position = new_draw_position;
  }

#if 0
  for(int bt_row = 0; bt_row < btrace_rows; bt_row++)
  {
   strbuf[0] = 0;
   strbuf_len = 0;
   for(unsigned int y = 0; y < (btrace.size() + btrace_rows - 1) / btrace_rows && btrace_index < btrace.size(); y++)
   {
    strbuf_len += trio_snprintf(strbuf + strbuf_len, 256 - strbuf_len, /*"%s→"*/ "%s ", btrace[btrace_index].c_str());
    btrace_index++;
   }

   strbuf[strbuf_len - 1] = 0; // Get rid of the trailing space

   DrawTextTrans(btpixels + bt_row * 8 * pitch32, surface->pitchinpix << 2, rect->w, strbuf, MK_COLOR_A(0x60, 0xb0, 0xfF, 0xFF), TRUE, MDFN_FONT_5x7);
  }
#endif
 }

 // Draw memory watch section
 {
  uint32 *watchpixels = pixels + (rect->h - moo * 7 + (InRegs ? 0 : 4) * 7) * pitch32;
  int mw_rows = InRegs ? 8 : 4;
  int bytes_per_row = 32;

  if(CompactMode) 
   mw_rows = 16;

  if(CompactMode)
   bytes_per_row = 16;

  for(int y = 0; y < mw_rows; y++)
  {
   uint32 *row = watchpixels + y * pitch32 * 7;
   char tbuf[256];
   char asciistr[32 + 1];
   uint32 ewa;
   uint32 ewa_bits;
   uint32 ewa_mask;

   asciistr[32] = 0;

   if(WatchLogical)
   {
    ewa_bits = CurGame->Debugger->LogAddrBits;
    ewa = WatchAddr;
   }
   else
   {
    ewa_bits = CurGame->Debugger->PhysAddrBits;
    ewa = WatchAddrPhys;
   }
   
   ewa_mask = ((uint64)1 << ewa_bits) - 1;

   if(InRegs)
    ewa = (ewa - 0x80) & ewa_mask;

   if(ewa_bits <= 16)
    trio_snprintf(tbuf, 256, "%04X: ", (ewa + y * bytes_per_row) & ewa_mask);
   else if(ewa_bits <= 20)
    trio_snprintf(tbuf, 256, "%05X: ", (ewa + y * bytes_per_row) & ewa_mask);
   else if(ewa_bits <= 24)
    trio_snprintf(tbuf, 256, "%06X: ", (ewa + y * bytes_per_row) & ewa_mask);
   else
    trio_snprintf(tbuf, 256, "%08X: ", (ewa + y * bytes_per_row) & ewa_mask);

   row += DrawTextTrans(row, surface->pitchinpix << 2, rect->w, tbuf, MK_COLOR_A(0xa0, 0xa0, 0xFF, 0xFF), FALSE, MDFN_FONT_5x7);
   for(int x = 0; x < bytes_per_row; x++)
   {
    uint8 zebyte = CurGame->Debugger->MemPeek((ewa + y * bytes_per_row + x) & ewa_mask, 1, 1, WatchLogical);
    uint32 bcolor = MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF);

    if(x & 1)
     bcolor = MK_COLOR_A(0xD0, 0xFF, 0xF0, 0xFF);
    if(!(x & 0x7))
     bcolor = MK_COLOR_A(0xFF, 0x80, 0xFF, 0xFF);
    asciistr[x] = zebyte;
    if(zebyte & 0x80 || !zebyte)
     asciistr[x] = '.';

    if(x == 16) row += 7;

    trio_snprintf(tbuf, 256, "%02X", zebyte);
    row += DrawTextTrans(row, surface->pitchinpix << 2, rect->w, tbuf, bcolor, 0, 1) + 2;
   }
   DrawTextTrans(row + 5, surface->pitchinpix << 2, rect->w, asciistr, MK_COLOR_A(0xFF, 0xFF, 0xFF, 0xFF), 0, MDFN_FONT_5x7);
  }
 }  

 if(InPrompt)
  myprompt->Draw(surface, rect);
 else if(myprompt)
 {
  delete myprompt;
  myprompt = NULL;
 }
}

static void MDFN_COLD SetActive(bool active, unsigned which_ms)
{
  IsActive = active;
  WhichMode = which_ms;

  if(IsActive)
  {
   if(!DebuggerSurface[0])
   {
    DebuggerSurface[0] = new MDFN_Surface(NULL, 640, 480, 640, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, 0, 8, 16, 24));
    DebuggerSurface[1] = new MDFN_Surface(NULL, 640, 480, 640, MDFN_PixelFormat(MDFN_COLORSPACE_RGB, 0, 8, 16, 24));
   }

   if(NeedInit)
   {
    std::string des_disfont = MDFN_GetSettingS(std::string(std::string(CurGame->shortname) + "." + std::string("debugger.disfontsize")));
    DebuggerOpacity = 0xC0;

    // Debug remove me
#if 0
    {
     DisComment comment;

     comment.push_back("// Hi!");
     comment.push_back("// We welcome you to the wonderful world");
     comment.push_back("// of tomorrow...TODAY!");
     comment.push_back("//");
     comment.push_back("// Warning: Beware of deathbots.");

     Comments[0x8001] = comment;
    }
#endif
    // End debug remove me
 
    if(des_disfont == "xsmall")
    {
     DisFont = MDFN_FONT_4x5;
     DisFontHeight = 6;
    }
    else if(des_disfont == "medium")
    {
     DisFont = MDFN_FONT_6x13_12x13;
     DisFontHeight = 12;
    }
    else if(des_disfont == "large")
    {
     DisFont = MDFN_FONT_9x18_18x18;
     DisFontHeight = 17;
    }
    else // small
    {
     DisFont = MDFN_FONT_5x7;
     DisFontHeight = 7;
    }

    DIS_ENTRIES = 406 / DisFontHeight;

    //DIS_ENTRIES = CompactMode ? 46 : 58;

    NeedInit = FALSE;
    WatchAddr = CurGame->Debugger->DefaultWatchAddr;

    DisAddr = GetPC();
    DisCOffs = 0xFFFFFFFF;
    //DisAddr = (*CurGame->Debugger->RegGroups)[0]->GetRegister(/*PC*/0, NULL, 0); // FIXME

    Regs_Init(DIS_ENTRIES * DisFontHeight);
   }
  }

  UpdateCoreHooks();	// Note: Relies on value of IsActive.
  UpdateBreakpoints();

  GfxDebugger_SetActive((WhichMode == 1) && IsActive);
  memdbg->SetActive((WhichMode == 2) && IsActive);
  LogDebugger_SetActive((WhichMode == 3) && IsActive);

  SDL_MDFN_ShowCursor(IsActive);
}

static const char HexLUT[16] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

static void DoTraceLog(const uint32 PC)
{
  uint32 trace_PC = PC;

  char dis_text_buf[256 + 64];
  char *distbp = dis_text_buf;

  *distbp++ = '\n';

  for(unsigned i = 0; i < CurGame->Debugger->LogAddrBits; i += 4)
   *distbp++ = HexLUT[(trace_PC >> (CurGame->Debugger->LogAddrBits - i - 4)) & 0xF];

  *distbp++ = ':';
  *distbp++ = ' ';

  CurGame->Debugger->Disassemble(trace_PC, trace_PC, distbp);
  fputs(dis_text_buf, TraceLog);

  if(1)
  {
   char regs_buf[1024 + 1];
   unsigned tpos = 0;
   RegGroupType *rg = (*CurGame->Debugger->RegGroups)[0];

   {
    unsigned sl = strlen(dis_text_buf);

    if((sl + 3) > TraceLogRTO)
     TraceLogRTO = sl + 3;

    for(unsigned i = sl; i < TraceLogRTO && tpos < 1024; i++)
     regs_buf[tpos++] = ' ';
   }

   for(unsigned i = 0; rg->Regs[i].bsize > 0; i++)
   {
    const RegType* rt = &rg->Regs[i];
    uint32 val;

    if(rg->Regs[i].bsize == 0xFFFF)
     continue;

    val = rg->GetRegister(rt->id, NULL, 0);

    if(i)
    {
     if(tpos < 1024)
      regs_buf[tpos++] = ' ';
    }

    for(unsigned s = 0; s < rt->name.size() && tpos < 1024; s++)
    {
     regs_buf[tpos++] = rt->name[s];
    }

    if(tpos < 1024)
     regs_buf[tpos++] = '=';

    for(unsigned n = 0; n < (rt->bsize * 2) && tpos < 1024; n++)
     regs_buf[tpos++] = HexLUT[(val >> (((rt->bsize * 2) - 1 - n) * 4)) & 0xF];
   }

   regs_buf[tpos] = 0;

   fputs(regs_buf, TraceLog);
  }

  if(TraceLogEnd >= 0 && (uint32)TraceLogEnd == PC)
  {
   fclose(TraceLog);
   TraceLog = 0;
   UpdateCoreHooks();
  }
}

// Function called from game thread
static void CPUCallback(uint32 PC, bool bpoint)
{
 if((NeedStep == 2 && !InSteppingMode) || bpoint)
 {
  if(bpoint)
   SetActive(true, 0);

  DisAddr = PC;
  DisCOffs = 0xFFFFFFFF;
  NeedStep = 0;
  InSteppingMode = 1;
 }

 if(NeedStep == 1)
 {
  DisAddr = PC;
  DisCOffs = 0xFFFFFFFF;
  NeedStep = 0;
 }

 if(TraceLog)
  DoTraceLog(PC);

 while(InSteppingMode && GameThreadRun)
 {
  DebuggerFudge();
  if(NeedStep == 2)
  {
   NeedStep--;
   break;
  }
  if(NeedRun)
  {
   NeedStep = 0;
   NeedRun = 0;
   InSteppingMode = 0;
  }
  if(!InSteppingMode)
   UpdateCoreHooks();
 }
 if(NeedRun) NeedRun = 0;
}


// Function called from game thread, input driver code.
void Debugger_GT_ForceStepIfStepping(void)
{
 if(InSteppingMode)
  NeedStep = 2;
}

// Function called from game thread, input driver code.
void Debugger_GT_SyncDisToPC(void)
{
 if(CurGame->Debugger && !NeedInit)
 {
  DisAddr = GetPC();
  DisCOffs = 0xFFFFFFFF;
 }
}

// Called from game thread, or in the main thread game thread creation sequence code.
void Debugger_GT_ForceSteppingMode(void)
{
 if(!InSteppingMode)
 {
  NeedStep = 2;
  UpdateCoreHooks();
 }
}

// Call this function from any thread:
bool Debugger_IsActive(void)
{
 return(IsActive);
}

// Call this function from the game thread:
bool Debugger_GT_Toggle(void)
{
 if(CurGame->Debugger)
  SetActive(!IsActive, WhichMode);

 return(IsActive);
}

void Debugger_GT_ModOpacity(int deltalove)
{
 DebuggerOpacity += deltalove;
 if(DebuggerOpacity < 0) DebuggerOpacity = 0;
 if(DebuggerOpacity > 0xFF) DebuggerOpacity = 0xFF;
}

void Debugger_GT_Event(const SDL_Event *event)
{
  if(event->type == SDL_KEYDOWN)
  {
   if(event->key.keysym.mod & KMOD_ALT)
   {
    switch(event->key.keysym.sym)
    {
     case SDLK_1: WhichMode = 0; 
 		  GfxDebugger_SetActive(FALSE);
 		  memdbg->SetActive(FALSE);
		  LogDebugger_SetActive(FALSE);
		  break;
     case SDLK_2: WhichMode = 1;
		  GfxDebugger_SetActive(TRUE); 
		  memdbg->SetActive(FALSE);
		  LogDebugger_SetActive(FALSE);
		  break;
     case SDLK_3: if(CurGame->Debugger->AddressSpaces->size())
		  {
		   WhichMode = 2;
		   GfxDebugger_SetActive(FALSE);
		   memdbg->SetActive(TRUE);
		   LogDebugger_SetActive(FALSE);
		  }
		  break;
     case SDLK_4: if(CurGame->Debugger->SetLogFunc)
		  {
		   WhichMode = 3;
		   GfxDebugger_SetActive(FALSE);
		   memdbg->SetActive(FALSE);
		   LogDebugger_SetActive(TRUE);
		  }
		  break;

     default: break;
    }
   }
  }

  if(WhichMode == 1)
  {
   GfxDebugger_Event(event);
   return;
  }
  else if(WhichMode == 2)
  {
   memdbg->Event(event);
   return;
  }
  else if(WhichMode == 3)
  {
   LogDebugger_Event(event);
   return;
  }

  switch(event->type)
  {
   case SDL_KEYDOWN:
        if(event->key.keysym.mod & KMOD_ALT)
         break;

        if(InPrompt)
        {
	 myprompt->Event(event);

	 if(event->key.keysym.sym == SDLK_ESCAPE)
	 {
	  delete myprompt;
	  myprompt = NULL; 
	  InPrompt = None;
	 }
	}
        else switch(event->key.keysym.sym)
        {
	 default: break;
	 case SDLK_MINUS: Debugger_GT_ModOpacity(-8);
        	          break;
	 case SDLK_EQUALS: Debugger_GT_ModOpacity(8);
	                   break;

	 case SDLK_HOME:
		if(event->key.keysym.mod & KMOD_SHIFT)
		{
		 if(WatchLogical)
		  WatchAddr = 0;
		 else
		  WatchAddrPhys = 0;
		}
		else
		{
		 DisAddr = 0x0000;
		 DisCOffs = 0xFFFFFFFF;
		}
		break;
	 case SDLK_END:
		if(event->key.keysym.mod & KMOD_SHIFT)
		{
                 if(WatchLogical)
                  WatchAddr = ((1ULL << CurGame->Debugger->LogAddrBits) - 1) & ~0x7F;
                 else
                  WatchAddrPhys = (((uint64)1 << CurGame->Debugger->PhysAddrBits) - 1) & ~0x7F;
		}
		else
		{
		 DisAddr = ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
		 DisAddr &= ~(CurGame->Debugger->InstructionAlignment - 1);
		 DisCOffs = 0xFFFFFFFF;
	        }
		break;

         case SDLK_PAGEUP:
          if(event->key.keysym.mod & KMOD_SHIFT)
	  {
	   int change = 0x80; //InRegs ? 0x100 : 0x80;

	   if(WatchLogical)
            WatchAddr = (WatchAddr - change) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
	   else
	    WatchAddrPhys = (WatchAddrPhys - change) & (((uint64)1 << CurGame->Debugger->PhysAddrBits) - 1);
	  }
          else
	   NeedDisAddrChange = -11;
          break;

	 case SDLK_PAGEDOWN: 
          if(event->key.keysym.mod & KMOD_SHIFT) 
	  {
	   int change = 0x80; //InRegs ? 0x100 : 0x80;

	   if(WatchLogical)
            WatchAddr = (WatchAddr + change) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
	   else
	    WatchAddrPhys = (WatchAddrPhys + change) & (((uint64)1 << CurGame->Debugger->PhysAddrBits) - 1);
	  }
          else  
	   NeedDisAddrChange = 11;
          break;

	case SDLK_m:
	   WatchLogical = !WatchLogical;
	   break;

	case SDLK_TAB:
		if(RegsCols)
		 InRegs = !InRegs;
		break;

	case SDLK_LEFT:
		if(!InRegs)
		{
		 if(RegsCols)
		 {
		  InRegs = true;
		  RegsPosX = RegsCols - 1;
		 }
		}
		else
		{
		 if(!RegsPosX)
		  InRegs = false;
		 else
		  RegsPosX--;
		}

		if(InRegs && RegsPosY >= RegsColsCounts[RegsPosX])
 		 RegsPosY = RegsColsCounts[RegsPosX] - 1;
		break;

	case SDLK_RIGHT:
		if(!InRegs)
		{
		 if(RegsCols)
		 {
		  InRegs = true;
		  RegsPosX = 0;
		 }
		}
		else
		{
		 if(RegsPosX == RegsCols - 1)
		  InRegs = false;
		 else
		  RegsPosX++;
		}

		if(InRegs && RegsPosY >= RegsColsCounts[RegsPosX])
 		 RegsPosY = RegsColsCounts[RegsPosX] - 1;
		break;

        case SDLK_UP:
	  if(InRegs)
	  {
		if(RegsPosY)
		 RegsPosY--;
	  }
	  else
	  {
           if(event->key.keysym.mod & KMOD_SHIFT)
	   {
	    if(WatchLogical)
             WatchAddr = (WatchAddr - 0x10) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
	    else
	     WatchAddrPhys = (WatchAddrPhys - 0x10) & (((uint64)1 << CurGame->Debugger->PhysAddrBits) - 1);
	   }
           else
	   {
            NeedDisAddrChange = -1;
	   }
	  }
          break;

         case SDLK_DOWN:
	  if(InRegs)
	  {
                if(RegsPosY < (RegsColsCounts[RegsPosX] - 1))
		 RegsPosY++;
	  }
	  else
	  {
           if(event->key.keysym.mod & KMOD_SHIFT)
	   {
	    if(WatchLogical)
             WatchAddr = (WatchAddr + 0x10) & ((1ULL << CurGame->Debugger->LogAddrBits) - 1);
	    else
	     WatchAddrPhys = (WatchAddrPhys + 0x10) & (((uint64)1 << CurGame->Debugger->PhysAddrBits) - 1);
	   }
           else
	   {
	    NeedDisAddrChange = 1;
	   }
	  }
          break;

	 case SDLK_t:
		if(CurGame->Debugger->ToggleSyntax)
		{
		 CurGame->Debugger->ToggleSyntax();
		}
		break;

         case SDLK_SPACE:
		NeedPCBPToggle = 1;
		break;

	 case SDLK_s:
		NeedStep = 2;
		UpdateCoreHooks();
		break;

	 case SDLK_w:
                if(event->key.keysym.mod & KMOD_SHIFT)
                {
		 if(event->key.keysym.mod & KMOD_CTRL)
		 {
		  InPrompt = IOWriteBPS;
		  myprompt = new DebuggerPrompt("I/O Write Breakpoints", IOWriteBreakpoints);
		 }
		 else
		 {
                  InPrompt = WriteBPS;
		  myprompt = new DebuggerPrompt("Write Breakpoints", WriteBreakpoints);
                 }
                }
                else if(event->key.keysym.mod & KMOD_CTRL)
                {
                 InPrompt = AuxWriteBPS;
                 myprompt = new DebuggerPrompt("Aux Write Breakpoints", AuxWriteBreakpoints);
                }
		break;

	 case SDLK_o:
		if(event->key.keysym.mod & KMOD_SHIFT)
		{
		 InPrompt = OpBPS;
		 myprompt = new DebuggerPrompt("Opcode Breakpoints", OpBreakpoints);
		}
		break;
	 case SDLK_r:
		if(event->key.keysym.mod & KMOD_SHIFT)
		{
		 if(event->key.keysym.mod & KMOD_CTRL)
		 {
		  InPrompt = IOReadBPS;
		  myprompt = new DebuggerPrompt("I/O Read Breakpoints", IOReadBreakpoints);
		 }
		 else
		 {
		  InPrompt = ReadBPS;
		  myprompt = new DebuggerPrompt("Read Breakpoints", ReadBreakpoints);
		 }
		}
                else if(event->key.keysym.mod & KMOD_CTRL)
                {
                 InPrompt = AuxReadBPS;
                 myprompt = new DebuggerPrompt("Aux Read Breakpoints", AuxReadBreakpoints);
                }
		else if(InSteppingMode)
		 NeedRun = true;
		break;

	 case SDLK_l:
		if(!InPrompt)
		{
		 InPrompt = TraceLogPrompt;
		 myprompt = new DebuggerPrompt("Trace Log(filename end_pc)", TraceLogSpec);
		}
	 case SDLK_i:
	 	if(!InPrompt && CurGame->Debugger->IRQ)
		{
		 InPrompt = ForceInt;
		 myprompt = new DebuggerPrompt("Force Interrupt", "");
		}
		break;
	 case SDLK_p:
		if(!InPrompt)
		{
		 if(event->key.keysym.mod & KMOD_SHIFT)
		 {
		  InPrompt = PokeMeHL;
		  myprompt = new DebuggerPrompt("HL Poke(address value size)", "");
		 }
		 else
		 {
		  InPrompt = PokeMe;
		  myprompt = new DebuggerPrompt("Poke(address value size)", "");
		 }
		}
		break;

	  case SDLK_g:
	  case SDLK_RETURN:
		 {
		  char buf[64];
		  std::string ptext;

		  if(event->key.keysym.mod & KMOD_SHIFT)
		  {
		   InPrompt = WatchGoto;
		   ptext = "Watch Address";
                   trio_snprintf(buf, 64, "%08X", WatchLogical ? WatchAddr : WatchAddrPhys);
	 	  }
		  else
		  {
		   if(InRegs && event->key.keysym.sym != SDLK_g)
		   {
		    if((*CurGame->Debugger->RegGroups)[RegsPosX]->Regs[RegsPosY].bsize == 0xFFFF)
		     break;

		    InPrompt = (PromptType)(EditRegs);
		    CurRegIP = &(*CurGame->Debugger->RegGroups)[RegsPosX]->Regs[RegsPosY];
		    CurRegGroupIP = (*CurGame->Debugger->RegGroups)[RegsPosX];

		    ptext = CurRegIP->name;
		    int len = CurRegIP->bsize;

		    uint32 RegValue;

		    RegValue = CurRegGroupIP->GetRegister(CurRegIP->id, NULL, 0);

		    if(len == 1)
		     trio_snprintf(buf, 64, "%02X", RegValue);
		    else if(len == 2)
		     trio_snprintf(buf, 64, "%04X", RegValue);
		    else
		     trio_snprintf(buf, 64, "%08X", RegValue);
		   }
		   else
		   {
		    char addr_text_fs[64];	 // Format string.

		    trio_snprintf(addr_text_fs, 64, "%%0%uX", (CurGame->Debugger->LogAddrBits + 3) / 4);

		    InPrompt = DisGoto;
		    ptext = "Disassembly Address";
		    trio_snprintf(buf, 64, addr_text_fs, DisAddr);
		   }
		  }

                  myprompt = new DebuggerPrompt(ptext, buf);
		 }
	         break;
         }
         break;
  }
}

//
// Note: A lot of the more expensive initialization is deferred to when the debugger is first activated after a game is loaded.
//
void Debugger_Init(void)
{
	memdbg = new MemDebugger();

	TraceLogSpec = "";
	TraceLogEnd = 0;
	TraceLogRTO = 0;

	NeedInit = true;
	WatchLogical = true;
	IsActive = false;
	CompactMode = false;

	WhichMode = 0;

	NeedPCBPToggle = false;
	NeedStep = 0;
	NeedRun = 0;
	InSteppingMode = false;

	ReadBreakpoints = "";
	IOReadBreakpoints = "";
	AuxReadBreakpoints = "";
	WriteBreakpoints = "";
	IOWriteBreakpoints = "";
	AuxWriteBreakpoints = "";
	OpBreakpoints = "";
	PCBreakPoints.clear();

	Comments.clear();

	//

	DMTV_BackBuffer = 0;
	DMTV_Surface = NULL;
	DMTV_Rect = NULL;

	//
	//
	//
	if(MDFN_GetSettingB("debugger.autostepmode"))
	{
	 Debugger_GT_Toggle();
	 Debugger_GT_ForceSteppingMode();
	}
}

void Debugger_Kill(void)
{
	if(TraceLog)
	{
	 fclose(TraceLog);
	 TraceLog = NULL;
	}

	if(memdbg != NULL)
	{
	 delete memdbg;
	 memdbg = NULL;
	}

	for(unsigned i = 0; i < 2; i++)
	{
	 if(DebuggerSurface[i] != NULL)
	 {
	  delete DebuggerSurface[i];
	  DebuggerSurface[i] = NULL;
	 }
	}
}
