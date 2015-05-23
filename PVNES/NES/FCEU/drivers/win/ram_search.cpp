// A few notes about this implementation of a RAM search window:
//
// Speed of update was one of the highest priories.
// This is because I wanted the RAM search window to be able to
// update every single value in RAM every single frame, and
// keep track of the exact number of frames across which each value has changed,
// without causing the emulation to run noticeably slower than normal.
//
// The data representation was changed from one entry per valid address
// to one entry per contiguous range of uneliminated addresses
// which references uniform pools of per-address properties.
// - This saves time when there are many items because
//   it minimizes the amount of data that needs to be stored and processed per address.
// - It also saves time when there are few items because
//   it ensures that no time is wasted in iterating through
//   addresses that have already been eliminated from the search.
//
// The worst-case scenario is when every other item has been
// eliminated from the search, maximizing the number of regions.
// This implementation manages to handle even that pathological case
// acceptably well. In fact, it still updates faster than the previous implementation.
// The time spent setting up or clearing such a large number of regions
// is somewhat horrendous, but it seems reasonable to have poor worst-case speed
// during these sporadic "setup" steps to achieve an all-around faster per-update speed.
// (You can test this case by performing the search: Modulo 2 Is Specific Address 0)


#include <windows.h>
#include "common.h"
#include "fceu.h"
#include "../../debug.h"

#include "resource.h"
#include "ram_search.h"
#include "ramwatch.h"
#include "cheat.h"
#include <assert.h>
#include <commctrl.h>
#include <list>
#include <vector>
#ifdef WIN32
	#include "BaseTsd.h"
	typedef INT_PTR intptr_t;
#else
	#include "stdint.h"
#endif
#include "memview.h"

bool ShowROM = false;

bool IsHardwareAddressValid(HWAddressType address)
{
	if (!GameInfo)
		return false;

	if(!ShowROM)
		if ((address >= 0x0000 && address < 0x0800) || (address >= 0x6000 && address < 0x8000))
			return true;
		else
			return false;
	else
		if (address >= 0x8000 && address < 0x10000)
			return true;
		else
			return false;
}
#define INVALID_HARDWARE_ADDRESS	((HWAddressType) -1)

struct MemoryRegion
{
	HWAddressType hardwareAddress; // hardware address of the start of this region
	unsigned int size; // number of bytes to the end of this region

	unsigned int virtualIndex; // index into s_prevValues, s_curValues, and s_numChanges, valid after being initialized in ResetMemoryRegions()
	unsigned int itemIndex; // index into listbox items, valid when s_itemIndicesInvalid is false
};

int MAX_RAM_SIZE = 0;
static unsigned char* s_prevValues = 0; // values at last search or reset
static unsigned char* s_curValues = 0; // values at last frame update
static unsigned short* s_numChanges = 0; // number of changes of the item starting at this virtual index address
static MemoryRegion** s_itemIndexToRegionPointer = 0; // used for random access into the memory list (trading memory size to get speed here, too bad it's so much memory), only valid when s_itemIndicesInvalid is false
static BOOL s_itemIndicesInvalid = true; // if true, the link from listbox items to memory regions (s_itemIndexToRegionPointer) and the link from memory regions to list box items (MemoryRegion::itemIndex) both need to be recalculated
static BOOL s_prevValuesNeedUpdate = true; // if true, the "prev" values should be updated using the "cur" values on the next frame update signaled
static unsigned int s_maxItemIndex = 0; // max currently valid item index, the listbox sometimes tries to update things past the end of the list so we need to know this to ignore those attempts

HWND RamSearchHWnd;
#define hWnd hAppWnd
#define hInst fceu_hInstance
static char Str_Tmp [1024];

int disableRamSearchUpdate = false;

// list of contiguous uneliminated memory regions
typedef std::list<MemoryRegion> MemoryList;
static MemoryList s_activeMemoryRegions;
static CRITICAL_SECTION s_activeMemoryRegionsCS;

// for undo support (could be better, but this way was really easy)
static MemoryList s_activeMemoryRegionsBackup;
static int s_undoType = 0; // 0 means can't undo, 1 means can undo, 2 means can redo

void RamSearchSaveUndoStateIfNotTooBig(HWND hDlg);
static const int tooManyRegionsForUndo = 10000;

void ResetMemoryRegions()
{
//	Clear_Sound_Buffer();
	EnterCriticalSection(&s_activeMemoryRegionsCS);

	s_activeMemoryRegions.clear();

	// use IsHardwareAddressValid to figure out what all the possible memory regions are,
	// split up wherever there's a discontinuity in the address in our software RAM.
	static const int regionSearchGranularity = 1; // if this is too small, we'll waste time (in this function only), but if any region in RAM isn't evenly divisible by this, we might crash.
	HWAddressType hwRegionStart = INVALID_HARDWARE_ADDRESS;
	HWAddressType hwRegionEnd = INVALID_HARDWARE_ADDRESS;
	for(HWAddressType addr = 0; addr != 0x10000+regionSearchGranularity; addr += regionSearchGranularity)
	{
		if (!IsHardwareAddressValid(addr)) {
			// create the region
			if (hwRegionStart != INVALID_HARDWARE_ADDRESS && hwRegionEnd != INVALID_HARDWARE_ADDRESS) {
				MemoryRegion region = { hwRegionStart, regionSearchGranularity + (hwRegionEnd - hwRegionStart) };
				s_activeMemoryRegions.push_back(region);
			}

			hwRegionStart = INVALID_HARDWARE_ADDRESS;
			hwRegionEnd = INVALID_HARDWARE_ADDRESS;
		}
		else {
			if (hwRegionStart != INVALID_HARDWARE_ADDRESS) {
				// continue region
				hwRegionEnd = addr;
			}
			else {
				// start new region
				hwRegionStart = addr;
				hwRegionEnd = addr;
			}
		}
	}


	int nextVirtualIndex = 0;
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); ++iter)
	{
		MemoryRegion& region = *iter;
		region.virtualIndex = nextVirtualIndex;
		nextVirtualIndex = region.virtualIndex + region.size;
	}
	//assert(nextVirtualIndex <= MAX_RAM_SIZE);

	if(nextVirtualIndex > MAX_RAM_SIZE)
	{
		s_prevValues = (unsigned char*)realloc(s_prevValues, sizeof(char)*(nextVirtualIndex+4));
		memset(s_prevValues, 0, sizeof(char)*(nextVirtualIndex+4));

		s_curValues = (unsigned char*)realloc(s_curValues, sizeof(char)*(nextVirtualIndex+4));
		memset(s_curValues, 0, sizeof(char)*(nextVirtualIndex+4));

		s_numChanges = (unsigned short*)realloc(s_numChanges, sizeof(short)*(nextVirtualIndex+4));
		memset(s_numChanges, 0, sizeof(short)*(nextVirtualIndex+4));

		s_itemIndexToRegionPointer = (MemoryRegion**)realloc(s_itemIndexToRegionPointer, sizeof(MemoryRegion*)*(nextVirtualIndex+4));
		memset(s_itemIndexToRegionPointer, 0, sizeof(MemoryRegion*)*(nextVirtualIndex+4));

		MAX_RAM_SIZE = nextVirtualIndex;
	}
	LeaveCriticalSection(&s_activeMemoryRegionsCS);
}

// eliminates a range of hardware addresses from the search results
// returns 2 if it changed the region and moved the iterator to another region
// returns 1 if it changed the region but didn't move the iterator
// returns 0 if it had no effect
// warning: don't call anything that takes an itemIndex in a loop that calls DeactivateRegion...
//   doing so would be tremendously slow because DeactivateRegion invalidates the index cache
int DeactivateRegion(MemoryRegion& region, MemoryList::iterator& iter, HWAddressType hardwareAddress, unsigned int size)
{
	if(hardwareAddress + size <= region.hardwareAddress || hardwareAddress >= region.hardwareAddress + region.size)
	{
		// region is unaffected
		return 0;
	}
	else if(hardwareAddress > region.hardwareAddress && hardwareAddress + size >= region.hardwareAddress + region.size)
	{
		// erase end of region
		region.size = hardwareAddress - region.hardwareAddress;
		return 1;
	}
	else if(hardwareAddress <= region.hardwareAddress && hardwareAddress + size < region.hardwareAddress + region.size)
	{
		// erase start of region
		int eraseSize = (hardwareAddress + size) - region.hardwareAddress;
		region.hardwareAddress += eraseSize;
		region.size -= eraseSize;
		region.virtualIndex += eraseSize;
		return 1;
	}
	else if(hardwareAddress <= region.hardwareAddress && hardwareAddress + size >= region.hardwareAddress + region.size)
	{
		// erase entire region
		iter = s_activeMemoryRegions.erase(iter);
		s_itemIndicesInvalid = TRUE;
		return 2;
	}
	else //if(hardwareAddress > region.hardwareAddress && hardwareAddress + size < region.hardwareAddress + region.size)
	{
		// split region
		int eraseSize = (hardwareAddress + size) - region.hardwareAddress;
		MemoryRegion region2 = {region.hardwareAddress + eraseSize, region.size - eraseSize, region.virtualIndex + eraseSize};
		region.size = hardwareAddress - region.hardwareAddress;
		iter = s_activeMemoryRegions.insert(++iter, region2);
		s_itemIndicesInvalid = TRUE;
		return 2;
	}
}

/*
// eliminates a range of hardware addresses from the search results
// this is a simpler but usually slower interface for the above function
void DeactivateRegion(HWAddressType hardwareAddress, unsigned int size)
{
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); )
	{
		MemoryRegion& region = *iter;
		if(2 != DeactivateRegion(region, iter, hardwareAddress, size))
			++iter;
	}
}
*/

struct AutoCritSect
{
	AutoCritSect(CRITICAL_SECTION* cs) : m_cs(cs) { EnterCriticalSection(m_cs); }
	~AutoCritSect() { LeaveCriticalSection(m_cs); }
	CRITICAL_SECTION* m_cs;
};

// warning: can be slow
void CalculateItemIndices(int itemSize)
{
	AutoCritSect cs(&s_activeMemoryRegionsCS);
	unsigned int itemIndex = 0;
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); ++iter)
	{
		MemoryRegion& region = *iter;
		region.itemIndex = itemIndex;
		int startSkipSize = ((unsigned int)(itemSize - (unsigned int)region.hardwareAddress)) % itemSize; // FIXME: is this still ok?
		unsigned int start = startSkipSize;
		unsigned int end = region.size;
		for(unsigned int i = start; i < end; i += itemSize)
			s_itemIndexToRegionPointer[itemIndex++] = &region;
	}
	s_maxItemIndex = itemIndex;
	s_itemIndicesInvalid = FALSE;
}

template<typename stepType, typename compareType>
void UpdateRegionT(const MemoryRegion& region, const MemoryRegion* nextRegionPtr)
{
	//if(GetAsyncKeyState(VK_SHIFT) & 0x8000) // speed hack
	//	return;

	if(s_prevValuesNeedUpdate)
		memcpy(s_prevValues + region.virtualIndex, s_curValues + region.virtualIndex, region.size + sizeof(compareType) - sizeof(stepType));

	unsigned int startSkipSize = ((unsigned int)(sizeof(stepType) - region.hardwareAddress)) % sizeof(stepType);


	HWAddressType hwSourceAddr = region.hardwareAddress - region.virtualIndex;

	unsigned int indexStart = region.virtualIndex + startSkipSize;
	unsigned int indexEnd = region.virtualIndex + region.size;

	if(sizeof(compareType) == 1)
	{
		for(unsigned int i = indexStart; i < indexEnd; i++)
		{
			if(s_curValues[i] != ReadValueAtHardwareAddress(hwSourceAddr+i, 1)) // if value changed
			{
				s_curValues[i] = ReadValueAtHardwareAddress(hwSourceAddr+i, 1); // update value
				//if(s_numChanges[i] != 0xFFFF)
					s_numChanges[i]++; // increase change count
			}
		}
	}
	else // it's more complicated for non-byte sizes because:
	{    // - more than one byte can affect a given change count entry
	     // - when more than one of those bytes changes simultaneously the entry's change count should only increase by 1
	     // - a few of those bytes can be outside the region

		unsigned int endSkipSize = ((unsigned int)(startSkipSize - region.size)) % sizeof(stepType);
		unsigned int lastIndexToRead = indexEnd + endSkipSize + sizeof(compareType) - sizeof(stepType);
		unsigned int lastIndexToCopy = lastIndexToRead;
		if(nextRegionPtr)
		{
			const MemoryRegion& nextRegion = *nextRegionPtr;
			int nextStartSkipSize = ((unsigned int)(sizeof(stepType) - nextRegion.hardwareAddress)) % sizeof(stepType);
			unsigned int nextIndexStart = nextRegion.virtualIndex + nextStartSkipSize;
			if(lastIndexToCopy > nextIndexStart)
				lastIndexToCopy = nextIndexStart;
		}

		unsigned int nextValidChange [sizeof(compareType)];
		for(unsigned int i = 0; i < sizeof(compareType); i++)
			nextValidChange[i] = indexStart + i;

		for(unsigned int i = indexStart, j = 0; i < lastIndexToRead; i++, j++)
		{
			if(s_curValues[i] != ReadValueAtHardwareAddress(hwSourceAddr+i, 1)) // if value of this byte changed
			{
				if(i < lastIndexToCopy)
					s_curValues[i] = ReadValueAtHardwareAddress(hwSourceAddr+i, 1); // update value
				for(int k = 0; k < sizeof(compareType); k++) // loop through the previous entries that contain this byte
				{
					if(i >= indexEnd+k)
						continue;
					int m = (j-k+sizeof(compareType)) & (sizeof(compareType)-1);
					if(nextValidChange[m] <= i) // if we didn't already increase the change count for this entry
					{
						//if(s_numChanges[i-k] != 0xFFFF)
							s_numChanges[i-k]++; // increase the change count for this entry
						nextValidChange[m] = i-k+sizeof(compareType); // and remember not to increase it again
					}
				}
			}
		}
	}
}

template<typename stepType, typename compareType>
void UpdateRegionsT()
{
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end();)
	{
		const MemoryRegion& region = *iter;
		++iter;
		const MemoryRegion* nextRegion = (iter == s_activeMemoryRegions.end()) ? NULL : &*iter;

		UpdateRegionT<stepType, compareType>(region, nextRegion);
	}

	s_prevValuesNeedUpdate = false;
}

template<typename stepType, typename compareType>
int CountRegionItemsT()
{
	AutoCritSect cs(&s_activeMemoryRegionsCS);
	if(sizeof(stepType) == 1)
	{
		if(s_activeMemoryRegions.empty())
			return 0;

		if(s_itemIndicesInvalid)
			CalculateItemIndices(sizeof(stepType));

		MemoryRegion& lastRegion = s_activeMemoryRegions.back();
		return lastRegion.itemIndex + lastRegion.size;
	}
	else // the branch above is faster but won't work if the step size isn't 1
	{
		int total = 0;
		for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); ++iter)
		{
			MemoryRegion& region = *iter;
			int startSkipSize = ((unsigned int)(sizeof(stepType) - region.hardwareAddress)) % sizeof(stepType);
			total += (region.size - startSkipSize + (sizeof(stepType)-1)) / sizeof(stepType);
		}
		return total;
	}
}

// returns information about the item in the form of a "fake" region
// that has the item in it and nothing else
template<typename stepType, typename compareType>
void ItemIndexToVirtualRegion(unsigned int itemIndex, MemoryRegion& virtualRegion)
{
	if(s_itemIndicesInvalid)
		CalculateItemIndices(sizeof(stepType));

	if(itemIndex >= s_maxItemIndex)
	{
		memset(&virtualRegion, 0, sizeof(MemoryRegion));
		return;
	}

	const MemoryRegion* regionPtr = s_itemIndexToRegionPointer[itemIndex];
	const MemoryRegion& region = *regionPtr;

	int bytesWithinRegion = (itemIndex - region.itemIndex) * sizeof(stepType);
	int startSkipSize = ((unsigned int)(sizeof(stepType) - region.hardwareAddress)) % sizeof(stepType);
	bytesWithinRegion += startSkipSize;
	
	virtualRegion.size = sizeof(compareType);
	virtualRegion.hardwareAddress = region.hardwareAddress + bytesWithinRegion;
	virtualRegion.virtualIndex = region.virtualIndex + bytesWithinRegion;
	virtualRegion.itemIndex = itemIndex;
	return;
}

template<typename stepType, typename compareType>
unsigned int ItemIndexToVirtualIndex(unsigned int itemIndex)
{
	MemoryRegion virtualRegion;
	ItemIndexToVirtualRegion<stepType,compareType>(itemIndex, virtualRegion);
	return virtualRegion.virtualIndex;
}

template<typename T>
T ReadLocalValue(const unsigned char* data)
{
	return *(const T*)data;
}
//template<> signed char ReadLocalValue(const unsigned char* data) { return *data; }
//template<> unsigned char ReadLocalValue(const unsigned char* data) { return *data; }


template<typename stepType, typename compareType>
compareType GetPrevValueFromVirtualIndex(unsigned int virtualIndex)
{
	return ReadLocalValue<compareType>(s_prevValues + virtualIndex);
	//return *(compareType*)(s_prevValues+virtualIndex);
}
template<typename stepType, typename compareType>
compareType GetCurValueFromVirtualIndex(unsigned int virtualIndex)
{
	return ReadLocalValue<compareType>(s_curValues + virtualIndex);
//	return *(compareType*)(s_curValues+virtualIndex);
}
template<typename stepType, typename compareType>
unsigned short GetNumChangesFromVirtualIndex(unsigned int virtualIndex)
{
	unsigned short num = s_numChanges[virtualIndex];
	//for(unsigned int i = 1; i < sizeof(stepType); i++)
	//	if(num < s_numChanges[virtualIndex+i])
	//		num = s_numChanges[virtualIndex+i];
	return num;
}

template<typename stepType, typename compareType>
compareType GetPrevValueFromItemIndex(unsigned int itemIndex)
{
	int virtualIndex = ItemIndexToVirtualIndex<stepType,compareType>(itemIndex);
	return GetPrevValueFromVirtualIndex<stepType,compareType>(virtualIndex);
}
template<typename stepType, typename compareType>
compareType GetCurValueFromItemIndex(unsigned int itemIndex)
{
	int virtualIndex = ItemIndexToVirtualIndex<stepType,compareType>(itemIndex);
	return GetCurValueFromVirtualIndex<stepType,compareType>(virtualIndex);
}
template<typename stepType, typename compareType>
unsigned short GetNumChangesFromItemIndex(unsigned int itemIndex)
{
	int virtualIndex = ItemIndexToVirtualIndex<stepType,compareType>(itemIndex);
	return GetNumChangesFromVirtualIndex<stepType,compareType>(virtualIndex);
}
template<typename stepType, typename compareType>
unsigned int GetHardwareAddressFromItemIndex(unsigned int itemIndex)
{
	MemoryRegion virtualRegion;
	ItemIndexToVirtualRegion<stepType,compareType>(itemIndex, virtualRegion);
	return virtualRegion.hardwareAddress;
}

// this one might be unreliable, haven't used it much
template<typename stepType, typename compareType>
unsigned int HardwareAddressToItemIndex(HWAddressType hardwareAddress)
{
	if(s_itemIndicesInvalid)
		CalculateItemIndices(sizeof(stepType));

	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); ++iter)
	{
		MemoryRegion& region = *iter;
		if(hardwareAddress >= region.hardwareAddress && hardwareAddress < region.hardwareAddress + region.size)
		{
			int indexWithinRegion = (hardwareAddress - region.hardwareAddress) / sizeof(stepType);
			return region.itemIndex + indexWithinRegion;
		}
	}

	return -1;
}



// workaround for MSVC 7 that doesn't support varadic C99 macros
#define CALL_WITH_T_SIZE_TYPES_0(functionName, sizeTypeID, isSigned, requiresAligned) \
	(sizeTypeID == 'b' \
		? (isSigned \
			? functionName<char, signed char>() \
			: functionName<char, unsigned char>()) \
	: sizeTypeID == 'w' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed short>() \
				: functionName<char, signed short>()) \
			: (requiresAligned \
				? functionName<short, unsigned short>() \
				: functionName<char, unsigned short>())) \
	: sizeTypeID == 'd' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed long>() \
				: functionName<char, signed long>()) \
			: (requiresAligned \
				? functionName<short, unsigned long>() \
				: functionName<char, unsigned long>())) \
	: functionName<char, signed char>())

#define CALL_WITH_T_SIZE_TYPES_1(functionName, sizeTypeID, isSigned, requiresAligned, p0) \
	(sizeTypeID == 'b' \
		? (isSigned \
			? functionName<char, signed char>(p0) \
			: functionName<char, unsigned char>(p0)) \
	: sizeTypeID == 'w' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed short>(p0) \
				: functionName<char, signed short>(p0)) \
			: (requiresAligned \
				? functionName<short, unsigned short>(p0) \
				: functionName<char, unsigned short>(p0))) \
	: sizeTypeID == 'd' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed long>(p0) \
				: functionName<char, signed long>(p0)) \
			: (requiresAligned \
				? functionName<short, unsigned long>(p0) \
				: functionName<char, unsigned long>(p0))) \
	: functionName<char, signed char>(p0))

#define CALL_WITH_T_SIZE_TYPES_3(functionName, sizeTypeID, isSigned, requiresAligned, p0, p1, p2) \
	(sizeTypeID == 'b' \
		? (isSigned \
			? functionName<char, signed char>(p0, p1, p2) \
			: functionName<char, unsigned char>(p0, p1, p2)) \
	: sizeTypeID == 'w' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed short>(p0, p1, p2) \
				: functionName<char, signed short>(p0, p1, p2)) \
			: (requiresAligned \
				? functionName<short, unsigned short>(p0, p1, p2) \
				: functionName<char, unsigned short>(p0, p1, p2))) \
	: sizeTypeID == 'd' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed long>(p0, p1, p2) \
				: functionName<char, signed long>(p0, p1, p2)) \
			: (requiresAligned \
				? functionName<short, unsigned long>(p0, p1, p2) \
				: functionName<char, unsigned long>(p0, p1, p2))) \
	: functionName<char, signed char>(p0, p1, p2))

#define CALL_WITH_T_SIZE_TYPES_4(functionName, sizeTypeID, isSigned, requiresAligned, p0, p1, p2, p3) \
	(sizeTypeID == 'b' \
		? (isSigned \
			? functionName<char, signed char>(p0, p1, p2, p3) \
			: functionName<char, unsigned char>(p0, p1, p2, p3)) \
	: sizeTypeID == 'w' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed short>(p0, p1, p2, p3) \
				: functionName<char, signed short>(p0, p1, p2, p3)) \
			: (requiresAligned \
				? functionName<short, unsigned short>(p0, p1, p2, p3) \
				: functionName<char, unsigned short>(p0, p1, p2, p3))) \
	: sizeTypeID == 'd' \
		? (isSigned \
			? (requiresAligned \
				? functionName<short, signed long>(p0, p1, p2, p3) \
				: functionName<char, signed long>(p0, p1, p2, p3)) \
			: (requiresAligned \
				? functionName<short, unsigned long>(p0, p1, p2, p3) \
				: functionName<char, unsigned long>(p0, p1, p2, p3))) \
	: functionName<char, signed char>(p0, p1, p2, p3))

// version that takes a forced comparison type
#define CALL_WITH_T_STEP_3(functionName, sizeTypeID, type, requiresAligned, p0, p1, p2) \
	(sizeTypeID == 'b' \
		? functionName<char, type>(p0, p1, p2) \
	: sizeTypeID == 'w' \
		? (requiresAligned \
			? functionName<short, type>(p0, p1, p2) \
			: functionName<char, type>(p0, p1, p2)) \
	: sizeTypeID == 'd' \
		? (requiresAligned \
			? functionName<short, type>(p0, p1, p2) \
			: functionName<char, type>(p0, p1, p2)) \
	: functionName<char, type>(p0, p1, p2))

// version that takes a forced comparison type
#define CALL_WITH_T_STEP_4(functionName, sizeTypeID, type, requiresAligned, p0, p1, p2, p3) \
	(sizeTypeID == 'b' \
		? functionName<char, type>(p0, p1, p2, p3) \
	: sizeTypeID == 'w' \
		? (requiresAligned \
			? functionName<short, type>(p0, p1, p2, p3) \
			: functionName<char, type>(p0, p1, p2, p3)) \
	: sizeTypeID == 'd' \
		? (requiresAligned \
			? functionName<short, type>(p0, p1, p2, p3) \
			: functionName<char, type>(p0, p1, p2, p3)) \
	: functionName<char, type>(p0, p1, p2, p3))

// basic comparison functions:
template <typename T> inline bool LessCmp (T x, T y, T i)        { return x < y; }
template <typename T> inline bool MoreCmp (T x, T y, T i)        { return x > y; }
template <typename T> inline bool LessEqualCmp (T x, T y, T i)   { return x <= y; }
template <typename T> inline bool MoreEqualCmp (T x, T y, T i)   { return x >= y; }
template <typename T> inline bool EqualCmp (T x, T y, T i)       { return x == y; }
template <typename T> inline bool UnequalCmp (T x, T y, T i)     { return x != y; }
template <typename T> inline bool DiffByCmp (T x, T y, T p)      { return x - y == p || y - x == p; }
template <typename T> inline bool ModIsCmp (T x, T y, T p)       { return p && x % p == y; }

// compare-to type functions:
template<typename stepType, typename T>
void SearchRelative (bool(*cmpFun)(T,T,T), T ignored, T param)
{
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); )
	{
		MemoryRegion& region = *iter;
		int startSkipSize = ((unsigned int)(sizeof(stepType) - region.hardwareAddress)) % sizeof(stepType);
		unsigned int start = region.virtualIndex + startSkipSize;
		unsigned int end = region.virtualIndex + region.size;
		for(unsigned int i = start, hwaddr = region.hardwareAddress; i < end; i += sizeof(stepType), hwaddr += sizeof(stepType))
			if(!cmpFun(GetCurValueFromVirtualIndex<stepType,T>(i), GetPrevValueFromVirtualIndex<stepType,T>(i), param))
				if(2 == DeactivateRegion(region, iter, hwaddr, sizeof(stepType)))
					goto outerContinue;
		++iter;
outerContinue:
		continue;
	}
}
template<typename stepType, typename T>
void SearchSpecific (bool(*cmpFun)(T,T,T), T value, T param)
{
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); )
	{
		MemoryRegion& region = *iter;
		int startSkipSize = ((unsigned int)(sizeof(stepType) - region.hardwareAddress)) % sizeof(stepType);
		unsigned int start = region.virtualIndex + startSkipSize;
		unsigned int end = region.virtualIndex + region.size;
		for(unsigned int i = start, hwaddr = region.hardwareAddress; i < end; i += sizeof(stepType), hwaddr += sizeof(stepType))
			if(!cmpFun(GetCurValueFromVirtualIndex<stepType,T>(i), value, param))
				if(2 == DeactivateRegion(region, iter, hwaddr, sizeof(stepType)))
					goto outerContinue;
		++iter;
outerContinue:
		continue;
	}
}
template<typename stepType, typename T>
void SearchAddress (bool(*cmpFun)(T,T,T), T address, T param)
{
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); )
	{
		MemoryRegion& region = *iter;
		int startSkipSize = ((unsigned int)(sizeof(stepType) - region.hardwareAddress)) % sizeof(stepType);
		unsigned int start = region.virtualIndex + startSkipSize;
		unsigned int end = region.virtualIndex + region.size;
		for(unsigned int i = start, hwaddr = region.hardwareAddress; i < end; i += sizeof(stepType), hwaddr += sizeof(stepType))
			if(!cmpFun(hwaddr, address, param))
				if(2 == DeactivateRegion(region, iter, hwaddr, sizeof(stepType)))
					goto outerContinue;
		++iter;
outerContinue:
		continue;
	}
}
template<typename stepType, typename T>
void SearchChanges (bool(*cmpFun)(T,T,T), T changes, T param)
{
	for(MemoryList::iterator iter = s_activeMemoryRegions.begin(); iter != s_activeMemoryRegions.end(); )
	{
		MemoryRegion& region = *iter;
		int startSkipSize = ((unsigned int)(sizeof(stepType) - region.hardwareAddress)) % sizeof(stepType);
		unsigned int start = region.virtualIndex + startSkipSize;
		unsigned int end = region.virtualIndex + region.size;
		for(unsigned int i = start, hwaddr = region.hardwareAddress; i < end; i += sizeof(stepType), hwaddr += sizeof(stepType))
			if(!cmpFun(GetNumChangesFromVirtualIndex<stepType,T>(i), changes, param))
				if(2 == DeactivateRegion(region, iter, hwaddr, sizeof(stepType)))
					goto outerContinue;
		++iter;
outerContinue:
		continue;
	}
}

char rs_c='s';
char rs_o='=';
char rs_t='s';
int rs_param=0, rs_val=0, rs_val_valid=0;
char rs_type_size = 'b', rs_last_type_size = rs_type_size;
bool noMisalign = true, rs_last_no_misalign = noMisalign;
//bool littleEndian = false;
int last_rs_possible = -1;
int last_rs_regions = -1;

void prune(char c,char o,char t,int v,int p)
{
	// repetition-reducing macros
	#define DO_SEARCH(sf) \
	switch (o) \
	{ \
		case '<': DO_SEARCH_2(LessCmp,sf); break; \
		case '>': DO_SEARCH_2(MoreCmp,sf); break; \
		case '=': DO_SEARCH_2(EqualCmp,sf); break; \
		case '!': DO_SEARCH_2(UnequalCmp,sf); break; \
		case 'l': DO_SEARCH_2(LessEqualCmp,sf); break; \
		case 'm': DO_SEARCH_2(MoreEqualCmp,sf); break; \
		case 'd': DO_SEARCH_2(DiffByCmp,sf); break; \
		case '%': DO_SEARCH_2(ModIsCmp,sf); break; \
		default: assert(!"Invalid operator for this search type."); break; \
	}

	// perform the search, eliminating nonmatching values
	switch (c)
	{
		#define DO_SEARCH_2(CmpFun,sf) CALL_WITH_T_SIZE_TYPES_3(sf, rs_type_size, t, noMisalign, CmpFun,v,p)
		case 'r': DO_SEARCH(SearchRelative); break;
		case 's': DO_SEARCH(SearchSpecific); break;

		#undef DO_SEARCH_2
		#define DO_SEARCH_2(CmpFun,sf) CALL_WITH_T_STEP_3(sf, rs_type_size, unsigned int, noMisalign, CmpFun,v,p)
		case 'a': DO_SEARCH(SearchAddress); break;

		#undef DO_SEARCH_2
		#define DO_SEARCH_2(CmpFun,sf) CALL_WITH_T_STEP_3(sf, rs_type_size, unsigned short, noMisalign, CmpFun,v,p)
		case 'n': DO_SEARCH(SearchChanges); break;

		default: assert(!"Invalid search comparison type."); break;
	}

	s_prevValuesNeedUpdate = true;

	int prevNumItems = last_rs_possible;

	CompactAddrs();

	if(prevNumItems == last_rs_possible)
	{
		SetRamSearchUndoType(RamSearchHWnd, 0); // nothing to undo
	}
}




template<typename stepType, typename T>
bool CompareRelativeAtItem (bool(*cmpFun)(T,T,T), int itemIndex, T ignored, T param)
{
	return cmpFun(GetCurValueFromItemIndex<stepType,T>(itemIndex), GetPrevValueFromItemIndex<stepType,T>(itemIndex), param);
}
template<typename stepType, typename T>
bool CompareSpecificAtItem (bool(*cmpFun)(T,T,T), int itemIndex, T value, T param)
{
	return cmpFun(GetCurValueFromItemIndex<stepType,T>(itemIndex), value, param);
}
template<typename stepType, typename T>
bool CompareAddressAtItem (bool(*cmpFun)(T,T,T), int itemIndex, T address, T param)
{
	return cmpFun(GetHardwareAddressFromItemIndex<stepType,T>(itemIndex), address, param);
}
template<typename stepType, typename T>
bool CompareChangesAtItem (bool(*cmpFun)(T,T,T), int itemIndex, T changes, T param)
{
	return cmpFun(GetNumChangesFromItemIndex<stepType,T>(itemIndex), changes, param);
}

int ReadControlInt(int controlID, bool forceHex, BOOL& success)
{
	int rv = 0;
	BOOL ok = false;

	if(!forceHex)
	{
		rv = GetDlgItemInt(RamSearchHWnd,controlID,&ok,(rs_t == 's'));
	}

	if(!ok)
	{
		if(GetDlgItemText(RamSearchHWnd,controlID,Str_Tmp,16))
		{
			for(int i = 0; Str_Tmp[i]; i++) {if(toupper(Str_Tmp[i]) == 'O') Str_Tmp[i] = '0';}
			const char* strPtr = Str_Tmp;
			bool negate = false;
			while(strPtr[0] == '-')
				strPtr++, negate = !negate;
			if(strPtr[0] == '+')
				strPtr++;
			if(strPtr[0] == '0' && tolower(strPtr[1]) == 'x')
				strPtr += 2, forceHex = true;
			if(strPtr[0] == '$')
				strPtr++, forceHex = true;
			if(!forceHex)
			{
				const char* strSearchPtr = strPtr;
				while(*strSearchPtr)
				{
					int c = tolower(*strSearchPtr++);
					if(c >= 'a' && c <= 'f')
						forceHex = true;
				}
			}
			const char* formatString = forceHex ? "%X" : ((rs_t=='s') ? "%d" : "%u");
			if(sscanf(strPtr, formatString, &rv) > 0)
				ok = true;
			if(negate)
				rv = -rv;
		}
	}

	success = ok;
	return rv;
}


bool Set_RS_Val()
{
	BOOL success;

	// update rs_val
	switch(rs_c)
	{
		case 'r':
		default:
			rs_val = 0;
			break;
		case 's':
			rs_val = ReadControlInt(IDC_EDIT_COMPAREVALUE, rs_t == 'h', success);
			if(!success)
				return false;
			if((rs_type_size == 'b' && rs_t == 's' && (rs_val < -128 || rs_val > 127)) ||
			   (rs_type_size == 'b' && rs_t != 's' && (rs_val < 0 || rs_val > 255)) ||
			   (rs_type_size == 'w' && rs_t == 's' && (rs_val < -32768 || rs_val > 32767)) ||
			   (rs_type_size == 'w' && rs_t != 's' && (rs_val < 0 || rs_val > 65535)))
			   return false;
			break;
		case 'a':
			rs_val = ReadControlInt(IDC_EDIT_COMPAREADDRESS, true, success);
			if(!success || rs_val < 0 || rs_val > 0x06040000)
				return false;
			break;
		case 'n': {
			rs_val = ReadControlInt(IDC_EDIT_COMPARECHANGES, false, success);
			if(!success || rs_val < 0 || rs_val > 0xFFFF)
				return false;
		}	break;
	}

	// also update rs_param
	switch(rs_o)
	{
		default:
			rs_param = 0;
			break;
		case 'd':
			rs_param = ReadControlInt(IDC_EDIT_DIFFBY, false, success);
			if(!success)
				return false;
			if(rs_param < 0)
				rs_param = -rs_param;
			break;
		case '%':
			rs_param = ReadControlInt(IDC_EDIT_MODBY, false, success);
			if(!success || rs_param == 0)
				return false;
			break;
	}

	// validate that rs_param fits in the comparison data type
	{
		int appliedSize = rs_type_size;
		int appliedSign = rs_t;
		if(rs_c == 'n')
			appliedSize = 'w', appliedSign = 'u';
		if(rs_c == 'a')
			appliedSize = 'd', appliedSign = 'u';
		if((appliedSize == 'b' && appliedSign == 's' && (rs_param < -128 || rs_param > 127)) ||
		   (appliedSize == 'b' && appliedSign != 's' && (rs_param < 0 || rs_param > 255)) ||
		   (appliedSize == 'w' && appliedSign == 's' && (rs_param < -32768 || rs_param > 32767)) ||
		   (appliedSize == 'w' && appliedSign != 's' && (rs_param < 0 || rs_param > 65535)))
		   return false;
	}

	return true;
}

bool IsSatisfied(int itemIndex)
{
	if(!rs_val_valid)
		return true;
	int o = rs_o;
	switch (rs_c)
	{
		#undef DO_SEARCH_2
		#define DO_SEARCH_2(CmpFun,sf) return CALL_WITH_T_SIZE_TYPES_4(sf, rs_type_size,(rs_t=='s'),noMisalign, CmpFun,itemIndex,rs_val,rs_param);
		case 'r': DO_SEARCH(CompareRelativeAtItem); break;
		case 's': DO_SEARCH(CompareSpecificAtItem); break;

		#undef DO_SEARCH_2
		#define DO_SEARCH_2(CmpFun,sf) return CALL_WITH_T_STEP_4(sf, rs_type_size, unsigned int, noMisalign, CmpFun,itemIndex,rs_val,rs_param);
		case 'a': DO_SEARCH(CompareAddressAtItem); break;

		#undef DO_SEARCH_2
		#define DO_SEARCH_2(CmpFun,sf) return CALL_WITH_T_STEP_4(sf, rs_type_size, unsigned short, noMisalign, CmpFun,itemIndex,rs_val,rs_param);
		case 'n': DO_SEARCH(CompareChangesAtItem); break;
	}
	return false;
}



unsigned int ReadValueAtSoftwareAddress(const unsigned char* address, unsigned int size)
{
	unsigned int value = 0;
	//if(!byteSwapped)
	{
		// assumes we're little-endian
		memcpy(&value, address, size);
	}
	return value;
}
void WriteValueAtSoftwareAddress(unsigned char* address, unsigned int value, unsigned int size)
{
	//if(!byteSwapped)
	{
		// assumes we're little-endian
		memcpy(address, &value, size);
	}
}
unsigned int ReadValueAtHardwareAddress(HWAddressType address, unsigned int size)
{
	unsigned int value = 0;

	// read as little endian
	for(unsigned int i = 0; i < size; i++)
	{
		value <<= 8;
		value |= (IsHardwareAddressValid(address) ? GetMem(address) : 0);
		address++;
	}
	return value;
}
bool WriteValueAtHardwareAddress(HWAddressType address, unsigned int value, unsigned int size)
{
	// TODO: NYI
	return false;
}



int ResultCount=0;
bool AutoSearch=false;
bool AutoSearchAutoRetry=false;
LRESULT CALLBACK PromptWatchNameProc(HWND, UINT, WPARAM, LPARAM);
void UpdatePossibilities(int rs_possible, int regions);


void CompactAddrs()
{
	int size = (rs_type_size=='b' || !noMisalign) ? 1 : 2;
	int prevResultCount = ResultCount;

	CalculateItemIndices(size);
	ResultCount = CALL_WITH_T_SIZE_TYPES_0(CountRegionItemsT, rs_type_size,rs_t=='s',noMisalign);

	UpdatePossibilities(ResultCount, (int)s_activeMemoryRegions.size());

	if(ResultCount != prevResultCount)
		ListView_SetItemCount(GetDlgItem(RamSearchHWnd,IDC_RAMLIST),ResultCount);
}

void soft_reset_address_info ()
{
	/*
	if (resetPrevValues) {
		if(s_prevValues)
			memcpy(s_prevValues, s_curValues, (sizeof(*s_prevValues)*(MAX_RAM_SIZE)));
		s_prevValuesNeedUpdate = false;
	}*/
	s_prevValuesNeedUpdate = false;
	ResetMemoryRegions();
	if(!RamSearchHWnd)
	{
		EnterCriticalSection(&s_activeMemoryRegionsCS);
		s_activeMemoryRegions.clear();
		LeaveCriticalSection(&s_activeMemoryRegionsCS);
		ResultCount = 0;
	}
	else
	{
		// force s_prevValues to be valid
		signal_new_frame();
		s_prevValuesNeedUpdate = true;
		signal_new_frame();
	}
	if(s_numChanges)
		memset(s_numChanges, 0, (sizeof(*s_numChanges)*(MAX_RAM_SIZE)));
	CompactAddrs();
}
void reset_address_info ()
{
	SetRamSearchUndoType(RamSearchHWnd, 0);
	EnterCriticalSection(&s_activeMemoryRegionsCS);
	s_activeMemoryRegionsBackup.clear(); // not necessary, but we'll take the time hit here instead of at the next thing that sets up an undo
	LeaveCriticalSection(&s_activeMemoryRegionsCS);
	if(s_prevValues)
		memcpy(s_prevValues, s_curValues, (sizeof(*s_prevValues)*(MAX_RAM_SIZE)));
	s_prevValuesNeedUpdate = false;
	ResetMemoryRegions();
	if(!RamSearchHWnd)
	{
		EnterCriticalSection(&s_activeMemoryRegionsCS);
		s_activeMemoryRegions.clear();
		LeaveCriticalSection(&s_activeMemoryRegionsCS);
		ResultCount = 0;
	}
	else
	{
		// force s_prevValues to be valid
		signal_new_frame();
		s_prevValuesNeedUpdate = true;
		signal_new_frame();
	}
	memset(s_numChanges, 0, (sizeof(*s_numChanges)*(MAX_RAM_SIZE)));
	CompactAddrs();
}

void signal_new_frame ()
{
	EnterCriticalSection(&s_activeMemoryRegionsCS);
	CALL_WITH_T_SIZE_TYPES_0(UpdateRegionsT, rs_type_size, rs_t=='s', noMisalign);
	LeaveCriticalSection(&s_activeMemoryRegionsCS);
}





bool RamSearchClosed = false;
bool RamWatchClosed = false;

void ResetResults()
{
	reset_address_info();
	ResultCount = 0;
	if (RamSearchHWnd)
		ListView_SetItemCount(GetDlgItem(RamSearchHWnd,IDC_RAMLIST),ResultCount);
}
void CloseRamWindows() //Close the Ram Search & Watch windows when rom closes
{
	ResetWatches();
	ResetResults();
	if (RamSearchHWnd)
	{
		SendMessage(RamSearchHWnd,WM_CLOSE,NULL,NULL);
		RamSearchClosed = true;
	}
	if (RamWatchHWnd)
	{
		SendMessage(RamWatchHWnd,WM_CLOSE,NULL,NULL);
		RamWatchClosed = true;
	}
}
void ReopenRamWindows() //Reopen them when a new Rom is loaded
{
	HWND hwnd = GetActiveWindow();

	if (RamSearchClosed)
	{
		RamSearchClosed = false;
		if(!RamSearchHWnd)
		{
			reset_address_info();
			LRESULT CALLBACK RamSearchProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);
			RamSearchHWnd = CreateDialog(hInst, MAKEINTRESOURCE(IDD_RAMSEARCH), hWnd, (DLGPROC) RamSearchProc);
		}
	}
	if (RamWatchClosed || AutoRWLoad)
	{
		RamWatchClosed = false;
		if(!RamWatchHWnd)
		{
			if (AutoRWLoad) OpenRWRecentFile(0);
			RamWatchHWnd = CreateDialog(hInst, MAKEINTRESOURCE(IDD_RAMWATCH), hWnd, (DLGPROC) RamWatchProc);
		}
	}

	if (hwnd == hWnd && hwnd != GetActiveWindow())
		SetActiveWindow(hWnd); // restore focus to the main window if it had it before
}






void RefreshRamListSelectedCountControlStatus(HWND hDlg)
{
	static int prevSelCount=-1;
	int selCount = ListView_GetSelectedCount(GetDlgItem(hDlg,IDC_RAMLIST));
	if(selCount != prevSelCount)
	{
		if(selCount < 2 || prevSelCount < 2)
		{
			EnableWindow(GetDlgItem(hDlg, IDC_C_WATCH), (selCount >= 1 && WatchCount < MAX_WATCH_COUNT) ? TRUE : FALSE);
			EnableWindow(GetDlgItem(hDlg, IDC_C_ADDCHEAT), (selCount >= 1) ? TRUE : FALSE);
			EnableWindow(GetDlgItem(hDlg, IDC_C_HEXEDITOR), (selCount >= 1) ? TRUE : FALSE);
			EnableWindow(GetDlgItem(hDlg, IDC_C_ELIMINATE), (selCount >= 1) ? TRUE : FALSE);
		}
		prevSelCount = selCount;
	}
}




struct AddrRange
{
	unsigned int addr;
	unsigned int size;
	unsigned int End() const { return addr + size; }
	AddrRange(unsigned int a, unsigned int s) : addr(a),size(s){}
};

void signal_new_size ()
{
	HWND lv = GetDlgItem(RamSearchHWnd,IDC_RAMLIST);

	int oldSize = (rs_last_type_size=='b' || !rs_last_no_misalign) ? 1 : 2;
	int newSize = (rs_type_size=='b' || !noMisalign) ? 1 : 2;
	bool numberOfItemsChanged = (oldSize != newSize);

	unsigned int itemsPerPage = ListView_GetCountPerPage(lv);
	unsigned int oldTopIndex = ListView_GetTopIndex(lv);
	unsigned int oldSelectionIndex = ListView_GetSelectionMark(lv);
	unsigned int oldTopAddr = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_last_type_size,rs_t=='s',rs_last_no_misalign, oldTopIndex);
	unsigned int oldSelectionAddr = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_last_type_size,rs_t=='s',rs_last_no_misalign, oldSelectionIndex);

	std::vector<AddrRange> selHardwareAddrs;
	if(numberOfItemsChanged)
	{
		// store selection ranges
		// unfortunately this can take a while if the user has a huge range of items selected
//		Clear_Sound_Buffer();
		int selCount = ListView_GetSelectedCount(lv);
		int size = (rs_last_type_size=='b' || !rs_last_no_misalign) ? 1 : 2;
		int watchIndex = -1;
		for(int i = 0; i < selCount; ++i)
		{
			watchIndex = ListView_GetNextItem(lv, watchIndex, LVNI_SELECTED);
			int addr = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_last_type_size,rs_t=='s',rs_last_no_misalign, watchIndex);
			if(!selHardwareAddrs.empty() && addr == selHardwareAddrs.back().End())
				selHardwareAddrs.back().size += size;
			else if (!(noMisalign && oldSize < newSize && addr % newSize != 0))
				selHardwareAddrs.push_back(AddrRange(addr,size));
		}
	}

	CompactAddrs();

	rs_last_type_size = rs_type_size;
	rs_last_no_misalign = noMisalign;

	if(numberOfItemsChanged)
	{
		// restore selection ranges
		unsigned int newTopIndex = CALL_WITH_T_SIZE_TYPES_1(HardwareAddressToItemIndex, rs_type_size,rs_t=='s',noMisalign, oldTopAddr);
		unsigned int newBottomIndex = newTopIndex + itemsPerPage - 1;
		SendMessage(lv, WM_SETREDRAW, FALSE, 0);
		ListView_SetItemState(lv, -1, 0, LVIS_SELECTED|LVIS_FOCUSED); // deselect all
		for(unsigned int i = 0; i < selHardwareAddrs.size(); i++)
		{
			// calculate index ranges of this selection
			const AddrRange& range = selHardwareAddrs[i];
			int selRangeTop = CALL_WITH_T_SIZE_TYPES_1(HardwareAddressToItemIndex, rs_type_size,rs_t=='s',noMisalign, range.addr);
			int selRangeBottom = -1;
			for(int endAddr = range.End()-1; endAddr >= selRangeTop && selRangeBottom == -1; endAddr--)
				selRangeBottom = CALL_WITH_T_SIZE_TYPES_1(HardwareAddressToItemIndex, rs_type_size,rs_t=='s',noMisalign, endAddr);
			if(selRangeBottom == -1)
				selRangeBottom = selRangeTop;
			if(selRangeTop == -1)
				continue;

			// select the entire range
			for (int j = selRangeTop; j <= selRangeBottom; j++)
			{
				ListView_SetItemState(lv, j, LVIS_SELECTED|LVIS_FOCUSED, LVIS_SELECTED|LVIS_FOCUSED);
			}
		}

		// restore previous scroll position
		if(newBottomIndex != -1)
			ListView_EnsureVisible(lv, newBottomIndex, 0);
		if(newTopIndex != -1)
			ListView_EnsureVisible(lv, newTopIndex, 0);

		SendMessage(lv, WM_SETREDRAW, TRUE, 0);

		RefreshRamListSelectedCountControlStatus(RamSearchHWnd);

		EnableWindow(GetDlgItem(RamSearchHWnd,IDC_MISALIGN), rs_type_size != 'b');
	}
	else
	{
		ListView_Update(lv, -1);
	}
	InvalidateRect(lv, NULL, TRUE);
	//SetFocus(lv);
}




LRESULT CustomDraw (LPARAM lParam)
{
	LPNMLVCUSTOMDRAW lplvcd = (LPNMLVCUSTOMDRAW)lParam;

	switch(lplvcd->nmcd.dwDrawStage) 
	{
		case CDDS_PREPAINT :
			return CDRF_NOTIFYITEMDRAW;

		case CDDS_ITEMPREPAINT:
		{
			int rv = CDRF_DODEFAULT;

			if(lplvcd->nmcd.dwItemSpec % 2)
			{
				// alternate the background color slightly
				lplvcd->clrTextBk = RGB(248,248,255);
				rv = CDRF_NEWFONT;
			}

			if(!IsSatisfied(lplvcd->nmcd.dwItemSpec))
			{
				// tint red any items that would be eliminated if a search were to run now
				lplvcd->clrText = RGB(192,64,64);
				rv = CDRF_NEWFONT;
			}

			return rv;
		}	break;
	}
	return CDRF_DODEFAULT;
}

void Update_RAM_Search() //keeps RAM values up to date in the search and watch windows
{
	if(disableRamSearchUpdate)
		return;

	int prevValuesNeededUpdate;
	if (AutoSearch && !ResultCount)
	{
		if(!AutoSearchAutoRetry)
		{
//			Clear_Sound_Buffer();
			int answer = MessageBox(RamSearchHWnd,"Choosing Retry will reset the search once and continue autosearching.\nChoose Ignore will reset the search whenever necessary and continue autosearching.\nChoosing Abort will reset the search once and stop autosearching.","Autosearch - out of results.",MB_ABORTRETRYIGNORE|MB_DEFBUTTON2|MB_ICONINFORMATION);
			if(answer == IDABORT)
			{
				SendDlgItemMessage(RamSearchHWnd, IDC_C_AUTOSEARCH, BM_SETCHECK, BST_UNCHECKED, 0);
				SendMessage(RamSearchHWnd, WM_COMMAND, IDC_C_AUTOSEARCH, 0);
			}
			if(answer == IDIGNORE)
				AutoSearchAutoRetry = true;
		}
		reset_address_info();
		prevValuesNeededUpdate = s_prevValuesNeedUpdate;
	}
	else
	{
		prevValuesNeededUpdate = s_prevValuesNeedUpdate;
		if (RamSearchHWnd)
		{
			// update active RAM values
			signal_new_frame();
		}

		if (AutoSearch && ResultCount)
		{
			//Clear_Sound_Buffer();
			if(!rs_val_valid)
				rs_val_valid = Set_RS_Val();
			if(rs_val_valid)
				prune(rs_c,rs_o,rs_t=='s',rs_val,rs_param);
		}
	}

	if(RamSearchHWnd)
	{
		HWND lv = GetDlgItem(RamSearchHWnd,IDC_RAMLIST);
		if(prevValuesNeededUpdate != s_prevValuesNeedUpdate)
		{
			// previous values got updated, refresh everything visible
			ListView_Update(lv, -1);
		}
		else
		{
			// refresh any visible parts of the listview box that changed
			static int changes[128];
			int top = ListView_GetTopIndex(lv);
			int count = ListView_GetCountPerPage(lv);
			int start = -1;
			for(int i = top; i <= top+count; i++)
			{
				int changeNum = CALL_WITH_T_SIZE_TYPES_1(GetNumChangesFromItemIndex, rs_type_size,rs_t=='s',noMisalign, i); //s_numChanges[i];
				int changed = changeNum != changes[i-top];
				if(changed)
					changes[i-top] = changeNum;

				if(start == -1)
				{
					if(i != top+count && changed)
					{
						start = i;
						//somethingChanged = true;
					}
				}
				else
				{
					if(i == top+count || !changed)
					{
						ListView_RedrawItems(lv, start, i-1);
						start = -1;
					}
				}
			}
		}
	}

	if(RamWatchHWnd)
	{
		Update_RAM_Watch();
	}
}

static int rs_lastPercent = -1;
inline void UpdateRamSearchProgressBar(int percent)
{
	if(rs_lastPercent != percent)
	{
		rs_lastPercent = percent;
		UpdateRamSearchTitleBar(percent);
	}
}

static void SelectEditControl(int controlID)
{
	HWND hEdit = GetDlgItem(RamSearchHWnd,controlID);
	SetFocus(hEdit);
	SendMessage(hEdit, EM_SETSEL, 0, -1);
}

static BOOL SelectingByKeyboard()
{
	int a = GetKeyState(VK_LEFT);
	int b = GetKeyState(VK_RIGHT);
	int c = GetKeyState(VK_UP);
	int d = GetKeyState(VK_DOWN); // space and tab are intentionally omitted
	return (a | b | c | d) & 0x80;
}

LRESULT CALLBACK RamSearchProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	RECT r;
	RECT r2;
	int dx1, dy1, dx2, dy2;
	static int watchIndex=0;

	switch(uMsg)
	{
		case WM_INITDIALOG: {
			RamSearchHWnd = hDlg;

			GetWindowRect(hWnd, &r);
			dx1 = (r.right - r.left) / 2;
			dy1 = (r.bottom - r.top) / 2;

			GetWindowRect(hDlg, &r2);
			dx2 = (r2.right - r2.left) / 2;
			dy2 = (r2.bottom - r2.top) / 2;

			// push it away from the main window if we can
			const int width = (r.right-r.left); 
			const int width2 = (r2.right-r2.left); 
			if(r.left+width2 + width < GetSystemMetrics(SM_CXSCREEN))
			{
				r.right += width;
				r.left += width;
			}
			else if((int)r.left - (int)width2 > 0)
			{
				r.right -= width2;
				r.left -= width2;
			}

			SetWindowPos(hDlg, NULL, r.left, r.top, NULL, NULL, SWP_NOSIZE | SWP_NOZORDER | SWP_SHOWWINDOW);
			switch(rs_o)
			{
				case '<':
					SendDlgItemMessage(hDlg, IDC_LESSTHAN, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case '>':
					SendDlgItemMessage(hDlg, IDC_MORETHAN, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 'l':
					SendDlgItemMessage(hDlg, IDC_NOMORETHAN, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 'm':
					SendDlgItemMessage(hDlg, IDC_NOLESSTHAN, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case '=': 
					SendDlgItemMessage(hDlg, IDC_EQUALTO, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case '!':
					SendDlgItemMessage(hDlg, IDC_DIFFERENTFROM, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 'd':
					SendDlgItemMessage(hDlg, IDC_DIFFERENTBY, BM_SETCHECK, BST_CHECKED, 0);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),true);
					break;
				case '%':
					SendDlgItemMessage(hDlg, IDC_MODULO, BM_SETCHECK, BST_CHECKED, 0);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),true);
					break;
			}
			switch (rs_c)
			{
				case 'r':
					SendDlgItemMessage(hDlg, IDC_PREVIOUSVALUE, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 's':
					SendDlgItemMessage(hDlg, IDC_SPECIFICVALUE, BM_SETCHECK, BST_CHECKED, 0);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREVALUE),true);
					break;
				case 'a':
					SendDlgItemMessage(hDlg, IDC_SPECIFICADDRESS, BM_SETCHECK, BST_CHECKED, 0);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREADDRESS),true);
					break;
				case 'n':
					SendDlgItemMessage(hDlg, IDC_NUMBEROFCHANGES, BM_SETCHECK, BST_CHECKED, 0);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPARECHANGES),true);
					break;
			}
			switch (rs_t)
			{
				case 's':
					SendDlgItemMessage(hDlg, IDC_SIGNED, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 'u':
					SendDlgItemMessage(hDlg, IDC_UNSIGNED, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 'h':
					SendDlgItemMessage(hDlg, IDC_HEX, BM_SETCHECK, BST_CHECKED, 0);
					break;
			}
			switch (rs_type_size)
			{
				case 'b':
					SendDlgItemMessage(hDlg, IDC_1_BYTE, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 'w':
					SendDlgItemMessage(hDlg, IDC_2_BYTES, BM_SETCHECK, BST_CHECKED, 0);
					break;
				case 'd':
					SendDlgItemMessage(hDlg, IDC_4_BYTES, BM_SETCHECK, BST_CHECKED, 0);
					break;
			}

			s_prevValuesNeedUpdate = true;

			SendDlgItemMessage(hDlg,IDC_C_AUTOSEARCH,BM_SETCHECK,AutoSearch?BST_CHECKED:BST_UNCHECKED,0);
			SendDlgItemMessage(hDlg,IDC_C_SEARCHROM,BM_SETCHECK,ShowROM?BST_CHECKED:BST_UNCHECKED,0);
			//const char* names[5] = {"Address","Value","Previous","Changes","Notes"};
			//int widths[5] = {62,64,64,55,55};
			const char* names[] = {"Address","Value","Previous","Changes"};
			int widths[4] = {68,76,76,68};
			if (!ResultCount)
				reset_address_info();
			else
			{
				signal_new_frame();
				CompactAddrs();
			}
			void init_list_box(HWND Box, const char* Strs[], int numColumns, int *columnWidths);
			init_list_box(GetDlgItem(hDlg,IDC_RAMLIST),names,4,widths);
			//ListView_SetItemCount(GetDlgItem(hDlg,IDC_RAMLIST),ResultCount);
			if (!noMisalign) SendDlgItemMessage(hDlg, IDC_MISALIGN, BM_SETCHECK, BST_CHECKED, 0);
			//if (littleEndian) SendDlgItemMessage(hDlg, IDC_ENDIAN, BM_SETCHECK, BST_CHECKED, 0);
			last_rs_possible = -1;
			RefreshRamListSelectedCountControlStatus(hDlg);

			// force misalign checkbox to refresh
			signal_new_size();

			// force undo button to refresh
			int undoType = s_undoType;
			SetRamSearchUndoType(hDlg, -2);
			SetRamSearchUndoType(hDlg, undoType);

			// force possibility count to refresh
			last_rs_possible--;
			UpdatePossibilities(ResultCount, (int)s_activeMemoryRegions.size());
			
			rs_val_valid = Set_RS_Val();

			ListView_SetCallbackMask(GetDlgItem(hDlg,IDC_RAMLIST), LVIS_FOCUSED|LVIS_SELECTED);

			return true;
		}	break;

		case WM_NOTIFY:
		{
			LPNMHDR lP = (LPNMHDR) lParam;
			switch (lP->code)
			{
				case NM_CUSTOMDRAW:
				{
					SetWindowLong(hDlg, DWL_MSGRESULT, CustomDraw(lParam));
					return TRUE;
				}

				case LVN_ITEMCHANGED: // selection changed event
				{
					NM_LISTVIEW* pNMListView = (NM_LISTVIEW*)lP;
					if(pNMListView->uNewState & LVIS_FOCUSED ||
						(pNMListView->uNewState ^ pNMListView->uOldState) & LVIS_SELECTED)
					{
						// disable buttons that we don't have the right number of selected items for
						RefreshRamListSelectedCountControlStatus(hDlg);
					}
					break;
				}

				case LVN_GETDISPINFO:
				{
					LV_DISPINFO *Item = (LV_DISPINFO *)lParam;
					Item->item.mask = LVIF_TEXT;
					Item->item.state = 0;
					Item->item.iImage = 0;
					const unsigned int iNum = Item->item.iItem;
					static char num[11];
					switch (Item->item.iSubItem)
					{
						case 0:
						{
							int addr = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_type_size,rs_t=='s',noMisalign, iNum);
							sprintf(num,"%04X",addr);
							Item->item.pszText = num;
						}	return true;
						case 1:
						{
							int i = CALL_WITH_T_SIZE_TYPES_1(GetCurValueFromItemIndex, rs_type_size,rs_t=='s',noMisalign, iNum);
							const char* formatString = ((rs_t=='s') ? "%d" : (rs_t=='u') ? "%u" : (rs_type_size=='d' ? "%08X" : rs_type_size=='w' ? "%04X" : "%02X"));
							switch (rs_type_size)
							{
								case 'b':
								default: sprintf(num, formatString, rs_t=='s' ? (char)(i&0xff) : (unsigned char)(i&0xff)); break;
								case 'w': sprintf(num, formatString, rs_t=='s' ? (short)(i&0xffff) : (unsigned short)(i&0xffff)); break;
								case 'd': sprintf(num, formatString, rs_t=='s' ? (long)(i&0xffffffff) : (unsigned long)(i&0xffffffff)); break;
							}
							Item->item.pszText = num;
						}	return true;
						case 2:
						{
							int i = CALL_WITH_T_SIZE_TYPES_1(GetPrevValueFromItemIndex, rs_type_size,rs_t=='s',noMisalign, iNum);
							const char* formatString = ((rs_t=='s') ? "%d" : (rs_t=='u') ? "%u" : (rs_type_size=='d' ? "%08X" : rs_type_size=='w' ? "%04X" : "%02X"));
							switch (rs_type_size)
							{
								case 'b':
								default: sprintf(num, formatString, rs_t=='s' ? (char)(i&0xff) : (unsigned char)(i&0xff)); break;
								case 'w': sprintf(num, formatString, rs_t=='s' ? (short)(i&0xffff) : (unsigned short)(i&0xffff)); break;
								case 'd': sprintf(num, formatString, rs_t=='s' ? (long)(i&0xffffffff) : (unsigned long)(i&0xffffffff)); break;
							}
							Item->item.pszText = num;
						}	return true;
						case 3:
						{
							int i = CALL_WITH_T_SIZE_TYPES_1(GetNumChangesFromItemIndex, rs_type_size,rs_t=='s',noMisalign, iNum);
							sprintf(num,"%d",i);

							Item->item.pszText = num;
						}	return true;
						//case 4:
						//	Item->item.pszText = rsaddrs[rsresults[iNum].Index].comment ? rsaddrs[rsresults[iNum].Index].comment : "";
						//	return true;
						default:
							return false;
					}
				}

				case NM_RCLICK:
				{
					// go to the address in Hex Editor
					LPNMITEMACTIVATE lpnmitem = (LPNMITEMACTIVATE)lParam;
					int watchItemIndex = lpnmitem->iItem;
					if (watchItemIndex >= 0)
					{
						unsigned int addr = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_type_size, rs_t=='s', noMisalign, watchItemIndex);
						ChangeMemViewFocus(0, addr, -1);
					}
					break;
				}

				//case LVN_ODCACHEHINT: //Copied this bit from the MSDN virtual listbox code sample. Eventually it should probably do something.
				//{
				//	LPNMLVCACHEHINT   lpCacheHint = (LPNMLVCACHEHINT)lParam;
				//	return 0;
				//}
				//case LVN_ODFINDITEM: //Copied this bit from the MSDN virtual listbox code sample. Eventually it should probably do something.
				//{	
				//	LPNMLVFINDITEM lpFindItem = (LPNMLVFINDITEM)lParam;
				//	return 0;
				//}
			}
			break;
		}

		case WM_COMMAND:
		{
			int rv = false;
			switch(LOWORD(wParam))
			{
				case IDC_SIGNED:
					rs_t='s';
					signal_new_size();
					{rv = true; break;}
				case IDC_UNSIGNED:
					rs_t='u';
					signal_new_size();
					{rv = true; break;}
				case IDC_HEX:
					rs_t='h';
					signal_new_size();
					{rv = true; break;}
				case IDC_1_BYTE:
					rs_type_size = 'b';
					signal_new_size();
					{rv = true; break;}
				case IDC_2_BYTES:
					rs_type_size = 'w';
					signal_new_size();
					{rv = true; break;}
				case IDC_4_BYTES:
					rs_type_size = 'd';
					signal_new_size();
					{rv = true; break;}
				case IDC_MISALIGN:
					noMisalign = !noMisalign;
					//CompactAddrs();
					signal_new_size();
					{rv = true; break;}
//				case IDC_ENDIAN:
////					littleEndian = !littleEndian;
////					signal_new_size();
//					{rv = true; break;}				
				case IDC_LESSTHAN:
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),false);
					rs_o = '<';
					{rv = true; break;}
				case IDC_MORETHAN:
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),false);
					rs_o = '>';
					{rv = true; break;}
				case IDC_NOMORETHAN:
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),false);
					rs_o = 'l';
					{rv = true; break;}
				case IDC_NOLESSTHAN:
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),false);
					rs_o = 'm';
					{rv = true; break;}
				case IDC_EQUALTO:
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),false);
					rs_o = '=';
					{rv = true; break;}
				case IDC_DIFFERENTFROM:
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),false);
					rs_o = '!';
					{rv = true; break;}
				case IDC_DIFFERENTBY:
				{
					rs_o = 'd';
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),true);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),false);
					if(!SelectingByKeyboard())
						SelectEditControl(IDC_EDIT_DIFFBY);
				}	{rv = true; break;}
				case IDC_MODULO:
				{
					rs_o = '%';
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_DIFFBY),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_MODBY),true);
					if(!SelectingByKeyboard())
						SelectEditControl(IDC_EDIT_MODBY);
				}	{rv = true; break;}
				case IDC_PREVIOUSVALUE:
					rs_c='r';
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREVALUE),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREADDRESS),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPARECHANGES),false);
					{rv = true; break;}
				case IDC_SPECIFICVALUE:
				{
					rs_c = 's';
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREVALUE),true);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREADDRESS),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPARECHANGES),false);
					if(!SelectingByKeyboard())
						SelectEditControl(IDC_EDIT_COMPAREVALUE);
					{rv = true; break;}
				}
				case IDC_SPECIFICADDRESS:
				{
					rs_c = 'a';
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREADDRESS),true);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREVALUE),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPARECHANGES),false);
					if(!SelectingByKeyboard())
						SelectEditControl(IDC_EDIT_COMPAREADDRESS);
				}	{rv = true; break;}
				case IDC_NUMBEROFCHANGES:
				{
					rs_c = 'n';
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPARECHANGES),true);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREVALUE),false);
					EnableWindow(GetDlgItem(hDlg,IDC_EDIT_COMPAREADDRESS),false);
					if(!SelectingByKeyboard())
						SelectEditControl(IDC_EDIT_COMPARECHANGES);
				}	{rv = true; break;}
				case IDC_C_ADDCHEAT:
				{
					HWND ramListControl = GetDlgItem(hDlg,IDC_RAMLIST);
					int watchItemIndex = ListView_GetNextItem(ramListControl, -1, LVNI_SELECTED);
					while (watchItemIndex >= 0)
					{
						unsigned long address = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_type_size,rs_t=='s',noMisalign, watchItemIndex);
						unsigned long curvalue = CALL_WITH_T_SIZE_TYPES_1(GetCurValueFromItemIndex, rs_type_size,rs_t=='s',noMisalign, watchItemIndex);

						int sizeType = -1;
						if(rs_type_size == 'b')
							sizeType = 0;
						else if(rs_type_size == 'w')
							sizeType = 1;
						else if(rs_type_size == 'd')
							sizeType = 2;

						int numberType = -1;
						if(rs_t == 's')
							numberType = 0;
						else if(rs_t == 'u')
							numberType = 1;
						else if(rs_t == 'h')
							numberType = 2;

						// Don't open cheat dialog

						switch (sizeType) {
						case 0: {
								FCEUI_AddCheat("",address,curvalue,-1,1);
								break; }
						case 1: {
								FCEUI_AddCheat("",address,curvalue & 0xFF,-1,1);
								FCEUI_AddCheat("",address + 1,(curvalue & 0xFF00) / 0x100,-1,1);
								break; }
						case 2: {
								FCEUI_AddCheat("",address,curvalue & 0xFF,-1,1);
								FCEUI_AddCheat("",address + 1,(curvalue & 0xFF00) / 0x100,-1,1);
								FCEUI_AddCheat("",address + 2,(curvalue & 0xFF0000) / 0x10000,-1,1);
								FCEUI_AddCheat("",address + 3,(curvalue & 0xFF000000) / 0x1000000,-1,1);
								break; }
						}

						UpdateCheatsAdded();

						watchItemIndex = ListView_GetNextItem(ramListControl, watchItemIndex, LVNI_SELECTED);

					}
				}	{rv = true; break;}
				case IDC_C_SEARCHROM:
					ShowROM = SendDlgItemMessage(hDlg, IDC_C_SEARCHROM, BM_GETCHECK, 0, 0) != 0;
				case IDC_C_RESET:
				{
					RamSearchSaveUndoStateIfNotTooBig(RamSearchHWnd);
					int prevNumItems = last_rs_possible;

					soft_reset_address_info();

					if(prevNumItems == last_rs_possible)
						SetRamSearchUndoType(RamSearchHWnd, 0); // nothing to undo

					ListView_SetItemState(GetDlgItem(hDlg,IDC_RAMLIST), -1, 0, LVIS_SELECTED); // deselect all
					//ListView_SetItemCount(GetDlgItem(hDlg,IDC_RAMLIST),ResultCount);
					ListView_SetSelectionMark(GetDlgItem(hDlg,IDC_RAMLIST), 0);
					RefreshRamListSelectedCountControlStatus(hDlg);
					Update_RAM_Search();
					{rv = true; break;}
				}
				case IDC_C_RESET_CHANGES:
					memset(s_numChanges, 0, (sizeof(*s_numChanges)*(MAX_RAM_SIZE)));
					ListView_Update(GetDlgItem(hDlg,IDC_RAMLIST), -1);
					Update_RAM_Search();
					//SetRamSearchUndoType(hDlg, 0);
					{rv = true; break;}
				case IDC_C_UNDO:
					if(s_undoType>0)
					{
//						Clear_Sound_Buffer();
						EnterCriticalSection(&s_activeMemoryRegionsCS);
						if(s_activeMemoryRegions.size() < tooManyRegionsForUndo)
						{
							MemoryList tempMemoryList = s_activeMemoryRegions;
							s_activeMemoryRegions = s_activeMemoryRegionsBackup;
							s_activeMemoryRegionsBackup = tempMemoryList;
							LeaveCriticalSection(&s_activeMemoryRegionsCS);
							SetRamSearchUndoType(hDlg, 3 - s_undoType);
						}
						else
						{
							s_activeMemoryRegions = s_activeMemoryRegionsBackup;
							LeaveCriticalSection(&s_activeMemoryRegionsCS);
							SetRamSearchUndoType(hDlg, -1);
						}
						CompactAddrs();
						ListView_SetItemState(GetDlgItem(hDlg,IDC_RAMLIST), -1, 0, LVIS_SELECTED); // deselect all
						ListView_SetSelectionMark(GetDlgItem(hDlg,IDC_RAMLIST), 0);
						RefreshRamListSelectedCountControlStatus(hDlg);
					}
					{rv = true; break;}
				case IDC_C_AUTOSEARCH:
					AutoSearch = SendDlgItemMessage(hDlg, IDC_C_AUTOSEARCH, BM_GETCHECK, 0, 0) != 0;
					AutoSearchAutoRetry = false;
					if (!AutoSearch) {rv = true; break;}
				case IDC_C_SEARCH:
				{
//					Clear_Sound_Buffer();

					if(!rs_val_valid && !(rs_val_valid = Set_RS_Val()))
						goto invalid_field;

					if(ResultCount)
					{
						RamSearchSaveUndoStateIfNotTooBig(hDlg);

						prune(rs_c,rs_o,rs_t=='s',rs_val,rs_param);

						RefreshRamListSelectedCountControlStatus(hDlg);
					}

					if(!ResultCount)
					{

						MessageBox(RamSearchHWnd,"Resetting search.","Out of results.",MB_OK|MB_ICONINFORMATION);
						soft_reset_address_info();
					}

					{rv = true; break;}

invalid_field:
					MessageBox(RamSearchHWnd,"Invalid or out-of-bound entered value.","Error",MB_OK|MB_ICONSTOP);
					if(AutoSearch) // stop autosearch if it just started
					{
						SendDlgItemMessage(hDlg, IDC_C_AUTOSEARCH, BM_SETCHECK, BST_UNCHECKED, 0);
						SendMessage(hDlg, WM_COMMAND, IDC_C_AUTOSEARCH, 0);
					}
					{rv = true; break;}
				}
				case IDC_C_HEXEDITOR:
				{
					HWND ramListControl = GetDlgItem(hDlg,IDC_RAMLIST);
					int selCount = ListView_GetSelectedCount(ramListControl);
					int watchItemIndex = ListView_GetNextItem(ramListControl, -1, LVNI_SELECTED);
					if (watchItemIndex >= 0)
					{
						unsigned int addr = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_type_size, rs_t=='s', noMisalign, watchItemIndex);
						ChangeMemViewFocus(0, addr, -1);
					}
					break;
				}
				case IDC_C_WATCH:
				{
					HWND ramListControl = GetDlgItem(hDlg,IDC_RAMLIST);
					int selCount = ListView_GetSelectedCount(ramListControl);

					bool inserted = false;
					int watchItemIndex = ListView_GetNextItem(ramListControl, -1, LVNI_SELECTED);
					while (watchItemIndex >= 0)
					{
						AddressWatcher tempWatch;
						tempWatch.Address = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_type_size,rs_t=='s',noMisalign, watchItemIndex);
						tempWatch.Size = rs_type_size;
						tempWatch.Type = rs_t;
						tempWatch.WrongEndian = 0; //Replace when I get little endian working
						tempWatch.comment = NULL;

						if (selCount == 1)
							inserted |= InsertWatch(tempWatch, hDlg);
						else
							inserted |= InsertWatch(tempWatch, "");

						watchItemIndex = ListView_GetNextItem(ramListControl, watchItemIndex, LVNI_SELECTED);
					}
					// bring up the ram watch window if it's not already showing so the user knows where the watch went
					if(inserted && !RamWatchHWnd)
						SendMessage(hWnd, WM_COMMAND, ID_RAM_WATCH, 0);
					SetForegroundWindow(RamSearchHWnd);
					{rv = true; break;}
				}

				// eliminate all selected items
				case IDC_C_ELIMINATE:
				{
					RamSearchSaveUndoStateIfNotTooBig(hDlg);

					HWND ramListControl = GetDlgItem(hDlg,IDC_RAMLIST);
					int size = (rs_type_size=='b' || !noMisalign) ? 1 : 2;
					int selCount = ListView_GetSelectedCount(ramListControl);
					int watchIndex = -1;

					// time-saving trick #1:
					// condense the selected items into an array of address ranges
					std::vector<AddrRange> selHardwareAddrs;
					for(int i = 0, j = 1024; i < selCount; ++i, --j)
					{
						watchIndex = ListView_GetNextItem(ramListControl, watchIndex, LVNI_SELECTED);
						int addr = CALL_WITH_T_SIZE_TYPES_1(GetHardwareAddressFromItemIndex, rs_type_size,rs_t=='s',noMisalign, watchIndex);
						if(!selHardwareAddrs.empty() && addr == selHardwareAddrs.back().End())
							selHardwareAddrs.back().size += size;
						else
							selHardwareAddrs.push_back(AddrRange(addr,size));

						if(!j) UpdateRamSearchProgressBar(i * 50 / selCount), j = 1024;
					}

					// now deactivate the ranges

					// time-saving trick #2:
					// take advantage of the fact that the listbox items must be in the same order as the regions
					MemoryList::iterator iter = s_activeMemoryRegions.begin();
					int numHardwareAddrRanges = selHardwareAddrs.size();
					for(int i = 0, j = 16; i < numHardwareAddrRanges; ++i, --j)
					{
						int addr = selHardwareAddrs[i].addr;
						int size = selHardwareAddrs[i].size;
						bool affected = false;
						while(iter != s_activeMemoryRegions.end())
						{
							MemoryRegion& region = *iter;
							int affNow = DeactivateRegion(region, iter, addr, size);
							if(affNow)
								affected = true;
							else if(affected)
								break;
							if(affNow != 2)
								++iter;
						}

						if(!j) UpdateRamSearchProgressBar(50 + (i * 50 / selCount)), j = 16;
					}
					UpdateRamSearchTitleBar();

					// careful -- if the above two time-saving tricks aren't working,
					// the runtime can absolutely explode (seconds -> hours) when there are lots of regions

					ListView_SetItemState(ramListControl, -1, 0, LVIS_SELECTED); // deselect all
					signal_new_size();
					{rv = true; break;}
				}
				//case IDOK:
				case IDCANCEL:
					RamSearchHWnd = NULL;
/*					if (theApp.pauseDuringCheatSearch)
						EndDialog(hDlg, true);	// this should never be called on a modeless dialog
					else
*/
						DestroyWindow(hDlg);
					{rv = true; break;}
			}

			// check refresh for comparison preview color update
			// also, update rs_val if needed
			bool needRefresh = false;
			switch(LOWORD(wParam))
			{
				case IDC_LESSTHAN:
				case IDC_MORETHAN:
				case IDC_NOMORETHAN:
				case IDC_NOLESSTHAN:
				case IDC_EQUALTO:
				case IDC_DIFFERENTFROM:
				case IDC_DIFFERENTBY:
				case IDC_MODULO:
				case IDC_PREVIOUSVALUE:
				case IDC_SPECIFICVALUE:
				case IDC_SPECIFICADDRESS:
				case IDC_NUMBEROFCHANGES:
				case IDC_SIGNED:
				case IDC_UNSIGNED:
				case IDC_HEX:
					rs_val_valid = Set_RS_Val();
					needRefresh = true;
					break;
				case IDC_EDIT_COMPAREVALUE:
				case IDC_EDIT_COMPAREADDRESS:
				case IDC_EDIT_COMPARECHANGES:
				case IDC_EDIT_DIFFBY:
				case IDC_EDIT_MODBY:
					if(HIWORD(wParam) == EN_CHANGE)
					{
						rs_val_valid = Set_RS_Val();
						needRefresh = true;
					}
					break;
			}
			if(needRefresh)
				ListView_Update(GetDlgItem(hDlg,IDC_RAMLIST), -1);


			return rv;
		}	break;

//		case WM_CLOSE:
		case WM_DESTROY:
			RamSearchHWnd = NULL;
//			theApp.modelessCheatDialogIsOpen = false;
//			return true;
			break;
	}

	return false;
}

void UpdateRamSearchTitleBar(int percent)
{
#define HEADER_STR " RAM Search - "
#define PROGRESS_STR " %d%% ... "
#define STATUS_STR "%d Possibilit%s (%d Region%s)"

	int poss = last_rs_possible;
	int regions = last_rs_regions;
	if(poss <= 0)
		strcpy(Str_Tmp," RAM Search");
	else if(percent <= 0)
		sprintf(Str_Tmp, HEADER_STR STATUS_STR, poss, poss==1?"y":"ies", regions, regions==1?"":"s");
	else
		sprintf(Str_Tmp, PROGRESS_STR STATUS_STR, percent, poss, poss==1?"y":"ies", regions, regions==1?"":"s");
	SetWindowText(RamSearchHWnd, Str_Tmp);
}

void UpdatePossibilities(int rs_possible, int regions)
{
	if(rs_possible != last_rs_possible)
	{
		last_rs_possible = rs_possible;
		last_rs_regions = regions;
		UpdateRamSearchTitleBar();
	}
}

void SetRamSearchUndoType(HWND hDlg, int type)
{
	if(s_undoType != type)
	{
		if((s_undoType!=2 && s_undoType!=-1)!=(type!=2 && type!=-1))
			SendDlgItemMessage(hDlg,IDC_C_UNDO,WM_SETTEXT,0,(LPARAM)((type == 2 || type == -1) ? "Redo" : "Undo"));
		if((s_undoType>0)!=(type>0))
			EnableWindow(GetDlgItem(hDlg,IDC_C_UNDO),type>0);
		s_undoType = type;
	}
}

void RamSearchSaveUndoStateIfNotTooBig(HWND hDlg)
{
	EnterCriticalSection(&s_activeMemoryRegionsCS);
	if(s_activeMemoryRegions.size() < tooManyRegionsForUndo)
	{
		s_activeMemoryRegionsBackup = s_activeMemoryRegions;
		LeaveCriticalSection(&s_activeMemoryRegionsCS);
		SetRamSearchUndoType(hDlg, 1);
	}
	else
	{
		LeaveCriticalSection(&s_activeMemoryRegionsCS);
		SetRamSearchUndoType(hDlg, 0);
	}
}

struct InitRamSearch
{
	InitRamSearch()
	{
		InitializeCriticalSection(&s_activeMemoryRegionsCS);
	}
	~InitRamSearch()
	{
		DeleteCriticalSection(&s_activeMemoryRegionsCS);
	}
} initRamSearch;


void init_list_box(HWND Box, const char* Strs[], int numColumns, int *columnWidths) //initializes the ram search and/or ram watch listbox
{
	LVCOLUMN Col;
	Col.mask = LVCF_FMT | LVCF_ORDER | LVCF_SUBITEM | LVCF_TEXT | LVCF_WIDTH;
	Col.fmt = LVCFMT_CENTER;
	for (int i = 0; i < numColumns; i++)
	{
		Col.iOrder = i;
		Col.iSubItem = i;
		Col.pszText = (LPSTR)(Strs[i]);
		Col.cx = columnWidths[i];
		ListView_InsertColumn(Box,i,&Col);
	}

	ListView_SetExtendedListViewStyle(Box, LVS_EX_FULLROWSELECT);
}

void SetSearchType(int SearchType) {
	EnableWindow(GetDlgItem(RamSearchHWnd,IDC_EDIT_DIFFBY),false);
	EnableWindow(GetDlgItem(RamSearchHWnd,IDC_EDIT_MODBY),false);
	
	SendDlgItemMessage(RamSearchHWnd, IDC_LESSTHAN, BM_SETCHECK, SearchType == 0 ? BST_CHECKED : BST_UNCHECKED, 0);
	SendDlgItemMessage(RamSearchHWnd, IDC_MORETHAN, BM_SETCHECK, SearchType == 1 ? BST_CHECKED : BST_UNCHECKED, 0);
	SendDlgItemMessage(RamSearchHWnd, IDC_NOMORETHAN, BM_SETCHECK, SearchType == 2 ? BST_CHECKED : BST_UNCHECKED, 0);
	SendDlgItemMessage(RamSearchHWnd, IDC_NOLESSTHAN, BM_SETCHECK, SearchType == 3 ? BST_CHECKED : BST_UNCHECKED, 0);
	SendDlgItemMessage(RamSearchHWnd, IDC_EQUALTO, BM_SETCHECK, SearchType == 4 ? BST_CHECKED : BST_UNCHECKED, 0);
	SendDlgItemMessage(RamSearchHWnd, IDC_DIFFERENTFROM, BM_SETCHECK, SearchType == 5 ? BST_CHECKED : BST_UNCHECKED, 0);

	switch(SearchType)
	{
		case 0:
			// Less Than
			//SendDlgItemMessage(RamSearchHWnd, IDC_LESSTHAN, BM_SETCHECK, BST_CHECKED, 0);
			rs_o = '<';
			break;
		case 1:
			// Greater Than
			//SendDlgItemMessage(RamSearchHWnd, IDC_MORETHAN, BM_SETCHECK, BST_CHECKED, 0);
			rs_o = '>';
			break;
		case 2:
			// Less Than or Equal
			//SendDlgItemMessage(RamSearchHWnd, IDC_NOMORETHAN, BM_SETCHECK, BST_CHECKED, 0);
			rs_o = 'l';
			break;
		case 3:
			// Greater Than or Equal
			//SendDlgItemMessage(RamSearchHWnd, IDC_NOLESSTHAN, BM_SETCHECK, BST_CHECKED, 0);
			rs_o = 'm';
			break;
		case 4: 
			// Equal
			//SendDlgItemMessage(RamSearchHWnd, IDC_EQUALTO, BM_SETCHECK, BST_CHECKED, 0);
			rs_o = '=';
			break;
		case 5:
			// Not Equal
			//SendDlgItemMessage(RamSearchHWnd, IDC_DIFFERENTFROM, BM_SETCHECK, BST_CHECKED, 0);
			rs_o = '!';
			break;
	}
	return;
}

void DoRamSearchOperation() {
	RamSearchProc(RamSearchHWnd, WM_COMMAND, IDC_C_SEARCH, 0);
	return;
}