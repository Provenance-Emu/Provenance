
//#include <sys/stat.h>
//#include <stdlib.h>
//#include <stdio.h>
#include <fileio.h>
#include "types.h"
#include "file.h"


Bool FileReadMem(Char *pFilePath, void *pMem, Uint32 nBytes)
{
    #if 0
	FILE *pFile;
	pFile = fopen(pFilePath, "rb");
	if (pFile)
	{
		Uint32 nReadBytes;
		nReadBytes = fread(pMem, 1, nBytes, pFile);
		fclose(pFile);
		return (nBytes == nReadBytes);
	}
	return FALSE;
	#else

	int hFile;
	unsigned int nReadBytes;

	hFile = fioOpen(pFilePath, O_RDONLY);
	if (hFile < 0)
	{
		return FALSE;
	}

	nReadBytes = fioRead(hFile, pMem, nBytes);
	fioClose(hFile);
	
	return (nReadBytes == nBytes);
    #endif
}

Bool FileWriteMem(Char *pFilePath, void *pMem, Uint32 nBytes)
{
    #if 0
	FILE *pFile;
	Uint32 nWriteBytes;

	pFile = fopen(pFilePath, "wb");
	if (pFile)
	{
		nWriteBytes = fwrite(pMem, 1, nBytes, pFile);
		fclose(pFile);
		return (nBytes == nWriteBytes);
	}
	return FALSE;
    #else

	int hFile;
	unsigned int nWriteBytes;

	hFile = fioOpen(pFilePath, O_CREAT | O_WRONLY);
	if (hFile < 0)
	{
		return FALSE;
	}

	nWriteBytes = fioWrite(hFile, pMem, nBytes);
	fioClose(hFile);
	
	return (nWriteBytes == nBytes);
    #endif
}

Bool FileExists(Char *pFilePath)
{
    #if 0
	FILE *pFile;

	pFile = fopen(pFilePath, "rb");
	if (pFile)
	{
		fclose(pFile);
		return true;
	}
	else
	{
		return false;
	}
	#else

	int hFile;

	hFile = fioOpen(pFilePath, O_RDONLY);
	if (hFile < 0)
	{
		return FALSE;
	}

	fioClose(hFile);
	return TRUE;

    #endif
}

