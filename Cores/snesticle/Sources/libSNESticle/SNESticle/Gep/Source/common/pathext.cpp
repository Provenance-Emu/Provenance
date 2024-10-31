
#include <string.h>
#include "types.h"
#include "pathext.h"

#define PATHEXT_SIZE 		  (8)
#define PATHEXT_MAXEXTENSIONS (16)

struct PathExtT
{
	char			Ext[PATHEXT_SIZE];
	PathExtTypeE 	Type;
};

static Uint32 _Path_nExtList = 0;
static PathExtT _Path_ExtList[PATHEXT_MAXEXTENSIONS];

static PathExtT *_PathNewExt()
{
	if (_Path_nExtList < PATHEXT_MAXEXTENSIONS)
	{
		return &_Path_ExtList[_Path_nExtList++];
	} 
	return NULL;
}

static PathExtT *_PathFindExt(char *pExt)
{
	Uint32 iExt;
	for (iExt=0; iExt < _Path_nExtList; iExt++)
	{
		if (!strcasecmp(_Path_ExtList[iExt].Ext, pExt))
		{
			return &_Path_ExtList[iExt];
		}
	}
	return NULL;
}

int PathExtAdd(PathExtTypeE Type, char *pExt)
{
	PathExtT *pPathExt;
	if (!pExt) return -1;

	pPathExt = _PathNewExt();

	if (pPathExt)
	{
		// set extension info
		pPathExt->Type = Type;
		strcpy(pPathExt->Ext, pExt);
		return 0;
	}
	return -1;
}

char *PathExtGet(char *pPath)
{
	Int32 i;

	i = strlen(pPath);

	// search backwards for first delimiter
	while (i>=0 && pPath[i]!='.' && pPath[i]!='/' && pPath[i]!='\\')
	{
		i--;
	}

	// did we get to an extension?
	if (i>0 && pPath[i]=='.')
	{
		// return pointer to extension (including '.')
		return pPath + i;
	}

	return NULL;
}


Bool PathExtResolve(char *pPath, PathExtTypeE *pType, Bool bTruncatePath)
{
	char *pExt;

	pExt = PathExtGet(pPath);

	// did we get to an extension?
	if (pExt)
	{
		PathExtT *pPathExt;
		pPathExt = _PathFindExt(pExt + 1);
		if (pPathExt)
		{
			// truncate pathname
			if (bTruncatePath)
				*pExt = '\0';

			if (pType)
			{
				*pType = pPathExt->Type;
			}
			return TRUE;
		}
	}

	// no extension exists
	return FALSE;
}



