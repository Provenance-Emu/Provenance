#ifndef _RAR_STRLIST_
#define _RAR_STRLIST_

class StringList
{
  private:
    Array<char> StringData;
    size_t CurPos;

    Array<wchar> StringDataW;
    size_t CurPosW;

    Array<size_t> PosDataW;
    size_t PosDataItem;

    uint StringsCount;

    size_t SaveCurPos[16],SaveCurPosW[16],SavePosDataItem[16],SavePosNumber;
  public:
    StringList();
    ~StringList();
    void Reset();
    size_t AddString(const char *Str);
    size_t AddString(const char *Str,const wchar *StrW);
    bool GetString(char *Str,size_t MaxLength);
    bool GetString(char *Str,wchar *StrW,size_t MaxLength);
    bool GetString(char *Str,wchar *StrW,size_t MaxLength,int StringNum);
    char* GetString();
    bool GetString(char **Str,wchar **StrW);
    char* GetString(uint StringPos);
    void Rewind();
    uint ItemsCount() {return(StringsCount);};
    size_t GetBufferSize();
    bool Search(char *Str,wchar *StrW,bool CaseSensitive);
    void SavePosition();
    void RestorePosition();
};

#endif
