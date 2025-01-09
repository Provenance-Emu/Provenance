
char *PDebugMain(void);
char *PDebug32x(void);
char *PDebugSpriteList(void);
void PDebugShowSpriteStats(unsigned short *screen, int stride);
void PDebugShowPalette(unsigned short *screen, int stride);
void PDebugShowSprite(unsigned short *screen, int stride, int which);
void PDebugDumpMem(void);
void PDebugZ80Frame(void);
void PDebugCPUStep(void);

#if defined(CPU_CMP_R) || defined(CPU_CMP_W) || defined(DRC_CMP)
enum ctl_byte {
  CTL_68K_SLAVE = 0x02,
  CTL_68K_PC = 0x04,
  CTL_68K_SR = 0x05,
  CTL_68K_CYCLES = 0x06,
  CTL_68K_R = 0x10, // .. 0x20
  CTL_MASTERSLAVE = 0x80,
  CTL_EA = 0x82,
  CTL_EAVAL = 0x83,
  CTL_M68KPC = 0x84,
  CTL_CYCLES = 0x85,
  CTL_SH2_R = 0x90, // .. 0xa8
};

void tl_write(const void *ptr, size_t size);
void tl_write_uint(unsigned char ctl, unsigned int v);
int tl_read(void *ptr, size_t size);
int tl_read_uint(void *ptr);
#endif
