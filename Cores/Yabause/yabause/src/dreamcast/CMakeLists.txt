project(yabause-dc)

if(NOT dreamcast)
    return()
endif(NOT dreamcast)

enable_language(ASM-ATT)
include_directories(${PORT_INCLUDE_DIRS})
add_definitions(${PORT_CFLAGS})

set(yabause_dc_SOURCES
    cd.s
    localtime.c
    perdc.c
    viddc.c
    yui.c)

set(yabause_dc_HEADERS
    localtime.h
    perdc.h
    viddc.h)

link_directories(..)
add_executable(yabause-dc ${yabause_dc_SOURCES})
set_target_properties(yabause-dc PROPERTIES OUTPUT_NAME yabause.elf)
target_link_libraries(yabause-dc ${YABAUSE_LIBRARIES})
target_link_libraries(yabause-dc ${PORT_LIBRARIES})
target_link_libraries(yabause-dc yabause)
target_link_libraries(yabause-dc m)
