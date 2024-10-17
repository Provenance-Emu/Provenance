

#ifndef _FILE_H
#define _FILE_H

Bool FileReadMem(Char *pFilePath, void *pMem, Uint32 nBytes);
Bool FileWriteMem(Char *pFilePath, void *pMem, Uint32 nBytes);

Bool FileExists(Char *pFilePath);

#endif

