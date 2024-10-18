
extern int memdev;
extern volatile unsigned short *gp2x_memregs;
extern volatile unsigned long  *gp2x_memregl;

/* 940 core */
void pause940(int yes);
void reset940(int yes, int bank);

