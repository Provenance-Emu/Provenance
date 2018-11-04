/*

Copyright 1996, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABIL-
ITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT
SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABIL-
ITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization from
The Open Group.

*/

/*
 * This header file has the sole purpose of allowing the inclusion of
 * windows.h without getting any name conflicts with X headers code, by
 * renaming the conflicting definitions from windows.h
 *
 * Some (non-Microsoft) versions of the Windows API headers actually avoid
 * making the conflicting definitions if XFree86Server is defined, so we
 * need to remember if that was defined and undefine it during including
 * windows.h (so the conflicting definitions get wrapped correctly), and
 * then redefine it afterwards...
 *
 * There doesn't seem to be a good way to wrap the min/max macros from
 * windows.h, so we simply avoid defining them completely, allowing any
 * pre-existing definition to stand.
 *
 */

#undef _XFree86Server
#ifdef XFree86Server
# define _XFree86Server
# undef XFree86Server
#endif

#define NOMINMAX
#define BOOL wBOOL
#define INT32 wINT32
#undef Status
#define Status wStatus
#define ATOM wATOM
#define BYTE wBYTE
#define FreeResource wFreeResource
#include <windows.h>
#undef NOMINMAX
#undef Status
#define Status int
#undef BYTE
#undef BOOL
#undef INT32
#undef ATOM
#undef FreeResource
#undef CreateWindowA

#ifdef RESOURCE_H
# undef RT_FONT
# undef RT_CURSOR
# define RT_FONT         ((RESTYPE)4)
# define RT_CURSOR       ((RESTYPE)5)
#endif

#ifndef __CYGWIN__
#define sleep(x) Sleep((x) * 1000)
#endif

#if defined(WIN32) && (!defined(PATH_MAX) || PATH_MAX < 1024)
# undef PATH_MAX
# define PATH_MAX 1024
#endif

#ifdef _XFree86Server
# define XFree86Server
# undef _XFree86Server
#endif

