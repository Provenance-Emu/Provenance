#include "reios.h"

#include "deps/libelf/elf.h"

#include "hw/sh4/sh4_mem.h"

bool reios_loadElf(const string& elf) {

	FILE* f = fopen(elf.c_str(), "rb");
	if (!f) {
		return false;
	}
	fseek(f, 0, SEEK_END);
	size_t size = ftell(f);

	if (size > 16 * 1024 * 1024) {
		return false;
	}

	void* elfFile = malloc(size);
	memset(elfFile, 0, size);

	fseek(f, 0, SEEK_SET);
	fread(elfFile, 1, size, f);
	fclose(f);

	int i;
	bool phys = false;


	if (elf_checkFile(elfFile) != 0) {
		free(elfFile);
		return false;
	}

	for (i = 0; i < elf_getNumProgramHeaders(elfFile); i++) {
		/* Load that section */
		uint64_t dest, src;
		size_t len;
		if (phys) {
			dest = elf_getProgramHeaderPaddr(elfFile, i);
		}
		else {
			dest = elf_getProgramHeaderVaddr(elfFile, i);
		}
		len = elf_getProgramHeaderFileSize(elfFile, i);
		src = (uint64_t)(uintptr_t)elfFile + elf_getProgramHeaderOffset(elfFile, i);
		
		u8* ptr = GetMemPtr(dest, len);

		memcpy((void*)ptr, (void*)(uintptr_t)src, len);
		ptr += len;
		memset((void*)ptr, 0, elf_getProgramHeaderMemorySize(elfFile, i) - len);
	}

	return true;
}