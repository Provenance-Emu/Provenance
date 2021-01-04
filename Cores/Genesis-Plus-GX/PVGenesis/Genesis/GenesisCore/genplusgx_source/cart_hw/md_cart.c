/****************************************************************************
 *  Genesis Plus
 *  Mega Drive cartridge hardware support
 *
 *  Copyright (C) 2007-2020  Eke-Eke (Genesis Plus GX)
 *
 *  Many cartridge protections were initially documented by Haze
 *  (http://haze.mameworld.info/)
 *
 *  Realtec mapper was documented by TascoDeluxe
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
 ****************************************************************************************/

#include "shared.h"
#include "eeprom_i2c.h"
#include "eeprom_spi.h"

/* Cart database entry */
typedef struct
{
  uint16 chk_1;       /* header checksum */
  uint16 chk_2;       /* real checksum */
  uint8 bank_start;   /* first mapped bank in $400000-$7fffff region */
  uint8 bank_end;     /* last mapped bank in $400000-$7fffff region */
  cart_hw_t cart_hw;  /* hardware description */
} md_entry_t;

/* Function prototypes */
static void mapper_sega_w(uint32 data);
static void mapper_512k_w(uint32 address, uint32 data);
static void mapper_ssf2_w(uint32 address, uint32 data);
static void mapper_sf001_w(uint32 address, uint32 data);
static void mapper_sf002_w(uint32 address, uint32 data);
static void mapper_sf004_w(uint32 address, uint32 data);
static uint32 mapper_sf004_r(uint32 address);
static void mapper_t5740_w(uint32 address, uint32 data);
static uint32 mapper_t5740_r(uint32 address);
static void mapper_flashkit_w(uint32 address, uint32 data);
static uint32 mapper_flashkit_r(uint32 address);
static uint32 mapper_smw_64_r(uint32 address);
static void mapper_smw_64_w(uint32 address, uint32 data);
static void mapper_realtec_w(uint32 address, uint32 data);
static void mapper_seganet_w(uint32 address, uint32 data);
static void mapper_32k_w(uint32 data);
static void mapper_64k_w(uint32 data);
static void mapper_64k_multi_w(uint32 address);
static uint32 mapper_128k_multi_r(uint32 address);
static void mapper_256k_multi_w(uint32 address, uint32 data);
static void mapper_wd1601_w(uint32 address, uint32 data);
static uint32 mapper_64k_radica_r(uint32 address);
static uint32 mapper_128k_radica_r(uint32 address);
static void default_time_w(uint32 address, uint32 data);
static void default_regs_w(uint32 address, uint32 data);
static uint32 default_regs_r(uint32 address);
static uint32 default_regs_r_16(uint32 address);
static uint32 custom_regs_r(uint32 address);
static void custom_regs_w(uint32 address, uint32 data);
static void custom_alt_regs_w(uint32 address, uint32 data);
static uint32 topshooter_r(uint32 address);
static void topshooter_w(uint32 address, uint32 data);
static uint32 tekken_regs_r(uint32 address);
static void tekken_regs_w(uint32 address, uint32 data);

/* Games that need extra hardware emulation:
  - copy protection device
  - custom ROM banking device
*/
static const md_entry_t rom_database[] =
{
/* Funny World & Balloon Boy */
  {0x0000,0x06ab,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},1,0,NULL,NULL,NULL,mapper_realtec_w}},
/* Whac-a-Critter */
  {0xffff,0xf863,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},1,0,NULL,NULL,NULL,mapper_realtec_w}},
/* Earth Defense */
  {0xffff,0x44fb,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},1,0,NULL,NULL,NULL,mapper_realtec_w}},
/* Tom Clown */
  {0x0000,0xc0cd,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},1,0,NULL,NULL,NULL,mapper_realtec_w}},

/* 1800-in-1 */
  {0x3296,0x2370,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,1,mapper_128k_multi_r,m68k_unused_8_w,NULL,NULL}},

/* Golden Mega 250-in-1 */
  {0xe43c,0x886f,0x08,0x08,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,1,NULL,m68k_unused_8_w,NULL,mapper_256k_multi_w}},

/* RADICA (Volume 1) (bad dump ?) */
  {0x0000,0x2326,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,1,mapper_64k_radica_r,m68k_unused_8_w,NULL,NULL}},
/* RADICA (Volume 1) */
  {0x24f4,0xfc84,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,mapper_64k_radica_r,m68k_unused_8_w,NULL,NULL}},
/* RADICA (Volume 2) */
  {0xd951,0x78d0,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,mapper_64k_radica_r,m68k_unused_8_w,NULL,NULL}},
/* RADICA (Volume 3 - Super Sonic Gold edition) */
  {0x0000,0x1f25,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,mapper_64k_radica_r,m68k_unused_8_w,NULL,NULL}},
/* RADICA (Street Fighter II CE edition) */
  {0x1add,0xa838,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,mapper_64k_radica_r,m68k_unused_8_w,NULL,NULL}},
/* RADICA (Street Fighter II CE edition) (PAL) */
  {0x104f,0x32e9,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,mapper_64k_radica_r,m68k_unused_8_w,NULL,NULL}},
/* RADICA (Sensible Soccer Plus edition) (PAL) */
  {0x0000,0x1f7f,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,mapper_128k_radica_r,m68k_unused_8_w,NULL,NULL}},


/* Tenchi wo Kurau III: Sangokushi Gaiden - Chinese Fighter */
  {0x9490,0x8180,0x40,0x6f,{{0x00,0x00,0x00,0x00},{0xf0000c,0xf0000c,0xf0000c,0xf0000c},{0x400000,0x400004,0x400008,0x40000c},0,1,NULL,NULL,default_regs_r,custom_alt_regs_w}},


/* Top Fighter */
  {0x4eb9,0x5d8b,0x60,0x7f,{{0x00,0x00,0x00,0x00},{0xf00007,0xf00007,0xf00007,0xffffff},{0x600001,0x600003,0x600005,0x000000},0,1,NULL,NULL,default_regs_r,custom_regs_w}},
/* Soul Edge VS Samurai Spirits  */
  {0x00ff,0x5d34,0x60,0x7f,{{0x00,0x00,0x00,0x00},{0xf00007,0xf00007,0xf00007,0xffffff},{0x600001,0x600003,0x600005,0x000000},0,1,NULL,NULL,default_regs_r,custom_regs_w}},
/* Mulan */
  {0x0404,0x1b40,0x60,0x7f,{{0x00,0x00,0x00,0x00},{0xf00007,0xf00007,0xf00007,0xffffff},{0x600001,0x600003,0x600005,0x000000},0,1,NULL,NULL,default_regs_r,custom_regs_w}},
/* Pocket Monsters II */
  {0x47f9,0x17e5,0x60,0x7f,{{0x00,0x00,0x00,0x00},{0xf00007,0xf00007,0xf00007,0xffffff},{0x600001,0x600003,0x600005,0x000000},0,1,NULL,NULL,default_regs_r,custom_regs_w}},
/* Lion King 3 */
  {0x0000,0x507c,0x60,0x7f,{{0x00,0x00,0x00,0x00},{0xf00007,0xf00007,0xf00007,0xffffff},{0x600001,0x600003,0x600005,0x000000},0,1,NULL,NULL,default_regs_r,custom_regs_w}},
/* Super King Kong 99 */
  {0x0000,0x7d6e,0x60,0x7f,{{0x00,0x00,0x00,0x00},{0xf00007,0xf00007,0xf00007,0xffffff},{0x600001,0x600003,0x600005,0x000000},0,1,NULL,NULL,default_regs_r,custom_regs_w}},
/* Gunfight 3-in-1 */
  {0x0000,0x6ff8,0x60,0x7f,{{0x00,0x00,0x00,0x00},{0xf00007,0xf00007,0xf00007,0xffffff},{0x600001,0x600003,0x600005,0x000000},0,1,NULL,NULL,default_regs_r,custom_regs_w}}, 
/* Pokemon Stadium */
  {0x0000,0x843c,0x70,0x7f,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,1,NULL,NULL,NULL,custom_regs_w}},


/* Tekken 3 Special (original dump) (a bootleg version also exists, with patched protection & different boot routine which reads unused !TIME mapped area) */
  {0x0000,0xc2f0,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,NULL,NULL,tekken_regs_r,tekken_regs_w}},


/* Lion King 2 */
  {0xffff,0x1d9b,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xfffffd,0xfffffd,0xffffff,0xffffff},{0x400000,0x400004,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,default_regs_w}},
/* Squirell King */
  {0x0000,0x8ec8,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xfffffd,0xfffffd,0xffffff,0xffffff},{0x400000,0x400004,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,default_regs_w}},
/* Tiny Toon Adventures 3 */
  {0x2020,0xed9c,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xfffffd,0xfffffd,0xffffff,0xffffff},{0x400000,0x400004,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,default_regs_w}},
/* Lian Huan Pao - Barver Battle Saga (registers accessed by Z80, related to sound engine ?) */
  {0x30b9,0x1c2a,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xfffffd,0xfffffd,0xffffff,0xffffff},{0x400000,0x400004,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,default_regs_w}},
/* Shui Hu Zhuan (registers accessed by Z80, related to sound engine ?) */
  {0x6001,0x0211,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xfffffd,0xfffffd,0xffffff,0xffffff},{0x400000,0x400004,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,default_regs_w}},
/* Feng Shen Ying Jie Chuan (registers accessed by Z80, related to sound engine ?) */
  {0xffff,0x5d98,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xfffffd,0xfffffd,0xffffff,0xffffff},{0x400000,0x400004,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,default_regs_w}},
/* (*) Shui Hu - Feng Yun Zhuan (patched ROM, unused registers) */
  {0x3332,0x872b,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xfffffd,0xfffffd,0xffffff,0xffffff},{0x400000,0x400004,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,default_regs_w}},


/* (*) Chao Ji Da Fu Weng (patched ROM, various words witten to register, long word also read from $7E0000, unknown banking hardware ?) */
  {0xa697,0xa697,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x000000,0x000000,0x000000},0,0,NULL,NULL,NULL,default_regs_w}},

/* (*) Aq Renkan Awa (patched ROM, ON/OFF bit sequence is written to register, unknown banking hardware ?) */
  {0x8104,0x0517,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400001,0x000000,0x000000,0x000000},0,0,NULL,NULL,NULL,default_regs_w}},


/* (*) Tun Shi Tian Di III (patched ROM, unused register) */
  {0x0000,0x9c5e,0x40,0x40,{{0xab,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400046,0x000000,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,NULL}},


/* Ma Jiang Qing Ren - Ji Ma Jiang Zhi */
  {0x0000,0x7037,0x40,0x40,{{0x90,0xd3,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x401000,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,NULL}},
/* Super Majon Club */
  {0x0000,0x3b95,0x40,0x40,{{0x90,0xd3,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x401000,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,NULL}},
/* Feng Kuang Tao Hua Yuan (original version from Creaton Softec Inc) (a bootleg version also exists with patched protection and minor title screen variations) */
  {0x0000,0x9dc4,0x40,0x40,{{0x90,0xd3,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x401000,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,NULL}},


/* (*) Jiu Ji Ma Jiang II - Ye Yan Bian (patched ROM, using expected register value - $0f - crashes the game) (uses 16-bits reads) */
  {0x0c44,0xba81,0x40,0x40,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x400006},0,0,NULL,NULL,default_regs_r_16,NULL}},
/* 16 Zhang Ma Jiang (uses 16-bits reads) */
  {0xfb40,0x4bed,0x40,0x40,{{0x00,0xaa,0x00,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x400002,0x000000,0x400006},0,0,NULL,NULL,default_regs_r_16,NULL}},
/* 16 Tiles Mahjong II (uses 16-bits reads) */
  {0xffff,0x0903,0x40,0x40,{{0x00,0x00,0xc9,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x400004,0x000000},0,0,NULL,NULL,default_regs_r_16,NULL}},
/* Thunderbolt II (uses 16-bits reads) */
  {0x0000,0x1585,0x40,0x40,{{0x55,0x0f,0xaa,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r_16,NULL}},


/* Chaoji Puke - Super Poker (correct ROM dump, original release is an overdump) */
  {0xffff,0xd7b0,0x40,0x40,{{0x55,0x0f,0xaa,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* Super Bubble Bobble */
  {0x0000,0x16cd,0x40,0x40,{{0x55,0x0f,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,NULL}},
/* Tenchi wo Kurau II - The Battle of Red Cliffs (Unl) */
  {0x0000,0xed61,0x40,0x40,{{0x55,0x0f,0xaa,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* Huan Le Tao Qi Shu - Smart Mouse */
  {0x0000,0x1a28,0x40,0x40,{{0x55,0x0f,0xaa,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* (*) Hei Tao 2 - Super Big 2 (patched ROM, unused registers) */
  {0x0000,0x5843,0x40,0x40,{{0x55,0x0f,0xaa,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* Mighty Morphin Power Rangers - The Fighting Edition */
  {0x0000,0x2288,0x40,0x40,{{0x55,0x0f,0xc9,0x18},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* Elf Wor */
  {0x0080,0x3dba,0x40,0x40,{{0x55,0x0f,0xc9,0x18},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* Ya-Se Chuanshuo */
  {0xffff,0xd472,0x40,0x40,{{0x63,0x98,0xc9,0x18},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* 777 Casino (For first one, 0x55 works as well. Other values are never used so they are guessed from on other unlicensed games using similar mapper) */
  {0x0000,0xf8d9,0x40,0x40,{{0x63,0x98,0xc9,0x18},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* Wu Kong Wai Zhuan (original) (a bootleg version also exists, with patched protection & modified SRAM test routine ?) */
  {0x0000,0x19ff,0x40,0x40,{{0x63,0x98,0xc9,0x18},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},
/* Soul Blade */
  {0x0000,0x0c5b,0x40,0x40,{{0x63,0x98,0xc9,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0x400000,0x400002,0x400004,0x400006},0,0,NULL,NULL,default_regs_r,NULL}},


/* King of Fighter 98 */
  {0x0000,0xd0a0,0x48,0x4f,{{0x00,0x00,0xaa,0xf0},{0xffffff,0xffffff,0xfc0000,0xfc0000},{0x000000,0x000000,0x480000,0x4c0000},0,0,NULL,NULL,default_regs_r,NULL}},


/* Rock Heaven */
  {0x6cca,0x2395,0x50,0x50,{{0x50,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x500008,0x000000,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,NULL}},
/* Rock World */
  {0x3547,0xa3da,0x50,0x50,{{0x50,0xa0,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x500008,0x500208,0x000000,0x000000},0,0,NULL,NULL,default_regs_r,NULL}},


/* Rockman X3 (bootleg version ? two last register returned values are ignored, note that 0xaa/0x18 would work as well) */
  {0x0000,0x9d0e,0x40,0x40,{{0x0c,0x00,0xc9,0xf0},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0x000000,0x400004,0x400006},0,0,default_regs_r,NULL,default_regs_r,NULL}},


/* (*) Dragon Ball Final Bout  (patched ROM, in original code, different switches occurs depending on returned value $00-$0f) */
  {0xc65a,0xc65a,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0x000000,0x000000,0x000000},0,0,default_regs_r,NULL,NULL,NULL}},
/* (*) Yang Jia Jiang - Yang Warrior Family (patched ROM, register value unused) */
  {0x0000,0x96b0,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0x000000,0x000000,0x000000},0,0,default_regs_r,NULL,NULL,NULL}},
/* Super Mario 2 1998 */
  {0xffff,0x0474,0x00,0x00,{{0x0a,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0x000000,0x000000,0x000000},0,0,default_regs_r,NULL,NULL,NULL}},
/* Super Mario World */
  {0x2020,0xb4eb,0x00,0x00,{{0x1c,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0x000000,0x000000,0x000000},0,0,default_regs_r,NULL,NULL,NULL}},


/* King of Fighter 99 */
  {0x0000,0x021e,0x00,0x00,{{0x00,0x01,0x1f,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0xa13002,0xa1303e,0x000000},0,0,custom_regs_r,default_regs_w,NULL,NULL}},
/* Pocket Monster */
  {0xd6fc,0x1eb1,0x00,0x00,{{0x00,0x01,0x1f,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0xa13002,0xa1303e,0x000000},0,0,custom_regs_r,default_regs_w,NULL,NULL}},
/* Pocket Monster (bootleg version ? two last register returned values are ignored & first register test has been modified) */
  {0xd6fc,0x6319,0x00,0x00,{{0x14,0x01,0x1f,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0xa13002,0xa1303e,0x000000},0,0,default_regs_r,m68k_unused_8_w,NULL,NULL}},
/* A Bug's Life (bootleg version ? two last register returned values are ignored & first register test has been modified ?) */
  {0x7f7f,0x2aad,0x00,0x00,{{0x28,0x01,0x1f,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0xa13000,0xa13002,0xa1303e,0x000000},0,0,default_regs_r,m68k_unused_8_w,NULL,NULL}},


/* Game no Kanzume Otokuyou */
  {0x0000,0xf9d1,0x00,0x00,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,NULL,mapper_seganet_w,NULL,NULL}},


/* Top Shooter (arcade hardware) */
  {0xffff,0x3632,0x20,0x20,{{0x00,0x00,0x00,0x00},{0xffffff,0xffffff,0xffffff,0xffffff},{0x000000,0x000000,0x000000,0x000000},0,0,NULL,NULL,topshooter_r,topshooter_w}}
};


/************************************************************
          Cart Hardware initialization 
*************************************************************/

void md_cart_init(void)
{
  int i;

  /***************************************************************************************************************
                CARTRIDGE ROM MIRRORING                                                                                   
   ***************************************************************************************************************
  
    MD Cartridge area is mapped to $000000-$3fffff:

      -> when accessing ROM, 68k address lines A1 to A21 can be used by the internal cartridge hardware to decode
         full 4MB address range.
      -> depending on ROM total size and additional decoding hardware, some address lines might be ignored,
         resulting in ROM mirroring.

    Cartridges can use either 8-bits (x2) or 16-bits (x1, x2) Mask ROM chips, each chip size is a factor of 2 bytes:

      -> two 8-bits chips are equivalent to one 16-bits chip, no specific address decoding is required, needed
         address lines are simply connected to each chip, upper address lines are ignored and data lines are
         connected appropriately to each chip (D0-D7 to one chip, D8-D15 to the other one).
         ROM is generally mirrored each N bytes where N=2^(k+1) is the total ROM size (ROM1+ROM2,ROM1+ROM2,...)

      -> one single 16-bits chip do not need specific address decoding, address lines are simply connected
         depending on the ROM size, upper address lines being ignored.
         ROM is generally mirrored each N bytes where N=2^k is the size of the ROM chip (ROM1,ROM1,ROM1,...)

      -> two 16-bits chips of the same size are equivalent to one chip of double size, address decoding generally
         is the same except that specific hardware is used (one address line is generally used for chip selection,
         lower ones being used to address the chips and upper ones being ignored).
         ROM is generally mirrored each N bytes where N=2^(k+1) is the total ROM size (ROM1,ROM2,ROM1,ROM2,...)

      -> two 16-bits chips with different size are mapped differently. Address decoding is done the same way as
         above (one address line used for chip selection) but the ignored & required address lines differ from
         one chip to another, which makes ROM mirroring different.
         ROM2 size is generally half of ROM1 size and upper half ignored (ROM1,ROM2,XXXX,ROM1,ROM2,XXXX,...)

      From the emulator point of view, we only need to distinguish 2 cases:

      1/ total ROM size is a factor of 2: ROM is mirrored each 2^k bytes.

      2/ total ROM size is not a factor of 2: ROM is padded up to 2^k then mirrored each 2^k bytes.

  ******************************************************************************************************************/
  
  /* calculate nearest size with factor of 2 */
  unsigned int size = 0x10000;
  while (cart.romsize > size)
    size <<= 1;

  /* Sonic & Knuckles */
  if (strstr(rominfo.international,"SONIC & KNUCKLES"))
  {
    /* disable ROM mirroring at $200000-$3fffff (normally mapped to external cartridge) */
    size = 0x400000;
  }

  /* total ROM size is not a factor of 2  */
  /* TODO: handle all possible ROM configurations using cartridge database */
  if (cart.romsize < size)
  {
    if (size < MAXROMSIZE)
    {
      /* ROM is padded up to 2^k bytes */
      memset(cart.rom + cart.romsize, 0xff, size - cart.romsize);
    }
    else
    {
      /* ROM is padded up to max ROM size */
      memset(cart.rom + cart.romsize, 0xff, MAXROMSIZE - cart.romsize);
    }
  }

  /* ROM is mirrored each 2^k bytes */
  cart.mask = size - 1;

  /* no special external hardware required by default */
  cart.special = 0;

  /**********************************************
          DEFAULT CARTRIDGE MAPPING 
  ***********************************************/
  for (i=0; i<0x40; i++)
  {
    /* cartridge ROM */
    m68k.memory_map[i].base     = cart.rom + ((i<<16) & cart.mask);
    m68k.memory_map[i].read8    = NULL;
    m68k.memory_map[i].read16   = NULL;
    m68k.memory_map[i].write8   = m68k_unused_8_w;
    m68k.memory_map[i].write16  = m68k_unused_16_w;
    zbank_memory_map[i].read    = NULL;
    zbank_memory_map[i].write   = zbank_unused_w;
  }

  for (i=0x40; i<0x80; i++)
  {
    /* unused area */
    m68k.memory_map[i].base     = cart.rom + (i<<16);
    m68k.memory_map[i].read8    = m68k_read_bus_8;
    m68k.memory_map[i].read16   = m68k_read_bus_16;
    m68k.memory_map[i].write8   = m68k_unused_8_w;
    m68k.memory_map[i].write16  = m68k_unused_16_w;
    zbank_memory_map[i].read    = zbank_unused_r;
    zbank_memory_map[i].write   = zbank_unused_w;
  }

  /* support for Quackshot REV 01 (real) dump */
  if (strstr(rominfo.product,"00004054-01") && (cart.romsize == 0x80000))
  {
    /* $000000-$0fffff: first 256K mirrored (A18 not connected to ROM chip, A19 not decoded) */
    for (i=0x00; i<0x10; i++)
    {
      /* $200000-$3fffff: mirror of $000000-$1fffff (A21 not decoded) */
      m68k.memory_map[i].base = m68k.memory_map[i + 0x20].base = cart.rom + ((i & 0x03) << 16);
    }

    /* $100000-$1fffff: second 256K mirrored (A20 connected to ROM chip A18) */
    for (i=0x10; i<0x20; i++)
    {
      /* $200000-$3fffff: mirror of $000000-$1fffff (A21 not decoded) */
      m68k.memory_map[i].base = m68k.memory_map[i + 0x20].base = cart.rom + 0x40000 + ((i & 0x03) << 16);
    }
  }

  /**********************************************
          BACKUP MEMORY 
  ***********************************************/
  sram_init();
  eeprom_i2c_init();

  /* memory-mapped SRAM */
  if (sram.on && !sram.custom)
  {
    /* SRAM is mapped by default unless it overlaps with ROM area (Phantasy Star 4, Beyond Oasis/Legend of Thor, World Series Baseball 9x, Duke Nukem 3D,...) */
    if (sram.start >= cart.romsize)
    {
      m68k.memory_map[sram.start >> 16].base    = sram.sram;
      m68k.memory_map[sram.start >> 16].read8   = sram_read_byte;
      m68k.memory_map[sram.start >> 16].read16  = sram_read_word;
      m68k.memory_map[sram.start >> 16].write8  = sram_write_byte;
      m68k.memory_map[sram.start >> 16].write16 = sram_write_word;
      zbank_memory_map[sram.start >> 16].read   = sram_read_byte;
      zbank_memory_map[sram.start >> 16].write  = sram_write_byte;
    }

    /* support for Triple Play 96 & Triple Play - Gold Edition mapping */
    else if ((strstr(rominfo.product,"T-172026") != NULL) || (strstr(rominfo.product,"T-172116") != NULL))
    {
      /* $000000-$1fffff: cartridge ROM (lower 2MB) */
      /* $200000-$2fffff: SRAM (32KB mirrored) */
      /* NB: existing 4MB ROM dumps include SRAM data at ROM offsets 0x200000-0x2fffff */ 
      for (i=0x20; i<0x30; i++)
      {
        m68k.memory_map[i].base    = sram.sram;
        m68k.memory_map[i].read8   = sram_read_byte;
        m68k.memory_map[i].read16  = sram_read_word;
        m68k.memory_map[i].write8  = sram_write_byte;
        m68k.memory_map[i].write16 = sram_write_word;
        zbank_memory_map[i].read   = sram_read_byte;
        zbank_memory_map[i].write  = sram_write_byte;
      }

      /* $300000-$3fffff: cartridge ROM (upper 1MB) */
      /* NB: only real (3MB) Mask ROM dumps need ROM offsets 0x200000-0x2fffff to be remapped to this area */
      if (READ_BYTE(cart.rom, 0x200000) != 0xFF)
      {
        for (i=0x30; i<0x40; i++)
        {
          m68k.memory_map[i].base = cart.rom + ((i - 0x10) << 16);
        }
      }
    }
  }

  /**********************************************
          SVP CHIP 
  ***********************************************/
  svp = NULL;
  if (strstr(rominfo.international,"Virtua Racing"))
  {
    svp_init();
  }

  /**********************************************
          LOCK-ON 
  ***********************************************/

  /* clear existing patches */
  ggenie_shutdown();
  areplay_shutdown();

  /* initialize extra hardware */
  switch (config.lock_on)
  {
    case TYPE_GG:
    {
      ggenie_init();
      break;
    }

    case TYPE_AR:
    {
      areplay_init();
      break;
    }

    case TYPE_SK:
    {
      /* store S&K ROM above cartridge ROM (and before backup memory) */
      if (cart.romsize > 0x600000) break;

      /* try to load Sonic & Knuckles ROM file (2 MB) */
      if (load_archive(SK_ROM, cart.rom + 0x600000, 0x200000, NULL) == 0x200000)
      {
        /* check ROM header */
        if (!memcmp(cart.rom + 0x600000 + 0x120, "SONIC & KNUCKLES",16))
        {
          /* try to load Sonic 2 & Knuckles UPMEM ROM (256 KB) */
          if (load_archive(SK_UPMEM, cart.rom + 0x900000, 0x40000, NULL) == 0x40000)
          {
            /* $000000-$1FFFFF is mapped to S&K ROM */
            for (i=0x00; i<0x20; i++)
            {
              m68k.memory_map[i].base = cart.rom + 0x600000 + (i << 16);
            }

#ifdef LSB_FIRST
            for (i=0; i<0x200000; i+=2)
            {
              /* Byteswap ROM */
              uint8 temp = cart.rom[i + 0x600000];
              cart.rom[i + 0x600000] = cart.rom[i + 0x600000 + 1];
              cart.rom[i + 0x600000 + 1] = temp;
            }

            for (i=0; i<0x40000; i+=2)
            {
              /* Byteswap ROM */
              uint8 temp = cart.rom[i + 0x900000];
              cart.rom[i + 0x900000] = cart.rom[i + 0x900000 + 1];
              cart.rom[i + 0x900000 + 1] = temp;
            }
#endif
            cart.special |= HW_LOCK_ON;
          }
        }
      }
      break;
    }

    default:
    {
      break;
    }
  }

  /**********************************************
        CARTRIDGE EXTRA HARDWARE
  ***********************************************/
  memset(&cart.hw, 0, sizeof(cart.hw));

  /* search for game into database */
  for (i=0; i<(sizeof(rom_database)/sizeof(md_entry_t)); i++)
  {
    /* known cart found ! */
    if ((rominfo.checksum == rom_database[i].chk_1) &&
        (rominfo.realchecksum == rom_database[i].chk_2))
    {
      int j = rom_database[i].bank_start;

      /* retrieve hardware information */
      memcpy(&cart.hw, &(rom_database[i].cart_hw), sizeof(cart.hw));

      /* initialize memory handlers for $400000-$7FFFFF region */
      while (j <= rom_database[i].bank_end)
      {
        if (cart.hw.regs_r)
        {
          m68k.memory_map[j].read8    = cart.hw.regs_r;
          m68k.memory_map[j].read16   = cart.hw.regs_r;
          zbank_memory_map[j].read    = cart.hw.regs_r;
        }
        if (cart.hw.regs_w)
        {
          m68k.memory_map[j].write8   = cart.hw.regs_w;
          m68k.memory_map[j].write16  = cart.hw.regs_w;
          zbank_memory_map[j].write   = cart.hw.regs_w;
        }
        j++;
      }

      /* leave loop */
      break;
    }
  }

  /* Realtec mapper */
  if (cart.hw.realtec)
  {
    /* 8k BOOT ROM */
    for (i=0; i<8; i++)
    {
      memcpy(cart.rom + 0x900000 + i*0x2000, cart.rom + 0x7e000, 0x2000);
    }

    /* BOOT ROM is mapped to $000000-$3FFFFF */
    for (i=0x00; i<0x40; i++)
    {
      m68k.memory_map[i].base = cart.rom + 0x900000;
    }
  }

  /* detect specific mappers */
  if (strstr(rominfo.consoletype,"SEGA SSF"))
  {
    /* Everdrive extended SSF mapper */
    cart.hw.time_w = mapper_512k_w;

    /* cartridge ROM mapping is reinitialized on /VRES */
    cart.hw.bankshift = 1;
  }
  else if (strstr(rominfo.domestic,"SUPER STREET FIGHTER2"))
  {
    /* SSF2 mapper */
    cart.hw.time_w = mapper_ssf2_w;

    /* cartridge ROM mapping is reinitialized on /VRES */
    cart.hw.bankshift = 1;
  }
  else if (strstr(rominfo.product,"T-5740"))
  {
    /* T-5740XX-XX mapper */
    cart.hw.bankshift = 1;
    m68k.memory_map[0x01].read8 = mapper_t5740_r;
    zbank_memory_map[0x01].read = mapper_t5740_r;

    /* specific !TIME handlers */
    cart.hw.time_w = mapper_t5740_w;
    cart.hw.time_r = eeprom_spi_read;

    /* initialize SPI EEPROM board */
    eeprom_spi_init();
  }
  else if (strstr(rominfo.ROMType,"SF") && strstr(rominfo.product,"001"))
  {
    /* SF-001 mapper */
    m68k.memory_map[0x00].write8 = mapper_sf001_w;
    m68k.memory_map[0x00].write16 = mapper_sf001_w;
    zbank_memory_map[0x00].write = mapper_sf001_w;

    /* no !TIME handler */
    cart.hw.time_w = m68k_unused_8_w;

    /* cartridge ROM is mapped to $3C0000-$3FFFFF on reset */
    for (i=0x3c; i<0x40; i++)
    {
      m68k.memory_map[i].base     = cart.rom + (i << 16);
      m68k.memory_map[i].read8    = NULL;
      m68k.memory_map[i].read16   = NULL;
      m68k.memory_map[i].write8   = m68k_unused_8_w;
      m68k.memory_map[i].write16  = m68k_unused_16_w;
      zbank_memory_map[i].read    = NULL;
      zbank_memory_map[i].write   = m68k_unused_8_w;
    }
  }
  else if (strstr(rominfo.ROMType,"SF") && strstr(rominfo.product,"002"))
  {
    /* SF-002 mapper */
    m68k.memory_map[0x00].write8 = mapper_sf002_w;
    m68k.memory_map[0x00].write16 = mapper_sf002_w;
    zbank_memory_map[0x00].write = mapper_sf002_w;

    /* no !TIME handler */
    cart.hw.time_w = m68k_unused_8_w;
  }
  else if (strstr(rominfo.ROMType,"SF") && strstr(rominfo.product,"004"))
  {
    /* SF-004 mapper */
    m68k.memory_map[0x00].write8 = mapper_sf004_w;
    m68k.memory_map[0x00].write16 = mapper_sf004_w;
    zbank_memory_map[0x00].write = mapper_sf004_w;

    /* specific !TIME handlers */
    cart.hw.time_r = mapper_sf004_r;
    cart.hw.time_w = m68k_unused_8_w;

    /* first 256K ROM bank is mirrored into $000000-$1FFFFF on reset */
    for (i=0x00; i<0x20; i++)
    {
      m68k.memory_map[i].base = cart.rom + ((i & 0x03) << 16);
    }

    /* 32K static RAM mapped to $200000-$2FFFFF is disabled on reset */
    for (i=0x20; i<0x30; i++)
    {
      m68k.memory_map[i].base    = sram.sram;
      m68k.memory_map[i].read8   = m68k_read_bus_8;
      m68k.memory_map[i].read16  = m68k_read_bus_16;
      m68k.memory_map[i].write8  = m68k_unused_8_w;
      m68k.memory_map[i].write16 = m68k_unused_16_w;
      zbank_memory_map[i].read   = m68k_read_bus_8;
      zbank_memory_map[i].write  = zbank_unused_w;
    }

    /* $300000-$3FFFFF is not mapped */
    for (i=0x30; i<0x40; i++)
    {
      m68k.memory_map[i].read8   = m68k_read_bus_8;
      m68k.memory_map[i].read16  = m68k_read_bus_16;
      m68k.memory_map[i].write8  = m68k_unused_8_w;
      m68k.memory_map[i].write16 = m68k_unused_16_w;
      zbank_memory_map[i].read   = m68k_read_bus_8;
      zbank_memory_map[i].write  = zbank_unused_w;
    }
  }
  else if (strstr(rominfo.ROMType,"GM") && strstr(rominfo.product,"00000000-42"))
  {
    /* Flashkit MD mapper */
    m68k.memory_map[0x00].write8 = mapper_flashkit_w;
    m68k.memory_map[0x00].write16 = mapper_flashkit_w;
    zbank_memory_map[0x00].write = mapper_flashkit_w;
  }
  else if ((cart.romsize == 0x400000) && 
           (READ_BYTE(cart.rom, 0x200150) == 'C') &&
           (READ_BYTE(cart.rom, 0x200151) == 'A') &&
           (READ_BYTE(cart.rom, 0x200152) == 'N') &&
           (READ_BYTE(cart.rom, 0x200153) == 'O') &&
           (READ_BYTE(cart.rom, 0x200154) == 'N'))
  {
    /* Canon - Legend of the new Gods (4MB dump) */
    cart.hw.time_w = mapper_wd1601_w;
    cart.hw.bankshift = 1;
    sram.on = 1;
    sram.start = 0x200000;
    sram.end = 0x201fff;
  }
  else if ((*(uint16 *)(cart.rom + 0x08) == 0x6000) && (*(uint16 *)(cart.rom + 0x0a) == 0x01f6) && (rominfo.realchecksum == 0xf894))
  {
    /* Super Mario World 64 (unlicensed) mapper */
    for (i=0x08; i<0x10; i++)
    {
      /* lower 512KB mirrored */
      m68k.memory_map[i].base = cart.rom + ((i & 7) << 16);
    }

    for (i=0x10; i<0x40; i++)
    {
      /* unused area */
      m68k.memory_map[i].read8   = m68k_read_bus_8;
      m68k.memory_map[i].read16  = m68k_read_bus_16;
      m68k.memory_map[i].write8  = m68k_unused_8_w;
      m68k.memory_map[i].write16 = m68k_unused_16_w;
      zbank_memory_map[i].read   = m68k_read_bus_8;
      zbank_memory_map[i].write  = zbank_unused_w;
    }

    for (i=0x60; i<0x70; i++)
    {
      /* custom hardware */
      m68k.memory_map[i].base   = cart.rom + 0x0f0000;
      m68k.memory_map[i].read8  = ((i & 0x07) < 0x04) ? NULL : mapper_smw_64_r;
      m68k.memory_map[i].read16  = ((i & 0x07) < 0x04) ? NULL : mapper_smw_64_r;
      m68k.memory_map[i].write8 = mapper_smw_64_w;
      m68k.memory_map[i].write16 = mapper_smw_64_w;
      zbank_memory_map[i].read  = ((i & 0x07) < 0x04) ? NULL : mapper_smw_64_r;
      zbank_memory_map[i].write = mapper_smw_64_w;
    }
  }
  else if (cart.romsize > 0x400000)
  {
    /* assume linear ROM mapping by default (max. 10MB) */
    for (i=0x40; i<0xA0; i++)
    {
      m68k.memory_map[i].base   = cart.rom + (i<<16);
      m68k.memory_map[i].read8  = NULL;
      m68k.memory_map[i].read16 = NULL;
      zbank_memory_map[i].read  = NULL;
    }
  }

  /* default write handler for !TIME range ($A130xx)*/
  if (!cart.hw.time_w)
  {
    cart.hw.time_w = default_time_w;
  }
}

/* hardware that need to be reseted on power on */
void md_cart_reset(int hard_reset)
{
  int i;

  /* reset cartridge mapping */
  if (cart.hw.bankshift)
  {
    for (i=0x00; i<0x40; i++)
    {
      m68k.memory_map[i].base = cart.rom + ((i<<16) & cart.mask);
    }
  }
  
  /* SVP chip */
  if (svp)
  {
    svp_reset();
  }

  /* Lock-ON */
  switch (config.lock_on)
  {
    case TYPE_GG:
    {
      ggenie_reset(hard_reset);
      break;
    }

    case TYPE_AR:
    {
      areplay_reset(hard_reset);
      break;
    }

    case TYPE_SK:
    {
      if (cart.special & HW_LOCK_ON)
      {
        /* disable UPMEM chip at $300000-$3fffff */
        for (i=0x30; i<0x40; i++)
        {
          m68k.memory_map[i].base = cart.rom + ((i<<16) & cart.mask);
        }
      }
      break;
    }

    default:
    {
      break;
    }
  }
}

int md_cart_context_save(uint8 *state)
{
  int i;
  int bufferptr = 0;
  uint8 *base;

  /* cartridge mapping */
  for (i=0; i<0x40; i++)
  {
    /* get base address */
    base = m68k.memory_map[i].base;
      
    if (base == sram.sram)
    {
      /* SRAM */
      state[bufferptr++] = 0xff;
    }
    else if (base == boot_rom)
    {
      /* Boot ROM */
      state[bufferptr++] = 0xfe;
    }
    else
    {
      /* Cartridge ROM */
      state[bufferptr++] = ((base - cart.rom) >> 16) & 0xff;
    }
  }

  /* hardware registers */
  save_param(cart.hw.regs, sizeof(cart.hw.regs));

  /* SVP */
  if (svp)
  {
    save_param(svp->iram_rom, 0x800);
    save_param(svp->dram,sizeof(svp->dram));
    save_param(&svp->ssp1601,sizeof(ssp1601_t));
  }

  return bufferptr;
}

int md_cart_context_load(uint8 *state)
{
  int i;
  int bufferptr = 0;
  uint8 offset;

  /* cartridge mapping */
  for (i=0; i<0x40; i++)
  {
    /* get offset */
    offset = state[bufferptr++];

    if (offset == 0xff)
    {
      /* SRAM */
      m68k.memory_map[i].base     = sram.sram;
      m68k.memory_map[i].read8    = sram_read_byte;
      m68k.memory_map[i].read16   = sram_read_word;
      m68k.memory_map[i].write8   = sram_write_byte;
      m68k.memory_map[i].write16  = sram_write_word;
      zbank_memory_map[i].read    = sram_read_byte;
      zbank_memory_map[i].write   = sram_write_byte;

    }
    else
    {
      /* check if SRAM was mapped there before loading state */
      if (m68k.memory_map[i].base == sram.sram)
      {
        m68k.memory_map[i].read8    = NULL;
        m68k.memory_map[i].read16   = NULL;
        m68k.memory_map[i].write8   = m68k_unused_8_w;
        m68k.memory_map[i].write16  = m68k_unused_16_w;
        zbank_memory_map[i].read    = NULL;
        zbank_memory_map[i].write   = zbank_unused_w;
      }

      /* ROM */
      m68k.memory_map[i].base = (offset == 0xfe) ? boot_rom : (cart.rom + (offset << 16));
    }
  }

  /* hardware registers */
  load_param(cart.hw.regs, sizeof(cart.hw.regs));

  /* SVP */
  if (svp)
  {
    load_param(svp->iram_rom, 0x800);
    load_param(svp->dram,sizeof(svp->dram));
    load_param(&svp->ssp1601,sizeof(ssp1601_t));
  }

  return bufferptr;
}

/************************************************************
          MAPPER handlers 
*************************************************************/

/* 
  "official" ROM/SRAM bankswitch (Phantasy Star IV, Story of Thor/Beyond Oasis, Sonic 3 & Knuckles)
*/
static void mapper_sega_w(uint32 data)
{
  int i;

  if (data & 1)
  {
    if (sram.on)
    {
      /* Backup RAM mapped to $200000-$20ffff (normally mirrored up to $3fffff but this breaks Sonic Megamix and no game need it) */
      m68k.memory_map[0x20].base    = sram.sram;
      m68k.memory_map[0x20].read8   = sram_read_byte;
      m68k.memory_map[0x20].read16  = sram_read_word;
      zbank_memory_map[0x20].read   = sram_read_byte;

      /* Backup RAM write protection */
      if (data & 2)
      {
        m68k.memory_map[0x20].write8  = m68k_unused_8_w;
        m68k.memory_map[0x20].write16 = m68k_unused_16_w;
        zbank_memory_map[0x20].write  = zbank_unused_w;
      }
      else
      {
        m68k.memory_map[0x20].write8  = sram_write_byte;
        m68k.memory_map[0x20].write16 = sram_write_word;
        zbank_memory_map[0x20].write  = sram_write_byte;
      }
    }

    /* S&K lock-on chip */
    if ((cart.special & HW_LOCK_ON) && (config.lock_on == TYPE_SK))
    {
      /* S2K upmem chip mapped to $300000-$3fffff (256K mirrored) */
      for (i=0x30; i<0x40; i++)
      {
        m68k.memory_map[i].base = (cart.rom + 0x900000) + ((i & 3) << 16);
      }
    }
  }
  else
  {
    /* cartridge ROM mapped to $200000-$3fffff */
    for (i=0x20; i<0x40; i++)
    {
      m68k.memory_map[i].base     = cart.rom + ((i<<16) & cart.mask);
      m68k.memory_map[i].read8    = NULL;
      m68k.memory_map[i].read16   = NULL;
      zbank_memory_map[i].read    = NULL;
      m68k.memory_map[i].write8   = m68k_unused_8_w;
      m68k.memory_map[i].write16  = m68k_unused_16_w;
      zbank_memory_map[i].write   = zbank_unused_w;
    }
  }
}

/*
   Everdrive extended SSF ROM bankswitch
   documented by Krikzz (http://krikzz.com/pub/support/mega-ed/dev/extended_ssf.txt) 
*/
static void mapper_512k_w(uint32 address, uint32 data)
{
  uint32 i;

  /* 512K ROM paging */
  uint8 *src = cart.rom + ((data << 19) & cart.mask);

  /* cartridge area ($000000-$3FFFFF) is divided into 8 x 512K banks */
  address = (address << 2) & 0x38;
  
  /* remap selected ROM page to selected bank */
  for (i=0; i<8; i++)
  {
    m68k.memory_map[address++].base = src + (i<<16);
  }
}

/*
   Super Street Fighter 2 ROM bankswitch
   documented by Bart Trzynadlowski (http://emu-docs.org/Genesis/ssf2.txt) 
*/
static void mapper_ssf2_w(uint32 address, uint32 data)
{
  /* only banks 1-7 are remappable, bank 0 remains unchanged */
  if (address & 0x0E)
  {
    mapper_512k_w(address, data);
  }
}

/* 
  SF-001 mapper
*/
static void mapper_sf001_w(uint32 address, uint32 data)
{
  switch ((address >> 8) & 0xf)
  {
    case 0xe:
    {
      int i;

      /* bit 6: enable / disable cartridge access  */
      if (data & 0x40)
      {
        /* $000000-$3FFFFF is not mapped */
        for (i=0x00; i<0x40; i++)
        {
          m68k.memory_map[i].base     = cart.rom + (i << 16);
          m68k.memory_map[i].read8    = m68k_read_bus_8;
          m68k.memory_map[i].read16   = m68k_read_bus_16;
          m68k.memory_map[i].write8   = (i > 0x00) ? m68k_unused_8_w : mapper_sf001_w;
          m68k.memory_map[i].write16  = (i > 0x00) ? m68k_unused_16_w : mapper_sf001_w;
          zbank_memory_map[i].read    = zbank_unused_r;
          zbank_memory_map[i].write   = (i > 0x00) ? m68k_unused_8_w : mapper_sf001_w;
        }
      }

      /* bit 7: enable / disable SRAM & ROM bankswitching */
      else if (data & 0x80)
      {
        /* 256K ROM bank #15 mapped to $000000-$03FFFF  */
        for (i=0x00; i<0x04; i++)
        {
          m68k.memory_map[i].base     = cart.rom + ((0x38 + i) << 16);
          m68k.memory_map[i].read8    = NULL;
          m68k.memory_map[i].read16   = NULL;
          zbank_memory_map[i].read    = NULL;
        }

        /* 256K ROM banks #2 to #15 mapped to $040000-$3BFFFF (last revision) or $040000-$3FFFFF (older revisions) */
        for (i=0x04; i<(sram.start >> 16); i++)
        {
          m68k.memory_map[i].base     = cart.rom + (i << 16);
          m68k.memory_map[i].read8    = NULL;
          m68k.memory_map[i].read16   = NULL;
          zbank_memory_map[i].read    = NULL;
        }

        /* 32K static RAM mirrored into $3C0000-$3FFFFF (odd bytes only) (last revision only) */
        while (i<0x40)
        {
          m68k.memory_map[i].base     = sram.sram;
          m68k.memory_map[i].read8    = sram_read_byte;
          m68k.memory_map[i].read16   = sram_read_word;
          m68k.memory_map[i].write8   = sram_write_byte;
          m68k.memory_map[i].write16  = sram_write_word;
          zbank_memory_map[i].read    = sram_read_byte;
          zbank_memory_map[i].write   = sram_write_byte;
          i++;
        }
      }
      else
      {
        /* 256K ROM banks #1 to #16 mapped to $000000-$3FFFFF (default) */
        for (i=0x00; i<0x40; i++)
        {
          m68k.memory_map[i].base     = cart.rom + (i << 16);
          m68k.memory_map[i].read8    = NULL;
          m68k.memory_map[i].read16   = NULL;
          m68k.memory_map[i].write8   = (i > 0x00) ? m68k_unused_8_w : mapper_sf001_w;
          m68k.memory_map[i].write16  = (i > 0x00) ? m68k_unused_16_w : mapper_sf001_w;
          zbank_memory_map[i].read    = NULL;
          zbank_memory_map[i].write   = (i > 0x00) ? m68k_unused_8_w : mapper_sf001_w;
        }
      }

      /* bit 5: lock bankswitch hardware when set */
      if (data & 0x20)
      {
        /* disable bankswitch hardware access until hard reset */
        m68k.memory_map[0x00].write8  = m68k_unused_8_w;
        m68k.memory_map[0x00].write16 = m68k_unused_16_w;
        zbank_memory_map[0x00].write  = m68k_unused_8_w;
      }

      return;
    }

    default:
    {
      m68k_unused_8_w(address, data);
      return;
    }
  }
}

/* 
  SF-002 mapper
*/
static void mapper_sf002_w(uint32 address, uint32 data)
{
  int i;
  if (data & 0x80)
  {
    /* $000000-$1BFFFF mapped to $200000-$3BFFFF */
    for (i=0x20; i<0x3C; i++)
    {
      m68k.memory_map[i].base = cart.rom + ((i & 0x1F) << 16);
    }
  }
  else
  {
    /* $200000-$3BFFFF mapped to $200000-$3BFFFF */
    for (i=0x20; i<0x3C; i++)
    {
      m68k.memory_map[i].base = cart.rom + (i << 16);
    }
  }
}

/* 
  SF-004 mapper
*/
static void mapper_sf004_w(uint32 address, uint32 data)
{
  int i;
  switch ((address >> 8) & 0xf)
  {
    case 0xd:
    {
      /* bit 7: enable/disable static RAM access */
      if (data & 0x80)
      {
        /* 32KB static RAM mirrored into $200000-$2FFFFF (odd bytes only) */
        for (i=0x20; i<0x30; i++)
        {
          m68k.memory_map[i].read8   = sram_read_byte;
          m68k.memory_map[i].read16  = sram_read_word;
          m68k.memory_map[i].write8  = sram_write_byte;
          m68k.memory_map[i].write16 = sram_write_word;
          zbank_memory_map[i].read   = sram_read_byte;
          zbank_memory_map[i].write  = sram_write_byte;
        }
      }
      else
      {
        /* 32KB static RAM disabled at $200000-$2FFFFF */
        for (i=0x20; i<0x30; i++)
        {
          m68k.memory_map[i].read8   = m68k_read_bus_8;
          m68k.memory_map[i].read16  = m68k_read_bus_16;
          m68k.memory_map[i].write8  = m68k_unused_8_w;
          m68k.memory_map[i].write16 = m68k_unused_16_w;
          zbank_memory_map[i].read   = m68k_read_bus_8;
          zbank_memory_map[i].write  = m68k_unused_8_w;
        }
      }

      return;
    }

    case 0x0e:
    {
      /* bit 5: enable / disable cartridge ROM access */
      if (data & 0x20)
      {
        /* $000000-$1FFFFF is not mapped */
        for (i=0x00; i<0x20; i++)
        {
          m68k.memory_map[i].read8  = m68k_read_bus_8;
          m68k.memory_map[i].read16 = m68k_read_bus_16;
          zbank_memory_map[i].read  = m68k_read_bus_8;
        }
      }

      /* bit 6: enable / disable first page mirroring */
      else if (data & 0x40)
      {
        /* first page ROM bank */
        uint8 base = (m68k.memory_map[0x00].base - cart.rom) >> 16;

        /* 5 x 256K ROM banks mapped to $000000-$13FFFF, starting from first page ROM bank */
        for (i=0x00; i<0x14; i++)
        {
          m68k.memory_map[i].base   = cart.rom + (((base + i) & 0x1f) << 16);
          m68k.memory_map[i].read8  = NULL;
          m68k.memory_map[i].read16 = NULL;
          zbank_memory_map[i].read  = NULL;
        }

        /* $140000-$1FFFFF is not mapped */
        for (i=0x14; i<0x20; i++)
        {
          m68k.memory_map[i].read8  = m68k_read_bus_8;
          m68k.memory_map[i].read16 = m68k_read_bus_16;
          zbank_memory_map[i].read  = m68k_read_bus_8;
        }
      }
      else
      {
        /* first page 256K ROM bank mirrored into $000000-$1FFFFF */
        for (i=0x00; i<0x20; i++)
        {
          m68k.memory_map[i].base = m68k.memory_map[0].base + ((i & 0x03) << 16);
          m68k.memory_map[i].read8  = NULL;
          m68k.memory_map[i].read16 = NULL;
          zbank_memory_map[i].read  = NULL;
        }
      }

      /* bit 7: lock ROM bankswitching hardware when cleared */
      if (!(data & 0x80))
      {
        /* disable bankswitch hardware access */
        m68k.memory_map[0x00].write8 = m68k_unused_8_w;
        m68k.memory_map[0x00].write16 = m68k_unused_16_w;
        zbank_memory_map[0x00].write = m68k_unused_8_w;
      }

      return;
    }

    case 0x0f:
    {
      /* bits 6-4: select first page ROM bank (8 x 256K ROM banks) */
      uint8 base = ((data >> 4) & 7) << 2;

      if (m68k.memory_map[0].base == m68k.memory_map[4].base)
      {
        /* selected 256K ROM bank mirrored into $000000-$1FFFFF */
        for (i=0x00; i<0x20; i++)
        {
          m68k.memory_map[i].base = cart.rom + ((base + (i & 0x03)) << 16);
        }
      }
      else
      {
        /* 5 x 256K ROM banks mapped to $000000-$13FFFF, starting from selected bank */
        for (i=0x00; i<0x14; i++)
        {
          m68k.memory_map[i].base = cart.rom + (((base + i) & 0x1f) << 16);
        }
      }

      return;
    }

    default:
    {
      m68k_unused_8_w(address, data);
      return;
    }
  }
}

static uint32 mapper_sf004_r(uint32 address)
{
  /* return first page 256K bank index ($00,$10,$20,...,$70) */
  return (((m68k.memory_map[0x00].base - cart.rom) >> 18) << 4);
}

/* 
  T-5740xx-xx mapper
*/
static void mapper_t5740_w(uint32 address, uint32 data)
{
  int i;
  uint8 *base;

  switch (address & 0xff)
  {
    case 0x01: /* mode register */
    {
      /* bits 7-4: unused ?                           */
      /* bit 3: enable SPI registers access ?         */
      /* bit 2: not used ?                            */
      /* bit 1: enable bankswitch registers access ?  */
      /* bit 0: always set, enable hardware access ?  */
      return;
    }

    case 0x03: /* page #5 register */
    {
      /* map any of 16 x 512K ROM banks to $280000-$2FFFFF */
      base = cart.rom + ((data & 0x0f) << 19);
      for (i=0x28; i<0x30; i++)
      {
        m68k.memory_map[i].base = base + ((i & 0x07) << 16);
      }
      return;
    }

    case 0x05: /* page #6 register */
    {
      /* map any of 16 x 512K ROM banks to $300000-$37FFFF */
      base = cart.rom + ((data & 0x0f) << 19);
      for (i=0x30; i<0x38; i++)
      {
        m68k.memory_map[i].base = base + ((i & 0x07) << 16);
      }
      return;
    }

    case 0x07: /* page #7 register */
    {
      /* map any of 16 x 512K ROM banks to $380000-$3FFFFF */
      base = cart.rom + ((data & 0x0f) << 19);
      for (i=0x38; i<0x40; i++)
      {
        m68k.memory_map[i].base = base + ((i & 0x07) << 16);
      }
      return;
    }

    case 0x09: /* serial EEPROM SPI board support */
    {
      eeprom_spi_write(data);
      return;
    }

    default:
    {
      /* unknown registers */
      m68k_unused_8_w(address, data);
      return;
    }
  }
}

static uint32 mapper_t5740_r(uint32 address)
{
  /* By default, first 32K of each eight 512K pages mapped in $000000-$3FFFFF are mirrored in the 512K page   */
  /* mirroring is disabled/enabled when a specific number of words is being read from specific ROM addresses  */
  /* Exact decoding isn't known but mirrored data is expected on startup when reading a few times from $181xx */
  /* this area doesn't seem to be accessed as byte later so it seems safe to always return mirrored data here */
  if ((address & 0xff00) == 0x8100)
  {
    return READ_BYTE(cart.rom , (address & 0x7fff));
  }

  return READ_BYTE(cart.rom, address);
}

/* 
  FlashKit MD mapper (very limited M29W320xx Flash memory support -- enough for unlicensed games using device signature as protection) 
*/
static void mapper_flashkit_w(uint32 address, uint32 data)
{
  /* Increment Bus Write counter */
  cart.hw.regs[0]++;

  /* Wait for 3 consecutive bus writes */
  if (cart.hw.regs[0] == 3)
  {
    /* assume 'Auto Select' command */
    m68k.memory_map[0x0].read16 = mapper_flashkit_r;
  }
  else if (cart.hw.regs[0] == 4)
  {
    /* assume 'Read/Reset' command */
    m68k.memory_map[0x0].read16 = NULL;

    /* reset Bus Write counter */
    cart.hw.regs[0] = 0;
  }
}

static uint32 mapper_flashkit_r(uint32 address)
{
  /* hard-coded device signature */
  switch (address & 0x06)
  {
    case 0x00:  /* Manufacturer Code (STMicroelectronics) */
      return 0x0020;
    case 0x02:  /* Device Code (M29W320EB) */
      return 0x2257;
    default:    /* not supported */
      return 0xffff;
  }
}

/* 
  Super Mario World 64 (unlicensed) mapper
*/
static void mapper_smw_64_w(uint32 address, uint32 data)
{
  /* internal registers (saved to backup RAM) */
  switch ((address >> 16) & 0x07)
  {
    case 0x00:  /* $60xxxx */
    {
      if (address & 2)
      {
        /* $600003 data write mode ? */
        switch (sram.sram[0x00] & 0x07)
        {
          case 0x00:
          {
            /* update value returned at $660001-$660003 */
            sram.sram[0x06] = ((sram.sram[0x06] ^ sram.sram[0x01]) ^ data) & 0xFE;
            break;
          }

          case 0x01:
          {
            /* update value returned at $660005-$660007 */
            sram.sram[0x07] = data & 0xFE;
            break;
          }

          case 0x07:
          {
            /* update selected ROM bank (upper 512K) mapped at $610000-$61ffff */
            m68k.memory_map[0x61].base = m68k.memory_map[0x69].base = cart.rom + 0x080000 + ((data & 0x1c) << 14);
            break;
          }

          default:
          {
            /* unknown mode */
            break;
          }
        }

        /* $600003 data register */
        sram.sram[0x01] = data;
      }
      else
      {
        /* $600001 ctrl register */
        sram.sram[0x00] = data;
      }
      return;
    }

    case 0x01:  /* $61xxxx */
    {
      if (address & 2)
      {
        /* $610003 ctrl register */
        sram.sram[0x02] = data;
      }
      return;
    }

    case 0x04:  /* $64xxxx */
    {
      if (address & 2)
      {
        /* $640003 data register */
        sram.sram[0x04] = data;
      }
      else
      {
        /* $640001 data register */
        sram.sram[0x03] = data;
      }
      return;
    }

    case 0x06:  /* $66xxxx */
    {
      /* unknown */
      return;
    }

    case 0x07:  /* $67xxxx */
    {
      if (!(address & 2))
      {
        /* $670001 ctrl register */
        sram.sram[0x05] = data;

        /* upper 512K ROM bank-switching enabled ? */
        if (sram.sram[0x02] & 0x80)
        {
          /* update selected ROM bank (upper 512K) mapped at $600000-$60ffff */
          m68k.memory_map[0x60].base = m68k.memory_map[0x68].base = cart.rom + 0x080000 + ((data & 0x1c) << 14);
        }
      }
      return;
    }

    default:  /* not used */
    {
      m68k_unused_8_w(address, data);
      return;
    }
  }
}

static uint32 mapper_smw_64_r(uint32 address)
{
  /* internal registers (saved to backup RAM) */
  switch ((address >> 16) & 0x03)
  {
    case 0x02:  /* $66xxxx */
    {
      switch ((address >> 1) & 7)
      {
        case 0x00:  return sram.sram[0x06];
        case 0x01:  return sram.sram[0x06] + 1;
        case 0x02:  return sram.sram[0x07];
        case 0x03:  return sram.sram[0x07] + 1;
        case 0x04:  return sram.sram[0x08];
        case 0x05:  return sram.sram[0x08] + 1;
        case 0x06:  return sram.sram[0x08] + 2;
        case 0x07:  return sram.sram[0x08] + 3;
      }
    }

    case 0x03:  /* $67xxxx */
    {
      uint8 data = (sram.sram[0x02] & 0x80) ? ((sram.sram[0x05] & 0x40) ? (sram.sram[0x03] & sram.sram[0x04]) : (sram.sram[0x03] ^ 0xFF)) : 0x00;

      if (address & 2)
      {
        /* $670003 */
        data &= 0x7f;
      }
      else
      {
        /* $66xxxx data registers update */
        if (sram.sram[0x05] & 0x80)
        {
          if (sram.sram[0x05] & 0x20)
          {
            /* update $660009-$66000f data register */
            sram.sram[0x08] = (sram.sram[0x04] << 2) & 0xFC;
          }
          else
          {
            /* update $660001-$660003 data register */
            sram.sram[0x06] = (sram.sram[0x01] ^ (sram.sram[0x03] << 1)) & 0xFE;
          }
        }
      }

      return data;
    }

    default:  /* 64xxxx-$65xxxx */
    {
      return 0x00;
    }
  }
}

/* 
  Realtec ROM bankswitch (Earth Defend, Balloon Boy & Funny World, Whac-A-Critter)
  (Note: register usage is inverted in TascoDlx documentation)
*/
static void mapper_realtec_w(uint32 address, uint32 data)
{
  switch (address)
  {
    case 0x402000:  
    {
      /* number of mapped 64k blocks (the written value is a number of 128k blocks) */
      cart.hw.regs[2] = data << 1;
      return;
    }

    case 0x404000:
    {
      /* 00000xxx */
      cart.hw.regs[0] = data & 7;
      return;
    }

    case 0x400000:  
    {
      /* 00000yy1 */
      cart.hw.regs[1] = data & 6;

      /* ensure mapped size is not null */
      if (cart.hw.regs[2])
      {
        /* mapped start address is 00yy xxx0 0000 0000 0000 0000 */
        uint32 base = (cart.hw.regs[0] << 1) | (cart.hw.regs[1] << 3);

        /* selected blocks are mirrored into the whole cartridge area */
        int i;
        for (i=0x00; i<0x40; i++)
        {
          m68k.memory_map[i].base = &cart.rom[(base + (i % cart.hw.regs[2])) << 16];
        }
      }
      return;
    }
  }
}

/* Game no Kanzume Otokuyou ROM Mapper */
static void mapper_seganet_w(uint32 address, uint32 data)
{
  if ((address & 0xff) == 0xf1)
  {
    int i;
    if (data & 1)
    {
      /* ROM Write protected */
      for (i=0; i<0x40; i++)
      {
        m68k.memory_map[i].write8   = m68k_unused_8_w;
        m68k.memory_map[i].write16  = m68k_unused_16_w;
        zbank_memory_map[i].write   = zbank_unused_w;
      }
    }
    else
    {
      /* ROM Write enabled */
      for (i=0; i<0x40; i++)
      {
        m68k.memory_map[i].write8   = NULL;
        m68k.memory_map[i].write16  = NULL;
        zbank_memory_map[i].write   = NULL;
      }
    }
  }
}

/* 
  Custom ROM Bankswitch used in Soul Edge VS Samurai Spirits, Top Fighter, Mulan, Pocket Monsters II, Lion King 3, Super King Kong 99, Pokemon Stadium
*/
static void mapper_32k_w(uint32 data)
{
  int i;
  
  /* 64 x 32k banks */
  if (data)
  {
    for (i=0; i<0x10; i++)
    {
      /* Remap to unused ROM area  */
      m68k.memory_map[i].base = &cart.rom[0x400000 + (i << 16)];

      /* address = address OR (value << 15) */
      memcpy(m68k.memory_map[i].base, cart.rom + ((i << 16) | (data & 0x3f) << 15), 0x8000);
      memcpy(m68k.memory_map[i].base + 0x8000, cart.rom + ((i << 16) | ((data | 1) & 0x3f) << 15), 0x8000);
    }
  }
  else
  {
    /* reset default $000000-$0FFFFF mapping */
    for (i=0; i<16; i++)
    {
      m68k.memory_map[i].base = &cart.rom[i << 16];
    }
  }
}

/* 
  Custom ROM Bankswitch used in Chinese Fighter III
*/
static void mapper_64k_w(uint32 data)
{
  int i;

  /* 16 x 64k banks */
  if (data)
  {
    /* bank is mapped at $000000-$0FFFFF */
    for (i=0; i<16; i++)
    {
      m68k.memory_map[i].base = &cart.rom[(data & 0xf) << 16];
    }
  }
  else
  {
    /* reset default $000000-$0FFFFF mapping */
    for (i=0; i<16; i++)
    {
      m68k.memory_map[i].base = &cart.rom[(i & 0xf) << 16];
    }
  }
}

/* 
  Custom ROM Bankswitch used in pirate "Multi-in-1" cartridges, A Bug's Life, King of Fighter 99, Pocket Monster, Rockman X3
 */
static void mapper_64k_multi_w(uint32 address)
{
  int i;

  /* 64 x 64k banks */
  for (i=0; i<64; i++)
  {
    m68k.memory_map[i].base = &cart.rom[((address + i) & 0x3f) << 16];
  }
}

/* 
  Custom ROM Bankswitch used in pirate "1800-in-1" cartridge
 */
static uint32 mapper_128k_multi_r(uint32 address)
{
  int i;

  /* 16 x 128k banks (2MB ROM) */
  /* Bank index (B3 B2 B1 B0) is encoded in address lower byte = {0 X B0 B1 X B2 B3 0} */
  /* Note: {0 B0 X B1 X B2 B3 0} also works, see below for the 9 unique values being used for all menu entries
      read16 00A13000 (0002FBEE) => 0x000000-0x03ffff (2x128KB)
      read16 00A13018 (00FF2056) => 0x040000-0x07ffff (2x128KB)
      read16 00A13004 (00FF2120) => 0x080000-0x0bffff (2x128KB)
      read16 00A1301C (00FF20A6) => 0x0c0000-0x0fffff (2x128KB)
      read16 00A1300A (00FF20BA) => 0x100000-0x13ffff (2x128KB)
      read16 00A1301A (00FF20CE) => 0x140000-0x17ffff (2x128KB)
      read16 00A1300E (00FF20F4) => 0x180000-0x1bffff (2x128KB)
      read16 00A1301E (00FF2136) => 0x1c0000-0x1dffff (1x128KB)
      read16 00A1307E (00FF2142) => 0x1e0000-0x1fffff (1x128KB)
  */
  int bank = ((address & 0x02) << 2) | (address & 0x04) | ((address & 0x10) >> 3) | ((address & 0x20) >> 5);

  /* remap cartridge area (64 x 64k banks) */
  address = bank << 1;
  for (i=0x00; i<0x40; i++)
  {
    m68k.memory_map[i].base = &cart.rom[((address + i) & 0x3f) << 16];
  }

  /* returned value changes the menu title and number of entries in the 'game' list (the number of distinct games does not change though) */
  /* 0x00 => 9-in-1 */
  /* 0x01 => 190-in-1 */
  /* 0x02 => 888-in-1 */
  /* 0x03 => 1800-in-1 */
  /* real cartridge board has switches to select between the four different menus but here we force the largest menu selection (each other menus being a subset of the next larger menu) */
  return 0x03;
}

/* 
  Custom ROM Bankswitch used in pirate "Golden Mega 250-in-1" cartridge
 */
static void mapper_256k_multi_w(uint32 address, uint32 data)
{
  int i;

  /* 8 x 256k banks (2MB ROM) */
  /* Bank index (B2 B1 B0) is encoded in data lower byte = {B1 B0 X X 0 0 0 B2} */
  /* Note: {X B0 B1 B2 0 0 0 X}, {B1 B0 X B2 0 0 0 X} or {X B0 B1 X 0 0 0 B2} also work, see below for the 4 unique values being used for all menu entries
      write16 00089000 = 0000 (00FF0006) => 0x000000-0x03ffff (1x256KB)
      write16 00089000 = 0040 (00FF0006) => 0x040000-0x07ffff (1x256KB)
      write16 00089000 = 00A0 (00FF0006) => 0x080000-0x0fffff (2x256KB)
      write16 00089000 = 0011 (00FF0006) => 0x100000-0x1fffff (4x256KB)
  */
  int bank = ((data & 0x01) << 2) | ((data & 0xc0) >> 6);

  /* remap cartridge area (64 x 64k banks) */
  address = bank << 2;
  for (i=0x00; i<0x40; i++)
  {
    m68k.memory_map[i].base = &cart.rom[((address + i) & 0x3f) << 16];
  }
}

/* 
  Custom ROM Bankswitch used in "Canon - Legend of the New Gods" 
  (uses WD1601 QFPL V1.01 board also used in chinese X-in-1 pirates sold by mindkids)
 */
static void mapper_wd1601_w(uint32 address, uint32 data)
{
  int i;

  /* !TIME write16 0xA13002 = 0x3002 (00FFFE0C) */
  /* The board probably allows up to 256MB Flash ROM remapping but this game only has 4MB ROM chip */
  if ((address & 0xfe) == 0x02)
  {
    /* upper 2MB ROM mapped to $000000-$1fffff */
    for (i=0; i<0x20; i++)
    {
      m68k.memory_map[i].base = &cart.rom[(0x20 + i) << 16];
    }

    /* backup RAM (8KB) mapped to $2000000-$3fffff */
    for (i=0x20; i<0x40; i++)
    {
      m68k.memory_map[i].base    = sram.sram;
      m68k.memory_map[i].read8   = sram_read_byte;
      m68k.memory_map[i].read16  = sram_read_word;
      m68k.memory_map[i].write8  = sram_write_byte;
      m68k.memory_map[i].write16 = sram_write_word;
      zbank_memory_map[i].read   = sram_read_byte;
      zbank_memory_map[i].write  = sram_write_byte;
    }
  }
}

/*
  Custom ROM Bankswitch used in RADICA cartridges
  +++++++++++++++++++++++++++++++++++++++++++++++
   Two different boards seem to exist (one with support for 64KB banks mapping and another one supporting 128KB banks + battery-RAM).
   Radica Volume 1 requires 64KB banks mapping as the menu is located at a 64KB boundary.
   Sensible Soccer Plus edition requires 128KB banks mapping with only VA6-VA2 being used to select bank index (VA1 is ignored).
   Sensible Soccer Plus edition also requires 8KB backup RAM to be mapped in higher 2MB range.
   Other games support both 64KB or 128KB mapping so it's not clear what exact board they are using but none require SRAM so we use 64KB mapper by default.
   Note that Radica Volume 3 uses similar ROM mapping as Sensible Soccer Plus edition so it might be using same 128KB board, without any SRAM chip connected.
*/
static uint32 mapper_64k_radica_r(uint32 address)
{
  int i = 0;

  /* 64 x 64k banks */
  /*
    Volume 1
    --------
    000000h-0fffffh: Kid Chameleon                   : !TIME read16 0xA13000 (00FF103A)
    100000h-1fffffh: Dr Robotnik's Mean Bean Machine : !TIME read16 0xA13020 (00FF101E)
    200000h-27ffffh: Sonic The Hedgehog              : !TIME read16 0xA13040 (00FF101E)
    280000h-2fffffh: Golden Axe                      : !TIME read16 0xA13050 (00FF101E)
    300000h-37ffffh: Altered Beast                   : !TIME read16 0xA13060 (00FF101E)
    380000h-39ffffh: Flicky                          : !TIME read16 0xA13070 (00FF101E)
    3a0000h-3effffh: N/A                             : N/A
    3f0000h-3fffffh: Radica Menu (64 KB)             : !TIME read16 0xA1307E (00FF1006)

    Volume 2
    --------
    000000h-0fffffh: Sonic The Hedgehog 2            : !TIME read16 0xA13000 (00FF103A)
    100000h-1fffffh: The Ooze                        : !TIME read16 0xA13020 (00FF101E)
    200000h-2fffffh: Ecco The Dolphin                : !TIME read16 0xA13040 (00FF101E)
    300000h-37ffffh: Gain Ground                     : !TIME read16 0xA13060 (00FF101E)
    380000h-3bffffh: Alex Kidd in Enchanted Castle   : !TIME read16 0xA13070 (00FF101E)
    3c0000h-3dffffh: Columns                         : !TIME read16 0xA13078 (00FF101E)
    3e0000h-3fffffh: Radica Menu (128 KB)            : !TIME read16 0xA1307C (00FF1006)

    Volume 3 - Super Sonic Gold edition
    -----------------------------------
    000000h-01ffffh: Radica Menu (128 KB)            : N/A
    020000h-07ffffh: N/A                             : N/A
    080000h-0fffffh: Sonic The Hedgehog              : !TIME read16 0xA13010 (00FF1012)
    100000h-1fffffh: Sonic The Hedgehog 2            : !TIME read16 0xA13020 (00FF1012)
    200000h-2fffffh: Sonic Spinball                  : !TIME read16 0xA13040 (00FF1012)
    300000h-3fffffh: Dr Robotnik's Mean Bean Machine : !TIME read16 0xA13060 (00FF1012)

    Street Fighter 2 CE edition
    ---------------------------
    000000h-2fffffh: Street Fighter 2 CE             : !TIME read16 0xA13000 (00FF103A)
    300000h-3bffffh: Ghouls'n Ghosts                 : !TIME read16 0xA13060 (00FF101E)
    3c0000h-3dffffh: Radica Menu (128 KB)            : !TIME read16 0xA13078 (00FF1006)
    3e0000h-3fffffh: N/A                             : N/A
  */
  int index = (address >> 1) & 0x3F;

  /* $000000-$3fffff area is mapped to selected banks (OR gates between VA21-VA16 and selected index) */
  for (i = 0x00; i < 0x40; i++)
  {
    m68k.memory_map[i].base = &cart.rom[(index | i) << 16];
  }

  return 0xffff;
}

static uint32 mapper_128k_radica_r(uint32 address)
{
  int i = 0;

  /* 32 x 128k banks */
  /*
    Sensible Soccer Plus edition
    ----------------------------
    000000h-01ffffh: Radica Menu (128 KB)            : N/A
    020000h-07ffffh: N/A                             : N/A
    080000h-0fffffh: Sensible Soccer                 : !TIME read16 0xA13010 (00FF1012)
    100000h-1fffffh: Mega-Lo-Mania                   : !TIME read16 0xA13022 (00FF1012)
    200000h-37ffffh: Cannon Fodder                   : !TIME read16 0xA13042 (00FF1012)
    380000h-3fffffh: N/A                             : N/A

    Note: address bit 1 is ignored for bank selection but might be used to enable/disable SRAM mapping ? 
  */
  int index = (address >> 1) & 0x3E;

  /* $000000-$1fffff area is mapped to selected banks (OR gates between VA20-VA17 and selected index) */
  for (i = 0x00; i < 0x20; i++)
  {
    m68k.memory_map[i].base = &cart.rom[(index | i) << 16];
  }

  /* $200000-$3fffff area is mapped to 8KB SRAM (mirrored) */
  for (i = 0x20; i < 0x40; i++)
  {
    m68k.memory_map[i].base    = sram.sram;
    m68k.memory_map[i].read8   = sram_read_byte;
    m68k.memory_map[i].read16  = sram_read_word;
    m68k.memory_map[i].write8  = sram_write_byte;
    m68k.memory_map[i].write16 = sram_write_word;
    zbank_memory_map[i].read   = sram_read_byte;
    zbank_memory_map[i].write  = sram_write_byte;
  }

  return 0xffff;
}

/************************************************************
          default !TIME signal handler 
*************************************************************/

static void default_time_w(uint32 address, uint32 data)
{
  /* enable multi-game cartridge mapper by default */
  if (address < 0xa13060)
  {
    mapper_64k_multi_w(address);
    return;
  }

  /* enable "official" cartridge mapper by default */
  if (address > 0xa130f1)
  {
    mapper_512k_w(address, data);
  }
  else
  {
    mapper_sega_w(data);
  }
}


/************************************************************
          Internal register handlers
*************************************************************/

static uint32 default_regs_r(uint32 address)
{
  int i;
  for (i=0; i<4; i++)
  {
    if ((address & cart.hw.mask[i]) == cart.hw.addr[i])
    {
      return cart.hw.regs[i];
    }
  }
  return m68k_read_bus_8(address);
}

static uint32 default_regs_r_16(uint32 address)
{
  int i;
  for (i=0; i<4; i++)
  {
    if ((address & cart.hw.mask[i]) == cart.hw.addr[i])
    {
      return (cart.hw.regs[i] << 8);
    }
  }
  return m68k_read_bus_16(address);
}

static void default_regs_w(uint32 address, uint32 data)
{
  int i;
  for (i=0; i<4; i++)
  {
    if ((address & cart.hw.mask[i]) == cart.hw.addr[i])
    {
      cart.hw.regs[i] = data;
      return;
    }
  }
  m68k_unused_8_w(address, data);
}

/* basic register shifting hardware (Bug's Life, Pocket Monster) */
static uint32 custom_regs_r(uint32 address)
{
  int i;
  for (i=0; i<4; i++)
  {
    if ((address & cart.hw.mask[i]) == cart.hw.addr[i])
    {
      return cart.hw.regs[i] >> 1;
    }
  }

  return m68k_read_bus_8(address);
}

/* custom register hardware (Top Fighter, Lion King III, Super Donkey Kong  99, Mulan, Pocket Monsters II, Pokemon Stadium) */
static void custom_regs_w(uint32 address, uint32 data)
{
  uint8 temp;
  
  /* ROM bankswitch */
  if ((address >> 16) > 0x6f)
  {
    mapper_32k_w(data);
    return;
  }

  /* write register */
  default_regs_w(address, data);

  /* bitswapping */
  temp = cart.hw.regs[0];
  switch (cart.hw.regs[1] & 3)
  {
    case 0:
      cart.hw.regs[2] = (temp << 1);
      break;

    case 1:
      cart.hw.regs[2] = (temp >> 1);
      return;

    case 2:
      cart.hw.regs[2] = ((temp >> 4) | ((temp & 0x0F) << 4));
      return;

    default:
      cart.hw.regs[2] = (((temp >> 7) & 0x01) | ((temp >> 5) & 0x02) |
                         ((temp >> 3) & 0x04) | ((temp >> 1) & 0x08) |
                         ((temp << 1) & 0x10) | ((temp << 3) & 0x20) |
                         ((temp << 5) & 0x40) | ((temp << 7) & 0x80));
      return;
  }
}

/* alternate custom register hardware (Chinese Fighters III) */
static void custom_alt_regs_w(uint32 address, uint32 data)
{
  /* ROM bankswitch */
  if ((address >> 16) > 0x5f)
  {
    mapper_64k_w(data);
    return;
  }

  /* write regs */
  default_regs_w(address, data);
}


/* "Tekken 3 Special" custom register hardware */
static uint32 tekken_regs_r(uint32 address)
{
  /* data output */
  if ((address & 0x0e) == 0x02)
  {
    /* maybe depends on mode bits ? */
    return (cart.hw.regs[0] - 1);
  }

  return m68k_read_bus_16(address);
}

static void tekken_regs_w(uint32 address, uint32 data)
{
  switch (address & 0x0e)
  {
    case 0x00:
    {
      /* data output reset ? (game writes $FF before & after protection check) */
      cart.hw.regs[0]= 0x00;
      break;
    }
  
    case 0x02:
    {
      /* read only ? */
      break;
    }
  
    case 0x0c:
    {
      /* data output mode bit 0 ? (game writes $01) */
      break;
    }
  
    case 0x0e:
    {
      /* data output mode bit 1 ? (never written by game) */
      break;
    }
  
    default:
    {
      /* data input (only connected to D0 ?)*/
      if (data & 1)
      {
        /* 4-bit hardware register ($400004 corresponds to bit0, $400006 to bit1, etc) */
        cart.hw.regs[0] |= 1 << (((address - 0x04) >> 1) & 3);
      }
      break;
    }
  }
}

/* "Top Shooter" arcade board hardware */
static uint32 topshooter_r(uint32 address)
{
  if (address < 0x202000)
  {
    uint8 temp = 0xff;

    switch (address & 0xff)
    {
      case 0x43:
      {
        if (input.pad[0] & INPUT_A)     temp &= ~0x80; /* Shoot */
        if (input.pad[0] & INPUT_B)     temp &= ~0x10; /* Bet */
        if (input.pad[0] & INPUT_START) temp &= ~0x20; /* Start */
        break;
      }

      case 0x45:  /* ??? (DOWN) & Service Mode (UP) */
      {
        if (input.pad[0] & INPUT_UP)    temp &= ~0x08; /* Service Mode */
        if (input.pad[0] & INPUT_DOWN)  temp &= ~0x10; /* ???, used in service menu to select next option */
        break;
      }

      case 0x47:
      {
        if (input.pad[0] & INPUT_RIGHT) temp &= ~0x03; /* Insert 10 coins */
        break;
      }

      case 0x49:
      {
        if (input.pad[0] & INPUT_LEFT)  temp &= ~0x03; /* Clear coins */
        if (input.pad[0] & INPUT_C)     temp &= ~0x01; /* Insert XXX coins */
        break;
      }

      case 0x51:
      {
        temp = 0xA5;
        break;
      }

      default:
      {
        temp = m68k_read_bus_8(address);
        break;
      }
    }
    return temp;
  }

  return READ_BYTE(sram.sram , address & 0xffff);
}

static void topshooter_w(uint32 address, uint32 data)
{
  if (address >= 0x202000)
  {
    WRITE_BYTE(sram.sram , address & 0xffff, data);
    return;
  }

  m68k_unused_8_w(address, data);
}


/* Sega Channel hardware (not emulated) */
/* 

$A13004: BUSY ? ? ? ? ? ? ? ? ? ? ? ? ? ? ? 

Unused read16 00A13004 (00005B54)
Unused read16 00A13004 (00005B70)
Unused read16 00A13006 (00005B7C)

Unused read16 00A13004 (00005BC4)
Unused read16 00A13004 (00005BDA)

Unused write16 00A13032 = 0004 (00005706)
Unused write16 00A130F0 = 0000 (0000570E)

Unused write16 00A130F0 = 0000 (0000463E)
Unused write16 00A130F2 = 0001 (00004646)
Unused write16 00A130F4 = 0002 (0000464E)
Unused write16 00A130F6 = 0003 (00004656)
Unused write16 00A130F8 = 0004 (0000465E)
Unused write16 00A130FA = 0005 (00004666)

Unused write16 00A13032 = 0004 (00005706)
Unused write16 00A13032 = 0104 (0000579E)

Unused write16 00380000 = ACDC (00005718)
Unused write16 00380002 = 0000 (00005722)
Unused read16 00380000 (0000572C)
Unused write16 00A13032 = 0104 (0000579E)
Unused write16 00300000 = ACDC (000057B2)
Unused write16 00380000 = 0000 (000057BC)
Unused read16 00300000 (000057C6)

static uint32 sega_channel_r(uint32 address)
{
  return m68k_read_bus_16(address);;
}

static void sega_channel_w(uint32 address, uint32 data)
{
  m68k_unused_16_w(address, data);
}
*/
