#ifndef F3DDKR_H
#define F3DDKR_H

#define F3DDKR_VTX_APPEND		0x00010000

#define F3DDKR_DMA_MTX			0x01
#define F3DDKR_DMA_TEX_OFFSET	0x02
#define F3DDKR_DMA_VTX			0x04
#define F3DDKR_DMA_TRI			0x05
#define F3DDKR_DMA_DL			0x07
#define F3DDKR_DMA_OFFSETS		0xBF

void F3DDKR_Init();
void F3DJFG_Init();
#endif

