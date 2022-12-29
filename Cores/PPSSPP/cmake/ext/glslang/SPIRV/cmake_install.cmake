# Install script for directory: ../ppsspp/ext/glslang/SPIRV

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "ON")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/objdump")
endif()

set(CMAKE_BINARY_DIR "../cmake")

if(NOT PLATFORM_NAME)
  if(NOT "$ENV{PLATFORM_NAME}" STREQUAL "")
    set(PLATFORM_NAME "$ENV{PLATFORM_NAME}")
  endif()
  if(NOT PLATFORM_NAME)
    set(PLATFORM_NAME iphoneos)
  endif()
endif()

if(NOT EFFECTIVE_PLATFORM_NAME)
  if(NOT "$ENV{EFFECTIVE_PLATFORM_NAME}" STREQUAL "")
    set(EFFECTIVE_PLATFORM_NAME "$ENV{EFFECTIVE_PLATFORM_NAME}")
  endif()
  if(NOT EFFECTIVE_PLATFORM_NAME)
    set(EFFECTIVE_PLATFORM_NAME -iphoneos)
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "../cmake/lib/Debug/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "../cmake/lib/Release/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "../cmake/lib/MinSizeRel/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  elseif(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "../cmake/lib/RelWithDebInfo/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SPIRVTargets.cmake")
    file(DIFFERENT _cmake_export_file_changed FILES
         "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SPIRVTargets.cmake"
         "../cmake/ext/glslang/SPIRV/CMakeFiles/Export/c220ae0af1591e9e9e916bba91f25986/SPIRVTargets.cmake")
    if(_cmake_export_file_changed)
      file(GLOB _cmake_old_config_files "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SPIRVTargets-*.cmake")
      if(_cmake_old_config_files)
        string(REPLACE ";" ", " _cmake_old_config_files_text "${_cmake_old_config_files}")
        message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/SPIRVTargets.cmake\" will be replaced.  Removing files [${_cmake_old_config_files_text}].")
        unset(_cmake_old_config_files_text)
        file(REMOVE ${_cmake_old_config_files})
      endif()
      unset(_cmake_old_config_files)
    endif()
    unset(_cmake_export_file_changed)
  endif()
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake" TYPE FILE FILES "../cmake/ext/glslang/SPIRV/CMakeFiles/Export/c220ae0af1591e9e9e916bba91f25986/SPIRVTargets.cmake")
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake" TYPE FILE FILES "../cmake/ext/glslang/SPIRV/CMakeFiles/Export/c220ae0af1591e9e9e916bba91f25986/SPIRVTargets-debug.cmake")
  endif()
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake" TYPE FILE FILES "../cmake/ext/glslang/SPIRV/CMakeFiles/Export/c220ae0af1591e9e9e916bba91f25986/SPIRVTargets-minsizerel.cmake")
  endif()
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake" TYPE FILE FILES "../cmake/ext/glslang/SPIRV/CMakeFiles/Export/c220ae0af1591e9e9e916bba91f25986/SPIRVTargets-relwithdebinfo.cmake")
  endif()
  if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake" TYPE FILE FILES "../cmake/ext/glslang/SPIRV/CMakeFiles/Export/c220ae0af1591e9e9e916bba91f25986/SPIRVTargets-release.cmake")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/glslang/SPIRV" TYPE FILE FILES
    "../ppsspp/ext/glslang/SPIRV/bitutils.h"
    "../ppsspp/ext/glslang/SPIRV/spirv.hpp"
    "../ppsspp/ext/glslang/SPIRV/GLSL.std.450.h"
    "../ppsspp/ext/glslang/SPIRV/GLSL.ext.EXT.h"
    "../ppsspp/ext/glslang/SPIRV/GLSL.ext.KHR.h"
    "../ppsspp/ext/glslang/SPIRV/GlslangToSpv.h"
    "../ppsspp/ext/glslang/SPIRV/hex_float.h"
    "../ppsspp/ext/glslang/SPIRV/Logger.h"
    "../ppsspp/ext/glslang/SPIRV/SpvBuilder.h"
    "../ppsspp/ext/glslang/SPIRV/spvIR.h"
    "../ppsspp/ext/glslang/SPIRV/doc.h"
    "../ppsspp/ext/glslang/SPIRV/SpvTools.h"
    "../ppsspp/ext/glslang/SPIRV/disassemble.h"
    "../ppsspp/ext/glslang/SPIRV/GLSL.ext.AMD.h"
    "../ppsspp/ext/glslang/SPIRV/GLSL.ext.NV.h"
    "../ppsspp/ext/glslang/SPIRV/NonSemanticDebugPrintf.h"
    "../ppsspp/ext/glslang/SPIRV/SPVRemapper.h"
    "../ppsspp/ext/glslang/SPIRV/doc.h"
    )
endif()

