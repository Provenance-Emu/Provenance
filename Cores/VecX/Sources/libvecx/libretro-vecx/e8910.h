#ifndef __E8910_H
#define __E8910_H

#include <stdint.h>

void e8910_init_sound(void);
void e8910_done_sound(void);
void e8910_callback(void* userdata, uint8_t* stream, int length);
void e8910_write(int r, int v);

int e8910_statesz(void);
void e8910_deserialize(char* dst);
void e8910_serialize(char* dst);

#endif
