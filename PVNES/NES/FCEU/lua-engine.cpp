#ifdef __linux
#include <unistd.h>
#define SetCurrentDir chdir
#include <sys/types.h>
#include <sys/wait.h>
#endif

#ifdef WIN32
#include <direct.h>
#define SetCurrentDir _chdir
#endif

#include "types.h"
#include "fceu.h"
#include "video.h"
#include "debug.h"
#include "sound.h"
#include "drawing.h"
#include "state.h"
#include "movie.h"
#include "driver.h"
#include "cheat.h"
#include "x6502.h"
#include "utils/xstring.h"
#include "utils/memory.h"
#include "utils/crc32.h"
#include "fceulua.h"

#ifdef WIN32
#include "drivers/win/common.h"
#include "drivers/win/main.h"
#include "drivers/win/taseditor/selection.h"
#include "drivers/win/taseditor/laglog.h"
#include "drivers/win/taseditor/markers.h"
#include "drivers/win/taseditor/snapshot.h"
#include "drivers/win/taseditor/taseditor_lua.h"
extern TASEDITOR_LUA taseditor_lua;
#endif

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <cassert>
#include <cstdlib>
#include <cmath>
#include <zlib.h>

#include <vector>
#include <map>
#include <string>
#include <algorithm>
#include <bitset>

#include "x6502abbrev.h"

bool CheckLua()
{
#ifdef WIN32
	HMODULE mod = LoadLibrary("lua51.dll");
	if(!mod)
	{
		return false;
	}
	FreeLibrary(mod);
	return true;
#else
	return true;
#endif
}

bool DemandLua()
{
#ifdef WIN32
	if(!CheckLua())
	{
		MessageBox(NULL, "lua51.dll was not found. Please get it into your PATH or in the same directory as fceux.exe", "FCEUX", MB_OK | MB_ICONERROR);
		return false;
	}
	return true;
#else
	return true;
#endif
}

extern "C"
{
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#ifdef WIN32
#include <lstate.h>
	int iuplua_open(lua_State * L);
	int iupcontrolslua_open(lua_State * L);
	int luaopen_winapi(lua_State * L);

	//luasocket
	int luaopen_socket_core(lua_State *L);
	int luaopen_mime_core(lua_State *L);
#endif
}

#ifndef TRUE
#define TRUE 1
#define FALSE 0
#endif

#ifndef _MSC_VER
 #define stricmp  strcasecmp
 #define strnicmp strncasecmp

 #ifdef __GNUC__
  #define __forceinline __attribute__ ((always_inline))
 #else
  #define __forceinline
 #endif
#endif

#ifdef WIN32
extern void AddRecentLuaFile(const char *filename);
#endif

extern bool turbo;
extern int32 fps_scale;

struct LuaSaveState {
	std::string filename;
	EMUFILE_MEMORY *data;
	bool anonymous, persisted;
	LuaSaveState()
		: data(0)
		, anonymous(false)
		, persisted(false)
	{}
	~LuaSaveState() {
		if(data) delete data;
	}
	void persist() {
		persisted = true;
		FILE* outf = fopen(filename.c_str(),"wb");
		fwrite(data->buf(),1,data->size(),outf);
		fclose(outf);
	}
	void ensureLoad() {
		if(data) return;
		persisted = true;
		FILE* inf = fopen(filename.c_str(),"rb");
		fseek(inf,0,SEEK_END);
		int len = ftell(inf);
		fseek(inf,0,SEEK_SET);
		data = new EMUFILE_MEMORY(len);
		fread(data->buf(),1,len,inf);
		fclose(inf);
	}
};

static void(*info_print)(int uid, const char* str);
static void(*info_onstart)(int uid);
static void(*info_onstop)(int uid);
static int info_uid;
#ifdef WIN32
extern HWND LuaConsoleHWnd;
extern INT_PTR CALLBACK DlgLuaScriptDialog(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam);
extern void PrintToWindowConsole(int hDlgAsInt, const char* str);
extern void WinLuaOnStart(int hDlgAsInt);
extern void WinLuaOnStop(int hDlgAsInt);
void TaseditorDisableManualFunctionIfNeeded();
#endif

static lua_State *L;

static int luaexiterrorcount = 8;

// Are we running any code right now?
static char *luaScriptName = NULL;

// Are we running any code right now?
int luaRunning = FALSE;

// True at the frame boundary, false otherwise.
static int frameBoundary = FALSE;

// The execution speed we're running at.
static enum {SPEED_NORMAL, SPEED_NOTHROTTLE, SPEED_TURBO, SPEED_MAXIMUM} speedmode = SPEED_NORMAL;

// Rerecord count skip mode
static int skipRerecords = FALSE;

// Used by the registry to find our functions
static const char *frameAdvanceThread = "FCEU.FrameAdvance";
static const char *guiCallbackTable = "FCEU.GUI";

// True if there's a thread waiting to run after a run of frame-advance.
static int frameAdvanceWaiting = FALSE;

// We save our pause status in the case of a natural death.
static int wasPaused = FALSE;

// Transparency strength. 255=opaque, 0=so transparent it's invisible
static int transparencyModifier = 255;

// Our joypads.
static uint8 luajoypads1[4]= { 0xFF, 0xFF, 0xFF, 0xFF }; //x1
static uint8 luajoypads2[4]= { 0x00, 0x00, 0x00, 0x00 }; //0x
/* Crazy logic stuff.
	11 - true		01 - pass-through (default)
	00 - false		10 - invert					*/

static enum { GUI_USED_SINCE_LAST_DISPLAY, GUI_USED_SINCE_LAST_FRAME, GUI_CLEAR } gui_used = GUI_CLEAR;
static uint8 *gui_data = NULL;
static int gui_saw_current_palette = FALSE;

// Protects Lua calls from going nuts.
// We set this to a big number like 1000 and decrement it
// over time. The script gets knifed once this reaches zero.
static int numTries;

// number of registered memory functions (1 per hooked byte)
static unsigned int numMemHooks;

// Look in fceu.h for macros named like JOY_UP to determine the order.
static const char *button_mappings[] = {
	"A", "B", "select", "start", "up", "down", "left", "right"
};

#ifdef _MSC_VER
	#define snprintf _snprintf
	#define vscprintf _vscprintf
#else
	#define stricmp strcasecmp
	#define strnicmp strncasecmp
#endif

static const char* luaCallIDStrings [] =
{
	"CALL_BEFOREEMULATION",
	"CALL_AFTEREMULATION",
	"CALL_BEFOREEXIT",
	"CALL_BEFORESAVE",
	"CALL_AFTERLOAD",
	"CALL_TASEDITOR_AUTO",
	"CALL_TASEDITOR_MANUAL",

};

//make sure we have the right number of strings
CTASSERT(sizeof(luaCallIDStrings)/sizeof(*luaCallIDStrings) == LUACALL_COUNT)

static const char* luaMemHookTypeStrings [] =
{
	"MEMHOOK_WRITE",
	"MEMHOOK_READ",
	"MEMHOOK_EXEC",

	"MEMHOOK_WRITE_SUB",
	"MEMHOOK_READ_SUB",
	"MEMHOOK_EXEC_SUB",
};

//make sure we have the right number of strings
CTASSERT(sizeof(luaMemHookTypeStrings)/sizeof(*luaMemHookTypeStrings) ==  LUAMEMHOOK_COUNT)

static char* rawToCString(lua_State* L, int idx=0);
static const char* toCString(lua_State* L, int idx=0);

/**
 * Resets emulator speed / pause states after script exit.
 */
static void FCEU_LuaOnStop()
{
	luaRunning = FALSE;
	for (int i = 0 ; i < 4 ; i++ ){
		luajoypads1[i]= 0xFF;	// Set these back to pass-through
		luajoypads2[i]= 0x00;
	}
	gui_used = GUI_CLEAR;
	//if (wasPaused && !FCEUI_EmulationPaused())
	//	FCEUI_ToggleEmulationPause();

	//zero 21-nov-2014 - this variable doesnt exist outside windows so it cant have this feature
	#ifdef _MSC_VER
	if (fps_scale != 256)							//thanks, we already know it's on normal speed
		FCEUD_SetEmulationSpeed(EMUSPEED_NORMAL);	//TODO: Ideally lua returns the speed to the speed the user set before running the script
													//rather than returning it to normal, and turbo off.  Perhaps some flags and a FCEUD_GetEmulationSpeed function
	#endif

	turbo = false;
	//FCEUD_TurboOff();
#ifdef WIN32
	TaseditorDisableManualFunctionIfNeeded();
#endif
}


/**
 * Asks Lua if it wants control of the emulator's speed.
 * Returns 0 if no, 1 if yes. If yes, caller should also
 * consult FCEU_LuaFrameSkip().
 */
int FCEU_LuaSpeed() {
	if (!L || !luaRunning)
		return 0;

	//printf("%d\n", speedmode);

	switch (speedmode) {
	case SPEED_NOTHROTTLE:
	case SPEED_TURBO:
	case SPEED_MAXIMUM:
		return 1;
	case SPEED_NORMAL:
	default:
		return 0;
	}
}

/**
 * Asks Lua if it wants control whether this frame is skipped.
 * Returns 0 if no, 1 if frame should be skipped, -1 if it should not be.
 */
int FCEU_LuaFrameSkip() {
	if (!L || !luaRunning)
		return 0;

	switch (speedmode) {
	case SPEED_NORMAL:
		return 0;
	case SPEED_NOTHROTTLE:
		return -1;
	case SPEED_TURBO:
		return 0;
	case SPEED_MAXIMUM:
		return 1;
	}
	return 0;
}

/**
 * Toggle certain rendering planes
 * emu.setrenderingplanes(sprites, background)
 * Accepts two (lua) boolean values and acts accordingly
*/
static int emu_setrenderplanes(lua_State *L) {
	bool sprites = (lua_toboolean( L, 1 ) == 1);
	bool background = (lua_toboolean( L, 2 ) == 1);
	FCEUI_SetRenderPlanes(sprites, background);
	return 0;
}

///////////////////////////



// emu.speedmode(string mode)
//
//   Takes control of the emulation speed
//   of the system. Normal is normal speed (60fps, 50 for PAL),
//   nothrottle disables speed control but renders every frame,
//   turbo renders only a few frames in order to speed up emulation,
//   maximum renders no frames
//   TODO: better enforcement, done in the same way as basicbot...
static int emu_speedmode(lua_State *L) {
	const char *mode = luaL_checkstring(L,1);

	if (strcasecmp(mode, "normal")==0) {
		speedmode = SPEED_NORMAL;
	} else if (strcasecmp(mode, "nothrottle")==0) {
		speedmode = SPEED_NOTHROTTLE;
	} else if (strcasecmp(mode, "turbo")==0) {
		speedmode = SPEED_TURBO;
	} else if (strcasecmp(mode, "maximum")==0) {
		speedmode = SPEED_MAXIMUM;
	} else
		luaL_error(L, "Invalid mode %s to emu.speedmode",mode);

	//printf("new speed mode:  %d\n", speedmode);
        if (speedmode == SPEED_NORMAL)
		{
			FCEUD_SetEmulationSpeed(EMUSPEED_NORMAL);
			FCEUD_TurboOff();
		}
        else if (speedmode == SPEED_TURBO)				//adelikat: Making turbo actually use turbo.
			FCEUD_TurboOn();							//Turbo and max speed are two different results. Turbo employs frame skipping and sound bypassing if mute turbo option is enabled.
												//This makes it faster but with frame skipping. Therefore, maximum is still a useful feature, in case the user is recording an avi or making screenshots (or something else that needs all frames)
		else
			FCEUD_SetEmulationSpeed(EMUSPEED_FASTEST);  //TODO: Make nothrottle turn off throttle, or remove the option
	return 0;
}

// emu.poweron()
//
// Executes a power cycle
static int emu_poweron(lua_State *L) {
	if (GameInfo)
		FCEUI_PowerNES();

	return 0;
}

// emu.softreset()
//
// Executes a power cycle
static int emu_softreset(lua_State *L) {
	if (GameInfo)
		FCEUI_ResetNES();

	return 0;
}

// emu.frameadvance()
//
//  Executes a frame advance. Occurs by yielding the coroutine, then re-running
//  when we break out.
static int emu_frameadvance(lua_State *L) {
	// We're going to sleep for a frame-advance. Take notes.

	if (frameAdvanceWaiting)
		return luaL_error(L, "can't call emu.frameadvance() from here");

	frameAdvanceWaiting = TRUE;

	// Now we can yield to the main
	return lua_yield(L, 0);


	// It's actually rather disappointing...
}

// bool emu.paused()
static int emu_paused(lua_State *L)
{
	lua_pushboolean(L, FCEUI_EmulationPaused() != 0);
	return 1;
}

// emu.pause()
//
//  Pauses the emulator. Returns immediately.
static int emu_pause(lua_State *L)
{
	if (!FCEUI_EmulationPaused())
		FCEUI_ToggleEmulationPause();
	return 0;
}

//emu.unpause()
//
//  Unpauses the emulator. Returns immediately.
static int emu_unpause(lua_State *L)
{
	if (FCEUI_EmulationPaused())
		FCEUI_ToggleEmulationPause();
	return 0;
}


// emu.message(string msg)
//
//  Displays the given message on the screen.
static int emu_message(lua_State *L) {

	const char *msg = luaL_checkstring(L,1);
	FCEU_DispMessage("%s",0, msg);

	return 0;
}

// emu.getdir()
//
//  Returns the path of fceux.exe as a string.
static int emu_getdir(lua_State *L) {
#ifdef WIN32
	TCHAR fullPath[2048];
	TCHAR driveLetter[3];
	TCHAR directory[2048];
	TCHAR finalPath[2048];

	GetModuleFileName(NULL, fullPath, 2048);
	_splitpath(fullPath, driveLetter, directory, NULL, NULL);
	snprintf(finalPath, sizeof(finalPath), "%s%s", driveLetter, directory);
	lua_pushstring(L, finalPath);

	return 1;
#endif
}

// emu.loadrom(string filename)
//
//  Loads the rom from the directory relative to the lua script or from the absolute path.
//  If the rom can't e loaded, loads the most recent one.
static int emu_loadrom(lua_State *L) {
#ifdef WIN32
	const char *nameo2 = luaL_checkstring(L,1);
	char nameo[2048];
	strncpy(nameo, nameo2, sizeof(nameo));
	if (!ALoad(nameo)) {
		extern void LoadRecentRom(int slot);
		LoadRecentRom(0);
		return 0;
	} else {
		return 1;
	}
#endif
}


static int emu_registerbefore(lua_State *L) {
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);
	lua_settop(L,1);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFOREEMULATION]);
	lua_insert(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFOREEMULATION]);
	//StopScriptIfFinished(luaStateToUIDMap[L]);
	return 1;
}

static int emu_registerafter(lua_State *L) {
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);
	lua_settop(L,1);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_AFTEREMULATION]);
	lua_insert(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_AFTEREMULATION]);
	//StopScriptIfFinished(luaStateToUIDMap[L]);
	return 1;
}

static int emu_registerexit(lua_State *L) {
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);
	lua_settop(L,1);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFOREEXIT]);
	lua_insert(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFOREEXIT]);
	//StopScriptIfFinished(luaStateToUIDMap[L]);
	return 1;
}

static int emu_addgamegenie(lua_State *L) {

	const char *msg = luaL_checkstring(L,1);

	// Add a Game Genie code if it hasn't already been added
	int GGaddr, GGcomp, GGval;
	int i=0;

	uint32 Caddr;
	uint8 Cval;
	int Ccompare, Ctype;

	if (!FCEUI_DecodeGG(msg, &GGaddr, &GGval, &GGcomp)) {
		luaL_error(L, "Failed to decode game genie code");
		lua_pushboolean(L, false);
		return 1;
	}

	while (FCEUI_GetCheat(i,NULL,&Caddr,&Cval,&Ccompare,NULL,&Ctype)) {

		if ((GGaddr == Caddr) && (GGval == Cval) && (GGcomp == Ccompare) && (Ctype == 1)) {
			// Already Added, so consider it a success
			lua_pushboolean(L, true);
			return 1;
		}

		i = i + 1;
	}

	if (FCEUI_AddCheat(msg,GGaddr,GGval,GGcomp,1)) {
		// Code was added
		// Can't manage the display update the way I want, so I won't bother with it
		// UpdateCheatsAdded();
		lua_pushboolean(L, true);
		return 1;
	} else {
		// Code didn't get added
		lua_pushboolean(L, false);
		return 1;
	}
}

static int emu_delgamegenie(lua_State *L) {

	const char *msg = luaL_checkstring(L,1);

	// Remove a Game Genie code. Very restrictive about deleted code.
	int GGaddr, GGcomp, GGval;
	uint32 i=0;

	char * Cname;
	uint32 Caddr;
	uint8 Cval;
	int Ccompare, Ctype;

	if (!FCEUI_DecodeGG(msg, &GGaddr, &GGval, &GGcomp)) {
		luaL_error(L, "Failed to decode game genie code");
		lua_pushboolean(L, false);
		return 1;
	}

	while (FCEUI_GetCheat(i,&Cname,&Caddr,&Cval,&Ccompare,NULL,&Ctype)) {

		if ((!strcmp(msg,Cname)) && (GGaddr == Caddr) && (GGval == Cval) && (GGcomp == Ccompare) && (Ctype == 1)) {
			// Delete cheat code
			if (FCEUI_DelCheat(i)) {
				lua_pushboolean(L, true);
				return 1;
			}
			else {
				lua_pushboolean(L, false);
				return 1;
			}
		}

		i = i + 1;
	}

	// Cheat didn't exist, so it's not an error
	lua_pushboolean(L, true);
	return 1;
}


// can't remember what the best way of doing this is...
#if defined(i386) || defined(__i386) || defined(__i386__) || defined(M_I86) || defined(_M_IX86) || defined(WIN32)
	#define IS_LITTLE_ENDIAN
#endif

// push a value's bytes onto the output stack
template<typename T>
void PushBinaryItem(T item, std::vector<unsigned char>& output)
{
	unsigned char* buf = (unsigned char*)&item;
#ifdef IS_LITTLE_ENDIAN
	for(int i = sizeof(T); i; i--)
		output.push_back(*buf++);
#else
	int vecsize = output.size();
	for(int i = sizeof(T); i; i--)
		output.insert(output.begin() + vecsize, *buf++);
#endif
}
// read a value from the byte stream and advance the stream by its size
template<typename T>
T AdvanceByteStream(const unsigned char*& data, unsigned int& remaining)
{
#ifdef IS_LITTLE_ENDIAN
	T rv = *(T*)data;
	data += sizeof(T);
#else
	T rv; unsigned char* rvptr = (unsigned char*)&rv;
	for(int i = sizeof(T)-1; i>=0; i--)
		rvptr[i] = *data++;
#endif
	remaining -= sizeof(T);
	return rv;
}
// advance the byte stream by a certain size without reading a value
void AdvanceByteStream(const unsigned char*& data, unsigned int& remaining, int amount)
{
	data += amount;
	remaining -= amount;
}

#define LUAEXT_TLONG		30 // 0x1E // 4-byte signed integer
#define LUAEXT_TUSHORT		31 // 0x1F // 2-byte unsigned integer
#define LUAEXT_TSHORT		32 // 0x20 // 2-byte signed integer
#define LUAEXT_TBYTE		33 // 0x21 // 1-byte unsigned integer
#define LUAEXT_TNILS		34 // 0x22 // multiple nils represented by a 4-byte integer (warning: becomes multiple stack entities)
#define LUAEXT_TTABLE		0x40 // 0x40 through 0x4F // tables of different sizes:
#define LUAEXT_BITS_1A		0x01 // size of array part fits in a 1-byte unsigned integer
#define LUAEXT_BITS_2A		0x02 // size of array part fits in a 2-byte unsigned integer
#define LUAEXT_BITS_4A		0x03 // size of array part fits in a 4-byte unsigned integer
#define LUAEXT_BITS_1H		0x04 // size of hash part fits in a 1-byte unsigned integer
#define LUAEXT_BITS_2H		0x08 // size of hash part fits in a 2-byte unsigned integer
#define LUAEXT_BITS_4H		0x0C // size of hash part fits in a 4-byte unsigned integer
#define BITMATCH(x,y) (((x) & (y)) == (y))

static void PushNils(std::vector<unsigned char>& output, int& nilcount)
{
	int count = nilcount;
	nilcount = 0;

	static const int minNilsWorthEncoding = 6; // because a LUAEXT_TNILS entry is 5 bytes

	if(count < minNilsWorthEncoding)
	{
		for(int i = 0; i < count; i++)
			output.push_back(LUA_TNIL);
	}
	else
	{
		output.push_back(LUAEXT_TNILS);
		PushBinaryItem<uint32>(count, output);
	}
}

static std::vector<const void*> s_tableAddressStack; // prevents infinite recursion of a table within a table (when cycle is found, print something like table:parent)
static std::vector<const void*> s_metacallStack; // prevents infinite recursion if something's __tostring returns another table that contains that something (when cycle is found, print the inner result without using __tostring)

static void LuaStackToBinaryConverter(lua_State* L, int i, std::vector<unsigned char>& output)
{
	int type = lua_type(L, i);

	// the first byte of every serialized item says what Lua type it is
	output.push_back(type & 0xFF);

	switch(type)
	{
		default:
			{
				char errmsg [1024];
				sprintf(errmsg, "values of type \"%s\" are not allowed to be returned from registered save functions.\r\n", luaL_typename(L,i));
				if(info_print)
					info_print(info_uid, errmsg);
				else
					puts(errmsg);
			}
			break;
		case LUA_TNIL:
			// no information necessary beyond the type
			break;
		case LUA_TBOOLEAN:
			// serialize as 0 or 1
			output.push_back(lua_toboolean(L,i));
			break;
		case LUA_TSTRING:
			// serialize as a 0-terminated string of characters
			{
				const char* str = lua_tostring(L,i);
				while(*str)
					output.push_back(*str++);
				output.push_back('\0');
			}
			break;
		case LUA_TNUMBER:
			{
				double num = (double)lua_tonumber(L,i);
				int32 inum = (int32)lua_tointeger(L,i);
				if(num != inum)
				{
					PushBinaryItem(num, output);
				}
				else
				{
					if((inum & ~0xFF) == 0)
						type = LUAEXT_TBYTE;
					else if((uint16)(inum & 0xFFFF) == inum)
						type = LUAEXT_TUSHORT;
					else if((int16)(inum & 0xFFFF) == inum)
						type = LUAEXT_TSHORT;
					else
						type = LUAEXT_TLONG;
					output.back() = type;
					switch(type)
					{
					case LUAEXT_TLONG:
						PushBinaryItem<int32>(static_cast<int32>(inum), output);
						break;
					case LUAEXT_TUSHORT:
						PushBinaryItem<uint16>(static_cast<uint16>(inum), output);
						break;
					case LUAEXT_TSHORT:
						PushBinaryItem<int16>(static_cast<int16>(inum), output);
						break;
					case LUAEXT_TBYTE:
						output.push_back(static_cast<uint8>(inum));
						break;
					}
				}
			}
			break;
		case LUA_TTABLE:
			// serialize as a type that describes how many bytes are used for storing the counts,
			// followed by the number of array entries if any, then the number of hash entries if any,
			// then a Lua value per array entry, then a (key,value) pair of Lua values per hashed entry
			// note that the structure of table references are not faithfully serialized (yet)
		{
			int outputTypeIndex = output.size() - 1;
			int arraySize = 0;
			int hashSize = 0;

			if(lua_checkstack(L, 4) && std::find(s_tableAddressStack.begin(), s_tableAddressStack.end(), lua_topointer(L,i)) == s_tableAddressStack.end())
			{
				s_tableAddressStack.push_back(lua_topointer(L,i));
				struct Scope { ~Scope(){ s_tableAddressStack.pop_back(); } } scope;

				bool wasnil = false;
				int nilcount = 0;
				arraySize = lua_objlen(L, i);
				int arrayValIndex = lua_gettop(L) + 1;
				for(int j = 1; j <= arraySize; j++)
				{
			        lua_rawgeti(L, i, j);
					bool isnil = lua_isnil(L, arrayValIndex);
					if(isnil)
						nilcount++;
					else
					{
						if(wasnil)
							PushNils(output, nilcount);
						LuaStackToBinaryConverter(L, arrayValIndex, output);
					}
					lua_pop(L, 1);
					wasnil = isnil;
				}
				if(wasnil)
					PushNils(output, nilcount);

				if(arraySize)
					lua_pushinteger(L, arraySize); // before first key
				else
					lua_pushnil(L); // before first key

				int keyIndex = lua_gettop(L);
				int valueIndex = keyIndex + 1;
				while(lua_next(L, i))
				{
//					assert(lua_type(L, keyIndex) && "nil key in Lua table, impossible");
//					assert(lua_type(L, valueIndex) && "nil value in Lua table, impossible");
					LuaStackToBinaryConverter(L, keyIndex, output);
					LuaStackToBinaryConverter(L, valueIndex, output);
					lua_pop(L, 1);
					hashSize++;
				}
			}

			int outputType = LUAEXT_TTABLE;
			if(arraySize & 0xFFFF0000)
				outputType |= LUAEXT_BITS_4A;
			else if(arraySize & 0xFF00)
				outputType |= LUAEXT_BITS_2A;
			else if(arraySize & 0xFF)
				outputType |= LUAEXT_BITS_1A;
			if(hashSize & 0xFFFF0000)
				outputType |= LUAEXT_BITS_4H;
			else if(hashSize & 0xFF00)
				outputType |= LUAEXT_BITS_2H;
			else if(hashSize & 0xFF)
				outputType |= LUAEXT_BITS_1H;
			output[outputTypeIndex] = outputType;

			int insertIndex = outputTypeIndex;
			if(BITMATCH(outputType,LUAEXT_BITS_4A) || BITMATCH(outputType,LUAEXT_BITS_2A) || BITMATCH(outputType,LUAEXT_BITS_1A))
				output.insert(output.begin() + (++insertIndex), arraySize & 0xFF);
			if(BITMATCH(outputType,LUAEXT_BITS_4A) || BITMATCH(outputType,LUAEXT_BITS_2A))
				output.insert(output.begin() + (++insertIndex), (arraySize & 0xFF00) >> 8);
			if(BITMATCH(outputType,LUAEXT_BITS_4A))
				output.insert(output.begin() + (++insertIndex), (arraySize & 0x00FF0000) >> 16),
				output.insert(output.begin() + (++insertIndex), (arraySize & 0xFF000000) >> 24);
			if(BITMATCH(outputType,LUAEXT_BITS_4H) || BITMATCH(outputType,LUAEXT_BITS_2H) || BITMATCH(outputType,LUAEXT_BITS_1H))
				output.insert(output.begin() + (++insertIndex), hashSize & 0xFF);
			if(BITMATCH(outputType,LUAEXT_BITS_4H) || BITMATCH(outputType,LUAEXT_BITS_2H))
				output.insert(output.begin() + (++insertIndex), (hashSize & 0xFF00) >> 8);
			if(BITMATCH(outputType,LUAEXT_BITS_4H))
				output.insert(output.begin() + (++insertIndex), (hashSize & 0x00FF0000) >> 16),
				output.insert(output.begin() + (++insertIndex), (hashSize & 0xFF000000) >> 24);

		}	break;
	}
}


// complements LuaStackToBinaryConverter
void BinaryToLuaStackConverter(lua_State* L, const unsigned char*& data, unsigned int& remaining)
{
//	assert(s_dbg_dataSize - (data - s_dbg_dataStart) == remaining);

	unsigned char type = AdvanceByteStream<unsigned char>(data, remaining);

	switch(type)
	{
		default:
			{
				char errmsg [1024];
				if(type <= 10 && type != LUA_TTABLE)
					sprintf(errmsg, "values of type \"%s\" are not allowed to be loaded into registered load functions. The save state's Lua save data file might be corrupted.\r\n", lua_typename(L,type));
				else
					sprintf(errmsg, "The save state's Lua save data file seems to be corrupted.\r\n");
				if(info_print)
					info_print(info_uid, errmsg);
				else
					puts(errmsg);
			}
			break;
		case LUA_TNIL:
			lua_pushnil(L);
			break;
		case LUA_TBOOLEAN:
			lua_pushboolean(L, AdvanceByteStream<uint8>(data, remaining));
			break;
		case LUA_TSTRING:
			lua_pushstring(L, (const char*)data);
			AdvanceByteStream(data, remaining, strlen((const char*)data) + 1);
			break;
		case LUA_TNUMBER:
			lua_pushnumber(L, AdvanceByteStream<double>(data, remaining));
			break;
		case LUAEXT_TLONG:
			lua_pushinteger(L, AdvanceByteStream<int32>(data, remaining));
			break;
		case LUAEXT_TUSHORT:
			lua_pushinteger(L, AdvanceByteStream<uint16>(data, remaining));
			break;
		case LUAEXT_TSHORT:
			lua_pushinteger(L, AdvanceByteStream<int16>(data, remaining));
			break;
		case LUAEXT_TBYTE:
			lua_pushinteger(L, AdvanceByteStream<uint8>(data, remaining));
			break;
		case LUAEXT_TTABLE:
		case LUAEXT_TTABLE | LUAEXT_BITS_1A:
		case LUAEXT_TTABLE | LUAEXT_BITS_2A:
		case LUAEXT_TTABLE | LUAEXT_BITS_4A:
		case LUAEXT_TTABLE | LUAEXT_BITS_1H:
		case LUAEXT_TTABLE | LUAEXT_BITS_2H:
		case LUAEXT_TTABLE | LUAEXT_BITS_4H:
		case LUAEXT_TTABLE | LUAEXT_BITS_1A | LUAEXT_BITS_1H:
		case LUAEXT_TTABLE | LUAEXT_BITS_2A | LUAEXT_BITS_1H:
		case LUAEXT_TTABLE | LUAEXT_BITS_4A | LUAEXT_BITS_1H:
		case LUAEXT_TTABLE | LUAEXT_BITS_1A | LUAEXT_BITS_2H:
		case LUAEXT_TTABLE | LUAEXT_BITS_2A | LUAEXT_BITS_2H:
		case LUAEXT_TTABLE | LUAEXT_BITS_4A | LUAEXT_BITS_2H:
		case LUAEXT_TTABLE | LUAEXT_BITS_1A | LUAEXT_BITS_4H:
		case LUAEXT_TTABLE | LUAEXT_BITS_2A | LUAEXT_BITS_4H:
		case LUAEXT_TTABLE | LUAEXT_BITS_4A | LUAEXT_BITS_4H:
			{
				unsigned int arraySize = 0;
				if(BITMATCH(type,LUAEXT_BITS_4A) || BITMATCH(type,LUAEXT_BITS_2A) || BITMATCH(type,LUAEXT_BITS_1A))
					arraySize |= AdvanceByteStream<uint8>(data, remaining);
				if(BITMATCH(type,LUAEXT_BITS_4A) || BITMATCH(type,LUAEXT_BITS_2A))
					arraySize |= ((uint16)AdvanceByteStream<uint8>(data, remaining)) << 8;
				if(BITMATCH(type,LUAEXT_BITS_4A))
					arraySize |= ((uint32)AdvanceByteStream<uint8>(data, remaining)) << 16,
					arraySize |= ((uint32)AdvanceByteStream<uint8>(data, remaining)) << 24;

				unsigned int hashSize = 0;
				if(BITMATCH(type,LUAEXT_BITS_4H) || BITMATCH(type,LUAEXT_BITS_2H) || BITMATCH(type,LUAEXT_BITS_1H))
					hashSize |= AdvanceByteStream<uint8>(data, remaining);
				if(BITMATCH(type,LUAEXT_BITS_4H) || BITMATCH(type,LUAEXT_BITS_2H))
					hashSize |= ((uint16)AdvanceByteStream<uint8>(data, remaining)) << 8;
				if(BITMATCH(type,LUAEXT_BITS_4H))
					hashSize |= ((uint32)AdvanceByteStream<uint8>(data, remaining)) << 16,
					hashSize |= ((uint32)AdvanceByteStream<uint8>(data, remaining)) << 24;

				lua_checkstack(L, 8);

				lua_createtable(L, arraySize, hashSize);

				unsigned int n = 1;
				while(n <= arraySize)
				{
					if(*data == LUAEXT_TNILS)
					{
						AdvanceByteStream(data, remaining, 1);
						n += AdvanceByteStream<uint32>(data, remaining);
					}
					else
					{
						BinaryToLuaStackConverter(L, data, remaining); // push value
						lua_rawseti(L, -2, n); // table[n] = value
						n++;
					}
				}

				for(unsigned int h = 1; h <= hashSize; h++)
				{
					BinaryToLuaStackConverter(L, data, remaining); // push key
					BinaryToLuaStackConverter(L, data, remaining); // push value
					lua_rawset(L, -3); // table[key] = value
				}
			}
			break;
	}
}

static const unsigned char luaBinaryMajorVersion = 9;
static const unsigned char luaBinaryMinorVersion = 1;

unsigned char* LuaStackToBinary(lua_State* L, unsigned int& size)
{
	int n = lua_gettop(L);
	if(n == 0)
		return NULL;

	std::vector<unsigned char> output;
	output.push_back(luaBinaryMajorVersion);
	output.push_back(luaBinaryMinorVersion);

	for(int i = 1; i <= n; i++)
		LuaStackToBinaryConverter(L, i, output);

	unsigned char* rv = new unsigned char [output.size()];
	memcpy(rv, &output.front(), output.size());
	size = output.size();
	return rv;
}

void BinaryToLuaStack(lua_State* L, const unsigned char* data, unsigned int size, unsigned int itemsToLoad)
{
	unsigned char major = *data++;
	unsigned char minor = *data++;
	size -= 2;
	if(luaBinaryMajorVersion != major || luaBinaryMinorVersion != minor)
		return;

	while(size > 0 && itemsToLoad > 0)
	{
		BinaryToLuaStackConverter(L, data, size);
		itemsToLoad--;
	}
}

// saves Lua stack into a record and pops it
void LuaSaveData::SaveRecord(lua_State* L, unsigned int key)
{
	if(!L)
		return;

	Record* cur = new Record();
	cur->key = key;
	cur->data = LuaStackToBinary(L, cur->size);
	cur->next = NULL;

	lua_settop(L,0);

	if(cur->size <= 0)
	{
		delete cur;
		return;
	}

	Record* last = recordList;
	while(last && last->next)
		last = last->next;
	if(last)
		last->next = cur;
	else
		recordList = cur;
}

// pushes a record's data onto the Lua stack
void LuaSaveData::LoadRecord(struct lua_State* L, unsigned int key, unsigned int itemsToLoad) const
{
	if(!L)
		return;

	Record* cur = recordList;
	while(cur)
	{
		if(cur->key == key)
		{
//			s_dbg_dataStart = cur->data;
//			s_dbg_dataSize = cur->size;
			BinaryToLuaStack(L, cur->data, cur->size, itemsToLoad);
			return;
		}
		cur = cur->next;
	}
}

// saves part of the Lua stack (at the given index) into a record and does NOT pop anything
void LuaSaveData::SaveRecordPartial(struct lua_State* L, unsigned int key, int idx)
{
	if(!L)
		return;

	if(idx < 0)
		idx += lua_gettop(L)+1;

	Record* cur = new Record();
	cur->key = key;
	cur->next = NULL;

	if(idx <= lua_gettop(L))
	{
		std::vector<unsigned char> output;
		output.push_back(luaBinaryMajorVersion);
		output.push_back(luaBinaryMinorVersion);

		LuaStackToBinaryConverter(L, idx, output);

		unsigned char* rv = new unsigned char [output.size()];
		memcpy(rv, &output.front(), output.size());
		cur->size = output.size();
		cur->data = rv;
	}

	if(cur->size <= 0)
	{
		delete cur;
		return;
	}

	Record* last = recordList;
	while(last && last->next)
		last = last->next;
	if(last)
		last->next = cur;
	else
		recordList = cur;
}

void fwriteint(unsigned int value, FILE* file)
{
	for(int i=0;i<4;i++)
	{
		int w = value & 0xFF;
		fwrite(&w, 1, 1, file);
		value >>= 8;
	}
}
void freadint(unsigned int& value, FILE* file)
{
	int rv = 0;
	for(int i=0;i<4;i++)
	{
		int r = 0;
		fread(&r, 1, 1, file);
		rv |= r << (i*8);
	}
	value = rv;
}

// writes all records to an already-open file
void LuaSaveData::ExportRecords(void* fileV) const
{
	FILE* file = (FILE*)fileV;
	if(!file)
		return;

	Record* cur = recordList;
	while(cur)
	{
		fwriteint(cur->key, file);
		fwriteint(cur->size, file);
		fwrite(cur->data, cur->size, 1, file);
		cur = cur->next;
	}
}

// reads records from an already-open file
void LuaSaveData::ImportRecords(void* fileV)
{
	FILE* file = (FILE*)fileV;
	if(!file)
		return;

	ClearRecords();

	Record rec;
	Record* cur = &rec;
	Record* last = NULL;
	while(1)
	{
		freadint(cur->key, file);
		freadint(cur->size, file);

		if(feof(file) || ferror(file))
			break;

		cur->data = new unsigned char [cur->size];
		fread(cur->data, cur->size, 1, file);

		Record* next = new Record();
		memcpy(next, cur, sizeof(Record));
		next->next = NULL;

		if(last)
			last->next = next;
		else
			recordList = next;
		last = next;
	}
}

void LuaSaveData::ClearRecords()
{
	Record* cur = recordList;
	while(cur)
	{
		Record* del = cur;
		cur = cur->next;

		delete[] del->data;
		delete del;
	}

	recordList = NULL;
}






void CallRegisteredLuaSaveFunctions(int savestateNumber, LuaSaveData& saveData)
{
	//lua_State* L = FCEU_GetLuaState();
	if(L)
	{
		lua_settop(L, 0);
		lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFORESAVE]);

		if (lua_isfunction(L, -1))
		{
			lua_pushinteger(L, savestateNumber);
			int ret = lua_pcall(L, 1, LUA_MULTRET, 0);
			if (ret != 0) {
				// This is grounds for trashing the function
				lua_pushnil(L);
				lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFORESAVE]);
#ifdef WIN32
				MessageBox(hAppWnd, lua_tostring(L, -1), "Lua Error in SAVE function", MB_OK);
#else
				fprintf(stderr, "Lua error in registersave function: %s\n", lua_tostring(L, -1));
#endif
			}
			saveData.SaveRecord(L, LUA_DATARECORDKEY);
		}
		else
		{
			lua_pop(L, 1);
		}
	}
}


void CallRegisteredLuaLoadFunctions(int savestateNumber, const LuaSaveData& saveData)
{
	//lua_State* L = FCEU_GetLuaState();
	if(L)
	{
		lua_settop(L, 0);
		lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_AFTERLOAD]);

		if (lua_isfunction(L, -1))
		{
#ifdef WIN32
			// since the scriptdata can be very expensive to load
			// (e.g. the registered save function returned some huge tables)
			// check the number of parameters the registered load function expects
			// and don't bother loading the parameters it wouldn't receive anyway
			int numParamsExpected = (L->top - 1)->value.gc->cl.l.p->numparams; // NOTE: if this line crashes, that means your Lua headers are out of sync with your Lua lib
			if(numParamsExpected) numParamsExpected--; // minus one for the savestate number we always pass in

			int prevGarbage = lua_gc(L, LUA_GCCOUNT, 0);

			lua_pushinteger(L, savestateNumber);
			saveData.LoadRecord(L, LUA_DATARECORDKEY, numParamsExpected);
#else
			int prevGarbage = lua_gc(L, LUA_GCCOUNT, 0);

			lua_pushinteger(L, savestateNumber);
			saveData.LoadRecord(L, LUA_DATARECORDKEY, (unsigned int) -1);
#endif

			int n = lua_gettop(L) - 1;

			int ret = lua_pcall(L, n, 0, 0);
			if (ret != 0) {
				// This is grounds for trashing the function
				lua_pushnil(L);
				lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_AFTERLOAD]);
#ifdef WIN32
				MessageBox(hAppWnd, lua_tostring(L, -1), "Lua Error in LOAD function", MB_OK);
#else
				fprintf(stderr, "Lua error in registerload function: %s\n", lua_tostring(L, -1));
#endif
			}
			else
			{
				int newGarbage = lua_gc(L, LUA_GCCOUNT, 0);
				if(newGarbage - prevGarbage > 50)
				{
					// now seems to be a very good time to run the garbage collector
					// it might take a while now but that's better than taking 10 whiles 9 loads from now
					lua_gc(L, LUA_GCCOLLECT, 0);
				}
			}
		}
		else
		{
			lua_pop(L, 1);
		}
	}
}


static int rom_readbyte(lua_State *L) {
	lua_pushinteger(L, FCEU_ReadRomByte(luaL_checkinteger(L,1)));
	return 1;
}

static int rom_readbytesigned(lua_State *L) {
	lua_pushinteger(L, (signed char)FCEU_ReadRomByte(luaL_checkinteger(L,1)));
	return 1;
}

// doesn't keep backups to allow maximum speed (for automatic rom corruptors and stuff)
// keeping them might be an option though, just need to use memview's ApplyPatch()
// that'd also highlight the edits in hex editor
static int rom_writebyte(lua_State *L) 
{
	uint32 address = luaL_checkinteger(L,1);
	if (address < 16)
		luaL_error(L,"rom.writebyte() can't edit the ROM header.");
	else
		FCEU_WriteRomByte(address, luaL_checkinteger(L,2));
	return 1;
}

static int rom_gethash(lua_State *L) {
	const char *type = luaL_checkstring(L, 1);
	if(!type) lua_pushstring(L, "");
	else if(!stricmp(type,"md5")) lua_pushstring(L, md5_asciistr(GameInfo->MD5));
	else lua_pushstring(L, "");
	return 1;
}

static int memory_readbyte(lua_State *L) {
	lua_pushinteger(L, FCEU_CheatGetByte(luaL_checkinteger(L,1)));
	return 1;
}

static int memory_readbytesigned(lua_State *L) {
	signed char c = (signed char) FCEU_CheatGetByte(luaL_checkinteger(L,1));
	lua_pushinteger(L, c);
	return 1;
}

static int GetWord(lua_State *L, bool isSigned)
{
	// little endian, unless the high byte address is specified as a 2nd parameter
	uint16 addressLow = luaL_checkinteger(L, 1);
	uint16 addressHigh = addressLow + 1;
	if (lua_type(L, 2) == LUA_TNUMBER)
		addressHigh = luaL_checkinteger(L, 2);
	uint16 result = FCEU_CheatGetByte(addressLow) | (FCEU_CheatGetByte(addressHigh) << 8);
	return isSigned ? (int16)result : result;
}

static int memory_readword(lua_State *L)
{
	lua_pushinteger(L, GetWord(L, false));
	return 1;
}

static int memory_readwordsigned(lua_State *L) {
	lua_pushinteger(L, GetWord(L, true));
	return 1;
}

static int memory_writebyte(lua_State *L) {
	FCEU_CheatSetByte(luaL_checkinteger(L,1), luaL_checkinteger(L,2));
	return 0;
}

static int memory_readbyterange(lua_State *L) {

	int range_start = luaL_checkinteger(L,1);
	int range_size = luaL_checkinteger(L,2);
	if(range_size < 0)
		return 0;

	char* buf = (char*)alloca(range_size);
	for(int i=0;i<range_size;i++) {
		buf[i] = FCEU_CheatGetByte(range_start+i);
	}

	lua_pushlstring(L,buf,range_size);

	return 1;
}

static inline bool isalphaorunderscore(char c)
{
	return isalpha(c) || c == '_';
}

#define APPENDPRINT { int _n = snprintf(ptr, remaining,
#define END ); if(_n >= 0) { ptr += _n; remaining -= _n; } else { remaining = 0; } }
static void toCStringConverter(lua_State* L, int i, char*& ptr, int& remaining)
{
	if(remaining <= 0)
		return;

	const char* str = ptr; // for debugging

	// if there is a __tostring metamethod then call it
	int usedMeta = luaL_callmeta(L, i, "__tostring");
	if(usedMeta)
	{
		std::vector<const void*>::const_iterator foundCycleIter = std::find(s_metacallStack.begin(), s_metacallStack.end(), lua_topointer(L,i));
		if(foundCycleIter != s_metacallStack.end())
		{
			lua_pop(L, 1);
			usedMeta = false;
		}
		else
		{
			s_metacallStack.push_back(lua_topointer(L,i));
			i = lua_gettop(L);
		}
	}

	switch(lua_type(L, i))
	{
		case LUA_TNONE: break;
		case LUA_TNIL: APPENDPRINT "nil" END break;
		case LUA_TBOOLEAN: APPENDPRINT lua_toboolean(L,i) ? "true" : "false" END break;
		case LUA_TSTRING: APPENDPRINT "%s",lua_tostring(L,i) END break;
		case LUA_TNUMBER: APPENDPRINT "%.12Lg",lua_tonumber(L,i) END break;
		case LUA_TFUNCTION:
			/*if((L->base + i-1)->value.gc->cl.c.isC)
			{
				//lua_CFunction func = lua_tocfunction(L, i);
				//std::map<lua_CFunction, const char*>::iterator iter = s_cFuncInfoMap.find(func);
				//if(iter == s_cFuncInfoMap.end())
					goto defcase;
				//APPENDPRINT "function(%s)", iter->second END
			}
			else
			{
				APPENDPRINT "function(" END
				Proto* p = (L->base + i-1)->value.gc->cl.l.p;
				int numParams = p->numparams + (p->is_vararg?1:0);
				for (int n=0; n<p->numparams; n++)
				{
					APPENDPRINT "%s", getstr(p->locvars[n].varname) END
					if(n != numParams-1)
						APPENDPRINT "," END
				}
				if(p->is_vararg)
					APPENDPRINT "..." END
				APPENDPRINT ")" END
			}*/
			goto defcase;
			break;
defcase:default: APPENDPRINT "%s:%p",luaL_typename(L,i),lua_topointer(L,i) END break;
		case LUA_TTABLE:
		{
			// first make sure there's enough stack space
			if(!lua_checkstack(L, 4))
			{
				// note that even if lua_checkstack never returns false,
				// that doesn't mean we didn't need to call it,
				// because calling it retrieves stack space past LUA_MINSTACK
				goto defcase;
			}

			std::vector<const void*>::const_iterator foundCycleIter = std::find(s_tableAddressStack.begin(), s_tableAddressStack.end(), lua_topointer(L,i));
			if(foundCycleIter != s_tableAddressStack.end())
			{
				int parentNum = s_tableAddressStack.end() - foundCycleIter;
				if(parentNum > 1)
					APPENDPRINT "%s:parent^%d",luaL_typename(L,i),parentNum END
				else
					APPENDPRINT "%s:parent",luaL_typename(L,i) END
			}
			else
			{
				s_tableAddressStack.push_back(lua_topointer(L,i));
				struct Scope { ~Scope(){ s_tableAddressStack.pop_back(); } } scope;

				APPENDPRINT "{" END

				lua_pushnil(L); // first key
				int keyIndex = lua_gettop(L);
				int valueIndex = keyIndex + 1;
				bool first = true;
				bool skipKey = true; // true if we're still in the "array part" of the table
				lua_Number arrayIndex = (lua_Number)0;
				while(lua_next(L, i))
				{
					if(first)
						first = false;
					else
						APPENDPRINT ", " END
					if(skipKey)
					{
						arrayIndex += (lua_Number)1;
						bool keyIsNumber = (lua_type(L, keyIndex) == LUA_TNUMBER);
						skipKey = keyIsNumber && (lua_tonumber(L, keyIndex) == arrayIndex);
					}
					if(!skipKey)
					{
						bool keyIsString = (lua_type(L, keyIndex) == LUA_TSTRING);
						bool invalidLuaIdentifier = (!keyIsString || !isalphaorunderscore(*lua_tostring(L, keyIndex)));
						if(invalidLuaIdentifier)
							if(keyIsString)
								APPENDPRINT "['" END
							else
								APPENDPRINT "[" END

						toCStringConverter(L, keyIndex, ptr, remaining); // key

						if(invalidLuaIdentifier)
							if(keyIsString)
								APPENDPRINT "']=" END
							else
								APPENDPRINT "]=" END
						else
							APPENDPRINT "=" END
					}

					bool valueIsString = (lua_type(L, valueIndex) == LUA_TSTRING);
					if(valueIsString)
						APPENDPRINT "'" END

					toCStringConverter(L, valueIndex, ptr, remaining); // value

					if(valueIsString)
						APPENDPRINT "'" END

					lua_pop(L, 1);

					if(remaining <= 0)
					{
						lua_settop(L, keyIndex-1); // stack might not be clean yet if we're breaking early
						break;
					}
				}
				APPENDPRINT "}" END
			}
		}	break;
	}

	if(usedMeta)
	{
		s_metacallStack.pop_back();
		lua_pop(L, 1);
	}
}

static const int s_tempStrMaxLen = 64 * 1024;
static char s_tempStr [s_tempStrMaxLen];

static char* rawToCString(lua_State* L, int idx)
{
	int a = idx>0 ? idx : 1;
	int n = idx>0 ? idx : lua_gettop(L);

	char* ptr = s_tempStr;
	*ptr = 0;

	int remaining = s_tempStrMaxLen;
	for(int i = a; i <= n; i++)
	{
		toCStringConverter(L, i, ptr, remaining);
		if(i != n)
			APPENDPRINT " " END
	}

	if(remaining < 3)
	{
		while(remaining < 6)
			remaining++, ptr--;
		APPENDPRINT "..." END
	}
	APPENDPRINT "\r\n" END
	// the trailing newline is so print() can avoid having to do wasteful things to print its newline
	// (string copying would be wasteful and calling info.print() twice can be extremely slow)
	// at the cost of functions that don't want the newline needing to trim off the last two characters
	// (which is a very fast operation and thus acceptable in this case)

	return s_tempStr;
}
#undef APPENDPRINT
#undef END


// replacement for luaB_tostring() that is able to show the contents of tables (and formats numbers better, and show function prototypes)
// can be called directly from lua via tostring(), assuming tostring hasn't been reassigned
static int tostring(lua_State *L)
{
	char* str = rawToCString(L);
	str[strlen(str)-2] = 0; // hack: trim off the \r\n (which is there to simplify the print function's task)
	lua_pushstring(L, str);
	return 1;
}

// tobitstring(int value)
//
//   Converts byte to binary string
static int tobitstring(lua_State *L)
{
	std::bitset<8> bits (luaL_checkinteger(L, 1));
	std::string temp = bits.to_string().insert(4, " ");
	const char * result = temp.c_str();
	lua_pushstring(L,result);
	return 1;
}

// like rawToCString, but will check if the global Lua function tostring()
// has been replaced with a custom function, and call that instead if so
static const char* toCString(lua_State* L, int idx)
{
	int a = idx>0 ? idx : 1;
	int n = idx>0 ? idx : lua_gettop(L);
	lua_getglobal(L, "tostring");
	lua_CFunction cf = lua_tocfunction(L,-1);
	if(cf == tostring) // optimization: if using our own C tostring function, we can bypass the call through Lua and all the string object allocation that would entail
	{
		lua_pop(L,1);
		return rawToCString(L, idx);
	}
	else // if the user overrided the tostring function, we have to actually call it and store the temporarily allocated string it returns
	{
		lua_pushstring(L, "");
		for (int i=a; i<=n; i++) {
			lua_pushvalue(L, -2);  // function to be called
			lua_pushvalue(L, i);   // value to print
			lua_call(L, 1, 1);
			if(lua_tostring(L, -1) == NULL)
				luaL_error(L, LUA_QL("tostring") " must return a string to " LUA_QL("print"));
			lua_pushstring(L, (i<n) ? " " : "\r\n");
			lua_concat(L, 3);
		}
		const char* str = lua_tostring(L, -1);
		strncpy(s_tempStr, str, s_tempStrMaxLen);
		s_tempStr[s_tempStrMaxLen-1] = 0;
		lua_pop(L, 2);
		return s_tempStr;
	}
}

// replacement for luaB_print() that goes to the appropriate textbox instead of stdout
static int print(lua_State *L)
{
	const char* str = toCString(L);

	int uid = info_uid;//luaStateToUIDMap[L->l_G->mainthread];
	//LuaContextInfo& info = GetCurrentInfo();

	if(info_print)
		info_print(uid, str);
	else
		puts(str);

	//worry(L, 100);
	return 0;
}

// gethash()
//
//  Returns the crc32 hashsum of an arbitrary buffer
static int gethash(lua_State *L) {
	uint8 *buffer = (uint8 *)luaL_checkstring(L, 1);
	int size = luaL_checkinteger(L,2);
	int hash = CalcCRC32(0, buffer, size);
	lua_pushinteger(L, hash);
	return 1;
}

// provides an easy way to copy a table from Lua
// (simple assignment only makes an alias, but sometimes an independent table is desired)
// currently this function only performs a shallow copy,
// but I think it should be changed to do a deep copy (possibly of configurable depth?)
// that maintains the internal table reference structure
static int copytable(lua_State *L)
{
	int origIndex = 1; // we only care about the first argument
	int origType = lua_type(L, origIndex);
	if(origType == LUA_TNIL)
	{
		lua_pushnil(L);
		return 1;
	}
	if(origType != LUA_TTABLE)
	{
		luaL_typerror(L, 1, lua_typename(L, LUA_TTABLE));
		lua_pushnil(L);
		return 1;
	}

	lua_createtable(L, lua_objlen(L,1), 0);
	int copyIndex = lua_gettop(L);

	lua_pushnil(L); // first key
	int keyIndex = lua_gettop(L);
	int valueIndex = keyIndex + 1;

	while(lua_next(L, origIndex))
	{
		lua_pushvalue(L, keyIndex);
		lua_pushvalue(L, valueIndex);
		lua_rawset(L, copyIndex); // copytable[key] = value
		lua_pop(L, 1);
	}

	// copy the reference to the metatable as well, if any
	if(lua_getmetatable(L, origIndex))
		lua_setmetatable(L, copyIndex);

	return 1; // return the new table
}

// because print traditionally shows the address of tables,
// and the print function I provide instead shows the contents of tables,
// I also provide this function
// (otherwise there would be no way to see a table's address, AFAICT)
static int addressof(lua_State *L)
{
	const void* ptr = lua_topointer(L,-1);
	lua_pushinteger(L, (lua_Integer)ptr);
	return 1;
}

struct registerPointerMap
{
	const char* registerName;
	unsigned int* pointer;
	int dataSize;
};

#define RPM_ENTRY(name,var) {name, (unsigned int*)&var, sizeof(var)},

registerPointerMap regPointerMap [] = {
	RPM_ENTRY("pc", _PC)
	RPM_ENTRY("a", _A)
	RPM_ENTRY("x", _X)
	RPM_ENTRY("y", _Y)
	RPM_ENTRY("s", _S)
	RPM_ENTRY("p", _P)
	{}
};

struct cpuToRegisterMap
{
	const char* cpuName;
	registerPointerMap* rpmap;
}
cpuToRegisterMaps [] =
{
	{"", regPointerMap},
};


//DEFINE_LUA_FUNCTION(memory_getregister, "cpu_dot_registername_string")
static int memory_getregister(lua_State *L)
{
	const char* qualifiedRegisterName = luaL_checkstring(L,1);
	lua_settop(L,0);
	for(int cpu = 0; cpu < sizeof(cpuToRegisterMaps)/sizeof(*cpuToRegisterMaps); cpu++)
	{
		cpuToRegisterMap ctrm = cpuToRegisterMaps[cpu];
		int cpuNameLen = strlen(ctrm.cpuName);
		if(!strnicmp(qualifiedRegisterName, ctrm.cpuName, cpuNameLen))
		{
			qualifiedRegisterName += cpuNameLen;
			for(int reg = 0; ctrm.rpmap[reg].dataSize; reg++)
			{
				registerPointerMap rpm = ctrm.rpmap[reg];
				if(!stricmp(qualifiedRegisterName, rpm.registerName))
				{
					switch(rpm.dataSize)
					{ default:
					case 1: lua_pushinteger(L, *(unsigned char*)rpm.pointer); break;
					case 2: lua_pushinteger(L, *(unsigned short*)rpm.pointer); break;
					case 4: lua_pushinteger(L, *(unsigned long*)rpm.pointer); break;
					}
					return 1;
				}
			}
			lua_pushnil(L);
			return 1;
		}
	}
	lua_pushnil(L);
	return 1;
}
//DEFINE_LUA_FUNCTION(memory_setregister, "cpu_dot_registername_string,value")
static int memory_setregister(lua_State *L)
{
	const char* qualifiedRegisterName = luaL_checkstring(L,1);
	unsigned long value = (unsigned long)(luaL_checkinteger(L,2));
	lua_settop(L,0);
	for(int cpu = 0; cpu < sizeof(cpuToRegisterMaps)/sizeof(*cpuToRegisterMaps); cpu++)
	{
		cpuToRegisterMap ctrm = cpuToRegisterMaps[cpu];
		int cpuNameLen = strlen(ctrm.cpuName);
		if(!strnicmp(qualifiedRegisterName, ctrm.cpuName, cpuNameLen))
		{
			qualifiedRegisterName += cpuNameLen;
			for(int reg = 0; ctrm.rpmap[reg].dataSize; reg++)
			{
				registerPointerMap rpm = ctrm.rpmap[reg];
				if(!stricmp(qualifiedRegisterName, rpm.registerName))
				{
					switch(rpm.dataSize)
					{ default:
					case 1: *(unsigned char*)rpm.pointer = (unsigned char)(value & 0xFF); break;
					case 2: *(unsigned short*)rpm.pointer = (unsigned short)(value & 0xFFFF); break;
					case 4: *(unsigned long*)rpm.pointer = value; break;
					}
					return 0;
				}
			}
			return 0;
		}
	}
	return 0;
}


void HandleCallbackError(lua_State* L)
{
	//if(L->errfunc || L->errorJmp)
	//	luaL_error(L, "%s", lua_tostring(L,-1));
	//else
	{
		lua_pushnil(L);
		lua_setfield(L, LUA_REGISTRYINDEX, guiCallbackTable);

		// Error?
#ifdef WIN32
		MessageBox( hAppWnd, lua_tostring(L,-1), "Lua run error", MB_OK | MB_ICONSTOP);
#else
		fprintf(stderr, "Lua thread bombed out: %s\n", lua_tostring(L,-1));
#endif

		FCEU_LuaStop();
	}
}


// the purpose of this structure is to provide a way of
// QUICKLY determining whether a memory address range has a hook associated with it,
// with a bias toward fast rejection because the majority of addresses will not be hooked.
// (it must not use any part of Lua or perform any per-script operations,
//  otherwise it would definitely be too slow.)
// calculating the regions when a hook is added/removed may be slow,
// but this is an intentional tradeoff to obtain a high speed of checking during later execution
struct TieredRegion
{
	template<unsigned int maxGap>
	struct Region
	{
		struct Island
		{
			unsigned int start;
			unsigned int end;
#ifdef NEED_MINGW_HACKS
			bool Contains(unsigned int address, int size) const { return address < end && address+size > start; }
#else
			__forceinline bool Contains(unsigned int address, int size) const { return address < end && address+size > start; }
#endif
		};
		std::vector<Island> islands;

		void Calculate(const std::vector<unsigned int>& bytes)
		{
			islands.clear();

			unsigned int lastEnd = ~0;

			std::vector<unsigned int>::const_iterator iter = bytes.begin();
			std::vector<unsigned int>::const_iterator end = bytes.end();
			for(; iter != end; ++iter)
			{
				unsigned int addr = *iter;
				if(addr < lastEnd || addr > lastEnd + (long long)maxGap)
				{
					islands.push_back(Island());
					islands.back().start = addr;
				}
				islands.back().end = addr+1;
				lastEnd = addr+1;
			}
		}
		bool Contains(unsigned int address, int size) const
		{
            for (size_t i = 0; i != islands.size(); ++i)
            {
                if (islands[i].Contains(address, size))
                    return true;
            }
			return false;
		}
	};

	Region<0xFFFFFFFF> broad;
	Region<0x1000> mid;
	Region<0> narrow;

	void Calculate(std::vector<unsigned int>& bytes)
	{
		std::sort(bytes.begin(), bytes.end());

		broad.Calculate(bytes);
		mid.Calculate(bytes);
		narrow.Calculate(bytes);
	}

	TieredRegion()
	{
        std::vector <unsigned int> temp;
		Calculate(temp);
	}

	__forceinline int NotEmpty()
	{
		return broad.islands.size();
	}

	// note: it is illegal to call this if NotEmpty() returns 0
	__forceinline bool Contains(unsigned int address, int size)
	{
		return broad.islands[0].Contains(address,size) &&
		       mid.Contains(address,size) &&
			   narrow.Contains(address,size);
	}
};
TieredRegion hookedRegions [LUAMEMHOOK_COUNT];


static void CalculateMemHookRegions(LuaMemHookType hookType)
{
	std::vector<unsigned int> hookedBytes;
//	std::map<int, LuaContextInfo*>::iterator iter = luaContextInfo.begin();
//	std::map<int, LuaContextInfo*>::iterator end = luaContextInfo.end();
//	while(iter != end)
//	{
//		LuaContextInfo& info = *iter->second;
		if(/*info.*/ numMemHooks)
		{
//			lua_State* L = info.L;
			if(L)
			{
				lua_settop(L, 0);
				lua_getfield(L, LUA_REGISTRYINDEX, luaMemHookTypeStrings[hookType]);
				lua_pushnil(L);
				while(lua_next(L, -2))
				{
					if(lua_isfunction(L, -1))
					{
						unsigned int addr = lua_tointeger(L, -2);
						hookedBytes.push_back(addr);
					}
					lua_pop(L, 1);
				}
				lua_settop(L, 0);
			}
		}
//		++iter;
//	}
	hookedRegions[hookType].Calculate(hookedBytes);
}

static void CallRegisteredLuaMemHook_LuaMatch(unsigned int address, int size, unsigned int value, LuaMemHookType hookType)
{
//	std::map<int, LuaContextInfo*>::iterator iter = luaContextInfo.begin();
//	std::map<int, LuaContextInfo*>::iterator end = luaContextInfo.end();
//	while(iter != end)
//	{
//		LuaContextInfo& info = *iter->second;
		if(/*info.*/ numMemHooks)
		{
//			lua_State* L = info.L;
			if(L/* && !info.panic*/)
			{
#ifdef USE_INFO_STACK
				infoStack.insert(infoStack.begin(), &info);
				struct Scope { ~Scope(){ infoStack.erase(infoStack.begin()); } } scope;
#endif
				lua_settop(L, 0);
				lua_getfield(L, LUA_REGISTRYINDEX, luaMemHookTypeStrings[hookType]);
				for(int i = address; i != address+size; i++)
				{
					lua_rawgeti(L, -1, i);
					if (lua_isfunction(L, -1))
					{
						bool wasRunning = (luaRunning!=0) /*info.running*/;
						luaRunning /*info.running*/ = true;
						//RefreshScriptSpeedStatus();
						lua_pushinteger(L, address);
						lua_pushinteger(L, size);
						int errorcode = lua_pcall(L, 2, 0, 0);
						luaRunning /*info.running*/ = wasRunning;
						//RefreshScriptSpeedStatus();
						if (errorcode)
						{
							HandleCallbackError(L);
							//int uid = iter->first;
							//HandleCallbackError(L,info,uid,true);
						}
						break;
					}
					else
					{
						lua_pop(L,1);
					}
				}
				lua_settop(L, 0);
			}
		}
//		++iter;
//	}
}
void CallRegisteredLuaMemHook(unsigned int address, int size, unsigned int value, LuaMemHookType hookType)
{
	// performance critical! (called VERY frequently)
	// I suggest timing a large number of calls to this function in Release if you change anything in here,
	// before and after, because even the most innocent change can make it become 30% to 400% slower.
	// a good amount to test is: 100000000 calls with no hook set, and another 100000000 with a hook set.
	// (on my system that consistently took 200 ms total in the former case and 350 ms total in the latter case)
	if(hookedRegions[hookType].NotEmpty())
	{
		//if((hookType <= LUAMEMHOOK_EXEC) && (address >= 0xE00000))
		//	address |= 0xFF0000; // account for mirroring of RAM
		if(hookedRegions[hookType].Contains(address, size))
			CallRegisteredLuaMemHook_LuaMatch(address, size, value, hookType); // something has hooked this specific address
	}
}

void CallRegisteredLuaFunctions(LuaCallID calltype)
{
	assert((unsigned int)calltype < (unsigned int)LUACALL_COUNT);
	const char* idstring = luaCallIDStrings[calltype];

	if (!L)
		return;

	lua_settop(L, 0);
	lua_getfield(L, LUA_REGISTRYINDEX, idstring);

	int errorcode = 0;
	if (lua_isfunction(L, -1))
	{
		errorcode = lua_pcall(L, 0, 0, 0);
		if (errorcode)
			HandleCallbackError(L);
	}
	else
	{
		lua_pop(L, 1);
	}
}

void ForceExecuteLuaFrameFunctions()
{
	FCEU_LuaFrameBoundary();
	CallRegisteredLuaFunctions(LUACALL_BEFOREEMULATION);
	CallRegisteredLuaFunctions(LUACALL_AFTEREMULATION);
}

void TaseditorAutoFunction()
{
	CallRegisteredLuaFunctions(LUACALL_TASEDITOR_AUTO);
}

void TaseditorManualFunction()
{
	CallRegisteredLuaFunctions(LUACALL_TASEDITOR_MANUAL);
}

#ifdef WIN32
void TaseditorDisableManualFunctionIfNeeded()
{
	if (L)
	{
		// check if LUACALL_TASEDITOR_MANUAL function is not nil
		lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_TASEDITOR_MANUAL]);
		if (!lua_isfunction(L, -1))
			taseditor_lua.disableRunFunction();
		lua_pop(L, 1);
	} else taseditor_lua.disableRunFunction();
}
#endif

static int memory_registerHook(lua_State* L, LuaMemHookType hookType, int defaultSize)
{
	// get first argument: address
	unsigned int addr = luaL_checkinteger(L,1);
	//if((addr & ~0xFFFFFF) == ~0xFFFFFF)
	//	addr &= 0xFFFFFF;

	// get optional second argument: size
	int size = defaultSize;
	int funcIdx = 2;
	if(lua_isnumber(L,2))
	{
		size = luaL_checkinteger(L,2);
		if(size < 0)
		{
			size = -size;
			addr -= size;
		}
		funcIdx++;
	}

	// check last argument: callback function
	bool clearing = lua_isnil(L,funcIdx);
	if(!clearing)
		luaL_checktype(L, funcIdx, LUA_TFUNCTION);
	lua_settop(L,funcIdx);

	// get the address-to-callback table for this hook type of the current script
	lua_getfield(L, LUA_REGISTRYINDEX, luaMemHookTypeStrings[hookType]);

	// count how many callback functions we'll be displacing
	int numFuncsAfter = clearing ? 0 : size;
	int numFuncsBefore = 0;
	for(unsigned int i = addr; i != addr+size; i++)
	{
		lua_rawgeti(L, -1, i);
		if(lua_isfunction(L, -1))
			numFuncsBefore++;
		lua_pop(L,1);
	}

	// put the callback function in the address slots
	for(unsigned int i = addr; i != addr+size; i++)
	{
		lua_pushvalue(L, -2);
		lua_rawseti(L, -2, i);
	}

	// adjust the count of active hooks
	//LuaContextInfo& info = GetCurrentInfo();
	/*info.*/ numMemHooks += numFuncsAfter - numFuncsBefore;

	// re-cache regions of hooked memory across all scripts
	CalculateMemHookRegions(hookType);

	//StopScriptIfFinished(luaStateToUIDMap[L]);
	return 0;
}

LuaMemHookType MatchHookTypeToCPU(lua_State* L, LuaMemHookType hookType)
{
	int cpuID = 0;

	int cpunameIndex = 0;
	if(lua_type(L,2) == LUA_TSTRING)
		cpunameIndex = 2;
	else if(lua_type(L,3) == LUA_TSTRING)
		cpunameIndex = 3;

	if(cpunameIndex)
	{
		const char* cpuName = lua_tostring(L, cpunameIndex);
		if(!stricmp(cpuName, "sub"))
			cpuID = 1;
		lua_remove(L, cpunameIndex);
	}

	switch(cpuID)
	{
	case 0:
		return hookType;

	case 1:
		switch(hookType)
		{
		case LUAMEMHOOK_WRITE: return LUAMEMHOOK_WRITE_SUB;
		case LUAMEMHOOK_READ: return LUAMEMHOOK_READ_SUB;
		case LUAMEMHOOK_EXEC: return LUAMEMHOOK_EXEC_SUB;
		}
	}
	return hookType;
}

static int memory_registerwrite(lua_State *L)
{
	return memory_registerHook(L, MatchHookTypeToCPU(L,LUAMEMHOOK_WRITE), 1);
}
static int memory_registerread(lua_State *L)
{
	return memory_registerHook(L, MatchHookTypeToCPU(L,LUAMEMHOOK_READ), 1);
}
static int memory_registerexec(lua_State *L)
{
	return memory_registerHook(L, MatchHookTypeToCPU(L,LUAMEMHOOK_EXEC), 1);
}

//adelikat: table pulled from GENS.  credz nitsuja!

#ifdef WIN32
const char* s_keyToName[256] =
{
	NULL,
	"leftclick",
	"rightclick",
	NULL,
	"middleclick",
	NULL,
	NULL,
	NULL,
	"backspace",
	"tab",
	NULL,
	NULL,
	NULL,
	"enter",
	NULL,
	NULL,
	"shift", // 0x10
	"control",
	"alt",
	"pause",
	"capslock",
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	"escape",
	NULL,
	NULL,
	NULL,
	NULL,
	"space", // 0x20
	"pageup",
	"pagedown",
	"end",
	"home",
	"left",
	"up",
	"right",
	"down",
	NULL,
	NULL,
	NULL,
	NULL,
	"insert",
	"delete",
	NULL,
	"0","1","2","3","4","5","6","7","8","9",
	NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	"A","B","C","D","E","F","G","H","I","J",
	"K","L","M","N","O","P","Q","R","S","T",
	"U","V","W","X","Y","Z",
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	"numpad0","numpad1","numpad2","numpad3","numpad4","numpad5","numpad6","numpad7","numpad8","numpad9",
	"numpad*","numpad+",
	NULL,
	"numpad-","numpad.","numpad/",
	"F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
	"F13","F14","F15","F16","F17","F18","F19","F20","F21","F22","F23","F24",
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	"numlock",
	"scrolllock",
	NULL, // 0x92
	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NULL, // 0xB9
	"semicolon",
	"plus",
	"comma",
	"minus",
	"period",
	"slash",
	"tilde",
	NULL, // 0xC1
	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NULL, NULL, NULL, NULL, NULL, NULL, NULL,
	NULL, // 0xDA
	"leftbracket",
	"backslash",
	"rightbracket",
	"quote",
};
#endif

//adelikat - the code for the keys is copied directly from GENS.  Props to nitsuja
//			 the code for the mouse is simply the same code from zapper.get
// input.get()
// takes no input, returns a lua table of entries representing the current input state,
// independent of the joypad buttons the emulated game thinks are pressed
// for example:
//   if the user is holding the W key and the left mouse button
//   and has the mouse at the bottom-right corner of the game screen,
//   then this would return {W=true, leftclick=true, xmouse=319, ymouse=223}
static int input_get(lua_State *L) {
	lua_newtable(L);

#ifdef WIN32
	// keyboard and mouse button status
	{
		extern int EnableBackgroundInput;
		unsigned char keys [256];
		if(!EnableBackgroundInput)
		{
			if(GetKeyboardState(keys))
			{
				for(int i = 1; i < 255; i++)
				{
					int mask = (i == VK_CAPITAL || i == VK_NUMLOCK || i == VK_SCROLL) ? 0x01 : 0x80;
					if(keys[i] & mask)
					{
						const char* name = s_keyToName[i];
						if(name)
						{
							lua_pushboolean(L, true);
							lua_setfield(L, -2, name);
						}
					}
				}
			}
		}
		else // use a slightly different method that will detect background input:
		{
			for(int i = 1; i < 255; i++)
			{
				const char* name = s_keyToName[i];
				if(name)
				{
					int active;
					if(i == VK_CAPITAL || i == VK_NUMLOCK || i == VK_SCROLL)
						active = GetKeyState(i) & 0x01;
					else
						active = GetAsyncKeyState(i) & 0x8000;
					if(active)
					{
						lua_pushboolean(L, true);
						lua_setfield(L, -2, name);
					}
				}
			}
		}
	}
#else
	//SDL TODO: implement this for keyboard!!
#endif

	// mouse position in game screen pixel coordinates

	extern void GetMouseData(uint32 (&md)[3]);

	uint32 MouseData[3];
	GetMouseData (MouseData);
	int x = MouseData[0];
	int y = MouseData[1];
	int click = MouseData[2];		///adelikat TODO: remove the ability to store the value 2?  Since 2 is right-clicking and not part of zapper input and is used for context menus

	lua_pushinteger(L, x);
	lua_setfield(L, -2, "xmouse");
	lua_pushinteger(L, y);
	lua_setfield(L, -2, "ymouse");
	lua_pushinteger(L, click);
	lua_setfield(L, -2, "click");

	return 1;
}

// table zapper.read
//int which unecessary because zapper is always controller 2
//Reads the zapper coordinates and a click value (1 if clicked, 0 if not, 2 if right click (but this is not used for zapper input)
static int zapper_read(lua_State *L){

	lua_newtable(L);
	int z = 0;
	extern void GetMouseData(uint32 (&md)[3]); //adelikat: shouldn't this be ifdef'ed for Win32?
	int x,y,click;
	if (FCEUMOV_Mode(MOVIEMODE_PLAY))
	{
		if (!currFrameCounter)
			z = 0;
		else
			z = currFrameCounter -1;

		x = currMovieData.records[z].zappers[1].x;	//adelikat:  Used hardcoded port 1 since as far as I know, only port 1 is valid for zappers
		y = currMovieData.records[z].zappers[1].y;
		click = currMovieData.records[z].zappers[1].b;
	}
	else
	{
		uint32 MouseData[3];
		GetMouseData (MouseData);
		x = MouseData[0];
		y = MouseData[1];
		click = MouseData[2];
		if (click > 1)
			click = 1;	//adelikat: This is zapper.read() thus should only give valid zapper input (instead of simply mouse input
	}
	lua_pushinteger(L, x);
	lua_setfield(L, -2, "x");
	lua_pushinteger(L, y);
	lua_setfield(L, -2, "y");
	lua_pushinteger(L, click);
	lua_setfield(L, -2, "fire");
	return 1;
}



// table joypad.read(int which = 1)
//
//  Reads the joypads as inputted by the user.
//  TODO: Don't read in *everything*...
static int joy_get_internal(lua_State *L, bool reportUp, bool reportDown) {

	// Reads the joypads as inputted by the user
	int which = luaL_checkinteger(L,1);

	if (which < 1 || which > 4) {
		luaL_error(L,"Invalid input port (valid range 1-4, specified %d)", which);
	}

	// Use the OS-specific code to do the reading.
	extern SFORMAT FCEUCTRL_STATEINFO[];
	uint8 buttons = ((uint8 *) FCEUCTRL_STATEINFO[1].v)[which - 1];

	lua_newtable(L);

	int i;
	for (i = 0; i < 8; i++) {
		bool pressed = (buttons & (1<<i))!=0;
		if ((pressed && reportDown) || (!pressed && reportUp)) {
			lua_pushboolean(L, pressed);
			lua_setfield(L, -2, button_mappings[i]);
		}
	}

	return 1;
}
// joypad.get(which)
// returns a table of every game button,
// true meaning currently-held and false meaning not-currently-held
// (as of last frame boundary)
// this WILL read input from a currently-playing movie
static int joypad_get(lua_State *L)
{
	return joy_get_internal(L, true, true);
}
// joypad.getdown(which)
// returns a table of every game button that is currently held
static int joypad_getdown(lua_State *L)
{
	return joy_get_internal(L, false, true);
}
// joypad.getup(which)
// returns a table of every game button that is not currently held
static int joypad_getup(lua_State *L)
{
	return joy_get_internal(L, true, false);
}

// table joypad.getimmediate(int which)
// Reads immediate state of joypads (at the moment of calling)
static int joypad_getimmediate(lua_State *L)
{
	int which = luaL_checkinteger(L,1);
	if (which < 1 || which > 4)
	{
		luaL_error(L,"Invalid input port (valid range 1-4, specified %d)", which);
	}
	// Currently only supports Windows, sorry...
#ifdef WIN32
	extern uint32 GetGamepadPressedImmediate();
	uint8 buttons = GetGamepadPressedImmediate() >> ((which - 1) * 8);

	lua_newtable(L);
	for (int i = 0; i < 8; ++i)
	{
		lua_pushboolean(L, (buttons & (1 << i)) != 0);
		lua_setfield(L, -2, button_mappings[i]);
	}
#else
	lua_pushnil(L);
#endif
	return 1;
}


// joypad.set(int which, table buttons)
//
//   Sets the given buttons to be pressed during the next
//   frame advance. The table should have the right
//   keys (no pun intended) set.
/*FatRatKnight: I changed some of the logic.
  Now with 4 options!*/
static int joypad_set(lua_State *L) {

	// Which joypad we're tampering with
	int which = luaL_checkinteger(L,1);
	if (which < 1 || which > 4) {
		luaL_error(L,"Invalid output port (valid range 1-4, specified %d)", which);

	}

	// And the table of buttons.
	luaL_checktype(L,2,LUA_TTABLE);

	// Set up for taking control of the indicated controller
	luajoypads1[which-1] = 0xFF; // .1  Reset right bit
	luajoypads2[which-1] = 0x00; // 0.  Reset left bit

	int i;
	for (i=0; i < 8; i++) {
		lua_getfield(L, 2, button_mappings[i]);

		//Button is not nil, so find out if it is true/false
		if (!lua_isnil(L,-1))
		{
			if (lua_toboolean(L,-1))							//True or string
				luajoypads2[which-1] |= 1 << i;
			if (lua_toboolean(L,-1) == 0 || lua_isstring(L,-1))	//False or string
				luajoypads1[which-1] &= ~(1 << i);
		}

		else
		{

		}
		lua_pop(L,1);
	}

	return 0;
}

// Helper function to convert a savestate object to the filename it represents.
static const char *savestateobj2filename(lua_State *L, int offset) {

	// First we get the metatable of the indicated object
	int result = lua_getmetatable(L, offset);

	if (!result)
		luaL_error(L, "object not a savestate object");

	// Also check that the type entry is set
	lua_getfield(L, -1, "__metatable");
	if (strcmp(lua_tostring(L,-1), "FCEU Savestate") != 0)
		luaL_error(L, "object not a savestate object");
	lua_pop(L,1);

	// Now, get the field we want
	lua_getfield(L, -1, "filename");

	// Return it
	return lua_tostring(L, -1);
}

// Helper function for garbage collection.
static int savestate_gc(lua_State *L) {

	LuaSaveState *ss = (LuaSaveState *)lua_touserdata(L, 1);
	if(ss->persisted && ss->anonymous)
		remove(ss->filename.c_str());
	ss->~LuaSaveState();

	//// The object we're collecting is on top of the stack
	//lua_getmetatable(L,1);
	//
	//// Get the filename
	//const char *filename;
	//lua_getfield(L, -1, "filename");
	//filename = lua_tostring(L,-1);

	//// Delete the file
	//remove(filename);
	//

	// We exit, and the garbage collector takes care of the rest.
	return 0;
}

//  Referenced by:
//  savestate.create(int which = nil)
//  savestate.object(int which = nil)
//
//  Creates an object used for savestates.
//  The object can be associated with a player-accessible savestate
//  ("which" between 1 and 10) or not (which == nil).
static int savestate_create_aliased(lua_State *L, bool newnumbering) {
	int which = -1;
	if (lua_gettop(L) >= 1) {
		which = luaL_checkinteger(L, 1);
		if (which < 1 || which > 10) {
			luaL_error(L, "invalid player's savestate %d", which);
		}
	}

	//lets use lua to allocate the memory, since it is effectively a memory pool.
	LuaSaveState *ss = new(lua_newuserdata(L,sizeof(LuaSaveState))) LuaSaveState();

	if (which > 0) {
		// Find an appropriate filename. This is OS specific, unfortunately.
		// So I turned the filename selection code into my bitch. :)
		// Numbers are 0 through 9.
		if (newnumbering) //1-9, 10 = 0. QWERTY style.
		ss->filename = FCEU_MakeFName(FCEUMKF_STATE, (which % 10), 0);
		else // Note: Windows Slots 1-10 = Which 2-10, 1
		ss->filename = FCEU_MakeFName(FCEUMKF_STATE, which - 1, 0);

		// Only ensure load if the file exists
		// Also makes it persistent, but files are like that
		if (CheckFileExists(ss->filename.c_str()))
			ss->ensureLoad();

	}
	else {
		//char tempbuf[100] = "snluaXXXXXX";
		//filename = mktemp(tempbuf);
		//doesnt work -^

		//mbg 8/13/08 - this needs to be this way. we'll make a better system later:
		ss->filename = tempnam(NULL, "snlua");
		ss->anonymous = true;
	}


	// The metatable we use, protected from Lua and contains garbage collection info and stuff.
	lua_newtable(L);

	//// First, we must protect it
	lua_pushstring(L, "FCEU Savestate");
	lua_setfield(L, -2, "__metatable");
	//
	//
	//// Now we need to save the file itself.
	//lua_pushstring(L, filename.c_str());
	//lua_setfield(L, -2, "filename");

	// If it's an anonymous savestate, we must delete the file from disk should it be gargage collected
	//if (which < 0) {
		lua_pushcfunction(L, savestate_gc);
		lua_setfield(L, -2, "__gc");
	//}

	// Set the metatable
	lua_setmetatable(L, -2);

	// Awesome. Return the object
	return 1;
}

// object savestate.object(int which = nil)
//
//  Creates an object used for savestates.
//  The object can be associated with a player-accessible savestate
//  ("which" between 1 and 10) or not (which == nil).
//  Uses more windows-friendly slot numbering
static int savestate_object(lua_State *L) {
	// New Save Slot Numbers:
	// 1-9 refer to 1-9, 10 refers to 0. QWERTY style.
	return savestate_create_aliased(L,true);
}

// object savestate.create(int which = nil)
//
//  Creates an object used for savestates.
//  The object can be associated with a player-accessible savestate
//  ("which" between 1 and 10) or not (which == nil).
//  Uses original slot numbering
static int savestate_create(lua_State *L) {
	// Original Save Slot Numbers:
	// 1-10, 1 refers to slot 0, 2-10 refer to 1-9
	return savestate_create_aliased(L,false);
}


// savestate.save(object state)
//
//   Saves a state to the given object.
static int savestate_save(lua_State *L) {

	//char *filename = savestateobj2filename(L,1);

	LuaSaveState *ss = (LuaSaveState *)lua_touserdata(L, 1);
	if (!ss) {
		luaL_error(L, "Invalid savestate.save object");
		return 0;
	}

	if(ss->data) delete ss->data;
	ss->data = new EMUFILE_MEMORY();

//	printf("saving %s\n", filename);

	// Save states are very expensive. They take time.
	numTries--;

	FCEUSS_SaveMS(ss->data,Z_NO_COMPRESSION);
	ss->data->fseek(0,SEEK_SET);
	return 0;
}

static int savestate_persist(lua_State *L) {

	LuaSaveState *ss = (LuaSaveState *)lua_touserdata(L, 1);
	ss->persist();
	return 0;
}

// savestate.load(object state)
//
//   Loads the given state
static int savestate_load(lua_State *L) {

	//char *filename = savestateobj2filename(L,1);

	LuaSaveState *ss = (LuaSaveState *)lua_touserdata(L, 1);

	if (!ss) {
		luaL_error(L, "Invalid savestate.load object");
		return 0;
	}

	numTries--;

	/*if (!ss->data) {
		luaL_error(L, "Invalid savestate.load data");
		return 0;
	} */
	if (FCEUSS_LoadFP(ss->data,SSLOADPARAM_NOBACKUP))
		ss->data->fseek(0,SEEK_SET);

	return 0;

}

static int savestate_registersave(lua_State *L) {

	lua_settop(L,1);
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFORESAVE]);
	lua_pushvalue(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFORESAVE]);
	//StopScriptIfFinished(luaStateToUIDMap[L]);
	return 1;
}
static int savestate_registerload(lua_State *L) {

	lua_settop(L,1);
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_AFTERLOAD]);
	lua_pushvalue(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_AFTERLOAD]);
	//StopScriptIfFinished(luaStateToUIDMap[L]);
	return 1;
}

static int savestate_loadscriptdata(lua_State *L) {

	const char *filename = savestateobj2filename(L,1);

	{
		LuaSaveData saveData;

		char luaSaveFilename [512];
		strncpy(luaSaveFilename, filename, 512);
		luaSaveFilename[512-(1+7/*strlen(".luasav")*/)] = '\0';
		strcat(luaSaveFilename, ".luasav");
		FILE* luaSaveFile = fopen(luaSaveFilename, "rb");
		if(luaSaveFile)
		{
			saveData.ImportRecords(luaSaveFile);
			fclose(luaSaveFile);

			lua_settop(L, 0);
			saveData.LoadRecord(L, LUA_DATARECORDKEY, (unsigned int)-1);
			return lua_gettop(L);
		}
	}
	return 0;
}


// int emu.framecount()
//
//   Gets the frame counter
int emu_framecount(lua_State *L) {

	lua_pushinteger(L, FCEUMOV_GetFrame());
	return 1;
}

// int emu.lagcount()
//
//   Gets the current lag count
int emu_lagcount(lua_State *L) {

	lua_pushinteger(L, FCEUI_GetLagCount());
	return 1;
}

// emu.lagged()
//
//   Returns true if the game is currently on a lag frame
int emu_lagged (lua_State *L) {

	bool Lag_Frame = FCEUI_GetLagged();
	lua_pushboolean(L, Lag_Frame);
	return 1;
}

// emu.setlagflag(bool value)
//
//   Returns true if the game is currently on a lag frame
int emu_setlagflag(lua_State *L)
{
	FCEUI_SetLagFlag(lua_toboolean(L, 1) == 1);
	return 0;
}

// boolean emu.emulating()
int emu_emulating(lua_State *L) {
	lua_pushboolean(L, GameInfo != NULL);
	return 1;
}

// string movie.mode()
//
//   Returns "taseditor", "record", "playback", "finished" or nil
int movie_mode(lua_State *L)
{
	if (FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
		lua_pushstring(L, "taseditor");
	else if (FCEUMOV_IsRecording())
		lua_pushstring(L, "record");
	else if (FCEUMOV_IsFinished())
		lua_pushstring(L, "finished"); //Note: this comes before playback since playback checks for finished as well
	else if (FCEUMOV_IsPlaying())
		lua_pushstring(L, "playback");
	else
		lua_pushnil(L);
	return 1;
}


static int movie_rerecordcounting(lua_State *L) {
	if (lua_gettop(L) == 0)
		luaL_error(L, "no parameters specified");

	skipRerecords = lua_toboolean(L,1);
	return 0;
}

// movie.stop()
//
//   Stops movie playback/recording. Bombs out if movie is not running.
static int movie_stop(lua_State *L) {
	if (!FCEUMOV_IsRecording() && !FCEUMOV_IsPlaying())
		luaL_error(L, "no movie");

	FCEUI_StopMovie();
	return 0;

}

// movie.active()
//
//returns a bool value is there is a movie currently open
int movie_isactive (lua_State *L) {

	bool movieactive = (FCEUMOV_IsRecording() || FCEUMOV_IsPlaying());
	lua_pushboolean(L, movieactive);
	return 1;
}

// movie.recording()
int movie_isrecording (lua_State *L) {

	lua_pushboolean(L, FCEUMOV_IsRecording());
	return 1;
}

// movie.playing()
int movie_isplaying (lua_State *L) {

	lua_pushboolean(L, FCEUMOV_IsPlaying());
	return 1;
}

//movie.rerecordcount()
//
//returns the rerecord count of the current movie
static int movie_rerecordcount (lua_State *L) {
	if (!FCEUMOV_IsRecording() && !FCEUMOV_IsPlaying() && !FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
		luaL_error(L, "No movie loaded.");

	lua_pushinteger(L, FCEUI_GetMovieRerecordCount());

	return 1;
}

//movie.length()
//
//returns an int value representing the total length of the current movie loaded

static int movie_getlength (lua_State *L) {
	if (!FCEUMOV_IsRecording() && !FCEUMOV_IsPlaying() && !FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
		luaL_error(L, "No movie loaded.");

	lua_pushinteger(L, FCEUI_GetMovieLength());

	return 1;
}

//movie.readonly
//
//returns true is emulator is in read-only mode, false if it is in read+write
static int movie_getreadonly (lua_State *L) {
	lua_pushboolean(L, FCEUI_GetMovieToggleReadOnly());

	return 1;
}

//movie.setreadonly
//
//Sets readonly / read+write status
static int movie_setreadonly (lua_State *L) {
	bool which = (lua_toboolean( L, 1 ) == 1);
	FCEUI_SetMovieToggleReadOnly(which);

	return 0;
}

//movie.getname
//
//returns the filename of the movie loaded
static int movie_getname (lua_State *L) {

	if (!FCEUMOV_IsRecording() && !FCEUMOV_IsPlaying() && !FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
		luaL_error(L, "No movie loaded.");

	std::string name = FCEUI_GetMovieName();
	lua_pushstring(L, name.c_str());
	return 1;
}

//movie.getfilename
//
//returns the filename of movie loaded with no path
static int movie_getfilename (lua_State *L) {

	if (!FCEUMOV_IsRecording() && !FCEUMOV_IsPlaying() && !FCEUMOV_Mode(MOVIEMODE_TASEDITOR))
		luaL_error(L, "No movie loaded.");

	std::string name = FCEUI_GetMovieName();
	int x =  name.find_last_of("/\\") + 1;
	if (x)
		name = name.substr(x, name.length()-x);
	lua_pushstring(L, name.c_str());
	return 1;
}

//movie.replay
//
//calls the play movie from beginning function
static int movie_replay (lua_State *L) {

	FCEUI_MoviePlayFromBeginning();

	return 0;
}

//movie.ispoweron
//
//If movie is recorded from power-on
static int movie_ispoweron (lua_State *L) {
	if (FCEUMOV_IsRecording() || FCEUMOV_IsPlaying()) {
		return FCEUMOV_FromPoweron();
	}
	else
		return 0;
}

//movie.isfromsavestate()
//
//If movie is recorded from a savestate
static int movie_isfromsavestate (lua_State *L) {
	if (FCEUMOV_IsRecording() || FCEUMOV_IsPlaying()) {
		return !FCEUMOV_FromPoweron();
	}
	else
		return 0;
}


#define LUA_SCREEN_WIDTH    256
#define LUA_SCREEN_HEIGHT   240

// Common code by the gui library: make sure the screen array is ready
static void gui_prepare() {
	if (!gui_data)
		gui_data = (uint8*) FCEU_dmalloc(LUA_SCREEN_WIDTH*LUA_SCREEN_HEIGHT*4);
	if (gui_used != GUI_USED_SINCE_LAST_DISPLAY)
		memset(gui_data, 0, LUA_SCREEN_WIDTH*LUA_SCREEN_HEIGHT*4);
	gui_used = GUI_USED_SINCE_LAST_DISPLAY;
}

// pixform for lua graphics
#define BUILD_PIXEL_ARGB8888(A,R,G,B) (((int) (A) << 24) | ((int) (R) << 16) | ((int) (G) << 8) | (int) (B))
#define DECOMPOSE_PIXEL_ARGB8888(PIX,A,R,G,B) { (A) = ((PIX) >> 24) & 0xff; (R) = ((PIX) >> 16) & 0xff; (G) = ((PIX) >> 8) & 0xff; (B) = (PIX) & 0xff; }
#define LUA_BUILD_PIXEL BUILD_PIXEL_ARGB8888
#define LUA_DECOMPOSE_PIXEL DECOMPOSE_PIXEL_ARGB8888
#define LUA_PIXEL_A(PIX) (((PIX) >> 24) & 0xff)
#define LUA_PIXEL_R(PIX) (((PIX) >> 16) & 0xff)
#define LUA_PIXEL_G(PIX) (((PIX) >> 8) & 0xff)
#define LUA_PIXEL_B(PIX) ((PIX) & 0xff)

template <class T> static void swap(T &one, T &two) {
	T temp = one;
	one = two;
	two = temp;
}

// write a pixel to buffer
static inline void blend32(uint32 *dstPixel, uint32 colour)
{
	uint8 *dst = (uint8*) dstPixel;
	int a, r, g, b;
	LUA_DECOMPOSE_PIXEL(colour, a, r, g, b);

	if (a == 255 || dst[3] == 0) {
		// direct copy
		*(uint32*)(dst) = colour;
	}
	else if (a == 0) {
		// do not copy
	}
	else {
		// alpha-blending
		int a_dst = ((255 - a) * dst[3] + 128) / 255;
		int a_new = a + a_dst;

		dst[0] = (uint8) ((( dst[0] * a_dst + b * a) + (a_new / 2)) / a_new);
		dst[1] = (uint8) ((( dst[1] * a_dst + g * a) + (a_new / 2)) / a_new);
		dst[2] = (uint8) ((( dst[2] * a_dst + r * a) + (a_new / 2)) / a_new);
		dst[3] = (uint8) a_new;
	}
}
// check if a pixel is in the lua canvas
static inline bool gui_check_boundary(int x, int y) {
	return !(x < 0 || x >= LUA_SCREEN_WIDTH || y < 0 || y >= LUA_SCREEN_HEIGHT);
}

// write a pixel to gui_data (do not check boundaries for speedup)
static inline void gui_drawpixel_fast(int x, int y, uint32 colour) {
	//gui_prepare();
	blend32((uint32*) &gui_data[(y*LUA_SCREEN_WIDTH+x)*4], colour);
}

// write a pixel to gui_data (check boundaries)
static inline void gui_drawpixel_internal(int x, int y, uint32 colour) {
	//gui_prepare();
	if (gui_check_boundary(x, y))
		gui_drawpixel_fast(x, y, colour);
}

// draw a line on gui_data (checks boundaries)
static void gui_drawline_internal(int x1, int y1, int x2, int y2, bool lastPixel, uint32 colour) {

	//gui_prepare();

	// Note: New version of Bresenham's Line Algorithm
	// http://groups.google.co.jp/group/rec.games.roguelike.development/browse_thread/thread/345f4c42c3b25858/29e07a3af3a450e6?show_docid=29e07a3af3a450e6

	int swappedx = 0;
	int swappedy = 0;

	int xtemp = x1-x2;
	int ytemp = y1-y2;
	if (xtemp == 0 && ytemp == 0) {
		gui_drawpixel_internal(x1, y1, colour);
		return;
	}
	if (xtemp < 0) {
		xtemp = -xtemp;
		swappedx = 1;
	}
	if (ytemp < 0) {
		ytemp = -ytemp;
		swappedy = 1;
	}

	int delta_x = xtemp << 1;
	int delta_y = ytemp << 1;

	signed char ix = x1 > x2?1:-1;
	signed char iy = y1 > y2?1:-1;

	if (lastPixel)
		gui_drawpixel_internal(x2, y2, colour);

	if (delta_x >= delta_y) {
		int error = delta_y - (delta_x >> 1);

		while (x2 != x1) {
			if (error == 0 && !swappedx)
				gui_drawpixel_internal(x2+ix, y2, colour);
			if (error >= 0) {
				if (error || (ix > 0)) {
					y2 += iy;
					error -= delta_x;
				}
			}
			x2 += ix;
			gui_drawpixel_internal(x2, y2, colour);
			if (error == 0 && swappedx)
				gui_drawpixel_internal(x2, y2+iy, colour);
			error += delta_y;
		}
	}
	else {
		int error = delta_x - (delta_y >> 1);

		while (y2 != y1) {
			if (error == 0 && !swappedy)
				gui_drawpixel_internal(x2, y2+iy, colour);
			if (error >= 0) {
				if (error || (iy > 0)) {
					x2 += ix;
					error -= delta_y;
				}
			}
			y2 += iy;
			gui_drawpixel_internal(x2, y2, colour);
			if (error == 0 && swappedy)
				gui_drawpixel_internal(x2+ix, y2, colour);
			error += delta_x;
		}
	}
}

// draw a rect on gui_data
static void gui_drawbox_internal(int x1, int y1, int x2, int y2, uint32 colour) {

	if (x1 > x2)
		swap<int>(x1, x2);
	if (y1 > y2)
		swap<int>(y1, y2);
	if (x1 < 0)
		x1 = -1;
	if (y1 < 0)
		y1 = -1;
	if (x2 >= LUA_SCREEN_WIDTH)
		x2 = LUA_SCREEN_WIDTH;
	if (y2 >= LUA_SCREEN_HEIGHT)
		y2 = LUA_SCREEN_HEIGHT;

	//gui_prepare();

	gui_drawline_internal(x1, y1, x2, y1, true, colour);
	gui_drawline_internal(x1, y2, x2, y2, true, colour);
	gui_drawline_internal(x1, y1, x1, y2, true, colour);
	gui_drawline_internal(x2, y1, x2, y2, true, colour);
}

// draw fill rect on gui_data
static void gui_fillbox_internal(int x1, int y1, int x2, int y2, uint32 colour)
{
	if (x1 > x2)
		std::swap(x1, x2);
	if (y1 > y2)
		std::swap(y1, y2);
	if (x1 < 0)
		x1 = 0;
	if (y1 < 0)
		y1 = 0;
	if (x2 >= LUA_SCREEN_WIDTH)
		x2 = LUA_SCREEN_WIDTH - 1;
	if (y2 >= LUA_SCREEN_HEIGHT)
		y2 = LUA_SCREEN_HEIGHT - 1;

	//gui_prepare();
	int ix, iy;
	for (iy = y1; iy <= y2; iy++)
	{
		for (ix = x1; ix <= x2; ix++)
		{
			gui_drawpixel_fast(ix, iy, colour);
		}
	}
}

enum
{
	GUI_COLOUR_CLEAR
	/*
	, GUI_COLOUR_WHITE, GUI_COLOUR_BLACK, GUI_COLOUR_GREY
	, GUI_COLOUR_RED,   GUI_COLOUR_GREEN, GUI_COLOUR_BLUE
	*/
};
/**
 * Returns an index approximating an RGB colour.
 * TODO: This is easily improvable in terms of speed and probably
 * quality of matches. (gd overlay & transparency code call it a lot.)
 * With effort we could also cheat and map indices 0x08 .. 0x3F
 * ourselves.
 */
static uint8 gui_colour_rgb(uint8 r, uint8 g, uint8 b) {
	static uint8 index_lookup[1 << (3+3+3)];
	int k;

	if (!gui_saw_current_palette)
	{
		memset(index_lookup, GUI_COLOUR_CLEAR, sizeof(index_lookup));
		gui_saw_current_palette = TRUE;
	}

	k = ((r & 0xE0) << 1) | ((g & 0xE0) >> 2) | ((b & 0xE0) >> 5);
	uint16 test, best = GUI_COLOUR_CLEAR;
	uint32 best_score = 0xffffffffu, test_score;
	if (index_lookup[k] != GUI_COLOUR_CLEAR) return index_lookup[k];
	for (test = 0; test < 0xff; test++)
	{
		uint8 tr, tg, tb;
		if (test == GUI_COLOUR_CLEAR) continue;
		FCEUD_GetPalette(test, &tr, &tg, &tb);
		test_score = abs(r - tr) *  66 +
		             abs(g - tg) * 129 +
		             abs(b - tb) *  25;
		if (test_score < best_score) best_score = test_score, best = test;
	}
	index_lookup[k] = best;
	return best;
}

void FCEU_LuaUpdatePalette()
{
	gui_saw_current_palette = FALSE;
}

// Helper for a simple hex parser
static int hex2int(lua_State *L, char c) {
	if (c >= '0' && c <= '9')
		return c-'0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	return luaL_error(L, "invalid hex in colour");
}

static const struct ColorMapping
{
	const char* name;
	unsigned int value;
}
s_colorMapping [] =
{
	{"white",     0xFFFFFFFF},
	{"black",     0x000000FF},
	{"clear",     0x00000000},
	{"gray",      0x7F7F7FFF},
	{"grey",      0x7F7F7FFF},
	{"red",       0xFF0000FF},
	{"orange",    0xFF7F00FF},
	{"yellow",    0xFFFF00FF},
	{"chartreuse",0x7FFF00FF},
	{"green",     0x00FF00FF},
	{"teal",      0x00FF7FFF},
	{"cyan" ,     0x00FFFFFF},
	{"blue",      0x0000FFFF},
	{"purple",    0x7F00FFFF},
	{"magenta",   0xFF00FFFF},
};

/**
 * Converts an integer or a string on the stack at the given
 * offset to a RGB32 colour. Several encodings are supported.
 * The user may construct their own RGB value, given a simple colour name,
 * or an HTML-style "#09abcd" colour. 16 bit reduction doesn't occur at this time.
 * NES palettes added with notation "P00" to "P3F". "P40" to "P7F" denote LUA palettes.
 */
static inline bool str2colour(uint32 *colour, lua_State *L, const char *str) {
	if (str[0] == '#') {
		int color;
		sscanf(str+1, "%X", &color);
		int len = strlen(str+1);
		int missing = std::max(0, 8-len);
		color <<= missing << 2;
		if(missing >= 2) color |= 0xFF;
		*colour = color;
		return true;
	}
	else if (str[0] == 'P') {
		uint8 palette;
		uint8 tr, tg, tb;

		if (strlen(str+1) == 2) {
			palette = ((hex2int(L, str[1]) * 0x10) + hex2int(L, str[2]));
		} else if (strlen(str+1) == 1) {
			palette = (hex2int(L, str[1]));
		} else {
			luaL_error(L, "palettes are defined with P## hex notion");
			return false;
		}

		if (palette > 0x7F) {
			luaL_error(L, "palettes range from P00 to P7F");
			return false;
		}

		FCEUD_GetPalette(palette + 0x80, &tr, &tg, &tb);
		// Feeding it RGBA, because it will spit out the right value for me
		*colour = LUA_BUILD_PIXEL(tr, tg, tb, 0xFF);
		return true;
	}
	else {
		if(!strnicmp(str, "rand", 4)) {
			*colour = ((rand()*255/RAND_MAX) << 8) | ((rand()*255/RAND_MAX) << 16) | ((rand()*255/RAND_MAX) << 24) | 0xFF;
			return true;
		}
		for(int i = 0; i < sizeof(s_colorMapping)/sizeof(*s_colorMapping); i++) {
			if(!stricmp(str,s_colorMapping[i].name)) {
				*colour = s_colorMapping[i].value;
				return true;
			}
		}
	}
	return false;
}
static inline uint32 gui_getcolour_wrapped(lua_State *L, int offset, bool hasDefaultValue, uint32 defaultColour) {
	switch (lua_type(L,offset)) {
	case LUA_TSTRING:
		{
			const char *str = lua_tostring(L,offset);
			uint32 colour;

			if (str2colour(&colour, L, str))
				return colour;
			else {
				if (hasDefaultValue)
					return defaultColour;
				else
					return luaL_error(L, "unknown colour %s", str);
			}
		}
	case LUA_TNUMBER:
		{
			uint32 colour = (uint32) lua_tointeger(L,offset);
			return colour;
		}
	case LUA_TTABLE:
		{
			int color = 0xFF;
			lua_pushnil(L); // first key
			int keyIndex = lua_gettop(L);
			int valueIndex = keyIndex + 1;
			bool first = true;
			while(lua_next(L, offset))
			{
				bool keyIsString = (lua_type(L, keyIndex) == LUA_TSTRING);
				bool keyIsNumber = (lua_type(L, keyIndex) == LUA_TNUMBER);
				int key = keyIsString ? tolower(*lua_tostring(L, keyIndex)) : (keyIsNumber ? lua_tointeger(L, keyIndex) : 0);
				int value = lua_tointeger(L, valueIndex);
				if(value < 0) value = 0;
				if(value > 255) value = 255;
				switch(key)
				{
				case 1: case 'r': color |= value << 24; break;
				case 2: case 'g': color |= value << 16; break;
				case 3: case 'b': color |= value << 8; break;
				case 4: case 'a': color = (color & ~0xFF) | value; break;
				}
				lua_pop(L, 1);
			}
			return color;
		}	break;
	case LUA_TFUNCTION:
		luaL_error(L, "invalid colour"); // NYI
		return 0;
	default:
		if (hasDefaultValue)
			return defaultColour;
		else
			return luaL_error(L, "invalid colour");
	}
}
static uint32 gui_getcolour(lua_State *L, int offset) {
	uint32 colour;
	int a, r, g, b;

	colour = gui_getcolour_wrapped(L, offset, false, 0);
	a = ((colour & 0xff) * transparencyModifier) / 255;
	if (a > 255) a = 255;
	b = (colour >> 8) & 0xff;
	g = (colour >> 16) & 0xff;
	r = (colour >> 24) & 0xff;
	return LUA_BUILD_PIXEL(a, r, g, b);
}
static uint32 gui_optcolour(lua_State *L, int offset, uint32 defaultColour) {
	uint32 colour;
	int a, r, g, b;
	uint8 defA, defB, defG, defR;

	LUA_DECOMPOSE_PIXEL(defaultColour, defA, defR, defG, defB);
	defaultColour = (defR << 24) | (defG << 16) | (defB << 8) | defA;

	colour = gui_getcolour_wrapped(L, offset, true, defaultColour);
	a = ((colour & 0xff) * transparencyModifier) / 255;
	if (a > 255) a = 255;
	b = (colour >> 8) & 0xff;
	g = (colour >> 16) & 0xff;
	r = (colour >> 24) & 0xff;
	return LUA_BUILD_PIXEL(a, r, g, b);
}

// gui.pixel(x,y,colour)
static int gui_pixel(lua_State *L) {

	int x = luaL_checkinteger(L, 1);
	int y = luaL_checkinteger(L,2);

	uint32 colour = gui_getcolour(L,3);

//	if (!gui_check_boundary(x, y))
//		luaL_error(L,"bad coordinates");

	gui_prepare();

	gui_drawpixel_internal(x, y, colour);

	return 0;
}

// Usage:
// local r,g,b,a = gui.getpixel(255, 223)
// Gets the LUA set pixel color
static int gui_getpixel(lua_State *L) {

	int x = luaL_checkinteger(L, 1);
	int y = luaL_checkinteger(L,2);

	int r, g, b, a;

	if (!gui_check_boundary(x, y))
		luaL_error(L,"bad coordinates. Use 0-%d x 0-%d", LUA_SCREEN_WIDTH - 1, LUA_SCREEN_HEIGHT - 1);

	if (!gui_data) {
		// Return all 0s, including for alpha.
		// If alpha == 0, there was no color data for that spot
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		return 4;
	}

	//uint8 *dst = (uint8*) &gui_data[(y*LUA_SCREEN_WIDTH+x)*4];

	//uint32 color = *(uint32*) &gui_data[(y*LUA_SCREEN_WIDTH+x)*4];

	LUA_DECOMPOSE_PIXEL(*(uint32*) &gui_data[(y*LUA_SCREEN_WIDTH+x)*4], a, r, g, b);

	lua_pushinteger(L, r);
	lua_pushinteger(L, g);
	lua_pushinteger(L, b);
	lua_pushinteger(L, a);
	return 4;

}

// Usage:
// local r,g,b,palette = gui.getpixel(255, 255)
// Gets the screen pixel color
// Palette will be 254 on error
static int emu_getscreenpixel(lua_State *L) {

	int x = luaL_checkinteger(L, 1);
	int y = luaL_checkinteger(L,2);
	bool getemuscreen = (lua_toboolean(L,3) == 1);

	int r, g, b;
	int palette;

	if (((x < 0) || (x > 255)) || ((y < 0) || (y > 239))) {
		luaL_error(L,"bad coordinates. Use 0-255 x 0-239");

		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 254);
		return 4;
	}

	if (!XBuf) {
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 0);
		lua_pushinteger(L, 254);
		return 4;
	}

	uint32 pixelinfo = GetScreenPixel(x,y,getemuscreen);

	LUA_DECOMPOSE_PIXEL(pixelinfo, palette, r, g, b);
	palette = GetScreenPixelPalette(x,y,getemuscreen);

	lua_pushinteger(L, r);
	lua_pushinteger(L, g);
	lua_pushinteger(L, b);
	lua_pushinteger(L, palette);
	return 4;

}

// gui.line(x1,y1,x2,y2,color,skipFirst)
static int gui_line(lua_State *L) {

	int x1,y1,x2,y2;
	uint32 color;
	x1 = luaL_checkinteger(L,1);
	y1 = luaL_checkinteger(L,2);
	x2 = luaL_checkinteger(L,3);
	y2 = luaL_checkinteger(L,4);
	color = gui_optcolour(L,5,LUA_BUILD_PIXEL(255, 255, 255, 255));
	int skipFirst = lua_toboolean(L,6);

	gui_prepare();

	gui_drawline_internal(x2, y2, x1, y1, !skipFirst, color);

	return 0;
}

// gui.box(x1, y1, x2, y2, fillcolor, outlinecolor)
static int gui_box(lua_State *L) {

	int x1,y1,x2,y2;
	uint32 fillcolor;
	uint32 outlinecolor;

	x1 = luaL_checkinteger(L,1);
	y1 = luaL_checkinteger(L,2);
	x2 = luaL_checkinteger(L,3);
	y2 = luaL_checkinteger(L,4);
	fillcolor = gui_optcolour(L,5,LUA_BUILD_PIXEL(63, 255, 255, 255));
	outlinecolor = gui_optcolour(L,6,LUA_BUILD_PIXEL(255, LUA_PIXEL_R(fillcolor), LUA_PIXEL_G(fillcolor), LUA_PIXEL_B(fillcolor)));

	if (x1 > x2)
		std::swap(x1, x2);
	if (y1 > y2)
		std::swap(y1, y2);

	gui_prepare();

	gui_drawbox_internal(x1, y1, x2, y2, outlinecolor);
	if ((x2 - x1) >= 2 && (y2 - y1) >= 2)
		gui_fillbox_internal(x1+1, y1+1, x2-1, y2-1, fillcolor);

	return 0;
}

// (old) gui.box(x1, y1, x2, y2, color)
static int gui_box_old(lua_State *L) {

	int x1,y1,x2,y2;
	uint32 colour;

	x1 = luaL_checkinteger(L,1);
	y1 = luaL_checkinteger(L,2);
	x2 = luaL_checkinteger(L,3);
	y2 = luaL_checkinteger(L,4);
	colour = gui_getcolour(L,5);

//	if (!gui_check_boundary(x1, y1))
//		luaL_error(L,"bad coordinates");
//
//	if (!gui_check_boundary(x2, y2))
//		luaL_error(L,"bad coordinates");

	gui_prepare();

	gui_drawbox_internal(x1, y1, x2, y2, colour);

	return 0;
}

static int gui_parsecolor(lua_State *L)
{
	int r, g, b, a;
	uint32 color = gui_getcolour(L,1);
	LUA_DECOMPOSE_PIXEL(color, a, r, g, b);
	lua_pushinteger(L, r);
	lua_pushinteger(L, g);
	lua_pushinteger(L, b);
	lua_pushinteger(L, a);
	return 4;
}


// gui.savescreenshotas()
//
// Causes FCEUX to write a screenshot to a file based on a received filename, caution: will overwrite existing screenshot files
//
// Unconditionally retrns 1; any failure in taking a screenshot would be reported on-screen
// from the function ReallySnap().
static int gui_savescreenshotas(lua_State *L) {
	const char* name = NULL;
	size_t l;
	name = luaL_checklstring(L,1,&l);
	lua_pushstring(L, name);
	if (name)
		FCEUI_SetSnapshotAsName(name);
	else
		luaL_error(L,"gui.savesnapshotas must have a string parameter");
	FCEUI_SaveSnapshotAs();
	return 1;
}


// gui.savescreenshot()
//
// Causes FCEUX to write a screenshot to a file as if the user pressed the associated hotkey.
//
// Unconditionally retrns 1; any failure in taking a screenshot would be reported on-screen
// from the function ReallySnap().
static int gui_savescreenshot(lua_State *L) {
	FCEUI_SaveSnapshot();
	return 1;
}

// gui.gdscreenshot()
//
//  Returns a screen shot as a string in gd's v1 file format.
//  This allows us to make screen shots available without gd installed locally.
//  Users can also just grab pixels via substring selection.
//
//  I think...  Does lua support grabbing byte values from a string? // yes, string.byte(str,offset)
//  Well, either way, just install gd and do what you like with it.
//  It really is easier that way.
// example: gd.createFromGdStr(gui.gdscreenshot()):png("outputimage.png")
static int gui_gdscreenshot(lua_State *L) {

	int width = LUA_SCREEN_WIDTH;
	int height = LUA_SCREEN_HEIGHT;

	int size = 11 + width * height * 4;
	char* str = new char[size+1];
	str[size] = 0;
	unsigned char* ptr = (unsigned char*)str;

	// GD format header for truecolor image (11 bytes)
	*ptr++ = (65534 >> 8) & 0xFF;
	*ptr++ = (65534     ) & 0xFF;
	*ptr++ = (width >> 8) & 0xFF;
	*ptr++ = (width     ) & 0xFF;
	*ptr++ = (height>> 8) & 0xFF;
	*ptr++ = (height    ) & 0xFF;
	*ptr++ = 1;
	*ptr++ = 255;
	*ptr++ = 255;
	*ptr++ = 255;
	*ptr++ = 255;

	for (int y=0; y < height; y++) {
		for (int x=0; x < width; x++) {
			uint8 index = XBuf[(y)*256 + x];

			// Write A,R,G,B (alpha=0 for us):
			*ptr = 0;
			FCEUD_GetPalette(index, ptr + 1, ptr + 2, ptr + 3);
			ptr += 4;
		}
	}

	lua_pushlstring(L, str, size);
	delete[] str;
	return 1;
}

// gui.opacity(number alphaValue)
// sets the transparency of subsequent draw calls
// 0.0 is completely transparent, 1.0 is completely opaque
// non-integer values are supported and meaningful, as are values greater than 1.0
// it is not necessary to use this function to get transparency (or the less-recommended gui.transparency() either),
// because you can provide an alpha value in the color argument of each draw call.
// however, it can be convenient to be able to globally modify the drawing transparency
static int gui_setopacity(lua_State *L) {
	double opacF = luaL_checknumber(L,1);
	transparencyModifier = (int) (opacF * 255);
	if (transparencyModifier < 0)
		transparencyModifier = 0;
	return 0;
}

// gui.transparency(int strength)
//
//  0 = solid,
static int gui_transparency(lua_State *L) {
	double trans = luaL_checknumber(L,1);
	transparencyModifier = (int) ((4.0 - trans) / 4.0 * 255);
	if (transparencyModifier < 0)
		transparencyModifier = 0;
	return 0;
}


static const uint32 Small_Font_Data[] =
{
	0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,			// 32
	0x00000000, 0x00000300, 0x00000400, 0x00000500, 0x00000000, 0x00000700, 0x00000000,			// 33	!
	0x00000000, 0x00040002, 0x00050003, 0x00000000, 0x00000000, 0x00000000, 0x00000000,			// 34	"
	0x00000000, 0x00040002, 0x00050403, 0x00060004, 0x00070605, 0x00080006, 0x00000000,			// 35	#
	0x00000000, 0x00040300, 0x00000403, 0x00000500, 0x00070600, 0x00000706, 0x00000000,			// 36	$
	0x00000000, 0x00000002, 0x00050000, 0x00000500, 0x00000005, 0x00080000, 0x00000000,			// 37	%
	0x00000000, 0x00000300, 0x00050003, 0x00000500, 0x00070005, 0x00080700, 0x00000000,			// 38	&
	0x00000000, 0x00000300, 0x00000400, 0x00000000, 0x00000000, 0x00000000, 0x00000000,			// 39	'
	0x00000000, 0x00000300, 0x00000003, 0x00000004, 0x00000005, 0x00000700, 0x00000000,			// 40	(
	0x00000000, 0x00000300, 0x00050000, 0x00060000, 0x00070000, 0x00000700, 0x00000000,			// 41	)
	0x00000000, 0x00000000, 0x00000400, 0x00060504, 0x00000600, 0x00080006, 0x00000000,			// 42	*
	0x00000000, 0x00000000, 0x00000400, 0x00060504, 0x00000600, 0x00000000, 0x00000000,			// 43	+
	0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000600, 0x00000700, 0x00000007,			// 44	,
	0x00000000, 0x00000000, 0x00000000, 0x00060504, 0x00000000, 0x00000000, 0x00000000,			// 45	-
	0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000700, 0x00000000,			// 46	.
	0x00030000, 0x00040000, 0x00000400, 0x00000500, 0x00000005, 0x00000006, 0x00000000,			// 47	/
	0x00000000, 0x00000300, 0x00050003, 0x00060004, 0x00070005, 0x00000700, 0x00000000,			// 48	0
	0x00000000, 0x00000300, 0x00000403, 0x00000500, 0x00000600, 0x00000700, 0x00000000,			// 49	1
	0x00000000, 0x00000302, 0x00050000, 0x00000500, 0x00000005, 0x00080706, 0x00000000,			// 50	2
	0x00000000, 0x00000302, 0x00050000, 0x00000504, 0x00070000, 0x00000706, 0x00000000,			// 51	3
	0x00000000, 0x00000300, 0x00000003, 0x00060004, 0x00070605, 0x00080000, 0x00000000,			// 52	4
	0x00000000, 0x00040302, 0x00000003, 0x00000504, 0x00070000, 0x00000706, 0x00000000,			// 53	5
	0x00000000, 0x00000300, 0x00000003, 0x00000504, 0x00070005, 0x00000700, 0x00000000,			// 54	6
	0x00000000, 0x00040302, 0x00050000, 0x00000500, 0x00000600, 0x00000700, 0x00000000,			// 55	7
	0x00000000, 0x00000300, 0x00050003, 0x00000500, 0x00070005, 0x00000700, 0x00000000,			// 56	8
	0x00000000, 0x00000300, 0x00050003, 0x00060500, 0x00070000, 0x00000700, 0x00000000,			// 57	9
	0x00000000, 0x00000000, 0x00000400, 0x00000000, 0x00000000, 0x00000700, 0x00000000,			// 58	:
	0x00000000, 0x00000000, 0x00000000, 0x00000500, 0x00000000, 0x00000700, 0x00000007,			// 59	;
	0x00000000, 0x00040000, 0x00000400, 0x00000004, 0x00000600, 0x00080000, 0x00000000,			// 60	<
	0x00000000, 0x00000000, 0x00050403, 0x00000000, 0x00070605, 0x00000000, 0x00000000,			// 61	=
	0x00000000, 0x00000002, 0x00000400, 0x00060000, 0x00000600, 0x00000006, 0x00000000,			// 62	>
	0x00000000, 0x00000302, 0x00050000, 0x00000500, 0x00000000, 0x00000700, 0x00000000,			// 63	?
	0x00000000, 0x00000300, 0x00050400, 0x00060004, 0x00070600, 0x00000000, 0x00000000,			// 64	@
	0x00000000, 0x00000300, 0x00050003, 0x00060504, 0x00070005, 0x00080006, 0x00000000,			// 65	A
	0x00000000, 0x00000302, 0x00050003, 0x00000504, 0x00070005, 0x00000706, 0x00000000,			// 66	B
	0x00000000, 0x00040300, 0x00000003, 0x00000004, 0x00000005, 0x00080700, 0x00000000,			// 67	C
	0x00000000, 0x00000302, 0x00050003, 0x00060004, 0x00070005, 0x00000706, 0x00000000,			// 68	D
	0x00000000, 0x00040302, 0x00000003, 0x00000504, 0x00000005, 0x00080706, 0x00000000,			// 69	E
	0x00000000, 0x00040302, 0x00000003, 0x00000504, 0x00000005, 0x00000006, 0x00000000,			// 70	F
	0x00000000, 0x00040300, 0x00000003, 0x00060004, 0x00070005, 0x00080700, 0x00000000,			// 71	G
	0x00000000, 0x00040002, 0x00050003, 0x00060504, 0x00070005, 0x00080006, 0x00000000,			// 72	H
	0x00000000, 0x00000300, 0x00000400, 0x00000500, 0x00000600, 0x00000700, 0x00000000,			// 73	I
	0x00000000, 0x00040000, 0x00050000, 0x00060000, 0x00070005, 0x00000700, 0x00000000,			// 74	J
	0x00000000, 0x00040002, 0x00050003, 0x00000504, 0x00070005, 0x00080006, 0x00000000,			// 75	K
	0x00000000, 0x00000002, 0x00000003, 0x00000004, 0x00000005, 0x00080706, 0x00000000,			// 76	l
	0x00000000, 0x00040002, 0x00050403, 0x00060004, 0x00070005, 0x00080006, 0x00000000,			// 77	M
	0x00000000, 0x00000302, 0x00050003, 0x00060004, 0x00070005, 0x00080006, 0x00000000,			// 78	N
	0x00000000, 0x00040302, 0x00050003, 0x00060004, 0x00070005, 0x00080706, 0x00000000,			// 79	O
	0x00000000, 0x00000302, 0x00050003, 0x00000504, 0x00000005, 0x00000006, 0x00000000,			// 80	P
	0x00000000, 0x00040302, 0x00050003, 0x00060004, 0x00070005, 0x00080706, 0x00090000,			// 81	Q
	0x00000000, 0x00000302, 0x00050003, 0x00000504, 0x00070005, 0x00080006, 0x00000000,			// 82	R
	0x00000000, 0x00040300, 0x00000003, 0x00000500, 0x00070000, 0x00000706, 0x00000000,			// 83	S
	0x00000000, 0x00040302, 0x00000400, 0x00000500, 0x00000600, 0x00000700, 0x00000000,			// 84	T
	0x00000000, 0x00040002, 0x00050003, 0x00060004, 0x00070005, 0x00080706, 0x00000000,			// 85	U
	0x00000000, 0x00040002, 0x00050003, 0x00060004, 0x00000600, 0x00000700, 0x00000000,			// 86	V
	0x00000000, 0x00040002, 0x00050003, 0x00060004, 0x00070605, 0x00080006, 0x00000000,			// 87	W
	0x00000000, 0x00040002, 0x00050003, 0x00000500, 0x00070005, 0x00080006, 0x00000000,			// 88	X
	0x00000000, 0x00040002, 0x00050003, 0x00000500, 0x00000600, 0x00000700, 0x00000000,			// 89	Y
	0x00000000, 0x00040302, 0x00050000, 0x00000500, 0x00000005, 0x00080706, 0x00000000,			// 90	Z
	0x00000000, 0x00040300, 0x00000400, 0x00000500, 0x00000600, 0x00080700, 0x00000000,			// 91	[
	0x00000000, 0x00000002, 0x00000400, 0x00000500, 0x00070000, 0x00080000, 0x00000000,			// 92	'\'
	0x00000000, 0x00000302, 0x00000400, 0x00000500, 0x00000600, 0x00000706, 0x00000000,			// 93	]
	0x00000000, 0x00000300, 0x00050003, 0x00000000, 0x00000000, 0x00000000, 0x00000000,			// 94	^
	0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00080706, 0x00000000,			// 95	_
	0x00000000, 0x00000002, 0x00000400, 0x00000000, 0x00000000, 0x00000000, 0x00000000,			// 96	`
	0x00000000, 0x00000000, 0x00050400, 0x00060004, 0x00070005, 0x00080700, 0x00000000,			// 97	a
	0x00000000, 0x00000002, 0x00000003, 0x00000504, 0x00070005, 0x00000706, 0x00000000,			// 98	b
	0x00000000, 0x00000000, 0x00050400, 0x00000004, 0x00000005, 0x00080700, 0x00000000,			// 99	c
	0x00000000, 0x00040000, 0x00050000, 0x00060500, 0x00070005, 0x00080700, 0x00000000,			// 100	d
	0x00000000, 0x00000000, 0x00050400, 0x00060504, 0x00000005, 0x00080700, 0x00000000,			// 101	e
	0x00000000, 0x00040300, 0x00000003, 0x00000504, 0x00000005, 0x00000006, 0x00000000,			// 102	f
	0x00000000, 0x00000000, 0x00050400, 0x00060004, 0x00070600, 0x00080000, 0x00000807,			// 103	g
	0x00000000, 0x00000002, 0x00000003, 0x00000504, 0x00070005, 0x00080006, 0x00000000,			// 104	h
	0x00000000, 0x00000300, 0x00000000, 0x00000500, 0x00000600, 0x00000700, 0x00000000,			// 105	i
	0x00000000, 0x00000300, 0x00000000, 0x00000500, 0x00000600, 0x00000700, 0x00000007,			// 106	j
	0x00000000, 0x00000002, 0x00000003, 0x00060004, 0x00000605, 0x00080006, 0x00000000,			// 107	k
	0x00000000, 0x00000300, 0x00000400, 0x00000500, 0x00000600, 0x00080000, 0x00000000,			// 108	l
	0x00000000, 0x00000000, 0x00050003, 0x00060504, 0x00070005, 0x00080006, 0x00000000,			// 109	m
	0x00000000, 0x00000000, 0x00000403, 0x00060004, 0x00070005, 0x00080006, 0x00000000,			// 110	n
	0x00000000, 0x00000000, 0x00000400, 0x00060004, 0x00070005, 0x00000700, 0x00000000,			// 111	o
	0x00000000, 0x00000000, 0x00000400, 0x00060004, 0x00000605, 0x00000006, 0x00000007,			// 112	p
	0x00000000, 0x00000000, 0x00000400, 0x00060004, 0x00070600, 0x00080000, 0x00090000,			// 113	q
	0x00000000, 0x00000000, 0x00050003, 0x00000504, 0x00000005, 0x00000006, 0x00000000,			// 114	r
	0x00000000, 0x00000000, 0x00050400, 0x00000004, 0x00070600, 0x00000706, 0x00000000,			// 115	s
	0x00000000, 0x00000300, 0x00050403, 0x00000500, 0x00000600, 0x00080000, 0x00000000,			// 116	t
	0x00000000, 0x00000000, 0x00050003, 0x00060004, 0x00070005, 0x00080700, 0x00000000,			// 117	u
	0x00000000, 0x00000000, 0x00050003, 0x00060004, 0x00070005, 0x00000700, 0x00000000,			// 118	v
	0x00000000, 0x00000000, 0x00050003, 0x00060004, 0x00070605, 0x00080006, 0x00000000,			// 119	w
	0x00000000, 0x00000000, 0x00050003, 0x00000500, 0x00070005, 0x00080006, 0x00000000,			// 120	x
	0x00000000, 0x00000000, 0x00050003, 0x00060004, 0x00000600, 0x00000700, 0x00000007,			// 121	y
	0x00000000, 0x00000000, 0x00050403, 0x00000500, 0x00000005, 0x00080706, 0x00000000,			// 122	z
	0x00000000, 0x00040300, 0x00000400, 0x00000504, 0x00000600, 0x00080700, 0x00000000,			// 123	{
	0x00000000, 0x00000300, 0x00000400, 0x00000000, 0x00000600, 0x00000700, 0x00000000,			// 124	|
	0x00000000, 0x00000302, 0x00000400, 0x00060500, 0x00000600, 0x00000706, 0x00000000,			// 125	}
	0x00000000, 0x00000302, 0x00050000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,			// 126	~
	0x00000000, 0x00000000, 0x00000400, 0x00060004, 0x00070605, 0x00000000, 0x00000000,			// 127	
	0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x00000000,
};

static void PutTextInternal (const char *str, int len, short x, short y, int color, int backcolor)
{
	int Opac = (color >> 24) & 0xFF;
	int backOpac = (backcolor >> 24) & 0xFF;
	int origX = x;

	if(!Opac && !backOpac)
		return;

	while(*str && len && y < LUA_SCREEN_HEIGHT)
	{
		int c = *str++;
		while (x > LUA_SCREEN_WIDTH && c != '\n') {
			c = *str;
			if (c == '\0')
				break;
			str++;
		}
		if(c == '\n')
		{
			x = origX;
			y += 8;
			continue;
		}
		else if(c == '\t') // just in case
		{
			const int tabSpace = 8;
			x += (tabSpace-(((x-origX)/4)%tabSpace))*4;
			continue;
		}
		if((unsigned int)(c-32) >= 96)
			continue;
		const unsigned char* Cur_Glyph = (const unsigned char*)&Small_Font_Data + (c-32)*7*4;

		for(int y2 = 0; y2 < 8; y2++)
		{
			unsigned int glyphLine = *((unsigned int*)Cur_Glyph + y2);
			for(int x2 = -1; x2 < 4; x2++)
			{
				int shift = x2 << 3;
				int mask = 0xFF << shift;
				int intensity = (glyphLine & mask) >> shift;

				if(intensity && x2 >= 0 && y2 < 7)
				{
					//int xdraw = std::max(0,std::min(LUA_SCREEN_WIDTH - 1,x+x2));
					//int ydraw = std::max(0,std::min(LUA_SCREEN_HEIGHT - 1,y+y2));
					//gui_drawpixel_fast(xdraw, ydraw, color);
					gui_drawpixel_internal(x+x2, y+y2, color);
				}
				else if(backOpac)
				{
					for(int y3 = std::max(0,y2-1); y3 <= std::min(6,y2+1); y3++)
					{
						unsigned int glyphLine = *((unsigned int*)Cur_Glyph + y3);
						for(int x3 = std::max(0,x2-1); x3 <= std::min(3,x2+1); x3++)
						{
							int shift = x3 << 3;
							int mask = 0xFF << shift;
							intensity |= (glyphLine & mask) >> shift;
							if (intensity)
								goto draw_outline; // speedup?
						}
					}
draw_outline:
					if(intensity)
					{
						//int xdraw = std::max(0,std::min(LUA_SCREEN_WIDTH - 1,x+x2));
						//int ydraw = std::max(0,std::min(LUA_SCREEN_HEIGHT - 1,y+y2));
						//gui_drawpixel_fast(xdraw, ydraw, backcolor);
						gui_drawpixel_internal(x+x2, y+y2, backcolor);
					}
				}
			}
		}

		x += 4;
		len--;
	}
}

static int strlinelen(const char* string)
{
	const char* s = string;
	while(*s && *s != '\n')
		s++;
	if(*s)
		s++;
	return s - string;
}

static void LuaDisplayString (const char *string, int y, int x, uint32 color, uint32 outlineColor)
{
	if(!string)
		return;

	gui_prepare();

	PutTextInternal(string, strlen(string), x, y, color, outlineColor);
/*
	const char* ptr = string;
	while(*ptr && y < LUA_SCREEN_HEIGHT)
	{
		int len = strlinelen(ptr);
		int skip = 0;
		if(len < 1) len = 1;

		// break up the line if it's too long to display otherwise
		if(len > 63)
		{
			len = 63;
			const char* ptr2 = ptr + len-1;
			for(int j = len-1; j; j--, ptr2--)
			{
				if(*ptr2 == ' ' || *ptr2 == '\t')
				{
					len = j;
					skip = 1;
					break;
				}
			}
		}

		int xl = 0;
		int yl = 0;
		int xh = (LUA_SCREEN_WIDTH - 1 - 1) - 4*len;
		int yh = LUA_SCREEN_HEIGHT - 1;
		int x2 = std::min(std::max(x,xl),xh);
		int y2 = std::min(std::max(y,yl),yh);

		PutTextInternal(ptr,len,x2,y2,color,outlineColor);

		ptr += len + skip;
		y += 8;
	}
*/
}


static uint8 FCEUFont[792] =
{
	6,  0,  0,  0,  0,  0,  0,  0,	// 0x20 - Spacebar
	3, 64, 64, 64, 64, 64,  0, 64,
	5, 80, 80, 80,  0,  0,  0,  0,
	6, 80, 80,248, 80,248, 80, 80,
	6, 32,120,160,112, 40,240, 32,
	6, 64,168, 80, 32, 80,168, 16,
	6, 96,144,160, 64,168,144,104,
	3, 64, 64,  0,  0,  0,  0,  0,
	4, 32, 64, 64, 64, 64, 64, 32,
	4, 64, 32, 32, 32, 32, 32, 64,
	6,  0, 80, 32,248, 32, 80,  0,
	6,  0, 32, 32,248, 32, 32,  0,
	3,  0,  0,  0,  0,  0, 64,128,
	5,  0,  0,  0,240,  0,  0,  0,
	3,  0,  0,  0,  0,  0,  0, 64,
	5, 16, 16, 32, 32, 32, 64, 64,
	6,112,136,136,136,136,136,112,	// 0x30 - 0
	6, 32, 96, 32, 32, 32, 32, 32,
	6,112,136,  8, 48, 64,128,248,
	6,112,136,  8, 48,  8,136,112,
	6, 16, 48, 80,144,248, 16, 16,
	6,248,128,128,240,  8,  8,240,
	6, 48, 64,128,240,136,136,112,
	6,248,  8, 16, 16, 32, 32, 32,
	6,112,136,136,112,136,136,112,
	6,112,136,136,120,  8, 16, 96,
	3,  0,  0, 64,  0,  0, 64,  0,
	3,  0,  0, 64,  0,  0, 64,128,
	4,  0, 32, 64,128, 64, 32,  0,
	5,  0,  0,240,  0,240,  0,  0,
	4,  0,128, 64, 32, 64,128,  0,
	6,112,136,  8, 16, 32,  0, 32,	// 0x3F - ?
	6,112,136,136,184,176,128,112,	// 0x40 - @
	6,112,136,136,248,136,136,136,	// 0x41 - A
	6,240,136,136,240,136,136,240,
	6,112,136,128,128,128,136,112,
	6,224,144,136,136,136,144,224,
	6,248,128,128,240,128,128,248,
	6,248,128,128,240,128,128,128,
	6,112,136,128,184,136,136,120,
	6,136,136,136,248,136,136,136,
	4,224, 64, 64, 64, 64, 64,224,
	6,  8,  8,  8,  8,  8,136,112,
	6,136,144,160,192,160,144,136,
	6,128,128,128,128,128,128,248,
	6,136,216,168,168,136,136,136,
	6,136,136,200,168,152,136,136,
	7, 48, 72,132,132,132, 72, 48,
	6,240,136,136,240,128,128,128,
	6,112,136,136,136,168,144,104,
	6,240,136,136,240,144,136,136,
	6,112,136,128,112,  8,136,112,
	6,248, 32, 32, 32, 32, 32, 32,
	6,136,136,136,136,136,136,112,
	6,136,136,136, 80, 80, 32, 32,
	6,136,136,136,136,168,168, 80,
	6,136,136, 80, 32, 80,136,136,
	6,136,136, 80, 32, 32, 32, 32,
	6,248,  8, 16, 32, 64,128,248,
	3,192,128,128,128,128,128,192,
	5, 64, 64, 32, 32, 32, 16, 16,
	3,192, 64, 64, 64, 64, 64,192,
	4, 64,160,  0,  0,  0,  0,  0,
	6,  0,  0,  0,  0,  0,  0,248,
	3,128, 64,  0,  0,  0,  0,  0,
	5,  0,  0, 96, 16,112,144,112,	// 0x61 - a
	5,128,128,224,144,144,144,224,
	5,  0,  0,112,128,128,128,112,
	5, 16, 16,112,144,144,144,112,
	5,  0,  0, 96,144,240,128,112,
	5, 48, 64,224, 64, 64, 64, 64,
	5,  0,112,144,144,112, 16,224,
	5,128,128,224,144,144,144,144,
	2,128,  0,128,128,128,128,128,
	4, 32,  0, 32, 32, 32, 32,192,
	5,128,128,144,160,192,160,144,
	2,128,128,128,128,128,128,128,
	6,  0,  0,208,168,168,168,168,
	5,  0,  0,224,144,144,144,144,
	5,  0,  0, 96,144,144,144, 96,
	5,  0,  0,224,144,144,224,128,
	5,  0,  0,112,144,144,112, 16,
	5,  0,  0,176,192,128,128,128,
	5,  0,  0,112,128, 96, 16,224,
	4, 64, 64,224, 64, 64, 64, 32,
	5,  0,  0,144,144,144,144,112,
	5,  0,  0,144,144,144,160,192,
	6,  0,  0,136,136,168,168, 80,
	5,  0,  0,144,144, 96,144,144,
	5,  0,144,144,144,112, 16, 96,
	5,  0,  0,240, 32, 64,128,240,
	4, 32, 64, 64,128, 64, 64, 32,
	3, 64, 64, 64, 64, 64, 64, 64,
	4,128, 64, 64, 32, 64, 64,128,
	6,  0,104,176,  0,  0,  0,  0
};

static int FixJoedChar(uint8 ch)
{
	int c = ch; c -= 32;
	return (c < 0 || c > 98) ? 0 : c;
}
static int JoedCharWidth(uint8 ch)
{
	return FCEUFont[FixJoedChar(ch)*8];
}

void LuaDrawTextTransWH(const char *str, size_t l, int &x, int y, uint32 color, uint32 backcolor)
{
	int Opac = (color >> 24) & 0xFF;
	int backOpac = (backcolor >> 24) & 0xFF;
	int origX = x;

	if(!Opac && !backOpac)
		return;

	size_t len = l;
	int defaultAlpha = std::max(0, std::min(transparencyModifier, 255));
	int diffx;
	int diffy = std::max(0, std::min(7, LUA_SCREEN_HEIGHT - y));

	while(*str && len && y < LUA_SCREEN_HEIGHT)
	{
		int c = *str++;
		while (x >= LUA_SCREEN_WIDTH && c != '\n') {
			c = *str;
			if (c == '\0')
				break;
			str++;
			if (!(--len))
				break;
		}
		if(c == '\n')
		{
			x = origX;
			y += 8;
			diffy = std::max(0, std::min(7, LUA_SCREEN_HEIGHT - y));
			continue;
		}
		else if(c == '\t') // just in case
		{
			const int tabSpace = 8;
			x += (tabSpace-(((x-origX)/8)%tabSpace))*8;
			continue;
		}

		diffx = std::max(0, std::min(7, LUA_SCREEN_WIDTH - x));
		int ch  = FixJoedChar(c);
		int wid = std::min(diffx, JoedCharWidth(c));

		for(int y2 = 0; y2 < diffy; y2++)
		{
			uint8 d = FCEUFont[ch*8 + 1+y2];
			for(int x2 = 0; x2 < wid; x2++)
			{
				int c = (d >> (7-x2)) & 1;
				if(c)
					gui_drawpixel_internal(x+x2, y+y2, color);
				else
					gui_drawpixel_internal(x+x2, y+y2, backcolor);
			}
		}
		
		// halo
		if(diffy >= 7)
			for(int x2 = -1; x2 < wid; x2++)
			{
				gui_drawpixel_internal(x+x2, y-1, backcolor);
				gui_drawpixel_internal(x+x2, y+7, backcolor);
			}
		if(x == origX)
			for(int y2 = 0; y2 < diffy; y2++)
				gui_drawpixel_internal(x-1, y+y2, backcolor);

		x += wid;
		len--;
	}
}


// gui.text(int x, int y, string msg)
//
//  Displays the given text on the screen, using the same font and techniques as the
//  main HUD.
static int gui_text(lua_State *L) {

	extern int font_height;
	const char *msg;
	int x, y;
	size_t l;

	x = luaL_checkinteger(L,1);
	y = luaL_checkinteger(L,2);
	msg = luaL_checklstring(L,3,&l);

	//if (x < 0 || x >= LUA_SCREEN_WIDTH || y < 0 || y >= (LUA_SCREEN_HEIGHT - font_height))
	//	luaL_error(L,"bad coordinates");

#if 0
	uint32 colour = gui_optcolour(L,4,LUA_BUILD_PIXEL(255, 255, 255, 255));
	uint32 borderColour = gui_optcolour(L,5,LUA_BUILD_PIXEL(255, 0, 0, 0));

	gui_prepare();

	LuaDisplayString(msg, y, x, colour, borderColour);
#else
	uint32 color = gui_optcolour(L,4,LUA_BUILD_PIXEL(255, 255, 255, 255));
	uint32 bgcolor = gui_optcolour(L,5,LUA_BUILD_PIXEL(255, 27, 18, 105));

	gui_prepare();

	LuaDrawTextTransWH(msg, l, x, y, color, bgcolor);

    lua_pushinteger(L, x);
#endif
	return 1;

}


// gui.gdoverlay([int dx=0, int dy=0,] string str [, sx=0, sy=0, sw, sh] [, float alphamul=1.0])
//
//  Overlays the given image on the screen.
// example: gui.gdoverlay(gd.createFromPng("myimage.png"):gdStr())
static int gui_gdoverlay(lua_State *L) {

	int argCount = lua_gettop(L);

	int xStartDst = 0;
	int yStartDst = 0;
	int xStartSrc = 0;
	int yStartSrc = 0;

	int index = 1;
	if(lua_type(L,index) == LUA_TNUMBER)
	{
		xStartDst = lua_tointeger(L,index++);
		if(lua_type(L,index) == LUA_TNUMBER)
			yStartDst = lua_tointeger(L,index++);
	}

	luaL_checktype(L,index,LUA_TSTRING);
	const unsigned char* ptr = (const unsigned char*)lua_tostring(L,index++);

	if (ptr[0] != 255 || (ptr[1] != 254 && ptr[1] != 255))
		luaL_error(L, "bad image data");
	bool trueColor = (ptr[1] == 254);
	ptr += 2;
	int imgwidth = *ptr++ << 8;
	imgwidth |= *ptr++;
	int width = imgwidth;
	int imgheight = *ptr++ << 8;
	imgheight |= *ptr++;
	int height = imgheight;
	if ((!trueColor && *ptr) || (trueColor && !*ptr))
		luaL_error(L, "bad image data");
	ptr++;
	int pitch = imgwidth * (trueColor?4:1);

	if ((argCount - index + 1) >= 4) {
		xStartSrc = luaL_checkinteger(L,index++);
		yStartSrc = luaL_checkinteger(L,index++);
		width = luaL_checkinteger(L,index++);
		height = luaL_checkinteger(L,index++);
	}

	int alphaMul = transparencyModifier;
	if(lua_isnumber(L, index))
		alphaMul = (int)(alphaMul * lua_tonumber(L, index++));
	if(alphaMul <= 0)
		return 0;

	// since there aren't that many possible opacity levels,
	// do the opacity modification calculations beforehand instead of per pixel
	int opacMap[256];
	for(int i = 0; i < 128; i++)
	{
		int opac = 255 - ((i << 1) | (i & 1)); // gdAlphaMax = 127, not 255
		opac = (opac * alphaMul) / 255;
		if(opac < 0) opac = 0;
		if(opac > 255) opac = 255;
		opacMap[i] = opac;
	}
	for(int i = 128; i < 256; i++)
		opacMap[i] = 0; // what should we do for them, actually?

	int colorsTotal = 0;
	if (!trueColor) {
		colorsTotal = *ptr++ << 8;
		colorsTotal |= *ptr++;
	}
	int transparent = *ptr++ << 24;
	transparent |= *ptr++ << 16;
	transparent |= *ptr++ << 8;
	transparent |= *ptr++;
	struct { uint8 r, g, b, a; } pal[256];
	if (!trueColor) for (int i = 0; i < 256; i++) {
		pal[i].r = *ptr++;
		pal[i].g = *ptr++;
		pal[i].b = *ptr++;
		pal[i].a = opacMap[*ptr++];
	}

	// some of clippings
	if (xStartSrc < 0) {
		width += xStartSrc;
		xStartDst -= xStartSrc;
		xStartSrc = 0;
	}
	if (yStartSrc < 0) {
		height += yStartSrc;
		yStartDst -= yStartSrc;
		yStartSrc = 0;
	}
	if (xStartSrc+width >= imgwidth)
		width = imgwidth - xStartSrc;
	if (yStartSrc+height >= imgheight)
		height = imgheight - yStartSrc;
	if (xStartDst < 0) {
		width += xStartDst;
		if (width <= 0)
			return 0;
		xStartSrc = -xStartDst;
		xStartDst = 0;
	}
	if (yStartDst < 0) {
		height += yStartDst;
		if (height <= 0)
			return 0;
		yStartSrc = -yStartDst;
		yStartDst = 0;
	}
	if (xStartDst+width >= LUA_SCREEN_WIDTH)
		width = LUA_SCREEN_WIDTH - xStartDst;
	if (yStartDst+height >= LUA_SCREEN_HEIGHT)
		height = LUA_SCREEN_HEIGHT - yStartDst;
	if (width <= 0 || height <= 0)
		return 0; // out of screen or invalid size

	gui_prepare();

	const uint8* pix = (const uint8*)(&ptr[yStartSrc*pitch + (xStartSrc*(trueColor?4:1))]);
	int bytesToNextLine = pitch - (width * (trueColor?4:1));
	if (trueColor)
		for (int y = yStartDst; y < height+yStartDst && y < LUA_SCREEN_HEIGHT; y++, pix += bytesToNextLine) {
			for (int x = xStartDst; x < width+xStartDst && x < LUA_SCREEN_WIDTH; x++, pix += 4) {
				gui_drawpixel_fast(x, y, LUA_BUILD_PIXEL(opacMap[pix[0]], pix[1], pix[2], pix[3]));
			}
		}
	else
		for (int y = yStartDst; y < height+yStartDst && y < LUA_SCREEN_HEIGHT; y++, pix += bytesToNextLine) {
			for (int x = xStartDst; x < width+xStartDst && x < LUA_SCREEN_WIDTH; x++, pix++) {
				gui_drawpixel_fast(x, y, LUA_BUILD_PIXEL(pal[*pix].a, pal[*pix].r, pal[*pix].g, pal[*pix].b));
			}
		}

	return 0;
}


// function gui.register(function f)
//
//  This function will be called just before a graphical update.
//  More complicated, but doesn't suffer any frame delays.
//  Nil will be accepted in place of a function to erase
//  a previously registered function, and the previous function
//  (if any) is returned, or nil if none.
static int gui_register(lua_State *L) {

	// We'll do this straight up.


	// First set up the stack.
	lua_settop(L,1);

	// Verify the validity of the entry
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);

	// Get the old value
	lua_getfield(L, LUA_REGISTRYINDEX, guiCallbackTable);

	// Save the new value
	lua_pushvalue(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, guiCallbackTable);

	// The old value is on top of the stack. Return it.
	return 1;

}

// table sound.get()
static int sound_get(lua_State *L)
{
	extern ENVUNIT EnvUnits[3];
	extern int CheckFreq(uint32 cf, uint8 sr);
	extern int32 curfreq[2];
	extern uint8 PSG[0x10];
	extern int32 lengthcount[4];
	extern uint8 TriCount;
	extern const uint32 NoiseFreqTableNTSC[0x10];
	extern const uint32 NoiseFreqTablePAL[0x10];
	extern int32 DMCPeriod;
	extern uint8 DMCAddressLatch, DMCSizeLatch;
	extern uint8 DMCFormat;
	extern char DMCHaveSample;
	extern uint8 InitialRawDALatch;

	int freqReg;
	double freq;
	bool shortMode;

	lua_newtable(L);

	// rp2a03 start
	lua_newtable(L);
	// rp2a03 info setup
	double nesVolumes[3];
	for (int i = 0; i < 3; i++)
	{
		if ((EnvUnits[i].Mode & 1) != 0)
			nesVolumes[i] = EnvUnits[i].Speed;
		else
			nesVolumes[i] = EnvUnits[i].decvolume;
		nesVolumes[i] /= 15.0;
	}
	// rp2a03/square1
	lua_newtable(L);
	if((curfreq[0] < 8 || curfreq[0] > 0x7ff) ||
			(CheckFreq(curfreq[0], PSG[1]) == 0) ||
			(lengthcount[0] == 0))
		lua_pushnumber(L, 0.0);
	else
		lua_pushnumber(L, nesVolumes[0]);
	lua_setfield(L, -2, "volume");
	freq = ((PAL?PAL_CPU:NTSC_CPU)/16.0) / (curfreq[0] + 1);
	lua_pushnumber(L, freq);
	lua_setfield(L, -2, "frequency");
	lua_pushnumber(L, (log(freq / 440.0) * 12 / log(2.0)) + 69);
	lua_setfield(L, -2, "midikey");
	lua_pushinteger(L, (PSG[0] & 0xC0) >> 6);
	lua_setfield(L, -2, "duty");
	lua_newtable(L);
	lua_pushinteger(L, curfreq[0]);
	lua_setfield(L, -2, "frequency");
	lua_setfield(L, -2, "regs");
	lua_setfield(L, -2, "square1");
	// rp2a03/square2
	lua_newtable(L);
	if((curfreq[1] < 8 || curfreq[1] > 0x7ff) ||
			(CheckFreq(curfreq[1], PSG[5]) == 0) ||
			(lengthcount[1] == 0))
		lua_pushnumber(L, 0.0);
	else
		lua_pushnumber(L, nesVolumes[1]);
	lua_setfield(L, -2, "volume");
	freq = ((PAL?PAL_CPU:NTSC_CPU)/16.0) / (curfreq[1] + 1);
	lua_pushnumber(L, freq);
	lua_setfield(L, -2, "frequency");
	lua_pushnumber(L, (log(freq / 440.0) * 12 / log(2.0)) + 69);
	lua_setfield(L, -2, "midikey");
	lua_pushinteger(L, (PSG[4] & 0xC0) >> 6);
	lua_setfield(L, -2, "duty");
	lua_newtable(L);
	lua_pushinteger(L, curfreq[1]);
	lua_setfield(L, -2, "frequency");
	lua_setfield(L, -2, "regs");
	lua_setfield(L, -2, "square2");
	// rp2a03/triangle
	lua_newtable(L);
	if(lengthcount[2] == 0 || TriCount == 0)
		lua_pushnumber(L, 0.0);
	else
		lua_pushnumber(L, 1.0);
	lua_setfield(L, -2, "volume");
	freqReg = PSG[0xa] | ((PSG[0xb] & 7) << 8);
	freq = ((PAL?PAL_CPU:NTSC_CPU)/32.0) / (freqReg + 1);
	lua_pushnumber(L, freq);
	lua_setfield(L, -2, "frequency");
	lua_pushnumber(L, (log(freq / 440.0) * 12 / log(2.0)) + 69);
	lua_setfield(L, -2, "midikey");
	lua_newtable(L);
	lua_pushinteger(L, freqReg);
	lua_setfield(L, -2, "frequency");
	lua_setfield(L, -2, "regs");
	lua_setfield(L, -2, "triangle");
	// rp2a03/noise
	lua_newtable(L);
	if(lengthcount[3] == 0)
		lua_pushnumber(L, 0.0);
	else
		lua_pushnumber(L, nesVolumes[2]);
	lua_setfield(L, -2, "volume");
	freqReg = PSG[0xE] & 0xF;
	shortMode = ((PSG[0xE] & 0x80) != 0);
	lua_pushboolean(L, shortMode);
	lua_setfield(L, -2, "short");
	freq = PAL? PAL_CPU/NoiseFreqTablePAL[freqReg] : NTSC_CPU/NoiseFreqTableNTSC[freqReg] ;  // rate
	if(shortMode)
		freq /= 93.0;  // pitch
	lua_pushnumber(L, freq);
	lua_setfield(L, -2, "frequency");
	lua_pushnumber(L, (log(freq / 440.0) * 12 / log(2.0)) + 69);
	lua_setfield(L, -2, "midikey");
	lua_newtable(L);
	lua_pushinteger(L, freqReg);
	lua_setfield(L, -2, "frequency");
	lua_setfield(L, -2, "regs");
	lua_setfield(L, -2, "noise");
	// rp2a03/dpcm
	lua_newtable(L);
	if (DMCHaveSample == 0)
		lua_pushnumber(L, 0.0);
	else
		lua_pushnumber(L, 1.0);
	lua_setfield(L, -2, "volume");
	freq = (PAL?PAL_CPU:NTSC_CPU) / DMCPeriod;  // rate
	lua_pushnumber(L, freq);
	lua_setfield(L, -2, "frequency");
	lua_pushnumber(L, (log(freq / 440.0) * 12 / log(2.0)) + 69);
	lua_setfield(L, -2, "midikey");
	lua_pushinteger(L, 0xC000 + (DMCAddressLatch << 6));
	lua_setfield(L, -2, "dmcaddress");
	lua_pushinteger(L, (DMCSizeLatch << 4) + 1);
	lua_setfield(L, -2, "dmcsize");
	lua_pushboolean(L, DMCFormat & 0x40);
	lua_setfield(L, -2, "dmcloop");
	lua_pushinteger(L, InitialRawDALatch);
	lua_setfield(L, -2, "dmcseed");
	lua_newtable(L);
	lua_pushinteger(L, DMCFormat & 0xF);
	lua_setfield(L, -2, "frequency");
	lua_setfield(L, -2, "regs");
	lua_setfield(L, -2, "dpcm");
	// rp2a03 end
	lua_setfield(L, -2, "rp2a03");

	return 1;
}

// Debugger functions library

// debugger.hitbreakpoint()
static int debugger_hitbreakpoint(lua_State *L)
{
	break_asap = true;
	return 0;
}

// debugger.getcyclescount()
static int debugger_getcyclescount(lua_State *L)
{
	int64 counter_value = timestampbase + (uint64)timestamp - total_cycles_base;
	if (counter_value < 0)	// sanity check
	{
		ResetDebugStatisticsCounters();
		counter_value = 0;
	}
	lua_pushinteger(L, counter_value);
	return 1;
}

// debugger.getinstructionscount()
static int debugger_getinstructionscount(lua_State *L)
{
	lua_pushinteger(L, total_instructions);
	return 1;
}

// debugger.resetcyclescount()
static int debugger_resetcyclescount(lua_State *L)
{
	ResetCyclesCounter();
	return 0;
}

// debugger.resetinstructionscount()
static int debugger_resetinstructionscount(lua_State *L)
{
	ResetInstructionsCounter();
	return 0;
}

// TAS Editor functions library

// bool taseditor.registerauto()
static int taseditor_registerauto(lua_State *L)
{
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);
	lua_settop(L,1);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_TASEDITOR_AUTO]);
	lua_insert(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_TASEDITOR_AUTO]);
	//StopScriptIfFinished(luaStateToUIDMap[L]);
	return 1;
}

// bool taseditor.registermanual(string caption)
static int taseditor_registermanual(lua_State *L)
{
	if (!lua_isnil(L,1))
		luaL_checktype(L, 1, LUA_TFUNCTION);

	const char* caption = NULL;
	if (!lua_isnil(L, 2))
		caption = lua_tostring(L, 2);

	lua_settop(L,1);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_TASEDITOR_MANUAL]);
	lua_insert(L,1);
	lua_setfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_TASEDITOR_MANUAL]);
#ifdef WIN32
	taseditor_lua.enableRunFunction(caption);
#endif
	return 1;
}

// bool taseditor.engaged()
static int taseditor_engaged(lua_State *L)
{
#ifdef WIN32
	lua_pushboolean(L, taseditor_lua.engaged());
#else
	lua_pushboolean(L, false);
#endif
	return 1;
}

// bool taseditor.markedframe(int frame)
static int taseditor_markedframe(lua_State *L)
{
#ifdef WIN32
	lua_pushboolean(L, taseditor_lua.markedframe(luaL_checkinteger(L, 1)));
#else
	lua_pushboolean(L, false);
#endif
	return 1;
}

// int taseditor.getmarker(int frame)
static int taseditor_getmarker(lua_State *L)
{
#ifdef WIN32
	lua_pushinteger(L, taseditor_lua.getmarker(luaL_checkinteger(L, 1)));
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// int taseditor.setmarker(int frame)
static int taseditor_setmarker(lua_State *L)
{
#ifdef WIN32
	lua_pushinteger(L, taseditor_lua.setmarker(luaL_checkinteger(L, 1)));
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// taseditor.removemarker(int frame)
static int taseditor_removemarker(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.removemarker(luaL_checkinteger(L, 1));
#endif
	return 0;
}

// string taseditor.getnote(int index)
static int taseditor_getnote(lua_State *L)
{
#ifdef WIN32
	lua_pushstring(L, taseditor_lua.getnote(luaL_checkinteger(L, 1)));
#else
	lua_pushnil(L);
#endif
	return 1;
}

// taseditor.setnote(int index, string newtext)
static int taseditor_setnote(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.setnote(luaL_checkinteger(L, 1), luaL_checkstring(L, 2));
#endif
	return 0;
}

// int taseditor.getcurrentbranch()
static int taseditor_getcurrentbranch(lua_State *L)
{
#ifdef WIN32
	lua_pushinteger(L, taseditor_lua.getcurrentbranch());
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// string taseditor.getrecordermode()
static int taseditor_getrecordermode(lua_State *L)
{
#ifdef WIN32
	lua_pushstring(L, taseditor_lua.getrecordermode());
#else
	lua_pushnil(L);
#endif
	return 1;
}

// int taseditor.getsuperimpose()
static int taseditor_getsuperimpose(lua_State *L)
{
#ifdef WIN32
	lua_pushinteger(L, taseditor_lua.getsuperimpose());
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// int taseditor.getlostplayback()
static int taseditor_getlostplayback(lua_State *L)
{
#ifdef WIN32
	lua_pushinteger(L, taseditor_lua.getlostplayback());
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// int taseditor.getplaybacktarget()
static int taseditor_getplaybacktarget(lua_State *L)
{
#ifdef WIN32
	lua_pushinteger(L, taseditor_lua.getplaybacktarget());
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// taseditor.setplayback(int frame)
static int taseditor_setplayback(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.setplayback(luaL_checkinteger(L, 1));
#endif
	return 0;
}

// taseditor.stopseeking()
static int taseditor_stopseeking(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.stopseeking();
#endif
	return 0;
}

// table taseditor.getselection()
static int taseditor_getselection(lua_State *L)
{
#ifdef WIN32
	// create temp vector and provide its reference to TAS Editor for filling the vector with data
	std::vector<int> cur_set;
	taseditor_lua.getselection(cur_set);
	int size = cur_set.size();
	if (size)
	{
		lua_createtable(L, size, 0);
		for (int i = 0; i < size; ++i)
		{
			lua_pushinteger(L, cur_set[i]);
			lua_rawseti(L, -2, i + 1);
		}
	} else
	{
		lua_pushnil(L);
	}
#else
	lua_pushnil(L);
#endif
	return 1;
}

// taseditor.setselection(table new_set)
static int taseditor_setselection(lua_State *L)
{
#ifdef WIN32
	std::vector<int> cur_set;
	// retrieve new_set data from table to vector
	if (!lua_isnil(L, 1))
	{
		luaL_checktype(L, 1, LUA_TTABLE);
		int max_index = luaL_getn(L, 1);
		int i = 1;
		while (i <= max_index)
		{
			lua_rawgeti(L, 1, i);
			cur_set.push_back(lua_tonumber(L, -1));
			lua_pop(L, 1);
			i++;
		}
	}
	// and provide its reference to TAS Editor for changing selection
	taseditor_lua.setselection(cur_set);
#endif
	return 0;
}

// int taseditor.getinput(int frame, int joypad)
static int taseditor_getinput(lua_State *L)
{
#ifdef WIN32
	lua_pushinteger(L, taseditor_lua.getinput(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2)));
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// taseditor.submitinputchange(int frame, int joypad, int input)
static int taseditor_submitinputchange(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.submitinputchange(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2), luaL_checkinteger(L, 3));
#endif
	return 0;
}

// taseditor.submitinsertframes(int frame, int joypad, int input)
static int taseditor_submitinsertframes(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.submitinsertframes(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2));
#endif
	return 0;
}

// taseditor.submitdeleteframes(int frame, int joypad, int input)
static int taseditor_submitdeleteframes(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.submitdeleteframes(luaL_checkinteger(L, 1), luaL_checkinteger(L, 2));
#endif
	return 0;
}

// int taseditor.applyinputchanges([string name])
static int taseditor_applyinputchanges(lua_State *L)
{
#ifdef WIN32
	if (lua_isnil(L, 1))
	{
		lua_pushinteger(L, taseditor_lua.applyinputchanges(""));
	} else
	{
		const char* name = lua_tostring(L, 1);
		if (name)
			lua_pushinteger(L, taseditor_lua.applyinputchanges(name));
		else
			lua_pushinteger(L, taseditor_lua.applyinputchanges(""));
	}
#else
	lua_pushinteger(L, -1);
#endif
	return 1;
}

// taseditor.clearinputchanges()
static int taseditor_clearinputchanges(lua_State *L)
{
#ifdef WIN32
	taseditor_lua.clearinputchanges();
#endif
	return 0;
}


static int doPopup(lua_State *L, const char* deftype, const char* deficon) {
	const char *str = luaL_checkstring(L, 1);
	const char* type = lua_type(L,2) == LUA_TSTRING ? lua_tostring(L,2) : deftype;
	const char* icon = lua_type(L,3) == LUA_TSTRING ? lua_tostring(L,3) : deficon;

	int itype = -1, iters = 0;
	while(itype == -1 && iters++ < 2)
	{
		if(!stricmp(type, "ok")) itype = 0;
		else if(!stricmp(type, "yesno")) itype = 1;
		else if(!stricmp(type, "yesnocancel")) itype = 2;
		else if(!stricmp(type, "okcancel")) itype = 3;
		else if(!stricmp(type, "abortretryignore")) itype = 4;
		else type = deftype;
	}
	assert(itype >= 0 && itype <= 4);
	if(!(itype >= 0 && itype <= 4)) itype = 0;

	int iicon = -1; iters = 0;
	while(iicon == -1 && iters++ < 2)
	{
		if(!stricmp(icon, "message") || !stricmp(icon, "notice")) iicon = 0;
		else if(!stricmp(icon, "question")) iicon = 1;
		else if(!stricmp(icon, "warning")) iicon = 2;
		else if(!stricmp(icon, "error")) iicon = 3;
		else icon = deficon;
	}
	assert(iicon >= 0 && iicon <= 3);
	if(!(iicon >= 0 && iicon <= 3)) iicon = 0;

	static const char * const titles [] = {"Notice", "Question", "Warning", "Error"};
	const char* answer = "ok";

#ifdef WIN32
	static const int etypes [] = {MB_OK, MB_YESNO, MB_YESNOCANCEL, MB_OKCANCEL, MB_ABORTRETRYIGNORE};
	static const int eicons [] = {MB_ICONINFORMATION, MB_ICONQUESTION, MB_ICONWARNING, MB_ICONERROR};
	//StopSound(); //mbg merge 7/27/08
	int ianswer = MessageBox(hAppWnd, str, titles[iicon], etypes[itype] | eicons[iicon]);
	switch(ianswer)
	{
		case IDOK: answer = "ok"; break;
		case IDCANCEL: answer = "cancel"; break;
		case IDABORT: answer = "abort"; break;
		case IDRETRY: answer = "retry"; break;
		case IDIGNORE: answer = "ignore"; break;
		case IDYES: answer = "yes"; break;
		case IDNO: answer = "no"; break;
	}

	lua_pushstring(L, answer);
	return 1;
#else

	char *t;
#ifdef __linux

	int pid; // appease compiler

	// Before doing any work, verify the correctness of the parameters.
	if (strcmp(type, "ok") == 0)
		t = "OK:100";
	else if (strcmp(type, "yesno") == 0)
		t = "Yes:100,No:101";
	else if (strcmp(type, "yesnocancel") == 0)
		t = "Yes:100,No:101,Cancel:102";
	else
		return luaL_error(L, "invalid popup type \"%s\"", type);

	// Can we find a copy of xmessage? Search the path.

	char *path = strdup(getenv("PATH"));

	char *current = path;

	char *colon;

	int found = 0;

	while (current) {
		colon = strchr(current, ':');

		// Clip off the colon.
		*colon++ = 0;

		int len = strlen(current);
		char *filename = (char*)FCEU_dmalloc(len + 12); // always give excess
		snprintf(filename, len+12, "%s/xmessage", current);

		if (access(filename, X_OK) == 0) {
			free(filename);
			found = 1;
			break;
		}

		// Failed, move on.
		current = colon;
		free(filename);

	}

	free(path);

	// We've found it?
	if (!found)
		goto use_console;

	pid = fork();
	if (pid == 0) {// I'm the virgin sacrifice

		// I'm gonna be dead in a matter of microseconds anyways, so wasted memory doesn't matter to me.
		// Go ahead and abuse strdup.
		char * parameters[] = {"xmessage", "-buttons", t, strdup(str), NULL};

		execvp("xmessage", parameters);

		// Aw shitty
		perror("exec xmessage");
		exit(1);
	}
	else if (pid < 0) // something went wrong!!! Oh hell... use the console
		goto use_console;
	else {
		// We're the parent. Watch for the child.
		int r;
		int res = waitpid(pid, &r, 0);
		if (res < 0) // wtf?
			goto use_console;

		// The return value gets copmlicated...
		if (!WIFEXITED(r)) {
			luaL_error(L, "don't screw with my xmessage process!");
		}
		r = WEXITSTATUS(r);

		// We assume it's worked.
		if (r == 0)
		{
			return 0; // no parameters for an OK
		}
		if (r == 100) {
			lua_pushstring(L, "yes");
			return 1;
		}
		if (r == 101) {
			lua_pushstring(L, "no");
			return 1;
		}
		if (r == 102) {
			lua_pushstring(L, "cancel");
			return 1;
		}

		// Wtf?
		return luaL_error(L, "popup failed due to unknown results involving xmessage (%d)", r);
	}

use_console:
#endif

	// All else has failed

	if (strcmp(type, "ok") == 0)
		t = "";
	else if (strcmp(type, "yesno") == 0)
		t = "yn";
	else if (strcmp(type, "yesnocancel") == 0)
		t = "ync";
	else
		return luaL_error(L, "invalid popup type \"%s\"", type);

	fprintf(stderr, "Lua Message: %s\n", str);

	while (true) {
		char buffer[64];

		// We don't want parameters
		if (!t[0]) {
			fprintf(stderr, "[Press Enter]");
			fgets(buffer, sizeof(buffer), stdin);
			// We're done
			return 0;

		}
		fprintf(stderr, "(%s): ", t);
		fgets(buffer, sizeof(buffer), stdin);

		// Check if the option is in the list
		if (strchr(t, tolower(buffer[0]))) {
			switch (tolower(buffer[0])) {
			case 'y':
				lua_pushstring(L, "yes");
				return 1;
			case 'n':
				lua_pushstring(L, "no");
				return 1;
			case 'c':
				lua_pushstring(L, "cancel");
				return 1;
			default:
				luaL_error(L, "internal logic error in console based prompts for gui.popup");

			}
		}

		// We fell through, so we assume the user answered wrong and prompt again.

	}

	// Nothing here, since the only way out is in the loop.
#endif

}

static int doOpenFilePopup(lua_State *L, bool saveFile) {
#ifdef WIN32
	char filename[PATH_MAX];
	OPENFILENAME ofn;
	ZeroMemory(&ofn, sizeof(OPENFILENAME));
	ofn.lStructSize = sizeof(OPENFILENAME);
	ofn.hwndOwner = hAppWnd;
	ofn.lpstrFilter = TEXT("All files (*.*)\0*.*\0\0");
	ofn.nFilterIndex = 0;
	filename[0] = TEXT('\0');
	ofn.lpstrFile = filename;
	ofn.nMaxFile = PATH_MAX;
	ofn.Flags = OFN_NOCHANGEDIR | (saveFile ? OFN_OVERWRITEPROMPT : OFN_FILEMUSTEXIST);
	BOOL bResult = saveFile ? GetSaveFileName(&ofn) : GetOpenFileName(&ofn);
	lua_newtable(L);
	if (bResult)
	{
		lua_pushstring(L, filename);
		lua_rawseti(L, -2, 1);
	}
#else
	// TODO: more sophisticated interface
	char filename[PATH_MAX];
	printf("Enter %s filename: ", saveFile ? "save" : "open");
	fgets(filename, PATH_MAX, stdin);
	lua_newtable(L);
	lua_pushstring(L, filename);
	lua_rawseti(L, -2, 1);
#endif
	return 1;
}

// string gui.popup(string message, string type = "ok", string icon = "message")
// string input.popup(string message, string type = "yesno", string icon = "question")
static int gui_popup(lua_State *L)
{
	return doPopup(L, "ok", "message");
}
static int input_popup(lua_State *L)
{
	return doPopup(L, "yesno", "question");
}

static int input_openfilepopup(lua_State *L)
{
	return doOpenFilePopup(L, false);
}
static int input_savefilepopup(lua_State *L)
{
	return doOpenFilePopup(L, true);
}

// the following bit operations are ported from LuaBitOp 1.0.1,
// because it can handle the sign bit (bit 31) correctly.

/*
** Lua BitOp -- a bit operations library for Lua 5.1.
** http://bitop.luajit.org/
**
** Copyright (C) 2008-2009 Mike Pall. All rights reserved.
**
** Permission is hereby granted, free of charge, to any person obtaining
** a copy of this software and associated documentation files (the
** "Software"), to deal in the Software without restriction, including
** without limitation the rights to use, copy, modify, merge, publish,
** distribute, sublicense, and/or sell copies of the Software, and to
** permit persons to whom the Software is furnished to do so, subject to
** the following conditions:
**
** The above copyright notice and this permission notice shall be
** included in all copies or substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
** EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
** MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
** IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
** CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
** TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
** SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
**
** [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
*/

#ifdef _MSC_VER
/* MSVC is stuck in the last century and doesn't have C99's stdint.h. */
typedef __int32 int32_t;
typedef unsigned __int32 uint32_t;
typedef unsigned __int64 uint64_t;
#else
#include <stdint.h>
#endif

typedef int32_t SBits;
typedef uint32_t UBits;

typedef union {
  lua_Number n;
#ifdef LUA_NUMBER_DOUBLE
  uint64_t b;
#else
  UBits b;
#endif
} BitNum;

/* Convert argument to bit type. */
static UBits barg(lua_State *L, int idx)
{
  BitNum bn;
  UBits b;
  bn.n = lua_tonumber(L, idx);
#if defined(LUA_NUMBER_DOUBLE)
  bn.n += 6755399441055744.0;  /* 2^52+2^51 */
#ifdef SWAPPED_DOUBLE
  b = (UBits)(bn.b >> 32);
#else
  b = (UBits)bn.b;
#endif
#elif defined(LUA_NUMBER_INT) || defined(LUA_NUMBER_LONG) || \
      defined(LUA_NUMBER_LONGLONG) || defined(LUA_NUMBER_LONG_LONG) || \
      defined(LUA_NUMBER_LLONG)
  if (sizeof(UBits) == sizeof(lua_Number))
    b = bn.b;
  else
    b = (UBits)(SBits)bn.n;
#elif defined(LUA_NUMBER_FLOAT)
#error "A 'float' lua_Number type is incompatible with this library"
#else
#error "Unknown number type, check LUA_NUMBER_* in luaconf.h"
#endif
  if (b == 0 && !lua_isnumber(L, idx))
    luaL_typerror(L, idx, "number");
  return b;
}

/* Return bit type. */
#define BRET(b)  lua_pushnumber(L, (lua_Number)(SBits)(b)); return 1;

static int bit_tobit(lua_State *L) { BRET(barg(L, 1)) }
static int bit_bnot(lua_State *L) { BRET(~barg(L, 1)) }

#define BIT_OP(func, opr) \
  static int func(lua_State *L) { int i; UBits b = barg(L, 1); \
    for (i = lua_gettop(L); i > 1; i--) b opr barg(L, i); BRET(b) }
BIT_OP(bit_band, &=)
BIT_OP(bit_bor, |=)
BIT_OP(bit_bxor, ^=)

#define bshl(b, n)  (b << n)
#define bshr(b, n)  (b >> n)
#define bsar(b, n)  ((SBits)b >> n)
#define brol(b, n)  ((b << n) | (b >> (32-n)))
#define bror(b, n)  ((b << (32-n)) | (b >> n))
#define BIT_SH(func, fn) \
  static int func(lua_State *L) { \
    UBits b = barg(L, 1); UBits n = barg(L, 2) & 31; BRET(fn(b, n)) }
BIT_SH(bit_lshift, bshl)
BIT_SH(bit_rshift, bshr)
BIT_SH(bit_arshift, bsar)
BIT_SH(bit_rol, brol)
BIT_SH(bit_ror, bror)

static int bit_bswap(lua_State *L)
{
  UBits b = barg(L, 1);
  b = (b >> 24) | ((b >> 8) & 0xff00) | ((b & 0xff00) << 8) | (b << 24);
  BRET(b)
}

static int bit_tohex(lua_State *L)
{
  UBits b = barg(L, 1);
  SBits n = lua_isnone(L, 2) ? 8 : (SBits)barg(L, 2);
  const char *hexdigits = "0123456789abcdef";
  char buf[8];
  int i;
  if (n < 0) { n = -n; hexdigits = "0123456789ABCDEF"; }
  if (n > 8) n = 8;
  for (i = (int)n; --i >= 0; ) { buf[i] = hexdigits[b & 15]; b >>= 4; }
  lua_pushlstring(L, buf, (size_t)n);
  return 1;
}

static const struct luaL_Reg bit_funcs[] = {
  { "tobit",	bit_tobit },
  { "bnot",	bit_bnot },
  { "band",	bit_band },
  { "bor",	bit_bor },
  { "bxor",	bit_bxor },
  { "lshift",	bit_lshift },
  { "rshift",	bit_rshift },
  { "arshift",	bit_arshift },
  { "rol",	bit_rol },
  { "ror",	bit_ror },
  { "bswap",	bit_bswap },
  { "tohex",	bit_tohex },
  { NULL, NULL }
};

/* Signed right-shifts are implementation-defined per C89/C99.
** But the de facto standard are arithmetic right-shifts on two's
** complement CPUs. This behaviour is required here, so test for it.
*/
#define BAD_SAR		(bsar(-8, 2) != (SBits)-2)

bool luabitop_validate(lua_State *L) // originally named as luaopen_bit
{
  UBits b;
  lua_pushnumber(L, (lua_Number)1437217655L);
  b = barg(L, -1);
  if (b != (UBits)1437217655L || BAD_SAR) {  /* Perform a simple self-test. */
    const char *msg = "compiled with incompatible luaconf.h";
#ifdef LUA_NUMBER_DOUBLE
#ifdef WIN32
    if (b == (UBits)1610612736L)
      msg = "use D3DCREATE_FPU_PRESERVE with DirectX";
#endif
    if (b == (UBits)1127743488L)
      msg = "not compiled with SWAPPED_DOUBLE";
#endif
    if (BAD_SAR)
      msg = "arithmetic right-shift broken";
    luaL_error(L, "bit library self-test failed (%s)", msg);
    return false;
  }
  return true;
}

// LuaBitOp ends here

static int bit_bshift_emulua(lua_State *L)
{
	int shift = luaL_checkinteger(L,2);
	if (shift < 0) {
		lua_pushinteger(L, -shift);
		lua_replace(L, 2);
		return bit_lshift(L);
	}
	else
		return bit_rshift(L);
}

static int bitbit(lua_State *L)
{
	int rv = 0;
	int numArgs = lua_gettop(L);
	for(int i = 1; i <= numArgs; i++) {
		int where = luaL_checkinteger(L,i);
		if (where >= 0 && where < 32)
			rv |= (1 << where);
	}
	lua_settop(L,0);
	BRET(rv);
}

// The function called periodically to ensure Lua doesn't run amok.
static void FCEU_LuaHookFunction(lua_State *L, lua_Debug *dbg) {

	if (numTries-- == 0) {

		int kill = 0;

#ifdef WIN32
		// Uh oh
                //StopSound(); //mbg merge 7/23/08
		int ret = MessageBox(hAppWnd, "The Lua script running has been running a long time. It may have gone crazy. Kill it?\n\n(No = don't check anymore either)", "Lua Script Gone Nuts?", MB_YESNO);

		if (ret == IDYES) {
			kill = 1;
		}

#else
		fprintf(stderr, "The Lua script running has been running a long time.\nIt may have gone crazy. Kill it? (I won't ask again if you say No)\n");
		char buffer[64];
		while (TRUE) {
			fprintf(stderr, "(y/n): ");
			fgets(buffer, sizeof(buffer), stdin);
			if (buffer[0] == 'y' || buffer[0] == 'Y') {
				kill = 1;
				break;
			}

			if (buffer[0] == 'n' || buffer[0] == 'N')
				break;
		}
#endif

		if (kill) {
			luaL_error(L, "Killed by user request.");
			FCEU_LuaOnStop();
		}

		// else, kill the debug hook.
		lua_sethook(L, NULL, 0, 0);
	}


}

static void emu_exec_count_hook(lua_State *L, lua_Debug *dbg) {
	luaL_error(L, "exec_count timeout");
}

static int emu_exec_count(lua_State *L) {
	int count = (int)luaL_checkinteger(L,1);
	lua_pushvalue(L, 2);
	lua_sethook(L, emu_exec_count_hook, LUA_MASKCOUNT, count);
	int ret = lua_pcall(L, 0, 0, 0);
	lua_sethook(L, NULL, 0, 0);
	lua_settop(L,0);
	lua_pushinteger(L, ret);
	return 1;
}

#ifdef WIN32
static HANDLE readyEvent, goEvent;
DWORD WINAPI emu_exec_time_proc(LPVOID lpParameter)
{
	SetEvent(readyEvent);
	WaitForSingleObject(goEvent,INFINITE);
	lua_State *L = (lua_State *)lpParameter;
	lua_pushvalue(L, 2);
	int ret = lua_pcall(L, 0, 0, 0);
	lua_settop(L,0);
	lua_pushinteger(L, ret);
	SetEvent(readyEvent);
	return 0;
}

static void emu_exec_time_hook(lua_State *L, lua_Debug *dbg) {
	luaL_error(L, "exec_time timeout");
}

static int emu_exec_time(lua_State *L)
{
	int count = (int)luaL_checkinteger(L,1);

	readyEvent = CreateEvent(0,true,false,0);
	goEvent = CreateEvent(0,true,false,0);
	DWORD threadid;
	HANDLE thread = CreateThread(0,0,emu_exec_time_proc,(LPVOID)L,0,&threadid);
	SetThreadAffinityMask(thread,1);
	//wait for the lua thread to start
	WaitForSingleObject(readyEvent,INFINITE);
	ResetEvent(readyEvent);
	//tell the lua thread to proceed
	SetEvent(goEvent);
	//wait for the lua thread to finish, but no more than the specified amount of time
	WaitForSingleObject(readyEvent,count);

	//kill lua (if it hasnt already been killed)
	lua_sethook(L, emu_exec_time_hook, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);

	//keep on waiting for the lua thread to come back
	WaitForSingleObject(readyEvent,count);

	//clear the lua thread-killer
	lua_sethook(L, NULL, 0, 0);

	CloseHandle(readyEvent);
	CloseHandle(goEvent);
	CloseHandle(thread);

	return 1;
}

#else
static int emu_exec_time(lua_State *L) { return 0; }
#endif

static const struct luaL_reg emulib [] = {

	{"poweron", emu_poweron},
	{"softreset", emu_softreset},
	{"speedmode", emu_speedmode},
	{"frameadvance", emu_frameadvance},
	{"paused", emu_paused},
	{"pause", emu_pause},
	{"unpause", emu_unpause},
	{"exec_count", emu_exec_count},
	{"exec_time", emu_exec_time},
	{"setrenderplanes", emu_setrenderplanes},
	{"message", emu_message},
	{"framecount", emu_framecount},
	{"lagcount", emu_lagcount},
	{"lagged", emu_lagged},
	{"setlagflag", emu_setlagflag},
	{"emulating", emu_emulating},
	{"registerbefore", emu_registerbefore},
	{"registerafter", emu_registerafter},
	{"registerexit", emu_registerexit},
	{"addgamegenie", emu_addgamegenie},
	{"delgamegenie", emu_delgamegenie},
	{"getscreenpixel", emu_getscreenpixel},
	{"readonly", movie_getreadonly},
	{"setreadonly", movie_setreadonly},
    {"getdir", emu_getdir},
    {"loadrom", emu_loadrom},
	{"print", print}, // sure, why not
	{NULL,NULL}
};

static const struct luaL_reg romlib [] = {
	{"readbyte", rom_readbyte},
	{"readbytesigned", rom_readbytesigned},
	// alternate naming scheme for unsigned
	{"readbyteunsigned", rom_readbyte},
	{"writebyte", rom_writebyte},
	{"gethash", rom_gethash},
	{NULL,NULL}
};


static const struct luaL_reg memorylib [] = {

	{"readbyte", memory_readbyte},
	{"readbyterange", memory_readbyterange},
	{"readbytesigned", memory_readbytesigned},	
	{"readbyteunsigned", memory_readbyte},	// alternate naming scheme for unsigned
	{"readword", memory_readword},
	{"readwordsigned", memory_readwordsigned},
	{"readwordunsigned", memory_readword},	// alternate naming scheme for unsigned
	{"writebyte", memory_writebyte},
	{"getregister", memory_getregister},
	{"setregister", memory_setregister},

	// memory hooks
	{"registerwrite", memory_registerwrite},
	//{"registerread", memory_registerread}, TODO
	{"registerexec", memory_registerexec},
	// alternate names
	{"register", memory_registerwrite},
	{"registerrun", memory_registerexec},
	{"registerexecute", memory_registerexec},

	{NULL,NULL}
};

static const struct luaL_reg joypadlib[] = {
	{"get", joypad_get},
	{"getdown", joypad_getdown},
	{"getup", joypad_getup},
	{"getimmediate", joypad_getimmediate},
	{"set", joypad_set},
	// alternative names
	{"read", joypad_get},
	{"write", joypad_set},
	{"readdown", joypad_getdown},
	{"readup", joypad_getup},
	{"readimmediate", joypad_getimmediate},
	{NULL,NULL}
};

static const struct luaL_reg zapperlib[] = {
	{"read", zapper_read},
	{NULL,NULL}
};

static const struct luaL_reg inputlib[] = {
	{"get", input_get},
	{"popup", input_popup},
	{"openfilepopup", input_openfilepopup},
	{"savefilepopup", input_savefilepopup},
	// alternative names
	{"read", input_get},
	{NULL,NULL}
};

static const struct luaL_reg savestatelib[] = {
	{"create", savestate_create},
	{"object", savestate_object},
	{"save", savestate_save},
	{"persist", savestate_persist},
	{"load", savestate_load},

	{"registersave", savestate_registersave},
	{"registerload", savestate_registerload},
	{"loadscriptdata", savestate_loadscriptdata},

	{NULL,NULL}
};

static const struct luaL_reg movielib[] = {

	{"framecount", emu_framecount}, // for those familiar with other emulators that have movie.framecount() instead of emulatorname.framecount()
	{"mode", movie_mode},
	{"rerecordcounting", movie_rerecordcounting},
	{"stop", movie_stop},
	{"active", movie_isactive},
	{"recording", movie_isrecording},
	{"playing", movie_isplaying},
	{"length", movie_getlength},
	{"rerecordcount", movie_rerecordcount},
	{"name", movie_getname},
	{"filename", movie_getfilename},
	{"readonly", movie_getreadonly},
	{"setreadonly", movie_setreadonly},
	{"replay", movie_replay},
//	{"record", movie_record},
//	{"play", movie_playback},

	// alternative names
	{"close", movie_stop},
	{"getname", movie_getname},
//	{"playback", movie_playback},
	{"playbeginning", movie_replay},
	{"getreadonly", movie_getreadonly},
	{"ispoweron", movie_ispoweron},					//If movie recorded from power-on
	{"isfromsavestate", movie_isfromsavestate},		//If movie is recorded from savestate
	{NULL,NULL}

};


static const struct luaL_reg guilib[] = {

	{"pixel", gui_pixel},
	{"getpixel", gui_getpixel},
	{"line", gui_line},
	{"box", gui_box},
	{"text", gui_text},

	{"parsecolor", gui_parsecolor},

	{"savescreenshot",   gui_savescreenshot},
	{"savescreenshotas", gui_savescreenshotas},
	{"gdscreenshot", gui_gdscreenshot},
	{"gdoverlay", gui_gdoverlay},
	{"opacity", gui_setopacity},
	{"transparency", gui_transparency},

	{"register", gui_register},

	{"popup", gui_popup},
	// alternative names
	{"drawtext", gui_text},
	{"drawbox", gui_box},
	{"drawline", gui_line},
	{"drawpixel", gui_pixel},
	{"setpixel", gui_pixel},
	{"writepixel", gui_pixel},
	{"rect", gui_box},
	{"drawrect", gui_box},
	{"drawimage", gui_gdoverlay},
	{"image", gui_gdoverlay},
	{NULL,NULL}
};

static const struct luaL_reg soundlib[] = {

	{"get", sound_get},
	{NULL,NULL}
};

static const struct luaL_reg debuggerlib[] = {

	{"hitbreakpoint", debugger_hitbreakpoint},
	{"getcyclescount", debugger_getcyclescount},
	{"getinstructionscount", debugger_getinstructionscount},
	{"resetcyclescount", debugger_resetcyclescount},
	{"resetinstructionscount", debugger_resetinstructionscount},
	{NULL,NULL}
};

static const struct luaL_reg taseditorlib[] = {

	{"registerauto", taseditor_registerauto},
	{"registermanual", taseditor_registermanual},
	{"engaged", taseditor_engaged},
	{"markedframe", taseditor_markedframe},
	{"getmarker", taseditor_getmarker},
	{"setmarker", taseditor_setmarker},
	{"removemarker", taseditor_removemarker},
	{"getnote", taseditor_getnote},
	{"setnote", taseditor_setnote},
	{"getcurrentbranch", taseditor_getcurrentbranch},
	{"getrecordermode", taseditor_getrecordermode},
	{"getsuperimpose", taseditor_getsuperimpose},
	{"getlostplayback", taseditor_getlostplayback},
	{"getplaybacktarget", taseditor_getplaybacktarget},
	{"setplayback", taseditor_setplayback},
	{"stopseeking", taseditor_stopseeking},
	{"getselection", taseditor_getselection},
	{"setselection", taseditor_setselection},
	{"getinput", taseditor_getinput},
	{"submitinputchange", taseditor_submitinputchange},
	{"submitinsertframes", taseditor_submitinsertframes},
	{"submitdeleteframes", taseditor_submitdeleteframes},
	{"applyinputchanges", taseditor_applyinputchanges},
	{"clearinputchanges", taseditor_clearinputchanges},
	{NULL,NULL}
};

void CallExitFunction() {
	if (!L)
		return;

	lua_settop(L, 0);
	lua_getfield(L, LUA_REGISTRYINDEX, luaCallIDStrings[LUACALL_BEFOREEXIT]);

	int errorcode = 0;
	if (lua_isfunction(L, -1))
	{
		//chdir(luaCWD);
		errorcode = lua_pcall(L, 0, 0, 0);
		//_getcwd(luaCWD, _MAX_PATH);
	}

	if (errorcode)
		HandleCallbackError(L);
}

void FCEU_LuaFrameBoundary()
{
	//printf("Lua Frame\n");

	// HA!
	if (!L || !luaRunning)
		return;

	// Our function needs calling
	lua_settop(L,0);
	lua_getfield(L, LUA_REGISTRYINDEX, frameAdvanceThread);
	lua_State *thread = lua_tothread(L,1);

	// Lua calling C must know that we're busy inside a frame boundary
	frameBoundary = TRUE;
	frameAdvanceWaiting = FALSE;

	numTries = 1000;
	int result = lua_resume(thread, 0);

	if (result == LUA_YIELD) {
		// Okay, we're fine with that.
	} else if (result != 0) {
		// Done execution by bad causes
		FCEU_LuaOnStop();
		lua_pushnil(L);
		lua_setfield(L, LUA_REGISTRYINDEX, frameAdvanceThread);

		// Error?
#ifdef WIN32
                //StopSound();//StopSound(); //mbg merge 7/23/08
		MessageBox( hAppWnd, lua_tostring(thread,-1), "Lua run error", MB_OK | MB_ICONSTOP);
#else
		fprintf(stderr, "Lua thread bombed out: %s\n", lua_tostring(thread,-1));
#endif

	} else {
		FCEU_LuaOnStop();
		//FCEU_DispMessage("Script died of natural causes.\n",0);
		// weird sequence of functions calls the above message each time the script starts or stops,
		// then this message is overrided by "emu speed" within the same frame, which hides this bug
		// uncomment onse solution is found
	}

	// Past here, the nes actually runs, so any Lua code is called mid-frame. We must
	// not do anything too stupid, so let ourselves know.
	frameBoundary = FALSE;

	if (!frameAdvanceWaiting) {
		FCEU_LuaOnStop();
	}

}

/**
 * Loads and runs the given Lua script.
 * The emulator MUST be paused for this function to be
 * called. Otherwise, all frame boundary assumptions go out the window.
 *
 * Returns true on success, false on failure.
 */
int FCEU_LoadLuaCode(const char *filename, const char *arg) {
	if (!DemandLua())
	{
		return 0;
	}

	if (filename != luaScriptName)
	{
		if (luaScriptName) free(luaScriptName);
		luaScriptName = strdup(filename);
	}

#if defined(WIN32) || defined(__linux)
	std::string getfilepath = filename;

	getfilepath = getfilepath.substr(0,getfilepath.find_last_of("/\\") + 1);

	SetCurrentDir(getfilepath.c_str());
#endif

	//stop any lua we might already have had running
	FCEU_LuaStop();

	//Reinit the error count
	luaexiterrorcount = 8;

	if (!L) {

		L = lua_open();
		luaL_openlibs(L);
		#if defined( WIN32) && !defined(NEED_MINGW_HACKS)
		iuplua_open(L);
		iupcontrolslua_open(L);
		luaopen_winapi(L);

		//luasocket - yeah, have to open this in a weird way
		lua_pushcfunction(L,luaopen_socket_core);
		lua_setglobal(L,"tmp");
		luaL_dostring(L, "package.preload[\"socket.core\"] = _G.tmp");
		lua_pushcfunction(L,luaopen_mime_core);
		lua_setglobal(L,"tmp");
		luaL_dostring(L, "package.preload[\"mime.core\"] = _G.tmp");
		#endif

		luaL_register(L, "emu", emulib); // added for better cross-emulator compatibility
		luaL_register(L, "FCEU", emulib); // kept for backward compatibility
		luaL_register(L, "memory", memorylib);
		luaL_register(L, "rom", romlib);
		luaL_register(L, "joypad", joypadlib);
		luaL_register(L, "zapper", zapperlib);
		luaL_register(L, "input", inputlib);
		luaL_register(L, "savestate", savestatelib);
		luaL_register(L, "movie", movielib);
		luaL_register(L, "gui", guilib);
		luaL_register(L, "sound", soundlib);
		luaL_register(L, "debugger", debuggerlib);
		luaL_register(L, "taseditor", taseditorlib);
		luaL_register(L, "bit", bit_funcs); // LuaBitOp library
		lua_settop(L, 0);		// clean the stack, because each call to luaL_register leaves a table on top

		// register a few utility functions outside of libraries (in the global namespace)
		lua_register(L, "print", print);
		lua_register(L, "gethash", gethash),
		lua_register(L, "tostring", tostring);
		lua_register(L, "tobitstring", tobitstring);
		lua_register(L, "addressof", addressof);
		lua_register(L, "copytable", copytable);

		// old bit operation functions
		lua_register(L, "AND", bit_band);
		lua_register(L, "OR", bit_bor);
		lua_register(L, "XOR", bit_bxor);
		lua_register(L, "SHIFT", bit_bshift_emulua);
		lua_register(L, "BIT", bitbit);		

		if (arg)
		{
			luaL_Buffer b;
			luaL_buffinit(L, &b);
			luaL_addstring(&b, arg);
			luaL_pushresult(&b);

			lua_setglobal(L, "arg");
		}

		luabitop_validate(L);

		// push arrays for storing hook functions in
		for(int i = 0; i < LUAMEMHOOK_COUNT; i++)
		{
			lua_newtable(L);
			lua_setfield(L, LUA_REGISTRYINDEX, luaMemHookTypeStrings[i]);
		}
	}

	// We make our thread NOW because we want it at the bottom of the stack.
	// If all goes wrong, we let the garbage collector remove it.
	lua_State *thread = lua_newthread(L);

	// Load the data
	int result = luaL_loadfile(L,filename);

	if (result) {
#ifdef WIN32
		// Doing this here caused nasty problems; reverting to MessageBox-from-dialog behavior.
                //StopSound();//StopSound(); //mbg merge 7/23/08
		MessageBox(NULL, lua_tostring(L,-1), "Lua load error", MB_OK | MB_ICONSTOP);
#else
		fprintf(stderr, "Failed to compile file: %s\n", lua_tostring(L,-1));
#endif

		// Wipe the stack. Our thread
		lua_settop(L,0);
		return 0; // Oh shit.
	}
#ifdef WIN32
	AddRecentLuaFile(filename); //Add the filename to our recent lua menu
#endif

	// Get our function into it
	lua_xmove(L, thread, 1);

	// Save the thread to the registry. This is why I make the thread FIRST.
	lua_setfield(L, LUA_REGISTRYINDEX, frameAdvanceThread);


	// Initialize settings
	luaRunning = TRUE;
	skipRerecords = FALSE;
	numMemHooks = 0;
	transparencyModifier = 255; // opaque

	//wasPaused = FCEUI_EmulationPaused();
	//if (wasPaused) FCEUI_ToggleEmulationPause();

	// And run it right now. :)
	//FCEU_LuaFrameBoundary();

	// Set up our protection hook to be executed once every 10,000 bytecode instructions.
	//lua_sethook(thread, FCEU_LuaHookFunction, LUA_MASKCOUNT, 10000);

#ifdef WIN32
	info_print = PrintToWindowConsole;
	info_onstart = WinLuaOnStart;
	info_onstop = WinLuaOnStop;
	if(!LuaConsoleHWnd)
		LuaConsoleHWnd = CreateDialog(fceu_hInstance, MAKEINTRESOURCE(IDD_LUA), hAppWnd, (DLGPROC) DlgLuaScriptDialog);
	info_uid = (int)LuaConsoleHWnd;
#else
	info_print = NULL;
	info_onstart = NULL;
	info_onstop = NULL;
#endif
	if (info_onstart)
		info_onstart(info_uid);

	// We're done.
	return 1;
}

/**
 * Equivalent to repeating the last FCEU_LoadLuaCode() call.
 */
void FCEU_ReloadLuaCode()
{
	if (!luaScriptName)
	{
#ifdef WIN32
		// no script currently running, then try loading the most recent 
		extern char *recent_lua[];
		char*& fname = recent_lua[0];
		extern void UpdateLuaConsole(const char* fname);
		if (fname)
		{
			UpdateLuaConsole(fname);
			FCEU_LoadLuaCode(fname);
		} else
		{
			FCEU_DispMessage("There's no script to reload.", 0);
		}
#else
		FCEU_DispMessage("There's no script to reload.", 0);
#endif
	} else
	{
		FCEU_LoadLuaCode(luaScriptName);
	}
}


/**
 * Terminates a running Lua script by killing the whole Lua engine.
 *
 * Always safe to call, except from within a lua call itself (duh).
 *
 */
void FCEU_LuaStop() {

	if (!CheckLua())
		return;

	//already killed
	if (!L) return;

	// Since the script is exiting, we want to prevent an infinite loop.
	// CallExitFunction() > HandleCallbackError() > FCEU_LuaStop() > CallExitFunction() ...
	if (luaexiterrorcount > 0) {
		luaexiterrorcount = luaexiterrorcount - 1;
		//execute the user's shutdown callbacks
		CallExitFunction();
	}

	luaexiterrorcount = luaexiterrorcount + 1;

	//already killed (after multiple errors)
	if (!L) return;

	/*info.*/numMemHooks = 0;
	for(int i = 0; i < LUAMEMHOOK_COUNT; i++)
		CalculateMemHookRegions((LuaMemHookType)i);

	//sometimes iup uninitializes com
	//MBG TODO - test whether this is really necessary. i dont think it is
	#ifdef WIN32
	CoInitialize(0);
	#endif

	if (info_onstop)
		info_onstop(info_uid);

	//lua_gc(L,LUA_GCCOLLECT,0);


	lua_close(L); // this invokes our garbage collectors for us
	L = NULL;
	FCEU_LuaOnStop();
}

/**
 * Returns true if there is a Lua script running.
 *
 */
int FCEU_LuaRunning() {
	// FIXME: return false when no callback functions are registered.
	return (int) (L != NULL); // should return true if callback functions are active.
}


/**
 * Returns true if Lua would like to steal the given joypad control.
 */
//int FCEU_LuaUsingJoypad(int which) {
//	return lua_joypads_used & (1 << which);
//}

//adelikat: TODO: should I have a FCEU_LuaUsingJoypadFalse?

/**
 * Reads the buttons Lua is feeding for the given joypad, in the same
 * format as the OS-specific code.
 *
 * It may force set or force clear the buttons. It may also simply
 * pass the input along or invert it. The act of calling this
 * function will reset everything back to pass-through, though.
 * Generally means don't call it more than once per frame!
 */
uint8 FCEU_LuaReadJoypad(int which, uint8 joyl) {
	joyl = (joyl & luajoypads1[which]) | (~joyl & luajoypads2[which]);
	luajoypads1[which] = 0xFF;
	luajoypads2[which] = 0x00;
	return joyl;
}

//adelikat: Returns the buttons that will be specifically set to false (as opposed to on or nil)
//This will be used in input.cpp to &(and) against the input to override a button with a false value.  This is a work around to allow 3 conditions to be sent be lua, true, false, nil
//uint8 FCEU_LuaReadJoypadFalse(int which) {
//	lua_joypads_used_false &= ~(1 << which);
//	return lua_joypads_false[which];
//}

/**
 * If this function returns true, the movie code should NOT increment
 * the rerecord count for a load-state.
 *
 * This function will not return true if a script is not running.
 */
int FCEU_LuaRerecordCountSkip() {
	// FIXME: return true if (there are any active callback functions && skipRerecords)
	return L && luaRunning && skipRerecords;
}

/**
 * Given an 8-bit screen with the indicated resolution,
 * draw the current GUI onto it.
 *
 * Currently we only support 256x* resolutions.
 */
void FCEU_LuaGui(uint8 *XBuf)
{
	if (!L/* || !luaRunning*/)
		return;

	// First, check if we're being called by anybody
	lua_getfield(L, LUA_REGISTRYINDEX, guiCallbackTable);

	if (lua_isfunction(L, -1)) {
		// We call it now
		numTries = 1000;
		int ret = lua_pcall(L, 0, 0, 0);
		if (ret != 0) {
#ifdef WIN32
			//StopSound();//StopSound(); //mbg merge 7/23/08
			MessageBox(hAppWnd, lua_tostring(L, -1), "Lua Error in GUI function", MB_OK);
#else
			fprintf(stderr, "Lua error in gui.register function: %s\n", lua_tostring(L, -1));
#endif
			// This is grounds for trashing the function
			lua_pushnil(L);
			lua_setfield(L, LUA_REGISTRYINDEX, guiCallbackTable);

		}
	}

	// And wreak the stack
	lua_settop(L, 0);

	if (gui_used == GUI_CLEAR)
		return;

	if (gui_used == GUI_USED_SINCE_LAST_FRAME && !FCEUI_EmulationPaused())
	{
		memset(gui_data, 0, LUA_SCREEN_WIDTH*LUA_SCREEN_HEIGHT*4);
		gui_used = GUI_CLEAR;
		return;
	}

	gui_used = GUI_USED_SINCE_LAST_FRAME;

	int x, y;

	for (y = 0; y < LUA_SCREEN_HEIGHT; y++)
	{
		for (x=0; x < LUA_SCREEN_WIDTH; x++)
		{
			const uint8 gui_alpha = gui_data[(y*LUA_SCREEN_WIDTH+x)*4+3];
			if (gui_alpha == 0)
			{
				// do nothing
				continue;
			}

			const uint8 gui_red   = gui_data[(y*LUA_SCREEN_WIDTH+x)*4+2];
			const uint8 gui_green = gui_data[(y*LUA_SCREEN_WIDTH+x)*4+1];
			const uint8 gui_blue  = gui_data[(y*LUA_SCREEN_WIDTH+x)*4];

			int r, g, b;
			if (gui_alpha == 255) {
				// direct copy
				r = gui_red;
				g = gui_green;
				b = gui_blue;
			}
			else {
				// alpha-blending
				uint8 scr_red, scr_green, scr_blue;
				FCEUD_GetPalette(XBuf[(y)*256+x], &scr_red, &scr_green, &scr_blue);
				r = (((int) gui_red   - scr_red)   * gui_alpha / 255 + scr_red)   & 255;
				g = (((int) gui_green - scr_green) * gui_alpha / 255 + scr_green) & 255;
				b = (((int) gui_blue  - scr_blue)  * gui_alpha / 255 + scr_blue)  & 255;
			}

			XBuf[(y)*256+x] = gui_colour_rgb(r, g, b);
		}
	}

	return;
}


lua_State* FCEU_GetLuaState() {
	return L;
}
char* FCEU_GetLuaScriptName() {
	return luaScriptName;
}
