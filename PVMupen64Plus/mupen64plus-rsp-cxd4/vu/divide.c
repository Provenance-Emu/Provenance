/******************************************************************************\
* Project:  MSP Simulation Layer for Vector Unit Computational Divides         *
* Authors:  Iconoclast                                                         *
* Release:  2016.03.23                                                         *
* License:  CC0 Public Domain Dedication                                       *
*                                                                              *
* To the extent possible under law, the author(s) have dedicated all copyright *
* and related and neighboring rights to this software to the public domain     *
* worldwide. This software is distributed without any warranty.                *
*                                                                              *
* You should have received a copy of the CC0 Public Domain Dedication along    *
* with this software.                                                          *
* If not, see <http://creativecommons.org/publicdomain/zero/1.0/>.             *
\******************************************************************************/

#include "divide.h"

static s32 DivIn = 0; /* buffered numerator of division read from vector file */
static s32 DivOut = 0; /* global division result set by VRCP/VRCPL/VRSQ/VRSQL */
#if (0 != 0)
static s32 MovIn; /* We do not emulate this register (obsolete, for VMOV). */
#endif

/*
 * Boolean flag:  Double-precision high was the last vector divide op?
 *
 * if (lastDivideOp == VRCP, VRCPL, VRSQ, VRSQL)
 *     DPH = false; // single-precision or double-precision low, not high
 * else if (lastDivideOp == VRCPH, VRSQH)
 *     DPH = true; // double-precision high
 * else if (lastDivideOp == VMOV, VNOP)
 *     DPH = DPH; // no change--divide-group ops but not real divides
 */
static int DPH = 0;

/*
 * 11-bit vector divide result look-up table
 * Thanks to MAME / MESS for organizing.
 */
static const u16 div_ROM[1 << 10] = {
    0xFFFFu,
    0xFF00u,
    0xFE01u,
    0xFD04u,
    0xFC07u,
    0xFB0Cu,
    0xFA11u,
    0xF918u,
    0xF81Fu,
    0xF727u,
    0xF631u,
    0xF53Bu,
    0xF446u,
    0xF352u,
    0xF25Fu,
    0xF16Du,
    0xF07Cu,
    0xEF8Bu,
    0xEE9Cu,
    0xEDAEu,
    0xECC0u,
    0xEBD3u,
    0xEAE8u,
    0xE9FDu,
    0xE913u,
    0xE829u,
    0xE741u,
    0xE65Au,
    0xE573u,
    0xE48Du,
    0xE3A9u,
    0xE2C5u,
    0xE1E1u,
    0xE0FFu,
    0xE01Eu,
    0xDF3Du,
    0xDE5Du,
    0xDD7Eu,
    0xDCA0u,
    0xDBC2u,
    0xDAE6u,
    0xDA0Au,
    0xD92Fu,
    0xD854u,
    0xD77Bu,
    0xD6A2u,
    0xD5CAu,
    0xD4F3u,
    0xD41Du,
    0xD347u,
    0xD272u,
    0xD19Eu,
    0xD0CBu,
    0xCFF8u,
    0xCF26u,
    0xCE55u,
    0xCD85u,
    0xCCB5u,
    0xCBE6u,
    0xCB18u,
    0xCA4Bu,
    0xC97Eu,
    0xC8B2u,
    0xC7E7u,
    0xC71Cu,
    0xC652u,
    0xC589u,
    0xC4C0u,
    0xC3F8u,
    0xC331u,
    0xC26Bu,
    0xC1A5u,
    0xC0E0u,
    0xC01Cu,
    0xBF58u,
    0xBE95u,
    0xBDD2u,
    0xBD10u,
    0xBC4Fu,
    0xBB8Fu,
    0xBACFu,
    0xBA10u,
    0xB951u,
    0xB894u,
    0xB7D6u,
    0xB71Au,
    0xB65Eu,
    0xB5A2u,
    0xB4E8u,
    0xB42Eu,
    0xB374u,
    0xB2BBu,
    0xB203u,
    0xB14Bu,
    0xB094u,
    0xAFDEu,
    0xAF28u,
    0xAE73u,
    0xADBEu,
    0xAD0Au,
    0xAC57u,
    0xABA4u,
    0xAAF1u,
    0xAA40u,
    0xA98Eu,
    0xA8DEu,
    0xA82Eu,
    0xA77Eu,
    0xA6D0u,
    0xA621u,
    0xA574u,
    0xA4C6u,
    0xA41Au,
    0xA36Eu,
    0xA2C2u,
    0xA217u,
    0xA16Du,
    0xA0C3u,
    0xA01Au,
    0x9F71u,
    0x9EC8u,
    0x9E21u,
    0x9D79u,
    0x9CD3u,
    0x9C2Du,
    0x9B87u,
    0x9AE2u,
    0x9A3Du,
    0x9999u,
    0x98F6u,
    0x9852u,
    0x97B0u,
    0x970Eu,
    0x966Cu,
    0x95CBu,
    0x952Bu,
    0x948Bu,
    0x93EBu,
    0x934Cu,
    0x92ADu,
    0x920Fu,
    0x9172u,
    0x90D4u,
    0x9038u,
    0x8F9Cu,
    0x8F00u,
    0x8E65u,
    0x8DCAu,
    0x8D30u,
    0x8C96u,
    0x8BFCu,
    0x8B64u,
    0x8ACBu,
    0x8A33u,
    0x899Cu,
    0x8904u,
    0x886Eu,
    0x87D8u,
    0x8742u,
    0x86ADu,
    0x8618u,
    0x8583u,
    0x84F0u,
    0x845Cu,
    0x83C9u,
    0x8336u,
    0x82A4u,
    0x8212u,
    0x8181u,
    0x80F0u,
    0x8060u,
    0x7FD0u,
    0x7F40u,
    0x7EB1u,
    0x7E22u,
    0x7D93u,
    0x7D05u,
    0x7C78u,
    0x7BEBu,
    0x7B5Eu,
    0x7AD2u,
    0x7A46u,
    0x79BAu,
    0x792Fu,
    0x78A4u,
    0x781Au,
    0x7790u,
    0x7706u,
    0x767Du,
    0x75F5u,
    0x756Cu,
    0x74E4u,
    0x745Du,
    0x73D5u,
    0x734Fu,
    0x72C8u,
    0x7242u,
    0x71BCu,
    0x7137u,
    0x70B2u,
    0x702Eu,
    0x6FA9u,
    0x6F26u,
    0x6EA2u,
    0x6E1Fu,
    0x6D9Cu,
    0x6D1Au,
    0x6C98u,
    0x6C16u,
    0x6B95u,
    0x6B14u,
    0x6A94u,
    0x6A13u,
    0x6993u,
    0x6914u,
    0x6895u,
    0x6816u,
    0x6798u,
    0x6719u,
    0x669Cu,
    0x661Eu,
    0x65A1u,
    0x6524u,
    0x64A8u,
    0x642Cu,
    0x63B0u,
    0x6335u,
    0x62BAu,
    0x623Fu,
    0x61C5u,
    0x614Bu,
    0x60D1u,
    0x6058u,
    0x5FDFu,
    0x5F66u,
    0x5EEDu,
    0x5E75u,
    0x5DFDu,
    0x5D86u,
    0x5D0Fu,
    0x5C98u,
    0x5C22u,
    0x5BABu,
    0x5B35u,
    0x5AC0u,
    0x5A4Bu,
    0x59D6u,
    0x5961u,
    0x58EDu,
    0x5879u,
    0x5805u,
    0x5791u,
    0x571Eu,
    0x56ACu,
    0x5639u,
    0x55C7u,
    0x5555u,
    0x54E3u,
    0x5472u,
    0x5401u,
    0x5390u,
    0x5320u,
    0x52AFu,
    0x5240u,
    0x51D0u,
    0x5161u,
    0x50F2u,
    0x5083u,
    0x5015u,
    0x4FA6u,
    0x4F38u,
    0x4ECBu,
    0x4E5Eu,
    0x4DF1u,
    0x4D84u,
    0x4D17u,
    0x4CABu,
    0x4C3Fu,
    0x4BD3u,
    0x4B68u,
    0x4AFDu,
    0x4A92u,
    0x4A27u,
    0x49BDu,
    0x4953u,
    0x48E9u,
    0x4880u,
    0x4817u,
    0x47AEu,
    0x4745u,
    0x46DCu,
    0x4674u,
    0x460Cu,
    0x45A5u,
    0x453Du,
    0x44D6u,
    0x446Fu,
    0x4408u,
    0x43A2u,
    0x433Cu,
    0x42D6u,
    0x4270u,
    0x420Bu,
    0x41A6u,
    0x4141u,
    0x40DCu,
    0x4078u,
    0x4014u,
    0x3FB0u,
    0x3F4Cu,
    0x3EE8u,
    0x3E85u,
    0x3E22u,
    0x3DC0u,
    0x3D5Du,
    0x3CFBu,
    0x3C99u,
    0x3C37u,
    0x3BD6u,
    0x3B74u,
    0x3B13u,
    0x3AB2u,
    0x3A52u,
    0x39F1u,
    0x3991u,
    0x3931u,
    0x38D2u,
    0x3872u,
    0x3813u,
    0x37B4u,
    0x3755u,
    0x36F7u,
    0x3698u,
    0x363Au,
    0x35DCu,
    0x357Fu,
    0x3521u,
    0x34C4u,
    0x3467u,
    0x340Au,
    0x33AEu,
    0x3351u,
    0x32F5u,
    0x3299u,
    0x323Eu,
    0x31E2u,
    0x3187u,
    0x312Cu,
    0x30D1u,
    0x3076u,
    0x301Cu,
    0x2FC2u,
    0x2F68u,
    0x2F0Eu,
    0x2EB4u,
    0x2E5Bu,
    0x2E02u,
    0x2DA9u,
    0x2D50u,
    0x2CF8u,
    0x2C9Fu,
    0x2C47u,
    0x2BEFu,
    0x2B97u,
    0x2B40u,
    0x2AE8u,
    0x2A91u,
    0x2A3Au,
    0x29E4u,
    0x298Du,
    0x2937u,
    0x28E0u,
    0x288Bu,
    0x2835u,
    0x27DFu,
    0x278Au,
    0x2735u,
    0x26E0u,
    0x268Bu,
    0x2636u,
    0x25E2u,
    0x258Du,
    0x2539u,
    0x24E5u,
    0x2492u,
    0x243Eu,
    0x23EBu,
    0x2398u,
    0x2345u,
    0x22F2u,
    0x22A0u,
    0x224Du,
    0x21FBu,
    0x21A9u,
    0x2157u,
    0x2105u,
    0x20B4u,
    0x2063u,
    0x2012u,
    0x1FC1u,
    0x1F70u,
    0x1F1Fu,
    0x1ECFu,
    0x1E7Fu,
    0x1E2Eu,
    0x1DDFu,
    0x1D8Fu,
    0x1D3Fu,
    0x1CF0u,
    0x1CA1u,
    0x1C52u,
    0x1C03u,
    0x1BB4u,
    0x1B66u,
    0x1B17u,
    0x1AC9u,
    0x1A7Bu,
    0x1A2Du,
    0x19E0u,
    0x1992u,
    0x1945u,
    0x18F8u,
    0x18ABu,
    0x185Eu,
    0x1811u,
    0x17C4u,
    0x1778u,
    0x172Cu,
    0x16E0u,
    0x1694u,
    0x1648u,
    0x15FDu,
    0x15B1u,
    0x1566u,
    0x151Bu,
    0x14D0u,
    0x1485u,
    0x143Bu,
    0x13F0u,
    0x13A6u,
    0x135Cu,
    0x1312u,
    0x12C8u,
    0x127Fu,
    0x1235u,
    0x11ECu,
    0x11A3u,
    0x1159u,
    0x1111u,
    0x10C8u,
    0x107Fu,
    0x1037u,
    0x0FEFu,
    0x0FA6u,
    0x0F5Eu,
    0x0F17u,
    0x0ECFu,
    0x0E87u,
    0x0E40u,
    0x0DF9u,
    0x0DB2u,
    0x0D6Bu,
    0x0D24u,
    0x0CDDu,
    0x0C97u,
    0x0C50u,
    0x0C0Au,
    0x0BC4u,
    0x0B7Eu,
    0x0B38u,
    0x0AF2u,
    0x0AADu,
    0x0A68u,
    0x0A22u,
    0x09DDu,
    0x0998u,
    0x0953u,
    0x090Fu,
    0x08CAu,
    0x0886u,
    0x0842u,
    0x07FDu,
    0x07B9u,
    0x0776u,
    0x0732u,
    0x06EEu,
    0x06ABu,
    0x0668u,
    0x0624u,
    0x05E1u,
    0x059Eu,
    0x055Cu,
    0x0519u,
    0x04D6u,
    0x0494u,
    0x0452u,
    0x0410u,
    0x03CEu,
    0x038Cu,
    0x034Au,
    0x0309u,
    0x02C7u,
    0x0286u,
    0x0245u,
    0x0204u,
    0x01C3u,
    0x0182u,
    0x0141u,
    0x0101u,
    0x00C0u,
    0x0080u,
    0x0040u,
    0x6A09u,
    0xFFFFu,
    0x6955u,
    0xFF00u,
    0x68A1u,
    0xFE02u,
    0x67EFu,
    0xFD06u,
    0x673Eu,
    0xFC0Bu,
    0x668Du,
    0xFB12u,
    0x65DEu,
    0xFA1Au,
    0x6530u,
    0xF923u,
    0x6482u,
    0xF82Eu,
    0x63D6u,
    0xF73Bu,
    0x632Bu,
    0xF648u,
    0x6280u,
    0xF557u,
    0x61D7u,
    0xF467u,
    0x612Eu,
    0xF379u,
    0x6087u,
    0xF28Cu,
    0x5FE0u,
    0xF1A0u,
    0x5F3Au,
    0xF0B6u,
    0x5E95u,
    0xEFCDu,
    0x5DF1u,
    0xEEE5u,
    0x5D4Eu,
    0xEDFFu,
    0x5CACu,
    0xED19u,
    0x5C0Bu,
    0xEC35u,
    0x5B6Bu,
    0xEB52u,
    0x5ACBu,
    0xEA71u,
    0x5A2Cu,
    0xE990u,
    0x598Fu,
    0xE8B1u,
    0x58F2u,
    0xE7D3u,
    0x5855u,
    0xE6F6u,
    0x57BAu,
    0xE61Bu,
    0x5720u,
    0xE540u,
    0x5686u,
    0xE467u,
    0x55EDu,
    0xE38Eu,
    0x5555u,
    0xE2B7u,
    0x54BEu,
    0xE1E1u,
    0x5427u,
    0xE10Du,
    0x5391u,
    0xE039u,
    0x52FCu,
    0xDF66u,
    0x5268u,
    0xDE94u,
    0x51D5u,
    0xDDC4u,
    0x5142u,
    0xDCF4u,
    0x50B0u,
    0xDC26u,
    0x501Fu,
    0xDB59u,
    0x4F8Eu,
    0xDA8Cu,
    0x4EFEu,
    0xD9C1u,
    0x4E6Fu,
    0xD8F7u,
    0x4DE1u,
    0xD82Du,
    0x4D53u,
    0xD765u,
    0x4CC6u,
    0xD69Eu,
    0x4C3Au,
    0xD5D7u,
    0x4BAFu,
    0xD512u,
    0x4B24u,
    0xD44Eu,
    0x4A9Au,
    0xD38Au,
    0x4A10u,
    0xD2C8u,
    0x4987u,
    0xD206u,
    0x48FFu,
    0xD146u,
    0x4878u,
    0xD086u,
    0x47F1u,
    0xCFC7u,
    0x476Bu,
    0xCF0Au,
    0x46E5u,
    0xCE4Du,
    0x4660u,
    0xCD91u,
    0x45DCu,
    0xCCD6u,
    0x4558u,
    0xCC1Bu,
    0x44D5u,
    0xCB62u,
    0x4453u,
    0xCAA9u,
    0x43D1u,
    0xC9F2u,
    0x434Fu,
    0xC93Bu,
    0x42CFu,
    0xC885u,
    0x424Fu,
    0xC7D0u,
    0x41CFu,
    0xC71Cu,
    0x4151u,
    0xC669u,
    0x40D2u,
    0xC5B6u,
    0x4055u,
    0xC504u,
    0x3FD8u,
    0xC453u,
    0x3F5Bu,
    0xC3A3u,
    0x3EDFu,
    0xC2F4u,
    0x3E64u,
    0xC245u,
    0x3DE9u,
    0xC198u,
    0x3D6Eu,
    0xC0EBu,
    0x3CF5u,
    0xC03Fu,
    0x3C7Cu,
    0xBF93u,
    0x3C03u,
    0xBEE9u,
    0x3B8Bu,
    0xBE3Fu,
    0x3B13u,
    0xBD96u,
    0x3A9Cu,
    0xBCEDu,
    0x3A26u,
    0xBC46u,
    0x39B0u,
    0xBB9Fu,
    0x393Au,
    0xBAF8u,
    0x38C5u,
    0xBA53u,
    0x3851u,
    0xB9AEu,
    0x37DDu,
    0xB90Au,
    0x3769u,
    0xB867u,
    0x36F6u,
    0xB7C5u,
    0x3684u,
    0xB723u,
    0x3612u,
    0xB681u,
    0x35A0u,
    0xB5E1u,
    0x352Fu,
    0xB541u,
    0x34BFu,
    0xB4A2u,
    0x344Fu,
    0xB404u,
    0x33DFu,
    0xB366u,
    0x3370u,
    0xB2C9u,
    0x3302u,
    0xB22Cu,
    0x3293u,
    0xB191u,
    0x3226u,
    0xB0F5u,
    0x31B9u,
    0xB05Bu,
    0x314Cu,
    0xAFC1u,
    0x30DFu,
    0xAF28u,
    0x3074u,
    0xAE8Fu,
    0x3008u,
    0xADF7u,
    0x2F9Du,
    0xAD60u,
    0x2F33u,
    0xACC9u,
    0x2EC8u,
    0xAC33u,
    0x2E5Fu,
    0xAB9Eu,
    0x2DF6u,
    0xAB09u,
    0x2D8Du,
    0xAA75u,
    0x2D24u,
    0xA9E1u,
    0x2CBCu,
    0xA94Eu,
    0x2C55u,
    0xA8BCu,
    0x2BEEu,
    0xA82Au,
    0x2B87u,
    0xA799u,
    0x2B21u,
    0xA708u,
    0x2ABBu,
    0xA678u,
    0x2A55u,
    0xA5E8u,
    0x29F0u,
    0xA559u,
    0x298Bu,
    0xA4CBu,
    0x2927u,
    0xA43Du,
    0x28C3u,
    0xA3B0u,
    0x2860u,
    0xA323u,
    0x27FDu,
    0xA297u,
    0x279Au,
    0xA20Bu,
    0x2738u,
    0xA180u,
    0x26D6u,
    0xA0F6u,
    0x2674u,
    0xA06Cu,
    0x2613u,
    0x9FE2u,
    0x25B2u,
    0x9F59u,
    0x2552u,
    0x9ED1u,
    0x24F2u,
    0x9E49u,
    0x2492u,
    0x9DC2u,
    0x2432u,
    0x9D3Bu,
    0x23D3u,
    0x9CB4u,
    0x2375u,
    0x9C2Fu,
    0x2317u,
    0x9BA9u,
    0x22B9u,
    0x9B25u,
    0x225Bu,
    0x9AA0u,
    0x21FEu,
    0x9A1Cu,
    0x21A1u,
    0x9999u,
    0x2145u,
    0x9916u,
    0x20E8u,
    0x9894u,
    0x208Du,
    0x9812u,
    0x2031u,
    0x9791u,
    0x1FD6u,
    0x9710u,
    0x1F7Bu,
    0x968Fu,
    0x1F21u,
    0x960Fu,
    0x1EC7u,
    0x9590u,
    0x1E6Du,
    0x9511u,
    0x1E13u,
    0x9492u,
    0x1DBAu,
    0x9414u,
    0x1D61u,
    0x9397u,
    0x1D09u,
    0x931Au,
    0x1CB1u,
    0x929Du,
    0x1C59u,
    0x9221u,
    0x1C01u,
    0x91A5u,
    0x1BAAu,
    0x9129u,
    0x1B53u,
    0x90AFu,
    0x1AFCu,
    0x9034u,
    0x1AA6u,
    0x8FBAu,
    0x1A50u,
    0x8F40u,
    0x19FAu,
    0x8EC7u,
    0x19A5u,
    0x8E4Fu,
    0x1950u,
    0x8DD6u,
    0x18FBu,
    0x8D5Eu,
    0x18A7u,
    0x8CE7u,
    0x1853u,
    0x8C70u,
    0x17FFu,
    0x8BF9u,
    0x17ABu,
    0x8B83u,
    0x1758u,
    0x8B0Du,
    0x1705u,
    0x8A98u,
    0x16B2u,
    0x8A23u,
    0x1660u,
    0x89AEu,
    0x160Du,
    0x893Au,
    0x15BCu,
    0x88C6u,
    0x156Au,
    0x8853u,
    0x1519u,
    0x87E0u,
    0x14C8u,
    0x876Du,
    0x1477u,
    0x86FBu,
    0x1426u,
    0x8689u,
    0x13D6u,
    0x8618u,
    0x1386u,
    0x85A7u,
    0x1337u,
    0x8536u,
    0x12E7u,
    0x84C6u,
    0x1298u,
    0x8456u,
    0x1249u,
    0x83E7u,
    0x11FBu,
    0x8377u,
    0x11ACu,
    0x8309u,
    0x115Eu,
    0x829Au,
    0x1111u,
    0x822Cu,
    0x10C3u,
    0x81BFu,
    0x1076u,
    0x8151u,
    0x1029u,
    0x80E4u,
    0x0FDCu,
    0x8078u,
    0x0F8Fu,
    0x800Cu,
    0x0F43u,
    0x7FA0u,
    0x0EF7u,
    0x7F34u,
    0x0EABu,
    0x7EC9u,
    0x0E60u,
    0x7E5Eu,
    0x0E15u,
    0x7DF4u,
    0x0DCAu,
    0x7D8Au,
    0x0D7Fu,
    0x7D20u,
    0x0D34u,
    0x7CB6u,
    0x0CEAu,
    0x7C4Du,
    0x0CA0u,
    0x7BE5u,
    0x0C56u,
    0x7B7Cu,
    0x0C0Cu,
    0x7B14u,
    0x0BC3u,
    0x7AACu,
    0x0B7Au,
    0x7A45u,
    0x0B31u,
    0x79DEu,
    0x0AE8u,
    0x7977u,
    0x0AA0u,
    0x7911u,
    0x0A58u,
    0x78ABu,
    0x0A10u,
    0x7845u,
    0x09C8u,
    0x77DFu,
    0x0981u,
    0x777Au,
    0x0939u,
    0x7715u,
    0x08F2u,
    0x76B1u,
    0x08ABu,
    0x764Du,
    0x0865u,
    0x75E9u,
    0x081Eu,
    0x7585u,
    0x07D8u,
    0x7522u,
    0x0792u,
    0x74BFu,
    0x074Du,
    0x745Du,
    0x0707u,
    0x73FAu,
    0x06C2u,
    0x7398u,
    0x067Du,
    0x7337u,
    0x0638u,
    0x72D5u,
    0x05F3u,
    0x7274u,
    0x05AFu,
    0x7213u,
    0x056Au,
    0x71B3u,
    0x0526u,
    0x7152u,
    0x04E2u,
    0x70F2u,
    0x049Fu,
    0x7093u,
    0x045Bu,
    0x7033u,
    0x0418u,
    0x6FD4u,
    0x03D5u,
    0x6F76u,
    0x0392u,
    0x6F17u,
    0x0350u,
    0x6EB9u,
    0x030Du,
    0x6E5Bu,
    0x02CBu,
    0x6DFDu,
    0x0289u,
    0x6DA0u,
    0x0247u,
    0x6D43u,
    0x0206u,
    0x6CE6u,
    0x01C4u,
    0x6C8Au,
    0x0183u,
    0x6C2Du,
    0x0142u,
    0x6BD1u,
    0x0101u,
    0x6B76u,
    0x00C0u,
    0x6B1Au,
    0x0080u,
    0x6ABFu,
    0x0040u,
    0x6A64u,
};

enum {
    SP_DIV_SQRT_NO,
    SP_DIV_SQRT_YES
};
enum {
    SP_DIV_PRECISION_SINGLE = 0,
    SP_DIV_PRECISION_DOUBLE = ~0
/*, SP_DIV_PRECISION_CURRENT */
};

NOINLINE static void do_div(i32 data, int sqrt, int precision)
{
    i32 addr;
    int fetch;
    int shift;

#if (~0 >> 1 == -1)
    data ^= (s32)(data + 32768) >> 31; /* DP only:  (data < -32768) */
    fetch = (s32)(data +     0) >> 31;
    data ^= fetch;
    data -= fetch; /* two's complement:  -x == ~x - (~0) on wrap-around */
#else
    if (precision == SP_DIV_PRECISION_SINGLE)
        data = (data < 0) ? -data : +data;
    if (precision == SP_DIV_PRECISION_DOUBLE && data < 0)
        data = (data >= -32768) ? -data : ~data;
#endif

/*
 * Note, from the code just above, that data cannot be negative.
 * (data >= 0) is unconditionally forced by the above algorithm.
 */
    addr = data;
    if (data == 0x00000000) {
        shift = (precision == SP_DIV_PRECISION_SINGLE) ? 16 : 0;
        addr = addr << shift;
    } else {
        for (shift = 0; addr >= 0x00000000; addr <<= 1, shift++)
            ;
    }
    addr = (addr >> 22) & 0x000001FF;

    if (sqrt == SP_DIV_SQRT_YES) {
        addr &= 0x000001FE;
        addr |= 0x00000200 | (shift & 1);
    }
    shift ^= 31; /* flipping shift direction from left- to right- */
    shift >>= (sqrt == SP_DIV_SQRT_YES);
    DivOut = (0x40000000UL | ((u32)div_ROM[addr] << 14)) >> shift;
    if (DivIn == 0) /* corner case:  overflow via division by zero */
        DivOut = +0x7FFFFFFFl;
    else if (DivIn == -32768) /* corner case:  signed underflow barrier */
        DivOut = -0x00010000l;
    else
        DivOut ^= (DivIn < 0) ? ~0 : 0;
    return;
}

VECTOR_OPERATION VRCP(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;
    const int source = (inst_word & 0x0000FFFF) >> 11;
    const int target = (inst_word >> 16) & 31;
    const unsigned int element = (inst_word >> 21) & 0x7;

    DivIn = (i32)VR[target][element];
    do_div(DivIn, SP_DIV_SQRT_NO, SP_DIV_PRECISION_SINGLE);
#ifdef ARCH_MIN_SSE2
    *(v16 *)VACC_L = vt;
#else
    vector_copy(VACC_L, vt);
#endif
    VR[result][source & 07] = (i16)DivOut;
    DPH = SP_DIV_PRECISION_SINGLE;
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vs);
#else
    vector_copy(V_result, VR[result]);
    vs = vt; /* unused */
    return;
#endif
}

VECTOR_OPERATION VRCPL(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;
    const int source = (inst_word & 0x0000FFFF) >> 11;
    const int target = (inst_word >> 16) & 31;
    const unsigned int element = (inst_word >> 21) & 0x7;

    DivIn &= DPH;
    DivIn |= (u16)VR[target][element];
    do_div(DivIn, SP_DIV_SQRT_NO, DPH);
#ifdef ARCH_MIN_SSE2
    *(v16 *)VACC_L = vt;
#else
    vector_copy(VACC_L, vt);
#endif
    VR[result][source & 07] = (i16)DivOut;
    DPH = SP_DIV_PRECISION_SINGLE;
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vs);
#else
    vector_copy(V_result, VR[result]);
    vs = vt; /* unused */
    return;
#endif
}

VECTOR_OPERATION VRCPH(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;
    const int source = (inst_word & 0x0000FFFF) >> 11;
    const int target = (inst_word >> 16) & 31;
    const unsigned int element = (inst_word >> 21) & 0x7;

    DivIn = VR[target][element] << 16;
#ifdef ARCH_MIN_SSE2
    *(v16 *)VACC_L = vt;
#else
    vector_copy(VACC_L, vt);
#endif
    VR[result][source & 07] = DivOut >> 16;
    DPH = SP_DIV_PRECISION_DOUBLE;
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vs);
#else
    vector_copy(V_result, VR[result]);
    vs = vt; /* unused */
    return;
#endif
}

VECTOR_OPERATION VMOV(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;
    const int source = (inst_word & 0x0000FFFF) >> 11;
    const unsigned int element = (inst_word >> 21) & 0x7;

#ifdef ARCH_MIN_SSE2
    *(v16 *)VACC_L = vt;
#else
    vector_copy(VACC_L, vt);
#endif
    VR[result][source & 07] = VACC_L[element];
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vs);
#else
    vector_copy(V_result, VR[result]);
    vs = vt; /* unused */
    return;
#endif
}

VECTOR_OPERATION VRSQ(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;
    const int source = (inst_word & 0x0000FFFF) >> 11;
    const int target = (inst_word >> 16) & 31;
    const unsigned int element = (inst_word >> 21) & 0x7;

    DivIn = (i32)VR[target][element];
    do_div(DivIn, SP_DIV_SQRT_YES, SP_DIV_PRECISION_SINGLE);
#ifdef ARCH_MIN_SSE2
    *(v16 *)VACC_L = vt;
#else
    vector_copy(VACC_L, vt);
#endif
    VR[result][source & 07] = (i16)DivOut;
    DPH = SP_DIV_PRECISION_SINGLE;
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vs);
#else
    vector_copy(V_result, VR[result]);
    vs = vt; /* unused */
    return;
#endif
}

VECTOR_OPERATION VRSQL(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;
    const int source = (inst_word & 0x0000FFFF) >> 11;
    const int target = (inst_word >> 16) & 31;
    const unsigned int element = (inst_word >> 21) & 0x7;

    DivIn &= DPH;
    DivIn |= (u16)VR[target][element];
    do_div(DivIn, SP_DIV_SQRT_YES, DPH);
#ifdef ARCH_MIN_SSE2
    *(v16 *)VACC_L = vt;
#else
    vector_copy(VACC_L, vt);
#endif
    VR[result][source & 07] = (i16)DivOut;
    DPH = SP_DIV_PRECISION_SINGLE;
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vs);
#else
    vector_copy(V_result, VR[result]);
    vs = vt; /* unused */
    return;
#endif
}

VECTOR_OPERATION VRSQH(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;
    const int source = (inst_word & 0x0000FFFF) >> 11;
    const int target = (inst_word >> 16) & 31;
    const unsigned int element = (inst_word >> 21) & 0x7;

    DivIn = VR[target][element] << 16;
#ifdef ARCH_MIN_SSE2
    *(v16 *)VACC_L = vt;
#else
    vector_copy(VACC_L, vt);
#endif
    VR[result][source & 07] = DivOut >> 16;
    DPH = SP_DIV_PRECISION_DOUBLE;
#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vs);
#else
    vector_copy(V_result, VR[result]);
    vs = vt; /* unused */
    return;
#endif
}

VECTOR_OPERATION VNOP(v16 vs, v16 vt)
{
    const int result = (inst_word & 0x000007FF) >>  6;

#ifdef ARCH_MIN_SSE2
    vs = *(v16 *)VR[result];
    return (vt = vs); /* -Wunused-but-set-parameter */
#else
    vector_copy(V_result, VR[result]);
    if (vt == vs)
        return; /* -Wunused-but-set-parameter */
    return;
#endif
}
