# Copyright (C) 2009 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

LOCAL_PATH:= $(call my-dir)/..

include $(CLEAR_VARS)

FOR_ANDROID := 1
WEBUI := 1
USE_GLES := 1

ifneq ($(TARGET_ARCH_ABI),armeabi-v7a)
  NOT_ARM := 1
else
  NOT_ARM := 
endif

ifeq ($(TARGET_ARCH_ABI),x86)
  X86_REC := 1
else
  X86_REC := 
endif

ifeq ($(TARGET_ARCH_ABI),mips)
  ISMIPS := 1
  NO_REC := 1
else
  ISMIPS :=
  NO_REC :=
endif

$(info $$TARGET_ARCH_ABI is [${TARGET_ARCH_ABI}])

include $(LOCAL_PATH)/../../../../../core/core.mk

LOCAL_SRC_FILES := $(RZDCY_FILES)
LOCAL_SRC_FILES += $(wildcard $(LOCAL_PATH)/jni/src/Android.cpp)
LOCAL_SRC_FILES += $(wildcard $(LOCAL_PATH)/jni/src/utils.cpp)
LOCAL_CFLAGS  := $(RZDCY_CFLAGS) -fPIC -fvisibility=hidden -ffunction-sections -fdata-sections
LOCAL_CXXFLAGS  := $(RZDCY_CXXFLAGS) -fPIC -fvisibility=hidden -fvisibility-inlines-hidden -ffunction-sections -fdata-sections
LOCAL_CPPFLAGS  := $(RZDCY_CXXFLAGS) -fPIC -fvisibility=hidden -fvisibility-inlines-hidden -ffunction-sections -fdata-sections

# LOCAL_CFLAGS += -std=c++11
LOCAL_CXXFLAGS += -std=c++11

ifeq ($(TARGET_ARCH_ABI),x86)
  LOCAL_CFLAGS+= -DTARGET_NO_AREC
  LOCAL_CXXFLAGS+= -DTARGET_NO_AREC -fpermissive
  LOCAL_CPPFLAGS+= -DTARGET_NO_AREC
endif

LOCAL_CPP_FEATURES := 
# LOCAL_SHARED_LIBRARIES:= libcutils libutils
LOCAL_PRELINK_MODULE  := false

LOCAL_MODULE	:= dc
LOCAL_DISABLE_FORMAT_STRING_CHECKS=true
LOCAL_ASFLAGS := -fPIC -fvisibility=hidden
LOCAL_LDLIBS	:= -llog -lGLESv2 -lEGL -lz 
#-Wl,-Map,./res/raw/syms.mp3
LOCAL_ARM_MODE	:= arm

ifeq ($(TARGET_ARCH),mips)
  LOCAL_LDFLAGS += -Wl,--gc-sections
else
  LOCAL_LDFLAGS += -Wl,--gc-sections,--icf=safe
  LOCAL_LDLIBS +=  -Wl,--no-warn-shared-textrel
endif



#
# android has poor support for hardfp calling.
# r9b+ is required, and it only works for internal calls
# the opengl drivers would really benefit from this, but they are still using softfp
# the header files tell gcc to automatically use aapcs for calling system/etc
# so there is no real perfomance difference
#
# The way this is implemented is a huge hack on the android/linux side
# (but then again, which part of android isn't a huge hack?)

#ifneq ($(filter %armeabi-v7a,$(TARGET_ARCH_ABI)),)
#LOCAL_CFLAGS += -mhard-float -D_NDK_MATH_NO_SOFTFP=1 -DARM_HARDFP
#LOCAL_LDLIBS += -lm_hard
#ifeq (,$(filter -fuse-ld=mcld,$(APP_LDFLAGS) $(LOCAL_LDFLAGS)))
#LOCAL_LDFLAGS += -Wl,--no-warn-mismatch
#endif
#endif

include $(BUILD_SHARED_LIBRARY)