#ifndef __MDFN_STATE_H
#define __MDFN_STATE_H

#include "video.h"
#include "state-common.h"
#include "Stream.h"

#include <exception>

void MDFNSS_GetStateInfo(const char *filename, StateStatusStruct *status);

struct StateMem
{
 StateMem(Stream*s, int64 bnd = 0, bool svbe_ = false) : st(s), sss_bound(bnd), svbe(svbe_) { };
 ~StateMem();

 Stream* st = NULL;
 uint64 sss_bound = 0;	// State section search boundary, for state loading only.
 bool svbe = false;	// State variable data is stored big-endian(for normal-path state loading only).

 std::exception_ptr deferred_error;
 void ThrowDeferred(void);
};

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

// Flag for a single, >= 1 byte native-endian variable
#define MDFNSTATE_RLSB            0x80000000

// 32-bit native-endian elements
#define MDFNSTATE_RLSB32          0x40000000

// 16-bit native-endian elements
#define MDFNSTATE_RLSB16          0x20000000

// 64-bit native-endian elements
#define MDFNSTATE_RLSB64          0x10000000

#define MDFNSTATE_BOOL		  0x08000000


//// Array of structures
//#define MDFNSTATE_ARRAYOFS	  0x04000000

typedef struct {
           void *v;		// Pointer to the variable/array
           uint32 size;		// Length, in bytes, of the data to be saved EXCEPT:
				//  In the case of MDFNSTATE_BOOL, it is the number of bool elements to save(bool is not always 1-byte).
				// If 0, the subchunk isn't saved.
	   uint32 flags;	// Flags
	   const char *name;	// Name
	   //uint32 struct_size;	// Only used for MDFNSTATE_ARRAYOFS, sizeof(struct) that members of the linked SFORMAT struct are in.
} SFORMAT;

static INLINE bool SF_IS_BOOL(bool *) { return(1); }
static INLINE bool SF_IS_BOOL(void *) { return(0); }

static INLINE uint32 SF_FORCE_AB(bool *) { return(0); }

static INLINE uint32 SF_FORCE_A8(int8 *) { return(0); }
static INLINE uint32 SF_FORCE_A8(uint8 *) { return(0); }

static INLINE uint32 SF_FORCE_A16(int16 *) { return(0); }
static INLINE uint32 SF_FORCE_A16(uint16 *) { return(0); }

static INLINE uint32 SF_FORCE_A32(int32 *) { return(0); }
static INLINE uint32 SF_FORCE_A32(uint32 *) { return(0); }

static INLINE uint32 SF_FORCE_A64(int64 *) { return(0); }
static INLINE uint32 SF_FORCE_A64(uint64 *) { return(0); }

static INLINE uint32 SF_FORCE_D(double *) { return(0); }

template<typename T>
static INLINE int SF_VAR_OK(const T*)
{
 static_assert(std::is_same<T, bool>::value || sizeof(T) == 1 || sizeof(T) == 2 || sizeof(T) == 4 || sizeof(T) == 8, "Bad save state variable.");
 return 0;
}

#define SFVARN(x, n) { &(x), SF_IS_BOOL(&(x)) ? 1U : (uint32)sizeof(x), MDFNSTATE_RLSB | (SF_IS_BOOL(&(x)) ? MDFNSTATE_BOOL : 0) | SF_VAR_OK(&(x)), n }
#define SFVAR(x) SFVARN((x), #x)

#define SFARRAYN(x, l, n) { (x), (uint32)(l), 0 | SF_FORCE_A8(x), n }
#define SFARRAY(x, l) SFARRAYN((x), (l), #x)

#define SFARRAYBN(x, l, n) { (x), (uint32)(l), MDFNSTATE_BOOL | SF_FORCE_AB(x), n }
#define SFARRAYB(x, l) SFARRAYBN((x), (l), #x)

#define SFARRAY16N(x, l, n) { (x), (uint32)((l) * sizeof(uint16)), MDFNSTATE_RLSB16 | SF_FORCE_A16(x), n }
#define SFARRAY16(x, l) SFARRAY16N((x), (l), #x)

#define SFARRAY32N(x, l, n) { (x), (uint32)((l) * sizeof(uint32)), MDFNSTATE_RLSB32 | SF_FORCE_A32(x), n }
#define SFARRAY32(x, l) SFARRAY32N((x), (l), #x)

#define SFARRAY64N(x, l, n) { (x), (uint32)((l) * sizeof(uint64)), MDFNSTATE_RLSB64 | SF_FORCE_A64(x), n }
#define SFARRAY64(x, l) SFARRAY64N((x), (l), #x)

#if SIZEOF_DOUBLE != 8
#error "sizeof(double) != 8"
#endif

#define SFARRAYDN(x, l, n) { (x), (uint32)((l) * 8), MDFNSTATE_RLSB64 | SF_FORCE_D(x), n }
#define SFARRAYD(x, l) SFARRAYDN((x), (l), #x)

#define SFEND { 0, 0, 0, 0 }

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
bool MDFNSS_StateAction(StateMem *sm, const unsigned load, const bool data_only, SFORMAT *sf, const char *name, const bool optional = false) noexcept;

#endif
