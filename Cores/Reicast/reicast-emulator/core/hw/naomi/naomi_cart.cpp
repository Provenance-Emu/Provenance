#include "naomi_cart.h"
#include "cfg/cfg.h"

u8* RomPtr;
u32 RomSize;

#if HOST_OS == OS_WINDOWS
	typedef HANDLE fd_t;
	#define INVALID_FD INVALID_HANDLE_VALUE
#else
	typedef int fd_t;
	#define INVALID_FD -1

	#include <unistd.h>
	#include <fcntl.h>
	#include <sys/mman.h>
#endif

fd_t*	RomCacheMap = NULL;
u32		RomCacheMapCount;

char SelectedFile[512];

bool naomi_cart_LoadRom(char* file)
{

	printf("\nnullDC-Naomi rom loader v1.2\n");

	size_t folder_pos = strlen(file) - 1;
	while (folder_pos>1 && (file[folder_pos] != '\\' && file[folder_pos] != '/'))
		folder_pos--;

	folder_pos++;

	// FIXME: Data loss if buffer is too small
	char t[512];
	strncpy(t, file, sizeof(t));
	t[sizeof(t) - 1] = '\0';

	FILE* fl = fopen(t, "r");
	if (!fl)
		return false;

	char* line = fgets(t, 512, fl);
	if (!line)
	{
		fclose(fl);
		return false;
	}

	char* eon = strstr(line, "\n");
	if (!eon)
		printf("+Loading naomi rom that has no name\n");
	else
		*eon = 0;

	printf("+Loading naomi rom : %s\n", line);

	line = fgets(t, 512, fl);
	if (!line)
	{
		fclose(fl);
		return false;
	}

	vector<string> files;
	vector<u32> fstart;
	vector<u32> fsize;

	u32 setsize = 0;
	RomSize = 0;

	while (line)
	{
		char filename[512];
		u32 addr, sz;
		sscanf(line, "\"%[^\"]\",%x,%x", filename, &addr, &sz);
		files.push_back(filename);
		fstart.push_back(addr);
		fsize.push_back(sz);
		setsize += sz;
		RomSize = max(RomSize, (addr + sz));
		line = fgets(t, 512, fl);
	}
	fclose(fl);

	printf("+%d romfiles, %.2f MB set size, %.2f MB set address space\n", files.size(), setsize / 1024.f / 1024.f, RomSize / 1024.f / 1024.f);

	if (RomCacheMap)
	{
		RomCacheMapCount = 0;
		delete[] RomCacheMap;
	}

	RomCacheMapCount = (u32)files.size();
	RomCacheMap = new fd_t[files.size()];

	// FIXME: Data loss if buffer is too small
	strncpy(t, file, sizeof(t));
	t[sizeof(t) - 1] = '\0';

	t[folder_pos] = 0;
	strcat(t, "ndcn-composed.cache");

	//Allocate space for the ram, so we are sure we have a segment of continius ram
#if HOST_OS == OS_WINDOWS
	RomPtr = (u8*)VirtualAlloc(0, RomSize, MEM_RESERVE, PAGE_NOACCESS);
#else
	RomPtr = (u8*)mmap(0, RomSize, PROT_NONE, MAP_PRIVATE | MAP_ANON, -1, 0);
#endif

	verify(RomPtr != 0);
	verify(RomPtr != (void*)-1);

	// FIXME: Data loss if buffer is too small
	strncpy(t, file, sizeof(t));
	t[sizeof(t) - 1] = '\0';

	//Create File Mapping Objects
	for (size_t i = 0; i<files.size(); i++)
	{
		t[folder_pos] = 0;
		strcat(t, files[i].c_str());
		fd_t RomCache;

		if (strcmp(files[i].c_str(), "null") == 0)
		{
			RomCacheMap[i] = INVALID_FD;
			continue;
		}
#if HOST_OS == OS_WINDOWS
		RomCache = CreateFile(t, FILE_READ_ACCESS, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
#else
		RomCache = open(t, O_RDONLY);
#endif
		if (RomCache == INVALID_FD)
		{
			wprintf(L"-Unable to read file %s\n", files[i].c_str());
			RomCacheMap[i] = INVALID_FD;
			continue;
		}

#if HOST_OS == OS_WINDOWS
		RomCacheMap[i] = CreateFileMapping(RomCache, 0, PAGE_READONLY, 0, fsize[i], 0);
		verify(CloseHandle(RomCache));
#else
		RomCacheMap[i] = RomCache;
#endif

		verify(RomCacheMap[i] != INVALID_FD);
		wprintf(L"-Preparing \"%s\" at 0x%08X, size 0x%08X\n", files[i].c_str(), fstart[i], fsize[i]);
	}

	//We have all file mapping objects, we start to map the ram
	printf("+Mapping ROM\n");
	//Release the segment we reserved so we can map the files there
#if HOST_OS == OS_WINDOWS
	verify(VirtualFree(RomPtr, 0, MEM_RELEASE));
#else
	munmap(RomPtr, RomSize);
#endif

	//Map the files into the segment of the ram that was reserved
	for (size_t i = 0; i<RomCacheMapCount; i++)
	{
		u8* RomDest = RomPtr + fstart[i];

		if (RomCacheMap[i] == INVALID_FD)
		{
			wprintf(L"-Reserving ram at 0x%08X, size 0x%08X\n", fstart[i], fsize[i]);
			
#if HOST_OS == OS_WINDOWS
			bool mapped = RomDest == VirtualAlloc(RomDest, fsize[i], MEM_RESERVE, PAGE_NOACCESS);
#else
			bool mapped = RomDest == (u8*)mmap(RomDest, RomSize, PROT_NONE, MAP_PRIVATE, 0, 0);
#endif

			verify(mapped);
		}
		else
		{
			wprintf(L"-Mapping \"%s\" at 0x%08X, size 0x%08X\n", files[i].c_str(), fstart[i], fsize[i]);
#if HOST_OS == OS_WINDOWS
			bool mapped = RomDest != MapViewOfFileEx(RomCacheMap[i], FILE_MAP_READ, 0, 0, fsize[i], RomDest);
#else
			bool mapped = RomDest != mmap(RomDest, fsize[i], PROT_READ, MAP_PRIVATE, RomCacheMap[i], 0 );
#endif
			if (!mapped)
			{
				printf("-Mapping ROM FAILED\n");
				//unmap file
				return false;
			}
		}
	}

	//done :)
	printf("\nMapped ROM Successfully !\n\n");


	return true;
}

bool naomi_cart_SelectFile(void* handle)
{
	cfgLoadStr("config", "image", SelectedFile, "null");
	
#if HOST_OS == OS_WINDOWS
	if (strcmp(SelectedFile, "null") == 0) {
		OPENFILENAME ofn = { 0 };
		ofn.lStructSize = sizeof(OPENFILENAME);
		ofn.hInstance = (HINSTANCE)GetModuleHandle(0);
		ofn.lpstrFile = SelectedFile;
		ofn.nMaxFile = MAX_PATH;
		ofn.lpstrFilter = "*.lst\0*.lst\0\0";
		ofn.nFilterIndex = 0;
		ofn.hwndOwner = (HWND)handle;
		ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR;

		if (GetOpenFileName(&ofn) <= 0)
			return true;
	}
#endif
	if (!naomi_cart_LoadRom(SelectedFile))
	{
		cfgSaveStr("emu", "gamefile", "naomi_bios");
	}
	else
	{
		cfgSaveStr("emu", "gamefile", SelectedFile);
	}


	printf("EEPROM file : %s.eeprom\n", SelectedFile);

	return true;
}

bool naomi_cart_Read(u32 offset, u32 size, void* dst) {
	if (!RomPtr)
		return false;

	memcpy(dst, naomi_cart_GetPtr(offset, size), size);
	return true;
}

void* naomi_cart_GetPtr(u32 offset, u32 size) {

	offset &= 0x0FFFffff;

	verify(offset < RomSize);
	verify((offset + size) < RomSize);

	return &RomPtr[offset];
}
