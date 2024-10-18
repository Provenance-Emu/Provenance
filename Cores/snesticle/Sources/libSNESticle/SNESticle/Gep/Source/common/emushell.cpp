
#include <string.h>
#include <stdio.h>
#include "types.h"
#include "emusys.h"
#include "emurom.h"
#include "emushell.h"
#include "zlib.h"
#include "dataio.h"
#include "pathext.h"

EmuShellSysID CEmuShell::ResolveSysByPath(char *pPath, Bool *pbCompressed)
{
	char str[256];
	EmuShellSysID eType = EMUSHELL_SYSID_INVALID;

	strcpy(str, (char *)pPath);

	if (pbCompressed)
		*pbCompressed = FALSE;

	char *pExt;

	pExt = PathExtGet(str);
	if (pExt)
	{
		eType = GetSysIDByExt(pExt + 1);
		// is it an invalid type
		if (eType != EMUSHELL_SYSID_INVALID)
		{
			if (!strcmp(pExt,".gz"))
			{
				// its a compressed file
				*pbCompressed = TRUE;
				// remove extension
				*pExt = 0;

				pExt = PathExtGet(str);
			}
		}
	}

	return EMUSHELL_SYSID_INVALID;
}


static void _EmuShellGetName(Char *pName, Char *pPath)
{
	Char Path[256];
	Int32 i = strlen(pPath);

	strcpy(Path, pPath);

	while (i > 0 && Path[i]!='.' && Path[i]!='/')
	{
		i--;
	}

	if (Path[i]=='.' && Path[i+1]=='g' && Path[i+2]=='z')
	{
		i--;
		while (i > 0 && Path[i]!='.' && Path[i]!='/')
		{
			i--;
		}
	}

	if (Path[i]=='.')
	{
		Path[i]= 0;
	}	

	while (i > 0 &&  Path[i]!='/')
	{
		i--;
	}

	if (Path[i]=='/')
	{
		i++;
	}

	strcpy(pName, Path + i);
}

static Uint32 _EmuShellHash(char *pStr)
{
	Uint32 hash = 0;
	while (*pStr)
	{
		hash*=33;
		hash += *pStr;
		pStr++;
	}
	return hash;
}

int CEmuShell::ReadFileData(Uint8 *pBuffer, Int32 nBufferBytes, char *pRomFile, Bool bCompressed)
{
	int nBytes = 0;

    memset(pBuffer, 0, nBufferBytes);

	if (pRomFile)
	{
    	if (bCompressed)
    	{
    	    gzFile pFile;

    	    pFile = gzopen(pRomFile, "rb");
    	    if (!pFile)
    	    {
    	        printf("ERROR: Cannot open romgz %s", pRomFile);
    	        return -1;
    	    }
    	    nBytes = gzread(pFile, pBuffer, nBufferBytes);
    	    gzclose(pFile);

    	    printf("GZ ROM data read: %s (%d bytes)\n", pRomFile, nBytes);
    	} else
    	{
    	    FILE *pFile;

    	    pFile = fopen(pRomFile, "rb");
    	    if (!pFile)
    	    {
    	        printf("ERROR: Cannot open rom %s", pRomFile);
    	        return -1;
    	    }
    	    nBytes= fread(pBuffer,  1, nBufferBytes, pFile);
    	    fclose(pFile);

    	    printf("Uncompressed ROM data read: %s (%d bytes)\n", pRomFile, nBytes);
    	}
	}

	return nBytes;
}


static void _EmuShellTruncName(Char *pOut, Char *pStr, Int32 nMaxChars)
{
	Uint32 hash;

	hash = _EmuShellHash(pStr);

	// copy string up to maxchars length
	while (*pStr && nMaxChars > 0)
	{
		*pOut++ = *pStr++;
		nMaxChars--;
	}

	// terminate
	*pOut = 0;

	if (nMaxChars <= 0)
	{
		// mangle end of name
		sprintf(pOut - 3, "%03d", hash % 1000);
	}
}


void CEmuShell::SetRomFileName(Char *pRomFile)
{
	_EmuShellGetName(m_RomName, pRomFile);
	_EmuShellTruncName(m_SaveName, pRomFile, m_nMaxSaveChars);
}

CEmuShell::CEmuShell()
{
	m_pSystem = NULL;
	m_pRom    = NULL;
	m_pBois    = NULL;

	m_RomName[0] = 0;
	m_nMaxSaveChars = 32;
	m_nSystems = 0;
}


CEmuShell::~CEmuShell()
{
}

void CEmuShell::RegisterSystem(CEmuSystem *pSystem, CEmuRom *pRom, CEmuRom *pBios)
{
	EmuShellSysT *pShellSys = NULL;

	if (m_nSystems < EMUSHELL_MAX_SYSTEMS)
	{
		// allocate a new system
		pShellSys = &m_Systems[m_nSystems++];

		pShellSys->pRom    = pRom;
		pShellSys->pSystem = pSystem;
		pShellSys->pBios   = pBios;
	}
	return pShellSys;
}


EmuShellSysID CEmuShell::GetSysIDByName(char *pName)
{
	EmuShellSysID idSys;

	for (idSys=0; idSys < m_nSystems; idSys++)
	{
		CEmuSystem *pSystem = GetSysByID(idSys);
		if (!strcmp(pName, pSystem->GetString(EMUSYS_STRING_SHORTNAME)))
		{
			return idSys;
		}
	}
	return EMUSHELL_SYSID_INVALID;
}

EmuShellSysT *CEmuShell::FindSysByExt(char *pExt)
{
	Int32 idys;

	// iterate through all supported systems
	for (iSys=0; iSys < m_nSystems; iSys++)
	{
		CEmuRom *pRom = m_Systems[iSys].pRom;
		Uint32 uExt;

		// see if rom supports this extension...
		for (uExt=0; uExt < pRom->GetNumExts(); uExt++)
		{
			if (!stricmp(pExt, pRom->GetExtName(uExt)))
			{
				// it does!
				return &m_Systems[iSys];
			}
		}
	}
	return NULL;
}


void CEmuShell::UnloadRom()
{
	if (m_pSystem)
		m_pSystem->SetRom(NULL);

	if (m_pRom)
		m_pRom->Unload();
//    _bStateSaved = FALSE;
}

Bool CEmuShell::LoadRom(Char *pRomFile, Uint8 *pBuffer, Uint32 nBufferBytes)
{
	Int32 eType;
	Bool bCompressed;

    UnloadRom();

	// no system active
	m_pSystem=NULL;
	m_pRom   =NULL;

	eType = ResolveSysByPath(pRomFile, &bCompressed);
	if (eType == EMUSHELL_SYSID_INVALID) 
	{
		// unknown system type
		return FALSE;
	}

	// set current system 
	m_pSystem = m_pSystems[eType];
	m_pRom    = m_pRoms[eType];

    //_MainLoopResetHistory();
	//_MainLoopResetInputChecksums();

	if (m_pRom)
	{
		int nBytes;
		nBytes = ReadFileData(pBuffer, nBufferBytes, pRomFile, bCompressed);
		if (nBytes <= 0)
		{
			return FALSE;
		}

	    CMemFileIO romfile;
	    EmuRomLoadErrorE eError;

	    // open memoryfile for rom data
	    romfile.Open(pBuffer, nBytes);

		// load rom
	    eError = m_pRom->LoadRom(&romfile);
	    romfile.Close();

		if (eError!=EMUROM_LOADERROR_NONE)
		{
			return FALSE;
		}

		SetRomFileName(pRomFile);
	}

	if (m_pSystem)
	{
		// set the system to use this rom (this may trigger a reset)
		m_pSystem->SetRom(m_pRom);

		// trigger a reset
		m_pSystem->Reset();
	}

	return TRUE;
}





  /*


class CSnesShell : public CEmuShell
{
public:
	CSnesShell(EmuDefT *pEmuDef);
};


CSnesShell::CSnesShell(EmuDefT *pEmuDef)
		: CEmuShell(pEmuDef)
{
	m_pSystem = new SnesSystem();
	m_pRom    = new SnesRom();
}
*/








