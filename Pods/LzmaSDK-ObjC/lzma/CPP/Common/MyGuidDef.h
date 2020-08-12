// Common/MyGuidDef.h

#ifndef GUID_DEFINED
#define GUID_DEFINED

#include "MyTypes.h"

typedef struct final {
  UInt32 Data1;
  UInt16 Data2;
  UInt16 Data3;
  unsigned char Data4[8];
} GUID;

#ifdef __cplusplus
#define REFGUID const GUID &
#else
#define REFGUID const GUID *
#endif

#define REFCLSID REFGUID
#define REFIID REFGUID

#ifdef __cplusplus
inline int operator==(REFGUID g1, REFGUID g2)
{
  for (int i = 0; i < (int)sizeof(g1); i++)
    if (((unsigned char *)&g1)[i] != ((unsigned char *)&g2)[i])
      return 0;
  return 1;
}
inline int operator!=(REFGUID g1, REFGUID g2) { return !(g1 == g2); }
#endif

#ifdef __cplusplus
  #define MY_EXTERN_C extern "C"
#else
  #define MY_EXTERN_C extern
#endif

#endif

#if defined(__APPLE__)
#ifdef ENV_HAVE_GCCVISIBILITYPATCH
#define DLLEXPORT __attribute__ ((visibility("default")))
#else
#define DLLEXPORT
#endif
#ifdef __cplusplus
#define STDAPI extern "C" DLLEXPORT HRESULT
#else
#define STDAPI extern DLLEXPORT HRESULT
#endif  /* __cplusplus */
typedef GUID IID;
typedef GUID CLSID;
#endif

#ifdef DEFINE_GUID
#undef DEFINE_GUID
#endif

#ifdef INITGUID
  #define DEFINE_GUID(name, l, w1, w2, b1, b2, b3, b4, b5, b6, b7, b8) \
    MY_EXTERN_C const GUID name = { l, w1, w2, { b1, b2, b3, b4, b5, b6, b7, b8 } }
#else
  #define DEFINE_GUID(name, l, w1, w2, b1, b2, b3, b4, b5, b6, b7, b8) \
    MY_EXTERN_C const GUID name
#endif

#define CONSTRUCT_GUID(l, w1, w2, b1, b2, b3, b4, b5, b6, b7, b8) { l, w1, w2, { b1, b2, b3, b4, b5, b6, b7, b8 } }
