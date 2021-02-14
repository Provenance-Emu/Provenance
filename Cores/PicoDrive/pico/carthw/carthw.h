
/* svp */
#include "svp/ssp16.h"

typedef struct {
	unsigned char iram_rom[0x20000]; // IRAM (0-0x7ff) and program ROM (0x800-0x1ffff)
	unsigned char dram[0x20000];
	ssp1601_t ssp1601;
} svp_t;

extern svp_t *svp;

void PicoSVPInit(void);
void PicoSVPStartup(void);
void PicoSVPMemSetup(void);

/* misc */
void carthw_ssf2_startup(void);
void carthw_Xin1_startup(void);
void carthw_realtec_startup(void);
void carthw_radica_startup(void);
void carthw_pier_startup(void);

void carthw_sprot_startup(void);
void carthw_sprot_new_location(unsigned int a,
	unsigned int mask, unsigned short val, int is_ro);

void carthw_prot_lk3_startup(void);
