CROSS_COMPILE ?= arm-linux-gnueabi-

CC = $(CROSS_COMPILE)gcc
AS = $(CROSS_COMPILE)as
AR = $(CROSS_COMPILE)ar
TOOLCHAIN = $(notdir $(CROSS_COMPILE))
LIBGCC ?= ${HOME}/opt/open2x/gcc-4.1.1-glibc-2.3.6/lib/gcc/arm-open2x-linux/4.1.1/libgcc.a

CFLAGS += -Ipub -O2 -Wall -fstrict-aliasing -ffast-math
ifneq ($(findstring arm-,$(TOOLCHAIN)),)
CFLAGS += -mcpu=arm940t -mtune=arm940t -mfloat-abi=soft -mfpu=fpa -mabi=apcs-gnu -mno-thumb-interwork
ASFLAGS = -mcpu=arm940t -mfloat-abi=soft -mfpu=fpa -mabi=apcs-gnu
OBJS += real/arm/asmpoly_gcc.o
else
CFLAGS += -m32
ASFLAGS += -m32
OBJS += real/polyphase.o
endif

LIB = $(TOOLCHAIN)helix_mp3.a
SHLIB = $(TOOLCHAIN)helix_mp3.so

all: $(LIB) $(SHLIB)


OBJS += mp3dec.o mp3tabs.o
#OBJS += ipp/bitstream.o ipp/buffers.o ipp/dequant.o ipp/huffman.o ipp/imdct.o ipp/subband.o
OBJS += real/bitstream.o real/buffers.o real/dct32.o real/dequant.o real/dqchan.o real/huffman.o
OBJS += real/hufftabs.o real/imdct.o real/scalfact.o real/stproc.o real/subband.o real/trigtabs.o

OBJS += lib.o

real/arm/asmpoly_gcc.o: real/arm/asmpoly_gcc.s
	$(CC) -o $@ $(ASFLAGS) -c $<

$(LIB) : $(OBJS)
	$(AR) r $@ $^
$(SHLIB) : $(OBJS) $(LIBGCC)
	$(CC) -o $@ -nostdlib -shared $(CFLAGS) $^

clean:
	$(RM) -f $(OBJS)

