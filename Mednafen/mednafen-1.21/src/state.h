/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* state.h:
**  Copyright (C) 2005-2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

#ifndef __MDFN_STATE_H
#define __MDFN_STATE_H

#include "video.h"
#include "state-common.h"
#include "Stream.h"

void MDFNSS_GetStateInfo(const std::string& path, StateStatusStruct* status);

struct StateMem;
//
// "st" should be MemoryStream, or FileStream if running in a memory-constrained system.  GZFileStream won't work properly due to 
// the save state saving code relying on reverse-seeking.
//
// Pass 'true' for data_only to get faster and leaner save states, at the expense of cross-version and cross-platform compatibility(it's mainly intended for
// realtime state rewinding).
//
// On entry, the position of 'st' IS permitted to be greater than 0.
//
// Assuming no errors, and data_only is 'false', the position of 'st' will be just beyond the end of the save state on return.
//
// throws exceptions on errors.
//
void MDFNSS_SaveSM(Stream *st, bool data_only = false, const MDFN_Surface *surface = (MDFN_Surface *)NULL, const MDFN_Rect *DisplayRect = (MDFN_Rect*)NULL, const int32 *LineWidths = (int32*)NULL);
void MDFNSS_LoadSM(Stream *st, bool data_only = false);

void MDFNSS_CheckStates(void);

struct SFORMAT
{
	const char* name;	// Name;
	void* data;		// Pointer to the variable/array
	uint32 size;		// Length, in bytes, of the data to be saved EXCEPT:
				//  In the case of 'bool' it is the number of bool elements to save(bool is not always 1-byte).
				// If 0, the subchunk isn't saved.
	uint32 type;		// Type/element size; 0(bool), 1, 2, 4, 8
	uint32 repcount;
	uint32 repstride;
};

static INLINE int8* SF_FORCE_A8(int8* p) { return p; }
static INLINE uint8* SF_FORCE_A8(uint8* p) { return p; }

static INLINE int16* SF_FORCE_A16(int16* p) { return p; }
static INLINE uint16* SF_FORCE_A16(uint16* p) { return p; }

static INLINE int32* SF_FORCE_A32(int32* p) { return p; }
static INLINE uint32* SF_FORCE_A32(uint32* p) { return p; }

static INLINE int64* SF_FORCE_A64(int64* p) { return p; }
static INLINE uint64* SF_FORCE_A64(uint64* p) { return p; }

template<typename T>
static INLINE void SF_FORCE_ANY(typename std::enable_if<!std::is_enum<T>::value>::type* = nullptr)
{
 static_assert(	std::is_same<T, bool>::value ||
		std::is_same<T, int8>::value || std::is_same<T, uint8>::value ||
		std::is_same<T, int16>::value || std::is_same<T, uint16>::value ||
		std::is_same<T, int32>::value || std::is_same<T, uint32>::value || std::is_same<T, float>::value ||
		std::is_same<T, int64>::value || std::is_same<T, uint64>::value || std::is_same<T, double>::value, "Unsupported type");
}

template<typename T>
static INLINE void SF_FORCE_ANY(typename std::enable_if<std::is_enum<T>::value>::type* = nullptr)
{
 SF_FORCE_ANY<typename std::underlying_type<T>::type>();
}

template<typename IT>
static INLINE SFORMAT SFBASE_(IT* const iv, uint32 icount, const uint32 totalcount, const size_t repstride, void* repbase, const char* const name)
{
 typedef typename std::remove_all_extents<IT>::type T;
 uint32 count = icount * (sizeof(IT) / sizeof(T));
 SF_FORCE_ANY<T>();
 //
 //
 SFORMAT ret;

 ret.data = iv ? (char*)repbase + ((char*)iv - (char*)repbase) : nullptr;
 ret.name = name;
 ret.repcount = totalcount - 1;
 ret.repstride = repstride;
 if(std::is_same<T, bool>::value)
 {
  ret.size = count;
  ret.type = 0;
 }
 else
 {
  ret.size = sizeof(T) * count;
  ret.type = sizeof(T);
 }

 return ret;
}

/*
 Probably a bad idea unless we prevent derived classes.

template<typename IT>
static INLINE SFORMAT SFBASE_(std::array<IT, N>* iv, uint32 icount, const uint32 totalcount, const size_t repstride, void* repbase, const char* const name)
{
 return SFBASE_(iv->data(), icount * N, totalcount, repstride, repbase, name);
}
*/

template<typename T>
static INLINE SFORMAT SFBASE_(T* const v, const uint32 count, const char* const name)
{
 return SFBASE_(v, count, 1, 0, v, name);
}

#define SFVARN(x, ...)	SFBASE_(&(x), 1, __VA_ARGS__)

#define SFVAR1_(x)	   SFVARN((x), #x)
#define SFVAR4_(x, tc, rs, rb) SFVARN((x), tc, rs, rb, #x)
#define SFVAR_(a, b, c, d, e, ...)	e
#define SFVAR(...) 	SFVAR_(__VA_ARGS__, SFVAR4_, SFVAR3_, SFVAR2_, SFVAR1_, SFVAR0_)(__VA_ARGS__)

#if SIZEOF_DOUBLE != 8
 #error "sizeof(double) != 8"
#endif

#define SFPTR8N(x, ...)		SFBASE_(SF_FORCE_A8(x), __VA_ARGS__)
#define SFPTR8(x, ...)		SFBASE_(SF_FORCE_A8(x), __VA_ARGS__, #x)

#define SFPTRBN(x, ...)		SFBASE_<bool>((x), __VA_ARGS__)
#define SFPTRB(x, ...)		SFBASE_<bool>((x), __VA_ARGS__, #x)

#define SFPTR16N(x, ...)	SFBASE_(SF_FORCE_A16(x), __VA_ARGS__)
#define SFPTR16(x, ...)		SFBASE_(SF_FORCE_A16(x), __VA_ARGS__, #x)

#define SFPTR32N(x, ...)	SFBASE_(SF_FORCE_A32(x), __VA_ARGS__)
#define SFPTR32(x, ...)		SFBASE_(SF_FORCE_A32(x), __VA_ARGS__, #x)

#define SFPTR64N(x, ...)	SFBASE_(SF_FORCE_A64(x), __VA_ARGS__)
#define SFPTR64(x, ...)		SFBASE_(SF_FORCE_A64(x), __VA_ARGS__, #x)

#define SFPTRFN(x, ...)		SFBASE_<float>((x), __VA_ARGS__)
#define SFPTRF(x, ...)		SFBASE_<float>((x), __VA_ARGS__, #x)

#define SFPTRDN(x, ...)		SFBASE_<double>((x), __VA_ARGS__)
#define SFPTRD(x, ...)		SFBASE_<double>((x), __VA_ARGS__, #x)

#define SFLINK(x) { nullptr, (x), ~0U, 0, 0, 0 }

#define SFEND { nullptr, nullptr, 0, 0, 0, 0 }

//
// 'load' is 0 on save, and the version numeric contained in the save state on load.
//
// ALWAYS returns 'true' when 'load' is 0(saving), regardless of errors.
//
// When 'load' is non-zero:
//	Normally returns true, but if the section was not found and optional was true, returns false.
//
// 	If an error occurs(such as memory allocation error, stream error, or section-missing error when optional == false), this function
// 	marks deferred error status in *sm, and that call and all future calls with that particular *sm will return false.
//
// Does NOT throw exceptions, and must NOT throw exceptions, in order to make sure the emulation-module-specific loaded-variable sanitizing code
// is run.
//
bool MDFNSS_StateAction(StateMem *sm, const unsigned load, const bool data_only, const SFORMAT *sf, const char *name, const bool optional = false) noexcept;

#endif
