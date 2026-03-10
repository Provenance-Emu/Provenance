/*
 * PicoDrive
 * (C) notaz, 2009,2010
 *
 * This work is licensed under the terms of MAME license.
 * See COPYING file in the top-level directory.
 */
#include <windows.h>
#include <stdio.h>
#include <dirent.h>

#include "../libpicofe/plat.h"
#include "../libpicofe/posix.h"
#include "../common/emu.h"
#include <pico/pico_int.h>

int plat_is_dir(const char *path)
{
	return (GetFileAttributes(path) & FILE_ATTRIBUTE_DIRECTORY) ? 1 : 0;
}

unsigned int plat_get_ticks_ms(void)
{
	return GetTickCount();
}

unsigned int plat_get_ticks_us(void)
{
	// XXX: maybe performance counters?
	return GetTickCount() * 1000;
}

void plat_sleep_ms(int ms)
{
	Sleep(ms);
}

int plat_wait_event(int *fds_hnds, int count, int timeout_ms)
{
	return -1;
}

int plat_get_root_dir(char *dst, int len)
{
	int ml;

	ml = GetModuleFileName(NULL, dst, len);
	while (ml > 0 && dst[ml] != '\\')
		ml--;
	if (ml != 0)
		ml++;

	dst[ml] = 0;
	return ml;
}

int plat_get_skin_dir(char *dst, int len)
{
	int ml;

	ml = GetModuleFileName(NULL, dst, len);
	while (ml > 0 && dst[ml] != '\\')
		ml--;
	if (ml != 0)
		dst[ml++] = '\\';
	memcpy(dst + ml, "skin\\", sizeof("skin\\"));
	dst[ml + sizeof("skin\\")] = 0;
	return ml + sizeof("skin\\") - 1;
}

int plat_get_data_dir(char *dst, int len)
{
	return plat_get_root_dir(dst, len);
}

void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed)
{
	void *ptr;
	unsigned long old;

	ptr = VirtualAlloc(NULL, size, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE);
	if (ptr && need_exec)
		VirtualProtect(ptr, size, PAGE_EXECUTE_READWRITE, &old);
	return ptr;
}

void plat_munmap(void *ptr, size_t size)
{
	VirtualFree(ptr, 0, MEM_RELEASE);
}

void *plat_mremap(void *ptr, size_t oldsize, size_t newsize)
{
	void *ret = plat_mmap(0, newsize, 0, 0);
	if (ret != NULL) {
		memcpy(ret, ptr, oldsize);
		plat_munmap(ptr, oldsize);
	}
	return ret;
}

int   plat_mem_set_exec(void *ptr, size_t size)
{
	unsigned long old;

	return -(VirtualProtect(ptr, size, PAGE_EXECUTE_READWRITE, &old) == 0);
}

// other
void lprintf(const char *fmt, ...)
{
  char buf[512];
  va_list val;

  va_start(val, fmt);
  vsnprintf(buf, sizeof(buf), fmt, val);
  va_end(val);
  OutputDebugString(buf);
  printf("%s", buf);
}

// missing from mingw32
int scandir(const char *dir, struct dirent ***namelist, int (*select)(const struct dirent *), int (*compar)(const struct dirent **, const struct dirent **)) {
    HANDLE handle;
    WIN32_FIND_DATA info;
    char path[MAX_PATH];
    struct dirent **entries = NULL;
    size_t count = 0;

    snprintf(path, sizeof(path), "%s\\*", dir);
    handle = FindFirstFile(path, &info);
    if (handle == INVALID_HANDLE_VALUE)
        return -1;

    do {
        struct dirent *entry = (struct dirent *)malloc(sizeof(struct dirent));
        if (!entry) {
            free(entries);
            FindClose(handle);
            return -1;
        }

        strcpy(entry->d_name, info.cFileName);
        entry->d_type = (info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ? DT_DIR : DT_REG;

        if (!select || select(entry)) {
            entries = realloc(entries, (count + 1) * sizeof(struct dirent *));
            entries[count++] = entry;
        } else
            free(entry);
    } while (FindNextFile(handle, &info));

    FindClose(handle);

    // Sort entries if a comparison function is provided
    if (compar) {
        qsort(entries, count, sizeof(struct dirent *), (int (*)(const void *, const void *))compar);
    }

    *namelist = entries;
    return count;
}

int alphasort(const struct dirent **a, const struct dirent **b) {
    return strcmp((*a)->d_name, (*b)->d_name);
}
