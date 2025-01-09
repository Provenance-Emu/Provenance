MODULE := src/os/windows

MODULE_OBJS := \
	src/os/windows/FSNodeWINDOWS.o \
	src/os/windows/OSystemWINDOWS.o \
	src/os/windows/SerialPortWINDOWS.o \
	src/os/windows/SettingsWINDOWS.o \
	src/os/windows/stella_icon.o

MODULE_DIRS += \
	src/os/windows

# Include common rules
include $(srcdir)/common.rules
