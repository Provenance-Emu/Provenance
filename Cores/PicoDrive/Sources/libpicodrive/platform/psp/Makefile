
# ----------- release -----------
ifneq ($(findstring rel,$(MAKECMDGOALS)),)
ifeq ($(VER),)
$(error need VER)
endif
endif

include ../../config.mak

#PSPSDK ?= $(shell psp-config --pspsdk-path)
#include $(PSPSDK)/lib/build.mak

#PSP_EBOOT_TITLE = PicoDrive
#PSP_EBOOT_ICON = data/icon.png

#EBOOT.PBP:

../../tools/textfilter: ../../tools/textfilter.c
	make -C ../../tools/ textfilter

readme.txt: ../../tools/textfilter ../base_readme.txt ../../ChangeLog
	../../tools/textfilter ../base_readme.txt $@ PSP

rel: ../../EBOOT.PBP readme.txt ../game_def.cfg
	mkdir -p out/PicoDrive/skin/ out/bin_to_cso_mp3
	cp $^ out/PicoDrive/
	cp ../../skin/* out/PicoDrive/skin/
	#mkdir -p out/bin_to_cso_mp3
	#cp ../../tools/bin_to_cso_mp3/* out/bin_to_cso_mp3/
	cd out && zip -9 -r ../../../PicoDrive_psp_$(VER).zip *
	rm -rf out
