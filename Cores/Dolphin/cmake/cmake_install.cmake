# Install script for directory: /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios

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
  set(CMAKE_CROSSCOMPILING "TRUE")
endif()

# Set default install directory permissions.
if(NOT DEFINED CMAKE_OBJDUMP)
  set(CMAKE_OBJDUMP "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/objdump")
endif()

set(CMAKE_BINARY_DIR "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake")

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
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/share/dolphin-emu/sys/")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/share/dolphin-emu/sys" TYPE DIRECTORY FILES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Data/Sys/")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "Unspecified" OR NOT CMAKE_INSTALL_COMPONENT)
  list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
   "/usr/local/share/dolphin-emu/license.txt")
  if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
    message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
  endif()
  file(INSTALL DESTINATION "/usr/local/share/dolphin-emu" TYPE FILE FILES "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/dolphin-ios/Data/license.txt")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for each subdirectory.
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/cpp-optparse/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/imgui/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/glslang/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/pugixml/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/enet/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/xxhash/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/liblzma/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/zstd/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/minizip/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/LZO/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/libpng/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/FreeSurround/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/ed25519/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/soundtouch/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/SFML/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/curl/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/libiconv-1.14/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Externals/rangeset/cmake_install.cmake")
  include("/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/Source/cmake_install.cmake")

endif()

if(CMAKE_INSTALL_COMPONENT)
  set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
file(WRITE "/Users/jmattiello/Workspace/Provenance/Provenance/Cores/Dolphin/cmake/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
