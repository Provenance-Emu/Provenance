

/*!

    \File    emurom.cpp

    \Description
        Description

    \Notes
        None.

    \Copyright
        (c) 2004 Icer Addis

*/


/*-- Include files -------------------------------------------------------------------------------*/

#include <stdlib.h>
#include "types.h"
#include "emurom.h"

using namespace Emu;

/*-- Preprocessor Defines ------------------------------------------------------------------------*/

/*-- Type Definitions ----------------------------------------------------------------------------*/

/*-- Private Implementation ----------------------------------------------------------------------*/

/*-- Public Implementation -----------------------------------------------------------------------*/

Rom::Rom()
{
    m_bLoaded = FALSE;
}

Rom::~Rom()
{
}

Rom::LoadErrorE Rom::LoadRom(class CDataIO *pFileIO, Uint8 *pBuffer, Uint32 nBufferBytes)
{
	return LOADERROR_INVALID;
}


void Rom::Unload()
{
}


Uint32	Rom::GetNumRomRegions()
{
	return 0;
}

Char   *Rom::GetRomRegionName(Uint32 eRegion)
{
	return NULL;
}

Uint32 	Rom::GetRomRegionSize(Uint32 eRegion)
{
	return 0;
}

Uint32 Rom::GetNumExts()
{
	return 0;
}

Char *Rom::GetExtName(Uint32 uExt)
{
	return NULL;
}

