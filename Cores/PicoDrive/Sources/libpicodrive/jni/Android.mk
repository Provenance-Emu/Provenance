LOCAL_PATH := $(call my-dir)

CORE_DIR     := $(LOCAL_PATH)/..
COMMON_DIR   := $(CORE_DIR)/platform/common
LIBRETRO_DIR := $(CORE_DIR)/platform/libretro
LIBRETRO_COMM_DIR := $(LIBRETRO_DIR)/libretro-common
UNZIP_DIR    := $(CORE_DIR)/unzip
R            := $(CORE_DIR)/
FR           := $(R)

SRCS_COMMON :=
DEFINES     :=
ARCH        := $(TARGET_ARCH)

use_cyclone  := 0
use_fame     := 1
use_musashi  := 0
use_drz80    := 0
use_cz80     := 1
use_sh2drc   := 0
use_svpdrc   := 0

asm_memory   := 0
asm_render   := 0
asm_ym2612   := 0
asm_misc     := 0
asm_cdmemory := 0
asm_mix      := 0
asm_32xdraw  := 0
asm_32xmemory := 0

ifeq ($(TARGET_ARCH),arm)
#  use_cyclone  := 1
#  use_fame     := 0
#  use_drz80    := 1
#  use_cz80     := 0
  use_sh2drc   := 1
#  use_svpdrc   := 1

#  asm_memory   := 1
#  asm_render   := 1
#  asm_ym2612   := 1
#  asm_misc     := 1
#  asm_cdmemory := 1
#  asm_mix      := 1
#  asm_32xdraw  := 1
#  asm_32xmemory := 1
endif

ifeq ($(TARGET_ARCH_ABI),armeabi)
  CYCLONE_CONFIG := cyclone_config_armv4.h
endif

include $(COMMON_DIR)/common.mak

LCHDR = $(CORE_DIR)/pico/cd/libchdr
LCHDR_LZMA = $(LCHDR)/deps/lzma-24.05
LCHDR_ZSTD = $(LCHDR)/deps/zstd-1.5.6/lib

SOURCES_C := $(LIBRETRO_DIR)/libretro.c \
             $(LIBRETRO_COMM_DIR)/formats/png/rpng.c \
             $(LIBRETRO_COMM_DIR)/streams/trans_stream.c \
             $(LIBRETRO_COMM_DIR)/streams/trans_stream_pipe.c \
             $(LIBRETRO_COMM_DIR)/streams/trans_stream_zlib.c \
             $(LIBRETRO_COMM_DIR)/file/file_path_io.c \
             $(LIBRETRO_COMM_DIR)/file/file_path.c \
             $(LIBRETRO_COMM_DIR)/vfs/vfs_implementation.c \
             $(LIBRETRO_COMM_DIR)/time/rtime.c \
             $(LIBRETRO_COMM_DIR)/string/stdstring.c \
             $(LIBRETRO_COMM_DIR)/encodings/encoding_utf.c \
             $(LIBRETRO_COMM_DIR)/compat/compat_strcasestr.c \
             $(LIBRETRO_COMM_DIR)/compat/compat_strl.c \
             $(COMMON_DIR)/mp3.c \
             $(COMMON_DIR)/mp3_sync.c \
             $(COMMON_DIR)/mp3_dummy.c \
             $(UNZIP_DIR)/unzip.c \
             $(LCHDR)/src/libchdr_bitstream.c \
             $(LCHDR)/src/libchdr_cdrom.c \
             $(LCHDR)/src/libchdr_chd.c \
             $(LCHDR)/src/libchdr_flac.c \
             $(LCHDR)/src/libchdr_huffman.c \
             $(LCHDR_LZMA)/src/Alloc.c \
             $(LCHDR_LZMA)/src/CpuArch.c \
             $(LCHDR_LZMA)/src/Delta.c \
             $(LCHDR_LZMA)/src/LzFind.c \
             $(LCHDR_LZMA)/src/LzmaDec.c \
             $(LCHDR_LZMA)/src/LzmaEnc.c \
             $(LCHDR_LZMA)/src/Sort.c \
             $(LCHDR_ZSTD)/common/entropy_common.c \
             $(LCHDR_ZSTD)/common/error_private.c \
             $(LCHDR_ZSTD)/common/fse_decompress.c \
             $(LCHDR_ZSTD)/common/xxhash.c \
             $(LCHDR_ZSTD)/common/zstd_common.c \
             $(LCHDR_ZSTD)/decompress/huf_decompress.c \
             $(LCHDR_ZSTD)/decompress/zstd_ddict.c \
             $(LCHDR_ZSTD)/decompress/zstd_decompress_block.c \
             $(LCHDR_ZSTD)/decompress/zstd_decompress.c

COREFLAGS := $(addprefix -D,$(DEFINES)) -fno-strict-aliasing -DUSE_LIBCHDR=1 -DZ7_ST -DZSTD_DISABLE_ASM
COREFLAGS += -I$(LCHDR)/include -I$(LCHDR_LZMA)/include -I$(LCHDR_ZSTD)
ifeq (,$(call gte,$(APP_PLATFORM_LEVEL),18))
ifneq ($(TARGET_ARCH_ABI),arm64-v8a)
# HACK
COREFLAGS += -Dgetauxval=0*
endif
endif

GIT_REVISION := $(shell git rev-parse --short HEAD || echo unknown)
COREFLAGS += -DREVISION=\"$(GIT_REVISION)\"

ifneq ($(filter armeabi%, $(TARGET_ARCH_ABI)),)
$(CORE_DIR)/pico/pico_int_offs.h:
	cp $(CORE_DIR)/tools/offsets/generic-ilp32-offsets.h $@
.PHONY: $(CORE_DIR)/pico/pico_int_offs.h

$(filter %.S,$(SRCS_COMMON)): $(CORE_DIR)/pico/pico_int_offs.h
endif

include $(CLEAR_VARS)
LOCAL_MODULE     := retro
LOCAL_SRC_FILES  := $(SRCS_COMMON) $(SOURCES_C)
LOCAL_CFLAGS     := $(COREFLAGS)
LOCAL_C_INCLUDES := $(CORE_DIR) $(LIBRETRO_COMM_DIR)/include
LOCAL_LDFLAGS    := -Wl,-version-script=$(LIBRETRO_DIR)/link.T
LOCAL_LDLIBS     := -llog -lz
LOCAL_ARM_MODE   := arm

ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
  LOCAL_ARM_NEON := true
endif

include $(BUILD_SHARED_LIBRARY)
