#ifndef FLASH_H
#define FLASH_H

#define FLASH_128K_SZ 0x20000

#ifdef __LIBRETRO__
extern void flashSaveGame(u8 *& data);
extern void flashReadGame(const u8 *& data, int);
#else
extern void flashSaveGame(gzFile _gzFile);
extern void flashReadGame(gzFile _gzFile, int version);
#endif
extern void flashReadGameSkip(gzFile _gzFile, int version);
extern u8 flashRead(u32 address);
extern void flashWrite(u32 address, u8 byte);
extern void flashDelayedWrite(u32 address, u8 byte);
#ifdef __LIBRETRO__
extern uint8_t *flashSaveMemory;
#else
extern u8 flashSaveMemory[FLASH_128K_SZ];
#endif
extern void flashSaveDecide(u32 address, u8 byte);
extern void flashReset();
extern void flashSetSize(int size);
extern void flashInit();

extern int flashSize;

#endif // FLASH_H
