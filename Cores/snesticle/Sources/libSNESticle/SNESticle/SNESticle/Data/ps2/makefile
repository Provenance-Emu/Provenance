CDRECORD	= cdrecord dev=2,3,0 speed=16
DD			= dd
CP			= cp
MKISOFS		= mkisofs
CAT			= cat
TOUCH		= touch
DEVELF		= /d/proj/snesticle/project/ps2/snesticle.elf
CDDATAPATH	= /d/proj/snesticle/Data/ps2/CD
CDELFNAME   = SLPS_999.99
CDELF       = $(CDDATAPATH)/$(CDELFNAME)
LICENSE     = license.dat

iso: ps2cd_licensed.iso

burn: ps2cd_licensed.iso burn-data

$(CDELF): $(DEVELF)
	cp $(DEVELF) $(CDELF)

#1st_read.bin: $(1ST_READ)
#	/usr/local/sh-elf/bin/sh-elf-objcopy -O binary $(1ST_READ) temp.bin
#	$(SCRAMBLE) temp.bin 1st_read.bin
#	rm temp.bin

ps2cd_licensed.iso: ps2cd.iso license.dat
	( cat $(LICENSE) ; dd if=ps2cd.iso bs=2048 skip=16 ) > ps2cd_licensed.iso

ps2cd.iso: $(CDELF)
	$(MKISOFS) -joliet -R -o ps2cd.iso $(CDDATAPATH)

burn-data: ps2cd_licensed.iso
	$(CDRECORD) -xa1 ps2cd_licensed.iso

.PHONY : clean
clean:
	rm -f ps2cd*.iso

