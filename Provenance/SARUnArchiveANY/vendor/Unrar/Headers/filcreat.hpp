#ifndef _RAR_FILECREATE_
#define _RAR_FILECREATE_

bool FileCreate(RAROptions *Cmd,File *NewFile,char *Name,wchar *NameW,
                OVERWRITE_MODE Mode,bool *UserReject,int64 FileSize=INT64NDF,
                uint FileTime=0);
bool GetAutoRenamedName(char *Name);

#if defined(_WIN_32) && !defined(_WIN_CE)
bool UpdateExistingShortName(char *Name,wchar *NameW);
#endif

#endif
