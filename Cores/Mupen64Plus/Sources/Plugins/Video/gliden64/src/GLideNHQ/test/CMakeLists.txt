cmake_minimum_required(VERSION 2.6)

project( test_hq )

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

add_definitions(
  -DGHQCHK=1
  -DTXFILTER_DLL=1
)

if(WIN32)
  add_definitions(
	-DWIN32
	-DOS_WINDOWS
  )
endif(WIN32)

#SET( CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} ${GCC_CPP11_COMPILE_FLAGS}" )

add_executable( test_hq test.cpp ../Ext_TxFilter.cpp )
