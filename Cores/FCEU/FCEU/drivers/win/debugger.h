#ifndef DEBUGGER_H
#define DEBUGGER_H

//#define GetMem(x) (((x < 0x2000) || (x >= 0x4020))?ARead[x](x):0xFF)
#include <windows.h>
//#include "debug.h"

// TODO: Maybe change breakpoint array to std::vector
// Maximum number of breakpoints supported
#define MAXIMUM_NUMBER_OF_BREAKPOINTS 64

// Return values for AddBreak
#define TOO_MANY_BREAKPOINTS 1
#define INVALID_BREAKPOINT_CONDITION 3

//extern volatile int userpause; //mbg merge 7/18/06 removed for merging
extern HWND hDebug;

extern int childwnd,numWPs; //mbg merge 7/18/06 had to make extern
extern bool debuggerAutoload;
extern bool debuggerSaveLoadDEBFiles;
extern bool debuggerDisplayROMoffsets;

extern unsigned int debuggerPageSize;
extern unsigned int debuggerFontSize;
extern unsigned int hexeditorFontWidth;
extern unsigned int hexeditorFontHeight;
extern char* hexeditorFontName;

void CenterWindow(HWND hwndDlg);
void DoPatcher(int address,HWND hParent);
void UpdatePatcher(HWND hwndDlg);
int GetEditHex(HWND hwndDlg, int id);

extern void AddBreakList();
extern char* BreakToText(unsigned int num);

void UpdateDebugger(bool jump_to_pc = true);
void DoDebug(uint8 halt);
void DebuggerExit();
void Disassemble(HWND hWnd, int id, int scrollid, unsigned int addr);
void PrintOffsetToSeekAndBookmarkFields(int offset);

void LoadGameDebuggerData(HWND hwndDlg);
void updateGameDependentMenusDebugger(unsigned int enable);

extern bool inDebugger;

extern class DebugSystem {
public:
	DebugSystem();
	~DebugSystem();
	
	void init();

	HFONT hFixedFont;
	int fixedFontWidth;
	int fixedFontHeight;

	HFONT hHexeditorFont;
	int HexeditorFontWidth;
	int HexeditorFontHeight;

} *debugSystem;


#endif
