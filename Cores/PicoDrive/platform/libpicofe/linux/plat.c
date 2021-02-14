/*
 * (C) Gražvydas "notaz" Ignotas, 2008-2012
 *
 * This work is licensed under the terms of any of these licenses
 * (at your option):
 *  - GNU GPL, version 2 or later.
 *  - GNU LGPL, version 2.1 or later.
 *  - MAME license.
 * See the COPYING file in the top-level directory.
 */

#define _GNU_SOURCE 1
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <dirent.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include <sys/mman.h>
#include <errno.h>
#include <sys/stat.h>

#include "../plat.h"

/* XXX: maybe unhardcode pagesize? */
#define HUGETLB_PAGESIZE (2 * 1024 * 1024)
#define HUGETLB_THRESHOLD (HUGETLB_PAGESIZE / 2)
#ifndef MAP_HUGETLB
#define MAP_HUGETLB 0x40000 /* arch specific */
#endif


int plat_is_dir(const char *path)
{
	DIR *dir;
	if ((dir = opendir(path))) {
		closedir(dir);
		return 1;
	}
	return 0;
}

static int plat_get_data_dir(char *dst, int len)
{
#ifdef PICO_DATA_DIR
	memcpy(dst, PICO_DATA_DIR, sizeof PICO_DATA_DIR);
	return sizeof(PICO_DATA_DIR) - 1;
#else
	int j, ret = readlink("/proc/self/exe", dst, len - 1);
	if (ret < 0) {
		perror("readlink");
		ret = 0;
	}
	dst[ret] = 0;

	for (j = ret - 1; j > 0; j--)
		if (dst[j] == '/') {
			dst[++j] = 0;
			break;
		}
	return j;
#endif
}

int plat_get_skin_dir(char *dst, int len)
{
	int ret = plat_get_data_dir(dst, len);
	if (ret < 0)
		return ret;

	memcpy(dst + ret, "skin/", sizeof "skin/");
	return ret + sizeof("skin/") - 1;
}

#ifndef PICO_HOME_DIR
#define PICO_HOME_DIR "/.picodrive/"
#endif
int plat_get_root_dir(char *dst, int len)
{
#if !defined(__GP2X__) && !defined(PANDORA)
	const char *home = getenv("HOME");
	int ret;

	if (home != NULL) {
		ret = snprintf(dst, len, "%s%s", home, PICO_HOME_DIR);
		if (ret >= len)
			ret = len - 1;
		mkdir(dst, 0755);
		return ret;
	}
#endif
	return plat_get_data_dir(dst, len);
}

#ifdef __GP2X__
/* Wiz has a borked gettimeofday().. */
#define plat_get_ticks_ms plat_get_ticks_ms_good
#define plat_get_ticks_us plat_get_ticks_us_good
#endif

unsigned int plat_get_ticks_ms(void)
{
	struct timeval tv;
	unsigned int ret;

	gettimeofday(&tv, NULL);

	ret = (unsigned)tv.tv_sec * 1000;
	/* approximate /= 1000 */
	ret += ((unsigned)tv.tv_usec * 4195) >> 22;

	return ret;
}

unsigned int plat_get_ticks_us(void)
{
	struct timeval tv;
	unsigned int ret;

	gettimeofday(&tv, NULL);

	ret = (unsigned)tv.tv_sec * 1000000;
	ret += (unsigned)tv.tv_usec;

	return ret;
}

void plat_sleep_ms(int ms)
{
	usleep(ms * 1000);
}

int plat_wait_event(int *fds_hnds, int count, int timeout_ms)
{
	struct timeval tv, *timeout = NULL;
	int i, ret, fdmax = -1;
	fd_set fdset;

	if (timeout_ms >= 0) {
		tv.tv_sec = timeout_ms / 1000;
		tv.tv_usec = (timeout_ms % 1000) * 1000;
		timeout = &tv;
	}

	FD_ZERO(&fdset);
	for (i = 0; i < count; i++) {
		if (fds_hnds[i] > fdmax) fdmax = fds_hnds[i];
		FD_SET(fds_hnds[i], &fdset);
	}

	ret = select(fdmax + 1, &fdset, NULL, NULL, timeout);
	if (ret == -1)
	{
		perror("plat_wait_event: select failed");
		sleep(1);
		return -1;
	}

	if (ret == 0)
		return -1; /* timeout */

	ret = -1;
	for (i = 0; i < count; i++)
		if (FD_ISSET(fds_hnds[i], &fdset))
			ret = fds_hnds[i];

	return ret;
}

void *plat_mmap(unsigned long addr, size_t size, int need_exec, int is_fixed)
{
	static int hugetlb_warned;
	int prot = PROT_READ | PROT_WRITE;
	int flags = MAP_PRIVATE | MAP_ANONYMOUS;
	void *req, *ret;

	req = (void *)addr;
	if (need_exec)
		prot |= PROT_EXEC;
	if (is_fixed)
		flags |= MAP_FIXED;
	if (size >= HUGETLB_THRESHOLD)
		flags |= MAP_HUGETLB;

	ret = mmap(req, size, prot, flags, -1, 0);
	if (ret == MAP_FAILED && (flags & MAP_HUGETLB)) {
		if (!hugetlb_warned) {
			fprintf(stderr,
				"warning: failed to do hugetlb mmap (%p, %zu): %d\n",
				req, size, errno);
			hugetlb_warned = 1;
		}
		flags &= ~MAP_HUGETLB;
		ret = mmap(req, size, prot, flags, -1, 0);
	}
	if (ret == MAP_FAILED)
		return NULL;

	if (req != NULL && ret != req)
		fprintf(stderr,
			"warning: mmaped to %p, requested %p\n", ret, req);

	return ret;
}

void *plat_mremap(void *ptr, size_t oldsize, size_t newsize)
{
	void *ret;

	ret = mremap(ptr, oldsize, newsize, MREMAP_MAYMOVE);
	if (ret == MAP_FAILED)
		return NULL;
	if (ret != ptr)
		printf("warning: mremap moved: %p -> %p\n", ptr, ret);

	return ret;
}

void plat_munmap(void *ptr, size_t size)
{
	int ret;

	ret = munmap(ptr, size);
	if (ret != 0 && (size & (HUGETLB_PAGESIZE - 1))) {
		// prehaps an autorounded hugetlb mapping?
		size = (size + HUGETLB_PAGESIZE - 1) & ~(HUGETLB_PAGESIZE - 1);
		ret = munmap(ptr, size);
	}
	if (ret != 0) {
		fprintf(stderr,
			"munmap(%p, %zu) failed: %d\n", ptr, size, errno);
	}
}

int plat_mem_set_exec(void *ptr, size_t size)
{
	int ret = mprotect(ptr, size, PROT_READ | PROT_WRITE | PROT_EXEC);
	if (ret != 0)
		fprintf(stderr, "mprotect(%p, %zd) failed: %d\n",
			ptr, size, errno);

	return ret;
}

/* lprintf */
void lprintf(const char *fmt, ...)
{
	va_list vl;

	va_start(vl, fmt);
	vprintf(fmt, vl);
	va_end(vl);
}

