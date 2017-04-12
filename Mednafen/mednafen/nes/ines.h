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

}

int Mapper1_Init(CartInfo *);
int Mapper4_Init(CartInfo *);
int Mapper5_Init(CartInfo *);
int Mapper6_Init(CartInfo *);
int Mapper8_Init(CartInfo *);
int Mapper11_Init(CartInfo *);
int Mapper12_Init(CartInfo *);
int Mapper15_Init(CartInfo *);
int Mapper16_Init(CartInfo *);
int Mapper17_Init(CartInfo *);
int Mapper18_Init(CartInfo *);
int Mapper19_Init(CartInfo *);
int Mapper21_Init(CartInfo *);
int Mapper22_Init(CartInfo *);
int Mapper23_Init(CartInfo *);
int Mapper24_Init(CartInfo *);
int Mapper25_Init(CartInfo *);
int Mapper26_Init(CartInfo *);
int Mapper32_Init(CartInfo *);
int Mapper33_Init(CartInfo *);
int Mapper34_Init(CartInfo *);
int Mapper37_Init(CartInfo *);
int Mapper38_Init(CartInfo *);
int Mapper41_Init(CartInfo *);
int Mapper44_Init(CartInfo *);
int Mapper45_Init(CartInfo *);
int Mapper46_Init(CartInfo *);
int Mapper47_Init(CartInfo *);
int Mapper48_Init(CartInfo *);
int Mapper49_Init(CartInfo *);
int Mapper51_Init(CartInfo *);
int Mapper52_Init(CartInfo *);
int Mapper64_Init(CartInfo *);
int Mapper65_Init(CartInfo *);
int Mapper67_Init(CartInfo *);
int Mapper68_Init(CartInfo *);
int Mapper70_Init(CartInfo *);
int Mapper71_Init(CartInfo *);
int Mapper72_Init(CartInfo *);
int Mapper73_Init(CartInfo *);
int Mapper74_Init(CartInfo *);
int Mapper75_Init(CartInfo *);
int Mapper76_Init(CartInfo *);
int Mapper77_Init(CartInfo *);
int Mapper78_Init(CartInfo *);
int Mapper80_Init(CartInfo *);
int Mapper82_Init(CartInfo *);
int Mapper85_Init(CartInfo *);
int Mapper86_Init(CartInfo *);
int Mapper87_Init(CartInfo *);
int Mapper88_Init(CartInfo *);
int Mapper89_Init(CartInfo *);
int Mapper92_Init(CartInfo *);

int Mapper90_Init(CartInfo *);
int Mapper97_Init(CartInfo *);
int Mapper99_Init(CartInfo *);
int Mapper101_Init(CartInfo *);

int Mapper165_Init(CartInfo *);
int Mapper209_Init(CartInfo *);
int Mapper91_Init(CartInfo *);
int Mapper92_Init(CartInfo *);
int Mapper93_Init(CartInfo *);
int Mapper94_Init(CartInfo *);
int Mapper95_Init(CartInfo *);
int Mapper96_Init(CartInfo *);
int Mapper105_Init(CartInfo *);
int Mapper107_Init(CartInfo *);
int Mapper112_Init(CartInfo *);
int Mapper113_Init(CartInfo *);
int Mapper114_Init(CartInfo *);
int Mapper115_Init(CartInfo *);
int Mapper116_Init(CartInfo *);
int Mapper117_Init(CartInfo *);
int Mapper118_Init(CartInfo *);
int Mapper119_Init(CartInfo *);
int Mapper140_Init(CartInfo *);
int Mapper150_Init(CartInfo *);
int Mapper151_Init(CartInfo *);
int Mapper152_Init(CartInfo *);
int Mapper153_Init(CartInfo *);
int Mapper154_Init(CartInfo *);
int Mapper155_Init(CartInfo *);
int Mapper156_Init(CartInfo *);
int Mapper157_Init(CartInfo *);
int Mapper158_Init(CartInfo *);
int Mapper159_Init(CartInfo *);
int Mapper163_Init(CartInfo *);
int Mapper164_Init(CartInfo *);
int Mapper180_Init(CartInfo *);
int Mapper182_Init(CartInfo *);
int Mapper184_Init(CartInfo *);
int Mapper185_Init(CartInfo *);
int Mapper187_Init(CartInfo *);
int Mapper188_Init(CartInfo *);
int Mapper189_Init(CartInfo *);
int Mapper193_Init(CartInfo *);
int Mapper206_Init(CartInfo *);
int Mapper207_Init(CartInfo *);
int Mapper208_Init(CartInfo *);
int Mapper209_Init(CartInfo *);
int Mapper210_Init(CartInfo *);
int Mapper215_Init(CartInfo *);
int Mapper217_Init(CartInfo *);
int Mapper222_Init(CartInfo *);
int Mapper228_Init(CartInfo *);
int Mapper232_Init(CartInfo *);
int Mapper234_Init(CartInfo *);
int Mapper240_Init(CartInfo *);
int Mapper241_Init(CartInfo *);
int Mapper242_Init(CartInfo *);
int Mapper244_Init(CartInfo *);
int Mapper245_Init(CartInfo *);
int Mapper246_Init(CartInfo *);
int Mapper248_Init(CartInfo *);
int Mapper249_Init(CartInfo *);
int Mapper250_Init(CartInfo *);

#endif
