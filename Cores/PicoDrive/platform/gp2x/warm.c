/*
 * wARM - exporting ARM processor specific privileged services to userspace
 * userspace part
 *
 * Copyright (c) Gražvydas "notaz" Ignotas, 2009
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the organization nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/utsname.h>
#include <sys/syscall.h>
#include <errno.h>

#define WARM_CODE
#include "warm.h"

/* provided by glibc */
extern long init_module(void *, unsigned long, const char *);
extern long delete_module(const char *, unsigned int);

static int warm_fd = -1;
static int kernel_version;

static void sys_cacheflush(void *start, void *end)
{
#ifdef __ARM_EABI__
	/* EABI version */
	int num = __ARM_NR_cacheflush;
	__asm__("mov  r0, %0 ;"
		"mov  r1, %1 ;"
		"mov  r2, #0 ;"
		"mov  r7, %2 ;"
		"swi  0" : : "r" (start), "r" (end), "r" (num)
			: "r0", "r1", "r2", "r3", "r7");
#else
	/* OABI */
	__asm__("mov  r0, %0 ;"
		"mov  r1, %1 ;"
		"mov  r2, #0 ;"
		"swi  %2" : : "r" (start), "r" (end), "i" __ARM_NR_cacheflush
			: "r0", "r1", "r2", "r3");
#endif
}

/* Those are here because system() occasionaly fails on Wiz
 * with errno 12 for some unknown reason */
static int manual_insmod_26(const char *fname, const char *opts)
{
	unsigned long len, read_len;
	int ret = -1;
	void *buff;
	FILE *f;

	f = fopen(fname, "rb");
	if (f == NULL)
		return -1;

	fseek(f, 0, SEEK_END);
	len = ftell(f);
	fseek(f, 0, SEEK_SET);

	buff = malloc(len);
	if (buff == NULL)
		goto fail0;

	read_len = fread(buff, 1, len, f);
	if (read_len != len) {
		fprintf(stderr, "failed to read module\n");
		goto fail1;
	}

	ret = init_module(buff, len, opts);

fail1:
	free(buff);
fail0:
	fclose(f);
	return ret;
}

static int manual_rmmod(const char *name)
{
	return delete_module(name, O_NONBLOCK|O_EXCL);
}

int warm_init(void)
{
	struct utsname unm;
	char buff1[32], buff2[128];
	int ret;

	memset(&unm, 0, sizeof(unm));
	uname(&unm);

	if (strlen(unm.release) < 3 || unm.release[1] != '.') {
		fprintf(stderr, "unexpected version string: %s\n", unm.release);
		goto fail;
	}
	kernel_version = ((unm.release[0] - '0') << 4) | (unm.release[2] - '0');

	warm_fd = open("/proc/warm", O_RDWR);
	if (warm_fd >= 0)
		return 0;

	snprintf(buff1, sizeof(buff1), "warm_%s.%s", unm.release, kernel_version >= 0x26 ? "ko" : "o");
	snprintf(buff2, sizeof(buff2), "/sbin/insmod %s verbose=1", buff1);

	/* try to insmod */
	ret = system(buff2);
	if (ret != 0) {
		fprintf(stderr, "system/insmod failed: %d %d\n", ret, errno);
		if (kernel_version >= 0x26) {
			ret = manual_insmod_26(buff1, "verbose=1");
			if (ret != 0)
				fprintf(stderr, "manual insmod also failed: %d\n", ret);
		}
	}

	warm_fd = open("/proc/warm", O_RDWR);
	if (warm_fd >= 0)
		return 0;

fail:
	fprintf(stderr, "wARM: can't init, acting as sys_cacheflush wrapper\n");
	return -1;
}

void warm_finish(void)
{
	char name[32], cmd[64];
	int ret;

	if (warm_fd < 0)
		return;

	close(warm_fd);
	warm_fd = -1;

	if (kernel_version < 0x26) {
		struct utsname unm;
		memset(&unm, 0, sizeof(unm));
		uname(&unm);
		snprintf(name, sizeof(name), "warm_%s", unm.release);
	}
	else
		strcpy(name, "warm");

	snprintf(cmd, sizeof(cmd), "/sbin/rmmod %s", name);
	ret = system(cmd);
	if (ret != 0) {
		fprintf(stderr, "system/rmmod failed: %d %d\n", ret, errno);
		manual_rmmod(name);
	}
}

int warm_cache_op_range(int op, void *addr, unsigned long size)
{
	struct warm_cache_op wop;
	int ret;

	if (warm_fd < 0) {
		/* note that this won't work for warm_cache_op_all */
		sys_cacheflush(addr, (char *)addr + size);
		return -1;
	}

	wop.ops = op;
	wop.addr = (unsigned long)addr;
	wop.size = size;

	ret = ioctl(warm_fd, WARMC_CACHE_OP, &wop);
	if (ret != 0) {
		perror("WARMC_CACHE_OP failed");
		return -1;
	}

	return 0;
}

int warm_cache_op_all(int op)
{
	return warm_cache_op_range(op, NULL, (unsigned long)-1);
}

int warm_change_cb_range(int cb, int is_set, void *addr, unsigned long size)
{
	struct warm_change_cb ccb;
	int ret;

	if (warm_fd < 0)
		return -1;
	
	ccb.addr = (unsigned long)addr;
	ccb.size = size;
	ccb.cb = cb;
	ccb.is_set = is_set;

	ret = ioctl(warm_fd, WARMC_CHANGE_CB, &ccb);
	if (ret != 0) {
		perror("WARMC_CHANGE_CB failed");
		return -1;
	}

	return 0;
}

int warm_change_cb_upper(int cb, int is_set)
{
	return warm_change_cb_range(cb, is_set, 0, 0);
}

unsigned long warm_virt2phys(const void *ptr)
{
	unsigned long ptrio;
	int ret;

	ptrio = (unsigned long)ptr;
	ret = ioctl(warm_fd, WARMC_VIRT2PHYS, &ptrio);
	if (ret != 0) {
		perror("WARMC_VIRT2PHYS failed");
		return (unsigned long)-1;
	}

	return ptrio;
}

