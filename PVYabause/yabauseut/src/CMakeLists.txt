project(YabauseUT)

enable_language(ASM)
set(YabauseUT_SOURCES
	shared/crt0.s
	cart.c
	cdb.c
	dsp.c
	m68k.c
	main.c
	scsp.c
	scu.c
	sh2.c
	smpc.c
	tests.c
	vdp1.c
	vdp2.c)

set(CMAKE_C_FLAGS "-O2 -Wall -m2")
set(CMAKE_EXE_LINKER_FLAGS "-nostartfiles -Wl,--script,${CMAKE_SOURCE_DIR}/src/shared/bart.lk")
set(CMAKE_EXECUTABLE_SUFFIX ".elf")

add_executable(${PROJECT_NAME} ${YabauseUT_SOURCES})

target_link_libraries(${PROJECT_NAME} ${YabauseUT_LIBRARIES} )

ADD_CUSTOM_COMMAND(TARGET ${PROJECT_NAME}
	POST_BUILD
	DEPENDS ${PROJECT_NAME}
	COMMAND ${CMAKE_OBJCOPY} --output-format=binary ${PROJECT_NAME}.elf ${PROJECT_NAME}.bin
    COMMENT "Generating bin file ${PROJECT_NAME}.bin" )