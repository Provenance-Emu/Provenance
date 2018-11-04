# nacl-simulating linux build
# for debugging

LOCAL_PATH := $(call my-dir)
FOR_LINUX :=1
#NOT_ARM := 1
#X64_REC := 1
CPP_REC :=1
#NO_REC := 1
NO_REND := 1
WEBUI :=1 
USE_ALSA := 1
USE_OSS := 1
#USE_PULSEAUDIO := 1

RZDCY_SRC_DIR = ../../core

include $(RZDCY_SRC_DIR)/core.mk

RZDCY_FILES += $(RZDCY_SRC_DIR)/nacl/nacl_lin.cpp

CXX=${CC_PREFIX}g++
CC=${CC_PREFIX}gcc
AS=${CC_PREFIX}as
STRIP=${CC_PREFIX}strip

LD=${CC}

MFLAGS := #-m32
#-marm -march=armv7-a -mtune=cortex-a9 -mfpu=neon -mfloat-abi=softfp -funroll-loops
ASFLAGS := 
#-march=armv7-a -mfpu=neon -mfloat-abi=softfp

LDFLAGS	:= 	-g -Wl,-Map,$(notdir $@).map,--gc-sections -Wl,-O3 -Wl,--sort-common 

CFLAGS :=  -g -O3  -D RELEASE -c -D TARGET_LINUX_x64 -D TARGET_NACL32 -D USES_HOMEDIR -D TARGET_NO_JIT -D NO_REND -std=c++11
CFLAGS += -frename-registers -fno-strict-aliasing #-fsingle-precision-constant 
CFLAGS += -ffast-math -ftree-vectorize 


#-fprefetch-loop-arrays 
#-std=c++0x
CXXFLAGS += $(CFLAGS) $(MFLAGS) -fexceptions -fno-rtti -fpermissive
CXXFLAGS += -fno-operator-names

ifdef PGO_MAKE
	CFLAGS += -fprofile-generate -pg
	LDFLAGS	+= -fprofile-generate
else
	CFLAGS += -fomit-frame-pointer
endif

ifdef PGO_USE
	CFLAGS += -fprofile-use
endif


ifdef LTO_TEST
	CFLAGS += -flto -fwhole-program 
	LDFLAGS +=-flto -fwhole-program 
endif

INCS	:= -I$(RZDCY_SRC_DIR) -I$(RZDCY_SRC_DIR)/deps -I$(RZDCY_SRC_DIR)/khronos

LIBS    := # use system libs
LIBS    += -lm -lrt -ldl
LIBS    += -lpthread #-lX11

ifdef USE_ALSA
	CXXFLAGS += -D USE_ALSA
	LIBS += -lasound
endif

ifdef USE_OSS
	CXXFLAGS += -D USE_OSS
endif

ifdef USE_PULSEAUDIO
	CXXFLAGS += -D USE_PULSEAUDIO
	LIBS += -lpulse-simple
endif

ifdef USE_GLES
	CXXFLAGS += -DGLES
	LIBS	+= -lEGL -lGLESv2
else
	LIBS	+= -ldl -lGL #for desktop gl
endif


OBJECTS=$(RZDCY_FILES:.cpp=.build_obj)
OBJECTS:=$(OBJECTS:.c=.build_obj)
OBJECTS:=$(OBJECTS:.S=.build_obj)
OBJECTS:=$(patsubst $(RZDCY_SRC_DIR)/%,obj/%,$(OBJECTS))


EXECUTABLE_STRIPPED=nosym-reicast.elf
EXECUTABLE=reicast.elf

PACKAGE_FILES=$(EXECUTABLE_STRIPPED) default.gcw0.desktop icon-32.png

all: $(CPPFILES) $(EXECUTABLE) $(EXECUTABLE_STRIPPED)
	
$(EXECUTABLE): $(OBJECTS)
	$(CXX) $(MFLAGS) $(EXTRAFLAGS) $(LDFLAGS)  $(OBJECTS) $(LIBS) -o $@

$(EXECUTABLE_STRIPPED): $(EXECUTABLE)
	cp $< $@ && $(STRIP) $@

obj/%.build_obj : $(RZDCY_SRC_DIR)/%.cpp
	mkdir -p $(dir $@)
	$(CXX) $(EXTRAFLAGS) $(INCS) $(CFLAGS) $(CXXFLAGS) $< -o $@
	
obj/%.build_obj : $(RZDCY_SRC_DIR)/%.c
	mkdir -p $(dir $@)
	$(CC) $(EXTRAFLAGS) $(INCS) $(CFLAGS) $< -o $@

obj/%.build_obj : $(RZDCY_SRC_DIR)/%.S
	mkdir -p $(dir $@)	
	$(AS) $(ASFLAGS) $(INCS) $< -o $@


clean:
	rm $(OBJECTS) $(EXECUTABLE) -f
