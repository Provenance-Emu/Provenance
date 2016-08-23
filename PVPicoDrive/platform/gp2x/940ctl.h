void sharedmem940_init(void);
void sharedmem940_finish(void);

void YM2612Init_940(int baseclock, int rate);
void YM2612ResetChip_940(void);
int  YM2612UpdateOne_940(int *buffer, int length, int stereo, int is_buf_empty);

int  YM2612Write_940(unsigned int a, unsigned int v, int scanline);

int  YM2612PicoTick_940(int n);
void YM2612PicoStateLoad_940(void);
void YM2612PicoStateSave2_940(int tat, int tbt);
int  YM2612PicoStateLoad2_940(int *tat, int *tbt);
