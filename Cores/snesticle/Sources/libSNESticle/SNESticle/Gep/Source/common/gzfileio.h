
#ifndef _GZFILEIO_H
#define _GZFILEIO_H

#include "zlib.h"
#include "dataio.h"

class CGZFileIO : public CDataIO
{
	gzFile	m_pFile;
public:
	CGZFileIO();
	virtual Bool Open(Char *pFilePath, Char *pMode);
	virtual size_t Read(void *pBuffer, Int32 nBytes);
	virtual size_t Write(void *pBuffer, Int32 nBytes);
	virtual int Seek(Int32 iPos, Int32 Whence);
	virtual size_t GetPos();
	virtual void Close();
};


#endif