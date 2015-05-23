#ifndef RAMWATCH_H
#define RAMWATCH_H
bool ResetWatches();
void OpenRWRecentFile(int memwRFileNumber);
extern bool AutoRWLoad;
extern bool RWSaveWindowPos;
#define MAX_RECENT_WATCHES 5
extern char rw_recent_files[MAX_RECENT_WATCHES][1024];
extern bool AskSave();
extern int ramw_x;
extern int ramw_y;
extern bool RWfileChanged;

//Constants
#define AUTORWLOAD "RamWatchAutoLoad"
#define RWSAVEPOS "RamWatchSaveWindowPos"
#define RAMWX "RamwX"
#define RAMWY "RamwY"

// AddressWatcher is self-contained now
struct AddressWatcher
{
	unsigned int Address; // hardware address
	unsigned int CurValue;
	char* comment; // NULL means no comment, non-NULL means allocated comment
	bool WrongEndian;
	char Size; //'d' = 4 bytes, 'w' = 2 bytes, 'b' = 1 byte, and 'S' means it's a separator.
	char Type;//'s' = signed integer, 'u' = unsigned, 'h' = hex, 'S' = separator
};
#define MAX_WATCH_COUNT 256
extern AddressWatcher rswatches[MAX_WATCH_COUNT];
extern int WatchCount; // number of valid items in rswatches

extern char Watch_Dir[1024];

extern HWND RamWatchHWnd;
extern HACCEL RamWatchAccels;

bool InsertWatch(const AddressWatcher& Watch, char *Comment);
bool InsertWatch(const AddressWatcher& Watch, HWND parent=NULL); // asks user for comment
void Update_RAM_Watch();
bool Load_Watches(bool clear, const char* filename);
void RWAddRecentFile(const char *filename);

LRESULT CALLBACK RamWatchProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
extern HWND RamWatchHWnd;

#endif
