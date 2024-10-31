
#include <string.h>
#include "types.h"
#include "dataio.h"


CDataIO::CDataIO()
{
}

CDataIO::~CDataIO()
{
	Close();
}

CFileIO::CFileIO()
{
	m_pFile = NULL;
}

Bool CFileIO::Open(const Char *pFilePath, const Char *pMode)
{
	Close();
	m_pFile = fopen(pFilePath, pMode);
	return m_pFile ? TRUE : FALSE;
}
size_t CFileIO::Read(void *pBuffer, Int32 nBytes)
{
	return m_pFile ? fread(pBuffer, 1, nBytes, m_pFile) : 0;
}

size_t CFileIO::Write(const void *pBuffer, Int32 nBytes)
{
	return m_pFile ? fwrite(pBuffer, 1, nBytes, m_pFile) : 0;
}

int CFileIO::Seek(Int32 iPos, Int32 Whence)
{
	return m_pFile ? fseek(m_pFile, iPos, Whence) : -1;
}

size_t CFileIO::GetPos()
{
	return m_pFile ? ftell(m_pFile) : 0;
}

void CFileIO::Close()
{
	if (m_pFile)
	{
		fclose(m_pFile);
		m_pFile = NULL;
	}
}

CMemFileIO::CMemFileIO()
{
	m_pMem = NULL;
	m_uPos = 0;
	m_uSize = 0;
}

Bool CMemFileIO::Open(Uint8 *pMem, Uint32 uSize)
{
	Close();
	m_pMem = pMem;
	m_uPos = 0;
	m_uSize = uSize;
	return TRUE;
}

size_t CMemFileIO::Read(void *pBuffer, Int32 nBytes)
{
	Int32 nBytesLeft;
	if (!m_pMem) return 0;

	// get number of bytes remaining
	nBytesLeft = m_uSize - m_uPos;
	if (nBytes > nBytesLeft) nBytes = nBytesLeft;

	// copy data
	memcpy(pBuffer, m_pMem + m_uPos, nBytes);

	// update pointer
	m_uPos += nBytes;

	return nBytes;
}

size_t CMemFileIO::Write(const void *pBuffer, Int32 nBytes)
{
	Int32 nBytesLeft;
	if (!m_pMem) return 0;

	// get number of bytes remaining
	nBytesLeft = m_uSize - m_uPos;
	if (nBytes > nBytesLeft) nBytes = nBytesLeft;

	// copy data
	memcpy(m_pMem + m_uPos, pBuffer, nBytes);

	// update pointer
	m_uPos += nBytes;

	return nBytes;
}

int CMemFileIO::Seek(Int32 iPos, Int32 Whence)
{
	switch (Whence)
	{
	case SEEK_CUR:
		m_uPos+=iPos;
		break;
	case SEEK_SET:
		m_uPos = (Uint32)iPos;
		break;
	case SEEK_END:
		m_uPos = m_uSize - iPos;
		break;
	}

	if (m_uPos > m_uSize) m_uPos = m_uSize;
	return 0;
}

void CMemFileIO::Close()
{
	m_pMem  = NULL;
	m_uPos  = 0;
	m_uSize = 0;
}

Uint8 *CMemFileIO::ReadPtr(Int32 nBytes)
{
	Int32 nBytesLeft;
    Uint8 *pPtr;
	if (!m_pMem) return NULL;

	// get number of bytes remaining
	nBytesLeft = m_uSize - m_uPos;
	if (nBytes > nBytesLeft) return NULL;

    pPtr = m_pMem + m_uPos;

    m_uPos += nBytes;
	return pPtr;
}

