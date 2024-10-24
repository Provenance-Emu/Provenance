
#ifndef _UIBROWSER_H
#define _UIBROWSER_H

#include "uiScreen.h"
#include "uiMenu.h"

#define BROWSER_ENTRY_MAXCHARS (64)

enum BrowserEntryTypeE
{
	BROWSER_ENTRYTYPE_DIR,
	BROWSER_ENTRYTYPE_DRIVE,
	BROWSER_ENTRYTYPE_EXECUTABLE,
	BROWSER_ENTRYTYPE_OTHER,

	BROWSER_ENTRYTYPE_NUM
};

struct BrowserEntryT
{
	Char name[BROWSER_ENTRY_MAXCHARS];
	Int32 size;
	BrowserEntryTypeE eType;
};

typedef BrowserEntryTypeE (*BrowserNameResolveFuncT)(const char *pName);

class CBrowserScreen : public CScreen
{
	BrowserEntryT 	*m_pDirEntries;
	Int32 			m_nEntries;
	Int32   		m_MaxEntries;

	Char 	m_Dir[512];

	Int32 	m_iSelect;

	Int32 	m_iScroll;
	Int32 	m_MaxLines;

	Bool	m_bSubMenu;
	CMenuScreen m_SubMenu;

	static int MenuEvent(Uint32 Type, Uint32 Parm1, void *Parm2);

public:
	CBrowserScreen(Uint32 uMaxEntries);
	~CBrowserScreen();

	void Draw();
	void Process();
	void Input(Uint32 Buttons, Uint32 Trigger);

	void ResetEntries();
	void SortEntries();
	void AddEntry(Char *pName, BrowserEntryTypeE eType, Int32 size);

	int GetEntryPath(char *pStr, int nChars);
	Char *GetEntryName();
	BrowserEntryTypeE GetEntryType();

	void SetDir(Char *pDir);
	void Chdir(Char *pSubDir);

};

#endif

