

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "types.h"
#include "memspace.h"
#include "dataio.h"

CMemSpace::CMemSpace()
{
	m_uSize		 = 0;
	m_pMem		 = NULL;
	m_pMemAlloc	 = NULL;
	m_uBankShift = 0;
}

CMemSpace::~CMemSpace()
{
	Free();
}

void CMemSpace::Clear(Uint8 Value)
{
	if (m_pMem)
	{
		memset(m_pMem, Value, m_uSize);
	}
}

void CMemSpace::SetMem(Uint8 *pMem, Uint32 uSize)
{
	Free();

	m_uSize = uSize;
	m_pMem  = pMem;
}

void CMemSpace::Alloc(Uint32 uSize)
{
	Free();

	if (uSize > 0)
	{
		m_uSize = uSize;
		m_pMemAlloc = m_pMem  = (Uint8 *)malloc(uSize);
		Clear(0);
	}
}

void CMemSpace::Free()
{
	if (m_pMemAlloc)
	{
		free(m_pMemAlloc);
	}
	m_pMemAlloc = NULL;
	m_pMem = NULL;
	m_uSize = 0;
}

bool CMemSpace::ReadFile(FILE *pFile)
{
	return fread(m_pMem, 1, m_uSize, pFile) == m_uSize;
}

bool CMemSpace::WriteFile(FILE *pFile)
{
	return fwrite(m_pMem, 1, m_uSize, pFile) == m_uSize;
}


bool CMemSpace::ReadFile(CDataIO *pFile)
{
	return pFile->Read(m_pMem, m_uSize) == m_uSize;
}


bool CMemSpace::ReadAllocFile(CDataIO *pFile, Uint32 nBytes)
{
	Free();

    // attempt to use pointer if memory file
    m_pMem = pFile->ReadPtr(nBytes);
    if (!m_pMem)
    {
        // perform normal alloc/read
        Alloc(nBytes);
        return ReadFile(pFile);
    }
    return true;
}

bool CMemSpace::WriteFile(CDataIO *pFile)
{
	return pFile->Write(m_pMem, m_uSize) == m_uSize;
}



void CMemSpace::SaveState(Uint8 *pData, Uint32 uDataSize)
{
	if (uDataSize >= m_uSize) uDataSize = m_uSize;
	memcpy(pData, m_pMem, uDataSize);
}

void CMemSpace::RestoreState(Uint8 *pData, Uint32 uDataSize)
{
	if (uDataSize >= m_uSize) uDataSize = m_uSize;
	memcpy(m_pMem, pData, uDataSize);
}




