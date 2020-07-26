/******************************************************************************/
/* Mednafen Fast SNES Emulation Module                                        */
/******************************************************************************/
/* cx4.cpp:
**  Copyright (C) 2019 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

/*
 Take any information derived from this CX4 emulation code with a large grain of
 KCN, as it has guesswork and performance compromises with only MMX2 and
 MMX3 in mind.
*/

#include "common.h"
#include "cx4.h"

namespace MDFN_IEN_SNES_FAUST
{

/*
 static unsigned tab[0x400];

 for(unsigned i = 0; i < 0x100; i++)
 {
  tab[0x000 + i] = i ? (0x800000 / i) : 0xFFFFFF;
  tab[0x100 + i] = 0x100000 * sqrt(i);
 }

 for(unsigned i = 0; i < 0x80; i++)
 {
  tab[0x200 + i] = 0x1000000 * sin(M_PI * 2 * i / (0x80 * 4));
  tab[0x280 + i] = 0x1000000 * asin((double)i / 0x80) / M_PI;
  tab[0x300 + i] = floor(0.001 + 0x10000 * tan(M_PI * 2 * i / (0x80 * 4)));
  tab[0x380 + i] = std::min<unsigned>(0xFFFFFF, 0x1000000 * cos(M_PI * 2 * i / (0x80 * 4)));
 }

 for(unsigned i = 0; i < 0x400; i++)
 {
  printf(" 0x%06x,", tab[i]);
  if((i & 0x7) == 0x7)
   printf("\n");
 }
*/
static const uint32 DataROM[0x400] =
{
 0xffffff, 0x800000, 0x400000, 0x2aaaaa, 0x200000, 0x199999, 0x155555, 0x124924,
 0x100000, 0x0e38e3, 0x0ccccc, 0x0ba2e8, 0x0aaaaa, 0x09d89d, 0x092492, 0x088888,
 0x080000, 0x078787, 0x071c71, 0x06bca1, 0x066666, 0x061861, 0x05d174, 0x0590b2,
 0x055555, 0x051eb8, 0x04ec4e, 0x04bda1, 0x049249, 0x0469ee, 0x044444, 0x042108,
 0x040000, 0x03e0f8, 0x03c3c3, 0x03a83a, 0x038e38, 0x03759f, 0x035e50, 0x034834,
 0x033333, 0x031f38, 0x030c30, 0x02fa0b, 0x02e8ba, 0x02d82d, 0x02c859, 0x02b931,
 0x02aaaa, 0x029cbc, 0x028f5c, 0x028282, 0x027627, 0x026a43, 0x025ed0, 0x0253c8,
 0x024924, 0x023ee0, 0x0234f7, 0x022b63, 0x022222, 0x02192e, 0x021084, 0x020820,
 0x020000, 0x01f81f, 0x01f07c, 0x01e913, 0x01e1e1, 0x01dae6, 0x01d41d, 0x01cd85,
 0x01c71c, 0x01c0e0, 0x01bacf, 0x01b4e8, 0x01af28, 0x01a98e, 0x01a41a, 0x019ec8,
 0x019999, 0x01948b, 0x018f9c, 0x018acb, 0x018618, 0x018181, 0x017d05, 0x0178a4,
 0x01745d, 0x01702e, 0x016c16, 0x016816, 0x01642c, 0x016058, 0x015c98, 0x0158ed,
 0x015555, 0x0151d0, 0x014e5e, 0x014afd, 0x0147ae, 0x01446f, 0x014141, 0x013e22,
 0x013b13, 0x013813, 0x013521, 0x01323e, 0x012f68, 0x012c9f, 0x0129e4, 0x012735,
 0x012492, 0x0121fb, 0x011f70, 0x011cf0, 0x011a7b, 0x011811, 0x0115b1, 0x01135c,
 0x011111, 0x010ecf, 0x010c97, 0x010a68, 0x010842, 0x010624, 0x010410, 0x010204,
 0x010000, 0x00fe03, 0x00fc0f, 0x00fa23, 0x00f83e, 0x00f660, 0x00f489, 0x00f2b9,
 0x00f0f0, 0x00ef2e, 0x00ed73, 0x00ebbd, 0x00ea0e, 0x00e865, 0x00e6c2, 0x00e525,
 0x00e38e, 0x00e1fc, 0x00e070, 0x00dee9, 0x00dd67, 0x00dbeb, 0x00da74, 0x00d901,
 0x00d794, 0x00d62b, 0x00d4c7, 0x00d368, 0x00d20d, 0x00d0b6, 0x00cf64, 0x00ce16,
 0x00cccc, 0x00cb87, 0x00ca45, 0x00c907, 0x00c7ce, 0x00c698, 0x00c565, 0x00c437,
 0x00c30c, 0x00c1e4, 0x00c0c0, 0x00bfa0, 0x00be82, 0x00bd69, 0x00bc52, 0x00bb3e,
 0x00ba2e, 0x00b921, 0x00b817, 0x00b70f, 0x00b60b, 0x00b509, 0x00b40b, 0x00b30f,
 0x00b216, 0x00b11f, 0x00b02c, 0x00af3a, 0x00ae4c, 0x00ad60, 0x00ac76, 0x00ab8f,
 0x00aaaa, 0x00a9c8, 0x00a8e8, 0x00a80a, 0x00a72f, 0x00a655, 0x00a57e, 0x00a4a9,
 0x00a3d7, 0x00a306, 0x00a237, 0x00a16b, 0x00a0a0, 0x009fd8, 0x009f11, 0x009e4c,
 0x009d89, 0x009cc8, 0x009c09, 0x009b4c, 0x009a90, 0x0099d7, 0x00991f, 0x009868,
 0x0097b4, 0x009701, 0x00964f, 0x0095a0, 0x0094f2, 0x009445, 0x00939a, 0x0092f1,
 0x009249, 0x0091a2, 0x0090fd, 0x00905a, 0x008fb8, 0x008f17, 0x008e78, 0x008dda,
 0x008d3d, 0x008ca2, 0x008c08, 0x008b70, 0x008ad8, 0x008a42, 0x0089ae, 0x00891a,
 0x008888, 0x0087f7, 0x008767, 0x0086d9, 0x00864b, 0x0085bf, 0x008534, 0x0084a9,
 0x008421, 0x008399, 0x008312, 0x00828c, 0x008208, 0x008184, 0x008102, 0x008080,
 0x000000, 0x100000, 0x16a09e, 0x1bb67a, 0x200000, 0x23c6ef, 0x27311c, 0x2a54ff,
 0x2d413c, 0x300000, 0x3298b0, 0x3510e5, 0x376cf5, 0x39b056, 0x3bddd4, 0x3df7bd,
 0x400000, 0x41f83d, 0x43e1db, 0x45be0c, 0x478dde, 0x49523a, 0x4b0bf1, 0x4cbbb9,
 0x4e6238, 0x500000, 0x519595, 0x532370, 0x54a9fe, 0x5629a2, 0x57a2b7, 0x591590,
 0x5a8279, 0x5be9ba, 0x5d4b94, 0x5ea843, 0x600000, 0x6152fe, 0x62a170, 0x63eb83,
 0x653160, 0x667332, 0x67b11d, 0x68eb44, 0x6a21ca, 0x6b54cd, 0x6c846c, 0x6db0c2,
 0x6ed9eb, 0x700000, 0x712318, 0x72434a, 0x7360ad, 0x747b54, 0x759354, 0x76a8bf,
 0x77bba8, 0x78cc1f, 0x79da34, 0x7ae5f9, 0x7bef7a, 0x7cf6c8, 0x7dfbef, 0x7efefd,
 0x800000, 0x80ff01, 0x81fc0f, 0x82f734, 0x83f07b, 0x84e7ee, 0x85dd98, 0x86d182,
 0x87c3b6, 0x88b43d, 0x89a31f, 0x8a9066, 0x8b7c19, 0x8c6641, 0x8d4ee4, 0x8e360b,
 0x8f1bbc, 0x900000, 0x90e2db, 0x91c456, 0x92a475, 0x938341, 0x9460bd, 0x953cf1,
 0x9617e2, 0x96f196, 0x97ca11, 0x98a159, 0x997773, 0x9a4c64, 0x9b2031, 0x9bf2de,
 0x9cc470, 0x9d94eb, 0x9e6454, 0x9f32af, 0xa00000, 0xa0cc4a, 0xa19792, 0xa261dc,
 0xa32b2a, 0xa3f382, 0xa4bae6, 0xa5815a, 0xa646e1, 0xa70b7e, 0xa7cf35, 0xa89209,
 0xa953fd, 0xaa1513, 0xaad550, 0xab94b4, 0xac5345, 0xad1103, 0xadcdf2, 0xae8a15,
 0xaf456e, 0xb00000, 0xb0b9cc, 0xb172d6, 0xb22b20, 0xb2e2ac, 0xb3997c, 0xb44f93,
 0xb504f3, 0xb5b99d, 0xb66d95, 0xb720dc, 0xb7d375, 0xb88560, 0xb936a0, 0xb9e738,
 0xba9728, 0xbb4673, 0xbbf51a, 0xbca320, 0xbd5086, 0xbdfd4e, 0xbea979, 0xbf5509,
 0xc00000, 0xc0aa5f, 0xc15428, 0xc1fd5c, 0xc2a5fd, 0xc34e0d, 0xc3f58c, 0xc49c7d,
 0xc542e1, 0xc5e8b8, 0xc68e05, 0xc732c9, 0xc7d706, 0xc87abb, 0xc91deb, 0xc9c098,
 0xca62c1, 0xcb0469, 0xcba591, 0xcc463a, 0xcce664, 0xcd8612, 0xce2544, 0xcec3fc,
 0xcf623a, 0xd00000, 0xd09d4e, 0xd13a26, 0xd1d689, 0xd27277, 0xd30df3, 0xd3a8fc,
 0xd44394, 0xd4ddbc, 0xd57774, 0xd610be, 0xd6a99b, 0xd7420b, 0xd7da0f, 0xd871a9,
 0xd908d8, 0xd99f9f, 0xda35fe, 0xdacbf5, 0xdb6185, 0xdbf6b0, 0xdc8b76, 0xdd1fd8,
 0xddb3d7, 0xde4773, 0xdedaad, 0xdf6d86, 0xe00000, 0xe09219, 0xe123d4, 0xe1b530,
 0xe24630, 0xe2d6d2, 0xe36719, 0xe3f704, 0xe48694, 0xe515cb, 0xe5a4a8, 0xe6332d,
 0xe6c15a, 0xe74f2f, 0xe7dcad, 0xe869d6, 0xe8f6a9, 0xe98326, 0xea0f50, 0xea9b26,
 0xeb26a8, 0xebb1d9, 0xec3cb7, 0xecc743, 0xed517f, 0xeddb6a, 0xee6506, 0xeeee52,
 0xef7750, 0xf00000, 0xf08861, 0xf11076, 0xf1983e, 0xf21fba, 0xf2a6ea, 0xf32dcf,
 0xf3b469, 0xf43ab9, 0xf4c0c0, 0xf5467d, 0xf5cbf2, 0xf6511e, 0xf6d602, 0xf75a9f,
 0xf7def5, 0xf86305, 0xf8e6ce, 0xf96a52, 0xf9ed90, 0xfa708a, 0xfaf33f, 0xfb75b1,
 0xfbf7df, 0xfc79ca, 0xfcfb72, 0xfd7cd8, 0xfdfdfb, 0xfe7ede, 0xfeff7f, 0xff7fdf,
 0x000000, 0x03243a, 0x064855, 0x096c32, 0x0c8fb2, 0x0fb2b7, 0x12d520, 0x15f6d0,
 0x1917a6, 0x1c3785, 0x1f564e, 0x2273e1, 0x259020, 0x28aaed, 0x2bc428, 0x2edbb3,
 0x31f170, 0x350540, 0x381704, 0x3b269f, 0x3e33f2, 0x413ee0, 0x444749, 0x474d10,
 0x4a5018, 0x4d5043, 0x504d72, 0x534789, 0x563e69, 0x5931f7, 0x5c2214, 0x5f0ea4,
 0x61f78a, 0x64dca9, 0x67bde5, 0x6a9b20, 0x6d7440, 0x704927, 0x7319ba, 0x75e5dd,
 0x78ad74, 0x7b7065, 0x7e2e93, 0x80e7e4, 0x839c3c, 0x864b82, 0x88f59a, 0x8b9a6b,
 0x8e39d9, 0x90d3cc, 0x93682a, 0x95f6d9, 0x987fbf, 0x9b02c5, 0x9d7fd1, 0x9ff6ca,
 0xa26799, 0xa4d224, 0xa73655, 0xa99414, 0xabeb49, 0xae3bdd, 0xb085ba, 0xb2c8c9,
 0xb504f3, 0xb73a22, 0xb96841, 0xbb8f3a, 0xbdaef9, 0xbfc767, 0xc1d870, 0xc3e200,
 0xc5e403, 0xc7de65, 0xc9d112, 0xcbbbf7, 0xcd9f02, 0xcf7a1f, 0xd14d3d, 0xd31848,
 0xd4db31, 0xd695e4, 0xd84852, 0xd9f269, 0xdb941a, 0xdd2d53, 0xdebe05, 0xe04621,
 0xe1c597, 0xe33c59, 0xe4aa59, 0xe60f87, 0xe76bd7, 0xe8bf3b, 0xea09a6, 0xeb4b0b,
 0xec835e, 0xedb293, 0xeed89d, 0xeff573, 0xf10908, 0xf21352, 0xf31447, 0xf40bdd,
 0xf4fa0a, 0xf5dec6, 0xf6ba07, 0xf78bc5, 0xf853f7, 0xf91297, 0xf9c79d, 0xfa7301,
 0xfb14be, 0xfbaccd, 0xfc3b27, 0xfcbfc9, 0xfd3aab, 0xfdabcb, 0xfe1323, 0xfe70af,
 0xfec46d, 0xff0e57, 0xff4e6d, 0xff84ab, 0xffb10f, 0xffd397, 0xffec43, 0xfffb10,
 0x000000, 0x00a2f9, 0x0145f6, 0x01e8f8, 0x028c01, 0x032f14, 0x03d234, 0x047564,
 0x0518a5, 0x05bbfb, 0x065f68, 0x0702ef, 0x07a692, 0x084a54, 0x08ee38, 0x099240,
 0x0a366e, 0x0adac7, 0x0b7f4c, 0x0c2401, 0x0cc8e7, 0x0d6e02, 0x0e1355, 0x0eb8e3,
 0x0f5eae, 0x1004b9, 0x10ab08, 0x11519e, 0x11f87d, 0x129fa9, 0x134725, 0x13eef4,
 0x149719, 0x153f99, 0x15e875, 0x1691b2, 0x173b53, 0x17e55c, 0x188fd1, 0x193ab4,
 0x19e60a, 0x1a91d8, 0x1b3e20, 0x1beae7, 0x1c9831, 0x1d4602, 0x1df45f, 0x1ea34c,
 0x1f52ce, 0x2002ea, 0x20b3a3, 0x216500, 0x221705, 0x22c9b8, 0x237d1e, 0x24313c,
 0x24e618, 0x259bb9, 0x265224, 0x27095f, 0x27c171, 0x287a61, 0x293436, 0x29eef6,
 0x2aaaaa, 0x2b6759, 0x2c250a, 0x2ce3c7, 0x2da398, 0x2e6485, 0x2f2699, 0x2fe9dc,
 0x30ae59, 0x31741b, 0x323b2c, 0x330398, 0x33cd6b, 0x3498b1, 0x356578, 0x3633ce,
 0x3703c1, 0x37d560, 0x38a8bb, 0x397de4, 0x3a54ec, 0x3b2de6, 0x3c08e6, 0x3ce601,
 0x3dc54d, 0x3ea6e3, 0x3f8adc, 0x407152, 0x415a62, 0x42462c, 0x4334d0, 0x442671,
 0x451b37, 0x46134a, 0x470ed6, 0x480e0c, 0x491120, 0x4a184c, 0x4b23cd, 0x4c33ea,
 0x4d48ec, 0x4e6327, 0x4f82f9, 0x50a8c9, 0x51d50a, 0x53083f, 0x5442fc, 0x5585ea,
 0x56d1cc, 0x582782, 0x598815, 0x5af4bc, 0x5c6eed, 0x5df86c, 0x5f9369, 0x6142a3,
 0x6309a5, 0x64ed1e, 0x66f381, 0x692617, 0x6b9322, 0x6e52a5, 0x71937c, 0x75ceb4,
 0x000000, 0x000324, 0x000648, 0x00096d, 0x000c93, 0x000fba, 0x0012e2, 0x00160b,
 0x001936, 0x001c63, 0x001f93, 0x0022c4, 0x0025f9, 0x002930, 0x002c6b, 0x002fa9,
 0x0032eb, 0x003632, 0x00397c, 0x003ccb, 0x00401f, 0x004379, 0x0046d8, 0x004a3d,
 0x004da8, 0x005119, 0x005492, 0x005811, 0x005b99, 0x005f28, 0x0062c0, 0x006660,
 0x006a09, 0x006dbc, 0x00717a, 0x007541, 0x007914, 0x007cf2, 0x0080dc, 0x0084d2,
 0x0088d5, 0x008ce6, 0x009105, 0x009533, 0x009970, 0x009dbe, 0x00a21c, 0x00a68b,
 0x00ab0d, 0x00afa2, 0x00b44b, 0x00b909, 0x00bddc, 0x00c2c6, 0x00c7c8, 0x00cce3,
 0x00d218, 0x00d767, 0x00dcd3, 0x00e25d, 0x00e806, 0x00edcf, 0x00f3bb, 0x00f9ca,
 0x010000, 0x01065c, 0x010ce2, 0x011394, 0x011a73, 0x012183, 0x0128c6, 0x01303e,
 0x0137ef, 0x013fdc, 0x014808, 0x015077, 0x01592d, 0x01622d, 0x016b7d, 0x017522,
 0x017f21, 0x018980, 0x019444, 0x019f76, 0x01ab1c, 0x01b73e, 0x01c3e7, 0x01d11f,
 0x01def1, 0x01ed69, 0x01fc95, 0x020c83, 0x021d44, 0x022ee9, 0x024186, 0x025533,
 0x026a09, 0x028025, 0x0297a7, 0x02b0b5, 0x02cb78, 0x02e823, 0x0306ec, 0x032815,
 0x034beb, 0x0372c6, 0x039d10, 0x03cb47, 0x03fe02, 0x0435f7, 0x047405, 0x04b93f,
 0x0506ff, 0x055ef9, 0x05c35d, 0x063709, 0x06bdcf, 0x075ce6, 0x081b97, 0x09046d,
 0x0a2736, 0x0b9cc6, 0x0d8e81, 0x1046e9, 0x145aff, 0x1b2671, 0x28bc48, 0x517bb5,
 0xffffff, 0xfffb10, 0xffec43, 0xffd397, 0xffb10f, 0xff84ab, 0xff4e6d, 0xff0e57,
 0xfec46d, 0xfe70af, 0xfe1323, 0xfdabcb, 0xfd3aab, 0xfcbfc9, 0xfc3b27, 0xfbaccd,
 0xfb14be, 0xfa7301, 0xf9c79d, 0xf91297, 0xf853f7, 0xf78bc5, 0xf6ba07, 0xf5dec6,
 0xf4fa0a, 0xf40bdd, 0xf31447, 0xf21352, 0xf10908, 0xeff573, 0xeed89d, 0xedb293,
 0xec835e, 0xeb4b0b, 0xea09a6, 0xe8bf3b, 0xe76bd7, 0xe60f87, 0xe4aa59, 0xe33c59,
 0xe1c597, 0xe04621, 0xdebe05, 0xdd2d53, 0xdb941a, 0xd9f269, 0xd84852, 0xd695e4,
 0xd4db31, 0xd31848, 0xd14d3d, 0xcf7a1f, 0xcd9f02, 0xcbbbf7, 0xc9d112, 0xc7de65,
 0xc5e403, 0xc3e200, 0xc1d870, 0xbfc767, 0xbdaef9, 0xbb8f3a, 0xb96841, 0xb73a22,
 0xb504f3, 0xb2c8c9, 0xb085ba, 0xae3bdd, 0xabeb49, 0xa99414, 0xa73655, 0xa4d224,
 0xa26799, 0x9ff6ca, 0x9d7fd1, 0x9b02c5, 0x987fbf, 0x95f6d9, 0x93682a, 0x90d3cc,
 0x8e39d9, 0x8b9a6b, 0x88f59a, 0x864b82, 0x839c3c, 0x80e7e4, 0x7e2e93, 0x7b7065,
 0x78ad74, 0x75e5dd, 0x7319ba, 0x704927, 0x6d7440, 0x6a9b20, 0x67bde5, 0x64dca9,
 0x61f78a, 0x5f0ea4, 0x5c2214, 0x5931f7, 0x563e69, 0x534789, 0x504d72, 0x4d5043,
 0x4a5018, 0x474d10, 0x444749, 0x413ee0, 0x3e33f2, 0x3b269f, 0x381704, 0x350540,
 0x31f170, 0x2edbb3, 0x2bc428, 0x28aaed, 0x259020, 0x2273e1, 0x1f564e, 0x1c3785,
 0x1917a6, 0x15f6d0, 0x12d520, 0x0fb2b7, 0x0c8fb2, 0x096c32, 0x064855, 0x03243a,
};
static uint8 DataRAM[0x400 * 3];

enum : size_t
{
 RegsIndex_A = 0x00,
 RegsIndex_MACH,
 RegsIndex_MACL,
 RegsIndex_MBR,
 RegsIndex_ROMB,
 RegsIndex_RAMB,
 RegsIndex_MAR,
 RegsIndex_DPR,
 RegsIndex_IP,
 RegsIndex_P,
 RegsIndex_IR0,
 RegsIndex_IR15 = RegsIndex_IR0 + 0xF,
 RegsIndex_R0,
 RegsIndex_R15 = RegsIndex_R0 + 0xF,
 //
 RegsIndex_NextIP,
 //
 RegsIndex_WriteDummy,
 //
 RegsIndex__Count
};
static uint32 Regs[RegsIndex__Count];
static uint8 RegsRMap[0x80];
static uint8 RegsWMap[0x80];
static uint32 RegsWMask[0x80];

static uint32& Accum = Regs[RegsIndex_A];
static uint32& MACL = Regs[RegsIndex_MACL];
static uint32& MACH = Regs[RegsIndex_MACH];
static uint32& MBR = Regs[RegsIndex_MBR];
static uint32& IP = Regs[RegsIndex_IP];
static uint32& NextIP = Regs[RegsIndex_NextIP];
static uint32& ROMB = Regs[RegsIndex_ROMB];
static uint32& RAMB = Regs[RegsIndex_RAMB];
static uint32& MAR = Regs[RegsIndex_MAR];
static uint32& DPR = Regs[RegsIndex_DPR];
static uint32& P = Regs[RegsIndex_P];

//static uint32 Accum;
static bool Flag_Z, Flag_N, Flag_C, Flag_V;

static uint32 Stack[8];
static uint32 SP;

static uint32 NextInstr;
static struct Cache_S
{
 uint16 Data[256 + 2];
 uint32 Tag;
 bool Locked;
} Cache[2];
static Cache_S* Cache_Active;
static uint32 ProgROM_Base;

static uint32 DMASource;
static uint16 DMALength;
static uint32 DMADest;

static uint32 Status;
static bool IRQOut;
static uint8 WSControl;
static uint8 IRQControl;
static uint16 VectorRegs[0x10];

static uint32 last_master_timestamp;
static unsigned run_count_mod;
static unsigned clock_multiplier;
static int32 cycle_counter;

static INLINE uint32 ReadReg(unsigned o)
{
 return Regs[RegsRMap[o & 0x7F]];
}

static INLINE void WriteReg(unsigned o, uint32 v)
{
 Regs[RegsWMap[o & 0x7F]] = v & RegsWMask[o];
}

static void LoadCache(unsigned EffP)
{
 SNES_DBG("[CX4] LoadCache %u: ProgROM_Base=0x%06x, P=0x%04x\n", (unsigned)(Cache_Active - Cache), ProgROM_Base, EffP);

 for(unsigned i = 0; i < 256; i++)
 {
  uint32 rom_addr;
  uint32 tmp;

  rom_addr = ProgROM_Base + (((EffP << 8) + i) << 1);
  //assert(rom_addr & 0x8000);
  rom_addr = (rom_addr & 0x7FFF) + ((rom_addr >> 1) & 0x7F8000);

  tmp = Cart.ROM[(rom_addr + 0) & (sizeof(Cart.ROM) - 1)];
  tmp |= Cart.ROM[(rom_addr + 1) & (sizeof(Cart.ROM) - 1)] << 8;

  Cache_Active->Data[i] = tmp;

  cycle_counter -= (1 + (WSControl >> 4)) << 1;
 }
 Cache_Active->Tag = EffP;
}

static void CheckCache(const unsigned EffP)
{
 if(Cache_Active->Tag == EffP)
  return;

 Cache_Active = &Cache[!(Cache_Active - &Cache[0])];
 if(Cache_Active->Tag == EffP)
  return;

 if(Cache_Active->Locked)
 {
  SNES_DBG("[CX4] Wanted to load to cache page %u, but it's locked!\n", (unsigned)(Cache_Active - Cache));
  Cache_Active = &Cache[!(Cache_Active - &Cache[0])];
 }

 if(Cache_Active->Locked)
 {
  SNES_DBG("[CX4] Unable to load cache, both pages locked!\n");
  Status &= ~0x40;
  if(!(Status & 0x100))
   cycle_counter = std::min<int32>(cycle_counter, 0);
  return;
 }

 LoadCache(EffP);
}

static const unsigned preshift_tab[4] = { 0, 1, 8, 16 };


template<unsigned opcode>
static INLINE void Instr_Branch(uint32 instr)
{
 const bool bsub = opcode & 0x20;
 bool cond;

 static_assert(((opcode >> 2) & 0x7) >= 0x2 && ((opcode >> 2) & 0x7) <= 0x6, "bad opcode");

 switch((opcode >> 2) & 0x7)
 {
  case 0x2:
	cond = true;
	break;

  case 0x3:
	cond = Flag_Z;
	break;

  case 0x4:
	cond = Flag_C;
	break;

  case 0x5:
	cond = Flag_N;
	break;

  case 0x6:
	cond = Flag_V;
	break;
 }

 if(cond)
 {
  if(bsub)
  {
   SP = (SP + 1) & 0x7;
   Stack[SP] = (Cache_Active->Tag << 8) | (uint8)IP;
  }

  cycle_counter--;
  NextIP = (instr & 0xFF);
  NextInstr = 0;
  if(opcode & 0x2)
   CheckCache(P);
 }
}

template<unsigned opcode>
static INLINE void Instr_SKIP(uint32 instr)
{
 bool cond;

 switch(opcode & 0x3)
 {
  case 0x0:
	cond = Flag_V;
	break;

  case 0x1:
	cond = Flag_C;
	break;

  case 0x2:
	cond = Flag_Z;
	break;

  case 0x3:
	cond = Flag_N;
	break;
 }

 cond ^= instr & 1;

 if(!cond)
  NextInstr = 0;
}

template<unsigned opcode>
static INLINE void Instr_WRRAM(uint32 instr)
{
 const size_t w = opcode & 0x3;
 const unsigned shift = w << 3;
 const size_t index = ((opcode & 0x4) ? (DPR + (instr & 0xFF)) : Accum) & 0xFFF;

 if(!(opcode & 0x4) && (instr & 0xFF))
  SNES_DBG("[CX4] WRRAM with non-zero lower instruction byte: 0x%04x\n", instr);

 if(index < sizeof(DataRAM))
  DataRAM[index] = RAMB >> shift;
}

template<unsigned opcode>
static INLINE void Instr_RDRAM(uint32 instr)
{
 const size_t w = opcode & 0x3;
 const unsigned shift = w << 3;
 const size_t index = ((opcode & 0x4) ? (DPR + (instr & 0xFF)) : Accum) & 0xFFF;

 if(!(opcode & 0x4) && (instr & 0xFF))
  SNES_DBG("[CX4] RDRAM with non-zero lower instruction byte: 0x%04x\n", instr);

 if(index < sizeof(DataRAM))
  RAMB = (RAMB & ~(0xFF << shift)) | (DataRAM[index] << shift);
}

template<unsigned opcode>
static INLINE void Instr_RDROM(uint32 instr)
{
 const size_t index = (opcode & 0x4) ? (instr & 0x3FF) : (Accum & 0x3FF);

 if(!(opcode & 0x4) && (instr & 0xFF))
  SNES_DBG("[CX4] RDROM with non-zero lower instruction byte: 0x%04x\n", instr);

 ROMB = DataROM[index];
}

template<unsigned opcode>
static INLINE void Instr_MUL(uint32 instr)
{
 const uint32 arg = (opcode & 0x4) ? (instr & 0xFF) : Regs[RegsRMap[instr & 0x7F]];
 uint64 result;

 result = (int64)sign_x_to_s32(24, Accum) * sign_x_to_s32(24, arg);

 //printf("MUL 0x%06x * 0x%06x -> 0x%16llx\n", Accum, arg, (unsigned long long)result);

 MACH = (result >> 24) & 0xFFFFFF;
 MACL = result & 0xFFFFFF;
}

template<unsigned opcode>
static INLINE void Instr_BitOps(uint32 instr)
{
 const unsigned ss = opcode & 0x3;
 uint32 arg = (opcode & 0x4) ? (instr & 0xFF) : Regs[RegsRMap[instr & 0x7F]];
 uint32 tmp = (Accum << preshift_tab[ss]) & 0xFFFFFF;
 const unsigned subop = ((opcode - 0xA0) >> 3) & 0x07;
 //

 if(subop & 0x4)
 {
  if(ss != 0)
   SNES_DBG("[CX4] Shift instruction with SS!=0: 0x%04x\n", instr);

  arg &= 0x1F;

  if(arg >= 24)
   SNES_DBG("[CX4] Instr 0x%04x, large shift=%u\n", instr, arg);

  if(arg > 24)
   arg = 0;
 }

 switch(subop)
 {
  case 0x0: tmp ^= ~arg; break; // XNOR
  case 0x1: tmp ^= arg;	break;  // XOR
  case 0x2: tmp &= arg;	break;  // AND
  case 0x3: tmp |= arg; break;  // OR

  case 0x4: tmp >>= arg; break; 				// SHLR
  case 0x5: tmp = sign_x_to_s32(24, tmp) >> arg; break; 	// SHAR
  case 0x6: tmp = (tmp >> arg) | (tmp << (24 - arg)); break;	// ROTR
  case 0x7: tmp <<= arg; break; 				// SHLL
 }
 //
 Accum = tmp & 0xFFFFFF;
 Flag_N = (bool)(Accum & 0x800000);
 Flag_Z = !Accum;
}


template<unsigned opcode>
static INLINE void Instr_CMP(uint32 instr)
{
 const unsigned ss = opcode & 0x3;
 uint32 a = (Accum << preshift_tab[ss]) & 0xFFFFFF;
 uint32 b = (opcode & 0x4) ? (instr & 0xFF) : Regs[RegsRMap[instr & 0x7F]];
 uint32 tmp;

 switch(((opcode - 0x48) >> 3) & 0x1)
 {
  case 0: tmp = b - a;
	  Flag_V = (((a ^ b) & (b ^ tmp)) >> 23) & 1;
	  Flag_C = (~tmp >> 24) & 1;
	  break;

  case 1: tmp = a - b;
	  Flag_V = (((a ^ b) & (a ^ tmp)) >> 23) & 1;
	  Flag_C = (~tmp >> 24) & 1;
	  break;
 }
 //
 Flag_N = (bool)(tmp & 0x800000);
 Flag_Z = !(tmp & 0xFFFFFF);
}

template<unsigned opcode>
static INLINE void Instr_ADDSUB(uint32 instr)
{
 const unsigned ss = opcode & 0x3;
 uint32 a = (Accum << preshift_tab[ss]) & 0xFFFFFF;
 uint32 b = (opcode & 0x4) ? (instr & 0xFF) : Regs[RegsRMap[instr & 0x7F]];
 uint32 tmp;

 switch((opcode >> 3) & 0x3)
 {
  case 0: tmp = a + b;
	  Flag_V = (((~(a ^ b)) & (a ^ tmp)) >> 23) & 1;
	  Flag_C = (tmp >> 24) & 1;
	  break;

  case 1: tmp = b - a;
	  Flag_V = (((a ^ b) & (b ^ tmp)) >> 23) & 1;
	  Flag_C = (~tmp >> 24) & 1;
	  break;

  case 2: tmp = a - b;
	  Flag_V = (((a ^ b) & (a ^ tmp)) >> 23) & 1;
	  Flag_C = (~tmp >> 24) & 1;
	  break;
 }
 //
 Accum = tmp & 0xFFFFFF;
 Flag_N = (bool)(Accum & 0x800000);
 Flag_Z = !Accum;
}

static NO_INLINE void Update(uint32 master_timestamp)
{
 {
  int32 tmp;

  tmp = ((master_timestamp - last_master_timestamp) * clock_multiplier) + run_count_mod;
  last_master_timestamp = master_timestamp;
  run_count_mod  = (uint16)tmp;
  cycle_counter += tmp >> 16;
 }

 if((Status & 0x141) != 0x40) // Not running
 {
  if(MDFN_UNLIKELY(Status & 0x100))	// DMA
  {
   while(cycle_counter > 0)
   {
    uint8 tmp;

    if(!DMALength)
    {
     Status &= ~0x100;
     break;
    }

    if(MDFN_UNLIKELY(!(DMASource & 0x8000)))
    {
     SNES_DBG("[CX4] Unhandled DMA source address: 0x%06x\n", DMASource);
     Status &= ~0x100;
     break;
    }

    {
     const unsigned bank = DMADest >> 16;
     const unsigned offs = DMADest & 0xFFFF;

     if(MDFN_UNLIKELY((offs & 0x8000) || offs < 0x6000 || offs >= 0x7C00 || (bank & 0x40)))
     {
      SNES_DBG("[CX4] Unhandled DMA dest address: 0x%06x\n", DMADest);
      Status &= ~0x100;
      break;
     }
    }

    tmp = Cart.ROM[((DMASource & 0x7FFF) | ((DMASource >> 1) & 0x7F8000)) & (sizeof(Cart.ROM) - 1)];
    cycle_counter -= 1 + (WSControl >> 4);
    {
     const size_t index = DMADest & 0xFFF;

     if(index < sizeof(DataRAM))
      DataRAM[index] = tmp;
    }

    //printf("DMA: %08x->%08x, %02x\n", DMASource, DMADest, tmp);

    DMADest = (DMADest + 1) & 0xFFFFFF;
    DMASource = (DMASource + 1) & 0xFFFFFF;
    DMALength--;
   }
  }
  else
   cycle_counter = 0;
 }

 while(cycle_counter > 0)
 {
  const uint32 instr = (uint16)NextInstr;

  //printf("IP=%d:0x%02x, Instr=0x%04x (P=0x%04x) ;;; Accum=0x%06x, Flag_Z=%d, Flag_N=%d, Flag_C=%d, Flag_V=%d --- SP=0x%02x\n", (int)Cache_Active, IP, instr, P, Accum, Flag_Z, Flag_N, Flag_C, Flag_V, SP);

  NextInstr = Cache_Active->Data[NextIP];
  IP = (uint8)NextIP;
  NextIP++;

  cycle_counter--;

  switch(instr >> 8)
  {
   default:
	SNES_DBG("[CX4] Unknown instruction: 0x%04x\n", instr);
	break;

   //
   // NOP
   //
   case 0x00:
   case 0x01:
   case 0x02:
   case 0x03:
   case 0x04:
   case 0x05:
   case 0x06:
   case 0x07:
   {
    //
   }
   break;

   //
   // Branch
   //
   case 0x08: Instr_Branch<0x08>(instr); break;
   case 0x09: Instr_Branch<0x09>(instr); break;
   case 0x0A: Instr_Branch<0x0A>(instr); break;
   case 0x0B: Instr_Branch<0x0B>(instr); break;
   case 0x0C: Instr_Branch<0x0C>(instr); break;
   case 0x0D: Instr_Branch<0x0D>(instr); break;
   case 0x0E: Instr_Branch<0x0E>(instr); break;
   case 0x0F: Instr_Branch<0x0F>(instr); break;
   case 0x10: Instr_Branch<0x10>(instr); break;
   case 0x11: Instr_Branch<0x11>(instr); break;
   case 0x12: Instr_Branch<0x12>(instr); break;
   case 0x13: Instr_Branch<0x13>(instr); break;
   case 0x14: Instr_Branch<0x14>(instr); break;
   case 0x15: Instr_Branch<0x15>(instr); break;
   case 0x16: Instr_Branch<0x16>(instr); break;
   case 0x17: Instr_Branch<0x17>(instr); break;
   case 0x18: Instr_Branch<0x18>(instr); break;
   case 0x19: Instr_Branch<0x19>(instr); break;
   case 0x1A: Instr_Branch<0x1A>(instr); break;
   case 0x1B: Instr_Branch<0x1B>(instr); break;

   case 0x1C: // TODO
	break;

   //
   // SKIP*
   //
   case 0x24: Instr_SKIP<0x24>(instr); break;
   case 0x25: Instr_SKIP<0x25>(instr); break;
   case 0x26: Instr_SKIP<0x26>(instr); break;
   case 0x27: Instr_SKIP<0x27>(instr); break;

   //
   // Branch (subroutine)
   //
   case 0x28: Instr_Branch<0x28>(instr); break;
   case 0x29: Instr_Branch<0x29>(instr); break;
   case 0x2A: Instr_Branch<0x2A>(instr); break;
   case 0x2B: Instr_Branch<0x2B>(instr); break;
   case 0x2C: Instr_Branch<0x2C>(instr); break;
   case 0x2D: Instr_Branch<0x2D>(instr); break;
   case 0x2E: Instr_Branch<0x2E>(instr); break;
   case 0x2F: Instr_Branch<0x2F>(instr); break;
   case 0x30: Instr_Branch<0x30>(instr); break;
   case 0x31: Instr_Branch<0x31>(instr); break;
   case 0x32: Instr_Branch<0x32>(instr); break;
   case 0x33: Instr_Branch<0x33>(instr); break;
   case 0x34: Instr_Branch<0x34>(instr); break;
   case 0x35: Instr_Branch<0x35>(instr); break;
   case 0x36: Instr_Branch<0x36>(instr); break;
   case 0x37: Instr_Branch<0x37>(instr); break;
   case 0x38: Instr_Branch<0x38>(instr); break;
   case 0x39: Instr_Branch<0x39>(instr); break;
   case 0x3A: Instr_Branch<0x3A>(instr); break;
   case 0x3B: Instr_Branch<0x3B>(instr); break;

   //
   // RTS
   //
   case 0x3C:
   case 0x3D:
   case 0x3E:
   case 0x3F:
   {
    const uint32 tmp = Stack[SP];
    SP = (SP - 1) & 0x7;

    NextIP = (uint8)tmp;
    NextInstr = 0;
    CheckCache(tmp >> 8);
    cycle_counter--;
   }
   break;

   //
   // MAR++?
   //
   case 0x40:
   case 0x41:
   case 0x42:
   case 0x43:
   {
    MAR = (MAR + 1) & 0xFFFFFF;
   }
   break;

   //
   // CMP
   //
   case 0x48: Instr_CMP<0x48>(instr); break;
   case 0x49: Instr_CMP<0x49>(instr); break;
   case 0x4A: Instr_CMP<0x4A>(instr); break;
   case 0x4B: Instr_CMP<0x4B>(instr); break;
   case 0x4C: Instr_CMP<0x4C>(instr); break;
   case 0x4D: Instr_CMP<0x4D>(instr); break;
   case 0x4E: Instr_CMP<0x4E>(instr); break;
   case 0x4F: Instr_CMP<0x4F>(instr); break;
   case 0x50: Instr_CMP<0x50>(instr); break;
   case 0x51: Instr_CMP<0x51>(instr); break;
   case 0x52: Instr_CMP<0x52>(instr); break;
   case 0x53: Instr_CMP<0x53>(instr); break;
   case 0x54: Instr_CMP<0x54>(instr); break;
   case 0x55: Instr_CMP<0x55>(instr); break;
   case 0x56: Instr_CMP<0x56>(instr); break;
   case 0x57: Instr_CMP<0x57>(instr); break;

   //
   // Sign extension(8 bits)
   //
   case 0x59:
   {
    Accum = (int8)Accum & 0xFFFFFF;
    Flag_N = (bool)(Accum & 0x800000);
    Flag_Z = !Accum;
   }
   break;

   //
   // Sign extension(16 bits)
   //
   case 0x5A:
   {
    Accum = (int16)Accum & 0xFFFFFF;
    Flag_N = (bool)(Accum & 0x800000);
    Flag_Z = !Accum;
   }
   break;

   //
   // MOV
   //
   case 0x60:
   {
    const unsigned r = instr & 0x7F;

    Accum = Regs[RegsRMap[r]];
   }
   break;

   //
   // MOV
   //
   case 0x61:
   {
    const unsigned r = instr & 0x7F;

    if(r == 0x2E)
    {
     // Read cart ROM
     //printf("MAR: %08x\n", MAR);
     MBR = Cart.ROM[((MAR & 0x7FFF) | ((MAR >> 1) & 0x7F8000)) & (sizeof(Cart.ROM) - 1)];
     //MBR = Cart.ROM[MAR & (sizeof(Cart.ROM) - 1)];
     // MBR_ReadyDelay = 
    }
    else if(r == 0x2F)
    {
     SNES_DBG("[CX4] Unhandled instruction: 0x%04x\n", instr);
    }
    else
     MBR = Regs[RegsRMap[r]];
   }
   break;

   //
   // MOV
   //
   case 0x62:
   {
    MAR = Regs[RegsIndex_R0 + (instr & 0xF)];
   }
   break;

   //
   // MOV
   //
   case 0x63:
   {
    P = Regs[RegsIndex_R0 + (instr & 0xF)] & 0x7FFF;
   }
   break;

   //
   // MOV
   //
   case 0x64:
   {
    Accum = instr & 0xFF;
   }
   break;

   //
   // MOV
   //
   case 0x65:
   {
    MBR = instr & 0xFF;
   }
   break;

   //
   // MOV
   //
   case 0x66:
   {
    MAR = instr & 0xFF;
   }
   break;

   //
   // MOV
   //
   case 0x67:
   {
    P = instr & 0xFF;
   }
   break;

   //
   // RDRAM
   //
   case 0x68: Instr_RDRAM<0x68>(instr); break;
   case 0x69: Instr_RDRAM<0x69>(instr); break;
   case 0x6A: Instr_RDRAM<0x6A>(instr); break;
   case 0x6C: Instr_RDRAM<0x6C>(instr); break;
   case 0x6D: Instr_RDRAM<0x6D>(instr); break;
   case 0x6E: Instr_RDRAM<0x6E>(instr); break;

   //
   // RDROM
   //
   case 0x70: Instr_RDROM<0x70>(instr); break;
   case 0x71: Instr_RDROM<0x71>(instr); break;
   case 0x72: Instr_RDROM<0x72>(instr); break;
   case 0x73: Instr_RDROM<0x73>(instr); break;
   case 0x74: Instr_RDROM<0x74>(instr); break;
   case 0x75: Instr_RDROM<0x75>(instr); break;
   case 0x76: Instr_RDROM<0x76>(instr); break;
   case 0x77: Instr_RDROM<0x77>(instr); break;


   //
   // MOV
   //
   case 0x78:
   case 0x7A:
   {
    P = (P & 0x7F00) | (Regs[RegsRMap[instr & 0x7F]] & 0xFF);
   }
   break;

   //
   // MOV
   //
   case 0x79:
   case 0x7B:
   {
    P = (P & 0xFF) | ((Regs[RegsRMap[instr & 0x7F]] & 0x7F) << 8);
   }
   break;

   //
   // MOV
   //
   case 0x7C:
   case 0x7E:
   {
    P = (P & 0x7F00) | (instr & 0xFF);
   }
   break;

   //
   // MOV
   //
   case 0x7D:
   case 0x7F:
   {
    P = (P & 0xFF) | ((instr & 0x7F) << 8);
   }
   break;

   //
   // ADD/SUBR/SUB
   //
   case 0x80: Instr_ADDSUB<0x80>(instr); break;
   case 0x81: Instr_ADDSUB<0x81>(instr); break;
   case 0x82: Instr_ADDSUB<0x82>(instr); break;
   case 0x83: Instr_ADDSUB<0x83>(instr); break;
   case 0x84: Instr_ADDSUB<0x84>(instr); break;
   case 0x85: Instr_ADDSUB<0x85>(instr); break;
   case 0x86: Instr_ADDSUB<0x86>(instr); break;
   case 0x87: Instr_ADDSUB<0x87>(instr); break;
   case 0x88: Instr_ADDSUB<0x88>(instr); break;
   case 0x89: Instr_ADDSUB<0x89>(instr); break;
   case 0x8A: Instr_ADDSUB<0x8A>(instr); break;
   case 0x8B: Instr_ADDSUB<0x8B>(instr); break;
   case 0x8C: Instr_ADDSUB<0x8C>(instr); break;
   case 0x8D: Instr_ADDSUB<0x8D>(instr); break;
   case 0x8E: Instr_ADDSUB<0x8E>(instr); break;
   case 0x8F: Instr_ADDSUB<0x8F>(instr); break;
   case 0x90: Instr_ADDSUB<0x90>(instr); break;
   case 0x91: Instr_ADDSUB<0x91>(instr); break;
   case 0x92: Instr_ADDSUB<0x92>(instr); break;
   case 0x93: Instr_ADDSUB<0x93>(instr); break;
   case 0x94: Instr_ADDSUB<0x94>(instr); break;
   case 0x95: Instr_ADDSUB<0x95>(instr); break;
   case 0x96: Instr_ADDSUB<0x96>(instr); break;
   case 0x97: Instr_ADDSUB<0x97>(instr); break;

   //
   // MUL
   //
   case 0x98: Instr_MUL<0x98>(instr); break;
   case 0x99: Instr_MUL<0x99>(instr); break;
   case 0x9A: Instr_MUL<0x9A>(instr); break;
   case 0x9B: Instr_MUL<0x9B>(instr); break;
   case 0x9C: Instr_MUL<0x9C>(instr); break;
   case 0x9D: Instr_MUL<0x9D>(instr); break;
   case 0x9E: Instr_MUL<0x9E>(instr); break;
   case 0x9F: Instr_MUL<0x9F>(instr); break;

   //
   // Bit ops
   //
   case 0xA0: Instr_BitOps<0xA0>(instr); break;
   case 0xA1: Instr_BitOps<0xA1>(instr); break;
   case 0xA2: Instr_BitOps<0xA2>(instr); break;
   case 0xA3: Instr_BitOps<0xA3>(instr); break;
   case 0xA4: Instr_BitOps<0xA4>(instr); break;
   case 0xA5: Instr_BitOps<0xA5>(instr); break;
   case 0xA6: Instr_BitOps<0xA6>(instr); break;
   case 0xA7: Instr_BitOps<0xA7>(instr); break;
   case 0xA8: Instr_BitOps<0xA8>(instr); break;
   case 0xA9: Instr_BitOps<0xA9>(instr); break;
   case 0xAA: Instr_BitOps<0xAA>(instr); break;
   case 0xAB: Instr_BitOps<0xAB>(instr); break;
   case 0xAC: Instr_BitOps<0xAC>(instr); break;
   case 0xAD: Instr_BitOps<0xAD>(instr); break;
   case 0xAE: Instr_BitOps<0xAE>(instr); break;
   case 0xAF: Instr_BitOps<0xAF>(instr); break;
   case 0xB0: Instr_BitOps<0xB0>(instr); break;
   case 0xB1: Instr_BitOps<0xB1>(instr); break;
   case 0xB2: Instr_BitOps<0xB2>(instr); break;
   case 0xB3: Instr_BitOps<0xB3>(instr); break;
   case 0xB4: Instr_BitOps<0xB4>(instr); break;
   case 0xB5: Instr_BitOps<0xB5>(instr); break;
   case 0xB6: Instr_BitOps<0xB6>(instr); break;
   case 0xB7: Instr_BitOps<0xB7>(instr); break;
   case 0xB8: Instr_BitOps<0xB8>(instr); break;
   case 0xB9: Instr_BitOps<0xB9>(instr); break;
   case 0xBA: Instr_BitOps<0xBA>(instr); break;
   case 0xBB: Instr_BitOps<0xBB>(instr); break;
   case 0xBC: Instr_BitOps<0xBC>(instr); break;
   case 0xBD: Instr_BitOps<0xBD>(instr); break;
   case 0xBE: Instr_BitOps<0xBE>(instr); break;
   case 0xBF: Instr_BitOps<0xBF>(instr); break;
   case 0xC0: Instr_BitOps<0xC0>(instr); break;
   case 0xC1: Instr_BitOps<0xC1>(instr); break;
   case 0xC2: Instr_BitOps<0xC2>(instr); break;
   case 0xC3: Instr_BitOps<0xC3>(instr); break;
   case 0xC4: Instr_BitOps<0xC4>(instr); break;
   case 0xC5: Instr_BitOps<0xC5>(instr); break;
   case 0xC6: Instr_BitOps<0xC6>(instr); break;
   case 0xC7: Instr_BitOps<0xC7>(instr); break;
   case 0xC8: Instr_BitOps<0xC8>(instr); break;
   case 0xC9: Instr_BitOps<0xC9>(instr); break;
   case 0xCA: Instr_BitOps<0xCA>(instr); break;
   case 0xCB: Instr_BitOps<0xCB>(instr); break;
   case 0xCC: Instr_BitOps<0xCC>(instr); break;
   case 0xCD: Instr_BitOps<0xCD>(instr); break;
   case 0xCE: Instr_BitOps<0xCE>(instr); break;
   case 0xCF: Instr_BitOps<0xCF>(instr); break;
   case 0xD0: Instr_BitOps<0xD0>(instr); break;
   case 0xD1: Instr_BitOps<0xD1>(instr); break;
   case 0xD2: Instr_BitOps<0xD2>(instr); break;
   case 0xD3: Instr_BitOps<0xD3>(instr); break;
   case 0xD4: Instr_BitOps<0xD4>(instr); break;
   case 0xD5: Instr_BitOps<0xD5>(instr); break;
   case 0xD6: Instr_BitOps<0xD6>(instr); break;
   case 0xD7: Instr_BitOps<0xD7>(instr); break;
   case 0xD8: Instr_BitOps<0xD8>(instr); break;
   case 0xD9: Instr_BitOps<0xD9>(instr); break;
   case 0xDA: Instr_BitOps<0xDA>(instr); break;
   case 0xDB: Instr_BitOps<0xDB>(instr); break;
   case 0xDC: Instr_BitOps<0xDC>(instr); break;
   case 0xDD: Instr_BitOps<0xDD>(instr); break;
   case 0xDE: Instr_BitOps<0xDE>(instr); break;
   case 0xDF: Instr_BitOps<0xDF>(instr); break;


   //
   // MOV
   //
   case 0xE0:
   {
    const unsigned r = instr & 0x7F;

    Regs[RegsWMap[r]] = Accum & RegsWMask[r];
   }
   break;

   //
   // MOV
   //
   case 0xE1:
   {
    const unsigned r = instr & 0x7F;

    if(r == 0x2E || r == 0x2F)
    {
     SNES_DBG("[CX4] Unhandled instruction: 0x%04x\n", instr);
    }

    Regs[RegsWMap[r]] = Regs[RegsIndex_MBR] & RegsWMask[r];
   }
   break;

   //
   // WRRAM
   //
   case 0xE8: Instr_WRRAM<0xE8>(instr); break;
   case 0xE9: Instr_WRRAM<0xE9>(instr); break;
   case 0xEA: Instr_WRRAM<0xEA>(instr); break;
   case 0xEC: Instr_WRRAM<0xEC>(instr); break;
   case 0xED: Instr_WRRAM<0xED>(instr); break;
   case 0xEE: Instr_WRRAM<0xEE>(instr); break;

   //
   // SWAP
   //
   case 0xF0:
   case 0xF1:
   case 0xF2:
   case 0xF3:
   {
    //printf("SWAP: %04x\n", instr);
    std::swap(Accum, Regs[RegsIndex_R0 + (instr & 0xF)]);
   }
   break;

   //
   // Clear
   //
   case 0xF8:
   case 0xF9:
   case 0xFA:
   case 0xFB:
   {
    Accum = 0;
    RAMB = 0;
    DPR = 0;
    P = 0;
   }
   break;

   //
   // Halt
   //
   case 0xFC:
   case 0xFD:
   case 0xFE:
   case 0xFF:
   {
    Status &= ~0x40;
    cycle_counter = std::min<int32>(cycle_counter, 0);
   }
   break;
  }
 }
}

static uint32 EventHandler(uint32 timestamp)
{
 Update(timestamp);

 return SNES_EVENT_MAXTS;
}

static void AdjustTS(int32 delta)
{
 last_master_timestamp += delta;
}

static DEFREAD(MainCPU_ReadRAM)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 if(MDFN_UNLIKELY((Status & 0x41) == 0x40))
 {
  SNES_DBG("[CX4] MainCPU read from data RAM while CX4 busy: 0x%06x\n", A);
  return 0xFF;
 }
 else
  return DataRAM[A & 0xFFF];
}

static DEFWRITE(MainCPU_WriteRAM)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 //printf("MainCPU_WriteRAM: %03x %02x\n", A & 0xFFF, V);
 if(MDFN_UNLIKELY((Status & 0x41) == 0x40))
  SNES_DBG("[CX4] MainCPU write to data RAM while CX4 busy: 0x%06x 0x%02x\n", A, V);
 else
  DataRAM[A & 0xFFF] = V;
}

static DEFREAD(MainCPU_ReadGPR)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 if(MDFN_UNLIKELY((Status & 0x41) == 0x40))
 {
  SNES_DBG("[CX4] MainCPU read from GPR while CX4 busy: 0x%06x\n", A);
  return 0xFF;
 }
 else
 {
  const unsigned index = (A & 0x3F) / 3;
  const unsigned shift = ((A & 0x3F) % 3) << 3;

  return Regs[RegsIndex_R0 + index] >> shift;
 }
}

static DEFWRITE(MainCPU_WriteGPR)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 if(MDFN_UNLIKELY((Status & 0x41) == 0x40))
 {
  SNES_DBG("[CX4] MainCPU write to GPR while CX4 busy: 0x%06x 0x%02x\n", A, V);
 }
 else
 {
  const unsigned index = (A & 0x3F) / 3;
  const unsigned shift = ((A & 0x3F) % 3) << 3;
  uint32 &r = Regs[RegsIndex_R0 + index];

  r = (r & ~(0xFF << shift)) | (V << shift);
  //printf("WriteGPR: A=0x%06x, V=0x%02x, index=%d, shift=%d, r=0x%06x\n", A, V, index, shift, r);
 }
}


static DEFREAD(MainCPU_ReadZero)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 return 0;
}

static DEFWRITE(MainCPU_WriteCachePage)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 Cache_Active = &Cache[V & 1];
 LoadCache(P);
}

static DEFREAD(MainCPU_ReadCachePage)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 return Cache_Active - &Cache[0];
}

static DEFWRITE(MainCPU_WriteCacheLock)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 Cache[0].Locked = (V >> 0) & 1;
 Cache[1].Locked = (V >> 1) & 1;
}

static DEFREAD(MainCPU_ReadCacheLock)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 return Cache[0].Locked | (Cache[1].Locked << 1);
}

static DEFWRITE(MainCPU_WriteProgROMBase)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 const unsigned shift = ((A & 0x3) - 1) << 3;

 ProgROM_Base = (ProgROM_Base & ~(0xFF << shift)) | (V << shift);
}

static DEFREAD(MainCPU_ReadProgROMBase)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 const unsigned shift = ((A & 0x3) - 1) << 3;

 return ProgROM_Base >> shift;
}

static DEFWRITE(MainCPU_WriteProgROMPage)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 const unsigned shift = ((A & 0x1) ^ 1) << 3;

 P = ((P & ~(0xFF << shift)) | (V << shift)) & 0x7FFF;
}

static DEFREAD(MainCPU_ReadProgROMPage)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 const unsigned shift = ((A & 0x1) ^ 1) << 3;

 return P >> shift;
}

static DEFWRITE(MainCPU_WriteIP)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 SNES_DBG("[CX4] Command 0x%04x:0x%02x\n", P, V);
 NextIP = IP = V;
 NextInstr = 0;
 Status |= 0x40;
 LoadCache(P);
}

static DEFREAD(MainCPU_ReadIP)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 return IP;
}

template<unsigned w>
static DEFWRITE(MainCPU_WriteDMARegs)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 if(w <= 2)
 {
  const unsigned shift = (w & 3) << 3;
  DMASource = (DMASource & ~(0xFF << shift)) | (V << shift);
 }
 else if(w <= 4)
 {
  const unsigned shift = ((w - 3) & 1) << 3;
  DMALength = (DMALength & ~(0xFF << shift)) | (V << shift);
 }
 else
 {
  const unsigned shift = ((w - 5) & 3) << 3;

  DMADest = (DMADest & ~(0xFF << shift)) | (V << shift);

  if(w == 7)
   Status |= 0x100;
 }
}

template<unsigned w>
static DEFREAD(MainCPU_ReadDMARegs)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 if(w <= 2)
  return DMASource >> ((w & 3) << 3);
 else if(w <= 4)
  return DMALength >> (((w - 2) & 1) << 3);
 else
  return DMADest >> (((w - 5) & 3) << 3);
}

static DEFWRITE(MainCPU_WriteWSControl)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 WSControl = V & 0x77;
}

static DEFREAD(MainCPU_ReadWSControl)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 return WSControl;
}

static DEFWRITE(MainCPU_WriteIRQControl)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 IRQControl = V & 1;
}

static DEFREAD(MainCPU_ReadIRQControl)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 return IRQControl;
}

static DEFREAD(MainCPU_ReadROMConfig)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 return 0x00; //TODO/FIXME?
}

static DEFREAD(MainCPU_ReadStatus)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 return Status;
}

static DEFWRITE(MainCPU_ClearSuspend)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 Status &= ~0x01;
}

static DEFWRITE(MainCPU_ClearStatusIRQ)
{
 CPUM.timestamp += MEMCYC_SLOW;
 Update(CPUM.timestamp);
 //
 // TODO/FIXME
 //Status &= ~
}

static DEFWRITE(MainCPU_WriteVectorReg)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 const unsigned shift = (A & 1) << 3;
 uint16& vr = VectorRegs[(A >> 1) & 0xF];

 vr = (vr & ~(0xFF << shift)) | (V << shift);
}

static DEFREAD(MainCPU_ReadVectorReg)
{
 CPUM.timestamp += MEMCYC_SLOW;
 //
 const unsigned shift = (A & 1) << 3;
 const uint16& vr = VectorRegs[(A >> 1) & 0xF];

 return vr >> shift;
}

static MDFN_COLD void Reset(bool powering_up)
{
 memset(DataRAM, 0x00, sizeof(DataRAM));

 Regs[RegsIndex_A] = 0xFFFFFF;
 Regs[RegsIndex_MACH] = 0;
 Regs[RegsIndex_MACL] = 0;
 Regs[RegsIndex_MBR] = 0;
 Regs[RegsIndex_ROMB] = 0;
 Regs[RegsIndex_RAMB] = 0;
 Regs[RegsIndex_MAR] = 0;
 Regs[RegsIndex_DPR] = 0;
 Regs[RegsIndex_IP] = 0;
 Regs[RegsIndex_P] = 0;

 for(unsigned i = 0; i < 16; i++)
  Regs[RegsIndex_R0 + i] = 0;
 
 Regs[RegsIndex_NextIP] = 0;
 Regs[RegsIndex_WriteDummy] = 0;

 Flag_Z = false;
 Flag_N = false;
 Flag_C = false;
 Flag_V = false;

 memset(Stack, 0, sizeof(Stack));
 SP = 0;

 NextInstr = 0;
 for(unsigned i = 0; i < 2; i++)
 {
  memset(Cache[i].Data, 0, sizeof(Cache[i].Data));
  Cache[i].Data[0x100] = 0xFC00;
  Cache[i].Data[0x101] = 0xFC00;
  Cache[i].Tag = ~0U;
  Cache[i].Locked = false;
 }
 Cache_Active = &Cache[0];
 ProgROM_Base = 0;

 DMASource = 0;
 DMALength = 0;
 DMADest = 0;

 Status = 0;
 IRQOut = false;
 WSControl = 0;
 IRQControl = 0;

 for(unsigned i = 0; i < 0x10; i++)
  VectorRegs[i] = 0;

 cycle_counter = 0;

 if(powering_up)
  run_count_mod = 0;
}

static void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 bool lca = Cache_Active - Cache;

 SFORMAT StateRegs[] =
 {
  SFVAR(DataRAM),

  SFVARN(Regs[RegsIndex_A], "A"),
  SFVARN(Regs[RegsIndex_MACH], "MACH"),
  SFVARN(Regs[RegsIndex_MACL], "MACL"),
  SFVARN(Regs[RegsIndex_MBR], "MBR"),
  SFVARN(Regs[RegsIndex_ROMB], "ROMB"),
  SFVARN(Regs[RegsIndex_RAMB], "RAMB"),
  SFVARN(Regs[RegsIndex_MAR], "MAR"),
  SFVARN(Regs[RegsIndex_DPR], "DPR"),
  SFVARN(Regs[RegsIndex_IP], "IP"),
  SFVARN(Regs[RegsIndex_P], "P"),

  SFPTR32N(&Regs[RegsIndex_R0], 16, "R"),
 
  SFVARN(Regs[RegsIndex_NextIP], "NextIP"),

  SFVAR(Flag_Z),
  SFVAR(Flag_N),
  SFVAR(Flag_C),
  SFVAR(Flag_V),

  SFVAR(Stack),
  SFVAR(SP),

  SFVAR(NextInstr),
  SFVAR(Cache->Data, 2, sizeof(*Cache), Cache),
  SFVAR(Cache->Tag, 2, sizeof(*Cache), Cache),
  SFVAR(Cache->Locked, 2, sizeof(*Cache), Cache),
  SFVARN(lca, "Cache_Active"),
  SFVAR(ProgROM_Base),

  SFVAR(DMASource),
  SFVAR(DMALength),
  SFVAR(DMADest),

  SFVAR(Status),
  SFVAR(IRQOut),
  SFVAR(WSControl),
  SFVAR(IRQControl),

  SFVAR(VectorRegs),

  SFVAR(cycle_counter),

  SFVAR(run_count_mod),

  //
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "CX4");

 if(load)
 {
  Cache_Active = &Cache[lca];
  NextIP = std::min<uint32>(0x101, NextIP);
 }
}

void CART_CX4_Init(const int32 master_clock, const int32 ocmultiplier)
{
 for(unsigned bank = 0x00; bank < 0x100; bank++)
 {
  if(!(bank & 0x40))
  {
   Set_A_Handlers((bank << 16) | 0x6000, (bank << 16) | 0x6BFF, MainCPU_ReadRAM, MainCPU_WriteRAM);
   Set_A_Handlers((bank << 16) | 0x7000, (bank << 16) | 0x7BFF, MainCPU_ReadRAM, MainCPU_WriteRAM);

   Set_A_Handlers((bank << 16) | 0x7F40, MainCPU_ReadDMARegs<0>, MainCPU_WriteDMARegs<0>);
   Set_A_Handlers((bank << 16) | 0x7F41, MainCPU_ReadDMARegs<1>, MainCPU_WriteDMARegs<1>);
   Set_A_Handlers((bank << 16) | 0x7F42, MainCPU_ReadDMARegs<2>, MainCPU_WriteDMARegs<2>);
   Set_A_Handlers((bank << 16) | 0x7F43, MainCPU_ReadDMARegs<3>, MainCPU_WriteDMARegs<3>);
   Set_A_Handlers((bank << 16) | 0x7F44, MainCPU_ReadDMARegs<4>, MainCPU_WriteDMARegs<4>);
   Set_A_Handlers((bank << 16) | 0x7F45, MainCPU_ReadDMARegs<5>, MainCPU_WriteDMARegs<5>);
   Set_A_Handlers((bank << 16) | 0x7F46, MainCPU_ReadDMARegs<6>, MainCPU_WriteDMARegs<6>);
   Set_A_Handlers((bank << 16) | 0x7F47, MainCPU_ReadDMARegs<7>, MainCPU_WriteDMARegs<7>);
   Set_A_Handlers((bank << 16) | 0x7F48, MainCPU_ReadCachePage, MainCPU_WriteCachePage);
   Set_A_Handlers((bank << 16) | 0x7F49, (bank << 16) | 0x7F4B, MainCPU_ReadProgROMBase, MainCPU_WriteProgROMBase);
   Set_A_Handlers((bank << 16) | 0x7F4C, MainCPU_ReadCacheLock, MainCPU_WriteCacheLock);
   Set_A_Handlers((bank << 16) | 0x7F4D, (bank << 16) | 0x7F4E, MainCPU_ReadProgROMPage, MainCPU_WriteProgROMPage);
   Set_A_Handlers((bank << 16) | 0x7F4F, MainCPU_ReadIP, MainCPU_WriteIP);
   Set_A_Handlers((bank << 16) | 0x7F50, MainCPU_ReadWSControl, MainCPU_WriteWSControl);
   Set_A_Handlers((bank << 16) | 0x7F51, MainCPU_ReadIRQControl, MainCPU_WriteIRQControl);
   Set_A_Handlers((bank << 16) | 0x7F52, MainCPU_ReadROMConfig, OBWrite_SLOW); //MainCPU_WriteROMConfig);

   Set_A_Handlers((bank << 16) | 0x7F53, MainCPU_ReadStatus, OBWrite_SLOW);	// MainCPU_WriteForceIdle
   Set_A_Handlers((bank << 16) | 0x7F54, MainCPU_ReadStatus, OBWrite_SLOW);
   Set_A_Handlers((bank << 16) | 0x7F55, MainCPU_ReadStatus, OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F56, MainCPU_ReadStatus, OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F57, MainCPU_ReadStatus, OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F58, MainCPU_ReadZero,   OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F59, MainCPU_ReadStatus, OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F5A, MainCPU_ReadZero,   OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F5B, MainCPU_ReadStatus, OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F5C, MainCPU_ReadStatus, OBWrite_SLOW);	// MainCPU_WriteSuspend
   Set_A_Handlers((bank << 16) | 0x7F5D, MainCPU_ReadStatus, MainCPU_ClearSuspend);
   Set_A_Handlers((bank << 16) | 0x7F5E, MainCPU_ReadStatus, MainCPU_ClearStatusIRQ);
   Set_A_Handlers((bank << 16) | 0x7F5F, MainCPU_ReadStatus, OBWrite_SLOW);
   Set_A_Handlers((bank << 16) | 0x7F60, (bank << 16) | 0x7F7F, MainCPU_ReadVectorReg, MainCPU_WriteVectorReg);

   Set_A_Handlers((bank << 16) | 0x7F80, (bank << 16) | 0x7FAF, MainCPU_ReadGPR, MainCPU_WriteGPR);
   Set_A_Handlers((bank << 16) | 0x7FB0, (bank << 16) | 0x7FBF, MainCPU_ReadZero, OBWrite_SLOW);
   Set_A_Handlers((bank << 16) | 0x7FC0, (bank << 16) | 0x7FEF, MainCPU_ReadGPR, MainCPU_WriteGPR);
   Set_A_Handlers((bank << 16) | 0x7FF0, (bank << 16) | 0x7FFF, MainCPU_ReadZero, OBWrite_SLOW);
  }
 }
 //
 //
 //
 last_master_timestamp = 0;
 clock_multiplier = ((int64)ocmultiplier * 20000000 * 2 + master_clock) / (master_clock * 2);

 memset(RegsRMap, RegsIndex_IR0, sizeof(RegsRMap));
 memset(RegsWMap, RegsIndex_WriteDummy, sizeof(RegsWMap));

 for(unsigned i = 0; i < 0x80; i++)
  RegsWMask[i] = 0;

 RegsRMap[0x00] = RegsWMap[0x00] = RegsIndex_A;
 RegsWMask[0x00] = 0xFFFFFF;

 RegsRMap[0x01] = RegsIndex_MACH;
 RegsRMap[0x02] = RegsIndex_MACL;
 RegsRMap[0x03] = RegsWMap[0x03] = RegsIndex_MBR;
 RegsWMask[0x03] = 0xFF;

 RegsRMap[0x08] = RegsIndex_ROMB;
 RegsRMap[0x0C] = RegsIndex_RAMB;
 RegsWMap[0x0C] = RegsIndex_RAMB;
 RegsWMask[0x0C] = 0xFFFFFF;

 RegsRMap[0x13] = RegsWMap[0x13] = RegsIndex_MAR;
 RegsWMask[0x13] = 0xFFFFFF;

 RegsRMap[0x1C] = RegsWMap[0x1C] = RegsIndex_DPR;
 RegsWMask[0x1C] = 0xFFF;

 RegsRMap[0x20] = RegsIndex_IP;
 RegsWMap[0x20] = RegsIndex_NextIP;
 RegsWMask[0x20] = 0xFF;

 RegsRMap[0x28] = RegsWMap[0x28] = RegsIndex_P;
 RegsWMask[0x28] = 0x7FFF;

 for(unsigned i = 0; i < 0x10; i++)
 {
  static const uint32 ctab[16] =
  {
   0x000000, 0xFFFFFF, 0x00FF00, 0xFF0000, 0x00FFFF, 0xFFFF00, 0x800000, 0x7FFFFF,
   0x008000, 0x007FFF, 0xFF7FFF, 0xFFFF7F, 0x010000, 0xFEFFFF, 0x000100, 0x00FEFF
  };
  Regs[RegsIndex_IR0 + i] = ctab[i];
  RegsRMap[0x50 + i] = RegsIndex_IR0 + i;
 }

 for(unsigned i = 0x60; i < 0x80; i++)
 {
  RegsRMap[i] = RegsWMap[i] = RegsIndex_R0 + (i & 0xF);
  RegsWMask[i] = 0xFFFFFF;
 }
 //
 //
 //
 Cart.AdjustTS = AdjustTS;
 Cart.EventHandler = EventHandler;
 Cart.Reset = Reset;
 Cart.StateAction = StateAction;
}



}
