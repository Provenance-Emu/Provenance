#ifdef _S9XLUA_H
#ifndef _FCEULUA_H
#define _FCEULUA_H

enum LuaCallID
{
	LUACALL_BEFOREEMULATION,
	LUACALL_AFTEREMULATION,
	LUACALL_BEFOREEXIT,
	LUACALL_BEFORESAVE,
	LUACALL_AFTERLOAD,
	LUACALL_TASEDITOR_AUTO,
	LUACALL_TASEDITOR_MANUAL,

	LUACALL_COUNT
};
extern void CallRegisteredLuaFunctions(LuaCallID calltype);

enum LuaMemHookType
{
	LUAMEMHOOK_WRITE,
	LUAMEMHOOK_READ,
	LUAMEMHOOK_EXEC,
	LUAMEMHOOK_WRITE_SUB,
	LUAMEMHOOK_READ_SUB,
	LUAMEMHOOK_EXEC_SUB,

	LUAMEMHOOK_COUNT
};
void CallRegisteredLuaMemHook(unsigned int address, int size, unsigned int value, LuaMemHookType hookType);

struct LuaSaveData
{
	LuaSaveData() { recordList = 0; }
	~LuaSaveData() { ClearRecords(); }

	struct Record
	{
		unsigned int key; // crc32
		unsigned int size; // size of data
		unsigned char* data;
		Record* next;
	};

	Record* recordList;

	void SaveRecord(struct lua_State* L, unsigned int key); // saves Lua stack into a record and pops it
	void LoadRecord(struct lua_State* L, unsigned int key, unsigned int itemsToLoad) const; // pushes a record's data onto the Lua stack
	void SaveRecordPartial(struct lua_State* L, unsigned int key, int idx); // saves part of the Lua stack (at the given index) into a record and does NOT pop anything

	void ExportRecords(void* file) const; // writes all records to an already-open file
	void ImportRecords(void* file); // reads records from an already-open file
	void ClearRecords(); // deletes all record data

private:
	// disallowed, it's dangerous to call this
	// (because the memory the destructor deletes isn't refcounted and shouldn't need to be copied)
	// so pass LuaSaveDatas by reference and this should never get called
	LuaSaveData(const LuaSaveData& copy) {}
};

#define LUA_DATARECORDKEY 42

void CallRegisteredLuaSaveFunctions(int savestateNumber, LuaSaveData& saveData);
void CallRegisteredLuaLoadFunctions(int savestateNumber, const LuaSaveData& saveData);

// Just forward function declarations

void FCEU_LuaFrameBoundary();
int FCEU_LoadLuaCode(const char *filename, const char *arg=NULL);
void FCEU_ReloadLuaCode();
void FCEU_LuaStop();
int FCEU_LuaRunning();

uint8 FCEU_LuaReadJoypad(int,uint8); // HACK - Function needs controller input
int FCEU_LuaSpeed();
int FCEU_LuaFrameskip();
int FCEU_LuaRerecordCountSkip();

void FCEU_LuaGui(uint8 *XBuf);
void FCEU_LuaUpdatePalette();

struct lua_State* FCEU_GetLuaState();
char* FCEU_GetLuaScriptName();

// And some interesting REVERSE declarations!
char *FCEU_GetFreezeFilename(int slot);


#endif
#endif
