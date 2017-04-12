AUTOMAKE_OPTIONS = subdir-objects
DEFS = -DLOCALEDIR=\"$(datadir)/locale\" @DEFS@
DEFAULT_INCLUDES = -I$(top_builddir)/include -I$(top_srcdir)/include -I$(top_srcdir)/intl

noinst_LIBRARIES        =       libgba.a
libgba_a_SOURCES	= GBAinline.cpp arm.cpp thumb.cpp bios.cpp eeprom.cpp flash.cpp GBA.cpp Gfx.cpp Globals.cpp Mode0.cpp Mode1.cpp Mode2.cpp Mode3.cpp Mode4.cpp Mode5.cpp RTC.cpp Sound.cpp sram.cpp
