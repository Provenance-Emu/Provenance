set(simple_SOURCES main.c)

add_executable(simple-example ${simple_SOURCES})
target_link_libraries(simple-example mini18n-shared)

set(multi_SOURCES multi.c)

add_executable(multi-example ${multi_SOURCES})
target_link_libraries(multi-example mini18n-shared)
