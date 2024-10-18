

/*!

    \File    path.cpp

    \Description
	    Description

    \Notes
	    None.

    \Copyright
	    (c) 2004 Icer Addis

*/


/*-- Include files -------------------------------------------------------------------------------*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"
#include "path.h"

/*-- Preprocessor Defines ------------------------------------------------------------------------*/

/*-- Type Definitions ----------------------------------------------------------------------------*/

/*-- Private Implementation ----------------------------------------------------------------------*/

/*-- Public Implementation -----------------------------------------------------------------------*/



//
//
//


void PathGetFileName(Char *pName, const Char *pPath)
{
	CPath path;

	path.SetPath(pPath);
	strcpy(pName, path.GetName());
}

void PathGetFileExt(Char *pExt, const Char *pPath)
{
	CPath path;

	path.SetPath(pPath);
	strcpy(pExt, path.GetExt());
}

//
//
//

CPath::CPath()
{
	Reset();
}

CPath::CPath(const char *pPath)
{
	Reset();
	SetPath(pPath);
}

void CPath::SetDrive(const char *pDir)
{
	strncpy(m_drive, pDir, sizeof(m_drive));
}

void CPath::SetDir(const char *pDir)
{
	strncpy(m_dir, pDir, sizeof(m_dir));
}

void CPath::SetName(const char *pName)
{
	strncpy(m_name, pName, sizeof(m_name));
}

void CPath::SetExt(const char *pExt)
{
	strncpy(m_ext, pExt, sizeof(m_ext));
}

void CPath::Reset()
{
	m_drive[0]  = '\0';
	m_dir[0]  = '\0';
	m_name[0] = '\0';
	m_ext[0]  = '\0';
}

void CPath::SetPath(const char *pPath)
{
	_splitpath(pPath, m_drive, m_dir, m_name, m_ext);
}

const char *CPath::GetPath()
{
	_makepath(m_path, m_drive, m_dir, m_name, m_ext);
    return m_path;
}





