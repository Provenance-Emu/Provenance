# you may or may not need to change this
#devkit_path = x:/stuff/dev/devkitgp2x/
devkit_path ?= $(HOME)/opt/devkitGP2X/
lgcc_path = $(devkit_path)lib/gcc/arm-linux/4.0.3/
CROSS = arm-linux-
#CROSS = $(devkit_path)bin/arm-linux-

# settings
#up = 1

CFLAGS += -O2 -Wall -fomit-frame-pointer -fstrict-aliasing -ffast-math
CFLAGS += -I../.. -I. -D__GP2X__ -DARM
CFLAGS += -mcpu=arm940t -mtune=arm940t
LDFLAGS = -static -s -e code940 -Ttext 0x0 -L$(lgcc_path) -lgcc

GCC = $(CROSS)gcc
STRIP = $(CROSS)strip
AS = $(CROSS)as
LD = $(CROSS)ld
OBJCOPY = $(CROSS)objcopy

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
OBJS940 += 940init.o 940.o 940ym2612.o memcpy.o misc_arm.o mp3.o
# the asm code seems to be faster when run on 920, but not on 940 for some reason
# OBJS940 += ../../Pico/sound/ym2612_asm.o

# uClibc library code
OBJS940 += uClibc/memset.o uClibc/s_floor.o uClibc/e_pow.o uClibc/e_sqrt.o uClibc/s_fabs.o
OBJS940 += uClibc/s_scalbn.o uClibc/s_copysign.o uClibc/k_sin.o uClibc/k_cos.o uClibc/s_sin.o
OBJS940 += uClibc/e_rem_pio2.o uClibc/k_rem_pio2.o uClibc/e_log.o uClibc/wrappers.o

$(BIN) : code940.elf
	@echo ">>>" $@
	$(OBJCOPY) -O binary $< $@

code940.elf : $(OBJS940) ../../common/helix/$(CROSS)helix-mp3.a
	@echo ">>>" $@
	$(LD) $^ $(LDFLAGS) -o $@ -Map code940.map

940ym2612.o : ../../../pico/sound/ym2612.c
	@echo ">>>" $@
	$(GCC) $(CFLAGS) -Os -DEXTERNAL_YM2612 -c $< -o $@

mix.o : ../../../pico/sound/mix.s
	@echo ">>>" $@
	$(GCC) $(CFLAGS) -DEXTERNAL_YM2612 -c $< -o $@
misc_arm.o : ../../../pico/misc_arm.s
	@echo ">>>" $@
	$(GCC) $(CFLAGS) -DEXTERNAL_YM2612 -c $< -o $@

../../common/helix/helix_mp3.a:
	@make -C ../../common/helix/


up: $(BIN)
	@cp -v $< /mnt/gp2x/mnt/sd/emus/PicoDrive/


# cleanup
clean: tidy
	$(RM) $(BIN)
tidy:
	$(RM) code940.elf $(OBJS940) code940.map


##
OBJSMP3T = mp3test.o ../gp2x.o ../asmutils.o ../usbjoy.o

mp3test.gpe : $(OBJSMP3T) ../helix/helix_mp3.a
	$(GCC) -static -o $@ $^
	$(STRIP) $@
	@cp -v $@ /mnt/gp2x/mnt/sd

cleanmp3test:
	$(RM) $(OBJSMP3T) mp3test.gpe

