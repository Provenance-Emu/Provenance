# release packaging makefile

VER := $(shell head -n 1 ../common/version.h | \
	sed 's/.*"\(.*\)\.\(.*\)".*/\1\2/g')
BUILD := $(shell git describe HEAD | grep -- - | \
	sed -e 's/.*\-\(.*\)\-.*/\1/')
ifneq "$(BUILD)" ""
VER := $(VER)_$(BUILD)
endif

all: rel

../../tools/textfilter: ../../tools/textfilter.c
	make -C ../../tools/

readme.txt: ../../tools/textfilter ../base_readme.txt ../../ChangeLog
	../../tools/textfilter ../base_readme.txt $@ GP2X

CODE940 = code940/pico940_v3.bin

rel: ../../PicoDrive PicoDrive.gpe $(CODE940) readme.txt ../game_def.cfg \
		PicoDrive.png PicoDrive_s.png PicoDrive_t.png \
		warm_2.4.25.o warm_2.4.26-open2x.o warm_2.6.24.ko \
		../../pico/carthw.cfg
	mkdir -p out/PicoDrive/skin/
	cp $^ out/PicoDrive/
	cp PicoDrive.ini out/
	cp skin/*.png out/PicoDrive/skin/
	cp skin/*.txt out/PicoDrive/skin/
	#mkdir out/bin_to_cso_mp3
	#cp ../../tools/bin_to_cso_mp3/* out/bin_to_cso_mp3/
	cd out && zip -9 -r ../../../PicoDrive_$(VER).zip *
	rm -rf out

$(CODE940):
	make -C code940/
