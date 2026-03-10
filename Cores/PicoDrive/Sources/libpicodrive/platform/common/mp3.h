#ifndef __COMMON_MP3_H__
#define __COMMON_MP3_H__

#include <stdio.h>

int mp3_find_sync_word(const unsigned char *buf, int size);

/* decoder */
int mp3dec_start(FILE *f, int fpos_start);
int mp3dec_decode(FILE *f, int *file_pos, int file_len);

extern unsigned short mpeg1_l3_bitrates[16];

#ifdef __GP2X__
int _mp3dec_start(FILE *f, int fpos_start);
int _mp3dec_decode(FILE *f, int *file_pos, int file_len);
#endif

#endif // __COMMON_MP3_H__
