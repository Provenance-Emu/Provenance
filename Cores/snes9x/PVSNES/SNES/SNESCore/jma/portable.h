/*
Copyright (C) 2004 NSRT Team ( http://nsrt.edgeemu.com )
Copyright (C) 2002 Andrea Mazzoleni ( http://advancemame.sf.net )

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/


#ifndef __PORTABLE_H
#define __PORTABLE_H

#include <string.h>

typedef signed char INT8;
typedef unsigned char UINT8;
typedef short INT16;
typedef unsigned short UINT16;
typedef long INT32;
typedef unsigned long UINT32;
typedef INT32 INT64;
typedef UINT32 UINT64;


typedef UINT8 BYTE;
typedef UINT16 WORD;
typedef UINT32 DWORD;

typedef unsigned UINT_PTR;

typedef int BOOL;
#define FALSE 0
#define TRUE 1

#define HRESULT int
#define S_OK 0
#define E_INVALIDARG -1
#define E_OUTOFMEMORY -2
#define E_FAIL -3
#define E_INTERNAL_ERROR -4
#define E_INVALIDDATA -5

template <class T> inline T MyMin(T a, T b) {
	return a < b ? a : b;
}

template <class T> inline T MyMax(T a, T b) {
	return a > b ? a : b;
}

#define RETURN_IF_NOT_S_OK(x) { HRESULT __aResult_ = (x); if(__aResult_ != S_OK) return __aResult_; }


#define UINT_SIZE (4)
#define USHORT_SIZE (2)

//Convert an array of 4 bytes back into an integer
inline unsigned int charp_to_uint(const unsigned char buffer[UINT_SIZE])
{
  unsigned int num = (unsigned int)buffer[3];
  num |= ((unsigned int)buffer[2]) << 8;
  num |= ((unsigned int)buffer[1]) << 16;
  num |= ((unsigned int)buffer[0]) << 24;
  return(num);
}

//Convert an array of 2 bytes back into a short integer
inline unsigned short charp_to_ushort(const unsigned char buffer[USHORT_SIZE])
{
  unsigned short num = (unsigned short)buffer[1];
  num |= ((unsigned short)buffer[0]) << 8;
  return(num);
}

#endif
