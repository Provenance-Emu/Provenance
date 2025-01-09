

#include "types.h"
#include "dataio.h"
#include "gzfileio.h"



CGZFileIO::CGZFileIO()
{
	m_pFile = NULL;
}

Bool CGZFileIO::Open(Char *pFilePath, Char *pMode)
{
	Close();
	m_pFile = gzopen(pFilePath, pMode);
	return m_pFile ? TRUE : FALSE;
}
size_t CGZFileIO::Read(void *pBuffer, Int32 nBytes)
{
	return m_pFile ? gzread(m_pFile, pBuffer, nBytes) : 0;
}

size_t CGZFileIO::Write(void *pBuffer, Int32 nBytes)
{
	return m_pFile ? gzwrite(m_pFile, pBuffer, nBytes) : 0;
}

int CGZFileIO::Seek(Int32 iPos, Int32 Whence)
{
	return m_pFile ? gzseek(m_pFile, iPos, Whence) : -1;
}

size_t CGZFileIO::GetPos()
{
	return m_pFile ? gztell(m_pFile) : 0;
}

void CGZFileIO::Close()
{
	if (m_pFile)
	{
		gzclose(m_pFile);
		m_pFile = NULL;
	}
}

