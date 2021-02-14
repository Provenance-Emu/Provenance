ifdef drc_debug
use_fame = 1
use_cz80 = 1
use_cyclone = 0
use_drz80 = 0

asm_memory = 0
asm_render = 0
asm_ym2612 = 0
asm_misc = 0
asm_cdpico = 0
asm_cdmemory = 0
asm_mix = 0
endif

ifeq "$(profile)" "1"
CFLAGS += -fprofile-generate
endif
ifeq "$(profile)" "2"
CFLAGS += -fprofile-use
endif
ifeq "$(pdb)" "1"
DEFINES += PDB
SRCS_COMMON += $(R)cpu/debug.c
 ifeq "$(pdb_net)" "1"
 DEFINES += PDB_NET
 endif
 ifeq "$(readline)" "1"
 DEFINES += HAVE_READLINE
 LDFLAGS += -lreadline
 endif
endif
ifeq "$(cpu_cmp)" "1"
ifdef cpu_cmp_w
DEFINES += CPU_CMP_W
else
DEFINES += CPU_CMP_R
endif # cpu_cmp_w
endif
ifeq "$(pprof)" "1"
DEFINES += PPROF
SRCS_COMMON += $(R)platform/linux/pprof.c
endif

# ARM asm stuff
ifeq "$(ARCH)" "arm"
ifeq "$(asm_render)" "1"
DEFINES += _ASM_DRAW_C
SRCS_COMMON += $(R)pico/draw_arm.S $(R)pico/draw2_arm.S
endif
ifeq "$(asm_memory)" "1"
DEFINES += _ASM_MEMORY_C
SRCS_COMMON += $(R)pico/memory_arm.s
endif
ifeq "$(asm_ym2612)" "1"
DEFINES += _ASM_YM2612_C
SRCS_COMMON += $(R)pico/sound/ym2612_arm.s
endif
ifeq "$(asm_misc)" "1"
DEFINES += _ASM_MISC_C
SRCS_COMMON += $(R)pico/misc_arm.s
SRCS_COMMON += $(R)pico/cd/misc_arm.s
endif
ifeq "$(asm_cdpico)" "1"
DEFINES += _ASM_CD_PICO_C
SRCS_COMMON += $(R)pico/cd/mcd_arm.s
endif
ifeq "$(asm_cdmemory)" "1"
DEFINES += _ASM_CD_MEMORY_C
SRCS_COMMON += $(R)pico/cd/memory_arm.s
endif
ifeq "$(asm_32xdraw)" "1"
DEFINES += _ASM_32X_DRAW
SRCS_COMMON += $(R)pico/32x/draw_arm.s
endif
ifeq "$(asm_mix)" "1"
SRCS_COMMON += $(R)pico/sound/mix_arm.s
endif
endif # ARCH=arm

# === Pico core ===
# Pico
SRCS_COMMON += $(R)pico/pico.c $(R)pico/cart.c $(R)pico/memory.c \
	$(R)pico/state.c $(R)pico/sek.c $(R)pico/z80if.c \
	$(R)pico/videoport.c $(R)pico/draw2.c $(R)pico/draw.c \
	$(R)pico/mode4.c $(R)pico/misc.c $(R)pico/eeprom.c \
	$(R)pico/patch.c $(R)pico/debug.c $(R)pico/media.c
# SMS
ifneq "$(no_sms)" "1"
SRCS_COMMON += $(R)pico/sms.c
else
DEFINES += NO_SMS
endif
# CD
SRCS_COMMON += $(R)pico/cd/mcd.c $(R)pico/cd/memory.c $(R)pico/cd/sek.c \
	$(R)pico/cd/cdc.c $(R)pico/cd/cdd.c $(R)pico/cd/cd_image.c \
	$(R)pico/cd/cue.c $(R)pico/cd/gfx.c $(R)pico/cd/gfx_dma.c \
	$(R)pico/cd/misc.c $(R)pico/cd/pcm.c
# 32X
ifneq "$(no_32x)" "1"
SRCS_COMMON += $(R)pico/32x/32x.c $(R)pico/32x/memory.c $(R)pico/32x/draw.c \
	$(R)pico/32x/sh2soc.c $(R)pico/32x/pwm.c
else
DEFINES += NO_32X
endif
# Pico
SRCS_COMMON += $(R)pico/pico/pico.c $(R)pico/pico/memory.c $(R)pico/pico/xpcm.c
# carthw
SRCS_COMMON += $(R)pico/carthw/carthw.c
# SVP
SRCS_COMMON += $(R)pico/carthw/svp/svp.c $(R)pico/carthw/svp/memory.c \
	$(R)pico/carthw/svp/ssp16.c
ifeq "$(use_svpdrc)" "1"
DEFINES += _SVP_DRC
SRCS_COMMON += $(R)pico/carthw/svp/stub_arm.S
SRCS_COMMON += $(R)pico/carthw/svp/compiler.c
endif
# sound
SRCS_COMMON += $(R)pico/sound/sound.c
SRCS_COMMON += $(R)pico/sound/sn76496.c $(R)pico/sound/ym2612.c
ifneq "$(ARCH)$(asm_mix)" "arm1"
SRCS_COMMON += $(R)pico/sound/mix.c
endif

# === CPU cores ===
# --- M68k ---
ifeq "$(use_musashi)" "1"
DEFINES += EMU_M68K
SRCS_COMMON += $(R)cpu/musashi/m68kops.c $(R)cpu/musashi/m68kcpu.c
#SRCS_COMMON += $(R)cpu/musashi/m68kdasm.c
endif
ifeq "$(use_cyclone)" "1"
DEFINES += EMU_C68K
SRCS_COMMON += $(R)pico/m68kif_cyclone.s $(R)cpu/cyclone/Cyclone.s \
	$(R)cpu/cyclone/tools/idle.s
endif
ifeq "$(use_fame)" "1"
DEFINES += EMU_F68K
SRCS_COMMON += $(R)cpu/fame/famec.c
endif

# --- Z80 ---
ifeq "$(use_drz80)" "1"
DEFINES += _USE_DRZ80
SRCS_COMMON += $(R)cpu/DrZ80/drz80.s
endif
#
ifeq "$(use_cz80)" "1"
DEFINES += _USE_CZ80
SRCS_COMMON += $(R)cpu/cz80/cz80.c
endif

# --- SH2 ---
SRCS_COMMON += $(R)cpu/drc/cmn.c
ifneq "$(no_32x)" "1"
SRCS_COMMON += $(R)cpu/sh2/sh2.c
#
ifeq "$(use_sh2drc)" "1"
DEFINES += DRC_SH2
SRCS_COMMON += $(R)cpu/sh2/compiler.c
ifdef drc_debug
DEFINES += DRC_DEBUG=$(drc_debug)
SRCS_COMMON += $(R)cpu/sh2/mame/sh2dasm.c
SRCS_COMMON += $(R)platform/libpicofe/linux/host_dasm.c
LDFLAGS += -lbfd -lopcodes -liberty
endif
endif # use_sh2drc
SRCS_COMMON += $(R)cpu/sh2/mame/sh2pico.c
endif # !no_32x

OBJS_COMMON := $(SRCS_COMMON:.c=.o)
OBJS_COMMON := $(OBJS_COMMON:.s=.o)
OBJS_COMMON := $(OBJS_COMMON:.S=.o)

ifneq ($(deps_set),yes)
ifeq "$(use_cyclone)" "1"
$(FR)pico/pico.c: $(FR)cpu/cyclone/Cyclone.h
endif

$(FR)cpu/cyclone/Cyclone.h:
	@echo "Cyclone submodule is missing, please run 'git submodule update --init'"
	@false

$(FR)cpu/cyclone/Cyclone.s: $(FR)cpu/cyclone_config.h
	@echo building Cyclone...
	@make -C $(R)cpu/cyclone/ CONFIG_FILE=../cyclone_config.h

$(FR)cpu/cyclone/Cyclone.s: $(FR)cpu/cyclone/*.cpp $(FR)cpu/cyclone/*.h

$(FR)cpu/musashi/m68kops.c:
	@make -C $(R)cpu/musashi

deps_set = yes
endif # deps_set
