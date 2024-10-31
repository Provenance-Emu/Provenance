
#ifndef _EMUSHELL_H
#define _EMUSHELL_H

class CEmuSystem;
class CEmuRom;

#define EMUSHELL_MAX_SYSTEMS (8)

struct EmuShellSysT
{
	CEmuSystem	*pSystem;
	CEmuRom		*pRom;
	CEmuRom		*pBios;
};


class CEmuShell
{
protected:
	CEmuSystem  	*m_pSystem;		// current active system
	CEmuRom  		*m_pRom;		// current active rom
	CEmuRom  		*m_pBios;		// current active bios

	Uint32			m_nMaxSaveChars;
    Char 			m_RomName[256];		// base rom filename "Super Mario World"
	Char			m_SaveName[256];    // save filename "Super Mar001"

	// list of registered systems
	Int32			m_nSystems;
	EmuShellSysT	m_Systems[EMUSHELL_MAX_SYSTEMS];

public:
	CEmuShell();
	virtual ~CEmuShell();
	virtual Bool LoadRom(Char *pRomFile, Uint8 *pBuffer, Uint32 nBufferBytes);
	virtual void UnloadRom();

	void LoadState();
	void SaveState();

	EmuShellSysT *FindSysByExt(char *pExt);

	EmuShellSysT *RegisterSystem(CEmuSystem *pSystem, CEmuRom *pRom, CEmuRom *pBios);

	void SetRomFileName(Char *pFileName);
	Char *GetRomName() {return m_RomName;}
	Char *GetSaveName() {return m_SaveName;}
};

#endif
