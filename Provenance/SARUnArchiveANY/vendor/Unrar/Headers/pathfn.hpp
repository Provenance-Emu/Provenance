#ifndef _RAR_PATHFN_
#define _RAR_PATHFN_

char* PointToName(const char *Path);
wchar* PointToName(const wchar *Path);
char* PointToLastChar(const char *Path);
char* ConvertPath(const char *SrcPath,char *DestPath);
wchar* ConvertPath(const wchar *SrcPath,wchar *DestPath);
void SetExt(char *Name,const char *NewExt);
void SetExt(wchar *Name,const wchar *NewExt);
void SetSFXExt(char *SFXName);
void SetSFXExt(wchar *SFXName);
char *GetExt(const char *Name);
wchar *GetExt(const wchar *Name);
bool CmpExt(const char *Name,const char *Ext);
bool IsWildcard(const char *Str,const wchar *StrW=NULL);
bool IsPathDiv(int Ch);
bool IsDriveDiv(int Ch);
int GetPathDisk(const char *Path);
void AddEndSlash(char *Path);
void AddEndSlash(wchar *Path);
void GetFilePath(const char *FullName,char *Path,int MaxLength);
void GetFilePath(const wchar *FullName,wchar *Path,int MaxLength);
void RemoveNameFromPath(char *Path);
void RemoveNameFromPath(wchar *Path);
void GetAppDataPath(char *Path);
void GetRarDataPath(char *Path);
bool EnumConfigPaths(char *Path,int Number);
void GetConfigName(const char *Name,char *FullName,bool CheckExist);
char* GetVolNumPart(char *ArcName);
void NextVolumeName(char *ArcName,wchar *ArcNameW,uint MaxLength,bool OldNumbering);
bool IsNameUsable(const char *Name);
void MakeNameUsable(char *Name,bool Extended);
char* UnixSlashToDos(char *SrcName,char *DestName=NULL,uint MaxLength=NM);
char* DosSlashToUnix(char *SrcName,char *DestName=NULL,uint MaxLength=NM);
wchar* UnixSlashToDos(wchar *SrcName,wchar *DestName=NULL,uint MaxLength=NM);
bool IsFullPath(const char *Path);
bool IsFullPath(const wchar *Path);
bool IsDiskLetter(const char *Path);
bool IsDiskLetter(const wchar *Path);
void GetPathRoot(const char *Path,char *Root);
int ParseVersionFileName(char *Name,wchar *NameW,bool Truncate);
char* VolNameToFirstName(const char *VolName,char *FirstName,bool NewNumbering);
wchar* GetWideName(const char *Name,const wchar *NameW,wchar *DestW);


inline char* GetOutputName(const char *Name) {return((char *)Name);};

#endif
