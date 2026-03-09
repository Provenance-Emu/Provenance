
# ----------- release -----------
ifneq ($(findstring rel,$(MAKECMDGOALS)),)
ifeq ($(VER),)
$(error need VER)
endif
endif

include ../../config.mak

../../tools/textfilter: ../../tools/textfilter.c
	make -C ../../tools/ textfilter

readme.txt: ../../tools/textfilter ../base_readme.txt ../../ChangeLog
	../../tools/textfilter ../base_readme.txt $@ PS2

PicoDrive: ../../picodrive
	$(STRIP) $^ -o $@

PicoDrive.elf: PicoDrive
	ps2-packer $^ $@

rel: PicoDrive.elf readme.txt ../game_def.cfg
	mkdir -p out/PicoDrive/skin/ out/bin_to_cso_mp3
	cp $^ out/PicoDrive/
	cp ../../skin/* out/PicoDrive/skin/
	#mkdir -p out/bin_to_cso_mp3
	#cp ../../tools/bin_to_cso_mp3/* out/bin_to_cso_mp3/
	cd out && zip -9 -r ../../../PicoDrive_ps2_$(VER).zip *
	rm -rf out

