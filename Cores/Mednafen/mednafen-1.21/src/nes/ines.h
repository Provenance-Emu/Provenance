#ifndef __MDFN_NES_INES_H
#define __MDFN_NES_INES_H

namespace MDFN_IEN_NES
{
#ifdef INESPRIV
extern uint32 iNESGameCRC32;
#else
#endif

struct iNES_HEADER
{
	union
	{
	 struct
	 {
	  char ID[4]; /*NES^Z*/
          uint8 ROM_size;
          uint8 VROM_size;
          uint8 ROM_type;
          uint8 ROM_type2;
          uint8 reserve[8];
	 };
	 uint8 raw[16];
	};
};

int Mapper1_Init(CartInfo *) MDFN_COLD;
int Mapper4_Init(CartInfo *) MDFN_COLD;
int Mapper5_Init(CartInfo *) MDFN_COLD;
int Mapper6_Init(CartInfo *) MDFN_COLD;
int Mapper8_Init(CartInfo *) MDFN_COLD;
int Mapper11_Init(CartInfo *) MDFN_COLD;
int Mapper12_Init(CartInfo *) MDFN_COLD;
int Mapper15_Init(CartInfo *) MDFN_COLD;
int Mapper16_Init(CartInfo *) MDFN_COLD;
int Mapper17_Init(CartInfo *) MDFN_COLD;
int Mapper18_Init(CartInfo *) MDFN_COLD;
int Mapper19_Init(CartInfo *) MDFN_COLD;
int Mapper21_Init(CartInfo *) MDFN_COLD;
int Mapper22_Init(CartInfo *) MDFN_COLD;
int Mapper23_Init(CartInfo *) MDFN_COLD;
int Mapper24_Init(CartInfo *) MDFN_COLD;
int Mapper25_Init(CartInfo *) MDFN_COLD;
int Mapper26_Init(CartInfo *) MDFN_COLD;
int Mapper30_Init(CartInfo *) MDFN_COLD;
int Mapper32_Init(CartInfo *) MDFN_COLD;
int Mapper33_Init(CartInfo *) MDFN_COLD;
int Mapper34_Init(CartInfo *) MDFN_COLD;
int Mapper37_Init(CartInfo *) MDFN_COLD;
int Mapper38_Init(CartInfo *) MDFN_COLD;
int Mapper40_Init(CartInfo *) MDFN_COLD;
int Mapper41_Init(CartInfo *) MDFN_COLD;
int Mapper44_Init(CartInfo *) MDFN_COLD;
int Mapper45_Init(CartInfo *) MDFN_COLD;
int Mapper46_Init(CartInfo *) MDFN_COLD;
int Mapper47_Init(CartInfo *) MDFN_COLD;
int Mapper48_Init(CartInfo *) MDFN_COLD;
int Mapper49_Init(CartInfo *) MDFN_COLD;
int Mapper51_Init(CartInfo *) MDFN_COLD;
int Mapper52_Init(CartInfo *) MDFN_COLD;
int Mapper64_Init(CartInfo *) MDFN_COLD;

int Mapper71_Init(CartInfo *) MDFN_COLD;
int Mapper74_Init(CartInfo *) MDFN_COLD;
int Mapper85_Init(CartInfo *) MDFN_COLD;
int Mapper101_Init(CartInfo *) MDFN_COLD;
int Mapper105_Init(CartInfo *) MDFN_COLD;
int Mapper115_Init(CartInfo *) MDFN_COLD;
int Mapper116_Init(CartInfo *) MDFN_COLD;
int Mapper118_Init(CartInfo *) MDFN_COLD;
int Mapper119_Init(CartInfo *) MDFN_COLD;
int Mapper153_Init(CartInfo *) MDFN_COLD;
int Mapper155_Init(CartInfo *) MDFN_COLD;
int Mapper157_Init(CartInfo *) MDFN_COLD;
int Mapper158_Init(CartInfo *) MDFN_COLD;
int Mapper159_Init(CartInfo *) MDFN_COLD;

}

int Mapper65_Init(CartInfo *) MDFN_COLD;
int Mapper67_Init(CartInfo *) MDFN_COLD;
int Mapper68_Init(CartInfo *) MDFN_COLD;
int Mapper70_Init(CartInfo *) MDFN_COLD;
int Mapper72_Init(CartInfo *) MDFN_COLD;
int Mapper73_Init(CartInfo *) MDFN_COLD;
int Mapper75_Init(CartInfo *) MDFN_COLD;
int Mapper76_Init(CartInfo *) MDFN_COLD;
int Mapper77_Init(CartInfo *) MDFN_COLD;
int Mapper78_Init(CartInfo *) MDFN_COLD;
int Mapper80_Init(CartInfo *) MDFN_COLD;
int Mapper82_Init(CartInfo *) MDFN_COLD;
int Mapper86_Init(CartInfo *) MDFN_COLD;
int Mapper87_Init(CartInfo *) MDFN_COLD;
int Mapper88_Init(CartInfo *) MDFN_COLD;
int Mapper89_Init(CartInfo *) MDFN_COLD;
int Mapper92_Init(CartInfo *) MDFN_COLD;

int Mapper90_Init(CartInfo *) MDFN_COLD;
int Mapper97_Init(CartInfo *) MDFN_COLD;
int Mapper99_Init(CartInfo *) MDFN_COLD;

int Mapper165_Init(CartInfo *) MDFN_COLD;
int Mapper209_Init(CartInfo *) MDFN_COLD;
int Mapper91_Init(CartInfo *) MDFN_COLD;
int Mapper92_Init(CartInfo *) MDFN_COLD;
int Mapper93_Init(CartInfo *) MDFN_COLD;
int Mapper94_Init(CartInfo *) MDFN_COLD;
int Mapper95_Init(CartInfo *) MDFN_COLD;
int Mapper96_Init(CartInfo *) MDFN_COLD;
int Mapper107_Init(CartInfo *) MDFN_COLD;
int Mapper112_Init(CartInfo *) MDFN_COLD;
int Mapper113_Init(CartInfo *) MDFN_COLD;
int Mapper114_Init(CartInfo *) MDFN_COLD;
int Mapper117_Init(CartInfo *) MDFN_COLD;
int Mapper140_Init(CartInfo *) MDFN_COLD;
int Mapper150_Init(CartInfo *) MDFN_COLD;
int Mapper151_Init(CartInfo *) MDFN_COLD;
int Mapper152_Init(CartInfo *) MDFN_COLD;
int Mapper154_Init(CartInfo *) MDFN_COLD;
int Mapper156_Init(CartInfo *) MDFN_COLD;
int Mapper163_Init(CartInfo *) MDFN_COLD;
int Mapper164_Init(CartInfo *) MDFN_COLD;
int Mapper180_Init(CartInfo *) MDFN_COLD;
int Mapper182_Init(CartInfo *) MDFN_COLD;
int Mapper184_Init(CartInfo *) MDFN_COLD;
int Mapper185_Init(CartInfo *) MDFN_COLD;
int Mapper187_Init(CartInfo *) MDFN_COLD;
int Mapper188_Init(CartInfo *) MDFN_COLD;
int Mapper189_Init(CartInfo *) MDFN_COLD;
int Mapper190_Init(CartInfo *) MDFN_COLD;
int Mapper193_Init(CartInfo *) MDFN_COLD;
int Mapper206_Init(CartInfo *) MDFN_COLD;
int Mapper207_Init(CartInfo *) MDFN_COLD;
int Mapper208_Init(CartInfo *) MDFN_COLD;
int Mapper209_Init(CartInfo *) MDFN_COLD;

namespace MDFN_IEN_NES
{
int Mapper210_Init(CartInfo *) MDFN_COLD;
int Mapper215_Init(CartInfo *) MDFN_COLD;
int Mapper217_Init(CartInfo *) MDFN_COLD;
int Mapper222_Init(CartInfo *) MDFN_COLD;
int Mapper228_Init(CartInfo *) MDFN_COLD;
int Mapper234_Init(CartInfo *) MDFN_COLD;
int Mapper240_Init(CartInfo *) MDFN_COLD;
int Mapper241_Init(CartInfo *) MDFN_COLD;
int Mapper242_Init(CartInfo *) MDFN_COLD;
int Mapper244_Init(CartInfo *) MDFN_COLD;
int Mapper245_Init(CartInfo *) MDFN_COLD;
int Mapper246_Init(CartInfo *) MDFN_COLD;
int Mapper248_Init(CartInfo *) MDFN_COLD;
int Mapper249_Init(CartInfo *) MDFN_COLD;
int Mapper250_Init(CartInfo *) MDFN_COLD;
}

#endif
