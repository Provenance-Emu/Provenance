LOCAL_PATH := $(call my-dir)

CORE_DIR := $(LOCAL_PATH)/..
HAS_GPU := 1
GLES    := 1

include $(CORE_DIR)/Makefile.common

COREFLAGS   := -ffast-math $(COREDEFINES) $(INCFLAGS)
GIT_VERSION := " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
  COREFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\" -DHAVE_OPENGLES=1
endif

include $(CLEAR_VARS)
LOCAL_MODULE    := retro
LOCAL_SRC_FILES := $(SOURCES_C)
LOCAL_CFLAGS    := -std=gnu99 $(COREFLAGS)
LOCAL_LDFLAGS   := -Wl,-version-script=$(CORE_DIR)/link.T
LOCAL_LDLIBS    := -lGLESv2
include $(BUILD_SHARED_LIBRARY)
