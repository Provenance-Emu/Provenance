// hw.h

#ifndef _HW_H_
#define _HW_H_

#ifdef __cplusplus
extern "C" {
#endif

#define D2_CHCR_ *((volatile unsigned int*)0x1000A000)
#define D2_MADR_ *((volatile unsigned int*)0x1000A010)
#define D2_QWC_ *((volatile unsigned int*)0x1000A020)

// normal mode dma transfer to the gif. From the funslower src.
inline static void dma02_send(volatile void *start, int size, int chcr)
{
	D2_MADR_=(int)start;
	D2_QWC_=size;
	D2_CHCR_=chcr;
}

/* not too useful */
void install_VRend_handler();
void remove_VRend_handler();
void WaitForNextVRend();
int TestVRend();
void ClearVRendf();

/* quite useful */
void install_VRstart_handler();
void remove_VRstart_handler();
void WaitForNextVRstart(int numvrs);
int TestVRstart();
void ClearVRcount();

void initGraph(int mode);
void SetVideoMode();
void SetDrawFrameBuffer(int which);
void SetCrtFrameBuffer(int which);

void DmaReset();
void SendDma02(void *DmaTag);
void Dma02Wait();

void DCacheFlush();

void resetVU0();
void initMainThread();

void qmemcpy(void *dest, void *src, int numqwords);
void dmemcpy(void *dest, void *src, int numdwords);
void wmemcpy(void *dest, void *src, int numwords);

int	pal_ntsc(); // returns 2 if NTSC system, 3 if PAL system.

#ifdef __cplusplus
}
#endif

#endif


