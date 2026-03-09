# release packaging makefile

VER := $(shell head -n 1 ../common/version.h | \
	sed 's/[^0-9]*\([0-9]*\)\.\([0-9]*\).*/\1\2/g')
BUILD := $(shell git describe HEAD | grep -- - | \
	sed -e 's/.*\-\(.*\)\-.*/\1/')
ifneq "$(BUILD)" ""
VER := $(VER)_$(BUILD)
endif

include ../../config.mak

PND_MAKE ?= pnd_make

all: rel

../../tools/textfilter: ../../tools/textfilter.c
	make -C ../../tools/ textfilter

#readme.txt: ../../tools/textfilter ../base_readme.txt ../../ChangeLog
#	../../tools/textfilter ../base_readme.txt $@ PANDORA

/tmp/PicoDrive.pxml: PicoDrive.pxml.template FORCE
	./make_pxml.sh $< $@

PicoDrive: ../../picodrive
	$(STRIP) $^ -o $@

rel: PicoDrive PicoDrive.sh picorestore \
	PicoDrive.png PicoDrive_p.png \
	../../pico/carthw.cfg skin \
	../../README.md /tmp/PicoDrive.pxml
	rm -rf out
	mkdir out
	cp -r $^ out/
	$(PND_MAKE) -p PicoDrive_$(VER).pnd -d out -x out/PicoDrive.pxml -i out/PicoDrive.png -c

FORCE:
.PHONY: all rel FORCE
