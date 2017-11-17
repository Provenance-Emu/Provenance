#ifndef _RAR_STRFN_
#define _RAR_STRFN_

const char *NullToEmpty(const char *Str);
const wchar *NullToEmpty(const wchar *Str);
char *IntNameToExt(const char *Name);
void ExtToInt(const char *Src,char *Dest);
void IntToExt(const char *Src,char *Dest);
char* strlower(char *Str);
char* strupper(char *Str);
int stricomp(const char *Str1,const char *Str2);
int strnicomp(const char *Str1,const char *Str2,size_t N);
char* RemoveEOL(char *Str);
char* RemoveLF(char *Str);
unsigned char loctolower(unsigned char ch);
unsigned char loctoupper(unsigned char ch);

char* strncpyz(char *dest, const char *src, size_t maxlen);
wchar* strncpyzw(wchar *dest, const wchar *src, size_t maxlen);

unsigned char etoupper(unsigned char ch);
wchar etoupperw(wchar ch);

bool IsDigit(int ch);
bool IsSpace(int ch);



bool LowAscii(const char *Str);
bool LowAscii(const wchar *Str);


int stricompc(const char *Str1,const char *Str2);
#ifndef SFX_MODULE
int stricompcw(const wchar *Str1,const wchar *Str2);
#endif

void itoa(int64 n,char *Str);
int64 atoil(char *Str);

#endif
