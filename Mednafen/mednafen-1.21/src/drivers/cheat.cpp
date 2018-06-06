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
#include "console.h"
#include "video.h"
#include <mednafen/string/string.h>

static MDFN_Thread *CheatThread = NULL;
static MDFN_Mutex *CheatMutex = NULL;
static MDFN_Cond *CheatCond = NULL;
static bool isactive = 0;
static std::list<std::string> pending_text;
static bool volatile need_thread_exit;

class CheatConsoleT : public MDFNConsole
{
	public:

	CheatConsoleT(void)
	{
	 SetShellStyle(1);
	}

        virtual bool TextHook(const std::string &text) override
        {
	 MDFND_LockMutex(CheatMutex);
	 try
	 {
	  pending_text.push_back(text);
	  MDFND_SignalCond(CheatCond);
	 }
	 catch(std::exception& e)
	 {
	  MDFND_UnlockMutex(CheatMutex);
	  throw;
	 }
	 MDFND_UnlockMutex(CheatMutex);

         return(1);
        }

	MDFN_Surface* Draw(const MDFN_PixelFormat& pformat, const int32 dim_w, const int32 dim_h, const unsigned fontid)
	{
	 MDFN_Surface* ret;

	 MDFND_LockMutex(CheatMutex);
	 try
	 {
	  ret = MDFNConsole::Draw(pformat, dim_w, dim_h, fontid);
	 }
	 catch(...)
	 {
	  MDFND_UnlockMutex(CheatMutex);
	  throw;
	 }
	 MDFND_UnlockMutex(CheatMutex);

	 return ret;
	}

	void WriteLine(const std::string &text)
	{
	 MDFND_LockMutex(CheatMutex);
	 MDFNConsole::WriteLine(text);
 	 MDFND_UnlockMutex(CheatMutex);
	}

        void AppendLastLine(const std::string &text)
        {
         MDFND_LockMutex(CheatMutex);
         MDFNConsole::AppendLastLine(text);
         MDFND_UnlockMutex(CheatMutex);
        }
};

static CheatConsoleT CheatConsole;

static void CHEAT_printf(const char *format, ...)
{
 char temp[2048];

 va_list ap;

 va_start(ap, format);
 trio_vsnprintf(temp, 2048, format, ap);
 va_end(ap);

 CheatConsole.CheatConsoleT::WriteLine(temp);
}

static void CHEAT_puts(const char *string)
{
 CheatConsole.CheatConsoleT::WriteLine(string);
}

static std::string CHEAT_gets(void)
{
 std::string lpt;

 //
 //
 //
 MDFND_LockMutex(CheatMutex);
 while(!pending_text.size() && !need_thread_exit)
 {
  MDFND_WaitCond(CheatCond, CheatMutex);
 }

 try
 {
  lpt = std::move(pending_text.front());
  pending_text.pop_front();
 }
 catch(std::exception& e)
 {
  MDFND_UnlockMutex(CheatMutex);
  throw;
 }
 MDFND_UnlockMutex(CheatMutex);
 //
 //
 //

 if(lpt.size())
  CheatConsole.CheatConsoleT::AppendLastLine(lpt);

 if(need_thread_exit)
 {
  puts("WHEEE");
  throw(0);	// Sloppy laziness, but it works!  SWEAT PANTS OF PRAGMATISM.
 }

 return lpt;
}

static char CHEAT_getchar(char def)
{
 std::string s = CHEAT_gets();

 if(!s.size())
  return def;

 return s[0];
}


static std::string GetString(const std::string& def = "")
{
 std::string s = CHEAT_gets();

 if(!s.size())
  return def;

 MDFN_trim(s);

 return s;
}

static uint64 GetUI(unsigned long long def)
{
 std::string s = CHEAT_gets();

 if(!s.size())
  return def;

 if(s[0] == '$')
  trio_sscanf(s.c_str() + 1, "%llx", &def);	// $0FCE
 else if(s.size() >= 2 && s[0] == '0' && MDFN_azlower(s[1]) == 'x')
  trio_sscanf(s.c_str() + 2, "%llx", &def);	// 0x0FCE
 else if(MDFN_azlower(s[s.size() - 1]) == 'h') // 0FCEh
  trio_sscanf(s.c_str(), "%llx", &def);
 else
  trio_sscanf(s.c_str(), "%lld", &def);

 return def;
}


static int GetYN(int def)
{
 for(;;)
 {
  CHEAT_printf("(Y/N)[%s]: ", def ? "Y" : "N");
  //
  std::string s = CHEAT_gets();

  if(!s.size())
   return def;

  switch(MDFN_azlower(s[0]))
  {
   case 'y': return 1;
   case 'n': return 0;
  }
 }
}

/*
**	Begin list code.
**
*/
static int listcount;
static int listids[10];
static int listsel;
static int mordoe;

void BeginListShow(void)
{
 listcount=0;
 listsel=-1;
 mordoe=0;
}

/* Hmm =0 for in list choices, hmm=1 for end of list choices. */
/* Return equals 0 to continue, -1 to stop, otherwise a number. */
int ListChoice(int hmm)
{
 std::string s;

 if(!hmm)
 {
  int num=0;

  tryagain:
  CHEAT_printf(" <'Enter' to continue, (S)top, or #> ");
  s = CHEAT_gets();

  if(!s.size())
   return 0;

  if(MDFN_azlower(s[0]) == 's')
   return -1;

  if(!trio_sscanf(s.c_str(), "%d", &num))
   return 0;

  if(num < 1)
   goto tryagain;

  return num;
 }
 else
 {
  int num=0;

  tryagain2:
  CHEAT_printf(" <'Enter' to make no selection, or #> ");
  s = CHEAT_gets();

  if(!s.size())
   return 0;

  if(!trio_sscanf(s.c_str(), "%d", &num))
   return 0;

  if(num < 1)
   goto tryagain2;

  return num;
 }
}

int EndListShow(void)
{
  if(mordoe)
  {
   int r=ListChoice(1);
   if(r>0 && r<=listcount)
    listsel=listids[r-1];
  }
  return(listsel);
}

/* Returns 0 to stop listing, 1 to continue. */
int AddToList(const char *text, uint32 id, const char* second_text = NULL)
{
 if(listcount==10)
 {
  int t=ListChoice(0);
  mordoe=0;

  if(t==-1) return(0);  // Stop listing.
  else if(t>0 && t<11)
  {
   listsel=listids[t-1];
   return(0);
  }
  listcount=0;
 }
 mordoe = 1;
 listids[listcount] = id;
 CHEAT_printf("%2d) %s",listcount+1,text);

 if(second_text != NULL)
  CHEAT_printf("  %s", second_text);

 listcount++; 
 return(1);
}

/*
**	
**	End list code.
**/

struct MENU
{
	MENU(const char* t, void (*f)(void*), std::vector<MENU>* m, void* d = NULL);
	~MENU();

	std::string text;
	void (*func_action)(void*);
	std::vector<MENU>* menu_action;
	void* data;
};

MENU::MENU(const char* t, void (*f)(void*), std::vector<MENU>* m, void* d)
{
         text = std::string(t);
         func_action = f;
         menu_action = m;
	 data = d;
}

MENU::~MENU()
{

}

static void SetOC(void* data)
{
 MDFNI_CheatSearchSetCurrentAsOriginal();
}

static void UnhideEx(void* data)
{
 MDFNI_CheatSearchShowExcluded();
}

static void ToggleCheat(int num)
{
 CHEAT_printf("Cheat %d %sabled.",1+num,
 MDFNI_ToggleCheat(num)?"en":"dis");
}

static MemoryPatch GetCheatFields(const MemoryPatch &pin)
{
 MemoryPatch patch = pin;
 const bool support_read_subst = CurGame->CheatInfo.InstallReadPatch && CurGame->CheatInfo.RemoveReadPatches;

 CHEAT_printf("Name [%s]: ", patch.name.c_str());
 patch.name = GetString(patch.name);

 CHEAT_printf("Available types:");
 CHEAT_printf(" R - Replace/RAM write(high-level).");
 CHEAT_printf(" A - Addition/RAM read->add->write(high-level).");
 CHEAT_printf(" T - Transfer/RAM copy(high-level).");

 if(support_read_subst)
 {
  CHEAT_printf(" S - Subsitute on reads.");
  CHEAT_printf(" C - Substitute on reads, with compare.");
 }

 for(;;)
 {
  CHEAT_printf("Type [%c]: ", patch.type);
  patch.type = MDFN_azupper(CHEAT_getchar(patch.type));

  if(patch.type == 'R' || patch.type == 'A' || patch.type == 'T')
   break;

  if(support_read_subst && (patch.type == 'S' || patch.type == 'C'))
   break;
 }

 if(patch.type == 'T')
 {
  CHEAT_printf("Source address [$%08x]: ", (unsigned int)patch.copy_src_addr);
  patch.copy_src_addr = GetUI(patch.copy_src_addr);

  CHEAT_printf("Source address inc [%u]: ", patch.copy_src_addr_inc);
  patch.copy_src_addr_inc = GetUI(patch.copy_src_addr_inc);

  CHEAT_printf("Dest address [$%08x]: ", (unsigned int)patch.addr);
  patch.addr = GetUI(patch.addr);  

  CHEAT_printf("Dest address inc [%u]: ", patch.mltpl_addr_inc);
  patch.mltpl_addr_inc = GetUI(patch.mltpl_addr_inc);

  CHEAT_printf("Count [%u]: ", patch.mltpl_count);
  patch.mltpl_count = GetUI(patch.mltpl_count);

 }
 else
 {
  CHEAT_printf("Address [$%08x]: ", (unsigned int)patch.addr);
  patch.addr = GetUI(patch.addr);
 }

 if(patch.type == 'S' || patch.type == 'C')
  patch.length = 1;	// TODO in the future for GBA: support lengths other than 1 in core.
 else
 {
  do
  {
   if(patch.type == 'T')
   {
    //if(patch.length == 1 && patch.copy_src_addr_inc == 1 && patch.mltpl_addr_inc == 1)
    // break;

    //if((patch.copy_src_addr_inc == patch.mltpl_addr_inc) && patch.copy_src_addr_inc >= 1 && patch.copy_src_addr_inc <= 8)
    // CHEAT_printf("Transfer unit byte length should probably be \"%u\".", patch.copy_src_addr_inc);

    CHEAT_printf("Transfer unit byte length(1-8) [%u]: ", patch.length);
   }
   else 
    CHEAT_printf("Byte length(1-8) [%u]: ", patch.length);
   patch.length = GetUI(patch.length);
  } while(patch.length < 1 || patch.length > 8);
 }

 if(patch.length > 1 && (patch.type != 'S' && patch.type != 'C'))
 {
  CHEAT_printf("Big endian? [%c]: ", patch.bigendian ? 'Y' : 'N');
  patch.bigendian = GetYN(patch.bigendian);
 }
 else
  patch.bigendian = false;

 if(patch.type != 'T')
 {
  CHEAT_printf("Value [%03llu]: ", (unsigned long long)patch.val);
  patch.val = GetUI(patch.val);
 }

 // T type loop stuff is handled up above.
 if((patch.type != 'C' && patch.type != 'S' && patch.type != 'T') && patch.mltpl_count != 1)
 {
  CHEAT_printf("Loop count [%u]: ", patch.mltpl_count);
  patch.mltpl_count = GetUI(patch.mltpl_count);

  CHEAT_printf("Loop address inc [%u]: ", patch.mltpl_addr_inc);
  patch.mltpl_addr_inc = GetUI(patch.mltpl_addr_inc);

  CHEAT_printf("Loop value inc [%u]: ", patch.mltpl_val_inc);
  patch.mltpl_val_inc = GetUI(patch.mltpl_val_inc);
 }


 if(patch.type == 'C')
 {
  CHEAT_printf("Compare [%03lld]: ", patch.compare);
  patch.compare = GetUI(patch.compare);
 }

 if((patch.type != 'C' && patch.type != 'S') && patch.conditions.size())
 {
  CHEAT_printf("Conditions: %s", patch.conditions.c_str());	// Just informational for now.
  //CHEAT_printf("Conditions [%s]: ", );
  //patch.conditions = GetString();
 }

 CHEAT_printf("Enable? ");
 patch.status = GetYN(patch.status);

 return(patch);
}

static void ModifyCheat(int num)
{
 MemoryPatch patch = MDFNI_GetCheat(num);

 patch = GetCheatFields(patch);

 MDFNI_SetCheat(num, patch);
}

static void AddCodeCheat(void* data)
{
 const CheatFormatStruct* cf = (CheatFormatStruct*)data;
 MemoryPatch patch;
 unsigned iter = 0;
 std::string code;

 while(1)
 {
  if(iter == 0)
   CHEAT_printf("%s Code: ", cf->FullName);
  else
   CHEAT_printf("%s Code(part %u): ", cf->FullName, iter + 1);

  code = GetString();
  if(!code.size())
  {
   CHEAT_printf("Aborted.");
   return;
  }

  try
  {
   if(!cf->DecodeCheat(code, &patch))
    break;

   iter++;
  }
  catch(std::exception &e)
  {
   CHEAT_printf("Decode error: %s", e.what());
  }
 }

 if(patch.name.size() == 0)
  patch.name = code;

 CHEAT_printf("Name[%s]: ", patch.name.c_str());
 std::string name = GetString(); 

 if(name.size())
  patch.name = name;

 patch.status = true;

 CHEAT_printf("Add cheat?");
 if(GetYN(true))
 {
  try
  {
   MDFNI_AddCheat(patch);
  }
  catch(std::exception &e)
  {
   CHEAT_printf("Error adding cheat: %s", e.what());
   return;
  }
  CHEAT_puts("Cheat added.");
 }
}

static void AddCheatParam(uint32 A, uint64 V, unsigned int bytelen, bool bigendian)
{
 MemoryPatch patch;

 patch.addr = A;
 patch.val = V;
 patch.length = bytelen;
 patch.bigendian = bigendian;
 patch.type = 'R';
 patch.status = true;

 patch = GetCheatFields(patch);

 CHEAT_printf("Add cheat \"%s\" for address $%08x with value %llu?", patch.name.c_str(), (unsigned int)patch.addr, (unsigned long long)patch.val);
 if(GetYN(true))
 {
  try
  {
   MDFNI_AddCheat(patch);
  }
  catch(std::exception &e)
  {
   CHEAT_printf("Error adding cheat: %s", e.what());
   return;
  }
  CHEAT_puts("Cheat added.");
 }
}

static void AddCheat(void* data)
{
 AddCheatParam(0, 0, 1, CurGame->CheatInfo.BigEndian);
}

static int lid;
static int clistcallb(const MemoryPatch& patch, void *data)
{
 char tmp[512];
 int ret;

 if(!lid)
 {
  CHEAT_printf("  /---------------------------------------\\");
  CHEAT_printf("  |  Type  | Affected Addr Range | Name    \\");
  CHEAT_printf("  |-----------------------------------------\\");
 }

 if(patch.type == 'C' || patch.type == 'S')
 {
  trio_snprintf(tmp, 512, "%c %c    | $%08x           | %s", patch.status ? '*' : ' ', patch.type, patch.addr, patch.name.c_str());
  //trio_snprintf(tmp, 512, "%s %c $%08x:%lld:%lld - %s", patch.status ? "*" : " ", patch.type, patch.addr, patch.val, patch.compare, patch.name.c_str());
 }
 else
 {
  uint32 sa = patch.addr;
  uint32 ea = patch.addr + ((patch.mltpl_count - 1) * patch.mltpl_addr_inc) + (patch.length - 1);

  if(patch.mltpl_count == 0 || patch.length == 0)
   trio_snprintf(tmp, 512, "%c %c%s |                     | %s", patch.status ? '*' : ' ', patch.type, patch.conditions.size() ? "+CC" : "   ", patch.name.c_str());
  else
  {
   if(sa == ea)
    trio_snprintf(tmp, 512, "%c %c%s | $%08x           | %s", patch.status ? '*' : ' ', patch.type, patch.conditions.size() ? "+CC" : "   ", sa, patch.name.c_str());
   else
    trio_snprintf(tmp, 512, "%c %c%s | $%08x-$%08x | %s", patch.status ? '*' : ' ', patch.type, patch.conditions.size() ? "+CC" : "   ", sa, ea, patch.name.c_str());
  }
 }

 ret = AddToList(tmp, lid);
 lid++;
 return(ret);
}

static void ListCheats(void* data)
{
 int which;
 lid=0;

 BeginListShow();
 MDFNI_ListCheats(clistcallb,0);
 which=EndListShow();
 if(which>=0)
 {
  CHEAT_printf(" <(T)oggle status, (M)odify, or (D)elete this cheat.> ");
  std::string tmp = CHEAT_gets();

  if(tmp.size())
  {
   switch(MDFN_azlower(tmp[0]))
   {
    case 't':
	ToggleCheat(which);
	break;

    case 'd':
	try
	{
	 MDFNI_DelCheat(which);
	}
	catch(std::exception &e)
	{
	 CHEAT_printf("Error deleting cheat: %s", e.what());
	 break;
	 }
	CHEAT_puts("Cheat has been deleted.");
	break;

    case 'm':
	ModifyCheat(which);
	break;
   }
  }
 }
}

static void ResetSearch(void* data)
{
 MDFNI_CheatSearchBegin();
 CHEAT_puts("Done.");
}

static unsigned int searchbytelen;
static bool searchbigendian;

static int srescallb(uint32 a, uint64 last, uint64 current, void *data)
{
 char tmp[256];

 if(searchbytelen == 8)
  trio_snprintf(tmp, 256, "$%08x:%020llu:%020llu",(unsigned int)a,(unsigned long long)last,(unsigned long long)current);
 if(searchbytelen == 7)
  trio_snprintf(tmp, 256, "$%08x:%017llu:%017llu",(unsigned int)a,(unsigned long long)last,(unsigned long long)current);
 if(searchbytelen == 6)
  trio_snprintf(tmp, 256, "$%08x:%015llu:%015llu",(unsigned int)a,(unsigned long long)last,(unsigned long long)current);
 if(searchbytelen == 5)
  trio_snprintf(tmp, 256, "$%08x:%013llu:%013llu",(unsigned int)a,(unsigned long long)last,(unsigned long long)current);
 if(searchbytelen == 4)
  trio_snprintf(tmp, 256, "$%08x:%10u:%10u",(unsigned int)a,(unsigned int)last,(unsigned int)current);
 else if(searchbytelen == 3)
  trio_snprintf(tmp, 256, "$%08x:%08u:%08u",(unsigned int)a,(unsigned int)last,(unsigned int)current);
 else if(searchbytelen == 2)
  trio_snprintf(tmp, 256, "$%08x:%05u:%05u",(unsigned int)a,(unsigned int)last,(unsigned int)current);
 else if(searchbytelen == 1)
  trio_snprintf(tmp, 256, "$%08x:%03u:%03u",(unsigned int)a,(unsigned int)last,(unsigned int)current);
 else // > 4
  trio_snprintf(tmp, 256, "$%08x:%020llu:%020llu",(unsigned int)a,(unsigned long long)last,(unsigned long long)current);
 return(AddToList(tmp,a));
}

static void ShowRes(void* data)
{
 int n=MDFNI_CheatSearchGetCount();
 CHEAT_printf(" %d results:",n);
 if(n)
 {
  int which;
  BeginListShow();
  MDFNI_CheatSearchGet(srescallb, 0);
  which=EndListShow();
  if(which>=0)
   AddCheatParam(which,0, searchbytelen, searchbigendian);
 }
}

static int ShowShortList(const char *moe[], unsigned int n, int def)
{
 unsigned int x;
 int c;
 unsigned int baa;

 red:
 for(x=0;x<n;x++)
  CHEAT_printf("%d) %s",x+1,moe[x]);
 CHEAT_puts("D) Display List");
 clo:

 CHEAT_puts("");
 CHEAT_printf("Selection [%d]> ",def+1);
 std::string tmp = CHEAT_gets();
 if(!tmp.size())
  return def;

 c = MDFN_azlower(tmp[0]);
 baa = c - '1';

 if(baa < n)
  return baa;
 else if(c == 'd')
  goto red;
 else
 {
  CHEAT_puts("Invalid selection.");
  goto clo;
 }
}

static void DoSearch(void* data)
{
 static int v1=0,v2=0;
 static int method=0;

 const char *m[6]={"O==V1 && C==V2","O==V1 && |O-C|==V2","|O-C|==V2","O!=C","Value decreased","Value increased"};
 CHEAT_puts("");
 CHEAT_printf("Search Filter:");

 method = ShowShortList(m,6,method);

 if(method<=1)
 {
  CHEAT_printf("V1 [%03d]: ",v1);
  v1=GetUI(v1);
 }

 if(method<=2)
 {
  CHEAT_printf("V2 [%03d]: ",v2);
  v2=GetUI(v2);
 }

 CHEAT_printf("Byte length(1-8)[%1d]: ", searchbytelen);
 searchbytelen = GetUI(searchbytelen);

 if(searchbytelen > 1)
 {
  CHEAT_printf("Big endian? [%c]: ", searchbigendian ? 'Y' : 'N');
  searchbigendian = GetYN(searchbigendian);
 }

 MDFNI_CheatSearchEnd(method, v1, v2, searchbytelen, searchbigendian);
 CHEAT_puts("Search completed.");
}

static void DoMenu(const std::vector<MENU>& men, bool topmost = 0)
{
 bool MenuLoop = TRUE;

 while(MenuLoop)
 {
  int x;

  CHEAT_puts("");

  for(x = 0; x < (int)men.size(); x++)
   CHEAT_printf("%d) %s", x + 1, men[x].text.c_str());

  CHEAT_puts("D) Display Menu");

  if(!topmost)
   CHEAT_puts("X) Return to Previous");

  bool CommandLoop = TRUE;

  while(CommandLoop)
  {
   int c, c_numeral;

   CHEAT_printf("Command> ");
   std::string s = CHEAT_gets();

   if(!s.size())
    continue;

   c = MDFN_azlower(s[0]);
   if(c == 'd')
   {
    CommandLoop = FALSE;
   }
   else if(c == 'x' && !topmost)
   {
    CommandLoop = FALSE;
    MenuLoop = FALSE;
   }
   else if(trio_sscanf(s.c_str(), "%d", &c_numeral) == 1 && c_numeral <= x && c_numeral >= 1)
   {
    assert(!(men[c_numeral - 1].func_action && men[c_numeral - 1].menu_action));

    if(men[c_numeral - 1].func_action)
     men[c_numeral - 1].func_action(men[c_numeral - 1].data);
    else if(men[c_numeral - 1].menu_action)
     DoMenu(*men[c_numeral - 1].menu_action);	/* Mmm...recursivey goodness. */

    CommandLoop = FALSE;
   }
   else
   {
    CHEAT_puts("Invalid command.");
   }
  } // while(CommandLoop)
 } // while(MenuLoop)
}

int CheatLoop(void *arg)
{
 std::vector<MENU> NewCheatsMenu;
 std::vector<MENU> MainMenu;

 // TODO: Init on game load.
 searchbytelen = 1;
 searchbigendian = CurGame->CheatInfo.BigEndian;

 NewCheatsMenu.push_back( MENU(_("Add Cheat"), AddCheat, NULL) );
 NewCheatsMenu.push_back( MENU(_("Reset Search"), ResetSearch, NULL) );
 NewCheatsMenu.push_back( MENU(_("Do Search"), DoSearch, NULL) );
 NewCheatsMenu.push_back( MENU(_("Set Original to Current"), SetOC, NULL) );
 NewCheatsMenu.push_back( MENU(_("Unhide Excluded"), UnhideEx, NULL) );
 NewCheatsMenu.push_back( MENU(_("Show Results"), ShowRes, NULL) );

 MainMenu.push_back( MENU(_("List Cheats"), ListCheats, NULL) );
 MainMenu.push_back( MENU(_("Cheat Search..."), NULL, &NewCheatsMenu) );

 for(auto& cf : CurGame->CheatInfo.CheatFormatInfo)
 {
  char buf[256];
  trio_snprintf(buf, 256, _("Add %s Code"), cf.FullName);

  MainMenu.push_back( MENU(buf, AddCodeCheat, NULL, (void*)&cf) );
 }

 try
 {
  DoMenu(MainMenu, 1);
 }
 catch(...)
 {

 }

 return(1);
}

void CheatIF_GT_Show(bool show)
{
 if(!CheatMutex)
  CheatMutex = MDFND_CreateMutex();

 if(!CheatCond)
  CheatCond = MDFND_CreateCond();

 PauseGameLoop(show);
 if(show)
 {
  if(!CheatThread)
  {
   need_thread_exit = false;
   CheatThread = MDFND_CreateThread(CheatLoop, NULL);
  }
 }
 isactive = show;
}

bool CheatIF_Active(void)
{
 return(isactive);
}

void CheatIF_MT_Draw(const MDFN_PixelFormat& pformat, const int32 screen_w, const int32 screen_h)
{
 if(!isactive)
  return;

 //
 //
 //
 MDFN_Rect CheatRect;
 unsigned crs = 0;

 CheatRect.x = 0;
 CheatRect.y = 0;
 CheatRect.w = screen_w;
 CheatRect.h = screen_h;

 while((CheatRect.h >> crs) >= 1024 && (CheatRect.w >> crs) >= 1024)
  crs++;

 CheatRect.w >>= crs;
 CheatRect.h >>= crs;

 MDFN_Rect zederect;

 zederect.x = 0;
 zederect.y = 0;
 zederect.w = CheatRect.w << crs;
 zederect.h = CheatRect.h << crs;

 //
 unsigned fontid = MDFN_FONT_9x18_18x18;

 if(CheatRect.w < 342 || CheatRect.h < 342)
  fontid = MDFN_FONT_5x7;
 else if(CheatRect.w < 512 || CheatRect.h < 480)
  fontid = MDFN_FONT_6x13_12x13;
 else
  fontid = MDFN_FONT_9x18_18x18;

 BlitRaw(CheatConsole.CheatConsoleT::Draw(pformat, CheatRect.w, CheatRect.h, fontid), &CheatRect, &zederect);
}

int CheatIF_MT_EventHook(const SDL_Event *event)
{
 if(!isactive) return(1);

 return(CheatConsole.CheatConsoleT::Event(event));
}

#if 0
// TODO:
void CheatIF_Kill(void)
{
 if(CheatThread != NULL)
 {
  MDFND_LockMutex(CheatMutex);
  need_thread_exit = true;
  MDFND_SignalCond(CheatCond);
  MDFND_UnlockMutex(CheatMutex);
 
  MDFND_WaitThread(CheatThread, NULL);
 }

 if(CheatCond != NULL)
 {
  MDFND_DestroyCond(CheatCond);
  CheatCond = NULL;
 }

 if(CheatMutex != NULL)
 {
  MDFND_DestroyMutex(CheatMutex);
  CheatMutex = NULL;
 }

 if(pending_text)
 {
  free(pending_text);
  pending_text = NULL;
 }
}
#endif
