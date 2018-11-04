# A cmake file (currently only working on Linux).
# Currently not doing library detection because it's a pain.

cmake_minimum_required (VERSION 2.6)
project(reicast)

enable_language(C)
enable_language(CXX)
enable_language(ASM)

set(base ../..)
function(add_directory dir)
  file(GLOB _f ${base}/${dir}/*.h  ${base}/${dir}/*.c  ${base}/${dir}/*.cpp  ${base}/${dir}/*.hpp  ${base}/${dir}/*.S)
  set(source ${source} ${_f} PARENT_SCOPE)
endfunction()

# Options
option(USE_SDL "Use SDL" OFF)
option(USE_OSS "Use OSS" ON)
option(USE_ALSA "Use ALSA" ON)
option(USE_LIBAO "Use LibAO" OFF)
option(USE_GLES "Use GL ES" OFF)
option(USE_PULSEAUDIO "Use PulseAudio" OFF)
option(USE_WEBUI "Use WebUI" ON)
option(USE_REND "Use some rendering" ON)
option(USE_EVDEV "Use EVDEV" ON)
option(USE_JOYSTICK "Use Joystick" ON)

# Flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fpermissive -fno-rtti -fno-operator-names")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -frename-registers -fno-strict-aliasing -fsingle-precision-constant")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ffast-math -ftree-vectorize")
if("${CMAKE_BUILD_TYPE}" STREQUAL Release OR "${CMAKE_BUILD_TYPE}" STREQUAL RelWithDebInfo)
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--gc-sections -Wl,-O3 -Wl,--sort-common")
  # TODO, -Map,$(notdir $@).map
endif()

if("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "AMD64")
  set(arch "x86_64")
elseif("${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "i686")
  set(arch "x86")
else()
  set(arch "${CMAKE_SYSTEM_PROCESSOR}")
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL Release)
  add_definitions(-DRELEASE)
endif()

add_definitions(-DUSES_HOMEDIR)
add_definitions(-DTARGET_NO_AREC)

if(WINDOWS)
  add_definitions(-DTARGET_WIN86)
elseif("${CMAKE_SYSTEM_NAME}" STREQUAL Linux)
  if("${arch}" STREQUAL x86)
    add_definitions(-DTARGET_LINUX_x86)
  elseif("${arch}" STREQUAL x86_64)
    add_definitions(-DTARGET_LINUX_x64)
  elseif("${arch}" STREQUAL arm)
    add_definitions(-DTARGET_LINUX_ARMELv7)
  elseif("${arch}" STREQUAL mips)
    add_definitions(-DTARGET_LINUX_MIPS)
  else()
    message(FATAL_ERROR "Unknown processor")
  endif()
else()
  message(FATAL_ERROR "Unknown target")
  # TODO, TARGET_GCW0
  # TODO, TARGET_NACL32
  # TODO, TARGET_IPHONE
  # TODO, TARGET_PANDORA
endif()

# TODO, Android
# TODO, Pandora

# Temp stuff:
# TODO: -frename-registers -fno-strict-aliasing -fsingle-precision-constant -ffast-math -ftree-vectorize
# TODO: -fno-exceptions -fno-rtti
# TODO: -fno-exceptions -fno-rtti -std=gnu++11

include_directories(${base}/deps)
include_directories(${base}/core)
include_directories(${base}/core/khronos/)
include_directories(${base}/core/deps/libpng)

add_directory(core/cfg/)
add_directory(core/hw/aica)
add_directory(core/hw/arm7)
add_directory(core/hw/flashrom)
add_directory(core/hw/gdrom)
add_directory(core/hw/holly)
add_directory(core/hw/maple)
add_directory(core/hw/mem)
add_directory(core/hw/pvr)
add_directory(core/hw/sh4)
add_directory(core/hw/sh4/dyna)
add_directory(core/hw/sh4/modules)
add_directory(core/hw/sh4/interpr/)
add_directory(core/profiler)
add_directory(core/oslib)
add_directory(core/arm_emitter)
add_directory(core/rend)
add_directory(core/reios)
add_directory(core/imgread)
add_directory(core/deps/libelf)
add_directory(core)
add_directory(core/deps/chdr)
add_directory(core/deps/coreio)
add_directory(core/deps/crypto)
add_directory(core/deps/chdpsr)
add_directory(core/deps/libpng)
# add_directory(core/khronos/GL3)

# Core stuff:

list(APPEND libs GL z)

if(NOT WINDOWS AND NOT APPLE)
  add_definitions(-DSUPPORT_X11)
endif()

if("${CMAKE_SYSTEM_NAME}" STREQUAL Linux)
  # TODO, do some proper detection for this
  list(APPEND libs m rt dl pthread X11)
  if(USE_ALSA)
    add_definitions(-DUSE_ALSA)
    list(APPEND libs asound)
  endif()
endif()

# Processor-specific recompiler:

if("${arch}" STREQUAL x86)
  add_directory(core/rec-x86)
  add_directory(core/emitter)
elseif("${arch}" STREQUAL x86_64)
  add_directory(core/rec-x64)
elseif("${ARCH}" STREQUAL arm)
  add_directory(core/rec-ARM)
endif()

# Audio backends:

if(UNIX AND USE_OSS)
  add_definitions(-DUSE_OSS)
endif()

if(USE_PULSEAUDIO)
  add_definitions(-DUSE_PULSEAUDIO)
  list(APPEND libs pulse-simple)
endif()

if(USE_LIBAO)
  add_definitions(-DUSE_LIBAO)
  list(APPEND libs ao)
endif()

# Graphic stuffs:

if(USE_REND)
  add_directory(core/rend/gles)
else()
  add_directory(core/rend/norend)
endif()

if(USE_GLES)
  add_definitions(-DGLES)
  list(APPEND libs EGL GLESv2)
else()
  list(APPEND libs dl GL)
endif()

if(USE_SDL)
  list(APPEND source core/sdl/main.cpp)
elseif("${CMAKE_SYSTEM_NAME}" STREQUAL Linux)
  add_directory(core/linux-dist)
endif()

if(WINDOWS)
  add_directory(core/rend/d3d11)
  add_directory(core/rend/norend)
elseif("${CMAKE_SYSTEM_NAME}" STREQUAL Linux)
  add_directory(core/linux)
  add_directory(core/linux/nixprof)
else()
  message(FATAL_ERROR "Which OS?")
endif()

# Optional features

if(USE_WEBUI)
  add_definitions(-DWEBUI)
  add_directory(core/webui)
  add_directory(core/deps/libwebsocket)
  # TODO, deps/ifaddrs/ for Android
endif()

if(USE_EVDEV)
  add_definitions(-DUSE_EVDEV)
endif()

if(USE_JOYSTICK)
  add_definitions(-DUSE_JOYSTICK)
endif()

# Executable

add_executable(reicast ${source})
target_link_libraries(reicast ${libs})
