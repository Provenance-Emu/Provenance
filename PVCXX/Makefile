# Copyright 2020-2021 Apple Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

APP_00WINDOW_OBJECTS=learn-metal/00-window/00-window.o
APP_01PRIMITIVE_OBJECTS=learn-metal/01-primitive/01-primitive.o
APP_02ARGBUFFERS_OBJECTS=learn-metal/02-argbuffers/02-argbuffers.o
APP_03ANIMATION_OBJECTS=learn-metal/03-animation/03-animation.o
APP_04INSTANCING_OBJECTS=learn-metal/04-instancing/04-instancing.o
APP_05PERSPECTIVE_OBJECTS=learn-metal/05-perspective/05-perspective.o
APP_06LIGHTING_OBJECTS=learn-metal/06-lighting/06-lighting.o
APP_07TEXTURING_OBJECTS=learn-metal/07-texturing/07-texturing.o
APP_08COMPUTE_OBJECTS=learn-metal/08-compute/08-compute.o
APP_09COMPUTETORENDER_OBJECTS=learn-metal/09-compute-to-render/09-compute-to-render.o
APP_10FRAMEDEBUGGING_OBJECTS=learn-metal/10-frame-debugging/10-frame-debugging.o

ifdef DEBUG
DBG_OPT_FLAGS=-g
else
DBG_OPT_FLAGS=-O2
endif

ifdef ASAN
ASAN_FLAGS=-fsanitize=address
else
ASAN_FLAGS=
endif

CC=clang++
CFLAGS=-Wall -std=c++17 -I./metal-cpp -I./metal-cpp-extensions -fno-objc-arc $(DBG_OPT_FLAGS) $(ASAN_FLAGS)
LDFLAGS=-framework Metal -framework Foundation -framework Cocoa -framework CoreGraphics -framework MetalKit 

VPATH=./metal-cpp

%.o: %.cpp
	$(CC) -c $(CFLAGS) $< -o $@


all: build/00-window build/01-primitive build/02-argbuffers build/03-animation build/04-instancing build/05-perspective build/06-lighting build/07-texturing build/08-compute build/09-compute-to-render build/10-frame-debugging

.PHONY: all

build/00-window: $(APP_00WINDOW_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_00WINDOW_OBJECTS) -o $@

build/01-primitive: $(APP_01PRIMITIVE_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_01PRIMITIVE_OBJECTS) -o $@

build/02-argbuffers: $(APP_02ARGBUFFERS_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_02ARGBUFFERS_OBJECTS) -o $@

build/03-animation: $(APP_03ANIMATION_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_03ANIMATION_OBJECTS) -o $@

build/04-instancing: $(APP_04INSTANCING_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_04INSTANCING_OBJECTS) -o $@

build/05-perspective: $(APP_05PERSPECTIVE_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_05PERSPECTIVE_OBJECTS) -o $@

build/06-lighting: $(APP_06LIGHTING_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_06LIGHTING_OBJECTS) -o $@

build/07-texturing: $(APP_07TEXTURING_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_07TEXTURING_OBJECTS) -o $@

build/08-compute: $(APP_08COMPUTE_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_08COMPUTE_OBJECTS) -o $@

build/09-compute-to-render: $(APP_09COMPUTETORENDER_OBJECTS) Makefile
	$(CC) $(CFLAGS) $(LDFLAGS) $(APP_09COMPUTETORENDER_OBJECTS) -o $@

build/10-frame-debugging: $(APP_10FRAMEDEBUGGING_OBJECTS) Makefile
# project-less capture requires an Info.plist. Here it is embedded directly into the binary
	$(CC) $(CFLAGS) $(LDFLAGS) -sectcreate __TEXT __info_plist ./learn-metal/10-frame-debugging/Info.plist $(APP_10FRAMEDEBUGGING_OBJECTS) -o $@

clean:
	rm -f $(APP_00WINDOW_OBJECTS) \
		$(APP_01PRIMITIVE_OBJECTS) \
		$(APP_02ARGBUFFERS_OBJECTS) \
		$(APP_03ANIMATION_OBJECTS) \
		$(APP_04INSTANCING_OBJECTS) \
		$(APP_05PERSPECTIVE_OBJECTS) \
		$(APP_06LIGHTING_OBJECTS) \
		$(APP_07TEXTURING_OBJECTS) \
		$(APP_08COMPUTE_OBJECTS) \
		$(APP_09COMPUTETORENDER_OBJECTS) \
		$(APP_10FRAMEDEBUGGING_OBJECTS) \
		build/00-window \
		build/01-primitive \
		build/02-argbuffers \
		build/03-animation \
		build/04-instancing \
		build/05-perspective \
		build/06-lighting \
		build/07-texturing \
		build/08-compute \
		build/09-compute-to-render \
		build/10-frame-debugging
