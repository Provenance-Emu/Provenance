
//#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include "types.h"
#include "file.h"


Bool FileReadMem(Char *pFilePath, void *pMem, Uint32 nBytes)
{
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
}

Bool FileWriteMem(Char *pFilePath, void *pMem, Uint32 nBytes)
{
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
}

Bool FileExists(Char *pFilePath)
{
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

 //	struct _stat buf;
//	return _stat(pFilePath, &buf) ? FALSE : TRUE;
}

