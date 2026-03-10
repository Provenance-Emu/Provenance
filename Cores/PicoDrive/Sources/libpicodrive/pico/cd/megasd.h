/*
 * PicoDrive
 * (C) irixxxx, 2024
 *
 * MEGASD enhancement support as "documented" in "MegaSD DEV Manual Rev.2"
 */

struct megasd {
  // modifiable fields visible through the interface
  u16 data[0x800/2];
  u16 command;
  u16 result;

  // internal state
  s8 state;                             // CD drive has been initialized

  s8 loop;                              // playback should loop?
  s16 index;                            // >= 0 if playing audio
  s32 startlba, endlba, looplba;        // lba's for playback

  s32 readlba;                          // >= 0 if reading data

  s32 currentlba;                       // lba currently playing

  s32 pad[7];
};

#define MSD_ST_INIT     1
#define MSD_ST_PLAY     2
#define MSD_ST_PAUSE    4

extern struct megasd Pico_msd;


extern void msd_update(void);		// 75Hz update, like CDD irq
extern void msd_reset(void);		// reset state

extern void msd_write8(u32 a, u32 d);	// interface
extern void msd_write16(u32 a, u32 d);
