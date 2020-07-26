project( cdtest )

# C sources
set( cdtest_SOURCES
        cdtest.c )

add_executable( cdtest
	${cdtest_SOURCES} )

target_link_libraries( cdtest yabause )
target_link_libraries( cdtest ${YABAUSE_LIBRARIES} )

project( pertest )

# C sources
set( pertest_SOURCES
        pertest.c )

add_executable( pertest
	${pertest_SOURCES} )

target_link_libraries( pertest yabause )
target_link_libraries( pertest ${YABAUSE_LIBRARIES} )
