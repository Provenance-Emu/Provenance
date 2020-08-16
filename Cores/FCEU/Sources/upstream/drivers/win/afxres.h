#ifndef _AFXRES_H
#define _AFXRES_H
#if __GNUC__ >= 3
#pragma GCC system_header

// MINGW hack for Commctrl.h
#define _WIN32_IE	0x0600
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _WINDOWS_H
#include <windows.h>
#endif

/* IDC_STATIC is documented in winuser.h, but not defined. */
#ifndef IDC_STATIC
#define IDC_STATIC (-1)
#endif

#ifdef __cplusplus
}
#endif
#endif
