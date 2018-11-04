#ifndef RAM_SEARCH_H
#define RAM_SEARCH_H


extern char rs_type_size;
extern int ResultCount;
typedef unsigned int HWAddressType;

unsigned int sizeConv(unsigned int index,char size, char *prevSize = &rs_type_size, bool usePrev = false);
unsigned int GetRamValue(unsigned int Addr,char Size);
void prune(char Search, char Operater, char Type, int Value, int OperatorParameter);
void CompactAddrs();
void reset_address_info();
void signal_new_frame();
void signal_new_size();
void UpdateRamSearchTitleBar(int percent = 0);
void SetRamSearchUndoType(HWND hDlg, int type);
unsigned int ReadValueAtHardwareAddress(HWAddressType address, unsigned int size);
bool WriteValueAtHardwareAddress(HWAddressType address, unsigned int value, unsigned int size);
bool IsHardwareAddressValid(HWAddressType address);
extern int curr_ram_size;
extern bool noMisalign;

void ResetResults();
void CloseRamWindows(); //Close the Ram Search & Watch windows when rom closes
void ReopenRamWindows(); //Reopen them when a new Rom is loaded
void Update_RAM_Search(); //keeps RAM values up to date in the search and watch windows

void SetSearchType(int SearchType); //Set the search type
void DoRamSearchOperation(); //Perform a search

extern HWND RamSearchHWnd;
extern LRESULT CALLBACK RamSearchProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);

#endif
