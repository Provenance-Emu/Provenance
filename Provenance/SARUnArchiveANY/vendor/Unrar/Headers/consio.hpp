#ifndef _RAR_CONSIO_
#define _RAR_CONSIO_

#if !defined(SILENT) && !defined(SFX_MODULE)
enum {SOUND_OK,SOUND_ALARM,SOUND_ERROR,SOUND_QUESTION};
#endif

enum PASSWORD_TYPE {PASSWORD_GLOBAL,PASSWORD_FILE,PASSWORD_ARCHIVE};

void InitConsoleOptions(MESSAGE_TYPE MsgStream,bool Sound);

#ifndef SILENT
void mprintf(const char *fmt,...);
void eprintf(const char *fmt,...);
void Alarm();
void GetPasswordText(char *Str,int MaxLength);
bool GetPassword(PASSWORD_TYPE Type,const char *FileName,char *Password,int MaxLength);
int Ask(const char *AskStr);
#endif

void OutComment(char *Comment,size_t Size);

#ifdef SILENT
#ifdef __GNUC__
  #define mprintf(args...)
  #define eprintf(args...)
#else
  #ifdef _MSC_VER
    inline void mprintf(const char *fmt,...) {}
  #else
    inline void mprintf(const char *fmt,const char *a=NULL,const char *b=NULL) {}
  #endif
  inline void eprintf(const char *fmt,const char *a=NULL,const char *b=NULL) {}
  inline void mprintf(const char *fmt,int b) {}
  inline void eprintf(const char *fmt,int b) {}
  inline void mprintf(const char *fmt,const char *a,int b) {}
  inline void eprintf(const char *fmt,const char *a,int b) {}
#endif
inline void Alarm() {}
inline void GetPasswordText(char *Str,int MaxLength) {}
inline unsigned int GetKey() {return(0);}
inline bool GetPassword(PASSWORD_TYPE Type,const char *FileName,char *Password,int MaxLength) {return(false);}
inline int Ask(const char *AskStr) {return(0);}
#endif

#endif
