# Makefile for PO directory in any package using GNU gettext.
# Copyright (C) 1995-1997, 2000-2007, 2009-2010 by Ulrich Drepper <drepper@gnu.ai.mit.edu>
#
# This file can be copied and used freely without restrictions.  It can
# be used in projects which are not available under the GNU General Public
# License but which still want to provide support for the GNU gettext
# functionality.
# Please note that the actual code of GNU gettext is covered by the GNU
# General Public License and is *not* in the public domain.
#
# Origin: gettext-0.18
GETTEXT_MACRO_VERSION = 0.18

PACKAGE = mednafen
VERSION = 1.21.1
PACKAGE_BUGREPORT = 

SHELL = /bin/sh


srcdir = .
top_srcdir = ..


prefix = /usr/local
exec_prefix = ${prefix}
datarootdir = ${prefix}/share
datadir = ${datarootdir}
localedir = ${datarootdir}/locale
gettextsrcdir = $(datadir)/gettext/po

INSTALL = /usr/local/bin/ginstall -c
INSTALL_DATA = ${INSTALL} -m 644

# We use $(mkdir_p).
# In automake <= 1.9.x, $(mkdir_p) is defined either as "mkdir -p --" or as
# "$(mkinstalldirs)" or as "$(install_sh) -d". For these automake versions,
# ${SHELL} /Users/jmattiello/Workspace/Provenance/Provenance-jmattiello/Mednafen/mednafen-1.21/install-sh does not start with $(SHELL), so we add it.
# In automake >= 1.10, /usr/local/bin/gmkdir -p is derived from ${MKDIR_P}, which is defined
# either as "/path/to/mkdir -p" or ".../install-sh -c -d". For these automake
# versions, $(mkinstalldirs) and $(install_sh) are unused.
mkinstalldirs = $(SHELL) ${SHELL} /Users/jmattiello/Workspace/Provenance/Provenance-jmattiello/Mednafen/mednafen-1.21/install-sh -d
install_sh = $(SHELL) ${SHELL} /Users/jmattiello/Workspace/Provenance/Provenance-jmattiello/Mednafen/mednafen-1.21/install-sh
MKDIR_P = /usr/local/bin/gmkdir -p
mkdir_p = /usr/local/bin/gmkdir -p

GMSGFMT_ = :
GMSGFMT_no = :
GMSGFMT_yes = :
GMSGFMT = $(GMSGFMT_$(USE_MSGCTXT))
MSGFMT_ = :
MSGFMT_no = :
MSGFMT_yes = :
MSGFMT = $(MSGFMT_$(USE_MSGCTXT))
XGETTEXT_ = :
XGETTEXT_no = :
XGETTEXT_yes = :
XGETTEXT = $(XGETTEXT_$(USE_MSGCTXT))
MSGMERGE = msgmerge
MSGMERGE_UPDATE = : --update
MSGINIT = msginit
MSGCONV = msgconv
MSGFILTER = msgfilter

POFILES =  ru.po es.po de.po
GMOFILES =  ru.gmo es.gmo de.gmo
UPDATEPOFILES =  ru.po-update es.po-update de.po-update
DUMMYPOFILES =  ru.nop es.nop de.nop
DISTFILES.common = Makefile.in.in remove-potcdate.sin \
$(DISTFILES.common.extra1) $(DISTFILES.common.extra2) $(DISTFILES.common.extra3)
DISTFILES = $(DISTFILES.common) Makevars POTFILES.in \
$(POFILES) $(GMOFILES) \
$(DISTFILES.extra1) $(DISTFILES.extra2) $(DISTFILES.extra3)

POTFILES = \
     ../src/md/cart/ssp16.c \
     ../src/cputest/x86_cpu.c \
     ../src/cputest/ppc_cpu.c \
     ../src/cputest/cputest.c \
     ../src/cputest/arm_cpu.c \
     ../src/drivers/scalebit.c \
     ../src/drivers/scale2x.c \
     ../src/drivers/scale3x.c \
     ../src/mpcdec/streaminfo.c \
     ../src/mpcdec/crc32.c \
     ../src/mpcdec/huffman.c \
     ../src/mpcdec/mpc_bits_reader.c \
     ../src/mpcdec/requant.c \
     ../src/mpcdec/mpc_reader.c \
     ../src/mpcdec/mpc_demux.c \
     ../src/mpcdec/mpc_decoder.c \
     ../src/mpcdec/synth_filter.c \
     ../src/trio/trio.c \
     ../src/trio/trionan.c \
     ../src/trio/triostr.c \
     ../src/video/font-data-18x18.c \
     ../src/video/font-data-12x13.c \
     ../src/quicklz/quicklz.c \
     ../src/nes/ntsc/demo.c \
     ../src/nes/ntsc/benchmark.c \
     ../src/resampler/resample.c \
     ../src/tremor/codebook.c \
     ../src/tremor/res012.c \
     ../src/tremor/bitwise.c \
     ../src/tremor/window.c \
     ../src/tremor/mapping0.c \
     ../src/tremor/block.c \
     ../src/tremor/vorbisfile.c \
     ../src/tremor/info.c \
     ../src/tremor/mdct.c \
     ../src/tremor/floor1.c \
     ../src/tremor/synthesis.c \
     ../src/tremor/framing.c \
     ../src/tremor/floor0.c \
     ../src/tremor/sharedbook.c \
     ../src/tremor/registry.c \
     ../src/snes/src/chip/dsp3/dsp3emu.c \
     ../src/snes/src/chip/dsp4/dsp4emu.c \
     ../src/snes/src/lib/libco/x86.c \
     ../src/snes/src/lib/libco/amd64.c \
     ../src/snes/src/lib/libco/fiber.c \
     ../src/snes/src/lib/libco/sjlj.c \
     ../src/snes/src/lib/libco/libco.c \
     ../src/snes/src/lib/libco/arm.c \
     ../src/snes/src/lib/libco/ucontext.c \
     ../src/snes/src/lib/libco/ppc.c \
     ../src/desa68/desa68.c \
     ../src/hw_cpu/z80-fuse/z80_ed.c \
     ../src/hw_cpu/z80-fuse/opcodes_base.c \
     ../src/hw_cpu/z80-fuse/z80_cb.c \
     ../src/hw_cpu/z80-fuse/z80_ddfdcb.c \
     ../src/hw_cpu/z80-fuse/z80_ddfd.c \
     ../src/minilzo/minilzo.c \
     ../src/memory.cpp \
     ../src/Time.cpp \
     ../src/md/memvdp.cpp \
     ../src/md/debug.cpp \
     ../src/md/cart/map_svp.cpp \
     ../src/md/cart/map_realtec.cpp \
     ../src/md/cart/map_rom.cpp \
     ../src/md/cart/map_sbb.cpp \
     ../src/md/cart/map_yase.cpp \
     ../src/md/cart/map_eeprom.cpp \
     ../src/md/cart/cart.cpp \
     ../src/md/cart/map_sram.cpp \
     ../src/md/cart/map_rmx3.cpp \
     ../src/md/cart/map_ssf2.cpp \
     ../src/md/cart/map_ff.cpp \
     ../src/md/header.cpp \
     ../src/md/cd/timer.cpp \
     ../src/md/cd/cd.cpp \
     ../src/md/cd/pcm.cpp \
     ../src/md/cd/cdc_cdd.cpp \
     ../src/md/cd/interrupt.cpp \
     ../src/md/genesis.cpp \
     ../src/md/genio.cpp \
     ../src/md/mem68k.cpp \
     ../src/md/input/4way.cpp \
     ../src/md/input/multitap.cpp \
     ../src/md/input/megamouse.cpp \
     ../src/md/input/gamepad.cpp \
     ../src/md/membnk.cpp \
     ../src/md/memz80.cpp \
     ../src/md/vdp.cpp \
     ../src/md/sound.cpp \
     ../src/md/system.cpp \
     ../src/FileStream.cpp \
     ../src/Stream.cpp \
     ../src/SNSFLoader.cpp \
     ../src/drivers/Joystick.cpp \
     ../src/drivers/logdebugger.cpp \
     ../src/drivers/ers.cpp \
     ../src/drivers/mouse.cpp \
     ../src/drivers/nnx.cpp \
     ../src/drivers/help.cpp \
     ../src/drivers/debugger.cpp \
     ../src/drivers/video-state.cpp \
     ../src/drivers/opengl.cpp \
     ../src/drivers/shader.cpp \
     ../src/drivers/hq2x.cpp \
     ../src/drivers/netplay.cpp \
     ../src/drivers/2xSaI.cpp \
     ../src/drivers/prompt.cpp \
     ../src/drivers/main.cpp \
     ../src/drivers/hqxx-common.cpp \
     ../src/drivers/video.cpp \
     ../src/drivers/Joystick_XInput.cpp \
     ../src/drivers/input.cpp \
     ../src/drivers/memdebugger.cpp \
     ../src/drivers/rmdui.cpp \
     ../src/drivers/Joystick_DX5.cpp \
     ../src/drivers/gfxdebugger.cpp \
     ../src/drivers/Joystick_Linux.cpp \
     ../src/drivers/Joystick_SDL.cpp \
     ../src/drivers/keyboard.cpp \
     ../src/drivers/remote.cpp \
     ../src/drivers/console.cpp \
     ../src/drivers/hq3x.cpp \
     ../src/drivers/nongl.cpp \
     ../src/drivers/cheat.cpp \
     ../src/drivers/thread_sdl.cpp \
     ../src/drivers/fps.cpp \
     ../src/drivers/thread_win32.cpp \
     ../src/drivers/sound.cpp \
     ../src/drivers/args.cpp \
     ../src/drivers/hq4x.cpp \
     ../src/net/Net_POSIX.cpp \
     ../src/net/Net.cpp \
     ../src/net/Net_WS2.cpp \
     ../src/sound/Fir_Resampler.cpp \
     ../src/sound/WAVRecord.cpp \
     ../src/sound/okiadpcm_generate.cpp \
     ../src/sound/okiadpcm.cpp \
     ../src/sound/Blip_Buffer.cpp \
     ../src/sound/OwlResampler.cpp \
     ../src/sound/Stereo_Buffer.cpp \
     ../src/SSFLoader.cpp \
     ../src/MemoryStream.cpp \
     ../src/state_rewind.cpp \
     ../src/cheat_formats/snes.cpp \
     ../src/cheat_formats/gb.cpp \
     ../src/cheat_formats/psx.cpp \
     ../src/debug.cpp \
     ../src/hash/md5.cpp \
     ../src/hash/sha1.cpp \
     ../src/hash/sha256.cpp \
     ../src/demo/demo.cpp \
     ../src/ngp/rom.cpp \
     ../src/ngp/gfx_scanline_mono.cpp \
     ../src/ngp/biosHLE.cpp \
     ../src/ngp/mem.cpp \
     ../src/ngp/flash.cpp \
     ../src/ngp/T6W28_Apu.cpp \
     ../src/ngp/gfx.cpp \
     ../src/ngp/bios.cpp \
     ../src/ngp/Z80_interface.cpp \
     ../src/ngp/gfx_scanline_colour.cpp \
     ../src/ngp/rtc.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_disassemble_src.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_interpret.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_registers.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_disassemble_extra.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_disassemble_reg.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_reg.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_dst.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_single.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_disassemble.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_disassemble_dst.cpp \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_src.cpp \
     ../src/ngp/sound.cpp \
     ../src/ngp/interrupt.cpp \
     ../src/ngp/neopop.cpp \
     ../src/ngp/dma.cpp \
     ../src/sms/tms.cpp \
     ../src/sms/romdb.cpp \
     ../src/sms/render.cpp \
     ../src/sms/cart.cpp \
     ../src/sms/memz80.cpp \
     ../src/sms/vdp.cpp \
     ../src/sms/sms.cpp \
     ../src/sms/sound.cpp \
     ../src/sms/system.cpp \
     ../src/sms/pio.cpp \
     ../src/video/resize.cpp \
     ../src/video/png.cpp \
     ../src/video/font-data.cpp \
     ../src/video/video.cpp \
     ../src/video/primitives.cpp \
     ../src/video/text.cpp \
     ../src/video/tblur.cpp \
     ../src/video/surface.cpp \
     ../src/video/Deinterlacer.cpp \
     ../src/netplay.cpp \
     ../src/settings.cpp \
     ../src/file.cpp \
     ../src/ss/scu_dsp_mvi.cpp \
     ../src/ss/cdb.cpp \
     ../src/ss/ssf.cpp \
     ../src/ss/vdp2_render.cpp \
     ../src/ss/cart/backup.cpp \
     ../src/ss/cart/rom.cpp \
     ../src/ss/cart/extram.cpp \
     ../src/ss/cart/cs1ram.cpp \
     ../src/ss/cart/debug.cpp \
     ../src/ss/cart/ar4mp.cpp \
     ../src/ss/smpc.cpp \
     ../src/ss/scu_dsp_jmp.cpp \
     ../src/ss/cart.cpp \
     ../src/ss/vdp1_line.cpp \
     ../src/ss/scu_dsp_gen.cpp \
     ../src/ss/vdp1_sprite.cpp \
     ../src/ss/input/3dpad.cpp \
     ../src/ss/input/mouse.cpp \
     ../src/ss/input/gun.cpp \
     ../src/ss/input/jpkeyboard.cpp \
     ../src/ss/input/keyboard.cpp \
     ../src/ss/input/multitap.cpp \
     ../src/ss/input/wheel.cpp \
     ../src/ss/input/mission.cpp \
     ../src/ss/input/gamepad.cpp \
     ../src/ss/vdp1.cpp \
     ../src/ss/notes/gen_dsp.cpp \
     ../src/ss/vdp2.cpp \
     ../src/ss/ss.cpp \
     ../src/ss/db.cpp \
     ../src/ss/scu_dsp_misc.cpp \
     ../src/ss/vdp1_poly.cpp \
     ../src/ss/sound.cpp \
     ../src/state.cpp \
     ../src/gba/Mode3.cpp \
     ../src/gba/GBAinline.cpp \
     ../src/gba/Gfx.cpp \
     ../src/gba/Mode5.cpp \
     ../src/gba/eeprom.cpp \
     ../src/gba/sram.cpp \
     ../src/gba/RTC.cpp \
     ../src/gba/flash.cpp \
     ../src/gba/bios.cpp \
     ../src/gba/thumb.cpp \
     ../src/gba/Sound.cpp \
     ../src/gba/Globals.cpp \
     ../src/gba/Mode0.cpp \
     ../src/gba/Mode4.cpp \
     ../src/gba/arm.cpp \
     ../src/gba/GBA.cpp \
     ../src/gba/Mode2.cpp \
     ../src/gba/Mode1.cpp \
     ../src/IPSPatcher.cpp \
     ../src/nes/fds.cpp \
     ../src/nes/debug.cpp \
     ../src/nes/boards/107.cpp \
     ../src/nes/boards/246.cpp \
     ../src/nes/boards/96.cpp \
     ../src/nes/boards/228.cpp \
     ../src/nes/boards/8.cpp \
     ../src/nes/boards/99.cpp \
     ../src/nes/boards/182.cpp \
     ../src/nes/boards/18.cpp \
     ../src/nes/boards/mmc2and4.cpp \
     ../src/nes/boards/34.cpp \
     ../src/nes/boards/sachen.cpp \
     ../src/nes/boards/73.cpp \
     ../src/nes/boards/ffe.cpp \
     ../src/nes/boards/51.cpp \
     ../src/nes/boards/244.cpp \
     ../src/nes/boards/93.cpp \
     ../src/nes/boards/90.cpp \
     ../src/nes/boards/240.cpp \
     ../src/nes/boards/151.cpp \
     ../src/nes/boards/185.cpp \
     ../src/nes/boards/89.cpp \
     ../src/nes/boards/78.cpp \
     ../src/nes/boards/32.cpp \
     ../src/nes/boards/vrc6.cpp \
     ../src/nes/boards/190.cpp \
     ../src/nes/boards/241.cpp \
     ../src/nes/boards/92.cpp \
     ../src/nes/boards/16.cpp \
     ../src/nes/boards/mmc5.cpp \
     ../src/nes/boards/41.cpp \
     ../src/nes/boards/163.cpp \
     ../src/nes/boards/nina06.cpp \
     ../src/nes/boards/deirom.cpp \
     ../src/nes/boards/30.cpp \
     ../src/nes/boards/23.cpp \
     ../src/nes/boards/114.cpp \
     ../src/nes/boards/21.cpp \
     ../src/nes/boards/novel.cpp \
     ../src/nes/boards/vrc7.cpp \
     ../src/nes/boards/22.cpp \
     ../src/nes/boards/242.cpp \
     ../src/nes/boards/222.cpp \
     ../src/nes/boards/187.cpp \
     ../src/nes/boards/80.cpp \
     ../src/nes/boards/75.cpp \
     ../src/nes/boards/n106.cpp \
     ../src/nes/boards/87.cpp \
     ../src/nes/boards/208.cpp \
     ../src/nes/boards/184.cpp \
     ../src/nes/boards/malee.cpp \
     ../src/nes/boards/248.cpp \
     ../src/nes/boards/25.cpp \
     ../src/nes/boards/maxicart.cpp \
     ../src/nes/boards/super24.cpp \
     ../src/nes/boards/82.cpp \
     ../src/nes/boards/supervision.cpp \
     ../src/nes/boards/colordreams.cpp \
     ../src/nes/boards/46.cpp \
     ../src/nes/boards/8237.cpp \
     ../src/nes/boards/70.cpp \
     ../src/nes/boards/97.cpp \
     ../src/nes/boards/68.cpp \
     ../src/nes/boards/40.cpp \
     ../src/nes/boards/189.cpp \
     ../src/nes/boards/156.cpp \
     ../src/nes/boards/112.cpp \
     ../src/nes/boards/193.cpp \
     ../src/nes/boards/emu2413.cpp \
     ../src/nes/boards/77.cpp \
     ../src/nes/boards/38.cpp \
     ../src/nes/boards/simple.cpp \
     ../src/nes/boards/88.cpp \
     ../src/nes/boards/mmc3.cpp \
     ../src/nes/boards/140.cpp \
     ../src/nes/boards/h2288.cpp \
     ../src/nes/boards/86.cpp \
     ../src/nes/boards/95.cpp \
     ../src/nes/boards/65.cpp \
     ../src/nes/boards/76.cpp \
     ../src/nes/boards/117.cpp \
     ../src/nes/boards/42.cpp \
     ../src/nes/boards/180.cpp \
     ../src/nes/boards/codemasters.cpp \
     ../src/nes/boards/72.cpp \
     ../src/nes/boards/234.cpp \
     ../src/nes/boards/113.cpp \
     ../src/nes/boards/mmc1.cpp \
     ../src/nes/boards/67.cpp \
     ../src/nes/boards/fme7.cpp \
     ../src/nes/boards/15.cpp \
     ../src/nes/boards/232.cpp \
     ../src/nes/boards/94.cpp \
     ../src/nes/boards/33.cpp \
     ../src/nes/boards/tengen.cpp \
     ../src/nes/boards/152.cpp \
     ../src/nes/ppu/ppu.cpp \
     ../src/nes/ppu/palette.cpp \
     ../src/nes/cart.cpp \
     ../src/nes/filter.cpp \
     ../src/nes/input/shadow.cpp \
     ../src/nes/input/mahjong.cpp \
     ../src/nes/input/suborkb.cpp \
     ../src/nes/input/ftrainer.cpp \
     ../src/nes/input/oekakids.cpp \
     ../src/nes/input/arkanoid.cpp \
     ../src/nes/input/hypershot.cpp \
     ../src/nes/input/powerpad.cpp \
     ../src/nes/input/cursor.cpp \
     ../src/nes/input/partytap.cpp \
     ../src/nes/input/toprider.cpp \
     ../src/nes/input/zapper.cpp \
     ../src/nes/input/fkb.cpp \
     ../src/nes/input/bbattler2.cpp \
     ../src/nes/nsfe.cpp \
     ../src/nes/dis6502.cpp \
     ../src/nes/input.cpp \
     ../src/nes/ines.cpp \
     ../src/nes/ntsc/nes_ntsc.cpp \
     ../src/nes/nes.cpp \
     ../src/nes/nsf.cpp \
     ../src/nes/fds-sound.cpp \
     ../src/nes/vsuni.cpp \
     ../src/nes/unif.cpp \
     ../src/nes/x6502.cpp \
     ../src/nes/sound.cpp \
     ../src/snes_faust/snes.cpp \
     ../src/snes_faust/ppu.cpp \
     ../src/snes_faust/cart.cpp \
     ../src/snes_faust/input.cpp \
     ../src/snes_faust/cpu.cpp \
     ../src/snes_faust/apu.cpp \
     ../src/cdplay/cdplay.cpp \
     ../src/pcfx/timer.cpp \
     ../src/pcfx/debug.cpp \
     ../src/pcfx/rainbow.cpp \
     ../src/pcfx/huc6273.cpp \
     ../src/pcfx/input/mouse.cpp \
     ../src/pcfx/input/gamepad.cpp \
     ../src/pcfx/input.cpp \
     ../src/pcfx/king.cpp \
     ../src/pcfx/pcfx.cpp \
     ../src/pcfx/soundbox.cpp \
     ../src/pcfx/fxscsi.cpp \
     ../src/pcfx/jrevdct.cpp \
     ../src/pcfx/interrupt.cpp \
     ../src/snes/src/memory/memory.cpp \
     ../src/snes/src/memory/smemory/serialization.cpp \
     ../src/snes/src/memory/smemory/smemory.cpp \
     ../src/snes/src/memory/smemory/system.cpp \
     ../src/snes/src/memory/smemory/generic.cpp \
     ../src/snes/src/smp/ssmp/memory/memory.cpp \
     ../src/snes/src/smp/ssmp/debugger/debugger.cpp \
     ../src/snes/src/smp/ssmp/serialization.cpp \
     ../src/snes/src/smp/ssmp/timing/timing.cpp \
     ../src/snes/src/smp/ssmp/ssmp.cpp \
     ../src/snes/src/smp/smp.cpp \
     ../src/snes/src/smp/core/opcode_misc.cpp \
     ../src/snes/src/smp/core/algorithms.cpp \
     ../src/snes/src/smp/core/opcode_read.cpp \
     ../src/snes/src/smp/core/serialization.cpp \
     ../src/snes/src/smp/core/table.cpp \
     ../src/snes/src/smp/core/core.cpp \
     ../src/snes/src/smp/core/opcode_rmw.cpp \
     ../src/snes/src/smp/core/opcode_mov.cpp \
     ../src/snes/src/smp/core/opcode_pc.cpp \
     ../src/snes/src/chip/dsp3/dsp3.cpp \
     ../src/snes/src/chip/bsx/bsx_flash.cpp \
     ../src/snes/src/chip/bsx/bsx_base.cpp \
     ../src/snes/src/chip/bsx/bsx_cart.cpp \
     ../src/snes/src/chip/bsx/bsx.cpp \
     ../src/snes/src/chip/spc7110/spc7110.cpp \
     ../src/snes/src/chip/spc7110/serialization.cpp \
     ../src/snes/src/chip/spc7110/decomp.cpp \
     ../src/snes/src/chip/obc1/obc1.cpp \
     ../src/snes/src/chip/obc1/serialization.cpp \
     ../src/snes/src/chip/dsp4/dsp4.cpp \
     ../src/snes/src/chip/srtc/srtc.cpp \
     ../src/snes/src/chip/srtc/serialization.cpp \
     ../src/snes/src/chip/superfx/mmio/mmio.cpp \
     ../src/snes/src/chip/superfx/superfx.cpp \
     ../src/snes/src/chip/superfx/memory/memory.cpp \
     ../src/snes/src/chip/superfx/bus/bus.cpp \
     ../src/snes/src/chip/superfx/serialization.cpp \
     ../src/snes/src/chip/superfx/timing/timing.cpp \
     ../src/snes/src/chip/superfx/disasm/disasm.cpp \
     ../src/snes/src/chip/superfx/core/core.cpp \
     ../src/snes/src/chip/superfx/core/opcode_table.cpp \
     ../src/snes/src/chip/superfx/core/opcodes.cpp \
     ../src/snes/src/chip/st010/st010_op.cpp \
     ../src/snes/src/chip/st010/serialization.cpp \
     ../src/snes/src/chip/st010/st010.cpp \
     ../src/snes/src/chip/sdd1/sdd1emu.cpp \
     ../src/snes/src/chip/sdd1/serialization.cpp \
     ../src/snes/src/chip/sdd1/sdd1.cpp \
     ../src/snes/src/chip/cx4/data.cpp \
     ../src/snes/src/chip/cx4/oam.cpp \
     ../src/snes/src/chip/cx4/serialization.cpp \
     ../src/snes/src/chip/cx4/functions.cpp \
     ../src/snes/src/chip/cx4/cx4.cpp \
     ../src/snes/src/chip/cx4/opcodes.cpp \
     ../src/snes/src/chip/dsp1/serialization.cpp \
     ../src/snes/src/chip/dsp1/dsp1.cpp \
     ../src/snes/src/chip/dsp1/dsp1emu.cpp \
     ../src/snes/src/chip/sa1/mmio/mmio.cpp \
     ../src/snes/src/chip/sa1/dma/dma.cpp \
     ../src/snes/src/chip/sa1/memory/memory.cpp \
     ../src/snes/src/chip/sa1/bus/bus.cpp \
     ../src/snes/src/chip/sa1/serialization.cpp \
     ../src/snes/src/chip/sa1/sa1.cpp \
     ../src/snes/src/chip/dsp2/serialization.cpp \
     ../src/snes/src/chip/dsp2/dsp2.cpp \
     ../src/snes/src/chip/dsp2/opcodes.cpp \
     ../src/snes/src/ppu/mmio/mmio.cpp \
     ../src/snes/src/ppu/render/addsub.cpp \
     ../src/snes/src/ppu/render/oam.cpp \
     ../src/snes/src/ppu/render/render.cpp \
     ../src/snes/src/ppu/render/windows.cpp \
     ../src/snes/src/ppu/render/line.cpp \
     ../src/snes/src/ppu/render/cache.cpp \
     ../src/snes/src/ppu/render/bg.cpp \
     ../src/snes/src/ppu/render/mode7.cpp \
     ../src/snes/src/ppu/memory/memory.cpp \
     ../src/snes/src/ppu/ppu.cpp \
     ../src/snes/src/ppu/debugger/debugger.cpp \
     ../src/snes/src/ppu/debugger/render.cpp \
     ../src/snes/src/ppu/serialization.cpp \
     ../src/snes/src/cpu/scpu/mmio/mmio.cpp \
     ../src/snes/src/cpu/scpu/dma/dma.cpp \
     ../src/snes/src/cpu/scpu/memory/memory.cpp \
     ../src/snes/src/cpu/scpu/scpu.cpp \
     ../src/snes/src/cpu/scpu/debugger/debugger.cpp \
     ../src/snes/src/cpu/scpu/serialization.cpp \
     ../src/snes/src/cpu/scpu/timing/joypad.cpp \
     ../src/snes/src/cpu/scpu/timing/event.cpp \
     ../src/snes/src/cpu/scpu/timing/irq.cpp \
     ../src/snes/src/cpu/scpu/timing/timing.cpp \
     ../src/snes/src/cpu/cpu.cpp \
     ../src/snes/src/cpu/core/opcode_write.cpp \
     ../src/snes/src/cpu/core/opcode_misc.cpp \
     ../src/snes/src/cpu/core/algorithms.cpp \
     ../src/snes/src/cpu/core/opcode_read.cpp \
     ../src/snes/src/cpu/core/serialization.cpp \
     ../src/snes/src/cpu/core/table.cpp \
     ../src/snes/src/cpu/core/core.cpp \
     ../src/snes/src/cpu/core/opcode_rmw.cpp \
     ../src/snes/src/cpu/core/opcode_pc.cpp \
     ../src/snes/src/sdsp/gaussian.cpp \
     ../src/snes/src/sdsp/counter.cpp \
     ../src/snes/src/sdsp/envelope.cpp \
     ../src/snes/src/sdsp/voice.cpp \
     ../src/snes/src/sdsp/brr.cpp \
     ../src/snes/src/sdsp/misc.cpp \
     ../src/snes/src/sdsp/serialization.cpp \
     ../src/snes/src/sdsp/echo.cpp \
     ../src/snes/src/sdsp/sdsp.cpp \
     ../src/snes/src/cartridge/gameboyheader.cpp \
     ../src/snes/src/cartridge/header.cpp \
     ../src/snes/src/cartridge/cartridge.cpp \
     ../src/snes/src/cartridge/serialization.cpp \
     ../src/snes/src/cheat/cheat.cpp \
     ../src/snes/src/system/video/video.cpp \
     ../src/snes/src/system/audio/audio.cpp \
     ../src/snes/src/system/debugger/debugger.cpp \
     ../src/snes/src/system/serialization.cpp \
     ../src/snes/src/system/config/config.cpp \
     ../src/snes/src/system/input/input.cpp \
     ../src/snes/src/system/scheduler/scheduler.cpp \
     ../src/snes/src/system/system.cpp \
     ../src/snes/interface.cpp \
     ../src/wswan/memory.cpp \
     ../src/wswan/dis/resolve.cpp \
     ../src/wswan/dis/dis_groups.cpp \
     ../src/wswan/dis/syntax.cpp \
     ../src/wswan/dis/dis_decode.cpp \
     ../src/wswan/debug.cpp \
     ../src/wswan/eeprom.cpp \
     ../src/wswan/v30mz.cpp \
     ../src/wswan/main.cpp \
     ../src/wswan/gfx.cpp \
     ../src/wswan/tcache.cpp \
     ../src/wswan/comm.cpp \
     ../src/wswan/rtc.cpp \
     ../src/wswan/sound.cpp \
     ../src/wswan/interrupt.cpp \
     ../src/error.cpp \
     ../src/player.cpp \
     ../src/movie.cpp \
     ../src/SPCReader.cpp \
     ../src/gb/memory.cpp \
     ../src/gb/z80.cpp \
     ../src/gb/gb.cpp \
     ../src/gb/gfx.cpp \
     ../src/gb/sound.cpp \
     ../src/gb/gbGlobals.cpp \
     ../src/tests.cpp \
     ../src/vb/timer.cpp \
     ../src/vb/debug.cpp \
     ../src/vb/vb.cpp \
     ../src/vb/vip.cpp \
     ../src/vb/vsu.cpp \
     ../src/vb/input.cpp \
     ../src/qtrecord.cpp \
     ../src/mempatcher.cpp \
     ../src/hw_sound/ym2413/emu2413.cpp \
     ../src/hw_sound/ym2612/Ym2612_Emu.cpp \
     ../src/hw_sound/pce_psg/pce_psg.cpp \
     ../src/hw_sound/sms_apu/Sms_Apu.cpp \
     ../src/hw_sound/gb_apu/Gb_Apu_State.cpp \
     ../src/hw_sound/gb_apu/Gb_Apu.cpp \
     ../src/hw_sound/gb_apu/Gb_Oscs.cpp \
     ../src/PSFLoader.cpp \
     ../src/general.cpp \
     ../src/git.cpp \
     ../src/lynx/rom.cpp \
     ../src/lynx/ram.cpp \
     ../src/lynx/cart.cpp \
     ../src/lynx/memmap.cpp \
     ../src/lynx/mikie.cpp \
     ../src/lynx/susie.cpp \
     ../src/lynx/c65c02.cpp \
     ../src/lynx/system.cpp \
     ../src/hw_cpu/v810/v810_cpuD.cpp \
     ../src/hw_cpu/v810/v810_fp_ops.cpp \
     ../src/hw_cpu/v810/v810_cpu.cpp \
     ../src/hw_cpu/m68k/m68k.cpp \
     ../src/hw_cpu/m68k/gen.cpp \
     ../src/hw_cpu/z80-fuse/z80.cpp \
     ../src/hw_cpu/z80-fuse/z80_ops.cpp \
     ../src/pce_fast/hes.cpp \
     ../src/pce_fast/huc.cpp \
     ../src/pce_fast/pcecd.cpp \
     ../src/pce_fast/psg.cpp \
     ../src/pce_fast/input.cpp \
     ../src/pce_fast/vdc.cpp \
     ../src/pce_fast/pcecd_drive.cpp \
     ../src/pce_fast/pce.cpp \
     ../src/pce_fast/huc6280.cpp \
     ../src/compress/GZFileStream.cpp \
     ../src/compress/ZIPReader.cpp \
     ../src/compress/ZLInflateFilter.cpp \
     ../src/hw_video/huc6270/vdc.cpp \
     ../src/mednafen.cpp \
     ../src/cdrom/crc32.cpp \
     ../src/cdrom/CDAccess.cpp \
     ../src/cdrom/galois.cpp \
     ../src/cdrom/CDAccess_CCD.cpp \
     ../src/cdrom/lec.cpp \
     ../src/cdrom/CDAFReader_SF.cpp \
     ../src/cdrom/l-ec.cpp \
     ../src/cdrom/CDAFReader.cpp \
     ../src/cdrom/CDUtility.cpp \
     ../src/cdrom/CDAccess_Image.cpp \
     ../src/cdrom/scsicd.cpp \
     ../src/cdrom/recover-raw.cpp \
     ../src/cdrom/cdromif.cpp \
     ../src/cdrom/CDAFReader_MPC.cpp \
     ../src/cdrom/CDAFReader_Vorbis.cpp \
     ../src/string/string.cpp \
     ../src/string/escape.cpp \
     ../src/hw_misc/arcade_card/arcade_card.cpp \
     ../src/psx/frontio.cpp \
     ../src/psx/sio.cpp \
     ../src/psx/timer.cpp \
     ../src/psx/dis.cpp \
     ../src/psx/debug.cpp \
     ../src/psx/gpu_line.cpp \
     ../src/psx/gpu_polygon.cpp \
     ../src/psx/spu.cpp \
     ../src/psx/input/negcon.cpp \
     ../src/psx/input/mouse.cpp \
     ../src/psx/input/dualshock.cpp \
     ../src/psx/input/justifier.cpp \
     ../src/psx/input/guncon.cpp \
     ../src/psx/input/memcard.cpp \
     ../src/psx/input/dualanalog.cpp \
     ../src/psx/input/multitap.cpp \
     ../src/psx/input/gamepad.cpp \
     ../src/psx/notes/tristep.cpp \
     ../src/psx/irq.cpp \
     ../src/psx/gte.cpp \
     ../src/psx/cpu.cpp \
     ../src/psx/mdec.cpp \
     ../src/psx/cdc.cpp \
     ../src/psx/gpu_sprite.cpp \
     ../src/psx/gpu.cpp \
     ../src/psx/psx.cpp \
     ../src/psx/dma.cpp \
     ../src/pce/hes.cpp \
     ../src/pce/debug.cpp \
     ../src/pce/huc.cpp \
     ../src/pce/mcgenjin.cpp \
     ../src/pce/dis6280.cpp \
     ../src/pce/vce.cpp \
     ../src/pce/pcecd.cpp \
     ../src/pce/input/mouse.cpp \
     ../src/pce/input/gamepad.cpp \
     ../src/pce/input/tsushinkb.cpp \
     ../src/pce/input.cpp \
     ../src/pce/pce.cpp \
     ../src/pce/huc6280.cpp \
     ../src/pce/tsushin.cpp \
     ../src/endian.cpp \
     ../src/sexyal/drivers/es1370.cpp \
     ../src/sexyal/drivers/openbsd.cpp \
     ../src/sexyal/drivers/cmi8738.cpp \
     ../src/sexyal/drivers/es1371.cpp \
     ../src/sexyal/drivers/wasapish.cpp \
     ../src/sexyal/drivers/dummy.cpp \
     ../src/sexyal/drivers/jack.cpp \
     ../src/sexyal/drivers/wasapi.cpp \
     ../src/sexyal/drivers/oss.cpp \
     ../src/sexyal/drivers/alsa.cpp \
     ../src/sexyal/drivers/dos_common.cpp \
     ../src/sexyal/drivers/sb.cpp \
     ../src/sexyal/drivers/dsound.cpp \
     ../src/sexyal/drivers/sdl.cpp \
     ../src/sexyal/sexyal.cpp \
     ../src/sexyal/convert.cpp \
     ../src/md/vdp_run.inc \
     ../src/drivers/shader_sabr.inc \
     ../src/drivers/shader_scale2x.inc \
     ../src/sound/OwlResampler_neon.inc \
     ../src/sound/OwlResampler_x86.inc \
     ../src/sound/OwlResampler_altivec.inc \
     ../src/sms/hvc.inc \
     ../src/ss/scu_actab.inc \
     ../src/ss/scu_dsp_gentab.inc \
     ../src/ss/scsp.inc \
     ../src/ss/sh7095.inc \
     ../src/ss/scu_dsp_mvitab.inc \
     ../src/ss/scu.inc \
     ../src/ss/sh7095_idecodetab.inc \
     ../src/ss/debug.inc \
     ../src/ss/scu_dsp_common.inc \
     ../src/ss/scu_btab.inc \
     ../src/ss/scu_dsp_dmatab.inc \
     ../src/ss/scu_aciv1tab.inc \
     ../src/ss/sh7095_opdefs.inc \
     ../src/ss/scu_dsp_misctab.inc \
     ../src/ss/scu_dsp_jmptab.inc \
     ../src/nes/ines-correct.inc \
     ../src/nes/ines-bad.inc \
     ../src/snes_faust/dma.inc \
     ../src/snes_faust/apu_ipl.inc \
     ../src/snes_faust/spc700.inc \
     ../src/snes_faust/dsp.inc \
     ../src/snes_faust/cpu_loop_body.inc \
     ../src/pcfx/king-bgfast.inc \
     ../src/pcfx/rainbow_dcuv.inc \
     ../src/pcfx/rainbow_acy.inc \
     ../src/pcfx/rainbow_dcy.inc \
     ../src/pcfx/mem-handler.inc \
     ../src/pcfx/king-bgfast-blit.inc \
     ../src/pcfx/king_mix_body.inc \
     ../src/pcfx/io-handler.inc \
     ../src/pcfx/gamedb.inc \
     ../src/pcfx/rainbow_acuv.inc \
     ../src/wswan/dis/dis_tables.inc \
     ../src/wswan/dis/opcodes.inc \
     ../src/wswan/v30mz-ea.inc \
     ../src/wswan/start.inc \
     ../src/wswan/v30mz-modrm.inc \
     ../src/vb/vip_draw.inc \
     ../src/hw_sound/ym2612/ym2612_opeg.inc \
     ../src/hw_cpu/v810/v810_oploop.inc \
     ../src/hw_cpu/m68k/m68k_instr.inc \
     ../src/pce_fast/huc6280_ops.inc \
     ../src/pce_fast/vpc_mix_inner.inc \
     ../src/pce_fast/ioread.inc \
     ../src/cdrom/scsicd-pce-commands.inc \
     ../src/cdrom/scsicd_cdda_filter.inc \
     ../src/psx/spu_reverb.inc \
     ../src/psx/spu_fir_table.inc \
     ../src/psx/gpu_common.inc \
     ../src/pce/huc6280_ops.inc \
     ../src/md/memvdp.h \
     ../src/md/debug.h \
     ../src/md/vdp.h \
     ../src/md/hvc.h \
     ../src/md/cart/ssp16.h \
     ../src/md/cart/map_ff.h \
     ../src/md/cart/map_yase.h \
     ../src/md/cart/map_sram.h \
     ../src/md/cart/map_rmx3.h \
     ../src/md/cart/map_ssf2.h \
     ../src/md/cart/map_rom.h \
     ../src/md/cart/map_sbb.h \
     ../src/md/cart/map_realtec.h \
     ../src/md/cart/map_eeprom.h \
     ../src/md/cart/map_svp.h \
     ../src/md/cart/cart.h \
     ../src/md/cd/interrupt.h \
     ../src/md/cd/timer.h \
     ../src/md/cd/cd.h \
     ../src/md/cd/pcm.h \
     ../src/md/cd/cdc_cdd.h \
     ../src/md/sound.h \
     ../src/md/vcnt.h \
     ../src/md/mem68k.h \
     ../src/md/macros.h \
     ../src/md/input/gamepad.h \
     ../src/md/input/4way.h \
     ../src/md/input/multitap.h \
     ../src/md/input/megamouse.h \
     ../src/md/memz80.h \
     ../src/md/genesis.h \
     ../src/md/system.h \
     ../src/md/genio.h \
     ../src/md/header.h \
     ../src/md/shared.h \
     ../src/md/membnk.h \
     ../src/settings.h \
     ../src/state.h \
     ../src/PSFLoader.h \
     ../src/git.h \
     ../src/debug.h \
     ../src/netplay.h \
     ../src/error.h \
     ../src/cputest/cputest.h \
     ../src/cputest/x86_cpu.h \
     ../src/drivers/Joystick_SDL.h \
     ../src/drivers/remote.h \
     ../src/drivers/netplay.h \
     ../src/drivers/main.h \
     ../src/drivers/input.h \
     ../src/drivers/logdebugger.h \
     ../src/drivers/memdebugger.h \
     ../src/drivers/args.h \
     ../src/drivers/video-state.h \
     ../src/drivers/ers.h \
     ../src/drivers/sound.h \
     ../src/drivers/hqxx-common.h \
     ../src/drivers/video.h \
     ../src/drivers/Joystick.h \
     ../src/drivers/Joystick_XInput.h \
     ../src/drivers/scale3x.h \
     ../src/drivers/debugger.h \
     ../src/drivers/shader.h \
     ../src/drivers/fps.h \
     ../src/drivers/console.h \
     ../src/drivers/keyboard_scancodes.h \
     ../src/drivers/gfxdebugger.h \
     ../src/drivers/mouse.h \
     ../src/drivers/scale2x.h \
     ../src/drivers/Joystick_DX5.h \
     ../src/drivers/nongl.h \
     ../src/drivers/input-default-buttons.h \
     ../src/drivers/keyboard.h \
     ../src/drivers/opengl.h \
     ../src/drivers/scalebit.h \
     ../src/drivers/Joystick_Linux.h \
     ../src/drivers/rmdui.h \
     ../src/drivers/help.h \
     ../src/drivers/nnx.h \
     ../src/drivers/prompt.h \
     ../src/drivers/2xSaI.h \
     ../src/drivers/cheat.h \
     ../src/net/Net.h \
     ../src/net/Net_POSIX.h \
     ../src/net/Net_WS2.h \
     ../src/sound/Blip_Buffer.h \
     ../src/sound/okiadpcm.h \
     ../src/sound/WAVRecord.h \
     ../src/sound/fir_blargg_source.h \
     ../src/sound/fir_blargg_endian.h \
     ../src/sound/okiadpcm-deltatable.h \
     ../src/sound/Fir_Resampler.h \
     ../src/sound/fir_blargg_common.h \
     ../src/sound/Stereo_Buffer.h \
     ../src/sound/fir_blargg_config.h \
     ../src/sound/OwlResampler.h \
     ../src/endian.h \
     ../src/cheat_formats/snes.h \
     ../src/cheat_formats/psx.h \
     ../src/cheat_formats/gb.h \
     ../src/SSFLoader.h \
     ../src/SNSFLoader.h \
     ../src/file.h \
     ../src/mpcdec/huffman.h \
     ../src/mpcdec/requant.h \
     ../src/mpcdec/mpc_bits_reader.h \
     ../src/mpcdec/decoder.h \
     ../src/mpcdec/internal.h \
     ../src/mpcdec/datatypes.h \
     ../src/mpcdec/streaminfo.h \
     ../src/mpcdec/mpc_types.h \
     ../src/mpcdec/mpcdec_math.h \
     ../src/mpcdec/mpcdec.h \
     ../src/mpcdec/mpcmath.h \
     ../src/mpcdec/reader.h \
     ../src/mpcdec/minimax.h \
     ../src/Stream.h \
     ../src/hash/sha1.h \
     ../src/hash/md5.h \
     ../src/hash/sha256.h \
     ../src/player.h \
     ../src/netplay-driver.h \
     ../src/ngp/interrupt.h \
     ../src/ngp/mem.h \
     ../src/ngp/sound.h \
     ../src/ngp/dma.h \
     ../src/ngp/neopop.h \
     ../src/ngp/rtc.h \
     ../src/ngp/Z80_interface.h \
     ../src/ngp/T6W28_Oscs.h \
     ../src/ngp/gfx.h \
     ../src/ngp/flash.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeL2.h \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_reg.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeB3.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapL.h \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_single.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeW0.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeB0.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeB1.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeL0.h \
     ../src/ngp/TLCS-900h/TLCS900h_disassemble.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeW3.h \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_dst.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapW.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeL3.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeW1.h \
     ../src/ngp/TLCS-900h/TLCS900h_interpret.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeL1.h \
     ../src/ngp/TLCS-900h/TLCS900h_interpret_src.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeB2.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapCodeW2.h \
     ../src/ngp/TLCS-900h/TLCS900h_registers_mapB.h \
     ../src/ngp/bios.h \
     ../src/ngp/T6W28_Apu.h \
     ../src/sms/romdb.h \
     ../src/sms/vdp.h \
     ../src/sms/sound.h \
     ../src/sms/render.h \
     ../src/sms/tms.h \
     ../src/sms/memz80.h \
     ../src/sms/sms.h \
     ../src/sms/system.h \
     ../src/sms/shared.h \
     ../src/sms/cart.h \
     ../src/sms/pio.h \
     ../src/trio/trionan.h \
     ../src/trio/trio.h \
     ../src/trio/triodef.h \
     ../src/trio/triop.h \
     ../src/trio/triostr.h \
     ../src/types.h \
     ../src/video/font-data.h \
     ../src/video/text.h \
     ../src/video/video-common.h \
     ../src/video/surface.h \
     ../src/video/tblur.h \
     ../src/video/font9x18.h \
     ../src/video/font6x13.h \
     ../src/video/resize.h \
     ../src/video/primitives.h \
     ../src/video/png.h \
     ../src/video/font5x7.h \
     ../src/video/Deinterlacer.h \
     ../src/video/font18x18ko.h \
     ../src/video/font12x13ja.h \
     ../src/video/font6x12.h \
     ../src/video/font6x9.h \
     ../src/math_ops.h \
     ../src/qtrecord.h \
     ../src/state-driver.h \
     ../src/video.h \
     ../src/mempatcher.h \
     ../src/IPSPatcher.h \
     ../src/ss/cdb.h \
     ../src/ss/vdp1.h \
     ../src/ss/vdp1_common.h \
     ../src/ss/db.h \
     ../src/ss/cart/debug.h \
     ../src/ss/cart/ar4mp.h \
     ../src/ss/cart/extram.h \
     ../src/ss/cart/rom.h \
     ../src/ss/cart/backup.h \
     ../src/ss/cart/cs1ram.h \
     ../src/ss/cart/common.h \
     ../src/ss/sh7095.h \
     ../src/ss/sound.h \
     ../src/ss/vdp2_render.h \
     ../src/ss/ss.h \
     ../src/ss/input/gamepad.h \
     ../src/ss/input/3dpad.h \
     ../src/ss/input/mouse.h \
     ../src/ss/input/multitap.h \
     ../src/ss/input/keyboard.h \
     ../src/ss/input/gun.h \
     ../src/ss/input/wheel.h \
     ../src/ss/input/mission.h \
     ../src/ss/input/jpkeyboard.h \
     ../src/ss/input/common.h \
     ../src/ss/vdp2.h \
     ../src/ss/vdp2_common.h \
     ../src/ss/smpc.h \
     ../src/ss/smpc_iodevice.h \
     ../src/ss/scu.h \
     ../src/ss/cart.h \
     ../src/ss/scsp.h \
     ../src/mednafen.h \
     ../src/AtomicFIFO.h \
     ../src/gba/GBA.h \
     ../src/gba/Sound.h \
     ../src/gba/thumb.h \
     ../src/gba/Globals.h \
     ../src/gba/Port.h \
     ../src/gba/RTC.h \
     ../src/gba/eeprom.h \
     ../src/gba/arm.h \
     ../src/gba/Gfx.h \
     ../src/gba/myrom.h \
     ../src/gba/flash.h \
     ../src/gba/bios.h \
     ../src/gba/sram.h \
     ../src/gba/GBAinline.h \
     ../src/gba/gfx-draw.h \
     ../src/quicklz/quicklz.h \
     ../src/lepacker.h \
     ../src/gettext.h \
     ../src/nes/debug.h \
     ../src/nes/nsfe.h \
     ../src/nes/input.h \
     ../src/nes/nsf.h \
     ../src/nes/fds.h \
     ../src/nes/ops.h \
     ../src/nes/sound.h \
     ../src/nes/boards/vrc7tone.h \
     ../src/nes/boards/mapinc.h \
     ../src/nes/boards/emutypes.h \
     ../src/nes/boards/emu2413.h \
     ../src/nes/ppu/palette.h \
     ../src/nes/ppu/ppu-fastrl.h \
     ../src/nes/ppu/palettes/rp2c04-0001.h \
     ../src/nes/ppu/palettes/rp2c04-0004.h \
     ../src/nes/ppu/palettes/rp2c04-0002.h \
     ../src/nes/ppu/palettes/default.h \
     ../src/nes/ppu/palettes/rp2c04-0003.h \
     ../src/nes/ppu/palettes/rp2c0x.h \
     ../src/nes/ppu/fast-pputile.h \
     ../src/nes/ppu/ppu-subline.h \
     ../src/nes/ppu/ppu.h \
     ../src/nes/fds-sound.h \
     ../src/nes/ines.h \
     ../src/nes/input/share.h \
     ../src/nes/input/cursor.h \
     ../src/nes/input/fkb.h \
     ../src/nes/input/suborkb.h \
     ../src/nes/nes.h \
     ../src/nes/ntsc/nes_ntsc.h \
     ../src/nes/unif.h \
     ../src/nes/x6502.h \
     ../src/nes/dis6502.h \
     ../src/nes/vsuni.h \
     ../src/nes/x6502struct.h \
     ../src/nes/filter.h \
     ../src/nes/cart.h \
     ../src/snes_faust/input.h \
     ../src/snes_faust/snes.h \
     ../src/snes_faust/cpu.h \
     ../src/snes_faust/ppu.h \
     ../src/snes_faust/apu.h \
     ../src/snes_faust/cart.h \
     ../src/settings-common.h \
     ../src/resampler/fixed_generic.h \
     ../src/resampler/arch.h \
     ../src/resampler/resampler.h \
     ../src/resampler/resample_sse.h \
     ../src/resampler/stack_alloc.h \
     ../src/settings-driver.h \
     ../src/tremor/window.h \
     ../src/tremor/registry.h \
     ../src/tremor/block.h \
     ../src/tremor/backends.h \
     ../src/tremor/os.h \
     ../src/tremor/os_types.h \
     ../src/tremor/lsp_lookup.h \
     ../src/tremor/asm_arm.h \
     ../src/tremor/ogg.h \
     ../src/tremor/codebook.h \
     ../src/tremor/ivorbisfile.h \
     ../src/tremor/mdct_lookup.h \
     ../src/tremor/codec_internal.h \
     ../src/tremor/window_lookup.h \
     ../src/tremor/ivorbiscodec.h \
     ../src/tremor/mdct.h \
     ../src/tremor/misc.h \
     ../src/pcfx/interrupt.h \
     ../src/pcfx/pcfx.h \
     ../src/pcfx/debug.h \
     ../src/pcfx/input.h \
     ../src/pcfx/huc6273.h \
     ../src/pcfx/timer.h \
     ../src/pcfx/king.h \
     ../src/pcfx/fxscsi.h \
     ../src/pcfx/input/gamepad.h \
     ../src/pcfx/input/mouse.h \
     ../src/pcfx/rainbow.h \
     ../src/pcfx/jrevdct.h \
     ../src/pcfx/soundbox.h \
     ../src/Time.h \
     ../src/snes/src/chip/dsp4/dsp4emu.h \
     ../src/snes/src/lib/libco/libco.h \
     ../src/wswan/interrupt.h \
     ../src/wswan/debug.h \
     ../src/wswan/dis/dis_tables.h \
     ../src/wswan/dis/disasm.h \
     ../src/wswan/comm.h \
     ../src/wswan/sound.h \
     ../src/wswan/v30mz-private.h \
     ../src/wswan/v30mz.h \
     ../src/wswan/rtc.h \
     ../src/wswan/eeprom.h \
     ../src/wswan/gfx.h \
     ../src/wswan/wswan.h \
     ../src/wswan/memory.h \
     ../src/general.h \
     ../src/desa68/desa68.h \
     ../src/gb/gbCodesCB.h \
     ../src/gb/gbCodes.h \
     ../src/gb/sound.h \
     ../src/gb/z80.h \
     ../src/gb/gb.h \
     ../src/gb/gbGlobals.h \
     ../src/gb/memory.h \
     ../src/SPCReader.h \
     ../src/vb/debug.h \
     ../src/vb/input.h \
     ../src/vb/timer.h \
     ../src/vb/vb.h \
     ../src/vb/vip.h \
     ../src/vb/vsu.h \
     ../src/state-common.h \
     ../src/video-driver.h \
     ../src/hw_sound/ym2413/2413tone.h \
     ../src/hw_sound/ym2413/emu2413.h \
     ../src/hw_sound/ym2612/Ym2612_Emu.h \
     ../src/hw_sound/pce_psg/pce_psg.h \
     ../src/hw_sound/sms_apu/Sms_Apu.h \
     ../src/hw_sound/sms_apu/Sms_Oscs.h \
     ../src/hw_sound/gb_apu/Gb_Oscs.h \
     ../src/hw_sound/gb_apu/blargg_common.h \
     ../src/hw_sound/gb_apu/blargg_source.h \
     ../src/hw_sound/gb_apu/Gb_Apu.h \
     ../src/hw_sound/gb_apu/blargg_config.h \
     ../src/MemoryStream.h \
     ../src/state_rewind.h \
     ../src/movie.h \
     ../src/mempatcher-driver.h \
     ../src/lynx/machine.h \
     ../src/lynx/sysbase.h \
     ../src/lynx/rom.h \
     ../src/lynx/susie.h \
     ../src/lynx/c65c02.h \
     ../src/lynx/memmap.h \
     ../src/lynx/c6502mak.h \
     ../src/lynx/lynxbase.h \
     ../src/lynx/system.h \
     ../src/lynx/lynxdef.h \
     ../src/lynx/ram.h \
     ../src/lynx/cart.h \
     ../src/lynx/mikie.h \
     ../src/hw_cpu/v810/v810_cpuD.h \
     ../src/hw_cpu/v810/v810_fp_ops.h \
     ../src/hw_cpu/v810/v810_cpu.h \
     ../src/hw_cpu/v810/v810_do_am.h \
     ../src/hw_cpu/v810/v810_opt.h \
     ../src/hw_cpu/m68k/m68k.h \
     ../src/hw_cpu/z80-fuse/z80_macros.h \
     ../src/hw_cpu/z80-fuse/z80.h \
     ../src/pce_fast/pcecd.h \
     ../src/pce_fast/input.h \
     ../src/pce_fast/pce.h \
     ../src/pce_fast/huc.h \
     ../src/pce_fast/psg.h \
     ../src/pce_fast/pcecd_drive.h \
     ../src/pce_fast/huc6280.h \
     ../src/pce_fast/hes.h \
     ../src/pce_fast/vdc.h \
     ../src/minilzo/_minilzo.h \
     ../src/compress/GZFileStream.h \
     ../src/compress/ZLInflateFilter.h \
     ../src/compress/ZIPReader.h \
     ../src/hw_video/huc6270/vdc.h \
     ../src/FileStream.h \
     ../src/cdrom/CDAccess.h \
     ../src/cdrom/CDAFReader_MPC.h \
     ../src/cdrom/galois-inlines.h \
     ../src/cdrom/CDAFReader_SF.h \
     ../src/cdrom/scsicd.h \
     ../src/cdrom/CDAFReader_Vorbis.h \
     ../src/cdrom/lec.h \
     ../src/cdrom/cdromif.h \
     ../src/cdrom/SimpleFIFO.h \
     ../src/cdrom/CDAFReader.h \
     ../src/cdrom/CDAccess_Image.h \
     ../src/cdrom/CDAccess_CCD.h \
     ../src/cdrom/dvdisaster.h \
     ../src/cdrom/CDUtility.h \
     ../src/movie-driver.h \
     ../src/mednafen-driver.h \
     ../src/memory.h \
     ../src/string/string.h \
     ../src/string/escape.h \
     ../src/hw_misc/arcade_card/arcade_card.h \
     ../src/psx/mdec.h \
     ../src/psx/debug.h \
     ../src/psx/frontio.h \
     ../src/psx/timer.h \
     ../src/psx/dis.h \
     ../src/psx/cpu.h \
     ../src/psx/FastFIFO.h \
     ../src/psx/dma.h \
     ../src/psx/psx.h \
     ../src/psx/input/negcon.h \
     ../src/psx/input/gamepad.h \
     ../src/psx/input/guncon.h \
     ../src/psx/input/mouse.h \
     ../src/psx/input/multitap.h \
     ../src/psx/input/dualanalog.h \
     ../src/psx/input/memcard.h \
     ../src/psx/input/dualshock.h \
     ../src/psx/input/justifier.h \
     ../src/psx/gpu.h \
     ../src/psx/cdc.h \
     ../src/psx/gte.h \
     ../src/psx/sio.h \
     ../src/psx/spu.h \
     ../src/psx/irq.h \
     ../src/psx/masmem.h \
     ../src/pce/tsushin.h \
     ../src/pce/debug.h \
     ../src/pce/pcecd.h \
     ../src/pce/input.h \
     ../src/pce/dis6280.h \
     ../src/pce/pce.h \
     ../src/pce/huc.h \
     ../src/pce/input/gamepad.h \
     ../src/pce/input/tsushinkb.h \
     ../src/pce/input/mouse.h \
     ../src/pce/mcgenjin.h \
     ../src/pce/vce.h \
     ../src/pce/huc6280.h \
     ../src/pce/hes.h \
     ../src/sexyal/drivers/dos_common.h \
     ../src/sexyal/sexyal.h \
     ../src/sexyal/convert.h \
     ../src/driver.h \
     ../src/tests.h

CATALOGS =  ru.gmo es.gmo de.gmo

# Makevars gets inserted here. (Don't remove this line!)
# Makefile variables for PO directory in any package using GNU gettext.

# Usually the message domain is the same as the package name.
DOMAIN = $(PACKAGE)

# These two variables depend on the location of this directory.
subdir = po
top_builddir = ..

MSGMERGE_OPTIONS = -N

# These options get passed to xgettext.
XGETTEXT_OPTIONS = --keyword=_ --keyword=N_ --from-code=utf-8

# This is the copyright holder that gets inserted into the header of the
# $(DOMAIN).pot file.  Set this to the copyright holder of the surrounding
# package.  (Note that the msgstr strings, extracted from the package's
# sources, belong to the copyright holder of the package.)  Translators are
# expected to transfer the copyright for their translations to this person
# or entity, or to disclaim their copyright.  The empty string stands for
# the public domain; in this case the translators are expected to disclaim
# their copyright.
COPYRIGHT_HOLDER = Mednafen Team

# This is the email address or URL to which the translators shall report
# bugs in the untranslated strings:
# - Strings which are not entire sentences, see the maintainer guidelines
#   in the GNU gettext documentation, section 'Preparing Strings'.
# - Strings which use unclear terms or require additional context to be
#   understood.
# - Strings which make invalid assumptions about notation of date, time or
#   money.
# - Pluralisation problems.
# - Incorrect English spelling.
# - Incorrect formatting.
# It can be your email address, or a mailing list address where translators
# can write to without being subscribed, or the URL of a web page through
# which the translators can contact you.
MSGID_BUGS_ADDRESS = http://forum.fobby.net/

# This is the list of locale categories, beyond LC_MESSAGES, for which the
# message catalogs shall be used.  It is usually empty.
EXTRA_LOCALE_CATEGORIES =

.SUFFIXES:
.SUFFIXES: .po .gmo .mo .sed .sin .nop .po-create .po-update

.po.mo:
	@echo "$(MSGFMT) -c -o $@ $<"; \
	$(MSGFMT) -c -o t-$@ $< && mv t-$@ $@

.po.gmo:
	@lang=`echo $* | sed -e 's,.*/,,'`; \
	test "$(srcdir)" = . && cdcmd="" || cdcmd="cd $(srcdir) && "; \
	echo "$${cdcmd}rm -f $${lang}.gmo && $(GMSGFMT) -c --statistics --verbose -o $${lang}.gmo $${lang}.po"; \
	cd $(srcdir) && rm -f $${lang}.gmo && $(GMSGFMT) -c --statistics --verbose -o t-$${lang}.gmo $${lang}.po && mv t-$${lang}.gmo $${lang}.gmo

.sin.sed:
	sed -e '/^#/d' $< > t-$@
	mv t-$@ $@


all: check-macro-version all-yes

all-yes: stamp-po
all-no:

# Ensure that the gettext macros and this Makefile.in.in are in sync.
check-macro-version:
	@test "$(GETTEXT_MACRO_VERSION)" = "0.18" \
	  || { echo "*** error: gettext infrastructure mismatch: using a Makefile.in.in from gettext version $(GETTEXT_MACRO_VERSION) but the autoconf macros are from gettext version 0.18" 1>&2; \
	       exit 1; \
	     }

# $(srcdir)/$(DOMAIN).pot is only created when needed. When xgettext finds no
# internationalized messages, no $(srcdir)/$(DOMAIN).pot is created (because
# we don't want to bother translators with empty POT files). We assume that
# LINGUAS is empty in this case, i.e. $(POFILES) and $(GMOFILES) are empty.
# In this case, stamp-po is a nop (i.e. a phony target).

# stamp-po is a timestamp denoting the last time at which the CATALOGS have
# been loosely updated. Its purpose is that when a developer or translator
# checks out the package via CVS, and the $(DOMAIN).pot file is not in CVS,
# "make" will update the $(DOMAIN).pot and the $(CATALOGS), but subsequent
# invocations of "make" will do nothing. This timestamp would not be necessary
# if updating the $(CATALOGS) would always touch them; however, the rule for
# $(POFILES) has been designed to not touch files that don't need to be
# changed.
stamp-po: $(srcdir)/$(DOMAIN).pot
	test ! -f $(srcdir)/$(DOMAIN).pot || \
	  test -z "$(GMOFILES)" || $(MAKE) $(GMOFILES)
	@test ! -f $(srcdir)/$(DOMAIN).pot || { \
	  echo "touch stamp-po" && \
	  echo timestamp > stamp-poT && \
	  mv stamp-poT stamp-po; \
	}

# Note: Target 'all' must not depend on target '$(DOMAIN).pot-update',
# otherwise packages like GCC can not be built if only parts of the source
# have been downloaded.

# This target rebuilds $(DOMAIN).pot; it is an expensive operation.
# Note that $(DOMAIN).pot is not touched if it doesn't need to be changed.
$(DOMAIN).pot-update: $(POTFILES) $(srcdir)/POTFILES.in remove-potcdate.sed
	if LC_ALL=C grep 'GNU mednafen' $(top_srcdir)/* 2>/dev/null | grep -v 'libtool:' >/dev/null; then \
	  package_gnu='GNU '; \
	else \
	  package_gnu=''; \
	fi; \
	if test -n '$(MSGID_BUGS_ADDRESS)' || test '$(PACKAGE_BUGREPORT)' = '@'PACKAGE_BUGREPORT'@'; then \
	  msgid_bugs_address='$(MSGID_BUGS_ADDRESS)'; \
	else \
	  msgid_bugs_address='$(PACKAGE_BUGREPORT)'; \
	fi; \
	case `$(XGETTEXT) --version | sed 1q | sed -e 's,^[^0-9]*,,'` in \
	  '' | 0.[0-9] | 0.[0-9].* | 0.1[0-5] | 0.1[0-5].* | 0.16 | 0.16.[0-1]*) \
	    $(XGETTEXT) --default-domain=$(DOMAIN) --directory=$(top_srcdir) \
	      --add-comments=TRANSLATORS: $(XGETTEXT_OPTIONS)  \
	      --files-from=$(srcdir)/POTFILES.in \
	      --copyright-holder='$(COPYRIGHT_HOLDER)' \
	      --msgid-bugs-address="$$msgid_bugs_address" \
	    ;; \
	  *) \
	    $(XGETTEXT) --default-domain=$(DOMAIN) --directory=$(top_srcdir) \
	      --add-comments=TRANSLATORS: $(XGETTEXT_OPTIONS)  \
	      --files-from=$(srcdir)/POTFILES.in \
	      --copyright-holder='$(COPYRIGHT_HOLDER)' \
	      --package-name="$${package_gnu}mednafen" \
	      --package-version='1.21.1' \
	      --msgid-bugs-address="$$msgid_bugs_address" \
	    ;; \
	esac
	test ! -f $(DOMAIN).po || { \
	  if test -f $(srcdir)/$(DOMAIN).pot; then \
	    sed -f remove-potcdate.sed < $(srcdir)/$(DOMAIN).pot > $(DOMAIN).1po && \
	    sed -f remove-potcdate.sed < $(DOMAIN).po > $(DOMAIN).2po && \
	    if cmp $(DOMAIN).1po $(DOMAIN).2po >/dev/null 2>&1; then \
	      rm -f $(DOMAIN).1po $(DOMAIN).2po $(DOMAIN).po; \
	    else \
	      rm -f $(DOMAIN).1po $(DOMAIN).2po $(srcdir)/$(DOMAIN).pot && \
	      mv $(DOMAIN).po $(srcdir)/$(DOMAIN).pot; \
	    fi; \
	  else \
	    mv $(DOMAIN).po $(srcdir)/$(DOMAIN).pot; \
	  fi; \
	}

# This rule has no dependencies: we don't need to update $(DOMAIN).pot at
# every "make" invocation, only create it when it is missing.
# Only "make $(DOMAIN).pot-update" or "make dist" will force an update.
$(srcdir)/$(DOMAIN).pot:
	$(MAKE) $(DOMAIN).pot-update

# This target rebuilds a PO file if $(DOMAIN).pot has changed.
# Note that a PO file is not touched if it doesn't need to be changed.
$(POFILES): $(srcdir)/$(DOMAIN).pot
	@lang=`echo $@ | sed -e 's,.*/,,' -e 's/\.po$$//'`; \
	if test -f "$(srcdir)/$${lang}.po"; then \
	  test "$(srcdir)" = . && cdcmd="" || cdcmd="cd $(srcdir) && "; \
	  echo "$${cdcmd}$(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) --lang=$${lang} $${lang}.po $(DOMAIN).pot"; \
	  cd $(srcdir) \
	    && { case `$(MSGMERGE_UPDATE) --version | sed 1q | sed -e 's,^[^0-9]*,,'` in \
	           '' | 0.[0-9] | 0.[0-9].* | 0.1[0-7] | 0.1[0-7].*) \
	             $(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) $${lang}.po $(DOMAIN).pot;; \
	           *) \
	             $(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) --lang=$${lang} $${lang}.po $(DOMAIN).pot;; \
	         esac; \
	       }; \
	else \
	  $(MAKE) $${lang}.po-create; \
	fi


install: install-exec install-data
install-exec:
install-data: install-data-yes
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  $(mkdir_p) $(DESTDIR)$(gettextsrcdir); \
	  for file in $(DISTFILES.common) Makevars.template; do \
	    $(INSTALL_DATA) $(srcdir)/$$file \
			    $(DESTDIR)$(gettextsrcdir)/$$file; \
	  done; \
	  for file in Makevars; do \
	    rm -f $(DESTDIR)$(gettextsrcdir)/$$file; \
	  done; \
	else \
	  : ; \
	fi
install-data-no: all
install-data-yes: all
	@catalogs='$(CATALOGS)'; \
	for cat in $$catalogs; do \
	  cat=`basename $$cat`; \
	  lang=`echo $$cat | sed -e 's/\.gmo$$//'`; \
	  dir=$(localedir)/$$lang/LC_MESSAGES; \
	  $(mkdir_p) $(DESTDIR)$$dir; \
	  if test -r $$cat; then realcat=$$cat; else realcat=$(srcdir)/$$cat; fi; \
	  $(INSTALL_DATA) $$realcat $(DESTDIR)$$dir/$(DOMAIN).mo; \
	  echo "installing $$realcat as $(DESTDIR)$$dir/$(DOMAIN).mo"; \
	  for lc in '' $(EXTRA_LOCALE_CATEGORIES); do \
	    if test -n "$$lc"; then \
	      if (cd $(DESTDIR)$(localedir)/$$lang && LC_ALL=C ls -l -d $$lc 2>/dev/null) | grep ' -> ' >/dev/null; then \
	        link=`cd $(DESTDIR)$(localedir)/$$lang && LC_ALL=C ls -l -d $$lc | sed -e 's/^.* -> //'`; \
	        mv $(DESTDIR)$(localedir)/$$lang/$$lc $(DESTDIR)$(localedir)/$$lang/$$lc.old; \
	        mkdir $(DESTDIR)$(localedir)/$$lang/$$lc; \
	        (cd $(DESTDIR)$(localedir)/$$lang/$$lc.old && \
	         for file in *; do \
	           if test -f $$file; then \
	             ln -s ../$$link/$$file $(DESTDIR)$(localedir)/$$lang/$$lc/$$file; \
	           fi; \
	         done); \
	        rm -f $(DESTDIR)$(localedir)/$$lang/$$lc.old; \
	      else \
	        if test -d $(DESTDIR)$(localedir)/$$lang/$$lc; then \
	          :; \
	        else \
	          rm -f $(DESTDIR)$(localedir)/$$lang/$$lc; \
	          mkdir $(DESTDIR)$(localedir)/$$lang/$$lc; \
	        fi; \
	      fi; \
	      rm -f $(DESTDIR)$(localedir)/$$lang/$$lc/$(DOMAIN).mo; \
	      ln -s ../LC_MESSAGES/$(DOMAIN).mo $(DESTDIR)$(localedir)/$$lang/$$lc/$(DOMAIN).mo 2>/dev/null || \
	      ln $(DESTDIR)$(localedir)/$$lang/LC_MESSAGES/$(DOMAIN).mo $(DESTDIR)$(localedir)/$$lang/$$lc/$(DOMAIN).mo 2>/dev/null || \
	      cp -p $(DESTDIR)$(localedir)/$$lang/LC_MESSAGES/$(DOMAIN).mo $(DESTDIR)$(localedir)/$$lang/$$lc/$(DOMAIN).mo; \
	      echo "installing $$realcat link as $(DESTDIR)$(localedir)/$$lang/$$lc/$(DOMAIN).mo"; \
	    fi; \
	  done; \
	done

install-strip: install

installdirs: installdirs-exec installdirs-data
installdirs-exec:
installdirs-data: installdirs-data-yes
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  $(mkdir_p) $(DESTDIR)$(gettextsrcdir); \
	else \
	  : ; \
	fi
installdirs-data-no:
installdirs-data-yes:
	@catalogs='$(CATALOGS)'; \
	for cat in $$catalogs; do \
	  cat=`basename $$cat`; \
	  lang=`echo $$cat | sed -e 's/\.gmo$$//'`; \
	  dir=$(localedir)/$$lang/LC_MESSAGES; \
	  $(mkdir_p) $(DESTDIR)$$dir; \
	  for lc in '' $(EXTRA_LOCALE_CATEGORIES); do \
	    if test -n "$$lc"; then \
	      if (cd $(DESTDIR)$(localedir)/$$lang && LC_ALL=C ls -l -d $$lc 2>/dev/null) | grep ' -> ' >/dev/null; then \
	        link=`cd $(DESTDIR)$(localedir)/$$lang && LC_ALL=C ls -l -d $$lc | sed -e 's/^.* -> //'`; \
	        mv $(DESTDIR)$(localedir)/$$lang/$$lc $(DESTDIR)$(localedir)/$$lang/$$lc.old; \
	        mkdir $(DESTDIR)$(localedir)/$$lang/$$lc; \
	        (cd $(DESTDIR)$(localedir)/$$lang/$$lc.old && \
	         for file in *; do \
	           if test -f $$file; then \
	             ln -s ../$$link/$$file $(DESTDIR)$(localedir)/$$lang/$$lc/$$file; \
	           fi; \
	         done); \
	        rm -f $(DESTDIR)$(localedir)/$$lang/$$lc.old; \
	      else \
	        if test -d $(DESTDIR)$(localedir)/$$lang/$$lc; then \
	          :; \
	        else \
	          rm -f $(DESTDIR)$(localedir)/$$lang/$$lc; \
	          mkdir $(DESTDIR)$(localedir)/$$lang/$$lc; \
	        fi; \
	      fi; \
	    fi; \
	  done; \
	done

# Define this as empty until I found a useful application.
installcheck:

uninstall: uninstall-exec uninstall-data
uninstall-exec:
uninstall-data: uninstall-data-yes
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  for file in $(DISTFILES.common) Makevars.template; do \
	    rm -f $(DESTDIR)$(gettextsrcdir)/$$file; \
	  done; \
	else \
	  : ; \
	fi
uninstall-data-no:
uninstall-data-yes:
	catalogs='$(CATALOGS)'; \
	for cat in $$catalogs; do \
	  cat=`basename $$cat`; \
	  lang=`echo $$cat | sed -e 's/\.gmo$$//'`; \
	  for lc in LC_MESSAGES $(EXTRA_LOCALE_CATEGORIES); do \
	    rm -f $(DESTDIR)$(localedir)/$$lang/$$lc/$(DOMAIN).mo; \
	  done; \
	done

check: all

info dvi ps pdf html tags TAGS ctags CTAGS ID:

mostlyclean:
	rm -f remove-potcdate.sed
	rm -f stamp-poT
	rm -f core core.* $(DOMAIN).po $(DOMAIN).1po $(DOMAIN).2po *.new.po
	rm -fr *.o

clean: mostlyclean

distclean: clean
	rm -f Makefile Makefile.in POTFILES *.mo

maintainer-clean: distclean
	@echo "This command is intended for maintainers to use;"
	@echo "it deletes files that may require special tools to rebuild."
	rm -f stamp-po $(GMOFILES)

distdir = $(top_builddir)/$(PACKAGE)-$(VERSION)/$(subdir)
dist distdir:
	$(MAKE) update-po
	@$(MAKE) dist2
# This is a separate target because 'update-po' must be executed before.
dist2: stamp-po $(DISTFILES)
	dists="$(DISTFILES)"; \
	if test "$(PACKAGE)" = "gettext-tools"; then \
	  dists="$$dists Makevars.template"; \
	fi; \
	if test -f $(srcdir)/$(DOMAIN).pot; then \
	  dists="$$dists $(DOMAIN).pot stamp-po"; \
	fi; \
	if test -f $(srcdir)/ChangeLog; then \
	  dists="$$dists ChangeLog"; \
	fi; \
	for i in 0 1 2 3 4 5 6 7 8 9; do \
	  if test -f $(srcdir)/ChangeLog.$$i; then \
	    dists="$$dists ChangeLog.$$i"; \
	  fi; \
	done; \
	if test -f $(srcdir)/LINGUAS; then dists="$$dists LINGUAS"; fi; \
	for file in $$dists; do \
	  if test -f $$file; then \
	    cp -p $$file $(distdir) || exit 1; \
	  else \
	    cp -p $(srcdir)/$$file $(distdir) || exit 1; \
	  fi; \
	done

update-po: Makefile
	$(MAKE) $(DOMAIN).pot-update
	test -z "$(UPDATEPOFILES)" || $(MAKE) $(UPDATEPOFILES)
	$(MAKE) update-gmo

# General rule for creating PO files.

.nop.po-create:
	@lang=`echo $@ | sed -e 's/\.po-create$$//'`; \
	echo "File $$lang.po does not exist. If you are a translator, you can create it through 'msginit'." 1>&2; \
	exit 1

# General rule for updating PO files.

.nop.po-update:
	@lang=`echo $@ | sed -e 's/\.po-update$$//'`; \
	if test "$(PACKAGE)" = "gettext-tools"; then PATH=`pwd`/../src:$$PATH; fi; \
	tmpdir=`pwd`; \
	echo "$$lang:"; \
	test "$(srcdir)" = . && cdcmd="" || cdcmd="cd $(srcdir) && "; \
	echo "$${cdcmd}$(MSGMERGE) $(MSGMERGE_OPTIONS) --lang=$$lang $$lang.po $(DOMAIN).pot -o $$lang.new.po"; \
	cd $(srcdir); \
	if { case `$(MSGMERGE) --version | sed 1q | sed -e 's,^[^0-9]*,,'` in \
	       '' | 0.[0-9] | 0.[0-9].* | 0.1[0-7] | 0.1[0-7].*) \
	         $(MSGMERGE) $(MSGMERGE_OPTIONS) -o $$tmpdir/$$lang.new.po $$lang.po $(DOMAIN).pot;; \
	       *) \
	         $(MSGMERGE) $(MSGMERGE_OPTIONS) --lang=$$lang -o $$tmpdir/$$lang.new.po $$lang.po $(DOMAIN).pot;; \
	     esac; \
	   }; then \
	  if cmp $$lang.po $$tmpdir/$$lang.new.po >/dev/null 2>&1; then \
	    rm -f $$tmpdir/$$lang.new.po; \
	  else \
	    if mv -f $$tmpdir/$$lang.new.po $$lang.po; then \
	      :; \
	    else \
	      echo "msgmerge for $$lang.po failed: cannot move $$tmpdir/$$lang.new.po to $$lang.po" 1>&2; \
	      exit 1; \
	    fi; \
	  fi; \
	else \
	  echo "msgmerge for $$lang.po failed!" 1>&2; \
	  rm -f $$tmpdir/$$lang.new.po; \
	fi

$(DUMMYPOFILES):

update-gmo: Makefile $(GMOFILES)
	@:

# Recreate Makefile by invoking config.status. Explicitly invoke the shell,
# because execution permission bits may not work on the current file system.
# Use /bin/sh, which is the shell determined by autoconf for the use by its
# scripts, not $(SHELL) which is hardwired to /bin/sh and may be deficient.
Makefile: Makefile.in.in Makevars $(top_builddir)/config.status POTFILES.in LINGUAS
	cd $(top_builddir) \
	  && /bin/sh ./config.status $(subdir)/$@.in po-directories

force:

# Tell versions [3.59,3.63) of GNU make not to export all variables.
# Otherwise a system limit (for SysV at least) may be exceeded.
.NOEXPORT:
# Special Makefile rules for English message catalogs with quotation marks.

DISTFILES.common.extra1 = quot.sed boldquot.sed en@quot.header en@boldquot.header insert-header.sin Rules-quot

.SUFFIXES: .insert-header .po-update-en

en@quot.po-create:
	$(MAKE) en@quot.po-update
en@boldquot.po-create:
	$(MAKE) en@boldquot.po-update

en@quot.po-update: en@quot.po-update-en
en@boldquot.po-update: en@boldquot.po-update-en

.insert-header.po-update-en:
	@lang=`echo $@ | sed -e 's/\.po-update-en$$//'`; \
	if test "$(PACKAGE)" = "gettext"; then PATH=`pwd`/../src:$$PATH; GETTEXTLIBDIR=`cd $(top_srcdir)/src && pwd`; export GETTEXTLIBDIR; fi; \
	tmpdir=`pwd`; \
	echo "$$lang:"; \
	ll=`echo $$lang | sed -e 's/@.*//'`; \
	LC_ALL=C; export LC_ALL; \
	cd $(srcdir); \
	if $(MSGINIT) -i $(DOMAIN).pot --no-translator -l $$lang -o - 2>/dev/null | sed -f $$tmpdir/$$lang.insert-header | $(MSGCONV) -t UTF-8 | $(MSGFILTER) sed -f `echo $$lang | sed -e 's/.*@//'`.sed 2>/dev/null > $$tmpdir/$$lang.new.po; then \
	  if cmp $$lang.po $$tmpdir/$$lang.new.po >/dev/null 2>&1; then \
	    rm -f $$tmpdir/$$lang.new.po; \
	  else \
	    if mv -f $$tmpdir/$$lang.new.po $$lang.po; then \
	      :; \
	    else \
	      echo "creation of $$lang.po failed: cannot move $$tmpdir/$$lang.new.po to $$lang.po" 1>&2; \
	      exit 1; \
	    fi; \
	  fi; \
	else \
	  echo "creation of $$lang.po failed!" 1>&2; \
	  rm -f $$tmpdir/$$lang.new.po; \
	fi

en@quot.insert-header: insert-header.sin
	sed -e '/^#/d' -e 's/HEADER/en@quot.header/g' $(srcdir)/insert-header.sin > en@quot.insert-header

en@boldquot.insert-header: insert-header.sin
	sed -e '/^#/d' -e 's/HEADER/en@boldquot.header/g' $(srcdir)/insert-header.sin > en@boldquot.insert-header

mostlyclean: mostlyclean-quot
mostlyclean-quot:
	rm -f *.insert-header
