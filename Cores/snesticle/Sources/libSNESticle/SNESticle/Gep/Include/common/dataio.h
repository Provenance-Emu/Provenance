
#ifndef _DATAIO_H
#define _DATAIO_H

#include <stdio.h>

class CDataIO
{
public:
	CDataIO();
	virtual ~CDataIO();
	virtual size_t Read(void *pBuffer, Int32 nBytes)=0;
	virtual Uint8 *ReadPtr(Int32 nBytes) {return NULL;}
	virtual size_t Write(const void *pBuffer, Int32 nBytes)=0;
	virtual int Seek(Int32 iPos, Int32 Whence) = 0;
	virtual size_t GetPos() = 0;
	virtual void Close() {};
};

class CFileIO : public CDataIO
{
	FILE	*m_pFile;
public:
	CFileIO();
	virtual Bool Open(const Char *pFilePath, const Char *pMode);
	virtual size_t Read(void *pBuffer, Int32 nBytes);
	virtual size_t Write(const void *pBuffer, Int32 nBytes);
	virtual int Seek(Int32 iPos, Int32 Whence);
	virtual size_t GetPos();
	virtual void Close();
};

class CMemFileIO : public CDataIO
{
	Uint8 *m_pMem;
	Uint32 m_uPos;
	Uint32 m_uSize;
public:
	CMemFileIO();
	virtual Bool Open(Uint8 *pMem, Uint32 uSize);
	virtual size_t Read(void *pBuffer, Int32 nBytes);
	virtual size_t Write(const void *pBuffer, Int32 nBytes);
	virtual int Seek(Int32 iPos, Int32 Whence);
	virtual size_t GetPos() {return (size_t)m_uPos;}
	virtual void Close();
	virtual Uint8 *ReadPtr(Int32 nBytes);
};



#endif

