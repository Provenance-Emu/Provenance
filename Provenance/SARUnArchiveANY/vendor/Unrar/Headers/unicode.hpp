#ifndef _RAR_UNICODE_
#define _RAR_UNICODE_

#ifndef _EMX
#define MBFUNCTIONS
#endif

#if defined(MBFUNCTIONS) || defined(_WIN_32) || defined(_EMX) && !defined(_DJGPP)
#define UNICODE_SUPPORTED
#endif

#ifdef _WIN_32
#define DBCS_SUPPORTED
#endif

#ifdef _EMX
int uni_init(int codepage);
int uni_done();
#endif

bool WideToChar(const wchar *Src,char *Dest,size_t DestSize=0x1000000);
bool CharToWide(const char *Src,wchar *Dest,size_t DestSize=0x1000000);
byte* WideToRaw(const wchar *Src,byte *Dest,size_t DestSize=0x1000000);
wchar* RawToWide(const byte *Src,wchar *Dest,size_t DestSize=0x1000000);
void WideToUtf(const wchar *Src,char *Dest,size_t DestSize);
void UtfToWide(const char *Src,wchar *Dest,size_t DestSize);
bool UnicodeEnabled();

size_t strlenw(const wchar *str);
wchar* strcpyw(wchar *dest,const wchar *src);
wchar* strncpyw(wchar *dest,const wchar *src,size_t n);
wchar* strcatw(wchar *dest,const wchar *src);
wchar* strncatw(wchar *dest,const wchar *src,size_t n);
int strcmpw(const wchar *s1,const wchar *s2);
int strncmpw(const wchar *s1,const wchar *s2,size_t n);
int stricmpw(const wchar *s1,const wchar *s2);
int strnicmpw(const wchar *s1,const wchar *s2,size_t n);
wchar *strchrw(const wchar *s,int c);
wchar* strrchrw(const wchar *s,int c);
wchar* strpbrkw(const wchar *s1,const wchar *s2);
wchar* strlowerw(wchar *Str);
wchar* strupperw(wchar *Str);
wchar* strdupw(const wchar *Str);
int toupperw(int ch);
int atoiw(const wchar *s);

#ifdef DBCS_SUPPORTED
class SupportDBCS
{
  public:
    SupportDBCS();
    void Init();

    char* charnext(const char *s);
    size_t strlend(const char *s);
    char *strchrd(const char *s, int c);
    char *strrchrd(const char *s, int c);
    void copychrd(char *dest,const char *src);

    bool IsLeadByte[256];
    bool DBCSMode;
};

extern SupportDBCS gdbcs;

inline char* charnext(const char *s) {return (char *)(gdbcs.DBCSMode ? gdbcs.charnext(s):s+1);}
inline size_t strlend(const char *s) {return (uint)(gdbcs.DBCSMode ? gdbcs.strlend(s):strlen(s));}
inline char* strchrd(const char *s, int c) {return (char *)(gdbcs.DBCSMode ? gdbcs.strchrd(s,c):strchr(s,c));}
inline char* strrchrd(const char *s, int c) {return (char *)(gdbcs.DBCSMode ? gdbcs.strrchrd(s,c):strrchr(s,c));}
inline void copychrd(char *dest,const char *src) {if (gdbcs.DBCSMode) gdbcs.copychrd(dest,src); else *dest=*src;}
inline bool IsDBCSMode() {return(gdbcs.DBCSMode);}
inline void InitDBCS() {gdbcs.Init();}

#else
#define charnext(s) ((s)+1)
#define strlend strlen
#define strchrd strchr
#define strrchrd strrchr
#define IsDBCSMode() (true)
inline void copychrd(char *dest,const char *src) {*dest=*src;}
#endif

#endif
