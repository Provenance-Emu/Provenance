#ifndef ZSORT_H
#define ZSORT_H

struct zSortVDest{
	s16 sy;
	s16 sx;
	s32 invw;
	s16 yi;
	s16 xi;
	s16 wi;
	u8 fog;
	u8 cc;
};

typedef f32 M44[4][4];

void ZSort_Init();
void ZSort_RDPCMD( u32, u32 _w1 );
int Calc_invw( int _w );

#endif // ZSORT_H
