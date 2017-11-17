#ifndef _RAR_ARCHIVE_
#define _RAR_ARCHIVE_

class Pack;

enum {EN_LOCK=1,EN_VOL=2,EN_FIRSTVOL=4};

class Archive:public File
{
  private:
    bool IsSignature(byte *D);
    void UpdateLatestTime(FileHeader *CurBlock);
    void ConvertNameCase(char *Name);
    void ConvertNameCase(wchar *Name);
    void ConvertUnknownHeader();
    size_t ReadOldHeader();
    void UnexpEndArcMsg();

#if !defined(SHELL_EXT) && !defined(NOCRYPT)
    CryptData HeadersCrypt;
    byte HeadersSalt[SALT_SIZE];
#endif
#ifndef SHELL_EXT
    ComprDataIO SubDataIO;
    byte SubDataSalt[SALT_SIZE];
#endif
    RAROptions *Cmd,DummyCmd;

    MarkHeader MarkHead;
    OldMainHeader OldMhd;

    int RecoverySectors;
    int64 RecoveryPos;

    RarTime LatestTime;
    int LastReadBlock;
    int CurHeaderType;

    bool SilentOpen;
  public:
    Archive(RAROptions *InitCmd=NULL);
    bool IsArchive(bool EnableBroken);
    size_t SearchBlock(int BlockType);
    size_t SearchSubBlock(const char *Type);
    int ReadBlock(int BlockType);
    void WriteBlock(int BlockType,BaseBlock *wb=NULL);
    int PrepareNamesToWrite(char *Name,wchar *NameW,char *DestName,byte *DestNameW);
    void SetLhdSize();
    size_t ReadHeader();
    void CheckArc(bool EnableBroken);
    void CheckOpen(char *Name,wchar *NameW=NULL);
    bool WCheckOpen(char *Name,wchar *NameW=NULL);
    bool TestLock(int Mode);
    void MakeTemp();
    void CopyMainHeader(Archive &Src,bool CopySFX=true,char *NameToDisplay=NULL);
    bool ProcessToFileHead(Archive &Src,bool LastBlockAdded,
      Pack *Pack=NULL,const char *SkipName=NULL);
    void TmpToArc(Archive &Src);
    void CloseNew(int AdjustRecovery,bool CloseVolume);
    void WriteEndBlock(bool CloseVolume);
    void CopyFileRecord(Archive &Src);
    void CopyArchiveData(Archive &Src);
    bool GetComment(Array<byte> *CmtData,Array<wchar> *CmtDataW);
    void ViewComment();
    void ViewFileComment();
    void SetLatestTime(RarTime *NewTime);
    void SeekToNext();
    bool CheckAccess();
    bool IsArcDir();
    bool IsArcLabel();
    void ConvertAttributes();
    int GetRecoverySize(bool Required);
    void VolSubtractHeaderSize(size_t SubSize);
    void AddSubData(byte *SrcData,size_t DataSize,File *SrcFile,const char *Name,bool AllowSplit);
    bool ReadSubData(Array<byte> *UnpData,File *DestFile);
    int GetHeaderType() {return(CurHeaderType);};
    size_t ReadCommentData(Array<byte> *CmtData,Array<wchar> *CmtDataW);
    void WriteCommentData(byte *Data,size_t DataSize,bool FileComment);
    RAROptions* GetRAROptions() {return(Cmd);}
    void SetSilentOpen(bool Mode) {SilentOpen=Mode;}

    BaseBlock ShortBlock;
    MainHeader NewMhd;
    FileHeader NewLhd;
    EndArcHeader EndArcHead;
    SubBlockHeader SubBlockHead;
    FileHeader SubHead;
    CommentHeader CommHead;
    ProtectHeader ProtectHead;
    AVHeader AVHead;
    SignHeader SignHead;
    UnixOwnersHeader UOHead;
    MacFInfoHeader MACHead;
    EAHeader EAHead;
    StreamHeader StreamHead;

    int64 CurBlockPos;
    int64 NextBlockPos;

    bool OldFormat;
    bool Solid;
    bool Volume;
    bool MainComment;
    bool Locked;
    bool Signed;
    bool NotFirstVolume;
    bool Protected;
    bool Encrypted;
    size_t SFXSize;
    bool BrokenFileHeader;

    bool Splitting;

    ushort HeaderCRC;

    int64 VolWrite;
    int64 AddingFilesSize;
    size_t AddingHeadersSize;

    bool NewArchive;

    char FirstVolumeName[NM];
    wchar FirstVolumeNameW[NM];
};

#endif
