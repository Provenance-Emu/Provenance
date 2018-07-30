cmake_minimum_required(VERSION 3.2.0)

if(REALM_PLATFORM STREQUAL "Android")
    # This must be before project()
    set(CMAKE_TOOLCHAIN_FILE "${CMAKE_CURRENT_SOURCE_DIR}/CMake/android.toolchain.cmake")
    set(ANDROID_ABI "x86" CACHE STRING "")
    set(ANDROID_NATIVE_API_LEVEL "android-16" CACHE STRING "")
endif()

set(CMAKE_BUILD_TYPE Debug CACHE STRING "")
project(realm-object-store)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/CMake")

include(CodeCoverage)
include(CompilerFlags)
include(Sanitizers)

# Sync is disabled unless -DREALM_ENABLE_SYNC=1 is specified when invoking CMake.
# FIXME: Flip the default once we can build against prebuilt sync binaries.
set(REALM_ENABLE_SYNC OFF CACHE BOOL "")

if(REALM_SYNC_PREFIX AND NOT REALM_CORE_PREFIX)
    message(FATAL_ERROR "REALM_CORE_PREFIX must be set when specifying REALM_SYNC_PREFIX.")
endif()
if(REALM_SYNC_PREFIX AND NOT REALM_ENABLE_SYNC)
    message(FATAL_ERROR "REALM_ENABLE_SYNC must be set when specifying REALM_SYNC_PREFIX.")
endif()
if(REALM_CORE_PREFIX AND REALM_ENABLE_SYNC AND NOT REALM_SYNC_PREFIX)
    message(FATAL_ERROR "REALM_SYNC_PREFIX must be set when specifying REALM_CORE_PREFIX when REALM_ENABLE_SYNC is set.")
endif()

include(RealmCore)
use_realm_core("${REALM_ENABLE_SYNC}" "${REALM_CORE_PREFIX}" "${REALM_SYNC_PREFIX}")

if(REALM_ENABLE_SYNC)
  add_definitions(-DREALM_ENABLE_SYNC)
endif()

set(PEGTL_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/external/pegtl)

add_subdirectory(src)
add_subdirectory(tests)
