
# pspdev is expected to be in path
PSPSDK = $(shell psp-config --pspsdk-path)

# settings
#use_musashi = 1
#use_mz80 = 1
amalgamate = 0
for_15fw = 1
# :!touch platform/psp/psp.c


CFLAGS += -I../.. -I. -DNO_SYNC -D_ASM_DRAW_C_AMIPS
CFLAGS += -Wall -Winline -G0
#CFLAGS += -DLPRINTF_STDIO
#CFLAGS += -pg
ifeq ($(DEBUG),)
CFLAGS += -O2 -ftracer -fstrength-reduce -ffast-math
else
CFLAGS += -ggdb
endif
ifeq "$(for_15fw)" "1"
CFLAGS += -DFW15
endif


# frontend and stuff
OBJS += main.o emu.o mp3.o menu.o psp.o asm_utils.o

# common
OBJS += platform/common/emu.o platform/common/menu.o platform/common/fonts.o platform/common/config.o platform/common/readpng.o

# Pico
ifeq "$(amalgamate)" "1"
OBJS += ../../picoAll.o
else
OBJS += pico/area.o pico/cart.o pico/memory.o pico/misc.o pico/pico.o pico/sek.o pico/videoport.o \
	pico/draw2.o pico/draw.o pico/z80if.o pico/patch.o pico/draw_amips.o pico/memory_amips.o \
	pico/misc_amips.o pico/debug.o
# Pico - CD
OBJS += pico/cd/pico.o pico/cd/memory.o pico/cd/sek.o pico/cd/LC89510.o \
		pico/cd/cd_sys.o pico/cd/cd_file.o pico/cd/cue.o pico/cd/gfx_cd.o \
		pico/cd/area.o pico/cd/misc.o pico/cd/pcm.o pico/cd/buffering.o
# Pico - carthw
OBJS += pico/carthw/carthw.o pico/carthw/svp/svp.o pico/carthw/svp/memory.o \
		pico/carthw/svp/ssp16.o
# Pico - Pico
OBJS += pico/pico/pico.o pico/pico/memory.o pico/pico/xpcm.o
endif

# Pico - sound
ifneq "$(amalgamate)" "1"
OBJS += pico/sound/sound.o
endif
OBJS += pico/sound/mix.o
OBJS += pico/sound/sn76496.o pico/sound/ym2612.o
# zlib (hacked)
OBJS += zlib/gzio.o zlib/inffast.o zlib/inflate.o zlib/inftrees.o zlib/trees.o \
	zlib/deflate.o zlib/crc32.o zlib/adler32.o zlib/zutil.o zlib/compress.o \
	zlib/uncompr.o
# unzip
OBJS += unzip/unzip.o unzip/unzip_stream.o
# CPU cores
ifeq "$(use_musashi)" "1"
CFLAGS += -DEMU_M68K
OBJS += cpu/musashi/m68kops.o cpu/musashi/m68kcpu.o
else
CFLAGS += -DEMU_F68K
OBJS += cpu/fame/famec.o
endif
# z80
ifeq "$(use_mz80)" "1"
CFLAGS += -D_USE_MZ80
OBJS += cpu/mz80/mz80.o
else
CFLAGS += -D_USE_CZ80
OBJS += cpu/cz80/cz80.o
endif
# bg images
OBJS += data/bg32.o data/bg40.o

vpath %.c = ../..
vpath %.s = ../..
DIRS = platform platform/psp platform/common pico pico/cd pico/pico pico/sound pico/carthw/svp \
	zlib unzip cpu cpu/musashi cpu/fame cpu/mz80 cpu/cz80


LIBS += -lpng -lm -lpspgu -lpsppower -lpspaudio -lpsprtc -lpspaudiocodec -lpspkubridge
#LIBS += -lpspprof
LDFLAGS += -Wl,-Map=PicoDrive.map


# target
TARGET = PicoDrive
EXTRA_TARGETS = mkdirs EBOOT.PBP
PSP_EBOOT_TITLE = PicoDrive
PSP_EBOOT_ICON = data/icon.png
#PSP_EBOOT_PIC1 = .png
ifneq "$(for_15fw)" "1"
BUILD_PRX = 1
endif

CUSTOM_CLEAN = myclean

include $(PSPSDK)/lib/build.mak

# some additional rules
mkdirs:
	mkdir -p $(DIRS)

.c.o:
	@echo ">>>" $<
	$(CC) $(CFLAGS) -c $< -o $@

AS := psp-as

.s.o:
	@echo ">>>" $<
	$(AS) -march=allegrex -mtune=allegrex $< -o $@

../../cpu/musashi/m68kops.c :
	make -C ../../cpu/musashi

cpu/fame/famec.o : ../../cpu/fame/famec.c
	@echo ">>>" $<
	$(CC) $(CFLAGS) -Wno-unused -c $< -o $@

pico/misc.o : ../../pico/misc.c
	@echo ">>>" $<
	$(CC) $(CFLAGS) -c $< -o $@ -D_ASM_MISC_C_AMIPS

pico/memory.o : ../../pico/memory.c
	@echo ">>>" $<
	$(CC) $(CFLAGS) -O2 -c $< -o $@ -D_ASM_MEMORY_C -D_ASM_MEMORY_C_AMIPS

pico/cd/memory.o : ../../pico/cd/memory.c
	@echo ">>>" $<
	$(CC) $(CFLAGS) -O2 -c $< -o $@

pico/cd/gfx_cd.o : ../../pico/cd/gfx_cd.c
	@echo ">>>" $<
	$(CC) $(CFLAGS) -O2 -c $< -o $@

readme.txt: ../../tools/textfilter ../base_readme.txt
	../../tools/textfilter ../base_readme.txt $@ PSP

../../tools/textfilter: ../../tools/textfilter.c
	make -C ../../tools/ textfilter

data/bg32.o: data/bg32.bin
	bin2o -i $< $@ bgdatac32

data/bg40.o: data/bg40.bin
	bin2o -i $< $@ bgdatac40

#
ifndef UPDIR
UPDIR = /media/disk/PSP/GAME/PicoDrive/
endif
up: EBOOT.PBP
	@cp -v $^ $(UPDIR)


# cleanup

myclean:
	#rm -rf $(DIRS)
	$(RM) PicoDrive.map
	make -C ../../cpu/musashi clean


clean_prof:
	find ../.. -name '*.gcno' -delete
	find ../.. -name '*.gcda' -delete

# ----------- release -----------
ifneq ($(findstring rel,$(MAKECMDGOALS)),)
ifeq ($(VER),)
$(error need VER)
endif
endif

# ?
rel: EBOOT.PBP readme.txt ../game_def.cfg
	mkdir -p PicoDrive/skin/
	cp $^ PicoDrive/
	cp skin/* PicoDrive/skin/
	zip -9 -r ../../PicoDrive_psp_$(VER).zip PicoDrive
	rm -rf PicoDrive
	mkdir bin_to_cso_mp3
	cp ../../tools/bin_to_cso_mp3/* bin_to_cso_mp3/
	zip -9 -r ../../PicoDrive_psp_$(VER).zip bin_to_cso_mp3
	rm -rf bin_to_cso_mp3

rel_kxploit: readme.txt ../game_def.cfg
	mkdir -p PicoDrive/skin/
	cp $^ PicoDrive/
	cp skin/* PicoDrive/skin/
	zip -9 -r ../../PicoDrive_psp_$(VER)_kxploit.zip PicoDrive
	zip -9 -r ../../PicoDrive_psp_$(VER)_kxploit.zip PicoDrive%
	mkdir bin_to_cso_mp3
	cp ../../tools/bin_to_cso_mp3/* bin_to_cso_mp3/
	zip -9 -r ../../PicoDrive_psp_$(VER)_kxploit.zip bin_to_cso_mp3
	rm -rf bin_to_cso_mp3

