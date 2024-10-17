
#ifndef _MEMCARD_H
#define _MEMCARD_H

void MemCardInit();
void MemCardShutdown();
int MemCardCreateSave(char *pDir, char *pTitle, Bool bForceWrite);
Bool MemCardCheckNewCard();
Bool MemCardReadFile(char *pPath, Uint8 *pData, Uint32 nBytes);
Bool MemCardWriteFile(char *pPath, Uint8 *pData, Uint32 nBytes);

#endif
