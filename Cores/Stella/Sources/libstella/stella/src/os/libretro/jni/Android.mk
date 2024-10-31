LOCAL_PATH := $(call my-dir)

CORE_DIR := $(LOCAL_PATH)/../../..

include $(CORE_DIR)/os/libretro/Makefile.common

COREFLAGS := -DANDROID -D__LIB_RETRO__ -DHAVE_STRINGS_H -DSOUND_SUPPORT $(INCFLAGS)

GIT_VERSION := " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
  COREFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

include $(CLEAR_VARS)
LOCAL_MODULE    := retro
LOCAL_SRC_FILES := $(SOURCES_CXX) $(SOURCES_C)
LOCAL_CXXFLAGS  := $(COREFLAGS) -std=c++17
LOCAL_LDFLAGS   := -Wl,-version-script=$(CORE_DIR)/os/libretro/link.T
include $(BUILD_SHARED_LIBRARY)
