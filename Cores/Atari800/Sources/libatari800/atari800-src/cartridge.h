#ifndef CARTRIDGE_H_
#define CARTRIDGE_H_

#include "config.h"
#include "atari.h"

enum {
	CARTRIDGE_UNKNOWN        = -1,
	CARTRIDGE_NONE           =  0,
	CARTRIDGE_STD_8          =  1,
	CARTRIDGE_STD_16         =  2,
	CARTRIDGE_OSS_034M_16    =  3,
	CARTRIDGE_5200_32        =  4,
	CARTRIDGE_DB_32          =  5,
	CARTRIDGE_5200_EE_16     =  6,
	CARTRIDGE_5200_40        =  7,
	CARTRIDGE_WILL_64        =  8,
	CARTRIDGE_EXP_64         =  9,
	CARTRIDGE_DIAMOND_64     = 10,
	CARTRIDGE_SDX_64         = 11,
	CARTRIDGE_XEGS_32        = 12,
	CARTRIDGE_XEGS_07_64     = 13,
	CARTRIDGE_XEGS_128       = 14,
	CARTRIDGE_OSS_M091_16    = 15,
	CARTRIDGE_5200_NS_16     = 16,
	CARTRIDGE_ATRAX_128      = 17,
	CARTRIDGE_BBSB_40        = 18,
	CARTRIDGE_5200_8         = 19,
	CARTRIDGE_5200_4         = 20,
	CARTRIDGE_RIGHT_8        = 21,
	CARTRIDGE_WILL_32        = 22,
	CARTRIDGE_XEGS_256       = 23,
	CARTRIDGE_XEGS_512       = 24,
	CARTRIDGE_XEGS_1024      = 25,
	CARTRIDGE_MEGA_16        = 26,
	CARTRIDGE_MEGA_32        = 27,
	CARTRIDGE_MEGA_64        = 28,
	CARTRIDGE_MEGA_128       = 29,
	CARTRIDGE_MEGA_256       = 30,
	CARTRIDGE_MEGA_512       = 31,
	CARTRIDGE_MEGA_1024      = 32,
	CARTRIDGE_SWXEGS_32      = 33,
	CARTRIDGE_SWXEGS_64      = 34,
	CARTRIDGE_SWXEGS_128     = 35,
	CARTRIDGE_SWXEGS_256     = 36,
	CARTRIDGE_SWXEGS_512     = 37,
	CARTRIDGE_SWXEGS_1024    = 38,
	CARTRIDGE_PHOENIX_8      = 39,
	CARTRIDGE_BLIZZARD_16    = 40,
	CARTRIDGE_ATMAX_128      = 41,
	CARTRIDGE_ATMAX_1024     = 42,
	CARTRIDGE_SDX_128        = 43,
	CARTRIDGE_OSS_8          = 44,
	CARTRIDGE_OSS_043M_16    = 45,
	CARTRIDGE_BLIZZARD_4     = 46,
	CARTRIDGE_AST_32         = 47,
	CARTRIDGE_ATRAX_SDX_64   = 48,
	CARTRIDGE_ATRAX_SDX_128  = 49,
	CARTRIDGE_TURBOSOFT_64   = 50,
	CARTRIDGE_TURBOSOFT_128  = 51,
	CARTRIDGE_ULTRACART_32   = 52,
	CARTRIDGE_LOW_BANK_8     = 53,
	CARTRIDGE_SIC_128        = 54,
	CARTRIDGE_SIC_256        = 55,
	CARTRIDGE_SIC_512        = 56,
	CARTRIDGE_STD_2          = 57,
	CARTRIDGE_STD_4          = 58,
	CARTRIDGE_RIGHT_4        = 59,
	CARTRIDGE_BLIZZARD_32    = 60,
	CARTRIDGE_MEGAMAX_2048   = 61,
	CARTRIDGE_THECART_128M   = 62,
	CARTRIDGE_MEGA_4096      = 63,
	CARTRIDGE_MEGA_2048      = 64,
	CARTRIDGE_THECART_32M    = 65,
	CARTRIDGE_THECART_64M    = 66,
	CARTRIDGE_XEGS_8F_64     = 67,
	CARTRIDGE_LAST_SUPPORTED = 67
};

#define CARTRIDGE_MAX_SIZE	(128 * 1024 * 1024)
extern int const CARTRIDGE_kb[CARTRIDGE_LAST_SUPPORTED + 1];

#define CARTRIDGE_STD_8_DESC         "Standard 8 KB cartridge"
#define CARTRIDGE_STD_16_DESC        "Standard 16 KB cartridge"
#define CARTRIDGE_OSS_034M_16_DESC   "OSS two chip 16 KB cartridge (034M)"
#define CARTRIDGE_5200_32_DESC       "Standard 32 KB 5200 cartridge"
#define CARTRIDGE_DB_32_DESC         "DB 32 KB cartridge"
#define CARTRIDGE_5200_EE_16_DESC    "Two chip 16 KB 5200 cartridge"
#define CARTRIDGE_5200_40_DESC       "Bounty Bob 40 KB 5200 cartridge"
#define CARTRIDGE_WILL_64_DESC       "64 KB Williams cartridge"
#define CARTRIDGE_EXP_64_DESC        "Express 64 KB cartridge"
#define CARTRIDGE_DIAMOND_64_DESC    "Diamond 64 KB cartridge"
#define CARTRIDGE_SDX_64_DESC        "SpartaDOS X 64 KB cartridge"
#define CARTRIDGE_XEGS_32_DESC       "XEGS 32 KB cartridge"
#define CARTRIDGE_XEGS_07_64_DESC    "XEGS 64 KB cartridge (banks 0-7)"
#define CARTRIDGE_XEGS_128_DESC      "XEGS 128 KB cartridge"
#define CARTRIDGE_OSS_M091_16_DESC   "OSS one chip 16 KB cartridge"
#define CARTRIDGE_5200_NS_16_DESC    "One chip 16 KB 5200 cartridge"
#define CARTRIDGE_ATRAX_128_DESC     "Atrax 128 KB cartridge"
#define CARTRIDGE_BBSB_40_DESC       "Bounty Bob 40 KB cartridge"
#define CARTRIDGE_5200_8_DESC        "Standard 8 KB 5200 cartridge"
#define CARTRIDGE_5200_4_DESC        "Standard 4 KB 5200 cartridge"
#define CARTRIDGE_RIGHT_8_DESC       "Right slot 8 KB cartridge"
#define CARTRIDGE_WILL_32_DESC       "32 KB Williams cartridge"
#define CARTRIDGE_XEGS_256_DESC      "XEGS 256 KB cartridge"
#define CARTRIDGE_XEGS_512_DESC      "XEGS 512 KB cartridge"
#define CARTRIDGE_XEGS_1024_DESC     "XEGS 1 MB cartridge"
#define CARTRIDGE_MEGA_16_DESC       "MegaCart 16 KB cartridge"
#define CARTRIDGE_MEGA_32_DESC       "MegaCart 32 KB cartridge"
#define CARTRIDGE_MEGA_64_DESC       "MegaCart 64 KB cartridge"
#define CARTRIDGE_MEGA_128_DESC      "MegaCart 128 KB cartridge"
#define CARTRIDGE_MEGA_256_DESC      "MegaCart 256 KB cartridge"
#define CARTRIDGE_MEGA_512_DESC      "MegaCart 512 KB cartridge"
#define CARTRIDGE_MEGA_1024_DESC     "MegaCart 1 MB cartridge"
#define CARTRIDGE_SWXEGS_32_DESC     "Switchable XEGS 32 KB cartridge"
#define CARTRIDGE_SWXEGS_64_DESC     "Switchable XEGS 64 KB cartridge"
#define CARTRIDGE_SWXEGS_128_DESC    "Switchable XEGS 128 KB cartridge"
#define CARTRIDGE_SWXEGS_256_DESC    "Switchable XEGS 256 KB cartridge"
#define CARTRIDGE_SWXEGS_512_DESC    "Switchable XEGS 512 KB cartridge"
#define CARTRIDGE_SWXEGS_1024_DESC   "Switchable XEGS 1 MB cartridge"
#define CARTRIDGE_PHOENIX_8_DESC     "Phoenix 8 KB cartridge"
#define CARTRIDGE_BLIZZARD_16_DESC   "Blizzard 16 KB cartridge"
#define CARTRIDGE_ATMAX_128_DESC     "Atarimax 128 KB Flash cartridge"
#define CARTRIDGE_ATMAX_1024_DESC    "Atarimax 1 MB Flash cartridge"
#define CARTRIDGE_SDX_128_DESC       "SpartaDOS X 128 KB cartridge"
#define CARTRIDGE_OSS_8_DESC         "OSS 8 KB cartridge"
#define CARTRIDGE_OSS_043M_16_DESC   "OSS two chip 16 KB cartridge (043M)"
#define CARTRIDGE_BLIZZARD_4_DESC    "Blizzard 4 KB cartridge"
#define CARTRIDGE_AST_32_DESC        "AST 32 KB cartridge"
#define CARTRIDGE_ATRAX_SDX_64_DESC  "Atrax SDX 64 KB cartridge"
#define CARTRIDGE_ATRAX_SDX_128_DESC "Atrax SDX 128 KB cartridge"
#define CARTRIDGE_TURBOSOFT_64_DESC  "Turbosoft 64 KB cartridge"
#define CARTRIDGE_TURBOSOFT_128_DESC "Turbosoft 128 KB cartridge"
#define CARTRIDGE_ULTRACART_32_DESC  "Ultracart 32 KB cartridge"
#define CARTRIDGE_LOW_BANK_8_DESC    "Low bank 8 KB cartridge"
#define CARTRIDGE_SIC_128_DESC       "SIC! 128 KB cartridge"
#define CARTRIDGE_SIC_256_DESC       "SIC! 256 KB cartridge"
#define CARTRIDGE_SIC_512_DESC       "SIC! 512 KB cartridge"
#define CARTRIDGE_STD_2_DESC         "Standard 2 KB cartridge"
#define CARTRIDGE_STD_4_DESC         "Standard 4 KB cartridge"
#define CARTRIDGE_RIGHT_4_DESC       "Right slot 4 KB cartridge"
#define CARTRIDGE_BLIZZARD_32_DESC   "Blizzard 32 KB cartridge"
#define CARTRIDGE_MEGAMAX_2048_DESC  "MegaMax 2 MB cartridge"
#define CARTRIDGE_THECART_128M_DESC  "The!Cart 128 MB cartridge"
#define CARTRIDGE_MEGA_4096_DESC     "Flash MegaCart 4 MB cartridge"
#define CARTRIDGE_MEGA_2048_DESC     "MegaCart 2 MB cartridge"
#define CARTRIDGE_THECART_32M_DESC   "The!Cart 32 MB cartridge"
#define CARTRIDGE_THECART_64M_DESC   "The!Cart 64 MB cartridge"
#define CARTRIDGE_XEGS_8F_64_DESC    "XEGS 64 KB cartridge (banks 8-15)"

/* Indicates whether the emulator should automatically reboot (coldstart)
   after inserting/removing a cartridge. (Doesn't affect the piggyback
   cartridge - in this case system will never autoreboot.) */
extern int CARTRIDGE_autoreboot;

typedef struct CARTRIDGE_image_t {
	int type;
	int state; /* Cartridge's state, such as selected bank or switch on/off. */
	int size; /* Size of the image, in kilobytes */
	UBYTE *image;
	char filename[FILENAME_MAX];
} CARTRIDGE_image_t;

extern CARTRIDGE_image_t CARTRIDGE_main;
extern CARTRIDGE_image_t CARTRIDGE_piggyback;

int CARTRIDGE_Checksum(const UBYTE *image, int nbytes);

int CARTRIDGE_ReadConfig(char *string, char *ptr);
void CARTRIDGE_WriteConfig(FILE *fp);
int CARTRIDGE_Initialise(int *argc, char *argv[]);
void CARTRIDGE_Exit(void);

#define CARTRIDGE_CANT_OPEN		-1	/* Can't open cartridge image file */
#define CARTRIDGE_BAD_FORMAT		-2	/* Unknown cartridge format */
#define CARTRIDGE_BAD_CHECKSUM	-3	/* Warning: bad CART checksum */
/* Inserts the left cartrifge. */
int CARTRIDGE_Insert(const char *filename);
/* Inserts the left cartridge and reboots the system if needed. */
int CARTRIDGE_InsertAutoReboot(const char *filename);
/* Inserts the piggyback cartridge. */
int CARTRIDGE_Insert_Second(const char *filename);
/* When the cartridge type is CARTRIDGE_UNKNOWN after a call to
   CARTRIDGE_Insert(), this function should be called to set the
   cartridge's type manually to a value chosen by user. */
void CARTRIDGE_SetType(CARTRIDGE_image_t *cart, int type);
/* Sets type of the cartridge and reboots the system if needed. */
void CARTRIDGE_SetTypeAutoReboot(CARTRIDGE_image_t *cart, int type);

/* Removes the left cartridge. */
void CARTRIDGE_Remove(void);
/* Removes the left cartridge and reboots the system if needed. */
void CARTRIDGE_RemoveAutoReboot(void);
/* Removed the piggyback cartridge. */
void CARTRIDGE_Remove_Second(void);

/* Called on system coldstart. Resets the states of mounted cartridges. */
void CARTRIDGE_ColdStart(void);

UBYTE CARTRIDGE_GetByte(UWORD addr, int no_side_effects);
void CARTRIDGE_PutByte(UWORD addr, UBYTE byte);
void CARTRIDGE_BountyBob1(UWORD addr);
void CARTRIDGE_BountyBob2(UWORD addr);
void CARTRIDGE_StateSave(void);
void CARTRIDGE_StateRead(UBYTE version);
#ifdef PAGED_ATTRIB
UBYTE CARTRIDGE_BountyBob1GetByte(UWORD addr, int no_side_effects);
UBYTE CARTRIDGE_BountyBob2GetByte(UWORD addr, int no_side_effects);
void CARTRIDGE_BountyBob1PutByte(UWORD addr, UBYTE value);
void CARTRIDGE_BountyBob2PutByte(UWORD addr, UBYTE value);
#endif

#endif /* CARTRIDGE_H_ */
