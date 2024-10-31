AR	= iop-ar
AS	= iop-as
CC	= iop-gcc
GCC	= iop-gcc
LD	= iop-ld
NM	= iop-nm
SIZE	= iop-size
STRIP	= iop-strip
RANLIB	= iop-ranlib
OBJCOPY	= iop-objcopy
OBJDUMP	= iop-objdump
#PS2LIB = /d/proj/ps2lib-1.9

OBJ	= mcsave_irx.o 
CFLAGS	= -Wall -Werror -O2 -I$(PS2LIB)/iop/include -I$(PS2LIB)/common/include -G0 -EL -mcpu=r3000 -fomit-frame-pointer
LDFLAGS = -Wl,-s -nostdlib -L$(PS2LIB)/iop/lib -L$(PS2LIB)/iop/libkernel  -G0
LIBS	= -lkernel 
all:	mcsave.irx


mcsave.irx: $(OBJ)
	rm -f mcsave.irx
	$(CC) -o $@ $(OBJ) $(LDFLAGS) $(LIBS)

.s.o:
	$(CC) $(CFLAGS) -c $< -o $@

.c.o:
	$(CC) $(CFLAGS) -c $<


clean:
	rm -f *.o *.irx
