CMAKE_MINIMUM_REQUIRED(VERSION 2.8)

include(CMakeForceCompiler)
include(ExternalProject)

SET(CMAKE_SYSTEM_NAME SegaSaturn)

set(WANT_AUTOMATED_TESTING OFF CACHE BOOL "Build a version for automated testing")

if(WANT_AUTOMATED_TESTING)
  add_definitions(-DBUILD_AUTOMATED_TESTING)
endif()

find_path(IAPETUS_INCLUDE_DIR 
          NAMES iapetus.h
          PATHS ${IAPETUS_ROOT_PATH}/include
                $ENV{ProgramFiles}/iapetus/include )

if (IAPETUS_INCLUDE_DIR STREQUAL "IAPETUS_INCLUDE_DIR-NOTFOUND")
   ExternalProject_Add(iapetus
      GIT_REPOSITORY "https://github.com/cyberwarriorx/iapetus.git"
      LOG_DOWNLOAD 1
      LOG_CONFIGURE 1
      LOG_BUILD 1
      INSTALL_COMMAND "" 
   )

   ExternalProject_Get_Property(iapetus source_dir)
   set(IAPETUS_INCLUDE_DIR ${source_dir}/src)
endif(IAPETUS_INCLUDE_DIR STREQUAL "IAPETUS_INCLUDE_DIR-NOTFOUND")

PROJECT(YabauseUT C)

include_directories(${IAPETUS_INCLUDE_DIR})

#CONFIGURE_FILE(config.h.cmake config.h)

set(YABAUSEUT_VERSION_MAJOR 0)
set(YABAUSEUT_VERSION_MINOR 1)
set(YABAUSEUT_VERSION_PATCH 0)
set(YABAUSEUT_VERSION "${YABAUSEUT_VERSION_MAJOR}.${YABAUSEUT_VERSION_MINOR}.${YABAUSEUT_VERSION_PATCH}")

set(CPACK_SOURCE_GENERATOR TGZ)
set(CPACK_PACKAGE_VERSION_MAJOR ${YABAUSEUT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${YABAUSEUT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${YABAUSEUT_VERSION_PATCH})
set(CPACK_PACKAGE_VENDOR "Yabause team")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/COPYING")
set(CPACK_SOURCE_PACKAGE_FILE_NAME "YABAUSEUT-${YABAUSEUT_VERSION}")
include(CPack)

set(CMAKE_CONFIGURATION_TYPES Release)

find_library(IAPETUS_LIB
             NAMES iapetus
             PATHS ${IAPETUS_ROOT_PATH}/lib
                   $ENV{ProgramFiles}/iapetus/lib)

if (IAPETUS_LIB STREQUAL "IAPETUS_LIB-NOTFOUND")
   ExternalProject_Get_Property(iapetus binary_dir)
   #add_dependencies(${PROJECT_NAME} iapetus)
   set(IAPETUS_LIB "${binary_dir}/src/${CMAKE_FIND_LIBRARY_PREFIXES}iapetus.a")
endif(IAPETUS_LIB STREQUAL "IAPETUS_LIB-NOTFOUND")

set(YabauseUT_LIBRARIES ${IAPETUS_LIB})

add_subdirectory(src)

add_dependencies(${PROJECT_NAME} ${IAPETUS_LIB})


