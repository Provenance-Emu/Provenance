/* 
 * basic, incomplete SSP160x (SSP1601?) interpreter
 *
 * Copyright (c) Gražvydas "notaz" Ignotas, 2008
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

// register names
enum {
	SSP_GR0, SSP_X,     SSP_Y,   SSP_A,
	SSP_ST,  SSP_STACK, SSP_PC,  SSP_P,
	SSP_PM0, SSP_PM1,   SSP_PM2, SSP_XST,
	SSP_PM4, SSP_gr13,  SSP_PMC, SSP_AL
};

typedef union
{
	unsigned int v;
	struct {
		unsigned short l;
		unsigned short h;
	};
} ssp_reg_t;

typedef struct
{
	union {
		unsigned short RAM[256*2];	// 000 2 internal RAM banks
		struct {
			unsigned short RAM0[256];
			unsigned short RAM1[256];
		};
	};
	ssp_reg_t gr[16];			// 400 general registers
	union {
		unsigned char r[8];		// 440 BANK pointers
		struct {
			unsigned char r0[4];
			unsigned char r1[4];
		};
	};
	unsigned short stack[6];		// 448
	unsigned int pmac_read[6];		// 454 read modes/addrs for PM0-PM5
	unsigned int pmac_write[6];		// 46c write ...
	//
	#define SSP_PMC_HAVE_ADDR	0x0001	// address written to PMAC, waiting for mode
	#define SSP_PMC_SET		0x0002	// PMAC is set
	#define SSP_WAIT_PM0		0x2000	// bit1 in PM0
	#define SSP_WAIT_30FE06		0x4000	// ssp tight loops on 30FE06 to become non-zero
	#define SSP_WAIT_30FE08		0x8000	// same for 30FE06
	#define SSP_WAIT_MASK		0xe000
	unsigned int emu_status;		// 484
	/* used by recompiler only: */
	struct {
		unsigned int ptr_rom;		// 488
		unsigned int ptr_iram_rom;	// 48c
		unsigned int ptr_dram;		// 490
		unsigned int iram_dirty;	// 494
		unsigned int iram_context;	// 498
		unsigned int ptr_btable;	// 49c
		unsigned int ptr_btable_iram;	// 4a0
		unsigned int tmp0;		// 4a4
		unsigned int tmp1;		// 4a8
		unsigned int tmp2;		// 4ac
	} drc;
} ssp1601_t;


void ssp1601_reset(ssp1601_t *ssp);
void ssp1601_run(int cycles);

