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

TARGET = netplay.irx
PS2SMAP=$(PS2DEV)/ps2eth

SOURCE  = 
SOURCE += ../../Source/common ../../Source/ps2/iop

INCLUDE = -I../../Source/common -I../../Source/ps2/common  -I../../Source/ps2/iop


OBJ	= netplay_iop.o netserver.o netsys.o netclient.o netsocket.o netprint.o netpacket.o netqueue.o
CFLAGS	= -O2 -Werror -Wall -I$(PS2LIB)/iop/include -I$(PS2LIB)/common/include -I$(PS2IP)/include $(INCLUDE) -G0 -EL -mcpu=r3000 -fomit-frame-pointer
LDFLAGS = -Wl,-s -nostdlib -L$(PS2LIB)/iop/lib -L$(PS2LIB)/iop/libkernel -L$(PS2IP)/iop/lib  -L$(PS2SMAP)/lib -G0
LIBS	= -lkernel -liop_ps2ip
all: $(TARGET)


vpath % $(SOURCE)

$(TARGET): $(OBJ)
	rm -f $(TARGET)
	$(CC) -o $@ $(OBJ) $(LDFLAGS) $(LIBS)

.s.o:
	$(CC) $(CFLAGS) -c $< -o $@

.c.o:
	$(CC) $(CFLAGS) -c $<


clean:
	rm -f *.o *.irx $(TARGET)
