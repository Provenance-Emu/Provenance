MODULE := src/os/unix

MODULE_OBJS := \
	src/os/unix/FSNodePOSIX.o \
	src/os/unix/OSystemUNIX.o \
	src/os/unix/SerialPortUNIX.o

MODULE_DIRS += \
	src/os/unix

# Include common rules
include $(srcdir)/common.rules
