#ifndef __E6809_H
#define __E6809_H

/* user defined read and write functions */

extern unsigned char (*e6809_read8) (unsigned address);
extern void (*e6809_write8) (unsigned address, unsigned char data);

void e6809_reset(void);
unsigned e6809_sstep(unsigned irq_i, unsigned irq_f);

int e6809_statesz(void);
void e6809_serialize(char* ary);
void e6809_deserialize(char * ary);

#endif
