#ifdef __cplusplus
extern "C" {
#endif

int  DSoundInit(HWND wnd_coop, int rate, int stereo, int seg_samples);
void DSoundExit(void);
int  DSoundUpdate(const void *buff, int blocking);

extern short *DSoundNext;

#ifdef __cplusplus
}
#endif

