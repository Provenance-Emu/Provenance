#ifndef RTC_H
#define RTC_H

u16 rtcRead(u32 address);
bool rtcWrite(u32 address, u16 value);
void rtcEnable(bool);
bool rtcIsEnabled();
void rtcReset();

#ifdef __LIBRETRO__
void rtcReadGame(const u8 *&data);
void rtcSaveGame(u8 *&data);
#else
void rtcReadGame(gzFile gzFile);
void rtcSaveGame(gzFile gzFile);
#endif

#endif // RTC_H
