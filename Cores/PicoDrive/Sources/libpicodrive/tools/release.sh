#! /bin/bash
#
# (C) irixxxx 2021-2024
#
# picodrive release build script
#
# creates builds for the supported platforms in the release directory
#
# usage: release.sh <version> [platform...]
#	platforms:	gph dingux retrofw gcw0 opendingux miyoo psp ps2 pandora odbeta-gcw0 odbeta-lepus odbeta-rg99
#
# expects toolchains to be installed in these docker containers:
#	gph:		ghcr.io/irixxxx/toolchain-gp2x
#	dingux:		ghcr.io/irixxxx/toolchain-dingux
#	retrofw:	ghcr.io/irixxxx/toolchain-retrofw
#	gcw0,opendingux:ghcr.io/irixxxx/toolchain-opendingux
#	miyoo:		ghcr.io/irixxxx/toolchain-miyoo
#	psp:		docker.io/pspdev/pspdev
#	ps2:		docker.io/ps2dev/ps2dev
#	pandora:	ghcr.io/irixxxx/toolchain-pandora
#	odbeta-gcw0:	ghcr.io/irixxxx/toolchain-odbeta-gcw0
#	odbeta-lepus:	ghcr.io/irixxxx/toolchain-odbeta-lepus
#	odbeta-rg99:	ghcr.io/irixxxx/toolchain-odbeta-rg99

trap "exit" ERR

rel=$1
mkdir -p release-$rel

shift; plat=" $* "
[ -z "$(echo $plat|tr -d ' ')" ] && plat=" gph dingux retrofw gcw0 opendingux miyoo psp ps2 pandora odbeta-gcw0 odbeta-lepus odbeta-rg99 "


[ -z "${plat##* gph *}" ] && {
# GPH devices: gp2x, wiz, caanoo, with ubuntu arm gcc 4.7
docker pull ghcr.io/irixxxx/toolchain-gp2x
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=gph &&\
	make clean && make -j2 all &&\
	make -C platform/gp2x rel VER=$rel "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-gp2x sh &&
mv PicoDrive_$rel.zip release-$rel/PicoDrive-gph_$rel.zip
}

[ -z "${plat##* dingux *}" ] && {
# dingux: dingoo a320, ritmix rzx-50, JZ4755 or older (mips32r1 w/o fpu)
# NB works for legacy dingux and possibly opendingux before gcw0
docker pull ghcr.io/irixxxx/toolchain-dingux
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=dingux &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-dingux sh &&
mv PicoDrive-dge.zip release-$rel/PicoDrive-dge_$rel.zip
}

[ -z "${plat##* retrofw *}" ] && {
# retrofw: rs-97 and similar, JZ4760 (mips32r1 with fpu)
docker pull ghcr.io/irixxxx/toolchain-retrofw
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=retrofw &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-retrofw sh &&
mv PicoDrive.opk release-$rel/PicoDrive-retrofw_$rel.opk
}

[ -z "${plat##* gcw0 *}" ] && {
# gcw0: JZ4770 (mips32r2 with fpu), swapped X/Y buttons
docker pull ghcr.io/irixxxx/toolchain-opendingux
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=opendingux-gcw0 &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-opendingux sh &&
mv PicoDrive.opk release-$rel/PicoDrive-gcw0_$rel.opk
}

[ -z "${plat##* opendingux *}" ] && {
# rg350, gkd350h etc: JZ4770 or newer
docker pull ghcr.io/irixxxx/toolchain-opendingux
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=opendingux &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-opendingux sh &&
mv PicoDrive.opk release-$rel/PicoDrive-opendingux_$rel.opk
}

[ -z "${plat##* miyoo *}" ] && {
# miyoo: BittBoy >=v1, PocketGo, Powkiddy [QV]90/Q20 (Allwinner F1C100s, ARM926)
docker pull ghcr.io/irixxxx/toolchain-miyoo
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=miyoo &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-miyoo sh &&
mv PicoDrive-miyoo.zip release-$rel/PicoDrive-miyoo_$rel.zip
}

[ -z "${plat##* psp *}" ] && {
# psp (experimental), pspdev SDK toolchain
docker pull --platform=linux/amd64 pspdev/pspdev
echo "	apk add git gcc g++ zip && export CROSS_COMPILE=psp- &&\
	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=psp &&\
	make clean && make -j2 all &&\
	make -C platform/psp rel VER=$rel "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm pspdev/pspdev sh &&
mv PicoDrive_psp_$rel.zip release-$rel/PicoDrive-psp_$rel.zip
}

[ -z "${plat##* ps2 *}" ] && {
# ps2 (experimental), ps2dev SDK toolchain
docker pull --platform=linux/amd64 ps2dev/ps2dev
echo "	apk add build-base cmake git zip make && export CROSS_COMPILE=mips64r5900el-ps2-elf- &&\
	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=ps2 &&\
	make clean && make -j2 all &&\
	make -C platform/ps2 rel VER=$rel "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ps2dev/ps2dev sh &&
mv PicoDrive_ps2_$rel.zip release-$rel/PicoDrive-ps2_$rel.zip
}

[ -z "${plat##* pandora *}" ] && {
# pandora (untested), openpandora SDK toolchain
docker pull ghcr.io/irixxxx/toolchain-pandora
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=pandora &&\
	make clean && make -j2 all &&\
	make -C platform/pandora rel VER=$rel "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-pandora sh &&
mv platform/pandora/PicoDrive_*.pnd release-$rel/
}

[ -z "${plat##* odbeta-gcw0 *}" ] && {
# gcw0, rg350 and similar devices: JZ4770 (mips32r2 with fpu)
docker pull ghcr.io/irixxxx/toolchain-odbeta-gcw0
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=odbeta &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-odbeta-gcw0 sh &&
mv PicoDrive.opk release-$rel/PicoDrive-odbeta-gcw0_$rel.opk
}

[ -z "${plat##* odbeta-lepus *}" ] && {
# rg300 and other Ingenic lepus based: JZ4760 (mips32r1 with fpu)
docker pull ghcr.io/irixxxx/toolchain-odbeta-lepus
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=odbeta &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-odbeta-lepus sh &&
mv PicoDrive.opk release-$rel/PicoDrive-odbeta-lepus_$rel.opk
}

[ -z "${plat##* odbeta-rg99 *}" ] && {
# rg99 and similar devices: JZ4725B (mips32r1 w/o fpu)
docker pull ghcr.io/irixxxx/toolchain-odbeta-rs90
echo "	git config --global --add safe.directory /home/picodrive &&\
	./configure --platform=odbeta &&\
	make clean && make -j2 all "\
  | docker run -i -v$PWD:/home/picodrive -w/home/picodrive --rm ghcr.io/irixxxx/toolchain-odbeta-rs90 sh &&
mv PicoDrive.opk release-$rel/PicoDrive-odbeta-rg99_$rel.opk
}
