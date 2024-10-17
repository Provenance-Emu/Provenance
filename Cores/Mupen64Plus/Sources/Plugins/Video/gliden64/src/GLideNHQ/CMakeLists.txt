cmake_minimum_required(VERSION 2.6)

project( GLideNHQ )

set(GLideNHQ_SOURCES
  TextureFilters.cpp
  TextureFilters_2xsai.cpp
  TextureFilters_hq2x.cpp
  TextureFilters_hq4x.cpp
  TextureFilters_xbrz.cpp
  TxCache.cpp
  TxDbg.cpp
  TxFilter.cpp
  TxFilterExport.cpp
  TxHiResCache.cpp
  TxImage.cpp
  TxQuantize.cpp
  TxReSample.cpp
  TxTexCache.cpp
  TxUtil.cpp
)

if(MINGW OR PANDORA OR BCMHOST)
  include_directories( ${CMAKE_CURRENT_SOURCE_DIR}/../osal )
else(MINGW OR PANDORA OR BCMHOST)
  include_directories( inc ${CMAKE_CURRENT_SOURCE_DIR}/../osal )
endif(MINGW OR PANDORA OR BCMHOST)
LINK_DIRECTORIES( ${CMAKE_CURRENT_SOURCE_DIR}/lib )

if(UNIX)
  if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    add_definitions(
      -DOS_MAC_OS_X
    )
    set(APPLE ON)
  elseif(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    add_definitions(
      -DNDEBUG
      -DOS_LINUX
    )
  endif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
endif(UNIX)

if(WIN32)
  LINK_DIRECTORIES( ${CMAKE_CURRENT_SOURCE_DIR}/lib )
  add_definitions(
	-DWIN32
	-DOS_WINDOWS
	-D_CRT_SECURE_NO_WARNINGS
  )
endif(WIN32)

# Build type

if( NOT CMAKE_BUILD_TYPE)
	set( CMAKE_BUILD_TYPE Release)
endif( NOT CMAKE_BUILD_TYPE)

if( CMAKE_BUILD_TYPE STREQUAL "Debug")
	set( CMAKE_BUILD_TYPE Debug)
	set( DEBUG_BUILD TRUE)
	add_definitions(
		-DDEBUG
	)
endif( CMAKE_BUILD_TYPE STREQUAL "Debug")

if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
	add_definitions( -D__MSC__)
endif()

if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    SET(GCC_CPP11_COMPILE_FLAGS "-std=c++0x -Wno-unused-result")
    if( NOT GHQCHK )
      if ( NOT MINGW )
          SET ( PIC_FLAGS "-fPIC" )
      endif ( NOT MINGW)
      SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} ${GCC_CPP11_COMPILE_FLAGS} -static ${PIC_FLAGS} " )
      SET( CMAKE_C_FLAGS  "${CMAKE_C_FLAGS} -static ${PIC_FLAGS} " )
    else( NOT GHQCHK )
      SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} ${GCC_CPP11_COMPILE_FLAGS}" )
    endif( NOT GHQCHK )
#SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} ${GCC_CPP11_COMPILE_FLAGS} " )
endif()

if( NOT GHQCHK )

    add_definitions( -DTXFILTER_LIB)

    if( CMAKE_BUILD_TYPE STREQUAL "Debug")
      add_library( GLideNHQd STATIC ${GLideNHQ_SOURCES})

      set_target_properties(GLideNHQd PROPERTIES LINK_SEARCH_START_STATIC 1)
      set_target_properties(GLideNHQd PROPERTIES LINK_SEARCH_END_STATIC 1)

      if(MINGW OR BCMHOST OR APPLE OR USE_SYSTEM_LIBS)
        FIND_PACKAGE( ZLIB REQUIRED )
        FIND_PACKAGE( PNG REQUIRED )
        target_link_libraries(GLideNHQd
          ${PNG_LIBRARIES}
          ${ZLIB_LIBRARIES}
          osald
        )
      else(MINGW OR BCMHOST OR APPLE OR USE_SYSTEM_LIBS)
        target_link_libraries(GLideNHQd PRIVATE
          ${CMAKE_CURRENT_SOURCE_DIR}/lib/libpng.a
          ${CMAKE_CURRENT_SOURCE_DIR}/lib/libz.a
          dl
          osald
        )
      endif(MINGW OR BCMHOST OR APPLE OR USE_SYSTEM_LIBS)
    endif( CMAKE_BUILD_TYPE STREQUAL "Debug")

    if( CMAKE_BUILD_TYPE STREQUAL "Release")
      add_library( GLideNHQ STATIC ${GLideNHQ_SOURCES})

#      set_target_properties(GLideNHQ PROPERTIES LINK_SEARCH_START_STATIC 1)
#      set_target_properties(GLideNHQ PROPERTIES LINK_SEARCH_END_STATIC 1)
#      set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
#      find_library(PNGLIB libpng.a)

      if(PANDORA)
        target_link_libraries(GLideNHQ PRIVATE
          /mnt/utmp/codeblocks/usr/lib/libpng.a
          /mnt/utmp/codeblocks/usr/lib/libz.a
          osal
        )
      elseif(BCMHOST OR MINGW OR APPLE OR USE_SYSTEM_LIBS)
        FIND_PACKAGE( ZLIB REQUIRED )
        FIND_PACKAGE( PNG REQUIRED )
        target_link_libraries(GLideNHQ
          ${PNG_LIBRARIES}
          ${ZLIB_LIBRARIES}
          osal
        )
      else(PANDORA)
        target_link_libraries(GLideNHQ PRIVATE
          ${CMAKE_CURRENT_SOURCE_DIR}/lib/libpng.a
          ${CMAKE_CURRENT_SOURCE_DIR}/lib/libz.a
          dl
          osal
        )
      endif(PANDORA)
    endif( CMAKE_BUILD_TYPE STREQUAL "Release")
else( NOT GHQCHK )
    add_definitions(-DGHQCHK)

    add_library( ghqchk SHARED ${GLideNHQ_SOURCES})

    SET_TARGET_PROPERTIES(
      ghqchk
      PROPERTIES
      LINKER_LANGUAGE CXX # Or else we get an error message, because cmake can't figure out from the ".o"-suffix that it is a C-linker we need.
      PREFIX ""
      LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/plugin
      )

    if( CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_link_libraries(ghqchk png z )
    endif( CMAKE_BUILD_TYPE STREQUAL "Debug")

    if( CMAKE_BUILD_TYPE STREQUAL "Release")
    target_link_libraries(ghqchk png z )
    endif( CMAKE_BUILD_TYPE STREQUAL "Release")
endif( NOT GHQCHK )

