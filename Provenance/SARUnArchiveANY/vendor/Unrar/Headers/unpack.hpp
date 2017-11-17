#ifndef _RAR_UNPACK_
#define _RAR_UNPACK_

enum BLOCK_TYPES {BLOCK_LZ,BLOCK_PPM};

struct Decode
{
  unsigned int MaxNum;
  unsigned int DecodeLen[16];
  unsigned int DecodePos[16];
  unsigned int DecodeNum[2];
};

struct LitDecode
{
  unsigned int MaxNum;
  unsigned int DecodeLen[16];
  unsigned int DecodePos[16];
  unsigned int DecodeNum[NC];
};

struct DistDecode
{
  unsigned int MaxNum;
  unsigned int DecodeLen[16];
  unsigned int DecodePos[16];
  unsigned int DecodeNum[DC];
};

struct LowDistDecode
{
  unsigned int MaxNum;
  unsigned int DecodeLen[16];
  unsigned int DecodePos[16];
  unsigned int DecodeNum[LDC];
};

struct RepDecode
{
  unsigned int MaxNum;
  unsigned int DecodeLen[16];
  unsigned int DecodePos[16];
  unsigned int DecodeNum[RC];
};

struct BitDecode
{
  unsigned int MaxNum;
  unsigned int DecodeLen[16];
  unsigned int DecodePos[16];
  unsigned int DecodeNum[BC];
};

struct UnpackFilter
{
  unsigned int BlockStart;
  unsigned int BlockLength;
  unsigned int ExecCount;
  bool NextWindow;

  // position of parent filter in Filters array used as prototype for filter
  // in PrgStack array. Not defined for filters in Filters array.
  unsigned int ParentFilter;

  VM_PreparedProgram Prg;
};

/***************************** Unpack v 2.0 *********************************/
struct MultDecode
{
  unsigned int MaxNum;
  unsigned int DecodeLen[16];
  unsigned int DecodePos[16];
  unsigned int DecodeNum[MC20];
};

struct AudioVariables
{
  int K1,K2,K3,K4,K5;
  int D1,D2,D3,D4;
  int LastDelta;
  unsigned int Dif[11];
  unsigned int ByteCount;
  int LastChar;
};
/***************************** Unpack v 2.0 *********************************/


class Unpack:private BitInput
{
  private:
    friend class Pack;

    void Unpack29(bool Solid);
    bool UnpReadBuf();
    void UnpWriteBuf();
    void ExecuteCode(VM_PreparedProgram *Prg);
    void UnpWriteArea(unsigned int StartPtr,unsigned int EndPtr);
    void UnpWriteData(byte *Data,size_t Size);
    bool ReadTables();
    void MakeDecodeTables(unsigned char *LenTab,struct Decode *Dec,int Size);
    int DecodeNumber(struct Decode *Dec);
    inline int SafePPMDecodeChar();
    void CopyString();
    inline void InsertOldDist(unsigned int Distance);
    inline void InsertLastMatch(unsigned int Length,unsigned int Distance);
    void UnpInitData(int Solid);
    void CopyString(unsigned int Length,unsigned int Distance);
    bool ReadEndOfBlock();
    bool ReadVMCode();
    bool ReadVMCodePPM();
    bool AddVMCode(unsigned int FirstByte,byte *Code,int CodeSize);
    void InitFilters();

    ComprDataIO *UnpIO;
    ModelPPM PPM;
    int PPMEscChar;

    RarVM VM;

    /* Filters code, one entry per filter */
    Array<UnpackFilter*> Filters;

    /* Filters stack, several entrances of same filter are possible */
    Array<UnpackFilter*> PrgStack;

    /* lengths of preceding blocks, one length per filter. Used to reduce
       size required to write block length if lengths are repeating */
    Array<int> OldFilterLengths;

    int LastFilter;

    bool TablesRead;
    struct LitDecode LD;
    struct DistDecode DD;
    struct LowDistDecode LDD;
    struct RepDecode RD;
    struct BitDecode BD;

    unsigned int OldDist[4],OldDistPtr;
    unsigned int LastDist,LastLength;

    unsigned int UnpPtr,WrPtr;
    
    // Top border of read packed data.
    int ReadTop; 

    // Border to call UnpReadBuf. We use it instead of (ReadTop-C)
    // for optimization reasons. Ensures that we have C bytes in buffer
    // unless we are at the end of file.
    int ReadBorder;

    unsigned char UnpOldTable[HUFF_TABLE_SIZE];

    int UnpBlockType;

    byte *Window;
    bool ExternalWindow;


    int64 DestUnpSize;

    bool Suspended;
    bool UnpAllBuf;
    bool UnpSomeRead;
    int64 WrittenFileSize;
    bool FileExtracted;

    int PrevLowDist,LowDistRepCount;

/***************************** Unpack v 1.5 *********************************/
    void Unpack15(bool Solid);
    void ShortLZ();
    void LongLZ();
    void HuffDecode();
    void GetFlagsBuf();
    void OldUnpInitData(int Solid);
    void InitHuff();
    void CorrHuff(unsigned int *CharSet,unsigned int *NumToPlace);
    void OldCopyString(unsigned int Distance,unsigned int Length);
    uint DecodeNum(uint Num,uint StartPos,uint *DecTab,uint *PosTab);
    void OldUnpWriteBuf();

    unsigned int ChSet[256],ChSetA[256],ChSetB[256],ChSetC[256];
    unsigned int Place[256],PlaceA[256],PlaceB[256],PlaceC[256];
    unsigned int NToPl[256],NToPlB[256],NToPlC[256];
    unsigned int FlagBuf,AvrPlc,AvrPlcB,AvrLn1,AvrLn2,AvrLn3;
    int Buf60,NumHuf,StMode,LCount,FlagsCnt;
    unsigned int Nhfb,Nlzb,MaxDist3;
/***************************** Unpack v 1.5 *********************************/

/***************************** Unpack v 2.0 *********************************/
    void Unpack20(bool Solid);
    struct MultDecode MD[4];
    unsigned char UnpOldTable20[MC20*4];
    int UnpAudioBlock,UnpChannels,UnpCurChannel,UnpChannelDelta;
    void CopyString20(unsigned int Length,unsigned int Distance);
    bool ReadTables20();
    void UnpInitData20(int Solid);
    void ReadLastTables();
    byte DecodeAudio(int Delta);
    struct AudioVariables AudV[4];
/***************************** Unpack v 2.0 *********************************/

  public:
    Unpack(ComprDataIO *DataIO);
    ~Unpack();
    void Init(byte *Window=NULL);
    void DoUnpack(int Method,bool Solid);
    bool IsFileExtracted() {return(FileExtracted);}
    void SetDestSize(int64 DestSize) {DestUnpSize=DestSize;FileExtracted=false;}
    void SetSuspended(bool Suspended) {Unpack::Suspended=Suspended;}

    unsigned int GetChar()
    {
      if (InAddr>BitInput::MAX_SIZE-30)
        UnpReadBuf();
      return(InBuf[InAddr++]);
    }
};

#endif
