# you may or may not need to change this
lgcc_path = $(HOME)/opt/open2x/gcc-4.1.1-glibc-2.3.6/lib/gcc/arm-open2x-linux/4.1.1/
CROSS_COMPILE ?= arm-none-eabi-

# settings
#up = 1

CFLAGS += -O3 -Wall -mno-thumb-interwork -fstrict-aliasing -fno-stack-protector -fno-common -ffast-math
CFLAGS += -I../../common/helix/pub -I../../.. -I. -D__GP2X__ -DARM
CFLAGS += -mcpu=arm940t -mtune=arm940t -mabi=apcs-gnu -mfloat-abi=soft -mfpu=fpa
LDFLAGS = -static -e code940 -Ttext 0x0 -L$(lgcc_path) -lgcc

GCC = $(CROSS_COMPILE)gcc
STRIP = $(CROSS_COMPILE)strip
AS = $(CROSS_COMPILE)as
LD = $(CROSS_COMPILE)ld
OBJCOPY = $(CROSS_COMPILE)objcopy

vpath %.c = ../../common

BIN = pico940_v3.bin

all: $(BIN)

.c.o:
	@echo ">>>" $<
	$(GCC) $(CFLAGS) -c $< -o $@
.s.o:
	@echo ">>>" $<
	$(GCC) $(CFLAGS) -c $< -o $@


# stuff for 940 core

# init, emu_control, emu
OBJS940 += 940init.o 940.o 940ym2612.o misc_arm.o mp3_sync.o
# the asm memcpy code crashes job LOAD2 on 940. Possibly a globbered reg?
# OBJS940 += memcpy.o
# the asm code seems to be faster when run on 920, but not on 940 for some reason
# OBJS940 += ../../Pico/sound/ym2612_asm.o

# uClibc library code
OBJS940 += uClibc/memset.o uClibc/s_floor.o uClibc/e_pow.o uClibc/e_sqrt.o uClibc/s_fabs.o
OBJS940 += uClibc/s_scalbn.o uClibc/s_copysign.o uClibc/k_sin.o uClibc/k_cos.o uClibc/s_sin.o
OBJS940 += uClibc/e_rem_pio2.o uClibc/k_rem_pio2.o uClibc/e_log.o uClibc/wrappers.o
LIBHELIX ?= ../../common/helix/$(notdir $(CROSS_COMPILE))helix_mp3.a

$(BIN) : code940.elf
	@echo ">>>" $@
	$(OBJCOPY) -O binary $< $@

code940.elf : $(OBJS940) $(LIBHELIX)
	@echo ">>>" $@
	$(LD) $^ $(LDFLAGS) -o $@ -Map code940.map

940ym2612.o : ../../../pico/sound/ym2612.c
	@echo ">>>" $@
	$(GCC) $(CFLAGS) -Os -DEXTERNAL_YM2612 -c $< -o $@

misc_arm.o : ../../../pico/misc_arm.s
	@echo ">>>" $@
	$(GCC) $(CFLAGS) -DEXTERNAL_YM2612 -c $< -o $@

mp3_sync.o: ../../common/mp3_sync.c
	@echo ">>>" $@
	$(GCC) $(CFLAGS) -Os -DCODE940 -c $< -o $@

$(LIBHELIX):
	@$(MAKE) -C ../../common/helix/ CROSS_COMPILE=$(CROSS_COMPILE)


up: $(BIN)
	@cp -v $< /mnt/gp2x/mnt/sd/emus/PicoDrive/


# cleanup
clean: tidy
	$(RM) $(BIN)
tidy:
	$(RM) code940.elf $(OBJS940) code940.map


##
OBJSMP3T = mp3test.o ../gp2x.o ../asmutils.o ../usbjoy.o

mp3test.gpe : $(OBJSMP3T) $(LIBHELIX)
	$(GCC) -static -o $@ $^
	$(STRIP) $@
	@cp -v $@ /mnt/gp2x/mnt/sd

cleanmp3test:
	$(RM) $(OBJSMP3T) mp3test.gpe

