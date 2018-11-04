LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

ifeq ($(NEON_BUILD)$(TARGET_ARCH_ABI),1armeabi-v7a)
  LOCAL_MODULE := retro_picodrive-neon
else
  LOCAL_MODULE := retro_picodrive
endif

R := ../
FR := $(LOCAL_PATH)/$(R)

use_cyclone = 0
use_fame = 0
use_musashi = 0
use_drz80 = 0
use_cz80 = 0
use_sh2drc = 0
use_sh2mame = 0
use_svpdrc = 0

asm_memory = 0
asm_render = 0
asm_ym2612 = 0
asm_misc = 0
asm_cdpico = 0
asm_cdmemory = 0
asm_mix = 0

ifeq ($(TARGET_ARCH),arm)
  LOCAL_ARM_MODE := arm
  ifeq ($(NEON_BUILD),1)
    LOCAL_ARM_NEON := true
  endif

  use_cyclone = 1
  use_drz80 = 1
  use_sh2drc = 1
  use_svpdrc = 1

  asm_memory = 1
  asm_render = 1
  asm_ym2612 = 1
  asm_misc = 1
  asm_cdpico = 1
  asm_cdmemory = 1
  asm_mix = 1
else
  use_fame = 1
  use_cz80 = 1
  use_sh2mame = 1
endif

# sources
SRCS_COMMON :=
DEFINES :=
ARCH := $(TARGET_ARCH)
include $(R)platform/common/common.mak

LOCAL_SRC_FILES += $(SRCS_COMMON)
LOCAL_SRC_FILES += $(R)platform/libretro.c
LOCAL_SRC_FILES += $(R)platform/common/mp3.c
LOCAL_SRC_FILES += $(R)platform/common/mp3_dummy.c

# zlib/unzip
LOCAL_SRC_FILES += $(R)zlib/gzio.c $(R)zlib/inffast.c $(R)zlib/inflate.c \
	$(R)zlib/inftrees.c $(R)zlib/trees.c $(R)zlib/deflate.c \
	$(R)zlib/crc32.c $(R)zlib/adler32.c $(R)zlib/zutil.c \
	$(R)zlib/compress.c $(R)zlib/uncompr.c

LOCAL_SRC_FILES += $(R)unzip/unzip.c $(R)unzip/unzip_stream.c

LOCAL_C_INCLUDES += $(R)

LOCAL_CFLAGS += $(addprefix -D,$(DEFINES))
LOCAL_CFLAGS += -Wall -O3 -ffast-math -DNDEBUG
LOCAL_LDLIBS := -llog

include $(BUILD_SHARED_LIBRARY)
