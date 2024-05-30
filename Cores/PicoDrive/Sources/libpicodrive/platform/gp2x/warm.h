/*
 * wARM - exporting ARM processor specific privileged services to userspace
 * library functions
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
#ifndef __WARM_H__
#define __WARM_H__ 1

/* cache operations (warm_cache_op_*):
 * o clean - write dirty data to memory, but also leave in cache.
 * o invalidate - throw away everything in cache, losing dirty data.
 *
 * Write buffer is always drained, no ops will only drain WB
 */
#define WOP_D_CLEAN		(1 << 0)
#define WOP_D_INVALIDATE	(1 << 1)
#define WOP_I_INVALIDATE	(1 << 2)

/* change C and B bits (warm_change_cb_*)
 * if is_set in not zero, bits are set, else cleared.
 * the address for range function is virtual address.
 */
#define WCB_C_BIT		(1 << 0)
#define WCB_B_BIT		(1 << 1)

#ifndef __ASSEMBLER__

#ifdef __cplusplus
extern "C"
{
#endif

int warm_init(void);

int warm_cache_op_range(int ops, void *virt_addr, unsigned long size);
int warm_cache_op_all(int ops);

int warm_change_cb_upper(int cb, int is_set);
int warm_change_cb_range(int cb, int is_set, void *virt_addr, unsigned long size);

unsigned long warm_virt2phys(const void *ptr);

void warm_finish(void);

#ifdef __cplusplus
}
#endif

/* internal */
#ifdef WARM_CODE

#include <linux/ioctl.h>

#define WARM_IOCTL_BASE 'A'

struct warm_cache_op
{
	unsigned long addr;
	unsigned long size;
	int ops;
};

struct warm_change_cb
{
	unsigned long addr;
	unsigned long size;
	int cb;
	int is_set;
};

#define WARMC_CACHE_OP	_IOW(WARM_IOCTL_BASE,  0, struct warm_cache_op)
#define WARMC_CHANGE_CB	_IOW(WARM_IOCTL_BASE,  1, struct warm_change_cb)
#define WARMC_VIRT2PHYS	_IOWR(WARM_IOCTL_BASE, 2, unsigned long)

#endif /* WARM_CODE */
#endif /* !__ASSEMBLER__ */
#endif /* __WARM_H__ */
