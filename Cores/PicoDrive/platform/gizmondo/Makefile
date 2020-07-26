
# you may or may not need to change this
export CROSS = arm-wince-cegcc-

# settings
asm_memory = 1
asm_render = 1
asm_ym2612 = 1
asm_misc = 1
asm_cdpico = 1
asm_cdmemory = 1
amalgamate = 0
#profile = 1



DEFINC = -I../.. -I. -D__GIZ__ -DNO_SYNC
COPT_COMMON = -Wall -Winline
ifeq ($(DEBUG),)
COPT_COMMON += -O2 -ftracer -fomit-frame-pointer -fstrict-aliasing -ffast-math
else
COPT_COMMON += -ggdb
endif
ifeq "$(profile)" "1"
COPT_COMMON += -fprofile-generate
endif
ifeq "$(profile)" "2"
COPT_COMMON += -fprofile-use
endif
CFLAGS = $(COPT_COMMON) -mcpu=arm920t -mtune=arm920t
SFLAGS = $(CFLAGS)
ASFLAGS = -mcpu=arm920t -mfloat-abi=soft
CC = $(CROSS)gcc
STRIP = $(CROSS)strip
AS = $(CROSS)as
LD = $(CROSS)ld

# frontend
OBJS += main.o emu.o menu.o giz.o asm_utils.o

# common
OBJS += platform/common/emu.o platform/common/menu.o platform/common/fonts.o platform/common/config.o \
	platform/common/arm_utils.o platform/common/readpng.o platform/common/mp3_helix.o

# Pico
ifeq "$(amalgamate)" "1"
OBJS += picoAll.o
else
OBJS += pico/area.o pico/cart.o pico/memory.o pico/misc.o pico/pico.o pico/sek.o \
	pico/videoport.o pico/draw2.o pico/draw.o pico/z80if.o pico/patch.o pico/debug.o
# Pico - CD
OBJS += pico/cd/pico.o pico/cd/memory.o pico/cd/sek.o pico/cd/LC89510.o \
		pico/cd/cd_sys.o pico/cd/cd_file.o pico/cd/gfx_cd.o pico/cd/cue.o \
		pico/cd/area.o pico/cd/misc.o pico/cd/pcm.o pico/cd/buffering.o
endif
# Pico - Pico
OBJS += pico/pico/pico.o pico/pico/memory.o pico/pico/xpcm.o
# Pico - carthw
OBJS += pico/carthw/carthw.o pico/carthw/svp/svp.o pico/carthw/svp/memory.o \
		pico/carthw/svp/ssp16.o pico/carthw/svp/compiler.o pico/carthw/svp/stub_arm.o

# Pico - sound
ifneq "$(amalgamate)" "1"
OBJS += pico/sound/sound.o
endif
OBJS += pico/sound/mix_asm.o
OBJS += pico/sound/sn76496.o pico/sound/ym2612.o
# zlib
OBJS += zlib/gzio.o zlib/inffast.o zlib/inflate.o zlib/inftrees.o zlib/trees.o \
	zlib/deflate.o zlib/crc32.o zlib/adler32.o zlib/zutil.o zlib/compress.o
# unzip
OBJS += unzip/unzip.o unzip/unzip_stream.o
# CPU cores
# Cyclone
DEFINC += -DEMU_C68K
OBJS += cpu/Cyclone/proj/Cyclone.o cpu/Cyclone/tools/idle.o
# drz80
DEFINC += -D_USE_DRZ80
OBJS += cpu/DrZ80/drz80.o

vpath %.c = ../..
vpath %.s = ../..
vpath %.S = ../..
DIRS = platform platform/common pico pico/cd pico/pico pico/sound pico/carthw/svp \
	zlib unzip cpu cpu/musashi cpu/Cyclone/proj cpu/Cyclone/tools cpu/mz80 cpu/DrZ80


all: mkdirs PicoDrive.exe readme.txt

PicoDrive.exe : $(OBJS) ../common/helix/$(CROSS)helix-mp3.a
	@echo ">>>" $@
	$(CC) -o $@ -static $(CFLAGS) $^ -lm -lpng -Lkgsdk/ -lKGSDK -Wl,-Map=PicoDrive.map \
		2>&1 | grep -v ".idata$$4" # | grep -v "supports interworking, whereas"
ifeq ($(DEBUG),)
	$(STRIP) $@
endif
ifeq "$(profile)" "1"
	../../tools/gcda $@
endif


readme.txt: ../../tools/textfilter ../base_readme.txt
	../../tools/textfilter ../base_readme.txt $@ GIZ

include ../common/common_arm.mak


# cleanup
clean: tidy
	@$(RM) PicoDrive.exe
tidy:
	@$(RM) $(OBJS)


up: PicoDrive.exe
	synce-pcp -d 3 PicoDrive.exe ":/SD Card/emus/PicoDrive/PicoDrive.exe"

run: up
	synce-prun "/SD Card/emus/PicoDrive/PicoDrive.exe"

run_only:
	synce-prun "/SD Card/emus/PicoDrive/PicoDrive.exe"

# ----------- release -----------
ifneq ($(findstring rel,$(MAKECMDGOALS)),)
ifeq ($(VER),)
$(error need VER)
endif
endif

rel: PicoDrive.exe kgsdk/ARMV4IRel/KGSDK.dll ../game_def.cfg readme.txt
	zip -9 -j ../../PicoDrive_giz_$(VER).zip $^
	ln -s ../gp2x/skin skin
	zip -9 -r ../../PicoDrive_giz_$(VER).zip skin -i \*.png -i \*.txt
	rm skin

