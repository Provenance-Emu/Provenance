
LOCAL_PATH := $(call my-dir)
FOR_LINUX :=1
NOT_ARM := 1
#NO_REC := 1
#NO_REND := 1
CPP_REC := 1
NO_NIXPROF := 1
RZDCY_SRC_DIR = ../../core

include $(RZDCY_SRC_DIR)/core.mk

CC_PREFIX ?= 

CXX=${CC_PREFIX}em++
CC=${CC_PREFIX}emcc
#AS=${CC_PREFIX}as
STRIP=${CC_PREFIX}emstrip

LD=${CC}

MFLAGS := 
ASFLAGS := 

LDFLAGS	:= -Wl,-Map,$(notdir $@).map,--gc-sections -Wl,-O3 -Wl,--sort-common 


CXXONLYFLAGS := -std=c++11
CXXFLAGS := -O3  -D GLES -D RELEASE -c -D TARGET_EMSCRIPTEN -D TARGET_NO_REC -D TARGET_NO_NVMEM -D TARGET_NO_WEBUI -D TARGET_NO_THREADS -D TARGET_BOUNDED_EXECUTION -D TARGET_NO_EXCEPTIONS -D TARGET_NO_COREIO_HTTP
CXXFLAGS += -fno-strict-aliasing
CXXFLAGS += -ffast-math

CXXFLAGS += $(CFLAGS) $(MFLAGS) -fno-exceptions -fno-rtti


INCS	:= -I$(RZDCY_SRC_DIR) -I$(RZDCY_SRC_DIR)/deps -I$(RZDCY_SRC_DIR)/khronos -I../linux-deps/include

LIBS	:= #emscripten has all the basic libs, and egl, and sdl, built in

OBJECTS=$(RZDCY_FILES:.cpp=.build.obj)
OBJECTS:=$(OBJECTS:.c=.build.obj)
OBJECTS:=$(OBJECTS:.S=.build.obj)
OBJECTS:=$(patsubst $(RZDCY_SRC_DIR)/%,obj/%,$(OBJECTS))


EXECUTABLE=reicast.html

all: $(CPPFILES) $(EXECUTABLE)
	
$(EXECUTABLE): $(OBJECTS)
	echo $(RZDCY_FILES)
	$(CXX) $(MFLAGS) $(EXTRAFLAGS) $(LDFLAGS)  $(OBJECTS) $(LIBS) -o $@ --preload-file data/dc_boot.bin --preload-file data/dc_flash.bin -s TOTAL_MEMORY=96000000 -s NO_EXIT_RUNTIME=1 -O3 

obj/%.build.obj : $(RZDCY_SRC_DIR)/%.cpp
	mkdir -p $(dir $@)
	$(CXX) $(EXTRAFLAGS) $(INCS) $(CXXFLAGS) $(CXXONLYFLAGS) $< -o $@
	
obj/%.build.obj : $(RZDCY_SRC_DIR)/%.c
	mkdir -p $(dir $@)
	$(CC) $(EXTRAFLAGS) $(INCS) $(CXXFLAGS) $< -o $@

obj/%.build.obj : $(RZDCY_SRC_DIR)/%.S
	mkdir -p $(dir $@)	
	$(AS) $(ASFLAGS) $(INCS) $< -o $@


clean:
	rm $(OBJECTS) $(EXECUTABLE) -f
