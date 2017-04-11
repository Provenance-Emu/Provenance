project(yabause-gtk)

yab_port_start()

find_package(GTK2 2.10 COMPONENTS gtk)

if (NOT GTK2_FOUND)
	return()
endif (NOT GTK2_FOUND)

set(PORT_INCLUDE_DIRS ${GTK2_INCLUDE_DIRS})
set(PORT_LIBRARIES ${GTK2_LIBRARIES})

if (OPENGL_FOUND)
	find_path(GDKGLEXT_CONFIG_INCLUDE_DIR gdkglext-config.h PATHS ${CMAKE_SYSTEM_PREFIX_PATH} PATH_SUFFIXES lib/gtkglext-1.0/include)
	find_path(GTKGLEXT_INCLUDE_DIR gtk/gtkgl.h PATH_SUFFIXES gtkglext-1.0)
	find_library(GDKGLEXT_LIBRARY gdkglext-x11-1.0)
	find_library(GTKGLEXT_LIBRARY gtkglext-x11-1.0)
	if (NOT GDKGLEXT_CONFIG_INCLUDE_DIR OR NOT GTKGLEXT_INCLUDE_DIR OR NOT GDKGLEXT_LIBRARY OR NOT GTKGLEXT_LIBRARY)
		message(STATUS "Found OpenGL and Gtk+ but not libgtkglext, skipping Gtk+ port.")
		return()
	endif ()
	set(PORT_INCLUDE_DIRS ${PORT_INCLUDE_DIRS} ${GTKGLEXT_INCLUDE_DIR} ${GDKGLEXT_CONFIG_INCLUDE_DIR})
	set(PORT_LIBRARIES ${PORT_LIBRARIES} ${GTKGLEXT_LIBRARY} ${GDKGLEXT_LIBRARY})
	add_definitions(-DHAVE_LIBGTKGLEXT=1)
endif (OPENGL_FOUND)
include_directories(${PORT_INCLUDE_DIRS})

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -I/usr/include/gdk-pixbuf-2.0")

set(yabause_gtk_SOURCES
	gtk-compat.c
	gtkglwidget.c
	main.c
	menu.c
	pergtk.c
	settings.c
	yuicheckbutton.c
	yuifileentry.c
	yuiinputentry.c
	yuim68k.c
	yuimem.c
	yuipage.c
	yuirange.c
	yuiresolution.c
	yuiscreenshot.c
	yuiscsp.c
	yuiscudsp.c
	yuish.c
	yuitransfer.c
	yuivdp1.c
	yuivdp2.c
	yuiviewer.c
	yuiwindow.c)

add_executable(yabause-gtk ${yabause_gtk_SOURCES})
target_link_libraries(yabause-gtk yabause ${YABAUSE_LIBRARIES} ${PORT_LIBRARIES})

yab_port_success(yabause-gtk)
configure_file(yabause.desktop.in ${YAB_PORT_NAME}.desktop)

install(TARGETS yabause-gtk DESTINATION "bin")
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/${YAB_PORT_NAME}.desktop DESTINATION "share/applications")
install(FILES "doc/yabause.1" DESTINATION "${YAB_MAN_DIR}/man1" RENAME "${YAB_PORT_NAME}.1")
install(FILES "yabause.png" DESTINATION "share/pixmaps")
