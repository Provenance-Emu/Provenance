project(yabause-cocoa)

yab_port_start()

find_library(AUDIO_LIBRARY AudioUnit)

if (NOT AUDIO_LIBRARY)
	return()
endif()

set(yabause_cocoa_SOURCES
	main.m
	PerCocoa.m
	YabauseButtonFormatter.m
	YabauseController.m
	YabauseGLView.m
	YabausePrefsController.m
	vidgcd.c
	vidgcd.h
)

set(yabause_cocoa_XIBS English.lproj/MainMenu)

include_directories("${CMAKE_CURRENT_SOURCE_DIR}/..")

add_executable(yabause-cocoa MACOSX_BUNDLE ${yabause_cocoa_SOURCES})
target_link_libraries(yabause-cocoa yabause ${YABAUSE_LIBRARIES}
	${AUDIO_LIBRARY})

yab_port_stop()
set_target_properties(yabause-cocoa PROPERTIES OUTPUT_NAME Yabause)

set_target_properties(yabause-cocoa PROPERTIES MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/CMake-Info.plist)

find_program(IBTOOL ibtool HINTS "/usr/bin" "${OSX_DEVELOPER_ROOT}/usr/bin")
if (${IBTOOL} STREQUAL "IBTOOL-NOTFOUND")
  message(SEND_ERROR "ibtool can not be found and is needed to compile the .xib files. It should have been installed with 
                    the Apple developer tools. The default system paths were searched in addition to ${OSX_DEVELOPER_ROOT}/usr/bin")
endif()

add_custom_command(
	TARGET yabause-cocoa PRE_BUILD
	COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/Yabause.app/Contents/MacOS)

add_custom_command(
	TARGET yabause-cocoa PRE_BUILD
	COMMAND mkdir -p ${CMAKE_CURRENT_BINARY_DIR}/Yabause.app/Contents/Resources/English.lproj)

foreach(xib ${yabause_cocoa_XIBS})
	add_custom_command(
		TARGET yabause-cocoa POST_BUILD 
		COMMAND ${IBTOOL} --errors --warnings --notices
		--output-format human-readable-text 
		--compile ${CMAKE_CURRENT_BINARY_DIR}/Yabause.app/Contents/Resources/${xib}.nib 
		${CMAKE_CURRENT_SOURCE_DIR}/${xib}.xib
		COMMENT "Compiling ${CMAKE_CURRENT_SOURCE_DIR}/${xib}.xib")

endforeach()

add_custom_command(
	TARGET yabause-cocoa POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/Yabause.icns ${CMAKE_CURRENT_BINARY_DIR}/Yabause.app/Contents/Resources)

add_custom_command(
	TARGET yabause-cocoa POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/resources/controller.png ${CMAKE_CURRENT_BINARY_DIR}/Yabause.app/Contents/Resources)

install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Yabause.app/" DESTINATION "Yabause.app" USE_SOURCE_PERMISSIONS)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../AUTHORS    DESTINATION ".")
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../ChangeLog  DESTINATION ".")
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../COPYING    DESTINATION ".")
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../README     DESTINATION ".")
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../README.MAC DESTINATION ".")
