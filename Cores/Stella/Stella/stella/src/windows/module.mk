MODULE := src/windows

MODULE_OBJS := \
	src/windows/FSNodeWINDOWS.o \
	src/windows/OSystemWINDOWS.o \
	src/windows/SerialPortWINDOWS.o \
	src/windows/SettingsWINDOWS.o \
	src/windows/stella_icon.o

MODULE_DIRS += \
	src/windows

# Include common rules 
include $(srcdir)/common.rules
