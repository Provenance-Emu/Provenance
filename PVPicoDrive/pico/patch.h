#ifndef _GENIE_DECODE_H__
#define _GENIE_DECODE_H__

#ifdef __cplusplus
extern "C" {
#endif

struct patch_inst
{
	char code[12];
	char name[52];
	unsigned int active;
	unsigned int addr;
	unsigned short data;
	unsigned short data_old;
};

extern struct patch_inst *PicoPatches;
extern int PicoPatchCount;

int  PicoPatchLoad(const char *fname);
void PicoPatchUnload(void);
void PicoPatchPrepare(void);
void PicoPatchApply(void);


#ifdef __cplusplus
} // extern "C"
#endif

#endif // _GENIE_DECODE_H__
