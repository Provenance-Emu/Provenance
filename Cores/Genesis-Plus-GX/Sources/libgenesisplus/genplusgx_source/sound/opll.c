#ifdef HAVE_OPLL_CORE
/*
 * Copyright (C) 2019 Nuke.YKT
 * 
 *  Redistribution and use of this code or any derivative works are permitted
 *  provided that the following conditions are met:
 *
 *   - Redistributions may not be sold, nor may they be used in a commercial
 *     product or activity.
 *
 *   - Redistributions that are modified from the original source must include the
 *     complete source code, including the source code for all components used by a
 *     binary built from the modified sources. However, as a special exception, the
 *     source code distributed need not include anything that is normally distributed
 *     (in either source or binary form) with the major components (compiler, kernel,
 *     and so on) of the operating system on which the executable runs, unless that
 *     component itself accompanies the executable.
 *
 *   - Redistributions must reproduce the above copyright notice, this list of
 *     conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *  POSSIBILITY OF SUCH DAMAGE.
 *
 *
 *  Yamaha YM2413 emulator
 *  Thanks:
 *      siliconpr0n.org(digshadow, John McMaster):
 *          VRC VII decap and die shot.
 *
 *  version: 1.0
 */

#include <string.h>
#include "opll.h"

enum {
    eg_num_attack = 0,
    eg_num_decay = 1,
    eg_num_sustain = 2,
    eg_num_release = 3
};

enum {
    rm_num_bd0 = 0,
    rm_num_hh = 1,
    rm_num_tom = 2,
    rm_num_bd1 = 3,
    rm_num_sd = 4,
    rm_num_tc = 5
};

/* logsin table */
static const uint16_t logsinrom[256] = {
    0x859, 0x6c3, 0x607, 0x58b, 0x52e, 0x4e4, 0x4a6, 0x471,
    0x443, 0x41a, 0x3f5, 0x3d3, 0x3b5, 0x398, 0x37e, 0x365,
    0x34e, 0x339, 0x324, 0x311, 0x2ff, 0x2ed, 0x2dc, 0x2cd,
    0x2bd, 0x2af, 0x2a0, 0x293, 0x286, 0x279, 0x26d, 0x261,
    0x256, 0x24b, 0x240, 0x236, 0x22c, 0x222, 0x218, 0x20f,
    0x206, 0x1fd, 0x1f5, 0x1ec, 0x1e4, 0x1dc, 0x1d4, 0x1cd,
    0x1c5, 0x1be, 0x1b7, 0x1b0, 0x1a9, 0x1a2, 0x19b, 0x195,
    0x18f, 0x188, 0x182, 0x17c, 0x177, 0x171, 0x16b, 0x166,
    0x160, 0x15b, 0x155, 0x150, 0x14b, 0x146, 0x141, 0x13c,
    0x137, 0x133, 0x12e, 0x129, 0x125, 0x121, 0x11c, 0x118,
    0x114, 0x10f, 0x10b, 0x107, 0x103, 0x0ff, 0x0fb, 0x0f8,
    0x0f4, 0x0f0, 0x0ec, 0x0e9, 0x0e5, 0x0e2, 0x0de, 0x0db,
    0x0d7, 0x0d4, 0x0d1, 0x0cd, 0x0ca, 0x0c7, 0x0c4, 0x0c1,
    0x0be, 0x0bb, 0x0b8, 0x0b5, 0x0b2, 0x0af, 0x0ac, 0x0a9,
    0x0a7, 0x0a4, 0x0a1, 0x09f, 0x09c, 0x099, 0x097, 0x094,
    0x092, 0x08f, 0x08d, 0x08a, 0x088, 0x086, 0x083, 0x081,
    0x07f, 0x07d, 0x07a, 0x078, 0x076, 0x074, 0x072, 0x070,
    0x06e, 0x06c, 0x06a, 0x068, 0x066, 0x064, 0x062, 0x060,
    0x05e, 0x05c, 0x05b, 0x059, 0x057, 0x055, 0x053, 0x052,
    0x050, 0x04e, 0x04d, 0x04b, 0x04a, 0x048, 0x046, 0x045,
    0x043, 0x042, 0x040, 0x03f, 0x03e, 0x03c, 0x03b, 0x039,
    0x038, 0x037, 0x035, 0x034, 0x033, 0x031, 0x030, 0x02f,
    0x02e, 0x02d, 0x02b, 0x02a, 0x029, 0x028, 0x027, 0x026,
    0x025, 0x024, 0x023, 0x022, 0x021, 0x020, 0x01f, 0x01e,
    0x01d, 0x01c, 0x01b, 0x01a, 0x019, 0x018, 0x017, 0x017,
    0x016, 0x015, 0x014, 0x014, 0x013, 0x012, 0x011, 0x011,
    0x010, 0x00f, 0x00f, 0x00e, 0x00d, 0x00d, 0x00c, 0x00c,
    0x00b, 0x00a, 0x00a, 0x009, 0x009, 0x008, 0x008, 0x007,
    0x007, 0x007, 0x006, 0x006, 0x005, 0x005, 0x005, 0x004,
    0x004, 0x004, 0x003, 0x003, 0x003, 0x002, 0x002, 0x002,
    0x002, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001, 0x001,
    0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000, 0x000
};

/* exp table */
static const uint16_t exprom[256] = {
    0x7fa, 0x7f5, 0x7ef, 0x7ea, 0x7e4, 0x7df, 0x7da, 0x7d4,
    0x7cf, 0x7c9, 0x7c4, 0x7bf, 0x7b9, 0x7b4, 0x7ae, 0x7a9,
    0x7a4, 0x79f, 0x799, 0x794, 0x78f, 0x78a, 0x784, 0x77f,
    0x77a, 0x775, 0x770, 0x76a, 0x765, 0x760, 0x75b, 0x756,
    0x751, 0x74c, 0x747, 0x742, 0x73d, 0x738, 0x733, 0x72e,
    0x729, 0x724, 0x71f, 0x71a, 0x715, 0x710, 0x70b, 0x706,
    0x702, 0x6fd, 0x6f8, 0x6f3, 0x6ee, 0x6e9, 0x6e5, 0x6e0,
    0x6db, 0x6d6, 0x6d2, 0x6cd, 0x6c8, 0x6c4, 0x6bf, 0x6ba,
    0x6b5, 0x6b1, 0x6ac, 0x6a8, 0x6a3, 0x69e, 0x69a, 0x695,
    0x691, 0x68c, 0x688, 0x683, 0x67f, 0x67a, 0x676, 0x671,
    0x66d, 0x668, 0x664, 0x65f, 0x65b, 0x657, 0x652, 0x64e,
    0x649, 0x645, 0x641, 0x63c, 0x638, 0x634, 0x630, 0x62b,
    0x627, 0x623, 0x61e, 0x61a, 0x616, 0x612, 0x60e, 0x609,
    0x605, 0x601, 0x5fd, 0x5f9, 0x5f5, 0x5f0, 0x5ec, 0x5e8,
    0x5e4, 0x5e0, 0x5dc, 0x5d8, 0x5d4, 0x5d0, 0x5cc, 0x5c8,
    0x5c4, 0x5c0, 0x5bc, 0x5b8, 0x5b4, 0x5b0, 0x5ac, 0x5a8,
    0x5a4, 0x5a0, 0x59c, 0x599, 0x595, 0x591, 0x58d, 0x589,
    0x585, 0x581, 0x57e, 0x57a, 0x576, 0x572, 0x56f, 0x56b,
    0x567, 0x563, 0x560, 0x55c, 0x558, 0x554, 0x551, 0x54d,
    0x549, 0x546, 0x542, 0x53e, 0x53b, 0x537, 0x534, 0x530,
    0x52c, 0x529, 0x525, 0x522, 0x51e, 0x51b, 0x517, 0x514,
    0x510, 0x50c, 0x509, 0x506, 0x502, 0x4ff, 0x4fb, 0x4f8,
    0x4f4, 0x4f1, 0x4ed, 0x4ea, 0x4e7, 0x4e3, 0x4e0, 0x4dc,
    0x4d9, 0x4d6, 0x4d2, 0x4cf, 0x4cc, 0x4c8, 0x4c5, 0x4c2,
    0x4be, 0x4bb, 0x4b8, 0x4b5, 0x4b1, 0x4ae, 0x4ab, 0x4a8,
    0x4a4, 0x4a1, 0x49e, 0x49b, 0x498, 0x494, 0x491, 0x48e,
    0x48b, 0x488, 0x485, 0x482, 0x47e, 0x47b, 0x478, 0x475,
    0x472, 0x46f, 0x46c, 0x469, 0x466, 0x463, 0x460, 0x45d,
    0x45a, 0x457, 0x454, 0x451, 0x44e, 0x44b, 0x448, 0x445,
    0x442, 0x43f, 0x43c, 0x439, 0x436, 0x433, 0x430, 0x42d,
    0x42a, 0x428, 0x425, 0x422, 0x41f, 0x41c, 0x419, 0x416,
    0x414, 0x411, 0x40e, 0x40b, 0x408, 0x406, 0x403, 0x400
};

static const opll_patch_t patch_ds1001[opll_patch_max] = {
    { 0x05, 0x00, 0x00, 0x06,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x03, 0x01 },{ 0x00, 0x00 },{ 0x0e, 0x08 },{ 0x08, 0x01 },{ 0x04, 0x02 },{ 0x02, 0x07 } },
    { 0x14, 0x00, 0x01, 0x05,{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x03, 0x01 },{ 0x00, 0x00 },{ 0x0d, 0x0f },{ 0x08, 0x06 },{ 0x02, 0x01 },{ 0x03, 0x02 } },
    { 0x08, 0x00, 0x01, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x0f, 0x0b },{ 0x0a, 0x02 },{ 0x02, 0x01 },{ 0x00, 0x02 } },
    { 0x0c, 0x00, 0x00, 0x07,{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x0a, 0x06 },{ 0x08, 0x04 },{ 0x06, 0x02 },{ 0x01, 0x07 } },
    { 0x1e, 0x00, 0x00, 0x06,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x02, 0x01 },{ 0x00, 0x00 },{ 0x0e, 0x07 },{ 0x01, 0x06 },{ 0x00, 0x02 },{ 0x01, 0x08 } },
    { 0x06, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x02, 0x01 },{ 0x00, 0x00 },{ 0x0a, 0x0e },{ 0x03, 0x02 },{ 0x0f, 0x0f },{ 0x04, 0x04 } },
    { 0x1d, 0x00, 0x00, 0x07,{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x08, 0x08 },{ 0x02, 0x01 },{ 0x01, 0x00 },{ 0x01, 0x07 } },
    { 0x22, 0x01, 0x00, 0x07,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x03, 0x01 },{ 0x00, 0x00 },{ 0x0a, 0x07 },{ 0x02, 0x02 },{ 0x00, 0x01 },{ 0x01, 0x07 } },
    { 0x25, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x01, 0x01 },{ 0x05, 0x01 },{ 0x00, 0x00 },{ 0x04, 0x07 },{ 0x00, 0x03 },{ 0x07, 0x00 },{ 0x02, 0x01 } },
    { 0x0f, 0x00, 0x01, 0x07,{ 0x01, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x01, 0x00 },{ 0x05, 0x01 },{ 0x00, 0x00 },{ 0x0a, 0x0a },{ 0x08, 0x05 },{ 0x05, 0x00 },{ 0x01, 0x02 } },
    { 0x24, 0x00, 0x00, 0x07,{ 0x00, 0x01 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x07, 0x01 },{ 0x00, 0x00 },{ 0x0f, 0x0f },{ 0x08, 0x08 },{ 0x02, 0x01 },{ 0x02, 0x02 } },
    { 0x11, 0x00, 0x00, 0x06,{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x01, 0x03 },{ 0x00, 0x00 },{ 0x06, 0x07 },{ 0x05, 0x04 },{ 0x01, 0x01 },{ 0x08, 0x06 } },
    { 0x13, 0x00, 0x00, 0x05,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x02 },{ 0x03, 0x00 },{ 0x0c, 0x09 },{ 0x09, 0x05 },{ 0x00, 0x00 },{ 0x03, 0x02 } },
    { 0x0c, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x03 },{ 0x00, 0x00 },{ 0x09, 0x0c },{ 0x04, 0x00 },{ 0x03, 0x0f },{ 0x03, 0x06 } },
    { 0x0d, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x01, 0x01 },{ 0x00, 0x01 },{ 0x01, 0x02 },{ 0x00, 0x00 },{ 0x0c, 0x0d },{ 0x01, 0x05 },{ 0x05, 0x00 },{ 0x06, 0x06 } },

    { 0x18, 0x00, 0x01, 0x07,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x00, 0x00 },{ 0x0d, 0x00 },{ 0x0f, 0x00 },{ 0x06, 0x00 },{ 0x0a, 0x00 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x00, 0x00 },{ 0x0c, 0x00 },{ 0x08, 0x00 },{ 0x0a, 0x00 },{ 0x07, 0x00 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x05, 0x00 },{ 0x00, 0x00 },{ 0x0f, 0x00 },{ 0x08, 0x00 },{ 0x05, 0x00 },{ 0x09, 0x00 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x00, 0x0f },{ 0x00, 0x08 },{ 0x00, 0x06 },{ 0x00, 0x0d } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x00, 0x0d },{ 0x00, 0x08 },{ 0x00, 0x06 },{ 0x00, 0x08 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x00, 0x0a },{ 0x00, 0x0a },{ 0x00, 0x05 },{ 0x00, 0x05 } }
};

static const opll_patch_t patch_ym2413[opll_patch_max] = {
    { 0x1e, 0x01, 0x00, 0x07,{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x0d, 0x07 },{ 0x00, 0x08 },{ 0x00, 0x01 },{ 0x00, 0x07 } },
    { 0x1a, 0x00, 0x01, 0x05,{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x03, 0x01 },{ 0x00, 0x00 },{ 0x0d, 0x0f },{ 0x08, 0x07 },{ 0x02, 0x01 },{ 0x03, 0x03 } },
    { 0x19, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x03, 0x01 },{ 0x02, 0x00 },{ 0x0f, 0x0c },{ 0x02, 0x04 },{ 0x01, 0x02 },{ 0x01, 0x03 } },
    { 0x0e, 0x00, 0x00, 0x07,{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x0a, 0x06 },{ 0x08, 0x04 },{ 0x07, 0x02 },{ 0x00, 0x07 } },
    { 0x1e, 0x00, 0x00, 0x06,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x02, 0x01 },{ 0x00, 0x00 },{ 0x0e, 0x07 },{ 0x00, 0x06 },{ 0x00, 0x02 },{ 0x00, 0x08 } },
    { 0x16, 0x00, 0x00, 0x05,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x01, 0x02 },{ 0x00, 0x00 },{ 0x0e, 0x07 },{ 0x00, 0x01 },{ 0x00, 0x01 },{ 0x00, 0x08 } },
    { 0x1d, 0x00, 0x00, 0x07,{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x08, 0x08 },{ 0x02, 0x01 },{ 0x01, 0x00 },{ 0x00, 0x07 } },
    { 0x2d, 0x01, 0x00, 0x04,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x03, 0x01 },{ 0x00, 0x00 },{ 0x0a, 0x07 },{ 0x02, 0x02 },{ 0x00, 0x00 },{ 0x00, 0x07 } },
    { 0x1b, 0x00, 0x00, 0x06,{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x06, 0x06 },{ 0x04, 0x05 },{ 0x01, 0x01 },{ 0x00, 0x07 } },
    { 0x0b, 0x01, 0x01, 0x00,{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x00, 0x00 },{ 0x08, 0x0f },{ 0x05, 0x07 },{ 0x07, 0x00 },{ 0x01, 0x07 } },
    { 0x03, 0x01, 0x00, 0x01,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x03, 0x01 },{ 0x02, 0x00 },{ 0x0f, 0x0e },{ 0x0a, 0x04 },{ 0x01, 0x00 },{ 0x00, 0x04 } },
    { 0x24, 0x00, 0x00, 0x07,{ 0x00, 0x01 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x07, 0x01 },{ 0x00, 0x00 },{ 0x0f, 0x0f },{ 0x08, 0x08 },{ 0x02, 0x01 },{ 0x02, 0x02 } },
    { 0x0c, 0x00, 0x00, 0x05,{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x00, 0x01 },{ 0x01, 0x00 },{ 0x00, 0x00 },{ 0x0c, 0x0f },{ 0x02, 0x05 },{ 0x02, 0x04 },{ 0x00, 0x02 } },
    { 0x15, 0x00, 0x00, 0x03,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x0c, 0x09 },{ 0x09, 0x05 },{ 0x00, 0x00 },{ 0x03, 0x02 } },
    { 0x09, 0x00, 0x00, 0x03,{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x01, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x01 },{ 0x02, 0x00 },{ 0x0f, 0x0e },{ 0x01, 0x04 },{ 0x04, 0x01 },{ 0x00, 0x03 } },

    { 0x18, 0x00, 0x01, 0x07,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x00, 0x00 },{ 0x0d, 0x00 },{ 0x0f, 0x00 },{ 0x06, 0x00 },{ 0x0a, 0x00 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x01, 0x00 },{ 0x00, 0x00 },{ 0x0c, 0x00 },{ 0x08, 0x00 },{ 0x0a, 0x00 },{ 0x07, 0x00 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x05, 0x00 },{ 0x00, 0x00 },{ 0x0f, 0x00 },{ 0x08, 0x00 },{ 0x05, 0x00 },{ 0x09, 0x00 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x00, 0x0f },{ 0x00, 0x08 },{ 0x00, 0x06 },{ 0x00, 0x0d } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x00, 0x0d },{ 0x00, 0x08 },{ 0x00, 0x04 },{ 0x00, 0x08 } },
    { 0x00, 0x00, 0x00, 0x00,{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x00 },{ 0x00, 0x01 },{ 0x00, 0x00 },{ 0x00, 0x0a },{ 0x00, 0x0a },{ 0x00, 0x05 },{ 0x00, 0x05 } }
};

static const uint32_t ch_offset[18] = {
    1, 2, 0, 1, 2, 3, 4, 5, 3, 4, 5, 6, 7, 8, 6, 7, 8, 0
};

static const uint32_t pg_multi[16] = {
    1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 20, 24, 24, 30, 30
};

static const uint32_t eg_stephi[4][4] = {
    { 0, 0, 0, 0 },
    { 1, 0, 0, 0 },
    { 1, 0, 1, 0 },
    { 1, 1, 1, 0 }
};

static const uint32_t eg_ksltable[16] = {
    0, 32, 40, 45, 48, 51, 53, 55, 56, 58, 59, 60, 61, 62, 63, 64
};

void OPLL_DoIO(opll_t *chip) {
    /* Write signal check */
    chip->write_a_en = (chip->write_a & 0x03) == 0x01;
    chip->write_d_en = (chip->write_d & 0x03) == 0x01;
    chip->write_a <<= 1;
    chip->write_d <<= 1;
}

void OPLL_DoModeWrite(opll_t *chip) {
    uint8_t slot;
    if ((chip->write_mode_address & 0x10) && chip->write_d_en) {
        slot = chip->write_mode_address & 0x01;
        switch (chip->write_mode_address & 0x0f) {
        case 0x00:
        case 0x01:
            chip->patch.multi[slot] = chip->write_data & 0x0f;
            chip->patch.ksr[slot] = (chip->write_data >> 4) & 0x01;
            chip->patch.et[slot] = (chip->write_data >> 5) & 0x01;
            chip->patch.vib[slot] = (chip->write_data >> 6) & 0x01;
            chip->patch.am[slot] = (chip->write_data >> 7) & 0x01;
            break;

        case 0x02:
            chip->patch.ksl[0] = (chip->write_data >> 6) & 0x03;
            chip->patch.tl = chip->write_data & 0x3f;
            break;

        case 0x03:
            chip->patch.ksl[1] = (chip->write_data >> 6) & 0x03;
            chip->patch.dc = (chip->write_data >> 4) & 0x01;
            chip->patch.dm = (chip->write_data >> 3) & 0x01;
            chip->patch.fb = chip->write_data & 0x07;
            break;

        case 0x04:
        case 0x05:
            chip->patch.dr[slot] = chip->write_data & 0x0f;
            chip->patch.ar[slot] = (chip->write_data >> 4) & 0x0f;
            break;

        case 0x06:
        case 0x07:
            chip->patch.rr[slot] = chip->write_data & 0x0f;
            chip->patch.sl[slot] = (chip->write_data >> 4) & 0x0f;
            break;

        case 0x0e:
            chip->rhythm = chip->write_data & 0x3f;
            if (chip->chip_type == opll_type_ds1001) {
                chip->rhythm |= 0x20;
            }
            chip->rm_enable = (chip->rm_enable & 0x7f) | ((chip->rhythm << 2) & 0x80);
            break;

        case 0x0f:
            chip->testmode = chip->write_data & 0x0f;
            break;
        }
    }
}

void OPLL_Reset(opll_t *chip, uint32_t chip_type) {
    uint32_t i;
    memset(chip, 0, sizeof(opll_t));
    chip->chip_type = chip_type;
    if (chip_type == opll_type_ds1001) {
        /* Rhythm mode is always on */
        chip->rhythm = 0x20;
        chip->rm_enable = (int8_t)0x80;
    }
    switch (chip_type) {
    case opll_type_ds1001:
        chip->patchrom = patch_ds1001;
        break;
    case opll_type_ym2413:
    case opll_type_ym2413b:
    default:
        chip->patchrom = patch_ym2413;
        break;
    }
    for (i = 0; i < 18; i++) {
        chip->eg_state[i] = eg_num_release;
        chip->eg_level[i] = 0x7f;
        chip->eg_out = 0x7f;
    }
    chip->rm_select = rm_num_tc + 1;
}

void OPLL_DoRegWrite(opll_t *chip) {
    uint32_t channel;

    /* Address */
    if (chip->write_a_en) {
        if ((chip->write_data & 0xc0) == 0x00) {
            /* FM Write */
            chip->write_fm_address = 1;
            chip->address = chip->write_data;
        } else {
            chip->write_fm_address = 0;
        }
    }
    /* Data */
    if (chip->write_fm_address && chip->write_d_en) {
        chip->data = chip->write_data;
    }

    /* Update registers */
    if (chip->write_fm_data && !chip->write_a_en) {
        if ((chip->address & 0x0f) == chip->cycles && chip->cycles < 16) {
            channel = chip->cycles % 9;
            switch (chip->address & 0xf0) {
            case 0x10:
                chip->fnum[channel] = (chip->fnum[channel] & 0x100) | chip->data;
                break;
            case 0x20:
                chip->fnum[channel] = (chip->fnum[channel] & 0xff) | ((chip->data & 0x01) << 8);
                chip->block[channel] = (chip->data >> 1) & 0x07;
                chip->kon[channel] = (chip->data >> 4) & 0x01;
                chip->son[channel] = (chip->data >> 5) & 0x01;
                break;
            case 0x30:
                chip->vol[channel] = chip->data & 0x0f;
                chip->inst[channel] = (chip->data >> 4) & 0x0f;
                break;
            }
        }
    }


    if (chip->write_a_en) {
        chip->write_fm_data = 0;
    }
    if (chip->write_fm_address && chip->write_d_en) {
        chip->write_fm_data = 1;
    }
    if (chip->write_a_en) {
        if (((chip->write_data & 0xf0) == 0x00)) {
            chip->write_mode_address = 0x10 | (chip->write_data & 0x0f);
        } else {
            chip->write_mode_address = 0x00;
        }
    }

}
void OPLL_PreparePatch1(opll_t *chip) {
    uint8_t instr;
    uint32_t mcsel = ((chip->cycles + 1) / 3) & 0x01;
    uint32_t instr_index;
    uint32_t ch = ch_offset[chip->cycles];
    const opll_patch_t *patch;
    instr = chip->inst[ch];
    if (instr > 0) {
        instr_index = opll_patch_1 + instr - 1;
    }
    if (chip->rm_select <= rm_num_tc) {
        instr_index = opll_patch_drum_0 + chip->rm_select;
    }
    if (chip->rm_select <= rm_num_tc || instr > 0) {
        patch = &chip->patchrom[instr_index];
    } else {
        patch = &chip->patch;
    }
    if (chip->rm_select == rm_num_hh || chip->rm_select == rm_num_tom) {
        chip->c_tl = chip->inst[ch] << 2;
    } else if (mcsel == 1) {
        chip->c_tl = chip->vol[ch] << 2;
    } else {
        chip->c_tl = patch->tl;
    }

    chip->c_adrr[0] = patch->ar[mcsel];
    chip->c_adrr[1] = patch->dr[mcsel];
    chip->c_adrr[2] = patch->rr[mcsel];
    chip->c_et = patch->et[mcsel];
    chip->c_ksr = patch->ksr[mcsel];
    chip->c_ksl = patch->ksl[mcsel];
    chip->c_ksr_freq = (chip->block[ch] << 1) | (chip->fnum[ch] >> 8);
    chip->c_ksl_freq = (chip->fnum[ch]>>5);
    chip->c_ksl_block = (chip->block[ch]);
}

void OPLL_PreparePatch2(opll_t *chip) {
    uint8_t instr;
    uint32_t mcsel = ((chip->cycles + 1) / 3) & 0x01;
    uint32_t instr_index;
    const opll_patch_t *patch;
    instr = chip->inst[ch_offset[chip->cycles]];
    if (instr > 0) {
        instr_index = opll_patch_1 + instr - 1;
    }
    if (chip->rm_select <= rm_num_tc) {
        instr_index = opll_patch_drum_0 + chip->rm_select;
    }
    if (chip->rm_select <= rm_num_tc || instr > 0) {
        patch = &chip->patchrom[instr_index];
    } else {
        patch = &chip->patch;
    }

    chip->c_fnum = chip->fnum[ch_offset[chip->cycles]];
    chip->c_block = chip->block[ch_offset[chip->cycles]];

    chip->c_multi = patch->multi[mcsel];
    chip->c_sl = patch->sl[mcsel];
    chip->c_fb = patch->fb;
    chip->c_vib = patch->vib[mcsel];
    chip->c_am = patch->am[mcsel];
    chip->c_dc <<= 1;
    chip->c_dm <<= 1;
    chip->c_dc |= patch->dc;
    chip->c_dm |= patch->dm;
}

void OPLL_PhaseGenerate(opll_t *chip) {
    uint32_t ismod;
    uint32_t phase;
    uint8_t rm_bit;
    uint16_t pg_out;

    chip->pg_phase[(chip->cycles + 17) % 18] = chip->pg_phase_next + chip->pg_inc;

    if ((chip->rm_enable & 0x40) && (chip->cycles == 13 || chip->cycles == 14)) {
        ismod = 0;
    } else {
        ismod = ((chip->cycles + 3) / 3) & 1;
    }
    phase = chip->pg_phase[chip->cycles];
    /* KeyOn event check */
    if ((chip->testmode & 0x04)
     || (ismod && (chip->eg_dokon & 0x8000)) || (!ismod && (chip->eg_dokon & 0x01))) {
        chip->pg_phase_next = 0;
    } else {
        chip->pg_phase_next = phase;
    }
    /* Rhythm mode */
    if (chip->cycles == 13) {
        chip->rm_hh_bit2 = (phase >> (2 + 9)) & 1;
        chip->rm_hh_bit3 = (phase >> (3 + 9)) & 1;
        chip->rm_hh_bit7 = (phase >> (7 + 9)) & 1;
        chip->rm_hh_bit8 = (phase >> (8 + 9)) & 1;
    } else if (chip->cycles == 17 && (chip->rm_enable & 0x80)) {
        chip->rm_tc_bit3 = (phase >> (3 + 9)) & 1;
        chip->rm_tc_bit5 = (phase >> (5 + 9)) & 1;
    }
    if ((chip->rm_enable & 0x80)) {
        switch (chip->cycles) {
        case 13:
            /* HH */
            rm_bit = (chip->rm_hh_bit2 ^ chip->rm_hh_bit7)
                   | (chip->rm_hh_bit3 ^ chip->rm_tc_bit5)
                   | (chip->rm_tc_bit3 ^ chip->rm_tc_bit5);
            pg_out = rm_bit << 9;
            if (rm_bit ^ (chip->rm_noise & 1)) {
                pg_out |= 0xd0;
            } else {
                pg_out |= 0x34;
            }
            break;
        case 16:
            /* SD */
            pg_out = (chip->rm_hh_bit8 << 9)
                   | ((chip->rm_hh_bit8 ^ (chip->rm_noise & 1)) << 8);
            break;
        case 17:
            /* TC */
            rm_bit = (chip->rm_hh_bit2 ^ chip->rm_hh_bit7)
                   | (chip->rm_hh_bit3 ^ chip->rm_tc_bit5)
                   | (chip->rm_tc_bit3 ^ chip->rm_tc_bit5);
            pg_out = (rm_bit << 9) | 0x100;
            break;
        default:
            pg_out = phase >> 9;
        }
    } else {
        pg_out = phase >> 9;
    }
    chip->pg_out = pg_out;
}

void OPLL_PhaseCalcIncrement(opll_t *chip) {
    uint32_t freq;
    uint16_t block;
    freq = chip->c_fnum << 1;
    block = chip->c_block;
    /* Apply vibrato */
    if (chip->c_vib) {
        switch (chip->lfo_vib_counter) {
        case 0:
        case 4:
            break;
        case 1:
        case 3:
            freq += freq >> 8;
            break;
        case 2:
            freq += freq >> 7;
            break;
        case 5:
        case 7:
            freq -= freq >> 8;
            break;
        case 6:
            freq -= freq >> 7;
            break;
        }
    }
    /* Apply block */
    freq = (freq << block) >> 1;

    chip->pg_inc = (freq * pg_multi[chip->c_multi]) >> 1;
}

void OPLL_EnvelopeKSLTL(opll_t *chip)
{
    int32_t ksl;

    ksl = eg_ksltable[chip->c_ksl_freq]-((8-chip->c_ksl_block)<<3);
    if (ksl < 0) {
        ksl = 0;
    }

    ksl <<= 1;

    if (chip->c_ksl) {
        ksl = ksl >> (3-chip->c_ksl);
    } else {
        ksl = 0;
    }

    chip->eg_ksltl = ksl + (chip->c_tl<<1);
}

void OPLL_EnvelopeOutput(opll_t *chip)
{
    int32_t level = chip->eg_level[(chip->cycles+17)%18];

    level += chip->eg_ksltl;

    if (chip->c_am) {
        level += chip->lfo_am_out;
    }

    if (level >= 128) {
        level = 127;
    }

    if (chip->testmode & 0x01) {
        level = 0;
    }

    chip->eg_out = level;
}

void OPLL_EnvelopeGenerate(opll_t *chip) {
    uint8_t timer_inc;
    uint8_t timer_bit;
    uint8_t timer_low;
    uint8_t rate;
    uint8_t state_rate;
    uint8_t ksr;
    uint8_t sum;
    uint8_t rate_hi;
    uint8_t rate_lo;
    int32_t level;
    int32_t next_level;
    uint8_t zero;
    uint8_t state;
    uint8_t next_state;
    int32_t step;
    int32_t sl;
    uint32_t mcsel = ((chip->cycles + 1) / 3) & 0x01;


    /* EG timer */
    if ((chip->eg_counter_state & 3) != 3) {
        timer_inc = 0;
    } else if (chip->cycles == 0) {
        timer_inc = 1;
    } else {
        timer_inc = chip->eg_timer_carry;
    }
    timer_low = chip->eg_timer & 3;
    timer_bit = chip->eg_timer & 1;
    timer_bit += timer_inc;
    chip->eg_timer_carry = timer_bit >> 1;
    chip->eg_timer = ((timer_bit & 1) << 17) | (chip->eg_timer >> 1);
    if (chip->testmode & 0x08) {
        chip->eg_timer &= 0x2ffff;
        chip->eg_timer |= (chip->write_data << (16 - 2)) & 0x10000;
    }
    if (!chip->eg_timer_shift_stop && ((chip->eg_timer >> 16) & 1)) {
        chip->eg_timer_shift = chip->cycles;
    }
    if (chip->cycles == 0 && (chip->eg_counter_state_prev & 1) == 1) {
        chip->eg_timer_low_lock = timer_low;
        chip->eg_timer_shift_lock = chip->eg_timer_shift;
        if (chip->eg_timer_shift_lock > 13)
            chip->eg_timer_shift_lock = 0;

        chip->eg_timer_shift = 0;
    }
    chip->eg_timer_shift_stop |= (chip->eg_timer >> 16) & 1;
    if (chip->cycles == 0) {
        chip->eg_timer_shift_stop = 0;
    }
    chip->eg_counter_state_prev = chip->eg_counter_state;
    if (chip->cycles == 17) {
        chip->eg_counter_state++;
    }

    level = chip->eg_level[(chip->cycles+16)%18];
    next_level = level;
    zero = level == 0;
    chip->eg_silent = level == 0x7f;

    if (chip->eg_state[(chip->cycles+16)%18] != eg_num_attack && (chip->eg_off&2) && !(chip->eg_dokon&2)) {
        next_level = 0x7f;
    }

    if (chip->eg_maxrate && (chip->eg_dokon&2)) {
        next_level = 0x00;
    }


    state = chip->eg_state[(chip->cycles+16)%18];
    next_state = eg_num_attack;

    step = 0;
    sl = chip->eg_sl;

    switch (state) {
    case eg_num_attack:
        if (!chip->eg_maxrate && (chip->eg_kon & 2) && !zero) {
            int32_t shift = chip->eg_rate_hi - 11 + chip->eg_inc_hi;
            if (chip->eg_inc_lo) {
                shift = 1;
            }
            if (shift > 0) {
                if (shift > 4)
                    shift = 4;
                step = ~level >> (5 - shift);
            }
        }
        if (zero) {
            next_state = eg_num_decay;
        } else {
            next_state = eg_num_attack;
        }
        break;
    case eg_num_decay:
        if (!(chip->eg_off & 2) && !(chip->eg_dokon & 2) && (level >> 3) != sl)
        {
            uint8_t i0 = chip->eg_rate_hi == 15 || (chip->eg_rate_hi == 14 && chip->eg_inc_hi);
            uint8_t i1 = (chip->eg_rate_hi == 14 && !chip->eg_inc_hi) || (chip->eg_rate_hi == 13 && chip->eg_inc_hi) ||
                (chip->eg_rate_hi == 13 && !chip->eg_inc_hi && (chip->eg_counter_state_prev & 1))
                || (chip->eg_rate_hi == 12 && chip->eg_inc_hi && (chip->eg_counter_state_prev & 1))
                || (chip->eg_rate_hi == 12 && !chip->eg_inc_hi && ((chip->eg_counter_state_prev & 3) == 3))
                || (chip->eg_inc_lo && ((chip->eg_counter_state_prev & 3) == 3));
            step = (i0<<1) | i1;
        }
        if ((level >> 3) == sl) {
            next_state = eg_num_sustain;
        } else {
            next_state = eg_num_decay;
        }
        break;
    case eg_num_sustain:
    case eg_num_release:
        if (!(chip->eg_off & 2) && !(chip->eg_dokon & 2))
        {
            uint8_t i0 = chip->eg_rate_hi == 15 || (chip->eg_rate_hi == 14 && chip->eg_inc_hi);
            uint8_t i1 = (chip->eg_rate_hi == 14 && !chip->eg_inc_hi) || (chip->eg_rate_hi == 13 && chip->eg_inc_hi) ||
                (chip->eg_rate_hi == 13 && !chip->eg_inc_hi && (chip->eg_counter_state_prev & 1))
                || (chip->eg_rate_hi == 12 && chip->eg_inc_hi && (chip->eg_counter_state_prev & 1))
                || (chip->eg_rate_hi == 12 && !chip->eg_inc_hi && ((chip->eg_counter_state_prev & 3) == 3))
                || (chip->eg_inc_lo && ((chip->eg_counter_state_prev & 3) == 3));
            step = (i0<<1) | i1;
        }
        next_state = state;
        break;
    }

    if (!(chip->eg_kon & 2)) {
        next_state = eg_num_release;
    }
    if (chip->eg_dokon & 2) {
        next_state = eg_num_attack;
    }

    chip->eg_level[(chip->cycles+16)%18] = next_level+step;
    chip->eg_state[(chip->cycles+16)%18] = next_state;

    rate_hi = chip->eg_rate >> 2;
    rate_lo = chip->eg_rate & 3;
    chip->eg_inc_hi = eg_stephi[rate_lo][chip->eg_timer_low_lock];
    sum = (chip->eg_timer_shift_lock + rate_hi) & 0x0f;
    chip->eg_inc_lo = 0;
    if (rate_hi < 12 && !chip->eg_zerorate) {
        switch (sum) {
        case 12:
            chip->eg_inc_lo = 1;
            break;
        case 13:
            chip->eg_inc_lo = (rate_lo >> 1) & 1;
            break;
        case 14:
            chip->eg_inc_lo = rate_lo & 1;
            break;
        }
    }
    chip->eg_maxrate = rate_hi == 0x0f;

    chip->eg_rate_hi = rate_hi;

    chip->eg_kon <<= 1;
    chip->eg_kon |= chip->kon[ch_offset[chip->cycles]];
    chip->eg_off <<= 1;
    chip->eg_off |= (chip->eg_level[chip->cycles] >> 2) == 0x1f;
    switch (chip->rm_select) {
    case rm_num_bd0:
    case rm_num_bd1:
        chip->eg_kon |= (chip->rhythm >> 4) & 1;
        break;
    case rm_num_sd:
        chip->eg_kon |= (chip->rhythm >> 3) & 1;
        break;
    case rm_num_tom:
        chip->eg_kon |= (chip->rhythm >> 2) & 1;
        break;
    case rm_num_tc:
        chip->eg_kon |= (chip->rhythm >> 1) & 1;
        break;
    case rm_num_hh:
        chip->eg_kon |= chip->rhythm & 1;
        break;
    }

    /* Calculate rate */
    rate = 0;
    chip->eg_dokon <<= 1;
    state_rate = chip->eg_state[chip->cycles];
    if (state_rate == eg_num_release && (chip->eg_kon&1) && (chip->eg_off&1)) {
        state_rate = eg_num_attack;
        chip->eg_dokon |= 1;
    }
    switch (state_rate) {
    case eg_num_attack:
        rate = chip->c_adrr[0];
        break;
    case eg_num_decay:
        rate = chip->c_adrr[1];
        break;
    case eg_num_sustain:
        if (!chip->c_et) {
            rate = chip->c_adrr[2];
        }
        break;
    case eg_num_release:
        if (chip->son[ch_offset[chip->cycles]]) {
            rate = 5;
        } else {
            rate = chip->c_adrr[2];
        }
        break;
    }
    if (!(chip->eg_kon&1) && !mcsel && chip->rm_select != rm_num_tom && chip->rm_select != rm_num_hh) {
        rate = 0;
    }
    if ((chip->eg_kon&1) && chip->eg_state[chip->cycles] == eg_num_release && !(chip->eg_off&1)) {
        rate = 12;
    }
    if (!(chip->eg_kon&1) && !chip->son[ch_offset[chip->cycles]] && mcsel == 1 && !chip->c_et) {
        rate = 7;
    }
    chip->eg_zerorate = rate == 0;
    ksr = chip->c_ksr_freq;
    if (!chip->c_ksr)
        ksr >>= 2;
    chip->eg_rate = (rate << 2) + ksr;
    if (chip->eg_rate & 0x40) {
        chip->eg_rate = 0x3c | (ksr & 3);
    }
    chip->eg_sl = chip->c_sl;
}

void OPLL_Channel(opll_t *chip) {
    int16_t sign;
    int16_t ch_out = chip->ch_out;
    uint8_t ismod = (chip->cycles / 3) & 1;
    uint8_t mute_m = ismod || ((chip->rm_enable&0x40) && (chip->cycles+15)%18 >= 12);
    uint8_t mute_r = 1;
    if (chip->chip_type == opll_type_ds1001) {
        chip->output_m = ch_out;
        if (chip->output_m >= 0) {
            chip->output_m++;
        }
        if (mute_m) {
            chip->output_m = 0;
        }
        chip->output_r = 0;
        return;
    } else {
        /* TODO: This might be incorrect */
        if ((chip->rm_enable & 0x40)) {
            switch (chip->cycles) {
            case 16: /* HH */
            case 17: /* TOM */
            case 0: /* BD */
            case 1: /* SD */
            case 2: /* TC */
            case 3: /* HH */
            case 4: /* TOM */
            case 5: /* BD */
            case 9: /* TOM */
            case 10: /* TOM */
                mute_r = 0;
                break;
            }
        }
        if (chip->chip_type == opll_type_ym2413b) {
            if (mute_m)
                chip->output_m = 0;
            else
                chip->output_m = ch_out;
            if (mute_r)
                chip->output_r = 0;
            else
                chip->output_r = ch_out;
        } else {
            sign = ch_out >> 8;
            if (ch_out >= 0) {
                ch_out++;
                sign++;
            }
            if (mute_m)
                chip->output_m = sign;
            else
                chip->output_m = ch_out;
            if (mute_r)
                chip->output_r = sign;
            else
                chip->output_r = ch_out;
        }
    }
}

void OPLL_Operator(opll_t *chip) {
    uint8_t ismod1, ismod2, ismod3;
    uint32_t op_mod;
    uint16_t exp_shift;
    int16_t output;
    uint32_t level;
    uint32_t phase;
    int16_t routput;
    if ((chip->rm_enable & 0x80) && (chip->cycles == 15 || chip->cycles == 16)) {
        ismod1 = 0;
    } else {
        ismod1 = ((chip->cycles + 1) / 3) & 1;
    }
    if ((chip->rm_enable & 0x40) && (chip->cycles == 13 || chip->cycles == 14)) {
        ismod2 = 0;
    } else {
        ismod2 = ((chip->cycles + 3) / 3) & 1;
    }
    if ((chip->rm_enable & 0x40) && (chip->cycles == 16 || chip->cycles == 17)) {
        ismod3 = 0;
    } else {
        ismod3 = (chip->cycles / 3) & 1;
    }

    op_mod = 0;
    
    if (ismod3) {
        op_mod |= chip->op_mod << 1;
    }

    if (ismod2 && chip->c_fb) {
        op_mod |= chip->op_fbsum >> (7 - chip->c_fb);
    }

    exp_shift = chip->op_exp_s;
    if (chip->eg_silent || ((chip->op_neg&2) && (ismod1 ? (chip->c_dm&4) : (chip->c_dc&4)))) {
        exp_shift |= 12;
    }

    output = chip->op_exp_m>>exp_shift;
    if (!chip->eg_silent && (chip->op_neg&2)) {
        output = ~output;
    }

    level = chip->op_logsin+(chip->eg_out<<4);
    if (level >= 4096) {
        level = 4095;
    }

    chip->op_exp_m = exprom[level & 0xff];
    chip->op_exp_s = level >> 8;

    phase = (op_mod + chip->pg_out) & 0x3ff;
    if (phase & 0x100) {
        phase ^= 0xff;
    }
    chip->op_logsin = logsinrom[phase & 0xff];
    chip->op_neg <<= 1;
    chip->op_neg |= phase >> 9;
    chip->op_fbsum = (chip->op_fb1[(chip->cycles + 3) % 9] + chip->op_fb2[(chip->cycles + 3) % 9]) >> 1;

    if (ismod1) {
        chip->op_fb2[chip->cycles%9] = chip->op_fb1[chip->cycles%9];
        chip->op_fb1[chip->cycles%9] = output;
    }
    chip->op_mod = output&0x1ff;

    if (chip->chip_type == opll_type_ds1001) {
        routput = 0;
    } else {
        switch (chip->cycles) {
        case 2:
            routput = chip->ch_out_hh;
            break;
        case 3:
            routput = chip->ch_out_tm;
            break;
        case 4:
            routput = chip->ch_out_bd;
            break;
        case 8:
            routput = chip->ch_out_sd;
            break;
        case 9:
            routput = chip->ch_out_tc;
            break;
        default:
            routput = 0; /* TODO: Not quite true */
            break;
        }
        switch (chip->cycles) {
        case 15:
            chip->ch_out_hh = output>>3;
            break;
        case 16:
            chip->ch_out_tm = output>>3;
            break;
        case 17:
            chip->ch_out_bd = output>>3;
            break;
        case 0:
            chip->ch_out_sd = output>>3;
            break;
        case 1:
            chip->ch_out_tc = output>>3;
            break;
        default:
            break;
        }
    }

    chip->ch_out = ismod1 ? routput : (output>>3);
}

void OPLL_DoRhythm(opll_t *chip) {
    uint8_t nbit;

    /* Noise */
    nbit = (chip->rm_noise ^ (chip->rm_noise >> 14)) & 0x01;
    nbit |= (chip->rm_noise == 0x00) | ((chip->testmode >> 1) & 0x01);
    chip->rm_noise = (nbit << 22) | (chip->rm_noise >> 1);
}

void OPLL_DoLFO(opll_t *chip) {
    uint8_t vib_step;
    uint8_t am_inc = 0;
    uint8_t am_bit;
    
    /* Update counter */
    if (chip->cycles == 17) {
        vib_step = ((chip->lfo_counter & 0x3ff) + 1) >> 10;
        chip->lfo_am_step = ((chip->lfo_counter & 0x3f) + 1) >> 6;
        vib_step |= (chip->testmode >> 3) & 0x01;
        chip->lfo_vib_counter += vib_step;
        chip->lfo_vib_counter &= 0x07;
        chip->lfo_counter++;
    }
    
    /* LFO AM */
    if ((chip->lfo_am_step || (chip->testmode & 0x08)) && chip->cycles < 9) {
        am_inc = chip->lfo_am_dir | (chip->cycles == 0);
    }

    if (chip->cycles >= 9) {
        chip->lfo_am_car = 0;
    }

    if (chip->cycles == 0) {
        if (chip->lfo_am_dir && (chip->lfo_am_counter & 0x7f) == 0) {
            chip->lfo_am_dir = 0;
        } else if (!chip->lfo_am_dir && (chip->lfo_am_counter & 0x69) == 0x69) {
            chip->lfo_am_dir = 1;
        }
    }

    am_bit = chip->lfo_am_counter & 0x01;
    am_bit += am_inc + chip->lfo_am_car;
    chip->lfo_am_car = am_bit >> 1;
    am_bit &= 0x01;
    chip->lfo_am_counter = (am_bit << 8) | (chip->lfo_am_counter >> 1);


    /* Reset LFO */
    if (chip->testmode & 0x02) {
        chip->lfo_vib_counter = 0;
        chip->lfo_counter = 0;
        chip->lfo_am_dir = 0;
        chip->lfo_am_counter &= 0xff;
    }
}


void OPLL_Clock(opll_t *chip, int32_t *buffer) {
    buffer[0] = chip->output_m;
    buffer[1] = chip->output_r;
    if (chip->cycles == 0) {
        chip->lfo_am_out = (chip->lfo_am_counter >> 3) & 0x0f;
    }
    chip->rm_enable >>= 1;
    OPLL_DoModeWrite(chip);
    chip->rm_select++;
    if (chip->rm_select > rm_num_tc) {
        chip->rm_select = rm_num_tc + 1;
    }
    if (chip->cycles == 11 && (chip->rm_enable & 0x80) == 0x80) {
        chip->rm_select = rm_num_bd0;
    }
    OPLL_PreparePatch1(chip);

    OPLL_Channel(chip);

    OPLL_PhaseGenerate(chip);

    OPLL_Operator(chip);

    OPLL_PhaseCalcIncrement(chip);

    OPLL_EnvelopeOutput(chip);
    OPLL_EnvelopeKSLTL(chip);
    OPLL_EnvelopeGenerate(chip);

    OPLL_DoLFO(chip);
    OPLL_DoRhythm(chip);
    OPLL_PreparePatch2(chip);
    OPLL_DoRegWrite(chip);
    OPLL_DoIO(chip);
    chip->cycles = (chip->cycles + 1) % 18;

}


void OPLL_Write(opll_t *chip, uint32_t port, uint8_t data) {
    chip->write_data = data;
    if (port & 1) {
        /* Data */
        chip->write_d |= 1;
    } else {
        /* Address */
        chip->write_a |= 1;
    }
}
#endif
