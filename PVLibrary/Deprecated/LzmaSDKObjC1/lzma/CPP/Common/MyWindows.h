// MyWindows.h

#ifndef __MY_WINDOWS_H
#define __MY_WINDOWS_H

#include "../../../src/LzmaAppleCommon.h"

#ifdef _WIN32

#include <windows.h>

#ifdef UNDER_CE
  #undef VARIANT_TRUE
  #define VARIANT_TRUE ((VARIANT_BOOL)-1)
#endif

#else

#include <stddef.h> // for wchar_t
#include <string.h>
// #include <stdint.h> // for uintptr_t

#include "MyGuidDef.h"

#define WINAPI

typedef char CHAR;
typedef unsigned char UCHAR;

#undef BYTE
typedef unsigned char BYTE;

typedef short SHORT;
typedef unsigned short USHORT;

#undef WORD
typedef unsigned short WORD;
typedef short VARIANT_BOOL;

typedef int INT;
typedef Int32 INT32;
typedef unsigned int UINT;
typedef UInt32 UINT32;
typedef INT32 LONG;   // LONG, ULONG and DWORD must be 32-bit
typedef UINT32 ULONG;

#undef DWORD

#if defined(__APPLE__)
#ifndef DWORD_SIZE
#define DWORD_SIZE 4
typedef uint32_t DWORD;
#endif
#else
typedef UINT32 DWORD;
#endif

//typedef long BOOL;

#ifndef FALSE
  #define FALSE 0
  #define TRUE 1
#endif

// typedef size_t ULONG_PTR;
typedef size_t DWORD_PTR;
// typedef uintptr_t UINT_PTR;
// typedef ptrdiff_t UINT_PTR;

typedef Int64 LONGLONG;
typedef UInt64 ULONGLONG;

typedef struct _LARGE_INTEGER { LONGLONG QuadPart; } LARGE_INTEGER;
typedef struct _ULARGE_INTEGER { ULONGLONG QuadPart; } ULARGE_INTEGER;

typedef const CHAR *LPCSTR;
typedef CHAR TCHAR;
typedef const TCHAR *LPCTSTR;
typedef wchar_t WCHAR;
typedef WCHAR OLECHAR;
typedef const WCHAR *LPCWSTR;
typedef OLECHAR *BSTR;
typedef const OLECHAR *LPCOLESTR;
typedef OLECHAR *LPOLESTR;

#if defined(__APPLE__)
typedef CHAR *LPSTR;
typedef DWORD *LPDWORD;
typedef TCHAR *LPTSTR;
#if defined(__APPLE_64__)
typedef uint64_t ULONG_PTR;
#else
typedef unsigned long ULONG_PTR;
#endif
#endif

typedef struct _FILETIME final
{
  DWORD dwLowDateTime;
  DWORD dwHighDateTime;
} FILETIME;

#if defined(__APPLE__)
typedef struct _BY_HANDLE_FILE_INFORMATION final {
    DWORD    dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD    dwVolumeSerialNumber;
    DWORD    nFileSizeHigh;
    DWORD    nFileSizeLow;
    DWORD    nNumberOfLinks;
    DWORD    nFileIndexHigh;
    DWORD    nFileIndexLow;
} BY_HANDLE_FILE_INFORMATION, *PBY_HANDLE_FILE_INFORMATION, *LPBY_HANDLE_FILE_INFORMATION;

//typedef struct _OVERLAPPED {
//    ULONG_PTR Internal;
//    ULONG_PTR InternalHigh;
//    union {
//        struct {
//            DWORD Offset;
//            DWORD OffsetHigh;
//        };
//        PVOID  Pointer;
//    };
//    HANDLE    hEvent;
//} OVERLAPPED, *LPOVERLAPPED;
typedef enum _MEDIA_TYPE {
    Unknown         = 0x00,
    F5_1Pt2_512     = 0x01,
    F3_1Pt44_512    = 0x02,
    F3_2Pt88_512    = 0x03,
    F3_20Pt8_512    = 0x04,
    F3_720_512      = 0x05,
    F5_360_512      = 0x06,
    F5_320_512      = 0x07,
    F5_320_1024     = 0x08,
    F5_180_512      = 0x09,
    F5_160_512      = 0x0a,
    RemovableMedia  = 0x0b,
    FixedMedia      = 0x0c,
    F3_120M_512     = 0x0d,
    F3_640_512      = 0x0e,
    F5_640_512      = 0x0f,
    F5_720_512      = 0x10,
    F3_1Pt2_512     = 0x11,
    F3_1Pt23_1024   = 0x12,
    F5_1Pt23_1024   = 0x13,
    F3_128Mb_512    = 0x14,
    F3_230Mb_512    = 0x15,
    F8_256_128      = 0x16,
    F3_200Mb_512    = 0x17,
    F3_240M_512     = 0x18,
    F3_32M_512      = 0x19
} MEDIA_TYPE;
typedef struct _DISK_GEOMETRY final {
    LARGE_INTEGER Cylinders;
    MEDIA_TYPE    MediaType;
    DWORD         TracksPerCylinder;
    DWORD         SectorsPerTrack;
    DWORD         BytesPerSector;
} DISK_GEOMETRY;
typedef struct _SYSTEMTIME final {
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
} SYSTEMTIME, *PSYSTEMTIME;
#define FILE_ATTRIBUTE_READONLY             1
#define FILE_ATTRIBUTE_HIDDEN               2
#define FILE_ATTRIBUTE_SYSTEM               4
#define FILE_ATTRIBUTE_DIRECTORY           16
#define FILE_ATTRIBUTE_ARCHIVE             32
#define FILE_ATTRIBUTE_DEVICE              64
#define FILE_ATTRIBUTE_NORMAL             128
#define FILE_ATTRIBUTE_TEMPORARY          256
#define FILE_ATTRIBUTE_SPARSE_FILE        512
#define FILE_ATTRIBUTE_REPARSE_POINT     1024
#define FILE_ATTRIBUTE_COMPRESSED        2048
#define FILE_ATTRIBUTE_OFFLINE          0x1000
#define FILE_ATTRIBUTE_ENCRYPTED        0x4000
#define FILE_ATTRIBUTE_UNIX_EXTENSION   0x8000   /* trick for Unix */
#define INVALID_HANDLE_VALUE 0
#define STATUS_SUCCESS                   0x00000000

#define TICKSPERSEC        10000000
#define TICKSPERMSEC       10000
#define SECSPERDAY         86400
#define SECSPERHOUR        3600
#define SECSPERMIN         60
#define MINSPERHOUR        60
#define HOURSPERDAY        24
#define EPOCHWEEKDAY       1  /* Jan 1, 1601 was Monday */
#define DAYSPERWEEK        7
#define EPOCHYEAR          1601
#define DAYSPERNORMALYEAR  365
#define DAYSPERLEAPYEAR    366
#define MONSPERYEAR        12
#define DAYSPERQUADRICENTENNIUM (365 * 400 + 97)
#define DAYSPERNORMALCENTURY (365 * 100 + 24)
#define DAYSPERNORMALQUADRENNIUM (365 * 4 + 1)

/* 1601 to 1970 is 369 years plus 89 leap days */
#define SECS_1601_TO_1970  ((369 * 365 + 89) * (ULONGLONG)SECSPERDAY)
#define TICKS_1601_TO_1970 (SECS_1601_TO_1970 * TICKSPERSEC)
/* 1601 to 1980 is 379 years plus 91 leap days */
#define SECS_1601_TO_1980  ((379 * 365 + 91) * (ULONGLONG)SECSPERDAY)
#define TICKS_1601_TO_1980 (SECS_1601_TO_1980 * TICKSPERSEC)

#define EBADF           9                // Bad file number
#define EINTR           4                // Interrupted system call
#define NO_ERROR                    0L
#define ERROR_ALREADY_EXISTS        EEXIST
#define ERROR_FILE_EXISTS           EEXIST
#define ERROR_INVALID_HANDLE        EBADF
#define ERROR_PATH_NOT_FOUND        ENOENT
#define ERROR_DISK_FULL             ENOSPC
#define ERROR_NO_MORE_FILES         0x100123 // FIXME
#define WAIT_TIMEOUT                ETIMEDOUT
#define WAIT_OBJECT_0 0
#define INFINITE    0xFFFFFFFF
#define ERROR_NEGATIVE_SEEK 131L
#ifndef FALSE
#define FALSE 0
#endif

#ifndef TRUE
#define TRUE 1
#endif

#ifndef MAX_PATHNAME_LEN
#define MAX_PATHNAME_LEN 1024
#endif

#ifndef MAX_PATH
#define MAX_PATH MAX_PATHNAME_LEN
#endif

#endif

#define HRESULT LONG
#define FAILED(Status) ((HRESULT)(Status)<0)
typedef ULONG PROPID;
typedef LONG SCODE;

#define ERROR_NEGATIVE_SEEK 131L

#define S_OK    ((HRESULT)0x00000000L)
#define S_FALSE ((HRESULT)0x00000001L)
#define E_NOTIMPL ((HRESULT)0x80004001L)
#define E_NOINTERFACE ((HRESULT)0x80004002L)
#define E_ABORT ((HRESULT)0x80004004L)
#define E_FAIL ((HRESULT)0x80004005L)
#define STG_E_INVALIDFUNCTION ((HRESULT)0x80030001L)
#define E_OUTOFMEMORY ((HRESULT)0x8007000EL)
#define E_INVALIDARG ((HRESULT)0x80070057L)

#if defined(__APPLE__)
#define CLASS_E_CLASSNOTAVAILABLE ((HRESULT)0x80040111L)

//
// HRESULT_FROM_WIN32(x) used to be a macro, however we now run it as an inline function
// to prevent double evaluation of 'x'. If you still need the macro, you can use __HRESULT_FROM_WIN32(x)
//
#define __HRESULT_FROM_WIN32(x) ((HRESULT)(x) <= 0 ? ((HRESULT)(x)) : ((HRESULT) (((x) & 0x0000FFFF) | (FACILITY_WIN32 << 16) | 0x80000000)))
#define FACILITY_WIN32 0x0007
#ifndef __midl
inline HRESULT HRESULT_FROM_WIN32(unsigned long x) {
    return (HRESULT)(x) <= 0 ? (HRESULT)(x) : (HRESULT) (((x) & 0x0000FFFF) | (FACILITY_WIN32 << 16) | 0x80000000);
}
#else
#define HRESULT_FROM_WIN32(x) __HRESULT_FROM_WIN32(x)
#endif

#endif

#ifdef _MSC_VER
#define STDMETHODCALLTYPE __stdcall
#else
#define STDMETHODCALLTYPE
#endif

#define STDMETHOD_(t, f) virtual t STDMETHODCALLTYPE f
#define STDMETHOD(f) STDMETHOD_(HRESULT, f)
#define STDMETHODIMP_(type) type STDMETHODCALLTYPE
#define STDMETHODIMP STDMETHODIMP_(HRESULT)

#define PURE = 0

#define MIDL_INTERFACE(x) struct

#ifdef __cplusplus

DEFINE_GUID(IID_IUnknown,
0x00000000, 0x0000, 0x0000, 0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x46);
struct IUnknown
{
  STDMETHOD(QueryInterface) (REFIID iid, void **outObject) PURE;
  STDMETHOD_(ULONG, AddRef)() PURE;
  STDMETHOD_(ULONG, Release)() PURE;
  #ifndef _WIN32
  virtual ~IUnknown() {}
  #endif
};

typedef IUnknown *LPUNKNOWN;

#endif

#define VARIANT_TRUE ((VARIANT_BOOL)-1)
#define VARIANT_FALSE ((VARIANT_BOOL)0)

enum VARENUM
{
  VT_EMPTY = 0,
  VT_NULL = 1,
  VT_I2 = 2,
  VT_I4 = 3,
  VT_R4 = 4,
  VT_R8 = 5,
  VT_CY = 6,
  VT_DATE = 7,
  VT_BSTR = 8,
  VT_DISPATCH = 9,
  VT_ERROR = 10,
  VT_BOOL = 11,
  VT_VARIANT = 12,
  VT_UNKNOWN = 13,
  VT_DECIMAL = 14,
  VT_I1 = 16,
  VT_UI1 = 17,
  VT_UI2 = 18,
  VT_UI4 = 19,
  VT_I8 = 20,
  VT_UI8 = 21,
  VT_INT = 22,
  VT_UINT = 23,
  VT_VOID = 24,
  VT_HRESULT = 25,
  VT_FILETIME = 64
};

typedef unsigned short VARTYPE;
typedef WORD PROPVAR_PAD1;
typedef WORD PROPVAR_PAD2;
typedef WORD PROPVAR_PAD3;

typedef struct tagPROPVARIANT
{
  VARTYPE vt;
  PROPVAR_PAD1 wReserved1;
  PROPVAR_PAD2 wReserved2;
  PROPVAR_PAD3 wReserved3;
  union
  {
    CHAR cVal;
    UCHAR bVal;
    SHORT iVal;
    USHORT uiVal;
    LONG lVal;
    ULONG ulVal;
    INT intVal;
    UINT uintVal;
    LARGE_INTEGER hVal;
    ULARGE_INTEGER uhVal;
    VARIANT_BOOL boolVal;
    SCODE scode;
    FILETIME filetime;
    BSTR bstrVal;
  };
} PROPVARIANT;

typedef PROPVARIANT tagVARIANT;
typedef tagVARIANT VARIANT;
typedef VARIANT VARIANTARG;

MY_EXTERN_C HRESULT VariantClear(VARIANTARG *prop);
MY_EXTERN_C HRESULT VariantCopy(VARIANTARG *dest, const VARIANTARG *src);

typedef struct tagSTATPROPSTG final
{
  LPOLESTR lpwstrName;
  PROPID propid;
  VARTYPE vt;
} STATPROPSTG;

MY_EXTERN_C BSTR SysAllocStringByteLen(LPCSTR psz, UINT len);
MY_EXTERN_C BSTR SysAllocStringLen(const OLECHAR *sz, UINT len);
MY_EXTERN_C BSTR SysAllocString(const OLECHAR *sz);
MY_EXTERN_C void SysFreeString(BSTR bstr);
MY_EXTERN_C UINT SysStringByteLen(BSTR bstr);
MY_EXTERN_C UINT SysStringLen(BSTR bstr);

//MY_EXTERN_C DWORD GetLastError();
MY_EXTERN_C LONG CompareFileTime(const FILETIME* ft1, const FILETIME* ft2);

#if defined(__APPLE__)
DWORD WINAPI WaitForMultipleObjects(DWORD count, const HANDLE *handles, BoolInt wait_all, DWORD timeout);
BoolInt WINAPI RtlTimeToSecondsSince1970(const LARGE_INTEGER *Time, DWORD *Seconds);
DWORD WINAPI GetTickCount(void);
const TCHAR kAnyStringWildcard = '*';
#endif

#define CP_ACP    0
#define CP_OEMCP  1
#define CP_UTF8   65001

typedef enum tagSTREAM_SEEK
{
  STREAM_SEEK_SET = 0,
  STREAM_SEEK_CUR = 1,
  STREAM_SEEK_END = 2
} STREAM_SEEK;

#endif
#endif
